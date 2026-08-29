# ceval exceptions (jac-py/PLAN.md §4 module-boundary constraint).
# Exception-table unwind, plain except matching, and PEP 654 ExceptionGroup
# split/subgroup kernel. ceval.jac imports this module; must not import pyc_first.

import ceval_host_bridge as _hb;

import from objects {
    exc_is_subclass_of,
    PyObj,
    PyCode,
    PyHandler,
    PyException,
    PyError,
    PyTraceback,
    PyClass,
    PyExceptionType,
    PyHostProxy,
    PyTuple,
    PyList,
    PyStr,
    PyExcGroup,
    PyFunction,
    PyNativeBuiltin,
    PyUserObj,
    PyInt,
    is_error,
    py_none,
    py_error,
}
import from exceptions_core { exc_name_matches }
import from ceval { class_mro, py_invoke }

::py::
def _jac_is_exception_type(host_val):
    return _hb._jac_is_exception_type(host_val)

def _jac_host_class_name(host_val):
    return _hb._jac_host_class_name(host_val)

::py::

# Signed varint (zigzag-style: bit 0 is the sign) used by linetable line deltas.
def read_svarint(data: list[int], pos: int) -> tuple[int, int] {
    (uval, npos) = read_varint(data, pos);
    if uval % 2 == 1 {
        return (-(uval >> 1), npos);
    }
    return ((uval >> 1), npos);
}

def read_varint(data: list[int], pos: int) -> tuple[int, int] {
    value = 0;
    current = 0;
    while pos < len(data) {
        current = data[pos] & 0xFF;
        pos = pos + 1;
        value = (value << 6) | (current & 63);
        if (current & 64) == 0 {
            return (value, pos);
        }
    }
    return (value, pos);
}

# Line number for a bytecode offset, decoded from the PEP 626 location table
# (same format the assembler emits and host marshal delivers; entry layout per
# CPython advance_with_locations in Objects/codeobject.c: first byte carries a
# 128 start bit, kind in bits 3-6, run length in bits 0-2).
def pycode_lineno(co: PyCode, offset: int) -> int {
    line = co.firstlineno;
    table = co.linetable;
    pos = 0;
    span_start = 0;
    while pos < len(table) {
        first = table[pos];
        if (first & 128) == 0 {
            # Not an entry start byte: corrupt table, stop with best-known line.
            break;
        }
        kind = (first >> 3) & 15;
        units = (first & 7) + 1;
        pos = pos + 1;
        span_end = span_start + units * 2;
        # NONE entries carry no location; keep the last known line so a raise
        # inside an unlocated region still reports something sane.
        if kind != 15 {
            if kind == 14 {
                # LONG: signed line delta + three varints (endline delta, cols).
                dec = read_svarint(table, pos);
                line = line + dec[0];
                pos = dec[1];
                dec = read_varint(table, pos);
                pos = dec[1];
                dec = read_varint(table, pos);
                pos = dec[1];
                dec = read_varint(table, pos);
                pos = dec[1];
            } elif kind == 13 {
                # NO_COLUMNS: signed line delta only.
                dec = read_svarint(table, pos);
                line = line + dec[0];
                pos = dec[1];
            } elif kind >= 10 {
                # ONE_LINE0..2: fixed line deltas, two raw column bytes.
                line = line + (kind - 10);
                pos = pos + 2;
            } else {
                # SHORT0..9: same line, one raw column-pair byte.
                pos = pos + 1;
            }
            if offset >= span_start and offset < span_end {
                return line;
            }
        }
        span_start = span_end;
    }
    return line;
}

def find_handler(co: PyCode, offset: int) -> PyHandler | None {
    data = co.exceptiontable;
    pos = 0;
    while pos < len(data) {
        start_read = read_varint(data, pos);
        start = start_read[0] * 2;
        pos = start_read[1];
        length_read = read_varint(data, pos);
        end = start + length_read[0] * 2;
        pos = length_read[1];
        target_read = read_varint(data, pos);
        target = target_read[0] * 2;
        pos = target_read[1];
        depth_read = read_varint(data, pos);
        depth = depth_read[0] >> 1;
        lasti = (depth_read[0] & 1) != 0;
        pos = depth_read[1];
        if offset >= start and offset < end {
            return PyHandler(
                t="handler",
                start=start,
                end=end,
                target=target,
                depth=depth,
                lasti=lasti
            );
        }
    }
    return None;
}

