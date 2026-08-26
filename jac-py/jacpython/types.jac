# Native lift of reference/cpython/Modules/_typesmodule.c.
#
# _typesmodule.c carries no executable logic: multi-phase init (_types_exec)
# inserts 27 immortal static type objects into the module dict via
# EXPORT_STATIC_TYPE, in a fixed ORDER (BuiltinMethodType re-exports
# PyCFunction_Type and LambdaType re-exports PyFunction_Type -- aliases, not
# distinct types). Lib/types.py opens with ``from _types import *`` and falls
# back to introspective definitions only when that import fails, so serving
# this surface natively makes the guest types.py take CPython's real path and
# pins every static-type NAME byte-exactly.
#
# The exported values are HOST type objects; the wiring site (ceval.jac)
# wraps each raw fetch in a proxy -- the same representation
# build_types_facade serves for these names on the proxy-import path, so
# identity between ``type(x)`` answers (py_type maps native
# functions/generators/coroutines onto these same host classes) and the
# module attributes holds.
#
# Wiring: ceval.jac registers this surface as the lazy shim "_types" in both
# import_native and host_import, so guest ``import _types`` /
# ``from _types import *`` resolves proxy-free like errno/heapq instead of
# ModuleNotFoundError-ing into the types.py fallback.
#
# This file stays a leaf: ceval imports FROM here and Jac forbids import
# cycles, so PyHostProxy/PyModule construction lives on the wiring site while
# the export table, fetch helper, and dict assembly live here (the raw host
# values pass through a plain dict untouched).

import from objects {
    PyObj,
    PyStr,
}

::py::
def _types_static_type(name):
    # Fetch one immortal static type by its _typesmodule.c export NAME from
    # the HOST types module (every export name is also a types.py attribute).
    # Returns (True, typeobj) / (False, None) instead of raising so one
    # unavailable host name degrades to an absent key, never a broken module.
    # The host module is fetched by string name through importlib (the same
    # convention as ceval's _jac_host_import): a literal ``import types`` here
    # would resolve to THIS facade module and form an import cycle.
    try:
        import importlib
        host_types = importlib.import_module("types")
        return (True, getattr(host_types, name))
    except Exception:
        return (False, None)
::py::

# Names in _typesmodule.c EXPORT_STATIC_TYPE insertion ORDER; aliases kept
# (BuiltinMethodType == BuiltinFunctionType, LambdaType == FunctionType).
def types_export_names -> list[str] {
    return [
        "AsyncGeneratorType", "BuiltinFunctionType", "BuiltinMethodType",
        "CapsuleType", "CellType", "ClassMethodDescriptorType", "CodeType",
        "CoroutineType", "EllipsisType", "FrameType", "FunctionType",
        "GeneratorType", "GenericAlias", "GetSetDescriptorType", "LambdaType",
        "MappingProxyType", "MemberDescriptorType", "MethodDescriptorType",
        "MethodType", "MethodWrapperType", "ModuleType", "NoneType",
        "NotImplementedType", "SimpleNamespace", "TracebackType", "UnionType",
        "WrapperDescriptorType",
    ];
}

# Module dict exactly as _types_exec builds it: every export name -> its raw
# HOST type object (unwrapped; ceval proxies at the boundary), plus the
# module docstring from the PyModuleDef. Names the host cannot serve are
# skipped rather than poisoned with a placeholder.
def types_module_attrs -> dict[str, any] {
    attrs: dict[str, any] = {};
    names = types_export_names();
    for name in names {
        fetched = _types_static_type(name);
        if fetched[0] {
            attrs[name] = fetched[1];
        }
    }
    attrs["__doc__"] = PyStr(t="str", val="Define names for built-in types.");
    return attrs;
}
