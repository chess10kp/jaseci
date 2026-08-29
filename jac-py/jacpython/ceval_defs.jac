# ceval type definitions (jac-py/PLAN.md §4 acyclic leaf).
# Callable/heap proxy types extracted from ceval.jac; spokes import these
# instead of ceval. Back-edge calls go through ceval_api forwarders.

import from hash_dispatch { hash_element, }
import from abstract_protocol {
    PyObject_GetIter,
    PyIter_Check,
    PyObject_Hash,
    PyObject_HashNotImplemented,
}
import from exceptions_core { exc_name_matches, }
import from ceval_exceptions { class_is_exception, }
import from vm_dispatch { jac_frame_chain_slot_ref, }
import from ceval_api {
    as_error,
    builtin_sorted_min_max,
    descriptor_get,
    frame_clear,
    format_exception_text,
    from_host,
    gen_close,
    gen_send,
    gen_throw,
    host_builtin,
    host_import,
    host_iter,
    localsplus_name,
    normalize_throw_args,
    obj_is_callable,
    py_attr,
    py_aiter,
    py_anext,
    py_build_class,
    py_del_attr,
    py_dir,
    py_hash,
    py_id,
    py_identity,
    py_invoke,
    py_isinstance,
    py_issubclass,
    py_iter,
    py_len,
    py_raise_value,
    py_repr,
    py_set_attr,
    py_type_of,
    send_into,
    stop_iteration,
    to_host_coerce,
    user_instance_dict,
}
import from objects {
    Py_EQ,
    Py_NE,
    DictEntry,
    _unhashable_error,
    PyObj,
    PyInt,
    PyStr,
    PyBool,
    PyNoneType,
    PyCode,
    PyCell,
    PyTuple,
    PyList,
    PyDict,
    PySet,
    PyError,
    PyException,
    PyExceptionType,
    PyHostProxy,
    PyUserObj,
    PyClass,
    PyCallableIter,
    PyIter,
    find_name,
    expect_str,
    py_none,
    py_error,
    is_error,
    hashkey_str,
    dict_key_repr,
    PY_NOT_IMPLEMENTED,
}

# opcode_meta NB_OR / NB_INPLACE_OR (ceval_defs cannot import opcode_meta)
glob _NB_OR: int = 7;
glob _NB_INPLACE_OR: int = 20;

obj PyBoundMethod(PyObj) {
    has function: PyObj,
        receiver: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        call_args: list[PyObj] = [self.receiver];
        call_args.extend(args);
        return self.function.tp_call(call_args, kwargs);
    }

    # A bound method exposes __func__/__self__ and otherwise forwards attribute
    # reads (__name__, __qualname__, __doc__) to the underlying function.
    def tp_getattro(name: str) -> PyObj {
        if name == "__func__" {
            return self.function;
        }
        if name == "__self__" {
            return self.receiver;
        }
        # Bound methods are descriptors too (self-reproducing __get__).
        if name == "__get__" {
            return PyGetDescriptorFn(t="get_descriptor", target=self);
        }
        return py_attr(self.function, name);
    }
}
# typing._GenericAlias(Generic, params) stand-in -- the implicit PEP 695 class
# base produced by CALL_INTRINSIC_1 arg 10 (INTRINSIC_SUBSCRIPT_GENERIC).
# Data-only: attribute answers (__origin__/__args__/__parameters__), the repr,
# and the __mro_entries__ hook live in ceval (py_attr / py_repr) because the
# origin is typing_generic_class() below and resolution re-enters execution.
obj PyGenericAlias(PyObj) {
    has params: PyObj;
}
obj PyBuildClass(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_build_class(args, kwargs);
    }
}
obj PyGetDescriptorFn(PyObj) {
    has target: PyObj;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        instance = py_none();
        owner = py_none();
        if len(args) >= 1 {
            instance = args[0];
        }
        if len(args) >= 2 {
            owner = args[1];
        }
        return descriptor_get(self.target, instance, owner);
    }
}
glob _handled_exc_stack: list[PyObj] = [];

def current_handled_exc() -> PyObj {
    if len(_handled_exc_stack) == 0 {
        return py_none();
    }
    return _handled_exc_stack[len(_handled_exc_stack) - 1];
}

# Identity-counting removal of one occurrence per item: generator suspend must
# deactivate exactly ITS handler entries so unrelated frames stop seeing them
# (CPython exc_info is dynamic; the global stack is a single-threaded mirror).
def _handled_stack_remove_each(items: list[PyObj]) -> None {
    for it in items {
        idx = -1;
        i = 0;
        while i < len(_handled_exc_stack) {
            if py_identity(_handled_exc_stack[i], it) {
                idx = i;
                break;
            }
            i = i + 1;
        }
        if idx >= 0 {
            _handled_exc_stack = _handled_exc_stack[:idx] + _handled_exc_stack[idx + 1:];
        }
    }
}

