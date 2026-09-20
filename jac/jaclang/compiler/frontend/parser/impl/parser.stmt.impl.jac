import from jaclang.compiler.frontend.constant {
    Tokens as Tok,
    SymbolAccess,
    SymbolType
}


impl Parser.parse_element_stmt -> ElementStmt | EmptyToken | None {
    if self.check(TokenKind.SEMI) {
        self.emit_diag("Unexpected semicolon at module level", "E0030");
        self.expect(TokenKind.SEMI);
        return None;
    }
    if self.at_end() {
        return None;
    }

    if (
        self.check(TokenKind.NAME)
        and self.current().value in ('sv', 'cl', 'na')
        and (
            self.check_peek(TokenKind.LBRACE)
            or self.peek().kind
                in (
                    TokenKind.KW_IMPORT,
                    TokenKind.KW_INCLUDE,
                    TokenKind.KW_DEF,
                    TokenKind.KW_CAN,
                    TokenKind.KW_OBJECT,
                    TokenKind.KW_CLASS,
                    TokenKind.KW_ENUM,
                    TokenKind.KW_NODE,
                    TokenKind.KW_EDGE,
                    TokenKind.KW_WALKER,
                    TokenKind.KW_GLOBAL,
                    TokenKind.KW_TEST,
                    TokenKind.KW_IMPL,
                    TokenKind.KW_SEM,
                    TokenKind.KW_WITH,
                    TokenKind.KW_ASYNC
                )
        )
    ) {
        return self._recover_removed_marker();
    }
    if self.check(TokenKind.TYP_TYPE) {
        save = self.pos;
        self.expect(TokenKind.TYP_TYPE);

        if self.check_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT) {
            self.expect_any(TokenKind.KW_PUB, TokenKind.KW_PRIV, TokenKind.KW_PROT);
        }
        if self.check_name() or self.check(TokenKind.KWESC_NAME) {
            self._lookahead_advance();
            if self.check(TokenKind.EQ)
                or self.check(TokenKind.WALRUS_EQ)
                or self.check(TokenKind.LSQUARE) {
                self.pos = save;
                return self.parse_type_alias();
            }
        }
        self.pos = save;
    }
    if self.check_any(TokenKind.KW_IMPORT, TokenKind.KW_INCLUDE) {
        return self.parse_import_stmt();
    }
    if self.check_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    ) {
        return self.parse_archetype();
    }
    if self.check(TokenKind.KW_ENUM) {
        return self.parse_enum();
    }
    if self.check(TokenKind.KW_TEST) {
        return self.parse_test();
    }

    if self.check(TokenKind.STRING)
        and self.check_peek_any(
            TokenKind.KW_TEST,
            TokenKind.KW_DEF,
            TokenKind.KW_CAN,
            TokenKind.KW_OVERRIDE,
            TokenKind.KW_STATIC,
            TokenKind.KW_ASYNC,
            TokenKind.DECOR_OP,
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS,
            TokenKind.KW_ENUM,
            TokenKind.KW_IMPL,
            TokenKind.TYP_TYPE,
            TokenKind.KW_GLOBAL,
            TokenKind.KW_COMPTIME,
            TokenKind.KW_WITH
        ) {
        return self.parse_docstring_target();
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        return self.parse_ability();
    }

    if self.check(TokenKind.KW_GLOBAL) {
        return self.parse_global_var();
    }

    if self.check(TokenKind.KW_COMPTIME) {
        return self.parse_comptime_element();
    }

    if self.check(TokenKind.KW_IMPL) {
        return self.parse_impl_def();
    }

    if self.check(TokenKind.KW_SEM) {
        return self.parse_sem_def();
    }

    if self.check(TokenKind.PYNLINE) {
        py_tok = self.expect(TokenKind.PYNLINE);
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }

    if self.check(TokenKind.KW_WITH) {
        return self.parse_module_code();
    }

    if self.check(TokenKind.DECOR_OP) {
        return self._dispatch_decorated();
    }

    if self.check(TokenKind.KW_ASYNC) {
        return self._dispatch_async();
    }
    self.emit_diag(f"Unexpected token '{self.current().value}'", "E0005");
    self.synchronize();
    return EmptyToken();
}

impl Parser._dispatch_decorated_stmt -> CodeBlockStmt | None {
    decorated = self._dispatch_decorated();
    return decorated if isinstance(decorated, CodeBlockStmt) else None;
}

impl Parser.parse_comptime_element -> ElementStmt | EmptyToken | None {
    if self.check_peek_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        return self.parse_ability();
    }
    if self.check_peek(TokenKind.KW_IMPORT) {
        return self.parse_import_stmt();
    }
    if self.check_peek(TokenKind.KW_ASSERT) {
        stmt = self.parse_comptime_stmt();
        return stmt if isinstance(stmt, AssertStmt) else None;
    }
    return self.parse_comptime_global();
}

impl Parser.parse_comptime_global -> GlobalVars {
    ct_uni = self.consume_uni(TokenKind.KW_COMPTIME);
    access = self.parse_access_tag();

    assignments: list[Assignment] = [];
    comma_unis: list[Token] = [];
    assignments.append(self.parse_global_var_assignment());
    while self.match_tok(TokenKind.COMMA) {
        comma_unis.append(self.make_uni_token(self.previous()));
        assignments.append(self.parse_global_var_assignment());
    }
    self.expect(TokenKind.SEMI);
    kid: list[UniNode] = [ct_uni];
    if access {
        kid.append(access);
    }
    for (ai, asn) in enumerate(assignments) {
        asn.is_comptime = True;
        if ai > 0 {
            kid.append(comma_unis[ai - 1]);
        }
        kid.append(asn);
    }
    kid.append(self.make_semi());
    return GlobalVars(
        access=access, assignments=assignments, is_frozen=True, kid=kid, doc=None
    );
}

impl Parser.parse_comptime_stmt -> CodeBlockStmt | None {
    if self.check_peek(TokenKind.KW_IF) {
        return self.parse_if_stmt();
    }
    if self.check_peek(TokenKind.KW_FOR) {
        return self.parse_for_stmt();
    }
    if self.check_peek(TokenKind.KW_ASSERT) {
        return self.parse_assert_stmt();
    }
    if self.check_peek(TokenKind.KW_IMPORT) {
        return self.parse_import_stmt();
    }
    if self.check_peek_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        return self.parse_ability();
    }
    ct_uni = self.consume_uni(TokenKind.KW_COMPTIME);
    target = self.make_name(self.expect_name("comptime binding"));
    asn = self.parse_assignment_with_target(target);
    asn.is_comptime = True;
    asn.add_kids_left([ct_uni]);
    return asn;
}

impl Parser._dispatch_decorated -> ElementStmt | None {
    save_pos = self.pos;
    while self.check(TokenKind.DECOR_OP) {
        self.advance();
        self.parse_atomic_chain();
    }

    self.match_tok(TokenKind.KW_COMPTIME);

    while self.check(TokenKind.KW_ASYNC) {
        self.advance();
    }

    if self.check(TokenKind.KW_OVERRIDE) {
        self.advance();
    }
    if self.check(TokenKind.KW_STATIC) {
        self.advance();
    }

    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        self.advance();
    }

    has_abs_prefix = self.check(TokenKind.KW_ABSTRACT);
    if has_abs_prefix {
        self.advance();
    }

    is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
    is_enum = self.check(TokenKind.KW_ENUM);
    is_impl = self.check(TokenKind.KW_IMPL);
    is_test = self.check(TokenKind.KW_TEST);
    self.pos = save_pos;
    if is_test {
        return self.parse_test();
    } elif is_ability {
        return self.parse_ability();
    } elif is_enum {
        return self.parse_enum();
    } elif is_impl {
        return self.parse_impl_def();
    } else {
        return self.parse_archetype();
    }
}

impl Parser._dispatch_async -> ElementStmt | None {
    save_pos = self.pos;
    while self.check(TokenKind.KW_ASYNC) {
        self.advance();
    }

    if self.check(TokenKind.KW_STATIC) {
        self.advance();
    }
    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
        self.advance();
    }
    is_ability = self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
    self.pos = save_pos;
    if is_ability {
        return self.parse_ability();
    }
    return self.parse_archetype();
}

