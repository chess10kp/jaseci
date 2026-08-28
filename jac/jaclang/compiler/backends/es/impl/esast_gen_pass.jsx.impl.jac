impl EsastGenPass._return_type_includes_jsx_element(rt: uni.Expr) -> bool {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR
    ) {
        return (
            self._return_type_includes_jsx_element(rt.left)
            or self._return_type_includes_jsx_element(rt.right)
        );
    }
    return isinstance(rt, uni.Name)
        and rt.value in ('JsxElement', 'JsxPage', 'JsxLayout');
}

impl EsastGenPass._return_type_route_role(rt: uni.Expr) -> (str | None) {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR
    ) {
        left_role = self._return_type_route_role(rt.left);
        return left_role or self._return_type_route_role(rt.right);
    }
    if isinstance(rt, uni.Name) {
        if rt.value == 'JsxPage' {
            return 'page';
        }
        if rt.value == 'JsxLayout' {
            return 'layout';
        }
    }
    return None;
}

impl EsastGenPass._component_pascal_name(nd: uni.Ability) -> (str | None) {
    if nd.code_context != CodeContext.CLIENT or nd.is_method {
        return None;
    }
    if not isinstance(nd.signature, uni.FuncSignature) {
        return None;
    }
    rt = nd.signature.return_type;
    if rt is None or not self._return_type_includes_jsx_element(rt) {
        return None;
    }
    name = nd.name_ref.sym_name;
    if not name or not ('a' <= name[0] and name[0] <= 'z') {
        return None;
    }
    pascal = name[0].upper() + name[1:];
    mod = nd.find_parent_of_type(uni.Module);
    if mod is not None and mod.lookup(pascal, deep=False) is not None {
        return None;
    }
    return pascal;
}

impl EsastGenPass._component_call_abi(ability_node: uni.Ability) -> str {
    cached_abi = ability_node.gen?.component_call_abi;
    if isinstance(cached_abi, str) and cached_abi {
        return cached_abi;
    }
    abi = 'direct';
    if isinstance(ability_node.signature, uni.FuncSignature) {
        sig = ability_node.signature;
        if sig.get_parameters() {
            rt = sig.return_type;

            if rt is not None and self._return_type_includes_jsx_element(rt) {
                if (
                    ability_node.name_ref
                    and ability_node.name_ref.sym_name
                    and ability_node.name_ref.sym_name.startswith('__jac')
                ) {
                    abi = 'direct';
                } else {
                    all_pos_params = self._pos_params_from_ability(ability_node);
                    if (
                        len(all_pos_params) == 1
                        and all_pos_params[0].name.sym_name == 'props'
                    ) {
                        abi = 'props_passthrough';
                    } else {
                        abi = 'props_destructure';
                    }
                }
            }
        }
    }
    ability_node.gen.component_call_abi = abi;
    return abi;
}

