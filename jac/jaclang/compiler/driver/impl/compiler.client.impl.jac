import from jaclang.compiler.driver.pipeline_types { AnalysisFact }


impl JacCompiler.jac_file_formatter(
    file_path: str, auto_lint: bool = False
) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    import from jaclang.compiler.driver.pipeline { execute_passes }
    current_mod = execute_passes(
        prog, current_mod, get_format_sched(auto_lint=auto_lint)
    );
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
    return prog;
}

impl JacCompiler.jac_str_formatter(
    source_str: str, file_path: str, auto_lint: bool = False
) -> JacProgram {
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    import from jaclang.compiler.driver.pipeline { execute_passes }
    current_mod = execute_passes(
        prog, current_mod, get_format_sched(auto_lint=auto_lint)
    );
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
    return prog;
}

impl JacCompiler.jac_file_linter(file_path: str) -> JacProgram {
    source_str = read_file_with_encoding(file_path);
    (prog, current_mod) = JacCompiler._prepare_tool_program(source_str, file_path);
    if current_mod is None {
        return prog;
    }
    import from jaclang.compiler.driver.pipeline { execute_passes }
    current_mod = execute_passes(prog, current_mod, get_lint_sched());
    prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
    return prog;
}

impl JacCompiler.client_codegen_target(
    full_target: str, target_program: JacProgram
) -> (uni.Module | None) {
    mod = target_program.find_module(full_target);
    if mod is None {
        return None;
    }
    if target_program.analysis.analyses_run.provides(mod, AnalysisFact.TYPE_OF) {
        return mod;
    }
    return None;
}

impl JacCompiler.ensure_client_codegen(
    mod: uni.Module, target_program: JacProgram
) -> bool {
    if mod.gen.js {
        return True;
    }
    import from jaclang.compiler.driver.pipeline { require_product, CompilationProduct }
    return require_product(target_program, mod, CompilationProduct.CLIENT);
}

impl JacCompiler.client_artifact_of(mod: uni.Module) -> (ClientArtifact | None) {
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
    js = mod.gen.js;
    if not js {
        return None;
    }
    native_sources: list[str] = [];
    if mod.declares_codespace(CodeContext.NATIVE) {
        native_sources.append(mod.loc.mod_path);
    }
    for binding in mod.gen.interop_manifest.client_native_imports {
        if binding.source_module {
            native_sources.append(str(binding.source_module));
        }
    }
    segments: list[tuple[int, int, int, int, str]] = [];
    import from jaclang.compiler.backends.es.estree { Node as EsNode }
    es_ast = mod.gen.es_ast;
    if isinstance(es_ast, EsNode) {
        try {
            import from jaclang.compiler.backends.es.es_unparse { es_to_js_with_map }
            (_, segments) = es_to_js_with_map(es_ast);
        } except Exception {
            segments = [];
        }
    }
    manifest = mod.gen.client_manifest;
    digests: dict[str, str] = {};
    for dep_path in manifest.imports.values() {
        dep = str(dep_path);
        if not os.path.isfile(dep) {
            continue;
        }
        try {
            digests[dep] = compute_content_sha256(dep);
        } except OSError {
            continue;
        }
    }
    import from jaclang.compiler.backends.es.backends.registry {
        resolve_active_backend
    }
    return ClientArtifact(
        js=js,
        manifest=manifest,
        native_import_sources=native_sources,
        source_map=segments,
        dep_digests=digests,
        boundary_contracts=self._build_interop_dict(mod),
        framework=resolve_active_backend().name()
    );
}

impl JacCompiler._cached_client_artifact(full_target: str) -> (ClientArtifact | None) {
    import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
    (rebuild, _no_precompile) = cache_mode();
    if rebuild {
        return None;
    }
    try {
        cache_path = get_module_cache_path(full_target);
        if not is_module_cache_valid(full_target, cache_path) {
            return None;
        }
        raw = read_section_bytes(cache_path.read_bytes(), SEC_CLIENT);
    } except Exception {
        return None;
    }
    if raw is None {
        return None;
    }
    return ClientArtifact.from_bytes(raw);
}

impl JacCompiler._client_deps_fresh(artifact: ClientArtifact) -> bool {
    for (dep, digest) in artifact.dep_digests.items() {
        try {
            if compute_content_sha256(dep) != digest {
                return False;
            }
        } except OSError {
            return False;
        }
    }
    return True;
}

impl JacCompiler._persist_client_artifact(
    full_target: str, artifact: ClientArtifact
) -> None {
    try {
        write_module_cache(
            full_target, None, extra_sections={SEC_CLIENT: artifact.to_bytes()}
        );
    } except Exception {}
}

impl JacCompiler.get_client_artifact(
    full_target: str, target_program: JacProgram
) -> (ClientArtifact | None) {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program,
        compilation_scope
    }
    actual = self.selfhost.resolve(full_target, target_program);
    if not self.selfhost.is_selfhost(actual) {
        options = bind_options(full_target, actual, actual.options);
        actual = context_program(actual, options);
    }
    with compilation_scope(
        '' if self.selfhost.is_selfhost(actual) else actual.context_key, actual.options
    ) {
        return self._get_client_artifact(full_target, actual);
    }
}

impl JacCompiler._get_client_artifact(
    full_target: str, target_program: JacProgram
) -> (ClientArtifact | None) {
    full_target = JacProgram.hub_key(full_target);
    actual_program = self.selfhost.resolve(full_target, target_program);
    ready = self.client_codegen_target(full_target, actual_program);
    if ready is not None {
        if not self.ensure_client_codegen(ready, actual_program) {
            return None;
        }
        built = self.client_artifact_of(ready);
        if built is not None {
            actual_program.hub.client_artifacts[full_target] = built;
            self._persist_client_artifact(full_target, built);
        }
        return built;
    }

    has_live_tree = actual_program.find_module(full_target) is not None;
    held = actual_program.hub.client_artifacts.get(full_target)
        if not has_live_tree
        else None;
    if held is None and not has_live_tree {
        held = self._cached_client_artifact(full_target);
    }
    if held is not None {
        import from jaclang.compiler.backends.es.backends.registry {
            resolve_active_backend
        }
        if (
            held.framework == resolve_active_backend().name()
            and JacCompiler._client_deps_fresh(held)
        ) {
            actual_program.hub.client_artifacts[full_target] = held;
            return held;
        }
        actual_program.hub.client_artifacts.pop(full_target, None);
    }
    mark = len(actual_program.errors_had);
    compiled = self.compile(
        file_path=full_target,
        target_program=actual_program,
        options=CompileOptions(no_cgen=True)
    );
    if len(actual_program.errors_had) > mark {
        return None;
    }
    if not self.ensure_client_codegen(compiled, actual_program) {
        return None;
    }
    built = self.client_artifact_of(compiled);
    if built is not None {
        actual_program.hub.client_artifacts[full_target] = built;
        self._persist_module_cache(full_target, compiled, actual_program);
        self._persist_client_artifact(full_target, built);
    }
    return built;
}
