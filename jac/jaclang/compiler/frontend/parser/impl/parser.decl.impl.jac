import from jaclang.compiler.frontend.constant {
    Tokens as Tok,
    SymbolAccess,
    SymbolType
}


impl Parser.parse_archetype -> Archetype {
    decorators: list[Expr] = [];
    decor_unis: list[Token] = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    is_async = False;
    async_uni = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    arch_tok = self.expect_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    );
    arch_type = self.make_uni_token(arch_tok);
    access = self.parse_access_tag();
    name_tok = self.expect_name("archetype");
    name = self.make_name(name_tok);

    tp_list: (list[TypeParam] | None) = None;
    tp_lb_uni: Token | None = None;
    tp_rb_uni: Token | None = None;
    tp_comma_unis: list[Token] = [];
    if self.match_tok(TokenKind.LSQUARE) {
        tp_lb_uni = self.make_uni_token(self.previous());
        (tp_list, tp_comma_unis) = self.parse_type_params();
        tp_rb_uni = self.consume_uni(TokenKind.RSQUARE);
    }
    base_classes: list[Expr] = [];
    keywords: list[KWPair] = [];
    inherit_items: list[Expr | KWPair] = [];
    lp_uni = None;
    rp_uni = None;
    arch_comma_unis: list[Token] = [];
    if self.match_tok(TokenKind.LPAREN) {
        lp_uni = self.make_uni_token(self.previous());
        if not self.check(TokenKind.RPAREN) {
            `entry = self.parse_call_arg();
            inherit_items.append(`entry);
            if isinstance(`entry, KWPair) {
                keywords.append(`entry);
            } else {
                base_classes.append(`entry);
            }
            while self.match_tok(TokenKind.COMMA) {
                arch_comma_unis.append(self.make_uni_token(self.previous()));
                if self.check(TokenKind.RPAREN) {
                    break;
                }
                `entry = self.parse_call_arg();
                inherit_items.append(`entry);
                if isinstance(`entry, KWPair) {
                    keywords.append(`entry);
                } else {
                    base_classes.append(`entry);
                }
            }
        }
        rp_uni = self.consume_uni(TokenKind.RPAREN);
    }

    src_endpoint = None;
    tgt_endpoint = None;
    ep_colon_uni = None;
    ep_arrow_uni = None;
    if self.check(TokenKind.COLON) {
        self.expect(TokenKind.COLON);
        ep_colon_uni = self.make_uni_token(self.previous());
        src_endpoint = self.parse_atomic_chain();
        ep_arrow_uni = self.consume_uni(TokenKind.ARROW_R);
        tgt_endpoint = self.parse_atomic_chain();
    }
    body_l: (list[UniNode] | None) = None;
    body_lb_uni = None;
    body_rb_uni = None;
    if self.match_tok(TokenKind.LBRACE) {
        body_l = [];
        body_lb_uni = self.make_uni_token(self.previous());
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            before = self.pos;
            member = self.parse_archetype_member();
            if member is not None {
                body_l.append(member);
            }

            if self.pos == before {
                self.advance();
            }
        }
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list[UniNode] = [];
    for (i, d) in enumerate(decorators) {
        kid.append(decor_unis[i]);
        kid.append(d);
    }
    if is_async and async_uni is not None {
        kid.append(async_uni);
    }
    kid.append(arch_type);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if tp_list is not None and tp_lb_uni is not None and tp_rb_uni is not None {
        kid.append(tp_lb_uni);
        for (i, tp) in enumerate(tp_list) {
            if i > 0 {
                kid.append(tp_comma_unis[i - 1]);
            }
            kid.append(tp);
        }
        kid.append(tp_rb_uni);
    }
    if lp_uni is not None {
        kid.append(lp_uni);
        for (i, it) in enumerate(inherit_items) {
            if i > 0 {
                kid.append(arch_comma_unis[i - 1]);
            }
            kid.append(it);
        }
        if rp_uni is not None {
            kid.append(rp_uni);
        }
    }
    if src_endpoint is not None
        and ep_colon_uni is not None
        and ep_arrow_uni is not None
        and tgt_endpoint is not None {
        kid.append(ep_colon_uni);
        kid.append(src_endpoint);
        kid.append(ep_arrow_uni);
        kid.append(tgt_endpoint);
    }
    if body_l is not None and body_lb_uni is not None and body_rb_uni is not None {
        kid.append(body_lb_uni);
        kid.extend(body_l);
        kid.append(body_rb_uni);
    } else {
        kid.append(self.make_semi());
    }
    arch = Archetype(
        name=name,
        arch_type=arch_type,
        access=access,
        base_classes=base_classes,
        keywords=keywords,
        body=body_l,
        kid=kid,
        doc=None,
        decorators=decorators,
        type_params=tp_list,
        src_endpoint=src_endpoint,
        tgt_endpoint=tgt_endpoint
    );
    if is_async {
        arch.is_async = True;
    }
    return arch;
}

impl Parser.parse_archetype_member -> UniNode | None {
    self._skip_semicolons();
    if self.check(TokenKind.RBRACE) or self.at_end() {
        return None;
    }

    doc: String | None = None;
    if self.check(TokenKind.STRING) {
        doc_tok = self.expect(TokenKind.STRING);
        doc = self.make_string(doc_tok);
    }

