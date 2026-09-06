# P0.7 parser action helpers (PLAN.md).
#
# Lowers CPython grammar actions (_PyAST_*, _PyPegen_*) into ast_nodes.jac
# objects. Generated parser rules call these helpers; this file is hand-written
# and grows with each grammar profile.

import from objects { PyObj, PyInt, PyBool, PyStr, PyBytes, PyFloat, PyComplex, py_none }
import from ast_nodes {
    ast_node,
    expr,
    mod,
    stmt,
    operator,
    unaryop,
    boolop,
    cmpop,
    expr_context,
    Expression,
    Module,
    Constant,
    Name,
    Load,
    Store,
    Del,
    Attribute,
    Subscript,
    Slice,
    AugAssign,
    Delete,
    BinOp,
    UnaryOp,
    BoolOp,
    Compare,
    Call,
    IfExp,
    Starred,
    Assign,
    AnnAssign,
    Expr,
    Return,
    Pass,
    Tuple,
    Add,
    Sub,
    Mult,
    Div,
    FloorDiv,
    Mod,
    MatMult,
    Pow,
    LShift,
    RShift,
    BitOr,
    BitXor,
    BitAnd,
    USub,
    UAdd,
    Invert,
    Not,
    And,
    Or,
    Eq,
    NotEq,
    Lt,
    LtE,
    Gt,
    GtE,
    Is,
    IsNot,
    In,
    NotIn,
    cmpop,
    keyword,
    Break,
    Continue,
    FunctionDef,
    ClassDef,
    AsyncFunctionDef,
    pattern,
    arguments,
    alias,
    arg,
    comprehension,
    excepthandler,
    match_case,
    type_param,
    withitem,
    MatchOr,
    MatchSingleton,
    ImportFrom,
    JoinedStr,
    FormattedValue,
}
import from peg_runtime { peg_parser, peg_token, peg_has_error, peg_raise_syntax_error }

obj pa_cmpop_expr_pair {
    has cmpop: cmpop,
        expr: expr;
}

obj kv_pair {
    has key: expr,
        value: expr;
}

obj kp_pair {
    has key: expr,
        pattern: pattern;
}

obj keyword_or_starred_node {
    has element: object,
        is_keyword: bool;
}

