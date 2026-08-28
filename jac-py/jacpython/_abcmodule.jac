# Product-path wiring for the native _abc facade (jac-py/jacpython/abc.jac).
#
# CPython's Lib/abc.py imports the C accelerator ``_abc`` for registry/caches
# and the subclass/instance check algorithms. When abc boots in-VM during the
# guest-metaclass path, a host-proxied ``_abc`` hands guest ABC classes to host
# C ABCMeta.__subclasscheck__, which cannot traverse guest PyClass MROs --
# ``import typing`` dies in Protocol gates and ``enum.IntFlag`` extend checks
# see spurious ``ceval.Flag`` failures.
#
# This module exposes abc.jac through the same lazy shim pattern as weakref,
# errno, and gc: import_native/host_import register it before the generic
# builtin proxy path runs.
#
# NAMING: deliberately ``_abcmodule.jac`` (not ``abc.jac``) so ceval's own
# host-side imports never capture the guest facade.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    py_none,
    py_error,
    is_error,
}
import from abc {
    _abc_init,
    _abc_register,
    _abc_subclasscheck,
    _abc_instancecheck,
    get_cache_token,
    _get_dump,
    _reset_registry,
    _reset_caches,
}

def _abc_pylist(items: list) -> PyObj {
    out: list[PyObj] = [];
    for item in items {
        out.append(item as PyObj);
    }
    return PyList(t="list", items=out);
}

def _abc_dump_tuple(raw: tuple) -> PyObj {
    return PyTuple(
        t="tuple",
        items=[
            _abc_pylist(raw[0]),
            _abc_pylist(raw[1]),
            _abc_pylist(raw[2]),
            PyInt(t="int", val=raw[3]),
        ],
    );
}

obj PyAbcInitFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "_abc_init() missing 1 required positional argument: 'cls'");
        }
        _abc_init(args[0]);
        return py_none();
    }
}

obj PyAbcRegisterFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "_abc_register() missing 2 required positional arguments");
        }
        return _abc_register(args[0], args[1]) as PyObj;
    }
}

obj PyAbcSubclasscheckFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "_abc_subclasscheck() missing 2 required positional arguments");
        }
        return PyBool(t="bool", val=_abc_subclasscheck(args[0], args[1]));
    }
}

obj PyAbcInstancecheckFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 2 {
            return py_error("TypeError", "_abc_instancecheck() missing 2 required positional arguments");
        }
        return PyBool(t="bool", val=_abc_instancecheck(args[0], args[1]));
    }
}

obj PyAbcCacheTokenFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return PyInt(t="int", val=get_cache_token());
    }
}

obj PyAbcGetDumpFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "_get_dump() missing 1 required positional argument: 'cls'");
        }
        return _abc_dump_tuple(_get_dump(args[0]));
    }
}

obj PyAbcResetRegistryFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "_reset_registry() missing 1 required positional argument: 'cls'");
        }
        _reset_registry(args[0]);
        return py_none();
    }
}

obj PyAbcResetCachesFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) < 1 {
            return py_error("TypeError", "_reset_caches() missing 1 required positional argument: 'cls'");
        }
        _reset_caches(args[0]);
        return py_none();
    }
}

def abc_module_attrs() -> dict[str, PyObj] {
    return {
        "_abc_init": PyAbcInitFn(t="function"),
        "_abc_register": PyAbcRegisterFn(t="function"),
        "_abc_subclasscheck": PyAbcSubclasscheckFn(t="function"),
        "_abc_instancecheck": PyAbcInstancecheckFn(t="function"),
        "get_cache_token": PyAbcCacheTokenFn(t="function"),
        "_get_dump": PyAbcGetDumpFn(t="function"),
        "_reset_registry": PyAbcResetRegistryFn(t="function"),
        "_reset_caches": PyAbcResetCachesFn(t="function"),
    };
}
