impl JacCompiler.selfhost.getter -> SelfHostCache {
    cache = self._selfhost;
    if (cache is None) {
        import from jaclang.runtime.runtime { JacRuntime }
        cache = JacRuntime.get_selfhost();
        self._selfhost = cache;
    }
    return cache;
}

impl JacCompiler.stub_catalog -> StubCatalog | None {
    if self.stub_catalog_disabled or self._stub_trees_served {
        return None;
    }
    found = self._stub_catalog;
    if found is not None {
        return found;
    }
    import from jaclang.jac0core.stubcat_hook { active }
    found = active();
    self._stub_catalog = found;
    return found;
}

impl JacCompiler.note_stub_tree_served(path: str, program: JacProgram) -> None {
    if self._stub_trees_served or self.selfhost.is_selfhost(program) {
        return;
    }
    if self.stub_catalog() is not None {
        return;
    }
    import from jaclang.project.modresolver { _in_typeshed_tree }
    if _in_typeshed_tree(path) {
        self._stub_trees_served = True;
    }
}

impl JacCompiler.ensure_stub_catalog -> StubCatalog | None {
    if self.stub_catalog_disabled or self._stub_trees_served {
        return None;
    }
    found = self.stub_catalog();
    if found is None {
        import from jaclang.jac0core.stubcat_hook { env_disabled }
        if env_disabled() or self._stub_catalog_tried {
            return None;
        }
        self._stub_catalog_tried = True;
        import jaclang.compiler.types.stubcat.format;
        import jaclang.compiler.types.stubcat.reader;
        import from jaclang.compiler.types.stubcat.locate { ensure_catalog }
        found = ensure_catalog();
        self._stub_catalog = found;
    }

    internal = self._selfhost.peek_program() if self._selfhost is not None else None;
    if found is not None
        and internal is not None
        and not self._reentrant_depth
        and not internal.scratch.compile_depth
        and any(path.endswith('.pyi') for path in internal.mod.hub) {
        self.release_compile_state(internal);
    }
    return found;
}

impl JacCompiler.get_native_interop_setup(
    full_target: str, target_program: JacProgram
) -> tuple[((object | None), (dict[(str, object)] | None))] {
    import from jaclang.compiler.driver.compilation_context { program_for }
    actual_program = program_for(full_target, target_program);
    if (full_target in actual_program.hub.artifacts) {
        gen = actual_program.hub.artifacts[full_target];
        return (gen.native_engine, gen.interop_py_funcs);
    }
    if (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        native_engine = mod.gen.native_engine;
        interop_py_funcs = mod.gen.interop_py_funcs;
        return (native_engine, interop_py_funcs);
    }

    keyed = actual_program.find_module(full_target);
    if keyed is not None {
        return (keyed.gen.native_engine, keyed.gen.interop_py_funcs);
    }
    return (None, None);
}

impl JacCompiler.get_native_layout(
    full_target: str, target_program: JacProgram
) -> (NativeModuleLayout | None) {
    import from jaclang.compiler.driver.compilation_context { program_for }
    actual_program = program_for(full_target, target_program);
    _layout: NativeModuleLayout | None = None;
    if (full_target in actual_program.hub.artifacts) {
        gen = actual_program.hub.artifacts[full_target];
        _layout = gen.native_layout;
    } elif (full_target in actual_program.mod.hub) {
        mod = actual_program.mod.hub[full_target];
        _layout = mod.gen.native_layout;
    }
    if _layout is not None {
        JacCompiler._check_native_abi(_layout, full_target);
    }
    return _layout;
}

impl JacCompiler._check_native_abi(
    layout: NativeModuleLayout, full_target: str
) -> None {
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ABI_VERSION }
    stamped = layout.abi_version;
    if stamped is not None and stamped != NATIVE_ABI_VERSION {
        import logging as _abi_log;
        _abi_log.getLogger(__name__).warning(
            f"native ABI mismatch for {full_target}: layout abi_version="
            f"{stamped} but this compiler emits {NATIVE_ABI_VERSION}; recompile."
        );
    }
}

