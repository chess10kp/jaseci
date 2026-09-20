impl JacAutoLintPass._is_usestate_assignment(
    stmt: uni.UniNode
) -> (tuple[str, str, uni.Expr | None] | None) {
    if not isinstance(stmt, uni.Assignment) {
        return None;
    }

    rhs = stmt.value;
    if not isinstance(rhs, uni.FuncCall) {
        return None;
    }
    if not isinstance(rhs.target, uni.Name) or rhs.target.value != "useState" {
        return None;
    }

    if len(stmt.target) != 1 {
        return None;
    }
    lhs = stmt.target[0];
    if not isinstance(lhs, (uni.ListVal, uni.TupleVal)) {
        return None;
    }
    if len(lhs.values) != 2 {
        return None;
    }
    name_node = lhs.values[0];
    setter_node = lhs.values[1];
    if not isinstance(name_node, uni.Name) or not isinstance(setter_node, uni.Name) {
        return None;
    }
    initial_value: (uni.Expr | None) = None;
    if rhs.params and len(rhs.params) > 0 {
        first_param = rhs.params[0];
        if isinstance(first_param, uni.Expr) {
            initial_value = first_param;
        }
    }
    return (name_node.value, setter_node.value, initial_value);
}

impl JacAutoLintPass._infer_type_from_usestate_value(value: (uni.Expr | None)) -> str {
    if value is None {
        return "any";
    }
    if isinstance(value, (uni.String, uni.MultiString)) {
        return "str";
    }
    if isinstance(value, uni.Int) {
        return "int";
    }
    if isinstance(value, uni.Float) {
        return "float";
    }
    if isinstance(value, uni.Bool) {
        return "bool";
    }
    if isinstance(value, uni.Null) {
        return "None";
    }
    if isinstance(value, uni.ListVal) {
        return "list";
    }
    if isinstance(value, uni.DictVal) {
        return "dict";
    }
    return "any";
}

impl JacAutoLintPass._create_has_from_usestate(
    ref_node: uni.UniNode, var_name: str, type_str: str, init_value: (uni.Expr | None)
) -> uni.ArchHas {
    name_node = uni.Name(
        orig_src=ref_node.loc.orig_src,
        name=Tok.NAME.value,
        value=var_name,
        line=ref_node.loc.first_line,
        end_line=ref_node.loc.last_line,
        col_start=ref_node.loc.col_start,
        col_end=ref_node.loc.col_start + len(var_name),
        pos_start=ref_node.loc.pos_start,
        pos_end=ref_node.loc.pos_end,
        is_kwesc=False
    );

    type_name_node = uni.Name(
        orig_src=ref_node.loc.orig_src,
        name=Tok.NAME.value,
        value=type_str,
        line=ref_node.loc.first_line,
        end_line=ref_node.loc.last_line,
        col_start=ref_node.loc.col_start,
        col_end=ref_node.loc.col_start + len(type_str),
        pos_start=ref_node.loc.pos_start,
        pos_end=ref_node.loc.pos_end,
        is_kwesc=False
    );
    colon_tok = ref_node.gen_token(Tok.COLON);
    type_tag = uni.SubTag(tag=type_name_node, kid=[colon_tok, type_name_node]);
    has_var_kids: list[uni.UniNode] = [name_node, type_tag];
    if init_value is not None {
        eq_tok = ref_node.gen_token(Tok.EQ);
        has_var_kids.append(eq_tok);
        has_var_kids.append(init_value);
    }
    has_var = uni.HasVar(
        name=name_node,
        type_tag=type_tag,
        value=init_value,
        defer=False,
        kid=has_var_kids
    );

    has_kw = ref_node.gen_token(Tok.KW_HAS);
    semi_tok = ref_node.gen_token(Tok.SEMI);
    arch_has = uni.ArchHas(
        is_static=False,
        vars=[has_var],
        is_frozen=False,
        access=None,
        doc=None,
        kid=[has_kw, has_var, semi_tok]
    );
    return arch_has;
}

