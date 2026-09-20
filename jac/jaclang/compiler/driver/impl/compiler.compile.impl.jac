impl JacCompiler.compile(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from jaclang.compiler.driver.compilation_context {
        bind_options,
        context_program
    }
    caller_program = target_program;
    resolved_program = self.selfhost.resolve(file_path, target_program)
        if not options.force_target_program
        else target_program;
    if not self.selfhost.is_selfhost(resolved_program) {
        options = bind_options(file_path, resolved_program, options);
        target_program = context_program(resolved_program, options);
    } else {
        target_program = resolved_program;
    }
    context_errors = len(target_program.errors_had);
    context_warnings = len(target_program.warnings_had);
    import from jaclang.compiler.driver.compilation_context { compilation_scope }
    identity = ''
        if self.selfhost.is_selfhost(target_program)
        else target_program.context_key;
    with compilation_scope(identity, options) {
        import from jaclang.compiler.native_scope {
            activate_scope_lowering,
            deactivate_scope_lowering,
            in_native_scope_path,
            scope_lowering_active
        }
        with compile_progress.track(str(file_path)) {
            _scope_armed = False;
            if (
                options.aot_mode
                and options.default_codespace == 'native'
                and self._reentrant_depth == 0
                and in_native_scope_path(str(file_path))
                and not scope_lowering_active()
            ) {
                activate_scope_lowering(str(file_path));
                _scope_armed = True;
            }
            if self._reentrant_depth == 0 and not self.stub_catalog_disabled {
                if not self.selfhost.is_selfhost(target_program) {
                    import from jaclang.compiler.types.stubcat.locate {
                        StubCatalogUnavailable
                    }
                    try {
                        self.ensure_stub_catalog();
                    } except StubCatalogUnavailable {}
                }
            }
            import from pathlib { Path as _WrapPath }
            import from jaclang.compiler.frontend.codeinfo {
                get_effective_default_codespace_override,
                set_effective_default_codespace
            }
            _prev_cs = get_effective_default_codespace_override();
            _depth_prev = self._reentrant_depth;
            self._reentrant_depth = _depth_prev + 1;
            if _depth_prev == 0 {
                self._closure_opts = options;
            }
            _gc_prev: (tuple[int, int, int] | None) = None;
            if _depth_prev == 0 and not os.environ.get('JAC_GC_NO_COMPILE_BOOST') {
                import gc;
                _gc_prev = gc.get_threshold();
                if _gc_prev[0] >= COMPILE_GC_THRESHOLDS[0] {
                    _gc_prev = None;
                } else {
                    gc.set_threshold(*COMPILE_GC_THRESHOLDS);
                }
            }
            _outer_opts: (CompileOptions | None) = None;
            _outer_prog: (JacProgram | None) = None;
            _scratch_prog: (JacProgram | None) = None;
            import from jaclang.compiler.driver.jir {
                native_ir_cache_set_suspended,
                native_ir_cache_suspended
            }
            _na_cache_prev = native_ir_cache_suspended();
            if options.no_ir_cache {
                native_ir_cache_set_suspended(True);
            }
            try {
                if options.force_target_program {
                    _wrap_prog = target_program;
                } else {
                    _wrap_prog = self.selfhost.resolve(file_path, target_program);
                }

                _scratch_prog = _wrap_prog;
                _wrap_prog.scratch.compile_depth += 1;
                if _depth_prev > 0 {
                    _outer_prog = _wrap_prog;
                    _outer_opts = _wrap_prog.options;
                }
                _pre_errs = len(_wrap_prog.errors_had);
                _pre_warns = len(_wrap_prog.warnings_had);
                _mod: (uni.Module | None) = None;
                _crash: (Exception | None) = None;
                try {
                    _mod = self._compile_once(
                        file_path=file_path,
                        target_program=target_program,
                        use_str=use_str,
                        options=options
                    );
                } except Exception as _e {
                    _crash = _e;
                }
                if _crash is not None {
                    _re_entered = import_error_re_enters(_crash, file_path);
                    if _re_entered is not None {
                        raise CompilerSourceError(
                            f"compiling {file_path} re-entered it: a pass imported "
                            f"'{_re_entered}' while Python was still executing that "
                            "module, so the name is not bound yet. A module a pass "
                            "reaches at run time belongs in the schedule's dependency "
                            "list (IR_SCHED_DEPS in jaclang.compiler.driver.pipeline), "
                            "which the loader pre-imports and which puts any compile "
                            "nested in its import on the bootstrap tier."
                        ) from _crash;
                    }
                }
                _resolved = os.path.realpath(file_path);
                _probe = _mod
                    if _mod is not None
                    else _wrap_prog.mod.hub.get(_resolved);
                _inferred_native = (
                    not options.aot_mode
                    and not options.force_codespace
                    and _probe is not None
                    and _probe.decided_codespace == 'native'
                );
                _failed = _crash is not None or len(_wrap_prog.errors_had) > _pre_errs;
                if not (_inferred_native and _failed) {
                    if _crash is not None {
                        raise _crash;
                    }
                    assert _mod is not None;
                    return _mod;
                }

                _is_ice = _crash is not None
                    and len(_wrap_prog.errors_had) == _pre_errs;
                if _is_ice and os.environ.get('JAC_NATIVE_ICE_RAISE') {
                    raise _crash;
                }
                _first_err = (
                    _wrap_prog.errors_had[_pre_errs].pretty_print().split('\n')[0]
                        if len(_wrap_prog.errors_had) > _pre_errs
                        else f"{type(_crash).__name__}: {_crash}"
                );
                _demote_alerts = _wrap_prog.errors_had[_pre_errs:];
                _demote_code = (
                    _demote_alerts[0].code.code
                        if (_demote_alerts and _demote_alerts[0].code is not None)
                        else type(_crash).__name__
                );
                na_coverage_record(
                    _resolved, 'ice' if _is_ice else 'demoted', _demote_code, _first_err
                );
                import from jaclang.compiler.placement.placement_pins {
                    _mark_demoted_native
                }
                _mark_demoted_native(_resolved, _demote_code);
                del _wrap_prog.errors_had[_pre_errs:];
                del _wrap_prog.warnings_had[_pre_warns:];
                try {
                    _wrap_prog.invalidate_module(_resolved);
                } except Exception {}
                try {
                    import from jaclang.compiler.placement.placement_solver {
                        invalidate_importers_es
                    }
                    for _stale_mod in invalidate_importers_es(_wrap_prog, _resolved) {
                        _drop_demoted_native_bindings(_stale_mod, _resolved);
                    }
                } except Exception as _reset_exc {
                    import logging as _reset_log;
                    _reset_log.getLogger(__name__).warning(
                        f"native demotion of {_resolved} could not reset its importers "
                        f"({_reset_exc}); stale client bindings may persist until a rebuild."
                    );
                }
                try {
                    import from jaclang.cli.console { console as _note_console }
                    (_note_msg, _note_style) = na_demotion_note(
                        file_path, _first_err, _is_ice
                    );
                    _note_console.print(_note_msg, style=_note_style, file=sys.stderr);
                } except Exception {}
                return self._compile_once(
                    file_path=file_path,
                    target_program=target_program,
                    use_str=use_str,
                    options=options
                );
            } finally {
                if target_program is not caller_program
                    and not self.selfhost.is_selfhost(target_program) {
                    caller_program.errors_had.extend(
                        target_program.errors_had[context_errors:]
                    );
                    caller_program.warnings_had.extend(
                        target_program.warnings_had[context_warnings:]
                    );
                }
                if _scope_armed {
                    deactivate_scope_lowering();
                }
                native_ir_cache_set_suspended(_na_cache_prev);
                set_effective_default_codespace(_prev_cs);
                self._reentrant_depth = _depth_prev;
                if _depth_prev == 0 {
                    self._closure_opts = None;
                    if caller_program is not target_program {
                        self._release_compile_scratch(caller_program);
                    }
                }
                if _outer_prog is not None and _outer_opts is not None {
                    _outer_prog.options = _outer_opts;
                }
                if _scratch_prog is not None {
                    _scratch_prog.scratch.compile_depth -= 1;
                    if _scratch_prog.scratch.compile_depth <= 0 {
                        _scratch_prog.scratch.compile_depth = 0;
                        self._release_compile_scratch(_scratch_prog);
                    }
                }
                if _gc_prev is not None {
                    import gc;
                    gc.set_threshold(*_gc_prev);
                }
            }
        }
    }
}