obj name_default_pair {
    has arg: arg,
        `default: expr | None;
}

obj star_etc_node {
    has vararg: arg | None = None,
        kwonlyargs: list[arg] = [],
        kw_defaults: list[expr | None] = [],
        kwarg: arg | None = None;
}

def pa_extra(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> tuple[int, int, int, int] {
    return (lineno, col_offset, end_lineno, end_col_offset);
}

def pa_name_id(ast_name: expr) -> str {
    if isinstance(ast_name, Name) {
        n = ast_name as Name;
        return n.id;
    }
    return "";
}

def pa_name_from_token(tok: peg_token | None) -> Name | None {
    if tok is None {
        return None;
    }
    return Name(
        id=tok.spelling,
        ctx=Load(),
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def _pa_digit_val(c: str) -> int {
    if c >= "0" and c <= "9" {
        return ord(c) - ord("0");
    }
    return -1;
}

def _strip_underscores(spelling: str) -> str {
    out = "";
    i = 0;
    while i < len(spelling) {
        if spelling[i] != "_" {
            out = out + spelling[i];
        }
        i = i + 1;
    }
    return out;
}

def _pa_digit_val_base(c: str, base: int) -> int {
    d = -1;
    if c >= "0" and c <= "9" {
        d = ord(c) - ord("0");
    } elif base == 16 {
        if c >= "a" and c <= "f" {
            d = ord(c) - ord("a") + 10;
        } elif c >= "A" and c <= "F" {
            d = ord(c) - ord("A") + 10;
        }
    }
    if d < 0 or d >= base {
        return -1;
    }
    return d;
}

def _fold_radix(s: str, start: int, base: int) -> int {
    # Tokenizer-guaranteed valid spellings; a bad digit means a lexer bug.
    n = 0;
    i = start;
    while i < len(s) {
        d = _pa_digit_val_base(s[i], base);
        if d < 0 {
            return -1;
        }
        n = n * base + d;
        i = i + 1;
    }
    return n;
}

def pa_parse_int_spelling(spelling: str) -> int {
    s = _strip_underscores(spelling);
    if len(s) >= 3 and s[0] == "0" and (s[1] == "x" or s[1] == "X") {
        return _fold_radix(s, 2, 16);
    }
    if len(s) >= 3 and s[0] == "0" and (s[1] == "o" or s[1] == "O") {
        return _fold_radix(s, 2, 8);
    }
    if len(s) >= 3 and s[0] == "0" and (s[1] == "b" or s[1] == "B") {
        return _fold_radix(s, 2, 2);
    }
    return _fold_radix(s, 0, 10);
}

def _pa_hex_digit_val(c: str) -> int {
    d = _pa_digit_val(c);
    if d >= 0 {
        return d;
    }
    if c >= "a" and c <= "f" {
        return ord(c) - ord("a") + 10;
    }
    if c >= "A" and c <= "F" {
        return ord(c) - ord("A") + 10;
    }
    return -1;
}

def pa_decode_escape_body(body: str) -> str {
    out = "";
    i = 0;
    while i < len(body) {
        c = body[i];
        if c != "\\" {
            out = out + c;
            i = i + 1;
            continue;
        }
        i = i + 1;
        if i >= len(body) {
            out = out + "\\";
            break;
        }
        e = body[i];
        if e == "n" {
            out = out + "\n";
            i = i + 1;
            continue;
        }
        if e == "t" {
            out = out + "\t";
            i = i + 1;
            continue;
        }
        if e == "r" {
            out = out + "\r";
            i = i + 1;
            continue;
        }
        if e == "\\" {
            out = out + "\\";
            i = i + 1;
            continue;
        }
        if e == "'" {
            out = out + "'";
            i = i + 1;
            continue;
        }
        if e == "\"" {
            out = out + "\"";
            i = i + 1;
            continue;
        }
        if e == "x" or e == "u" or e == "U" {
            width = 2 if e == "x" else (4 if e == "u" else 8);
            if i + width < len(body) {
                value = 0;
                valid = True;
                j = i + 1;
                while j <= i + width {
                    digit = _pa_hex_digit_val(body[j]);
                    if digit < 0 {
                        valid = False;
                        break;
                    }
                    value = value * 16 + digit;
                    j = j + 1;
                }
                if valid {
                    out = out + chr(value);
                    i = i + width + 1;
                    continue;
                }
            }
        }
        out = out + e;
        i = i + 1;
    }
    return out;
}

def pa_decode_bytes_escape_body(body: str, raw: bool) -> list[int] {
    out: list[int] = [];
    i = 0;
    while i < len(body) {
        c = body[i];
        if raw or c != "\\" or i + 1 >= len(body) {
            out.append(ord(c));
            i = i + 1;
            continue;
        }
        e = body[i + 1];
        if e == "n" {
            out.append(10);
            i = i + 2;
            continue;
        }
        if e == "t" {
            out.append(9);
            i = i + 2;
            continue;
        }
        if e == "r" {
            out.append(13);
            i = i + 2;
            continue;
        }
        if e == "b" {
            out.append(8);
            i = i + 2;
            continue;
        }
        if e == "f" {
            out.append(12);
            i = i + 2;
            continue;
        }
        if e == "v" {
            out.append(11);
            i = i + 2;
            continue;
        }
        if e == "a" {
            out.append(7);
            i = i + 2;
            continue;
        }
        if e == "\\" or e == "'" or e == "\"" {
            out.append(ord(e));
            i = i + 2;
            continue;
        }
        if e >= "0" and e <= "7" {
            j = i + 1;
            limit = i + 4 if i + 4 <= len(body) else len(body);
            while j < limit and body[j] >= "0" and body[j] <= "7" {
                j = j + 1;
            }
            value = 0;
            k = i + 1;
            while k < j {
                value = value * 8 + ord(body[k]) - ord("0");
                k = k + 1;
            }
            out.append(value % 256);
            i = j;
            continue;
        }
        if e == "x" and i + 3 < len(body) {
            h1 = _pa_hex_digit_val(body[i + 2]);
            h2 = _pa_hex_digit_val(body[i + 3]);
            if h1 >= 0 and h2 >= 0 {
                out.append(h1 * 16 + h2);
                i = i + 4;
                continue;
            }
        }
        out.append(92);
        out.append(ord(e));
        i = i + 2;
    }
    return out;
}

def pa_decode_string_literal_spelling(spelling: str) -> str | list[int] | None {
    if len(spelling) == 0 {
        return None;
    }
    i = 0;
    raw = False;
    is_bytes = False;
    while i < len(spelling) {
        c = spelling[i];
        if c == "r" or c == "R" {
            raw = True;
            i = i + 1;
            continue;
        }
        if c == "b" or c == "B" {
            is_bytes = True;
            i = i + 1;
            continue;
        }
        if c == "u" or c == "U" or c == "f" or c == "F" {
            i = i + 1;
            continue;
        }
        break;
    }
    if i >= len(spelling) {
        return None;
    }
    quote = spelling[i];
    if quote != "'" and quote != "\"" {
        return None;
    }
    # Delimiter is 1 or 3 quotes (Python has no 2-quote delimiter). `''`/`""`
    # is an EMPTY single-quoted string, not a 2-char opener.
    qlen = 1;
    if i + 2 < len(spelling)
        and spelling[i + 1] == quote
        and spelling[i + 2] == quote {
        qlen = 3;
    }
    start = i + qlen;
    end = len(spelling) - qlen;
    if end < start {
        return None;
    }
    body = spelling[start:end];
    if is_bytes {
        return pa_decode_bytes_escape_body(body, raw);
    }
    if raw {
        return body;
    }
    return pa_decode_escape_body(body);
}

def pa_constant_from_fstring_middle(tok: peg_token | None, raw: bool) -> Constant | None {
    if tok is None {
        return None;
    }
    body = tok.spelling;
    if raw {
        decoded = body;
    } else {
        decoded = pa_decode_escape_body(body);
    }
    return Constant(
        value=PyStr(t="str", val=decoded),
        kind=None,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_constant_from_string(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    decoded = pa_decode_string_literal_spelling(tok.spelling);
    if decoded is None {
        return None;
    }
    value: PyObj;
    if isinstance(decoded, list) {
        value = PyBytes(t="bytes", val=decoded);
    } else {
        value = PyStr(t="str", val=decoded);
    }
    return Constant(
        value=value,
        kind=None,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_concatenate_strings(parts: list[object]) -> expr | None {
    if len(parts) == 0 {
        return None;
    }
    has_fstring = False;
    i = 0;
    while i < len(parts) {
        if isinstance(parts[i], JoinedStr) {
            has_fstring = True;
        }
        i = i + 1;
    }
    if not has_fstring {
        # All-literal concatenation: fold into one Constant.
        if len(parts) == 1 {
            return parts[0] as Constant;
        }
        out = "";
        i = 0;
        while i < len(parts) {
            c = parts[i];
            if not isinstance(c, Constant) {
                return None;
            }
            cc = c as Constant;
            if not isinstance(cc.value, PyStr) {
                return None;
            }
            out = out + (cc.value as PyStr).val;
            i = i + 1;
        }
        first = parts[0] as Constant;
        last = parts[len(parts) - 1] as Constant;
        return Constant(
            value=PyStr(t="str", val=out),
            kind=None,
            lineno=first.lineno,
            col_offset=first.col_offset,
            end_lineno=last.end_lineno,
            end_col_offset=last.end_col_offset
        );
    }
    # Mixed literal/f-string concatenation (CP concatenate_strings semantics):
    # flatten every part into JoinedStr figures -- constants stay literal
    # figures, each f-string contributes its own values in place.
    figures: list[expr] = [];
    i = 0;
    while i < len(parts) {
        c = parts[i];
        if isinstance(c, Constant) {
            figures.append(c as expr);
        } elif isinstance(c, JoinedStr) {
            js = c as JoinedStr;
            vals = js.values if js.values is not None else [];
            j = 0;
            while j < len(vals) {
                figures.append(vals[j]);
                j = j + 1;
            }
        } else {
            return None;
        }
        i = i + 1;
    }
    if len(figures) == 0 {
        return None;
    }
    fpart = parts[0];
    lpart = parts[len(parts) - 1];
    fl: int | None = 0;
    fc: int | None = 0;
    ll: int | None = 0;
    lc: int | None = 0;
    if isinstance(fpart, Constant) {
        fc0 = fpart as Constant;
        fl = fc0.lineno;
        fc = fc0.col_offset;
    } else {
        f0 = fpart as JoinedStr;
        fl = f0.lineno;
        fc = f0.col_offset;
    }
    if isinstance(lpart, Constant) {
        lc0 = lpart as Constant;
        ll = lc0.end_lineno;
        lc = lc0.end_col_offset;
    } else {
        l0 = lpart as JoinedStr;
        ll = l0.end_lineno;
        lc = l0.end_col_offset;
    }
    return JoinedStr(
        values=figures,
        lineno=fl,
        col_offset=fc,
        end_lineno=ll,
        end_col_offset=lc
    );
}

def pa_constant_from_token(tok: peg_token | None) -> Constant | None {
    return pa_constant_from_string(tok);
}

def pa_decoded_constant_from_token(tok: peg_token | None) -> Constant | None {
    return pa_constant_from_fstring_middle(tok, False);
}

def _is_prefixed_int(s: str) -> bool {
    return len(s) >= 3 and s[0] == "0" and (
        s[1] == "x" or s[1] == "X" or
        s[1] == "o" or s[1] == "O" or
        s[1] == "b" or s[1] == "B"
    );
}

def _has_float_marker(s: str) -> bool {
    # Only meaningful for non-prefixed spellings (hex digits include e/E).
    i = 0;
    while i < len(s) {
        c = s[i];
        if c == "." or c == "e" or c == "E" {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def _parse_decimal_float(s: str) -> float {
    # strtod-equivalent for tokenizer-valid non-prefixed spellings
    # (optional sign, digits, optional fraction, optional exponent).
    # NOTE: accumulate-and-scale rounding may differ from correctly-rounded
    # strtod by <=1 ULP on adversarially long literals.
    val = 0.0;
    i = 0;
    neg = False;
    if s[i] == "+" or s[i] == "-" {
        neg = s[i] == "-";
        i = i + 1;
    }
    while i < len(s) and s[i] >= "0" and s[i] <= "9" {
        val = val * 10.0 + (ord(s[i]) - ord("0"));
        i = i + 1;
    }
    if i < len(s) and s[i] == "." {
        i = i + 1;
        scale = 0.1;
        while i < len(s) and s[i] >= "0" and s[i] <= "9" {
            val = val + (ord(s[i]) - ord("0")) * scale;
            scale = scale / 10.0;
            i = i + 1;
        }
    }
    e = 0;
    if i < len(s) and (s[i] == "e" or s[i] == "E") {
        i = i + 1;
        exp_neg = False;
        if i < len(s) and (s[i] == "+" or s[i] == "-") {
            exp_neg = s[i] == "-";
            i = i + 1;
        }
        while i < len(s) and s[i] >= "0" and s[i] <= "9" {
            e = e * 10 + (ord(s[i]) - ord("0"));
            i = i + 1;
        }
        if exp_neg {
            e = -e;
        }
    }
    if e >= 0 {
        k = 0;
        while k < e {
            val = val * 10.0;
            k = k + 1;
        }
    } else {
        k = 0;
        while k > e {
            val = val / 10.0;
            k = k - 1;
        }
    }
    if neg {
        return -val;
    }
    return val;
}

def pa_py_number_from_spelling(spelling: str) -> PyObj {
    # Mirrors CPython pegen number_token: prefixed ints first (they never
    # carry a j suffix or float markers), then imaginary, then float.
    s = _strip_underscores(spelling);
    if _is_prefixed_int(s) {
        return PyInt(t="int", val=pa_parse_int_spelling(s));
    }
    last = s[len(s) - 1];
    if last == "j" or last == "J" {
        body = "";
        i = 0;
        while i < len(s) - 1 {
            body = body + s[i];
            i = i + 1;
        }
        return PyComplex(t="complex", real=0.0, imag=_parse_decimal_float(body));
    }
    if _has_float_marker(s) {
        return PyFloat(t="float", val=_parse_decimal_float(s));
    }
    return PyInt(t="int", val=pa_parse_int_spelling(s));
}

def pa_number_from_token(tok: peg_token | None) -> Constant | None {
    if tok is None {
        return None;
    }
    val = pa_py_number_from_spelling(tok.spelling);
    return Constant(
        value=val,
        kind=None,
        lineno=tok.lineno,
        col_offset=tok.col_offset,
        end_lineno=tok.end_lineno,
        end_col_offset=tok.end_col_offset
    );
}

def pa_constant_none(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=py_none(),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_constant_bool(
    val: bool, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=PyBool(t="bool", val=val),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_match_singleton(
    val: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> MatchSingleton {
    pyval: PyObj;
    if val is True {
        pyval = PyBool(t="bool", val=True);
    } elif val is False {
        pyval = PyBool(t="bool", val=False);
    } else {
        pyval = py_none();
    }
    return MatchSingleton(
        value=pyval,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_pattern_list(patterns: object) -> list[pattern] {
    if patterns is None {
        return [];
    }
    src = patterns as list[pattern | None];
    out: list[pattern] = [];
    i = 0;
    while i < len(src) {
        p = src[i];
        if p is not None {
            out.append(p);
        }
        i = i + 1;
    }
    return out;
}

def pa_ast_expression(body: expr) -> Expression {
    return Expression(body=body);
}

def pa_ast_binop(
    left: expr,
    op: operator,
    right: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> BinOp {
    return BinOp(
        left=left,
        op=op,
        right=right,
        lineno=left.lineno,
        col_offset=left.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_unaryop(
    op: unaryop,
    operand: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> UnaryOp {
    return UnaryOp(
        op=op,
        operand=operand,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_boolop(
    op: boolop,
    values: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> BoolOp {
    start_lineno = lineno;
    start_col = col_offset;
    if len(values) > 0 {
        start_lineno = values[0].lineno;
        start_col = values[0].col_offset;
    }
    return BoolOp(
        op=op,
        values=values,
        lineno=start_lineno,
        col_offset=start_col,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_compare(
    left: expr,
    ops: list[cmpop],
    comparators: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Compare {
    return Compare(
        left=left,
        ops=ops,
        comparators=comparators,
        lineno=left.lineno,
        col_offset=left.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_call(
    func: expr,
    args: list[expr],
    keywords: list[keyword] | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    kws = keywords if keywords is not None else [];
    return Call(
        func=func,
        args=args,
        keywords=kws,
        lineno=func.lineno,
        col_offset=func.col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_starred(
    value: expr, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Starred {
    return Starred(
        value=value,
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_ifexp(
    test_expr: expr,
    body: expr,
    orelse: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> IfExp {
    return IfExp(
        `test=test_expr,
        body=body,
        orelse=orelse,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_singleton_seq(item: object) -> list[object] {
    return [item];
}

def pa_seq_insert_front(head: object, tail: object | None) -> list[object] {
    if tail is None {
        return pa_singleton_seq(head);
    }
    tail_list = tail as list[object];
    out: list[object] = [head];
    i = 0;
    while i < len(tail_list) {
        out.append(tail_list[i]);
        i = i + 1;
    }
    return out;
}


def pa_singleton_seq_expr(item: expr) -> list[expr] {
    return [item];
}

def pa_seq_insert_front_expr(head: expr, tail: list[expr] | None) -> list[expr] {
    if tail is None {
        return pa_singleton_seq_expr(head);
    }
    out: list[expr] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_pattern(item: pattern) -> list[pattern] {
    return [item];
}

def pa_seq_insert_front_pattern(head: pattern, tail: list[pattern] | None) -> list[pattern] {
    if tail is None {
        return pa_singleton_seq_pattern(head);
    }
    out: list[pattern] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_stmt(item: stmt) -> list[stmt] {
    return [item];
}

def pa_seq_insert_front_stmt(head: stmt, tail: list[stmt] | None) -> list[stmt] {
    if tail is None {
        return pa_singleton_seq_stmt(head);
    }
    out: list[stmt] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_alias(item: alias) -> list[alias] {
    return [item];
}

def pa_seq_insert_front_alias(head: alias, tail: list[alias] | None) -> list[alias] {
    if tail is None {
        return pa_singleton_seq_alias(head);
    }
    out: list[alias] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_type_param(item: type_param) -> list[type_param] {
    return [item];
}

def pa_seq_insert_front_type_param(head: type_param, tail: list[type_param] | None) -> list[type_param] {
    if tail is None {
        return pa_singleton_seq_type_param(head);
    }
    out: list[type_param] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_withitem(item: withitem) -> list[withitem] {
    return [item];
}

def pa_seq_insert_front_withitem(head: withitem, tail: list[withitem] | None) -> list[withitem] {
    if tail is None {
        return pa_singleton_seq_withitem(head);
    }
    out: list[withitem] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_arg(item: arg) -> list[arg] {
    return [item];
}

def pa_seq_insert_front_arg(head: arg, tail: list[arg] | None) -> list[arg] {
    if tail is None {
        return pa_singleton_seq_arg(head);
    }
    out: list[arg] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_kw_or_starred(item: keyword_or_starred_node) -> list[keyword_or_starred_node] {
    return [item];
}

def pa_seq_insert_front_kw_or_starred(
    head: keyword_or_starred_node, tail: list[keyword_or_starred_node] | None
) -> list[keyword_or_starred_node] {
    if tail is None {
        return pa_singleton_seq_kw_or_starred(head);
    }
    out: list[keyword_or_starred_node] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_kvpair(item: kv_pair) -> list[kv_pair] {
    return [item];
}

def pa_seq_insert_front_kvpair(
    head: kv_pair, tail: list[kv_pair] | None
) -> list[kv_pair] {
    if tail is None {
        return pa_singleton_seq_kvpair(head);
    }
    out: list[kv_pair] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}

def pa_singleton_seq_kvpattern(item: kp_pair) -> list[kp_pair] {
    return [item];
}

def pa_seq_insert_front_kvpattern(
    head: kp_pair, tail: list[kp_pair] | None
) -> list[kp_pair] {
    if tail is None {
        return pa_singleton_seq_kvpattern(head);
    }
    out: list[kp_pair] = [head];
    i = 0;
    while i < len(tail) {
        out.append(tail[i]);
        i = i + 1;
    }
    return out;
}


def pa_make_cmpop_pair(op: cmpop, rhs: expr) -> pa_cmpop_expr_pair {
    return pa_cmpop_expr_pair(cmpop=op, expr=rhs);
}

def pa_get_cmpops(pairs: list[pa_cmpop_expr_pair]) -> list[cmpop] {
    out: list[cmpop] = [];
    i = 0;
    while i < len(pairs) {
        out.append(pairs[i].cmpop);
        i = i + 1;
    }
    return out;
}

def pa_get_exprs(pairs: list[pa_cmpop_expr_pair]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(pairs) {
        out.append(pairs[i].expr);
        i = i + 1;
    }
    return out;
}

def pa_collect_call_seqs(
    args: list[expr],
    kwargs: object | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    dummy = Name(
        id="",
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
    if kwargs is None {
        return pa_ast_call(
            dummy, args, [], lineno, col_offset, end_lineno, end_col_offset
        );
    }
    if isinstance(kwargs, Call) {
        c = kwargs as Call;
        return pa_ast_call(
            c.func, args, c.keywords, lineno, col_offset, end_lineno, end_col_offset
        );
    }
    kw_list = kwargs as list[object];
    starred = pa_seq_extract_starred_exprs(kw_list);
    keywords = pa_seq_delete_starred_exprs(kw_list);
    merged: list[expr] = args;
    si = 0;
    while si < len(starred) {
        merged.append(starred[si]);
        si = si + 1;
    }
    return pa_ast_call(
        dummy, merged, keywords, lineno, col_offset, end_lineno, end_col_offset
    );
}

def pa_call_from_optional_args(
    func: expr,
    args_expr: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Call {
    args: list[expr] = [];
    keywords: list[keyword] = [];
    if args_expr is not None and isinstance(args_expr, Call) {
        c = args_expr as Call;
        args = c.args;
        keywords = c.keywords;
    }
    return pa_ast_call(
        func, args, keywords, lineno, col_offset, end_lineno, end_col_offset
    );
}

def pa_check(body: object) -> object {
    return body;
}

def pa_stmt_list_or_empty(xs: list[stmt] | None) -> list[stmt] {
    if xs is None {
        return [];
    }
    return xs;
}

def pa_unsupported_action(p: peg_parser, label: str) -> None {
    if peg_has_error(p) {
        return None;
    }
    peg_raise_syntax_error(p, False, f"unsupported grammar action: {label}");
    return None;
}

# ---------------- statement actions (file/exec profile, P0.12 band 2) ----------------
# These lower the straight-line statement grammar actions into ast_nodes.jac
# objects. Locations arrive as the EXTRA quad (start_lineno, start_col_offset,
# end_lineno, end_col_offset). Type comments are disabled (None).

# file -> Module. _PyPegen_make_module wraps the flattened statement list. A
# missing statement list (empty file) yields an empty module body.
def pa_make_module(body: list[stmt] | None) -> Module {
    stmts: list[stmt] = [];
    if body is not None {
        stmts = body;
    }
    return Module(body=stmts, type_ignores=[]);
}

# statements: statement+ -> flatten list[list[stmt]] into list[stmt]. Each
# `statement` result is itself a seq (compound -> singleton, simple_stmts -> the
# ';' separated list). _PyPegen_seq_flatten concatenates them in source order.
def pa_seq_flatten(parts: list[object]) -> list[stmt] {
    out: list[stmt] = [];
    i = 0;
    while i < len(parts) {
        chunk = parts[i];
        if isinstance(chunk, list) {
            inner = chunk as list[object];
            j = 0;
            while j < len(inner) {
                s = inner[j];
                if isinstance(s, stmt) {
                    out.append(s as stmt);
                }
                j = j + 1;
            }
        }
        i = i + 1;
    }
    return out;
}

# target / RHS context switch: _PyPegen_set_expr_context rewrites a Name's ctx.
# Jac values are immutable, so rebuild the Name with the requested context.
def pa_set_context(target: expr, ctx: expr_context) -> expr {
    if isinstance(target, Name) {
        n = target as Name;
        return Name(
            id=n.id,
            ctx=ctx,
            lineno=n.lineno,
            col_offset=n.col_offset,
            end_lineno=n.end_lineno,
            end_col_offset=n.end_col_offset
        );
    }
    if isinstance(target, Attribute) {
        a = target as Attribute;
        return Attribute(
            value=a.value,
            attr=a.attr,
            ctx=ctx,
            lineno=a.lineno,
            col_offset=a.col_offset,
            end_lineno=a.end_lineno,
            end_col_offset=a.end_col_offset
        );
    }
    if isinstance(target, Subscript) {
        s = target as Subscript;
        return Subscript(
            value=s.value,
            slice=s.slice,
            ctx=ctx,
            lineno=s.lineno,
            col_offset=s.col_offset,
            end_lineno=s.end_lineno,
            end_col_offset=s.end_col_offset
        );
    }
    return target;
}

# star_expressions as a statement -> Expr (expression statement).
def pa_ast_expr_stmt(
    value: expr, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Expr {
    return Expr(
        value=value,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# star_targets '=' annotated_rhs -> Assign. NEW_TYPE_COMMENT is lowered to None
# (type comments disabled).
def pa_ast_assign(
    targets: list[expr],
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Assign {
    return Assign(
        targets=targets,
        value=value,
        type_comment=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# NAME ':' expression ['=' rhs] -> AnnAssign. Faithful AST build; codegen for
# annotated assignment lands in a later P0.12 band and fails loud if hit first.
def pa_ast_annassign(
    target: expr,
    annotation: expr,
    value: expr | None,
    simple: int,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> AnnAssign {
    return AnnAssign(
        target=target,
        annotation=annotation,
        value=value,
        simple=simple,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# return [expr] -> Return.
def pa_ast_return(
    value: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Return {
    return Return(
        value=value,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# pass -> Pass.
def pa_ast_pass(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Pass {
    return Pass(
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# tuple literal / target -> Tuple. ctx is Load (RHS) or Store (multi-target).
def pa_ast_tuple(
    elts: list[expr] | None,
    ctx: expr_context,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Tuple {
    return Tuple(
        elts=elts if elts is not None else [],
        ctx=ctx,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_attribute(
    value: expr,
    attr_name: str,
    ctx: expr_context,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Attribute {
    return Attribute(
        value=value,
        attr=attr_name,
        ctx=ctx,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_subscript(
    value: expr,
    slice_expr: expr,
    ctx: expr_context,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Subscript {
    return Subscript(
        value=value,
        slice=slice_expr,
        ctx=ctx,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_slice(
    lower: expr | None,
    upper: expr | None,
    step: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Slice {
    return Slice(
        lower=lower,
        upper=upper,
        step=step,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_augassign(
    target: expr,
    op: operator,
    value: expr,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> AugAssign {
    return AugAssign(
        target=target,
        op=op,
        value=value,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_delete(
    targets: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> Delete {
    return Delete(
        targets=targets,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

# ---------------- full-grammar parser action helpers (Phase 1) ----------------

def pa_ast_break(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Break {
    return Break(
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_ast_continue(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Continue {
    return Continue(
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_constant_from_expr(
    value: expr, lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Constant {
    return Constant(
        value=py_none(),
        kind=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_seq_append_to_end(head: object | None, item: object) -> list[object] {
    if head is None {
        return pa_singleton_seq(item);
    }
    head_list = head as list[object];
    out: list[object] = [];
    i = 0;
    while i < len(head_list) {
        out.append(head_list[i]);
        i = i + 1;
    }
    out.append(item);
    return out;
}

def pa_seq_append_to_end_expr(
    head: list[expr] | None, item: expr
) -> list[expr] {
    if head is None {
        return pa_singleton_seq_expr(item);
    }
    out: list[expr] = [];
    i = 0;
    while i < len(head) {
        out.append(head[i]);
        i = i + 1;
    }
    out.append(item);
    return out;
}

def pa_seq_append_to_end_stmt(
    head: list[stmt] | None, item: stmt
) -> list[stmt] {
    if head is None {
        return pa_singleton_seq_stmt(item);
    }
    out: list[stmt] = [];
    i = 0;
    while i < len(head) {
        out.append(head[i]);
        i = i + 1;
    }
    out.append(item);
    return out;
}

def pa_get_keys(pairs: list[object] | None) -> list[expr] {
    out: list[expr] = [];
    if pairs is None {
        return out;
    }
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kv_pair).key);
        i = i + 1;
    }
    return out;
}

def pa_get_values(pairs: list[object] | None) -> list[expr] {
    out: list[expr] = [];
    if pairs is None {
        return out;
    }
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kv_pair).value);
        i = i + 1;
    }
    return out;
}

def pa_get_patterns(pairs: list[object]) -> list[pattern] {
    out: list[pattern] = [];
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kp_pair).pattern);
        i = i + 1;
    }
    return out;
}

def pa_get_pattern_keys(pairs: list[object]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(pairs) {
        out.append((pairs[i] as kp_pair).key);
        i = i + 1;
    }
    return out;
}

def pa_map_names_to_ids(names: list[expr]) -> list[str] {
    out: list[str] = [];
    i = 0;
    while i < len(names) {
        out.append(pa_name_id(names[i]));
        i = i + 1;
    }
    return out;
}

def pa_seq_count_dots(seq: object) -> int {
    return 0;
}

def pa_body_end_span(body: list[stmt]) -> tuple[int, int] {
    last = body[len(body) - 1];
    end_lineno: int = last.lineno;
    end_col_offset: int = last.col_offset;
    if last.end_lineno is not None {
        end_lineno = last.end_lineno as int;
    }
    if last.end_col_offset is not None {
        end_col_offset = last.end_col_offset as int;
    }
    return (end_lineno, end_col_offset);
}

def pa_empty_arguments -> arguments {
    return arguments(
        posonlyargs=[],
        args=[],
        vararg=None,
        kwonlyargs=[],
        kw_defaults=[],
        kwarg=None,
        defaults=[]
    );
}

def pa_args_from_list(seq: object | None) -> list[arg] {
    if seq is None {
        return [];
    }
    out: list[arg] = [];
    raw = seq as list[object];
    i = 0;
    while i < len(raw) {
        out.append(raw[i] as arg);
        i = i + 1;
    }
    return out;
}

def pa_append_args_from_pairs(
    args: list[arg], defaults: list[expr], pairs: object | None
) -> tuple[list[arg], list[expr]] {
    if pairs is None {
        return (args, defaults);
    }
    raw = pairs as list[object];
    if len(raw) == 0 {
        return (args, defaults);
    }
    i = 0;
    while i < len(raw) {
        pair = raw[i] as name_default_pair;
        args.append(pair.arg);
        if pair.`default is not None {
            defaults.append(pair.`default as expr);
        }
        i = i + 1;
    }
    return (args, defaults);
}

def pa_make_arguments(
    slash_no_default: object,
    slash_with_default: object,
    plain_names: object,
    names_with_default: object,
    star_etc: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> arguments {
    posonlyargs = pa_args_from_list(slash_no_default);
    defaults: list[expr] = [];
    if slash_with_default is not None {
        split = slash_with_default as tuple;
        posonlyargs = pa_args_from_list(split[0]);
        (posonlyargs, defaults) = pa_append_args_from_pairs(
            posonlyargs, defaults, split[1]
        );
    }
    args = pa_args_from_list(plain_names);
    (args, defaults) = pa_append_args_from_pairs(args, defaults, names_with_default);
    vararg: arg | None = None;
    kwonlyargs: list[arg] = [];
    kw_defaults: list[expr | None] = [];
    kwarg: arg | None = None;
    if star_etc is not None {
        se = star_etc as star_etc_node;
        vararg = se.vararg;
        kwonlyargs = se.kwonlyargs;
        kw_defaults = se.kw_defaults;
        kwarg = se.kwarg;
    }
    return arguments(
        posonlyargs=posonlyargs,
        args=args,
        vararg=vararg,
        kwonlyargs=kwonlyargs,
        kw_defaults=kw_defaults,
        kwarg=kwarg,
        defaults=defaults
    );
}

def pa_dummy_name(
    lineno: int, col_offset: int, end_lineno: int, end_col_offset: int
) -> Name {
    return Name(
        id="_",
        ctx=Load(),
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_interactive_exit(p: peg_parser) -> list[stmt] {
    return [];
}

def pa_aug_op(op: operator) -> operator {
    return op;
}

# arguments rule returns a dummy Call from pa_collect_call_seqs; peel args/keywords.
def pa_call_args(`node: expr) -> list[expr] {
    if `node is None {
        return [];
    }
    if isinstance(`node, Call) {
        return (`node as Call).args;
    }
    return [];
}

def pa_call_keywords(`node: expr) -> list[keyword] {
    if `node is None {
        return [];
    }
    if isinstance(`node, Call) {
        return (`node as Call).keywords;
    }
    return [];
}

def pa_comp_field(`node: object, field: str) -> expr {
    pair = `node as kv_pair;
    if field == "key" {
        return pair.key;
    }
    return pair.value;
}

def pa_seq_first(seq: list[object]) -> expr | None {
    return None;
}

def pa_seq_last(seq: list[object]) -> expr | None {
    return None;
}

def pa_seq_len(seq: list[object]) -> int {
    return len(seq);
}

def pa_seq_get(seq: list[object], index: int) -> object | None {
    return None;
}

def pa_or_pattern_singleton(
    patterns: list[pattern],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> pattern {
    return MatchOr(
        patterns=patterns,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_err_occurred(p: peg_parser) -> bool {
    return peg_has_error(p);
}

def pa_expr_lineno(`node: expr) -> int {
    return `node.lineno;
}

def pa_expr_end_col_offset(`node: expr) -> int {
    v = `node.end_col_offset;
    if v is not None {
        return v as int;
    }
    return `node.col_offset;
}

def pa_expr_end_lineno(`node: expr) -> int {
    v = `node.end_lineno;
    if v is not None {
        return v as int;
    }
    return `node.lineno;
}

def pa_raise_syntax(p: peg_parser, on_next: bool, message: str) -> None {
    if peg_has_error(p) {
        return None;
    }
    peg_raise_syntax_error(p, on_next, message);
    return None;
}

def pa_raise_syntax_known_expr(
    p: peg_parser, on_next: bool, `node: object | None, message: str
) -> None {
    return pa_raise_syntax(p, on_next, message);
}

def pa_raise_syntax_known_range(
    p: peg_parser, on_next: bool, a: object | None, b: object | None, message: str
) -> None {
    return pa_raise_syntax(p, on_next, message);
}

def pa_raise_invalid_target(p: peg_parser, kind: object, `node: object | None) -> None {
    return pa_raise_syntax(p, False, "invalid assignment target");
}

def pa_raise_type_param_error(colon: object, `node: expr, is_tuple: bool) -> None {
    return None;
}

def pa_raise_kvpair_error(p: peg_parser, `node: expr) -> None {
    return pa_raise_syntax(p, False, "':' expected after dictionary key");
}

def pa_check_legacy_stmt_or_raise(p: peg_parser, a: object, b: object) -> None {
    return None;
}

def pa_checked_future_import(
    module: object,
    names: object,
    level: object,
    lineno: int,
    col_offset: int,
    end_lineno: int | None,
    end_col_offset: int | None
) -> ImportFrom {
    mod: str | None = None;
    if isinstance(module, str) {
        mod = module as str;
    }
    lvl: int | None = None;
    if isinstance(level, int) {
        lvl = level as int;
    }
    alist: list[alias] = [];
    if isinstance(names, list) {
        alist = names as list[alias];
    }
    return ImportFrom(
        module=mod,
        names=alist,
        level=lvl,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_nonparen_genexp_in_call(a: object, b: object) -> object {
    return None;
}

def pa_arguments_parsing_error(`node: object) -> object {
    return None;
}

def pa_check_legacy_stmt(p: peg_parser, `node: object) -> bool {
    return False;
}

def pa_concatenate_tstrings(parts: list[object]) -> expr | None {
    return None;
}

def pa_ensure_imaginary(`node: expr) -> expr {
    return `node;
}

def pa_ensure_real(`node: expr) -> expr {
    return `node;
}

def pa_get_expr_name(`node: expr) -> str {
    return "";
}

def pa_get_last_comprehension_item(`node: object) -> object {
    return None;
}

def pa_join_names_with_dot(a: expr, b: expr) -> expr {
    return a;
}

def pa_join_sequences(a: list[object], b: list[object]) -> list[object] {
    out: list[object] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_join_sequences_kw_or_starred(
    a: list[keyword_or_starred_node], b: list[keyword_or_starred_node]
) -> list[keyword_or_starred_node] {
    out: list[keyword_or_starred_node] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_join_sequences_expr(a: list[expr], b: list[expr]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_join_sequences_stmt(a: list[stmt], b: list[stmt]) -> list[stmt] {
    out: list[stmt] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_join_sequences_alias(a: list[alias], b: list[alias]) -> list[alias] {
    out: list[alias] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_join_sequences_pattern(a: list[pattern], b: list[pattern]) -> list[pattern] {
    out: list[pattern] = [];
    i = 0;
    while i < len(a) {
        out.append(a[i]);
        i = i + 1;
    }
    i = 0;
    while i < len(b) {
        out.append(b[i]);
        i = i + 1;
    }
    return out;
}

def pa_alias_for_star(
    lineno: int, col_offset: int, end_lineno: int | None, end_col_offset: int | None
) -> alias | None {
    return alias(
        name="*",
        asname=None,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
}

def pa_add_type_comment_to_arg(arg: arg, comment: object) -> arg {
    return arg;
}

def pa_seq_number_of_starred_exprs(seq: list[object]) -> int {
    n = 0;
    i = 0;
    while i < len(seq) {
        k = seq[i] as keyword_or_starred_node;
        if not k.is_keyword {
            n = n + 1;
        }
        i = i + 1;
    }
    return n;
}

def pa_seq_delete_starred_exprs(seq: list[object]) -> list[keyword] {
    new_len = len(seq) - pa_seq_number_of_starred_exprs(seq);
    if new_len == 0 {
        return [];
    }
    out: list[keyword] = [];
    i = 0;
    while i < len(seq) {
        k = seq[i] as keyword_or_starred_node;
        if k.is_keyword {
            out.append(k.element as keyword);
        }
        i = i + 1;
    }
    return out;
}

def pa_seq_extract_starred_exprs(seq: list[object]) -> list[expr] {
    new_len = pa_seq_number_of_starred_exprs(seq);
    if new_len == 0 {
        return [];
    }
    out: list[expr] = [];
    i = 0;
    while i < len(seq) {
        k = seq[i] as keyword_or_starred_node;
        if not k.is_keyword {
            out.append(k.element as expr);
        }
        i = i + 1;
    }
    return out;
}

def pa_setup_full_format_spec(
    colon: peg_token,
    spec: list[expr],
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    if colon is None {
        return None;
    }
    non_empty: list[expr] = [];
    i = 0;
    while i < len(spec) {
        item = spec[i];
        if isinstance(item, Constant) {
            c = item as Constant;
            if isinstance(c.value, PyStr) and len((c.value as PyStr).val) == 0 {
                i = i + 1;
                continue;
            }
        }
        non_empty.append(item);
        i = i + 1;
    }
    if len(non_empty) == 0 {
        return JoinedStr(
            values=[],
            lineno=lineno,
            col_offset=col_offset,
            end_lineno=end_lineno,
            end_col_offset=end_col_offset
        );
    }
    if len(non_empty) == 1 and isinstance(non_empty[0], Constant) {
        return JoinedStr(
            values=non_empty,
            lineno=lineno,
            col_offset=col_offset,
            end_lineno=end_lineno,
            end_col_offset=end_col_offset
        );
    }
    joined = pa_concatenate_strings(non_empty);
    if joined is None {
        return None;
    }
    if isinstance(joined, Constant) {
        return JoinedStr(
            values=[joined],
            lineno=lineno,
            col_offset=col_offset,
            end_lineno=end_lineno,
            end_col_offset=end_col_offset
        );
    }
    return joined;
}

def pa_check_fstring_conversion(conv_token: peg_token, conv: Name) -> Name | None {
    if conv_token.lineno != conv.lineno or conv_token.end_col_offset != conv.col_offset {
        return None;
    }
    if len(conv.id) != 1 {
        return None;
    }
    ch = conv.id[0];
    if ch != "s" and ch != "r" and ch != "a" {
        return None;
    }
    return conv;
}

def _fstring_prefix_is_raw(start: peg_token) -> bool {
    s = start.spelling;
    i = 0;
    while i < len(s) {
        c = s[i];
        if c == "r" or c == "R" {
            return True;
        }
        i = i + 1;
    }
    return False;
}

def _fstring_debug_prefix(expression: expr) -> str {
    if isinstance(expression, Name) {
        return (expression as Name).id + "=";
    }
    return "=";
}

def _interpolation_conversion(
    debug_expr: object,
    conversion: object,
    format: object
) -> int {
    if conversion is not None {
        conv = conversion as Name;
        return ord(conv.id[0]);
    }
    if debug_expr is not None and format is None {
        return ord("r");
    }
    return -1;
}

def pa_resize_fstring_parts(start: peg_token, parts: list[expr]) -> list[expr] {
    out: list[expr] = [];
    i = 0;
    while i < len(parts) {
        item = parts[i];
        if isinstance(item, JoinedStr) {
            js = item as JoinedStr;
            vals = js.values if js.values is not None else [];
            if len(vals) == 2 {
                out.append(vals[0]);
                out.append(vals[1]);
            } else {
                out.append(item);
            }
            i = i + 1;
            continue;
        }
        if isinstance(item, Constant) {
            c = item as Constant;
            if isinstance(c.value, PyStr) and len((c.value as PyStr).val) == 0 {
                i = i + 1;
                continue;
            }
        }
        out.append(item);
        i = i + 1;
    }
    return out;
}

def pa_function_def_decorators(decs: list[expr], stmt: stmt) -> stmt {
    if isinstance(stmt, FunctionDef) {
        fd = stmt as FunctionDef;
        return FunctionDef(
            name=fd.name,
            args=fd.args,
            body=fd.body,
            decorator_list=decs,
            returns=fd.returns,
            type_comment=fd.type_comment,
            type_params=fd.type_params,
            lineno=fd.lineno,
            col_offset=fd.col_offset,
            end_lineno=fd.end_lineno,
            end_col_offset=fd.end_col_offset
        );
    }
    if isinstance(stmt, AsyncFunctionDef) {
        afd = stmt as AsyncFunctionDef;
        return AsyncFunctionDef(
            name=afd.name,
            args=afd.args,
            body=afd.body,
            decorator_list=decs,
            returns=afd.returns,
            type_comment=afd.type_comment,
            type_params=afd.type_params,
            lineno=afd.lineno,
            col_offset=afd.col_offset,
            end_lineno=afd.end_lineno,
            end_col_offset=afd.end_col_offset
        );
    }
    return stmt;
}

def pa_class_def_decorators(decs: list[expr], stmt: stmt) -> stmt {
    # Mirrors _PyPegen_class_def_decorators: attach the decorators to the
    # ClassDef produced by class_def_raw. Node spans stay anchored on the
    # `class` keyword (CPython never extends them over the decorator lines).
    if isinstance(stmt, ClassDef) {
        cd = stmt as ClassDef;
        return ClassDef(
            name=cd.name,
            bases=cd.bases,
            keywords=cd.keywords,
            body=cd.body,
            decorator_list=decs,
            type_params=cd.type_params,
            lineno=cd.lineno,
            col_offset=cd.col_offset,
            end_lineno=cd.end_lineno,
            end_col_offset=cd.end_col_offset
        );
    }
    return stmt;
}

def pa_key_value_pair(
    key: object | None,
    value: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> kv_pair {
    return kv_pair(key=key as expr, value=value as expr);
}

def pa_key_pattern_pair(
    key: expr,
    pat: pattern,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> kp_pair {
    return kp_pair(key=key, pattern=pat);
}

def pa_name_default_pair(
    arg: arg,
    `default: expr | None,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> name_default_pair {
    return name_default_pair(arg=arg, `default=`default);
}

def pa_keyword_or_starred(
    element: object,
    is_keyword: int,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> keyword_or_starred_node {
    return keyword_or_starred_node(element=element, is_keyword=is_keyword != 0);
}

def pa_star_etc(
    a: object,
    b: object,
    c: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> star_etc_node | None {
    if a is None and b is None and c is None {
        return None;
    }
    vararg: arg | None = None;
    if a is not None {
        vararg = a as arg;
    }
    kwonlyargs: list[arg] = [];
    kw_defaults: list[expr | None] = [];
    if b is not None {
        raw = b as list[object];
        pi = 0;
        while pi < len(raw) {
            pair = raw[pi] as name_default_pair;
            kwonlyargs.append(pair.arg);
            kw_defaults.append(pair.`default);
            pi = pi + 1;
        }
    }
    kwarg: arg | None = None;
    if c is not None {
        kwarg = c as arg;
    }
    return star_etc_node(
        vararg=vararg, kwonlyargs=kwonlyargs, kw_defaults=kw_defaults, kwarg=kwarg
    );
}

def pa_slash_with_default(
    a: object,
    b: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> object {
    return (a, b);
}

def pa_joined_str(
    a: object,
    b: list[expr],
    c: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    start = a as peg_token;
    end = c as peg_token;
    vals = pa_resize_fstring_parts(start, b);
    return JoinedStr(
        values=vals,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end.end_lineno,
        end_col_offset=end.end_col_offset
    );
}

def pa_template_str(
    a: object,
    b: list[expr],
    c: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return None;
}

def pa_formatted_value(
    a: object,
    b: object,
    c: object,
    d: object,
    e: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    expression = a as expr;
    debug_expr = b;
    conversion = c;
    format = d;
    closing_brace = e as peg_token;
    conv_val = _interpolation_conversion(debug_expr, conversion, format);
    format_spec: expr | None = None;
    if format is not None {
        format_spec = format as expr;
    }
    fv = FormattedValue(
        value=expression,
        conversion=conv_val,
        format_spec=format_spec,
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=end_lineno,
        end_col_offset=end_col_offset
    );
    if debug_expr is None {
        return fv;
    }
    debug_end_lineno = end_lineno;
    debug_end_col = end_col_offset;
    if conversion is not None {
        conv = conversion as Name;
        debug_end_lineno = conv.lineno;
        debug_end_col = conv.col_offset;
    } elif format is not None {
        if isinstance(format, JoinedStr) {
            fs = format as JoinedStr;
            debug_end_lineno = fs.lineno;
            debug_end_col = fs.col_offset + 1;
        }
    } else {
        debug_end_lineno = closing_brace.end_lineno;
        debug_end_col = closing_brace.end_col_offset;
    }
    dbg_const = Constant(
        value=PyStr(t="str", val=_fstring_debug_prefix(expression)),
        kind=None,
        lineno=lineno,
        col_offset=col_offset + 1,
        end_lineno=debug_end_lineno,
        end_col_offset=debug_end_col - 1
    );
    return JoinedStr(
        values=[dbg_const, fv],
        lineno=lineno,
        col_offset=col_offset,
        end_lineno=debug_end_lineno,
        end_col_offset=debug_end_col
    );
}

def pa_interpolation(
    a: object,
    b: object,
    c: object,
    d: object,
    e: object,
    lineno: int,
    col_offset: int,
    end_lineno: int,
    end_col_offset: int
) -> expr | None {
    return None;
}