impl JacCompiler.get_bytecode(
    full_target: str, target_program: JacProgram
) -> (types.CodeType | None) {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program,
        compilation_scope
    }
    if full_target.endswith('.py') {
        import builtins;
        import from jaclang.project.source { read_file_with_encoding }
        return builtins.compile(
            read_file_with_encoding(full_target), full_target, 'exec'
        );
    }
    actual = self.selfhost.resolve(full_target, target_program);
    if not self.selfhost.is_selfhost(actual) {
        options = bind_options(full_target, actual, actual.options);
        actual = context_program(actual, options);
    }
    with compilation_scope(
        '' if self.selfhost.is_selfhost(actual) else actual.context_key, actual.options
    ) {
        return self._get_bytecode(full_target, actual);
    }
}

impl JacCompiler._get_bytecode(
    full_target: str, target_program: JacProgram
) -> (types.CodeType | None) {
    actual_program = self.selfhost.resolve(full_target, target_program);
    (rebuild, no_precompile) = cache_mode();
    symtab_only_recovery = False;

    if (
        (not rebuild)
        and (full_target in actual_program.mod.hub)
        and not actual_program.is_hub_entry_fresh(full_target)
    ) {
        actual_program.invalidate_module(full_target);
    }
    if (
        (not rebuild)
        and (full_target in actual_program.mod.hub)
        and not actual_program.mod.hub[full_target].gen.py_bytecode
    ) {
        actual_program.invalidate_module(full_target);
        symtab_only_recovery = True;
    } elif (
        (not rebuild)
        and (full_target in actual_program.mod.hub)
        and actual_program.mod.hub[full_target].gen.py_bytecode
    ) {
        hit_mod = actual_program.mod.hub[full_target];
        codeobj = hit_mod.gen.py_bytecode;
        if isinstance(codeobj, `bytes)
            and not self.selfhost.is_selfhost(actual_program) {
            self._persist_module_cache(full_target, hit_mod, actual_program);
        }
        return marshal.loads(codeobj) if isinstance(codeobj, `bytes) else None;
    }

    if not rebuild {
        sealed = self._sealed_jir_data(full_target);
        if sealed is not None {
            import from jaclang.compiler.driver.jir { PRECOMPILE_SENTINEL }
            (sealed_data, sealed_root) = sealed;
            bc = read_bytecode_only(sealed_data);
            if bc is not None {
                magic0: any = SECTIONS_MAGIC;
                sp0 = sealed_data.find(magic0, HEADER_SIZE);
                if sp0 >= 0 {
                    self._restore_sections(
                        full_target,
                        actual_program,
                        read_sections(sealed_data, sp0 + len(magic0)),
                        base_dir=sealed_root
                    );
                }
                return marshal.loads(
                    patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, sealed_root)
                );
            }
        }
    }

    cache_path = get_module_cache_path(full_target);
    if (not rebuild) and is_module_cache_valid(full_target, cache_path) {
        try {
            jir_data = cache_path.read_bytes();
            magic_bytes: any = SECTIONS_MAGIC;
            sec_pos = jir_data.find(magic_bytes, HEADER_SIZE);
            secs: dict[int, bytes] = (
                read_sections(jir_data, sec_pos + len(magic_bytes))
                    if sec_pos >= 0
                    else {}
            );
            bc = secs.get(SEC_BYTECODE);
            if bc is not None {
                self._restore_sections(full_target, actual_program, secs);
                _had_native_secs = SEC_NATIVE_OBJ in secs or SEC_LLVM_IR in secs;
                if (
                    _had_native_secs
                    and full_target not in actual_program.hub.artifacts
                    and not self.selfhost.is_selfhost(actual_program)
                ) {
                    import logging as _bc_logging;
                    _bc_logging.getLogger(__name__).warning(
                        f"Cached native sections for {full_target} could "
                        f"not be restored; recompiling."
                    );

                    cache_path.unlink(missing_ok=True);
                } else {
                    return marshal.loads(bc);
                }
            } else {
                if SEC_IFACE not in secs and SEC_CLIENT not in secs {
                    cache_path.unlink(missing_ok=True);
                }
                actual_program.invalidate_module(full_target);
                symtab_only_recovery = True;
            }
        } except Exception {}
    }

    allow_unsealed = (not rebuild) and (not no_precompile);
    precompiled = self._get_precompiled_jir_bytecode(full_target, allow_unsealed);
    if precompiled is not None {
        (precompiled_bc, precompiled_ctdeps) = precompiled;
        try {
            import from jaclang.compiler.driver.jir { SEC_CTDEPS as _PC_CTDEPS }
            _pc_sections: dict[int, bytes] = {};
            if precompiled_ctdeps {
                _pc_sections[_PC_CTDEPS] = precompiled_ctdeps;
            }
            write_module_cache(
                full_target,
                precompiled_bc,
                flags=FLAG_PRECOMPILED,
                extra_sections=_pc_sections
            );
        } except Exception {}
        return marshal.loads(precompiled_bc);
    }

    is_internal = self.selfhost.is_selfhost(actual_program);
    if is_internal {
        setup_progress.on_internal_compile(full_target);
        self.selfhost.enter_bytecode();
    }
    options = CompileOptions();
    result: (uni.Module | None) = None;
    enclosing_closure = self._closure_opts;
    self._closure_opts = options;
    try {
        result = self.compile(
            file_path=full_target, target_program=actual_program, options=options
        );
        if result.gen.py_bytecode {
            actual_program.hub_cache_stamp(full_target);
            self._persist_module_cache(full_target, result, actual_program);
            if is_internal {
                note_compiler_source_failure(full_target, '');
            }
            return marshal.loads(result.gen.py_bytecode);
        }
        if is_internal {
            note_compiler_source_failure(
                full_target,
                module_scoped_failure_details(full_target, actual_program)
                    or bootstrap_tier_failure_details(full_target)
            );
        }
        return None;
    } finally {
        self._closure_opts = enclosing_closure;
        if is_internal {
            if self.selfhost.at_outermost_bytecode() {
                self.selfhost.evict_unit(
                    full_target, result, collect=self.unit_collect
                );
            }
            self.selfhost.exit_bytecode();
        }
    }
}

