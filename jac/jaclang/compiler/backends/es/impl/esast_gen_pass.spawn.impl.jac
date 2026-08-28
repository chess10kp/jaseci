impl EsastGenPass._try_lower_server_rpc_call(
    nd: uni.FuncCall,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)]
) -> (es.Expression | None) {
    if not (nd.in_client_context() and isinstance(nd.target, uni.Name)) {
        return None;
    }
    ability_node = self._resolve_call_ability(nd);
    if not ability_node {
        return None;
    }
    is_server_func = (
        ability_node.code_context != CodeContext.CLIENT
        and ability_node.code_context != CodeContext.NATIVE
        and not ability_node.in_client_context()
        and ability_node.access is not None
        and ability_node.access.tag.name == Tok.KW_PUB
    );
    if not is_server_func {
        return None;
    }
    func_name = nd.target.sym_name;
    self._warn_rpc_callable_params(ability_node, func_name, nd);

    param_names: list[str] = self._param_names_from_ability(ability_node);
    inline_param_type_map: dict[str, str] = self._param_type_map_from_ability(
        ability_node
    );
    inline_ret_type: str = self._extract_return_type(
        ability_node, func_name, self.ir_in.gen.interop_manifest
    );
    inline_boundary = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, nd);
    use_kwargs_temp = spread_read_source is not None;
    slots = self._resolve_call_arg_slots(
        nd, args, props, param_names, func_name, spread_read_source
    );
    rpc_props: list[(es.Property | es.SpreadElement)] = [];
    for slot in slots {
        if slot.value is None {
            continue;
        }
        if slot.name is None {
            rpc_props.append(slot.value);
            continue;
        }
        named_value = self._wrap_to_wire_if_boundary(
            cast(es.Expression, slot.value),
            inline_param_type_map.get(slot.name, ''),
            inline_boundary,
            nd
        );
        rpc_props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=slot.name), jac_node=nd),
                    value=named_value,
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=nd
            )
        );
    }
    args_obj: es.Expression = self.sync_loc(
        es.ObjectExpression(properties=rpc_props), jac_node=nd
    );
    if use_kwargs_temp and spread_arg is not None {
        args_obj = self._wrap_with_kwargs_temp(args_obj, spread_arg, nd);
    }

    result_expr: es.Expression = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacCallFunction'), jac_node=nd),
            arguments=[
                self.sync_loc(es.Literal(value=func_name), jac_node=nd),
                args_obj
            ]
        ),
        jac_node=nd
    );
    result_expr = self._wrap_return_with_boundary(
        result_expr, inline_ret_type, inline_boundary, nd, pre_awaited=False
    );
    self._inject_runtime_import('__jacCallFunction', nd);
    return result_expr;
}

impl EsastGenPass._warn_rpc_callable_params(
    ability_node: uni.Ability, func_name: str, at: uni.UniNode
) -> None {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return;
    }
    import re;
    import from jaclang.compiler.frontend.diagnostics { W6005 }
    _sig = ability_node.signature;
    for _plist in [_sig.posonly_params, _sig.params or [], _sig.kwonlyargs] {
        for _p in _plist {
            if (
                _p.type_tag is not None
                and _p.type_tag.tag is not None
                and re.search(r"\bCallable\b", unparse_node(_p.type_tag.tag))
            ) {
                self.emit(
                    W6005, node_override=at, func=func_name, param=_p.name.sym_name
                );
            }
        }
    }
}

impl EsastGenPass._forwarder_ret_label(ability_node: uni.Ability) -> str {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return '';
    }
    rt = ability_node.signature.return_type;
    if rt is None {
        return '';
    }
    label = unparse_node(rt).strip();
    return '' if label in ('', 'None') else label;
}

