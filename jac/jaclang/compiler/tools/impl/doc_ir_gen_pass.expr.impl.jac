impl DocIRGenPass.exit_ellipsis with uni.Ellipsis exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_null with uni.Null exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_bool with uni.Bool exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_special_var_ref with uni.SpecialVarRef exit {
    here.gen.doc_ir = self.text(here.value.replace('_', ''), source_token=here);
}

impl DocIRGenPass.exit_string with uni.String exit {
    is_escaped_curly = (
        (here.lit_value in ['{', '}'])
        and here.parent
        and isinstance(here.parent, uni.FString)
    );
    if is_escaped_curly {
        here.gen.doc_ir = self.concat(
            [
                self.text(here.value, source_token=here),
                self.text(here.value, source_token=here)
            ]
        );
        return;
    }
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_float with uni.Float exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_builtin_type with uni.BuiltinType exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_int with uni.Int exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_name with uni.Name exit {
    if here.__class__ is not uni.Name {
        return;
    }
    name_text = f"`{here.value}" if here.is_kwesc else here.value;
    by_kids = [
        k
        for k in here.kid
        if (isinstance(k, uni.Token) and (k.name == Tok.KW_BY))
    ];
    by_kid = by_kids[0] if by_kids else None;
    if by_kid is not None {
        semi_kids = [
            k
            for k in here.kid
            if isinstance(k, uni.Semi)
        ];
        semi_kid = semi_kids[0] if semi_kids else None;
        parts: list[doc.DocType] = [
            by_kid.gen.doc_ir,
            self.space(),
            self.text(name_text, source_token=here)
        ];
        if semi_kid is not None {
            parts.append(semi_kid.gen.doc_ir);
        }
        here.gen.doc_ir = self.concat(parts, ast_node=here);
    } else {
        here.gen.doc_ir = self.text(name_text, source_token=here);
    }
}

impl DocIRGenPass.exit_semi with uni.Semi exit {
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_token with uni.Token exit {
    if here.__class__ is not uni.Token {
        return;
    }
    here.gen.doc_ir = self.text(here.value, source_token=here);
}

impl DocIRGenPass.exit_typed_ctx_block with uni.TypedCtxBlock exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_assign_compr with uni.AssignCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if isinstance(i, uni.Token) and i.name == Tok.COMMA {
            parts.append(doc.Text(", "));
        } else {
            parts.append(self.remove_all_spaces(i.gen.doc_ir));
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts));
}

impl DocIRGenPass.exit_filter_compr with uni.FilterCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if isinstance(i, uni.Token) and i.name == Tok.COMMA {
            parts.append(doc.Text(", "));
        } else {
            parts.append(self.remove_all_spaces(i.gen.doc_ir));
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts));
}

impl DocIRGenPass.exit_expr_as_item with uni.ExprAsItem exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_atom_unit with uni.AtomUnit exit {
    parts: list[doc.DocType] = [];
    prev_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
            if not (
                prev_item
                and isinstance(prev_item, uni.Token)
                and (prev_item.name == Tok.LPAREN)
            ) {
                parts.pop();
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
        prev_item = i;
    }
    parts.pop();
    broken = self.group(
        self.concat(
            [
                parts[0],
                self.indent(self.concat([self.tight_line(), *parts[1:-1]])),
                self.tight_line(),
                parts[-1]
            ]
        )
    );
    if (
        isinstance(here.parent, uni.Assignment)
        or (
            isinstance(here.parent, uni.IfStmt) and isinstance(here.value, uni.BoolExpr)
        )
    ) {
        here.gen.doc_ir = self.if_break(
            flat_contents=self.group(self.concat(parts[1:-1])), break_contents=broken
        );
    } else {
        here.gen.doc_ir = broken;
    }
}

impl DocIRGenPass.exit_compare_expr with uni.CompareExpr exit {
    self._assign_operator_chain(here, [here.left] + list(here.rights), list(here.ops));
}