def recover_exception(
    co: PyCode, value: PyObj, offset: int, stack: list[PyObj]
) -> int {
    if value.t != "error" {
        return -1;
    }
    # Traceback growth (CPython generic `error` label): every ERROR EVENT --
    # a failing opcode or RAISE_VARARGS 1/2 -- prepends exactly one entry per
    # frame before handler search, so e.__traceback__ heads at the catching
    # frame and tb_next walks toward the raise point. Reraises are NOT error
    # events: RERAISE and bare RAISE_VARARGS 0 jump straight to
    # exception_unwind in CPython, adding no entry -- those paths must go
    # through dispatch_exception below instead.
    error = value as PyError;
    prev = error.exception.traceback;
    error.exception.traceback = PyTraceback(
        t="traceback",
        tb_next=prev,
        code=co,
        tb_lineno=pycode_lineno(co, offset),
        tb_lasti=offset
    );
    return dispatch_exception(co, value, offset, offset, stack);
}

# Handler search + stack handoff WITHOUT traceback growth. This is CPython's
# exception_unwind: locate the covering exception-table entry (at `offset`,
# the faulting/reraising instruction), trim the value stack to its depth, push
# lasti (when flagged; `lasti_offset` lets re-raises push the RESTORED lasti,
# matching CPython's instr_ptr restore) and the exception, and jump.
def dispatch_exception(
    co: PyCode,
    value: PyObj,
    offset: int,
    lasti_offset: int,
    stack: list[PyObj]
) -> int {
    handler = find_handler(co, offset);
    if handler is None {
        return -1;
    }
    error = value as PyError;
    while len(stack) > handler.depth {
        stack.pop();
    }
    if handler.lasti {
        stack.append(PyInt(t="int", val=lasti_offset));
    }
    stack.append(error.exception);
    return handler.target;
}

# _PyEval_CheckExceptTypeValid: a plain `except X` target must be a class
# deriving BaseException -- a builtin native exception type, a guest class whose
# MRO reaches one, or a host-proxied exception class. Tuples are validated
# element-wise. Anything else (int, str, an instance, a non-exception class)
# makes CHECK_EXC_MATCH raise CPython's TypeError before any matching happens.
def except_target_valid(target: PyObj) -> bool {
    if target.t == "tuple" {
        for item in (target as PyTuple).items {
            if not except_target_valid(item) {
                return False;
            }
        }
        return True;
    }
    if target.t == "exception_type" {
        return True;
    }
    if isinstance(target, PyHostProxy)
        and bool(_jac_is_exception_type((target as PyHostProxy).val)) {
        return True;
    }
    if isinstance(target, PyClass) {
        return class_is_exception(target as PyClass);
    }
    return False;
}

def exception_matches(value: PyObj, target: PyObj) -> bool {
    if value.t != "exception" {
        return False;
    }
    exception = value as PyException;
    # A user exception class target (except Exc): match by the raised instance's
    # MRO if we kept the instance, else by class name.
    if isinstance(target, PyClass) {
        raw = exception.raw;
        if raw is not None and isinstance(raw, PyUserObj) {
            for klass in class_mro((raw as PyUserObj).cls) {
                if klass is (target as PyClass) {
                    return True;
                }
            }
        }
        return (target as PyClass).name == exception.type_name;
    }
    if target.t == "tuple" {
        # `except (A, B):` - CPython's CHECK_EXC_MATCH delegates to
        # PyErr_GivenExceptionMatches, which iterates tuple targets.
        for item in (target as PyTuple).items {
            if exception_matches(value, item) {
                return True;
            }
        }
        return False;
    }
    target_name: str = "";
    if target.t == "exception_type" {
        target_name = (target as PyExceptionType).name;
    } elif target.t == "host" {
        # The except-target is a host exception CLASS; read its own __name__, not
        # type(cls).__name__ (which is "type" and never matches).
        target_name = _jac_host_class_name((target as PyHostProxy).val) as str;
    }
    if target_name == "" {
        return False;
    }
    # A raised USER exception instance matches builtin targets through its real
    # MRO: class MyErr(KeyError) must satisfy `except KeyError` even though the
    # name-level tree has no MyErr entry. Walk the MRO classes and their bases,
    # which carry the native/host exception-type markers recorded at class
    # creation.
    raw = exception.raw;
    if raw is not None and isinstance(raw, PyUserObj) {
        for klass in class_mro((raw as PyUserObj).cls) {
            if klass.name == target_name {
                return True;
            }
            for base in klass.bases {
                # Transitive name-level match so a user subclass of a builtin
                # subclass (MyErr(KeyError)) satisfies broader targets
                # (`except LookupError`); inclusive of exact equality.
                if isinstance(base, PyExceptionType)
                    and exc_is_subclass_of(
                        (base as PyExceptionType).name, target_name
                    ) {
                    return True;
                }
                if isinstance(base, PyHostProxy)
                    and (_jac_host_class_name((base as PyHostProxy).val) as str)
                        == target_name {
                    return True;
                }
            }
        }
    }
    return exc_name_matches(exception.type_name, target_name);
}