impl Parser._attach_doc(nd: AstDocNode, elem_doc: String) -> None {
    nd.set_doc(elem_doc);
    nd.add_kids_left([elem_doc]);
}

impl Parser.parse_docstring_target -> ElementStmt | None {
    doc_tok = self.expect(TokenKind.STRING);
    elem_doc = self.make_string(doc_tok);

    if self.check(TokenKind.KW_TEST) {
        doc_test = self.parse_test();
        self._attach_doc(doc_test, elem_doc);
        return doc_test;
    }
    if self.check(TokenKind.KW_ENUM) {
        doc_enum = self.parse_enum();
        self._attach_doc(doc_enum, elem_doc);
        return doc_enum;
    }
    if self.check(TokenKind.TYP_TYPE) {
        doc_alias = self.parse_type_alias();
        self._attach_doc(doc_alias, elem_doc);
        return doc_alias;
    }
    if self.check(TokenKind.KW_GLOBAL) {
        doc_globals = self.parse_global_var();
        self._attach_doc(doc_globals, elem_doc);
        return doc_globals;
    }
    if self.check(TokenKind.KW_COMPTIME) {
        doc_ct = self.parse_comptime_element();
        if isinstance(doc_ct, AstDocNode) {
            self._attach_doc(doc_ct, elem_doc);
        }
        return doc_ct if isinstance(doc_ct, ElementStmt) else None;
    }
    if self.check(TokenKind.KW_IMPL) {
        doc_impl = self.parse_impl_def();
        self._attach_doc(doc_impl, elem_doc);
        return doc_impl;
    }
    if self.check(TokenKind.KW_WITH) {
        doc_mc = self.parse_module_code();
        self._attach_doc(doc_mc, elem_doc);
        return doc_mc;
    }
    decorated = self._dispatch_decorated();
    if decorated is not None {
        self._attach_doc(decorated, elem_doc);
    }
    return decorated;
}

impl Parser.parse_module_code -> ModuleCode {
    with_uni = self.consume_uni(TokenKind.KW_WITH);
    name = None;
    target_name = None;
    colon_uni = None;
    if self.check(TokenKind.KW_EXIT) {
        name_tok = self.expect(TokenKind.KW_EXIT);
        name = self.make_uni_token(name_tok);
    } elif self.check(TokenKind.KW_ENTRY) {
        name_tok = self.expect(TokenKind.KW_ENTRY);
        name = self.make_uni_token(name_tok);
    }

    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        target_tok = self.expect_name();
        target_name = self.make_name(target_tok);
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [with_uni];
    if name {
        kid.append(name);
    }
    if target_name is not None and colon_uni is not None {
        kid.append(colon_uni);
        kid.append(target_name);
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);

    return ModuleCode(name=target_name, body=body, kid=kid, doc=None);
}

impl Parser.parse_code_block_stmts -> list[CodeBlockStmt] {
    stmts: list[CodeBlockStmt] = [];
    checked_first = False;
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt is not None {
            is_docstring = False;
            if (
                not checked_first
                and self._view_body_depth == 0
                and isinstance(stmt, ExprStmt)
                and not stmt.in_fstring
                and stmt.has_semi
            ) {
                _se = stmt.expr;
                if isinstance(_se, String) {
                    is_docstring = True;
                } elif (
                    isinstance(_se, MultiString)
                    and all(isinstance(sn, String) for sn in _se.strings)
                ) {
                    is_docstring = True;
                }
            }
            if is_docstring {
                self.emit_warn(
                    "Docstrings in Jac go before the declaration, not inside the body. Move this string before the enclosing test/can/obj/etc.",
                    "W0060",
                    loc=self.tokens[before].loc
                );
            }
            if not isinstance(stmt, Semi) {
                checked_first = True;
            }
            stmts.append(stmt);

            if self.match_tok(TokenKind.SEMI) {
                prev = self.previous();
                stmts.append(
                    Semi(
                        orig_src=self.source,
                        name=Tok.SEMI.value,
                        value=";",
                        line=prev.loc.line,
                        end_line=prev.loc.end_line,
                        col_start=prev.loc.col_start,
                        col_end=prev.loc.col_end,
                        pos_start=prev.loc.pos_start,
                        pos_end=prev.loc.pos_end
                    )
                );
            }
        }

        if self.pos == before {
            self.advance();
        }
    }
    return stmts;
}

impl Parser._apply_implicit_return(body: list[CodeBlockStmt]) -> list[CodeBlockStmt] {
    if len(body) == 0 {
        return body;
    }
    last = body[-1];
    if isinstance(last, ExprStmt) and not last.has_semi and not last.in_fstring {
        _le = last.expr;
        body[-1] = ReturnStmt(expr=_le, is_implicit=True, kid=[_le]);
    }
    return body;
}

impl Parser.parse_ctrl_stmt -> CtrlStmt | DisengageStmt | None {
    if self.check_any(TokenKind.KW_BREAK, TokenKind.KW_CONTINUE, TokenKind.KW_SKIP) {
        self.expect_any(TokenKind.KW_BREAK, TokenKind.KW_CONTINUE, TokenKind.KW_SKIP);
        ctrl_uni = self.make_uni_token(self.previous());
        kid: list[UniNode] = [ctrl_uni];
        self.expect(TokenKind.SEMI);
        kid.append(self.make_semi());
        return CtrlStmt(ctrl=ctrl_uni, kid=kid);
    }
    if self.check(TokenKind.KW_DISENGAGE) {
        self.expect(TokenKind.KW_DISENGAGE);
        dis_uni = self.make_uni_token(self.previous());
        kid: list[UniNode] = [dis_uni];
        self.expect(TokenKind.SEMI);
        kid.append(self.make_semi());
        return DisengageStmt(kid=kid);
    }
    return None;
}

impl Parser.parse_statement -> CodeBlockStmt | None {
    if self.match_tok(TokenKind.SEMI) {
        return self.make_semi();
    }
    if self.check(TokenKind.RBRACE) or self.at_end() {
        return None;
    }

    if self._view_body_depth > 0
        and self.check_any(TokenKind.JSX_OPEN_START, TokenKind.JSX_FRAG_OPEN) {
        jsx = self.parse_jsx_element();
        jsx_kid: list[UniNode] = [jsx];
        if self.match_tok(TokenKind.SEMI) {
            jsx_kid.append(self.make_semi());
        }
        return ExprStmt(expr=jsx, in_fstring=False, kid=jsx_kid);
    }

    if self._view_body_depth > 0
        and self.check(TokenKind.LBRACE)
        and self.check_peek_any(
            TokenKind.KW_FOR,
            TokenKind.KW_WHILE,
            TokenKind.KW_FOREVER,
            TokenKind.KW_IF,
            TokenKind.KW_MATCH,
            TokenKind.KW_SWITCH,
            TokenKind.KW_WITH,
            TokenKind.KW_TRY,
            TokenKind.KW_RETURN,
            TokenKind.KW_SKIP
        ) {
        redundant_lbrace_loc = self.current().loc;
        peeked_kw = self.peek().value;
        self.emit_diag(
            "Redundant '{...}' slot wrapping inside a JSX slot body -- slot "
                + "bodies are already in slot mode. Drop the outer braces: write "
                + f"'{peeked_kw} ... {{ ... }}' directly instead of "
                + f"'{{{peeked_kw} ... {{ ... }}}}'.",
            "E2023",
            loc=redundant_lbrace_loc
        );
        self.advance();
        inner = self.parse_statement();

        self.match_tok(TokenKind.SEMI);
        if self.check(TokenKind.RBRACE) {
            self.expect(TokenKind.RBRACE);
        }
        return inner;
    }

    if self._view_body_depth > 0 and self.check(TokenKind.LBRACE) {
        save_pos = self.pos;
        saved_error_count = self.error_count;
        saved_diags_len = len(self.diags);

        redundant_lbrace_loc = self.current().loc;
        self.advance();
        inner_expr = self.parse_expression();
        parsed_clean = self.error_count == saved_error_count;
        if parsed_clean and self.check(TokenKind.RBRACE) {
            self.emit_diag(
                "Redundant '{...}' around a single expression inside a JSX slot "
                    + "body -- slot bodies are already in slot mode, so the value renders "
                    + "without the extra braces. Drop them: write the expression directly, "
                    + "terminated with ';' (e.g. 'name;' instead of '{name}').",
                "E2028",
                loc=redundant_lbrace_loc
            );
            self.advance();
            expr_kid: list[UniNode] = [inner_expr];
            if self.match_tok(TokenKind.SEMI) {
                expr_kid.append(self.make_semi());
            }
            return ExprStmt(expr=inner_expr, in_fstring=False, kid=expr_kid);
        }

        self.pos = save_pos;
        self.error_count = saved_error_count;
        while len(self.diags) > saved_diags_len {
            self.diags.pop();
        }
    }

