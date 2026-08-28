impl EsastGenPass.exit_delete_stmt(nd: uni.DeleteStmt) -> None {
    target = nd.target;
    if isinstance(target, uni.AtomTrailer) {
        return;
    }
    _kind = self._osp_expr_arch_kind(target);
    if (_kind is not None) and (_kind != "edge") {
        return;
    }
    self.needs_osp_graph = True;
    target_es = cast(
        es.Expression,
        self._get_ast_or_default(
            target, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(es.Identifier(name='__ospDiscW'), jac_node=nd),
                    arguments=[target_es]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_switch_case(nd: uni.SwitchCase) -> None {
    case_test: (es.Expression | None) = None;
    if (nd.pattern and isinstance(nd.pattern, uni.MatchValue)) {
        case_test = self._get_ast_or_default(
            nd.pattern.value,
            default_factory=lambda (_src: any) { es.Literal(value=None); }
        );
    }
    body_stmts = self._collect_stmt_body(nd.body);
    nd.gen.es_ast = self.sync_loc(
        es.SwitchCase(`test=case_test, consequent=body_stmts), jac_node=nd
    );
}

impl EsastGenPass.exit_switch_stmt(nd: uni.SwitchStmt) -> None {
    `test = self._get_ast_or_default(
        nd.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
    );
    cases: list[es.SwitchCase] = [];
    for stmt in nd.cases {
        if (stmt.gen.es_ast and isinstance(stmt.gen.es_ast, es.SwitchCase)) {
            switch_case = cast(es.SwitchCase, stmt.gen.es_ast);
            cases.append(switch_case);
        }
    }
    nd.gen.es_ast = self.sync_loc(
        es.SwitchStatement(discriminant=`test, cases=cases), jac_node=nd
    );
}

impl EsastGenPass.exit_match_stmt(nd: uni.MatchStmt) -> None {
    subj_expr = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.target, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    self.match_seq += 1;
    subj_name = f"__jac_match_subj_{self.match_seq}";
    flag_name = f"__jac_matched_{self.match_seq}";
    stmts: list[es.Statement] = [];
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=es.Identifier(name=subj_name), `init=subj_expr
                        ),
                        jac_node=nd
                    )
                ],
                kind='let'
            ),
            jac_node=nd
        )
    );
    stmts.append(
        self.sync_loc(
            es.VariableDeclaration(
                declarations=[
                    self.sync_loc(
                        es.VariableDeclarator(
                            id=es.Identifier(name=flag_name),
                            `init=es.Literal(value=False)
                        ),
                        jac_node=nd
                    )
                ],
                kind='let'
            ),
            jac_node=nd
        )
    );
    for mcase in nd.cases {
        (cond, binds, ok) = self._lower_match_pattern(
            mcase.pattern, self.sync_loc(es.Identifier(name=subj_name), jac_node=mcase)
        );
        if not ok {
            nd.gen.es_ast = self.sync_loc(es.BlockStatement(body=[]), jac_node=nd);
            return;
        }
        body_stmts = self._collect_stmt_body(mcase.body);
        set_flag = self.sync_loc(
            es.ExpressionStatement(
                expression=self.sync_loc(
                    es.AssignmentExpression(
                        operator='=',
                        left=es.Identifier(name=flag_name),
                        right=es.Literal(value=True)
                    ),
                    jac_node=mcase
                )
            ),
            jac_node=mcase
        );
        inner: list[es.Statement] = list(binds);
        if mcase.guard is not None {
            guard_expr = self._coerce_truthy(
                mcase.guard,
                cast(
                    es.Expression,
                    self._get_ast_or_default(
                        mcase.guard,
                        default_factory=lambda (_src: any) { es.Literal(value=True); }
                    )
                ),
                mcase
            );
            inner.append(
                self.sync_loc(
                    es.IfStatement(
                        `test=guard_expr,
                        consequent=self.sync_loc(
                            es.BlockStatement(body=[set_flag] + body_stmts),
                            jac_node=mcase
                        )
                    ),
                    jac_node=mcase
                )
            );
        } else {
            inner.append(set_flag);
            inner.extend(body_stmts);
        }
        test_expr: es.Expression = self.sync_loc(
            es.UnaryExpression(
                operator='!', prefix=True, argument=es.Identifier(name=flag_name)
            ),
            jac_node=mcase
        );
        if cond is not None {
            test_expr = self.sync_loc(
                es.LogicalExpression(operator='&&', left=test_expr, right=cond),
                jac_node=mcase
            );
        }
        stmts.append(
            self.sync_loc(
                es.IfStatement(
                    `test=test_expr,
                    consequent=self.sync_loc(
                        es.BlockStatement(body=inner), jac_node=mcase
                    )
                ),
                jac_node=mcase
            )
        );
    }
    nd.gen.es_ast = stmts;
}
impl EsastGenPass._match_subj_member(subj: es.Expression, field: str) -> es.Expression {
    return es.MemberExpression(
        object=subj, property=es.Identifier(name=field), computed=False
    );
}

impl EsastGenPass._match_bind_name(
    name_node: uni.UniNode, value: es.Expression
) -> es.Statement {
    bind_name = name_node.sym_name
        if isinstance(name_node, uni.AstSymbolNode)
        else str(name_node);
    self._ensure_identifier_declared(bind_name, name_node);
    return self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.AssignmentExpression(
                    operator='=', left=es.Identifier(name=bind_name), right=value
                ),
                jac_node=name_node
            )
        ),
        jac_node=name_node
    );
}

impl EsastGenPass._match_arch_field_order(pat: uni.MatchArch) -> (list[str] | None) {
    nm = pat.name;
    sym = nm.sym if isinstance(nm, uni.AstSymbolNode) else None;
    if sym is None {
        return None;
    }
    arch_node: (uni.UniNode | None) = sym.decl;
    while arch_node is not None and not isinstance(arch_node, uni.Archetype) {
        arch_node = arch_node.parent;
    }
    if arch_node is None {
        return None;
    }
    inner = self.unwrap_body(arch_node);
    if inner is None {
        return None;
    }
    order: list[str] = [];
    for stmt in inner {
        if isinstance(stmt, uni.ArchHas) {
            for hv in stmt.vars {
                order.append(hv.name.value);
            }
        }
    }
    return order or None;
}

impl EsastGenPass._lower_match_pattern(
    pat: uni.MatchPattern, subj: es.Expression
) -> tuple[(es.Expression | None), list[es.Statement], bool] {
    no_binds: list[es.Statement] = [];
    if isinstance(pat, uni.MatchWild) {
        return (None, no_binds, True);
    }
    if isinstance(pat, uni.MatchAs) {
        cond: (es.Expression | None) = None;
        binds: list[es.Statement] = [];
        if pat.pattern is not None {
            (cond, binds, ok) = self._lower_match_pattern(pat.pattern, subj);
            if not ok {
                return (None, no_binds, False);
            }
        }
        binds.append(self._match_bind_name(pat.name, subj));
        return (cond, binds, True);
    }
    if isinstance(pat, (uni.MatchValue, uni.MatchSingleton)) {
        val_node = pat.value;
        val_expr = cast(
            es.Expression,
            self._get_ast_or_default(
                val_node, default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );

        op = '==' if self._is_null_literal(val_node) else '===';
        return (
            self.sync_loc(
                es.BinaryExpression(operator=op, left=subj, right=val_expr),
                jac_node=pat
            ),
            no_binds,
            True
        );
    }
    if isinstance(pat, uni.MatchOr) {
        or_cond: (es.Expression | None) = None;
        for sub in pat.patterns {
            (c, b, ok) = self._lower_match_pattern(sub, subj);
            if not ok {
                return (None, no_binds, False);
            }
            if b {
                self.emit(
                    E5018,
                    node_override=sub,
                    construct='binding in an or-pattern',
                    fix="Give each '|' alternative its own 'case', so the binding "
                    "appears once per branch."
                );
                return (None, no_binds, False);
            }
            if c is None {
                return (None, no_binds, True);
            }
            or_cond = c
                if or_cond is None
                else self.sync_loc(
                    es.LogicalExpression(operator='||', left=or_cond, right=c),
                    jac_node=pat
                );
        }
        return (or_cond, no_binds, True);
    }
    if isinstance(pat, uni.MatchSequence) {
        values = list(pat.values);
        star_idx = -1;
        for i in range(len(values)) {
            if isinstance(values[i], uni.MatchStar) {
                star_idx = i;
                break;
            }
        }
        conds: list[es.Expression] = [
            self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Array'),
                        property=es.Identifier(name='isArray'),
                        computed=False
                    ),
                    arguments=[subj]
                ),
                jac_node=pat
            )
        ];
        seq_binds: list[es.Statement] = [];
        subj_len = self._match_subj_member(subj, 'length');
        if star_idx < 0 {
            conds.append(
                self.sync_loc(
                    es.BinaryExpression(
                        operator='===',
                        left=subj_len,
                        right=es.Literal(value=len(values))
                    ),
                    jac_node=pat
                )
            );
        } else {
            conds.append(
                self.sync_loc(
                    es.BinaryExpression(
                        operator='>=',
                        left=subj_len,
                        right=es.Literal(value=len(values) - 1)
                    ),
                    jac_node=pat
                )
            );
        }
        for i in range(len(values)) {
            sub = values[i];
            if isinstance(sub, uni.MatchStar) {
                after = len(values) - 1 - i;
                slice_args: list[es.Expression] = [es.Literal(value=i)];
                if after > 0 {
                    slice_args.append(
                        self.sync_loc(
                            es.BinaryExpression(
                                operator='-',
                                left=self._match_subj_member(subj, 'length'),
                                right=es.Literal(value=after)
                            ),
                            jac_node=sub
                        )
                    );
                }
                seq_binds.append(
                    self._match_bind_name(
                        sub.name,
                        self.sync_loc(
                            es.CallExpression(
                                callee=self._match_subj_member(subj, 'slice'),
                                arguments=slice_args
                            ),
                            jac_node=sub
                        )
                    )
                );
                continue;
            }
            if star_idx >= 0 and i > star_idx {
                elem_idx: es.Expression = self.sync_loc(
                    es.BinaryExpression(
                        operator='-',
                        left=self._match_subj_member(subj, 'length'),
                        right=es.Literal(value=len(values) - i)
                    ),
                    jac_node=sub
                );
            } else {
                elem_idx = es.Literal(value=i);
            }
            elem = self.sync_loc(
                es.MemberExpression(object=subj, property=elem_idx, computed=True),
                jac_node=sub
            );
            (c, b, ok) = self._lower_match_pattern(sub, elem);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                conds.append(c);
            }
            seq_binds.extend(b);
        }
        seq_cond: es.Expression = conds[0];
        for c in conds[1:] {
            seq_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=seq_cond, right=c),
                jac_node=pat
            );
        }
        return (seq_cond, seq_binds, True);
    }
    if isinstance(pat, uni.MatchMapping) {
        map_conds: list[es.Expression] = [];
        map_binds: list[es.Statement] = [];
        rest_star: (uni.MatchStar | None) = None;
        matched_keys: list[es.Expression] = [];
        for `entry in pat.values {
            if isinstance(`entry, uni.MatchStar) {
                rest_star = `entry;
                continue;
            }
            key_node = `entry.key;
            if isinstance(key_node, uni.MatchValue) {
                key_node = key_node.value;
            }
            key_expr = cast(
                es.Expression,
                self._get_ast_or_default(
                    key_node,
                    default_factory=lambda (_src: any) { es.Literal(value=None); }
                )
            );
            map_conds.append(
                self.sync_loc(
                    es.CallExpression(
                        callee=es.MemberExpression(
                            object=es.MemberExpression(
                                object=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='prototype'),
                                    computed=False
                                ),
                                property=es.Identifier(name='hasOwnProperty'),
                                computed=False
                            ),
                            property=es.Identifier(name='call'),
                            computed=False
                        ),
                        arguments=[subj, key_expr]
                    ),
                    jac_node=`entry
                )
            );
            val_at_key = self.sync_loc(
                es.MemberExpression(object=subj, property=key_expr, computed=True),
                jac_node=`entry
            );
            matched_keys.append(key_expr);
            (c, b, ok) = self._lower_match_pattern(`entry.value, val_at_key);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                map_conds.append(c);
            }
            map_binds.extend(b);
        }
        if rest_star is not None {
            filter_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[es.ArrayPattern(elements=[es.Identifier(name='__jac_k')])],
                    body=self.sync_loc(
                        es.UnaryExpression(
                            operator='!',
                            prefix=True,
                            argument=self.sync_loc(
                                es.CallExpression(
                                    callee=es.MemberExpression(
                                        object=es.ArrayExpression(
                                            elements=list(matched_keys)
                                        ),
                                        property=es.Identifier(name='includes'),
                                        computed=False
                                    ),
                                    arguments=[es.Identifier(name='__jac_k')]
                                ),
                                jac_node=rest_star
                            )
                        ),
                        jac_node=rest_star
                    ),
                    expression=True
                ),
                jac_node=rest_star
            );
            rest_value = self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Object'),
                        property=es.Identifier(name='fromEntries'),
                        computed=False
                    ),
                    arguments=[
                        self.sync_loc(
                            es.CallExpression(
                                callee=es.MemberExpression(
                                    object=self.sync_loc(
                                        es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='Object'),
                                                property=es.Identifier(name='entries'),
                                                computed=False
                                            ),
                                            arguments=[subj]
                                        ),
                                        jac_node=rest_star
                                    ),
                                    property=es.Identifier(name='filter'),
                                    computed=False
                                ),
                                arguments=[filter_arrow]
                            ),
                            jac_node=rest_star
                        )
                    ]
                ),
                jac_node=rest_star
            );
            map_binds.append(self._match_bind_name(rest_star.name, rest_value));
        }
        if not map_conds {
            return (None, map_binds, True);
        }
        map_cond: es.Expression = map_conds[0];
        for c in map_conds[1:] {
            map_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=map_cond, right=c),
                jac_node=pat
            );
        }
        return (map_cond, map_binds, True);
    }
    if isinstance(pat, uni.MatchArch) {
        cls_name = pat.name.sym_name
            if isinstance(pat.name, uni.AstSymbolNode)
            else None;
        if cls_name is None {
            self.emit(
                E5018,
                node_override=pat,
                construct='dotted class pattern',
                fix="Import the archetype directly and match on its bare name."
            );
            return (None, no_binds, False);
        }
        arch_conds: list[es.Expression] = [
            self.sync_loc(
                es.BinaryExpression(
                    operator='instanceof', left=subj, right=es.Identifier(name=cls_name)
                ),
                jac_node=pat
            )
        ];
        arch_binds: list[es.Statement] = [];
        pairs: list = [];
        arg_pats = list(pat.arg_patterns) if pat.arg_patterns else [];
        if arg_pats {
            order = self._match_arch_field_order(pat);
            if order is None or len(arg_pats) > len(order) {
                self.emit(
                    E5018,
                    node_override=pat,
                    construct='positional class pattern with unresolvable field order',
                    fix="Match the fields by keyword, 'Cls(field=pattern)', instead "
                    "of by position."
                );
                return (None, no_binds, False);
            }
            for i in range(len(arg_pats)) {
                pairs.append((order[i], arg_pats[i]));
            }
        }
        for kv in (list(pat.kw_patterns) if pat.kw_patterns else []) {
            fname = kv.key.sym_name if isinstance(kv.key, uni.AstSymbolNode) else None;
            if fname is None {
                self.emit(
                    E5018,
                    node_override=kv,
                    construct='computed class-pattern field',
                    fix="Name the field with a plain identifier instead of a "
                    "computed key."
                );
                return (None, no_binds, False);
            }
            pairs.append((fname, kv.value));
        }
        for (fname, sub_pat) in pairs {
            field_expr = self.sync_loc(
                self._match_subj_member(subj, fname), jac_node=pat
            );
            (c, b, ok) = self._lower_match_pattern(sub_pat, field_expr);
            if not ok {
                return (None, no_binds, False);
            }
            if c is not None {
                arch_conds.append(c);
            }
            arch_binds.extend(b);
        }
        arch_cond: es.Expression = arch_conds[0];
        for c in arch_conds[1:] {
            arch_cond = self.sync_loc(
                es.LogicalExpression(operator='&&', left=arch_cond, right=c),
                jac_node=pat
            );
        }
        return (arch_cond, arch_binds, True);
    }
    self.emit(
        E5018,
        node_override=pat,
        construct=pat.__class__.__name__,
        fix="Rewrite it with literal, capture, sequence, mapping, or class patterns."
    );
    return (None, no_binds, False);
}
impl EsastGenPass.exit_ctrl_stmt(nd: uni.CtrlStmt) -> None {
    acc = self._cur_view_acc();
    if acc is not None and nd.ctrl.value == "skip" {
        nd.gen.es_ast = self._view_fragment_return(acc, nd);
        return;
    }
    stmt: (es.BreakStatement | es.ContinueStatement | es.ReturnStatement);
    if (nd.ctrl.name == Tok.KW_BREAK) {
        stmt = self.sync_loc(es.BreakStatement(), jac_node=nd);
    } elif (nd.ctrl.name == Tok.KW_SKIP) {
        stmt = self.sync_loc(es.ReturnStatement(argument=None), jac_node=nd);
    } else {
        stmt = self.sync_loc(es.ContinueStatement(), jac_node=nd);
    }
    nd.gen.es_ast = stmt;
}

