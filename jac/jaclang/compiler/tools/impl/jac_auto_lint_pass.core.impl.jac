impl JacAutoLintPass.postinit -> None {
    import from jaclang.compiler.driver.compilation_context { context_app }
    import from jaclang.compiler.driver.pass_driver { diagnostic_policy_for }
    import from jaclang.project.config {
        JacConfig,
        get_config_for_path,
        get_explicit_config
    }
    import from pathlib { Path }

    mod_path = self.module.loc.mod_path if self.module?.loc else None;
    config = (
        get_config_for_path(Path(mod_path)) if mod_path else get_explicit_config()
    )
        or JacConfig();
    if mod_path {
        _app = context_app(str(Path(mod_path).resolve()));
        if _app is not None and not _app.implicit and _app.name in config.apps {
            config = config.effective_for_app(_app.name);
        }
    }
    _opts = self.prog.options;
    _extra: list[str] = (
        list(_opts.suppress_codes)
            if (_opts is not None and _opts.suppress_codes)
            else []
    );
    self.ctx.policy = diagnostic_policy_for(config, _extra);
    if config.check?.lint {
        self._exclude_patterns = config.check.lint.exclude;
        self._project_root = str(config.project_root) if config.project_root else "";
    }
}

impl JacAutoLintPass._is_file_excluded(file_path: str) -> bool {
    import from jaclang.project.source { path_matches_exclude }
    return path_matches_exclude(file_path, self._exclude_patterns, self._project_root);
}

impl JacAutoLintPass.exit_ability with uni.Ability exit {
    if not self.lint_enabled {
        return;
    }

    if not self.report_only and self._pending_setters {
        self._pending_setters.pop();
    }
    if not self.ctx._is_suppressed(W3005) {
        sig = here.signature;
        if isinstance(sig, uni.FuncSignature) {
            self._remove_empty_parens_from_sig(here, sig, "signature");
        }
    }
    if here.body is not None and isinstance(here.body, list) {
        self._check_unnecessary_pass(list(here.body));
    }
    name = here.name_spec.sym_name if here.name_spec else "<anonymous>";
    self._check_unnecessary_none_return(here, here.body, here.signature, name);
    self._check_stale_has_read(here);
}

impl JacAutoLintPass._remove_staticmethod_from_kids(ability_node: uni.Ability) -> None {
    new_kids: list[uni.UniNode] = [];
    i = 0;
    kids = ability_node.kid;
    skip_next_ws = False;
    has_static_kw = False;
    staticmethod_loc: (uni.Name | None) = None;
    for kid in kids {
        if isinstance(kid, uni.Token) and kid.name == Tok.KW_STATIC {
            has_static_kw = True;
        }

        if isinstance(kid, uni.Name) and kid.value == "staticmethod" {
            staticmethod_loc = kid;
        }
    }
    while i < len(kids) {
        kid = kids[i];

        if (isinstance(kid, uni.Token) and kid.value == "@" and (i + 1) < len(kids)) {
            next_kid = kids[i + 1];
            if isinstance(next_kid, uni.Name) and next_kid.value == "staticmethod" {
                i += 2;
                skip_next_ws = True;
                continue;
            }
        }

        if skip_next_ws and isinstance(kid, uni.Token) {
            if kid.name in ("WS", "NL", "NEWLINE") or kid.value in ("\n", " ", "") {
                i += 1;
                skip_next_ws = False;
                continue;
            }
        }
        skip_next_ws = False;

        if (
            not has_static_kw
            and isinstance(kid, uni.Token)
            and kid.name in (Tok.KW_DEF, Tok.KW_CAN)
        ) {
            static_kw = ability_node.gen_token(Tok.KW_STATIC);
            if staticmethod_loc {
                static_kw.line_no = staticmethod_loc.loc.first_line;
                static_kw.c_start = staticmethod_loc.loc.col_start;
                static_kw.c_end = static_kw.c_start + len("static");
            }
            new_kids.append(static_kw);
            has_static_kw = True;
        }
        new_kids.append(kid);
        i += 1;
    }
    ability_node.set_kids(new_kids);
}

impl JacAutoLintPass.enter_ability with uni.Ability entry {
    if not self.lint_enabled or self.report_only {
        return;
    }
    if here.decorators {
        has_staticmethod = False;
        for dec in here.decorators {
            if isinstance(dec, uni.Name) and dec.value == "staticmethod" {
                has_staticmethod = True;
                break;
            }
        }
        if has_staticmethod and self.ctx.emit(W3001, node_override=here) {
            if not here.is_static {
                here.is_static = True;
            }
            new_decorators: list[uni.Expr] = [
                dec
                for dec in here.decorators
                if not (isinstance(dec, uni.Name) and dec.value == "staticmethod")
            ];
            here._role_set(DecoratorsRole, new_decorators or None);
        }
    }
    if not self.ctx._is_suppressed(W3001) and here.is_static {
        self._remove_staticmethod_from_kids(here);
    }