# True iff a raised error IS StopIteration or a SUBCLASS of it -- CPython's
# FOR_ITER / tp_iternext exhaustion contract matches by type
# (PyErr_ExceptionMatches), never by exact type-name equality. Covers builtin
# name-chain subclasses via exc_name_matches and guest classes whose bases
# reach the native StopIteration type.
def error_is_stopiteration(err: PyObj) -> bool {
    if err.t != "error" {
        return False;
    }
    exc = (err as PyError).exception;
    if exc_name_matches(exc.type_name, "StopIteration") {
        return True;
    }
    raw = exc.raw;
    if raw is not None and isinstance(raw, PyUserObj) {
        for klass in class_mro((raw as PyUserObj).cls) {
            for base in klass.bases {
                if isinstance(base, PyExceptionType)
                    and (base as PyExceptionType).name == "StopIteration" {
                    return True;
                }
            }
        }
    }
    return False;
}

# True iff `cls` (a user class) derives from a builtin exception -- i.e. one of
# its MRO classes lists a host BaseException-subclass proxy among its bases.
# `class Exc(Exception)` has native_base "" (Exception is not a subclassable
# builtin layout), so we detect it through the recorded host base, not the layout.
def class_is_exception(cls: PyClass) -> bool {
    for klass in class_mro(cls) {
        for base in klass.bases {
            # Builtin exceptions resolve to a native PyExceptionType (Exception,
            # ValueError, ...); a not-yet-native one arrives as a host proxy.
            if isinstance(base, PyExceptionType) {
                return True;
            }
            if isinstance(base, PyHostProxy)
                and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                return True;
            }
        }
    }
    return False;
}

# ---------------- except* primitives (CHECK_EG_MATCH) ----------------

# True iff a builtin exception-family name sits under BaseExceptionGroup.
# The plain parent walk misses PEP 654's polymorphism -- EXC_PARENT records
# ExceptionGroup under Exception, not under BaseExceptionGroup -- so the
# ExceptionGroup branch is checked explicitly.
def exc_is_eg_family(name: str) -> bool {
    return exc_is_subclass_of(name, "BaseExceptionGroup")
        or exc_is_subclass_of(name, "ExceptionGroup");
}

# Builtin exception-family name behind a caught-class target: PyExceptionType
# for builtin names, host class for delegated ones, and the nearest builtin
# PyExceptionType base for user classes (class MyErr(KeyError) -> "KeyError").
# "" marks a target that is not an exception class at all.
def eg_target_family(target: PyObj) -> str {
    if isinstance(target, PyExceptionType) {
        return (target as PyExceptionType).name;
    }
    if isinstance(target, PyHostProxy)
        and bool(_jac_is_exception_type((target as PyHostProxy).val)) {
        return _jac_host_class_name((target as PyHostProxy).val) as str;
    }
    if isinstance(target, PyClass) {
        for klass in class_mro(target as PyClass) {
            for base in klass.bases {
                if isinstance(base, PyExceptionType) {
                    return (base as PyExceptionType).name;
                }
                if isinstance(base, PyHostProxy)
                    and bool(_jac_is_exception_type((base as PyHostProxy).val)) {
                    return _jac_host_class_name((base as PyHostProxy).val) as str;
                }
            }
        }
    }
    return "";
}

