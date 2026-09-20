import from jaclang.compiler.driver.pipeline { run_utility, UtilityProduct }


impl JacCompiler.parse_str(
    source_str: str,
    file_path: str,
    target_program: JacProgram,
    cancel_token: (Event | None) = None
) -> uni.Module {
    had_error = False;
    run_codespace_infer = False;
    if (file_path.endswith('.py') or file_path.endswith('.pyi')) {
        import from jaclang.compiler.passes.pyast_load_pass { PyastBuildPass }
        parsed_ast = py_ast.parse(source_str);
        py_ast_ret = run_utility(
            UtilityProduct.PYTHON_AST,
            uni.PythonModuleAst(
                parsed_ast, orig_src=uni.Source(source_str, mod_path=file_path)
            ),
            target_program,
            cancel_token=cancel_token
        );
        had_error = len(py_ast_ret.ctx.errors_had) > 0;
        converted = py_ast_ret.module;
        assert isinstance(converted, uni.Module);
        mod = converted;
    } else {
        import from jaclang.jac0core.ext_registry {
            is_retired_client_marker,
            is_retired_native_marker
        }
        if is_retired_native_marker(file_path) {
            raise ValueError(
                f"{file_path}: the .na.jac marker was retired in 0.35 -- rename "
                "the file to .jac; native placement is inferred (or forced by "
                "'jac build --native' / 'jac build --as native'). See 'jac guide "
                "reference/language/native-pathway'."
            );
        }
        if is_retired_client_marker(file_path) {
            raise ValueError(
                f"{file_path}: the .cl.jac marker was retired -- rename the "
                "file to .jac; client placement is inferred from JSX/npm "
                "imports (override via [placement.pins] in jac.toml). Run "
                "'jac fix placement' to migrate the project."
            );
        }
        import from jaclang.compiler.frontend.parser.frontend {
            annex_sources,
            parse_woven
        }
        codespace = '';
        import from jaclang.compiler.frontend.codeinfo {
            is_client_by_location as _cbl,
            is_native_by_location as _nbl
        }
        if _nbl(file_path) {
            codespace = 'native';
        }
        if not codespace and _cbl(file_path) {
            codespace = 'client';
        }
        if not codespace {
            import from jaclang.compiler.placement.placement_pins {
                effective_module_pin as _mod_pin
            }
            _pinned_space = _mod_pin(file_path);
            if _pinned_space in ('client', 'native') {
                codespace = _pinned_space;
            }
        }
        if not codespace {
            import from jaclang.compiler.native_scope {
                in_native_scope_path as _in_scope,
                scope_lowering_active as _scope_on
            }
            if _scope_on() and _in_scope(file_path) {
                codespace = 'native';
            }
        }
        if not codespace {
            _p_opts = target_program.options;
            _forced_pre = _p_opts.force_codespace if _p_opts is not None else '';
            if (
                not _forced_pre
                and _p_opts is not None
                and _p_opts.aot_mode
                and not self.selfhost.is_selfhost(target_program)
                and _default_codespace_for(target_program) == 'native'
            ) {
                _forced_pre = 'native';
            }
            if _forced_pre and not self.selfhost.is_selfhost(target_program) {
                codespace = _forced_pre;
            }
        }
        if not codespace and not self.selfhost.is_selfhost(target_program) {
            import from jaclang.compiler.placement.placement_pins {
                config_kind_space as _kind_space_of
            }
            _k_opts = target_program.options;
            _kind_space = _kind_space_of(
                file_path, _k_opts.app_kind if _k_opts is not None else ''
            );
            if _kind_space in ('client', 'native') {
                codespace = _kind_space;
            }
        }
        if self.selfhost.is_selfhost(target_program) {
            (mod, had_error) = parse_woven(
                source_str,
                file_path,
                target_program,
                annex_sources(file_path),
                early_context=codespace or 'server'
            );
        } else {
            (mod, had_error) = target_program.source_store.parse(
                source_str, file_path, target_program, annex_sources(file_path)
            );
        }
        if (codespace == 'client') {
            _coerce_client_module(mod);
        } elif (codespace == 'native') {
            _coerce_native_module(mod);
            na_coverage_record(mod.loc.mod_path, 'native');
        } elif codespace == 'server' {
            mod.set_code_context(CodeContext.SERVER);
        } else {
            run_codespace_infer = True;
        }
    }
    hub_key = target_program.hub_key(mod.loc.mod_path);
    if had_error {
        mod.parse_failed = True;
        target_program.install_module(hub_key, mod);
        return mod;
    }
    if target_program.mod.main.stub_only {
        old_hub = target_program.mod.hub;
        target_program.reset_module_root(uni.ProgramModule(main_mod=mod));

        target_program.mod.hub.clear();
        target_program.mod.hub.update(old_hub);
    }
    target_program.install_module(hub_key, mod);

    if run_codespace_infer {
        _opts = target_program.options;
        _analysis_only = _opts is not None and _opts.no_cgen;
        import from jaclang.compiler.native_scope {
            in_native_scope_path,
            scope_lowering_active
        }
        _scope_native = (
            scope_lowering_active() and in_native_scope_path(mod.loc.mod_path or '')
        );
        _native_eligible = (
            not _analysis_only
            and (
                _scope_native
                or (
                    not self.selfhost.is_selfhost(target_program)
                    and _default_codespace_for(target_program) == 'native'
                )
            )
        );
        if _native_eligible {
            import from jaclang.compiler.placement.placement_solver {
                native_default_verdict
            }
            (_na_ok, _na_why) = native_default_verdict(mod);
            if _na_ok {
                _coerce_native_module(mod);
                mod.codespace_inferred = True;
                na_coverage_record(mod.loc.mod_path, 'native');
            } elif _na_why == 'previously-demoted' {
                import from jaclang.compiler.placement.placement_pins {
                    _demoted_native_code
                }
                na_coverage_record(
                    mod.loc.mod_path,
                    'demoted',
                    _demoted_native_code(os.path.realpath(mod.loc.mod_path)),
                    _na_why
                );
            } else {
                na_coverage_record(mod.loc.mod_path, 'server', '', _na_why);
            }
        }
    }
    return mod;
}