impl DocIRGenPass.exit_disconnect_op with uni.DisconnectOp exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_connect_op with uni.ConnectOp exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_yield_expr with uni.YieldExpr exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_await_expr with uni.AwaitExpr exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_cast_expr with uni.CastExpr exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_k_w_pair with uni.KWPair exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_dict_compr with uni.DictCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name in [Tok.STAR_POW, Tok.STAR_MUL])) {
            parts.append(i.gen.doc_ir);
        } else {
            if isinstance(i, uni.InnerCompr) {
                parts.append(
                    self.group(self.concat([self.tight_line(), i.gen.doc_ir]))
                );
            } else {
                parts.append(i.gen.doc_ir);
            }
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.format_comprehension(parts);
}

impl DocIRGenPass.exit_set_compr with uni.SetCompr exit {
    self._assign_compr_doc_ir(here);
}

impl DocIRGenPass.exit_gen_compr with uni.GenCompr exit {
    self._assign_compr_doc_ir(here);
}

impl DocIRGenPass.exit_slice with uni.Slice exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_index_slice with uni.IndexSlice exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_edge_op_ref with uni.EdgeOpRef exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_edge_ref_trailer with uni.EdgeRefTrailer exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name in [Tok.KW_EDGE, Tok.KW_NODE])) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_lambda_expr with uni.LambdaExpr exit {
    parts: list[doc.DocType] = [];

    body_stmts = list(here.body) if isinstance(here.body, Sequence) else [];
    has_multi_stmt_body = len(body_stmts) > 1;

