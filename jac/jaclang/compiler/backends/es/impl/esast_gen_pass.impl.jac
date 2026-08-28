import from jaclang.compiler.tools.unparse_pass { unparse_node }
import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect
}

impl EsastGenPass._ensure_backend -> None {
    if self.backend is None {
        import from jaclang.compiler.backends.es.backends.registry {
            resolve_active_backend
        }
        try {
            self.backend = resolve_active_backend();
        } except ValueError {
            import from jaclang.project.config { get_config }
            import from jaclang.compiler.frontend.diagnostics { E5081 }
            import from jaclang.compiler.backends.es.backends.react {
                ReactBackend
            }
            cfg = get_config();
            fw = cfg.client.framework if (cfg and cfg.client) else "unknown";
            self.emit(E5081, framework=fw);
            self.backend = ReactBackend();
        }
    }
}

impl EsastGenPass.exit_semi(nd: uni.Semi) -> None {
    ;
}

impl EsastGenPass.exit_token(nd: uni.Token) -> None {
    ;
}

impl EsastGenPass._collect_body_stmts(
    body: Sequence[uni.UniNode]
) -> list[es.Statement] {
    body_stmts: list[es.Statement] = [];
    if body {
        for stmt in body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(cast(es.Statement, s) for s in stmt.gen.es_ast);
                } else {
                    body_stmts.append(cast(es.Statement, stmt.gen.es_ast));
                }
            }
        }
    }
    return body_stmts;
}

impl EsastGenPass.exit_test(nd: uni.Test) -> None {
    params: list[es.Pattern] = [];
    body_stmts = self._collect_body_stmts(nd.body);
    body_stmts = self._prepend_hoisted(nd, body_stmts);
    block = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=nd);
    func_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);

    func_decl = self.sync_loc(
        es.FunctionDeclaration(id=func_id, params=params, body=block, async_=True),
        jac_node=nd
    );
    nd.gen.es_ast = func_decl;

    self.client_manifest.has_client = True;
    self.client_manifest.tests.append(
        {
            'name': nd.name.sym_name,
            'description': nd.description.lit_value
                if nd.description
                else nd.name.sym_name
        }
    );
}

impl EsastGenPass.exit_module_code(nd: uni.ModuleCode) -> None {
    nd.gen.es_ast = self._collect_body_stmts(nd.body);
}

impl EsastGenPass.exit_global_vars(nd: uni.GlobalVars) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub or nd.codespace_dual {
            for assignment in nd.assignments {
                for target in assignment.target {
                    if (sym_name := target?.sym_name) {
                        self.client_manifest.globals.append(sym_name);
                        if (
                            assignment.value
                            and (
                                (lit_val := self._literal_value(assignment.value))
                                is not None
                            )
                        ) {
                            self.client_manifest.globals_values[sym_name] = lit_val;
                        }
                    }
                }
            }
        }
    }
    statements: list[(es.Statement | es.ModuleDeclaration)] = [];
    for assignment in nd.assignments {
        if assignment.gen.es_ast {
            stmt = assignment.gen.es_ast;
            if (
                isinstance(stmt, es.VariableDeclaration)
                and nd.is_frozen
                and (stmt.kind != 'const')
            ) {
                stmt.kind = 'const';
            }
            statements.append(cast(es.Statement, stmt));
        }
    }
    nd.gen.es_ast = statements;
}

impl EsastGenPass.exit_name(nd: uni.Name) -> None {
    if (nd.sym_name in self.reactive_vars) and not self._in_identifier_slot(nd) {
        self._ensure_backend();
        nd.gen.es_ast = self.sync_loc(
            self.backend.lower_state_read(nd.sym_name), jac_node=nd
        );
        return;
    }
    name_map = {'None': 'null', 'True': 'true', 'False': 'false', 'self': 'this'};
    name = name_map.get(nd.sym_name, nd.sym_name);
    identifier = self.sync_loc(es.Identifier(name=name), jac_node=nd);
    nd.gen.es_ast = identifier;
}

impl EsastGenPass._in_identifier_slot(nd: uni.UniNode) -> bool {
    parent = nd.parent;
    if parent is None {
        return False;
    }
    if isinstance(parent, uni.KWPair) {
        return parent.key is nd;
    }
    if isinstance(parent, uni.AtomTrailer) {
        return parent.is_attr and (parent.right is nd);
    }
    if isinstance(parent, (uni.ParamVar, uni.HasVar, uni.Archetype, uni.Enum)) {
        return parent.name is nd;
    }
    if isinstance(parent, uni.Ability) {
        return parent.name_ref is nd;
    }
    if isinstance(parent, uni.ModuleItem) {
        return (parent.name is nd) or (parent.alias is nd);
    }
    if isinstance(parent, uni.ModulePath) {
        return (parent.alias is nd) or any(part is nd for part in (parent.path or []));
    }
    if isinstance(parent, uni.JsxNormalAttribute) {
        return (parent.name is nd) and (parent.value is not nd);
    }
    if isinstance(parent, uni.JsxElementName) {
        return any(part is nd for part in (parent.parts or []));
    }
    if isinstance(parent, uni.CompareExpr) {
        return (parent.left is nd) and isinstance(parent.parent, uni.FilterCompr);
    }
    return False;
}

impl EsastGenPass._in_type_slot(nd: uni.UniNode) -> bool {
    child = nd;
    parent = nd.parent;
    while parent is not None {
        if (
            isinstance(parent, uni.SubTag)
            or (isinstance(parent, uni.FuncSignature) and parent.return_type is child)
            or (isinstance(parent, uni.CastExpr) and parent.cast_type is child)
            or (isinstance(parent, uni.TypedCtxBlock) and parent.type_ctx is child)
            or (isinstance(parent, uni.Except) and parent.ex_type is child)
        ) {
            return True;
        }
        child = parent;
        parent = parent.parent;
    }
    return False;
}

impl EsastGenPass._is_call_target(nd: uni.UniNode) -> bool {
    return isinstance(nd.parent, uni.FuncCall) and nd.parent.target is nd;
}

impl EsastGenPass.exit_builtin_type(nd: uni.BuiltinType) -> None {
    type_name = nd.sym_name;
    self._ensure_emitters();
    if (
        not self._in_type_slot(nd)
        and getattr(self._builtin_emitter, "emit_" + type_name, None) is not None
    ) {
        nd.gen.es_ast = self.sync_loc(
            es.MemberExpression(
                object=es.MemberExpression(
                    object=es.Identifier(name='_jac'),
                    property=es.Identifier(name='types'),
                    computed=False
                ),
                property=es.Identifier(name=type_name),
                computed=False
            ),
            jac_node=nd
        );
        if not self._is_call_target(nd) {
            self.needs_jac_runtime = True;
        }
        return;
    }
    tag = self.sync_loc(
        es.Literal(value=type_name, raw=json.dumps(type_name)), jac_node=nd
    );
    nd.gen.es_ast = tag;
}

impl EsastGenPass._ability_is_generator(nd: uni.Ability) -> bool {
    for y in nd.get_all_sub_nodes(uni.YieldExpr) {
        if y.find_parent_of_type(uni.Ability) is nd {
            return True;
        }
    }
    return False;
}

impl EsastGenPass.exit_cast_expr(nd: uni.CastExpr) -> None {
    nd.gen.es_ast = nd.value.gen.es_ast;
}

