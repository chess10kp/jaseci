# ceval host bridge (jac-py/PLAN.md §4 module-boundary constraint).
# Pure ::py:: helpers for guest<->host crossings: host syscall shims, type
# probes, module discovery, weakref lazy import. ceval.jac re-exports these via
# thin ::py:: wrappers (Jac type checker treats inline ::py:: as opaque).
# Jac-coupled bridge shims (live views, trampolines, reraise, standins) live
# in ceval_bridge_guest.jac to preserve the acyclic objects <- ceval DAG.

import marshal;

::py::
def _jac_host_error(exc):
    # Failed-bridge result carrying the ORIGINAL host exception object in slot
    # 3. Existing consumers only read slots 0..2 (host_result_ok plus the
    # type-name/message strings), so the extra slot is transparent to them --
    # but the guest-side converter (host_result_error below) can now preserve
    # the exception's identity, args, __cause__/__context__ chain, and
    # traceback instead of re-synthesizing a bare etype(message).
    return (False, type(exc).__name__, str(exc), exc)

def _jac_host_import(name, fromlist):
    import importlib
    try:
        if fromlist:
            return (True, importlib.import_module(name))
        return (True, importlib.import_module(name.split(".")[0]))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_getattr(value, name):
    try:
        return (True, getattr(value, name))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_setattr(value, name, field):
    try:
        setattr(value, name, field)
        return (True, None)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_call(fn, args, kwargs):
    try:
        return (True, fn(*args, **kwargs), None, None)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_dir(value):
    # Exact host dir() for values with a faithful host representation (host
    # proxies, native scalars/containers): CPython's own enumeration, so the
    # name list is byte-exact with the host interpreter.
    try:
        return (True, [str(n) for n in dir(value)])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_type_surface(kind):
    # Unsorted __dict__ keys of a HOST type surface -- the static half of
    # CPython's dir() merge_class_dict walk (object/type/BaseException/...).
    import builtins
    import types
    try:
        target = None
        if kind == "object":
            target = builtins.object
        elif kind == "type":
            target = builtins.type
        elif kind == "function":
            target = types.FunctionType
        elif kind == "method":
            target = types.MethodType
        else:
            target = getattr(builtins, kind, None)
        if target is None:
            raise TypeError("unknown type surface '" + kind + "'")
        return (True, [str(n) for n in vars(target)])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_type_attr(kind, name):
    # getattr on the HOST type for `kind` -- the inherited slot-wrapper surface
    # a guest class exposes through CPython's metaclass channel (type(C).__mro__
    # reaches object, whose type dict carries every slot wrapper). Companion to
    # _jac_host_type_surface, which enumerates this dict for dir(); this fetches
    # one entry's live value so `Cls.__repr__` returns the byte-exact host
    # wrapper object pprint-style dispatch tables key on.
    import builtins
    import types
    try:
        if kind == "object":
            target = builtins.object
        elif kind == "type":
            target = builtins.type
        elif kind == "function":
            target = types.FunctionType
        elif kind == "method":
            target = types.MethodType
        else:
            target = getattr(builtins, kind, None)
        if target is None:
            raise TypeError("unknown type surface '" + kind + "'")
        return (True, getattr(target, name))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_is_callable(value):
    return callable(value)

def _jac_host_getitem(value, index):
    try:
        return (True, value[index])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_str_encode(s, encoding, errors):
    try:
        return (True, s.encode(encoding, errors))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_len(value):
    try:
        return (True, len(value))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_is_object_type(value):
    # True iff value is exactly the builtin `object` type. object.__new__(cls) is
    # the canonical plain-instance constructor (functools._PlaceholderType, any
    # singleton). Other types' __new__ stays host-routed so namedtuple's
    # tuple.__new__(HostClass, ...) is unaffected.
    return value is object

def _jac_is_type_type(value):
    # True iff value is exactly the builtin `type`. A user class listing `type`
    # among its bases is a metaclass; super().__new__ inside its __new__ must
    # build a class object (type.__new__), not a plain instance.
    return value is type

def _jac_static_type_name(value):
    # CPython type.__setattr__ policy probe (Objects/typeobject.c
    # type_setattro): attribute writes land only on HEAP types; a static
    # builtin/extension type rejects EVERY write with the canonical TypeError,
    # before the assigned value is examined. Returns the tp_name for a static
    # type (the error message quotes it), "" for heap types and non-types.
    import builtins
    if isinstance(value, type) and not (value.__flags__ & (1 << 9)):
        return getattr(value, "__name__", "")  # Py_TPFLAGS_HEAPTYPE = 1 << 9
    return ""

