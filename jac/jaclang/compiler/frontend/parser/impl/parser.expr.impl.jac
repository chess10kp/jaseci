import from jaclang.compiler.frontend.constant {
    Tokens as Tok,
    SymbolAccess,
    SymbolType
}


impl Parser.parse_concurrent_expr(allow_cast: bool = True) -> Expr {
    if self.check_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT) {
        tok = self.expect_any(TokenKind.KW_FLOW, TokenKind.KW_WAIT);
        target = self.parse_walrus_assign(allow_cast);
        uni_tok = self.make_uni_token(tok);
        return ConcurrentExpr(tok=uni_tok, target=target, kid=[uni_tok, target]);
    }
    return self.parse_walrus_assign(allow_cast);
}

impl Parser.parse_walrus_assign(allow_cast: bool = True) -> Expr {
    expr = self.parse_by_expr(allow_cast);
    if self.check(TokenKind.WALRUS_EQ) {
        walrus_tok = self.expect(TokenKind.WALRUS_EQ);
        value = self.parse_by_expr(allow_cast);
        op = self.make_uni_token(walrus_tok);
        return BinaryExpr(left=expr, op=op, right=value, kid=[expr, op, value]);
    }
    return expr;
}

impl Parser.parse_by_expr(allow_cast: bool = True) -> Expr {
    left = self.parse_pipe(allow_cast);
    if self.match_tok(TokenKind.KW_BY) {
        by_uni = self.make_uni_token(self.previous());
        right = self.parse_by_expr(allow_cast);
        return BinaryExpr(left=left, op=by_uni, right=right, kid=[left, by_uni, right]);
    }
    return left;
}

impl Parser.parse_cast(allow_cast: bool = True) -> Expr {
    expr = self.parse_bitwise_or();
    while allow_cast and self.match_tok(TokenKind.KW_AS) {
        as_uni = self.make_uni_token(self.previous());
        cast_type = self.parse_cast_type();
        expr = CastExpr(value=expr, cast_type=cast_type, kid=[expr, as_uni, cast_type]);
    }
    return expr;
}