    if self.check(TokenKind.DECOR_OP) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }

    if self.check(TokenKind.KW_STATIC) {
        if self.check_peek(TokenKind.KW_HAS) {
            has_stmt = self.parse_has_stmt();
            if doc {
                _ = self._attach_doc(has_stmt, doc);
            }
            return has_stmt;
        }

        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }
    if self.check(TokenKind.KW_HAS) {
        has_stmt = self.parse_has_stmt();
        if doc {
            _ = self._attach_doc(has_stmt, doc);
        }
        return has_stmt;
    }

    if self.check(TokenKind.KW_ASYNC) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }
    if self.check(TokenKind.KW_COMPTIME)
        and not self.check_peek_any(
            TokenKind.KW_DEF,
            TokenKind.KW_CAN,
            TokenKind.KW_OVERRIDE,
            TokenKind.KW_STATIC,
            TokenKind.KW_ASYNC
        ) {
        ct_globals = self.parse_comptime_global();
        if doc {
            _ = self._attach_doc(ct_globals, doc);
        }
        return ct_globals;
    }
    if self.check_any(
        TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_OVERRIDE, TokenKind.KW_COMPTIME
    ) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }

    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        ability = self.parse_ability();
        if doc {
            _ = self._attach_doc(ability, doc);
        }
        return ability;
    }
    if self.check_any(
        TokenKind.KW_OBJECT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_CLASS
    ) {
        archetype = self.parse_archetype();
        if doc {
            _ = self._attach_doc(archetype, doc);
        }
        return archetype;
    }
    if self.check(TokenKind.KW_ENUM) {
        enum_node = self.parse_enum();
        if doc {
            _ = self._attach_doc(enum_node, doc);
        }
        return enum_node;
    }

    if self.check(TokenKind.KW_IMPL) {
        impl_node = self.parse_impl_def();
        if doc {
            _ = self._attach_doc(impl_node, doc);
        }
        return impl_node;
    }

    if self.check(TokenKind.PYNLINE) {
        py_tok = self.expect(TokenKind.PYNLINE);
        py_code = self.make_uni_token(py_tok);
        return PyInlineCode(code=py_code, kid=[py_code]);
    }

    if self.check(TokenKind.KW_WITH) {
        self.expect(TokenKind.KW_WITH);
        with_tok = self.previous();
        if self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT) {
            event_tok = self.expect_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT);
            lb_uni = self.consume_uni(TokenKind.LBRACE);
            body = self.parse_code_block_stmts();
            rb_uni = self.consume_uni(TokenKind.RBRACE);
            kid: list[UniNode] = [
                self.make_uni_token(with_tok),
                self.make_uni_token(event_tok),
                lb_uni
            ];
            kid.extend(body);
            kid.append(rb_uni);
            module_code = ModuleCode(name=None, body=body, kid=kid, doc=None);
            if doc {
                _ = self._attach_doc(module_code, doc);
            }
            return module_code;
        }
    }

    if self.check(TokenKind.NAME) {
        stmt = self.parse_statement();
        return stmt;
    }
    self._error_unexpected_member();
    return EmptyToken();
}

impl Parser._skip_semicolons{
    while self.match_tok(TokenKind.SEMI) {
        continue;
    }
}

impl Parser._error_unexpected_member{
    self.emit_diag("Unexpected token in archetype body", "E0046");
    self.advance();
}

impl Parser.parse_has_stmt -> ArchHas {
    is_static = False;
    static_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    has_tok = self.expect(TokenKind.KW_HAS);
    access = self.parse_access_tag();
    vars: list[HasVar] = [];
    has_comma_unis: list[Token] = [];
    vars.append(self.parse_has_var());
    while self.match_tok(TokenKind.COMMA) {
        has_comma_unis.append(self.make_uni_token(self.previous()));
        vars.append(self.parse_has_var());
    }

    last_had_accessors = vars and (vars[len(vars) - 1].accessors is not None);
    saw_semi = False;
    if last_had_accessors {
        saw_semi = self.match_tok(TokenKind.SEMI) is not None;
    } else {
        self.expect(TokenKind.SEMI);
        saw_semi = True;
    }
    kid: list[UniNode] = [];
    if static_tok is not None {
        kid.append(self.make_uni_token(static_tok));
    }
    kid.append(self.make_uni_token(has_tok));
    if access {
        kid.append(access);
    }

    for (i, v) in enumerate(vars) {
        if i > 0 {
            kid.append(has_comma_unis[i - 1]);
        }
        kid.append(v);
    }

    if saw_semi {
        prev = self.previous();
        kid.append(
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
    return ArchHas(
        is_static=is_static,
        access=access,
        vars=vars,
        is_frozen=False,
        kid=kid,
        doc=None
    );
}

impl Parser.parse_has_var -> HasVar {
    name_tok = self.expect_name("field");
    name: Name = self.make_name(name_tok);
    colon_uni = self.consume_uni(TokenKind.COLON);
    type_expr = self.parse_pipe();
    type_tag = SubTag(tag=type_expr, kid=[colon_uni, type_expr]);
    value: (Expr | None) = None;
    defer = False;
    eq_uni: Token | None = None;
    postinit_name: Name | None = None;
    if self.match_tok(TokenKind.EQ) {
        eq_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
    } elif self.match_tok(TokenKind.KW_POST_INIT) {
        postinit_name = self.make_special_name(self.previous());
        defer = True;
    }

    acc_list: (list[Ability] | None) = None;
    acc_lb_uni: Token | None = None;
    acc_rb_uni: Token | None = None;
    if self.check(TokenKind.LBRACE) {
        if value is not None {
            self.emit_diag(
                "Property declarations cannot have an initializer",
                "E0080",
                help="Declare backing storage as a separate `has` field (e.g. `has _x: T = value;`) and reference it from your accessors."
            );
        }
        acc_lb_uni = self.consume_uni(TokenKind.LBRACE);
        acc_list = [];
        while not self.check(TokenKind.RBRACE) {
            acc_list.append(self.parse_accessor());
        }
        acc_rb_uni = self.consume_uni(TokenKind.RBRACE);
        if len(acc_list) == 0 {
            self.emit_diag(
                "Property declaration must contain at least one of `getter`, `setter`, `deleter`",
                "E0081"
            );
        }
    }
    kid: list[UniNode] = [name, type_tag];
    if value is not None and eq_uni is not None {
        kid.append(eq_uni);
        kid.append(value);
    }
    if defer and postinit_name is not None {
        kid.append(postinit_name);
    }
    if acc_list is not None and acc_lb_uni is not None and acc_rb_uni is not None {
        kid.append(acc_lb_uni);
        for acc in acc_list {
            kid.append(acc);
        }
        kid.append(acc_rb_uni);
    }
    return HasVar(
        name=name,
        type_tag=type_tag,
        value=value,
        defer=defer,
        accessors=acc_list,
        kid=kid
    );
}

impl Parser._consume_accessor_kind -> tuple[str, LexToken] {
    if self.check(TokenKind.KW_DELETER) {
        return ("deleter", self.advance());
    }
    if self.check(TokenKind.KW_SETTER) {
        return ("setter", self.advance());
    }
    if self.check(TokenKind.KW_GETTER) {
        return ("property", self.advance());
    }
    self.emit_diag(
        f"Expected 'getter' or 'setter', got '{self.current().kind.value}'", "E0001"
    );
    return ("property", self.advance());
}

impl Parser.parse_accessor -> Ability {
    (kind_str, kind_tok) = self._consume_accessor_kind();
    name = self.make_name(kind_tok);

    signature: FuncSignature | None = self.parse_func_signature();
    has_sig_content = not (
        len(signature.kid) == 1 and isinstance(signature.kid[0], EmptyToken)
    );
    if not has_sig_content {
        signature = None;
    }

    body: (list[CodeBlockStmt] | None) = None;
    body_lb_uni: Token | None = None;
    body_rb_uni: Token | None = None;
    if self.match_tok(TokenKind.LBRACE) {
        body_lb_uni = self.make_uni_token(self.previous());
        body = self.parse_code_block_stmts();
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list[UniNode] = [name];
    if signature is not None {
        kid.append(signature);
    }
    if body is not None and body_lb_uni is not None and body_rb_uni is not None {
        kid.append(body_lb_uni);
        kid.extend(body);
        kid.append(body_rb_uni);
    } else {
        kid.append(self.make_semi());
    }
    return Ability(
        name_ref=name,
        is_async=False,
        is_override=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        access=None,
        signature=signature,
        body=body,
        kid=kid,
        doc=None,
        decorators=None,
        type_params=None,
        accessor_kind=kind_str
    );
}

impl Parser.parse_ability -> Ability {
    decorators: list[Expr] = [];
    decor_unis: list[Token] = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    is_comptime = False;
    comptime_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_COMPTIME) {
        is_comptime = True;
        comptime_tok = self.previous();
    }
    is_override = False;
    override_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_OVERRIDE) {
        is_override = True;
        override_tok = self.previous();
    }
    is_classmethod = False;
    classmethod_tok: LexToken | None = None;
    if self.check(TokenKind.KW_CLASS)
        and self.check_peek_any(
            TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC
        ) {
        self.expect(TokenKind.KW_CLASS);
        is_classmethod = True;
        classmethod_tok = self.previous();
    }
    is_static = False;
    static_tok: LexToken | None = None;
    if not is_classmethod and self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    is_async = False;
    async_tok: LexToken | None = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_tok = self.previous();

        (is_override, override_tok, is_static, static_tok) = self._parse_post_async_modifiers(
            is_override, override_tok, is_static, static_tok
        );
        if not is_classmethod
            and self.check(TokenKind.KW_CLASS)
            and self.check_peek_any(TokenKind.KW_DEF, TokenKind.KW_CAN) {
            self.expect(TokenKind.KW_CLASS);
            is_classmethod = True;
            classmethod_tok = self.previous();
        }
    }
    is_can = self.check(TokenKind.KW_CAN);
    ability_tok = self.expect_any(TokenKind.KW_DEF, TokenKind.KW_CAN);
    access = self.parse_access_tag();
    name: NameAtom | None = None;