impl JacCompiler._release_compile_scratch(target_program: JacProgram) -> None {
    try {
        target_program.release_native_dep_units();
        target_program.release_check_caches();
    } except Exception {}
}

impl JacCompiler._compile_once(
    file_path: str,
    target_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from jaclang.jac0core.ext_registry { is_annex }
    if (use_str is None and options.resolve_annex_parent and is_annex(file_path)) {
        import from jaclang.compiler.driver.bccache { discover_base_file }
        base_path = discover_base_file(file_path);
        if (base_path and base_path not in target_program.mod.hub) {
            return self.compile(
                file_path=base_path, target_program=target_program, options=options
            );
        }
    }
    if options.force_target_program {
        actual_program = target_program;
    } else {
        actual_program = self.selfhost.resolve(file_path, target_program);
    }

    _prev_opts = actual_program.options;
    if _prev_opts is not None
        and not (options.nogc_enforce_all or options.memory_enforce) {
        options.nogc_enforce_all = _prev_opts.nogc_enforce_all;
        options.memory_enforce = _prev_opts.memory_enforce;
        options.memory_exempt = _prev_opts.memory_exempt;
    }
    if _prev_opts is not None and not options.default_codespace {
        options.default_codespace = _prev_opts.default_codespace;
    }
    _closure = self._closure_opts;
    if _closure is not None and _closure is not options and _closure.need_full_ast {
        options.need_full_ast = True;
    }
    actual_program.options = options;
    if options.default_codespace {
        import from jaclang.compiler.frontend.codeinfo {
            set_effective_default_codespace
        }
        set_effective_default_codespace(options.default_codespace);
    }

    _iface_reg: any = None;
    _iface_target = "";
    if use_str is None {
        _iface_target = os.path.realpath(str(file_path));
        _reg_probe = actual_program.iface_registry();
        if _reg_probe.eligible(self, _iface_target, options) {
            _served = _reg_probe.serve(self, _iface_target, options);
            if _served is not None {
                return _served;
            }
            _iface_reg = _reg_probe;
        }
    }
    if _iface_reg is None {
        return self._compile_pipeline(file_path, actual_program, use_str, options);
    }
    _err_start = len(actual_program.errors_had);
    _warn_start = len(actual_program.warnings_had);
    _iface_reg.frame_push(_iface_target);
    _mod_out: (uni.Module | None) = None;
    try {
        _mod_out = self._compile_pipeline(file_path, actual_program, use_str, options);
        try {
            _iface_reg.persist_after_compile(
                _iface_target, _mod_out, options, _err_start, _warn_start
            );
        } except Exception {}
    } finally {
        _iface_reg.frame_pop();
    }
    assert _mod_out is not None;
    return _mod_out;
}