def _handled_stack_append_each(items: list[PyObj]) -> None {
    for it in items {
        _handled_exc_stack.append(it);
    }
}
# ---------------- generator frame machinery (PLAN.md §5, P5) ----------------
# CPython implements a generator as a suspended frame; jacpython mirrors that.
# PyFrame captures the resumable eval state (stack/fast/ip). YIELD_VALUE
# saves it and hands a PyYield up to run_frame's caller; PyGenerator drives the
# frame forward one yield at a time. PyGenStop is the "frame returned normally"
# (StopIteration) sentinel that distinguishes exhaustion from a real raise.
obj PyFrame(PyObj) {
    has co: PyCode,
        # Merged localsplus: [varnames] [non-arg cellvar cells] [freevar cells].
        # Entries hold values or PyCell objects (see resolve_cell); OP_MAKE_CELL
        # converts more slots dynamically mid-frame.
        fast: list[PyObj],
        assigned: list[bool],
        closure: list[PyCell],
        stack: list[PyObj],
        globals: dict[str, PyObj],
        locals: dict[str, PyObj],
        ip: int = 0,
        # True when suspended inside `yield from` (YIELD_VALUE oparg 1). A throw
        # is then delegated into the sub-iterator via the SEND loop rather than
        # injected at the outer suspend point.
        yf: bool = False,
        # A pending exception to throw into the current yield-from sub-iterator,
        # consumed by the next SEND instead of a normal send.
        pending_throw: any = None,
        # True once the frame's locals/stack have been released (gen.close() or
        # gi_frame.clear()); guards against running __del__ finalizers twice.
        cleared: bool = False,
        # Exception-handler stack captured at a YIELD_VALUE suspension and
        # restored when the generator resumes, so a bare `raise` inside an
        # except block that spans a yield re-raises the right exception
        # (CPython keeps this state in the frame's exc_info across suspends).
        exc_state: list[PyObj] | None = None,
        # PEP 667 "extra locals" -- keys written through f_locals that are not
        # localsplus slots (CPython frame->f_extra_locals). Keyed by hashkey so
        # non-string keys work exactly like CPython's extras dict.
        extra_locals: dict[str, DictEntry] = {};

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "f_locals" {
            return PyFrameLocalsProxy(t="frame_locals_proxy", frame=self) as PyObj;
        }
        if name2 == "f_globals" {
            return PyGlobalsProxy(t="globals", ns=self.globals);
        }
        if name2 == "f_code" {
            return self.co as PyObj;
        }
        if name2 == "f_back" {
            # The live guest chain published by run_frame (innermost last).
            i = len(jac_frame_chain_slot_ref()) - 1;
            while i >= 0 {
                if jac_frame_chain_slot_ref()[i] is self {
                    if i > 0 {
                        return jac_frame_chain_slot_ref()[i - 1] as PyObj;
                    }
                    break;
                }
                i = i - 1;
            }
            return py_none();
        }
        return py_error("AttributeError", name2);
    }
}