impl Parser.parse_cast_type -> Expr {
    left = self.parse_atomic_chain();
    while self.match_tok(TokenKind.BW_OR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_atomic_chain();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_pipe(allow_cast: bool = True) -> Expr {
    left = self.parse_pipe_back(allow_cast);
    while self.match_tok(TokenKind.PIPE_FWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_pipe_back(allow_cast);
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_pipe_back(allow_cast: bool = True) -> Expr {
    left = self.parse_logical_or(allow_cast);
    while self.match_tok(TokenKind.PIPE_BKWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_logical_or(allow_cast);
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_bitwise_or -> Expr {
    left = self.parse_bitwise_xor();
    while self.match_tok(TokenKind.BW_OR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_xor();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_bitwise_xor -> Expr {
    left = self.parse_bitwise_and();
    while self.match_tok(TokenKind.BW_XOR) {
        op = self.make_uni_token(self.previous());
        right = self.parse_bitwise_and();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_bitwise_and -> Expr {
    left = self.parse_shift();
    while self.match_tok(TokenKind.BW_AND) {
        op = self.make_uni_token(self.previous());
        right = self.parse_shift();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_shift -> Expr {
    left = self.parse_arithmetic();
    while self.check_any(TokenKind.LSHIFT, TokenKind.RSHIFT) {
        tok = self.expect_any(TokenKind.LSHIFT, TokenKind.RSHIFT);
        op = self.make_uni_token(tok);
        right = self.parse_arithmetic();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_logical_or(allow_cast: bool = True) -> Expr {
    left = self.parse_logical_and(allow_cast);
    while self.match_tok(TokenKind.KW_OR) {
        values: list[Expr] = [left];
        op = self.make_uni_token(self.previous());
        while True {
            values.append(self.parse_logical_and(allow_cast));
            if not self.match_tok(TokenKind.KW_OR) {
                break;
            }
        }
        cfg_values = [CfgExpr(expr=v, kid=[v]) for v in values];
        kid: list[UniNode] = [];
        for (i, cv) in enumerate(cfg_values) {
            kid.append(cv);
            if i < len(cfg_values) - 1 {
                kid.append(op);
            }
        }
        left = BoolExpr(op=op, values=cfg_values, kid=kid);
    }
    return left;
}

impl Parser.parse_logical_and(allow_cast: bool = True) -> Expr {
    left = self.parse_logical_not(allow_cast);
    while self.match_tok(TokenKind.KW_AND) {
        values: list[Expr] = [left];
        op = self.make_uni_token(self.previous());
        while True {
            values.append(self.parse_logical_not(allow_cast));
            if not self.match_tok(TokenKind.KW_AND) {
                break;
            }
        }
        cfg_values = [CfgExpr(expr=v, kid=[v]) for v in values];
        kid: list[UniNode] = [];
        for (i, cv) in enumerate(cfg_values) {
            kid.append(cv);
            if i < len(cfg_values) - 1 {
                kid.append(op);
            }
        }
        left = BoolExpr(op=op, values=cfg_values, kid=kid);
    }
    return left;
}

impl Parser.parse_logical_not(allow_cast: bool = True) -> Expr {
    if self.match_tok(TokenKind.KW_NOT) {
        op = self.make_uni_token(self.previous());
        operand = self.parse_logical_not(allow_cast);
        return UnaryExpr(operand=operand, op=op, kid=[op, operand]);
    }
    return self.parse_compare(allow_cast);
}

impl Parser.parse_compare(allow_cast: bool = True) -> Expr {
    left = self.parse_cast(allow_cast);
    if self.check_any(
        TokenKind.EE,
        TokenKind.NE,
        TokenKind.LT,
        TokenKind.GT,
        TokenKind.LTE,
        TokenKind.GTE,
        TokenKind.KW_IN,
        TokenKind.KW_IS,
        TokenKind.KW_NIN,
        TokenKind.KW_ISN
    ) {
        rights: list[Expr] = [];
        ops: list[Token] = [];
        kid: list[UniNode] = [left];
        while self.check_any(
            TokenKind.EE,
            TokenKind.NE,
            TokenKind.LT,
            TokenKind.GT,
            TokenKind.LTE,
            TokenKind.GTE,
            TokenKind.KW_IN,
            TokenKind.KW_IS,
            TokenKind.KW_NIN,
            TokenKind.KW_ISN
        ) {
            op_tok = self.expect_any(
                TokenKind.EE,
                TokenKind.NE,
                TokenKind.LT,
                TokenKind.GT,
                TokenKind.LTE,
                TokenKind.GTE,
                TokenKind.KW_IN,
                TokenKind.KW_IS,
                TokenKind.KW_NIN,
                TokenKind.KW_ISN
            );
            op = self.make_uni_token(op_tok);
            ops.append(op);
            kid.append(op);
            right = self.parse_cast(allow_cast);
            rights.append(right);
            kid.append(right);
        }
        return CompareExpr(left=left, rights=rights, ops=ops, kid=kid);
    }
    return left;
}

impl Parser.parse_arithmetic -> Expr {
    left = self.parse_term();
    while self.check_any(TokenKind.PLUS, TokenKind.MINUS) {
        tok = self.expect_any(TokenKind.PLUS, TokenKind.MINUS);
        op = self.make_uni_token(tok);
        right = self.parse_term();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_term -> Expr {
    left = self.parse_power();
    while self.check_any(
        TokenKind.STAR_MUL,
        TokenKind.DIV,
        TokenKind.FLOOR_DIV,
        TokenKind.MOD,
        TokenKind.DECOR_OP
    ) {
        tok = self.expect_any(
            TokenKind.STAR_MUL,
            TokenKind.DIV,
            TokenKind.FLOOR_DIV,
            TokenKind.MOD,
            TokenKind.DECOR_OP
        );
        op = self.make_uni_token(tok);
        right = self.parse_power();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_power -> Expr {
    left = self.parse_factor();
    if self.match_tok(TokenKind.STAR_POW) {
        op = self.make_uni_token(self.previous());
        right = self.parse_power();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_factor -> Expr {
    if self.check_any(TokenKind.BW_NOT, TokenKind.MINUS, TokenKind.PLUS) {
        tok = self.expect_any(TokenKind.BW_NOT, TokenKind.MINUS, TokenKind.PLUS);
        op = self.make_uni_token(tok);
        operand = self.parse_factor();
        return UnaryExpr(operand=operand, op=op, kid=[op, operand]);
    }
    return self.parse_connect();
}

impl Parser.parse_connect -> Expr {
    left = self.parse_atomic_pipe();
    while True {
        conn_op = self.parse_connect_op();
        if conn_op is None {
            break;
        }
        if self._recover_missing_connect_rhs() {
            break;
        }
        right = self.parse_atomic_pipe();
        kid: list[UniNode] = [left, conn_op, right];
        left = BinaryExpr(left=left, op=conn_op, right=right, kid=kid);
    }
    return left;
}

impl Parser._recover_missing_connect_rhs -> bool {
    if not self.check_any(
        TokenKind.SEMI,
        TokenKind.RBRACE,
        TokenKind.RPAREN,
        TokenKind.RSQUARE,
        TokenKind.COMMA,
        TokenKind.EOF
    ) {
        return False;
    }
    self.emit_diag(
        "Connect/disconnect operator requires a right operand",
        "E0026",
        help="Connect (`++>`, `+>:T:+>`) and disconnect (`del -->`, `del ->:T:->`) operators are binary -- supply the right-hand side, e.g. `a ++> b;` or `a del --> b;`."
    );
    return True;
}

impl Parser.parse_edge_op_ref_inline -> EdgeOpRef | None {
    return self.parse_edge_op_ref();
}

impl Parser.parse_connect_op -> ConnectOp | DisconnectOp | None {
    if self.check(TokenKind.KW_DELETE)
        and self.check_peek_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1
        ) {
        del_tok = self.expect(TokenKind.KW_DELETE);

        edge_op = self.parse_edge_op_ref_inline();
        if edge_op {
            return DisconnectOp(
                edge_spec=edge_op, kid=[self.make_uni_token(del_tok), edge_op]
            );
        }
    }

    if self.match_tok(TokenKind.CARROW_R) {
        tok = self.make_uni_token(self.previous());
        return ConnectOp(
            conn_type=None, conn_assign=None, edge_dir=EdgeDir.OUT, kid=[tok]
        );
    }
    if self.match_tok(TokenKind.CARROW_R_P1) {
        start_tok = self.make_uni_token(self.previous());
        conn_type = self.parse_expression();
        conn_assign: AssignCompr | None = None;
        kid: list[UniNode] = [start_tok, conn_type];
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.make_uni_token(self.previous()));

            assigns: list[KWPair] = [];
            ac_kid: list[UniNode] = [];
            while not self.check(TokenKind.CARROW_R_P2) and not self.at_end() {
                key_name = self.make_name(self.expect_name());
                eq_uni = self.consume_uni(TokenKind.EQ);
                val_expr = self.parse_expression();
                item = KWPair(
                    key=key_name, value=val_expr, kid=[key_name, eq_uni, val_expr]
                );
                assigns.append(item);
                ac_kid.append(item);
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
                ac_kid.append(self.make_uni_token(self.previous()));
            }
            if assigns {
                conn_assign = AssignCompr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }
        if not self.check(TokenKind.CARROW_R_P2) {
            self.emit_diag(
                "Expected ':+>' to close forward typed connection -- did you mean '+>: <EdgeType> :+> <node>'?",
                "E0027"
            );
            self.synchronize();
            return None;
        }
        end_uni = self.consume_uni(TokenKind.CARROW_R_P2);
        kid.append(end_uni);
        return ConnectOp(
            conn_type=conn_type, conn_assign=conn_assign, edge_dir=EdgeDir.OUT, kid=kid
        );
    }

    if self.match_tok(TokenKind.CARROW_L) {
        tok = self.make_uni_token(self.previous());
        return ConnectOp(
            conn_type=None, conn_assign=None, edge_dir=EdgeDir.IN, kid=[tok]
        );
    }
    if self.match_tok(TokenKind.CARROW_L_P1) {
        start_tok = self.make_uni_token(self.previous());
        conn_type = self.parse_expression();
        conn_assign: AssignCompr | None = None;
        kid: list[UniNode] = [start_tok, conn_type];
        if self.match_tok(TokenKind.COLON) {
            kid.append(self.make_uni_token(self.previous()));
            assigns: list[KWPair] = [];
            ac_kid: list[UniNode] = [];
            while not self.check_any(TokenKind.CARROW_L_P2, TokenKind.CARROW_R_P2)
                and not self.at_end() {
                key_name = self.make_name(self.expect_name());
                eq_uni = self.consume_uni(TokenKind.EQ);
                val_expr = self.parse_expression();
                item = KWPair(
                    key=key_name, value=val_expr, kid=[key_name, eq_uni, val_expr]
                );
                assigns.append(item);
                ac_kid.append(item);
                if not self.match_tok(TokenKind.COMMA) {
                    break;
                }
                ac_kid.append(self.make_uni_token(self.previous()));
            }
            if assigns {
                conn_assign = AssignCompr(assigns=assigns, kid=ac_kid);
                kid.append(conn_assign);
            }
        }

        if self.match_tok(TokenKind.CARROW_L_P2) {
            kid.append(self.make_uni_token(self.previous()));
            return ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.IN,
                kid=kid
            );
        } elif self.match_tok(TokenKind.CARROW_R_P2) {
            kid.append(self.make_uni_token(self.previous()));
            return ConnectOp(
                conn_type=conn_type,
                conn_assign=conn_assign,
                edge_dir=EdgeDir.ANY,
                kid=kid
            );
        } else {
            self.emit_diag(
                "Expected ':<+' or ':+>' to close backward typed connection -- did you mean '<+: <EdgeType> :<+ <node>' (backward) or '<+: <EdgeType> :+> <node>' (bidirectional)?",
                "E0028"
            );
            self.synchronize();
            return None;
        }
    }

    if self.match_tok(TokenKind.CARROW_BI) {
        tok = self.make_uni_token(self.previous());
        return ConnectOp(
            conn_type=None, conn_assign=None, edge_dir=EdgeDir.ANY, kid=[tok]
        );
    }
    return None;
}

impl Parser.parse_atomic_pipe -> Expr {
    left = self.parse_atomic_pipe_back();
    while self.match_tok(TokenKind.A_PIPE_FWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_atomic_pipe_back();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_atomic_pipe_back -> Expr {
    left = self.parse_spawn();
    while self.match_tok(TokenKind.A_PIPE_BKWD) {
        op = self.make_uni_token(self.previous());
        right = self.parse_spawn();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_spawn -> Expr {
    if self.check(TokenKind.KW_SPAWN) {
        op_tok = self.expect(TokenKind.KW_SPAWN);
        op = self.make_uni_token(op_tok);
        target = self.parse_unpack();

        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    left = self.parse_unpack();
    while self.match_tok(TokenKind.KW_SPAWN) {
        op = self.make_uni_token(self.previous());
        right = self.parse_unpack();
        left = BinaryExpr(left=left, op=op, right=right, kid=[left, op, right]);
    }
    return left;
}

impl Parser.parse_unpack -> Expr {
    if self.match_tok(TokenKind.STAR_MUL) {
        op = self.make_uni_token(self.previous());
        target = self.parse_ref();
        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_ref();
}

impl Parser.parse_ref -> Expr {
    if self.match_tok(TokenKind.KW_OWN) {
        own_op = self.make_uni_token(self.previous());
        own_target = self.parse_await_expr();
        return UnaryExpr(
            operand=own_target,
            op=own_op,
            ownership=OwnershipKind.OWN,
            kid=[own_op, own_target]
        );
    }
    if self.match_tok(TokenKind.KW_IMM) {
        imm_op = self.make_uni_token(self.previous());
        imm_target = self.parse_await_expr();
        return UnaryExpr(
            operand=imm_target,
            op=imm_op,
            ownership=OwnershipKind.IMM,
            kid=[imm_op, imm_target]
        );
    }
    if self.match_tok(TokenKind.BW_AND) {
        raw_tok = self.previous();
        op = self.make_uni_token(raw_tok);
        kids: list[UniNode] = [op];

        if self.check(TokenKind.LPAREN)
            or (
                not self.at_end() and self.current().loc.pos_start > raw_tok.loc.pos_end
            ) {
            target = self.parse_await_expr();
            kids.append(target);
            return UnaryExpr(
                operand=target, op=op, ownership=OwnershipKind.NONE, kid=kids
            );
        }

        is_mut = False;
        if self.check(TokenKind.KW_MUT) {
            mut_tok = self.expect(TokenKind.KW_MUT);
            kids.append(self.make_uni_token(mut_tok));
            is_mut = True;
        }
        target = self.parse_await_expr();
        kids.append(target);
        return UnaryExpr(
            operand=target,
            op=op,
            ownership=OwnershipKind.MUT_BORROW if is_mut else OwnershipKind.BORROW,
            kid=kids
        );
    }
    return self.parse_await_expr();
}

impl Parser.parse_await_expr -> Expr {
    if self.match_tok(TokenKind.KW_AWAIT) {
        await_tok = self.make_uni_token(self.previous());
        expr = self.parse_pipe_call();
        return AwaitExpr(target=expr, kid=[await_tok, expr]);
    }
    return self.parse_pipe_call();
}

impl Parser.parse_pipe_call -> Expr {
    if self.check_any(TokenKind.PIPE_FWD, TokenKind.A_PIPE_FWD) {
        tok = self.expect_any(TokenKind.PIPE_FWD, TokenKind.A_PIPE_FWD);
        op = self.make_uni_token(tok);
        target = self.parse_atomic_chain();
        return UnaryExpr(operand=target, op=op, kid=[op, target]);
    }
    return self.parse_atomic_chain();
}

impl Parser.parse_atomic_chain -> Expr {
    expr = self.parse_atom();
    while True {
        if self.match_tok(TokenKind.DOT)
            or (
                self.check(TokenKind.NULL_OK)
                and not self.check_peek(TokenKind.LSQUARE)
                and self.match_tok(TokenKind.NULL_OK)
            )
            or self.match_tok(TokenKind.DOT_FWD)
            or self.match_tok(TokenKind.DOT_BKWD) {
            first_consumed_tok = self.previous();
            dot_kind = first_consumed_tok.kind;
            null_ok = dot_kind == TokenKind.NULL_OK;
            is_dot_fwd = dot_kind == TokenKind.DOT_FWD;
            is_dot_bkwd = dot_kind == TokenKind.DOT_BKWD;
            null_ok_uni: Token | None = None;
            dot_uni: Token | None = None;
            if null_ok {
                null_ok_uni = self.make_uni_token(first_consumed_tok);
            } else {
                dot_uni = self.make_uni_token(first_consumed_tok);
            }
            if null_ok
                and self.check_any(
                    TokenKind.DOT, TokenKind.DOT_FWD, TokenKind.DOT_BKWD
                ) {
                dot_kind2 = self.current().kind;
                is_dot_fwd = dot_kind2 == TokenKind.DOT_FWD;
                is_dot_bkwd = dot_kind2 == TokenKind.DOT_BKWD;
                dot_uni = self.make_uni_token(
                    self.expect_any(
                        TokenKind.DOT, TokenKind.DOT_FWD, TokenKind.DOT_BKWD
                    )
                );
            }
            if not dot_uni and null_ok and null_ok_uni is not None {
                dot_uni = null_ok_uni;
            }

            attr: UniNode | None = None;
            if self.check_name() {
                name_tok = self.expect_name("attribute");
                attr = self.make_name(name_tok);
            } elif is_special_var_kind(self.current().kind) {
                name_tok = self.advance();
                attr = self._make_attr_from_keyword(name_tok);
            } elif self.check_any(
                TokenKind.KW_GETTER, TokenKind.KW_SETTER, TokenKind.KW_DELETER
            ) {
                attr = self.make_special_name(self.advance());
            } elif self.is_keyword_token() {
                attr = self.make_name(self.advance());
            }
            if not attr {
                dot_tok = first_consumed_tok;
                attr = Name(
                    orig_src=self.source,
                    name=Tok.NAME.value,
                    value="",
                    line=dot_tok.loc.end_line,
                    end_line=dot_tok.loc.end_line,
                    col_start=dot_tok.loc.col_end,
                    col_end=dot_tok.loc.col_end,
                    pos_start=dot_tok.loc.pos_end,
                    pos_end=dot_tok.loc.pos_end
                );
            }
            kid: list[UniNode] = [expr];
            if null_ok and null_ok_uni is not None {
                kid.append(null_ok_uni);
            }
            if dot_uni is not None {
                kid.append(dot_uni);
            }
            kid.append(attr);
            target_node = expr if not is_dot_bkwd else attr;
            right_node = attr if not is_dot_bkwd else expr;
            expr = AtomTrailer(
                target=target_node,
                right=right_node,
                is_attr=True,
                is_null_ok=null_ok,
                kid=kid
            );
        } elif self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.emit_diag(
                    "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
                    "E0048",
                    loc=self.current().loc,
                    help="Replace (?:Type, cond) with [?:Type, cond]"
                );
                self.expect(TokenKind.LPAREN);
                filter_expr: FilterCompr = self.parse_filter_compr_inner();

                kid = [expr, filter_expr];
                expr = AtomTrailer(
                    target=expr,
                    right=filter_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } elif self.check_peek(TokenKind.EQ) {
                self.expect(TokenKind.LPAREN);
                assign_expr = self.parse_assign_compr_inner();
                kid = [expr, assign_expr];
                expr = AtomTrailer(
                    target=expr,
                    right=assign_expr,
                    is_attr=False,
                    is_null_ok=False,
                    kid=kid
                );
            } else {
                lp_uni = self.make_uni_token(self.expect(TokenKind.LPAREN));
                call_kid: list[UniNode] = [expr, lp_uni];
                args = self.parse_call_args(call_kid);
                rp_uni = self.consume_uni(TokenKind.RPAREN);
                call_kid.append(rp_uni);
                first_arg = args[0] if len(args) == 1 else None;
                if isinstance(first_arg, GenCompr) {
                    lparen_tok = call_kid[1];
                    rparen_tok = call_kid[len(call_kid) - 1];
                    new_gc_kid: list[UniNode] = [lparen_tok];
                    for c in first_arg.kid {
                        new_gc_kid.append(c);
                    }
                    new_gc_kid.append(rparen_tok);
                    gencompr = GenCompr(
                        out_expr=first_arg.out_expr,
                        compr=first_arg.compr,
                        kid=new_gc_kid
                    );
                    args = [gencompr];
                    call_kid = [expr, gencompr];
                }
                expr = FuncCall(
                    target=expr, params=args, genai_call=None, kid=call_kid
                );
            }
        } elif self.check(TokenKind.LSQUARE) and self.check_peek(TokenKind.NULL_OK) {
            self.expect(TokenKind.LSQUARE);
            filter_expr = self.parse_filter_compr_bracket();
            kid = [expr, filter_expr];
            expr = AtomTrailer(
                target=expr, right=filter_expr, is_attr=False, is_null_ok=False, kid=kid
            );
        } elif (self.check(TokenKind.NULL_OK) and self.check_peek(TokenKind.LSQUARE))
            or self.check(TokenKind.LSQUARE) {
            is_null_ok_index = False;
            null_ok_idx_uni: Token | None = None;
            if self.match_tok(TokenKind.NULL_OK) {
                is_null_ok_index = True;
                null_ok_idx_uni = self.make_uni_token(self.previous());
            }
            index_slice = self.parse_index_slice();
            kid: list[UniNode] = [expr];
            if is_null_ok_index and null_ok_idx_uni is not None {
                kid.append(null_ok_idx_uni);
            }
            kid.append(index_slice);
            expr = AtomTrailer(
                target=expr,
                right=index_slice,
                is_attr=False,
                is_null_ok=is_null_ok_index,
                kid=kid
            );
        } else {
            break;
        }
    }
    return expr;
}

impl Parser._make_attr_from_keyword(name_tok: LexToken) -> Name {
    special_kinds: list[TokenKind] = [
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT,
        TokenKind.KW_SELF,
        TokenKind.KW_PROPS,
        TokenKind.KW_SUPER,
        TokenKind.KW_ROOT,
        TokenKind.KW_HERE,
        TokenKind.KW_VISITOR
    ];
    for sk in special_kinds {
        if name_tok.kind == sk {
            return SpecialVarRef(
                var=self.make_special_name(name_tok), is_enum_stmt=False
            );
        }
    }
    return self.make_special_name(name_tok);
}

impl Parser.parse_index_slice -> IndexSlice {
    lsq_uni = self.consume_uni(TokenKind.LSQUARE);
    first_expr: Expr | None = None;
    if not self.check_any(TokenKind.RSQUARE, TokenKind.COLON) {
        first_expr = self.parse_expression();
    }
    if self.check(TokenKind.COLON) {
        index_kid: list[UniNode] = [lsq_uni];
        slices: list[Slice] = [];

        s1_kid: list[UniNode] = [];
        if first_expr is not None {
            s1_kid.append(first_expr);
        }
        colon1_uni = self.consume_uni(TokenKind.COLON);
        s1_kid.append(colon1_uni);
        stop: Expr | None = None;
        if not self.check_any(TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA) {
            stop = self.parse_expression();
            s1_kid.append(stop);
        }
        step: Expr | None = None;
        if self.match_tok(TokenKind.COLON) {
            s1_kid.append(self.make_uni_token(self.previous()));
            if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                step = self.parse_expression();
                s1_kid.append(step);
            }
        }
        slice1 = Slice(start=first_expr, stop=stop, step=step, kid=s1_kid);
        slices.append(slice1);
        index_kid.append(slice1);
        while self.match_tok(TokenKind.COMMA) {
            index_kid.append(self.make_uni_token(self.previous()));
            sn_kid: list[UniNode] = [];
            s2: Expr | None = None;
            if not self.check(TokenKind.COLON) {
                s2 = self.parse_expression();
                sn_kid.append(s2);
            }
            colon_s2_uni = self.consume_uni(TokenKind.COLON);
            sn_kid.append(colon_s2_uni);
            e2: Expr | None = None;
            if not self.check_any(
                TokenKind.COLON, TokenKind.RSQUARE, TokenKind.COMMA
            ) {
                e2 = self.parse_expression();
                sn_kid.append(e2);
            }
            t2: Expr | None = None;
            if self.match_tok(TokenKind.COLON) {
                sn_kid.append(self.make_uni_token(self.previous()));
                if not self.check_any(TokenKind.RSQUARE, TokenKind.COMMA) {
                    t2 = self.parse_expression();
                    sn_kid.append(t2);
                }
            }
            slice_n = Slice(start=s2, stop=e2, step=t2, kid=sn_kid);
            slices.append(slice_n);
            index_kid.append(slice_n);
        }
        rsq_uni = self.consume_uni(TokenKind.RSQUARE);
        index_kid.append(rsq_uni);
        return IndexSlice(slices=slices, is_range=True, kid=index_kid);
    } else {
        indices: list[Expr] = [];
        list_kid: list[UniNode] = [lsq_uni];
        if first_expr is not None {
            indices.append(first_expr);
            list_kid.append(first_expr);
            while self.match_tok(TokenKind.COMMA) {
                list_kid.append(self.make_uni_token(self.previous()));
                if self.check(TokenKind.RSQUARE) {
                    break;
                }
                idx = self.parse_expression();
                indices.append(idx);
                list_kid.append(idx);
            }
        }
        rsq_idx_uni = self.consume_uni(TokenKind.RSQUARE);
        list_kid.append(rsq_idx_uni);
        list_val = ListVal(values=indices, kid=list_kid);
        if len(indices) == 1 {
            idx_expr = indices[0];
            slice_node = Slice(start=idx_expr, stop=None, step=None, kid=[list_val]);
        } else {
            idx_expr = TupleVal(values=indices, kid=list_kid);
            slice_node = Slice(start=idx_expr, stop=None, step=None, kid=[idx_expr]);
        }
        return IndexSlice(slices=[slice_node], is_range=False, kid=[slice_node]);
    }
}

impl Parser.parse_call_args(kid: list[UniNode]) -> list[Expr | KWPair] {
    args: list[Expr | KWPair] = [];
    if self.check(TokenKind.RPAREN) {
        return args;
    }

    if self.check(TokenKind.SEMI) or self.check(TokenKind.RBRACE) {
        return args;
    }
    arg = self.parse_call_arg();
    args.append(arg);
    kid.append(arg);
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RPAREN) {
            break;
        }
        arg = self.parse_call_arg();
        args.append(arg);
        kid.append(arg);
    }

    if not self.check(TokenKind.RPAREN) and not self.at_end() {
        self.emit_diag("Missing ','", "E0002");
        self.emit_diag("Unexpected token", "E0006");

        while not self.check(TokenKind.RPAREN) and not self.at_end() {
            self.advance();
        }
    }
    return args;
}

impl Parser.parse_call_arg -> Expr | KWPair {
    if (self.check_name() or self.is_keyword_token())
        and self.check_peek(TokenKind.EQ) {
        name: Name;
        if is_special_var_kind(self.current().kind) {
            name = SpecialVarRef(
                var=self.make_special_name(self.advance()), is_enum_stmt=False
            );
        } else {
            name = self.make_name(self.expect_name("keyword argument"));
        }
        eq_uni = self.consume_uni(TokenKind.EQ);
        value = self.parse_expression();
        return KWPair(key=name, value=value, kid=[name, eq_uni, value]);
    }

    if self.check(TokenKind.STAR_POW) {
        star_tok = self.expect(TokenKind.STAR_POW);
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return KWPair(key=None, value=value, kid=[star, value]);
    }

    if self.check(TokenKind.STAR_MUL) {
        star_tok = self.expect(TokenKind.STAR_MUL);
        star = self.make_uni_token(star_tok);
        value = self.parse_expression();
        return UnaryExpr(op=star, operand=value, kid=[star, value]);
    }

    expr = self.parse_expression();

    if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid: list[UniNode] = [expr];
        kid.extend(comprs);
        return GenCompr(compr=comprs, out_expr=expr, kid=kid);
    }
    return expr;
}

impl Parser.parse_filter_compr_inner -> FilterCompr {
    lp_uni = self.make_uni_token(self.previous());
    kid: list[UniNode] = [lp_uni];
    f_type = None;

    null_ok_uni = self.consume_uni(TokenKind.NULL_OK);
    kid.append(null_ok_uni);

    if self.match_tok(TokenKind.COLON) {
        kid.append(self.make_uni_token(self.previous()));
        f_type = self.parse_expression();
        kid.append(f_type);
    }

    compares: list[Expr] = [];

    if f_type and self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
    }
    if not self.check(TokenKind.RPAREN) {
        comp = self.parse_compare();
        compares.append(comp);
        kid.append(comp);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            comp = self.parse_compare();
            compares.append(comp);
            kid.append(comp);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
    return FilterCompr(f_type=f_type, compares=compares, kid=kid);
}

impl Parser.parse_filter_compr_bracket -> FilterCompr {
    lsq_uni = self.make_uni_token(self.previous());
    kid: list[UniNode] = [lsq_uni];
    f_type = None;

    null_ok_uni = self.consume_uni(TokenKind.NULL_OK);
    kid.append(null_ok_uni);

    if self.match_tok(TokenKind.COLON) {
        kid.append(self.make_uni_token(self.previous()));
        f_type = self.parse_expression();
        kid.append(f_type);
    }

    compares: list[Expr] = [];

    if f_type and self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
    }
    if not self.check(TokenKind.RSQUARE) {
        comp = self.parse_compare();
        compares.append(comp);
        kid.append(comp);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            comp = self.parse_compare();
            compares.append(comp);
            kid.append(comp);
        }
    }
    rsq_uni = self.consume_uni(TokenKind.RSQUARE);
    kid.append(rsq_uni);
    return FilterCompr(f_type=f_type, compares=compares, kid=kid);
}

impl Parser.parse_assign_compr_inner -> AssignCompr {
    lp_uni = self.make_uni_token(self.previous());
    kid: list[UniNode] = [lp_uni];
    eq_lead_uni = self.consume_uni(TokenKind.EQ);
    kid.append(eq_lead_uni);
    assigns: list[KWPair] = [];

    if not self.check(TokenKind.RPAREN) {
        name_tok = self.expect_name();
        name = self.make_name(name_tok);
        eq_uni = self.consume_uni(TokenKind.EQ);
        value = self.parse_expression();
        kw = KWPair(key=name, value=value, kid=[name, eq_uni, value]);
        assigns.append(kw);
        kid.append(kw);
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            if self.check(TokenKind.RPAREN) {
                break;
            }
            name_tok = self.expect_name();
            name = self.make_name(name_tok);
            eq_uni2 = self.consume_uni(TokenKind.EQ);
            value = self.parse_expression();
            kw = KWPair(key=name, value=value, kid=[name, eq_uni2, value]);
            assigns.append(kw);
            kid.append(kw);
        }
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    kid.append(rp_uni);
    return AssignCompr(assigns=assigns, kid=kid);
}

impl Parser.parse_atom_literal -> Expr | None {
    if self.check(TokenKind.INT) {
        tok = self.expect(TokenKind.INT);
        return self.make_int(tok);
    }
    if self.check_any(TokenKind.HEX, TokenKind.BIN, TokenKind.OCT) {
        tok = self.expect_any(TokenKind.HEX, TokenKind.BIN, TokenKind.OCT);
        return self.make_int(tok);
    }
    if self.check(TokenKind.FLOAT) {
        tok = self.expect(TokenKind.FLOAT);
        return self.make_float(tok);
    }
    if self.check(TokenKind.BOOL) {
        tok = self.expect(TokenKind.BOOL);
        return self.make_bool(tok);
    }
    if self.check(TokenKind.NULL) {
        tok = self.expect(TokenKind.NULL);
        return self.make_null(tok);
    }
    if self.check(TokenKind.ELLIPSIS) {
        tok = self.expect(TokenKind.ELLIPSIS);
        return self.make_ellipsis(tok);
    }
    return None;
}

impl Parser.parse_multistring -> Expr | None {
    strings: list[String | FString] = [];

    if self.check(TokenKind.NAME)
        and self.current().value
            in ["r", "b", "rb", "br", "R", "B", "rB", "Rb", "bR", "Br", "BR", "RB"]
        and self.check_peek(TokenKind.STRING) {
        prefix_tok = self.expect(TokenKind.NAME);
        str_tok = self.expect(TokenKind.STRING);
        combined = self.make_string(str_tok);
        combined.value = prefix_tok.value + combined.value;
        strings.append(combined);
    } elif self.check(TokenKind.STRING) {
        first_tok = self.expect(TokenKind.STRING);
        strings.append(self.make_string(first_tok));
    } elif self.check_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
    ) {
        strings.append(self.parse_fstring());
    } else {
        return None;
    }

    while self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        )
        or (
            self.check(TokenKind.NAME)
            and self.current().value
                in ["r", "b", "rb", "br", "R", "B", "rB", "Rb", "bR", "Br", "BR", "RB"]
            and self.check_peek(TokenKind.STRING)
        ) {
        if self.check(TokenKind.NAME) and self.check_peek(TokenKind.STRING) {
            ptok = self.expect(TokenKind.NAME);
            stok = self.expect(TokenKind.STRING);
            s = self.make_string(stok);
            s.value = ptok.value + s.value;
            strings.append(s);
        } elif self.check(TokenKind.STRING) {
            tok = self.expect(TokenKind.STRING);
            strings.append(self.make_string(tok));
        } else {
            strings.append(self.parse_fstring());
        }
    }
    return MultiString(strings=strings, kid=strings);
}

impl Parser.parse_builtin_type -> Expr | None {
    if self.check_any(
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
    ) {
        tok = self.expect_any(
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
        builtin_name: str = TOKEN_KIND_TO_TOK[tok.kind]
            if tok.kind in TOKEN_KIND_TO_TOK
            else tok.kind.value;
        return BuiltinType(
            orig_src=self.source,
            name=builtin_name,
            value=tok.value,
            line=tok.loc.line,
            end_line=tok.loc.end_line,
            col_start=tok.loc.col_start,
            col_end=tok.loc.col_end,
            pos_start=tok.loc.pos_start,
            pos_end=tok.loc.pos_end
        );
    }
    return None;
}

impl Parser.parse_special_ref -> Expr | None {
    if self.check_any(
        TokenKind.KW_SELF,
        TokenKind.KW_SUPER,
        TokenKind.KW_HERE,
        TokenKind.KW_ROOT,
        TokenKind.KW_VISITOR,
        TokenKind.KW_PROPS,
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT
    ) {
        tok = self.advance();
        var_name = self.make_special_name(tok);
        return SpecialVarRef(var=var_name, is_enum_stmt=False);
    }

    if self.check_any(
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM
    ) {
        tok = self.expect_any(
            TokenKind.KW_NODE,
            TokenKind.KW_EDGE,
            TokenKind.KW_WALKER,
            TokenKind.KW_OBJECT,
            TokenKind.KW_CLASS,
            TokenKind.KW_ENUM
        );
        return self.make_special_name(tok);
    }
    return None;
}

impl Parser.parse_atom -> Expr {
    if self.check(TokenKind.KW_GRAPH) {
        return self.parse_graph_expr();
    }
    if self.check_any(
        TokenKind.INT,
        TokenKind.HEX,
        TokenKind.BIN,
        TokenKind.OCT,
        TokenKind.FLOAT,
        TokenKind.BOOL,
        TokenKind.NULL,
        TokenKind.ELLIPSIS
    ) {
        lit = self.parse_atom_literal();
        if lit is not None {
            return lit;
        }
    }

    if self.check(TokenKind.STRING)
        or self.check_any(
            TokenKind.F_DQ_START,
            TokenKind.F_SQ_START,
            TokenKind.F_TDQ_START,
            TokenKind.F_TSQ_START,
            TokenKind.RF_DQ_START,
            TokenKind.RF_SQ_START,
            TokenKind.RF_TDQ_START,
            TokenKind.RF_TSQ_START
        )
        or (
            self.check(TokenKind.NAME)
            and self.current().value
                in ["r", "b", "rb", "br", "R", "B", "rB", "Rb", "bR", "Br", "BR", "RB"]
            and self.check_peek(TokenKind.STRING)
        ) {
        ms_val = self.parse_multistring();
        if ms_val is not None {
            return ms_val;
        }
    }

    if self.check_any(
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
        bt = self.parse_builtin_type();
        if bt is not None {
            return bt;
        }
    }

    if self.check_any(
        TokenKind.KW_SELF,
        TokenKind.KW_SUPER,
        TokenKind.KW_HERE,
        TokenKind.KW_ROOT,
        TokenKind.KW_VISITOR,
        TokenKind.KW_PROPS,
        TokenKind.KW_INIT,
        TokenKind.KW_POST_INIT,
        TokenKind.KW_NODE,
        TokenKind.KW_EDGE,
        TokenKind.KW_WALKER,
        TokenKind.KW_OBJECT,
        TokenKind.KW_CLASS,
        TokenKind.KW_ENUM
    ) {
        sref = self.parse_special_ref();
        if sref is not None {
            return sref;
        }
    }
    if self.check(TokenKind.NAME)
        or self.check(TokenKind.KWESC_NAME)
        or self.is_keyword_token() {
        if is_special_var_kind(self.current().kind) {
            return self.make_special_name(self.advance());
        }
        tok = self.expect_name("variable");
        if tok.kind != TokenKind.NAME and tok.kind != TokenKind.KWESC_NAME {
            return self.make_special_name(tok);
        }
        return self.make_name(tok);
    }

    if self.check(TokenKind.STAR_MUL) {
        star_tok = self.expect(TokenKind.STAR_MUL);
        star = self.make_uni_token(star_tok);
        operand = self.parse_expression();
        return UnaryExpr(op=star, operand=operand, kid=[star, operand]);
    }
    if self.check(TokenKind.LPAREN) {
        return self.parse_paren_expr();
    }
    if self.check(TokenKind.LSQUARE) {
        return self.parse_bracket_expr();
    }
    if self.check(TokenKind.LBRACE) {
        return self.parse_brace_expr();
    }

    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }
    self.emit_diag(
        f"Unexpected token in expression: '{self.current().kind.value}'", "E0004"
    );
    return self.make_name(self.advance());
}

impl Parser.parse_graph_expr -> GraphExpr {
    kid: list[UniNode] = [
        self.consume_uni(TokenKind.KW_GRAPH),
        self.consume_uni(TokenKind.LBRACE)
    ];
    exprs: list[Expr] = [];
    while not self.check(TokenKind.RBRACE) and not self.at_end() {
        start = self.pos;
        expr = self.parse_expression();
        exprs.append(expr);
        kid.append(expr);
        if self.check(TokenKind.SEMI) {
            kid.append(self.consume_uni(TokenKind.SEMI));
        } elif not self.check(TokenKind.RBRACE) {
            kid.append(self.consume_uni(TokenKind.SEMI));
        }
        if self.pos == start {
            self.advance();
        }
    }
    kid.append(self.consume_uni(TokenKind.RBRACE));
    return GraphExpr(exprs=exprs, kid=kid);
}

impl Parser.parse_tuple_item -> Expr | KWPair {
    if self.check(TokenKind.STAR_POW) {
        star = self.make_uni_token(self.expect(TokenKind.STAR_POW));
        value = self.parse_expression();
        return KWPair(key=None, value=value, kid=[star, value]);
    }
    return self.parse_expression();
}

impl Parser.parse_paren_expr -> Expr {
    lp_uni = self.consume_uni(TokenKind.LPAREN);
    if self.check(TokenKind.RPAREN) {
        rp_uni = self.make_uni_token(self.expect(TokenKind.RPAREN));
        return TupleVal(values=[], kid=[lp_uni, rp_uni]);
    }

    if self.check(TokenKind.KW_YIELD) {
        yield_expr = self.parse_yield_stmt();
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        return AtomUnit(value=yield_expr, kid=[lp_uni, yield_expr, rp_uni]);
    }

    if self.check_any(TokenKind.KW_DEF, TokenKind.KW_CAN, TokenKind.KW_ASYNC) {
        func_def = self.parse_ability();
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        return AtomUnit(value=func_def, kid=[lp_uni, func_def, rp_uni]);
    }
    first_item = self.parse_tuple_item();
    if isinstance(first_item, Expr) {
        expr = first_item;
        if self.check(TokenKind.KW_FOR)
            or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
            comprs = self.parse_comprehension_clauses();
            gc_kid: list[UniNode] = [lp_uni, expr];
            gc_kid.extend(comprs);
            rp_uni = self.consume_uni(TokenKind.RPAREN);
            gc_kid.append(rp_uni);
            return GenCompr(out_expr=expr, compr=comprs, kid=gc_kid);
        }
    }
    if self.check(TokenKind.COMMA) or isinstance(first_item, KWPair) {
        values: list[Expr | KWPair] = [first_item];
        comma_unis: list[Token] = [];
        trailing_comma = False;
        if self.match_tok(TokenKind.COMMA) {
            comma_unis.append(self.make_uni_token(self.previous()));
            trailing_comma = True;
        }
        while trailing_comma
            and not self.check(TokenKind.RPAREN)
            and not self.at_end() {
            values.append(self.parse_tuple_item());
            if self.match_tok(TokenKind.COMMA) {
                comma_unis.append(self.make_uni_token(self.previous()));
                trailing_comma = True;
            } else {
                trailing_comma = False;
                break;
            }
        }
        rp_uni = self.consume_uni(TokenKind.RPAREN);
        kid: list[UniNode] = [lp_uni];
        comma_idx = 0;
        for (i, v) in enumerate(values) {
            kid.append(v);
            if i < len(values) - 1 and comma_idx < len(comma_unis) {
                kid.append(comma_unis[comma_idx]);
                comma_idx += 1;
            }
        }
        if trailing_comma and comma_idx < len(comma_unis) {
            kid.append(comma_unis[comma_idx]);
        }
        kid.append(rp_uni);
        return TupleVal(values=values, kid=kid);
    }
    rp_uni = self.consume_uni(TokenKind.RPAREN);
    if isinstance(first_item, KWPair) {
        return TupleVal(values=[first_item], kid=[lp_uni, first_item, rp_uni]);
    }
    return AtomUnit(value=first_item, kid=[lp_uni, first_item, rp_uni]);
}

impl Parser.parse_bracket_expr -> Expr {
    self.expect(TokenKind.LSQUARE);

    if self.check(TokenKind.NULL_OK) {
        return self.parse_filter_compr_bracket();
    }
    if self._is_edge_ref_start() {
        return self.parse_edge_ref_chain();
    }
    return self.parse_list_or_compr();
}

impl Parser._is_edge_ref_start -> bool {
    if self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1,
        TokenKind.RETURN_HINT,
        TokenKind.KW_ASYNC
    ) {
        return True;
    }

    if self.check_any(TokenKind.KW_NODE, TokenKind.KW_EDGE)
        and self.check_peek_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1,
            TokenKind.RETURN_HINT,
            TokenKind.NAME,
            TokenKind.KW_ROOT,
            TokenKind.KW_SELF,
            TokenKind.KW_HERE,
            TokenKind.KW_SUPER,
            TokenKind.KW_VISITOR
        ) {
        return True;
    }

    if self.check_any(
        TokenKind.NAME,
        TokenKind.KW_ROOT,
        TokenKind.KW_SELF,
        TokenKind.KW_HERE,
        TokenKind.KW_SUPER,
        TokenKind.KW_VISITOR
    ) {
        if self.check_peek_any(
            TokenKind.ARROW_R,
            TokenKind.ARROW_L,
            TokenKind.ARROW_BI,
            TokenKind.ARROW_R_P1,
            TokenKind.ARROW_L_P1,
            TokenKind.RETURN_HINT
        ) {
            return True;
        }
        if self.check_peek(TokenKind.LSQUARE) {
            save_pos = self.pos;
            self.advance();
            self.advance();
            depth = 1;
            while depth > 0 and not self.at_end() {
                if self.check(TokenKind.LSQUARE) {
                    depth += 1;
                } elif self.check(TokenKind.RSQUARE) {
                    depth -= 1;
                }
                self.advance();
            }
            is_edge = self.check_any(
                TokenKind.ARROW_R,
                TokenKind.ARROW_L,
                TokenKind.ARROW_BI,
                TokenKind.ARROW_R_P1,
                TokenKind.ARROW_L_P1,
                TokenKind.RETURN_HINT
            );
            self.pos = save_pos;
            return is_edge;
        }
    }
    return False;
}

impl Parser.parse_brace_expr -> Expr {
    self.expect(TokenKind.LBRACE);
    return self.parse_dict_or_set();
}

impl Parser.parse_fstring -> FString {
    start_tok = self.expect_any(
        TokenKind.F_DQ_START,
        TokenKind.F_SQ_START,
        TokenKind.F_TDQ_START,
        TokenKind.F_TSQ_START,
        TokenKind.RF_DQ_START,
        TokenKind.RF_SQ_START,
        TokenKind.RF_TDQ_START,
        TokenKind.RF_TSQ_START
    );
    start = self.make_uni_token(start_tok);
    end_kind: TokenKind;
    text_kind: TokenKind;
    if start_tok.kind == TokenKind.F_DQ_START {
        end_kind = TokenKind.F_DQ_END;
        text_kind = TokenKind.F_TEXT_DQ;
    } elif start_tok.kind == TokenKind.F_SQ_START {
        end_kind = TokenKind.F_SQ_END;
        text_kind = TokenKind.F_TEXT_SQ;
    } elif start_tok.kind == TokenKind.F_TDQ_START {
        end_kind = TokenKind.F_TDQ_END;
        text_kind = TokenKind.F_TEXT_TDQ;
    } elif start_tok.kind == TokenKind.F_TSQ_START {
        end_kind = TokenKind.F_TSQ_END;
        text_kind = TokenKind.F_TEXT_TSQ;
    } elif start_tok.kind == TokenKind.RF_DQ_START {
        end_kind = TokenKind.F_DQ_END;
        text_kind = TokenKind.F_TEXT_DQ;
    } elif start_tok.kind == TokenKind.RF_SQ_START {
        end_kind = TokenKind.F_SQ_END;
        text_kind = TokenKind.F_TEXT_SQ;
    } elif start_tok.kind == TokenKind.RF_TDQ_START {
        end_kind = TokenKind.F_TDQ_END;
        text_kind = TokenKind.F_TEXT_TDQ;
    } else {
        end_kind = TokenKind.F_TSQ_END;
        text_kind = TokenKind.F_TEXT_TSQ;
    }
    parts: list[String | FormattedValue] = [];
    kid: list[UniNode] = [start];
    while not self.check(end_kind) and not self.at_end() {
        if self.check(text_kind) {
            text_tok = self.advance();
            part = self.make_string(text_tok);
            parts.append(part);
            kid.append(part);
        } elif self.check(TokenKind.D_LBRACE) {
            self.expect(TokenKind.D_LBRACE);
            part = self.make_string_from_value("{");
            parts.append(part);
            kid.append(part);
        } elif self.check(TokenKind.D_RBRACE) {
            self.expect(TokenKind.D_RBRACE);
            part = self.make_string_from_value("}");
            parts.append(part);
            kid.append(part);
        } elif self.match_tok(TokenKind.LBRACE) {
            lbrace_uni = self.make_uni_token(self.previous());
            expr = self.parse_expression();
            conv = -1;
            fv_kid: list[UniNode] = [lbrace_uni, expr];
            if self.check(TokenKind.CONV) {
                conv_tok = self.expect(TokenKind.CONV);
                conv = ord(conv_tok.value[1]) if len(conv_tok.value) > 1 else -1;
                fv_kid.append(self.make_uni_token(conv_tok));
            }
            format_spec = None;
            if self.check(TokenKind.COLON) {
                self.expect(TokenKind.COLON);
                fv_kid.append(self.make_uni_token(self.previous()));

                spec_parts: list[str] = [];
                spec_nodes: list[String | FormattedValue] = [];
                while not self.check(TokenKind.RBRACE) and not self.at_end() {
                    if self.match_tok(TokenKind.LBRACE) {
                        nested_lbrace_uni = self.make_uni_token(self.previous());

                        if spec_parts {
                            spec_text = "";
                            for sp in spec_parts {
                                spec_text += sp;
                            }
                            spec_nodes.append(self.make_string_from_value(spec_text));
                            spec_parts = [];
                        }

                        nested_expr = self.parse_expression();
                        nested_conv = -1;
                        nested_fv_kid: list[UniNode] = [nested_lbrace_uni, nested_expr];
                        if self.check(TokenKind.CONV) {
                            nc_tok = self.expect(TokenKind.CONV);
                            nested_conv = ord(nc_tok.value[1])
                                if len(nc_tok.value) > 1
                                else -1;
                            nested_fv_kid.append(self.make_uni_token(nc_tok));
                        }
                        nested_fv_kid.append(self.consume_uni(TokenKind.RBRACE));
                        nested_fv = FormattedValue(
                            format_part=nested_expr,
                            conversion=nested_conv,
                            format_spec=None,
                            kid=nested_fv_kid
                        );
                        spec_nodes.append(nested_fv);
                    } else {
                        spec_tok = self.advance();
                        spec_parts.append(spec_tok.value);
                    }
                }
                if spec_parts {
                    spec_text = "";
                    for sp in spec_parts {
                        spec_text += sp;
                    }
                    spec_nodes.append(self.make_string_from_value(spec_text));
                }
                if spec_nodes {
                    if len(spec_nodes) == 1 and isinstance(spec_nodes[0], String) {
                        format_spec = spec_nodes[0];
                    } else {
                        format_spec = FString(
                            start=None, parts=spec_nodes, end=None, kid=list(spec_nodes)
                        );
                    }
                    fv_kid.append(format_spec);
                }
            }
            fv_kid.append(self.consume_uni(TokenKind.RBRACE));
            fv = FormattedValue(
                format_part=expr, conversion=conv, format_spec=format_spec, kid=fv_kid
            );
            parts.append(fv);
            kid.append(fv);
        } else {
            self.advance();
        }
    }
    end: Token | None = None;
    if self.check(end_kind) {
        end_tok = self.advance();
        end = self.make_uni_token(end_tok);
        kid.append(end);
    }
    return FString(start=start, parts=parts, end=end, kid=kid);
}

impl Parser.parse_list_or_compr -> Expr {
    lsquare_uni = self.make_uni_token(self.previous());
    if self.check(TokenKind.RSQUARE) {
        self.expect(TokenKind.RSQUARE);
        return ListVal(
            values=[], kid=[lsquare_uni, self.make_uni_token(self.previous())]
        );
    }
    first = self.parse_expression();
    if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid: list[UniNode] = [lsquare_uni, first];
        kid.extend(comprs);
        kid.append(self.consume_uni(TokenKind.RSQUARE));
        return ListCompr(out_expr=first, compr=comprs, kid=kid);
    }

    if self.check_any(
        TokenKind.ARROW_R,
        TokenKind.ARROW_L,
        TokenKind.ARROW_BI,
        TokenKind.ARROW_R_P1,
        TokenKind.ARROW_L_P1
    ) {
        return self._continue_edge_ref_chain(first, lsquare_uni);
    }
    values = [first];
    kid = [lsquare_uni, first];
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RSQUARE) {
            break;
        }
        val = self.parse_expression();
        values.append(val);
        kid.append(val);
    }
    kid.append(self.consume_uni(TokenKind.RSQUARE));
    return ListVal(values=values, kid=kid);
}

impl Parser._continue_edge_ref_chain(start_expr: Expr, lsquare_uni: Token) -> Expr {
    kid: list[UniNode] = [lsquare_uni, start_expr];
    chain: list[Expr | FilterCompr] = [start_expr];
    while True {
        edge_op_ref = self.parse_edge_op_ref();
        if edge_op_ref is None {
            break;
        }
        chain.append(edge_op_ref);
        kid.append(edge_op_ref);

        if self.check(TokenKind.LSQUARE) and self.check_peek(TokenKind.NULL_OK) {
            self.advance();
            filter_expr = self.parse_filter_compr_bracket();
            chain.append(filter_expr);
            kid.append(filter_expr);
        } elif self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.emit_diag(
                    "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
                    "E0048",
                    loc=self.current().loc,
                    help="Replace (?:Type, cond) with [?:Type, cond]"
                );
                self.advance();
                fc_expr = self.parse_filter_compr_inner();
                chain.append(fc_expr);
                kid.append(fc_expr);
            } else {
                self.advance();
                kid.append(self.make_uni_token(self.previous()));
                plain_expr = self.parse_expression();
                chain.append(plain_expr);
                kid.append(plain_expr);
                kid.append(self.consume_uni(TokenKind.RPAREN));
            }
        } elif self.check_any(
            TokenKind.NAME,
            TokenKind.KWESC_NAME,
            TokenKind.KW_SELF,
            TokenKind.KW_ROOT,
            TokenKind.KW_HERE,
            TokenKind.KW_SUPER
        ) {
            target_expr = self.parse_atomic_chain();
            chain.append(target_expr);
            kid.append(target_expr);
        }
    }
    kid.append(self.consume_uni(TokenKind.RSQUARE));
    return EdgeRefTrailer(chain=chain, edges_only=False, is_async=False, kid=kid);
}

impl Parser.parse_edge_ref_chain -> Expr {
    kid: list[UniNode] = [self.make_uni_token(self.previous())];
    chain: list[Expr | FilterCompr] = [];
    is_async = False;
    edges_only = False;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        kid.append(self.make_uni_token(self.previous()));
    }

    if self.check(TokenKind.KW_EDGE) {
        edges_only = True;
        filter_tok = self.expect(TokenKind.KW_EDGE);
        kid.append(self.make_uni_token(filter_tok));
    } elif self.check(TokenKind.KW_NODE) {
        self.expect(TokenKind.KW_NODE);
        kid.append(self.make_uni_token(self.previous()));
    }

    if self.check_any(
        TokenKind.NAME,
        TokenKind.KWESC_NAME,
        TokenKind.KW_ROOT,
        TokenKind.KW_SELF,
        TokenKind.KW_HERE,
        TokenKind.KW_SUPER,
        TokenKind.KW_VISITOR,
        TokenKind.LSQUARE
    ) {
        start_expr = self.parse_atomic_chain();
        chain.append(start_expr);
        kid.append(start_expr);
    }

    while True {
        edge_op_ref = self.parse_edge_op_ref();
        if edge_op_ref is None {
            break;
        }
        if edge_op_ref is not None {
            chain.append(edge_op_ref);
            kid.append(edge_op_ref);
        }

        if self.check(TokenKind.LSQUARE) and self.check_peek(TokenKind.NULL_OK) {
            self.expect(TokenKind.LSQUARE);
            filter_expr = self.parse_filter_compr_bracket();
            chain.append(filter_expr);
            kid.append(filter_expr);
        } elif self.check(TokenKind.LPAREN) {
            if self.check_peek(TokenKind.NULL_OK) {
                self.emit_diag(
                    "Parenthesized filter syntax '(?:...)' was removed. Use bracket syntax '[?:...]' instead.",
                    "E0048",
                    loc=self.current().loc,
                    help="Replace (?:Type, cond) with [?:Type, cond]"
                );
                self.expect(TokenKind.LPAREN);
                fc_expr = self.parse_filter_compr_inner();
                chain.append(fc_expr);
                kid.append(fc_expr);
            } else {
                self.expect(TokenKind.LPAREN);
                kid.append(self.make_uni_token(self.previous()));
                plain_expr = self.parse_expression();
                chain.append(plain_expr);
                kid.append(plain_expr);
                kid.append(self.consume_uni(TokenKind.RPAREN));
            }
        } elif self.check_any(
            TokenKind.NAME,
            TokenKind.KWESC_NAME,
            TokenKind.KW_SELF,
            TokenKind.KW_ROOT,
            TokenKind.KW_HERE,
            TokenKind.KW_SUPER
        ) {
            target_expr = self.parse_atomic_chain();
            chain.append(target_expr);
            kid.append(target_expr);
        }
    }
    kid.append(self.consume_uni(TokenKind.RSQUARE));
    return EdgeRefTrailer(
        chain=chain, edges_only=edges_only, is_async=is_async, kid=kid
    );
}

impl Parser.parse_edge_op_ref -> EdgeOpRef | None {
    if self.check_any(TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI) {
        edge_tok = self.expect_any(
            TokenKind.ARROW_R, TokenKind.ARROW_L, TokenKind.ARROW_BI
        );
        edge_uni = self.make_uni_token(edge_tok);
        dir = EdgeDir.OUT;
        if edge_tok.kind == TokenKind.ARROW_L {
            dir = EdgeDir.IN;
        } elif edge_tok.kind == TokenKind.ARROW_BI {
            dir = EdgeDir.ANY;
        }
        return EdgeOpRef(filter_cond=None, edge_dir=dir, kid=[edge_uni]);
    }

    if self.check(TokenKind.ARROW_R_P1) {
        self.expect(TokenKind.ARROW_R_P1);
        start_uni = self.make_uni_token(self.previous());
        f_type = None;
        compares: list[Expr] = [];
        fcompr_kid: list[UniNode] = [];
        if self.check_name() or self.is_keyword_token() {
            f_type = self.parse_atom();
            fcompr_kid.append(f_type);
        }
        if self.check(TokenKind.COLON) and not self.check(TokenKind.ARROW_R_P2) {
            self.expect(TokenKind.COLON);
            fcompr_kid.append(self.make_uni_token(self.previous()));
            if not self.check(TokenKind.ARROW_R_P2) {
                cmp = self.parse_compare();
                compares.append(cmp);
                fcompr_kid.append(cmp);
                while self.match_tok(TokenKind.COMMA) {
                    fcompr_kid.append(self.make_uni_token(self.previous()));
                    cmp = self.parse_compare();
                    compares.append(cmp);
                    fcompr_kid.append(cmp);
                }
            }
        }
        fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
        end_uni = self.consume_uni(TokenKind.ARROW_R_P2);
        return EdgeOpRef(
            filter_cond=fcond, edge_dir=EdgeDir.OUT, kid=[start_uni, fcond, end_uni]
        );
    }

    if self.check(TokenKind.ARROW_L_P1) {
        self.expect(TokenKind.ARROW_L_P1);
        start_uni = self.make_uni_token(self.previous());
        f_type = None;
        compares: list[Expr] = [];
        fcompr_kid: list[UniNode] = [];
        if self.check_name() or self.is_keyword_token() {
            f_type = self.parse_atom();
            fcompr_kid.append(f_type);
        }
        if self.check(TokenKind.COLON) and not self.check(TokenKind.ARROW_L_P2) {
            self.expect(TokenKind.COLON);
            fcompr_kid.append(self.make_uni_token(self.previous()));
            if not self.check(TokenKind.ARROW_L_P2) {
                cmp = self.parse_compare();
                compares.append(cmp);
                fcompr_kid.append(cmp);
                while self.match_tok(TokenKind.COMMA) {
                    fcompr_kid.append(self.make_uni_token(self.previous()));
                    cmp = self.parse_compare();
                    compares.append(cmp);
                    fcompr_kid.append(cmp);
                }
            }
        }
        fcond = FilterCompr(f_type=f_type, compares=compares, kid=fcompr_kid);
        end_uni = self.consume_uni(TokenKind.ARROW_L_P2);
        return EdgeOpRef(
            filter_cond=fcond, edge_dir=EdgeDir.IN, kid=[start_uni, fcond, end_uni]
        );
    }
    return None;
}

impl Parser.parse_dict_or_set -> Expr {
    lbrace_uni = self.make_uni_token(self.previous());
    if self.check(TokenKind.RBRACE) {
        self.expect(TokenKind.RBRACE);
        return DictVal(
            kv_pairs=[], kid=[lbrace_uni, self.make_uni_token(self.previous())]
        );
    }

    if self.check(TokenKind.STAR_POW) {
        return self.parse_dict_with_spread(lbrace_uni);
    }
    first = self.parse_expression();
    if self.match_tok(TokenKind.COLON) {
        colon_uni = self.make_uni_token(self.previous());
        value = self.parse_expression();
        if self.check(TokenKind.KW_FOR)
            or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
            comprs = self.parse_comprehension_clauses();
            kv = KVPair(key=first, value=value, kid=[first, colon_uni, value]);
            kid: list[UniNode] = [lbrace_uni, kv];
            kid.extend(comprs);
            kid.append(self.consume_uni(TokenKind.RBRACE));
            return DictCompr(kv_pair=kv, compr=comprs, kid=kid);
        }
        first_pair = KVPair(key=first, value=value, kid=[first, colon_uni, value]);
        pairs = [first_pair];
        kid: list[UniNode] = [lbrace_uni, first_pair];
        while self.match_tok(TokenKind.COMMA) {
            kid.append(self.make_uni_token(self.previous()));
            if self.check(TokenKind.RBRACE) {
                break;
            }
            if self.check(TokenKind.STAR_POW) {
                self.expect(TokenKind.STAR_POW);
                star_pow_uni = self.make_uni_token(self.previous());
                spread_val = self.parse_expression();
                pair = KVPair(
                    key=None, value=spread_val, kid=[star_pow_uni, spread_val]
                );
            } else {
                key = self.parse_expression();
                kv_colon_uni = self.consume_uni(TokenKind.COLON);
                val = self.parse_expression();
                pair = KVPair(key=key, value=val, kid=[key, kv_colon_uni, val]);
            }
            pairs.append(pair);
            kid.append(pair);
        }
        kid.append(self.consume_uni(TokenKind.RBRACE));
        return DictVal(kv_pairs=pairs, kid=kid);
    }
    if self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs = self.parse_comprehension_clauses();
        kid = [lbrace_uni, first];
        kid.extend(comprs);
        kid.append(self.consume_uni(TokenKind.RBRACE));
        return SetCompr(out_expr=first, compr=comprs, kid=kid);
    }
    values = [first];
    kid: list[UniNode] = [lbrace_uni, first];
    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RBRACE) {
            break;
        }
        val = self.parse_expression();
        values.append(val);
        kid.append(val);
    }
    kid.append(self.consume_uni(TokenKind.RBRACE));
    return SetVal(values=values, kid=kid);
}

impl Parser.parse_dict_with_spread(lbrace_uni: Token) -> DictVal {
    pairs: list[KVPair] = [];
    kid: list[UniNode] = [lbrace_uni];