    if self.is_keyword_token()
        and not self.is_name_usable_token()
        and self.check_peek_any(
            TokenKind.EQ,
            TokenKind.ADD_EQ,
            TokenKind.SUB_EQ,
            TokenKind.MUL_EQ,
            TokenKind.DIV_EQ,
            TokenKind.FLOOR_DIV_EQ,
            TokenKind.MOD_EQ,
            TokenKind.STAR_POW_EQ,
            TokenKind.MATMUL_EQ,
            TokenKind.BW_AND_EQ,
            TokenKind.BW_OR_EQ,
            TokenKind.BW_XOR_EQ,
            TokenKind.LSHIFT_EQ,
            TokenKind.RSHIFT_EQ
        ) {
        kw_target = self.make_name(self.expect_name("variable"));
        return self.parse_assignment_with_target(kw_target);
    }

    if self.check(TokenKind.KW_COMPTIME) {
        return self.parse_comptime_stmt();
    }
    if self.check_any(TokenKind.KW_IMPORT, TokenKind.KW_INCLUDE) {
        return self.parse_import_stmt();
    }
    if self.check(TokenKind.KW_IF) {
        return self.parse_if_stmt();
    }
    if self.check(TokenKind.KW_WHILE) {
        return self.parse_while_stmt();
    }
    if self.check(TokenKind.KW_IN) {
        return self.parse_open_stmt();
    }
    if self.check(TokenKind.KW_FOREVER) {
        return self.parse_forever_stmt();
    }

    if self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR) {
        return self.parse_for_stmt();
    }
    if self.check(TokenKind.KW_FLOW) and self.check_peek(TokenKind.KW_FOR) {
        return self.parse_for_stmt();
    }
    if self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_WITH) {
        return self.parse_with_stmt();
    }
    if self.check(TokenKind.KW_FOR) {
        return self.parse_for_stmt();
    }
    if self.check(TokenKind.KW_TRY) {
        return self.parse_try_stmt();
    }
    if self.check(TokenKind.KW_WITH) {
        return self.parse_with_stmt();
    }
    if self.check(TokenKind.KW_MATCH) {
        return self.parse_match_stmt();
    }

    if self.check(TokenKind.KW_SWITCH) {
        return self.parse_switch_stmt();
    }
    if self.check(TokenKind.KW_RETURN) {
        return self.parse_return_stmt();
    }
    if self.check(TokenKind.KW_YIELD) {
        yield_expr = self.parse_yield_stmt();
        es_kid: list[UniNode] = [yield_expr];
        self.expect(TokenKind.SEMI);
        if yield_expr.expr is None {
            yield_expr.add_kids_right([self.make_semi()]);
        } else {
            es_kid.append(self.make_semi());
        }
        return ExprStmt(expr=yield_expr, in_fstring=False, kid=es_kid);
    }
    if self.check_any(TokenKind.KW_BREAK, TokenKind.KW_CONTINUE, TokenKind.KW_SKIP) {
        return self.parse_ctrl_stmt();
    }
    if self.check(TokenKind.KW_RAISE) {
        return self.parse_raise_stmt();
    }
    if self.check(TokenKind.KW_ASSERT) {
        return self.parse_assert_stmt();
    }
    if self.check(TokenKind.KW_DELETE) {
        return self.parse_delete_stmt();
    }
    if self.check(TokenKind.KW_GLOBAL) {
        return self.parse_global_var();
    }

    if self.check(TokenKind.KW_VISIT) {
        return self.parse_visit_stmt();
    }

    if self.check(TokenKind.KW_DISENGAGE) {
        return self.parse_ctrl_stmt();
    }

    if self.check(TokenKind.KW_REPORT) {
        return self.parse_report_stmt();
    }
    if self.check(TokenKind.STRING)
        and self.check_peek_any(
            TokenKind.KW_DEF,
            TokenKind.KW_CAN,
            TokenKind.KW_OVERRIDE,
            TokenKind.KW_STATIC,
            TokenKind.KW_ASYNC,
            TokenKind.DECOR_OP,
            TokenKind.KW_OBJECT,
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_CLASS
        ) {
        doc_stmt = self.parse_docstring_target();
        return doc_stmt if isinstance(doc_stmt, CodeBlockStmt) else None;
    }
    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
        return self.parse_ability();
    }

    if self.check(TokenKind.KW_STATIC)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        return self.parse_ability();
    }
    if self.check(TokenKind.DECOR_OP) {
        return self._dispatch_decorated_stmt();
    }

    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        return self.parse_ability();
    }

    if self.check_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    ) {
        return self.parse_archetype();
    }

    if self.check(TokenKind.KW_IMPL) {
        return self.parse_impl_def();
    }

    if self.check(TokenKind.KW_HAS)
        or (self.check(TokenKind.KW_STATIC) and self.check_peek(TokenKind.KW_HAS)) {
        return self.parse_has_stmt();
    }

    if self.check(TokenKind.PYNLINE) {
        py_tok = self.expect(TokenKind.PYNLINE);
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }

    if self.check_any(
        TokenKind.KW_ELIF,
        TokenKind.KW_ELSE,
        TokenKind.KW_EXCEPT,
        TokenKind.KW_FINALLY,
        TokenKind.KW_CASE
    ) {
        self.emit_diag(
            f"Unexpected '{self.current().value}' -- must follow its parent statement (if/try/match/switch)",
            "E0032"
        );
        self.expect_any(
            TokenKind.KW_ELIF,
            TokenKind.KW_ELSE,
            TokenKind.KW_EXCEPT,
            TokenKind.KW_FINALLY,
            TokenKind.KW_CASE
        );
        return None;
    }

    if self.check(TokenKind.RETURN_HINT) and not self.check_peek(TokenKind.SEMI) {
        self.expect(TokenKind.RETURN_HINT);
        arrow_uni = self.make_uni_token(self.previous());
        type_ctx = self.parse_expression();
        lb_uni = self.consume_uni(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        kid: list[UniNode] = [arrow_uni, type_ctx, lb_uni];
        kid.extend(body);
        kid.append(rb_uni);
        return TypedCtxBlock(type_ctx=type_ctx, body=body, kid=kid);
    }
    expr = self.parse_expression();
    if self.check(TokenKind.EQ)
        or self.check(TokenKind.COLON)
        or self.check_any(
            TokenKind.ADD_EQ,
            TokenKind.SUB_EQ,
            TokenKind.MUL_EQ,
            TokenKind.DIV_EQ,
            TokenKind.FLOOR_DIV_EQ,
            TokenKind.MOD_EQ,
            TokenKind.STAR_POW_EQ,
            TokenKind.MATMUL_EQ,
            TokenKind.BW_AND_EQ,
            TokenKind.BW_OR_EQ,
            TokenKind.BW_XOR_EQ,
            TokenKind.LSHIFT_EQ,
            TokenKind.RSHIFT_EQ
        ) {
        return self.parse_assignment_with_target(expr);
    }

    expr_kid: list[UniNode] = [expr];
    if self.match_tok(TokenKind.SEMI) {
        expr_kid.append(self.make_semi());
    } elif isinstance(expr, JsxElement) and self._view_body_depth > 0 {} elif isinstance(
        expr, Name
    )
        and expr.value == "new" {
        self.emit_diag(
            "Use the `new(target, ...args)` ambient builtin to create new instances",
            "E0012",
            loc=self.current().loc,
            help="`new` is a portable constructor: it lowers to `Cls(*args)` on the server and to `Reflect.construct(Cls, [args])` in cl blocks."
        );
    } elif self.check(TokenKind.RBRACE) {
        return ExprStmt(expr=expr, in_fstring=False, has_semi=False, kid=expr_kid);
    } else {
        self.emit_diag("Missing ';'", "E0002");
    }
    return ExprStmt(expr=expr, in_fstring=False, kid=expr_kid);
}