impl EsastGenPass._build_props_spread_component_call(
    nd: uni.FuncCall,
    callee_expr: es.Expression,
    ability_node: uni.Ability,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)]
) -> es.Expression {
    param_names = self._param_names_from_ability(ability_node);
    packed_args = self.sync_loc(es.ArrayExpression(elements=args), jac_node=nd);
    packed_kwargs = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
    args_id = self.sync_loc(es.Identifier(name='__jac_args'), jac_node=nd);
    kwargs_id = self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd);
    wrap_props: list[es.Property] = [];
    for (i, pname) in enumerate(param_names) {
        len_expr = self.sync_loc(
            es.MemberExpression(
                object=args_id, property=es.Identifier(name='length'), computed=False
            ),
            jac_node=nd
        );
        pos_exists = self.sync_loc(
            es.BinaryExpression(
                operator='>',
                left=len_expr,
                right=self.sync_loc(es.Literal(value=i), jac_node=nd)
            ),
            jac_node=nd
        );
        pos_value = self.sync_loc(
            es.MemberExpression(
                object=args_id,
                property=self.sync_loc(es.Literal(value=i), jac_node=nd),
                computed=True
            ),
            jac_node=nd
        );
        kw_value = self.sync_loc(
            es.MemberExpression(
                object=kwargs_id,
                property=self.sync_loc(es.Literal(value=pname), jac_node=nd),
                computed=True
            ),
            jac_node=nd
        );
        wrap_props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Identifier(name=pname), jac_node=nd),
                    value=self.sync_loc(
                        es.ConditionalExpression(
                            `test=pos_exists, consequent=pos_value, alternate=kw_value
                        ),
                        jac_node=nd
                    ),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    inner_call = self.sync_loc(
        es.CallExpression(
            callee=callee_expr,
            arguments=[
                self.sync_loc(es.ObjectExpression(properties=wrap_props), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[args_id, kwargs_id],
                    body=inner_call,
                    expression=True,
                    async_=False
                ),
                jac_node=nd
            ),
            arguments=[packed_args, packed_kwargs]
        ),
        jac_node=nd
    );
}
impl EsastGenPass.exit_jsx_expression(nd: uni.JsxExpression) -> None {
    self.jsx_processor.expression(nd);
}

impl EsastGenPass.enter_jsx_slot(nd: uni.JsxSlot) -> None {
    self._push_view_acc();
}

impl EsastGenPass.exit_jsx_slot(nd: uni.JsxSlot) -> None {
    acc = self._view_stack.pop() if self._view_stack else VIEW_ACC;
    acc_name = acc if isinstance(acc, str) else VIEW_ACC;
    nd.gen.es_ast = self._build_view_iife(nd.body, acc_name, nd);
}

impl EsastGenPass._cur_view_acc -> (str | None) {
    if self._view_stack and isinstance(self._view_stack[-1], str) {
        return self._view_stack[-1];
    }
    return None;
}

impl EsastGenPass._push_view_acc -> str {
    if not self._view_used_base {
        self._view_used_base = True;
        name = VIEW_ACC;
    } else {
        self._view_acc_counter += 1;
        name = f"{VIEW_ACC}_{self._view_acc_counter}";
    }
    self._view_acc_next[name] = 0;
    self._view_acc_high[name] = 0;
    self._view_stack.append(name);
    return name;
}

impl EsastGenPass._view_alloc_index(acc_name: str) -> int {
    index = self._view_acc_next.get(acc_name, 0);
    self._view_acc_next[acc_name] = index + 1;
    if (index + 1) > self._view_acc_high.get(acc_name, 0) {
        self._view_acc_high[acc_name] = index + 1;
    }
    return index;
}

impl EsastGenPass._view_assign_stmt(
    acc_name: str, index: int, value: es.Expression, anchor: uni.UniNode
) -> es.ExpressionStatement {
    slot = self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
            property=self.sync_loc(es.Literal(value=index), jac_node=anchor),
            computed=True,
            optional=False
        ),
        jac_node=anchor
    );
    assign = self.sync_loc(
        es.AssignmentExpression(operator='=', left=slot, right=value), jac_node=anchor
    );
    return self.sync_loc(es.ExpressionStatement(expression=assign), jac_node=anchor);
}

impl EsastGenPass._view_emit_child(
    acc_name: str, value: es.Expression, anchor: uni.UniNode
) -> es.ExpressionStatement {
    if acc_name in self._view_dynamic_accs {
        return self._view_push_stmt(acc_name, value, anchor);
    }
    return self._view_assign_stmt(
        acc_name, self._view_alloc_index(acc_name), value, anchor
    );
}

impl EsastGenPass._view_push_stmt(
    acc_name: str, value: es.Expression, anchor: uni.UniNode
) -> es.ExpressionStatement {
    member = self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
            property=self.sync_loc(es.Identifier(name='push'), jac_node=anchor),
            computed=False,
            optional=False
        ),
        jac_node=anchor
    );
    call = self.sync_loc(
        es.CallExpression(callee=member, arguments=[value]), jac_node=anchor
    );
    return self.sync_loc(es.ExpressionStatement(expression=call), jac_node=anchor);
}

impl EsastGenPass._jsx_fragment(
    children: es.Expression, anchor: uni.UniNode
) -> es.Expression {
    import from jaclang.compiler.backends.es.view_ir {
        ViewElement,
        FragmentTag,
        DynamicChild
    }
    self._ensure_backend();
    if not self.backend.lowers_fragments_natively() {
        factory = self.backend.jsx_factory_name();
        factory_name = factory if isinstance(factory, str) and factory else "__jacJsx";
        self._inject_runtime_import(factory_name, anchor);
        return self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(es.Identifier(name=factory_name), jac_node=anchor),
                arguments=[
                    self.sync_loc(es.Literal(value=None), jac_node=anchor),
                    self.sync_loc(es.ObjectExpression(properties=[]), jac_node=anchor),
                    children
                ]
            ),
            jac_node=anchor
        );
    }

    view = self.sync_loc(
        ViewElement(
            tag=FragmentTag(jac_node=anchor),
            attrs=[],
            children=[
                self.sync_loc(
                    DynamicChild(value=children, jac_node=anchor), jac_node=anchor
                )
            ],
            jac_node=anchor
        ),
        jac_node=anchor
    );
    for sym in self.backend.view_runtime_symbols(view) {
        self._inject_runtime_import(sym, anchor);
    }
    return self.backend.lower_view(view, self.sync_loc);
}

impl EsastGenPass._view_fragment_return(
    acc_name: str, anchor: uni.UniNode
) -> es.ReturnStatement {
    acc_id = self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor);
    argument: es.Expression = acc_id
        if acc_name in self._view_dynamic_accs
        else self._jsx_fragment(acc_id, anchor);
    return self.sync_loc(es.ReturnStatement(argument=argument), jac_node=anchor);
}

impl EsastGenPass._build_view_iife(
    body_nodes: (Sequence[uni.UniNode] | None), acc_name: str, anchor: uni.UniNode
) -> es.CallExpression {
    return self._view_iife_from_stmts(
        self._collect_stmt_body(body_nodes), acc_name, anchor
    );
}

impl EsastGenPass._view_iife_from_stmts(
    stmts: list[es.Statement], acc_name: str, anchor: uni.UniNode
) -> es.CallExpression {
    init = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(
                        id=self.sync_loc(es.Identifier(name=acc_name), jac_node=anchor),
                        `init=self.sync_loc(
                            es.ArrayExpression(
                                elements=[
                                    self.sync_loc(
                                        es.Literal(value=False), jac_node=anchor
                                    )
                                    for _ in range(
                                        0
                                            if acc_name in self._view_dynamic_accs
                                            else self._view_acc_high.get(acc_name, 0)
                                    )
                                ]
                            ),
                            jac_node=anchor
                        )
                    ),
                    jac_node=anchor
                )
            ],
            kind='let'
        ),
        jac_node=anchor
    );
    body: list[es.Statement] = [init];
    body.extend(stmts);
    body.append(self._view_fragment_return(acc_name, anchor));
    block = self.sync_loc(es.BlockStatement(body=body), jac_node=anchor);
    arrow = self.sync_loc(
        es.ArrowFunctionExpression(params=[], body=block, async_=False), jac_node=anchor
    );
    return self.sync_loc(
        es.CallExpression(callee=arrow, arguments=[]), jac_node=anchor
    );
}