obj PyYield(PyObj) {
    has val: PyObj;
}
obj PyNativeBuiltin(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {

        if self.name == "exc_info" {
            # sys.exc_info() over GUEST handled-exception state (host sys cannot
            # see guest frames). Returns (type, value, traceback); empty stack
            # yields CPython's (None, None, None).
            if len(_handled_exc_stack) == 0 {
                none3: list[PyObj] = [py_none(), py_none(), py_none()];
                return PyTuple(t="tuple", items=none3);
            }
            e = _handled_exc_stack[len(_handled_exc_stack) - 1];
            tbv = e.tp_getattro("__traceback__");
            if is_error(tbv) or isinstance(tbv, PyNoneType) {
                tbv = py_none();
            }
            # CANONICAL type identity: CPython guarantees sys.exc_info()[0] is
            # THE exception class object (exc_info()[0] is ValueError). Two
            # shapes carry it: user exceptions keep their defining PyClass in
            # raw; everything else resolves through the memoized builtin
            # registry so repeated calls return the SAME marker. py_type_of
            # would instead mint a fresh host-type proxy per call -- right
            # __name__, wrong identity.
            etype: PyObj;
            if e.raw is not None and isinstance(e.raw, PyUserObj) {
                etype = (e.raw as PyUserObj).cls as PyObj;
            } else {
                etype = host_builtin(e.type_name);
                if is_error(etype) {
                    etype = py_type_of(e);
                }
            }
            vals: list[PyObj] = [etype, e, tbv];
            return PyTuple(t="tuple", items=vals);
        }
        if self.name == "sys_getframe" {
            # sys._getframe(depth=0) over GUEST frames (host sys cannot see
            # them): walk the live chain published by run_frame, innermost
            # last. Errors byte-match CPython's sysmodule.c.
            depth = 0;
            if len(args) > 0 {
                if not isinstance(args[0], PyInt) {
                    return py_error("TypeError", "an integer is required");
                }
                depth = (args[0] as PyInt).val;
                if depth < 0 {
                    return py_error("ValueError", "depth must be non-negative");
                }
            }
            i = len(jac_frame_chain_slot_ref()) - 1 - depth;
            if i < 0 {
                return py_error("ValueError", "call stack is not deep enough");
            }
            return jac_frame_chain_slot_ref()[i] as PyObj;
        }
        if self.name == "sys_currentframe" {
            # sys.currentframe(): None where _getframe would raise -- only
            # possible in guest when no frame is executing at all.
            if len(jac_frame_chain_slot_ref()) == 0 {
                return py_none();
            }
            return jac_frame_chain_slot_ref()[len(jac_frame_chain_slot_ref()) - 1] as PyObj;
        }
        if self.name == "anext" {
            # anext(aiter[, default]): must stay NATIVE -- routed through the
            # host, a guest async generator crosses to its stand-in face and
            # the yielded item is lost (silently-None / not-an-async-
            # iterator). Returns the __anext__ awaitable; the caller's AWAIT
            # drives it. Divergence: with default=, CPython converts the
            # terminal StopIteration into the default -- that conversion needs
            # coroutine wrapping and is documented as absent for now.
            if len(args) < 1 or len(args) > 2 {
                return py_error(
                    "TypeError", "anext expected at least 1 argument, got " + str(len(args))
                );
            }
            result = py_anext(args[0]);
            if is_error(result) {
                if len(args) == 2 and exc_name_matches(
                    (result as PyError).exception.type_name, "StopAsyncIteration"
                ) {
                    return args[1];
                }
                return result;
            }
            return result;
        }
        if self.name == "aiter" {
            if len(args) != 1 {
                return py_error("TypeError", "aiter expected exactly 1 argument");
            }
            return py_aiter(args[0]);
        }
        if self.name == "exception" {
            # sys.exception() over GUEST handled-exception state: the most
            # recently caught exception, or None with no active handler. Must
            # agree with the exc_info branch above (same _handled_exc_stack).
            if len(_handled_exc_stack) == 0 {
                return py_none();
            }
            return _handled_exc_stack[len(_handled_exc_stack) - 1];
        }
        if self.name == "intern" {
            # sys.intern() must return its argument ITSELF (CPython identity
            # contract). The host bridge would round-trip a guest PyStr into a
            # fresh host string, breaking `intern(s) is s`; keep it in-VM.
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "intern expected 1 argument, got " + str(len(args))
                );
            }
            if not isinstance(args[0], PyStr) {
                return py_error(
                    "TypeError", "intern() argument must be str, not " + args[0].tp_type_name()
                );
            }
            return args[0];
        }
        if self.name == "tb_format_exc" {
            e = current_handled_exc();
            if isinstance(e, PyNoneType) {
                return PyStr(t="str", val="NoneType: None\n");
            }
            return format_exception_text(e);
        }
        if self.name == "tb_print_exc" or self.name == "tb_print_exc_legacy" {
            # print_exc()/print_exception(): full-chain text to stderr or a
            # guest file-like. print_exc with no positional args reads the
            # CURRENTLY HANDLED exception; legacy form takes (etype, value, tb)
            # and renders value.
            target = py_none();
            for wkey in kwargs {
                if wkey == "file" {
                    target = kwargs[wkey];
                } else {
                    return py_error("TypeError", "unsupported keyword argument: " + wkey);
                }
            }
            no_pos = len(args) == 0;
            if self.name == "tb_print_exc" and len(args) > 0 and isinstance(args[0], PyNoneType) {
                no_pos = True;
            }
            if no_pos {
                e = current_handled_exc();
                if isinstance(e, PyNoneType) {
                    return py_error("RuntimeError", "No active exception to re-raise");
                }
                text = format_exception_text(e);
            }
            elif self.name == "tb_print_exc_legacy" and len(args) >= 2 {
                text = format_exception_text(args[1]);
            }
            else {
                text = format_exception_text(args[0]);
            }
            w = py_attr(target, "write");
            if is_error(w) {
                return w;
            }
            return py_invoke(w, [text], {});
        }
        if self.name == "sorted" or self.name == "max" or self.name == "min" {
            return builtin_sorted_min_max(self.name, args, kwargs);
        }
        if self.name == "super" {
            # Zero-arg super() at a GENERIC call site: the compiler lowers every
            # super().attr / super().m() inside a method with a __class__ cell
            # to LOAD_SUPER_ATTR, so a plain super() call here is exactly
            # CPython's frame-without-cell case (class body, module level,
            # function without the closure) -- same RuntimeError.
            if len(args) == 0 and len(kwargs) == 0 {
                return py_error("RuntimeError", "super(): no arguments");
            }
        }
        if self.name == "id" {
            if len(kwargs) > 0 {
                return py_error("TypeError", "id() takes no keyword arguments");
            }
            if len(args) != 1 {
                return py_error(
                    "TypeError", "id() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return PyInt(t="int", val=py_id(args[0]));
        }
        if self.name == "len" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "len() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_len(args[0]);
        }
        if self.name == "hash" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "hash() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_hash(args[0]);
        }
        if self.name == "repr" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "repr() takes exactly one argument (" + str(len(args)) + " given)"
                );
            }
            return py_repr(args[0]);
        }
        if self.name == "isinstance" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "isinstance expected 2 arguments, got " + str(len(args)),
                );
            }
            return PyBool(t="bool", val=py_isinstance(args[0], args[1]));
        }
        if self.name == "issubclass" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "issubclass expected 2 arguments, got " + str(len(args)),
                );
            }
            return PyBool(t="bool", val=py_issubclass(args[0], args[1]));
        }
        if self.name == "callable" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "callable() takes exactly one argument (" + str(len(args)) + " given)",
                );
            }
            return PyBool(t="bool", val=obj_is_callable(args[0]));
        }
        if self.name == "getattr" {
            # getattr(obj, name[, default]): native attribute access, honoring a
            # 3rd-arg default on AttributeError (CPython only swallows that one).
            if len(args) < 2 {
                return py_error(
                    "TypeError",
                    "getattr expected at least 2 arguments, got " + str(len(args)),
                );
            }
            attr = py_attr(args[0], expect_str(args[1]));
            if is_error(attr)
                and len(args) >= 3
                and (attr as PyError).exception.type_name == "AttributeError" {
                return args[2];
            }
            return attr;
        }
        if self.name == "hasattr" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "hasattr expected 2 arguments, got " + str(len(args)),
                );
            }
            probe = py_attr(args[0], expect_str(args[1]));
            return PyBool(t="bool", val=not is_error(probe));
        }
        if self.name == "setattr" {
            if len(args) != 3 {
                return py_error("TypeError", "setattr expected 3 arguments, got " + str(len(args)));
            }
            return py_set_attr(args[0], expect_str(args[1]), args[2]);
        }
        if self.name == "delattr" {
            if len(args) < 2 {
                return py_error("TypeError", "delattr expected 2 arguments");
            }
            return py_del_attr(args[0], expect_str(args[1]));
        }
        if self.name == "dir" {
            # dir(obj): CPython attribute enumeration over the NATIVE object
            # (see py_dir). The no-arg form is intercepted at the ceval CALL
            # site (it reads that frame's locals); reaching tp_call with zero
            # args means an indirect host-side callback, where CPython would
            # see the trampoline frame -- an empty local scope answers []
            # instead of leaking foreign frame names.
            if len(kwargs) > 0 {
                return py_error("TypeError", "dir() takes no keyword arguments");
            }
            if len(args) == 0 {
                return PyList(t="list", items=[]);
            }
            if len(args) > 1 {
                return py_error(
                    "TypeError", "dir expected at most 1 argument, got " + str(len(args))
                );
            }
            return py_dir(args[0]);
        }
        if self.name == "vars" {
            if len(kwargs) > 0 {
                return py_error("TypeError", "vars() takes no keyword arguments");
            }
            if len(args) == 0 {
                # No-arg vars() is locals(); like dir(), only the ceval CALL
                # site sees that frame -- an indirect call answers an empty
                # dict instead of leaking a foreign frame.
                return PyDict(t="dict", items={});
            }
            if len(args) > 1 {
                return py_error(
                    "TypeError", "vars expected at most 1 argument, got " + str(len(args))
                );
            }
            # A user instance answers with its LIVE __dict__ (identity-stable
            # view); routing through the host crossed as a stand-in and lost
            # every guest attribute behind the _jac_guest_ marker.
            o = args[0];
            if isinstance(o, PyUserObj) {
                return user_instance_dict(o as PyUserObj);
            }
            d = py_attr(o, "__dict__");
            if is_error(d)
                and (d as PyError).exception.type_name == "AttributeError" {
                return py_error(
                    "TypeError", "vars() argument must have __dict__ attribute"
                );
            }
            return d;
        }
        if self.name == "iter" {
            if len(args) == 0 {
                return py_error("TypeError", "iter expected at least 1 argument");
            }
            if len(args) >= 2 {
                # Two-arg form (CPython calliterobject). The callable check is
                # EAGER -- builtin_iter raises "iter(v, w): v must be callable"
                # at construction time, not on first next(). Iteration then
                # calls it with no args until the result equals the sentinel.
                if not obj_is_callable(args[0]) {
                    return py_error("TypeError", "iter(v, w): v must be callable");
                }
                return PyCallableIter(t="calliter", fn=args[0], sentinel=args[1]);
            }
            result = py_iter(args[0]);
            if is_error(result) and isinstance(args[0], PyHostProxy) {
                # Dict views and other host-only iterables still materialize once.
                return host_iter(args[0] as PyHostProxy);
            }
            return result;
        }
        # next(iterator[, default])
        if len(args) == 0 {
            return py_error("TypeError", "next expected at least 1 argument, got 0");
        }
        if len(args) > 2 {
            return py_error("TypeError", "next expected at most 2 arguments, got " + str(len(args)));
        }
        if args[0].t == "async_generator" {
            # PyAsyncGenObject has no tp_iternext; CPython rejects it in
            # builtin_next via PyIter_Check with this dedicated message.
            return py_error("TypeError", "'async_generator' object is not an iterator");
        }
        step = send_into(args[0], py_none());
        if step.t == "genstop" {
            if len(args) > 1 {
                return args[1];
            }
            # Forward the generator's return value as StopIteration.value
            # (CPython: next() exhaustion surfaces `return x` as .value).
            return stop_iteration((step as PyGenStop).val);
        }
        return step;
    }
}
# A live view of a running frame's globals (`dict[str, PyObj]`, held by
# reference). globals() returns one so module init idioms that MUTATE the module
# namespace -- globals().update({...}), globals()[name] = value -- bind real
# globals a later LOAD_GLOBAL/LOAD_NAME resolves. A snapshot dict would silently
# drop those writes (re._constants._makecodes builds its OPCODES this way).
obj PyGlobalsProxy(PyObj) {
    has ns: dict[str, PyObj];

    def mp_subscript(index: PyObj) -> PyObj {
        key = expect_str(index);
        if key in self.ns {
            return self.ns[key];
        }
        return py_error("KeyError", key);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        self.ns[expect_str(index)] = value;
        return py_none();
    }

    # Iterating globals() yields its keys (module code does
    # `[n for n in globals() if ...]` to compute __all__).
    def tp_iter -> PyObj {
        keys: list[PyObj] = [];
        for k in self.ns {
            keys.append(PyStr(t="str", val=k));
        }
        return PyIter(t="iter", items=keys, index=0);
    }

    def tp_getattro(name: str) -> PyObj {
        if name == "update" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="update");
        }
        if name == "get" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="get");
        }
        if name == "keys" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="keys");
        }
        if name == "values" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="values");
        }
        if name == "items" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="items");
        }
        if name == "setdefault" {
            return PyNsMethod(t="ns_method", ns=self.ns, op="setdefault");
        }
        return py_error("AttributeError", name);
    }
}
# The bound dict-method objects a PyGlobalsProxy hands out. Kept minimal to the
# surface module-init code exercises; each mutates/reads the shared ns directly.
obj PyNsMethod(PyObj) {
    has ns: dict[str, PyObj],
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.op == "update" {
            if len(args) > 0 {
                src = args[0];
                pairs: PyObj = py_none();
                if isinstance(src, PyDict) {
                    pairs = src;
                } else {
                    hsrc_r = to_host_coerce(src);
                    hsrc = hsrc_r[1];
                    if not ((hsrc_r[0] as bool)) {
                        return hsrc_r[1] as PyObj;
                    }
                    pairs = from_host(hsrc);
                }
                if isinstance(pairs, PyDict) {
                    smap = (pairs as PyDict).dict_str_map();
                    for k in smap {
                        self.ns[k] = smap[k];
                    }
                }
            }
            for kw in kwargs {
                self.ns[kw] = kwargs[kw];
            }
            return py_none();
        }
        if self.op == "get" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_none();
        }
        if self.op == "setdefault" {
            if len(args) > 0 {
                key = expect_str(args[0]);
                if key in self.ns {
                    return self.ns[key];
                }
                fallback = py_none();
                if len(args) > 1 {
                    fallback = args[1];
                }
                self.ns[key] = fallback;
                return fallback;
            }
            return py_none();
        }
        if self.op == "keys" {
            out: list[PyObj] = [];
            for k in self.ns {
                out.append(PyStr(t="str", val=k));
            }
            return PyList(t="list", items=out);
        }
        if self.op == "values" {
            vout: list[PyObj] = [];
            for k in self.ns {
                vout.append(self.ns[k]);
            }
            return PyList(t="list", items=vout);
        }
        if self.op == "items" {
            iout: list[PyObj] = [];
            for k in self.ns {
                pair: list[PyObj] = [PyStr(t="str", val=k), self.ns[k]];
                iout.append(PyTuple(t="tuple", items=pair));
            }
            return PyList(t="list", items=iout);
        }
        return py_error("TypeError", "unsupported namespace op");
    }
}
def framelocals_nslots(co: PyCode) -> int {
    n = len(co.varnames);
    ci = 0;
    while ci < len(co.cellvars) {
        if find_name(co.varnames, co.cellvars[ci]) < 0 {
            n = n + 1;
        }
        ci = ci + 1;
    }
    return n + len(co.freevars);
}

