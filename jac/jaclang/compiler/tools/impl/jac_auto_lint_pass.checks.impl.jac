import from jaclang.compiler.tools.unparse_pass { unparse_node }


impl JacAutoLintPass._check_no_print(nd: uni.FuncCall) -> None {
    if not isinstance(nd.target, uni.Name) {
        return;
    }
    if nd.target.value != "print" {
        return;
    }
    if self._is_file_excluded(nd.loc.mod_path) {
        return;
    }
    self.ctx.emit(E3012, node_override=nd);
}

impl JacAutoLintPass._check_unnecessary_pass(body: list[uni.UniNode]) -> None {
    if self.ctx._is_suppressed(W3020) {
        return;
    }
    real_stmts = [
        s
        for s in body
        if not isinstance(s, uni.Semi)
    ];
    if len(real_stmts) <= 1 {
        return;
    }
    for stmt in body {
        if isinstance(stmt, uni.CtrlStmt)
            and stmt.ctrl
            and isinstance(stmt.ctrl, uni.Token)
            and stmt.ctrl.value == "pass" {
            self.ctx.emit(W3020, node_override=stmt);
        }

        if isinstance(stmt, uni.ExprStmt) {
            for k in stmt.kid {
                if isinstance(k, uni.Name) and k.value == "pass" {
                    self.ctx.emit(W3020, node_override=stmt);
                    break;
                }
            }
        }
    }
}

impl JacAutoLintPass._check_unnecessary_else_after_return(nd: uni.IfStmt) -> None {
    if self.ctx._is_suppressed(W3021) {
        return;
    }

    if not nd.body {
        return;
    }
    real_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    if not real_body {
        return;
    }
    last_stmt = real_body[-1];
    if not isinstance(last_stmt, (uni.ReturnStmt, uni.RaiseStmt)) {
        return;
    }

    else_node = nd.else_body;
    if else_node is not None and isinstance(else_node, uni.ElseStmt) {
        self.ctx.emit(W3021, node_override=else_node);
    }
}

impl JacAutoLintPass._check_nested_if_to_elif(nd: uni.ElseStmt) -> None {
    if self.ctx._is_suppressed(W3022) {
        return;
    }
    if not nd.body {
        return;
    }
    real_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    if len(real_body) == 1 and isinstance(real_body[0], uni.IfStmt) {
        self.ctx.emit(W3022, node_override=nd);
    }
}

impl JacAutoLintPass._check_return_bool_simplification(nd: uni.IfStmt) -> None {
    if self.ctx._is_suppressed(W3023) {
        return;
    }
    if nd.else_body is None or not isinstance(nd.else_body, uni.ElseStmt) {
        return;
    }
    if_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    else_body = [
        s
        for s in nd.else_body.body
        if not isinstance(s, uni.Semi)
    ];
    if len(if_body) != 1 or len(else_body) != 1 {
        return;
    }
    if_ret = if_body[0];
    else_ret = else_body[0];
    if not isinstance(if_ret, uni.ReturnStmt)
        or not isinstance(else_ret, uni.ReturnStmt) {
        return;
    }
    if (
        isinstance(if_ret.expr, uni.Bool)
        and isinstance(else_ret.expr, uni.Bool)
        and if_ret.expr.value != else_ret.expr.value
    ) {
        self.ctx.emit(W3023, node_override=nd);
    }
}

impl JacAutoLintPass._check_repeated_condition(nd: uni.IfStmt) -> None {
    if self.ctx._is_suppressed(W3024) {
        return;
    }
    conditions: list[str] = [];
    cond_key = self._expr_to_key(nd.condition);
    if cond_key is not None {
        conditions.append(cond_key);
    }

    current = nd.else_body;
    while current is not None and isinstance(current, uni.ElseIf) {
        elif_key = self._expr_to_key(current.condition);
        if elif_key is not None {
            if elif_key in conditions {
                self.ctx.emit(W3024, node_override=current);
            }
            conditions.append(elif_key);
        }
        current = current.else_body;
    }
}