impl EsastGenPass._build_server_forwarder(
    ability_node: uni.Ability, func_name: str, jac_node: uni.UniNode
) -> es.FunctionDeclaration {
    self._warn_rpc_callable_params(ability_node, func_name, jac_node);
    boundary = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    param_types = self._param_type_map_from_ability(ability_node);
    ret_type = self._extract_return_type(
        ability_node, func_name, self.ir_in.gen.interop_manifest
    );
    params: list[es.Pattern] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for pname in self._param_names_from_ability(ability_node) {
        params.append(self.sync_loc(es.Identifier(name=pname), jac_node=jac_node));
        props.append(
            self.sync_loc(
                es.Property(
                    key=self.sync_loc(es.Literal(value=pname), jac_node=jac_node),
                    value=self._wrap_to_wire_if_boundary(
                        self.sync_loc(es.Identifier(name=pname), jac_node=jac_node),
                        param_types.get(pname, ''),
                        boundary,
                        jac_node
                    ),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=jac_node
            )
        );
    }
    call_expr: es.Expression = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.Identifier(name='__jacCallFunction'), jac_node=jac_node
            ),
            arguments=[
                self.sync_loc(es.Literal(value=func_name), jac_node=jac_node),
                self.sync_loc(es.ObjectExpression(properties=props), jac_node=jac_node)
            ]
        ),
        jac_node=jac_node
    );
    call_expr = self._wrap_return_with_boundary(
        call_expr, ret_type, boundary, jac_node, pre_awaited=False
    );
    self._inject_runtime_import('__jacCallFunction', jac_node);
    ret_label = self._forwarder_ret_label(ability_node);
    if ret_label {
        import from jaclang.compiler.frontend.diagnostics { W6009 }
        self.emit(W6009, node_override=jac_node, name=func_name, ret=ret_label);
    }
    return self.sync_loc(
        es.FunctionDeclaration(
            id=self.sync_loc(es.Identifier(name=func_name), jac_node=jac_node),
            params=params,
            body=self.sync_loc(
                es.BlockStatement(
                    body=[
                        self.sync_loc(
                            es.ReturnStatement(argument=call_expr), jac_node=jac_node
                        )
                    ]
                ),
                jac_node=jac_node
            ),
            async_=True
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._bind_client_value_refs(nd: uni.Module) -> list[es.Statement] {
    import from jaclang.compiler.symbol_utils {
        client_bridged_endpoint,
        client_value_ref_targets,
        element_display_name
    }
    forwarders: list[es.Statement] = [];
    bound: set[str] = set();
    for (ref_name, top) in client_value_ref_targets(nd, self.shared_arch_names) {
        if (isinstance(top, uni.Ability) and client_bridged_endpoint(nd, top)) {
            func_name = element_display_name(top);
            if func_name in bound {
                continue;
            }
            bound.add(func_name);
            forwarders.append(self._build_server_forwarder(top, func_name, ref_name));
            continue;
        }
        self._unbound_reported.add(ref_name.sym_name);
        self.emit(E5086, node_override=ref_name, name=ref_name.sym_name);
    }
    return forwarders;
}
impl EsastGenPass._spawn_walker_arch(expr: uni.Expr) -> (str | None) {
    kinds = self._osp_arch_kinds();
    head = self._ref_head_name(expr);
    if (head is not None) and (kinds.get(head) == "walker") {
        return head;
    }
    if isinstance(expr, uni.Name) {
        bound = self._osp_var_arch().get(expr.sym_name);
        if (bound is not None) and (kinds.get(bound) == "walker") {
            return bound;
        }
    }
    typed = self._osp_expr_arch_name(expr);
    if (typed is not None) and (self._arch_kind_by_name(typed) == "walker") {
        return typed;
    }
    return None;
}

impl EsastGenPass._spawn_target_is_local_node(expr: uni.Expr) -> bool {
    kinds = self._osp_arch_kinds();
    head = self._ref_head_name(expr);
    if (head is not None) and (kinds.get(head) in ("node", "edge")) {
        return True;
    }
    if isinstance(expr, uni.Name) {
        bound = self._osp_var_arch().get(expr.sym_name);
        if (bound is not None) and (kinds.get(bound) in ("node", "edge")) {
            return True;
        }
    }
    if self._osp_expr_arch_kind(expr) in ("node", "edge") {
        return True;
    }
    return False;
}

impl EsastGenPass._build_local_osp_spawn(
    nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
) -> (es.Expression | None) {
    walker_es: (es.Expression | None) = None;
    target_es: (es.Expression | None) = None;
    target_expr: (uni.Expr | None) = None;
    if self._spawn_walker_arch(nd.left) is not None {
        walker_es = left;
        target_es = right;
        target_expr = nd.right;
    } elif self._spawn_walker_arch(nd.right) is not None {
        walker_es = right;
        target_es = left;
        target_expr = nd.left;
    } else {
        return None;
    }

    if not self._spawn_target_is_local_node(target_expr) {
        return None;
    }
    self.needs_osp_kernel = True;
    self.needs_jac_runtime = True;
    tag_lookup = self.sync_loc(
        es.MemberExpression(
            object=self.sync_loc(es.Identifier(name="__ospDESC"), jac_node=nd),
            property=self.sync_loc(
                es.MemberExpression(
                    object=walker_es,
                    property=self.sync_loc(es.Identifier(name="__tag"), jac_node=nd),
                    computed=False
                ),
                jac_node=nd
            ),
            computed=True
        ),
        jac_node=nd
    );
    starts = self.sync_loc(es.ArrayExpression(elements=[target_es]), jac_node=nd);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name="__ospC.osp_spawn"), jac_node=nd),
            arguments=[
                self.sync_loc(es.Identifier(name="__ospRT"), jac_node=nd),
                walker_es,
                tag_lookup,
                starts
            ]
        ),
        jac_node=nd
    );
}
impl EsastGenPass._build_spawn_runtime_call(
    nd: uni.BinaryExpr, parts: SpawnCallParts
) -> es.AwaitExpression {
    self._inject_runtime_import('__jacSpawn', nd);
    walker_literal = self.sync_loc(
        es.Literal(value=parts.`walker.walker_name), jac_node=parts.`walker.call_node
    );
    spawn_call = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__jacSpawn'), jac_node=nd),
            arguments=[
                walker_literal,
                parts.target.expression,
                parts.`walker.fields_object
            ]
        ),
        jac_node=nd
    );
    return self.sync_loc(es.AwaitExpression(argument=spawn_call), jac_node=nd);
}

impl EsastGenPass._prepare_spawn_call(
    nd: uni.BinaryExpr, left_expr: es.Expression, right_expr: es.Expression
) -> (SpawnCallParts | None) {
    left_walker = self._resolve_spawn_walker(nd.left, left_expr);
    right_walker = self._resolve_spawn_walker(nd.right, right_expr);
    if (left_walker and right_walker) {
        self.emit(W5013, node_override=nd);
        target = self._resolve_spawn_target(nd.left, left_expr);
        return SpawnCallParts(`walker=right_walker, target=target);
    }
    if left_walker {
        target = self._resolve_spawn_target(nd.right, right_expr);
        return SpawnCallParts(`walker=left_walker, target=target);
    }
    if right_walker {
        target = self._resolve_spawn_target(nd.left, left_expr);
        return SpawnCallParts(`walker=right_walker, target=target);
    }
    self.emit(E5010, node_override=nd);
    return None;
}