impl EsastGenPass.exit_return_stmt(nd: uni.ReturnStmt) -> None {
    acc = self._cur_view_acc();
    if acc is not None {
        nd.gen.es_ast = self._view_fragment_return(acc, nd);
        return;
    }
    argument: (es.Expression | None) = None;
    if (nd.expr and nd.expr.gen.es_ast) {
        argument = cast(es.Expression, nd.expr.gen.es_ast);
    }
    ret_stmt = self.sync_loc(es.ReturnStatement(argument=argument), jac_node=nd);
    nd.gen.es_ast = ret_stmt;
}
impl EsastGenPass._jac_exc_ref(
    member: str, jac_node: (uni.UniNode | None)
) -> es.MemberExpression {
    self.needs_jac_runtime = True;
    return cast(
        es.MemberExpression, self._build_jac_ref(['_jac', 'exc', member], jac_node)
    );
}

impl EsastGenPass.exit_raise_stmt(nd: uni.RaiseStmt) -> None {
    argument: es.Expression = cast(es.Expression, nd.cause.gen.es_ast)
        if (nd.cause and nd.cause.gen.es_ast)
        else self.sync_loc(es.Identifier(name='Error'), jac_node=nd);

    callee: (es.Expression | None) = None;
    call_args: (list | None) = None;
    if isinstance(argument, es.CallExpression) {
        callee = argument.callee;
        call_args = argument.arguments;
    } elif isinstance(argument, es.NewExpression) {
        callee = argument.callee;
        call_args = argument.arguments;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if callee is not None and isinstance(callee, es.Identifier) {
        if JAC_TYPE_REGISTRY.is_exception(callee.name) {
            exc_ref = self._jac_exc_ref(callee.name, nd);
            argument = self.sync_loc(
                es.NewExpression(callee=exc_ref, arguments=call_args or []), jac_node=nd
            );
        } elif callee.name == 'Error' {
            argument = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=nd),
                    arguments=call_args or []
                ),
                jac_node=nd
            );
        }
    }
    throw_stmt = self.sync_loc(es.ThrowStatement(argument=argument), jac_node=nd);
    nd.gen.es_ast = throw_stmt;
}