impl JacCompiler.resolve_absorb_imports(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.compiler.frontend.unitree { find_python_scope_node_of }
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.from_loc is not None {
            for item in imp.items {
                if (
                    isinstance(item, uni.ModulePath) and item.path and not item.alias
                ) {
                    imp.jac_detected = imp.is_jac;
                    break;
                }
            }
        }
        if not imp.is_absorb {
            continue;
        }
        if (find_python_scope_node_of(imp) is None) {
            continue;
        }
        path_node = imp.items[0];
        if not isinstance(path_node, uni.ModulePath) {
            continue;
        }
        resolved = path_node.resolve_relative_path();
        module: (uni.Module | None) = None;
        if (resolved in target_program.mod.hub) {
            module = target_program.mod.hub[resolved];
        } elif resolved.endswith('.pyi') {
            try {
                module = target_program.load_dependency_module(
                    resolved, importer_path=mod.loc.mod_path
                );
            } except Exception {
                module = None;
            }
        } else {
            try {
                module = target_program.load_dependency_module(
                    resolved, importer_path=mod.loc.mod_path, need_tree=True
                );
            } except Exception {
                module = None;
            }
        }
        imp.absorbed_mod = module;
    }
}

impl JacCompiler.stamp_access_check_facts(mod: uni.Module) -> None {
    enforce = False;
    try {
        import from jaclang.project.config { get_config }
        config = get_config();
        if (config and config.check) {
            enforce = config.check.enforce_access;
        }
    } except Exception {
        enforce = False;
    }
    mod.access_enforced = enforce;
}

impl JacCompiler.stamp_native_import_facts(
    mod: uni.Module, target_program: JacProgram
) -> None {
    """Stamp each import with the emitter's native-only verdict.

    Whether an import resolves to a module the native lane owns, and
    whether that module lives inside jaclang's own tree, are both
    import-resolution questions: they need the hub, the placement pins
    and the filesystem, which is the driver's ground and not a pass's.
    The emitter used to ask for them through `self.prog`, the one
    driver read left in a sealed pass. It now consumes a bool.
    """;
    import os;
    import from jaclang.compiler.frontend.module_facts { ModuleFacts }
    needs_native = mod.decided_codespace == 'native'
        or ModuleFacts.has_native_context_stmts(mod);
    for imp in mod.get_all_sub_nodes(uni.Import) {
        target = native_only_import_target(imp, target_program);
        imp.native_only_drop = needs_native
            and target is not None
            and (os.sep + 'jaclang' + os.sep) not in os.path.abspath(target);
    }
}