impl JacAutoLintPass._convert_usestate_vars(ability_node: uni.Ability) -> None {
    if not ability_node.body or not isinstance(ability_node.body, list) {
        return;
    }
    new_body: list[uni.UniNode] = [];
    replaced: dict[int, uni.ArchHas] = {};
    setters: dict[str, str] = {};
    for stmt in ability_node.body {
        match_result = self._is_usestate_assignment(stmt);
        if match_result is None {
            new_body.append(stmt);
            continue;
        }
        (var_name, setter_name, init_value) = match_result;
        type_str = self._infer_type_from_usestate_value(init_value);
        init_repr = (
            str(getattr(init_value, "value", "...")) if init_value is not None else '""'
        );
        if not self.ctx.emit(
            W3038, node_override=stmt, name=var_name, type_name=type_str, init=init_repr
        ) {
            new_body.append(stmt);
            continue;
        }
        has_node = self._create_has_from_usestate(stmt, var_name, type_str, init_value);
        has_node.set_parent(ability_node);
        new_body.append(has_node);
        replaced[id(stmt)] = has_node;
        setters[setter_name] = var_name;
    }
    if replaced {
        self._did_convert_usestate = True;
        ability_node._role_set(BodyRole, new_body);
        ability_node._invalidate_sub_node_tab();
        ability_node.set_kids([replaced.get(id(k), k) for k in ability_node.kid]);
        ability_node._invalidate_sub_node_tab();
    }

    self._pending_setters.append(setters);
}

impl JacAutoLintPass.exit_expr_stmt with uni.ExprStmt exit {
    if not self.lint_enabled or self.report_only or not self._pending_setters {
        return;
    }
    call_node = here.expr;
    if (
        not isinstance(call_node, uni.FuncCall)
        or not isinstance(call_node.target, uni.Name)
        or call_node.params is None
        or len(call_node.params) != 1
    ) {
        return;
    }
    var_name: (str | None) = None;
    for setter_map in self._pending_setters {
        if call_node.target.value in setter_map {
            var_name = setter_map[call_node.target.value];
            break;
        }
    }
    if var_name is None {
        return;
    }
    parent = here.parent;
    if parent is None {
        return;
    }
    value_expr = call_node.params[0];
    if isinstance(value_expr, uni.KWPair) {
        return;
    }
    lhs_name = uni.Name(
        orig_src=call_node.loc.orig_src,
        name=Tok.NAME.value,
        value=var_name,
        line=call_node.loc.first_line,
        end_line=call_node.loc.last_line,
        col_start=call_node.loc.col_start,
        col_end=call_node.loc.col_start + len(var_name),
        pos_start=call_node.loc.pos_start,
        pos_end=call_node.loc.pos_end,
        is_kwesc=False
    );
    assign = uni.Assignment(
        target=[lhs_name],
        value=value_expr,
        mutable=True,
        aug_op=None,
        kid=[
            lhs_name,
            call_node.gen_token(Tok.EQ),
            value_expr,
            call_node.gen_token(Tok.SEMI)
        ]
    );
    assign.set_parent(parent);

    parent_body = self._stmt_body_list(parent);
    if parent_body is not None and isinstance(parent_body, list) {
        for (i, s) in enumerate(parent_body) {
            if s is here {
                parent_body[i] = assign;
            }
        }
    }
    parent.set_kids([assign if k is here else k for k in parent.kid]);
    parent._invalidate_sub_node_tab();
}

impl JacAutoLintPass._strip_usestate_imports(nd: uni.Module) -> None {
    if not self.lint_enabled or self.report_only or not self._did_convert_usestate {
        return;
    }
    removed: set[int] = set();
    new_body = [];
    for stmt in nd.body {
        if not isinstance(stmt, uni.Import) or stmt.from_loc is None {
            new_body.append(stmt);
            continue;
        }
        usestate_items = {
            item
            for item in stmt.items
            if isinstance(item, uni.ModuleItem)
                and isinstance(item.name, uni.Name)
                and item.name.value == "useState"
        };
        if not usestate_items {
            new_body.append(stmt);
            continue;
        }
        stmt._role_set(
            ItemsRole,
            [
                item
                for item in stmt.items
                if item not in usestate_items
            ]
        );
        if not stmt.items {
            removed.add(id(stmt));
            continue;
        }

        new_kid = [
            kid
            for kid in stmt.kid
            if kid not in usestate_items
        ];
        commas = [
            k
            for k in new_kid
            if isinstance(k, uni.Token) and k.name == Tok.COMMA
        ];
        no_commas = [
            k
            for k in new_kid
            if not (isinstance(k, uni.Token) and k.name == Tok.COMMA)
        ];
        result: list[uni.UniNode] = [];
        ci = 0;
        for (i, kid) in enumerate(no_commas) {
            result.append(kid);
            if (
                i + 1 < len(no_commas)
                and isinstance(kid, uni.ModuleItem)
                and isinstance(no_commas[i + 1], uni.ModuleItem)
                and ci < len(commas)
            ) {
                result.append(commas[ci]);
                ci += 1;
            }
        }
        stmt.set_kids(nodes=result);
        new_body.append(stmt);
    }
    if len(new_body) == len(nd.body) {
        return;
    }
    nd._role_set(BodyRole, new_body);
    if removed {
        nd.set_kids(
            nodes=[
                k
                for k in nd.kid
                if id(k) not in removed
            ]
                or [uni.EmptyToken()]
        );
    }
    nd._invalidate_sub_node_tab();
}

