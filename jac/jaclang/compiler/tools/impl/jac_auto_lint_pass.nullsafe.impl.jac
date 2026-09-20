impl JacAutoLintPass.enter_special_var_ref with uni.SpecialVarRef entry {
    if not self.lint_enabled {
        return;
    }
    if self.report_only {
        return;
    }
    if here.is_kwesc {
        here.is_kwesc = False;
    }
}

impl JacAutoLintPass._convert_hasattr_to_null_ok(
    nd: uni.FuncCall
) -> (uni.AtomTrailer | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    if nd.target.value != "hasattr" {
        return None;
    }
    if nd.params is None or len(nd.params) != 2 {
        return None;
    }
    return self._funccall_to_null_safe(nd, False);
}

impl JacAutoLintPass._is_matching_attr_access(
    trailer: uni.AtomTrailer, obj_expr: uni.Expr, attr_name: str
) -> bool {
    if not trailer.is_attr {
        return False;
    }
    if not isinstance(trailer.right, uni.Name) {
        return False;
    }
    if trailer.right.value != attr_name {
        return False;
    }
    return self._exprs_are_identical(obj_expr, trailer.target);
}

impl JacAutoLintPass._make_null_ok(trailer: uni.AtomTrailer) -> None {
    if not trailer.is_null_ok {
        trailer.is_null_ok = True;
        new_kid: list[uni.UniNode] = [];
        inserted_null_ok = False;
        for kid in trailer.kid {
            new_kid.append(kid);

            if kid is trailer.target and not inserted_null_ok {
                new_kid.append(trailer.gen_token(Tok.NULL_OK));
                inserted_null_ok = True;
            }
        }
        trailer.set_kids(nodes=new_kid);
    }
}

impl JacAutoLintPass._bool_expr_has_matching_access(
    parent: uni.BoolExpr, hasattr_node: uni.FuncCall, obj_expr: uni.Expr, attr_name: str
) -> bool {
    for val in parent.values {
        if val is hasattr_node {
            continue;
        }
        trailers: list[uni.AtomTrailer] = [];
        self._collect_atom_trailers(val, trailers);
        for trailer in trailers {
            if self._is_matching_attr_access(trailer, obj_expr, attr_name) {
                return True;
            }
        }
    }
    return False;
}

impl JacAutoLintPass._convert_getattr_to_null_ok(
    nd: uni.FuncCall
) -> (uni.AtomTrailer | None) {
    if not isinstance(nd.target, uni.Name) {
        return None;
    }
    if nd.target.value != "getattr" {
        return None;
    }
    if nd.params is None or len(nd.params) != 3 {
        return None;
    }
    obj_expr = nd.params[0];
    attr_expr = nd.params[1];
    default_expr = nd.params[2];
    if isinstance(obj_expr, uni.KWPair)
        or isinstance(attr_expr, uni.KWPair)
        or isinstance(default_expr, uni.KWPair) {
        return None;
    }
    if not isinstance(default_expr, uni.Null) {
        return None;
    }
    return self._funccall_to_null_safe(nd, True);
}

impl JacAutoLintPass._funccall_to_null_safe(
    fc: uni.FuncCall, require_valid_identifier: bool
) -> (uni.AtomTrailer | None) {
    obj_expr = fc.params[0];
    attr_expr = fc.params[1];
    if isinstance(obj_expr, uni.KWPair) {
        return None;
    }
    attr_value: str | None = None;
    string_node: uni.String | None = None;
    if isinstance(attr_expr, uni.String) {
        attr_value = attr_expr.value;
        string_node = attr_expr;
    } elif isinstance(attr_expr, uni.MultiString) {
        if len(attr_expr.strings) == 1
            and isinstance(attr_expr.strings[0], uni.String) {
            attr_value = attr_expr.strings[0].value;
            string_node = attr_expr.strings[0];
        }
    }
    if attr_value is None or string_node is None {
        return None;
    }
    if (attr_value.startswith('"') and attr_value.endswith('"'))
        or (attr_value.startswith("'") and attr_value.endswith("'")) {
        attr_name = attr_value[1:-1];
    } else {
        return None;
    }
    if require_valid_identifier
        and (not attr_name.isidentifier() or keyword.iskeyword(attr_name)) {
        return None;
    }
    attr_name_node = uni.Name(
        orig_src=string_node.loc.orig_src,
        name=Tok.NAME.name,
        value=attr_name,
        line=string_node.loc.first_line,
        end_line=string_node.loc.last_line,
        col_start=string_node.loc.col_start,
        col_end=string_node.loc.col_end,
        pos_start=string_node.loc.pos_start,
        pos_end=string_node.loc.pos_end,
        is_kwesc=False
    );
    null_ok_access = uni.AtomTrailer(
        target=obj_expr,
        right=attr_name_node,
        is_attr=True,
        is_null_ok=True,
        kid=[obj_expr, attr_name_node]
    );
    new_kid: list[uni.UniNode] = [obj_expr];
    new_kid.append(null_ok_access.gen_token(Tok.NULL_OK));
    new_kid.append(null_ok_access.gen_token(Tok.DOT));
    new_kid.append(attr_name_node);
    null_ok_access.set_kids(nodes=new_kid);
    return null_ok_access;
}