    pair = self.parse_dict_spread_entry();
    pairs.append(pair);
    kid.append(pair);

    while self.match_tok(TokenKind.COMMA) {
        kid.append(self.make_uni_token(self.previous()));
        if self.check(TokenKind.RBRACE) {
            break;
        }
        pair = self.parse_dict_spread_entry();
        pairs.append(pair);
        kid.append(pair);
    }
    kid.append(self.consume_uni(TokenKind.RBRACE));
    return DictVal(kv_pairs=pairs, kid=kid);
}

impl Parser.parse_dict_spread_entry -> UniNode {
    if self.check(TokenKind.STAR_POW) {
        self.expect(TokenKind.STAR_POW);
        star_pow_uni = self.make_uni_token(self.previous());
        spread_val = self.parse_expression();
        return KVPair(key=None, value=spread_val, kid=[star_pow_uni, spread_val]);
    } else {
        key = self.parse_expression();
        kv_colon_uni = self.consume_uni(TokenKind.COLON);
        val = self.parse_expression();
        return KVPair(key=key, value=val, kid=[key, kv_colon_uni, val]);
    }
}

impl Parser.parse_comprehension_clauses -> list[InnerCompr] {
    comprs: list[InnerCompr] = [self.parse_compr_clause()];
    while self.check(TokenKind.KW_FOR)
        or (self.check(TokenKind.KW_ASYNC) and self.check_peek(TokenKind.KW_FOR)) {
        comprs.append(self.parse_compr_clause());
    }
    return comprs;
}

impl Parser.parse_compr_clause -> InnerCompr {
    is_async = False;
    async_uni: Token | None = None;
    if self.match_tok(TokenKind.KW_ASYNC) {
        is_async = True;
        async_uni = self.make_uni_token(self.previous());
    }
    for_uni = self.consume_uni(TokenKind.KW_FOR);
    target = self.parse_atomic_chain();
    in_uni = self.consume_uni(TokenKind.KW_IN);