def framelocals_keyerror(key: PyObj) -> PyObj {
    r = py_repr(key);
    if is_error(r) {
        return r;
    }
    # CPython formats KeyError with repr(key): for 'zz' the message carries
    # doubled quotes -- byte-exact with host FrameLocalsProxy.__getitem__.
    return py_error("KeyError", "local variable '" + (r as PyStr).val + "' is not defined");
}

obj PyFrameLocalsProxy(PyObj) {
    has frame: PyFrame;

    def slot_index(key: str) -> int {
        co = self.frame.co;
        i = 0;
        while i < framelocals_nslots(co) {
            if localsplus_name(co, i) == key {
                return i;
            }
            i = i + 1;
        }
        return -1;
    }

    def slot_bound(i: int) -> bool {
        slot = self.frame.fast[i];
        if isinstance(slot, PyCell) {
            return (slot as PyCell).filled;
        }
        if i < len(self.frame.assigned) {
            return self.frame.assigned[i];
        }
        return False;
    }

    def slot_get(i: int) -> PyObj {
        slot = self.frame.fast[i];
        if isinstance(slot, PyCell) {
            return (slot as PyCell).val;
        }
        return slot;
    }

    # (bound?, value) for a string key already known to sit in the slots.
    def ns_has(key: str) -> bool {
        return key in self.frame.locals;
    }

    # All visible pairs in CPython order: bound slots, then extras, then the
    # namespace dict (empty for function frames).
    def entry_pairs() -> list[PyObj] {
        out: list[PyObj] = [];
        co = self.frame.co;
        i = 0;
        while i < framelocals_nslots(co) {
            if self.slot_bound(i) {
                pair: list[PyObj] = [
                    PyStr(t="str", val=localsplus_name(co, i)),
                    self.slot_get(i),
                ];
                out.append(PyTuple(t="tuple", items=pair));
            }
            i = i + 1;
        }
        for hk in self.frame.extra_locals {
            e = self.frame.extra_locals[hk];
            pair2: list[PyObj] = [e.key, e.value];
            out.append(PyTuple(t="tuple", items=pair2));
        }
        for k in self.frame.locals {
            pair3: list[PyObj] = [PyStr(t="str", val=k), self.frame.locals[k]];
            out.append(PyTuple(t="tuple", items=pair3));
        }
        return out;
    }

    def keys_list() -> list[PyObj] {
        out: list[PyObj] = [];
        for p in self.entry_pairs() {
            out.append(((p as PyTuple).items[0]));
        }
        return out;
    }

    def as_dict() -> PyDict {
        d = PyDict(t="dict", items={});
        for p in self.entry_pairs() {
            _ = d.dict_set((p as PyTuple).items[0], (p as PyTuple).items[1]);
        }
        return d;
    }

    # Core lookup behind mp_subscript/get/contains: found? value.
    def lookup(index: PyObj) -> tuple[bool, PyObj] {
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return (False, _unhashable_error("a dict key", index));
        }
        hk = hashkey_str(hkr);
        if isinstance(index, PyStr) {
            k = (index as PyStr).val;
            i = self.slot_index(k);
            if i >= 0 {
                if self.slot_bound(i) {
                    return (True, self.slot_get(i));
                }
                # An unbound slot falls through like CPython (getval NULL).
                return (False, py_none());
            }
            if self.ns_has(k) {
                return (True, self.frame.locals[k]);
            }
        }
        if hk in self.frame.extra_locals {
            return (True, self.frame.extra_locals[hk].value);
        }
        return (False, py_none());
    }

    def contains_key(index: PyObj) -> PyObj {
        (found, val) = self.lookup(index);
        if is_error(val) {
            return val;
        }
        return PyBool(t="bool", val=found);
    }

    def mp_subscript(index: PyObj) -> PyObj {
        (found, val) = self.lookup(index);
        if is_error(val) {
            return val;
        }
        if found {
            return val;
        }
        return framelocals_keyerror(index);
    }

    def mp_ass_subscript(index: PyObj, value: PyObj) -> PyObj {
        if isinstance(index, PyStr) {
            k = (index as PyStr).val;
            i = self.slot_index(k);
            if i >= 0 {
                slot = self.frame.fast[i];
                if isinstance(slot, PyCell) {
                    c = slot as PyCell;
                    c.val = value;
                    c.filled = True;
                } else {
                    self.frame.fast[i] = value;
                    while len(self.frame.assigned) <= i {
                        self.frame.assigned.append(False);
                    }
                    self.frame.assigned[i] = True;
                }
                return py_none();
            }
            if self.ns_has(k) {
                self.frame.locals[k] = value;
                return py_none();
            }
        }
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        self.frame.extra_locals[hashkey_str(hkr)] = DictEntry(key=index, value=value);
        return py_none();
    }

    def mp_del_subscript(index: PyObj) -> PyObj {
        if isinstance(index, PyStr) {
            if self.slot_index((index as PyStr).val) >= 0 {
                return py_error(
                    "ValueError",
                    "cannot remove local variables from FrameLocalsProxy",
                );
            }
            k = (index as PyStr).val;
            if self.ns_has(k) {
                del self.frame.locals[k];
                return py_none();
            }
        }
        hkr = index.tp_hashkey();
        if is_error(hkr) {
            return _unhashable_error("a dict key", index);
        }
        hk = hashkey_str(hkr);
        if hk in self.frame.extra_locals {
            del self.frame.extra_locals[hk];
            return py_none();
        }
        return py_error("KeyError", dict_key_repr(index));
    }

    # Pairs of a merge source (dict | proxy); error otherwise.
    def merge_pairs(other: PyObj) -> PyObj {
        if isinstance(other, PyFrameLocalsProxy) {
            return PyList(t="list", items=(other as PyFrameLocalsProxy).entry_pairs());
        }
        if isinstance(other, PyDict) {
            src = other as PyDict;
            pairs: list[PyObj] = [];
            for hk in src.items {
                pair: list[PyObj] = [src.items[hk].key, src.items[hk].value];
                pairs.append(PyTuple(t="tuple", items=pair));
            }
            return PyList(t="list", items=pairs);
        }
        return py_error(
            "TypeError",
            "'" + other.t + "' object cannot be merged into FrameLocalsProxy",
        );
    }

    def nb_binop(kind: int, other: PyObj) -> PyObj {
        if kind != _NB_OR and kind != _NB_INPLACE_OR {
            return PY_NOT_IMPLEMENTED;
        }
        pairs_r = self.merge_pairs(other);
        if is_error(pairs_r) {
            if kind == _NB_INPLACE_OR {
                return pairs_r;
            }
            return PY_NOT_IMPLEMENTED;
        }
        if kind == _NB_INPLACE_OR {
            for p in (pairs_r as PyList).items {
                err = self.mp_ass_subscript((p as PyTuple).items[0], (p as PyTuple).items[1]);
                if is_error(err) {
                    return err;
                }
            }
            return self as PyObj;
        }
        result = self.as_dict();
        for p in (pairs_r as PyList).items {
            _ = result.dict_set((p as PyTuple).items[0], (p as PyTuple).items[1]);
        }
        return result;
    }

    def tp_richcompare(kind: int, other: PyObj) -> PyObj {
        if kind != Py_EQ and kind != Py_NE {
            return PY_NOT_IMPLEMENTED;
        }
        if isinstance(other, PyFrameLocalsProxy) {
            eq = self.frame is (other as PyFrameLocalsProxy).frame;
            return PyBool(t="bool", val=eq if kind == Py_EQ else not eq);
        }
        if isinstance(other, PyDict) {
            return dict_richcompare(kind, self.as_dict(), other as PyDict, py_compare);
        }
        return PY_NOT_IMPLEMENTED;
    }

    def tp_iter -> PyObj {
        return PyIter(t="iter", items=self.keys_list(), index=0);
    }

    def tp_getattro(name2: str) -> PyObj {
        if name2 == "keys" or name2 == "values" or name2 == "items"
            or name2 == "get" or name2 == "setdefault" or name2 == "update"
            or name2 == "copy" or name2 == "pop" or name2 == "__getitem__"
            or name2 == "__setitem__" or name2 == "__len__"
            or name2 == "__contains__" {
            return PyFrameLocalsMethod(t="framelocals_method", proxy=self, op=name2);
        }
        return py_error("AttributeError", name2);
    }
}