impl EsastGenPass.exit_if_else_expr(nd: uni.IfElseExpr) -> None {
    `test = self._coerce_truthy(
        nd.condition,
        cast(
            es.Expression,
            nd.condition.gen.es_ast
                or self.sync_loc(es.Identifier(name='condition'), jac_node=nd.condition)
        ),
        nd
    );
    consequent = cast(
        es.Expression,
        nd.value.gen.es_ast
            or self.sync_loc(es.Identifier(name='value'), jac_node=nd.value)
    );
    alternate = cast(
        es.Expression,
        nd.else_value.gen.es_ast
            or self.sync_loc(es.Identifier(name='alternate'), jac_node=nd.else_value)
    );
    cond_expr = self.sync_loc(
        es.ConditionalExpression(
            `test=`test, consequent=consequent, alternate=alternate
        ),
        jac_node=nd
    );
    nd.gen.es_ast = cond_expr;
}

impl EsastGenPass.exit_k_v_pair(nd: uni.KVPair) -> None {
    ;
}

impl EsastGenPass.exit_dict_val(nd: uni.DictVal) -> None {
    properties: list[(es.Property | es.SpreadElement)] = [];
    for kv_pair in nd.kv_pairs {
        if (not isinstance(kv_pair, uni.KVPair) or (kv_pair.value is None)) {
            continue;
        }
        if (kv_pair.key is None) {
            if kv_pair.value.gen.es_ast {
                properties.append(
                    self.sync_loc(
                        es.SpreadElement(
                            argument=cast(es.Expression, kv_pair.value.gen.es_ast)
                        ),
                        jac_node=kv_pair.value
                    )
                );
            }
            continue;
        }
        key = cast(
            es.Expression,
            kv_pair.key.gen.es_ast
                or self.sync_loc(es.Literal(value='key'), jac_node=kv_pair.key)
        );
        value = cast(
            es.Expression,
            kv_pair.value.gen.es_ast
                or self.sync_loc(es.Literal(value=None), jac_node=kv_pair.value)
        );
        prop = self.sync_loc(
            es.Property(key=key, value=value, kind='init'), jac_node=kv_pair
        );
        properties.append(prop);
    }
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=nd);
    nd.gen.es_ast = obj_expr;
}

impl EsastGenPass._gen_seq_array(nd: uni.UniNode) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in nd.values {
        if (
            isinstance(item, uni.UnaryExpr)
            and item.op.name == Tok.STAR_MUL.value
            and item.operand.gen.es_ast
        ) {
            elements.append(
                self.sync_loc(
                    es.SpreadElement(
                        argument=cast(es.Expression, item.operand.gen.es_ast)
                    ),
                    jac_node=item
                )
            );
        } elif item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    array_expr = self.sync_loc(es.ArrayExpression(elements=elements), jac_node=nd);
    nd.gen.es_ast = array_expr;
}

impl EsastGenPass.exit_tuple_val(nd: uni.TupleVal) -> None {
    self._gen_seq_array(nd);
}

impl EsastGenPass.exit_set_val(nd: uni.SetVal) -> None {
    elements: list[es.Expression | es.SpreadElement | None] = [];
    for item in nd.values {
        if item.gen.es_ast {
            elements.append(cast(es.Expression, item.gen.es_ast));
        }
    }
    set_expr = self.sync_loc(
        es.NewExpression(
            callee=self.sync_loc(es.Identifier(name='Set'), jac_node=nd),
            arguments=[
                self.sync_loc(es.ArrayExpression(elements=elements), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
    nd.gen.es_ast = set_expr;
}

impl EsastGenPass.exit_list_val(nd: uni.ListVal) -> None {
    self._gen_seq_array(nd);
}

impl EsastGenPass.exit_atom_unit(nd: uni.AtomUnit) -> None {
    if (isinstance(nd.value, uni.Ability) and nd.value.gen.es_ast) {
        func_decl = nd.value.gen.es_ast;
        if isinstance(func_decl, es.FunctionDeclaration) {
            func_expr = self.sync_loc(
                es.FunctionExpression(
                    id=func_decl.id,
                    params=func_decl.params,
                    body=func_decl.body,
                    generator=func_decl.generator,
                    async_=func_decl.async_
                ),
                jac_node=nd.value
            );
            nd.gen.es_ast = func_expr;
        } else {
            nd.gen.es_ast = nd.value.gen.es_ast;
        }
    } elif (nd.value and nd.value.gen.es_ast) {
        nd.gen.es_ast = nd.value.gen.es_ast;
    } else {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=None), jac_node=nd);
    }
}

impl EsastGenPass.exit_lambda_expr(nd: uni.LambdaExpr) -> None {
    params: list[es.Pattern] = [];
    if isinstance(nd.signature, uni.FuncSignature) {
        for param in nd.signature.get_parameters() {
            if param.gen.es_ast {
                params.append(cast(es.Pattern, param.gen.es_ast));
            }
        }
    }
    tail = nd.tail_return_expr();
    if (tail is not None and isinstance(nd.body, list)) {
        body_expr = cast(
            es.Expression,
            tail.gen.es_ast or self.sync_loc(es.Literal(value=None), jac_node=tail)
        );
        nd.gen.es_ast = self.sync_loc(
            es.ArrowFunctionExpression(
                params=params, body=body_expr, expression=True, async_=False
            ),
            jac_node=nd
        );
    } elif isinstance(nd.body, list) {
        body_stmts: list[es.Statement] = [];
        for stmt in nd.body {
            if stmt.gen.es_ast {
                if isinstance(stmt.gen.es_ast, list) {
                    body_stmts.extend(stmt.gen.es_ast);
                } else {
                    body_stmts.append(stmt.gen.es_ast);
                }
            }
        }
        body_stmts = self._prepend_hoisted(nd, body_stmts);
        block_stmt = self.sync_loc(es.BlockStatement(body=body_stmts), jac_node=nd);
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(params=params, body=block_stmt, async_=False),
            jac_node=nd
        );
        nd.gen.es_ast = arrow_func;
    } elif isinstance(nd.body, uni.Expr) {
        body_expr = cast(
            es.Expression,
            nd.body.gen.es_ast
                or self.sync_loc(es.Literal(value=None), jac_node=nd.body)
        );
        arrow_func = self.sync_loc(
            es.ArrowFunctionExpression(
                params=params, body=body_expr, expression=True, async_=False
            ),
            jac_node=nd
        );
        nd.gen.es_ast = arrow_func;
    }
}

impl EsastGenPass.exit_atom_trailer(nd: uni.AtomTrailer) -> None {
    `obj = cast(
        es.Expression,
        nd.target.gen.es_ast
            or self.sync_loc(es.Identifier(name='obj'), jac_node=nd.target)
    );
    if (nd.right and nd.right.gen.es_ast) {
        if isinstance(nd.right, uni.Name) {
            prop = self.sync_loc(
                es.Identifier(name=nd.right.sym_name), jac_node=nd.right
            );
            member_expr = self.sync_loc(
                es.MemberExpression(object=`obj, property=prop, computed=False),
                jac_node=nd
            );
            nd.gen.es_ast = member_expr;
        } elif isinstance(nd.right, uni.IndexSlice) {
            slice_info = nd.right.gen.es_ast;
            if isinstance(slice_info, es.SliceInfo) {
                start = cast(
                    es.Expression,
                    (
                        slice_info.start
                        or self.sync_loc(es.Literal(value=0), jac_node=nd)
                    )
                );
                stop = slice_info.stop;
                slice_args: list[(es.Expression | es.SpreadElement)] = [start];
                if (stop is not None) {
                    slice_args.append(cast(es.Expression, stop));
                }
                slice_call = self.sync_loc(
                    es.CallExpression(
                        callee=self.sync_loc(
                            es.MemberExpression(
                                object=`obj,
                                property=self.sync_loc(
                                    es.Identifier(name='slice'), jac_node=nd
                                ),
                                computed=False
                            ),
                            jac_node=nd
                        ),
                        arguments=slice_args
                    ),
                    jac_node=nd
                );
                nd.gen.es_ast = slice_call;
            } elif isinstance(slice_info, es.IndexInfo) {
                idx = cast(
                    es.Expression,
                    (
                        slice_info.value
                        or self.sync_loc(es.Literal(value=0), jac_node=nd)
                    )
                );
                nd.gen.es_ast = self._lower_subscript(nd.target, `obj, idx, nd);
            } else {
                nd.gen.es_ast = `obj;
            }
        } else {
            nd.gen.es_ast = nd.right.gen.es_ast;
        }
    }
}

impl EsastGenPass.exit_special_var_ref(nd: uni.SpecialVarRef) -> None {
    self.exit_name(nd);
}

impl EsastGenPass.exit_index_slice(nd: uni.IndexSlice) -> None {
    if (nd.slices and (len(nd.slices) > 0)) {
        first_slice = nd.slices[0];
        if nd.is_range {
            start_ast = first_slice.start.gen.es_ast
                if (
                    first_slice.start
                    and first_slice.start.gen.es_ast
                    and isinstance(first_slice.start.gen.es_ast, es.Node)
                )
                else None;
            stop_ast = first_slice.stop.gen.es_ast
                if (
                    first_slice.stop
                    and first_slice.stop.gen.es_ast
                    and isinstance(first_slice.stop.gen.es_ast, es.Node)
                )
                else None;
            nd.gen.es_ast = es.SliceInfo(start=start_ast, stop=stop_ast);
        } else {
            value_ast = first_slice.start.gen.es_ast
                if (
                    first_slice.start
                    and first_slice.start.gen.es_ast
                    and isinstance(first_slice.start.gen.es_ast, es.Node)
                )
                else self.sync_loc(es.Literal(value=0), jac_node=nd);
            nd.gen.es_ast = es.IndexInfo(value=value_ast);
        }
    } else {
        nd.gen.es_ast = None;
    }
}