    iter_expr = self.parse_pipe();
    ifs: list[Expr] = [];
    if_unis: list[Token] = [];
    while self.match_tok(TokenKind.KW_IF) {
        if_unis.append(self.make_uni_token(self.previous()));
        ifs.append(self.parse_walrus_assign());
    }
    kid: list[UniNode] = [];
    if async_uni {
        kid.append(async_uni);
    }
    kid.extend([for_uni, target, in_uni, iter_expr]);
    for i in range(len(ifs)) {
        kid.append(if_unis[i]);
        kid.append(ifs[i]);
    }
    return InnerCompr(
        is_async=is_async, target=target, collection=iter_expr, conditional=ifs, kid=kid
    );
}

impl Parser.parse_lambda_expr -> Expr {
    lambda_tok = self.consume_uni(TokenKind.KW_LAMBDA);

    sig_kid: list[UniNode] = [];
    params: list[ParamVar] = [];
    if self.match_tok(TokenKind.LPAREN) {
        sig_kid.append(self.make_uni_token(self.previous()));
        params = self.parse_func_params(sig_kid);
        sig_kid.append(self.consume_uni(TokenKind.RPAREN));
    }
    return_type = None;
    ret_hint_uni: Token | None = None;
    if self.match_tok(TokenKind.RETURN_HINT) {
        ret_hint_uni = self.make_uni_token(self.previous());
        return_type = self.parse_expression();
    }
    body_stmts2: (list[CodeBlockStmt] | None) = None;
    body_expr2: Expr | None = None;
    lbrace_uni: Token | None = None;
    rbrace_uni: Token | None = None;
    if self.match_tok(TokenKind.LBRACE) {
        lbrace_uni = self.make_uni_token(self.previous());
        body_stmts2 = self._apply_implicit_return(self.parse_code_block_stmts());
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
    } else {
        self.emit_diag(
            "Expected '{' after lambda parameters",
            "E0022",
            help="Lambda bodies are braced; a single expression statement is the implicit return, e.g. 'lambda (x: int) { x + 1; }'."
        );
        body_expr2 = self.parse_expression();
    }
    if return_type is not None and ret_hint_uni is not None {
        sig_kid.append(ret_hint_uni);
        sig_kid.append(return_type);
    }