# Bound method surface of PyFrameLocalsProxy (dict-shaped mapping API; .clear()
# is deliberately absent so it raises AttributeError like CPython's).
def framelocals_len(p: PyFrameLocalsProxy) -> int {
    return len(p.entry_pairs());
}

obj PyFrameLocalsMethod(PyObj) {
    has proxy: PyFrameLocalsProxy,
        op: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        p = self.proxy;
        if self.op == "keys" {
            return PyList(t="list", items=p.keys_list());
        }
        if self.op == "values" {
            out: list[PyObj] = [];
            for pr in p.entry_pairs() {
                out.append((pr as PyTuple).items[1]);
            }
            return PyList(t="list", items=out);
        }
        if self.op == "items" {
            return PyList(t="list", items=p.entry_pairs());
        }
        if self.op == "copy" {
            return p.as_dict();
        }
        if self.op == "__len__" {
            return PyInt(t="int", val=len(p.entry_pairs()));
        }
        if self.op == "__contains__" {
            if len(args) < 1 {
                return py_error("TypeError", "__contains__ expected 1 argument");
            }
            return p.contains_key(args[0]);
        }
        if self.op == "__getitem__" {
            if len(args) < 1 {
                return py_error("TypeError", "__getitem__ expected 1 argument");
            }
            return p.mp_subscript(args[0]);
        }
        if self.op == "__setitem__" {
            if len(args) < 2 {
                return py_error("TypeError", "__setitem__ expected 2 arguments");
            }
            return p.mp_ass_subscript(args[0], args[1]);
        }
        if self.op == "get" {
            if len(args) < 1 {
                return py_error("TypeError", "get expected at least 1 argument");
            }
            (found, val) = p.lookup(args[0]);
            if is_error(val) {
                return val;
            }
            if found {
                return val;
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_none();
        }
        if self.op == "setdefault" {
            if len(args) < 1 {
                return py_error("TypeError", "setdefault expected at least 1 argument");
            }
            (found2, val2) = p.lookup(args[0]);
            if is_error(val2) {
                return val2;
            }
            if found2 {
                return val2;
            }
            fallback = py_none();
            if len(args) > 1 {
                fallback = args[1];
            }
            err = p.mp_ass_subscript(args[0], fallback);
            if is_error(err) {
                return err;
            }
            return fallback;
        }
        if self.op == "update" {
            if len(args) < 1 {
                return py_error("TypeError", "update expected at least 1 argument");
            }
            pairs_r = p.merge_pairs(args[0]);
            if is_error(pairs_r) {
                return pairs_r;
            }
            for pr in (pairs_r as PyList).items {
                err2 = p.mp_ass_subscript((pr as PyTuple).items[0], (pr as PyTuple).items[1]);
                if is_error(err2) {
                    return err2;
                }
            }
            return py_none();
        }
        if self.op == "pop" {
            if len(args) < 1 {
                return py_error("TypeError", "pop expected at least 1 argument");
            }
            index = args[0];
            if isinstance(index, PyStr) and p.slot_index((index as PyStr).val) >= 0 {
                return py_error(
                    "ValueError",
                    "cannot remove local variables from FrameLocalsProxy",
                );
            }
            (found3, val3) = p.lookup(index);
            if is_error(val3) {
                return val3;
            }
            if found3 {
                del_err = p.mp_del_subscript(index);
                if is_error(del_err) {
                    return del_err;
                }
                return val3;
            }
            if len(args) > 1 {
                return args[1];
            }
            return py_error("KeyError", dict_key_repr(index));
        }
        return py_error("TypeError", "unsupported FrameLocalsProxy op");
    }
}
# A frame that ran to RETURN_VALUE. `val` is the generator's return value, which
# `yield from` yields as the sub-expression result and .send()/next() surface as
# StopIteration(val).
obj PyGenStop(PyObj) {
    has val: PyObj;
}