impl JacAutoLintPass._replace_child_in_parent(
    parent: uni.UniNode, old: uni.UniNode, new: uni.UniNode
) -> None {
    parent.replace_kid(old, new);
}

impl JacAutoLintPass.exit_func_call with uni.FuncCall exit {
    if not self.lint_enabled {
        return;
    }
    self._check_no_print(here);

    if not self.ctx._is_suppressed(W3007) {
        replacement = self._convert_hasattr_to_null_ok(here);
        if replacement is not None {
            if here.params is None {
                return;
            }
            obj_expr = here.params[0];
            attr_expr = here.params[1];
            if isinstance(obj_expr, uni.KWPair) or isinstance(attr_expr, uni.KWPair) {
                return;
            }
            attr_name = self._extract_string_literal_value(attr_expr);

            cfg_wrapper: uni.CfgExpr | None = None;
            parent = here.parent;
            if isinstance(parent, uni.CfgExpr) {
                cfg_wrapper = parent;
                parent = parent.parent;
            }
            if parent is None {
                return;
            }

            if isinstance(parent, uni.IfElseExpr) {} elif isinstance(
                parent, uni.BoolExpr
            ) {
                if attr_name is None
                    or not self._bool_expr_has_matching_access(
                        parent, here, obj_expr, attr_name
                    ) {
                    return;
                }
            } else {
                return;
            }
            if not self.ctx.emit(W3007, node_override=here) {
                return;
            }
            if self.report_only {
                return;
            }
            if cfg_wrapper is not None {
                replacement.set_parent(cfg_wrapper);
                cfg_wrapper._role_set(ExprRole, replacement);
                cfg_wrapper.set_kids([replacement]);
                cfg_wrapper._invalidate_sub_node_tab();
                if isinstance(parent, uni.IfElseExpr)
                    and parent.condition is cfg_wrapper
                    and attr_name is not None
                    and isinstance(parent.value.expr, uni.AtomTrailer)
                    and self._is_matching_attr_access(
                        parent.value.expr, obj_expr, attr_name
                    ) {
                    self._make_null_ok(parent.value.expr);
                }
                return;
            }
            replacement.set_parent(parent);
            if isinstance(parent, uni.IfElseExpr) {
                repl_cfg = uni.CfgExpr(expr=replacement, kid=[replacement]);
                if parent.condition is here {
                    parent._role_set(ConditionRole, repl_cfg);
                    if attr_name is not None
                        and isinstance(parent.value, uni.AtomTrailer) {
                        if self._is_matching_attr_access(
                            parent.value, obj_expr, attr_name
                        ) {
                            self._make_null_ok(parent.value);
                        }
                    }
                } elif parent.value is here {
                    parent._role_set(ValueRole, repl_cfg);
                } elif parent.else_value is here {
                    parent._role_set(ElseValueRole, repl_cfg);
                }
            } elif isinstance(parent, uni.BoolExpr) {
                new_values: list[uni.CfgExpr] = [];
                for val in parent.values {
                    if val is here {
                        new_values.append(
                            uni.CfgExpr(expr=replacement, kid=[replacement])
                        );
                    } else {
                        new_values.append(val);
                    }
                }
                parent._role_set(ValuesRole, new_values);
            }
            new_kids: list[uni.UniNode] = [];
            for kid in parent.kid {
                if kid is here {
                    new_kids.append(replacement);
                } else {
                    new_kids.append(kid);
                }
            }
            parent.set_kids(new_kids);
            parent._invalidate_sub_node_tab();
            return;
        }
    }