impl Parser.parse_if_stmt -> IfStmt {
    is_comptime = False;
    ct_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_COMPTIME) {
        is_comptime = True;
        ct_uni = self.make_uni_token(self.previous());
    }
    if_uni = self.consume_uni(TokenKind.KW_IF);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELIF) {
        else_body = self.parse_elif_stmt();
    } elif self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[UniNode] = [];
    if ct_uni is not None {
        kid.append(ct_uni);
    }
    kid.extend([if_uni, condition, lb_uni]);
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    if is_comptime {
        chain = else_body;
        while isinstance(chain, ElseIf) {
            chain.is_comptime = True;
            chain = chain.else_body;
        }
    }
    return IfStmt(
        condition=condition,
        body=body,
        else_body=else_body,
        is_comptime=is_comptime,
        kid=kid
    );
}

impl Parser.parse_elif_stmt -> ElseIf {
    elif_uni = self.consume_uni(TokenKind.KW_ELIF);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELIF) {
        else_body = self.parse_elif_stmt();
    } elif self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[UniNode] = [elif_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return ElseIf(condition=condition, body=body, else_body=else_body, kid=kid);
}

impl Parser.parse_else_stmt -> ElseStmt {
    else_uni = self.consume_uni(TokenKind.KW_ELSE);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [else_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return ElseStmt(body=body, kid=kid);
}

impl Parser.parse_while_stmt -> WhileStmt {
    while_uni = self.consume_uni(TokenKind.KW_WHILE);
    condition = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[UniNode] = [while_uni, condition, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return WhileStmt(condition=condition, body=body, else_body=else_body, kid=kid);
}

impl Parser.parse_open_stmt -> OpenStmt {
    in_uni = self.consume_uni(TokenKind.KW_IN);
    target = self.parse_expression();
    if not self.check(TokenKind.LBRACE) {
        self.error("expected '{' to open the region body after `in <handle>`");
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [in_uni, target, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return OpenStmt(target=target, body=body, kid=kid);
}

impl Parser.parse_forever_stmt -> ForeverStmt {
    forever_uni = self.consume_uni(TokenKind.KW_FOREVER);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [forever_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    return ForeverStmt(body=body, kid=kid);
}

impl Parser.parse_for_stmt -> IterForStmt | InForStmt {
    is_async = False;
    async_uni = None;
    flow_uni = None;
    is_comptime = False;
    ct_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_COMPTIME) {
        is_comptime = True;
        ct_uni = self.make_uni_token(self.previous());
    }
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    if self.match_tok(TokenKind.KW_FLOW) {
        flow_uni = self.make_uni_token(self.previous());
    }
    for_uni = self.consume_uni(TokenKind.KW_FOR);

    target = self.parse_atomic_chain();

    if self.check(TokenKind.EQ) {
        if flow_uni is not None {
            self.error("`flow for` requires the `for <x> in <collection>` form");
        }
        if is_comptime {
            self.error("`comptime for` requires the `for <x> in <collection>` form");
        }
        eq_tok = self.expect(TokenKind.EQ);
        eq_uni = self.make_uni_token(eq_tok);
        start_val = self.parse_expression();
        while_uni = self.consume_uni(TokenKind.KW_WHILE);
        end_val = self.parse_expression();
        with_uni = self.consume_uni(TokenKind.KW_WITH);

        step_target = self.parse_atomic_chain();
        step_assign: Assignment;
        if self.check_any(
            TokenKind.ADD_EQ,
            TokenKind.SUB_EQ,
            TokenKind.MUL_EQ,
            TokenKind.DIV_EQ,
            TokenKind.FLOOR_DIV_EQ,
            TokenKind.MOD_EQ,
            TokenKind.STAR_POW_EQ,
            TokenKind.MATMUL_EQ
        ) {
            step_assign = self.parse_assignment_with_target(
                step_target, require_semi=False
            );
        } else {
            step_assign = Assignment(
                target=[step_target],
                value=None,
                type_tag=None,
                kid=[step_target],
                mutable=True,
                aug_op=None,
                is_enum_stmt=False
            );
        }
        lb_uni = self.consume_uni(TokenKind.LBRACE);
        body = self.parse_code_block_stmts();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        else_body = None;
        if self.check(TokenKind.KW_ELSE) {
            else_body = self.parse_else_stmt();
        }

        init_assign = Assignment(
            target=[target],
            value=start_val,
            type_tag=None,
            kid=[target, eq_uni, start_val],
            mutable=True,
            aug_op=None,
            is_enum_stmt=False
        );
        kid: list[UniNode] = [];
        if is_async and async_uni is not None {
            kid.append(async_uni);
        }
        kid.extend(
            [for_uni, init_assign, while_uni, end_val, with_uni, step_assign, lb_uni]
        );
        kid.extend(body);
        kid.append(rb_uni);
        if else_body {
            kid.append(else_body);
        }
        return IterForStmt(
            iter=init_assign,
            is_async=is_async,
            condition=end_val,
            count_by=step_assign,
            body=body,
            else_body=else_body,
            kid=kid
        );
    }

    in_uni = self.consume_uni(TokenKind.KW_IN);
    iter_expr = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    else_body = None;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    kid: list[UniNode] = [];
    if ct_uni is not None {
        kid.append(ct_uni);
    }
    if is_async and async_uni is not None {
        kid.append(async_uni);
    }
    if flow_uni is not None {
        kid.append(flow_uni);
    }
    kid.extend([for_uni, target, in_uni, iter_expr]);
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    if else_body {
        kid.append(else_body);
    }
    return InForStmt(
        target=target,
        is_async=is_async,
        collection=iter_expr,
        body=body,
        else_body=else_body,
        is_comptime=is_comptime,
        kid=kid
    );
}

impl Parser.parse_try_stmt -> TryStmt {
    try_uni = self.consume_uni(TokenKind.KW_TRY);
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);

    awaiting_body = None;
    if self.check(TokenKind.KW_AWAITING) {
        awaiting_uni = self.make_uni_token(self.expect(TokenKind.KW_AWAITING));
        awaiting_lb = self.consume_uni(TokenKind.LBRACE);
        awaiting_stmts = self.parse_code_block_stmts();
        awaiting_rb = self.consume_uni(TokenKind.RBRACE);
        awaiting_kid: list[UniNode] = [awaiting_uni, awaiting_lb];
        awaiting_kid.extend(awaiting_stmts);
        awaiting_kid.append(awaiting_rb);
        awaiting_body = AwaitingClause(body=awaiting_stmts, kid=awaiting_kid);
    }
    excepts: list[Except] = [];
    while self.check(TokenKind.KW_EXCEPT) {
        excepts.append(self.parse_except_handler());
    }
    else_body = None;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    }
    finally_body = None;
    if self.check(TokenKind.KW_FINALLY) {
        fin_uni = self.make_uni_token(self.expect(TokenKind.KW_FINALLY));
        fin_lb = self.consume_uni(TokenKind.LBRACE);
        finally_stmts = self.parse_code_block_stmts();
        fin_rb = self.consume_uni(TokenKind.RBRACE);
        fin_kid: list[UniNode] = [fin_uni, fin_lb];
        fin_kid.extend(finally_stmts);
        fin_kid.append(fin_rb);
        finally_body = FinallyStmt(body=finally_stmts, kid=fin_kid);
    }
    kid: list[UniNode] = [try_uni, lb_uni];
    kid.extend(body);
    kid.append(rb_uni);
    if awaiting_body {
        kid.append(awaiting_body);
    }
    kid.extend(excepts);
    if else_body {
        kid.append(else_body);
    }
    if finally_body {
        kid.append(finally_body);
    }
    return TryStmt(
        body=body,
        excepts=excepts,
        else_body=else_body,
        awaiting_body=awaiting_body,
        finally_body=finally_body,
        kid=kid
    );
}

impl Parser.parse_except_handler -> Except {
    except_uni = self.consume_uni(TokenKind.KW_EXCEPT);