impl EsastGenPass.exit_finally_stmt(nd: uni.FinallyStmt) -> None {
    nd.gen.es_ast = self._build_block_statement(nd, nd.body);
}

impl EsastGenPass.exit_except(nd: uni.Except) -> None {
    if self._try_exit_except_view_awaiting(nd) {
        return;
    }

    body = self._build_block_statement(nd, nd.body);
    nd.gen.es_ast = body;
}

impl EsastGenPass.exit_try_stmt(nd: uni.TryStmt) -> None {
    if self._try_exit_try_stmt_view_awaiting(nd) {
        return;
    }
    block = self._build_block_statement(nd, nd.body);
    handler: (es.CatchClause | None) = None;
    if nd.excepts and len(nd.excepts) > 0 {
        catch_param_name = "__jac_e";
        catch_param = self.sync_loc(es.Identifier(name=catch_param_name), jac_node=nd);

        catch_body_stmts: list[es.Statement] = [];

        if_chain: (es.IfStatement | None) = None;
        for i in range(len(nd.excepts) - 1, -1, -1) {
            except_node = nd.excepts[i];

            handler_body: (es.BlockStatement | None) = None;
            if except_node.gen.es_ast
                and isinstance(except_node.gen.es_ast, es.BlockStatement) {
                handler_body = except_node.gen.es_ast;
            } else {
                handler_body = self.sync_loc(
                    es.BlockStatement(body=[]), jac_node=except_node
                );
            }

            if except_node.name {
                var_name = except_node.name?.sym_name or str(except_node.name);
                binding = self.sync_loc(
                    es.VariableDeclaration(
                        declarations=[
                            self.sync_loc(
                                es.VariableDeclarator(
                                    id=self.sync_loc(
                                        es.Identifier(name=var_name),
                                        jac_node=except_node.name
                                    ),
                                    init=self.sync_loc(
                                        es.Identifier(name=catch_param_name),
                                        jac_node=except_node
                                    )
                                ),
                                jac_node=except_node
                            )
                        ],
                        kind='let'
                    ),
                    jac_node=except_node
                );
                handler_body = self.sync_loc(
                    es.BlockStatement(body=[binding] + (handler_body.body or [])),
                    jac_node=except_node
                );
            }

            exc_type_name: (str | None) = None;
            if except_node.ex_type {
                if hasattr(except_node.ex_type, 'sym_name') {
                    exc_type_name = except_node.ex_type.sym_name;
                } elif hasattr(except_node.ex_type, 'value') {
                    exc_type_name = except_node.ex_type.value;
                }
            }
            import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

            test_expr: (es.Expression | None) = None;
            if exc_type_name and JAC_TYPE_REGISTRY.is_exception(exc_type_name) {
                test_expr = self.sync_loc(
                    es.CallExpression(
                        callee=self._jac_exc_ref('matches', except_node),
                        arguments=[
                            self.sync_loc(
                                es.Identifier(name=catch_param_name),
                                jac_node=except_node
                            ),
                            self.sync_loc(
                                es.Literal(
                                    value=exc_type_name, raw=json.dumps(exc_type_name)
                                ),
                                jac_node=except_node
                            )
                        ]
                    ),
                    jac_node=except_node
                );
            } elif exc_type_name {
                test_expr = self.sync_loc(
                    es.BinaryExpression(
                        operator='instanceof',
                        left=self.sync_loc(
                            es.Identifier(name=catch_param_name), jac_node=except_node
                        ),
                        right=self.sync_loc(
                            es.Identifier(name=exc_type_name), jac_node=except_node
                        )
                    ),
                    jac_node=except_node
                );
            }
            if test_expr is not None {
                if_chain = self.sync_loc(
                    es.IfStatement(
                        `test=test_expr, consequent=handler_body, alternate=if_chain
                    ),
                    jac_node=except_node
                );
            } else {
                if_chain = self.sync_loc(
                    es.IfStatement(
                        `test=self.sync_loc(
                            es.Literal(value=True, raw='true'), jac_node=except_node
                        ),
                        consequent=handler_body,
                        alternate=None
                    ),
                    jac_node=except_node
                );
            }
        }

        if if_chain is not None {
            tail = if_chain;
            while isinstance(tail.alternate, es.IfStatement) {
                tail = tail.alternate;
            }
            if tail.alternate is None {
                tail.alternate = self.sync_loc(
                    es.BlockStatement(
                        body=[
                            self.sync_loc(
                                es.ThrowStatement(
                                    argument=self.sync_loc(
                                        es.Identifier(name=catch_param_name),
                                        jac_node=nd
                                    )
                                ),
                                jac_node=nd
                            )
                        ]
                    ),
                    jac_node=nd
                );
            }
            catch_body_stmts.append(if_chain);
        }
        catch_body = self.sync_loc(
            es.BlockStatement(body=catch_body_stmts), jac_node=nd
        );
        handler = self.sync_loc(
            es.CatchClause(param=catch_param, body=catch_body), jac_node=nd
        );
    }
    finalizer: (es.BlockStatement | None) = None;
    if (
        nd.finally_body
        and nd.finally_body.gen.es_ast
        and isinstance(nd.finally_body.gen.es_ast, es.BlockStatement)
    ) {
        finalizer = nd.finally_body.gen.es_ast;
    }
    try_stmt = self.sync_loc(
        es.TryStatement(block=block, handler=handler, finalizer=finalizer), jac_node=nd
    );
    nd.gen.es_ast = try_stmt;
}
impl EsastGenPass._view_open_loop_acc(nd: uni.UniNode) -> None {
    acc = self._cur_view_acc();
    if (acc is None) or (acc in self._view_dynamic_accs) {
        return;
    }
    self._view_dynamic_accs.add(self._push_view_acc());
    self._view_slot_loops.add(id(nd));
}