    if self._convert_map_to_comprehension(here) {
        return;
    }
    if not self.ctx._is_suppressed(W3039) {
        getattr_replacement = self._convert_getattr_to_null_ok(here);
        if getattr_replacement is not None {
            parent = here.parent;
            if parent is not None and self.ctx.emit(W3039, node_override=here) {
                if self.report_only {
                    return;
                }
                getattr_replacement.set_parent(parent);
                self._replace_child_in_parent(parent, here, getattr_replacement);
                return;
            }
        }
    }
}

impl JacAutoLintPass._collect_atom_trailers(
    uni_node: uni.UniNode, results: list[uni.AtomTrailer]
) -> None {
    if isinstance(uni_node, uni.AtomTrailer) {
        results.append(uni_node);
    }
    if uni_node?.kid {
        for kid in uni_node.kid {
            if kid is not None {
                self._collect_atom_trailers(kid, results);
            }
        }
    }
}

impl JacAutoLintPass._expr_to_key(expr: uni.Expr) -> (str | None) {
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.AtomTrailer) {
        if expr.is_attr and isinstance(expr.right, uni.Name) {
            target_key = self._expr_to_key(expr.target);
            if target_key is not None {
                null_ok = "?" if expr.is_null_ok else "";
                return f"{target_key}{null_ok}.{expr.right.value}";
            }
        }
        return None;
    }
    if isinstance(expr, uni.SpecialVarRef) {
        return expr.value;
    }

    if isinstance(expr, (uni.Int, uni.Float, uni.String, uni.Bool, uni.Null)) {
        return str(expr.value);
    }

    if isinstance(expr, uni.CompareExpr) {
        left_key = self._expr_to_key(expr.left);
        if left_key is None {
            return None;
        }
        parts = [left_key];
        for (i, op) in enumerate(expr.ops) {
            right_key = self._expr_to_key(expr.rights[i])
                if i < len(expr.rights)
                else None;
            if right_key is None {
                return None;
            }
            parts.append(op.value);
            parts.append(right_key);
        }
        return " ".join(parts);
    }

    if isinstance(expr, uni.BinaryExpr) and expr.op is not None {
        left_key = self._expr_to_key(expr.left);
        right_key = self._expr_to_key(expr.right);
        if left_key is not None and right_key is not None {
            op_val = expr.op.value if isinstance(expr.op, uni.Token) else str(expr.op);
            return f"{left_key} {op_val} {right_key}";
        }
    }

    if isinstance(expr, uni.UnaryExpr) and expr.op is not None {
        operand_key = self._expr_to_key(expr.operand);
        if operand_key is not None {
            op_val = expr.op.value if isinstance(expr.op, uni.Token) else str(expr.op);
            return f"{op_val} {operand_key}";
        }
    }
    return None;
}

impl JacAutoLintPass._exprs_are_identical(expr1: uni.Expr, expr2: uni.Expr) -> bool {
    if expr1 is expr2 {
        return True;
    }
    if type(expr1) != type(expr2) {
        return False;
    }
    if isinstance(expr1, uni.AtomTrailer) and isinstance(expr2, uni.AtomTrailer) {
        if expr1.is_attr != expr2.is_attr {
            return False;
        }
        if expr1.is_null_ok != expr2.is_null_ok {
            return False;
        }
        if not self._exprs_are_identical(expr1.target, expr2.target) {
            return False;
        }
        if isinstance(expr1.right, uni.Name) and isinstance(expr2.right, uni.Name) {
            return expr1.right.value == expr2.right.value;
        }
        return self._exprs_are_identical(expr1.right, expr2.right);
    }
    key1 = self._expr_to_key(expr1);
    key2 = self._expr_to_key(expr2);
    if key1 is not None and key2 is not None {
        return key1 == key2;
    }
    return False;
}