impl JacCompiler.stamp_app_facts(mod: uni.Module, target_program: JacProgram) -> None {
    import from jaclang.project.modresolver { find_jac_project_root }
    import from jaclang.project.workspace { workspace_for_path }
    opts = target_program.options;
    mod_path = mod.loc.mod_path if mod.loc else '';
    mod.jac_project_root = find_jac_project_root(mod_path) if mod_path else None;
    ws = workspace_for_path(mod_path) if mod_path else None;
    app = ws.app_for_path(mod_path) if ws is not None else None;
    if app is None and ws is not None and opts.target_app {
        app = ws.apps.get(opts.target_app);
    }
    mod.app = app.name if app is not None else None;
    mod.app_root = ws.project_root if (app is not None and ws is not None) else None;
    target_kind = opts.app_kind if (opts is not None and opts.app_kind) else '';
    if app is not None {
        mod.app_kind = app.kind;
    } elif target_kind {
        mod.app_kind = target_kind;
    } else {
        mod.app_kind = '';
    }
    import from jaclang.project.workspace { UI_MOBUI }
    override_ui = opts.ui if (opts is not None and opts.ui) else '';
    ui = override_ui or (app.ui if app is not None else '');
    if ui == UI_MOBUI {
        enforced_root: (str | None) = None;
        if override_ui and opts.project_root {
            enforced_root = opts.project_root;
        }
        if enforced_root is None and ws is not None {
            enforced_root = ws.project_root;
        }
        if enforced_root is None {
            enforced_root = mod.jac_project_root;
        }
        mod.mobui_enforced_root = enforced_root;
    } else {
        mod.mobui_enforced_root = None;
    }
}