impl EsastGenPass._view_loop_stmt(
    nd: uni.UniNode, loop_stmt: es.Statement
) -> es.Statement {
    if id(nd) not in self._view_slot_loops {
        return loop_stmt;
    }
    self._view_slot_loops.discard(id(nd));
    acc = self._view_stack.pop() if self._view_stack else None;
    if not isinstance(acc, str) {
        return loop_stmt;
    }
    iife = self._view_iife_from_stmts([loop_stmt], acc, nd);
    outer = self._cur_view_acc();
    if outer is not None {
        return self._view_emit_child(outer, iife, nd);
    }
    return self.sync_loc(es.ExpressionStatement(expression=iife), jac_node=nd);
}

impl EsastGenPass._view_chain_open(nd: uni.UniNode) -> None {
    acc = self._cur_view_acc();
    if (acc is None) or (acc in self._view_dynamic_accs) {
        return;
    }
    self._view_branch_base[id(nd)] = self._view_acc_next.get(acc, 0);
}

impl EsastGenPass._view_chain_arm(nd: uni.UniNode) -> None {
    acc = self._cur_view_acc();
    if (acc is None) or (acc in self._view_dynamic_accs) or (nd.parent is None) {
        return;
    }
    base = self._view_branch_base.get(id(nd.parent));
    if base is None {
        return;
    }
    self._view_branch_base[id(nd)] = base;
    self._view_acc_next[acc] = base;
}