    if self.check_name() {
        name_tok = self.expect_name("ability");
        name = self.make_name(name_tok);
    } elif is_special_var_kind(self.current().kind) {
        name_tok = self.advance();
        name = SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif self.is_keyword_token() and not (is_can and self.check(TokenKind.KW_WITH)) {
        name_tok = self.expect_name("ability");
        name = self.make_name(name_tok);
    }

    tp_list: (list[TypeParam] | None) = None;
    tp_lb_uni: Token | None = None;
    tp_rb_uni: Token | None = None;
    tp_comma_unis: list[Token] = [];
    if self.match_tok(TokenKind.LSQUARE) {
        tp_lb_uni = self.make_uni_token(self.previous());
        (tp_list, tp_comma_unis) = self.parse_type_params();
        tp_rb_uni = self.consume_uni(TokenKind.RSQUARE);
    }
    signature: FuncSignature | EventSignature | None;
    if is_can and self.check(TokenKind.KW_WITH) {
        with_uni = self.make_uni_token(self.expect(TokenKind.KW_WITH));
        event_type = self.parse_expression()
            if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
            else None;
        event_tok = self.expect_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT);
        event_uni_tok = self.make_uni_token(event_tok);

        sig_kid: list[UniNode] = [with_uni];
        if event_type {
            sig_kid.append(event_type);
        }
        sig_kid.append(event_uni_tok);
        signature = EventSignature(
            event=event_uni_tok, arch_tag_info=event_type, kid=sig_kid
        );
    } elif is_can {
        self.emit_diag(
            "Expected 'with' after 'can' ability name (use 'def' for function-style declarations)",
            "E0034"
        );
        signature = self.parse_func_signature();
    } else {
        signature = self.parse_func_signature();
    }
    body_stmts: (list[CodeBlockStmt] | None) = None;
    body_expr: Expr | None = None;
    is_abstract = False;
    body_type = "semi";
    body_lb_uni = None;
    body_rb_uni = None;
    body_by_uni = None;
    body_abs_uni = None;
    if self.match_tok(TokenKind.LBRACE) {
        body_type = "brace";
        body_lb_uni = self.make_uni_token(self.previous());
        body_stmts = self.parse_code_block_stmts();
        body_stmts = self._apply_implicit_return(body_stmts);
        body_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body_type = "by";
        body_by_uni = self.make_uni_token(self.previous());
        by_expr = self.parse_expression();
        self.expect(TokenKind.SEMI);
        by_expr.add_kids_left([body_by_uni]);
        by_expr.add_kids_right([self.make_semi()]);
        body_expr = by_expr;
    } else {
        if self.match_tok(TokenKind.KW_ABSTRACT) {
            is_abstract = True;
            body_abs_uni = self.make_uni_token(self.previous());
        }
        self.expect(TokenKind.SEMI);
    }
    kid: list[UniNode] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(decor_unis[di]);
        kid.append(d);
    }
    if comptime_tok is not None {
        kid.append(self.make_uni_token(comptime_tok));
    }
    if override_tok is not None {
        kid.append(self.make_uni_token(override_tok));
    }
    if classmethod_tok is not None {
        kid.append(self.make_uni_token(classmethod_tok));
    }
    if static_tok is not None {
        kid.append(self.make_uni_token(static_tok));
    }
    if async_tok is not None {
        kid.append(self.make_uni_token(async_tok));
    }
    kid.append(self.make_uni_token(ability_tok));
    if access {
        kid.append(access);
    }
    if name {
        kid.append(name);
    }
    if tp_list is not None and tp_lb_uni is not None and tp_rb_uni is not None {
        kid.append(tp_lb_uni);
        for (i, tp) in enumerate(tp_list) {
            if i > 0 {
                kid.append(tp_comma_unis[i - 1]);
            }
            kid.append(tp);
        }
        kid.append(tp_rb_uni);
    }

    kid.append(signature);
    if body_type == "brace" and body_stmts is not None {
        if body_lb_uni is not None {
            kid.append(body_lb_uni);
        }
        kid.extend(body_stmts);
        if body_rb_uni is not None {
            kid.append(body_rb_uni);
        }
    } elif body_type == "by" and body_expr is not None {
        kid.append(body_expr);
    } else {
        if is_abstract and body_abs_uni is not None {
            kid.append(body_abs_uni);
        }
        kid.append(self.make_semi());
    }
    body_arg: (Expr | list[CodeBlockStmt] | None) = None;
    if body_type == "brace" {
        body_arg = body_stmts;
    } elif body_type == "by" and body_expr is not None {
        body_arg = body_expr;
    }
    return Ability(
        name_ref=name,
        is_async=is_async,
        is_override=is_override,
        is_static=is_static,
        is_classmethod=is_classmethod,
        is_abstract=is_abstract,
        access=access,
        signature=signature,
        body=body_arg,
        kid=kid,
        doc=None,
        decorators=decorators,
        type_params=tp_list,
        is_comptime=is_comptime
    );
}