    if len(sig_kid) == 0 {
        sig_kid.append(EmptyToken());
    }
    signature = FuncSignature(
        posonly_params=[],
        params=params,
        varargs=None,
        kwonlyargs=[],
        kwargs=None,
        return_type=return_type,
        kid=sig_kid
    );

    has_sig_content = (len(sig_kid) > 0 and not isinstance(sig_kid[0], EmptyToken))
        or return_type is not None;
    kid: list[UniNode] = [lambda_tok];
    if has_sig_content {
        kid.append(signature);
    }

    if body_expr2 is not None {
        kid.append(body_expr2);
    } else {
        if lbrace_uni {
            kid.append(lbrace_uni);
        }
        if body_stmts2 is not None {
            kid.extend(body_stmts2);
        }
        if rbrace_uni {
            kid.append(rbrace_uni);
        }
    }
    lam_body: (Expr | list[CodeBlockStmt]) = [];
    if body_expr2 is not None {
        lam_body = body_expr2;
    } elif body_stmts2 is not None {
        lam_body = body_stmts2;
    }
    return LambdaExpr(body=lam_body, kid=kid, signature=signature);
}

impl Parser.parse_jsx_element -> JsxElement {
    kid: list[UniNode] = [];

    if self.check(TokenKind.JSX_FRAG_OPEN) {
        frag_open = self.expect(TokenKind.JSX_FRAG_OPEN);
        kid.append(self.make_uni_token(frag_open));
        children = self.parse_jsx_children();
        kid.extend(children);
        kid.append(self.consume_uni(TokenKind.JSX_FRAG_CLOSE));
        return JsxElement(
            name=None,
            attributes=[],
            children=children,
            is_self_closing=False,
            is_fragment=True,
            kid=kid
        );
    }