# INTRINSIC_ASYNC_GEN_WRAP's payload (generated_cases.c.h): every value an
# async generator yields is wrapped so the anext/asend driver can tell a
# yield from a return even though both cross the same resume machinery.
obj PyAsyncGenWrappedValue(PyObj) {
    has val: PyObj;
}

# The one-shot awaitable `ag.__anext__()` / `ag.asend(v)` returns. The SEND
# loop drives it through agen_asend_step like a native coroutine: a yield
# surfaces the UNWRAPPED value, exhaustion raises StopAsyncIteration.
obj PyAsyncGenASend(PyObj) {
    has gen: PyGenerator,
        value: PyObj,
        started: bool = False;
}

# The one-shot awaitable `ag.athrow(exc)` / `ag.aclose()` returns: on first
# drive it throws `err` into the generator at its suspend point. aclose=True
# runs the GeneratorExit close protocol (silent on clean exit, RuntimeError
# when the generator yields again).
obj PyAsyncGenAThrow(PyObj) {
    has gen: PyGenerator,
        err: PyObj,
        aclose: bool = False,
        started: bool = False;
}

# A bound async-generator driver (asend/athrow/aclose/__anext__/__aiter__).
# Each call returns a FRESH awaitable object (genobject.c's
# async_gen_asend/athrow_new); awaiting it drives the underlying frame.
obj PyAsyncGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.kind == "anext" or self.kind == "__anext__" {
            return PyAsyncGenASend(t="agen_asend", gen=self.gen, value=py_none());
        }
        if self.kind == "asend" {
            if len(args) < 1 {
                return py_error("TypeError", "asend expected at least 1 argument");
            }
            return PyAsyncGenASend(t="agen_asend", gen=self.gen, value=args[0]);
        }
        if self.kind == "aclose" {
            return PyAsyncGenAThrow(
                t="agen_athrow", gen=self.gen, err=py_none(), aclose=True
            );
        }
        if self.kind == "__aiter__" {
            # PyAsyncGenObject.__aiter__ returns self, so `async for`
            # iterates the generator itself.
            return self.gen;
        }
        # athrow: an exception instance or type, coerced now so a bad operand
        # surfaces at call time. Multi-arg (type, value[, tb]) forms stay in
        # parity with the sync gen_throw surface.
        thrown = py_none();
        if len(args) > 0 {
            thrown = args[0];
        }
        err = as_error(thrown);
        if err.t != "error" {
            return err;
        }
        return PyAsyncGenAThrow(t="agen_athrow", gen=self.gen, err=err);
    }
}