impl JacAutoLintPass._convert_ternary_to_or(if_else_node: uni.IfElseExpr) -> bool {
    if not self._exprs_are_identical(
        if_else_node.value.expr, if_else_node.condition.expr
    ) {
        return False;
    }
    parent = if_else_node.parent;
    if parent is None {
        return False;
    }
    if not self.ctx.emit(W3008, node_override=if_else_node) {
        return False;
    }
    if isinstance(if_else_node.else_value.expr, uni.Null) {
        replacement: uni.Expr = if_else_node.value.expr;
        replacement.set_parent(parent);
    } else {
        or_token = uni.Token(
            orig_src=if_else_node.loc.orig_src,
            name=Tok.KW_OR,
            value="or",
            line=if_else_node.loc.first_line,
            end_line=if_else_node.loc.first_line,
            col_start=0,
            col_end=2,
            pos_start=0,
            pos_end=2
        );
        cfg_val = uni.CfgExpr(
            expr=if_else_node.value.expr, kid=[if_else_node.value.expr]
        );
        cfg_else = uni.CfgExpr(
            expr=if_else_node.else_value.expr, kid=[if_else_node.else_value.expr]
        );
        replacement = uni.BoolExpr(
            op=or_token, values=[cfg_val, cfg_else], kid=[cfg_val, or_token, cfg_else]
        );
        replacement.set_parent(parent);
    }
    if parent?.kid {
        new_kids: list[uni.UniNode] = [];
        for kid in parent.kid {
            if kid is if_else_node {
                new_kids.append(replacement);
            } else {
                new_kids.append(kid);
            }
        }
        parent.set_kids(new_kids);
        parent._invalidate_sub_node_tab();
    }
    if isinstance(parent, uni.Assignment) {
        if parent.value is if_else_node {
            parent._role_set(ValueRole, replacement);
        }
    } elif isinstance(parent, uni.IfElseExpr) {
        if parent.value.expr is if_else_node {
            parent._role_set(
                ValueRole, uni.CfgExpr(expr=replacement, kid=[replacement])
            );
        } elif parent.condition.expr is if_else_node {
            parent._role_set(
                ConditionRole, uni.CfgExpr(expr=replacement, kid=[replacement])
            );
        } elif parent.else_value.expr is if_else_node {
            parent._role_set(
                ElseValueRole, uni.CfgExpr(expr=replacement, kid=[replacement])
            );
        }
    } elif isinstance(parent, uni.BoolExpr) {
        new_values: list[uni.CfgExpr] = [];
        for val in parent.values {
            if val.expr is if_else_node {
                new_values.append(uni.CfgExpr(expr=replacement, kid=[replacement]));
            } else {
                new_values.append(val);
            }
        }
        parent._role_set(ValuesRole, new_values);
    }
    return True;
}

impl JacAutoLintPass.exit_if_else_expr with uni.IfElseExpr exit {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if not self.ctx._is_suppressed(W3008) and self._convert_ternary_to_or(here) {
        return;
    }
    if self.ctx._is_suppressed(W3007) {
        return;
    }
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(here, trailers);
    if len(trailers) < 2 {
        return;
    }
    null_ok_keys: set = set();
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None {
                null_ok_keys.add(key);
            }
        }
    }
    if not null_ok_keys {
        return;
    }
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and not trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
            }
        }
    }
}

impl JacAutoLintPass.exit_bool_expr with uni.BoolExpr exit {
    if not self.lint_enabled or self.report_only or self.ctx._is_suppressed(W3007) {
        return;
    }
    trailers: list[uni.AtomTrailer] = [];
    self._collect_atom_trailers(here, trailers);
    if len(trailers) < 2 {
        return;
    }
    null_ok_keys: set = set();
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None {
                null_ok_keys.add(key);
            }
        }
    }
    if not null_ok_keys {
        return;
    }
    for trailer in trailers {
        if isinstance(trailer, uni.AtomTrailer) and not trailer.is_null_ok {
            key = self._expr_to_key(trailer);
            if key is not None and key in null_ok_keys {
                self._make_null_ok(trailer);
            }
        }
    }
}