    open_start_uni = self.consume_uni(TokenKind.JSX_OPEN_START);
    open_kid: list[UniNode] = [open_start_uni];

    elem_name: JsxElementName | None = None;
    dyn_tag: Expr | None = None;
    if self.check(TokenKind.DECOR_OP) {
        dyn_tag = self._parse_jsx_dynamic_tag(open_kid);
    } else {
        name_tok = self.expect(TokenKind.JSX_NAME);
        name = self.make_name(name_tok);
        name_parts: list[Token] = [name];
        name_kid: list[UniNode] = [name];
        while self.match_tok(TokenKind.DOT) {
            name_kid.append(self.make_uni_token(self.previous()));
            next_name_tok = self.expect(TokenKind.JSX_NAME);
            next_name = self.make_name(next_name_tok);
            name_parts.append(next_name);
            name_kid.append(next_name);
        }
        elem_name = JsxElementName(parts=name_parts, kid=name_kid);
        open_kid.append(elem_name);
    }

    attrs = self.parse_jsx_attributes();
    open_kid.extend(attrs);

    if self.check(TokenKind.JSX_SELF_CLOSE) {
        self.expect(TokenKind.JSX_SELF_CLOSE);
        open_kid.append(self.make_uni_token(self.previous()));
        return JsxElement(
            name=elem_name,
            attributes=attrs,
            children=None,
            is_self_closing=True,
            is_fragment=False,
            dynamic_tag=dyn_tag,
            kid=open_kid
        );
    }

