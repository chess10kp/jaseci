# Validation-legality pins for the P4 back track (compiler_validate lane).
#
# Helpers drive validate_module_body / validate_eval_expr over hand-built ASTs
# and cross-check rejection messages against the host compile() oracle. Lives
# outside compiler_validate.jac because product modules must not call host
# compile() (P4 gate forbidden pattern).

import from ast_nodes {
    Constant,
    Name,
    UnaryOp,
    USub,
    Assign,
    Pass,
    Return,
    Tuple,
    Load,
    Store,
    Break,
    Nonlocal,
    While,
    Module,
}
import from compiler_diagnostics {
    compiler_diag_kind,
    compiler_diag_message,
}
import from parser { parse_file }
import from objects { PyInt }
import from compiler_validate {
    validate_module_body,
    validate_eval_expr,
}

def _host_compile_syntax_error(source: str, mode: str = "exec") -> str | None {
    try {
        compile(source, "<t>", mode);
    } except SyntaxError as e {
        return e.msg;
    }
    return None;
}


def host_compile_syntax_error(source: str, mode: str = "exec") -> str | None {
    return _host_compile_syntax_error(source, mode);
}

def assert_validate_rejects_like_compile(source: str) {
    m = parse_file(source, "<t>");
    assert m is not None;
    r = validate_module_body((m as Module).body);
    assert r.diag is not None;
    expected = host_compile_syntax_error(source, "exec");
    assert expected is not None;
    assert compiler_diag_message(r.diag) == expected;
}

import from objects { PyInt }
import from ast_nodes { USub }

test "compiler_validate: module return rejected" {
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=7,
        end_lineno=1,
        end_col_offset=8
    );
    r = validate_module_body(
        [Return(value=one, lineno=1, col_offset=0, end_lineno=1, end_col_offset=8)]
    );
    assert r.diag is not None;
    assert compiler_diag_kind(r.diag) == "SyntaxError";
    assert compiler_diag_message(r.diag) == "'return' outside function";
}

test "compiler_validate: pass module accepted" {
    r = validate_module_body(
        [Pass(lineno=1, col_offset=0, end_lineno=1, end_col_offset=4)]
    );
    assert r.diag is None;
}

test "compiler_validate: assign with load target rejected" {
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=4,
        end_lineno=1,
        end_col_offset=5
    );
    r = validate_module_body(
        [
            Assign(
                targets=[x],
                value=one,
                type_comment=None,
                lineno=1,
                col_offset=0,
                end_lineno=1,
                end_col_offset=5
            )
        ]
    );
    assert r.diag is not None;
    assert compiler_diag_kind(r.diag) == "SyntaxError";
}

test "compiler_validate: unsupported tuple target defers to codegen" {
    x = Name(
        id="x", ctx=Store(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    y = Name(
        id="y", ctx=Store(), lineno=1, col_offset=2, end_lineno=1, end_col_offset=3
    );
    one = Constant(
        value=PyInt(t="int", val=1),
        kind=None,
        lineno=1,
        col_offset=6,
        end_lineno=1,
        end_col_offset=7
    );
    r = validate_module_body(
        [
            Assign(
                targets=[
                    Tuple(
                        elts=[x, y],
                        ctx=Store(),
                        lineno=1,
                        col_offset=0,
                        end_lineno=1,
                        end_col_offset=4
                    )
                ],
                value=one,
                type_comment=None,
                lineno=1,
                col_offset=0,
                end_lineno=1,
                end_col_offset=7
            )
        ]
    );
    assert r.diag is None;
}

test "compiler_validate: eval expr accepted" {
    x = Name(
        id="x", ctx=Load(), lineno=1, col_offset=0, end_lineno=1, end_col_offset=1
    );
    r = validate_eval_expr(
        UnaryOp(
            op=USub(), operand=x, lineno=1, col_offset=0, end_lineno=1, end_col_offset=2
        )
    );
    assert r.diag is None;
}

test "compiler_validate: break outside loop rejected" {
    r = validate_module_body(
        [Break(lineno=1, col_offset=0, end_lineno=1, end_col_offset=5)]
    );
    assert r.diag is not None;
    assert compiler_diag_message(r.diag) == "'break' outside loop";
}

test "compiler_validate: nonlocal at module rejected" {
    r = validate_module_body(
        [Nonlocal(names=["x"], lineno=1, col_offset=0, end_lineno=1, end_col_offset=13)]
    );
    assert r.diag is not None;
    assert compiler_diag_message(r.diag)
        == "nonlocal declaration not allowed at module level";
}

test "compiler_validate: break inside while accepted" {
    r = validate_module_body(
        [
            While(
                `test=Constant(
                    value=PyInt(t="int", val=1),
                    kind=None,
                    lineno=1,
                    col_offset=5,
                    end_lineno=1,
                    end_col_offset=6
                ),
                body=[Break(lineno=2, col_offset=4, end_lineno=2, end_col_offset=9)],
                orelse=[],
                lineno=1,
                col_offset=0,
                end_lineno=2,
                end_col_offset=9
            )
        ]
    );
    assert r.diag is None;
}

test "compiler_validate: parsed return outside function matches compile oracle" {
    assert_validate_rejects_like_compile("return 1\n");
}

test "compiler_validate: parsed break outside loop matches compile oracle" {
    assert_validate_rejects_like_compile("break\n");
}

test "compiler_validate: parsed nonlocal at module matches compile oracle" {
    assert_validate_rejects_like_compile("nonlocal x\n");
}

test "compiler_validate: parsed continue outside loop matches compile oracle" {
    assert_validate_rejects_like_compile("continue\n");
}

test "compiler_validate: parsed yield outside function matches compile oracle" {
    assert_validate_rejects_like_compile("yield 1\n");
}

test "compiler_validate: parsed x=1 module accepted via parser" {
    m = parse_file("x = 1\n", "<t>");
    assert m is not None;
    r = validate_module_body((m as Module).body);
    assert r.diag is None;
}