    _sbrace = len(body_stmts) == 0;
    if len(body_stmts) == 1 and body_stmts[0].kid {
        _cur: uni.UniNode = body_stmts[0];
        while _cur.kid {
            _last = _cur.kid[-1];
            if isinstance(_last, uni.Token) {
                _sbrace = _last.name == Tok.RBRACE;
                break;
            }
            _cur = _last;
        }
    }
    single_body_ends_with_brace = _sbrace;
    body_parts: list[doc.DocType] = [];
    in_body = False;
    for i in here.kid {
        if (
            has_multi_stmt_body and isinstance(i, uni.Token) and (i.name == Tok.LBRACE)
        ) {
            parts.append(i.gen.doc_ir);
            in_body = True;
            continue;
        }
        if (
            has_multi_stmt_body and isinstance(i, uni.Token) and (i.name == Tok.RBRACE)
        ) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if body_parts {
                parts.append(self.hard_line());
            } else {
                parts.append(self.space());
            }
            parts.append(i.gen.doc_ir);
            continue;
        }
        if in_body {
            if (i in body_stmts) {
                body_parts.append(self.hard_line());
                body_parts.append(i.gen.doc_ir);
            } else {
                body_parts.append(i.gen.doc_ir);
            }
            continue;
        }
        if (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            if not single_body_ends_with_brace {
                parts.append(self.space());
            }
            parts.append(i.gen.doc_ir);
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not body_stmts
        ) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.Token) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, uni.Expr) {
            parts.append(
                self.if_break(
                    self.indent(self.concat([self.line(), i.gen.doc_ir])), i.gen.doc_ir
                )
            );
        } elif isinstance(i, uni.FuncSignature) {
            if (isinstance(i.gen.doc_ir, doc.Text) and (i.gen.doc_ir.text == '()')) {
                parts.append(i.gen.doc_ir);
            } elif not i.params {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_unary_expr with uni.UnaryExpr exit {
    if is_mut_kind(here.ownership) {
        here.gen.doc_ir = self.group(
            self.concat(
                [
                    here.op.gen.doc_ir,
                    self.text("mut"),
                    self.space(),
                    here.operand.gen.doc_ir
                ],
                ast_node=here
            ),
            ast_node=here
        );
        return;
    }
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (
            (isinstance(i, uni.Token) and (i.value in ['-', '~', '+', '*', '&']))
            or isinstance(i, uni.Expr)
        ) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_cfg_expr with uni.CfgExpr exit {
    here.gen.doc_ir = here.expr.gen.doc_ir;
}

impl DocIRGenPass.exit_bool_expr with uni.BoolExpr exit {
    operands: list[uni.UniNode] = [];
    ops: list[uni.UniNode] = [];
    def __flatten(expr: uni.Expr) {
        inner = expr.expr if isinstance(expr, uni.CfgExpr) else expr;
        if isinstance(inner, uni.BoolExpr) {
            first = True;
            for val in inner.values {
                if not first {
                    ops.append(inner.op);
                }
                __flatten(val);
                first = False;
            }
        } else {
            operands.append(expr);
        }
    }
    __flatten(here);
    self._assign_operator_chain(here, operands, ops);
}

impl DocIRGenPass.exit_if_else_expr with uni.IfElseExpr exit {
    parts: list[doc.DocType] = [];
    continuation: list[doc.DocType] = [];
    seen_first_expr = False;
    for i in here.kid {
        if isinstance(i, uni.Expr) and not seen_first_expr {
            parts.append(i.gen.doc_ir);
            seen_first_expr = True;
        } elif (isinstance(i, uni.Token) and not isinstance(i, uni.Expr)) {
            continuation.append(i.gen.doc_ir);
            continuation.append(self.space());
        } elif isinstance(i, uni.Expr) {
            continuation.append(i.gen.doc_ir);
            continuation.append(self.line());
        } else {
            continuation.append(i.gen.doc_ir);
            continuation.append(self.line());
        }
    }
    if continuation and isinstance(continuation[-1], doc.Line) {
        continuation.pop();
    }

    parts.append(self.indent(self.concat([self.line(), *continuation])));
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_formatted_value with uni.FormattedValue exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_f_string with uni.FString exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_inner_compr with uni.InnerCompr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_IF)) {
            parts.append(self.hard_line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_list_compr with uni.ListCompr exit {
    if here.__class__ is not uni.ListCompr {
        return;
    }
    self._assign_compr_doc_ir(here);
}

impl DocIRGenPass.exit_set_val with uni.SetVal exit {
    here.gen.doc_ir = self.format_comma_collection(here);
}

impl DocIRGenPass.exit_multi_string with uni.MultiString exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.group(
        self.concat(self.intersperse(parts, self.line()), ast_node=here), ast_node=here
    );
}

impl DocIRGenPass.exit_tuple_val with uni.TupleVal exit {
    here.gen.doc_ir = self.format_comma_collection(here);
}

impl DocIRGenPass.exit_k_v_pair with uni.KVPair exit {
    parts: list[doc.DocType] = [];
    kid_count = len(here.kid);
    for (idx, kid) in enumerate(here.kid) {
        parts.append(kid.gen.doc_ir);
        is_last = idx == (kid_count - 1);
        if (isinstance(kid, uni.Token) and (kid.name == Tok.COLON)) {
            if not is_last {
                parts.append(self.space());
            }
        } elif not is_last {
            next_kid = here.kid[(idx + 1)];
            if (isinstance(next_kid, uni.Token) and (next_kid.name == Tok.COLON)) {
                continue;
            }
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_dict_val with uni.DictVal exit {
    if not here.kid {
        here.gen.doc_ir = self.group(self.concat([]));
        return;
    }
    if not here.kv_pairs {
        here.gen.doc_ir = self.group(self.concat([kid.gen.doc_ir for kid in here.kid]));
        return;
    }
    inline_parts: list[doc.DocType] = [];
    broken_parts: list[doc.DocType] = [];
    for i in here.kid {
        if (
            (isinstance(i, uni.Token) and (i.name in [Tok.LBRACE, Tok.RBRACE]))
            or isinstance(i, uni.KVPair)
        ) {
            inline_parts.append(i.gen.doc_ir);
            broken_parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            inline_parts.append(i.gen.doc_ir);
            inline_parts.append(self.space());
            broken_parts.append(i.gen.doc_ir);
            broken_parts.append(self.hard_line());
        }
    }
    if (
        (len(inline_parts) >= 2)
        and isinstance(inline_parts[-2], doc.Text)
        and (inline_parts[-2].text == ' ')
    ) {
        inline_parts.pop(-2);
    }
    self.trim_trailing_line(broken_parts);
    not_broke = self.concat(inline_parts);
    lbrace_doc = broken_parts[0];
    rbrace_doc = broken_parts[-1];
    middle_parts = broken_parts[1:-1];
    broke = self.concat(
        [
            lbrace_doc,
            self.indent(self.concat([self.hard_line(), *middle_parts]), ast_node=here),
            self.hard_line(),
            rbrace_doc
        ]
    );
    here.gen.doc_ir = self.group(self.if_break(broke, not_broke));
}

impl DocIRGenPass.exit_list_val with uni.ListVal exit {
    here.gen.doc_ir = self.format_comma_collection(here);
}

impl DocIRGenPass.exit_graph_expr with uni.GraphExpr exit {
    parts: list[doc.DocType] = [];
    for (index, child) in enumerate(here.kid[2:-1]) {
        if isinstance(child, uni.Expr) {
            parts.extend([self.line(), child.gen.doc_ir]);
            following = here.kid[index + 3];
            if not (isinstance(following, uni.Token) and following.name == Tok.SEMI) {
                parts.append(self.text(";"));
            }
        } else {
            parts.append(child.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(
        self.concat(
            [
                here.kid[0].gen.doc_ir,
                self.space(),
                here.kid[1].gen.doc_ir,
                self.indent(self.concat(parts), ast_node=here),
                self.line(),
                here.kid[-1].gen.doc_ir
            ],
            ast_node=here
        ),
        ast_node=here
    );
}

impl DocIRGenPass.exit_atom_trailer with uni.AtomTrailer exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_BY)) {
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_func_call with uni.FuncCall exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    in_params = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and here.params) {
            in_params = True;
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and here.params) {
            in_params = False;
            if isinstance(indent_parts[-1], doc.Line) {
                indent_parts.pop();
            }
            parts.append(
                self.indent(
                    self.concat(
                        [self.tight_line(), self.group(self.concat([*indent_parts]))]
                    ),
                    ast_node=here
                )
            );
            parts.append(self.tight_line());
            parts.append(i.gen.doc_ir);
        } elif in_params {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                indent_parts.append(i.gen.doc_ir);
                indent_parts.append(self.line());
            } else {
                indent_parts.append(i.gen.doc_ir);
            }
        } else {
            parts.append(i.gen.doc_ir);
            if (isinstance(i, uni.Token) and (i.name == Tok.KW_BY)) {
                parts.append(self.space());
            }
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_concurrent_expr with uni.ConcurrentExpr exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
        parts.append(self.space());
    }
    here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
}

impl DocIRGenPass.exit_binary_expr with uni.BinaryExpr exit {
    if not isinstance(here.op, uni.Token) or here.op.name.startswith('KW_') {
        self._assign_space_group(here);
        return;
    }
    operands: list[uni.UniNode] = [];
    ops: list[uni.UniNode] = [];
    def __flatten(expr: uni.UniNode) {
        if (
            isinstance(expr, uni.BinaryExpr)
            and isinstance(expr.op, uni.Token)
            and (expr.op.name == here.op.name)
        ) {
            __flatten(expr.left);
            ops.append(expr.op);
            __flatten(expr.right);
        } else {
            operands.append(expr);
        }
    }
    __flatten(here);
    self._assign_operator_chain(here, operands, ops);
}

impl DocIRGenPass.trim_trailing_line(parts: list[doc.DocType]) -> None {
    if not parts {
        return;
    }
    while parts {
        last = parts[-1];
        if isinstance(last, doc.Line) {
            parts.pop();
            continue;
        } elif isinstance(last, doc.Concat) {
            self.trim_trailing_line(last.parts);
            if not last.parts {
                parts.pop();
                continue;
            }
        } elif isinstance(last, doc.Group) {
            contents = last.contents;
            if isinstance(contents, doc.Concat) {
                self.trim_trailing_line(contents.parts);
                if not contents.parts {
                    parts.pop();
                    continue;
                }
            } elif isinstance(contents, doc.Line) {
                parts.pop();
                continue;
            }
        }
        break;
    }
}

impl DocIRGenPass.is_within(
    kid_node: uni.UniNode, block: Sequence[uni.UniNode]
) -> bool {
    if not block {
        return False;
    }
    (start, end, kid) = (block[0].loc, block[-1].loc, kid_node.loc);
    first = (
        (start.first_line < kid.first_line)
        or ((start.first_line == kid.first_line) and (start.col_start <= kid.col_start))
    );
    last = (
        (end.last_line > kid.last_line)
        or ((end.last_line == kid.last_line) and (end.col_end >= kid.col_end))
    );
    return (first and last);
}

impl DocIRGenPass.add_body_stmt_with_spacing(
    body_parts: list[doc.DocType], current: uni.UniNode, previous: (uni.UniNode | None)
) -> None {
    if (previous and self.has_gap(previous, current)) {
        body_parts.append(self.hard_line());
    }
    body_parts.append(current.gen.doc_ir);
    body_parts.append(self.hard_line());
}

impl DocIRGenPass.has_gap(prev_kid: uni.UniNode, curr_kid: uni.UniNode) -> bool {
    return ((prev_kid.loc.last_line + 1) < self.effective_first_line(curr_kid));
}

impl DocIRGenPass.is_one_line(nd: uni.UniNode) -> bool {
    return (bool(nd.kid) and (nd.kid[0].loc.first_line == nd.kid[-1].loc.last_line));
}

impl DocIRGenPass.format_comprehension(parts: list[doc.DocType]) -> doc.DocType {
    if (parts and isinstance(parts[-1], doc.Text) and (parts[-1].text == ' ')) {
        parts.pop();
    }
    if (len(parts) >= 3) {
        opening = parts[0];
        closing = parts[-1];
        middle = parts[1:-1] if (len(parts) > 2) else [];
        if (middle and isinstance(middle[0], doc.Text) and (middle[0].text == ' ')) {
            middle = middle[1:];
        }
        if (middle and isinstance(middle[-1], doc.Text) and (middle[-1].text == ' ')) {
            middle = middle[:-1];
        }
        return self.group(
            self.concat(
                [
                    opening,
                    self.indent(self.concat([self.tight_line(), *middle])),
                    self.tight_line(),
                    closing
                ]
            )
        );
    } else {
        return self.group(self.concat(parts));
    }
}

impl DocIRGenPass.format_simple_stmt_with_body(
    nd: uni.UniNode, body: Sequence[uni.UniNode], space_between_parts: bool = True
) -> doc.DocType {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    prev_body_item: (uni.UniNode | None) = None;
    for i in nd.kid {
        if (isinstance(body, Sequence) and self.is_within(i, body)) {
            if (body and (i == body[0])) {
                parts.append(self.indent(self.concat(body_parts), ast_node=nd));
                parts.append(self.hard_line());
            }
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not body) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            if space_between_parts {
                parts.append(self.space());
            }
        }
    }
    if (parts and isinstance(parts[-1], doc.Text) and (parts[-1].text == ' ')) {
        parts.pop();
    }
    if (body_parts and isinstance(body_parts[-1], doc.Line)) {
        body_parts.pop();
    }
    return self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass.intersperse(
    items: list[doc.DocType], separator: doc.DocType
) -> list[doc.DocType] {
    if not items {
        return [];
    }
    result = [items[0]];
    for item in items[1:] {
        result.append(separator);
        result.append(item);
    }
    return result;
}

impl DocIRGenPass._assign_space_group(nd: uni.UniNode) -> None {
    nd.gen.doc_ir = self.group(self.join_with_space(self._child_docs(nd)), ast_node=nd);
}

impl DocIRGenPass._assign_operator_chain(
    nd: uni.UniNode, operands: list[uni.UniNode], ops: list[uni.UniNode]
) -> None {
    rest: list[doc.DocType] = [];
    for i in range(len(ops)) {
        rest += [
            self.line(),
            ops[i].gen.doc_ir,
            self.space(),
            operands[(i + 1)].gen.doc_ir
        ];
    }

    tail: doc.DocType = self.concat(rest);
    parent = nd.parent;
    if isinstance(parent, uni.CfgExpr) {
        parent = parent.parent;
    }
    if not isinstance(parent, uni.AtomUnit) {
        tail = self.indent(tail);
    }
    nd.gen.doc_ir = self.group(
        self.concat([operands[0].gen.doc_ir, tail], ast_node=nd), ast_node=nd
    );
}

impl DocIRGenPass._assign_group_concat(nd: uni.UniNode) -> None {
    nd.gen.doc_ir = self.group(
        self.concat(self._child_docs(nd), ast_node=nd), ast_node=nd
    );
}

impl DocIRGenPass._assign_semi_stmt_doc_ir(nd: uni.UniNode) -> None {
    parts: list[doc.DocType] = [];
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI) and len(parts)) {
            parts.pop();
        }
        parts.append(i.gen.doc_ir);
        parts.append(self.space());
    }
    parts.pop();
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass._assign_compr_doc_ir(nd: uni.UniNode) -> None {
    parts: list[doc.DocType] = [];
    for i in nd.kid {
        if isinstance(i, uni.InnerCompr) {
            parts.append(self.group(self.concat([self.tight_line(), i.gen.doc_ir])));
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    nd.gen.doc_ir = self.format_comprehension(parts);
}

impl DocIRGenPass._assign_else_doc_ir(
    nd: uni.UniNode, body: Sequence[uni.UniNode]
) -> None {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    for i in nd.kid {
        if (isinstance(body, Sequence) and self.is_within(i, body)) {
            if (i == body[0]) {
                parts.append(self.indent(self.concat(body_parts), ast_node=nd));
                parts.append(self.hard_line());
            }
            body_parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not body) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    body_parts.pop();
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass._emit_keyword_block(nd: uni.UniNode, kw: Tok) -> None {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == kw)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
            in_body = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=nd));
            if len(body_parts) {
                parts.append(self.hard_line());
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif in_body {
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass._child_docs(nd: uni.UniNode) -> list[doc.DocType] {
    docs: list[doc.DocType] = [];
    for kid in nd.kid {
        docs.append(kid.gen.doc_ir);
    }
    return docs;
}

impl DocIRGenPass.join_with_space(parts: list[doc.DocType]) -> doc.DocType {
    return self.join(self.space(), parts);
}

impl DocIRGenPass.join(
    separator: doc.DocType, parts: list[doc.DocType]
) -> doc.DocType {
    if not parts {
        return self.concat([]);
    }
    result = [parts[0]];
    for part in parts[1:] {
        result.append(separator);
        result.append(part);
    }
    return self.concat(result);
}

impl DocIRGenPass.align(contents: doc.DocType, n: (int | None) = None) -> doc.Align {
    return doc.Align(contents, n);
}

impl DocIRGenPass.if_break(
    break_contents: doc.DocType, flat_contents: doc.DocType
) -> doc.IfBreak {
    return doc.IfBreak(break_contents, flat_contents);
}

impl DocIRGenPass.concat(
    parts: list[doc.DocType], ast_node: (uni.UniNode | None) = None
) -> doc.Concat {
    return doc.Concat(parts, ast_node=ast_node);
}

impl DocIRGenPass.indent(
    contents: doc.DocType, ast_node: (uni.UniNode | None) = None
) -> doc.Indent {
    return doc.Indent(contents, ast_node=ast_node);
}

impl DocIRGenPass.group(
    contents: doc.DocType,
    break_contiguous: bool = False,
    ast_node: (uni.UniNode | None) = None
) -> doc.Group {
    return doc.Group(contents, break_contiguous, ast_node=ast_node);
}
