import marshal;
import os;
import sys;
import types;
import from pathlib { Path }
import from jaclang.cli.console { console, use_line_buffered_output }
import from jaclang.cli.commands.cli_helpers { proc_file as _proc_file }
import from jaclang.project.kinds { RunPlan }
import type from jaclang.project.config { AppConfig, JacConfig }


impl run_jab_image(
    img_root: Path, port: (int | None), args: list[str], serve_only: bool, label: str
) -> int {
    import from jaclang.dist.jab { jab_app_meta }

    meta = jab_app_meta(img_root);
    kind = str(meta.get("kind") or "cli");
    entry_meta: dict[str, any] = meta.get("entry") or {};
    caps: list[str] = meta.get("capabilities") or [];
    entry_rel = str(entry_meta.get("path") or "");
    if not entry_rel {
        attach_note = ", attachable package" if "attachable" in caps else "";
        console.error(
            f"{label} has no entry (kind '{kind}'{attach_note}); "
            "it cannot be run directly."
        );
        return 1;
    }
    entry_abs = str(img_root / entry_rel);
    if not os.path.isfile(entry_abs) {
        console.error(f"{label}: sealed entry '{entry_rel}' missing from image.");
        return 1;
    }
    servable = kind in ["service", "service-mesh", "web-app", "web-static"];
    if serve_only or servable {
        serve_port = port;
        if serve_port is None {
            import from jaclang.project.config { get_config_for_path }
            img_cfg = get_config_for_path(img_root);

            serve_port = (
                img_cfg.serve.port if img_cfg and img_cfg.serve.port != 8000 else 0
            );
        }
        return serve(
            filename=entry_abs,
            port=serve_port,
            no_client=(kind == "service"),
            dev=False
        );
    }
    if kind in ["cli", "cli-native", "native-binary"] {
        if kind != "cli" {
            native_bin = _jab_native_bin(img_root, entry_rel);
            if native_bin {
                os.execv(native_bin, [native_bin] + [str(a) for a in args]);
            }
        }
        return run(target=entry_abs, args=args);
    }
    console.error(
        f"{label}: kind '{kind}' is not directly runnable from a jab "
        "(build its platform projection instead)."
    );
    return 1;
}

def _jab_native_bin(img_root: Path, entry_rel: str) -> (str | None) {
    import from jaclang.jac0core.ext_registry { base_stem }
    import from jaclang.server.sealed_serve { NATIVE_DIR_REL }
    try {
        import jaclang.compiler.backends.native.llvm.binding as llvm;
        triple = str(llvm.get_default_triple());
    } except Exception {
        return None;
    }
    stem = base_stem(os.path.basename(entry_rel));
    cand = os.path.join(str(img_root), NATIVE_DIR_REL, triple, stem);
    if os.path.isfile(cand) and os.access(cand, os.X_OK) {
        return cand;
    }
    return None;
}

def _is_file_target(target: str) -> bool {
    if not target {
        return False;
    }
    if "/" in target or "\\" in target {
        return True;
    }
    return target.lower().endswith((".jac", ".py", ".jab"));
}

def _load_cwd_config -> any {
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { initialize_provider_registry }

    initialize_provider_registry();
    existing_config = get_config();
    active_profile = existing_config.profile_override if existing_config else None;
    return get_config(
        start_path=Path.cwd(), force_discover=True, profile=active_profile
    );
}

def _project_root_of(cfg: any) -> str {
    return str(cfg.project_root) if cfg.project_root else os.getcwd();
}

def _effective_config(cfg: any, app: any) -> any {
    if cfg is None or app is None or app.name not in cfg.apps {
        return cfg;
    }
    return cfg.effective_for_app(app.name);
}

def _file_app(cfg: any, target: str, takeover: (bool | None)) -> any {
    if cfg is None {
        return None;
    }
    app = cfg.app_for_path(os.path.abspath(target));
    if app is None
        and (takeover is True or (not cfg.is_workspace and takeover is not False)) {
        try {
            app = cfg.resolve_app("");
        } except ValueError {
            app = None;
        }
    }
    return app;
}