impl EsastGenPass._ensure_emitters -> None {
    if self._primitive_emitters is not None {
        return;
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import jaclang.compiler.backends.es.primitives_es as _pes;
    self._primitives_es_mod = _pes;
    self._primitive_emitters = {};
    for (_tn, _suffix) in JAC_TYPE_REGISTRY.emitter_items() {
        _ecls = getattr(_pes, "ES" + _suffix, None);
        if _ecls is not None {
            self._primitive_emitters[_tn] = _ecls();
        }
    }
    self._builtin_emitter = _pes.ESBuiltinEmitter();

    _poly: set[str] = set();
    for _emitter in self._primitive_emitters.values() {
        for _attr in dir(_emitter) {
            if _attr.startswith("emit_") and not _attr.startswith("emit_op_") {
                _poly.add(_attr[len("emit_"):]);
            }
        }
    }
    self._poly_methods = _poly;
}


impl EsastGenPass._operand_str(unparser: object, es_node: es.Expression) -> str {
    rendered = unparser.generate(es_node);
    if isinstance(
        es_node,
        (es.AssignmentExpression, es.ConditionalExpression, es.ArrowFunctionExpression)
    ) {
        return "(" + rendered + ")";
    }
    return rendered;
}

impl EsastGenPass._expr_type_name(expr_node: uni.UniNode) -> str {
    import from jaclang.compiler.type_system.type_utils { expr_primitive_name }
    return expr_primitive_name(self.prog, expr_node);
}

impl EsastGenPass._is_collection_expr(expr_node: uni.UniNode) -> bool {
    if isinstance(expr_node, uni.BoolExpr) {
        for val in expr_node.values {
            if self._is_collection_expr(val) {
                return True;
            }
        }
        return False;
    }
    return self._expr_type_name(expr_node)
        in {"list", "dict", "set", "tuple", "frozenset", "bytes"};
}

impl EsastGenPass._is_native_iterable_builtin_call(expr_node: uni.UniNode) -> bool {
    return isinstance(expr_node, uni.FuncCall)
        and expr_node.call_kind == "builtin"
        and isinstance(expr_node.target, uni.Name)
        and expr_node.target.sym_name
            in {"iter", "enumerate", "zip", "map", "filter", "sorted", "range"};
}

impl EsastGenPass._build_jac_ref(
    path: list[str], jac_node: (uni.UniNode | None)
) -> es.Expression {
    ref: es.Expression = self.sync_loc(es.Identifier(name=path[0]), jac_node=jac_node);
    for name in path[1:] {
        ref = self.sync_loc(
            es.MemberExpression(
                object=ref,
                property=self.sync_loc(es.Identifier(name=name), jac_node=jac_node),
                computed=False
            ),
            jac_node=jac_node
        );
    }
    return ref;
}

impl EsastGenPass._build_jac_call(
    path: list[str], args: list[es.Expression], jac_node: uni.UniNode
) -> es.Expression {
    self.needs_jac_runtime = True;
    return self.sync_loc(
        es.CallExpression(
            callee=self._build_jac_ref(path, jac_node),
            arguments=cast(list[(es.Expression | es.SpreadElement)], args)
        ),
        jac_node=jac_node
    );
}

impl EsastGenPass._coerce_truthy(
    expr_node: (uni.UniNode | None), es_expr: es.Expression, jac_node: uni.UniNode
) -> es.Expression {
    if (expr_node is not None) and self._is_collection_expr(expr_node) {
        return self._build_jac_call(["_jac", "builtin", "bool"], [es_expr], jac_node);
    }
    return es_expr;
}

impl EsastGenPass._is_literal_index(idx_es: es.Expression) -> bool {
    if not isinstance(idx_es, es.Literal) {
        return False;
    }
    return not (
        isinstance(idx_es.value, (int, float))
        and (not isinstance(idx_es.value, bool))
        and (idx_es.value < 0)
    );
}

impl EsastGenPass._lower_subscript(
    target_node: uni.UniNode,
    obj_es: es.Expression,
    idx_es: es.Expression,
    jac_node: uni.UniNode
) -> es.Expression {
    if self._is_literal_index(idx_es) {
        return self.sync_loc(
            es.MemberExpression(object=obj_es, property=idx_es, computed=True),
            jac_node=jac_node
        );
    }
    _tname = self._expr_type_name(target_node);
    if _tname in {"list", "tuple", "str", "bytes"} {
        return self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(
                    es.MemberExpression(
                        object=obj_es,
                        property=self.sync_loc(
                            es.Identifier(name='at'), jac_node=jac_node
                        ),
                        computed=False
                    ),
                    jac_node=jac_node
                ),
                arguments=[cast((es.Expression | es.SpreadElement), idx_es)]
            ),
            jac_node=jac_node
        );
    }
    if _tname == "dict" {
        return self.sync_loc(
            es.MemberExpression(object=obj_es, property=idx_es, computed=True),
            jac_node=jac_node
        );
    }
    return self._build_jac_call(
        ["_jac", "poly", "getitem"], [obj_es, idx_es], jac_node
    );
}



impl EsastGenPass._is_null_literal(nd: (uni.UniNode | None)) -> bool {
    if nd is None {
        return False;
    }
    return isinstance(nd, uni.Null)
        or (isinstance(nd, uni.Name) and nd.sym_name == 'None');
}


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

impl EsastGenPass.exit_expr_stmt(nd: uni.ExprStmt) -> None {
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.expr, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );

    acc = self._cur_view_acc();
    if acc is not None {
        nd.gen.es_ast = self._view_emit_child(acc, expr, nd);
        return;
    }
    expr_stmt = self.sync_loc(es.ExpressionStatement(expression=expr), jac_node=nd);
    nd.gen.es_ast = expr_stmt;
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