impl JacCompiler.stamp_boundary_facts(
    mod: uni.Module, target_program: JacProgram
) -> None {
    import from jaclang.compiler.frontend.codeinfo {
        is_bundled_native_module,
        resolve_native_module
    }
    import from jaclang.compiler.placement.placement_pins { config_module_pin }

    base_dir = '.';
    if mod.loc {
        base_dir = os.path.dirname(mod.loc.mod_path);
    }
    _sb_opts = target_program.options;
    in_native_mod = mod.loc is not None
        and (
            mod.decided_codespace == 'native'
            or (
                _sb_opts is not None
                and _sb_opts.aot_mode
                and not self.selfhost.is_selfhost(target_program)
                and _default_codespace_for(target_program) == 'native'
            )
        );

    def resolve_native(module_name: str, inferred_ok: bool) -> (str | None) {
        (src_mod_str, full_path) = resolve_native_module(
            module_name, base_dir, allow_inferred=inferred_ok
        );
        return os.path.realpath(full_path) if full_path is not None else src_mod_str;
    }

    def source_mod_for(resolved_path: (str | None)) -> (uni.Module | None) {
        if resolved_path is None or not os.path.isfile(resolved_path) {
            return None;
        }
        return target_program.load_dependency_module(
            resolved_path, importer_path=mod.loc.mod_path, need_tree=True
        );
    }

    def collect_abilities(nd: uni.UniNode, out: dict[(str, uni.Ability)]) {
        if isinstance(nd, uni.Ability) and nd.sym_name {
            out[nd.sym_name] = nd;
        }
        for k in nd.kid {
            collect_abilities(k, out);
        }
    }

    def collect_walkers(nd: uni.UniNode, out: dict[(str, uni.Archetype)]) {
        if isinstance(nd, uni.Archetype) and nd.sym_name {
            if nd.arch_kind == 'walker' {
                out[nd.sym_name] = nd;
            }
        }
        for k in nd.kid {
            collect_walkers(k, out);
        }
    }

    def imported_names(imp: uni.Import) -> set[str] {
        names: set[str] = set();
        for item in imp.items {
            if isinstance(item, uni.ModuleItem) {
                names.add(item.name.value);
            }
        }
        return names;
    }

    def stamp_sv_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        abilities: dict[(str, uni.Ability)] = {};
        walkers: dict[(str, uni.Archetype)] = {};
        try {
            collect_abilities(src, abilities);
        } except Exception {}
        try {
            collect_walkers(src, walkers);
        } except Exception {}
        for name in wanted {
            wk_decl = walkers.get(name);
            if wk_decl is not None {
                facts.sv_walkers[name] = wk_decl;
                continue;
            }
            ab_decl = abilities.get(name);
            if ab_decl is not None {
                facts.sv_abilities[name] = ab_decl;
            }
        }
    }

    def stamp_na_decls(imp: uni.Import, facts: uni.ImportBoundaryFacts) -> None {
        wanted = imported_names(imp);
        if not wanted {
            return;
        }
        src = source_mod_for(facts.from_loc_resolved);
        if src is None {
            return;
        }
        for decl in src.body {
            if not isinstance(decl, (uni.Ability, uni.Archetype, uni.Enum)) {
                continue;
            }
            name = decl.sym_name;
            if (
                not name
                or name not in wanted
                or name in facts.na_target_decls
                or name in facts.na_unmappable_targets
            ) {
                continue;
            }
            if isinstance(decl, uni.Ability)
                and isinstance(decl.signature, uni.FuncSignature) {
                facts.na_target_decls[name] = decl;
            } else {
                facts.na_unmappable_targets.append(name);
            }
        }
    }

    for nd in mod.get_all_sub_nodes(uni.Import) {
        facts = uni.ImportBoundaryFacts();
        nd.boundary_facts = facts;
        native_ctx = nd.codespace() == CodeContext.NATIVE;

        if (nd.from_loc and isinstance(nd.from_loc, uni.ModulePath)) {
            module_name = nd.from_loc.dot_path_str;
            if (not module_name and nd.from_loc.path) {
                module_name = '.'.join(p.value for p in nd.from_loc.path);
            }
            if module_name {
                cl_na_edge = is_client_native_edge_import(nd, target_program);
                facts.client_native_edge = cl_na_edge;
                na_intent = (
                    native_ctx
                    or in_native_mod
                    or import_declares_native_target(nd)
                    or cl_na_edge
                );
                facts.native_from_path = resolve_native(module_name, na_intent);
                try {
                    facts.from_loc_resolved = nd.from_loc.resolve_relative_path();
                } except Exception {
                    facts.from_loc_resolved = None;
                }
                facts.is_service = nd.is_service_import;
                if (nd.items and not facts.is_service and nd.in_client_context()) {
                    resolved = facts.from_loc_resolved;
                    if (resolved is not None and resolved.endswith('.jac')) {
                        try {
                            facts.pinned_server = (
                                config_module_pin(resolved) == 'server'
                            );
                        } except Exception {
                            facts.pinned_server = False;
                        }
                    }
                }
                if (
                    (facts.is_service and not facts.native_from_path)
                    or (nd.items and not facts.is_service and facts.pinned_server)
                ) {
                    stamp_sv_decls(nd, facts);
                }
                if (cl_na_edge and nd.items) {
                    stamp_na_decls(nd, facts);
                }
                if (
                    nd.items
                    and not facts.is_service
                    and not facts.pinned_server
                    and not cl_na_edge
                    and is_client_boundary_import(nd)
                ) {
                    linked_mod = source_mod_for(facts.from_loc_resolved);
                    if linked_mod is not None {
                        for item in nd.items {
                            if not isinstance(item, uni.ModuleItem) {
                                continue;
                            }
                            verdict = classify_client_import_item(linked_mod, item);
                            if verdict != ClientImportVerdict.BRIDGED {
                                continue;
                            }
                            sym_name = item.name.value;
                            decl = ability_of_symbol(linked_mod.lookup(sym_name));
                            if decl is not None {
                                facts.bridged_decls[sym_name] = decl;
                            }
                        }
                    }
                }
            }
        }

        if ((not nd.from_loc) and nd.is_absorb and nd.items and (not nd.clib_decls)) {
            item = nd.items[0];
            if (isinstance(item, uni.ModulePath) and item.path) {
                module_name = '.'.join(p.value for p in item.path);
                if module_name {
                    na_intent = (
                        native_ctx or in_native_mod or import_declares_native_target(nd)
                    );
                    facts.native_absorb_path = resolve_native(module_name, na_intent);
                }
            }
            continue;
        }

        if ((not nd.from_loc) and nd.items and (not nd.clib_decls)) {
            for item in nd.items {
                if (isinstance(item, uni.ModulePath) and item.path) {
                    whole_name = '.'.join(p.value for p in item.path);
                    eligible = is_bundled_native_module(whole_name)
                        or (item.alias is None and len(item.path) == 1);
                    if (whole_name and eligible) {
                        na_intent = (
                            native_ctx
                            or in_native_mod
                            or import_declares_native_target(nd)
                        );
                        item_path = resolve_native(whole_name, na_intent);
                        if item_path {
                            facts.native_item_paths[whole_name] = item_path;
                        }
                    }
                }
            }
        }
    }
}