    if not self.ctx._is_suppressed(W3038) {
        self._convert_usestate_vars(here);
    }
    self._combine_has_in_node(here);
    if not here.is_method {
        return;
    }
    if not isinstance(here.name_ref, uni.Name)
        or isinstance(here.name_ref, uni.SpecialVarRef) {
        return;
    }
    new_tok_name: (str | None) = None;
    if here.name_ref.value == "__init__" {
        new_tok_name = Tok.KW_INIT.value;
    } elif here.name_ref.value == "__post_init__" {
        new_tok_name = Tok.KW_POST_INIT.value;
    }
    if new_tok_name is not None {
        init_name = here.name_ref.value;
        if not self.ctx.emit(W3004, node_override=here, name=init_name) {
            return;
        }
        old_ref = here.name_ref;
        old_ref.name = new_tok_name;
        old_ref.value = new_tok_name;
        special_ref = uni.SpecialVarRef(var=old_ref);
        here._role_set(NameRefRole, special_ref);
        here.name_spec = special_ref;
        for (idx, kid) in enumerate(here.kid) {
            if kid is old_ref {
                here.replace_kid(here.kid[idx], special_ref);
                break;
            }
        }
    }
}

impl JacAutoLintPass.enter_impl_def with uni.ImplDef entry {
    if not self.lint_enabled {
        return;
    }
    impl_node = here;

    if not self.ctx._is_suppressed(W3043) {
        self._convert_property_impl(impl_node);
    }
    if self.report_only {
        return;
    }
    if not self.ctx._is_suppressed(W3010) {
        self._fix_impl_signature_mismatch(impl_node);
    }
    if impl_node.body is not None and isinstance(impl_node.body, list) {
        new_body = self.combine_consecutive_has(list(impl_node.body));
        if len(new_body) != len(impl_node.body)
            and self.ctx.emit(W3002, node_override=impl_node) {
            impl_node._role_set(BodyRole, new_body);
            impl_node._invalidate_sub_node_tab();
        }
    }
}

impl JacAutoLintPass.exit_impl_def with uni.ImplDef exit {
    if not self.lint_enabled or self.ctx._is_suppressed(W3005) {
        return;
    }
    spec = here.spec;
    if not isinstance(spec, uni.FuncSignature) {
        return;
    }
    self._remove_empty_parens_from_sig(here, spec, "spec");
}

impl JacAutoLintPass.enter_enum with uni.Enum entry {
    if not self.lint_enabled or self.report_only {
        return;
    }
    enum_node = here;
    self._combine_has_in_node(enum_node);
}

impl JacAutoLintPass.enter_archetype with uni.Archetype entry {
    if not self.lint_enabled {
        return;
    }
    arch = here;

    if not self.ctx._is_suppressed(W3043)
        and arch.body is not None
        and isinstance(arch.body, list) {
        self._convert_properties(arch);
    }
    if self.report_only {
        return;
    }
    self._combine_has_in_node(arch);
}

impl JacAutoLintPass._is_future_annotations_import(stmt: uni.UniNode) -> bool {
    if not isinstance(stmt, uni.Import) {
        return False;
    }
    import_node = stmt;
    if import_node.from_loc is None {
        return False;
    }
    from_path = import_node.from_loc.path;
    if from_path is None or len(from_path) != 1 {
        return False;
    }
    first_path = from_path[0];
    if not isinstance(first_path, uni.Name) {
        return False;
    }
    if first_path.value != "__future__" {
        return False;
    }
    for item in import_node.items {
        if isinstance(item, uni.ModuleItem) {
            if isinstance(item.name, uni.Name) and item.name.value == "annotations" {
                return True;
            }
        }
    }
    return False;
}