impl EsastGenPass._view_chain_close(nd: uni.UniNode) -> None {
    if id(nd) not in self._view_branch_base {
        return;
    }
    self._view_branch_base.pop(id(nd), None);
    acc = self._cur_view_acc();
    if (acc is not None) and (acc not in self._view_dynamic_accs) {
        self._view_acc_next[acc] = self._view_acc_high.get(acc, 0);
    }
}

impl EsastGenPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    self._view_chain_open(nd);
}

impl EsastGenPass.enter_else_if(nd: uni.ElseIf) -> None {
    self._view_chain_arm(nd);
}

impl EsastGenPass.enter_else_stmt(nd: uni.ElseStmt) -> None {
    self._view_chain_arm(nd);
}

impl EsastGenPass.enter_in_for_stmt(nd: uni.InForStmt) -> None {
    self._view_open_loop_acc(nd);
}

impl EsastGenPass.enter_iter_for_stmt(nd: uni.IterForStmt) -> None {
    self._view_open_loop_acc(nd);
}

impl EsastGenPass.enter_while_stmt(nd: uni.WhileStmt) -> None {
    self._view_open_loop_acc(nd);
}

impl EsastGenPass.enter_forever_stmt(nd: uni.ForeverStmt) -> None {
    self._view_open_loop_acc(nd);
}