def _jac_is_super_type(value):
    # True iff value is exactly the builtin `super` type. Zero-arg super() at a
    # generic call site must raise CPython's frame-without-cell error instead of
    # letting the host super introspect the jaclang interpreter's own frame.
    import builtins
    return value is builtins.super

def _jac_is_range_type(value):
    # True iff value is exactly the builtin `range` type. The py_call_host ctor
    # interception must match ONLY the exact builtin -- never a subclass -- so
    # this mirrors _jac_is_object_type/_jac_is_type_type rather than routing
    # through _jac_builtin_base_name (whose membership list feeds Track B
    # subclass machinery that range must NOT join).
    return value is range

def _jac_is_slice_type(value):
    # True iff value is exactly the builtin `slice` type. The tp_call
    # interception must match ONLY the exact builtin -- never a subclass -- so
    # this mirrors _jac_is_object_type/_jac_is_range_type rather than routing
    # through _jac_builtin_base_name (whose membership list feeds Track B
    # subclass machinery that slice must NOT join).
    import builtins
    return value is builtins.slice

def _jac_conversion_ctor_kind(value):
    # Which conversion constructor ("int"/"float"/"bool"/"str") value is, or "".
    # Identity against the exact host builtins -- the same mechanism-level
    # idiom as _jac_is_object_type/_jac_is_range_type -- because the tp_call
    # fast path below must match ONLY the real constructors: name matching
    # (_jac_builtin_base_name) would also catch a user-defined class merely
    # named "int", and that class's instances must take their own call path.
    import builtins
    if value is builtins.int:
        return "int"
    if value is builtins.float:
        return "float"
    if value is builtins.bool:
        return "bool"
    if value is builtins.str:
        return "str"
    return ""

def _jac_is_builtin_func(value, name):
    # True iff value is EXACTLY the builtin function `name` (repr/format/print).
    # Identity, never name matching: a user-defined callable merely named
    # "repr" must keep its own call path.
    import builtins
    return value is getattr(builtins, name, None)

def _jac_is_complex_type(value):
    # True iff value is EXACTLY the builtin `complex` type -- the tp_call
    # interception must match only the real constructor, never a user class
    # merely named "complex" (same identity idiom as _jac_conversion_ctor_kind).
    import builtins
    return value is builtins.complex

def _jac_host_hashkey(value) -> str:
    # Bucket a proxied host object by its host hash so it can be a dict/set key
    # (type-keyed dispatch tables in functools/copyreg/typing/contextlib). Equal
    # host objects share a hash, hence a bucket; the dict layer confirms a bucket
    # hit with a real == (PyHostProxy needs_eq_confirm). "" means unhashable --
    # tp_hashkey turns it into the explicit PyError marker.
    try:
        return "host:" + str(hash(value))
    except BaseException:
        return ""

def _jac_host_contains(member, container):
    try:
        return (True, member in container)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_is_notimpl(v):
    return v is NotImplemented

def _jac_host_iter(value):
    try:
        return (True, list(value))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_builtin(name):
    import builtins
    try:
        return (True, getattr(builtins, name))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_code_marshal(co):
    # A HOST code object (compile()/types.CodeType crossing the bridge as a
    # proxy) marshalled into the transport form unmarshal() turns back into a
    # native PyCode -- the exec() builtin's route for host-built code objects.
    import marshal
    try:
        return (True, marshal.dumps(co))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_source_marshal(source):
    # exec(str)/exec(bytes) source compiled on the host into the transport
    # form (native statement-mode compile is Phase C). Errors -- SyntaxError
    # above all -- come back through the tuple protocol so the guest raises a
    # CATCHABLE exception, matching CPython's exec('for = 1') contract.
    import marshal
    try:
        return (True, marshal.dumps(compile(source, "<string>", "exec")))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_type_name(value):
    return type(value).__name__

def _jac_host_id(value):
    return id(value)

def _jac_host_type(value):
    # type(value) for a host object -- the fallback for py_type_of when the
    # argument has no in-VM class (a proxied host value, or a native scalar whose
    # to_host round-trips cleanly to int/str/float/...).
    return type(value)

