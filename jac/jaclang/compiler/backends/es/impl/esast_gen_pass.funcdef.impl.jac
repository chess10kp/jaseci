impl EsastGenPass._ability_is_generator(nd: uni.Ability) -> bool {
    for y in nd.get_all_sub_nodes(uni.YieldExpr) {
        if y.find_parent_of_type(uni.Ability) is nd {
            return True;
        }
    }
    return False;
}

impl EsastGenPass.exit_has_var(nd: uni.HasVar) -> None {
    nd.gen.es_ast = None;
}

impl EsastGenPass._ref_forward_param(nd: uni.Ability) -> (uni.ParamVar | None) {
    if not isinstance(nd.signature, uni.FuncSignature) {
        return None;
    }
    params = nd.signature.params;
    if not params {
        return None;
    }
    last = params[-1];
    if (
        last.type_tag is not None and self._ref_head_name(last.type_tag.tag) == 'Ref'
    ) {
        return last;
    }
    return None;
}

impl EsastGenPass._transform_to_useeffect(nd: uni.Ability) -> None {
    inner = self.unwrap_body(nd);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(nd, body_stmts);

    is_entry = nd.signature.event.name == Tok.KW_ENTRY;
    is_async = nd.is_async;

    deps_elements: list[es.Expression | es.SpreadElement | None] = [];
    arch_tag = nd.signature.arch_tag_info;
    if arch_tag {
        if isinstance(arch_tag, (uni.ListVal, uni.TupleVal)) {
            for item in arch_tag.values {
                if item.gen.es_ast {
                    deps_elements.append(cast(es.Expression, item.gen.es_ast));
                }
            }
        } elif arch_tag.gen.es_ast {
            deps_elements.append(cast(es.Expression, arch_tag.gen.es_ast));
        }
    }
    effect = Effect(
        body=body_stmts, deps=deps_elements, is_entry=is_entry, is_async=is_async
    );
    self._ensure_backend();
    for sym in self.backend.effect_symbols(effect) {
        self._inject_runtime_import(sym, nd);
    }
    lowered = self.backend.lower_effect(effect);
    if lowered {
        nd.gen.es_ast = self.sync_loc(lowered[0], jac_node=nd);
    }
}

impl EsastGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    owner: (uni.UniNode | None) = nd.parent;
    while (owner is not None and not isinstance(owner, (uni.Ability, uni.Archetype))) {
        owner = owner.parent;
    }
    if isinstance(owner, uni.Archetype) or not nd.in_client_context() {
        nd.gen.es_ast = None;
        return;
    }

    statements: list[es.Statement] = [];
    for has_var in nd.vars {
        var_name = has_var.name.sym_name;

        ref_ctor = (
            isinstance(has_var.value, uni.FuncCall)
            and self._ref_head_name(has_var.value) == 'Ref'
        );
        ref_typed = (
            has_var.type_tag is not None
            and self._ref_head_name(has_var.type_tag.tag) == 'Ref'
        );
        if ref_ctor or ref_typed {
            if ref_typed and not ref_ctor {
                self.emit(E2025, node_override=has_var);
            }
            ref_init: es.Expression = self.sync_loc(
                es.Literal(value=None, raw='null'), jac_node=has_var
            );
            if isinstance(has_var.value, uni.FuncCall) and has_var.value.params {
                seed = has_var.value.params[0];
                seed_expr = seed.value if isinstance(seed, uni.KWPair) else seed;
                if seed_expr.gen.es_ast {
                    ref_init = cast(es.Expression, seed_expr.gen.es_ast);
                }
            }
            ref_field = RefField(name=var_name, init_expr=ref_init);
            self._ensure_backend();
            for sym in self.backend.ref_field_symbols(ref_field) {
                self._inject_runtime_import(sym, nd);
            }
            for stmt in self.backend.lower_ref_field(ref_field) {
                statements.append(self.sync_loc(stmt, jac_node=has_var));
            }
            self._register_declaration(var_name);
            continue;
        }

        init_value: es.Expression;
        if has_var.value and has_var.value.gen.es_ast {
            init_value = cast(es.Expression, has_var.value.gen.es_ast);
        } else {
            init_value = es.Identifier(name='undefined');
        }

        self._ensure_backend();
        setter_name = self.backend._get_setter_name(var_name);
        state_field = StateField(
            name=var_name,
            init_expr=init_value,
            bind_setter=not self._setter_name_taken(has_var, setter_name)
        );
        for sym in self.backend.state_field_symbols(state_field) {
            self._inject_runtime_import(sym, nd);
        }
        for stmt in self.backend.lower_state_field(state_field) {
            statements.append(self.sync_loc(stmt, jac_node=has_var));
        }

        self.reactive_vars.add(var_name);
        self._register_declaration(var_name);
        if state_field.bind_setter and setter_name {
            self._register_declaration(setter_name);
        }
    }
    if len(statements) == 1 {
        nd.gen.es_ast = statements[0];
    } elif len(statements) > 1 {
        nd.gen.es_ast = statements;
    } else {
        nd.gen.es_ast = None;
    }
}