impl JacAutoLintPass._check_identical_branches(nd: uni.IfStmt) -> None {
    if self.ctx._is_suppressed(W3025) {
        return;
    }
    if nd.else_body is None or not isinstance(nd.else_body, uni.ElseStmt) {
        return;
    }
    if_body = [
        s
        for s in nd.body
        if not isinstance(s, uni.Semi)
    ];
    else_body = [
        s
        for s in nd.else_body.body
        if not isinstance(s, uni.Semi)
    ];
    if not if_body or len(if_body) != len(else_body) {
        return;
    }

    for (a, b) in zip(if_body, else_body) {
        if type(a) is not type(b) {
            return;
        }
    }

    if_src = "".join(unparse_node(s) for s in if_body);
    else_src = "".join(unparse_node(s) for s in else_body);
    if if_src == else_src {
        self.ctx.emit(W3025, node_override=nd);
    }
}

impl JacAutoLintPass._check_too_many_params(nd: uni.FuncSignature) -> None {
    if self.ctx._is_suppressed(W3030) {
        return;
    }
    threshold = 7;
    count = len(nd.posonly_params);
    if nd.params {
        count += len(nd.params);
    }
    count += len(nd.kwonlyargs);
    if nd.varargs {
        count += 1;
    }
    if nd.kwargs {
        count += 1;
    }

    all_params: list[uni.ParamVar] = list(nd.posonly_params);
    if nd.params {
        all_params.extend(nd.params);
    }
    if all_params
        and isinstance(all_params[0], uni.ParamVar)
        and all_params[0].name.value == "self" {
        count -= 1;
    }
    if count > threshold {
        self.ctx.emit(W3030, node_override=nd, count=count, threshold=threshold);
    }
}

impl JacAutoLintPass._check_is_with_literal(nd: uni.CompareExpr) -> None {
    if self.ctx._is_suppressed(W3035) {
        return;
    }
    for (i, op) in enumerate(nd.ops) {
        if op.value not in ("is", "is not") {
            continue;
        }
        right = nd.rights[i] if i < len(nd.rights) else None;
        if right is None {
            continue;
        }

        if isinstance(right, (uni.Null, uni.Bool)) {
            continue;
        }
        if isinstance(right, (uni.Int, uni.Float, uni.String)) {
            self.ctx.emit(W3035, node_override=nd);
        }
    }
}

impl JacAutoLintPass._check_filter_compare_tautology(nd: uni.CompareExpr) -> None {
    import from jaclang.compiler.frontend.diagnostics { W3040 }
    if self.ctx._is_suppressed(W3040) {
        return;
    }

    if not nd.find_parent_of_type(uni.FilterCompr) {
        return;
    }
    left = nd.left;
    for (i, right) in enumerate(nd.rights) {
        if (
            isinstance(left, uni.Name)
            and isinstance(right, uni.Name)
            and left.value == right.value
        ) {
            self.ctx.emit(W3040, node_override=nd, name=left.value);
        }

        left = right;
    }
}

impl JacAutoLintPass._check_stale_has_read(ability_node: uni.Ability) -> None {
    if self.ctx._is_suppressed(W3041) {
        return;
    }
    sig = ability_node.signature;
    if not isinstance(sig, uni.EventSignature) {
        return;
    }
    if not sig.event or sig.event.name != Tok.KW_ENTRY {
        return;
    }
    if not ability_node.in_client_context() {
        return;
    }
    body = ability_node.body;
    if body is None or not isinstance(body, list) {
        return;
    }
    reactive = self._collect_reactive_has_names(ability_node);
    if not reactive {
        return;
    }
    writes: list[tuple[int, int, str]] = [];
    reads: list[tuple[int, int, str, uni.Name]] = [];
    for stmt in body {
        self._walk_for_has_uses(stmt, reactive, writes, reads);
    }
    if not writes or not reads {
        return;
    }
    earliest_write: dict[str, tuple[int, int]] = {};
    for write_entry in writes {
        wname = write_entry[2];
        wpos = (write_entry[0], write_entry[1]);
        if wname not in earliest_write or wpos < earliest_write[wname] {
            earliest_write[wname] = wpos;
        }
    }
    flagged: set[tuple[int, int, str]] = set();
    for read_entry in reads {
        rline = read_entry[0];
        rcol = read_entry[1];
        rname = read_entry[2];
        rnode = read_entry[3];
        key = (rline, rcol, rname);
        if key in flagged {
            continue;
        }
        first_write = earliest_write.get(rname);
        if first_write is not None and first_write < (rline, rcol) {
            self.ctx.emit(W3041, node_override=rnode, name=rname);
            flagged.add(key);
        }
    }
}