impl EsastGenPass.exit_jsx_text(nd: uni.JsxText) -> None {
    self.jsx_processor.text(nd);
}

impl EsastGenPass.exit_jsx_comment(nd: uni.JsxComment) -> None {
    nd.gen.es_ast = None;
}

impl EsastGenPass.exit_jsx_normal_attribute(nd: uni.JsxNormalAttribute) -> None { }

impl EsastGenPass.exit_jsx_spread_attribute(nd: uni.JsxSpreadAttribute) -> None {
    self.jsx_processor.spread_attribute(nd);
}

impl EsastGenPass.exit_jsx_element_name(nd: uni.JsxElementName) -> None {
    self.jsx_processor.element_name(nd);
}

impl EsastGenPass.exit_jsx_element(nd: uni.JsxElement) -> None {
    if (
        nd.name is not None
        and nd.name.parts
        and isinstance(nd.name.parts[0], uni.Name)
        and nd.name.parts[0].value in ("JacAwaiting", "JacClientErrorBoundary")
    ) {
        self._inject_runtime_import(nd.name.parts[0].value, nd);
    }

    if nd.dynamic_tag is not None {
        self._ensure_backend();
        if self.backend.import_source("Dynamic") != self.backend.runtime_module() {
            self._inject_runtime_import("Dynamic", nd);
        }
    }
    nd.gen.es_ast = self.jsx_processor.element(nd);

    self._ensure_backend();
    view = self.jsx_processor._view_by_node.get(id(nd));
    if view is not None {
        for sym in self.backend.view_runtime_symbols(view) {
            self._inject_runtime_import(sym, nd);
        }
    }
}
impl EsastGenPass._try_lower_component_props_destructure_call(
    nd: uni.FuncCall,
    ability_node_resolved: uni.Ability,
    callee_expr: es.Expression,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)],
    call_args: list[(es.Expression | es.SpreadElement)],
    spread_arg: (es.Expression | None),
    use_kwargs_temp: bool
) -> (es.Expression | None) {
    if self._component_call_abi(ability_node_resolved) != 'props_destructure' {
        return None;
    }
    result_expr: es.Expression;

    if any(isinstance(arg, es.SpreadElement) for arg in args) {
        result_expr = self._build_props_spread_component_call(
            nd, callee_expr, ability_node_resolved, args, props
        );
    } else {
        wrap_props: list[es.Property] = [];
        param_names = self._param_names_from_ability(ability_node_resolved);
        for (i, arg) in enumerate(call_args) {
            if i < len(param_names) {
                wrap_props.append(
                    self.sync_loc(
                        es.Property(
                            key=self.sync_loc(
                                es.Identifier(name=param_names[i]), jac_node=nd
                            ),
                            value=cast(es.Expression, arg),
                            kind='init',
                            method=False,
                            shorthand=False,
                            computed=False
                        ),
                        jac_node=nd
                    )
                );
            }
        }
        result_expr = self.sync_loc(
            es.CallExpression(
                callee=callee_expr,
                arguments=[
                    self.sync_loc(
                        es.ObjectExpression(properties=wrap_props), jac_node=nd
                    )
                ]
            ),
            jac_node=nd
        );
        if use_kwargs_temp and spread_arg is not None {
            result_expr = self._wrap_with_kwargs_temp(result_expr, spread_arg, nd);
        }
    }
    return result_expr;
}