impl EsastGenPass._setter_name_taken(has_var: uni.HasVar, setter_name: str) -> bool {
    if not setter_name {
        return True;
    }
    scope = has_var.sym_tab;
    if scope is None {
        return False;
    }
    existing = scope.names_in_scope.get(setter_name);
    if existing is None {
        return False;
    }

    return existing.decl.parent is not has_var;
}

impl EsastGenPass.exit_param_var(nd: uni.ParamVar) -> None {
    param_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    self._register_declaration(param_id.name);
    if nd.is_vararg or nd.is_kwargs {
        nd.gen.es_ast = self.sync_loc(es.RestElement(argument=param_id), jac_node=nd);
    } elif nd.value and nd.value.gen.es_ast {
        nd.gen.es_ast = self.sync_loc(
            es.AssignmentPattern(
                left=param_id, right=cast(es.Expression, nd.value.gen.es_ast)
            ),
            jac_node=nd
        );
    } else {
        nd.gen.es_ast = param_id;
    }
}

impl EsastGenPass.exit_func_signature(nd: uni.FuncSignature) -> None {
    nd.gen.es_ast = None;
}

impl EsastGenPass.exit_ability(nd: uni.Ability) -> None {
    if self._view_stack {
        self._view_stack.pop();
    }

    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
    }

    osp_info = self._osp_ability_info(nd);
    if osp_info is not None {
        self._emit_osp_slot_method(nd, osp_info);
        return;
    }

    if (isinstance(nd.signature, uni.EventSignature) and nd.in_client_context()) {
        self._transform_to_useeffect(nd);
        return;
    }

    ref_param: (uni.ParamVar | None) = None;
    if (
        nd.code_context == CodeContext.CLIENT
        and not nd.is_method
        and self._component_call_abi(nd) in ('props_destructure', 'props_passthrough')
    ) {
        ref_param = self._ref_forward_param(nd);
    }
    if (nd.code_context == CodeContext.CLIENT and not nd.is_method) {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        route_role: (str | None) = None;
        if (
            isinstance(nd.signature, uni.FuncSignature)
            and nd.signature.return_type is not None
        ) {
            route_role = self._return_type_route_role(nd.signature.return_type);
        }

        if is_pub or route_role or nd.codespace_dual {
            name = nd.name_ref.sym_name;
            self.client_manifest.exports.append(name);
            if (
                isinstance(nd.signature, uni.FuncSignature)
                and nd.signature.return_type is not None
                and self._return_type_includes_jsx_element(nd.signature.return_type)
            ) {
                self.component_export_names.add(name);
            }

            self.client_manifest.params[name] = [
                p.name.sym_name
                for p in nd.signature.params
                if p is not ref_param
            ]
                if isinstance(nd.signature, uni.FuncSignature)
                else [];
            if route_role == 'page' and self.client_manifest.page_export is None {
                self.client_manifest.page_export = name;
            } elif route_role == 'layout'
                and self.client_manifest.layout_export is None {
                self.client_manifest.layout_export = name;
            }
        }
    }
    component_call_abi = self._component_call_abi(nd);
    params: list[es.Pattern] = [];
    destructure_stmts: list[es.Statement] = [];
    destructure_props: list[es.AssignmentProperty | es.RestElement] = [];

    sig_params = (
        [
            p
            for p in nd.signature.params
            if p is not ref_param
        ]
            if isinstance(nd.signature, uni.FuncSignature)
            else []
    );
    value_params = (
        [
            p
            for p in nd.signature.get_parameters()
            if p is not ref_param
        ]
            if isinstance(nd.signature, uni.FuncSignature)
            else []
    );
    if value_params {
        if component_call_abi == 'props_destructure' {
            params.append(es.Identifier(name="props"));
            for param in sig_params {
                param_key = self.sync_loc(
                    es.Identifier(name=param.name.sym_name), jac_node=param.name
                );
                destructure_props.append(
                    self.sync_loc(
                        es.AssignmentProperty(
                            key=param_key,
                            value=cast(es.Pattern, param.gen.es_ast),
                            shorthand=not isinstance(
                                param.gen.es_ast, es.AssignmentPattern
                            ),
                        ),
                        jac_node=param,
                    )
                );
            }
            destructure_stmts = [
                self.sync_loc(
                    es.VariableDeclaration(
                        declarations=[
                            self.sync_loc(
                                es.VariableDeclarator(
                                    id=self.sync_loc(
                                        es.ObjectPattern(properties=destructure_props),
                                        jac_node=nd,
                                    ),
                                    `init=self.sync_loc(
                                        es.Identifier(name="props"), jac_node=nd
                                    ),
                                ),
                                jac_node=nd,
                            )
                        ],
                        kind="const",
                    ),
                    jac_node=nd,
                )
            ];
        } else {
            if component_call_abi == 'props_passthrough' {
                self.emit(
                    W5015, node_override=value_params[0], component=nd.name_ref.sym_name
                );
            }
            for param in value_params {
                if param.gen.es_ast {
                    params.append(cast(es.Pattern, param.gen.es_ast));
                }
            }
        }
    }
    if ref_param is not None {
        if not params {
            params.append(self.sync_loc(es.Identifier(name="props"), jac_node=nd));
        }
        params.append(
            cast(es.Pattern, ref_param.gen.es_ast)
                if ref_param.gen.es_ast
                else self.sync_loc(
                    es.Identifier(name=ref_param.name.sym_name), jac_node=ref_param.name
                )
        );
    }
    inner = self.unwrap_body(nd);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(
        es.BlockStatement(body=destructure_stmts + body_stmts), jac_node=nd
    );
    func_id = self.sync_loc(
        es.Identifier(name=nd.name_ref.sym_name), jac_node=nd.name_ref
    );
    is_gen = self._ability_is_generator(nd);
    if nd.is_method {
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=None, params=params, body=block, generator=is_gen, async_=nd.is_async
            ),
            jac_node=nd
        );
        method_def = self.sync_loc(
            es.MethodDefinition(
                key=func_id, value=func_expr, kind='method', `static=nd.is_static
            ),
            jac_node=nd
        );
        nd.gen.es_ast = method_def;
    } elif ref_param is not None {
        self._inject_runtime_import('forwardRef', nd);
        func_expr = self.sync_loc(
            es.FunctionExpression(
                id=func_id,
                params=params,
                body=block,
                generator=is_gen,
                async_=nd.is_async
            ),
            jac_node=nd
        );
        forward_call = self.sync_loc(
            es.CallExpression(
                callee=es.Identifier(name='forwardRef'), arguments=[func_expr]
            ),
            jac_node=nd
        );
        declarator = self.sync_loc(
            es.VariableDeclarator(
                id=self.sync_loc(
                    es.Identifier(name=nd.name_ref.sym_name), jac_node=nd.name_ref
                ),
                `init=forward_call,
            ),
            jac_node=nd
        );
        nd.gen.es_ast = self.sync_loc(
            es.VariableDeclaration(declarations=[declarator], kind='const'), jac_node=nd
        );
    } else {
        pascal = self._component_pascal_name(nd);
        if pascal is not None {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=self.sync_loc(es.Identifier(name=pascal), jac_node=nd.name_ref),
                    params=params,
                    body=block,
                    generator=is_gen,
                    async_=nd.is_async
                ),
                jac_node=nd
            );
            alias_decl = self.sync_loc(
                es.VariableDeclaration(
                    declarations=[
                        self.sync_loc(
                            es.VariableDeclarator(
                                id=self.sync_loc(
                                    es.Identifier(name=nd.name_ref.sym_name),
                                    jac_node=nd.name_ref
                                ),
                                `init=self.sync_loc(
                                    es.Identifier(name=pascal), jac_node=nd.name_ref
                                ),
                            ),
                            jac_node=nd
                        )
                    ],
                    kind='const'
                ),
                jac_node=nd
            );
            nd.gen.es_ast = [func_decl, alias_decl];
        } else {
            func_decl = self.sync_loc(
                es.FunctionDeclaration(
                    id=func_id,
                    params=params,
                    body=block,
                    generator=is_gen,
                    async_=nd.is_async
                ),
                jac_node=nd
            );
            nd.gen.es_ast = func_decl;
        }
    }
}

