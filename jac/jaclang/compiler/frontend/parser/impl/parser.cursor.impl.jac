import from jaclang.compiler.frontend.constant {
    Tokens as Tok,
    SymbolAccess,
    SymbolType
}


impl Parser.current -> LexToken {
    if self.pos < self._tokens_len {
        return self.tokens[self.pos];
    }
    return self.tokens[-1];
}

impl Parser.peek(offset: int = 1) -> LexToken {
    idx = self.pos + offset;
    if idx < self._tokens_len {
        return self.tokens[idx];
    }
    return self.tokens[-1];
}

impl Parser.advance -> LexToken {
    tok = self.current();
    if self.pos < self._tokens_len - 1 {
        self.pos += 1;
    }
    return tok;
}

impl Parser.previous -> LexToken {
    if self.pos > 0 {
        return self.tokens[self.pos - 1];
    }
    return self.tokens[0];
}

impl Parser.at_end -> bool {
    return self.current().kind == TokenKind.EOF;
}

impl Parser.check(kind: TokenKind) -> bool {
    return self.current().kind == kind;
}

impl Parser.check_any(*kinds: TokenKind) -> bool {
    return self.current().kind in kinds;
}

impl Parser.check_peek(kind: TokenKind) -> bool {
    return self.peek().kind == kind;
}

impl Parser.check_peek_any(*kinds: TokenKind) -> bool {
    return self.peek().kind in kinds;
}

impl Parser.postinit{
    self.source = Source(self.source_code, self.file_path);
    self._tokens_len = len(self.tokens);
}

impl Parser.match_tok(kind: TokenKind) -> LexToken | None {
    if self.check(kind) {
        return self.advance();
    }
    return None;
}

impl Parser.match_any(*kinds: TokenKind) -> LexToken | None {
    if self.current().kind in kinds {
        return self.advance();
    }
    return None;
}

impl Parser.expect_any(*kinds: TokenKind) -> LexToken {
    if self.current().kind in kinds {
        return self.advance();
    }
    expected = " | ".join([k.value for k in kinds]);
    self.emit_diag(
        f"Expected '{expected}', got '{self.current().kind.value}'", "E0001"
    );
    return self.advance();
}

impl Parser.expect(kind: TokenKind) -> LexToken {
    if self.check(kind) {
        return self.advance();
    }

    if kind
        in (
            TokenKind.RPAREN,
            TokenKind.RBRACE,
            TokenKind.RSQUARE,
            TokenKind.SEMI,
            TokenKind.COMMA
        ) {
        self.emit_diag(f"Missing '{kind.value}'", "E0002");
    } else {
        self.emit_diag(
            f"Expected '{kind.value}', got '{self.current().kind.value}'", "E0001"
        );
        return self.advance();
    }
    return self.current();
}

impl Parser.consume_uni(kind: TokenKind, value: str | None = None) -> Token {
    tok = self.expect(kind);
    if value is not None and tok.value != value {
        self.emit_diag(f"Expected '{value}', got '{tok.value}'", "E0001", loc=tok.loc);
    }
    return self.make_uni_token(tok);
}

impl Parser.error(message: str) {
    self.error_count += 1;
    self.diags.append(
        SrcDiag(message=message, code_str="", loc=self.current().loc, is_error=True)
    );
}

impl Parser.emit_diag(
    message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
) {
    sloc = loc if loc is not None else self.current().loc;
    self.error_count += 1;
    self.diags.append(
        SrcDiag(message=message, code_str=code_str, loc=sloc, is_error=True, help=help)
    );
}

impl Parser.emit_warn(
    message: str, code_str: str, loc: SourceLoc | None = None, help: str = ""
) {
    sloc = loc if loc is not None else self.current().loc;
    self.diags.append(
        SrcDiag(message=message, code_str=code_str, loc=sloc, is_error=False, help=help)
    );
}

impl Parser.check_name -> bool {
    return self.check(TokenKind.NAME) or self.check(TokenKind.KWESC_NAME);
}

impl Parser.is_name_usable_token -> bool {
    if self.check_any(TokenKind.KW_ROOT, TokenKind.KW_SUPER) {
        return False;
    }
    return is_special_var_kind(self.current().kind) or self.is_builtin_type_token();
}

impl Parser.is_keyword_token -> bool {
    return is_reserved_kind(self.current().kind);
}

impl Parser.is_builtin_type_token -> bool {
    return is_builtin_type_kind(self.current().kind);
}

impl Parser.expect_name(context: str = "identifier") -> LexToken {
    if self.check_name() {
        return self.advance();
    }
    if self.is_name_usable_token() {
        return self.advance();
    }
    if self.is_keyword_token() {
        kw = self.current().value;
        self.emit_diag(
            f"'{kw}' is a keyword and cannot be used as a {context} name", "E0013"
        );
        return self.advance();
    }
    self.emit_diag(f"Expected identifier, got '{self.current().kind.value}'", "E0003");
    return self.current();
}