impl EsastGenPass.exit_in_for_stmt(nd: uni.InForStmt) -> None {
    target_ast = nd.target.gen.es_ast;
    left: es.Node = target_ast
        if isinstance(target_ast, es.Node)
        else self.sync_loc(es.Identifier(name='item'), jac_node=nd.target);
    right: es.Expression = cast(es.Expression, nd.collection.gen.es_ast)
        if nd.collection.gen.es_ast
        else self.sync_loc(es.Identifier(name='collection'), jac_node=nd.collection);

    ctype = self._expr_type_name(nd.collection);
    if ctype == "dict" {
        right = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(
                            es.Identifier(name='Object'), jac_node=nd.collection
                        ),
                        property=self.sync_loc(
                            es.Identifier(name='keys'), jac_node=nd.collection
                        ),
                        computed=False
                    ),
                    jac_node=nd.collection
                ),
                arguments=[right]
            ),
            jac_node=nd.collection
        );
    } elif ctype
        not in [
            "list",
            "str",
            "tuple",
            "set",
            "bytes",
            "bytearray",
            "range",
            "generator",
            "frozenset"
        ]
        and not self._is_native_iterable_builtin_call(nd.collection) {
        right = self._build_jac_call(
            ["_jac", "builtin", "iter"], [right], nd.collection
        );
    }
    body = self._build_block_statement(nd, nd.body);
    if isinstance(left, es.VariableDeclaration) {
        decl = left;
    } else {
        pattern = self._target_to_pattern(left, nd.target);
        declarator = self.sync_loc(
            es.VariableDeclarator(id=pattern, `init=None), jac_node=nd.target
        );
        decl = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'),
            jac_node=nd.target
        );
    }
    for_stmt = self.sync_loc(
        es.ForOfStatement(left=decl, right=right, body=body, await_=nd.is_async),
        jac_node=nd
    );
    nd.gen.es_ast = self._view_loop_stmt(nd, for_stmt);
}

impl EsastGenPass._target_to_pattern(target: es.Node, loc: uni.UniNode) -> es.Node {
    if isinstance(target, es.SpreadElement) {
        inner = self._target_to_pattern(target.argument, loc)
            if target.argument
            else self.sync_loc(es.Identifier(name='_item'), jac_node=loc);
        return self.sync_loc(es.RestElement(argument=inner), jac_node=loc);
    }
    if isinstance(target, es.ArrayExpression) {
        elements: list[(es.Node | None)] = [];
        for elem in target.elements {
            elements.append(
                self._target_to_pattern(elem, loc) if elem is not None else None
            );
        }
        return self.sync_loc(es.ArrayPattern(elements=elements), jac_node=loc);
    }
    pattern_nodes = (
        es.Identifier,
        es.ArrayPattern,
        es.ObjectPattern,
        es.AssignmentPattern,
        es.RestElement
    );
    if isinstance(target, pattern_nodes) {
        return target;
    }
    return self.sync_loc(es.Identifier(name='_item'), jac_node=loc);
}

impl EsastGenPass.exit_iter_for_stmt(nd: uni.IterForStmt) -> None {
    `init: es.VariableDeclaration | es.Expression | None = None;
    if (nd.iter and nd.iter.gen.es_ast) {
        iter_gen = nd.iter.gen.es_ast;
        if isinstance(iter_gen, es.ExpressionStatement) {
            `init = cast(es.Expression, iter_gen.expression);
        } else {
            `init = cast('es.VariableDeclaration | es.Expression', iter_gen);
        }
    }
    `test: (es.Expression | None) = None;
    if (nd.condition and nd.condition.gen.es_ast) {
        `test = cast(es.Expression, nd.condition.gen.es_ast);
    }
    update: (es.AssignmentExpression | None) = None;
    if (
        nd.count_by
        and nd.count_by.gen.es_ast
        and isinstance(nd.count_by.gen.es_ast, es.ExpressionStatement)
    ) {
        update = cast(es.AssignmentExpression, nd.count_by.gen.es_ast.expression);
    }
    body = self._build_block_statement(nd, nd.body);
    nd.gen.es_ast = self._view_loop_stmt(
        nd,
        self.sync_loc(
            es.ForStatement(`init=`init, `test=`test, update=update, body=body),
            jac_node=nd
        )
    );
}

impl EsastGenPass.exit_while_stmt(nd: uni.WhileStmt) -> None {
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                nd.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        nd
    );
    body = self._build_block_statement(nd, nd.body);
    while_stmt = self.sync_loc(es.WhileStatement(`test=`test, body=body), jac_node=nd);
    nd.gen.es_ast = self._view_loop_stmt(nd, while_stmt);
}