impl JacCompiler._load_native_from_cache(
    full_target: str,
    target_program: JacProgram,
    cached_ir: str,
    cached_interop: (dict[str, any] | None)
) -> None {
    try {
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        llvm.initialize_native_target();
        llvm.initialize_native_asmprinter();
        import ctypes;
        import ctypes.util;
        libc_name = ctypes.util.find_library('c');
        if libc_name {
            llvm.load_library_permanently(libc_name);
        }
        libgc_name = ctypes.util.find_library('gc');
        if libgc_name {
            llvm.load_library_permanently(libgc_name);
        } else {
            libc = ctypes.CDLL(libc_name);
            malloc_addr = ctypes.cast(libc.malloc, ctypes.c_void_p).value;
            llvm.add_symbol('GC_malloc', malloc_addr);
        }
        llvm_mod = llvm.parse_assembly(cached_ir);
        llvm_mod.verify();
        target = llvm.Target.from_default_triple();
        assert isinstance(target, llvm.Target);
        target_machine = target.create_target_machine();
        engine = llvm.create_mcjit_compiler(llvm_mod, target_machine);
        assert isinstance(engine, llvm.ExecutionEngine);
        import from jaclang.compiler.frontend.codeinfo {
            CodeGenTarget,
            install_native_static_init
        }
        gen = CodeGenTarget();
        gen.native_engine = engine;
        py_func_table: dict[str, Callable[..., object]] = {};
        callbacks_list: list[object] = [];
        gen.interop_py_funcs = py_func_table;
        gen._interop_callbacks = callbacks_list;
        if cached_interop {
            import from jaclang.runtime.interop_bridge { register_py_callbacks }
            manifest = self._deserialize_interop_table(cached_interop);
            gen.interop_manifest = manifest;
            if manifest.native_imports {
                register_py_callbacks(
                    manifest.native_imports,
                    py_func_table,
                    callbacks_list,
                    llvm.add_symbol
                );
            }
        }
        install_native_static_init(engine, gen.interop_manifest);
        target_program.hub.artifacts[full_target] = gen;
    } except Exception as e {
        import logging;
        logging.getLogger(__name__).debug(
            f"Failed to load native module from cache: {e}"
        );
    }
}