impl Parser._parse_post_async_modifiers(
    is_override: bool,
    override_tok: (LexToken | None),
    is_static: bool,
    static_tok: (LexToken | None)
) -> tuple[(bool, (LexToken | None), bool, (LexToken | None))] {
    if not is_override and self.match_tok(TokenKind.KW_OVERRIDE) {
        is_override = True;
        override_tok = self.previous();
    }
    if not is_static and self.match_tok(TokenKind.KW_STATIC) {
        is_static = True;
        static_tok = self.previous();
    }
    return (is_override, override_tok, is_static, static_tok);
}

impl Parser.parse_func_signature -> FuncSignature {
    all_params: list[ParamVar] = [];
    return_type = None;
    kid: list[UniNode] = [];
    if self.match_tok(TokenKind.LPAREN) {
        kid.append(self.make_uni_token(self.previous()));
        if not self.check(TokenKind.RPAREN) {
            all_params = self.parse_func_params(kid);
        }
        rparen_uni = self.consume_uni(TokenKind.RPAREN);
        kid.append(rparen_uni);
    }
    if self.match_tok(TokenKind.RETURN_HINT) {
        kid.append(self.make_uni_token(self.previous()));
        return_type = self.parse_pipe();
        kid.append(return_type);
    }

    if len(kid) == 0 {
        kid.append(EmptyToken());
    }

    posonly_params: list[ParamVar] = [];
    regular_params: list[ParamVar] = [];
    kwonly_params: list[ParamVar] = [];
    varargs_param: ParamVar | None = None;
    kwargs_param: ParamVar | None = None;

    saw_bare_star = False;
    saw_slash = False;
    for k in kid {
        if isinstance(k, ParamVar) {
            _u = k.unpack;
            _un = _u.name if _u is not None else None;
            if _un is not None and _un == Tok.STAR_POW {
                kwargs_param = k;
            } elif _un is not None and _un == Tok.STAR_MUL {
                varargs_param = k;
                saw_bare_star = True;
            } elif saw_bare_star {
                kwonly_params.append(k);
            } else {
                regular_params.append(k);
            }
        } elif isinstance(k, Token) {
            _kn = k.name;
            if _kn == Tok.STAR_MUL {
                saw_bare_star = True;
            } elif _kn == Tok.DIV {
                posonly_params = regular_params;
                regular_params = [];
                saw_slash = True;
            }
        }
    }

    for p in posonly_params {
        if isinstance(p, ParamVar) {
            p.param_kind = ParamKind.POSONLY;
        }
    }
    for p in kwonly_params {
        if isinstance(p, ParamVar) {
            p.param_kind = ParamKind.KWONLY;
        }
    }
    if varargs_param is not None {
        varargs_param.param_kind = ParamKind.VARARG;
    }
    if kwargs_param is not None {
        kwargs_param.param_kind = ParamKind.KWARG;
    }
    return FuncSignature(
        posonly_params=posonly_params,
        params=regular_params,
        varargs=varargs_param,
        kwonlyargs=kwonly_params,
        kwargs=kwargs_param,
        return_type=return_type,
        kid=kid
    );
}

impl Parser.parse_func_params(kid: list[UniNode]) -> list[ParamVar] {
    params: list[ParamVar] = [];
    while not self.check(TokenKind.RPAREN) {
        if self.check(TokenKind.STAR_MUL)
            and (
                self.check_peek(TokenKind.COMMA) or self.check_peek(TokenKind.RPAREN)
            ) {
            star_tok = self.expect(TokenKind.STAR_MUL);
            star_uni = self.make_uni_token(star_tok);
            kid.append(star_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        } elif self.check(TokenKind.DIV)
            and (
                self.check_peek(TokenKind.COMMA) or self.check_peek(TokenKind.RPAREN)
            ) {
            div_tok = self.expect(TokenKind.DIV);
            div_uni = self.make_uni_token(div_tok);
            kid.append(div_uni);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        } else {
            pv = self.parse_param_var();
            if pv is None {
                break;
            }
            params.append(pv);
            kid.append(pv);
            if not self.match_tok(TokenKind.COMMA) {
                break;
            }
            kid.append(self.make_uni_token(self.previous()));
        }
    }
    return params;
}

impl Parser.parse_param_var -> ParamVar | None {
    ct_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_COMPTIME) {
        ct_uni = self.make_uni_token(self.previous());
    }
    unpack: Token | None = None;
    if self.check_any(TokenKind.STAR_MUL, TokenKind.STAR_POW) {
        unpack_tok = self.expect_any(TokenKind.STAR_MUL, TokenKind.STAR_POW);
        unpack = self.make_uni_token(unpack_tok);
    }