# _PyEval_CheckExceptStarTypeValid: every except* target must be an exception
# class (tuple members included), and none may be an ExceptionGroup subclass
# (CPython's CANNOT_EXCEPT_STAR_EG TypeError). Returns py_none() when valid.
def eg_validate_star_target(target: PyObj) -> PyObj {
    if target.t == "tuple" {
        for item in (target as PyTuple).items {
            invalid = eg_validate_star_target(item);
            if is_error(invalid) {
                return invalid;
            }
        }
        return py_none();
    }
    family = eg_target_family(target);
    if family == "" {
        return py_error(
            "TypeError",
            "catching classes that do not inherit from BaseException is not allowed"
        );
    }
    if exc_is_eg_family(family) {
        return py_error(
            "TypeError",
            "catching ExceptionGroup with except* is not allowed. Use except instead."
        );
    }
    return py_none();
}

# True iff a raised instance is an ExceptionGroup (BaseExceptionGroup family).
# User subclasses carry their builtin ancestor in `family` -- type_name alone
# would hide class MyGrp(ExceptionGroup) from the check.
def eg_is_group(exc: PyObj) -> bool {
    if exc.t != "exception" {
        return False;
    }
    e = exc as PyException;
    if exc_is_eg_family(e.type_name) {
        return True;
    }
    return e.family != "" and exc_is_eg_family(e.family);
}

# Leaf builtin-family name for the all-Exception rule below: user leaves
# resolve through their recorded family, builtin leaves through type_name.
def eg_leaf_family(exc: PyObj) -> str {
    e = exc as PyException;
    return e.family if e.family != "" else e.type_name;
}

# The group's member sequence, as stored by PyExceptionType.tp_call at
# construction time: args == [message, members]. Only list/tuple members are
# recognized; anything else is a malformed instance and surfaces as SystemError.
def eg_members(exc: PyObj) -> PyObj {
    args = (exc as PyException).args;
    if len(args) >= 2 {
        seq = args[1];
        if isinstance(seq, PyList) {
            return seq;
        }
        if isinstance(seq, PyTuple) {
            items: list[PyObj] = [];
            items.extend((seq as PyTuple).items);
            return PyList(t="list", items=items);
        }
    }
    return py_error("SystemError", "malformed ExceptionGroup instance");
}

# The group's message: args[0] per the tp_call layout above; falls back to the
# message field for groups built by other paths.
def eg_message(exc: PyObj) -> str {
    args = (exc as PyException).args;
    if len(args) > 0 and isinstance(args[0], PyStr) {
        return (args[0] as PyStr).val;
    }
    return (exc as PyException).message;
}

# All-Exception scan over a rebuilt member list: ExceptionGroup may only wrap
# Exception leaves; any BaseException leaf forces BaseExceptionGroup.
def eg_all_exception(members: PyList) -> bool {
    for m in members.items {
        if eg_is_group(m) {
            sub = eg_members(m);
            if is_error(sub) or not eg_all_exception(sub as PyList) {
                return False;
            }
        } elif not exc_is_subclass_of(eg_leaf_family(m), "Exception") {
            return False;
        }
    }
    return True;
}

# Rebuild an ExceptionGroup around surviving members, mirroring the
# PyExceptionType.tp_call storage layout so eg_members/eg_message round-trip.
# Derived-group narrowing (PEP 654 derive()) stays out of scope: rebuilt
# subgroups use the plain Exception/BaseExceptionGroup split fallback.
def eg_build(message: str, members: list[PyObj]) -> PyObj {
    if len(members) == 0 {
        return py_none();
    }
    inner: list[PyObj] = [];
    inner.extend(members);
    name = "BaseExceptionGroup";
    if eg_all_exception(PyList(t="list", items=inner)) {
        name = "ExceptionGroup";
    }
    stored_args: list[PyObj] = [
        PyStr(t="str", val=message),
        PyList(t="list", items=inner),
    ];
    excs_copy: list[PyObj] = [];
    excs_copy.extend(members);
    # Construct the typed group object so rebuilt groups carry the full
    # member surface (.message/.exceptions), same as tp_call construction.
    return PyExcGroup(
        t="exception", type_name=name, message=message,
        args=stored_args, excs=excs_copy
    );
}