impl JacCompiler._ingest_comptime_producers(
    mod_targ: uni.Module, actual_program: JacProgram, file_path: str
) -> None {
    if mod_targ is None or self.selfhost.is_selfhost(actual_program) {
        return;
    }
    saved_opts = actual_program.options;
    here_real = os.path.realpath(str(file_path));
    try {
        for imp in mod_targ.get_all_sub_nodes(uni.Import) {
            if not imp.is_comptime or imp.from_loc is None or imp.is_virtual_jac {
                continue;
            }
            try {
                target = imp.from_loc.resolve_relative_path();
            } except Exception {
                continue;
            }
            if not isinstance(target, str) or not target.endswith('.jac') {
                continue;
            }
            if not os.path.isfile(target) or os.path.realpath(target) == here_real {
                continue;
            }
            try {
                actual_program.load_dependency_module(
                    target, importer_path=file_path, need_tree=True
                );
            } except Exception as ct_ingest_err {
                import logging as _ct_logging;
                _ct_logging.getLogger(__name__).debug(
                    f"comptime producer {target} of {file_path} "
                    f"could not be ingested: {ct_ingest_err}"
                );
            }
        }
    } finally {
        actual_program.options = saved_opts;
    }
}

impl JacCompiler._compile_pipeline(
    file_path: str,
    actual_program: JacProgram,
    use_str: (str | None) = None,
    options: CompileOptions = CompileOptions()
) -> uni.Module {
    import from jaclang.compiler.driver.pipeline { compile_module }
    return compile_module(self, actual_program, file_path, options, use_str);
}

impl JacCompiler.build(
    file_path: str, target_program: JacProgram, use_str: (str | None) = None
) -> uni.Module {
    actual_program = self.selfhost.resolve(file_path, target_program);
    mod_targ = self.compile(
        file_path, actual_program, use_str, options=CompileOptions()
    );
    return mod_targ;
}

impl JacCompiler.run_schedule(
    mod: uni.Module,
    target_program: JacProgram,
    passes: list[type],
    cancel_token: (Event | None) = None
) -> None {
    import from jaclang.compiler.driver.pipeline { execute_passes }
    execute_passes(target_program, mod, passes, cancel_token);
}

