impl EsastGenPass._literal_value(expr: (uni.UniNode | None)) -> (object | None) {
    if (expr is None) {
        return None;
    }
    if isinstance(expr, (uni.String, uni.Int, uni.Float, uni.Bool)) {
        return expr.lit_value;
    }
    if isinstance(expr, uni.MultiString) {
        parts: list[str | bytes] = [];
        for segment in expr.strings {
            if isinstance(segment, uni.String) {
                parts.append(segment.lit_value);
            } else {
                return None;
            }
        }
        if parts and isinstance(parts[0], `bytes) {
            return b''.join(parts);
        }
        return ''.join(parts);
    }
    if isinstance(expr, uni.ListVal) {
        values = [self._literal_value(item) for item in expr.values];
        if all((val is not None) for val in values) {
            return values;
        }
    }
    if isinstance(expr, uni.TupleVal) {
        values = [self._literal_value(item) for item in expr.values];
        if all((val is not None) for val in values) {
            return tuple(values);
        }
    }
    if isinstance(expr, uni.DictVal) {
        items: dict[(str, any)] = {};
        for pair in expr.kv_pairs {
            if (isinstance(pair, uni.KVPair) and pair.key) {
                key_val = self._literal_value(pair.key);
                val_val = self._literal_value(pair.value);
                if (isinstance(key_val, str) and (val_val is not None)) {
                    items[key_val] = val_val;
                }
            }
        }
        if items {
            return items;
        }
    }
    return None;
}

impl EsastGenPass.exit_null(nd: uni.Null) -> None {
    null_lit = self.sync_loc(es.Literal(value=None, raw='null'), jac_node=nd);
    nd.gen.es_ast = null_lit;
}

impl EsastGenPass._template_element(
    text: str, tail: bool, jac_node: uni.UniNode
) -> es.TemplateElement {
    return self.sync_loc(
        es.TemplateElement(tail=tail, value={'cooked': text}), jac_node=jac_node
    );
}

impl EsastGenPass.exit_f_string(nd: uni.FString) -> None {
    quasis: list[es.TemplateElement] = [];
    expressions: list[es.Expression] = [];
    for (i, part) in enumerate(nd.parts) {
        is_last = i == (len(nd.parts) - 1);
        if isinstance(part, uni.String) {
            quasis.append(self._template_element(str(part.lit_value), is_last, part));
        } elif isinstance(part, uni.FormattedValue) {
            if ((i == 0) or not isinstance(nd.parts[(i - 1)], uni.String)) {
                quasis.append(self._template_element('', False, part));
            }
            expr = cast(
                es.Expression,
                part.gen.es_ast or self.sync_loc(es.Literal(value=''), jac_node=part)
            );
            expressions.append(expr);
            if is_last {
                quasis.append(self._template_element('', True, part));
            }
        }
    }
    if not quasis {
        quasis.append(self._template_element('', True, nd));
    }
    while (len(quasis) < (len(expressions) + 1)) {
        quasis.append(self._template_element('', True, nd));
    }
    template_lit = self.sync_loc(
        es.TemplateLiteral(quasis=quasis, expressions=expressions), jac_node=nd
    );
    nd.gen.es_ast = template_lit;
}

impl EsastGenPass.exit_formatted_value(nd: uni.FormattedValue) -> None {
    expr = nd.format_part.gen.es_ast
        or self.sync_loc(es.Literal(value=''), jac_node=nd.format_part);
    if nd.format_spec is not None {
        spec_es = nd.format_spec.gen.es_ast
            or self.sync_loc(es.Literal(value=''), jac_node=nd.format_spec);
        format_callee = self.sync_loc(
            es.MemberExpression(
                object=self.sync_loc(
                    es.MemberExpression(
                        object=self.sync_loc(es.Identifier(name='_jac'), jac_node=nd),
                        property=self.sync_loc(
                            es.Identifier(name='builtin'), jac_node=nd
                        ),
                        computed=False
                    ),
                    jac_node=nd
                ),
                property=self.sync_loc(es.Identifier(name='format'), jac_node=nd),
                computed=False
            ),
            jac_node=nd
        );
        self.needs_jac_runtime = True;
        nd.gen.es_ast = self.sync_loc(
            es.CallExpression(
                callee=cast(es.Expression, format_callee),
                arguments=[cast(es.Expression, expr), cast(es.Expression, spec_es)]
            ),
            jac_node=nd
        );
        return;
    }
    nd.gen.es_ast = expr;
}

impl EsastGenPass._str_literal(nd: uni.String) -> es.Literal {
    decoded = nd.lit_value;
    if isinstance(decoded, str) {
        return self.sync_loc(
            es.Literal(value=decoded, raw=json.dumps(decoded)), jac_node=nd
        );
    }

    raw_token = nd.value;
    fallback_raw = json.dumps(raw_token) if isinstance(raw_token, str) else None;
    return self.sync_loc(es.Literal(value=raw_token, raw=fallback_raw), jac_node=nd);
}

impl EsastGenPass.exit_string(nd: uni.String) -> None {
    nd.gen.es_ast = self._str_literal(nd);
}

impl EsastGenPass.exit_multi_string(nd: uni.MultiString) -> None {
    if not nd.strings {
        null_lit = self.sync_loc(es.Literal(value='', raw='""'), jac_node=nd);
        nd.gen.es_ast = null_lit;
        return;
    }
    if (len(nd.strings) == 1) {
        string_node = nd.strings[0];
        if string_node.gen.es_ast {
            nd.gen.es_ast = string_node.gen.es_ast;
        } elif isinstance(string_node, uni.String) {
            nd.gen.es_ast = self._str_literal(string_node);
        } else {
            nd.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=nd);
        }
        return;
    }
    parts = [];
    for string_node in nd.strings {
        if string_node.gen.es_ast {
            parts.append(string_node.gen.es_ast);
        } elif isinstance(string_node, uni.String) {
            parts.append(self._str_literal(string_node));
        }
    }
    if not parts {
        nd.gen.es_ast = self.sync_loc(es.Literal(value=''), jac_node=nd);
        return;
    }
    result: es.Expression = cast(es.Expression, parts[0]);
    for part in parts[1:] {
        result = self.sync_loc(
            es.BinaryExpression(
                operator='+', left=result, right=cast(es.Expression, part)
            ),
            jac_node=nd
        );
    }
    nd.gen.es_ast = result;
}

impl EsastGenPass.exit_float(nd: uni.Float) -> None {
    float_lit = self.sync_loc(
        es.Literal(value=float(nd.value), raw=nd.value), jac_node=nd
    );
    nd.gen.es_ast = float_lit;
}

impl EsastGenPass.exit_int(nd: uni.Int) -> None {
    int_lit = self.sync_loc(
        es.Literal(value=int(nd.value, 0), raw=nd.value), jac_node=nd
    );
    nd.gen.es_ast = int_lit;
}

impl EsastGenPass.exit_bool(nd: uni.Bool) -> None {
    value = nd.value.lower() == 'true';
    raw_value = 'true' if value else 'false';
    bool_lit = self.sync_loc(es.Literal(value=value, raw=raw_value), jac_node=nd);
    nd.gen.es_ast = bool_lit;
}