    open_kid.append(self.consume_uni(TokenKind.JSX_TAG_END));

    kid.extend(open_kid);

    children = self.parse_jsx_children();
    kid.extend(children);

    close_start_uni = self.consume_uni(TokenKind.JSX_CLOSE_START);
    close_kid: list[UniNode] = [close_start_uni];
    close_elem_name: JsxElementName | None = None;
    if self.check(TokenKind.DECOR_OP) {
        self._consume_jsx_dynamic_close(close_kid);
    } else {
        close_name_tok = self.expect(TokenKind.JSX_NAME);
        close_name_node = self.make_name(close_name_tok);
        close_parts: list[Token] = [close_name_node];
        close_name_kid: list[UniNode] = [close_name_node];
        while self.match_tok(TokenKind.DOT) {
            close_name_kid.append(self.make_uni_token(self.previous()));
            cn_tok = self.expect(TokenKind.JSX_NAME);
            cn = self.make_name(cn_tok);
            close_parts.append(cn);
            close_name_kid.append(cn);
        }
        close_elem_name = JsxElementName(parts=close_parts, kid=close_name_kid);
        close_kid.append(close_elem_name);
    }
    close_kid.append(self.consume_uni(TokenKind.JSX_TAG_END));
    kid.extend(close_kid);
    return JsxElement(
        name=elem_name,
        attributes=attrs,
        children=children,
        is_self_closing=False,
        is_fragment=False,
        dynamic_tag=dyn_tag,
        kid=kid
    );
}

impl Parser._parse_jsx_dynamic_tag(open_kid: list[UniNode]) -> Expr | None {
    at_uni = self.make_uni_token(self.advance());
    open_kid.append(at_uni);
    if self.check(TokenKind.LBRACE) {
        lb_uni = self.make_uni_token(self.advance());
        expr = self.parse_expression();
        rb_uni = self.consume_uni(TokenKind.RBRACE);
        open_kid.append(lb_uni);
        open_kid.append(expr);
        open_kid.append(rb_uni);
        return expr;
    }
    name_tok = self.expect(TokenKind.JSX_NAME);
    expr = self.make_name(name_tok);
    while self.match_tok(TokenKind.DOT) {
        dot_uni = self.make_uni_token(self.previous());
        attr_tok = self.expect(TokenKind.JSX_NAME);
        attr = self.make_name(attr_tok);
        expr = AtomTrailer(
            target=expr,
            right=attr,
            is_attr=True,
            is_null_ok=False,
            kid=[expr, dot_uni, attr]
        );
    }
    open_kid.append(expr);
    return expr;
}

impl Parser._consume_jsx_dynamic_close(close_kid: list[UniNode]) {
    close_kid.append(self.make_uni_token(self.advance()));
    if self.check(TokenKind.LBRACE) {
        close_kid.append(self.make_uni_token(self.advance()));
        close_kid.append(self.parse_expression());
        close_kid.append(self.consume_uni(TokenKind.RBRACE));
        return;
    }
    close_kid.append(self.make_name(self.expect(TokenKind.JSX_NAME)));
    while self.match_tok(TokenKind.DOT) {
        close_kid.append(self.make_uni_token(self.previous()));
        close_kid.append(self.make_name(self.expect(TokenKind.JSX_NAME)));
    }
}

impl Parser.parse_jsx_attributes -> list[JsxAttribute] {
    attrs: list[JsxAttribute] = [];
    while True {
        if self.check(TokenKind.JSX_NAME) {
            attr_name_tok = self.expect(TokenKind.JSX_NAME);
            attr_name = self.make_uni_token(attr_name_tok);
            attr_value: UniNode | None = None;
            attr_kid: list[UniNode] = [attr_name];
            if self.match_tok(TokenKind.EQ) {
                attr_kid.append(self.make_uni_token(self.previous()));

                if self.check(TokenKind.LBRACE) {
                    self.expect(TokenKind.LBRACE);
                    lbrace = self.make_uni_token(self.previous());
                    attr_value = self.parse_expression();
                    rbrace = self.consume_uni(TokenKind.RBRACE);
                    attr_kid.append(lbrace);
                    attr_kid.append(attr_value);
                    attr_kid.append(rbrace);
                } elif self.check(TokenKind.STRING) {
                    str_tok = self.expect(TokenKind.STRING);
                    str_val: String = self.make_string(str_tok);
                    attr_value = str_val;
                    attr_kid.append(attr_value);
                }
            }
            attrs.append(
                JsxNormalAttribute(name=attr_name, value=attr_value, kid=attr_kid)
            );
        } elif self.check(TokenKind.LBRACE) {
            self.expect(TokenKind.LBRACE);
            lbrace_tok = self.make_uni_token(self.previous());
            saw_spread_marker: bool = False;
            spread_marker_kid: UniNode | None = None;
            if self.check(TokenKind.STAR_POW) {
                star_tok = self.expect(TokenKind.STAR_POW);
                spread_marker_kid = self.make_uni_token(star_tok);
                saw_spread_marker = True;
            } elif self.check(TokenKind.ELLIPSIS) {
                self.emit_warn(
                    "JSX spread '{...expr}' is JS-idiomatic. Prefer '{**expr}' in Jac.",
                    "W0063",
                    loc=self.current().loc,
                    help="Jac uses ** for dict unpacking -- use {**expr} instead of {...expr} in JSX attributes."
                );
                ellipsis_tok = self.expect(TokenKind.ELLIPSIS);
                spread_marker_kid = self.make_ellipsis(ellipsis_tok);
                saw_spread_marker = True;
            }
            inner_expr = self.parse_expression();
            rbrace_tok = self.consume_uni(TokenKind.RBRACE);
            if not saw_spread_marker and isinstance(inner_expr, Name) {
                attrs.append(
                    JsxNormalAttribute(
                        name=inner_expr,
                        value=inner_expr,
                        is_shorthand=True,
                        kid=[lbrace_tok, inner_expr, rbrace_tok]
                    )
                );
            } else {
                spread_kid: list[UniNode] = [lbrace_tok];
                if spread_marker_kid is not None {
                    spread_kid.append(spread_marker_kid);
                }
                spread_kid.append(inner_expr);
                spread_kid.append(rbrace_tok);
                attrs.append(JsxSpreadAttribute(expr=inner_expr, kid=spread_kid));
            }
        } else {
            break;
        }
    }
    return attrs;
}

impl Parser.parse_jsx_children -> list[JsxChild | JsxElement] {
    children: list[JsxChild | JsxElement] = [];
    while not self.at_end() {
        if self.check(TokenKind.JSX_CLOSE_START)
            or self.check(TokenKind.JSX_FRAG_CLOSE) {
            break;
        }
        child = self.parse_jsx_child();
        if child {
            children.append(child);
        } else {
            break;
        }
    }
    return children;
}

impl Parser.parse_jsx_child -> JsxChild | JsxElement | None {
    if self.check(TokenKind.JSX_TEXT) {
        text_tok = self.expect(TokenKind.JSX_TEXT);
        raw = text_tok.value;
        if not raw.strip() and ('\n' in raw or '\r' in raw) {
            return self.parse_jsx_child();
        }
        text_node = self.make_uni_token(text_tok);
        return JsxText(value=text_node, kid=[text_node]);
    }