impl JacAutoLintPass._fix_impl_signature_mismatch(impl_node: uni.ImplDef) -> None {
    if self._is_file_excluded(impl_node.loc.mod_path) {
        return;
    }
    decl: uni.Ability | None = None;
    if isinstance(impl_node.decl_link, uni.Ability) {
        decl = impl_node.decl_link;
    } else {
        arch_node = self._impl_owner_archetype(impl_node);
        if arch_node is None {
            return;
        }
        ability_name = impl_node.target[-1].sym_name if impl_node.target[-1] else None;
        if not ability_name {
            return;
        }
        for member in arch_node.body {
            if isinstance(member, uni.Ability) {
                if member.name_ref and member.name_ref.sym_name == ability_name {
                    decl = member;
                    break;
                }
            }
        }
    }
    if decl is None {
        return;
    }
    decl_sig = decl.signature;
    if not isinstance(decl_sig, uni.FuncSignature) {
        return;
    }
    if not isinstance(impl_node.spec, uni.FuncSignature) {
        return;
    }
    impl_sig = impl_node.spec;
    if self._signatures_match(decl_sig, impl_sig) {
        return;
    }
    if not self.ctx.emit(W3010, node_override=impl_node) {
        return;
    }
    import copy;

    new_sig = decl_sig.detached_copy();
    new_sig.set_parent(impl_node);
    old_spec = impl_node.spec;

    old_first_tok = old_spec.loc.first_tok;
    old_last_tok = old_spec.loc.last_tok;
    def _fix_token_positions(nd: uni.UniNode) {
        if isinstance(nd, uni.Token) {
            nd.orig_src = old_first_tok.orig_src;
            nd.line_no = old_first_tok.line_no;
            nd.end_line = old_first_tok.end_line;
            nd.c_start = old_first_tok.c_start;
            nd.c_end = old_first_tok.c_end;
            nd.pos_start = old_first_tok.pos_start;
            nd.pos_end = old_first_tok.pos_end;
        }
        for k in nd.kid {
            if k is not None {
                _fix_token_positions(k);
            }
        }
    }
    _fix_token_positions(new_sig);
    impl_node._role_set(SpecRole, new_sig);
    new_kids: list[uni.UniNode] = [];
    for kid in impl_node.kid {
        if kid is old_spec {
            new_kids.append(new_sig);
        } else {
            new_kids.append(kid);
        }
    }
    impl_node.set_kids(new_kids);
    impl_node._invalidate_sub_node_tab();
}

impl JacAutoLintPass._impl_owner_archetype(
    impl_node: uni.ImplDef
) -> (uni.Archetype | None) {
    if not impl_node.target or len(impl_node.target) < 2 {
        return None;
    }
    root_arch_name = impl_node.target[0].sym_name if impl_node.target[0] else None;
    if not root_arch_name or self.main_module is None {
        return None;
    }
    arch_node: uni.Archetype | None = None;
    if self.main_module.sym_tab {
        arch_sym = self.main_module.sym_tab.lookup(root_arch_name);
        if arch_sym and arch_sym.decl {
            candidate = arch_sym.decl.name_of;
            if isinstance(candidate, uni.Archetype) {
                arch_node = candidate;
            }
        }
    }
    if arch_node is None {
        for stmt in self.main_module.body {
            if isinstance(stmt, uni.Archetype) {
                if stmt.name_spec and stmt.name_spec.sym_name == root_arch_name {
                    arch_node = stmt;
                    break;
                }
            }
        }
    }

    if arch_node is None {
        for stmt in self._base_decl_archetypes(impl_node.loc.mod_path) {
            if stmt.name_spec and stmt.name_spec.sym_name == root_arch_name {
                arch_node = stmt;
                break;
            }
        }
    }
    if arch_node is None or not arch_node.body {
        return None;
    }
    for i in range(1, len(impl_node.target) - 1) {
        if arch_node is None {
            return None;
        }
        nested_name = impl_node.target[i].sym_name if impl_node.target[i] else None;

        if not nested_name {
            return None;
        }
        nested: uni.Archetype | None = None;

        for member in arch_node.body {
            if isinstance(member, uni.Archetype) {
                if member.name_spec and member.name_spec.sym_name == nested_name {
                    nested = member;
                    break;
                }
            }
        }

        if nested is None or not nested.body {
            return None;
        }
        arch_node = nested;
    }
    return arch_node;
}

impl JacAutoLintPass._base_decl_archetypes(annex_path: str) -> list[uni.Archetype] {
    if self._base_decls_loaded {
        return self._base_decl_cache;
    }
    self._base_decls_loaded = True;
    import from jaclang.compiler.driver.bccache { discover_base_file }
    import from jaclang.compiler.frontend.parser { parse as rd_parse }
    import from jaclang.project.source { read_file_with_encoding }
    import from jaclang.compiler.driver.program { JacProgram }
    base_path = discover_base_file(annex_path);
    if base_path is None {
        return self._base_decl_cache;
    }
    try {
        source_str = read_file_with_encoding(base_path);

        (base_mod, _had_error) = rd_parse(source_str, base_path, prog=JacProgram());
    } except Exception {
        return self._base_decl_cache;
    }
    self._base_decl_cache = [
        stmt
        for stmt in base_mod.body
        if isinstance(stmt, uni.Archetype)
    ];
    return self._base_decl_cache;
}