impl EsastGenPass.exit_forever_stmt(nd: uni.ForeverStmt) -> None {
    body = self._build_block_statement(nd, nd.body);
    forever_stmt = self.sync_loc(
        es.WhileStatement(`test=es.Literal(value=True), body=body), jac_node=nd
    );
    nd.gen.es_ast = self._view_loop_stmt(nd, forever_stmt);
}

impl EsastGenPass.exit_else_stmt(nd: uni.ElseStmt) -> None {
    self._view_chain_close(nd);
    stmts = self._collect_stmt_body(nd.body);
    stmts = self._prepend_hoisted(nd, stmts);
    block = self.sync_loc(es.BlockStatement(body=stmts), jac_node=nd);
    nd.gen.es_ast = block;
}

impl EsastGenPass.exit_else_if(nd: uni.ElseIf) -> None {
    self._view_chain_close(nd);
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                nd.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        nd
    );
    consequent = self._build_block_statement(nd, nd.body);
    alternate: (es.Statement | None) = None;
    if (nd.else_body and nd.else_body.gen.es_ast) {
        alternate = cast(es.Statement, nd.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(`test=`test, consequent=consequent, alternate=alternate),
        jac_node=nd
    );
    nd.gen.es_ast = if_stmt;
}

impl EsastGenPass.exit_if_stmt(nd: uni.IfStmt) -> None {
    self._view_chain_close(nd);
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            self._get_ast_or_default(
                nd.condition,
                default_factory=lambda (_src: any) { es.Literal(value=True); }
            )
        ),
        nd
    );
    consequent = self._build_block_statement(nd, nd.body);
    alternate: (es.Statement | None) = None;
    if (nd.else_body and nd.else_body.gen.es_ast) {
        alternate = cast(es.Statement, nd.else_body.gen.es_ast);
    }
    if_stmt = self.sync_loc(
        es.IfStatement(`test=`test, consequent=consequent, alternate=alternate),
        jac_node=nd
    );
    nd.gen.es_ast = if_stmt;
}