impl JacAutoLintPass._collect_reactive_has_names(
    ability_node: uni.Ability
) -> set[str] {
    names: set[str] = set();
    container: (uni.UniNode | None) = ability_node.parent;
    while container is not None {
        if isinstance(container, (uni.Archetype, uni.Ability)) {
            body = container.body;
            if body is not None and isinstance(body, list) {
                for stmt in body {
                    if isinstance(stmt, uni.ArchHas) and stmt.in_client_context() {
                        for hv in stmt.vars {
                            names.add(hv.name.sym_name);
                        }
                    }
                }
            }
            break;
        }
        container = container.parent;
    }
    return names;
}

impl JacAutoLintPass._walk_for_has_uses(
    nd: uni.UniNode,
    reactive: set[str],
    writes: list[tuple[int, int, str]],
    reads: list[tuple[int, int, str, uni.Name]]
) -> None {
    import from jaclang.compiler.frontend.constant { ExprCtx }
    if isinstance(nd, (uni.LambdaExpr, uni.Ability, uni.Archetype)) {
        return;
    }
    if isinstance(nd, uni.Assignment) {
        if (
            len(nd.target) == 1
            and isinstance(nd.target[0], uni.Name)
            and nd.target[0].sym_name in reactive
        ) {
            tgt = nd.target[0];
            writes.append((tgt.loc.first_line, tgt.loc.col_start, tgt.sym_name));
        }
        if nd.value {
            self._walk_for_has_uses(nd.value, reactive, writes, reads);
        }
        return;
    }
    if isinstance(nd, uni.Name) {
        if nd.value in reactive and nd.expr_ctx == ExprCtx.LOAD {
            parent = nd.parent;
            if not (isinstance(parent, uni.AtomTrailer) and parent.is_attr) {
                reads.append((nd.loc.first_line, nd.loc.col_start, nd.value, nd));
            }
        }
        return;
    }
    for kid in nd.kid {
        self._walk_for_has_uses(kid, reactive, writes, reads);
    }
}

impl JacAutoLintPass._check_mutable_default(nd: uni.ParamVar) -> None {
    if self.ctx._is_suppressed(W3036) {
        return;
    }
    if nd.value is None {
        return;
    }
    `default = nd.value;
    if isinstance(`default, uni.ListVal) {
        self.ctx.emit(W3036, node_override=nd, type="list");
    } elif isinstance(`default, uni.DictVal) {
        self.ctx.emit(W3036, node_override=nd, type="dict");
    } elif isinstance(`default, uni.SetVal) {
        self.ctx.emit(W3036, node_override=nd, type="set");
    }
}

impl JacAutoLintPass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_pass(list(here.body));
    self._check_unnecessary_else_after_return(here);
    self._check_return_bool_simplification(here);
    self._check_repeated_condition(here);
    self._check_identical_branches(here);
}

impl JacAutoLintPass.enter_else_stmt with uni.ElseStmt entry {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_pass(list(here.body));
    self._check_nested_if_to_elif(here);
}

impl JacAutoLintPass.exit_compare_expr with uni.CompareExpr exit {
    if not self.lint_enabled {
        return;
    }
    self._check_is_with_literal(here);
    self._check_filter_compare_tautology(here);
}

impl JacAutoLintPass.exit_func_signature with uni.FuncSignature exit {
    if not self.lint_enabled {
        return;
    }
    self._check_too_many_params(here);
}

