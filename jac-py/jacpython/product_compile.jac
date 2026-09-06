# P4 product compilation entry (PLAN.md P0.3 / P0.13).
#
# source -> PyCode. It MUST NOT import host_oracle, marshal transport, or host
# tokenize/ast/compile. The eval-mode path is fully native: tokenizer -> parser
# -> validation -> codegen -> flowgraph -> assembler. exec/single (statement)
# modes are Phase C and fail loudly rather than falling back to the host.

import from objects { PyObj, py_error, is_error }
import from parser { parse_eval_expr, parse_file }
import from compiler_validate { validate_eval_expr, validate_module_body }
import from compiler_symtable { build_module_symtable }
import from compiler_diagnostics { compiler_diag_to_pyobj }
import from compiler_codegen { compile_eval, compile_exec }
# Statement-dispatch siblings: imported for their load-time registration into
# the compiler_dispatch leaf (see compiler_dispatch.jac); without these edges
# a compile of any compound statement would call an unwired handler slot.
import from compiler_defs { visit_function_def }
import from compiler_exc { visit_try }
import from compiler_loops { visit_if }
import from compiler_match { visit_match }
import from flowgraph { verify_cfg }
import from assembler { assemble }
import from compiler_context {
    enter_compile_context,
    exit_compile_context,
    product_compile_active,
    ensure_compile_registries_wired,
}

def compile_source(source: str, filename: str, mode: str, optimize: int) -> PyObj {
    reg = ensure_compile_registries_wired();
    if is_error(reg) {
        return reg;
    }
    enter_compile_context();
    try {
        if mode == "eval" {
            result = compile_eval_path(source, filename, mode);
        } else {
            result = compile_exec_path(source, filename, mode);
        }
    } finally {
        exit_compile_context();
    }
    return result;
}

# eval-mode native front end. Connects the already byte-exact-verified modules
# (parse_eval_expr -> validate -> compile_eval -> verify_cfg -> assemble).
# `optimize` is accepted for the public contract but does not affect eval
# expressions (no docstrings/asserts to strip); it threads through to Phase C
# statement compilation unchanged.
def compile_eval_path(source: str, filename: str, mode: str) -> PyObj {
    if mode != "eval" {
        return py_error(
            "NotImplementedError",
            "compile_source: mode '" + mode + "' not yet supported (Phase C)"
        );
    }
    e = parse_eval_expr(source, filename);
    if e is None {
        return py_error(
            "SyntaxError", "compile_source: failed to parse eval expression"
        );
    }
    vr = validate_eval_expr(e);
    if vr.diag is not None {
        return compiler_diag_to_pyobj(vr.diag);
    }
    u = compile_eval(e, filename, "<module>", 1);
    if u.diag is not None {
        return compiler_diag_to_pyobj(u.diag);
    }
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        return compiler_diag_to_pyobj(cfg.diag);
    }
    return assemble(cfg);
}

# exec-mode native front end (PLAN.md P0.12 band 2: straight-line modules).
# parse_file -> validate -> symtable -> compile_exec -> verify_cfg -> assemble.
def compile_exec_path(source: str, filename: str, mode: str) -> PyObj {
    if mode != "exec" {
        return py_error(
            "NotImplementedError",
            "compile_source: mode '" + mode + "' not yet supported"
        );
    }
    m = parse_file(source, filename);
    if m is None {
        return py_error("SyntaxError", "compile_source: failed to parse exec module");
    }
    vr = validate_module_body(m.body);
    if vr.diag is not None {
        return compiler_diag_to_pyobj(vr.diag);
    }
    sr = build_module_symtable(m.body);
    if sr.diag is not None {
        return compiler_diag_to_pyobj(sr.diag);
    }
    u = compile_exec(m.body, filename, "<module>", 1, sr.top);
    if u.diag is not None {
        return compiler_diag_to_pyobj(u.diag);
    }
    cfg = verify_cfg(u);
    if cfg.diag is not None {
        return compiler_diag_to_pyobj(cfg.diag);
    }
    return assemble(cfg);
}