impl JacAutoLintPass._detect_map_lambda_jsx(
    nd: uni.FuncCall
) -> (tuple[str, uni.JsxElement, uni.Expr] | None) {
    if not isinstance(nd.target, uni.AtomTrailer) {
        return None;
    }
    trailer = nd.target;
    if not trailer.is_attr
        or not isinstance(trailer.right, uni.Name)
        or trailer.right.value != "map"
        or nd.params is None
        or len(nd.params) != 1
        or not isinstance(nd.params[0], uni.LambdaExpr) {
        return None;
    }
    lam: uni.LambdaExpr = nd.params[0];
    if not isinstance(lam.body, list) {
        return None;
    }
    real_stmts = [
        s
        for s in lam.body
        if not isinstance(s, uni.Semi)
    ];
    if len(real_stmts) != 1 {
        return None;
    }
    ret_stmt = real_stmts[0];
    if not isinstance(ret_stmt, uni.ReturnStmt) or ret_stmt.expr is None {
        return None;
    }
    jsx: uni.Expr = ret_stmt.expr;
    if isinstance(jsx, uni.AtomUnit) and isinstance(jsx.value, uni.JsxElement) {
        jsx = jsx.value;
    }
    if jsx is None or not isinstance(jsx, uni.JsxElement) {
        return None;
    }

    sig = lam.signature;
    if sig is None {
        return None;
    }
    all_params: list[uni.ParamVar] = list(sig.posonly_params or [])
        + list(sig.params or []);
    if len(all_params) != 1 {
        return None;
    }

    item_name: str = all_params[0].name.value;
    return (item_name, jsx, trailer.target);
}

impl JacAutoLintPass._extract_filter_cond(
    collection: uni.Expr
) -> (tuple[uni.Expr, uni.Expr] | None) {
    if not isinstance(collection, uni.FuncCall)
        or not isinstance(collection.target, uni.AtomTrailer) {
        return None;
    }
    ft = collection.target;
    if not ft.is_attr
        or not isinstance(ft.right, uni.Name)
        or ft.right.value != "filter"
        or collection.params is None
        or len(collection.params) != 1
        or not isinstance(collection.params[0], uni.LambdaExpr) {
        return None;
    }
    filter_lam: uni.LambdaExpr = collection.params[0];
    if not isinstance(filter_lam.body, list) {
        return None;
    }
    filter_stmts = [
        s
        for s in filter_lam.body
        if not isinstance(s, uni.Semi)
    ];
    if len(filter_stmts) != 1
        or not isinstance(filter_stmts[0], uni.ReturnStmt)
        or filter_stmts[0].expr is None {
        return None;
    }
    return (filter_stmts[0].expr, ft.target);
}

impl JacAutoLintPass._convert_map_to_comprehension(nd: uni.FuncCall) -> bool {
    if self.ctx._is_suppressed(W3042) {
        return False;
    }
    detected = self._detect_map_lambda_jsx(nd);
    if detected is None {
        return False;
    }
    (item_name, jsx_expr, collection) = detected;

    filter_result = self._extract_filter_cond(collection);
    filter_cond: (uni.Expr | None) = None;
    if filter_result is not None {
        (filter_cond, collection) = filter_result;
    }

    parent = nd.parent;
    if parent is None {
        return False;
    }
    if not (
        isinstance(parent, (uni.JsxExpression, uni.ExprStmt, uni.CfgExpr))
        or (isinstance(parent, uni.Assignment) and parent.value is nd)
        or (isinstance(parent, uni.ReturnStmt) and parent.expr is nd)
    ) {
        return False;
    }

    if not self.ctx.emit(W3042, node_override=nd, name=item_name) {
        return False;
    }
    if self.report_only {
        return True;
    }

