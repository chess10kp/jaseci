"""Type-checker tests for narrowing across annotated assignments.

Regression coverage for a flow-narrowing bug: when a name is first bound to
`None` and conditionally re-stored (the widened-union path), the narrowing
engine evaluates the store's call arguments early. That walk used to infer the
RHS of `kid: list[Base] = [...]` without the declared annotation as context,
caching `list[Tok]` on the literal and on every downstream flow node -- so a
later `kid.extend(stmts)` was checked against `Iterable[Tok]` and rejected
(E1053), even though the declared type is `list[Base]`. The fix infers the RHS
of an annotated assignment with the declared type as the expected type, while
unannotated assignments still narrow to the more precise inferred type.
"""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }


"""Type-check a Jac source string and return the emitted error messages."""
def check_errors(src: str) -> list[str] {
    prog = JacProgram();
    prog.compile(
        file_path="annotated_narrowing_src.jac",
        use_str=src,
        options=CompileOptions(default_codespace='server')
    );
    return [str(e) for e in prog.errors_had];
}


test "annotated list decl keeps declared element type under flow narrowing" {
    src = "obj Base { }\n"
    "obj Tok(Base) { }\n"
    "obj Stmt(Base) { }\n"
    "\n"
    "def mk_box(body: list[Stmt], kid: list[Base]) -> Base {\n"
    "    return kid[0];\n"
    "}\n"
    "\n"
    "def make_tok -> Tok {\n"
    "    return Tok();\n"
    "}\n"
    "\n"
    "def make_stmts -> list[Stmt] {\n"
    "    return [Stmt()];\n"
    "}\n"
    "\n"
    "def parse -> (Base | None) {\n"
    "    box = None;\n"
    "    if True {\n"
    "        t1 = make_tok();\n"
    "        t2 = make_tok();\n"
    "        stmts = make_stmts();\n"
    "        kid: list[Base] = [t1, t2];\n"
    "        kid.extend(stmts);\n"
    "        box = mk_box(stmts, kid);\n"
    "    }\n"
    "    return box;\n"
    "}\n";
    errors = check_errors(src);
    assert errors == [] , errors;
}


test "control: unannotated decl still narrows to the precise element type" {
    src = "obj Base { }\n"
    "obj Tok(Base) { }\n"
    "obj Stmt(Base) { }\n"
    "\n"
    "def make_stmts -> list[Stmt] {\n"
    "    return [Stmt()];\n"
    "}\n"
    "\n"
    "def f -> None {\n"
    "    kid = [Tok(), Tok()];\n"
    "    kid.extend(make_stmts());\n"
    "}\n";
    errors = check_errors(src);
    assert any("Iterable[Tok]" in e for e in errors) , errors;
}