    exc_type = self.parse_expression(allow_cast=False);
    name = None;
    as_uni = None;
    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [except_uni, exc_type];
    if name is not None and as_uni is not None {
        kid.append(as_uni);
        kid.append(name);
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    return Except(ex_type=exc_type, name=name, body=body, kid=kid);
}

impl Parser.parse_with_stmt -> WithStmt {
    is_async = False;
    async_uni = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    with_uni = self.consume_uni(TokenKind.KW_WITH);
    exprs: list[ExprAsItem] = [];

    expr = self.parse_expression(allow_cast=False);
    alias = None;
    as_uni = None;
    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        alias = self.parse_expression();
    }
    exprs.append(
        ExprAsItem(
            expr=expr, alias=alias, kid=[expr] if not alias else [expr, as_uni, alias]
        )
    );
    comma_unis: list[Token] = [];
    while self.match_tok(TokenKind.COMMA) {
        comma_unis.append(self.make_uni_token(self.previous()));
        expr = self.parse_expression(allow_cast=False);
        alias = None;
        as_uni = None;
        if self.match_tok(TokenKind.KW_AS) {
            as_uni = self.make_uni_token(self.previous());
            alias = self.parse_expression();
        }
        exprs.append(
            ExprAsItem(
                expr=expr,
                alias=alias,
                kid=[expr] if not alias else [expr, as_uni, alias]
            )
        );
    }
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [];
    if is_async and async_uni is not None {
        kid.append(async_uni);
    }
    kid.append(with_uni);
    for (i, e) in enumerate(exprs) {
        kid.append(e);
        if i < len(exprs) - 1 {
            kid.append(comma_unis[i]);
        }
    }
    kid.append(lb_uni);
    kid.extend(body);
    kid.append(rb_uni);
    return WithStmt(is_async=is_async, exprs=exprs, body=body, kid=kid);
}

impl Parser.parse_match_stmt -> MatchStmt {
    match_uni = self.consume_uni(TokenKind.KW_MATCH);
    expr = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    cases: list[MatchCase] = [];
    while self.check(TokenKind.KW_CASE) {
        cases.append(self.parse_match_case());
    }
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [match_uni, expr, lb_uni];
    kid.extend(cases);
    kid.append(rb_uni);
    return MatchStmt(target=expr, cases=cases, kid=kid);
}

impl Parser.parse_match_case -> MatchCase {
    case_uni = self.consume_uni(TokenKind.KW_CASE);
    pattern = self.parse_pattern();
    guard = None;
    guard_if_uni = None;
    if self.match_tok(TokenKind.KW_IF) {
        guard_if_uni = self.make_uni_token(self.previous());
        guard = self.parse_expression();
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    body: list[CodeBlockStmt] = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.RBRACE)
        and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt is not None {
            body.append(stmt);
        }

        if self.pos == before {
            self.advance();
        }
    }
    kid: list[UniNode] = [case_uni, pattern];
    if guard is not None and guard_if_uni is not None {
        kid.append(guard_if_uni);
        kid.append(guard);
    }
    kid.append(colon_uni);
    kid.extend(body);
    return MatchCase(pattern=pattern, guard=guard, body=body, kid=kid);
}

impl Parser.parse_pattern -> MatchPattern {
    pattern = self.parse_or_pattern();

    if self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        kid: list[UniNode] = [pattern, as_uni, name];
        return MatchAs(name=name, pattern=pattern, kid=kid);
    }
    return pattern;
}

impl Parser.parse_or_pattern -> MatchPattern {
    patterns: list[MatchPattern] = [self.parse_single_pattern()];
    or_unis: list[Token] = [];
    while self.match_tok(TokenKind.BW_OR) {
        or_unis.append(self.make_uni_token(self.previous()));
        patterns.append(self.parse_single_pattern());
    }
    if len(patterns) == 1 {
        return patterns[0];
    }
    kid: list[UniNode] = [patterns[0]];
    for i in range(1, len(patterns)) {
        kid.append(or_unis[i - 1]);
        kid.append(patterns[i]);
    }
    return MatchOr(patterns=patterns, kid=kid);
}

impl Parser.parse_single_pattern -> MatchPattern {
    if self.check(TokenKind.LSQUARE) {
        return self.parse_sequence_pattern();
    }
    if self.check(TokenKind.LPAREN) {
        return self.parse_tuple_sequence_pattern();
    }
    if self.check(TokenKind.LBRACE) {
        return self.parse_mapping_pattern();
    }

    if self.check(TokenKind.BOOL) {
        tok = self.expect(TokenKind.BOOL);
        bval = self.make_bool(tok);
        return MatchSingleton(value=bval, kid=[bval]);
    }
    if self.check(TokenKind.NULL) {
        tok = self.expect(TokenKind.NULL);
        nval = self.make_null(tok);
        return MatchSingleton(value=nval, kid=[nval]);
    }

    if self.check_any(TokenKind.INT, TokenKind.FLOAT, TokenKind.MINUS)
        or self.check(TokenKind.STRING) {
        return self.parse_literal_pattern();
    }

    if self.check_name()
        or self.is_keyword_token()
        or self.check_any(
            TokenKind.TYP_STRING,
            TokenKind.TYP_INT,
            TokenKind.TYP_FLOAT,
            TokenKind.TYP_LIST,
            TokenKind.TYP_TUPLE,
            TokenKind.TYP_SET,
            TokenKind.TYP_DICT,
            TokenKind.TYP_BOOL,
            TokenKind.TYP_BYTES,
            TokenKind.TYP_ANY,
            TokenKind.TYP_TYPE
        ) {
        return self.parse_name_pattern();
    }

    expr = self.parse_expression();
    return MatchValue(value=expr, kid=[expr]);
}

impl Parser.parse_literal_pattern -> MatchValue {
    if self.check(TokenKind.INT) {
        tok = self.expect(TokenKind.INT);
        ival = self.make_int(tok);
        return MatchValue(value=ival, kid=[ival]);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.expect(TokenKind.FLOAT);
        fval = self.make_float(tok);
        return MatchValue(value=fval, kid=[fval]);
    }
    ms = self.parse_multistring();
    if ms is not None {
        return MatchValue(value=ms, kid=[ms]);
    }

    if self.check(TokenKind.MINUS) {
        minus_tok = self.expect(TokenKind.MINUS);
        if self.check(TokenKind.INT) {
            tok = self.expect(TokenKind.INT);
            inum = self.make_int(tok);
            mival = UnaryExpr(
                operand=inum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), inum]
            );
            return MatchValue(value=mival, kid=[mival]);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.expect(TokenKind.FLOAT);
            fnum = self.make_float(tok);
            mfval = UnaryExpr(
                operand=fnum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), fnum]
            );
            return MatchValue(value=mfval, kid=[mfval]);
        }
    }

    return self.parse_expression_pattern();
}

impl Parser.parse_expression_pattern -> MatchValue {
    expr = self.parse_expression();
    return MatchValue(value=expr, kid=[expr]);
}

impl Parser.parse_name_pattern -> MatchPattern {
    if self.check_name() {
        tok = self.expect_name();
        name = self.make_name(tok);

        if tok.value == "_" {
            return MatchWild(kid=[name]);
        }

        if self.check(TokenKind.DOT) {
            names: list[Name] = [name];
            dot_unis: list[Token] = [];
            while self.match_tok(TokenKind.DOT) {
                dot_unis.append(self.make_uni_token(self.previous()));
                next_tok = self.expect_name();
                names.append(self.make_name(next_tok));
            }
            if self.check(TokenKind.LPAREN) {
                return self.parse_class_pattern_args(names, dot_unis);
            }

            trailer: (NameAtom | AtomTrailer) = names[0];
            for i in range(1, len(names)) {
                trailer = AtomTrailer(
                    target=trailer,
                    right=names[i],
                    is_attr=True,
                    is_null_ok=False,
                    kid=[trailer, dot_unis[i - 1], names[i]]
                );
            }
            return MatchValue(value=trailer, kid=[trailer]);
        }

        if self.check(TokenKind.LPAREN) {
            return self.parse_class_pattern_args([name]);
        }

        return MatchAs(name=name, pattern=None, kid=[name]);
    }

    if self.is_keyword_token() {
        if is_special_var_kind(self.current().kind) {
            name = self.make_special_name(self.advance());
        } else {
            name = self.make_name(self.expect_name("pattern"));
        }
        if self.check(TokenKind.LPAREN) {
            return self.parse_class_pattern_args([name]);
        }
        return MatchValue(value=name, kid=[name]);
    }