impl EsastGenPass._resolve_spawn_target(
    expr: uni.Expr, es_expr: es.Expression
) -> SpawnTargetInfo {
    (stripped_node, stripped_es) = self._strip_spawn_await(expr, es_expr);
    if self._is_root_reference(stripped_node) {
        literal = self.sync_loc(es.Literal(value=''), jac_node=stripped_node);
        return SpawnTargetInfo(nd=stripped_node, expression=literal);
    }
    return SpawnTargetInfo(nd=stripped_node, expression=stripped_es);
}

impl EsastGenPass._is_root_reference(expr: uni.Expr) -> bool {
    if (isinstance(expr, uni.Name) and (expr.sym_name == 'root')) {
        return True;
    }
    return bool((isinstance(expr, uni.SpecialVarRef) and (expr.sym_name == 'root')));
}

impl EsastGenPass._resolve_spawn_walker(
    expr: uni.Expr, es_expr: es.Expression
) -> (SpawnWalkerInfo | None) {
    (stripped_node, _) = self._strip_spawn_await(expr, es_expr);
    if not isinstance(stripped_node, uni.FuncCall) {
        return None;
    }

    target_symbol = stripped_node.target.sym
        if isinstance(stripped_node.target, uni.AtomExpr)
        else None;

    if target_symbol and (target_symbol.sym_type == SymbolType.WALKER_ARCH) {
        walker_name = target_symbol.sym_name;
        fields_obj = self._build_spawn_arg_object(stripped_node, target_symbol);
        return SpawnWalkerInfo(
            call_node=stripped_node, walker_name=walker_name, fields_object=fields_obj
        );
    }

    if isinstance(stripped_node.target, uni.Name) {
        walker_name = stripped_node.target.sym_name;
        fields_obj = self._build_spawn_arg_object(stripped_node, None);
        return SpawnWalkerInfo(
            call_node=stripped_node, walker_name=walker_name, fields_object=fields_obj
        );
    }
    return None;
}