impl Parser.make_uni_token(tok: LexToken) -> Token {
    tok_name: str = TOKEN_KIND_TO_TOK[tok.kind]
        if tok.kind in TOKEN_KIND_TO_TOK
        else tok.kind.value;
    return Token(
        orig_src=self.source,
        name=tok_name,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_name(tok: LexToken, is_enum_stmt: bool = False) -> Name {
    val = tok.value;
    kwesc = False;
    if val.startswith("`") {
        val = val[1:];
        kwesc = True;
    } elif tok.kind == TokenKind.KWESC_NAME {
        kwesc = True;
    }
    return Name(
        orig_src=self.source,
        name=Tok.NAME.value,
        value=val,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end,
        is_enum_stmt=is_enum_stmt,
        is_kwesc=kwesc
    );
}

impl Parser.make_special_name(tok: LexToken) -> Name {
    tok_name: str = TOKEN_KIND_TO_TOK[tok.kind]
        if tok.kind in TOKEN_KIND_TO_TOK
        else tok.kind.value;
    return Name(
        orig_src=self.source,
        name=tok_name,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end,
        is_enum_stmt=False
    );
}

impl Parser.make_name_or_special(tok: LexToken) -> Name {
    if tok.kind == TokenKind.NAME or tok.kind == TokenKind.KWESC_NAME {
        return self.make_name(tok);
    }
    return self.make_special_name(tok);
}

impl Parser.parse_access_tag -> SubTag | None {
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            access_tok = self.expect_any(
                TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT
            );
            return SubTag(
                tag=(at := self.make_uni_token(access_tok)), kid=[colon_uni, at]
            );
        }
    }
    return None;
}