impl JacAutoLintPass._signatures_match(
    decl_sig: uni.FuncSignature, impl_sig: uni.FuncSignature
) -> bool {
    decl_params: Sequence[any] = decl_sig.params or [];
    impl_params: Sequence[any] = impl_sig.params or [];
    if (
        len(decl_params) != len(impl_params)
        or len(decl_sig.posonly_params) != len(impl_sig.posonly_params)
        or len(decl_sig.kwonlyargs) != len(impl_sig.kwonlyargs)
        or (decl_sig.varargs is None) != (impl_sig.varargs is None)
        or (decl_sig.kwargs is None) != (impl_sig.kwargs is None)
        or (decl_sig.return_type is None) != (impl_sig.return_type is None)
    ) {
        return False;
    }
    for (i, decl_param) in enumerate(decl_params) {
        impl_param = impl_params[i];

        if decl_param.name.value != impl_param.name.value {
            return False;
        }
    }
    for (i, decl_param) in enumerate(decl_sig.posonly_params) {
        impl_param = impl_sig.posonly_params[i];

        if decl_param.name.value != impl_param.name.value {
            return False;
        }
    }
    for (i, decl_param) in enumerate(decl_sig.kwonlyargs) {
        impl_param = impl_sig.kwonlyargs[i];

        if decl_param.name.value != impl_param.name.value {
            return False;
        }
    }
    return True;
}

impl JacAutoLintPass._stmt_body_list(
    nd: uni.UniNode
) -> (Sequence[uni.UniNode] | None) {
    if isinstance(nd, uni.Module) {
        return nd.body;
    }
    if isinstance(
        nd,
        (
            uni.Test,
            uni.ModuleCode,
            uni.TypedCtxBlock,
            uni.OpenStmt,
            uni.IfStmt,
            uni.ElseStmt,
            uni.TryStmt,
            uni.AwaitingClause,
            uni.Except,
            uni.FinallyStmt,
            uni.IterForStmt,
            uni.InForStmt,
            uni.WhileStmt,
            uni.ForeverStmt,
            uni.WithStmt,
            uni.MatchCase,
            uni.SwitchCase,
            uni.JsxSlot
        )
    ) {
        return nd.body;
    }
    if isinstance(nd, (uni.AstImplNeedingNode, uni.ImplDef, uni.LambdaExpr)) {
        return nd.body if isinstance(nd.body, Sequence) else None;
    }
    return None;
}

impl JacAutoLintPass._strip_redundant_semis(nd: uni.Module) -> None {
    if not self.lint_enabled or self.ctx._is_suppressed(W3013) {
        return;
    }
    removable: list[tuple[uni.UniNode, uni.Semi]] = [];
    stack: list[uni.UniNode] = [nd];
    while stack {
        current = stack.pop();
        body = self._stmt_body_list(current);
        if isinstance(body, list) and not isinstance(current, uni.JsxSlot) {
            semis = [
                s
                for s in body
                if isinstance(s, uni.Semi)
            ];
            if len(semis) == len(body)
                and isinstance(current, (uni.MatchCase, uni.SwitchCase)) {
                semis = semis[1:];
            }
            for semi in semis {
                removable.append((current, semi));
            }
        }
        for kid in current.kid {
            if kid is not None {
                stack.append(kid);
            }
        }
    }
    removable.sort(
        key=lambda (item) { (item[1].loc.first_line, item[1].loc.col_start); }
    );
    doomed: dict[int, tuple[uni.UniNode, set[int]]] = {};
    for (container, semi) in removable {
        if not self.ctx.emit(W3013, node_override=semi) {
            continue;
        }
        if self.report_only {
            continue;
        }
        if id(container) not in doomed {
            doomed[id(container)] = (container, set());
        }
        doomed[id(container)][1].add(id(semi));
    }
    for (container, semi_ids) in doomed.values() {
        body = self._stmt_body_list(container);
        if not isinstance(body, list) {
            continue;
        }
        container._role_set(
            BodyRole,
            [
                s
                for s in body
                if id(s) not in semi_ids
            ]
        );
        container.set_kids(
            [
                k
                for k in container.kid
                if id(k) not in semi_ids
            ]
        );
        container._invalidate_sub_node_tab();
    }
}