impl JacAutoLintPass.enter_param_var with uni.ParamVar entry {
    if not self.lint_enabled {
        return;
    }
    self._check_mutable_default(here);
}

impl JacAutoLintPass.exit_archetype with uni.Archetype exit {
    if not self.lint_enabled {
        return;
    }
    if here.body is not None and isinstance(here.body, list) {
        self._check_unnecessary_pass(list(here.body));
    }
}

impl JacAutoLintPass.exit_lambda_expr with uni.LambdaExpr exit {
    if not self.lint_enabled {
        return;
    }
    self._check_unnecessary_none_return(here, here.body, here.signature, "lambda");
}

impl JacAutoLintPass._check_unnecessary_none_return(
    nd: (uni.Ability | uni.LambdaExpr),
    body: (uni.UniNode | Sequence[uni.UniNode] | None),
    sig: (uni.FuncSignature | uni.EventSignature | None),
    name: str
) -> None {
    if self.ctx._is_suppressed(W3037) {
        return;
    }

    if not isinstance(sig, uni.FuncSignature) or sig.return_type is None {
        return;
    }

    ret = sig.return_type;
    is_none_return = (
        isinstance(ret, uni.Null)
        or (isinstance(ret, uni.BuiltinType) and ret.value == "None")
        or (isinstance(ret, uni.Name) and ret.value == "None")
    );
    if not is_none_return {
        return;
    }

    if not isinstance(body, list) {
        return;
    }

    if not self._body_has_return_stmt(body) {
        if not self.ctx.emit(W3037, node_override=sig.return_type, name=name) {
            return;
        }
        if self.report_only {
            return;
        }

        sig._role_set(ReturnTypeRole, None);
        new_kid: list[uni.UniNode] = [];
        skip_next = False;
        for kid in sig.kid {
            if isinstance(kid, uni.Token) and kid.name == Tok.RETURN_HINT {
                skip_next = True;
                continue;
            }
            if skip_next {
                skip_next = False;
                continue;
            }
            new_kid.append(kid);
        }
        if len(new_kid) > 0 {
            sig.set_kids(nodes=new_kid);
        } else {
            if isinstance(nd, uni.LambdaExpr) {
                nd._role_set(SignatureRole, None);
            } elif isinstance(nd, uni.Ability) {
                nd._role_set(SignatureRole, None);
            }
            nd.set_kids(
                [
                    k
                    for k in nd.kid
                    if k is not sig
                ]
            );
            nd._invalidate_sub_node_tab();
        }
    }
}

impl JacAutoLintPass._body_has_return_stmt(body: list[uni.UniNode]) -> bool {
    for stmt in body {
        if isinstance(stmt, uni.ReturnStmt) {
            return True;
        }

        if isinstance(stmt, uni.IfStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
            eb = stmt.else_body;
            while eb is not None {
                if isinstance(eb, uni.ElseIf) {
                    if self._body_has_return_stmt(list(eb.body)) {
                        return True;
                    }
                    eb = eb.else_body;
                } elif isinstance(eb, uni.ElseStmt) {
                    if self._body_has_return_stmt(list(eb.body)) {
                        return True;
                    }
                    break;
                } else {
                    break;
                }
            }
        }
        if isinstance(stmt, uni.InForStmt)
            or isinstance(stmt, uni.IterForStmt)
            or isinstance(stmt, uni.WhileStmt)
            or isinstance(stmt, uni.ForeverStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
        }
        if isinstance(stmt, uni.TryStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
            for handler in (stmt.excepts or []) {
                if self._body_has_return_stmt(list(handler.body)) {
                    return True;
                }
            }
            if stmt.finally_body {
                if self._body_has_return_stmt(list(stmt.finally_body.body)) {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.MatchStmt) {
            for `case in stmt.cases {
                if self._body_has_return_stmt(list(`case.body)) {
                    return True;
                }
            }
        }
        if isinstance(stmt, uni.WithStmt) {
            if self._body_has_return_stmt(list(stmt.body)) {
                return True;
            }
        }
    }
    return False;
}
