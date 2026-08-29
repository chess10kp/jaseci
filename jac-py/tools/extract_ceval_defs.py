#!/usr/bin/env python3
"""Extract ceval_defs.jac from ceval.jac for cycle inversion."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "jacpython"
CEVAL = ROOT / "ceval.jac"

# (start, end) 1-based inclusive line ranges to extract from ceval.jac
RANGES: list[tuple[int, int]] = [
    (2599, 2624),  # PyBoundMethod
    (2626, 2633),  # PyGenericAlias + comment
    (2678, 2682),  # PyBuildClass
    (3148, 3162),  # PyGetDescriptorFn
    (3468, 3475),  # handled exc stack glob + current_handled_exc
    (3498, 3522),  # _handled_stack_remove/append (skip live_container_bridge)
    (9389, 9457),  # PyFrame, PyYield + comments
    (9482, 9855),  # PyNativeBuiltin
    (9857, 9909),  # PyGlobalsProxy
    (9911, 9995),  # PyNsMethod
    (10001, 10418),  # framelocals helpers + proxy + method
    (12301, 12547),  # gen cluster through PyGenMethod
    (12854, 12876),  # PyGenFrame, PyGenFrameClear
]

CEVAL_API_FUNCS = [
    "as_error",
    "builtin_sorted_min_max",
    "descriptor_get",
    "frame_clear",
    "from_host",
    "gen_close",
    "gen_send",
    "gen_throw",
    "host_builtin",
    "host_import",
    "host_iter",
    "normalize_throw_args",
    "obj_is_callable",
    "py_attr",
    "py_aiter",
    "py_anext",
    "py_build_class",
    "py_del_attr",
    "py_dir",
    "py_hash",
    "py_id",
    "py_invoke",
    "py_isinstance",
    "py_issubclass",
    "py_iter",
    "py_len",
    "py_raise_value",
    "py_repr",
    "py_set_attr",
    "py_type_of",
    "send_into",
    "stop_iteration",
    "to_host_coerce",
    "user_instance_dict",
    "localsplus_name",
    "format_exception_text",
]

CEVAL_DEFS_TYPES = [
    "PyBoundMethod",
    "PyGenericAlias",
    "PyBuildClass",
    "PyGetDescriptorFn",
    "PyFrame",
    "PyYield",
    "PyNativeBuiltin",
    "PyGlobalsProxy",
    "PyNsMethod",
    "PyFrameLocalsProxy",
    "PyFrameLocalsMethod",
    "PyGenStop",
    "PyAsyncGenWrappedValue",
    "PyAsyncGenASend",
    "PyAsyncGenAThrow",
    "PyAsyncGenMethod",
    "PyGenerator",
    "PyGenMethod",
    "PyGenFrame",
    "PyGenFrameClear",
]

CEVAL_DEFS_GLOBS = [
    "_handled_exc_stack",
    "_handled_stack_append_each",
    "_handled_stack_remove_each",
    "current_handled_exc",
    "framelocals_nslots",
    "framelocals_keyerror",
    "framelocals_len",
]

HEADER = '''\
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

'''


def transform_body(text: str) -> str:
    text = re.sub(
        r"\bjac_frame_chain_slot\b(?!_ref)",
        "jac_frame_chain_slot_ref()",
        text,
    )
    text = text.replace("NB_INPLACE_OR", "_NB_INPLACE_OR")
    text = text.replace("NB_OR", "_NB_OR")
    return text


def extract_ranges(lines: list[str]) -> tuple[str, set[int]]:
    out: list[str] = []
    removed: set[int] = set()
    for start, end in RANGES:
        for i in range(start - 1, end):
            removed.add(i)
            out.append(lines[i])
    return "".join(out), removed


def remove_ranges(lines: list[str], removed: set[int]) -> list[str]:
    return [ln for i, ln in enumerate(lines) if i not in removed]


def patch_ceval_imports(text: str) -> str:
    insert = """