# _PyEval_ExceptionGroupMatch primitive: returns (rest, match). A full match
# yields (None, group-or-wrapped-exc); an EG partial match yields the split
# pair (either half may be None); no match yields (exc, None). Both None means
# there was no active exception.
# ---------------- P3 split/subgroup kernel (PEP 654) ----------------
# Port of Objects/exception_groups.c: check_subgroup condition validation and
# subgroup_split_recursive partitioning. Conditions are exception types,
# tuples of them, None (matches everything), or a callable applied per leaf.
# Type matching routes through the family-string matcher, so an unhashable
# metaclass type stays a valid condition (no hashing on this path).

obj PyAddNoteMethod(PyObj) {
    has target: PyException;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 or not isinstance(args[0], PyStr) {
            return py_error("TypeError", "add_note() argument must be a str");
        }
        note = args[0];
        existing = self.target.type_fields.get("__notes__");
        notes: list[PyObj] = [];
        if existing is not None and isinstance(existing, PyList) {
            notes.extend((existing as PyList).items);
        }
        notes.append(note);
        self.target.type_fields["__notes__"] = PyList(t="list", items=notes);
        return py_none();
    }
}

obj PyExcGroupMethod(PyObj) {
    has target: PyExcGroup,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 1 {
            return py_error(
                "TypeError",
                self.name + "() takes exactly one argument ("
                + str(len(args)) + " given)"
            );
        }
        if self.name == "split" {
            return eg_split_entry(self.target, args[0]);
        }
        return eg_subgroup_entry(self.target, args[0]);
    }
}

def eg_condition_error() -> PyObj {
    return py_error(
        "TypeError",
        "expected an exception type, a tuple of exception types, or a "
        "callable (other than a class)"
    );
}

# "" = invalid; "all" = None; "match" = type/tuple-of-types; "pred" = callable.
def eg_condition_kind(cond: PyObj) -> str {
    if cond.t == "none" {
        return "all";
    }
    if cond.t == "tuple" {
        for item in (cond as PyTuple).items {
            if eg_target_family(item) == "" and not isinstance(item, PyClass) {
                return "";
            }
        }
        return "match";
    }
    if eg_target_family(cond) != "" {
        return "match";
    }
    # Guest-defined classes carry no builtin family at the root; their name
    # matches leaves through eg_cond_match without crossing the host bridge
    # (an unhashable metaclass must never be hashed or to_host'ed here).
    if isinstance(cond, PyClass) {
        return "match";
    }
    if isinstance(cond, PyFunction) or isinstance(cond, PyNativeBuiltin) {
        return "pred";
    }
    return "";
}

# Leaf-vs-condition match for kind == "match": guest classes compare by name /
# family subclass chains (no hashing); builtin types and tuples delegate to
# the standard matcher.
def eg_cond_match(leaf: PyObj, cond: PyObj) -> bool {
    if isinstance(cond, PyClass) {
        lf = eg_leaf_family(leaf);
        cname = (cond as PyClass).name;
        return lf == cname or exc_is_subclass_of(lf, cname);
    }
    # Builtin/host-proxy types match through family strings -- never through
    # the host bridge, so an unhashable metaclass type stays valid.
    cf = eg_target_family(cond);
    if cf != "" {
        lf = eg_leaf_family(leaf);
        return lf == cf or exc_is_subclass_of(lf, cf);
    }
    return exception_matches(leaf, cond);
}

