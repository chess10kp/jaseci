"""Focused parser-fidelity coverage for the human P3 backlog."""

import from parser { parse_file }
import from ast_nodes { Module, Expr, Call, Constant, FunctionDef, Try, TryStar, arguments }
import from objects { PyInt, PyStr, PyBytes }

test "trailing keyword spread survives after named keyword" {
    m = parse_file("f(a=1, **d)\n", "<p3-call>");
    assert m is not None;
    call = ((m as Module).body[0] as Expr).value as Call;
    assert len(call.keywords) == 2;
    assert call.keywords[0].arg == "a";
    assert call.keywords[1].arg is None;
}

test "positional-only defaults parse" {
    src = "def f(a, b=2, /):\n    return a + b\n";
    m = parse_file(src, "<p3-posonly>");
    assert m is not None;
    fn = (m as Module).body[0] as FunctionDef;
    assert len(fn.args.posonlyargs) == 2;
    assert len(fn.args.args) == 0;
    assert len(fn.args.defaults) == 1;
    assert isinstance(fn.args.defaults[0], Constant);
    assert isinstance((fn.args.defaults[0] as Constant).value, PyInt);
    assert ((fn.args.defaults[0] as Constant).value as PyInt).val == 2;
}

test "try and except spans end at final body token" {
    src = "try:\n    x = 1\nexcept ValueError:\n    a = 1\nx = 2\n";
    m = parse_file(src, "<p3-try>");
    assert m is not None;
    stmt = (m as Module).body[0] as Try;
    assert stmt.end_lineno == 4 and stmt.end_col_offset == 9;
    assert stmt.handlers[0].end_lineno == 4;
    assert stmt.handlers[0].end_col_offset == 9;
}

test "try-star and except-star spans end at final body token" {
    src = "try:\n    x = 1\nexcept* ValueError:\n    a = 1\nx = 2\n";
    m = parse_file(src, "<p3-trystar>");
    assert m is not None;
    stmt = (m as Module).body[0] as TryStar;
    assert stmt.end_lineno == 4 and stmt.end_col_offset == 9;
    assert stmt.handlers[0].end_lineno == 4;
    assert stmt.handlers[0].end_col_offset == 9;
}

test "multiline def defaults inside parens (functools.wraps shape)" {
    src = "def wraps(wrapped,\n"
    "          assigned = WRAPPER_ASSIGNMENTS,\n"
    "          updated = WRAPPER_UPDATES):\n"
    "    pass\n";
    m = parse_file(src, "<wraps>");
    assert m is not None;
    fn = (m as Module).body[0] as FunctionDef;
    assert fn.name == "wraps";
}

test "keyword-only defaults (namedtuple shape)" {
    src = "def namedtuple(typename, field_names, *, rename=False, defaults=None, module=None):\n"
    "    pass\n";
    m = parse_file(src, "<namedtuple>");
    assert m is not None;
    fn = (m as Module).body[0] as FunctionDef;
    assert fn.name == "namedtuple";
    assert len(fn.args.kwonlyargs) == 3;
}

test "chained attribute subscript store target" {
    src = "a.b['c'] = 1\n";
    m = parse_file(src, "<chain-sub>");
    assert m is not None;
}

test "string escapes decode and bytes retain bytes value" {
    m = parse_file('x = "\\u0041"\ny = b"\\x41"\n', "<p3-literals>");
    assert m is not None;
    string_value = (((m as Module).body[0] as Expr).value as any).value;
    bytes_value = (((m as Module).body[1] as Expr).value as any).value;
    assert isinstance(string_value, PyStr);
    assert (string_value as PyStr).val == "A";
    assert isinstance(bytes_value, PyBytes);
    assert (bytes_value as PyBytes).val == [65];
}