impl EsastGenPass._osp_ability_info(nd: uni.Ability) -> (dict | None) {
    if not isinstance(nd.signature, uni.EventSignature) {
        return None;
    }
    if nd.body is None {
        return None;
    }
    owner = nd.method_owner;
    if not isinstance(owner, uni.Archetype) {
        return None;
    }
    kind = owner.arch_kind;
    if kind is None {
        return None;
    }
    if (nd.name_ref is None) or (owner.name is None) {
        return None;
    }
    return {
        "owner": owner.name.sym_name,
        "kind": kind,
        "is_entry": nd.signature.event.name == Tok.KW_ENTRY,
        "name": nd.name_ref.sym_name
    };
}

impl EsastGenPass._osp_const_decl(
    name: str, `init: es.Expression, nd: uni.UniNode
) -> es.VariableDeclaration {
    return self.sync_loc(
        es.VariableDeclaration(
            kind='const',
            declarations=[
                es.VariableDeclarator(id=es.Identifier(name=name), `init=`init)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._emit_osp_slot_method(nd: uni.Ability, osp: dict) -> None {
    self.needs_jac_runtime = True;
    is_walker = osp["kind"] == "walker";
    other_ref = self.sync_loc(es.Identifier(name="__other"), jac_node=nd);
    this_ref = self.sync_loc(es.ThisExpression(), jac_node=nd);
    here_init = other_ref if is_walker else this_ref;
    visitor_init = this_ref if is_walker else other_ref;
    binds: list[es.Statement] = [
        self._osp_const_decl("here", here_init, nd),
        self._osp_const_decl("visitor", visitor_init, nd)
    ];
    inner = self.unwrap_body(nd);
    body_stmts = self._collect_stmt_body(inner);
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=binds + body_stmts), jac_node=nd);
    func_expr = self.sync_loc(
        es.FunctionExpression(
            id=None,
            params=[self.sync_loc(es.Identifier(name="__other"), jac_node=nd)],
            body=block,
            async_=nd.is_async
        ),
        jac_node=nd
    );
    nd.gen.es_ast = self.sync_loc(
        es.MethodDefinition(
            key=self.sync_loc(
                es.Identifier(name=nd.name_ref.sym_name), jac_node=nd.name_ref
            ),
            value=func_expr,
            kind='method',
            `static=False
        ),
        jac_node=nd
    );
}