    if self.check_name() {
        name_tok = self.expect_name("parameter");
        name = self.make_name(name_tok);
    } elif self.check(TokenKind.KW_SELF) {
        name_tok = self.expect(TokenKind.KW_SELF);
        name = SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif self.check_any(
        TokenKind.KW_PROPS, TokenKind.KW_HERE, TokenKind.KW_VISITOR
    ) {
        name_tok = self.expect_any(
            TokenKind.KW_PROPS, TokenKind.KW_HERE, TokenKind.KW_VISITOR
        );
        name = SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif self.is_builtin_type_token() {
        name_tok = self.expect_any(
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
            TokenKind.TYP_TYPE,
            TokenKind.TYP_I8,
            TokenKind.TYP_U8,
            TokenKind.TYP_I16,
            TokenKind.TYP_U16,
            TokenKind.TYP_I32,
            TokenKind.TYP_U32,
            TokenKind.TYP_I64,
            TokenKind.TYP_U64,
            TokenKind.TYP_F32,
            TokenKind.TYP_F64
        );
        name = self.make_name_or_special(name_tok);
    } elif self.is_keyword_token() {
        name_tok = self.expect_name("parameter");
        name = self.make_name(name_tok);
    } else {
        return None;
    }
    type_tag: SubTag | None = None;
    if self.match_tok(TokenKind.COLON) {
        param_colon_uni = self.make_uni_token(self.previous());
        param_type_kid: list[UniNode] = [param_colon_uni];
        (param_kind, param_lin) = self.parse_ownership_prefix(param_type_kid);
        tp = self.parse_pipe();
        param_type_kid.append(tp);
        type_tag = SubTag(
            tag=tp, ownership=param_kind, linear=param_lin, kid=param_type_kid
        );
    }
    default_val: Expr | None = None;
    param_eq_uni: Token | None = None;
    if self.match_tok(TokenKind.EQ) {
        param_eq_uni = self.make_uni_token(self.previous());
        default_val = self.parse_expression();
    }
    pv_kid: list[UniNode] = [];
    if ct_uni is not None {
        pv_kid.append(ct_uni);
    }
    if unpack {
        pv_kid.append(unpack);
    }
    pv_kid.append(name);
    if type_tag is not None {
        pv_kid.append(type_tag);
    }
    if default_val is not None and param_eq_uni is not None {
        pv_kid.append(param_eq_uni);
        pv_kid.append(default_val);
    }

    return ParamVar(
        name=name,
        unpack=unpack,
        type_tag=type_tag,
        value=default_val,
        is_comptime=ct_uni is not None,
        kid=pv_kid
    );
}

impl Parser.parse_enum -> Enum {
    decorators: list[Expr] = [];
    enum_decor_unis: list[Token] = [];
    while self.check(TokenKind.DECOR_OP) {
        enum_decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    enum_kw_uni = self.consume_uni(TokenKind.KW_ENUM);
    access = self.parse_access_tag();
    name_tok = self.expect_name("enum");
    name = self.make_name(name_tok);
    value_type: Expr | None = None;
    enum_colon_uni: Token | None = None;
    base_classes: list[Expr] = [];
    enum_lp_uni: Token | None = None;
    enum_rp_uni: Token | None = None;
    enum_base_comma_unis: list[Token] = [];
    if self.match_tok(TokenKind.COLON) {
        enum_colon_uni = self.make_uni_token(self.previous());
        value_type = self.parse_atomic_chain();
    } elif self.match_tok(TokenKind.LPAREN) {
        enum_lp_uni = self.make_uni_token(self.previous());
        if not self.check(TokenKind.RPAREN) {
            base_classes.append(self.parse_atomic_chain());
            while self.match_tok(TokenKind.COMMA) {
                enum_base_comma_unis.append(self.make_uni_token(self.previous()));
                base_classes.append(self.parse_atomic_chain());
            }
        }
        enum_rp_uni = self.consume_uni(TokenKind.RPAREN);
    }
    body_l: (list[UniNode] | None) = None;
    body_kid: list[UniNode] = [];
    enum_lb_uni: Token | None = None;
    enum_rb_uni: Token | None = None;
    if self.match_tok(TokenKind.LBRACE) {
        body_l = [];
        enum_lb_uni = self.make_uni_token(self.previous());
        item: UniNode | None = None;
        while not self.check(TokenKind.RBRACE) and not self.at_end() {
            if self.check_name() {
                member = self.parse_enum_member();
                body_l.append(member);
                body_kid.append(member);
                if self.match_tok(TokenKind.COMMA) {
                    body_kid.append(self.make_uni_token(self.previous()));
                }
            } elif self.check(TokenKind.PYNLINE) {
                py_tok = self.expect(TokenKind.PYNLINE);
                py_code = self.make_uni_token(py_tok);
                pynline = PyInlineCode(code=py_code, kid=[py_code]);
                pynline.is_enum_stmt = True;
                body_l.append(pynline);
                body_kid.append(pynline);
            } elif self.check(TokenKind.KW_WITH) {
                mc = self.parse_module_code();
                mc.is_enum_stmt = True;
                body_l.append(mc);
                body_kid.append(mc);
            } else {
                break;
            }
        }

        enum_rb_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.expect(TokenKind.SEMI);
    }
    kid: list[UniNode] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(enum_decor_unis[di]);
        kid.append(d);
    }
    kid.append(enum_kw_uni);
    if access {
        kid.append(access);
    }
    kid.append(name);
    if value_type is not None and enum_colon_uni is not None {
        kid.append(enum_colon_uni);
        kid.append(value_type);
    } elif base_classes and enum_lp_uni is not None {
        kid.append(enum_lp_uni);
        for (i, base) in enumerate(base_classes) {
            kid.append(base);
            if i < len(base_classes) - 1 {
                kid.append(enum_base_comma_unis[i]);
            }
        }
        if enum_rp_uni is not None {
            kid.append(enum_rp_uni);
        }
    }
    if body_l is not None and enum_lb_uni is not None and enum_rb_uni is not None {
        kid.append(enum_lb_uni);
        kid.extend(body_kid);
        kid.append(enum_rb_uni);
    } else {
        kid.append(self.make_semi());
    }
    return Enum(
        name=name,
        access=access,
        value_type=value_type,
        base_classes=base_classes,
        body=body_l,
        kid=kid,
        doc=None,
        decorators=decorators
    );
}

impl Parser.parse_enum_member -> Assignment {
    name: Expr;
    name_tok = self.expect_name();
    name = self.make_name(name_tok, is_enum_stmt=True);
    value: (Expr | None) = None;
    em_eq_uni: Token | None = None;
    if self.match_tok(TokenKind.EQ) {
        em_eq_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
    }
    kid: list[UniNode] = [name];
    if value is not None and em_eq_uni is not None {
        kid.append(em_eq_uni);
        kid.append(value);
    }
    return Assignment(
        target=[name],
        value=value,
        type_tag=None,
        kid=kid,
        mutable=False,
        aug_op=None,
        is_enum_stmt=True
    );
}

impl Parser.parse_test -> Test {
    decorators: list[Expr] = [];
    decor_unis: list[Token] = [];
    while self.check(TokenKind.DECOR_OP) {
        decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    test_kw_uni = self.consume_uni(TokenKind.KW_TEST);

    name_tok = self.current();
    has_description = False;
    description: String | None = None;
    ident = "";
    if self.check(TokenKind.STRING) {
        str_tok = self.expect(TokenKind.STRING);
        description = self.make_string(str_tok);

        desc_text = _string_lit_text(str_tok.value);
        ident = _test_ident_from_desc(desc_text);
        name_tok = str_tok;
        has_description = True;
    }
    if not ident {
        self._gen_test_idx += 1;
        ident = f"_jac_gen_{self._gen_test_idx}";
    }
    name: Name = Name(
        orig_src=self.source,
        name=Tok.NAME.value,
        value=ident,
        line=name_tok.loc.line,
        end_line=name_tok.loc.end_line,
        col_start=name_tok.loc.col_start,
        col_end=name_tok.loc.col_end,
        pos_start=name_tok.loc.pos_start,
        pos_end=name_tok.loc.pos_end
    );
    test_lb_uni = self.consume_uni(TokenKind.LBRACE);
    body = self.parse_code_block_stmts();
    test_rb_uni = self.consume_uni(TokenKind.RBRACE);
    kid: list[UniNode] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(decor_unis[di]);
        kid.append(d);
    }
    kid.append(test_kw_uni);
    if has_description and description is not None {
        kid.append(description);
    }
    kid.append(test_lb_uni);
    kid.extend(body);
    kid.append(test_rb_uni);
    return Test(
        name=name,
        body=body,
        kid=kid,
        doc=None,
        description=description,
        decorators=decorators
    );
}

impl Parser.parse_global_var -> GlobalVars {
    glob_kw_uni = self.consume_uni(TokenKind.KW_GLOBAL);
    access = self.parse_access_tag();

    assignments: list[Assignment] = [];
    glob_comma_unis: list[Token] = [];
    assignments.append(self.parse_global_var_assignment());
    while self.match_tok(TokenKind.COMMA) {
        glob_comma_unis.append(self.make_uni_token(self.previous()));
        assignments.append(self.parse_global_var_assignment());
    }
    self.expect(TokenKind.SEMI);
    kid: list[UniNode] = [glob_kw_uni];
    if access {
        kid.append(access);
    }

    for (i, a) in enumerate(assignments) {
        if i > 0 {
            kid.append(glob_comma_unis[i - 1]);
        }
        kid.append(a);
    }

    kid.append(
        Semi(
            orig_src=self.source,
            name=Tok.SEMI.value,
            value=";",
            line=self.previous().loc.line,
            end_line=self.previous().loc.end_line,
            col_start=self.previous().loc.col_start,
            col_end=self.previous().loc.col_end,
            pos_start=self.previous().loc.pos_start,
            pos_end=self.previous().loc.pos_end
        )
    );
    return GlobalVars(
        access=access, assignments=assignments, is_frozen=False, kid=kid, doc=None
    );
}

impl Parser.parse_global_var_assignment -> Assignment {
    name_tok: LexToken = self.expect_name("global variable");
    name: Expr = self.make_name(name_tok);
    type_tag: SubTag | None = None;
    if self.match_tok(TokenKind.COLON) {
        gv_colon_uni = self.make_uni_token(self.previous());
        gv_own_kid: list[UniNode] = [gv_colon_uni];
        (gv_own_kind, gv_lin) = self.parse_ownership_prefix(gv_own_kid);
        tp = self.parse_pipe();
        gv_own_kid.append(tp);
        type_tag = SubTag(tag=tp, ownership=gv_own_kind, linear=gv_lin, kid=gv_own_kid);
    }
    value: (Expr | YieldExpr | None) = None;
    targets: list[Expr] = [name];
    gv_eq_unis: list[Token] = [];
    if self.match_tok(TokenKind.EQ) {
        gv_eq_unis.append(self.make_uni_token(self.previous()));
        value = self.parse_expression();

        while self.check(TokenKind.EQ) {
            if value is not None {
                targets.append(value);
            }
            self.expect(TokenKind.EQ);
            gv_eq_unis.append(self.make_uni_token(self.previous()));
            value = self.parse_expression();
        }
    }
    kid: list[UniNode] = [targets[0]];
    if type_tag is not None {
        kid.append(type_tag);
    }
    gv_eq_idx = 0;
    for i in range(1, len(targets)) {
        kid.append(gv_eq_unis[gv_eq_idx]);
        gv_eq_idx += 1;
        kid.append(targets[i]);
    }
    if value is not None {
        kid.append(
            gv_eq_unis[gv_eq_idx] if gv_eq_idx < len(gv_eq_unis) else gv_eq_unis[-1]
        );
        kid.append(value);
    }
    return Assignment(
        target=targets,
        value=value,
        type_tag=type_tag,
        kid=kid,
        mutable=True,
        aug_op=None,
        is_enum_stmt=False
    );
}

impl Parser.parse_impl_def -> ImplDef {
    decorators: list[Expr] = [];
    impl_decor_unis: list[Token] = [];
    while self.check(TokenKind.DECOR_OP) {
        impl_decor_unis.append(self.make_uni_token(self.expect(TokenKind.DECOR_OP)));
        decorators.append(self.parse_atomic_chain());
    }
    impl_uni = self.consume_uni(TokenKind.KW_IMPL);

    target_names: list[NameAtom] = [];
    dot_unis: list[Token] = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        dot_unis.append(self.make_uni_token(self.previous()));
        target_names.append(self.parse_impl_target_name());
    }

    spec_sig: UniNode | None = None;
    spec_is_inh = False;
    base_classes: list[Expr] = [];
    impl_inh_comma_unis: list[Token] = [];
    impl_inh_lp_tok: LexToken | None = None;
    impl_inh_rp_uni: Token | None = None;
    if self.check(TokenKind.LPAREN) {
        is_func_params = False;
        pk1 = self.peek(1).kind;
        if self.peek(2).kind == TokenKind.COLON and pk1 != TokenKind.RPAREN {
            is_func_params = True;
        } elif self.peek(1).kind == TokenKind.KW_SELF {
            is_func_params = True;
        } elif self.peek(1).kind == TokenKind.STAR_MUL
            or self.peek(1).kind == TokenKind.STAR_POW {
            is_func_params = True;
        } elif self.peek(1).kind == TokenKind.RPAREN {
            is_func_params = True;
        }
        if is_func_params {
            spec_sig = self.parse_func_signature();
        } else {
            impl_inh_lp_tok = self.expect(TokenKind.LPAREN);
            if not self.check(TokenKind.RPAREN) {
                base_classes.append(self.parse_atomic_chain());
                while self.match_tok(TokenKind.COMMA) {
                    impl_inh_comma_unis.append(self.make_uni_token(self.previous()));
                    base_classes.append(self.parse_atomic_chain());
                }
            }
            impl_inh_rp_uni = self.consume_uni(TokenKind.RPAREN);
            spec_is_inh = True;
        }
    } elif self.check(TokenKind.KW_WITH) {
        with_tok = self.expect(TokenKind.KW_WITH);
        event_type = self.parse_expression()
            if not self.check_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT)
            else None;
        event_tok = self.expect_any(TokenKind.KW_ENTRY, TokenKind.KW_EXIT);
        ev_kid: list[UniNode] = [self.make_uni_token(with_tok)];
        if event_type is not None {
            ev_kid.append(event_type);
        }
        ev_kid.append(self.make_uni_token(event_tok));
        spec_sig = EventSignature(
            event=self.make_uni_token(event_tok), arch_tag_info=event_type, kid=ev_kid
        );
    } elif self.check(TokenKind.RETURN_HINT)
        or (self.check(TokenKind.LPAREN) and not self.check(TokenKind.LBRACE)) {
        spec_sig = self.parse_func_signature();
    }