impl JacCompiler._load_native_from_bitcode(
    full_target: str,
    target_program: JacProgram,
    section_data: bytes,
    cached_interop: (dict[str, any] | None)
) -> None {
    import struct as _struct;
    import jaclang.compiler.backends.native.llvm.binding as llvm;
    llvm.initialize_native_target();
    llvm.initialize_native_asmprinter();

    if len(section_data) < 2 {
        raise ValueError("SEC_NATIVE_OBJ section too short");
    }
    (triple_len, ) = _struct.unpack_from('<H', section_data, 0);
    if len(section_data) < 2 + triple_len {
        raise ValueError("SEC_NATIVE_OBJ triple truncated");
    }
    cached_triple = section_data[2:2 + triple_len].decode('utf-8');
    current_triple = llvm.get_default_triple();
    if cached_triple != current_triple {
        raise ValueError(
            f"Platform mismatch: cached={cached_triple}, current={current_triple}"
        );
    }
    bitcode = section_data[2 + triple_len:];

    import ctypes;
    import ctypes.util;
    libc_name = ctypes.util.find_library('c');
    if libc_name {
        llvm.load_library_permanently(libc_name);
    }

    llvm_mod = llvm.parse_bitcode(bitcode);
    target = llvm.Target.from_default_triple();
    assert isinstance(target, llvm.Target);
    target_machine = target.create_target_machine();
    engine = llvm.create_mcjit_compiler(llvm_mod, target_machine);
    assert isinstance(engine, llvm.ExecutionEngine);
    import from jaclang.compiler.frontend.codeinfo {
        CodeGenTarget,
        install_native_static_init
    }
    gen = CodeGenTarget();
    gen.native_engine = engine;
    py_func_table: dict[str, Callable[..., object]] = {};
    callbacks_list: list[object] = [];
    gen.interop_py_funcs = py_func_table;
    gen._interop_callbacks = callbacks_list;
    if cached_interop {
        import from jaclang.runtime.interop_bridge { register_py_callbacks }
        manifest = self._deserialize_interop_table(cached_interop);
        gen.interop_manifest = manifest;
        if manifest.native_imports {
            register_py_callbacks(
                manifest.native_imports, py_func_table, callbacks_list, llvm.add_symbol
            );
        }
    }
    install_native_static_init(engine, gen.interop_manifest);
    target_program.hub.artifacts[full_target] = gen;
}

impl JacCompiler._restore_sections(
    full_target: str,
    actual_program: JacProgram,
    secs: dict[int, bytes],
    base_dir: str = ""
) -> None {
    import pickle;
    client_bytes = secs.get(SEC_CLIENT);
    if client_bytes is not None {
        import from jaclang.compiler.frontend.codeinfo { ClientArtifact }
        restored_client = ClientArtifact.from_bytes(client_bytes);
        if restored_client is not None {
            actual_program.hub.client_artifacts[full_target] = restored_client;
        }
    }
    mtir_bytes = secs.get(SEC_MTIR);
    if mtir_bytes is not None {
        try {
            mtir_map = pickle.loads(mtir_bytes);
            actual_program.mtir_map.update(mtir_map);
        } except Exception {}
    }

    placement_bytes = secs.get(SEC_PLACEMENT);
    if placement_bytes is not None {
        try {
            import from jaclang.compiler.placement.placement {
                summary_from_bytes,
                summary_store
            }
            import from jaclang.compiler.driver.jir { JirPaths, SEC_PATH_ROOT }
            paths = JirPaths.from_bytes(secs.get(SEC_PATH_ROOT), base_dir);
            restored = summary_from_bytes(placement_bytes, path_mapper=paths.resolve);
            if restored is not None {
                summary_store(actual_program)[os.path.abspath(full_target)] = restored;
            }
        } except Exception {}
    }

    native_obj_bytes = secs.get(SEC_NATIVE_OBJ);
    if native_obj_bytes is not None {
        try {
            import json;
            cached_interop: (dict[str, any] | None) = None;
            interop_bytes = secs.get(SEC_INTEROP);
            if interop_bytes is not None {
                cached_interop = json.loads(interop_bytes.decode('utf-8'));
            }
            self._load_native_from_bitcode(
                full_target, actual_program, native_obj_bytes, cached_interop
            );
            return;
        } except Exception {}
    }

    llvm_bytes = secs.get(SEC_LLVM_IR);
    if llvm_bytes is not None {
        try {
            import zlib;
            import json;
            cached_ir = zlib.decompress(llvm_bytes).decode('utf-8');
            cached_interop2: (dict[str, any] | None) = None;
            interop_bytes2 = secs.get(SEC_INTEROP);
            if interop_bytes2 is not None {
                cached_interop2 = json.loads(interop_bytes2.decode('utf-8'));
            }
            self._load_native_from_cache(
                full_target, actual_program, cached_ir, cached_interop2
            );
        } except Exception {}
    }
}