def _jac_host_delattr(host_obj, name):
    try:
        delattr(host_obj, name)
        return (True, None)
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_wrap_classmethod(host_fn):
    return classmethod(host_fn)

def _jac_wrap_staticmethod(host_fn):
    return staticmethod(host_fn)

def _jac_wrap_property(fget, fset, fdel):
    return property(fget, fset, fdel)

def _jac_wrap_mappingproxy(d):
    import types
    return types.MappingProxyType(d)

def _jac_wrap_tstr_interp(value, expression, conversion, format_spec):
    import string.templatelib as tl
    return tl.Interpolation(
        value=value,
        expression=expression,
        conversion=conversion,
        format_spec=format_spec
    )

def _jac_wrap_tstr_template(strings, interpolations):
    import string.templatelib as tl
    return tl.Template(strings=strings, interpolations=interpolations)

def _jac_construct_host_type(host_type, raw_args):
    # Non-builtin host C-type bases (io.BytesIO, ...) resolve by reference,
    # not builtins lookup -- unknown names cannot degrade gracefully here.
    try:
        if raw_args:
            return (True, host_type(*raw_args))
        return (True, host_type())
    except BaseException as exc:
        return _jac_host_error(exc)

# Track B (builtin subclassing) host helpers.
_JAC_BUILTIN_BASES = (
    "int", "str", "float", "bool", "list", "dict",
    "tuple", "set", "frozenset", "bytes", "object",
)

def _jac_builtin_base_name(host_val) -> str:
    # If host_val is one of the subclassable builtin TYPES, return its name.
    import builtins
    if isinstance(host_val, type):
        n = getattr(host_val, "__name__", "")
        if n in _JAC_BUILTIN_BASES:
            return n
    return ""

def _jac_construct_builtin(name, raw_args):
    import builtins
    # Unknown names (a user Exception subclass) must degrade gracefully -- the
    # callers fall back to a base type instead of crashing the boundary.
    t = getattr(builtins, name, None)
    if t is None:
        return (False, "AttributeError", "module 'builtins' has no attribute '" + name + "'")
    try:
        if raw_args:
            return (True, t(*raw_args))
        return (True, t())
    except BaseException as exc:
        return _jac_host_error(exc)

# Dynamic host Exception subclass for a USER/module exception name, cached per
# name so repeated crossings keep one host class (stable repr/isinstance).
_JAC_USER_EXC_TYPES = {}
def _jac_make_exception_type(name):
    import builtins
    t = _JAC_USER_EXC_TYPES.get(name)
    if t is None:
        t = type(name, (getattr(builtins, "Exception"),), {})
        _JAC_USER_EXC_TYPES[name] = t
    return t

# Registry-aware materialization for MODULE exceptions: a registered qualified
# name (struct.error, json.JSONDecodeError, ...) mints a cached host subclass
# of its DECLARED BASE -- json.JSONDecodeError subclasses ValueError, so guest
# `except ValueError` and host isinstance both see the real hierarchy. The
# host class presents the SHORT name (CPython repr shape: struct.error shows
# as "error('...')"). Resolution order: exact builtin -> registered base ->
# generic same-name Exception subclass.
_JAC_MODULE_EXC_TYPES = {}
def _jac_make_module_exc_type(qname, base_name):
    import builtins
    short = qname.rsplit(".", 1)[-1]
    t = _JAC_MODULE_EXC_TYPES.get(qname)
    if t is None:
        base = None
        if base_name:
            bt = getattr(builtins, base_name, None)
            if isinstance(bt, type) and issubclass(bt, BaseException):
                base = bt
        if base is None:
            base = _jac_make_exception_type(short)
        t = type(short, (base,), {})
        _JAC_MODULE_EXC_TYPES[qname] = t
    return t

def _jac_builtin_new(name, host_cls, raw_args):
    # builtin.__new__(host_cls, *raw_args): the host builtin constructor over a
    # HOST class (namedtuple's dynamic tuple subclass). Keeps the host subclass
    # instance intact instead of collapsing it to a native value.
    import builtins
    t = getattr(builtins, name)
    try:
        return (True, t.__new__(host_cls, *raw_args))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_builtin_new_slot(name):
    import builtins
    if name == "" or name == "object":
        return object.__new__
    return getattr(builtins, name).__new__

def _jac_isinstance_of_builtin(host_val, name) -> bool:
    # True iff host_val is an instance of the named builtin type.
    import builtins
    t = getattr(builtins, name, None)
    if t is None:
        return False
    return isinstance(host_val, t)