    body_stmts3: list[CodeBlockStmt] = [];
    body_expr3: Expr | None = None;
    lb_uni: Token | None = None;
    rb_uni: Token | None = None;
    impl_enum_commas: list[Token] = [];
    if self.match_tok(TokenKind.LBRACE) {
        lb_uni = self.make_uni_token(self.previous());
        if self._is_impl_enum_body() {
            (body_stmts3, impl_enum_commas) = self.parse_impl_enum_body();
        } else {
            body_stmts3 = self._apply_implicit_return(self.parse_code_block_stmts());
        }
        rb_uni = self.consume_uni(TokenKind.RBRACE);
    } elif self.match_tok(TokenKind.KW_BY) {
        body_expr3 = self.parse_expression();
        self.expect(TokenKind.SEMI);
    } else {
        self.emit_diag("Expected '{' or 'by' for impl body", "E0047");
        self.expect(TokenKind.SEMI);
    }
    kid: list[UniNode] = [];
    for (di, d) in enumerate(decorators) {
        kid.append(impl_decor_unis[di]);
        kid.append(d);
    }
    kid.append(impl_uni);
    for (i, n) in enumerate(target_names) {
        kid.append(n);
        if i < len(dot_unis) {
            kid.append(dot_unis[i]);
        }
    }
    if spec_sig is not None {
        kid.append(spec_sig);
    } elif spec_is_inh and len(base_classes) > 0 and impl_inh_lp_tok is not None {
        kid.append(self.make_uni_token(impl_inh_lp_tok));
        for (i, bc) in enumerate(base_classes) {
            if i > 0 {
                kid.append(impl_inh_comma_unis[i - 1]);
            }
            kid.append(bc);
        }
        if impl_inh_rp_uni is not None {
            kid.append(impl_inh_rp_uni);
        }
    }
    if body_expr3 is None {
        if lb_uni {
            kid.append(lb_uni);
        }
        for (i, raw_item) in enumerate(body_stmts3) {
            item: UniNode = raw_item;
            kid.append(item);

            if i < len(body_stmts3) - 1 and i < len(impl_enum_commas) {
                kid.append(impl_enum_commas[i]);
            }
        }
        if rb_uni {
            kid.append(rb_uni);
        }
    } else {
        kid.append(body_expr3);
    }
    spec_arg: (FuncSignature | EventSignature | list[Expr] | None) = None;
    if spec_sig is not None {
        spec_arg = spec_sig;
    } elif spec_is_inh {
        spec_arg = base_classes;
    }
    impl_body_arg: (Expr | list[CodeBlockStmt]) = body_stmts3;
    if body_expr3 is not None {
        impl_body_arg = body_expr3;
    }
    return ImplDef(
        decorators=decorators,
        target=target_names,
        spec=spec_arg,
        body=impl_body_arg,
        kid=kid,
        doc=None
    );
}