obj PyGenerator(PyObj) {
    has frame: PyFrame,
        started: bool = False,
        finished: bool = False,
        running: bool = False,
        # __name__ / __qualname__ overrides (gen_set_name/gen_set_qualname write
        # the generator object, not the code). Empty string = fall back to the
        # code object's name, matching CPython's pre-assignment read path.
        gen_name: str = "",
        gen_qualname: str = "";

    def tp_iter -> PyObj {
        # An async generator is driven exclusively through __anext__/asend;
        # CPython gives it no tp_iter at all.
        if self.t == "async_generator" {
            return py_error("TypeError", "'async_generator' object is not iterable");
        }
        return self;
    }

    # gen.send / gen.throw / gen.close / gen.__next__ resolve to native bound
    # driver methods; every other attribute is a real AttributeError. An async
    # generator (CO_ASYNC_GENERATOR) presents the ag_* surface instead: its
    # drivers return awaitables, and the sync driver names are absent exactly
    # as CPython's PyAsyncGenObject lacks send/throw/close/__next__.
    def tp_getattro(name: str) -> PyObj {
        if self.t == "async_generator" {
            if name == "asend" or name == "athrow" or name == "aclose"
                or name == "__anext__" or name == "__aiter__" {
                return PyAsyncGenMethod(t="agen_method", gen=self, kind=name);
            }
            if name == "ag_frame" {
                return PyGenFrame(t="genframe", gen=self);
            }
            if name == "ag_running" {
                # True only while the frame is actively executing, like gi_running.
                return PyBool(t="bool", val=self.running);
            }
            return py_error(
                "AttributeError",
                "'async_generator' object has no attribute '" + name + "'",
            );
        }
        if name == "send" or name == "throw" or name == "close" or name == "__next__" {
            return PyGenMethod(t="gen_method", gen=self, kind=name);
        }
        if name == "gi_frame" or name == "ag_frame" {
            return PyGenFrame(t="genframe", gen=self);
        }
        if name == "gi_running" or name == "ag_running" {
            # True only while the generator's frame is actively executing;
            # observable from re-entrant access (the generator inspecting
            # itself through a callback), False while suspended/finished.
            return PyBool(t="bool", val=self.running);
        }
        if name == "gi_yieldfrom" {
            # The sub-iterator a `yield from` is currently delegating to, else
            # None (genobject.c gi_yieldfrom getter). At a YIELD_VALUE(oparg 1)
            # suspension the sent slot has been consumed by the yield, so the
            # delegating receiver is the stack top.
            if self.frame.yf and len(self.frame.stack) >= 1 {
                return self.frame.stack[len(self.frame.stack) - 1];
            }
            return py_none();
        }
        if name == "__name__" {
            gname = self.gen_name;
            if gname == "" {
                gname = self.frame.co.name;
            }
            return PyStr(t="str", val=gname);
        }
        if name == "__qualname__" {
            gqn = self.gen_qualname;
            if gqn == "" {
                gqn = self.frame.co.qualname;
            }
            return PyStr(t="str", val=gqn);
        }
        return py_error("AttributeError", name);
    }

    # Only __name__/__qualname__ are writable on a generator object; everything
    # else keeps raising AttributeError (CPython has no other settable members).
    def tp_setattro(name: str, value: PyObj) -> PyObj {
        if name != "__name__" and name != "__qualname__" {
            return py_error("AttributeError", name);
        }
        if not isinstance(value, PyStr) {
            label = "__qualname__";
            if name == "__name__" {
                label = "__name__";
            }
            return py_error("TypeError", label + " must be set to a string object");
        }
        if self.running {
            return py_error("ValueError", "generator already executing");
        }
        text = (value as PyStr).val;
        if name == "__name__" {
            self.gen_name = text;
        } else {
            self.gen_qualname = text;
        }
        return py_none();
    }
}

