# Product-path facade for the atexit stdlib surface (native Jac).
# Semantics mirror CPython 3.14 ``Modules/atexitmodule.c``:
# callbacks live in a LIFO list of (func, args, kwargs) tuples inserted at
# index 0 on register(); ``register`` requires at least one argument whose
# first argument is callable and returns the function (decorator usage);
# ``unregister`` removes every callback equal to the argument (identity-shortcut
# richcompare, scanned last-registered first like
# ``atexit_unregister_locked``); ``_run_exitfuncs`` iterates a snapshot copy,
# invokes each callback swallowing exceptions (CPython's PyErr_FormatUnraisable
# path never propagates into the caller) and then clears the registry;
# ``_ncallbacks`` reports the live count.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyTuple,
    PyDict,
    py_none,
    py_error,
    is_error,
}
import from ceval {
    obj_is_callable,
    py_compare,
    py_invoke,
}

# Registry of pending callbacks: one (func, args-tuple, kwargs-dict|None)
# triple per register() call, newest first (LIFO exit order).
glob _atexit_callbacks: list = [];

def _p2_atexit_state_reset {
    # Fresh interpreter state for snippet isolation (mirrors _PyAtExit_Init's
    # empty-callbacks invariant).
    _atexit_callbacks = [];
}

def _p2_atexit_cleanup {
    # CPython atexit_cleanup(): drop all callbacks without calling them.
    _atexit_callbacks = [];
}

def _p2_atexit_callfuncs {
    # CPython atexit_callfuncs(): snapshot first (thread-safety copy in
    # CPython; here it also pins the iteration against reentrant mutation),
    # invoke every callback, swallow per-callback errors exactly like the
    # PyErr_FormatUnraisable arm, then clear the registry.
    snapshot: list[PyObj] = [];
    for at_entry in _atexit_callbacks {
        snapshot.append(at_entry);
    }
    for at_entry in snapshot {
        parts = (at_entry as PyTuple).items;
        func = parts[0];
        call_args = (parts[1] as PyTuple).items;
        kw: dict[str, PyObj] = {};
        if parts[2].t != "none" {
            for hk in (parts[2] as PyDict).items {
                cb_entry = ((parts[2] as PyDict).items)[hk];
                kw[(cb_entry.key as PyStr).val] = cb_entry.value;
            }
        }
        res = py_invoke(func, call_args, kw);
        if is_error(res) {
            # Exception ignored in atexit callback (unraisable in CPython);
            # remaining callbacks still run.
            continue;
        }
    }
    _p2_atexit_cleanup();
}

# ---------------- PyObj bridges (registered as the atexit shim module) ----

obj PyAtexitRegisterFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) == 0 {
            return py_error(
                "TypeError", "register() takes at least 1 argument (0 given)"
            );
        }
        func = args[0];
        if not obj_is_callable(func) {
            return py_error("TypeError", "the first argument must be callable");
        }
        rest: list[PyObj] = [];
        i = 1;
        while i < len(args) {
            rest.append(args[i]);
            i = i + 1;
        }
        kwarg_store: PyObj = py_none();
        if len(kwargs) > 0 {
            kd = PyDict(t="dict", items={});
            for key in kwargs {
                kd.dict_set(PyStr(t="str", val=key), kwargs[key]);
            }
            kwarg_store = kd;
        }
        callback = PyTuple(t="tuple", items=[func, PyTuple(t="tuple", items=rest), kwarg_store]);
        # atexit callbacks go in a LIFO order (PyList_Insert at 0).
        _atexit_callbacks.insert(0, callback);
        return func;
    }
}

obj PyAtexitUnregisterFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # atexit_unregister is METH_O: CPython's argument clinic emits the
        # generic single-argument arity message for both under/overflow.
        if len(args) != 1 {
            return py_error(
                "TypeError",
                "unregister() takes exactly one argument ("
                + str(len(args))
                + " given)",
            );
        }
        target = args[0];
        # atexit_unregister_locked: scan last-registered first, delete every
        # match; indices shift as matches are removed mid-scan.
        i = len(_atexit_callbacks) - 1;
        while i >= 0 {
            at_entry = _atexit_callbacks[i];
            to_compare = ((at_entry as PyTuple).items)[0];
            cmp = py_compare(2, target, to_compare);
            if is_error(cmp) {
                return cmp;
            }
            if cmp.tp_bool() {
                # The entry could have moved if an earlier (newer) match was
                # already deleted; clamp before hunting the real slot.
                j = len(_atexit_callbacks) - 1;
                if j > i {
                    j = i;
                }
                while j >= 0 {
                    if _atexit_callbacks[j] == at_entry {
                        del _atexit_callbacks[j];
                        break;
                    }
                    j = j - 1;
                }
                if i >= len(_atexit_callbacks) {
                    i = len(_atexit_callbacks);
                }
            }
            i = i - 1;
        }
        return py_none();
    }
}

obj PyAtexitRunExitfuncsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        _p2_atexit_callfuncs();
        return py_none();
    }
}

obj PyAtexitClearFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        _p2_atexit_cleanup();
        return py_none();
    }
}

obj PyAtexitNcallbacksFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyInt(t="int", val=len(_atexit_callbacks));
    }
}

def atexit_module_attrs() -> dict[str, PyObj] {
    return {
        "register": PyAtexitRegisterFn(t="function"),
        "unregister": PyAtexitUnregisterFn(t="function"),
        "_run_exitfuncs": PyAtexitRunExitfuncsFn(t="function"),
        "_clear": PyAtexitClearFn(t="function"),
        "_ncallbacks": PyAtexitNcallbacksFn(t="function"),
    };
}