    target_node: uni.Expr = self._make_name_node(nd, item_name);
    compr_kid: list[uni.UniNode] = [
        nd.gen_token(Tok.KW_FOR),
        target_node,
        nd.gen_token(Tok.KW_IN),
        collection
    ];
    if filter_cond is not None {
        compr_kid.extend([nd.gen_token(Tok.KW_IF), filter_cond]);
    }
    inner_compr = uni.InnerCompr(
        is_async=False,
        target=target_node,
        collection=collection,
        conditional=[filter_cond] if filter_cond is not None else None,
        kid=compr_kid
    );
    list_compr = uni.ListCompr(
        out_expr=jsx_expr,
        compr=[inner_compr],
        kid=[
            nd.gen_token(Tok.LSQUARE),
            jsx_expr,
            inner_compr,
            nd.gen_token(Tok.RSQUARE)
        ]
    );

    jsx_expr.set_parent(list_compr);
    inner_compr.set_parent(list_compr);
    target_node.set_parent(inner_compr);
    collection.set_parent(inner_compr);
    if filter_cond is not None {
        filter_cond.set_parent(inner_compr);
    }

    list_compr.set_parent(parent);
    if isinstance(parent, (uni.JsxExpression, uni.ExprStmt, uni.CfgExpr)) {
        parent._role_set(ExprRole, list_compr);
    } elif isinstance(parent, uni.Assignment) {
        parent._role_set(ValueRole, list_compr);
    } else {
        parent._role_set(ExprRole, list_compr);
    }
    parent.set_kids([list_compr if k is nd else k for k in parent.kid]);
    parent._invalidate_sub_node_tab();
    return True;
}

impl JacAutoLintPass._property_role_of_ability(ab: uni.Ability) -> str {
    if not ab.decorators {
        return "";
    }
    own_name = ab.name_ref.value if isinstance(ab.name_ref, uni.Name) else "";
    for dec in ab.decorators {
        if isinstance(dec, uni.Name) and dec.value == "property" {
            return "property";
        }

        if isinstance(dec, uni.AtomTrailer)
            and dec.is_attr
            and isinstance(dec.right, uni.Name)
            and isinstance(dec.target, uni.Name)
            and dec.target.value == own_name {
            if dec.right.value == "getter" {
                return "property";
            }
            if dec.right.value == "setter" {
                return "setter";
            }
            if dec.right.value == "deleter" {
                return "deleter";
            }
        }
    }
    return "";
}

impl JacAutoLintPass._make_accessor_from_ability(
    src: uni.Ability, kind: str
) -> uni.Ability {
    kw = "getter" if kind == "property" else kind;
    name_node = self._make_name_node(src, kw);
    sig: (uni.FuncSignature | uni.EventSignature | None) = (
        src.signature if kind == "setter" else None
    );
    acc_kid: list[uni.UniNode] = [name_node];
    if sig is not None {
        acc_kid.append(sig);
    }
    body: (list[uni.UniNode] | None) = None;
    if isinstance(src.body, list) {
        body = src.body;
        acc_kid.append(src.gen_token(Tok.LBRACE));
        for s in src.body {
            acc_kid.append(s);
        }
        acc_kid.append(src.gen_token(Tok.RBRACE));
    } else {
        acc_kid.append(src.gen_token(Tok.SEMI));
    }
    return uni.Ability(
        name_ref=name_node,
        is_async=False,
        is_override=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        access=None,
        signature=sig,
        body=body,
        kid=acc_kid,
        doc=None,
        decorators=None,
        type_params=None,
        accessor_kind=kind
    );
}

impl JacAutoLintPass._build_property_has(
    ref_node: uni.UniNode,
    prop_name: str,
    type_expr: uni.Expr,
    accessors: list[uni.Ability]
) -> uni.ArchHas {
    name_node = self._make_name_node(ref_node, prop_name);
    colon_tok = ref_node.gen_token(Tok.COLON);
    type_tag = uni.SubTag(tag=type_expr, kid=[colon_tok, type_expr]);
    hv_kid: list[uni.UniNode] = [name_node, type_tag, ref_node.gen_token(Tok.LBRACE)];
    for acc in accessors {
        hv_kid.append(acc);
    }
    hv_kid.append(ref_node.gen_token(Tok.RBRACE));
    has_var = uni.HasVar(
        name=name_node,
        type_tag=type_tag,
        value=None,
        defer=False,
        accessors=accessors,
        kid=hv_kid
    );
    has_kw = ref_node.gen_token(Tok.KW_HAS);
    return uni.ArchHas(
        is_static=False,
        vars=[has_var],
        is_frozen=False,
        access=None,
        doc=None,
        kid=[has_kw, has_var]
    );
}

