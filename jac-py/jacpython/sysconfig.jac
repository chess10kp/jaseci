# Native _sysconfig module facade (lift of reference/cpython/Modules/_sysconfig.c).
#
# _sysconfig is a tiny multi-phase-init C module exposing build facts for the
# sysconfig module: one clinic method, config_vars(), which returns a fresh
# dict of build variables Lib/sysconfig.py merges into its config vars. This
# facade mirrors that surface for the Linux/glibc default build of the pinned
# CPython 3.14 reference:
#
# - Py_GIL_DISABLED / Py_DEBUG resolve to 0 exactly as the C source's
#   compile-time guards do on a non-free-threaded, non-Py_DEBUG build
#   (_PyLong_GetZero arms of config_vars_impl).
# - The MS_WINDOWS arm (add_string_value for EXT_SUFFIX / SOABI) is out of
#   scope by design: it never compiles on the linux product path.
#
# Wiring: ceval.jac registers this surface as a lazy shim under "_sysconfig"
# in both import_native and host_import, so guest ``import _sysconfig``
# resolves proxy-free instead of leaking a host PyProxy whose config_vars()
# would answer about the HOST interpreter's build flags rather than ours.
# Module doc mirrors sysconfig__doc__ ("A helper for the sysconfig module.").

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyDict,
    py_error,
}

# _sysconfig.config_vars_impl (Modules/_sysconfig.c): METH_NOARGS method
# returning a fresh dict of build variables intended to be exposed by
# sysconfig. Key order follows the C insertion order (Py_GIL_DISABLED first,
# then Py_DEBUG; the Windows EXT_SUFFIX/SOABI inserts precede both but are
# unreachable on this platform).
obj PySysconfigConfigVarsFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) != 0 or len(kwargs) != 0 {
            return py_error(
                "TypeError",
                "config_vars() takes no arguments (" + str(len(args)) + " given)"
            );
        }
        config = PyDict(t="dict", items={});
        # PyObject *py_gil_disabled = _PyLong_GetZero(); (Py_GIL_DISABLED guard)
        config.dict_set(PyStr(t="str", val="Py_GIL_DISABLED"), PyInt(t="int", val=0));
        # PyObject *py_debug = _PyLong_GetZero(); (Py_DEBUG guard)
        config.dict_set(PyStr(t="str", val="Py_DEBUG"), PyInt(t="int", val=0));
        return config;
    }
}

# Module attrs: the single method-table entry (_SYSCONFIG_CONFIG_VARS_METHODDEF).
def sysconfig_module_attrs -> dict[str, PyObj] {
    return {
        "config_vars": PySysconfigConfigVarsFn(t="sysconfig_fn") as PyObj,
    };
}