impl EsastGenPass.exit_assert_stmt(nd: uni.AssertStmt) -> None {
    `test: es.Expression = cast(es.Expression, nd.condition.gen.es_ast)
        if nd.condition.gen.es_ast
        else self.sync_loc(es.Literal(value=True), jac_node=nd.condition);
    negated_test = self.sync_loc(
        es.UnaryExpression(operator='!', prefix=True, argument=`test), jac_node=nd
    );
    error_msg = 'Assertion failed';
    if (
        nd.error_msg
        and nd.error_msg.gen.es_ast
        and isinstance(nd.error_msg.gen.es_ast, es.Literal)
    ) {
        error_msg = str(nd.error_msg.gen.es_ast.value);
    }
    throw_stmt = self.sync_loc(
        es.ThrowStatement(
            argument=self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(es.Identifier(name='Error'), jac_node=nd),
                    arguments=[self.sync_loc(es.Literal(value=error_msg), jac_node=nd)]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
    if_stmt = self.sync_loc(
        es.IfStatement(
            `test=negated_test,
            consequent=self.sync_loc(es.BlockStatement(body=[throw_stmt]), jac_node=nd)
        ),
        jac_node=nd
    );
    nd.gen.es_ast = if_stmt;
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

impl EsastGenPass._ref_head_name(expr: (uni.UniNode | None)) -> (str | None) {
    cur = expr;
    while True {
        if isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        } elif isinstance(cur, uni.AtomTrailer) {
            cur = cur.target;
        } else {
            break;
        }
    }
    return cur.value if isinstance(cur, uni.Name) else None;
}

impl EsastGenPass._osp_model -> OspModel {
    import from jaclang.runtime.osp_model { get_osp_model }
    _root = self.ir_in if isinstance(self.ir_in, uni.Module) else self.get_main_mod();
    return get_osp_model(_root);
}

impl EsastGenPass._osp_arch_kinds -> dict[str, str] {
    _model = self._osp_model();
    if not _model.has_local_ability() {
        return {};
    }
    return _model.arch_kind;
}

impl EsastGenPass._osp_arch_set -> set[str] {
    return set(self._osp_arch_kinds().keys());
}

impl EsastGenPass._osp_expr_arch_name(expr: (uni.UniNode | None)) -> (str | None) {
    import from jaclang.compiler.type_system.types { ClassType }
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _ty = expr.type;
    if isinstance(_ty, ClassType) {
        _nm = _ty.shared.class_name;
        if self._arch_kind_of_type(_ty) is not None
            or self._arch_kind_by_name(_nm) is not None {
            return _nm;
        }
    }
    return None;
}

impl EsastGenPass._arch_kind_of_type(ty: object) -> (str | None) {
    import from jaclang.compiler.type_system.types { ClassType }
    if not isinstance(ty, ClassType) {
        return None;
    }
    _st = ty.shared.symbol_table;
    if isinstance(_st, uni.Archetype) {
        return {
            "KW_NODE": "node",
            "KW_EDGE": "edge",
            "KW_WALKER": "walker",
            "KW_OBJECT": "object"
        }.get(
            _st.arch_type.name
        );
    }
    return None;
}

impl EsastGenPass._expr_class_type(expr: (uni.UniNode | None)) -> (object | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _ty = expr.type;
    return _ty;
}

impl EsastGenPass._osp_expr_arch_kind(expr: (uni.UniNode | None)) -> (str | None) {
    _kind = self._arch_kind_of_type(self._expr_class_type(expr));
    if _kind is not None {
        return _kind;
    }
    _nm = self._osp_expr_arch_name(expr);
    if _nm is None {
        return None;
    }
    return self._arch_kind_by_name(_nm);
}

impl EsastGenPass._arch_kind_by_name(name: str) -> (str | None) {
    _local = self._osp_model().arch_kind.get(name);
    if _local is not None {
        return _local;
    }
    _mod = self.ir_in if isinstance(self.ir_in, uni.Module) else self.get_main_mod();
    _sym = _mod.lookup(name);
    if _sym is None {
        return None;
    }
    if _sym.sym_type.value in ("node", "edge", "walker") {
        return _sym.sym_type.value;
    }
    return self._arch_kind_of_type(self._expr_class_type(_sym.decl));
}

impl EsastGenPass._osp_var_arch -> dict[str, str] {
    if self._osp_var_arch_cache is not None {
        return self._osp_var_arch_cache;
    }
    bindings: dict[str, str] = {};
    kinds = self._osp_arch_kinds();
    if kinds {
        scan_root = self.ir_in
            if isinstance(self.ir_in, uni.Module)
            else self.get_main_mod();
        for asn in scan_root.get_all_sub_nodes(uni.Assignment) {
            if isinstance(asn.value, uni.FuncCall) {
                head = self._ref_head_name(asn.value);
                if (head is not None) and (head in kinds) {
                    for tgt in asn.target {
                        if isinstance(tgt, uni.Name) {
                            bindings[tgt.sym_name] = head;
                        }
                    }
                }
            }
        }
    }
    self._osp_var_arch_cache = bindings;
    return bindings;
}

impl EsastGenPass._build_osp_tags_js -> str {
    _model = self._osp_model();
    tags = _model.tags;
    lines: list[str] = [];
    isa_parts: list[str] = [];
    for name in _model.arch_kind.keys() {
        tag = tags.get(name);
        if tag is None {
            continue;
        }
        lines.append(
            f'if (typeof {name} !== "undefined") {name}.prototype.__tag = {tag};'
        );
        isa_members = ", ".join(
            [
                str(tags[a])
                for a in _model.isa.get(name, [])
                if a in tags
            ]
        );
        isa_parts.append(f"{tag}: new Set([{isa_members}])");
    }
    lines.append(
        "var __ospISA = Object.assign(globalThis.__jacOspIsa ??= {}, {"
            + ", ".join(isa_parts)
            + "});"
    );
    return "\n".join(lines);
}

impl EsastGenPass._build_osp_setup_js -> str {
    _model = self._osp_model();

    arch_kinds = self._osp_arch_kinds();
    tags = _model.tags;

    entry_by_owner: dict[str, list] = {};
    exit_by_owner: dict[str, list] = {};
    for slot in _model.local_slots() {
        bucket = entry_by_owner if slot.is_entry else exit_by_owner;
        if slot.owner not in bucket {
            bucket[slot.owner] = [];
        }
        bucket[slot.owner].append(slot);
    }

    lines: list[str] = [];
    desc_parts: list[str] = [];
    for name in arch_kinds.keys() {
        tag = tags.get(name);
        if tag is None {
            continue;
        }
        desc_cls = "__ospC.WalkerDesc"
            if (arch_kinds[name] == "walker")
            else "__ospC.NodeDesc";
        entry_js = self._osp_slots_js(entry_by_owner.get(name, []), tags);
        exit_js = self._osp_slots_js(exit_by_owner.get(name, []), tags);
        desc_parts.append(
            f"{tag}: new {desc_cls}({{type_tag: {tag}, entry: {entry_js}, exit: {exit_js}}})"
        );
    }
    lines.append(
        "var __ospDESC = Object.assign(globalThis.__jacOspDesc ??= {}, {"
            + ", ".join(desc_parts)
            + "});"
    );
    lines.append(
        "var __ospRT = globalThis.__jacOspRT ??= new __ospC.OspRuntime({"
            + "tag_of: (h) => h.__tag, "
            + "is_a: (t, b) => __ospIsA(t, b), "
            + "node_desc: (t) => (globalThis.__jacOspDesc || {})[t] "
            + "?? new __ospC.NodeDesc({type_tag: t, entry: [], exit: []}), "
            + "on_complete: (s, ok) => { if (s.wlk && !s.nested) s.wlk.reports = s.reports; }"
            + "});"
    );
    return "\n".join(lines);
}

impl EsastGenPass._osp_slots_js(slots: list, tags: dict) -> str {
    parts: list[str] = [];
    for slot in slots {
        fn = "(o, x) => o." + slot.ability + "(x)";
        if not slot.trigger_names {
            parts.append("new __ospC.Slot({trig_tag: -1, fn: " + fn + "})");
        } else {
            for trig in slot.trigger_names {
                ttag = tags[trig] if (trig in tags) else -1;
                if ttag < 0 {
                    if self._arch_kind_by_name(trig) in ("node", "edge", "walker") {
                        import from jaclang.runtime.osp_model { stable_osp_tag }
                        ttag = stable_osp_tag(trig);
                    }
                }
                parts.append(f"new __ospC.Slot({{trig_tag: {ttag}, fn: {fn}}})");
            }
        }
    }
    return "[" + ", ".join(parts) + "]";
}

impl EsastGenPass.exit_visit_stmt(nd: uni.VisitStmt) -> None {
    self.needs_osp_kernel = True;
    self.needs_jac_runtime = True;
    target = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.target,
            default_factory=lambda (_src: any) { es.ArrayExpression(elements=[]); }
        )
    );

    if not isinstance(nd.target, (uni.EdgeRefTrailer, uni.ListVal)) {
        target = self.sync_loc(es.ArrayExpression(elements=[target]), jac_node=nd);
    }
    insert: es.Expression = self.sync_loc(
        es.UnaryExpression(operator='-', argument=es.Literal(value=1), prefix=True),
        jac_node=nd
    );
    if nd.insert_loc and nd.insert_loc.gen.es_ast {
        insert = cast(es.Expression, nd.insert_loc.gen.es_ast);
    }
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospC.osp_visit'), jac_node=nd
                    ),
                    arguments=[target, insert]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_disengage_stmt(nd: uni.DisengageStmt) -> None {
    self.needs_osp_kernel = True;
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospC.osp_disengage'), jac_node=nd
                    ),
                    arguments=[]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_report_stmt(nd: uni.ReportStmt) -> None {
    self.needs_osp_kernel = True;
    expr = cast(
        es.Expression,
        self._get_ast_or_default(
            nd.expr, default_factory=lambda (_src: any) { es.Literal(value=None); }
        )
    );
    nd.gen.es_ast = self.sync_loc(
        es.ExpressionStatement(
            expression=self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.Identifier(name='__ospC.osp_report'), jac_node=nd
                    ),
                    arguments=[expr]
                ),
                jac_node=nd
            )
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_edge_ref_trailer(nd: uni.EdgeRefTrailer) -> None {
    nd.gen.es_ast = self._build_edge_ref(nd);
}

impl EsastGenPass._edge_tag_literal(
    nd: uni.UniNode, type_expr: (uni.UniNode | None), hard: bool
) -> int {
    if type_expr is None {
        return -1;
    }
    _etname = OspAnalysis.head_name(type_expr);
    if _etname is None {
        return -1;
    }
    _tag = self._osp_model().tags.get(_etname, -1);
    if _tag < 0 {
        _xkind = self._arch_kind_by_name(_etname);
        if _xkind is None {
            _xkind = self._arch_kind_of_type(self._expr_class_type(type_expr));
        }
        if _xkind in ("node", "edge") {
            import from jaclang.runtime.osp_model { stable_osp_tag }
            _tag = stable_osp_tag(_etname);
        }
    }
    if (_tag < 0) and hard {
        import from jaclang.compiler.frontend.diagnostics { E5097 }
        self.emit(
            E5097,
            node_override=nd,
            kind=f"a graph reference with unresolved archetype '{_etname}'"
        );
    }
    return _tag;
}

impl EsastGenPass._build_edge_ref(nd: uni.EdgeRefTrailer) -> es.Expression {
    import from jaclang.compiler.frontend.diagnostics { E5097 }
    fail = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
    chain = nd.chain;
    if not chain {
        self.emit(E5097, node_override=nd, kind="an empty edge reference");
        return fail;
    }
    self.needs_osp_graph = True;
    _idx = 0;
    origin: es.Expression;
    if isinstance(chain[0], uni.EdgeOpRef) {
        origin = self.sync_loc(es.Identifier(name='here'), jac_node=nd);
    } else {
        origin = cast(
            es.Expression,
            self._get_ast_or_default(
                chain[0],
                default_factory=lambda (_src: any) { es.ArrayExpression(elements=[]); }
            )
        );
        _idx = 1;
    }
    if (_idx >= len(chain)) or (not isinstance(chain[_idx], uni.EdgeOpRef)) {
        self.emit(E5097, node_override=nd, kind="this edge reference shape");
        return fail;
    }
    cur: (es.Expression | None) = None;
    while (_idx < len(chain)) and isinstance(chain[_idx], uni.EdgeOpRef) {
        step = chain[_idx];
        _idx += 1;
        _step_filter: (uni.FilterCompr | None) = None;
        if (_idx < len(chain)) and isinstance(chain[_idx], uni.FilterCompr) {
            _step_filter = chain[_idx];
            _idx += 1;
        }
        _is_last_hop = (_idx >= len(chain))
            or (not isinstance(chain[_idx], uni.EdgeOpRef));
        _fcond = step.filter_cond;
        _edge_tag = self._edge_tag_literal(
            nd, _fcond.f_type if (_fcond is not None) else None, True
        );
        _edges_only = 1 if (nd.edges_only and _is_last_hop) else 0;
        hop_args: list[es.Expression] = [
            origin if (cur is None) else cur,
            self.sync_loc(es.Literal(value=int(step.edge_dir.value)), jac_node=nd),
            self.sync_loc(es.Literal(value=_edge_tag), jac_node=nd),
            self.sync_loc(es.Literal(value=_edges_only), jac_node=nd)
        ];
        if (_fcond is not None) and _fcond.compares {
            _epred = self._build_osp_filter_pred(nd, _fcond);
            if _epred is None {
                return fail;
            }
            hop_args.append(
                self.sync_loc(
                    es.ArrowFunctionExpression(
                        params=[self.sync_loc(es.Identifier(name='x'), jac_node=nd)],
                        body=_epred,
                        expression=True
                    ),
                    jac_node=nd
                )
            );
        }
        hop_fn = '__ospRefsW' if (cur is None) else '__ospRefsManyW';
        result: es.Expression = self.sync_loc(
            es.CallExpression(
                callee=self.sync_loc(es.Identifier(name=hop_fn), jac_node=nd),
                arguments=hop_args
            ),
            jac_node=nd
        );
        if _step_filter is not None {
            pred = self._build_osp_filter_pred(nd, _step_filter);
            if pred is None {
                return fail;
            }
            result = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.MemberExpression(
                            object=result,
                            property=self.sync_loc(
                                es.Identifier(name='filter'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    arguments=[
                        self.sync_loc(
                            es.ArrowFunctionExpression(
                                params=[
                                    self.sync_loc(es.Identifier(name='x'), jac_node=nd)
                                ],
                                body=pred,
                                expression=True
                            ),
                            jac_node=nd
                        )
                    ]
                ),
                jac_node=nd
            );
        }
        cur = result;
    }
    if (cur is None) or (_idx != len(chain)) {
        self.emit(E5097, node_override=nd, kind="this edge reference shape");
        return fail;
    }
    return cur;
}

impl EsastGenPass._build_osp_filter_pred(
    nd: uni.UniNode, filt: uni.FilterCompr
) -> (es.Expression | None) {
    import from jaclang.compiler.frontend.diagnostics { E5097 }
    parts: list[es.Expression] = [];
    if filt.f_type is not None {
        _ntag = self._edge_tag_literal(nd, filt.f_type, True);
        if _ntag < 0 {
            return None;
        }
        parts.append(
            self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(es.Identifier(name='__ospIsA'), jac_node=nd),
                    arguments=[
                        self.sync_loc(
                            es.LogicalExpression(
                                operator='??',
                                left=self.sync_loc(
                                    es.MemberExpression(
                                        object=self.sync_loc(
                                            es.Identifier(name='x'), jac_node=nd
                                        ),
                                        property=self.sync_loc(
                                            es.Identifier(name='__tag'), jac_node=nd
                                        ),
                                        computed=False
                                    ),
                                    jac_node=nd
                                ),
                                right=self.sync_loc(es.Literal(value=-1), jac_node=nd)
                            ),
                            jac_node=nd
                        ),
                        self.sync_loc(es.Literal(value=_ntag), jac_node=nd)
                    ]
                ),
                jac_node=nd
            )
        );
    }
    for cmp in filt.compares {
        _lhs = cmp.left;
        _js_op: (str | None) = None;
        if isinstance(_lhs, uni.Name)
            and (len(cmp.ops) == 1)
            and (len(cmp.rights) == 1) {
            _op_name = cmp.ops[0].name;
            _op_tok = Tok(_op_name) if (_op_name in Tok.__members__) else None;
            if _op_tok in (Tok.EE, Tok.NE, Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                _js_op = ES_COMPARISON_OPS.get(_op_tok);
            }
        }
        if (_js_op is None) or (not isinstance(_lhs, uni.Name)) {
            self.emit(
                E5097,
                node_override=nd,
                kind="a graph filter outside 'name <op> value' form"
            );
            return None;
        }
        rhs = cast(
            es.Expression,
            self._get_ast_or_default(
                cmp.rights[0],
                default_factory=lambda (_src: any) { es.Literal(value=None); }
            )
        );
        parts.append(
            self.sync_loc(
                es.BinaryExpression(
                    operator=_js_op,
                    left=self.sync_loc(
                        es.MemberExpression(
                            object=self.sync_loc(es.Identifier(name='x'), jac_node=nd),
                            property=self.sync_loc(
                                es.Identifier(name=_lhs.sym_name), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    right=rhs
                ),
                jac_node=nd
            )
        );
    }
    if not parts {
        return self.sync_loc(es.Literal(value=True), jac_node=nd);
    }
    pred = parts[0];
    for part in parts[1:] {
        pred = self.sync_loc(
            es.LogicalExpression(operator='&&', left=pred, right=part), jac_node=nd
        );
    }
    return pred;
}

impl EsastGenPass._build_osp_graph_call(
    nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
) -> (es.Expression | None) {
    co = nd.op;
    if not isinstance(co, uni.ConnectOp) {
        return None;
    }
    self.needs_osp_graph = True;
    dir_val = int(co.edge_dir.value);

    undirected = dir_val == 3;
    if dir_val == 1 {
        (src, tgt) = (right, left);
    } else {
        (src, tgt) = (left, right);
    }
    edge_tag = -1;
    edge_body: es.Expression;
    if co.conn_type is None {
        edge_body = self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd);
    } else {
        edge_tag = self._edge_tag_literal(nd, co.conn_type, False);
        if isinstance(co.conn_type, uni.Name) {
            edge_body = self.sync_loc(
                es.NewExpression(
                    callee=self.sync_loc(
                        es.Identifier(name=co.conn_type.sym_name), jac_node=co.conn_type
                    ),
                    arguments=[]
                ),
                jac_node=nd
            );
        } else {
            edge_body = cast(
                es.Expression,
                self._get_ast_or_default(
                    co.conn_type,
                    default_factory=lambda (_src: any) { es.ObjectExpression(
                        properties=[]
                    ); }
                )
            );
        }
    }
    make_edge = self.sync_loc(
        es.ArrowFunctionExpression(params=[], body=edge_body, expression=True),
        jac_node=nd
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospConnW'), jac_node=nd),
            arguments=[
                src,
                tgt,
                make_edge,
                self.sync_loc(es.Literal(value=undirected), jac_node=nd),
                self.sync_loc(es.Literal(value=edge_tag), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_osp_disconnect_call(
    nd: uni.BinaryExpr, left: es.Expression, right: es.Expression
) -> es.Expression {
    self.needs_osp_graph = True;
    spec = cast(uni.DisconnectOp, nd.op).edge_spec;
    _fcond = spec.filter_cond;
    _edge_tag = self._edge_tag_literal(
        nd, _fcond.f_type if (_fcond is not None) else None, True
    );
    return self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(es.Identifier(name='__ospDiscBetweenW'), jac_node=nd),
            arguments=[
                left,
                right,
                self.sync_loc(es.Literal(value=int(spec.edge_dir.value)), jac_node=nd),
                self.sync_loc(es.Literal(value=_edge_tag), jac_node=nd)
            ]
        ),
        jac_node=nd
    );
}

impl EsastGenPass.exit_enum(nd: uni.Enum) -> None {
    if nd.code_context == CodeContext.CLIENT {
        self.client_manifest.has_client = True;
        is_pub = nd.access and (nd.access.tag.name == Tok.KW_PUB);
        if is_pub or nd.codespace_dual {
            self.client_manifest.exports.append(nd.name.sym_name);
        }
    }
    properties: list[(es.Property | es.SpreadElement)] = [];
    inner = self.unwrap_body(nd);
    next_auto = 1;
    if inner {
        for stmt in inner {
            if isinstance(stmt, uni.Assignment) {
                for target in stmt.target {
                    if isinstance(target, uni.AstSymbolNode) {
                        key = self.sync_loc(
                            es.Identifier(name=target.sym_name), jac_node=target
                        );
                        enum_value: es.Expression;
                        if (stmt.value and stmt.value.gen.es_ast) {
                            enum_value = cast(es.Expression, stmt.value.gen.es_ast);
                            if (
                                isinstance(enum_value, es.Literal)
                                and isinstance(enum_value.value, int)
                                and not isinstance(enum_value.value, bool)
                            ) {
                                next_auto = enum_value.value + 1;
                            }
                        } else {
                            enum_value = self.sync_loc(
                                es.Literal(value=next_auto), jac_node=stmt
                            );
                            next_auto += 1;
                        }
                        prop = self.sync_loc(
                            es.Property(key=key, value=enum_value, kind='init'),
                            jac_node=stmt
                        );
                        properties.append(prop);
                    }
                }
            }
        }
    }
    obj_expr = self.sync_loc(es.ObjectExpression(properties=properties), jac_node=nd);
    var_id = self.sync_loc(es.Identifier(name=nd.name.sym_name), jac_node=nd.name);
    var_decl = self.sync_loc(
        es.VariableDeclaration(
            declarations=[
                self.sync_loc(
                    es.VariableDeclarator(id=var_id, `init=obj_expr), jac_node=nd
                )
            ],
            kind='const'
        ),
        jac_node=nd
    );
    nd.gen.es_ast = var_decl;
}