impl JacCompiler._count_module_blocking_errors(
    target_program: JacProgram, mod_path: str
) -> int {
    count = 0;
    for e in target_program.errors_had {
        if e.code is None or not e.code.blocks_codegen {
            continue;
        }
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == mod_path {
            count += 1;
        }
    }
    return count;
}

impl JacCompiler._count_module_errors(
    target_program: JacProgram, mod_path: str
) -> int {
    count = 0;
    for e in target_program.errors_had {
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == mod_path {
            count += 1;
        }
    }
    return count;
}

impl JacCompiler._module_scoped_errors(
    target_program: JacProgram, mod_path: str
) -> bool {
    import from jaclang.compiler.frontend.diagnostics { Category }
    norm = os.path.normpath(mod_path);

    prefix = (norm[:-4] if norm.endswith('.jac') else norm) + '.';
    for e in target_program.errors_had {
        if e.code is None or e.code.category not in (Category.CODEGEN, Category.ICE) {
            continue;
        }
        try {
            e_path = os.path.normpath(e.loc.mod_path);
        } except Exception {
            continue;
        }
        if e_path == norm or e_path.startswith(prefix) {
            return True;
        }
    }
    return False;
}

impl JacCompiler._scrub_native_artifacts_on_error(
    target_program: JacProgram, mod: uni.Module
) -> bool {
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path {
        return False;
    }
    if not JacCompiler._module_scoped_errors(target_program, mod_path) {
        return False;
    }
    gen = mod.gen;
    gen.py_bytecode = None;
    gen.llvm_ir = None;
    gen.native_engine = None;
    gen.native_bitcode = None;
    gen.native_layout = None;
    return True;
}

impl JacCompiler._report_missing_native_ir(
    target_program: JacProgram, mod: uni.Module
) -> None {
    if mod?.gen is None or mod.gen.llvm_ir is not None {
        return;
    }
    mod_path = mod.loc.mod_path if mod?.loc else '';
    if not mod_path or JacCompiler._count_module_errors(target_program, mod_path) > 0 {
        return;
    }
    import from jaclang.compiler.frontend.diagnostics { E5092 }
    import from jaclang.compiler.frontend.module_facts { ModuleFacts }
    import from jaclang.compiler.passes.context { Alert }
    reason = native_schedule_failure();
    if not reason {
        (_avail, _why) = native_pipeline_available();
        if not _avail {
            reason = _why;
        }
    }
    if reason {
        detail = f"the native codegen schedule could not be built ({reason})";
    } elif not ModuleFacts.has_native_context_stmts(mod) {
        detail = "the module declares no native code for the backend to lower";
    } else {
        detail = (
            "the native codegen passes ran but emitted neither IR nor a "
            "diagnostic; this is a compiler bug -- please report it"
        );
    }
    from_pass: any = JcirGenPass;
    try {
        import from jaclang.compiler.backends.native { NaIRGenPass }
        from_pass = NaIRGenPass;
    } except Exception {}
    deliver_alerts(
        [
            Alert(
                msg=E5092.format_message(
                    kind='module', name=os.path.basename(mod_path)
                ),
                loc=mod.loc.span(),
                from_pass=from_pass,
                code=E5092,
                help_text=detail
            )
        ],
        [],
        target_program
    );
}

impl JacCompiler._prepare_tool_program(
    source_str: str, file_path: str
) -> tuple[JacProgram, (uni.Module | None)] {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.frontend.parser { parse as rd_parse }
    prog = JacProgram();
    (current_mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    if had_error {
        prog.reset_module_root(uni.ProgramModule(main_mod=current_mod));
        return (prog, None);
    }

    return (prog, current_mod);
}

impl JacCompiler.release_compile_state(target_program: JacProgram) -> None {
    if os.environ.get("JAC_NO_UNIT_EVICT") {
        return;
    }
    owner = target_program.context_root or target_program;
    internal = self._selfhost.peek_program() if self._selfhost is not None else None;
    if self._reentrant_depth
        or owner.scratch.compile_depth
        or (internal is not None and internal.scratch.compile_depth) {
        raise RuntimeError("Cannot release compiler state during compilation");
    }
    owner.release_compile_closure(collect=False, retain_stubs=False);
    if internal is not None and internal is not owner {
        internal.release_compile_closure(collect=False, retain_stubs=False);
    }

    import gc;
    gc.collect();
}