    return self.parse_expression_pattern();
}

impl Parser.parse_sequence_pattern -> MatchPattern {
    lsq_uni = self.consume_uni(TokenKind.LSQUARE);
    kid: list[UniNode] = [lsq_uni];
    values: list[MatchPattern] = [];
    while not self.check(TokenKind.RSQUARE) and not self.at_end() {
        if self.check(TokenKind.STAR_MUL) {
            star_tok = self.expect(TokenKind.STAR_MUL);
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = MatchStar(
                name=name, is_list=True, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            pat = self.parse_pattern();
            values.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RSQUARE) {
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rsq_uni = self.consume_uni(TokenKind.RSQUARE);
    kid.append(rsq_uni);
    return MatchSequence(values=values, kid=kid);
}

impl Parser.parse_tuple_sequence_pattern -> MatchPattern {
    lp_uni = self.consume_uni(TokenKind.LPAREN);
    kid: list[UniNode] = [lp_uni];
    values: list[MatchPattern] = [];
    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        if self.check(TokenKind.STAR_MUL) {
            star_tok = self.expect(TokenKind.STAR_MUL);
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = MatchStar(
                name=name, is_list=True, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            pat = self.parse_pattern();
            values.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RPAREN) {
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
    return MatchSequence(values=values, kid=kid);
}

impl Parser.parse_mapping_pattern -> MatchPattern {
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    kid: list[UniNode] = [lb_uni];
    values: list[MatchKVPair | MatchStar] = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check(TokenKind.STAR_POW) {
            star_tok = self.expect(TokenKind.STAR_POW);
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            star_pattern = MatchStar(
                name=name, is_list=False, kid=[self.make_uni_token(star_tok), name]
            );
            values.append(star_pattern);
            kid.append(star_pattern);
        } else {
            key = self.parse_literal_for_mapping();
            colon_uni = self.consume_uni(TokenKind.COLON);
            val = self.parse_pattern();
            if key is not None {
                kv = MatchKVPair(key=key, value=val, kid=[key, colon_uni, val]);
                values.append(kv);
                kid.append(kv);
            }
        }
        if not self.check(TokenKind.RBRACE) {
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid.append(rb_uni);
    return MatchMapping(values=values, kid=kid);
}

impl Parser.parse_literal_for_mapping -> MatchPattern | NameAtom | None {
    if self.check(TokenKind.INT) {
        tok = self.expect(TokenKind.INT);
        ival = self.make_int(tok);
        return MatchValue(value=ival, kid=[ival]);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.expect(TokenKind.FLOAT);
        fval = self.make_float(tok);
        return MatchValue(value=fval, kid=[fval]);
    }
    ms = self.parse_multistring();
    if ms is not None {
        return MatchValue(value=ms, kid=[ms]);
    }
    if self.check(TokenKind.MINUS) {
        minus_tok = self.expect(TokenKind.MINUS);
        if self.check(TokenKind.INT) {
            tok = self.expect(TokenKind.INT);
            inum = self.make_int(tok);
            mival = UnaryExpr(
                operand=inum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), inum]
            );
            return MatchValue(value=mival, kid=[mival]);
        }
        if self.check(TokenKind.FLOAT) {
            tok = self.expect(TokenKind.FLOAT);
            fnum = self.make_float(tok);
            mfval = UnaryExpr(
                operand=fnum,
                op=self.make_uni_token(minus_tok),
                kid=[self.make_uni_token(minus_tok), fnum]
            );
            return MatchValue(value=mfval, kid=[mfval]);
        }
    }

    self.emit_diag(
        "Expected literal (INT, FLOAT, or STRING) as mapping pattern key", "E0045"
    );
    return self.make_name(self.advance());
}

impl Parser.parse_class_pattern_args(
    names: list[Name], dot_unis: (list[Token] | None) = None
) -> MatchPattern {
    dots: list[Token] = [];
    if dot_unis is not None {
        dots = dot_unis;
    }
    lparen_uni = self.consume_uni(TokenKind.LPAREN);

    class_name: (NameAtom | AtomTrailer) = names[0];
    if len(names) > 1 {
        for i in range(1, len(names)) {
            class_name = AtomTrailer(
                target=class_name,
                right=names[i],
                is_attr=True,
                is_null_ok=False,
                kid=[class_name, dots[i - 1], names[i]]
            );
        }
    }
    arg_patterns: list[MatchPattern] = [];
    kw_patterns: list[MatchKVPair] = [];
    kid: list[UniNode] = [];

    kid.append(class_name);
    kid.append(lparen_uni);

    while not self.check(TokenKind.RPAREN) and not self.at_end() {
        if self.check_name() and self.check_peek(TokenKind.EQ) {
            name_tok = self.expect_name();
            eq_uni = self.consume_uni(TokenKind.EQ);
            val = self.parse_pattern();
            name = self.make_name(name_tok);
            kv = MatchKVPair(key=name, value=val, kid=[name, eq_uni, val]);
            kw_patterns.append(kv);
            kid.append(kv);
        } else {
            pat = self.parse_pattern();
            arg_patterns.append(pat);
            kid.append(pat);
        }
        if not self.check(TokenKind.RPAREN) {
            comma_uni = self.consume_uni(TokenKind.COMMA);
            kid.append(comma_uni);
        }
    }
    rparen_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rparen_uni);
    return MatchArch(
        name=class_name, arg_patterns=arg_patterns, kw_patterns=kw_patterns, kid=kid
    );
}

impl Parser.parse_return_stmt -> ReturnStmt {
    ret_uni = self.consume_uni(TokenKind.KW_RETURN);
    expr = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list[UniNode] = [ret_uni];
    if expr {
        kid.append(expr);
    }
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return ReturnStmt(expr=expr, kid=kid);
}

impl Parser.parse_yield_stmt -> YieldExpr {
    yield_uni = self.consume_uni(TokenKind.KW_YIELD);
    with_from = False;
    from_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_FROM) {
        with_from = True;
        from_uni = self.make_uni_token(self.previous());
    }
    expr = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    kid: list[UniNode] = [yield_uni];
    if from_uni {
        kid.append(from_uni);
    }
    if expr {
        kid.append(expr);
    }
    return YieldExpr(expr=expr, with_from=with_from, kid=kid);
}

impl Parser.parse_raise_stmt -> RaiseStmt {
    raise_uni = self.consume_uni(TokenKind.KW_RAISE);
    expr = None;
    from_target = None;
    if not self.check(TokenKind.SEMI) and not self.check(TokenKind.RBRACE) {
        expr = self.parse_expression();
    }
    from_kw_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_FROM) {
        from_kw_uni = self.make_uni_token(self.previous());
        from_target = self.parse_expression();
    }
    kid: list[UniNode] = [raise_uni];
    if expr {
        kid.append(expr);
    }
    if from_target is not None and from_kw_uni is not None {
        kid.append(from_kw_uni);
        kid.append(from_target);
    }
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return RaiseStmt(cause=expr, from_target=from_target, kid=kid);
}

impl Parser.parse_assert_stmt -> AssertStmt {
    is_comptime = False;
    ct_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_COMPTIME) {
        is_comptime = True;
        ct_uni = self.make_uni_token(self.previous());
    }
    assert_uni = self.consume_uni(TokenKind.KW_ASSERT);
    `test = self.parse_expression();
    msg = None;
    comma_uni: Token | None = None;
    if self.match_tok(TokenKind.COMMA) {
        comma_uni = self.make_uni_token(self.previous());
        msg = self.parse_expression();
    }
    kid: list[UniNode] = [];
    if ct_uni is not None {
        kid.append(ct_uni);
    }
    kid.extend([assert_uni, `test]);
    if msg is not None and comma_uni is not None {
        kid.append(comma_uni);
        kid.append(msg);
    }
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return AssertStmt(condition=`test, error_msg=msg, is_comptime=is_comptime, kid=kid);
}

impl Parser.parse_delete_stmt -> DeleteStmt {
    del_uni = self.consume_uni(TokenKind.KW_DELETE);
    kid: list[UniNode] = [del_uni];
    targets: list[Expr] = [];
    first = self.parse_expression();
    targets.append(first);
    kid.append(first);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        nxt = self.parse_expression();
        targets.append(nxt);
        kid.append(nxt);
    }
    self._recover_misplaced_disconnect();
    self.expect(TokenKind.SEMI);
    kid.append(self.make_semi());
    return DeleteStmt(targets=targets, kid=kid);
}

impl Parser._recover_misplaced_disconnect -> None {
    if not self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ) {
        return;
    }
    self.emit_diag(
        "Connect/disconnect operator requires a right operand",
        "E0026",
        help="Connect (`++>`, `+>:T:+>`) and disconnect (`del -->`, `del ->:T:->`) operators are binary -- supply the right-hand side, e.g. `a ++> b;` or `a del --> b;`."
    );
    while not self.at_end()
        and not self.check_any(
            TokenKind.SEMI, TokenKind.RBRACE, TokenKind.RPAREN, TokenKind.RSQUARE
        ) {
        self.advance();
    }
}

impl Parser.parse_ownership_prefix(kids: list[UniNode]) -> tuple[OwnershipKind, bool] {
    if self.check(TokenKind.KW_OWN) {
        own_tok = self.expect(TokenKind.KW_OWN);
        kids.append(self.make_uni_token(own_tok));
        return (OwnershipKind.OWN, False);
    } elif self.check(TokenKind.KW_LIN) {
        lin_tok = self.expect(TokenKind.KW_LIN);
        kids.append(self.make_uni_token(lin_tok));
        return (OwnershipKind.OWN, True);
    } elif self.check(TokenKind.KW_IMM) {
        imm_tok = self.expect(TokenKind.KW_IMM);
        kids.append(self.make_uni_token(imm_tok));
        return (OwnershipKind.IMM, False);
    } elif self.check(TokenKind.BW_AND) {
        amp_tok = self.expect(TokenKind.BW_AND);
        kids.append(self.make_uni_token(amp_tok));
        if self.check(TokenKind.KW_MUT) {
            mut_tok = self.expect(TokenKind.KW_MUT);
            kids.append(self.make_uni_token(mut_tok));
            return (OwnershipKind.MUT_BORROW, False);
        }
        return (OwnershipKind.BORROW, False);
    }
    return (OwnershipKind.NONE, False);
}

impl Parser.parse_assignment_with_target(
    target: Expr, require_semi: bool = True
) -> Assignment {
    type_tag: (SubTag | None) = None;
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());

        own_kid: list[UniNode] = [colon_uni];
        (own_kind, own_lin) = self.parse_ownership_prefix(own_kid);
        tp = self.parse_pipe();
        own_kid.append(tp);
        type_tag = SubTag(tag=tp, ownership=own_kind, linear=own_lin, kid=own_kid);
    }
    value: (Expr | YieldExpr | None) = None;
    aug_op: (Token | None) = None;
    targets: list[Expr] = [target];
    eq_unis: list[Token] = [];
    if self.match_tok(TokenKind.EQ) {
        eq_unis.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.KW_YIELD) {
            value = self.parse_yield_stmt();
        } else {
            value = self.parse_expression();
        }

        while self.check(TokenKind.EQ)
            and not self.check_any(TokenKind.SEMI, TokenKind.RBRACE) {
            self.expect(TokenKind.EQ);
            eq_unis.append(self.make_uni_token(self.previous()));
            if value is not None {
                targets.append(value);
            }
            if self.check(TokenKind.KW_YIELD) {
                value = self.parse_yield_stmt();
            } else {
                value = self.parse_expression();
            }
        }
    } elif self.check_any(
        TokenKind.ADD_EQ,
        TokenKind.SUB_EQ,
        TokenKind.MUL_EQ,
        TokenKind.DIV_EQ,
        TokenKind.FLOOR_DIV_EQ,
        TokenKind.MOD_EQ,
        TokenKind.STAR_POW_EQ,
        TokenKind.MATMUL_EQ,
        TokenKind.BW_AND_EQ,
        TokenKind.BW_OR_EQ,
        TokenKind.BW_XOR_EQ,
        TokenKind.LSHIFT_EQ,
        TokenKind.RSHIFT_EQ
    ) {
        aug_tok = self.expect_any(
            TokenKind.ADD_EQ,
            TokenKind.SUB_EQ,
            TokenKind.MUL_EQ,
            TokenKind.DIV_EQ,
            TokenKind.FLOOR_DIV_EQ,
            TokenKind.MOD_EQ,
            TokenKind.STAR_POW_EQ,
            TokenKind.MATMUL_EQ,
            TokenKind.BW_AND_EQ,
            TokenKind.BW_OR_EQ,
            TokenKind.BW_XOR_EQ,
            TokenKind.LSHIFT_EQ,
            TokenKind.RSHIFT_EQ
        );
        aug_op = self.make_uni_token(aug_tok);
        if self.check(TokenKind.KW_YIELD) {
            value = self.parse_yield_stmt();
        } else {
            value = self.parse_expression();
        }
    }

    kid: list[UniNode] = [];
    eq_idx = 0;
    for (ti, tgt) in enumerate(targets) {
        kid.append(tgt);
        if ti < len(targets) - 1 {
            kid.append(eq_unis[eq_idx]);
            eq_idx += 1;
        }
    }
    if type_tag is not None {
        kid.append(type_tag);
    }
    if aug_op is not None {
        kid.append(aug_op);
        if value is not None {
            kid.append(value);
        }
    } elif value is not None {
        kid.append(eq_unis[eq_idx] if eq_idx < len(eq_unis) else eq_unis[-1]);
        kid.append(value);
    }

    if require_semi {
        if not self.check(TokenKind.SEMI)
            and value is not None
            and isinstance(value, Name)
            and value.value == "new" {
            self.emit_diag(
                "Use the `new(target, ...args)` ambient builtin to create new instances",
                "E0012",
                loc=self.current().loc,
                help="`new` is a portable constructor: it lowers to `Cls(*args)` on the server and to `Reflect.construct(Cls, [args])` in cl blocks."
            );
        } else {
            self.expect(TokenKind.SEMI);
        }
        kid.append(self.make_semi());
    } elif self.match_tok(TokenKind.SEMI) {
        kid.append(self.make_semi());
    }
    return Assignment(
        target=targets,
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=aug_op,
        is_enum_stmt=False
    );
}

impl Parser.parse_import_stmt -> Import {
    is_comptime = False;
    kid: list[UniNode] = [];
    if self.match_tok(TokenKind.KW_COMPTIME) {
        is_comptime = True;
        kid.append(self.make_uni_token(self.previous()));
    }
    is_include = False;
    if self.match_tok(TokenKind.KW_INCLUDE) {
        is_include = True;
    } else {
        self.expect(TokenKind.KW_IMPORT);
    }
    kid.append(self.make_uni_token(self.previous()));

    is_typed = False;
    if not is_include and self.match_tok(TokenKind.TYP_TYPE) {
        is_typed = True;
        kid.append(self.make_uni_token(self.previous()));
    }

    from_loc: ModulePath | None = None;
    is_clib_import = False;
    if self.match_tok(TokenKind.KW_FROM) {
        kid.append(self.make_uni_token(self.previous()));
        result = self.parse_from_path();
        from_loc = result[0];
        is_clib_import = result[1];
        if from_loc is not None {
            kid.append(from_loc);
        }
    }

    items: list[ModuleItem | ModulePath] = [];
    clib_decls: list[UniNode] = [];
    if self.check(TokenKind.LBRACE) {
        (items, clib_decls) = self.parse_import_items(kid, is_clib_import);
    } elif from_loc is None {
        while True {
            path_names: list[Name | String] = [];
            path_kid: list[UniNode] = [];
            if self.check(TokenKind.STRING) {
                str_tok = self.expect(TokenKind.STRING);
                str_node = self.make_string(str_tok);
                path_names.append(str_node);
                path_kid.append(str_node);
            } elif self.check_name() or self.is_keyword_token() {
                if self.check_name() or self.is_keyword_token() {
                    name_tok = self.advance();
                } else {
                    name_tok = self.expect_name("module path");
                }
                nm = self.make_name(name_tok);
                path_names.append(nm);
                path_kid.append(nm);
                while self.match_tok(TokenKind.DOT) {
                    path_kid.append(self.make_uni_token(self.previous()));
                    if self.check_name() or self.is_keyword_token() {
                        name_tok = self.advance();
                    } else {
                        name_tok = self.expect_name("module path");
                    }
                    nm = self.make_name(name_tok);
                    path_names.append(nm);
                    path_kid.append(nm);
                }
            }
            if len(path_kid) == 0 {
                path_kid = [EmptyToken()];
            }

            alias: Name | None = None;
            if self.match_tok(TokenKind.KW_AS) {
                as_uni = self.make_uni_token(self.previous());
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
                path_kid.append(as_uni);
                path_kid.append(alias);
            }
            path = ModulePath(path=path_names, level=0, alias=alias, kid=path_kid);
            items.append(path);
            kid.append(path);

            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    if from_loc is None {
        self.expect(TokenKind.SEMI);
        kid.append(self.make_semi());
    }
    return Import(
        from_loc=from_loc,
        items=items,
        is_absorb=is_include,
        is_typed=is_typed,
        is_comptime=is_comptime,
        kid=kid,
        doc=None,
        clib_decls=clib_decls
    );
}

impl Parser.parse_from_path -> tuple[(ModulePath | None, bool)] {
    path_names: list[Name | String] = [];
    level = 0;
    path_kid: list[UniNode] = [];
    is_clib_import = False;
    if self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
        while self.check_any(TokenKind.DOT, TokenKind.ELLIPSIS) {
            if self.check(TokenKind.ELLIPSIS) {
                tok = self.expect(TokenKind.ELLIPSIS);
                level += 3;
                path_kid.append(self.make_ellipsis(tok));
            } else {
                tok = self.expect(TokenKind.DOT);
                level += 1;
                path_kid.append(self.make_uni_token(tok));
            }
        }
    }
    if self.check(TokenKind.STRING) {
        str_tok = self.expect(TokenKind.STRING);
        str_node = self.make_string(str_tok);
        path_names.append(str_node);
        path_kid.append(str_node);
        is_clib_import = True;
    } elif self.check_name() or self.is_keyword_token() {
        if self.check_name() or self.is_keyword_token() {
            name_tok = self.advance();
        } else {
            name_tok = self.expect_name("module path");
        }
        nm = self.make_name(name_tok);
        path_names.append(nm);
        path_kid.append(nm);
        while self.match_tok(TokenKind.DOT) {
            path_kid.append(self.make_uni_token(self.previous()));
            if self.check_name() or self.is_keyword_token() {
                name_tok = self.advance();
            } else {
                name_tok = self.expect_name("module path");
            }
            nm = self.make_name(name_tok);
            path_names.append(nm);
            path_kid.append(nm);
        }
    }
    if len(path_kid) == 0 {
        path_kid = [EmptyToken()];
    }
    from_loc = ModulePath(path=path_names, level=level, alias=None, kid=path_kid);
    return (from_loc, is_clib_import);
}

impl Parser.parse_import_items(
    kid: list[UniNode], is_clib_import: bool
) -> tuple[(list[ModuleItem | ModulePath], list[UniNode])] {
    items: list[ModuleItem | ModulePath] = [];
    clib_decls: list[UniNode] = [];
    self.expect(TokenKind.LBRACE);
    kid.append(self.make_uni_token(self.previous()));

    if self.check_any(
        TokenKind.KW_DEF,
        TokenKind.KW_CAN,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM,
        TokenKind.KW_ASYNC,
        TokenKind.STRING,
        TokenKind.KW_GLOBAL,
        TokenKind.KW_HAS
    )
        and (is_clib_import or not self.check(TokenKind.STRING)) {
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            stmt = self.parse_element_stmt();
            if stmt is not None {
                clib_decls.append(stmt);
                kid.append(stmt);
                if isinstance(stmt, ContextAwareNode) {
                    stmt.code_context = CodeContext.NATIVE;
                }
            }
        }
    } else {
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            item_name: UniNode;
            if self.check(TokenKind.STAR_MUL) {
                star_tok = self.expect(TokenKind.STAR_MUL);
                item_name = self.make_uni_token(star_tok);
            } else {
                item_name_tok: LexToken;
                if self.check(TokenKind.KW_DEFAULT) {
                    item_name_tok = self.expect(TokenKind.KW_DEFAULT);
                    item_name = self.make_uni_token(item_name_tok);
                } else {
                    item_name_tok = self.expect_name("import item");
                    item_name = self.make_name(item_name_tok);
                }
            }
            alias = None;
            as_tok: LexToken | None = None;
            if self.match_tok(TokenKind.KW_AS) {
                as_tok = self.previous();
                alias_tok = self.expect_name();
                alias = self.make_name(alias_tok);
            }
            item_kid: list[UniNode] = [item_name];
            if alias is not None and as_tok is not None {
                item_kid.append(self.make_uni_token(as_tok));
                item_kid.append(alias);
            }
            item = ModuleItem(name=item_name, alias=alias, kid=item_kid);
            items.append(item);
            kid.append(item);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    rbrace_uni = self.consume_uni(TokenKind.RBRACE);
    kid.append(rbrace_uni);
    return (items, clib_decls);
}

impl Parser.parse_switch_stmt -> SwitchStmt {
    switch_uni = self.consume_uni(TokenKind.KW_SWITCH);
    target = self.parse_expression();
    lb_uni = self.consume_uni(TokenKind.LBRACE);
    cases: list[SwitchCase] = [];
    while self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT) {
        cases.append(self.parse_switch_case());
    }

    rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [switch_uni, target, lb_uni];
    kid.extend(cases);
    kid.append(rb_uni);
    return SwitchStmt(target=target, cases=cases, kid=kid);
}

impl Parser.parse_switch_case -> SwitchCase {
    is_default = False;
    pattern = None;
    kw_uni = None;
    if self.match_tok(TokenKind.KW_DEFAULT) {
        is_default = True;
        kw_uni = self.make_uni_token(self.previous());
    } else {
        kw_uni = self.consume_uni(TokenKind.KW_CASE);
        pattern = self.parse_pattern();
    }
    colon_uni = self.consume_uni(TokenKind.COLON);
    body: list[CodeBlockStmt] = [];
    while not self.check_any(TokenKind.KW_CASE, TokenKind.KW_DEFAULT, TokenKind.RBRACE)
        and not self.at_end() {
        before = self.pos;
        stmt = self.parse_statement();
        if stmt is not None {
            body.append(stmt);
        }

        if self.pos == before {
            self.advance();
        }
    }
    kid: list[UniNode] = [kw_uni];
    if pattern {
        kid.append(pattern);
    }
    kid.append(colon_uni);
    kid.extend(body);
    return SwitchCase(pattern=pattern, body=body, kid=kid);
}

impl Parser.parse_visit_stmt -> VisitStmt {
    visit_uni = self.consume_uni(TokenKind.KW_VISIT);

    insert_loc = None;
    colon1_uni = None;
    colon2_uni = None;
    if self.match_tok(TokenKind.COLON) {
        colon1_uni = self.make_uni_token(self.previous());
        insert_loc = self.parse_expression();
        colon2_uni = self.consume_uni(TokenKind.COLON);
    }
    target = self.parse_expression();
    else_body = None;
    has_semi = False;
    if self.check(TokenKind.KW_ELSE) {
        else_body = self.parse_else_stmt();
    } elif self.match_tok(TokenKind.SEMI) {
        has_semi = True;
    }
    kid: list[UniNode] = [visit_uni];
    if insert_loc is not None and colon1_uni is not None and colon2_uni is not None {
        kid.append(colon1_uni);
        kid.append(insert_loc);
        kid.append(colon2_uni);
    }
    kid.append(target);
    if else_body {
        kid.append(else_body);
    } elif has_semi {
        kid.append(self.make_semi());
    }
    return VisitStmt(
        insert_loc=insert_loc, target=target, else_body=else_body, kid=kid
    );
}

impl Parser.parse_report_stmt -> ReportStmt {
    report_uni = self.consume_uni(TokenKind.KW_REPORT);
    expr = self.parse_expression();
    self.expect(TokenKind.SEMI);
    kid: list[UniNode] = [report_uni, expr, self.make_semi()];
    return ReportStmt(expr=expr, kid=kid);
}
