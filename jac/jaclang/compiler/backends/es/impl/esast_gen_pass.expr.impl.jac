impl EsastGenPass._resolve_call_ability(nd: uni.FuncCall) -> (uni.Ability | None) {
    import from jaclang.compiler.symbol_utils { ability_of_symbol }

    if nd.callee_decl is not None {
        return nd.callee_decl;
    }
    if isinstance(nd.target, uni.Name) {
        ability_node = ability_of_symbol(nd.target.sym);
        if ability_node {
            return ability_node;
        }

        manifest = self.ir_in.gen.interop_manifest;
        binding = manifest.bindings.get(nd.target.sym_name) if manifest else None;
        if binding and isinstance(binding.ast_node, uni.Ability) {
            return binding.ast_node;
        }
        return None;
    }
    if isinstance(nd.target, uni.AtomTrailer)
        and isinstance(nd.target.right, uni.Name) {
        return ability_of_symbol(nd.target.right.sym);
    }
    return None;
}

impl EsastGenPass._pos_params_from_ability(
    ability_node: uni.Ability
) -> list[uni.ParamVar] {
    sig = ability_node.signature;
    return (sig.posonly_params or []) + (sig.params or []);
}

impl EsastGenPass._param_names_from_ability(ability_node: uni.Ability) -> list[str] {
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return [];
    }
    sig = ability_node.signature;
    names: list[str] = [];
    for p in self._pos_params_from_ability(ability_node) {
        names.append(p.name.sym_name);
    }
    for p in sig.kwonlyargs {
        names.append(p.name.sym_name);
    }
    return names;
}

impl EsastGenPass._param_type_map_from_ability(
    ability_node: uni.Ability
) -> dict[(str, str)] {
    type_map: dict[(str, str)] = {};
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return type_map;
    }
    sig = ability_node.signature;
    param_lists = [sig.posonly_params, sig.params or [], sig.kwonlyargs];
    for params in param_lists {
        for p in params {
            if (
                p.type_tag and p.type_tag.tag and isinstance(p.type_tag.tag, uni.Name)
            ) {
                type_map[p.name.sym_name] = p.type_tag.tag.value;
            }
        }
    }
    return type_map;
}

impl EsastGenPass._extract_return_type(
    ability_node: uni.Ability, func_name: str, manifest: any
) -> str {
    if manifest {
        for b in manifest.server_exports_to_client {
            if b.name == func_name {
                return b.ret_type;
            }
        }
    }
    if not isinstance(ability_node.signature, uni.FuncSignature) {
        return '';
    }
    rt = ability_node.signature.return_type;
    if rt is None {
        return '';
    }
    if isinstance(rt, uni.Name) {
        return rt.value;
    }
    if isinstance(rt, uni.AtomTrailer) and isinstance(rt.target, uni.Name) {
        base = rt.target.value;
        if rt.right and isinstance(rt.right, uni.Name) {
            return f"{base}[{rt.right.value}]";
        }
        return base;
    }
    return '';
}

impl EsastGenPass._wrap_return_with_boundary(
    call_expr: es.Expression,
    ret_type: str,
    boundary_types: dict[(str, any)],
    jac_node: uni.UniNode,
    pre_awaited: bool
) -> es.Expression {
    awaited_call = call_expr
        if pre_awaited
        else self.sync_loc(es.AwaitExpression(argument=call_expr), jac_node=jac_node);

    if (ret_type in boundary_types and boundary_types[ret_type].kind != "enum") {
        return self.sync_loc(
            es.CallExpression(
                callee=es.MemberExpression(
                    object=es.Identifier(name=ret_type),
                    property=es.Identifier(name='__from_wire'),
                    computed=False
                ),
                arguments=[awaited_call]
            ),
            jac_node=jac_node
        );
    }

    if ret_type.startswith("list[") and ret_type.endswith("]") {
        inner = ret_type[5:-1];
        if inner in boundary_types and boundary_types[inner].kind != "enum" {
            return self.sync_loc(
                es.CallExpression(
                    callee=es.MemberExpression(
                        object=awaited_call,
                        property=es.Identifier(name='map'),
                        computed=False
                    ),
                    arguments=[
                        es.ArrowFunctionExpression(
                            params=[es.Identifier(name='x')],
                            body=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name=inner),
                                    property=es.Identifier(name='__from_wire'),
                                    computed=False
                                ),
                                arguments=[es.Identifier(name='x')]
                            ),
                            expression=True,
                            async_=False
                        )
                    ]
                ),
                jac_node=jac_node
            );
        }
    }

    if ret_type.startswith("dict[") and ret_type.endswith("]") {
        dict_params = ret_type[5:-1];
        comma_pos = dict_params.find(', ');
        if comma_pos >= 0 {
            val_type = dict_params[comma_pos + 2:].strip();
            if (
                val_type in boundary_types and boundary_types[val_type].kind != "enum"
            ) {
                entries_call = es.CallExpression(
                    callee=es.MemberExpression(
                        object=es.Identifier(name='Object'),
                        property=es.Identifier(name='entries'),
                        computed=False
                    ),
                    arguments=[awaited_call]
                );
                map_call = es.CallExpression(
                    callee=es.MemberExpression(
                        object=entries_call,
                        property=es.Identifier(name='map'),
                        computed=False
                    ),
                    arguments=[
                        es.ArrowFunctionExpression(
                            params=[
                                es.ArrayPattern(
                                    elements=[
                                        es.Identifier(name='k'),
                                        es.Identifier(name='v')
                                    ]
                                )
                            ],
                            body=es.ArrayExpression(
                                elements=[
                                    es.Identifier(name='k'),
                                    es.CallExpression(
                                        callee=es.MemberExpression(
                                            object=es.Identifier(name=val_type),
                                            property=es.Identifier(name='__from_wire'),
                                            computed=False
                                        ),
                                        arguments=[es.Identifier(name='v')]
                                    )
                                ]
                            ),
                            expression=True,
                            async_=False
                        )
                    ]
                );
                return self.sync_loc(
                    es.CallExpression(
                        callee=es.MemberExpression(
                            object=es.Identifier(name='Object'),
                            property=es.Identifier(name='fromEntries'),
                            computed=False
                        ),
                        arguments=[map_call]
                    ),
                    jac_node=jac_node
                );
            }
        }
    }

    return call_expr;
}