impl JacAutoLintPass._convert_properties(container: uni.Archetype) -> None {
    if self._is_file_excluded(container.loc.mod_path) {
        return;
    }
    body = container.body;
    if not isinstance(body, list) {
        return;
    }
    groups: dict[str, dict[str, uni.Ability]] = {};
    group_indices: dict[str, list[int]] = {};
    prop_types: dict[str, uni.Expr] = {};
    order: list[str] = [];
    for (idx, item) in enumerate(body) {
        if not isinstance(item, uni.Ability) {
            continue;
        }
        role = self._property_role_of_ability(item);
        if role == "" or not isinstance(item.name_ref, uni.Name) {
            continue;
        }
        pname = item.name_ref.value;
        if pname not in groups {
            groups[pname] = {};
            group_indices[pname] = [];
            order.append(pname);
        }

        if role == "property" and pname not in prop_types {
            declared = (
                item.signature.return_type
                    if isinstance(item.signature, uni.FuncSignature)
                    else None
            );
            if declared is not None {
                prop_types[pname] = declared;
            }
        }
        groups[pname][role] = item;
        group_indices[pname].append(idx);
    }
    replaced: dict[int, uni.ArchHas] = {};
    dropped_ids: set[int] = set();
    for pname in order {
        g = groups[pname];
        if "property" not in g {
            continue;
        }
        getter_ab = g["property"];
        type_expr = (
            getter_ab.signature.return_type
                if isinstance(getter_ab.signature, uni.FuncSignature)
                else None
        );
        if type_expr is None {
            type_expr = prop_types.get(pname);
        }
        if type_expr is None {
            continue;
        }
        type_name = type_expr.value if isinstance(type_expr, uni.Name) else "...";
        if not self.ctx.emit(
            W3043, node_override=getter_ab, name=pname, type_name=type_name
        ) {
            continue;
        }
        if self.report_only {
            continue;
        }
        accessors: list[uni.Ability] = [
            self._make_accessor_from_ability(getter_ab, "property")
        ];
        if "setter" in g {
            accessors.append(self._make_accessor_from_ability(g["setter"], "setter"));
        }
        if "deleter" in g {
            accessors.append(self._make_accessor_from_ability(g["deleter"], "deleter"));
        }
        arch_has = self._build_property_has(getter_ab, pname, type_expr, accessors);
        indices = sorted(group_indices[pname]);
        for i in indices {
            dropped_ids.add(id(body[i]));
        }
        replaced[indices[0]] = arch_has;
    }
    if not replaced {
        return;
    }
    first_map: dict[int, uni.ArchHas] = {};
    new_body: list[uni.UniNode] = [];
    for (idx, item) in enumerate(body) {
        if idx in replaced {
            first_map[id(item)] = replaced[idx];
            new_body.append(replaced[idx]);
        } elif id(item) in dropped_ids {
            continue;
        } else {
            new_body.append(item);
        }
    }
    container._role_set(BodyRole, new_body);
    new_kid: list[uni.UniNode] = [];
    for k in container.kid {
        if id(k) in first_map {
            new_kid.append(first_map[id(k)]);
        } elif id(k) in dropped_ids {
            continue;
        } else {
            new_kid.append(k);
        }
    }
    container.set_kids(new_kid);
    container._invalidate_sub_node_tab();
    container._invalidate_sub_node_tab();
}

impl JacAutoLintPass._property_impl_roles(
    arch: uni.Archetype, prop_name: str
) -> dict[str, list[uni.Ability]] {
    roles: dict[str, list[uni.Ability]] = {};

    for member in arch.body {
        if not isinstance(member, uni.ArchHas) {
            continue;
        }
        for var in member.vars {
            if var.name.sym_name != prop_name or not var.accessors {
                continue;
            }
            for acc in var.accessors {
                roles.setdefault(acc.accessor_kind, []).append(acc);
            }
        }
    }
    if roles {
        return roles;
    }
    for member in arch.body {
        if not isinstance(member, uni.Ability) {
            continue;
        }
        if not member.name_ref or member.name_ref.sym_name != prop_name {
            continue;
        }
        role = self._property_role_of_ability(member);
        if role {
            roles.setdefault(role, []).append(member);
        }
    }

    for `getter in roles.get("property", []) {
        if isinstance(`getter.signature, uni.FuncSignature)
            and (`getter.signature.return_type is not None)
            and not self.ctx._is_suppressed(W3043, `getter.loc) {
            return roles;
        }
    }
    return {};
}