impl EsastGenPass.enter_ability(nd: uni.Ability) -> None {
    if isinstance(nd.body, uni.ImplDef) and (nd.body not in nd.kid) {
        nd.add_kids_right([nd.body], pos_update=False, parent_update=True);
    }

    self._view_stack.append(None);
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = set(self.reactive_vars);
}

impl EsastGenPass.exit_archetype(nd: uni.Archetype) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub or nd.codespace_dual {
            self.client_manifest.exports.append(nd.name.sym_name);
        }
    }
    body_stmts: list[es.MethodDefinition | es.PropertyDefinition] = [];
    has_members: list[uni.ArchHas] = [];
    inner = self.unwrap_body(nd);
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.ArchHas) {
                has_members.append(stmt);
                continue;
            }
            if (
                stmt.gen.es_ast
                and stmt.gen.es_ast
                and isinstance(
                    stmt.gen.es_ast, (es.MethodDefinition, es.PropertyDefinition)
                )
            ) {
                body_stmts.append(stmt.gen.es_ast);
            }
        }
    }

    is_local_osp_arch = (
        (nd.name is not None)
        and (nd.name.sym_name in self._osp_arch_set())
        and (nd.arch_kind is not None)
    );
    is_shared_boundary_arch = (
        (nd.name is not None) and (nd.name.sym_name in self.shared_arch_names)
    );
    has_postinit = False;
    for _stmt in (self.unwrap_body(nd) or []) {
        if (
            isinstance(_stmt, uni.Ability)
            and getattr(_stmt, 'sym_name', '') == '__post_init__'
        ) {
            has_postinit = True;
        }
    }
    if (
        (
            (nd.arch_type.name == Tok.KW_OBJECT)
            or is_local_osp_arch
            or is_shared_boundary_arch
        )
        and (has_members or has_postinit)
    ) {
        constructor_stmts: list[es.Statement] = [];
        props_param = self.sync_loc(
            es.AssignmentPattern(
                left=self.sync_loc(es.Identifier(name='props'), jac_node=nd),
                right=self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd)
            ),
            jac_node=nd
        );
        for arch_has in has_members {
            if arch_has.is_static {
                for var in arch_has.vars {
                    default_expr: es.Expression = cast(
                        es.Expression, var.value.gen.es_ast
                    )
                        if (var.value and var.value.gen.es_ast and var.value.gen.es_ast)
                        else self.sync_loc(es.Literal(value=None), jac_node=var);
                    static_prop = self.sync_loc(
                        es.PropertyDefinition(
                            key=self.sync_loc(
                                es.Identifier(name=var.name.sym_name), jac_node=var.name
                            ),
                            value=default_expr,
                            `static=True
                        ),
                        jac_node=var
                    );
                    body_stmts.append(static_prop);
                }
                continue;
            }
            for var in arch_has.vars {
                props_ident = self.sync_loc(es.Identifier(name='props'), jac_node=var);
                prop_ident = self.sync_loc(
                    es.Identifier(name=var.name.sym_name), jac_node=var.name
                );
                this_member = self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(es.ThisExpression(), jac_node=var),
                        property=prop_ident,
                        computed=False
                    ),
                    jac_node=var
                );
                props_access = self.sync_loc(
                    es.MemberExpression(
                        object=props_ident,
                        property=self.sync_loc(
                            es.Identifier(name=var.name.sym_name), jac_node=var.name
                        ),
                        computed=False
                    ),
                    jac_node=var
                );
                has_call = self.sync_loc(
                    es.CallExpression(
                        callee=self.sync_loc(
                            es.MemberExpression(
                                object=props_ident,
                                property=self.sync_loc(
                                    es.Identifier(name='hasOwnProperty'), jac_node=var
                                ),
                                computed=False
                            ),
                            jac_node=var
                        ),
                        arguments=[
                            self.sync_loc(
                                es.Literal(value=var.name.sym_name), jac_node=var.name
                            )
                        ]
                    ),
                    jac_node=var
                );
                default_val: es.Expression = cast(es.Expression, var.value.gen.es_ast)
                    if (var.value and var.value.gen.es_ast and var.value.gen.es_ast)
                    else self.sync_loc(es.Literal(value=None), jac_node=var);
                conditional = self.sync_loc(
                    es.ConditionalExpression(
                        `test=has_call, consequent=props_access, alternate=default_val
                    ),
                    jac_node=var
                );
                assignment = self.sync_loc(
                    es.AssignmentExpression(
                        operator='=', left=this_member, right=conditional
                    ),
                    jac_node=var
                );
                constructor_stmts.append(
                    self.sync_loc(
                        es.ExpressionStatement(expression=assignment), jac_node=var
                    )
                );
            }
        }
        if has_postinit {
            constructor_stmts.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=self.sync_loc(
                            es.CallExpression(
                                callee=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.ThisExpression(), jac_node=nd
                                        ),
                                        property=self.sync_loc(
                                            es.Identifier(name='__post_init__'),
                                            jac_node=nd
                                        ),
                                        computed=False
                                    ),
                                    jac_node=nd
                                ),
                                arguments=[]
                            ),
                            jac_node=nd
                        )
                    ),
                    jac_node=nd
                )
            );
        }
        if constructor_stmts {
            if nd.base_classes {
                constructor_stmts.insert(
                    0,
                    self.sync_loc(
                        es.ExpressionStatement(
                            expression=self.sync_loc(
                                es.CallExpression(
                                    callee=es.Identifier(name='super'),
                                    arguments=[es.Identifier(name='props')]
                                ),
                                jac_node=nd
                            )
                        ),
                        jac_node=nd
                    )
                );
            }
            constructor_method = self.sync_loc(
                es.MethodDefinition(
                    key=self.sync_loc(es.Identifier(name='constructor'), jac_node=nd),
                    value=self.sync_loc(
                        es.FunctionExpression(
                            id=None,
                            params=[props_param],
                            body=self.sync_loc(
                                es.BlockStatement(body=constructor_stmts), jac_node=nd
                            )
                        ),
                        jac_node=nd
                    ),
                    kind='constructor',
                    `static=False
                ),
                jac_node=nd
            );
            body_stmts.insert(0, constructor_method);
        }
    }
    class_body = self.sync_loc(es.ClassBody(body=body_stmts), jac_node=nd);
    super_class: (es.Expression | None) = None;
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if nd.base_classes {
        base = nd.base_classes[0];
        if base.gen.es_ast {
            super_class = cast(es.Expression, base.gen.es_ast);
            if (
                isinstance(super_class, es.Identifier)
                and JAC_TYPE_REGISTRY.is_exception(super_class.name)
            ) {
                super_class = self._jac_exc_ref(super_class.name, base);
            }
        }
    }
    class_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    class_decl = self.sync_loc(
        es.ClassDeclaration(id=class_id, superClass=super_class, body=class_body),
        jac_node=nd
    );
    nd.gen.es_ast = class_decl;
}