impl EsastGenPass._wrap_to_wire_if_boundary(
    expr: es.Expression,
    type_name: str,
    boundary_types: dict[(str, any)],
    jac_node: uni.UniNode
) -> es.Expression {
    if (type_name in boundary_types and boundary_types[type_name].kind != "enum") {
        return self.sync_loc(
            es.CallExpression(
                callee=es.MemberExpression(
                    object=expr,
                    property=es.Identifier(name='__to_wire'),
                    computed=False
                ),
                arguments=[]
            ),
            jac_node=jac_node
        );
    }
    return expr;
}

impl EsastGenPass._resolve_call_arg_slots(
    nd: uni.FuncCall,
    args: list[(es.Expression | es.SpreadElement)],
    props: list[(es.Property | es.SpreadElement)],
    param_names: list[str],
    func_name: str,
    spread_read_source: (es.Expression | None)
) -> list[CallArgSlot] {
    by_name: dict[str, (es.Expression | es.SpreadElement)] = {};
    extras: list[CallArgSlot] = [];
    spread_sources: list[es.Expression] = [];
    seen_names: set[str] = set();
    for (i, arg) in enumerate(args) {
        if isinstance(arg, es.SpreadElement) {
            extras.append(CallArgSlot(name=None, value=arg));
            continue;
        }
        if i < len(param_names) {
            pname = param_names[i];
            seen_names.add(pname);
            by_name[pname] = arg;
        } else {
            extras.append(CallArgSlot(name=None, value=arg));
        }
    }
    for kw in props {
        if isinstance(kw, es.SpreadElement) {
            spread_sources.append(kw.argument);
            continue;
        }
        kw_key = kw.key;
        kw_name = '';
        if isinstance(kw_key, es.Identifier) {
            kw_name = kw_key.name;
        } elif isinstance(kw_key, es.Literal) {
            kw_name = str(kw_key.value);
        }
        if not kw_name {
            self.emit(
                E5099, node_override=nd, func=func_name, shape=type(kw_key).__name__
            );
            continue;
        }
        if kw_name in seen_names {
            self.emit(E5080, node_override=nd, name=kw_name, func=func_name);
        }
        seen_names.add(kw_name);
        by_name[kw_name] = kw.value;
    }
    resolved: list[CallArgSlot] = [];
    for pname in param_names {
        if pname in by_name {
            resolved.append(CallArgSlot(name=pname, value=by_name[pname]));
        } elif spread_sources {
            spread_source = spread_read_source;
            if spread_source is None {
                spread_source = spread_sources[0]
                    if len(spread_sources) == 1
                    else self.sync_loc(
                        es.ObjectExpression(
                            properties=[
                                self.sync_loc(
                                    es.SpreadElement(argument=src), jac_node=nd
                                ) for src in spread_sources
                            ]
                        ),
                        jac_node=nd
                    );
            }
            resolved.append(
                CallArgSlot(
                    name=pname,
                    value=self.sync_loc(
                        es.MemberExpression(
                            object=spread_source,
                            property=self.sync_loc(
                                es.Literal(value=pname), jac_node=nd
                            ),
                            computed=True
                        ),
                        jac_node=nd
                    )
                )
            );
        } else {
            resolved.append(CallArgSlot(name=pname, value=None));
        }
    }
    resolved.extend(extras);
    return resolved;
}

impl EsastGenPass._call_args_from_slots(
    slots: list[CallArgSlot]
) -> (list[(es.Expression | es.SpreadElement)] | None) {
    call_args: list[(es.Expression | es.SpreadElement)] = [];
    last_value_idx = -1;
    for (i, slot) in enumerate(slots) {
        if slot.value is not None {
            last_value_idx = i;
        }
    }
    if last_value_idx < 0 {
        return [];
    }
    for (i, slot) in enumerate(slots) {
        if i > last_value_idx {
            break;
        }
        if slot.value is None {
            call_args.append(es.Identifier(name='undefined'));
            continue;
        }
        if slot.name is None {
            call_args.append(slot.value);
            continue;
        }
        call_args.append(slot.value);
    }
    return call_args;
}