impl EsastGenPass._build_spawn_arg_object(
    call_node: uni.FuncCall, walker_symbol: (uni.Symbol | None)
) -> es.ObjectExpression {
    import from jaclang.compiler.symbol_utils {
        collect_field_names,
        symbol_owner_archetype
    }
    ordered_fields = collect_field_names(walker_symbol, Tok.KW_WALKER.value);

    field_type_map: dict[str, str] = {};
    if walker_symbol {
        arch = symbol_owner_archetype(walker_symbol);
        if arch {
            for field in arch.get_has_vars() {
                if field.type_tag and field.type_tag.tag {
                    if isinstance(field.type_tag.tag, uni.Name) {
                        field_type_map[field.sym_name] = field.type_tag.tag.value;
                    }
                }
            }
        }
    }
    boundary_types = self.ir_in.gen.interop_manifest.boundary_types
        if self.ir_in.gen.interop_manifest
        else {};
    properties: list[(es.Property | es.SpreadElement)] = [];
    positional_index = 0;
    for param in call_node.params {
        if isinstance(param, uni.KWPair) {
            if param.key {
                field_name = param.key.sym_name;
                key_expr = self.sync_loc(
                    es.Literal(value=field_name), jac_node=param.key
                );
                value_expr = self._expr_from_node(param.value);

                ftype = field_type_map.get(field_name, '');
                if ftype in boundary_types and boundary_types[ftype].kind != "enum" {
                    value_expr = self.sync_loc(
                        es.CallExpression(
                            callee=es.MemberExpression(
                                object=value_expr,
                                property=es.Identifier(name='__to_wire'),
                                computed=False
                            ),
                            arguments=[]
                        ),
                        jac_node=param
                    );
                }
                properties.append(
                    self.sync_loc(
                        es.Property(
                            key=key_expr,
                            value=value_expr,
                            kind='init',
                            method=False,
                            shorthand=False,
                            computed=False
                        ),
                        jac_node=param
                    )
                );
            } else {
                spread_arg = self._expr_from_node(param.value);
                properties.append(
                    self.sync_loc(es.SpreadElement(argument=spread_arg), jac_node=param)
                );
            }
            continue;
        }
        key_name = ordered_fields[positional_index]
            if (positional_index < len(ordered_fields))
            else f"arg{positional_index}";
        if (positional_index >= len(ordered_fields)) {
            self.emit(W5014, node_override=param);
        }
        positional_index += 1;
        key_expr = self.sync_loc(es.Literal(value=key_name), jac_node=param);
        value_expr = self._expr_from_node(param);

        ftype = field_type_map.get(key_name, '');
        if ftype in boundary_types and boundary_types[ftype].kind != "enum" {
            value_expr = self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=value_expr,
                        property=es.Identifier(name='__to_wire'),
                        computed=False
                    ),
                    arguments=[]
                ),
                jac_node=param
            );
        }
        properties.append(
            self.sync_loc(
                es.Property(
                    key=key_expr,
                    value=value_expr,
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                ),
                jac_node=param
            )
        );
    }
    return self.sync_loc(
        es.ObjectExpression(properties=properties), jac_node=call_node
    );
}
impl EsastGenPass._strip_spawn_await(
    node_expr: uni.Expr, es_expr: es.Expression
) -> tuple[uni.Expr, es.Expression] {
    cur_node = node_expr;
    cur_es = es_expr;
    while (isinstance(cur_node, uni.AwaitExpr) and cur_node.target) {
        cur_node = cur_node.target;
        if (isinstance(cur_es, es.AwaitExpression) and (cur_es.argument is not None)) {
            cur_es = cur_es.argument;
        } else {
            break;
        }
    }
    return (cur_node, cur_es);
}