def _jac_host_isinstance(host_obj, host_type):
    try:
        return isinstance(host_obj, host_type)
    except BaseException:
        return False

def _jac_type_has_flag(host_obj, flag_bit) -> bool:
    # Accepts BOTH shapes: a host INSTANCE (SEQUENCE/MAPPING checks inspect the
    # subject's type) and a host CLASS itself (MATCH_SELF checks inspect the
    # match pattern's own tp_flags -- type(cls).__flags__ would wrongly read
    # the metaclass).
    try:
        cls = host_obj if isinstance(host_obj, type) else type(host_obj)
        return bool(cls.__flags__ & flag_bit)
    except BaseException:
        return False

def _jac_host_pattern_name(host_val):
    # Name quoted by the MATCH_CLASS TypeError messages. A class-pattern proxy
    # wraps the HOST CLASS itself (int, str, ...), whose name is its own --
    # type(host_val).__name__ would quote the metaclass ('type') instead.
    try:
        return host_val.__name__ if isinstance(host_val, type) else type(host_val).__name__
    except BaseException:
        return "?"

def _jac_host_type_name(host_obj):
    try:
        return type(host_obj).__name__
    except BaseException:
        return "?"

def _jac_is_exception_type(host_val):
    # True iff host_val is a class deriving from BaseException (used to recognize
    # a user class like `class Exc(Exception)` whose host base proxy is here).
    return isinstance(host_val, type) and issubclass(host_val, BaseException)

def _jac_host_issubclass(host_cls, host_type) -> bool:
    try:
        return issubclass(host_cls, host_type)
    except BaseException:
        return False

def _jac_host_class_name(value):
    # The class's own __name__ (for an except-target that is an exception CLASS),
    # falling back to type(value).__name__ for a non-class value.
    return getattr(value, "__name__", None) or type(value).__name__

def _jac_exc_name_subclass(target_name, exc_name):
    # True iff a builtin exception named exc_name is target_name or a subclass of
    # it -- e.g. FileNotFoundError is-a OSError, ValueError is-a Exception. Both
    # names are resolved against builtins; user/native names not found there fall
    # back to the exact-name compare done by the caller (returns False here).
    try:
        t = getattr(builtins, target_name, None)
        e = getattr(builtins, exc_name, None)
        if (isinstance(t, type) and isinstance(e, type)
                and issubclass(t, BaseException)):
            return issubclass(e, t)
        return False
    except BaseException:
        return False

def _jac_host_format(value, spec):
    try:
        return (True, format(value, spec))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_unbound_method_info(value):
    # (True, owner_type_name, method_name) when value is an unbound builtin
    # method descriptor of a container type mirrored natively (list/dict/set).
    try:
        objclass = getattr(value, "__objclass__", None)
        if objclass is None:
            return (False, "", "")
        name = getattr(value, "__name__", "")
        if objclass in (list, dict, set):
            return (True, objclass.__name__, name)
        return (False, "", "")
    except BaseException:
        return (False, "", "")

def _jac_bound_method_type():
    # CPython: a bound method of a Python function is exactly `method`.
    class _M:
        def m(self):
            return None
    return type(_M().m)

def _jac_list_iterator_type():
    # Native PyIter mirrors list iteration; use the host list_iterator type.
    return type(iter([]))

def _jac_seq_iterator_type():
    # CPython's plain sequence iterator (PySeqIter_Type) has no reachable
    # builtin name; synthesize it from a __getitem__-only class.
    class _S:
        def __getitem__(self, i):
            raise IndexError
    return type(iter(_S()))

def _jac_builtin_function_or_method_type():
    import builtins
    # CPython: type(len) is builtin_function_or_method; grab the type object
    # itself so isinstance/name checks on native callables answer correctly.
    return type(builtins.len)

def _jac_generator_type():
    import types
    return types.GeneratorType

def _jac_coroutine_type():
    import types
    return types.CoroutineType

def _jac_async_generator_type():
    import types
    return types.AsyncGeneratorType

def _jac_module_type():
    import sys
    return type(sys)

def _jac_host_same_object(a, b):
    return a is b