impl JacAutoLintPass._impl_property_kind(nd: uni.ImplDef) -> str {
    if not nd.target {
        return "";
    }
    last = nd.target[-1];
    if isinstance(last, uni.Name) and last.value in ["getter", "setter", "deleter"] {
        return "";
    }
    decl = nd.decl_link;
    if isinstance(decl, uni.Ability) {
        return self._property_role_of_ability(decl);
    }

    arch = self._impl_owner_archetype(nd);
    prop_name = last.sym_name if last else "";
    if arch is None or not prop_name {
        return "";
    }
    roles = self._property_impl_roles(arch, prop_name);
    if "property" not in roles {
        return "";
    }

    pending: dict[str, uni.Ability] = {};
    for (role, accessors) in roles.items() {
        for acc in accessors {
            if acc.body is None and role not in pending {
                pending[role] = acc;
            }
        }
    }
    if not pending {
        return "";
    }
    if len(pending) == 1 {
        return list(pending.keys())[0];
    }

    spec = nd.spec if isinstance(nd.spec, uni.FuncSignature) else None;
    for role in ["property", "setter", "deleter"] {
        acc = pending.get(role);
        acc_sig = acc.signature if acc is not None else None;
        if (
            isinstance(acc_sig, uni.FuncSignature)
            and (spec is not None)
            and self._signatures_match(acc_sig, spec)
        ) {
            return role;
        }
    }

    takes_value = (spec is not None) and len(spec.params or []) > 0;
    returns_value = (spec is not None) and (spec.return_type is not None);
    if takes_value and "setter" in pending {
        return "setter";
    }
    if not takes_value and not returns_value and "deleter" in pending {
        return "deleter";
    }
    if "property" in pending {
        return "property";
    }
    return list(pending.keys())[0];
}

impl JacAutoLintPass._convert_property_impl(nd: uni.ImplDef) -> None {
    if self._is_file_excluded(nd.loc.mod_path) {
        return;
    }
    kind = self._impl_property_kind(nd);
    if kind == "" {
        return;
    }
    last_target = nd.target[-1];
    prop_name = last_target.value if isinstance(last_target, uni.Name) else "?";
    if not self.ctx.emit(W3043, node_override=nd, name=prop_name, type_name="...") {
        return;
    }
    if self.report_only {
        return;
    }

    kw = "getter" if kind == "property" else kind;
    acc_name = self._make_name_node(last_target, kw);
    dot_tok = last_target.gen_token(Tok.DOT);

    end_col = last_target.loc.col_end;
    dot_tok.c_start = end_col;
    dot_tok.c_end = end_col;
    acc_name.c_start = end_col;
    acc_name.c_end = end_col;
    nd._role_set(TargetRole, list(nd.target) + [acc_name]);
    new_kid: list[uni.UniNode] = [];
    for k in nd.kid {
        new_kid.append(k);
        if k is last_target {
            new_kid.append(dot_tok);
            new_kid.append(acc_name);
        }
    }
    nd.set_kids(new_kid);
    nd._invalidate_sub_node_tab();

    if nd.decorators {
        drop_ids: set[int] = set();
        for dec in nd.decorators {
            is_prop = (
                isinstance(dec, uni.Name)
                and dec.value in ["property", "cached_property"]
            )
                or (
                    isinstance(dec, uni.AtomTrailer)
                    and dec.is_attr
                    and isinstance(dec.right, uni.Name)
                    and dec.right.value in ["setter", "deleter"]
                );
            if is_prop {
                drop_ids.add(id(dec));
            }
        }
        if drop_ids {
            nd._role_set(
                DecoratorsRole,
                [
                    d
                    for d in nd.decorators
                    if id(d) not in drop_ids
                ]
                    or None
            );
            stripped_kid: list[uni.UniNode] = [];
            for k in nd.kid {
                if id(k) in drop_ids {
                    if (
                        stripped_kid
                        and isinstance(stripped_kid[-1], uni.Token)
                        and (stripped_kid[-1].name == Tok.DECOR_OP)
                    ) {
                        stripped_kid.pop();
                    }
                    continue;
                }
                stripped_kid.append(k);
            }
            nd.set_kids(stripped_kid);
            nd._invalidate_sub_node_tab();
        }
    }
    nd._invalidate_sub_node_tab();
}