import from ceval_defs {
    PyBoundMethod,
    PyGenericAlias,
    PyBuildClass,
    PyGetDescriptorFn,
    PyFrame,
    PyYield,
    PyNativeBuiltin,
    PyGlobalsProxy,
    PyNsMethod,
    PyFrameLocalsProxy,
    PyFrameLocalsMethod,
    PyGenStop,
    PyAsyncGenWrappedValue,
    PyAsyncGenASend,
    PyAsyncGenAThrow,
    PyAsyncGenMethod,
    PyGenerator,
    PyGenMethod,
    PyGenFrame,
    PyGenFrameClear,
    _handled_exc_stack,
    _handled_stack_append_each,
    _handled_stack_remove_each,
    current_handled_exc,
    framelocals_nslots,
    framelocals_keyerror,
    framelocals_len,
}
"""
    anchor = "import from ceval_exec_frame {"
    if "import from ceval_defs {" not in text:
        text = text.replace(anchor, insert + anchor, 1)
    # drop jac_frame_chain_slot from ceval_exec_frame import if present
    text = re.sub(
        r"import from ceval_exec_frame \{\s*\n"
        r"    exec_code_frame,\s*\n"
        r"    run_frame,\s*\n"
        r"    jac_frame_chain_slot,\s*\n",
        "import from ceval_exec_frame {\n"
        "    exec_code_frame,\n"
        "    run_frame,\n",
        text,
    )
    return text


def append_ceval_ops_registration(text: str) -> str:
    # Registration is generated by tools/gen_ceval_cycle_fix.py after spoke wiring.
    return text


def patch_vm_dispatch(text: str) -> str:
    if "def jac_frame_chain_slot_ref" in text:
        return text
    return (
        text.rstrip()
        + "\n\ndef jac_frame_chain_slot_ref() -> list[any] {\n"
        + "    return _frame_chain_slot;\n"
        + "}\n"
    )


def patch_ceval_exec_frame(text: str) -> str:
    # imports: ceval_defs for types/globs, ceval_api for funcs
    old = re.search(r"import from ceval \{[^}]+\}", text, re.DOTALL)
    if not old:
        return text
    type_import = """import from ceval_defs {
    _handled_exc_stack,
    _handled_stack_append_each,
    _handled_stack_remove_each,
    PyFrame,
    PyGenerator,
    PyYield,
    PyBuildClass,
    PyAsyncGenWrappedValue,
    PyGlobalsProxy,
    PyBoundMethod,
    PyNativeBuiltin,
    PyGenericAlias,
}
import from ceval_api {
    builtin_exec,
    dict_from_str_map,
    fast_value,
    fast_value_check,
    format_exc_unbound,
    localsplus_name,
    resolve_cell,
    make_function_from_stack,
    make_interpolation,
    make_template,
    members_of,
    descriptor_get,
    host_builtin,
    host_convert,
    host_format,
    host_import,
    import_star_into,
    layer3_is_active,
    load_name_fallback,
    gen_resume,
    send_into,
    send_throw_into,
    calliter_next,
    seqiter_next,
    dictiter_yield,
    dictiter_error,
    error_is_stopiteration,
    py_import_name,
    py_slot_truth,
    py_repr,
    py_str,
    py_compare,
    py_contains,
    py_binop,
    py_attr,
    py_set_attr,
    py_del_attr,
    py_invoke,
    py_iter,
    py_len,
    py_negative,
    py_invert,
    py_raise_value,
    py_get_awaitable,
    py_aiter,
    py_anext,
    py_match_class,
    py_match_keys,
    py_type_has_sequence_flag,
    py_type_has_mapping_flag,
    py_identity,
    py_dir_sorted,
    bind_attribute,
    super_lookup,
    user_has_dunder,
    call_user_dunder,
    from_host,
    to_host_coerce,
}"""
    text = text[: old.start()] + type_import + text[old.end() :]
    text = text.replace(
        "glob jac_frame_chain_slot: list[PyFrame] = [];\n\n",
        "import from vm_dispatch { jac_frame_chain_slot_ref, }\n\n",
    )
    text = re.sub(
        r"\bjac_frame_chain_slot\b(?!_ref)",
        "jac_frame_chain_slot_ref()",
        text,
    )
    return text


def patch_ceval_opcodes_containers(text: str) -> str:
    text = re.sub(
        r"import from ceval \{[^}]+\}",
        """import from ceval_exceptions { recover_exception, }