impl JacAutoLintPass._remove_empty_parens_from_sig(
    target_node: uni.UniNode, sig: uni.FuncSignature, sig_attr: str
) -> None {
    has_params = bool(
        sig.posonly_params or sig.params or sig.varargs or sig.kwonlyargs or sig.kwargs
    );
    if has_params {
        return;
    }
    has_parens = any(
        isinstance(kid, uni.Token) and kid.name in (Tok.LPAREN, Tok.RPAREN)
        for kid in sig.kid
    );
    if not has_parens {
        return;
    }
    if sig.return_type is None {
        if not self.ctx.emit(W3005, node_override=target_node) {
            return;
        }
        if self.report_only {
            return;
        }
        target_node._role_set(
            SignatureRole if sig_attr == "signature" else SpecRole, None
        );
        new_kid: list[uni.UniNode] = [];
        for kid in target_node.kid {
            if kid is not sig {
                new_kid.append(kid);
            }
        }
        target_node.set_kids(new_kid);
        target_node._invalidate_sub_node_tab();
    } else {
        if not self.ctx.emit(W3005, node_override=target_node) {
            return;
        }
        if self.report_only {
            return;
        }
        new_kid: list[uni.UniNode] = [];
        for kid in sig.kid {
            if isinstance(kid, uni.Token) and kid.name in (Tok.LPAREN, Tok.RPAREN) {
                continue;
            }
            new_kid.append(kid);
        }
        if len(new_kid) > 0 {
            sig.set_kids(nodes=new_kid);
        }
    }
}

impl JacAutoLintPass._extract_string_literal_value(expr: uni.Expr) -> (str | None) {
    attr_value: str | None = None;
    if isinstance(expr, uni.String) {
        attr_value = expr.value;
    } elif isinstance(expr, uni.MultiString) {
        if len(expr.strings) == 1 and isinstance(expr.strings[0], uni.String) {
            attr_value = expr.strings[0].value;
        }
    }
    if attr_value is None {
        return None;
    }
    if (attr_value.startswith('"') and attr_value.endswith('"'))
        or (attr_value.startswith("'") and attr_value.endswith("'")) {
        return attr_value[1:-1];
    }
    return None;
}

impl JacAutoLintPass.exit_module with uni.Module exit {
    self._strip_usestate_imports(here);
    self._strip_redundant_semis(here);
    self._strip_noise(here);
}

impl JacAutoLintPass._strip_noise(nd: uni.Module) -> None {
    if not self.lint_enabled {
        return;
    }

    if self._is_file_excluded(nd.loc.mod_path) {
        return;
    }

    if not self.ctx._is_suppressed(W3050) and nd.source.comments {
        kept: list[uni.CommentToken] = [];
        suppression_lines = nd.source.inline_suppressions;
        for comment in list(nd.source.comments) {
            if comment.line_no in suppression_lines {
                kept.append(comment);
                continue;
            }
            self.ctx.emit(W3050, node_override=comment);
        }
        if not self.report_only {
            nd.source.comments = kept;
        }
    }

    if not self.ctx._is_suppressed(W3051) {
        self._strip_docstrings(nd);
    }
}

impl JacAutoLintPass._strip_docstrings(start: uni.UniNode) -> None {
    doc_nodes: list[uni.AstDocNode] = [];
    self._collect_doc_nodes(start, doc_nodes);
    for `node in doc_nodes {
        doc_str = `node.doc;
        if doc_str is None {
            continue;
        }
        self.ctx.emit(W3051, node_override=doc_str);
        if self.report_only {
            continue;
        }
        `node._role_set(DocRole, None);
        new_kid: list[uni.UniNode] = [
            k
            for k in `node.kid
            if k is not doc_str
        ];
        `node.set_kids(nodes=new_kid if len(new_kid) else [uni.EmptyToken()]);
        `node._invalidate_sub_node_tab();
    }
}

impl JacAutoLintPass._collect_doc_nodes(
    `node: uni.UniNode, results: list[uni.AstDocNode]
) -> None {
    stack: list[uni.UniNode] = [`node];
    while stack {
        current = stack.pop();
        if isinstance(current, uni.AstDocNode) and current.doc is not None {
            results.append(current);
        }
        for kid in current.kid {
            if kid is not None {
                stack.append(kid);
            }
        }
    }
}

impl JacAutoLintPass._make_name_node(ref_node: uni.UniNode, value: str) -> uni.Name {
    return uni.Name(
        orig_src=ref_node.loc.orig_src,
        name=Tok.NAME.value,
        value=value,
        line=ref_node.loc.first_line,
        end_line=ref_node.loc.last_line,
        col_start=ref_node.loc.col_start,
        col_end=ref_node.loc.col_start + len(value),
        pos_start=ref_node.loc.pos_start,
        pos_end=ref_node.loc.pos_end,
        is_kwesc=False
    );
}
