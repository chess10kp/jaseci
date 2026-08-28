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