def _jac_host_eq(a, b):
    try:
        return (True, bool(a == b))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_richcompare(kind, a, b):
    import operator
    _CMP = {0: operator.lt, 1: operator.le, 2: operator.eq,
            3: operator.ne, 4: operator.gt, 5: operator.ge}
    try:
        return (True, bool(_CMP[kind](a, b)))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_binop(kind, a, b):
    import operator
    _NB = {
        0: operator.add, 1: operator.and_, 2: operator.floordiv,
        3: operator.lshift, 4: operator.matmul, 5: operator.mul,
        6: operator.mod, 7: operator.or_, 8: operator.pow,
        9: operator.rshift, 10: operator.sub, 11: operator.truediv,
        12: operator.xor,
    }
    fn = _NB.get(kind)
    if fn is None:
        return (False, "TypeError", "unsupported binary op " + str(kind))
    try:
        return (True, fn(a, b))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_host_convert(value, conv):
    try:
        if conv == 2:
            return (True, repr(value))
        if conv == 3:
            return (True, ascii(value))
        return (True, str(value))
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_module_info(absname):
    # Layer 3 module locator: resolve a fully-qualified module name to its source
    # by walking sys.path in order -- no importlib.util.find_spec, which would
    # import parent packages on the host (executing their bodies there) and leak
    # host-side module objects into the very namespace the VM must own.
    # Returns (status, source, is_pkg, origin, detail):
    #   "py"          -> pure-Python module/package; `source` is its text, run
    #                    in-VM proxy-free
    #   "native"      -> built-in / frozen / C extension / namespace package:
    #                    nothing to run in-VM; caller host-proxies it
    #   "missing"     -> ModuleNotFoundError("No module named '<absname>'")
    #   "not-package" -> ModuleNotFoundError(detail) where detail is CPython's
    #                    "No module named '<abs>'; '<parent>' is not a package"
    import os
    import sys
    import _imp
    import importlib.machinery as machinery
    parts = absname.split(".")
    if _imp.is_builtin(parts[0]):
        return ("native", "", False, "", "")
    # Frozen-but-with-source modules (abc, _collections_abc are frozen into the
    # 3.10+ bootstrap): CPython prefers the frozen copy for STARTUP, but our
    # guest must boot the REAL Lib source -- a host-proxied frozen module hands
    # back host class objects (ABCMeta as PyHostProxy), which class_mro then
    # excludes (non-PyClass bases are not MRO nodes), collapsing every
    # metaclass chain built on them: `class P(metaclass=_PM(ABCMeta))` lost its
    # entire ancestry and `import typing` died in _ProtocolMeta.__init__.
    # Unfreeze-by-name so the sys.path walk below finds Lib/abc.py and boots it
    # in-VM. Extend the set only with a fresh conv-pipe diff pass.
    if _imp.is_frozen(parts[0]) and parts[0] != "abc":
        return ("native", "", False, "", "")

    def locate(base_dir, part):
        # One directory scan: regular package > plain module > extension >
        # namespace portion. Returns (kind, payload) or None.
        pkg_dir = os.path.join(base_dir, part)
        init_py = os.path.join(pkg_dir, "__init__.py")
        if os.path.isfile(init_py):
            return ("pkg", pkg_dir)
        mod_py = os.path.join(base_dir, part + ".py")
        if os.path.isfile(mod_py):
            return ("py", mod_py)
        for suf in machinery.EXTENSION_SUFFIXES:
            ext = os.path.join(base_dir, part + suf)
            if os.path.isfile(ext):
                return ("ext", ext)
        if os.path.isdir(pkg_dir):
            return ("ns", pkg_dir)
        return None

    def read_source(path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                return fh.read()
        except OSError:
            return None

    def finish(kind, payload):
        if kind == "pkg":
            src = read_source(os.path.join(payload, "__init__.py"))
            if src is not None:
                return ("py", src, True, os.path.join(payload, "__init__.py"), "")
            return ("native", "", True, payload, "")
        if kind == "py":
            src = read_source(payload)
            if src is not None:
                return ("py", src, False, payload, "")
            return ("native", "", False, payload, "")
        return ("native", "", False, "", "")

    # Top-level scan: first regular hit across sys.path wins; the first
    # namespace portion is remembered in case no regular hit exists anywhere
    # (CPython's namespace-package rule).
    top = None
    ns_portion = None
    for entry in sys.path:
        d = entry or os.getcwd()
        if not os.path.isdir(d):
            continue
        hit = locate(d, parts[0])
        if hit is None:
            continue
        if hit[0] == "ns":
            if ns_portion is None:
                ns_portion = hit[1]
        elif top is None:
            top = hit
    if top is None:
        # Namespace packages have no body to run in-VM; hand them to the host
        # importer, which resolves their full __path__ the same way.
        if ns_portion is not None:
            return ("native", "", True, ns_portion, "")
        return ("missing", "", False, "", "")
    if len(parts) == 1:
        return finish(top[0], top[1])
    # Descend through subpackages. A non-package parent anywhere along the chain
    # yields CPython's "... is not a package" variant.
    loc = top
    depth = 1
    while depth < len(parts):
        if loc[0] != "pkg":
            return (
                "not-package", "", False, "",
                "No module named '" + absname + "'; '"
                    + ".".join(parts[:depth]) + "' is not a package",
            )
        nxt = locate(loc[1], parts[depth])
        if nxt is None:
            return ("missing", "", False, "", "")
        loc = nxt
        depth = depth + 1
    return finish(loc[0], loc[1])

def _jac_sys_modules_lookup(absname):
    # sys.modules-first rule (CPython _find_and_load checks the registry before
    # every path finder): a module body can register a submodule ALIAS at exec
    # time that exists nowhere on disk. CPython 3.14 removed Lib/collections/
    # abc.py; collections/__init__.py does
    #     _sys.modules['collections.abc'] = _collections_abc
    # so `import collections.abc` resolves through the registry, not a file.
    # Returns ("hit", module) / ("absent", "") / ("error", type, message).
    import sys
    try:
        mod = sys.modules.get(absname)
    except BaseException as exc:
        return _jac_host_error(exc)
    if mod is None:
        return ("absent", "")
    return ("hit", mod)

def _jac_star_names(host_val):
    # `from proxied_module import *` name set: __all__ if defined, else every
    # public (non-underscore) attribute -- CPython's import_all_from rule.
    try:
        alln = getattr(host_val, "__all__", None)
        if alln is not None:
            return (True, [str(n) for n in alln])
        return (True, [n for n in dir(host_val) if not n.startswith("_")])
    except BaseException as exc:
        return _jac_host_error(exc)

def _jac_dir_names(value):
    # Every attribute name on a host module (full dir(), not the __all__/
    # public-only view _jac_star_names serves for star-imports). The stdlib
    # delegation registry snapshots the complete surface so underscored API
    # (re._compile, datetime's C internals) stays reachable, matching dir()
    # on a real host module.
    try:
        return (True, [n for n in dir(value)])
    except BaseException as exc:
        return (False, type(exc).__name__, str(exc))
_JAC_HOST_WEAKREF = None

def _jac_host_weakref():
    # Direct host-module route: a plain `import weakref` in this file resolves
    # to jacpython/weakref.jac (modresolver prefers same-dir .jac), which
    # imports ceval and creates a static import cycle.
    global _JAC_HOST_WEAKREF
    if _JAC_HOST_WEAKREF is None:
        import importlib
        _JAC_HOST_WEAKREF = importlib.import_module("weakref")
    return _JAC_HOST_WEAKREF

def _jac_make_weakref(target):
    # Host weakref over the RAW jacpython object. PyUserObj/PyClass/native
    # wrappers are ordinary CPython objects, so the host weakref tracks their
    # exact refcount lifetime: when the last strong reference dies, ref()
    # returns None with no extra bookkeeping. Returns None on TypeError.
    try:
        return _jac_host_weakref().ref(target)
    except TypeError:
        return None

def _jac_weakref_deref(wr):
    return wr()

def _jac_dbg_dead_check_simple(r):
    # Minimal: alive or dead, no walking.
    import sys
    wr = getattr(r, "wr")
    return wr() is None

def _jac_recover_native(raw) -> PyObj | None:
    # If raw is a trampoline we minted, hand back the native function it wraps
    # so a host->native round-trip collapses instead of nesting proxies. Read the
    # marker from the object's OWN __dict__, not via getattr: a bound method
    # delegates attribute access to its __func__, so getattr(bound_method,
    # '__jac_native__') would unwrap it to the UNBOUND native function and lose
    # the receiver -- exactly what breaks `instance.method()`.
    import types as _types
    if isinstance(raw, _types.FunctionType):
        return raw.__dict__.get("__jac_native__")
    d = getattr(raw, "__dict__", None)
    if isinstance(d, dict):
        coro = d.get("__jac_native_coroutine__")
        if coro is not None:
            return coro
    return None
::py::