impl EsastGenPass._kwargs_spread_arg(
    props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
) -> (es.Expression | None) {
    sources: list[es.Expression] = [];
    for prop in props {
        if isinstance(prop, es.SpreadElement) {
            sources.append(prop.argument);
        }
    }
    if not sources {
        return None;
    }
    if len(sources) == 1 {
        return sources[0];
    }
    return self.sync_loc(
        es.ObjectExpression(
            properties=[
                self.sync_loc(es.SpreadElement(argument=src), jac_node=nd)
                for src in sources
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._kwargs_spread_needs_temp(
    props: list[(es.Property | es.SpreadElement)]
) -> bool {
    sources: list[es.Expression] = [];
    for prop in props {
        if isinstance(prop, es.SpreadElement) {
            sources.append(prop.argument);
        }
    }
    if len(sources) > 1 {
        return True;
    }
    if len(sources) == 1 and not isinstance(sources[0], es.Identifier) {
        return True;
    }
    return False;
}

impl EsastGenPass._make_kwargs_spread_context(
    props: list[(es.Property | es.SpreadElement)], nd: uni.FuncCall
) -> tuple[((es.Expression | None), (es.Expression | None))] {
    spread_arg = self._kwargs_spread_arg(props, nd);
    if spread_arg is None {
        return (None, None);
    }
    if self._kwargs_spread_needs_temp(props) {
        return (
            spread_arg,
            self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd)
        );
    }
    return (spread_arg, None);
}

impl EsastGenPass._wrap_with_kwargs_temp(
    expr: es.Expression, spread_arg: es.Expression, nd: uni.FuncCall
) -> es.Expression {
    temp_id = self.sync_loc(es.Identifier(name='__jac_kwargs'), jac_node=nd);
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[temp_id], body=expr, expression=True, async_=False
                ),
                jac_node=nd
            ),
            arguments=[spread_arg]
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_func_call(nd: uni.FuncCall) -> None {
    args: list[(es.Expression | es.SpreadElement)] = [];
    props: list[(es.Property | es.SpreadElement)] = [];
    for param in nd.params {
        if isinstance(param, uni.KWPair) {
            value_expr = cast(
                es.Expression,
                param.value.gen.es_ast
                    if (param.value and param.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=param)
            );

            if not param.key {
                props.append(
                    self.sync_loc(es.SpreadElement(argument=value_expr), jac_node=param)
                );
                continue;
            }
            key_expr = cast(
                es.Expression,
                self.sync_loc(
                    es.Identifier(name=param.key.sym_name), jac_node=param.key
                )
            );
            props.append(
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
            continue;
        }
        if (isinstance(param, uni.UnaryExpr) and param.op.name == Tok.STAR_MUL.value) {
            spread_arg = cast(
                es.Expression,
                param.operand.gen.es_ast
                    if (param.operand and param.operand.gen.es_ast)
                    else self.sync_loc(es.Identifier(name='undefined'), jac_node=param)
            );
            args.append(
                self.sync_loc(es.SpreadElement(argument=spread_arg), jac_node=param)
            );
            continue;
        }
        if param.gen.es_ast {
            args.append(cast(es.Expression, param.gen.es_ast));
        }
    }

    server_call = self._try_lower_server_rpc_call(nd, args, props);
    if server_call is not None {
        nd.gen.es_ast = server_call;
        return;
    }
    callee = nd.target.gen.es_ast
        or self.sync_loc(es.Identifier(name='func'), jac_node=nd.target);

    if (
        isinstance(callee, es.MemberExpression)
        and isinstance(callee.property, es.Identifier)
        and isinstance(nd.target, uni.AtomTrailer)
    ) {
        import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }

        _obj_type = nd.target.target?.type;
        _type_name = self._resolve_primitive_type_name(_obj_type);
        _method_name = callee.property.name;
        if _type_name {
            _emitter = self._primitive_emitters.get(_type_name);
            _emit_fn_name = "emit_" + _method_name;
            _emit_fn = getattr(_emitter, _emit_fn_name, None) if _emitter else None;
            if _emit_fn {
                _unparser = JSCodeGenerator();
                _ctx = self._primitives_es_mod.ESEmitCtx(unparser=_unparser);
                _target_str = _unparser.generate(callee.object);
                _args_strs: list[str] = [];
                for _a in args {
                    _args_strs.append(_unparser.generate(_a));
                }

                for _p in props {
                    if isinstance(_p, es.Property) and _p.value {
                        _args_strs.append(_unparser.generate(_p.value));
                    }
                }

                import inspect;
                _n_params = len(inspect.signature(_emit_fn).parameters);
                if _n_params == 2 {
                    _result = _emit_fn(_ctx, _args_strs);
                } else {
                    _result = _emit_fn(_ctx, _target_str, _args_strs);
                }
                if _result is not None and "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                nd.gen.es_ast = self.sync_loc(es.Identifier(name=_result), jac_node=nd);
                return;
            }
        }

        if self._poly_methods is not None and (_method_name in self._poly_methods) {
            _poly_args: list[(es.Expression | es.SpreadElement)] = [
                cast(es.Expression, callee.object),
                self.sync_loc(es.Literal(value=_method_name), jac_node=nd)
            ];
            for _a in args {
                _poly_args.append(_a);
            }

            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _poly_args.append(cast(es.Expression, _p.value));
                }
            }
            _poly_callee = es.MemberExpression(
                object=es.MemberExpression(
                    object=es.Identifier(name='_jac'),
                    property=es.Identifier(name='poly'),
                    computed=False
                ),
                property=es.Identifier(name='call'),
                computed=False
            );
            self.needs_jac_runtime = True;
            nd.gen.es_ast = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, _poly_callee), arguments=_poly_args
                ),
                jac_node=nd
            );
            return;
        }
    }

    self._ensure_emitters();

    _call_kind = nd.call_kind;
    if _call_kind == "builtin" and isinstance(nd.target, uni.Name) {
        import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }
        _builtin_name = nd.target.sym_name;
        _emit_fn_name = "emit_" + _builtin_name;
        _emit_fn = getattr(self._builtin_emitter, _emit_fn_name, None);
        if _emit_fn {
            _unparser = JSCodeGenerator();
            _arg_type_names: list[str] = [
                self._expr_type_name(_p)
                for _p in nd.params
                if not isinstance(_p, uni.KWPair)
            ];
            _ctx = self._primitives_es_mod.ESEmitCtx(
                unparser=_unparser, arg_type_names=_arg_type_names
            );
            _args_strs: list[str] = [];
            for _a in args {
                _args_strs.append(_unparser.generate(_a));
            }

            for _p in props {
                if isinstance(_p, es.Property) and _p.value {
                    _args_strs.append(_unparser.generate(_p.value));
                }
            }

            _result = None;
            try {
                _result = _emit_fn(_ctx, _args_strs);
            } except Exception as _emit_err {
                self.emit(
                    E5016, node_override=nd, name=_builtin_name, error=str(_emit_err)
                );
                return;
            }

            if _result is not None {
                if "_jac." in str(_result) {
                    self.needs_jac_runtime = True;
                }
                nd.gen.es_ast = self.sync_loc(es.Identifier(name=_result), jac_node=nd);
                return;
            }
        }
    }

    if isinstance(nd.target, uni.BuiltinType)
        and isinstance(callee, es.MemberExpression) {
        self.needs_jac_runtime = True;
    }

    args_obj = self.sync_loc(es.ObjectExpression(properties=props), jac_node=nd);
    callee_expr = cast(es.Expression, callee);
    call_args: list[(es.Expression | es.SpreadElement)] = args;
    (spread_arg, spread_read_source) = self._make_kwargs_spread_context(props, nd);
    use_kwargs_temp = spread_read_source is not None;
    ability_node_resolved = self._resolve_call_ability(nd);
    if props {
        if ability_node_resolved {
            ordered_args = self._call_args_from_slots(
                self._resolve_call_arg_slots(
                    nd,
                    args,
                    props,
                    self._param_names_from_ability(ability_node_resolved),
                    nd.target.sym_name if isinstance(nd.target, uni.Name) else "func",
                    spread_read_source
                )
            );
            call_args = ordered_args if ordered_args is not None else [args_obj];
        } else {
            call_args = [args_obj];
        }
    }

    if ability_node_resolved {
        lowered = self._try_lower_component_props_destructure_call(
            nd,
            ability_node_resolved,
            callee_expr,
            args,
            props,
            call_args,
            spread_arg,
            use_kwargs_temp
        );
        if lowered is not None {
            nd.gen.es_ast = lowered;
            return;
        }
    }

    _emit_new = _call_kind == "instantiation";
    if not _emit_new {
        _target_type = nd.target?.type;
        if (
            _target_type is not None
            and _target_type.is_instantiable_class()
            and not _target_type.shared.is_builtin_class
        ) {
            _emit_new = True;
        }
    }
    if _emit_new and isinstance(callee, es.Expression) {
        result_expr: es.Expression = self.sync_loc(
            es.NewExpression(callee=callee_expr, arguments=call_args), jac_node=nd
        );
    } else {
        if isinstance(nd.target, uni.Name) {
            import from jaclang.client.client_surface {
                runtime_import_source,
                runtime_symbol
            }
            _rt_name = nd.target.sym_name;
            if (
                runtime_symbol(_rt_name)
                and runtime_import_source(_rt_name, self.backend) == "@jac/runtime"
            ) {
                self._inject_runtime_import(_rt_name, nd);
            }
        }
        result_expr = self.sync_loc(
            es.CallExpression(callee=callee_expr, arguments=call_args), jac_node=nd
        );
    }
    if use_kwargs_temp and spread_arg is not None {
        result_expr = self._wrap_with_kwargs_temp(result_expr, spread_arg, nd);
    }
    nd.gen.es_ast = result_expr;
}
impl EsastGenPass.exit_assignment(nd: uni.Assignment) -> None {
    if not nd.target {
        nd.gen.es_ast = None;
        return;
    }
    value_expr = nd.value.gen.es_ast if (nd.value and nd.value.gen.es_ast) else None;

