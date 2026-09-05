# Native _types module surface (lift of reference/cpython/Modules/_typesmodule.c).
#
# _typesmodule.c is a pure-data multi-phase-init module: _types_exec() inserts
# 26 immortal static type objects into the module dict (EXPORT_STATIC_TYPE, in
# source order) and nothing else. Lib/types.py star-imports this surface
# (`from _types import *`) and re-exports it, so the names below are the C
# module's exact export ORDER -- all names are distinct so no shadowing occurs,
# but the sequence is kept verbatim from the C file so a future diff against
# upstream stays mechanical.
#
# Wiring: ceval.jac assembles the PyModule at the shim-install sites
# (build_types_module) and registers it as a lazy "_types" shim in both
# import_native and host_import, so guest `import _types` (and therefore the
# star-import inside Lib/types.py) resolves proxy-free instead of leaking a
# stdlib-delegation snapshot of host type objects.
#
# Value split (mirrors the traceback shim's two-part pattern):
# - Names whose type family exists faithfully in the VM are served as
#   ShimTypeMarker instances: py_isinstance answers them with one PyObj.t tag
#   compare (no host bridge). Nothing constructs instances through these names,
#   so each marker carries a rejecting ctor.
# - The remaining names have either no faithful native family or an actively
#   used constructor surface (types.FunctionType(...), types.ModuleType(name),
#   types.SimpleNamespace(...), types.MappingProxyType(d)); they are overlaid
#   at the install site with transparent host proxies of the real CPython
#   static types -- byte-identical to what stdlib delegation served before this
#   facade landed.

import from objects {
    PyObj,
    PyStr,
    py_error,
    ShimTypeMarker,
}

# Every exported name, in _typesmodule.c EXPORT_STATIC_TYPE order.
def _types_export_order -> list[PyStr] {
    return [
        PyStr(t="str", val="AsyncGeneratorType"),
        PyStr(t="str", val="BuiltinFunctionType"),
        PyStr(t="str", val="BuiltinMethodType"),
        PyStr(t="str", val="CapsuleType"),
        PyStr(t="str", val="CellType"),
        PyStr(t="str", val="ClassMethodDescriptorType"),
        PyStr(t="str", val="CodeType"),
        PyStr(t="str", val="CoroutineType"),
        PyStr(t="str", val="EllipsisType"),
        PyStr(t="str", val="FrameType"),
        PyStr(t="str", val="FunctionType"),
        PyStr(t="str", val="GenericAlias"),
        PyStr(t="str", val="GetSetDescriptorType"),
        PyStr(t="str", val="LambdaType"),
        PyStr(t="str", val="MappingProxyType"),
        PyStr(t="str", val="MemberDescriptorType"),
        PyStr(t="str", val="MethodDescriptorType"),
        PyStr(t="str", val="MethodType"),
        PyStr(t="str", val="MethodWrapperType"),
        PyStr(t="str", val="ModuleType"),
        PyStr(t="str", val="NoneType"),
        PyStr(t="str", val="NotImplementedType"),
        PyStr(t="str", val="SimpleNamespace"),
        PyStr(t="str", val="TracebackType"),
        PyStr(t="str", val="UnionType"),
        PyStr(t="str", val="WrapperDescriptorType"),
    ];
}

# Names with a faithful VM-native type family -> the PyObj.t tag their
# instances carry. BuiltinFunctionType/BuiltinMethodType map to
# "native_builtin" because guest builtins (len, repr, ...) ARE native builtins
# here; FrameType does not match generator frames ("genframe"), matching the
# CPython split where genframes are GeneratorType, not FrameType.
def _types_native_tags -> dict[str, PyStr] {
    return {
        "AsyncGeneratorType": PyStr(t="str", val="async_generator"),
        "BuiltinFunctionType": PyStr(t="str", val="native_builtin"),
        "BuiltinMethodType": PyStr(t="str", val="native_builtin"),
        "CellType": PyStr(t="str", val="cell"),
        "CoroutineType": PyStr(t="str", val="coroutine"),
        "EllipsisType": PyStr(t="str", val="ellipsis"),
        "FrameType": PyStr(t="str", val="frame"),
        "GenericAlias": PyStr(t="str", val="generic_alias"),
        "GetSetDescriptorType": PyStr(t="str", val="get_descriptor"),
        "MemberDescriptorType": PyStr(t="str", val="member_descr"),
        "MethodType": PyStr(t="str", val="bound_method"),
        "NoneType": PyStr(t="str", val="none"),
        "NotImplementedType": PyStr(t="str", val="notimplemented"),
        "TracebackType": PyStr(t="str", val="traceback"),
    };
}

# Rejecting ctor behind every native-family marker: these static types cannot
# be instantiated through the marker (CPython itself refuses NoneType() and
# friends); the error surfaces through the standard py_error channel.
obj TypesMarkerCtor(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return py_error(
            "TypeError", "cannot create '" + self.name + "' instances"
        );
    }
}

# Native-family exports from _typesmodule.c: ShimTypeMarker wrappers so
# py_isinstance matches on one PyObj.t compare. Constructor-bearing names
# (FunctionType, ModuleType, MappingProxyType, ...) are overlaid at the
# ceval install site with host proxies; this dict carries only the
# rejecting-marker surface.
def types_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    tags = _types_native_tags();
    for name in tags {
        tag = (tags[name] as PyStr).val;
        ctor = TypesMarkerCtor(t="types_marker_ctor", name=name);
        attrs[name] = ShimTypeMarker(
            t="shim_type_marker",
            tag=tag,
            ctor=ctor,
        );
    }
    return attrs;
}
