# Product-path facade for atexit (native Jac).
# Semantics mirror CPython 3.14 ``Modules/atexitmodule.c``: register stores
# (func, args, kwargs) tuples in LIFO order, unregister removes by callable
# identity, and _run_exitfuncs walks the list calling each entry then clears it.
# Callback exceptions are swallowed (CPython routes them through
# PyErr_FormatUnraisable; the guest VM has no unraisable hook yet).
#
# Interpreter-level state: every ``build_atexit_module()`` call yields a fresh
# PyModule object, but all instances share the same callback list (matching
# CPython's per-interpreter atexit_state). Re-import after
# ``del sys.modules['atexit']`` therefore returns a new module object while
# register/unregister on any instance still hits the shared queue.

import from objects {
    PyObj,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    PyDict,
    PyModule,
    PyNoneType,
    DictEntry,
    py_none,
    py_error,
    is_error,
    tuple_value,
    hashkey_str,
    PyStr,
}
import from ceval { obj_is_callable, py_compare, py_slot_truth }

glob _atexit_callbacks: list[PyObj] = [];

def atexit_state_reset {
    _atexit_callbacks = [];
}

def _atexit_dict_from_kwargs(kwargs: dict[str, PyObj]) -> PyObj {
    if len(kwargs) == 0 {
        return py_none();
    }
    items: dict[str, DictEntry] = {};
    for k in kwargs {
        key_obj = PyStr(t="str", val=k);
        hk = hashkey_str(key_obj.tp_hashkey());
        items[hk] = DictEntry(key=key_obj, value=kwargs[k]);
    }
    return PyDict(t="dict", items=items);
}

def _atexit_kwargs_dict(kwobj: PyObj) -> dict[str, PyObj] {
    out: dict[str, PyObj] = {};
    if isinstance(kwobj, PyNoneType) {
        return out;
    }
    if isinstance(kwobj, PyDict) {
        for hk in (kwobj as PyDict).items {
            ent = (kwobj as PyDict).items[hk];
            out[hk] = ent.value;
        }
    }
    return out;
}

def _atexit_callfuncs {
    copy: list[PyObj] = [];
    for cb in _atexit_callbacks {
        copy.append(cb);
    }
    _atexit_callbacks = [];
    for cb_rec in copy {
        parts = tuple_value(cb_rec);
        if len(parts) < 3 {
            continue;
        }
        func = parts[0];
        call_args = tuple_value(parts[1]);
        call_kwargs = _atexit_kwargs_dict(parts[2]);
        if not obj_is_callable(func) {
            continue;
        }
        res = func.tp_call(call_args, call_kwargs);
        if is_error(res) {
            # Exception ignored in atexit callback (atexitmodule.c).
            continue;
        }
    }
}

def atexit_run_exitfuncs {
    _atexit_callfuncs();
}

obj PyAtexitFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "register" {
            if len(args) == 0 {
                return py_error(
                    "TypeError", "register() takes at least 1 argument (0 given)"
                );
            }
            func = args[0];
            if not obj_is_callable(func) {
                return py_error("TypeError", "the first argument must be callable");
            }
            reg_args: list[PyObj] = [];
            i = 1;
            while i < len(args) {
                reg_args.append(args[i]);
                i += 1;
            }
            kw_store = _atexit_dict_from_kwargs(kwargs);
            callback = PyTuple(
                t="tuple",
                items=[func, PyTuple(t="tuple", items=reg_args), kw_store],
            );
            inserted: list[PyObj] = [callback];
            for old in _atexit_callbacks {
                inserted.append(old);
            }
            _atexit_callbacks = inserted;
            return func;
        }
        if self.name == "unregister" {
            if len(args) != 1 {
                return py_error(
                    "TypeError", "unregister() takes exactly one argument"
                );
            }
            func = args[0];
            kept: list[PyObj] = [];
            for cb_rec in _atexit_callbacks {
                parts = tuple_value(cb_rec);
                if len(parts) < 1 {
                    kept.append(cb_rec);
                    continue;
                }
                cmp = py_compare(2, func, parts[0]);
                if is_error(cmp) {
                    return cmp;
                }
                truth = py_slot_truth(cmp);
                if is_error(truth) {
                    return truth;
                }
                if (truth as PyBool).val {
                    continue;
                }
                kept.append(cb_rec);
            }
            _atexit_callbacks = kept;
            return py_none();
        }
        if self.name == "_clear" {
            _atexit_callbacks = [];
            return py_none();
        }
        if self.name == "_run_exitfuncs" {
            _atexit_callfuncs();
            return py_none();
        }
        if self.name == "_ncallbacks" {
            return PyInt(t="int", val=len(_atexit_callbacks));
        }
        return py_error("SystemError", "unknown atexit function '" + self.name + "'");
    }
}

def build_atexit_module -> PyObj {
    attrs: dict[str, PyObj] = {
        "register": PyAtexitFn(t="atexit_fn", name="register"),
        "unregister": PyAtexitFn(t="atexit_fn", name="unregister"),
        "_clear": PyAtexitFn(t="atexit_fn", name="_clear"),
        "_run_exitfuncs": PyAtexitFn(t="atexit_fn", name="_run_exitfuncs"),
        "_ncallbacks": PyAtexitFn(t="atexit_fn", name="_ncallbacks"),
    };
    return PyModule(t="module", name="atexit", attrs=attrs);
}
