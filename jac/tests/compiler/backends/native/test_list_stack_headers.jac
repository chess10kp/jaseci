"""Stack-constructed list headers for frame-local lists (issue #9376).

When escape analysis proves a list display's header never outlives the frame,
the backend allocates the header in the frame (`stkl.*` alloca), keeps only
the data buffer on the heap, and releases the buffer through the data-only
release helper. Every escape channel — global store, user-call argument —
must refuse the promotion and keep the plain heap header, because a dangling
frame header turns post-frame reads into use-after-free.
"""

import ctypes;
import from tests.support { compile_native, compile_native_ir, get_func }

test "frame-local list headers execute correctly and escape channels stay heap" {
    (engine, module) = compile_native("list_stack_headers.jac");
    churn = get_func(engine, "s1_churn_append", ctypes.c_int64);
    assert churn() == 12 , churn();
    fill = get_func(engine, "s2_annotated_empty_then_fill", ctypes.c_int64);
    assert fill() == 84 , fill();
    iterate = get_func(engine, "s3_iterate", ctypes.c_int64);
    assert iterate() == 12 , iterate();
    overwrite = get_func(engine, "s4_overwrite", ctypes.c_int64);
    assert overwrite() == 6 , overwrite();
    released = get_func(engine, "s5_items_released_at_scope_exit", ctypes.c_int64);
    drops = get_func(engine, "item_drop_count", ctypes.c_int64);
    before = drops();
    assert released() == 3 , released();
    assert drops() - before == 3 , drops() - before;
    escape_glob = get_func(engine, "n1_escape_global_store", ctypes.c_int64);
    assert escape_glob() == 0;
    read_sink = get_func(engine, "read_sink", ctypes.c_int64);
    assert read_sink() == 45 , read_sink();
    escape_call = get_func(engine, "n2_escape_call_arg", ctypes.c_int64);
    assert escape_call() == 27 , escape_call();
}

test "header promotion shows in IR only for proven locals" {
    module = compile_native_ir("list_stack_headers.jac");
    ir_text = str(module.gen.llvm_ir);
    assert "__rc_release_list_data_" in ir_text , "data-only release helper missing";
    for (fn_name, wants_stack) in [
        ("s1_churn_append", True),
        ("s4_overwrite", True),
        ("s5_items_released_at_scope_exit", True),
        ("n1_escape_global_store", False),
        ("n2_escape_call_arg", False)
    ] {
        _body = _function_body(ir_text, fn_name);
        assert _body is not None , f"{fn_name} not found in IR";
        has_stack = "stkl." in _body;
        if wants_stack {
            assert has_stack , f"{fn_name} must construct its header in the frame";
        } else {
            assert not has_stack , f"{fn_name} must keep the heap header";
            assert "__list_new_" in _body , f"{fn_name} must fall back to the heap path";
        }
    }
}

"""Slice the IR down to one function definition's body."""
def _function_body(ir_text: str, fn_name: str) -> (str | None) {
    for marker in ("@" + fn_name + "()", "@\"" + fn_name + "\"()") {
        for chunk in ir_text.split("define ") {
            head = chunk[: chunk.find("{")] if "{" in chunk else "";
            if marker in head {
                return chunk[: chunk.find("\n}") if "\n}" in chunk else len(chunk)];
            }
        }
    }
    return None;
}