# A bound generator driver (gen.send/throw/close/__next__). Calling it drives the
# suspended frame and raises StopIteration on exhaustion, matching CPython's
# generator method surface (unlike FOR_ITER, which swallows the StopIteration).
obj PyGenMethod(PyObj) {
    has gen: PyGenerator,
        kind: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Method-name prefix in arity errors mirrors CPython's METH_DEF_NAME
        # bindings: "generator.send()", "coroutine.close()", ...
        label = self.gen.t;
        if len(kwargs) > 0 {
            return py_error("TypeError", label + "." + self.kind + "() takes no keyword arguments");
        }
        if self.kind == "throw" {
            if len(args) < 1 {
                return py_error("TypeError", "throw expected at least 1 argument, got 0");
            }
            if len(args) > 3 {
                return py_error(
                    "TypeError",
                    "throw expected at most 3 arguments, got " + str(len(args))
                );
            }
            thrown = normalize_throw_args(args);
            result = gen_throw(self.gen, thrown);
            # A generator that catches the injected exception and returns
            # normally exhausts like any other run: surface its return value as
            # StopIteration(return_value), not a bare sentinel (gen_send_ex).
            if result.t == "genstop" {
                return stop_iteration((result as PyGenStop).val);
            }
            return result;
        }
        if self.kind == "close" {
            if len(args) > 0 {
                return py_error(
                    "TypeError",
                    label + ".close() takes no arguments (" + str(len(args)) + " given)"
                );
            }
            return gen_close(self.gen);
        }
        if self.kind == "send" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    label + ".send() takes exactly one argument ("
                        + str(len(args)) + " given)"
                );
            }
            return gen_send(self.gen, args[0]);
        }
        # __next__: CPython's slot wrapper takes no arguments.
        if len(args) > 0 {
            return py_error(
                "TypeError",
                label + ".__next__() takes no arguments (" + str(len(args)) + " given)"
            );
        }
        return gen_send(self.gen, py_none());
    }
}
# A generator's gi_frame surface: only .clear() is modeled (the frame-teardown
# entry point CPython exposes), which releases the suspended frame's locals and
# finalizes any user object dropped -- then marks the generator exhausted.
obj PyGenFrame(PyObj) {
    has gen: PyGenerator;

    def tp_getattro(name: str) -> PyObj {
        if name == "clear" {
            return PyGenFrameClear(t="genframe_clear", gen=self.gen);
        }
        return py_error("AttributeError", name);
    }
}

obj PyGenFrameClear(PyObj) {
    has gen: PyGenerator;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        frame_clear(self.gen.frame);
        self.gen.finished = True;
        return py_none();
    }
}
