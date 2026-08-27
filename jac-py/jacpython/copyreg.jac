# Product-path facade for copyreg (native Jac).
#
# Lib/copyreg.py is pure Python but its type-keyed ``dispatch_table`` and
# extension registries must retain guest PyClass / PyTuple identity. Host
# delegation snapshots host type objects, so ``copyreg.pickle(C, ...)`` never
# lines up with ``copy.copy(x)`` when ``x`` is a guest instance of ``C``.
#
# Semantics mirror CPython 3.14 ``Lib/copyreg.py`` for the surfaces converted
# suites exercise: ``pickle``/``constructor``, the live ``dispatch_table``,
# and the extension registry triple (``_extension_registry``,
# ``_inverted_registry``, ``_extension_cache``) plus
# ``add_extension``/``remove_extension``/``clear_extension_cache``.
#
# Divergences (ledger): module-level bootstrap registrations (complex, Union,
# super) are not replayed here — guest code that relies on them should register
# explicitly or take the host fallback on first import before this shim lands.
# ``_reconstructor`` / ``__newobj__`` reduce helpers are not exported yet.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyFloat,
    PyBytes,
    PyList,
    PyTuple,
    PyDict,
    PySet,
    PyNoneType,
    PyModule,
    py_none,
    py_error,
    is_error,
    dict_key_repr,
}

# Type-keyed reducer table (copyreg.dispatch_table).
glob _COPYREG_DISPATCH: PyDict = PyDict(t="dict", items={});

# Extension registry triple — names are stable; pickle grabs references at init.
glob _COPYREG_EXT_REG: PyDict = PyDict(t="dict", items={});
glob _COPYREG_EXT_INV: PyDict = PyDict(t="dict", items={});
glob _COPYREG_EXT_CACHE: PyDict = PyDict(t="dict", items={});

def _copyreg_callable(o: PyObj) -> bool {
    # Conservative callable probe (see signal.jac): scalars/containers are not
    # callable; everything else is accepted for registration.
    if (
        isinstance(o, PyNoneType)
        or isinstance(o, PyBool)
        or isinstance(o, PyInt)
        or isinstance(o, PyFloat)
        or isinstance(o, PyStr)
        or isinstance(o, PyBytes)
        or isinstance(o, PyList)
        or isinstance(o, PyTuple)
        or isinstance(o, PyDict)
        or isinstance(o, PySet)
    ) {
        return False;
    }
    return True;
}

def _copyreg_ext_key(mod: PyObj, name: PyObj) -> PyTuple {
    return PyTuple(t="tuple", items=[mod, name]);
}

def _copyreg_dict_get(d: PyDict, key: PyObj) -> PyObj {
    if not d.dict_contains(key) {
        return py_none();
    }
    return d.mp_subscript(key);
}

def _copyreg_pickle(args: list[PyObj]) -> PyObj {
    if len(args) < 2 {
        return py_error(
            "TypeError",
            "pickle() missing 2 required positional arguments: "
            + "'ob_type' and 'pickle_function'",
        );
    }
    ob_type = args[0];
    pickle_fn = args[1];
    if not _copyreg_callable(pickle_fn) {
        return py_error("TypeError", "reduction functions must be callable");
    }
    st = _COPYREG_DISPATCH.dict_set(ob_type, pickle_fn);
    if is_error(st) {
        return st;
    }
    if len(args) >= 3 and not isinstance(args[2], PyNoneType) {
        got = _copyreg_constructor([args[2]]);
        if is_error(got) {
            return got;
        }
    }
    return py_none();
}

def _copyreg_constructor(args: list[PyObj]) -> PyObj {
    if len(args) < 1 {
        return py_error(
            "TypeError",
            "constructor() missing 1 required positional argument: 'object'",
        );
    }
    ob = args[0];
    if not _copyreg_callable(ob) {
        return py_error("TypeError", "constructors must be callable");
    }
    return py_none();
}