    if self.check(TokenKind.JSX_COMMENT) {
        cmt_tok = self.expect(TokenKind.JSX_COMMENT);
        cmt_node = self.make_uni_token(cmt_tok);
        return JsxComment(value=cmt_node, kid=[cmt_node]);
    }

    if self.check(TokenKind.LBRACE) {
        lbrace = self.expect(TokenKind.LBRACE);
        lbrace_uni = self.make_uni_token(lbrace);

        if self.check_any(
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
            self._view_body_depth += 1;
            stmts = self.parse_code_block_stmts();
            self._view_body_depth -= 1;
            rbrace_uni = self.consume_uni(TokenKind.RBRACE);
            kid: list[UniNode] = [lbrace_uni];
            for s in stmts {
                kid.append(s);
            }
            kid.append(rbrace_uni);
            return JsxSlot(body=stmts, kid=kid);
        }

        expr = self.parse_expression();
        if self.check(TokenKind.SEMI) {
            first = ExprStmt(expr=expr, in_fstring=False, kid=[expr]);
            stmts2: list[CodeBlockStmt] = [first];
            if self.match_tok(TokenKind.SEMI) {
                prev_semi = self.previous();
                stmts2.append(
                    Semi(
                        orig_src=self.source,
                        name=Tok.SEMI.value,
                        value=prev_semi.value,
                        line=prev_semi.loc.line,
                        end_line=prev_semi.loc.end_line,
                        col_start=prev_semi.loc.col_start,
                        col_end=prev_semi.loc.col_end,
                        pos_start=prev_semi.loc.pos_start,
                        pos_end=prev_semi.loc.pos_end
                    )
                );
            }
            self._view_body_depth += 1;
            stmts2.extend(self.parse_code_block_stmts());
            self._view_body_depth -= 1;
            rbrace_uni = self.consume_uni(TokenKind.RBRACE);
            kid2: list[UniNode] = [lbrace_uni];
            for s in stmts2 {
                kid2.append(s);
            }
            kid2.append(rbrace_uni);
            return JsxSlot(body=stmts2, kid=kid2);
        }
        rbrace_uni = self.consume_uni(TokenKind.RBRACE);
        kid_expr: list[UniNode] = [lbrace_uni, expr, rbrace_uni];
        return JsxExpression(expr=expr, kid=kid_expr);
    }

    if self.check(TokenKind.JSX_OPEN_START) or self.check(TokenKind.JSX_FRAG_OPEN) {
        return self.parse_jsx_element();
    }

    return None;
}