impl JacCompiler._sealed_jir_data(full_target: str) -> (tuple[bytes, str] | None) {
    import from pathlib { Path as _Path }
    import from jaclang.jac0core { sealed as _sealed }
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    while True {
        bundle_dir = os.path.join(d, '_precompiled');
        if os.path.isdir(bundle_dir) {
            if _sealed.image_for_bundle_dir(bundle_dir) is None {
                return None;
            }
            norm_root = os.path.normpath(d);
            if not norm_file.startswith(norm_root + os.sep) {
                return None;
            }
            rel_path = norm_file[len(norm_root) + 1:];
            jir_path = os.path.join(
                bundle_dir, pyver, os.path.splitext(rel_path)[0] + '.jir'
            );
            if os.path.isfile(jir_path) {
                try {
                    return (_Path(jir_path).read_bytes(), d);
                } except OSError {
                    return None;
                }
            }
            return None;
        }
        parent = os.path.dirname(d);
        if parent == d {
            return None;
        }
        d = parent;
    }
}

impl JacCompiler._get_precompiled_jir_bytecode(
    full_target: str, allow_unsealed: bool = True
) -> (tuple[bytes, bytes] | None) {
    import from pathlib { Path as _Path }
    import from jaclang.compiler.driver.jir {
        PRECOMPILE_SENTINEL,
        SEC_CTDEPS,
        absolutize_ct_deps_section,
        cache_mode
    }
    import from jaclang.jac0core { sealed as _sealed }
    (rebuild_flag, no_precompile) = cache_mode();
    if rebuild_flag or no_precompile {
        return None;
    }
    norm_file = os.path.normpath(os.path.abspath(full_target));
    d = os.path.dirname(norm_file);
    pyver = f"cpython-{sys.version_info.major}{sys.version_info.minor}";
    while True {
        bundle_dir = os.path.join(d, '_precompiled');
        if os.path.isdir(bundle_dir) {
            norm_root = os.path.normpath(d);
            if not norm_file.startswith(norm_root + os.sep) {
                break;
            }
            rel_path = norm_file[len(norm_root) + 1:];
            jir_rel = os.path.splitext(rel_path)[0] + '.jir';
            jir_path = os.path.join(bundle_dir, pyver, jir_rel);

            sealed_img = _sealed.image_for_bundle_dir(bundle_dir);
            if sealed_img is None and not allow_unsealed {
                break;
            }
            if os.path.isfile(jir_path) {
                try {
                    jir_data = _Path(jir_path).read_bytes();
                    trusted = (
                        sealed_img is not None
                        or (
                            precompiled_jir_matches_source(
                                jir_data, norm_file, package_root=norm_root
                            )
                        )
                    );
                    if trusted {
                        bc = read_bytecode_only(jir_data);
                        if bc is not None {
                            _ct_raw = read_section_bytes(jir_data, SEC_CTDEPS);
                            return (
                                patch_co_filenames_bytes(bc, PRECOMPILE_SENTINEL, d),
                                absolutize_ct_deps_section(_ct_raw, norm_root)
                                    if _ct_raw
                                    else b"",

                            );
                        }
                    }
                } except Exception {}
            }
            break;
        }
        parent = os.path.dirname(d);
        if parent == d {
            break;
        }
        d = parent;
    }
    return None;
}

impl JacCompiler._build_interop_dict(result: uni.Module) -> dict[str, any] {
    manifest = result.gen.interop_manifest;
    if manifest is None {
        return {};
    }
    interop_data: dict[str, any] = {'bindings': {}};
    for (name, binding) in manifest.bindings.items() {
        interop_data['bindings'][name] = {
            'name': binding.name,
            'source_context': binding.source_context.value,
            'callers': [c.value for c in binding.callers],
            'ret_type': binding.ret_type,
            'param_types': binding.param_types,
            'param_names': binding.param_names,
            'source_module': binding.source_module,
            'kind': binding.kind,
            'provider_app': binding.provider_app,
            'native_contract': binding.native_contract,
            'endpoint_id': binding.endpoint_id
        };
    }

    interop_data['func_access'] = dict(manifest.func_access);
    interop_data['walker_access'] = dict(manifest.walker_access);
    interop_data['endpoint_effects'] = dict(manifest.endpoint_effects);
    interop_data['native_host_imports'] = dict(manifest.native_host_imports);
    interop_data['app_edges'] = list(manifest.app_edges);
    interop_data['provider_routes'] = dict(manifest.provider_routes);
    return interop_data;
}