impl EsastGenPass.exit_type_alias(nd: uni.TypeAlias) -> None {
    nd.gen.es_ast = [];
}

impl EsastGenPass.exit_type_param(nd: uni.TypeParam) -> None {
    nd.gen.es_ast = [];
}

impl EsastGenPass.exit_sub_tag(nd: uni.SubTag[uni.T]) -> None {
    if nd.tag.gen.es_ast {
        nd.gen.es_ast = nd.tag.gen.es_ast;
    }
}

impl EsastGenPass.populate_client_manifest(nd: uni.Module) -> None {
    for (ename, eeffect) in nd.gen.interop_manifest.endpoint_effects.items() {
        self.client_manifest.endpoint_effects[ename] = eeffect;
    }
}

impl EsastGenPass._es_json_literal(value: any) -> any {
    if isinstance(value, list) {
        return es.ArrayExpression(elements=[self._es_json_literal(v) for v in value]);
    }
    if isinstance(value, dict) {
        return es.ObjectExpression(
            properties=[
                es.Property(
                    key=es.Literal(value=k), value=self._es_json_literal(v), kind='init'
                ) for (k, v) in value.items()
            ]
        );
    }
    return es.Literal(value=value);
}

impl EsastGenPass._emit_boundary_type_stubs(nd: uni.Module) -> list[es.Statement] {
    manifest = nd.gen.interop_manifest;
    if not manifest.boundary_types {
        return [];
    }
    stubs: list[es.Statement] = [];