def _resolve_target(
    target: str, takeover: (bool | None) = None
) -> tuple[JacConfig | None, AppConfig | None, str, int] {
    import from jaclang.project.config { get_config }

    if _is_file_target(target) {
        _pin_run_scope(target, takeover);
        _discover_config_from_file(target);
        cfg = get_config();
        return (cfg, _file_app(cfg, target, takeover), target, 0);
    }
    cfg = _load_cwd_config();
    if cfg is None {
        if target {
            console.error(
                f"'{target}' is not a file, and no jac.toml defines an app by that "
                "name.\n"
                "  Usage: jac run <app> (inside a project), or jac run <file.jac>."
            );
        } else {
            console.error(
                "No target given and no jac.toml found.\n"
                "  Usage: jac run <file.jac>, or run inside a Jac project directory."
            );
        }
        return (None, None, "", 1);
    }
    if target {
        app = cfg.app(target);
        if app is not None {
            return (cfg, app, "", 0);
        }
        if os.path.isfile(target) {
            _pin_run_scope(target, takeover);
            _discover_config_from_file(target);
            file_cfg = get_config();
            return (file_cfg, _file_app(file_cfg, target, takeover), target, 0);
        }
        console.error(
            f"No app named '{target}' in {cfg.toml_path}, and no such file.",
            hint=f"Apps: {', '.join(cfg.apps.keys())}"
        );
        return (cfg, None, "", 2);
    }
    try {
        app = cfg.resolve_app("");
    } except ValueError as e {
        console.error(str(e));
        return (cfg, None, "", 2);
    }
    return (cfg, app, "", 0);
}

def _resolve_plan(
    target: str, takeover: (bool | None) = None
) -> tuple[RunPlan | None, JacConfig | None, AppConfig | None, str, int] {
    import from jaclang.project.kinds { plan_app_run }

    (cfg, app, file, rc) = _resolve_target(target, takeover);
    if rc {
        return (None, cfg, None, file, rc);
    }
    if cfg is None or app is None {
        return (None, cfg, None, file, 0);
    }
    project_root = _project_root_of(cfg);
    try {
        plan = plan_app_run(
            cfg,
            project_root,
            app,
            entry_override=(os.path.abspath(file) if file else "")
        );
    } except ValueError as e {
        if file {
            return (None, cfg, app, file, 0);
        }
        key = (
            "[project] entry-point"
                if app.implicit
                else f"[apps.{app.name}] entry-point"
        );
        console.error(f"{e}\n  Set {key} in jac.toml (project root: {project_root}).");
        return (None, cfg, app, file, 2);
    }
    return (plan, cfg, app, file, 0);
}