def _copyreg_add_extension(args: list[PyObj]) -> PyObj {
    if len(args) != 3 {
        return py_error(
            "TypeError",
            "add_extension() missing 3 required positional arguments: "
            + "'module', 'name', and 'code'",
        );
    }
    if not isinstance(args[0], PyStr) or not isinstance(args[1], PyStr) {
        return py_error("TypeError", "module and name must be strings");
    }
    if not isinstance(args[2], PyInt) {
        return py_error("TypeError", "an integer is required");
    }
    mod = args[0];
    name = args[1];
    code = (args[2] as PyInt).val;
    if code < 1 or code > 2147483647 {
        return py_error("ValueError", "code out of range");
    }
    key = _copyreg_ext_key(mod, name);
    code_key = PyInt(t="int", val=code);
    cur_code = _copyreg_dict_get(_COPYREG_EXT_REG, key);
    cur_key = _copyreg_dict_get(_COPYREG_EXT_INV, code_key);
    if (
        not isinstance(cur_code, PyNoneType)
        and (cur_code as PyInt).val == code
        and not isinstance(cur_key, PyNoneType)
        and cur_key is key
    ) {
        return py_none();
    }
    if _COPYREG_EXT_REG.dict_contains(key) {
        existing = _COPYREG_EXT_REG.mp_subscript(key);
        msg = "key " + dict_key_repr(key) + " is already registered with code "
            + dict_key_repr(existing);
        return py_error("ValueError", msg);
    }
    if _COPYREG_EXT_INV.dict_contains(code_key) {
        existing_key = _COPYREG_EXT_INV.mp_subscript(code_key);
        msg = "code " + str(code) + " is already in use for key "
            + dict_key_repr(existing_key);
        return py_error("ValueError", msg);
    }
    st = _COPYREG_EXT_REG.dict_set(key, code_key);
    if is_error(st) {
        return st;
    }
    st2 = _COPYREG_EXT_INV.dict_set(code_key, key);
    if is_error(st2) {
        return st2;
    }
    return py_none();
}

def _copyreg_remove_extension(args: list[PyObj]) -> PyObj {
    if len(args) != 3 {
        return py_error(
            "TypeError",
            "remove_extension() missing 3 required positional arguments: "
            + "'module', 'name', and 'code'",
        );
    }
    if not isinstance(args[0], PyStr) or not isinstance(args[1], PyStr) {
        return py_error("TypeError", "module and name must be strings");
    }
    if not isinstance(args[2], PyInt) {
        return py_error("TypeError", "an integer is required");
    }
    mod = args[0];
    name = args[1];
    code = (args[2] as PyInt).val;
    key = _copyreg_ext_key(mod, name);
    code_key = PyInt(t="int", val=code);
    cur_code = _copyreg_dict_get(_COPYREG_EXT_REG, key);
    cur_key = _copyreg_dict_get(_COPYREG_EXT_INV, code_key);
    if (
        isinstance(cur_code, PyNoneType)
        or (cur_code as PyInt).val != code
        or isinstance(cur_key, PyNoneType)
        or cur_key is not key
    ) {
        msg = "key " + dict_key_repr(key) + " is not registered with code "
            + str(code);
        return py_error("ValueError", msg);
    }
    del_st = _COPYREG_EXT_REG.mp_del_subscript(key);
    if is_error(del_st) {
        return del_st;
    }
    del_st2 = _COPYREG_EXT_INV.mp_del_subscript(code_key);
    if is_error(del_st2) {
        return del_st2;
    }
    if _COPYREG_EXT_CACHE.dict_contains(code_key) {
        cache_del = _COPYREG_EXT_CACHE.mp_del_subscript(code_key);
        if is_error(cache_del) {
            return cache_del;
        }
    }
    return py_none();
}

def _copyreg_clear_extension_cache(args: list[PyObj]) -> PyObj {
    if len(args) > 0 {
        return py_error("TypeError", "clear_extension_cache() takes no arguments");
    }
    _COPYREG_EXT_CACHE.items = {};
    return py_none();
}

obj PyCopyregFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        if self.name == "pickle" {
            return _copyreg_pickle(args);
        }
        if self.name == "constructor" {
            return _copyreg_constructor(args);
        }
        if self.name == "add_extension" {
            return _copyreg_add_extension(args);
        }
        if self.name == "remove_extension" {
            return _copyreg_remove_extension(args);
        }
        if self.name == "clear_extension_cache" {
            return _copyreg_clear_extension_cache(args);
        }
        return py_error("AttributeError", self.name);
    }
}

def build_copyreg_module -> PyObj {
    attrs: dict[str, PyObj] = {
        "pickle": PyCopyregFn(t="copyreg_fn", name="pickle"),
        "constructor": PyCopyregFn(t="copyreg_fn", name="constructor"),
        "add_extension": PyCopyregFn(t="copyreg_fn", name="add_extension"),
        "remove_extension": PyCopyregFn(t="copyreg_fn", name="remove_extension"),
        "clear_extension_cache": PyCopyregFn(
            t="copyreg_fn", name="clear_extension_cache"
        ),
        "dispatch_table": _COPYREG_DISPATCH,
        "_extension_registry": _COPYREG_EXT_REG,
        "_inverted_registry": _COPYREG_EXT_INV,
        "_extension_cache": _COPYREG_EXT_CACHE,
    };
    return PyModule(t="module", name="copyreg", attrs=attrs);
}