impl JacCompiler._deserialize_interop_table(
    cached_interop: dict[str, any]
) -> InteropManifest {
    import from jaclang.compiler.frontend.codeinfo {
        InteropManifest,
        InteropBinding,
        InteropContext
    }
    manifest = InteropManifest();
    cached_bindings: dict[str, dict[str, any]] = cached_interop.get('bindings', {});
    for (name, data) in cached_bindings.items() {
        binding = InteropBinding(
            name=data['name'],
            source_context=InteropContext(data['source_context']),
            callers={InteropContext(c) for c in data.get('callers', [])},
            ret_type=data.get('ret_type', 'int'),
            param_types=data.get('param_types', []),
            param_names=data.get('param_names', []),
            source_module=data.get('source_module'),
            kind=data.get('kind', 'function'),
            provider_app=data['provider_app'],
            native_contract=data['native_contract'],
            endpoint_id=data['endpoint_id']
        );
        manifest.bindings[name] = binding;
    }
    manifest.func_access.update(cached_interop.get('func_access', {}));
    manifest.walker_access.update(cached_interop.get('walker_access', {}));
    manifest.endpoint_effects.update(cached_interop.get('endpoint_effects', {}));
    manifest.native_host_imports.update(cached_interop['native_host_imports']);
    manifest.app_edges.extend(cached_interop['app_edges']);
    manifest.provider_routes.update(cached_interop['provider_routes']);
    return manifest;
}

impl JacCompiler._persist_module_cache(
    full_target: str, result: uni.Module, actual_program: JacProgram
) -> None {
    import from jaclang.compiler.driver.jir {
        get_module_cache_path,
        is_module_cache_valid
    }
    try {
        _pmc_path = get_module_cache_path(full_target);
        if is_module_cache_valid(full_target, _pmc_path) {
            _pmc_data = _pmc_path.read_bytes();
            _pmc_client_done = (
                not result.gen.js
                or read_section_bytes(_pmc_data, SEC_CLIENT) is not None
            );
            if read_section_bytes(_pmc_data, SEC_BYTECODE) is not None
                and _pmc_client_done {
                return;
            }
        }
    } except Exception {
        return;
    }
    cache_bc = result.gen.py_bytecode;
    if cache_bc is None or result.parse_failed {
        return;
    }
    try {
        import pickle;
        import json;
        import zlib;
        sections: dict[int, bytes] = {};
        sections[SEC_BYTECODE] = cache_bc;
        if actual_program.mtir_map {
            sections[SEC_MTIR] = pickle.dumps(
                actual_program.mtir_map, int(pickle.HIGHEST_PROTOCOL)
            );
        }

        native_bc = result.gen.native_bitcode;
        if native_bc is not None {
            import struct as _struct;
            import jaclang.compiler.backends.native.llvm.binding as _llvm;
            triple_text = _llvm.get_default_triple();
            assert isinstance(triple_text, str);
            triple = triple_text.encode('utf-8');
            hdr = _struct.pack('<H', len(triple)) + triple;
            sections[SEC_NATIVE_OBJ] = hdr + native_bc;
        } else {
            llvm_ir = result.gen.llvm_ir;
            if llvm_ir is not None {
                sections[SEC_LLVM_IR] = zlib.compress(str(llvm_ir).encode('utf-8'), 6);
            }
        }
        interop_dict = self._build_interop_dict(result);
        if interop_dict {
            sections[SEC_INTEROP] = json.dumps(interop_dict).encode('utf-8');
        }
        client_artifact = self.client_artifact_of(result);
        if client_artifact is not None {
            try {
                sections[SEC_CLIENT] = client_artifact.to_bytes();
            } except Exception {}
        }
        try {
            import from jaclang.compiler.placement.placement {
                get_module_summary,
                summary_to_bytes
            }
            sections[SEC_PLACEMENT] = summary_to_bytes(
                get_module_summary(result, actual_program)
            );
        } except Exception {}
        import from jaclang.compiler.driver.jir {
            SEC_CTDEPS,
            ct_deps_section,
            write_module_cache
        }
        if result.ct_file_deps {
            sections[SEC_CTDEPS] = ct_deps_section(
                result.ct_file_deps, result.ct_body_deps
            );
        }
        write_module_cache(full_target, cache_bc, extra_sections=sections);
    } except Exception {}
}