def _invoke_entrypoint(
    filename: str, entrypoint: str, args: list[str], main: bool, root_id: str, nd: str
) -> int {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.runtime.constructs { WalkerArchetype }

    if not filename.endswith('.jac') {
        console.error('Not a valid file!\nOnly supports `.jac`');
        return 1;
    }
    _discover_config_from_file(filename);
    (base, mod, mach) = _proc_file(filename);

    if root_id {
        mach.set_user_root(root_id);
    }
    ret_module = Jac.jac_import(
        target=mod, base_path=base, override_name='__main__' if main else None
    );
    if not ret_module {
        mach.close();
        return 0;
    }
    (loaded_mod, ) = ret_module;
    if not loaded_mod {
        console.error('Errors occurred while importing the module.');
        mach.close();
        return 1;
    }
    archetype = getattr(loaded_mod, entrypoint)(*args);
    mach.set_entry_node(nd);
    if (
        isinstance(archetype, WalkerArchetype)
        and Jac.check_read_access(mach.entry_node)
    ) {
        Jac.`spawn(mach.entry_node.archetype, archetype);
    }
    mach.close();
    return 0;
}

impl run(
    target: str = "",
    show: bool = False,
    main: bool = True,
    cache: bool = True,
    diagnostics: str = "",
    entry_name: str = "",
    nd: str = "",
    root_id: str = "",
    debug_mode: bool = False,
    serve_mode: (bool | None) = None,
    port: (int | None) = None,
    dev: (bool | None) = None,
    api_port: (int | None) = None,
    no_client: (bool | None) = None,
    faux: (bool | None) = None,
    host: (str | None) = None,
    platform: (str | None) = None,
    takeover: (bool | None) = None,
    fleet: bool = False,
    workers: (str | None) = None,
    args: list[str] = [],
    backend: str = ""
) -> int {
    use_line_buffered_output();
    if backend not in ("", "python", "native") {
        console.error("--backend must be python or native.");
        return 1;
    }
    if backend and (target.endswith(".jab") or debug_mode or entry_name) {
        console.error(
            "--backend requires ordinary Jac source execution; it cannot be combined with .jab, --debug or --entry."
        );
        return 1;
    }

    if target.endswith(".jab") {
        if dev {
            console.error(
                "A sealed .jab never serves in dev mode; run the project "
                "source with --dev instead."
            );
            return 1;
        }
        if show {
            console.print(
                f"jac run {target}  ->  kind-aware dispatch (sealed app bundle)"
            );
            return 0;
        }
        return _run_jab(target, port, args, serve_only=(serve_mode is True));
    }

    if show and not target {
        cfg0 = _load_cwd_config();
        if cfg0 is not None and cfg0.is_workspace {
            return _show_workspace(cfg0, _project_root_of(cfg0));
        }
    }

    (plan, cfg, app, file, rc) = _resolve_plan(target, takeover);
    if rc {
        return rc;
    }
    eff = _effective_config(cfg, app);

    over = _serve_overrides(
        port, dev, api_port, no_client, faux, host, platform, fleet, eff, workers
    );
    entry_flags = _entry_flags_used(entry_name, nd, root_id, debug_mode);
    kind_serves = plan is not None and plan.action == "serve";
    kind_can_serve = plan is None or kind_serves or bool(_plan_ui(plan));

    if serve_mode is False {
        want_serve = False;
    } elif serve_mode is True {
        want_serve = True;
    } elif kind_serves {
        want_serve = True;
    } else {
        want_serve = bool(over) and kind_can_serve;
    }

    if over and not want_serve {
        spelling = _serve_flag_spelling();
        shown = _flag_list([spelling[k] for k in over]);
        kind = plan.kind if plan is not None else "cli";
        console.error(
            f"{shown} applies only when serving, but app kind '{kind}' "
            "executes.\n"
            "  Add --serve to serve it anyway, or drop the flag."
        );
        return 1;
    }
    if entry_flags and want_serve {
        console.error(
            f"{_flag_list(entry_flags)} applies only when executing, but this "
            "runs as a server.\n"
            "  Add --no-serve to execute instead, or drop the flag."
        );
        return 1;
    }

    if backend
        and (
            want_serve or (plan is not None and plan.action == "build" and not file)
        ) {
        console.error(
            "--backend applies only when executing Jac source, not serving or building an app."
        );
        return 1;
    }
    if backend
        and not (file or (plan.entry_path if plan is not None else "")).endswith(
            ".jac"
        ) {
        console.error("--backend requires a .jac source file.");
        return 1;
    }
    if show {
        if backend {
            console.print(f"backend      : {backend}");
        }
        return _show_run(plan, app, target, file, want_serve);
    }

    if want_serve {
        return _serve_with(
            file or (plan.entry_path if plan is not None else ""),
            _kind_serve_flags(plan, kind_serves, serve_mode),
            over,
            main,
            app.name if app is not None else "",
            takeover=takeover is True
        );
    }
    if plan is not None and plan.action == "build" and not file {
        return _build_plan(plan);
    }

    exec_target = file or (plan.entry_path if plan is not None else "");
    if not exec_target {
        console.error(
            "Nothing to run: no entry-point resolved.\n"
            "  Usage: jac run <app> or jac run <file.jac>."
        );
        return 1;
    }
    if debug_mode {
        return debug(filename=exec_target, main=main, cache=cache);
    }
    if entry_name {
        return _invoke_entrypoint(exec_target, entry_name, args, main, root_id, nd);
    }
    return _exec_file(exec_target, main, cache, diagnostics, args, backend);
}

def _exec_file(
    filename: str,
    main: bool,
    cache: bool,
    diagnostics: str,
    args: list[str],
    backend: str = ""
) -> int {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from jaclang.project.config { get_config }

    _discover_config_from_file(filename);

    if not cache {
        import from jaclang.compiler.driver.jir { scrub_cache_dirs }
        scrub_cache_dirs(os.path.dirname(os.path.abspath(filename)) or ".");
    }

    if not diagnostics {
        cfg = get_config();
        diagnostics = cfg.run.diagnostics if cfg else "error";
    }

    original_argv = sys.argv;
    sys.argv = [filename] + list(args);
    (base, mod, mach) = _proc_file(filename);
    lng = filename.split('.')[-1];
    import from jaclang.compiler.frontend.codeinfo {
        get_effective_default_codespace_override,
        set_effective_default_codespace
    }
    previous_codespace = get_effective_default_codespace_override();
    try {
        if backend {
            set_effective_default_codespace(
                'server' if backend == 'python' else 'native'
            );
        }
        if filename.endswith('.jac') {
            native_executed = False;

            _cfg_kind = get_config();
            _kind_forced = False;
            if _cfg_kind is not None {
                import from jaclang.project.kinds { resolve_app_kind }
                _abs_file = os.path.abspath(filename);
                _app = _cfg_kind.app_for_path(_abs_file);
                _kind_forced = (
                    _app is not None
                    and resolve_app_kind(_cfg_kind, _app, _abs_file) == 'cli-native'
                );
            }
            import from jaclang.compiler.driver.boundary_classify {
                module_demoted_native as _na_demoted
            }
            if backend != "python"
                and (
                    backend == "native"
                    or _kind_forced
                    or (
                        _default_codespace_is_native()
                        and sys.stdout is sys.__stdout__
                        and not _na_demoted(filename)
                    )
                ) {
                import ctypes;
                import from jaclang.compiler.driver.compile_options {
                    CompileOptions as _RunOpts
                }
                full_path = os.path.abspath(filename);
                program = Jac.get_program();
                _run_options = (
                    _RunOpts(force_codespace='native', force_target_program=True)
                        if _kind_forced or backend == "native"
                        else None
                );
                ir_mod = program.compile(file_path=full_path, options=_run_options);
                if program.errors_had {
                    for _err in program.errors_had {
                        console.error(_err.pretty_print());
                    }
                    return 1;
                }
                if (
                    ir_mod
                    and ir_mod.decided_codespace == 'native'
                    and ir_mod.gen.native_engine
                ) {
                    engine = ir_mod.gen.native_engine;
                    _populate_native_argv(engine, sys.argv);
                    if main {
                        addr = engine.get_function_address("jac_entry");
                        if addr != 0 {
                            fn = ctypes.CFUNCTYPE(None)(addr);
                            fn();
                            native_executed = True;
                        }
                    }
                }
                if (_kind_forced or backend == "native") and not native_executed {
                    console.error(
                        "Native execution was requested but did not produce a runnable native "
                        "entry (no engine or no jac_entry)."
                    );
                    return 1;
                }
            }
            if not native_executed {
                if backend == "python" {
                    import from jaclang.compiler.driver.compile_options {
                        CompileOptions
                    }
                    program = Jac.get_program();
                    program.compile(
                        file_path=os.path.abspath(filename),
                        options=CompileOptions(
                            force_codespace="server",
                            default_codespace="server",
                            force_target_program=True
                        )
                    );
                    if program.errors_had {
                        for error in program.errors_had {
                            console.error(error.pretty_print());
                        }
                        return 1;
                    }
                }
                Jac.jac_import(
                    target=mod,
                    base_path=base,
                    override_name='__main__' if main else None,
                    lng=lng
                );
            }
        } else {
            Jac.jac_import(
                target=mod,
                base_path=base,
                override_name='__main__' if main else None,
                lng=lng
            );
        }
        n_errors = len(Jac.get_program().errors_had);
        n_warnings = len(Jac.get_program().warnings_had);
        if diagnostics != "none" {
            if n_errors {
                for error in Jac.get_program().errors_had {
                    console.error(error.pretty_print());
                }
            }
            if diagnostics == "all" and n_warnings {
                for warning in Jac.get_program().warnings_had {
                    console.warning(f"{warning}");
                }
            }
        }
        return 1 if (n_errors and diagnostics != "none") else 0;
    } except Exception as e {
        if diagnostics != "none" {
            if Jac.get_program().errors_had {
                for error in Jac.get_program().errors_had {
                    console.error(error.pretty_print());
                }
            } else {
                import from jaclang.runtime.traceback_render { dump_traceback }
                console.error(dump_traceback(e));
            }
        }
        return 1 if diagnostics != "none" else 0;
    } finally {
        set_effective_default_codespace(previous_codespace);
        sys.argv = original_argv;
        mach.close();
    }
}

impl debug(filename: str, main: bool = True, cache: bool = False) -> int {
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.debugger { debugger as db }
    if len(sys.argv) > 1 and sys.argv[1] == "debug" {
        console.print(
            "note: 'jac debug' is deprecated; use jac run <file> --debug", style="muted"
        );
    }
    (base, mod) = os.path.split(filename);
    base = base or './';
    mod = mod[:-4];
    if filename.endswith('.jac') {
        bytecode = JacProgram().compile(filename).gen.py_bytecode;
        if bytecode {
            code = marshal.loads(bytecode);
            if db.has_breakpoint(bytecode) {
                run(filename, main, cache);
            } else {
                func = types.FunctionType(code, globals());
                console.print('Debugging with Jac debugger.\n');
                db.runcall(func);
                console.print('Done debugging.');
            }
        } else {
            console.error(f"Error while generating bytecode in {filename}.");
            return 1;
        }
    } else {
        console.error('Not a .jac file.');
        return 1;
    }
    return 0;
}