# subgroup_split_recursive: partitions the group's members into (match, rest)
# group halves sharing the original message; nested groups are rebuilt (never
# reused), empty halves collapse to None, leaves keep identity. Third slot
# carries an error instead when condition evaluation raises.
def eg_split_rec(gexc: PyObj, kind: str, cond: PyObj) -> tuple[PyObj, PyObj, PyObj] {
    m_items: list[PyObj] = [];
    r_items: list[PyObj] = [];
    members = eg_members(gexc);
    if is_error(members) {
        return (py_none(), py_none(), members);
    }
    for m in (members as PyList).items {
        matched = False;
        if eg_is_group(m) {
            triple = eg_split_rec(m, kind, cond);
            if is_error(triple[2]) {
                return (py_none(), py_none(), triple[2]);
            }
            if triple[0].t != "none" {
                m_items.append(triple[0]);
            }
            if triple[1].t != "none" {
                r_items.append(triple[1]);
            }
            continue;
        }
        if kind == "all" {
            matched = True;
        } elif kind == "match" {
            matched = eg_cond_match(m, cond);
        } else {
            rv = py_invoke(cond, [m], {});
            if is_error(rv) {
                return (py_none(), py_none(), rv);
            }
            matched = rv.tp_bool();
        }
        if matched {
            m_items.append(m);
        } else {
            r_items.append(m);
        }
    }
    msg = eg_message(gexc);
    return (eg_build(msg, m_items), eg_build(msg, r_items), py_none());
}

# split_recursive tail: derived partitions inherit the original group's
# __context__/__cause__ when set (CPython SetContext/SetCause).
def eg_copy_chain(orig: PyObj, derived: PyObj) -> None {
    o = orig as PyException;
    d = derived as PyException;
    if o.context is not None {
        d.context = o.context;
    }
    if o.cause is not None {
        d.cause = o.cause;
    }
}

def eg_split_entry(exc: PyObj, cond: PyObj) -> PyObj {
    kind = eg_condition_kind(cond);
    if kind == "" {
        return eg_condition_error();
    }
    triple = eg_split_rec(exc, kind, cond);
    if is_error(triple[2]) {
        return triple[2];
    }
    if triple[0].t == "exception" {
        eg_copy_chain(exc, triple[0]);
    }
    if triple[1].t == "exception" {
        eg_copy_chain(exc, triple[1]);
    }
    items: list[PyObj] = [triple[0], triple[1]];
    return PyTuple(t="tuple", items=items);
}

def eg_subgroup_entry(exc: PyObj, cond: PyObj) -> PyObj {
    kind = eg_condition_kind(cond);
    if kind == "" {
        return eg_condition_error();
    }
    triple = eg_split_rec(exc, kind, cond);
    if is_error(triple[2]) {
        return triple[2];
    }
    if triple[0].t == "exception" {
        eg_copy_chain(exc, triple[0]);
    }
    return triple[0];
}


def exception_group_split(exc: PyObj, target: PyObj) -> tuple[PyObj, PyObj] {
    if exc.t == "none" {
        return (py_none(), py_none());
    }
    if exception_matches(exc, target) {
        matched_whole: PyObj = exc;
        if not eg_is_group(exc) {
            # Naked exception: CPython wraps it in ExceptionGroup('', [exc])
            # with the current traceback attached; traceback plumbing lands
            # with the PREP_RERAISE_STAR lane.
            matched_whole = eg_build("", [exc]);
        }
        return (py_none(), matched_whole);
    }
    if eg_is_group(exc) {
        members_obj = eg_members(exc);
        if is_error(members_obj) {
            return (members_obj, py_none());
        }
        matched: list[PyObj] = [];
        unmatched: list[PyObj] = [];
        msg = eg_message(exc);
        for m in (members_obj as PyList).items {
            if eg_is_group(m) {
                sub = exception_group_split(m, target);
                if is_error(sub[0]) {
                    return sub;
                }
                if sub[1].t != "none" {
                    matched.append(sub[1]);
                }
                if sub[0].t != "none" {
                    unmatched.append(sub[0]);
                }
            } elif exception_matches(m, target) {
                matched.append(m);
            } else {
                unmatched.append(m);
            }
        }
        return (eg_build(msg, unmatched), eg_build(msg, matched));
    }
    return (exc, py_none());
}

# BaseException attribute view of a USER exception instance: CPython records
# args at construction time (BaseException_new) and its tp_str/tp_repr read
# that slot, so a subclass without custom __str__/__repr__ presents exactly
# like its builtin base. The wrapper borrows the class name + stored args.