    osp_class_map: dict[str, es.ClassDeclaration] = {};
    for item in self._merge_module_bodies(nd) {
        if (
            isinstance(item, uni.Archetype)
            and (item.name is not None)
            and isinstance(item.gen.es_ast, es.ClassDeclaration)
        ) {
            osp_class_map[item.name.sym_name] = item.gen.es_ast;
        }
    }
    for (type_name, info) in manifest.boundary_types.items() {
        if info.kind == "enum" {
            enum_props: list[es.Property] = [];
            for (member_name, member_val) in info.enum_members {
                key = es.Identifier(name=member_name);
                val = es.Literal(
                    value=member_val if member_val is not None else member_name
                );
                enum_props.append(
                    es.Property(
                        key=key,
                        value=val,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            obj_expr = es.CallExpression(
                callee=es.MemberExpression(
                    object=es.Identifier(name='Object'),
                    property=es.Identifier(name='freeze'),
                    computed=False
                ),
                arguments=[es.ObjectExpression(properties=enum_props)]
            );
            decl = es.VariableDeclaration(
                declarations=[
                    es.VariableDeclarator(
                        id=es.Identifier(name=type_name), init=obj_expr
                    )
                ],
                kind='const'
            );
            stubs.append(decl);
        } else {
            field_names = [f[0] for f in info.fields];
            field_types = {f[0]: f[1] for f in info.fields};
            ctor_stmts: list[es.Statement] = [];
            for fname in field_names {
                fallback = self._es_json_literal(info.field_defaults[fname])
                    if fname in info.field_defaults
                    else es.Literal(value=None);
                assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            `test=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='props'),
                                    property=es.Identifier(name='hasOwnProperty'),
                                    computed=False
                                ),
                                arguments=[es.Literal(value=fname)]
                            ),
                            consequent=es.MemberExpression(
                                object=es.Identifier(name='props'),
                                property=es.Identifier(name=fname),
                                computed=False
                            ),
                            alternate=fallback
                        )
                    )
                );
                ctor_stmts.append(assign);
            }
            if info.kind == "node" {
                jac_id_assign = es.ExpressionStatement(
                    expression=es.AssignmentExpression(
                        operator='=',
                        left=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name='_jac_id'),
                            computed=False
                        ),
                        right=es.ConditionalExpression(
                            `test=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='props'),
                                    property=es.Identifier(name='hasOwnProperty'),
                                    computed=False
                                ),
                                arguments=[es.Literal(value='_jac_id')]
                            ),
                            consequent=es.MemberExpression(
                                object=es.Identifier(name='props'),
                                property=es.Identifier(name='_jac_id'),
                                computed=False
                            ),
                            alternate=es.Literal(value=None)
                        )
                    )
                );
                ctor_stmts.append(jac_id_assign);
            }
            ctor = es.FunctionExpression(
                id=None,
                params=[
                    es.AssignmentPattern(
                        left=es.Identifier(name='props'),
                        right=es.ObjectExpression(properties=[])
                    )
                ],
                body=es.BlockStatement(body=ctor_stmts),
                generator=False,
                async_=False
            );
            ctor_def = es.MethodDefinition(
                key=es.Identifier(name='constructor'),
                value=ctor,
                kind='constructor',
                `static=False,
                computed=False
            );
            from_wire_stmts: list[es.Statement] = [];
            from_wire_stmts.append(
                es.IfStatement(
                    `test=es.LogicalExpression(
                        operator='||',
                        left=es.BinaryExpression(
                            operator='===',
                            left=es.Identifier(name='d'),
                            right=es.Literal(value=None)
                        ),
                        right=es.BinaryExpression(
                            operator='===',
                            left=es.Identifier(name='d'),
                            right=es.Identifier(name='undefined')
                        )
                    ),
                    consequent=es.ReturnStatement(argument=es.Identifier(name='d')),
                    alternate=None
                )
            );
            nested_set = set(info.nested_types);
            for fname in field_names {
                ftype = field_types[fname];

                inner_type = None;
                is_list = False;
                is_dict = False;
                if ftype in nested_set {
                    inner_type = ftype;
                } elif ftype.startswith("list[") and ftype.endswith("]") {
                    inner = ftype[5:-1];
                    if inner in nested_set {
                        inner_type = inner;
                        is_list = True;
                    }
                } elif ftype.startswith("dict[") and ftype.endswith("]") {
                    dict_params = ftype[5:-1];
                    comma_pos = dict_params.find(', ');
                    if comma_pos >= 0 {
                        val_type = dict_params[comma_pos + 2:].strip();
                        if val_type in nested_set {
                            inner_type = val_type;
                            is_dict = True;
                        }
                    }
                }
                if inner_type {
                    if is_dict {
                        entries_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=es.Identifier(name='Object'),
                                property=es.Identifier(name='entries'),
                                computed=False
                            ),
                            arguments=[
                                es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                )
                            ]
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
                                                    object=es.Identifier(
                                                        name=inner_type
                                                    ),
                                                    property=es.Identifier(
                                                        name='__from_wire'
                                                    ),
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
                        from_entries_call = es.CallExpression(
                            callee=es.MemberExpression(
                                object=es.Identifier(name='Object'),
                                property=es.Identifier(name='fromEntries'),
                                computed=False
                            ),
                            arguments=[map_call]
                        );
                        from_wire_stmts.append(
                            es.IfStatement(
                                `test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=from_entries_call
                                    )
                                ),
                                alternate=None
                            )
                        );
                    } elif is_list {
                        from_wire_stmts.append(
                            es.IfStatement(
                                `test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.MemberExpression(
                                                    object=es.Identifier(name='d'),
                                                    property=es.Identifier(name=fname),
                                                    computed=False
                                                ),
                                                property=es.Identifier(name='map'),
                                                computed=False
                                            ),
                                            arguments=[
                                                es.ArrowFunctionExpression(
                                                    params=[es.Identifier(name='x')],
                                                    body=es.CallExpression(
                                                        callee=es.MemberExpression(
                                                            object=es.Identifier(
                                                                name=inner_type
                                                            ),
                                                            property=es.Identifier(
                                                                name='__from_wire'
                                                            ),
                                                            computed=False
                                                        ),
                                                        arguments=[
                                                            es.Identifier(name='x')
                                                        ]
                                                    ),
                                                    expression=True,
                                                    async_=False
                                                )
                                            ]
                                        )
                                    )
                                ),
                                alternate=None
                            )
                        );
                    } else {
                        from_wire_stmts.append(
                            es.IfStatement(
                                `test=es.MemberExpression(
                                    object=es.Identifier(name='d'),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.ExpressionStatement(
                                    expression=es.AssignmentExpression(
                                        operator='=',
                                        left=es.MemberExpression(
                                            object=es.Identifier(name='d'),
                                            property=es.Identifier(name=fname),
                                            computed=False
                                        ),
                                        right=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name=inner_type),
                                                property=es.Identifier(
                                                    name='__from_wire'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[
                                                es.MemberExpression(
                                                    object=es.Identifier(name='d'),
                                                    property=es.Identifier(name=fname),
                                                    computed=False
                                                )
                                            ]
                                        )
                                    )
                                ),
                                alternate=None
                            )
                        );
                    }
                }
            }
            from_wire_stmts.append(
                es.ReturnStatement(
                    argument=es.NewExpression(
                        callee=es.Identifier(name=type_name),
                        arguments=[es.Identifier(name='d')]
                    )
                )
            );
            from_wire_fn = es.FunctionExpression(
                id=None,
                params=[es.Identifier(name='d')],
                body=es.BlockStatement(body=from_wire_stmts),
                generator=False,
                async_=False
            );
            from_wire_def = es.MethodDefinition(
                key=es.Identifier(name='__from_wire'),
                value=from_wire_fn,
                kind='method',
                `static=True,
                computed=False
            );
            to_wire_props: list[es.Property] = [];
            to_wire_props.append(
                es.Property(
                    key=es.Literal(value='__type__'),
                    value=es.Literal(value=type_name),
                    kind='init',
                    method=False,
                    shorthand=False,
                    computed=False
                )
            );
            for fname in field_names {
                ftype = field_types[fname];
                value_expr: es.Expression = es.MemberExpression(
                    object=es.ThisExpression(),
                    property=es.Identifier(name=fname),
                    computed=False
                );

                if ftype in nested_set {
                    value_expr = es.ConditionalExpression(
                        `test=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name=fname),
                            computed=False
                        ),
                        consequent=es.CallExpression(
                            callee=es.MemberExpression(
                                object=value_expr,
                                property=es.Identifier(name='__to_wire'),
                                computed=False
                            ),
                            arguments=[]
                        ),
                        alternate=es.Literal(value=None)
                    );
                } elif ftype.startswith("list[") and ftype.endswith("]") {
                    inner = ftype[5:-1];
                    if inner in nested_set {
                        value_expr = es.ConditionalExpression(
                            `test=es.MemberExpression(
                                object=es.ThisExpression(),
                                property=es.Identifier(name=fname),
                                computed=False
                            ),
                            consequent=es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.MemberExpression(
                                        object=es.ThisExpression(),
                                        property=es.Identifier(name=fname),
                                        computed=False
                                    ),
                                    property=es.Identifier(name='map'),
                                    computed=False
                                ),
                                arguments=[
                                    es.ArrowFunctionExpression(
                                        params=[es.Identifier(name='x')],
                                        body=es.CallExpression(
                                            callee=es.MemberExpression(
                                                object=es.Identifier(name='x'),
                                                property=es.Identifier(
                                                    name='__to_wire'
                                                ),
                                                computed=False
                                            ),
                                            arguments=[]
                                        ),
                                        expression=True,
                                        async_=False
                                    )
                                ]
                            ),
                            alternate=es.ArrayExpression(elements=[])
                        );
                    }
                } elif ftype.startswith("dict[") and ftype.endswith("]") {
                    dict_params = ftype[5:-1];
                    comma_pos = dict_params.find(', ');
                    if comma_pos >= 0 {
                        val_type = dict_params[comma_pos + 2:].strip();
                        if val_type in nested_set {
                            this_field = es.MemberExpression(
                                object=es.ThisExpression(),
                                property=es.Identifier(name=fname),
                                computed=False
                            );
                            entries_call = es.CallExpression(
                                callee=es.MemberExpression(
                                    object=es.Identifier(name='Object'),
                                    property=es.Identifier(name='entries'),
                                    computed=False
                                ),
                                arguments=[this_field]
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
                                                        object=es.Identifier(name='v'),
                                                        property=es.Identifier(
                                                            name='__to_wire'
                                                        ),
                                                        computed=False
                                                    ),
                                                    arguments=[]
                                                )
                                            ]
                                        ),
                                        expression=True,
                                        async_=False
                                    )
                                ]
                            );
                            value_expr = es.ConditionalExpression(
                                `test=es.MemberExpression(
                                    object=es.ThisExpression(),
                                    property=es.Identifier(name=fname),
                                    computed=False
                                ),
                                consequent=es.CallExpression(
                                    callee=es.MemberExpression(
                                        object=es.Identifier(name='Object'),
                                        property=es.Identifier(name='fromEntries'),
                                        computed=False
                                    ),
                                    arguments=[map_call]
                                ),
                                alternate=es.ObjectExpression(properties=[])
                            );
                        }
                    }
                }
                to_wire_props.append(
                    es.Property(
                        key=es.Literal(value=fname),
                        value=value_expr,
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            if info.kind == "node" {
                to_wire_props.append(
                    es.Property(
                        key=es.Literal(value='_jac_id'),
                        value=es.MemberExpression(
                            object=es.ThisExpression(),
                            property=es.Identifier(name='_jac_id'),
                            computed=False
                        ),
                        kind='init',
                        method=False,
                        shorthand=False,
                        computed=False
                    )
                );
            }
            to_wire_fn = es.FunctionExpression(
                id=None,
                params=[],
                body=es.BlockStatement(
                    body=[
                        es.ReturnStatement(
                            argument=es.ObjectExpression(properties=to_wire_props)
                        )
                    ]
                ),
                generator=False,
                async_=False
            );
            to_wire_def = es.MethodDefinition(
                key=es.Identifier(name='__to_wire'),
                value=to_wire_fn,
                kind='method',
                `static=False,
                computed=False
            );
            osp_class = osp_class_map.get(type_name);
            if osp_class is not None {
                if info.kind == "node" {
                    for member in osp_class.body.body {
                        if (
                            isinstance(member, es.MethodDefinition)
                            and (member.kind == "constructor")
                        ) {
                            member.value.body.body.append(
                                es.IfStatement(
                                    `test=es.CallExpression(
                                        callee=es.MemberExpression(
                                            object=es.Identifier(name='props'),
                                            property=es.Identifier(
                                                name='hasOwnProperty'
                                            ),
                                            computed=False
                                        ),
                                        arguments=[es.Literal(value='_jac_id')]
                                    ),
                                    consequent=es.ExpressionStatement(
                                        expression=es.AssignmentExpression(
                                            operator='=',
                                            left=es.MemberExpression(
                                                object=es.ThisExpression(),
                                                property=es.Identifier(name='_jac_id'),
                                                computed=False
                                            ),
                                            right=es.MemberExpression(
                                                object=es.Identifier(name='props'),
                                                property=es.Identifier(name='_jac_id'),
                                                computed=False
                                            )
                                        )
                                    ),
                                    alternate=None
                                )
                            );
                        }
                    }
                }
                osp_class.body.body.append(from_wire_def);
                osp_class.body.body.append(to_wire_def);
            } else {
                class_body = es.ClassBody(body=[ctor_def, from_wire_def, to_wire_def]);
                class_decl = es.ClassDeclaration(
                    id=es.Identifier(name=type_name), superClass=None, body=class_body
                );
                stubs.append(class_decl);
            }
        }
    }
    return stubs;
}

impl EsastGenPass.exit_module(nd: uni.Module) -> None {
    import from jaclang.compiler.symbol_utils { report_client_bare_import_uses }
    report_client_bare_import_uses(self, nd);
    server_forwarders = self._bind_client_value_refs(nd);
    if (self.scoped_styles is not None and self.scoped_styles.class_map) {
        import os;
        nd.gen.css = self.scoped_styles.scoped_css;
        base = os.path.basename(self.scoped_styles.css_path);
        if base.endswith('.style.css') {
            base = base[:-len('.style.css')];
        }
        css_import = f"./{base}.css";
        css_source = self.sync_loc(
            es.Literal(value=css_import, raw=f'"{css_import}"'), jac_node=nd
        );
        self.imports.insert(
            0,
            self.sync_loc(
                es.ImportDeclaration(specifiers=[], source=css_source), jac_node=nd
            )
        );
    }
    body: list[(es.Statement | es.ModuleDeclaration)] = [];
    body.extend(self.imports);

    body.extend(self.sv_import_stubs);
    body.extend(self.na_import_stubs);

    body.extend(self._emit_boundary_type_stubs(nd));
    body.extend(server_forwarders);
    scope = self.scope_map.get(nd);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        body.extend(hoisted);
    }

    if self.needs_osp_graph or self.needs_osp_kernel {
        self.needs_jac_runtime = True;
    }
    if self.needs_jac_runtime {
        import from jaclang.compiler.backends.es.jac_runtime_js {
            build_jac_runtime_js
        }
        jac_rt_decl = es.VariableDeclaration(
            declarations=[
                es.VariableDeclarator(
                    id=es.Identifier(name='_jac'),
                    init=es.Identifier(name=build_jac_runtime_js())
                )
            ],
            kind='const'
        );
        body.append(jac_rt_decl);
    }
    merged_body = self._merge_module_bodies(nd);
    client_items: list[es.Statement | list[es.Statement] | None] = [];
    fallback_items: list[es.Statement | list[es.Statement] | None] = [];
    for stmt in merged_body {
        if stmt.gen.es_ast {
            is_shared_arch = (
                isinstance(stmt, uni.Archetype)
                and (stmt.name is not None)
                and (stmt.name.value in self.shared_arch_names)
            );
            if (getattr(stmt, 'code_context', CodeContext.CLIENT) == CodeContext.CLIENT)
                or is_shared_arch {
                client_items.append(cast(es.Statement, stmt.gen.es_ast));
            } else {
                ;
            }
        }
    }
    target_body = client_items or fallback_items;
    body.extend(self._flatten_ast_list(target_body));

    if self.needs_osp_graph or self.needs_osp_kernel {
        import from jaclang.compiler.backends.es.jac_runtime_js {
            build_osp_core_js,
            build_osp_driver_js
        }
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=build_osp_core_js())
                ),
                jac_node=nd
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=build_osp_driver_js())
                ),
                jac_node=nd
            )
        );
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=self._build_osp_tags_js())
                ),
                jac_node=nd
            )
        );
    }
    if self.needs_osp_kernel {
        body.append(
            self.sync_loc(
                es.ExpressionStatement(
                    expression=es.Identifier(name=self._build_osp_setup_js())
                ),
                jac_node=nd
            )
        );
    }
    body.extend(self.exports);
    self.populate_client_manifest(nd);
    self.client_manifest.exports.sort();
    self.client_manifest.globals.sort();
    module_export_names = sorted(
        set(self.client_manifest.exports + self.client_manifest.globals)
    );
    if module_export_names {
        export_specifiers: list[es.ExportSpecifier] = [];
        for name in module_export_names {
            export_specifiers.append(
                es.ExportSpecifier(
                    exported=es.Identifier(name=name), local=es.Identifier(name=name)
                )
            );
        }

        if (
            not self.client_manifest.globals
            and all(name in self.component_export_names for name in module_export_names)
        ) {
            body.append(
                self.sync_loc(
                    es.ExpressionStatement(
                        expression=es.Identifier(name='/*jac:refresh-boundary*/')
                    ),
                    jac_node=nd
                )
            );
        }
        comprehensive_export = es.ExportNamedDeclaration(
            declaration=None, specifiers=export_specifiers, source=None
        );
        body.append(comprehensive_export);
    }

    if self.client_manifest.endpoint_effects {
        import json as _json;
        effects_json = _json.dumps(self.client_manifest.endpoint_effects);
        register_code = (
            'if (typeof globalThis !== "undefined") {'
            ' if (!globalThis.__jacEndpointEffects__) globalThis.__jacEndpointEffects__ = {};'
            f' Object.assign(globalThis.__jacEndpointEffects__, {effects_json});'
            ' }'
        );
        body.append(
            es.ExpressionStatement(expression=es.Identifier(name=register_code))
        );
    }
    program = self.sync_loc(es.Program(body=body), jac_node=nd);
    nd.gen.es_ast = program;
    nd.gen.js = es_to_js(nd.gen.es_ast);
    nd.gen.client_manifest = self.client_manifest;
    self._audit_free_identifiers(nd, program);
}

impl EsastGenPass._audit_free_identifiers(nd: uni.Module, program: es.Program) -> None {
    if not self.client_manifest.has_client {
        return;
    }
    allowed = client_ambient_globals() | RUNTIME_PRELUDE_GLOBALS;
    frees = free_identifiers(program, allowed);
    if not frees {
        return;
    }
    names = nd.get_all_sub_nodes(typ=uni.Name);
    reported: set[str] = set();
    for free in frees {
        if (free.name in reported) or (free.name in self._unbound_reported) {
            continue;
        }
        origin: (uni.Name | None) = None;
        imported = False;
        for cand in names {
            if (cand.value != free.name) or (cand.sym is None) {
                continue;
            }
            if cand.sym.decl.find_parent_of_type(uni.Import) is not None {
                imported = True;
                break;
            }
            origin = cand;
            if cand.loc.first_line == free.line {
                break;
            }
        }
        if imported or (origin is None) {
            continue;
        }
        reported.add(free.name);
        self.emit(E5101, node_override=origin, name=free.name);
    }
}

impl EsastGenPass._build_block_statement(
    scope_node: uni.UniScopeNode, body_nodes: (Sequence[uni.UniNode] | None)
) -> es.BlockStatement {
    statements = self._collect_stmt_body(body_nodes);
    statements = self._prepend_hoisted(scope_node, statements);
    return self.sync_loc(es.BlockStatement(body=statements), jac_node=scope_node);
}

impl EsastGenPass._get_ast_or_default(
    nd: (uni.UniNode | None), default_factory: Callable[([(uni.UniNode | None)], _T)]
) -> _T {
    if (nd and nd.gen.es_ast) {
        generated = nd.gen.es_ast;
        if isinstance(generated, es.Node) {
            return cast(_T, generated);
        }
    }
    if (
        isinstance(nd, uni.Expr)
        and (nd.gen.es_ast is None)
        and (nd not in self._unlowered_reported)
        and self._is_client_destined(nd)
    ) {
        import from jaclang.compiler.frontend.diagnostics { E5097 }
        self._unlowered_reported.add(nd);
        self.emit(E5097, node_override=nd, kind=nd.__class__.__name__);
    }
    fallback = default_factory(nd);
    jac_ref = nd if (nd is not None) else self.cur_node;
    return self.sync_loc(fallback, jac_node=jac_ref);
}

impl EsastGenPass._is_client_destined(nd: uni.UniNode) -> bool {
    cur: (uni.UniNode | None) = nd;
    while cur is not None {
        if isinstance(cur, uni.ContextAwareNode) {
            return (cur.code_context == CodeContext.CLIENT) or cur.codespace_dual;
        }
        cur = cur.parent;
    }
    return False;
}

impl EsastGenPass._collect_stmt_body(
    body: (Sequence[uni.UniNode] | None)
) -> list[es.Statement] {
    if not body {
        return [];
    }
    statements: list[es.Statement] = [];
    for stmt in body {
        if isinstance(stmt, uni.Semi) {
            continue;
        }
        generated = stmt.gen.es_ast;
        if isinstance(generated, list) {
            statements.extend(
                item
                for item in generated
                if isinstance(item, es.Statement)
            );
        } elif isinstance(generated, es.Statement) {
            statements.append(generated);
        } elif (
            generated is None
            and isinstance(stmt, uni.CodeBlockStmt)
            and not isinstance(stmt, uni.Import)
        ) {
            cls_name = stmt.__class__.__name__;
            self.emit(
                E5017,
                node_override=stmt,
                construct=ES_STMT_DISPLAY.get(cls_name, cls_name)
            );
        }
    }
    return statements;
}

impl EsastGenPass._expr_from_node(
    nd: (uni.UniNode | None), `default: LiteralValue = None
) -> es.Expression {
    generated = self._get_ast_or_default(
        nd, default_factory=lambda (src: any) { es.Literal(value=`default); }
    );
    if isinstance(generated, es.Expression) {
        return generated;
    }
    self.emit(E5011, node_override=nd);
    return self.sync_loc(es.Literal(value=`default), jac_node=(nd or self.cur_node));
}

impl EsastGenPass.get_main_mod -> uni.Module {
    main_mod_path = self.ir_in.annexable_by or self.ir_in.loc.mod_path;
    mod = self.prog.mod.hub.get(main_mod_path);
    if not isinstance(mod, uni.Module) {
        self.emit(E5012);
    }
    return mod;
}

impl EsastGenPass._prepend_hoisted(
    nd: uni.UniScopeNode, statements: list[es.Statement]
) -> list[es.Statement] {
    scope = self.scope_map.get(nd);
    if (scope and scope.hoisted) {
        hoisted = list(scope.hoisted);
        scope.hoisted.clear();
        return (hoisted + statements);
    }
    return statements;
}

impl EsastGenPass._declaring_scope_for(name_node: uni.UniNode) -> (ScopeInfo | None) {
    if not isinstance(name_node, uni.AstSymbolNode) {
        return None;
    }
    sym = name_node.sym;
    if (sym is None) or (sym.parent_tab is None) {
        return None;
    }
    owner = sym.parent_tab;
    if not isinstance(
        owner, (uni.Module, uni.Ability, uni.ImplDef, uni.Test, uni.LambdaExpr)
    ) {
        return None;
    }
    if isinstance(owner, uni.ImplDef) {
        if not isinstance(owner.decl_link, uni.Ability) {
            return None;
        }
        owner = owner.decl_link;
    }
    for scope in reversed(self.scope_stack) {
        if scope.nd is owner {
            return scope;
        }
    }
    return None;
}

impl EsastGenPass._hoist_into(
    scope: ScopeInfo, name: str, jac_node: uni.UniNode
) -> None {
    if name in scope.declared {
        return;
    }
    ident = self.sync_loc(es.Identifier(name=name), jac_node=jac_node);
    declarator = self.sync_loc(
        es.VariableDeclarator(id=ident, `init=None), jac_node=jac_node
    );
    decl = self.sync_loc(
        es.VariableDeclaration(declarations=[declarator], kind='let'), jac_node=jac_node
    );
    scope.hoisted.append(decl);
    scope.declared.add(name);
}

impl EsastGenPass._ensure_identifier_declared(
    name: str, jac_node: uni.UniNode
) -> None {
    if self._is_declared_in_any_scope(name) {
        return;
    }
    scope = self._declaring_scope_for(jac_node) or self._current_scope();
    if not scope {
        return;
    }
    self._hoist_into(scope, name, jac_node);
}

impl EsastGenPass._register_declaration(name: str) -> None {
    scope = self._current_scope();
    if scope {
        scope.declared.add(name);
    }
}

impl EsastGenPass._is_declared_in_any_scope(name: str) -> bool {
    return any((name in scope.declared) for scope in reversed(self.scope_stack));
}

impl EsastGenPass._current_scope -> (ScopeInfo | None) {
    return self.scope_stack[-1] if self.scope_stack else None;
}

impl EsastGenPass._pop_scope(nd: uni.UniScopeNode) -> None {
    if (self.scope_stack and (self.scope_stack[-1].nd is nd)) {
        info = self.scope_stack.pop();
        if info.hoisted {
            names: list[str] = [];
            for decl in info.hoisted {
                if not isinstance(decl, es.VariableDeclaration) {
                    continue;
                }
                for declarator in decl.declarations {
                    ident = declarator.id;
                    if isinstance(ident, es.Identifier) {
                        names.append(f"'{ident.name}'");
                    }
                }
            }
            self.emit(
                E5085,
                node_override=nd,
                names=", ".join(names) or "<unknown>",
                scope=type(nd).__name__
            );
        }
    }
}

impl EsastGenPass._push_scope(nd: uni.UniScopeNode) -> None {
    info = ScopeInfo(nd=nd);
    self.scope_stack.append(info);
    self.scope_map[nd] = info;
}

impl EsastGenPass._alt_branch_scope_to_finalize(
    nd: uni.UniNode
) -> (uni.UniScopeNode | None) {
    parent = nd.parent;
    if parent is None {
        return None;
    }

    if (
        (isinstance(nd, uni.ElseStmt) or isinstance(nd, uni.ElseIf))
        and isinstance(parent, uni.IfStmt)
        and (parent.else_body is nd)
    ) {
        return parent;
    }

    if isinstance(parent, uni.TryStmt) {
        if isinstance(nd, uni.Except) and (nd in parent.excepts) {
            return parent;
        }
        if isinstance(nd, uni.FinallyStmt) and (parent.finally_body is nd) {
            return parent;
        }
        if isinstance(nd, uni.ElseStmt) and (parent.else_body is nd) {
            return parent;
        }
    }

    if (
        isinstance(nd, uni.ElseStmt)
        and isinstance(parent, (uni.WhileStmt, uni.IterForStmt, uni.InForStmt))
        and (parent.else_body is nd)
    ) {
        return parent;
    }
    return None;
}

impl EsastGenPass.sync_loc(es_node: _T, jac_node: (uni.UniNode | None) = None) -> _T {
    if not jac_node {
        jac_node = self.cur_node;
    }
    es_node.loc = es.SourceLocation(
        start=es.Position(line=jac_node.loc.first_line, column=jac_node.loc.col_start),
        end=es.Position(line=jac_node.loc.last_line, column=jac_node.loc.col_end)
    );
    return es_node;
}

impl EsastGenPass.exit_node(nd: uni.UniNode) -> None {
    if (
        isinstance(nd, uni.ElementStmt)
        and isinstance(nd, uni.ContextAwareNode)
        and nd.code_context != CodeContext.CLIENT
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        is_sv_import = isinstance(nd, uni.Import) and nd.is_service_import;

        is_native_edge = isinstance(nd, uni.Import)
            and self._is_client_native_import(nd);
        is_shared_arch = (
            isinstance(nd, uni.Archetype)
            and (nd.name is not None)
            and (nd.name.value in self.shared_arch_names)
        );
        if (not is_sv_import and not is_native_edge and not is_shared_arch) {
            return;
        }
    }
    super.exit_node(nd);
    if isinstance(nd, uni.UniScopeNode) {
        self._pop_scope(nd);

        self.scope_map.pop(nd, None);
    }
}

impl EsastGenPass.enter_node(nd: uni.UniNode) -> None {
    if (
        isinstance(nd, uni.ElementStmt)
        and isinstance(nd, uni.ContextAwareNode)
        and nd.code_context != CodeContext.CLIENT
        and ((nd.parent is None) or isinstance(nd.parent, uni.Module))
    ) {
        is_sv_import = isinstance(nd, uni.Import) and nd.is_service_import;

        is_shared_arch = (
            isinstance(nd, uni.Archetype)
            and (nd.name is not None)
            and (nd.name.value in self.shared_arch_names)
        );
        is_native_edge = isinstance(nd, uni.Import)
            and self._is_client_native_import(nd);
        if (not is_sv_import and not is_native_edge and not is_shared_arch) {
            self.prune();
            return;
        }
    }
    if isinstance(nd, uni.UniScopeNode) {
        scope_to_finalize = self._alt_branch_scope_to_finalize(nd);
        if scope_to_finalize is not None {
            self._pop_scope(scope_to_finalize);
        }
        self._push_scope(nd);
    }
    if nd.gen.es_ast {
        if not (isinstance(nd, uni.Import) and nd.code_context != CodeContext.CLIENT) {
            self.prune();
            return;
        }
    }
    super.enter_node(nd);
}

impl EsastGenPass.before_pass -> None {
    import from jaclang.compiler.frontend.codeinfo { ClientManifest }

    import from jaclang.compiler.backends.py.module_codegen_pass {
        client_capability_violations
    }
    import from jaclang.compiler.frontend.diagnostics { E5096 }
    if not self.ir_in.client_viols_reported {
        for (_vnode, _vkind) in client_capability_violations(self.ir_in) {
            self.emit(E5096, node_override=_vnode, kind=_vkind);
        }
        self.ir_in.client_viols_reported = True;
    }
    self.child_passes = self._init_child_passes(EsastGenPass);
    self.client_manifest = ClientManifest();
    self.component_export_names = set();

    self.client_manifest.endpoint_effects = dict(
        self.ir_in.gen.interop_manifest.endpoint_effects
    );

    import from jaclang.compiler.backends.py.module_codegen_pass { ModuleCodegenPass }
    self.shared_arch_names: set[str] = {
        a.name.value
        for a in ModuleCodegenPass.shared_archetypes_for_context(
            self.ir_in, CodeContext.CLIENT
        )
        if a.name is not None
    };
    self.jsx_processor = EsJsxProcessor(self);

    self.scoped_styles = load_style_annex(
        self.ir_in.annexable_by or self.ir_in.loc.mod_path
    );
}
