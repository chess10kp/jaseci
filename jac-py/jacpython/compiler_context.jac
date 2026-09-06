# Per-compilation context stack (PLAN.md Phase 3 / #4).
#
# Holds compilation-scoped mutable state (pending_break_finishes, active flag)
# so failed or nested compiles cannot leak process-global residue. Stack slots
# use the list-holder idiom from layer3_flag in ceval.jac; registry validation
# runs once before the first product compile.

import from objects { py_error, PyObj, py_none }
import from compiler_ir {
    pending_break_finish,
    basicblock,
    loop_frame,
}
import from compiler_dispatch { stmt_handlers }

obj compile_context {
    has pending_break_finishes: list[pending_break_finish] = [];
}

glob _compile_ctx_stack: list[compile_context] = [];
glob _registries_validated: list[bool] = [False];

def product_compile_active -> bool {
    return len(_compile_ctx_stack) > 0;
}

def enter_compile_context {
    _compile_ctx_stack.append(compile_context());
}

def exit_compile_context {
    n = len(_compile_ctx_stack);
    if n > 0 {
        _compile_ctx_stack = _compile_ctx_stack[0:n - 1];
    }
}

def current_pending_break_finishes -> list[pending_break_finish] {
    n = len(_compile_ctx_stack);
    if n == 0 {
        return [];
    }
    return (_compile_ctx_stack[n - 1] as compile_context).pending_break_finishes;
}

def push_pending_break_finish(
    frame: loop_frame, join: basicblock, allow_nop: bool
) {
    current_pending_break_finishes().append(
        pending_break_finish(frame=frame, join=join, allow_nop=allow_nop)
    );
}

def append_pending_break_finish(job: pending_break_finish) {
    current_pending_break_finishes().append(job);
}

def ensure_compile_registries_wired() -> PyObj {
    if _registries_validated[0] {
        return py_none();
    }
    required_handlers = [
        "visit_if",
        "visit_while",
        "visit_for",
        "visit_async_for",
        "visit_function_def",
        "visit_async_function_def",
        "visit_class_def",
        "visit_type_alias",
        "visit_import",
        "visit_import_from",
        "visit_try",
        "visit_try_star",
        "visit_raise_stmt",
        "visit_with",
        "visit_async_with",
        "visit_match",
        "deferred_comp_handlers",
    ];
    hi = 0;
    while hi < len(required_handlers) {
        key = required_handlers[hi];
        if not (key in stmt_handlers) {
            return py_error(
                "RuntimeError",
                "compiler: stmt_handlers missing '" + key + "'"
            );
        }
        slot = stmt_handlers[key];
        if slot is None {
            return py_error(
                "RuntimeError",
                "compiler: stmt_handlers '" + key + "' is unwired"
            );
        }
        hi = hi + 1;
    }
    _registries_validated[0] = True;
    return py_none();
}