    if (
        len(nd.target) == 1
        and isinstance(nd.target[0], uni.Name)
        and nd.target[0].sym_name == '_'
        and not nd.aug_op
        and '_' not in self.reactive_vars
    ) {
        discard_value = cast(
            es.Expression, value_expr or es.Identifier(name='undefined')
        );
        void_expr = self.sync_loc(
            es.UnaryExpression(operator='void', prefix=True, argument=discard_value),
            jac_node=nd
        );
        nd.gen.es_ast = self.sync_loc(
            es.ExpressionStatement(expression=void_expr), jac_node=nd
        );
        return;
    }

    if len(nd.target) == 1 and isinstance(nd.target[0], uni.Name) {
        target_name = nd.target[0].sym_name;
        if target_name in self.reactive_vars {
            setter_arg: es.Expression;
            aug_op: (str | None) = None;
            if nd.aug_op {
                aug_tok = Tok(nd.aug_op.name)
                    if (nd.aug_op.name in Tok.__members__)
                    else None;
                aug_to_binary: dict[Tok, str] = {
                    Tok.ADD_EQ: '+',
                    Tok.SUB_EQ: '-',
                    Tok.MUL_EQ: '*',
                    Tok.DIV_EQ: '/',
                    Tok.MOD_EQ: '%'
                };
                binary_op = aug_to_binary.get(aug_tok, '+') if aug_tok else '+';
                aug_op = binary_op;

                setter_arg = cast(es.Expression, value_expr or es.Literal(value=0));
            } else {
                setter_arg = cast(
                    es.Expression, value_expr or es.Identifier(name='undefined')
                );
            }
            state_update = StateUpdate(
                name=target_name, value=setter_arg, aug_op=aug_op
            );
            self._ensure_backend();
            setter_call = self.sync_loc(
                self.backend.lower_state_update(state_update), jac_node=nd
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=setter_call), jac_node=nd
            );
            nd.gen.es_ast = expr_stmt;
            return;
        }
    }
    if nd.aug_op {
        (left, _, _) = self._convert_assignment_target(nd.target[0]);
        aug_tok = Tok(nd.aug_op.name) if (nd.aug_op.name in Tok.__members__) else None;
        right = cast(
            es.Expression,
            (
                value_expr
                or self._get_ast_or_default(
                    nd.value,
                    default_factory=lambda (_src: any) { es.Identifier(
                        name='undefined'
                    ); }
                )
            )
        );

        _aug_emit_name = AUG_EMIT_MAP.get(aug_tok) if aug_tok else None;
        if _aug_emit_name {
            _prim_result = self._try_primitive_op(
                nd.target[0], _aug_emit_name, cast(es.Expression, left), right, nd
            );
            if _prim_result is not None {
                expr_stmt = self.sync_loc(
                    es.ExpressionStatement(expression=_prim_result), jac_node=nd
                );
                nd.gen.es_ast = expr_stmt;
                return;
            }
        }
        operator = ES_AUG_ASSIGN_OPS.get(aug_tok) if aug_tok else None;
        operator = operator or '=';
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator=operator, left=left, right=right),
            jac_node=nd
        );
        expr_stmt = self.sync_loc(
            es.ExpressionStatement(expression=assign_expr), jac_node=nd
        );
        nd.gen.es_ast = expr_stmt;
        return;
    }

    if len(nd.target) == 1 {
        _setitem = self._try_subscript_setitem(nd.target[0], value_expr, nd);
        if _setitem is not None {
            nd.gen.es_ast = _setitem;
            return;
        }
    }
    targets_info: list[AssignmentTargetInfo] = [];
    for target_node in nd.target {
        (left, reference, decl_name) = self._convert_assignment_target(target_node);
        pattern_names = self._collect_pattern_names(target_node);
        targets_info.append(
            AssignmentTargetInfo(
                nd=target_node,
                left=left,
                reference=reference,
                decl_name=decl_name,
                pattern_names=pattern_names
            )
        );
    }
    statements: list[es.Statement] = [];
    current_value: es.Expression = cast(
        es.Expression,
        (
            value_expr
            or self._get_ast_or_default(
                nd.value,
                default_factory=lambda (_src: any) { es.Identifier(name='undefined'); }
            )
        )
    );
    for info in reversed(targets_info) {
        target_node = info.nd;
        left = info.left;
        decl_name = info.decl_name;
        pattern_names = info.pattern_names;
        should_declare = False;
        cur_scope = self._current_scope();

        if decl_name {
            owning = self._declaring_scope_for(target_node);
            if owning is None {
                should_declare = not self._is_declared_in_any_scope(decl_name);
            } elif owning is cur_scope {
                should_declare = decl_name not in owning.declared;
            } elif decl_name not in owning.declared {
                self._hoist_into(owning, decl_name, target_node);
            }
        } elif pattern_names {
            inline_ok = True;
            for (name, name_node) in pattern_names {
                p_owning = self._declaring_scope_for(name_node);
                if p_owning is None {
                    if self._is_declared_in_any_scope(name) {
                        inline_ok = False;
                    }
                } elif (p_owning is not cur_scope) or (name in p_owning.declared) {
                    inline_ok = False;
                }
            }
            should_declare = inline_ok;
            if not inline_ok {
                for (name, name_node) in pattern_names {
                    p_owning = self._declaring_scope_for(name_node) or cur_scope;
                    if (
                        p_owning
                        and (name not in p_owning.declared)
                        and not self._is_declared_in_any_scope(name)
                    ) {
                        self._hoist_into(p_owning, name, name_node);
                    }
                }
            }
        }
        if should_declare {
            declarator = self.sync_loc(
                es.VariableDeclarator(
                    id=cast(es.Pattern, left),
                    `init=current_value if (value_expr is not None) else None
                ),
                jac_node=target_node
            );
            decl_stmt = self.sync_loc(
                es.VariableDeclaration(declarations=[declarator], kind='let'),
                jac_node=target_node
            );
            statements.append(decl_stmt);
            if decl_name {
                self._register_declaration(decl_name);
            } else {
                for (name, _) in pattern_names {
                    self._register_declaration(name);
                }
            }
        } else {
            assign_expr = self.sync_loc(
                es.AssignmentExpression(operator='=', left=left, right=current_value),
                jac_node=target_node
            );
            expr_stmt = self.sync_loc(
                es.ExpressionStatement(expression=assign_expr), jac_node=target_node
            );
            statements.append(expr_stmt);
        }
        if isinstance(left, es.Identifier) {
            current_value = self.sync_loc(
                es.Identifier(name=left.name), jac_node=target_node
            );
        } elif isinstance(info.reference, es.Identifier) {
            ref_ident = info.reference;
            current_value = self.sync_loc(
                es.Identifier(name=ref_ident.name), jac_node=target_node
            );
        } else {
            current_value = info.reference or current_value;
        }
    }
    if (len(statements) == 1) {
        nd.gen.es_ast = statements[0];
    } else {
        nd.gen.es_ast = statements;
    }
}

impl EsastGenPass._collect_pattern_names(
    target: uni.UniNode
) -> list[tuple[(str, uni.Name)]] {
    names: list[tuple[(str, uni.Name)]] = [];
    if isinstance(target, uni.Name) {
        names.append((target.sym_name, target));
    } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
        for value in target.values {
            names.extend(self._collect_pattern_names(value));
        }
    } elif isinstance(target, uni.DictVal) {
        for kv in target.kv_pairs {
            if isinstance(kv, uni.KVPair) {
                names.extend(self._collect_pattern_names(kv.value));
            }
        }
    } elif isinstance(target, uni.SubTag) {
        names.extend(self._collect_pattern_names(target.tag));
    }
    return names;
}

impl EsastGenPass._convert_assignment_target(
    target: uni.UniNode
) -> tuple[(es.Pattern | es.Expression), (es.Expression | None), (str | None)] {
    if isinstance(target, uni.Name) {
        identifier = self.sync_loc(
            es.Identifier(name=target.sym_name), jac_node=target
        );
        return (identifier, identifier, target.sym_name);
    }
    if isinstance(target, (uni.TupleVal, uni.ListVal)) {
        elements: list[(es.Pattern | None)] = [];
        for value in target.values {
            if (value is None) {
                elements.append(None);
                continue;
            }
            (pattern, _, _) = self._convert_assignment_target(value);
            elements.append(cast(es.Pattern, pattern));
        }
        pattern = self.sync_loc(es.ArrayPattern(elements=elements), jac_node=target);
        return (pattern, None, None);
    }
    if isinstance(target, uni.DictVal) {
        properties: list[(es.AssignmentProperty | es.RestElement)] = [];
        for kv in target.kv_pairs {
            if (not isinstance(kv, uni.KVPair) or (kv.key is None)) {
                continue;
            }
            key_expr = cast(
                es.Expression,
                kv.key.gen.es_ast
                    or self.sync_loc(es.Identifier(name='key'), jac_node=kv.key)
            );
            (value_pattern, _, _) = self._convert_assignment_target(kv.value);
            assignment = self.sync_loc(
                es.AssignmentProperty(
                    key=key_expr, value=cast(es.Pattern, value_pattern), shorthand=False
                ),
                jac_node=kv
            );
            properties.append(assignment);
        }
        pattern = self.sync_loc(
            es.ObjectPattern(properties=properties), jac_node=target
        );
        return (pattern, None, None);
    }
    if isinstance(target, uni.SubTag) {
        return self._convert_assignment_target(target.tag);
    }

    if (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.IndexSlice)
        and (not target.right.is_range)
    ) {
        _si = target.right.gen.es_ast;
        if isinstance(_si, es.IndexInfo) {
            _obj = cast(
                es.Expression,
                target.target.gen.es_ast
                    or self.sync_loc(es.Identifier(name='obj'), jac_node=target)
            );
            _idx = cast(
                es.Expression,
                _si.value or self.sync_loc(es.Literal(value=0), jac_node=target)
            );
            _member = self.sync_loc(
                es.MemberExpression(object=_obj, property=_idx, computed=True),
                jac_node=target
            );
            return (_member, _member, None);
        }
    }
    left = cast(
        (es.Pattern | es.Expression),
        target.gen.es_ast or self.sync_loc(es.Identifier(name='temp'), jac_node=target)
    );
    reference = cast(es.Expression, left) if isinstance(left, es.Node) else None;
    return (left, reference, None);
}
impl EsastGenPass._resolve_primitive_type_name(_obj_type: object) -> str {
    import from jaclang.compiler.type_system.type_utils { primitive_type_name_of }
    self._ensure_emitters();
    return primitive_type_name_of(_obj_type) or "";
}

impl EsastGenPass._try_primitive_op(
    expr_node: uni.UniNode,
    emit_method: str,
    left_es: es.Expression,
    right_es: (es.Expression | None),
    jac_node: uni.UniNode
) -> (es.Expression | None) {
    import from jaclang.compiler.backends.es.es_unparse { JSCodeGenerator }

    import from jaclang.compiler.type_system.type_utils { expr_primitive_name }
    _type_name = expr_primitive_name(self.prog, expr_node);
    if not _type_name {
        return None;
    }
    self._ensure_emitters();
    _emitter = self._primitive_emitters.get(_type_name);
    _emit_fn = getattr(_emitter, emit_method, None) if _emitter else None;
    if not _emit_fn {
        return None;
    }
    _unparser = JSCodeGenerator();
    _ctx = self._primitives_es_mod.ESEmitCtx(unparser=_unparser);

    _target_str = self._operand_str(_unparser, left_es);
    _args_strs: list[str] = [];
    if right_es is not None {
        _args_strs.append(self._operand_str(_unparser, right_es));
    }
    _result = _emit_fn(_ctx, _target_str, _args_strs);
    if _result is None {
        return None;
    }
    if "_jac." in str(_result) {
        self.needs_jac_runtime = True;
    }
    return self.sync_loc(es.Identifier(name=_result), jac_node=jac_node);
}
impl EsastGenPass._try_subscript_setitem(
    target: uni.UniNode, value_es: (es.Expression | None), jac_node: uni.UniNode
) -> (es.Statement | None) {
    if (
        not isinstance(target, uni.AtomTrailer)
        or not isinstance(target.right, uni.IndexSlice)
        or target.right.is_range
    ) {
        return None;
    }
    _si = target.right.gen.es_ast;
    if not isinstance(_si, es.IndexInfo) {
        return None;
    }
    _idx = cast(
        es.Expression,
        _si.value or self.sync_loc(es.Literal(value=0), jac_node=jac_node)
    );

    if self._is_literal_index(_idx) {
        return None;
    }

    if self._expr_type_name(target.target) != "list" {
        return None;
    }
    _obj = cast(
        es.Expression,
        target.target.gen.es_ast
            or self.sync_loc(es.Identifier(name='obj'), jac_node=jac_node)
    );
    _val = cast(
        es.Expression,
        value_es or self.sync_loc(es.Identifier(name='undefined'), jac_node=jac_node)
    );
    _call = self._build_jac_call(
        ["_jac", "poly", "setitem"], [_obj, _idx, _val], jac_node
    );
    return self.sync_loc(es.ExpressionStatement(expression=_call), jac_node=jac_node);
}
impl EsastGenPass.exit_unary_expr(nd: uni.UnaryExpr) -> None {
    operand = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.operand, default_factory=lambda (_src: any) { es.Literal(value=0); }
        )
    );
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;

    _unary_emit_name = UNARY_EMIT_MAP.get(op_tok) if op_tok else None;
    if _unary_emit_name {
        _prim_result = self._try_primitive_op(
            nd.operand, _unary_emit_name, operand, None, nd
        );
        if _prim_result is not None {
            nd.gen.es_ast = _prim_result;
            return;
        }
    }
    operator = ES_UNARY_OPS.get(op_tok) if op_tok else None;
    operator = operator or '!';

    if (op_tok == Tok.NOT) {
        operand = self._coerce_truthy(nd.operand, operand, nd);
    }
    unary_expr = self.sync_loc(
        es.UnaryExpression(operator=operator, prefix=True, argument=operand),
        jac_node=nd
    );
    nd.gen.es_ast = unary_expr;
}

impl EsastGenPass.exit_compare_expr(nd: uni.CompareExpr) -> None {
    if (not nd.rights or not nd.ops) {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=True), jac_node=nd);
        return;
    }
    comparisons: list[es.Expression] = [];
    left: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.left,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Identifier(name='left'); }
        )
    );
    left_uni: uni.UniNode = nd.left;
    for (op_token, right_node) in zip(nd.ops, nd.rights, strict=False) {
        right: es.Expression = cast(
            es.Expression,
            self._get_ast_or_default(
                right_node,
                default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                    if isinstance(src, uni.Name)
                    else es.Identifier(name='right'); }
            )
        );
        op_tok = Tok(op_token.name) if (op_token.name in Tok.__members__) else None;

        if (
            op_tok in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE)
            and (self._is_null_literal(left_uni) or self._is_null_literal(right_node))
        ) {
            loose_op = '==' if (op_tok in (Tok.KW_IS, Tok.EE)) else '!=';
            comparisons.append(
                self.sync_loc(
                    es.BinaryExpression(operator=loose_op, left=left, right=right),
                    jac_node=nd
                )
            );
            left = right;
            left_uni = right_node;
            continue;
        }

        _cmp_emit_name = CMP_EMIT_MAP.get(op_tok) if op_tok else None;
        if _cmp_emit_name {
            if op_tok in (Tok.KW_IN, Tok.KW_NIN) {
                _prim_result = self._try_primitive_op(
                    right_node, _cmp_emit_name, right, left, nd
                );
            } else {
                _prim_result = self._try_primitive_op(
                    nd.left, _cmp_emit_name, left, right, nd
                );
            }
            if _prim_result is not None {
                if op_tok == Tok.KW_NIN {
                    comparison = self.sync_loc(
                        es.UnaryExpression(
                            operator='!', prefix=True, argument=_prim_result
                        ),
                        jac_node=nd
                    );
                } else {
                    comparison = _prim_result;
                }
                comparisons.append(comparison);
                left = right;
                left_uni = right_node;
                continue;
            }
        }
        comparison: es.Expression;
        if (op_tok in (Tok.KW_IN, Tok.KW_NIN)) {
            contains_callee = self.sync_loc(
                es.MemberExpression(
                    object=self.sync_loc(
                        es.MemberExpression(
                            object=self.sync_loc(
                                es.Identifier(name='_jac'), jac_node=nd
                            ),
                            property=self.sync_loc(
                                es.Identifier(name='poly'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    property=self.sync_loc(es.Identifier(name='contains'), jac_node=nd),
                    computed=False
                ),
                jac_node=nd
            );
            self.needs_jac_runtime = True;
            contains_call = self.sync_loc(
                es.CallExpression(
                    callee=cast(es.Expression, contains_callee),
                    arguments=[cast(es.Expression, right), cast(es.Expression, left)]
                ),
                jac_node=nd
            );
            if (op_tok == Tok.KW_NIN) {
                comparison = self.sync_loc(
                    es.UnaryExpression(
                        operator='!',
                        prefix=True,
                        argument=cast(es.Expression, contains_call)
                    ),
                    jac_node=nd
                );
            } else {
                comparison = cast(es.Expression, contains_call);
            }
        } else {
            operator = ES_COMPARISON_OPS.get(op_tok) if op_tok else None;
            operator = operator or '===';
            comparison = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=nd
            );
        }
        comparisons.append(comparison);
        left = right;
        left_uni = right_node;
    }
    if (len(comparisons) == 1) {
        nd.gen.es_ast = comparisons[0];
    } else {
        result = comparisons[0];
        for comp in comparisons[1:] {
            result = self.sync_loc(
                es.LogicalExpression(operator='&&', left=result, right=comp),
                jac_node=nd
            );
        }
        nd.gen.es_ast = result;
    }
}
impl EsastGenPass.exit_cfg_expr(nd: uni.CfgExpr) -> None {
    nd.gen.es_ast = nd.expr.gen.es_ast;
}

impl EsastGenPass.exit_bool_expr(nd: uni.BoolExpr) -> None {
    if (not nd.values or (len(nd.values) < 2)) {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=nd);
        return;
    }
    op_tok = Tok(nd.op.name) if (nd.op.name in Tok.__members__) else None;
    logical_op = ES_LOGICAL_OPS.get(op_tok) if op_tok else None;
    logical_op = logical_op or '&&';

    _helper = "and_" if (op_tok == Tok.KW_AND) else "or_";
    result: es.Expression = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.values[0], default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );

    left_maybe_collection = self._is_collection_expr(nd.values[0]);
    for val in nd.values[1:] {
        right = cast(
            es.Expression,
            self._get_ast_or_default(
                val, default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );
        if left_maybe_collection {
            right_thunk = self.sync_loc(
                es.ArrowFunctionExpression(params=[], body=right, expression=True),
                jac_node=nd
            );
            result = self._build_jac_call(
                ["_jac", "poly", _helper],
                [result, cast(es.Expression, right_thunk)],
                nd
            );
        } else {
            result = self.sync_loc(
                es.LogicalExpression(operator=logical_op, left=result, right=right),
                jac_node=nd
            );
        }
        left_maybe_collection = left_maybe_collection or self._is_collection_expr(val);
    }
    nd.gen.es_ast = result;
}

impl EsastGenPass.exit_binary_expr(nd: uni.BinaryExpr) -> None {
    left = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.left,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0); }
        )
    );
    right = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.right,
            default_factory=lambda (src: any) { es.Identifier(name=src.sym_name)
                if isinstance(src, uni.Name)
                else es.Literal(value=0); }
        )
    );

    connect_call = self._build_osp_graph_call(nd, left, right);
    if connect_call is not None {
        nd.gen.es_ast = connect_call;
        return;
    }
    if isinstance(nd.op, uni.DisconnectOp) {
        nd.gen.es_ast = self._build_osp_disconnect_call(nd, left, right);
        return;
    }
    op_name_str = nd.op?.name;
    op_name = Tok(op_name_str) if (op_name_str in Tok.__members__) else None;
    if (op_name == Tok.KW_SPAWN) {
        local_spawn = self._build_local_osp_spawn(nd, left, right);
        if local_spawn is not None {
            nd.gen.es_ast = local_spawn;
            return;
        }
        spawn_parts = self._prepare_spawn_call(nd, left, right);
        if spawn_parts {
            nd.gen.es_ast = self._build_spawn_runtime_call(nd, spawn_parts);
        }
        return;
    }
    if ((op_name == Tok.WALRUS_EQ) and isinstance(left, es.Identifier)) {
        self._ensure_identifier_declared(left.name, nd.left);
        assign_expr = self.sync_loc(
            es.AssignmentExpression(operator='=', left=left, right=right), jac_node=nd
        );
        nd.gen.es_ast = assign_expr;
        return;
    }

    if op_name {
        _op_emit_name = OP_EMIT_MAP.get(op_name);
        if _op_emit_name {
            _prim_result = self._try_primitive_op(
                nd.left, _op_emit_name, left, right, nd
            );
            if _prim_result is not None {
                nd.gen.es_ast = _prim_result;
                return;
            }
        }
    }
    logical_op = ES_LOGICAL_OPS.get(op_name) if op_name else None;
    bin_expr: (es.LogicalExpression | es.BinaryExpression);
    if logical_op {
        bin_expr = self.sync_loc(
            es.LogicalExpression(operator=logical_op, left=left, right=right),
            jac_node=nd
        );
    } else {
        operator = ES_BINARY_OPS.get(op_name) if op_name else '+';
        operator = operator or '+';
        if operator == '+'
            and (
                isinstance(left, es.ArrayExpression)
                or isinstance(right, es.ArrayExpression)
            ) {
            left_spread = es.SpreadElement(argument=left);
            right_spread = es.SpreadElement(argument=right);
            bin_expr = self.sync_loc(
                es.ArrayExpression(elements=[left_spread, right_spread]), jac_node=nd
            );
        } else {
            bin_expr = self.sync_loc(
                es.BinaryExpression(operator=operator, left=left, right=right),
                jac_node=nd
            );
        }
    }
    nd.gen.es_ast = bin_expr;
}