import from ceval_api {
    to_host_coerce,
    iter_drain,
    append_to_list,
    dict_mapping_pairs,
    py_subscript,
    py_store_subscript,
    py_delete_subscript,
}""",
        text,
        count=1,
        flags=re.DOTALL,
    )
    return text


def patch_ceval_exceptions(text: str) -> str:
    return text.replace(
        "import from ceval { class_mro, py_invoke }",
        "import from ceval_api { class_mro, py_invoke }",
    )


def patch_ceval_bridge_guest(text: str) -> str:
    return re.sub(
        r"import from ceval \{[^}]+\}",
        """import from ceval_api {
    to_host,
    from_host,
    host_exception,
    py_repr,
    py_str,
    py_iter,
    py_attr,
    bind_attribute,
    send_into,
    class_lookup_attr,
    class_has_abc_meta,
    class_mro,
    gen_throw,
    gen_send,
    gen_close,
}""",
        text,
        count=1,
        flags=re.DOTALL,
    )


def extend_ceval_api(text: str) -> str:
    sigs = {
        "as_error": "def as_error(value: PyObj) -> PyObj",
        "builtin_sorted_min_max": "def builtin_sorted_min_max(name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj",
        "frame_clear": "def frame_clear(frame: PyFrame) -> None",
        "format_exception_text": "def format_exception_text(e: PyObj) -> PyObj",
        "host_iter": "def host_iter(value: PyHostProxy) -> PyObj",
        "normalize_throw_args": "def normalize_throw_args(args: list[PyObj]) -> PyObj",
        "obj_is_callable": "def obj_is_callable(x: PyObj) -> bool",
        "py_build_class": "def py_build_class(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj",
        "py_dir": "def py_dir(arg: PyObj) -> PyObj",
        "py_hash": "def py_hash(value: PyObj) -> PyObj",
        "py_id": "def py_id(o: PyObj) -> int",
        "py_isinstance": "def py_isinstance(ob: PyObj, typ: PyObj) -> bool",
        "py_issubclass": "def py_issubclass(cls: PyObj, typ: PyObj) -> bool",
        "py_type_of": "def py_type_of(o: PyObj) -> PyObj",
        "stop_iteration": "def stop_iteration(value: PyObj) -> PyObj",
        "user_instance_dict": "def user_instance_dict(u: PyUserObj) -> PyObj",
    }
    for name, hdr in sigs.items():
        if f'def {name}(' in text:
            continue
        text += f"\n{hdr} {{\n    return (ceval_ops[\"{name}\"] as any)(...)\n}}\n"
    if "PyFrame" not in text.split("import from objects")[1].split("}")[0]:
        text = text.replace(
            "import from objects { PyObj, }",
            "import from objects { PyObj, PyUserObj, PyHostProxy, PyFrame, }",
        )
    return text


def main() -> None:
    lines = CEVAL.read_text().splitlines(keepends=True)
    body, removed = extract_ranges(lines)
    body = transform_body(body)

    (ROOT / "ceval_defs.jac").write_text(HEADER + body)

    new_ceval = remove_ranges(lines, removed)
    ceval_text = "".join(new_ceval)
    ceval_text = patch_ceval_imports(ceval_text)
    ceval_text = append_ceval_ops_registration(ceval_text)
    CEVAL.write_text(ceval_text)

    vm = ROOT / "vm_dispatch.jac"
    vm.write_text(patch_vm_dispatch(vm.read_text()))

    api = ROOT / "ceval_api.jac"
    api.write_text(extend_ceval_api(api.read_text()))

    ef = ROOT / "ceval_exec_frame.jac"
    ef.write_text(patch_ceval_exec_frame(ef.read_text()))

    oc = ROOT / "ceval_opcodes_containers.jac"
    oc.write_text(patch_ceval_opcodes_containers(oc.read_text()))

    ex = ROOT / "ceval_exceptions.jac"
    ex.write_text(patch_ceval_exceptions(ex.read_text()))

    bg = ROOT / "ceval_bridge_guest.jac"
    bg.write_text(patch_ceval_bridge_guest(bg.read_text()))

    print(f"Wrote ceval_defs.jac ({len(body.splitlines())} body lines)")
    print(f"Removed {len(removed)} lines from ceval.jac")


if __name__ == "__main__":
    main()