impl Parser.make_string(tok: LexToken) -> String {
    return String(
        orig_src=self.source,
        name=Tok.STRING.value,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_string_from_value(value: str) -> String {
    return String(
        orig_src=self.source,
        name=Tok.STRING.value,
        value=value,
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl Parser.make_int(tok: LexToken) -> Int {
    return Int(
        orig_src=self.source,
        name=Tok.INT.value,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_float(tok: LexToken) -> Float {
    return Float(
        orig_src=self.source,
        name=Tok.FLOAT.value,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_bool(tok: LexToken) -> Bool {
    return Bool(
        orig_src=self.source,
        name=Tok.BOOL.value,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_null(tok: LexToken) -> Null {
    return Null(
        orig_src=self.source,
        name=Tok.NULL.value,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_ellipsis(tok: LexToken) -> EllipsisLit {
    return EllipsisLit(
        orig_src=self.source,
        name=Tok.ELLIPSIS.value,
        value=tok.value,
        line=tok.loc.line,
        end_line=tok.loc.end_line,
        col_start=tok.loc.col_start,
        col_end=tok.loc.col_end,
        pos_start=tok.loc.pos_start,
        pos_end=tok.loc.pos_end
    );
}

impl Parser.make_semi -> Semi {
    prev = self.previous();
    return Semi(
        orig_src=self.source,
        name=Tok.SEMI.value,
        value=";",
        line=prev.loc.line,
        end_line=prev.loc.end_line,
        col_start=prev.loc.col_start,
        col_end=prev.loc.col_end,
        pos_start=prev.loc.pos_start,
        pos_end=prev.loc.pos_end
    );
}

impl Parser.synchronize{
    self.advance();
    while not self.at_end() {
        if self.check_any(
            TokenKind.KW_IF,
            TokenKind.KW_WHILE,
            TokenKind.KW_FOREVER,
            TokenKind.KW_FOR,
            TokenKind.KW_DEF,
            TokenKind.KW_CAN,
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS,
            TokenKind.KW_ENUM,
            TokenKind.KW_IMPORT,
            TokenKind.KW_INCLUDE,
            TokenKind.KW_RETURN,
            TokenKind.KW_TEST,
            TokenKind.KW_GLOBAL,
            TokenKind.KW_IMPL,
            TokenKind.KW_ASYNC,
            TokenKind.KW_WITH,
            TokenKind.KW_TRY,
            TokenKind.KW_PUB,
            TokenKind.KW_PRIV,
            TokenKind.KW_PROT,
            TokenKind.DECOR_OP,
            TokenKind.RBRACE,
            TokenKind.SEMI
        ) {
            return;
        }
        self.advance();
    }
}

impl Parser.parse -> Module {
    self._tokens_len = len(self.tokens);
    return self.parse_module();
}

impl Parser.parse_module -> Module {
    doc: String | None = None;
    body: list[ElementStmt | EmptyToken] = [];
    terminals: list[Token] = [];
    for tok in self.tokens {
        terminals.append(self.make_uni_token(tok));
    }
    if self.check(TokenKind.STRING) {
        tok = self.expect(TokenKind.STRING);
        doc = self.make_string(tok);
    }
    while not self.at_end() {
        before = self.pos;
        stmt = self.parse_element_stmt();
        if stmt is not None {
            body.append(stmt);
        }

        if self.pos == before and not self.at_end() {
            self.advance();
        }
    }
    kid: list[UniNode] = [];
    if doc {
        kid.append(doc);
    }
    kid.extend(body);
    if len(kid) == 0 {
        kid.append(EmptyToken());
    }
    mod_name = self.file_path;
    if mod_name {
        while mod_name and (mod_name.endswith("/") or mod_name.endswith("\\")) {
            mod_name = mod_name[:-1];
        }
        slash = mod_name.rfind("/");
        bslash = mod_name.rfind("\\");
        cut = slash if slash > bslash else bslash;
        base = mod_name[cut + 1:];
        if base.endswith(".jac") {
            mod_name = base[:-4];
        } else {
            dot = base.rfind(".");
            mod_name = base[:dot] if dot > 0 else base;
        }
    }
    module = Module(
        source=self.source,
        name=mod_name,
        doc=doc,
        body=body,
        terminals=terminals,
        kid=kid
    );
    node_list: list[UniNode] = [];
    seen: dict[int, bool] = {};
    walk: list[UniNode] = [module];
    while walk {
        nd = walk.pop();
        nid = id(nd);
        if nid not in seen {
            seen[nid] = True;
            node_list.append(nd);
            for child in nd.kid {
                walk.append(child);
            }
        }
    }
    module._in_mod_nodes = node_list;
    return module;
}

impl Parser.parse_expression(allow_cast: bool = True) -> Expr {
    if self.check(TokenKind.KW_LAMBDA) {
        return self.parse_lambda_expr();
    }

    expr = self.parse_concurrent_expr(allow_cast);
    if self._check_js_arrow_fault() {
        expr = self._recover_js_arrow_fault(expr);
    }
    if self.match_tok(TokenKind.KW_IF) {
        if_uni = self.make_uni_token(self.previous());
        condition = self.parse_expression(allow_cast);
        else_uni = self.consume_uni(TokenKind.KW_ELSE);
        else_value = self.parse_expression(allow_cast);
        cond_cfg = CfgExpr(expr=condition, kid=[condition]);
        val_cfg = CfgExpr(expr=expr, kid=[expr]);
        else_cfg = CfgExpr(expr=else_value, kid=[else_value]);
        return IfElseExpr(
            condition=cond_cfg,
            value=val_cfg,
            else_value=else_cfg,
            kid=[val_cfg, if_uni, cond_cfg, else_uni, else_cfg]
        );
    }
    return expr;
}

impl Parser._check_js_arrow_fault -> bool {
    if not self.check(TokenKind.EQ) {
        return False;
    }
    nxt = self.peek();
    if nxt.kind != TokenKind.GT {
        return False;
    }
    return self.current().loc.pos_end == nxt.loc.pos_start;
}

impl Parser._recover_removed_marker -> ElementStmt | EmptyToken | None {
    self.error(
        f"'{self.current().value}' placement markers were removed: "
            + "placement is inferred (override via [placement.pins] in "
            + "jac.toml; a service is an app: [apps.<name>] kind = \"service\"). "
            + "Run 'jac fix placement' to migrate this file."
    );
    self.advance();
    return self.parse_element_stmt();
}

impl Parser._recover_js_arrow_fault(left: Expr) -> Expr {
    eq_tok = self.advance();
    gt_tok = self.advance();

    _arrow_span = SourceLoc(
        file_path=eq_tok.loc.file_path,
        line=eq_tok.loc.line,
        end_line=gt_tok.loc.end_line,
        col_start=eq_tok.loc.col_start,
        col_end=gt_tok.loc.col_end,
        pos_start=eq_tok.loc.pos_start,
        pos_end=gt_tok.loc.pos_end
    );
    self.emit_diag(
        "JavaScript arrow function syntax ('=>') is not supported in Jac",
        "E0025",
        loc=_arrow_span,
        help="Use Jac lambda syntax instead: 'lambda (e: ChangeEvent) { ... }' or 'lambda (x: int) { x + 1; }'."
    );
    if self.check(TokenKind.LBRACE) {
        self.advance();
        self.parse_code_block_stmts();
        if self.check(TokenKind.RBRACE) {
            self.advance();
        }
    } elif not self.check_any(
        TokenKind.SEMI,
        TokenKind.RBRACE,
        TokenKind.RPAREN,
        TokenKind.RSQUARE,
        TokenKind.COMMA,
        TokenKind.EOF
    ) {
        self.parse_expression();
    }
    return left;
}

impl Parser._lookahead_advance -> None {
    self.advance();
}
