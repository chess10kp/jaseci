impl EsastGenPass.exit_inner_compr(nd: uni.InnerCompr) -> None {
    ;
}

impl EsastGenPass.exit_list_compr(nd: uni.ListCompr) -> None {
    self._build_compr_chain(nd);
}

impl EsastGenPass.exit_set_compr(nd: uni.SetCompr) -> None {
    self._build_compr_chain(nd);
    if nd.gen.es_ast {
        nd.gen.es_ast = self.sync_loc(
            es.NewExpression(
                callee=self.sync_loc(es.Identifier(name='Set'), jac_node=nd),
                arguments=[cast(es.Expression, nd.gen.es_ast)]
            ),
            jac_node=nd
        );
    }
}

impl EsastGenPass.exit_gen_compr(nd: uni.GenCompr) -> None {
    self._build_compr_chain(nd);
}

impl EsastGenPass.exit_dict_compr(nd: uni.DictCompr) -> None {
    key_expr = cast(es.Expression, nd.kv_pair.key.gen.es_ast)
        if nd.kv_pair.key
        else None;
    val_expr = cast(es.Expression, nd.kv_pair.value.gen.es_ast);
    if not key_expr or not val_expr {
        nd.gen.es_ast = self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd);
        return;
    }

    out_expr = self.sync_loc(
        es.ArrayExpression(elements=[key_expr, val_expr]), jac_node=nd.kv_pair
    );

    chain = self._build_compr_expr(nd.compr, out_expr, nd);
    if not chain {
        nd.gen.es_ast = self.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd);
        return;
    }

    nd.gen.es_ast = self.sync_loc(
        es.CallExpression(
            callee=self.sync_loc(
                es.MemberExpression(
                    object=self.sync_loc(es.Identifier(name='Object'), jac_node=nd),
                    property=self.sync_loc(
                        es.Identifier(name='fromEntries'), jac_node=nd
                    ),
                    computed=False
                ),
                jac_node=nd
            ),
            arguments=[chain]
        ),
        jac_node=nd
    );
}

impl EsastGenPass._build_compr_chain(nd: uni.ListCompr) -> None {
    out_expr = cast(es.Expression, nd.out_expr.gen.es_ast);
    if not out_expr {
        nd.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
        return;
    }
    if not nd.compr or len(nd.compr) == 0 {
        nd.gen.es_ast = self.sync_loc(
            es.ArrayExpression(elements=[out_expr]), jac_node=nd
        );
        return;
    }
    result = self._build_compr_expr(nd.compr, out_expr, nd);
    if result {
        nd.gen.es_ast = result;
    } else {
        nd.gen.es_ast = self.sync_loc(es.ArrayExpression(elements=[]), jac_node=nd);
    }
}

impl EsastGenPass._build_compr_expr(
    comprs: list[uni.InnerCompr], out_expr: es.Expression, nd: uni.UniNode
) -> (es.Expression | None) {
    if not comprs or len(comprs) == 0 {
        return None;
    }

    result: (es.Expression | None) = None;
    i = len(comprs) - 1;
    while i >= 0 {
        compr = comprs[i];
        collection = cast(es.Expression, compr.collection.gen.es_ast);
        target = cast(es.Expression, compr.target.gen.es_ast);
        if not collection or not target {
            return None;
        }
        param = self._compr_param(target, compr.target);

        chain = collection;

        if compr.conditional {
            for cond in compr.conditional {
                cond_expr = cast(es.Expression, cond.gen.es_ast);
                if cond_expr {
                    filter_arrow = self.sync_loc(
                        es.ArrowFunctionExpression(
                            params=[param], body=cond_expr, expression=True
                        ),
                        jac_node=cond
                    );
                    chain = self.sync_loc(
                        es.CallExpression(
                            callee=self.sync_loc(
                                es.MemberExpression(
                                    object=chain,
                                    property=self.sync_loc(
                                        es.Identifier(name='filter'), jac_node=cond
                                    ),
                                    computed=False
                                ),
                                jac_node=cond
                            ),
                            arguments=[filter_arrow]
                        ),
                        jac_node=cond
                    );
                }
            }
        }
        if i == len(comprs) - 1 {
            map_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[param], body=out_expr, expression=True
                ),
                jac_node=nd
            );
            result = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.MemberExpression(
                            object=chain,
                            property=self.sync_loc(
                                es.Identifier(name='map'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    arguments=[map_arrow]
                ),
                jac_node=nd
            );
        } else {
            flat_arrow = self.sync_loc(
                es.ArrowFunctionExpression(
                    params=[param], body=cast(es.Expression, result), expression=True
                ),
                jac_node=nd
            );
            result = self.sync_loc(
                es.CallExpression(
                    callee=self.sync_loc(
                        es.MemberExpression(
                            object=chain,
                            property=self.sync_loc(
                                es.Identifier(name='flatMap'), jac_node=nd
                            ),
                            computed=False
                        ),
                        jac_node=nd
                    ),
                    arguments=[flat_arrow]
                ),
                jac_node=nd
            );
        }
        i -= 1;
    }
    return cast(es.Expression, result);
}

impl EsastGenPass._compr_param(
    target: es.Expression, jac_node: uni.UniNode
) -> es.Identifier | es.ArrayPattern {
    if isinstance(target, es.Identifier) {
        return self.sync_loc(es.Identifier(name=target.name), jac_node=jac_node);
    }
    if isinstance(target, es.ArrayExpression) {
        elements: list[(es.Identifier | None)] = [];
        for elem in target.elements {
            if isinstance(elem, es.Identifier) {
                elements.append(
                    self.sync_loc(es.Identifier(name=elem.name), jac_node=jac_node)
                );
            }
        }
        return self.sync_loc(es.ArrayPattern(elements=elements), jac_node=jac_node);
    }

    return self.sync_loc(es.Identifier(name='x'), jac_node=jac_node);
}
