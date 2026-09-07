"""Focused parser-fidelity coverage for the human P3 backlog."""

import from parser { parse_file }
import from ast_nodes { Module, Expr, Call, Constant, FunctionDef, Try, TryStar, Assign, Subscript, Attribute, JoinedStr, FormattedValue, Name, Return }
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

test "attribute subscript store target parses" {
    m = parse_file("m.attrs = {}\nm.attrs['k'] = 1\n", "<p3-attr-sub-store>");
    assert m is not None;
    body = (m as Module).body;
    assert len(body) == 2;
    assign = body[1] as Assign;
    assert len(assign.targets) == 1;
    sub = assign.targets[0] as Subscript;
    # The store chain must be Subscript(Attribute(Name)) — a plain atom would
    # only ever produce Subscript(Name).
    attr = sub.value as Attribute;
    assert attr.attr == "attrs";
    slice_const = sub.slice as Constant;
    assert (slice_const.value as PyStr).val == "k";
}

test "collections line 31 module-derived store parses" {
    src = "import _collections_abc\nimport sys as _sys\n\n_sys.modules['collections.abc'] = _collections_abc\n";
    m = parse_file(src, "<p3-collections-l31>");
    assert m is not None;
    assign = ((m as Module).body[2]) as Assign;
    sub = assign.targets[0] as Subscript;
    attr = sub.value as Attribute;
    assert attr.attr == "modules";
    assert attr.ctx is not None and sub.ctx is not None;
    slice_const = sub.slice as Constant;
    assert (slice_const.value as PyStr).val == "collections.abc";
}

test "adjacent fstrings with format spec parse" {
    m = parse_file("x = 'q'\nk = 2\ns = (f'{x.a}' f'{k:x}')\n", "<p3-fstring-adj-spec>");
    assert m is not None;
    joined = (((m as Module).body[2] as Expr).value) as JoinedStr;
    assert len(joined.values) == 2;
    first = joined.values[0] as FormattedValue;
    assert (first.value as Attribute).attr == "a";
    second = joined.values[1] as FormattedValue;
    spec = second.format_spec as JoinedStr;
    assert len(spec.values) == 1;
    assert ((spec.values[0] as Constant).value as PyStr).val == "x";
}

test "repr_int f-string return parses" {
    src = "def repr1(self, x, level):\n"
        "    k = 1\n"
        "    max_digits = 4300\n"
        "    return (f'<{x.__class__.__name__} instance with roughly {k} '\n"
        "            f'digits (limit at {max_digits}) at 0x{id(x):x}>')\n";
    m = parse_file(src, "<p3-repr-int>");
    assert m is not None;
    fn = (m as Module).body[0] as FunctionDef;
    ret = fn.body[2] as Return;
    joined = ret.value as JoinedStr;
    for v in joined.values {
        if isinstance(v, Constant) { print("C:" + str((v as Constant).value)); }
        else { print("F"); }
    }
    # Host oracle: JoinedStr with 9 values — Constant('<'), FormattedValue(
    # x.__class__.__name__), Constant(' instance with roughly '), k, Constant(
    # ' digits (limit at '), max_digits, Constant(' at 0x'), id(x) with spec
    # 'x', Constant('>').
    assert len(joined.values) == 9;
    first = joined.values[1] as FormattedValue;
    outer = first.value as Attribute;
    assert outer.attr == "__name__";
    assert (outer.value as Attribute).attr == "__class__";
    digits = joined.values[3] as FormattedValue;
    assert (digits.value as Name).id == "k";
    addr = joined.values[7] as FormattedValue;
    assert addr.format_spec is not None;
    spec = addr.format_spec as JoinedStr;
    assert ((spec.values[0] as Constant).value as PyStr).val == "x";
}

test "string literal at EOF without trailing newline parses" {
    m = parse_file('"""d"""', "<p3-eof-str>");
    assert m is not None;
    m2 = parse_file('x = 1', "<p3-eof-assign>");
    assert m2 is not None;
    m3 = parse_file('"""a\nb"""', "<p3-eof-triple>");
    assert m3 is not None;
}

test "truncated compound header at EOF fails cleanly" {
    # Host CPython: SyntaxError "expected an indented block". The parser must
    # return None (surfaced as a clean SyntaxError by compile_source) — never
    # hang or blow the stack on truncated input.
    assert parse_file("class C:", "<p3-eof-class>") is None;
    assert parse_file("class C:\n", "<p3-eof-class-nl>") is None;
    assert parse_file("def f():", "<p3-eof-def>") is None;
    assert parse_file("if x:", "<p3-eof-if>") is None;
}