impl Parser._is_impl_enum_body -> bool {
    if self.check_name() and self.check_peek(TokenKind.COMMA) {
        return True;
    }

    if self.check_name() and self.check_peek(TokenKind.COLON) {
        save_pos = self.pos;
        self.advance();
        self.advance();

        depth = 0;
        while not self.at_end()
            and not (
                depth == 0
                and self.check_any(
                    TokenKind.EQ, TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE
                )
            ) {
            if self.check_any(TokenKind.LPAREN, TokenKind.LBRACE, TokenKind.LSQUARE) {
                depth += 1;
            } elif self.check_any(
                TokenKind.RPAREN, TokenKind.RBRACE, TokenKind.RSQUARE
            ) {
                if depth > 0 {
                    depth -= 1;
                } else {
                    break;
                }
            }
            self.advance();
        }
        result = False;
        if self.check(TokenKind.EQ) {
            self.advance();
            depth = 0;
            while not self.at_end()
                and not (
                    depth == 0
                    and self.check_any(
                        TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE
                    )
                ) {
                if self.check_any(
                    TokenKind.LPAREN, TokenKind.LBRACE, TokenKind.LSQUARE
                ) {
                    depth += 1;
                } elif self.check_any(
                    TokenKind.RPAREN, TokenKind.RBRACE, TokenKind.RSQUARE
                ) {
                    if depth > 0 {
                        depth -= 1;
                    } else {
                        break;
                    }
                }
                self.advance();
            }
            if self.check(TokenKind.COMMA) {
                result = True;
            }
        } elif self.check(TokenKind.COMMA) {
            result = True;
        }
        self.pos = save_pos;
        return result;
    }

    if self.check_name() and self.check_peek(TokenKind.EQ) {
        save_pos = self.pos;
        self.advance();
        self.advance();
        depth = 0;
        while not self.at_end()
            and not (
                depth == 0
                and self.check_any(TokenKind.COMMA, TokenKind.SEMI, TokenKind.RBRACE)
            ) {
            if self.check_any(TokenKind.LPAREN, TokenKind.LBRACE, TokenKind.LSQUARE) {
                depth += 1;
            } elif self.check_any(
                TokenKind.RPAREN, TokenKind.RBRACE, TokenKind.RSQUARE
            ) {
                if depth > 0 {
                    depth -= 1;
                } else {
                    break;
                }
            }
            self.advance();
        }
        result = self.check(TokenKind.COMMA);
        self.pos = save_pos;
        return result;
    }
    return False;
}

impl Parser.parse_impl_target_name -> NameAtom {
    if self.check_name() {
        name_tok = self.expect_name();
        return self.make_name(name_tok);
    } elif self.check_any(TokenKind.KW_INIT, TokenKind.KW_POST_INIT) {
        name_tok = self.expect_any(TokenKind.KW_INIT, TokenKind.KW_POST_INIT);
        return SpecialVarRef(var=self.make_special_name(name_tok), is_enum_stmt=False);
    } elif self.check_any(
        TokenKind.KW_ENTRY,
        TokenKind.KW_EXIT,
        TokenKind.KW_DEFAULT,
        TokenKind.KW_GETTER,
        TokenKind.KW_SETTER,
        TokenKind.KW_DELETER,
        TokenKind.KW_RETURN
    ) {
        name_tok = self.expect_any(
            TokenKind.KW_ENTRY,
            TokenKind.KW_EXIT,
            TokenKind.KW_DEFAULT,
            TokenKind.KW_GETTER,
            TokenKind.KW_SETTER,
            TokenKind.KW_DELETER,
            TokenKind.KW_RETURN
        );
        return self.make_special_name(name_tok);
    } else {
        name_tok = self.expect_name("impl target");
        return self.make_name(name_tok);
    }
}

