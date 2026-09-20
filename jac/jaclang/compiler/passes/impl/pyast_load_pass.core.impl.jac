impl PyastBuildPass.aug_op_map(tok_dict: dict[str, str], op: Token) -> str {
    op.value += '=';
    for (_key, value) in tok_dict.items() {
        if (value == op.value) {
            break;
        }
    }
    return _key;
}

impl PyastBuildPass.is_canceled -> bool {
    return self.ctx.cancel_requested
        or (self.ctx.cancel_token is not None and self.ctx.cancel_token.is_set());
}

impl PyastBuildPass.convert_to_doc(string: String) -> None {
    val = string.value;
    if val.startswith('"""') or val.startswith("'''") {
        return;
    } elif val.startswith('"') or val.startswith("'") {
        content = val[1:-1];
    } else {
        content = val;
    }

    string.value = f'"""{content}"""';
}

impl PyastBuildPass.operator(tok: Tok, value: str) -> Token {
    return Token(
        orig_src=self.orig_src,
        name=tok,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl PyastBuildPass.extract_with_entry(
    body: list[UniNode], exclude_types: TypeAlias = T
) -> list[(T | ModuleCode)] {
    def gen_mod_code(with_entry_body: list[CodeBlockStmt]) -> ModuleCode {
        return ModuleCode(
            name=None, body=with_entry_body, kid=with_entry_body, doc=None
        );
    }
    extracted: list[(T | ModuleCode)] = [];
    with_entry_body: list[CodeBlockStmt] = [];
    for i in body {
        if isinstance(i, exclude_types)
            and not (isinstance(i, AssertStmt) and not i.is_comptime) {
            if len(with_entry_body) {
                extracted.append(gen_mod_code(with_entry_body));
                with_entry_body = [];
            }
            extracted.append(i);
        } elif isinstance(i, CodeBlockStmt) {
            if (isinstance(i, ExprStmt) and isinstance(i.expr, String)) {
                self.convert_to_doc(i.expr);
            }
            with_entry_body.append(i);
        } else {
            continue;
        }
    }
    if len(with_entry_body) {
        extracted.append(gen_mod_code(with_entry_body));
    }
    return extracted;
}

impl PyastBuildPass._run_impl(ir_in: PythonModuleAst) -> Module {
    py_mod = ir_in.ast;
    if not isinstance(py_mod, py_ast.Module) {
        raise RuntimeError(self.ctx.ice('Expected a Python module AST root'));
    }
    self.module = self.proc_module(py_mod);
    return self.module;
}

impl PyastBuildPass.convert(nd: py_ast.AST) -> UniNode {
    import from jaclang.project.source { pascal_to_snake }
    if self.is_canceled() {
        raise StopIteration;
    }
    if hasattr(self, f"proc_{pascal_to_snake(type(nd).__name__)}") {
        ret = getattr(self, f"proc_{pascal_to_snake(type(nd).__name__)}")(nd);
    } else {
        raise RuntimeError(self.ctx.ice(f"Unknown node type {type(nd).__name__}"));
    }
    return ret;
}

impl PyastBuildPass.nu(nd: T) -> T {
    self.ctx.current_node = nd;
    return nd;
}

impl PyastBuildPass.name_node(
    nd: py_ast.AST,
    value: str,
    name_tok: Tok = Tok.NAME,
    col_end: int = -1,
    col_start: int = -1,
    end_line: int = -1,
    is_kwesc: bool = False
) -> Name {
    return Name(
        orig_src=self.orig_src,
        name=name_tok,
        value=value,
        line=nd.lineno,
        end_line=(nd.end_lineno or nd.lineno) if (end_line == -1) else end_line,
        col_start=nd.col_offset if (col_start == -1) else col_start,
        col_end=(nd.col_offset + len(value)) if (col_end == -1) else col_end,
        pos_start=0,
        pos_end=0,
        is_kwesc=is_kwesc
    );
}

impl PyastBuildPass.postinit -> None {
    self.mod_path = self.module.loc.mod_path;
    self.orig_src = self.module.loc.orig_src;

    self._source_lines = self.orig_src.code.splitlines(keepends=True);
    self.in_type_annotation = False;
    self.in_match_pattern = False;
    self.in_fstring_expr = False;
}

impl PyastBuildPass._get_source_segment(nd: py_ast.AST) -> (str | None) {
    try {
        if (nd.end_lineno is None or nd.end_col_offset is None) {
            return None;
        }
        lineno = nd.lineno - 1;
        end_lineno = nd.end_lineno - 1;
        col_offset = nd.col_offset;
        end_col_offset = nd.end_col_offset;
    } except AttributeError {
        return None;
    }
    lines = self._source_lines;
    if (end_lineno >= len(lines)) {
        return None;
    }
    if (end_lineno == lineno) {
        return lines[lineno].encode()[col_offset:end_col_offset].decode();
    }
    first = lines[lineno].encode()[col_offset:].decode();
    last = lines[end_lineno].encode()[:end_col_offset].decode();
    middle = lines[lineno + 1:end_lineno];
    result_lines = [first] + middle + [last];
    return ''.join(result_lines);
}

impl PyastBuildPass._strip_string_continuations(seg: str) -> str {
    if not ('\\' in seg and '\n' in seg) {
        return seg;
    }
    out: list[str] = [];
    i = 0;
    n = len(seg);
    quote = '';
    triple = False;
    while (i < n) {
        c = seg[i];
        if quote {
            if (c == '\\') {
                out.append(seg[i:i + 2]);
                i += 2;
                continue;
            }
            if (triple and seg[i:i + 3] == (quote * 3)) {
                out.append(quote * 3);
                quote = '';
                i += 3;
                continue;
            }
            if ((not triple) and c == quote) {
                out.append(c);
                quote = '';
                i += 1;
                continue;
            }
            out.append(c);
            i += 1;
            continue;
        }

        if (c == '\\' and (i + 1) < n and seg[i + 1] in '\r\n') {
            i += 1;
            continue;
        }
        if (c == '"' or c == "'") {
            if (seg[i:i + 3] == (c * 3)) {
                triple = True;
                quote = c;
                out.append(c * 3);
                i += 3;
                continue;
            }
            triple = False;
            quote = c;
            out.append(c);
            i += 1;
            continue;
        }
        out.append(c);
        i += 1;
    }
    return ''.join(out);
}

impl PyastBuildPass.run_walk with PythonModuleAst entry {
    self.module = self._run_impl(here);
}