impl Parser.parse_impl_enum_body -> tuple[(list[Assignment], list[Token])] {
    members: list[Assignment] = [];
    comma_unis: list[Token] = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        if self.check_name() {
            name_tok = self.expect_name();
            name = self.make_name(name_tok, is_enum_stmt=True);
            type_tag: SubTag | None = None;
            value: Expr | None = None;

            if self.match_tok(TokenKind.COLON) {
                ieb_colon_uni = self.make_uni_token(self.previous());
                tp = self.parse_pipe();
                type_tag = SubTag(tag=tp, kid=[ieb_colon_uni, tp]);
            }
            ieb_eq_uni: Token | None = None;
            if self.match_tok(TokenKind.EQ) {
                ieb_eq_uni = self.make_uni_token(self.previous());
                value = self.parse_expression();
            }
            kid: list[UniNode] = [name];
            if type_tag is not None {
                kid.append(type_tag);
            }
            if value is not None and ieb_eq_uni is not None {
                kid.append(ieb_eq_uni);
                kid.append(value);
            }
            members.append(
                Assignment(
                    target=[name],
                    value=value,
                    type_tag=type_tag,
                    kid=kid,
                    mutable=True,
                    aug_op=None,
                    is_enum_stmt=True
                )
            );

            if self.match_tok(TokenKind.COMMA) {
                comma_unis.append(self.make_uni_token(self.previous()));
            }
        } else {
            break;
        }
    }
    return (members, comma_unis);
}

impl Parser.parse_sem_def -> SemDef {
    sem_kw_uni = self.consume_uni(TokenKind.KW_SEM);
    target_names: list[NameAtom] = [];
    sem_dot_unis: list[Token] = [];
    target_names.append(self.parse_impl_target_name());
    while self.match_tok(TokenKind.DOT) {
        sem_dot_unis.append(self.make_uni_token(self.previous()));
        target_names.append(self.parse_impl_target_name());
    }

    sep_uni: Token | None = None;
    if self.match_tok(TokenKind.EQ) {
        sep_uni = self.make_uni_token(self.previous());
    } elif self.match_tok(TokenKind.KW_IS) {
        sep_uni = self.make_uni_token(self.previous());
    } else {
        self.expect(TokenKind.EQ);
        sep_uni = self.make_uni_token(self.previous());
    }

    str_nodes: list[String | FString] = [
        self.make_string(self.expect(TokenKind.STRING))
    ];
    while self.check(TokenKind.STRING) {
        str_nodes.append(self.make_string(self.expect(TokenKind.STRING)));
    }
    value = MultiString(strings=str_nodes, kid=str_nodes);
    kid: list[UniNode] = [sem_kw_uni];
    for (i, n) in enumerate(target_names) {
        kid.append(n);
        if i < len(target_names) - 1 {
            kid.append(sem_dot_unis[i]);
        }
    }
    kid.append(sep_uni);
    kid.append(value);
    kid.append(self.make_semi());
    self.match_tok(TokenKind.SEMI);
    return SemDef(target=target_names, value=value, kid=kid);
}

impl Parser.parse_type_alias -> TypeAlias {
    type_kw_uni = self.consume_uni(TokenKind.TYP_TYPE);
    access = self.parse_access_tag();
    name_tok: LexToken;
    if self.check_name() {
        name_tok = self.expect_name();
    } elif self.is_keyword_token() {
        name_tok = self.advance();
    } else {
        name_tok = self.expect_name();
    }
    name = self.make_name_or_special(name_tok);
    tp_list: (list[TypeParam] | None) = None;
    tp_lb_uni: Token | None = None;
    tp_rb_uni: Token | None = None;
    tp_comma_unis: list[Token] = [];
    if self.match_tok(TokenKind.LSQUARE) {
        tp_lb_uni = self.make_uni_token(self.previous());
        (tp_list, tp_comma_unis) = self.parse_type_params();
        tp_rb_uni = self.consume_uni(TokenKind.RSQUARE);
    }

    is_distinct = False;
    eq_uni: Token;
    if self.match_tok(TokenKind.WALRUS_EQ) {
        is_distinct = True;
        eq_uni = self.make_uni_token(self.previous());
    } else {
        eq_uni = self.consume_uni(TokenKind.EQ);
    }
    value = self.parse_pipe();
    self.expect(TokenKind.SEMI);
    kid: list[UniNode] = [type_kw_uni];
    if access {
        kid.append(access);
    }
    kid.append(name);
    if tp_list is not None and tp_lb_uni is not None and tp_rb_uni is not None {
        kid.append(tp_lb_uni);
        for (i, tp) in enumerate(tp_list) {
            if i > 0 {
                kid.append(tp_comma_unis[i - 1]);
            }
            kid.append(tp);
        }
        kid.append(tp_rb_uni);
    }
    kid.append(eq_uni);
    kid.append(value);
    kid.append(self.make_semi());
    return TypeAlias(
        name=name,
        type_params=tp_list,
        value=value,
        is_distinct=is_distinct,
        access=access,
        kid=kid,
        doc=None
    );
}

impl Parser.parse_type_params -> tuple[(list[TypeParam], list[Token])] {
    params: list[TypeParam] = [];
    comma_unis: list[Token] = [];

    ct_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_COMPTIME) {
        ct_uni = self.make_uni_token(self.previous());
    }
    name_tok = self.expect_name();
    name = self.make_name_or_special(name_tok);
    bound: Expr | None = None;
    default_val: Expr | None = None;
    tp_kid: list[UniNode] = [];
    if ct_uni is not None {
        tp_kid.append(ct_uni);
    }
    tp_kid.append(name);
    if self.match_tok(TokenKind.COLON) {
        tp_kid.append(self.make_uni_token(self.previous()));
        bound = self.parse_pipe();
        tp_kid.append(bound);
    }
    if self.match_tok(TokenKind.EQ) {
        tp_kid.append(self.make_uni_token(self.previous()));
        default_val = self.parse_pipe();
        tp_kid.append(default_val);
    }
    params.append(
        TypeParam(
            name=name,
            bound=bound,
            default_val=default_val,
            is_comptime=ct_uni is not None,
            kid=tp_kid
        )
    );
    while self.match_tok(TokenKind.COMMA) {
        comma_unis.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RSQUARE) {
            break;
        }
        ct_uni = None;
        if self.match_tok(TokenKind.KW_COMPTIME) {
            ct_uni = self.make_uni_token(self.previous());
        }
        name_tok = self.expect_name();
        name = self.make_name_or_special(name_tok);
        bound = None;
        default_val = None;
        tp_kid = [];
        if ct_uni is not None {
            tp_kid.append(ct_uni);
        }
        tp_kid.append(name);
        if self.match_tok(TokenKind.COLON) {
            tp_kid.append(self.make_uni_token(self.previous()));
            bound = self.parse_pipe();
            tp_kid.append(bound);
        }
        if self.match_tok(TokenKind.EQ) {
            tp_kid.append(self.make_uni_token(self.previous()));
            default_val = self.parse_pipe();
            tp_kid.append(default_val);
        }
        params.append(
            TypeParam(
                name=name,
                bound=bound,
                default_val=default_val,
                is_comptime=ct_uni is not None,
                kid=tp_kid
            )
        );
    }
    return (params, comma_unis);
}
