import os;
import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.kinds { RunPlan }
import type from jaclang.project.config { JacConfig }
import type from jaclang.compiler.backends.native.llvm.binding.executionengine {
    ExecutionEngine
}


def _discover_config_from_file(filename: str) -> None {
    import from pathlib { Path }
    import from jaclang.project.config {
        JacConfig,
        get_config,
        project_scope_is_pinned,
        set_config
    }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.runtime.runtime { JacRuntime as Jac }

    file_path = Path(filename).resolve();

    Jac.set_full_target_path(str(file_path));
    file_dir = file_path.parent;

    if project_scope_is_pinned() {
        return;
    }

    existing_config = get_config();
    active_profile = existing_config.profile_override if existing_config else None;

    try {
        config = get_config(
            start_path=file_dir, force_discover=True, profile=active_profile
        );
    } except (OSError, KeyError, ValueError) as e {
        console.print(
            f"Warning: Failed to discover config from {file_dir}: {e}", style="warning"
        );
        return;
    }
    if config is not None {
        add_venv_to_path(config);
    }
}

def _project_label(config: any) -> str {
    name = config.project.name if config?.project else "";
    proj_root = str(config.project_root) if config?.project_root else "?";
    return f"'{name}' at {proj_root}" if name else proj_root;
}

def _app_serves(config: any, app: any) -> bool {
    import from jaclang.project.kinds { kind_spec }
    try {
        spec = kind_spec(config.resolved_kind(app));
    } except Exception {
        return False;
    }
    return spec is not None and spec.action == "serve";
}

def _project_serves(config: any) -> bool {
    if config is None {
        return False;
    }
    for app in config.apps.values() {
        if _app_serves(config, app) {
            return True;
        }
    }
    return False;
}

def _takes_over_app(config: any, file_path: str) -> bool {
    if config is None {
        return False;
    }
    app = _file_app(config, file_path, None);
    if app is None or not _app_serves(config, app) {
        return False;
    }
    project_root = str(config.project_root) if config.project_root else "";
    if not project_root {
        return True;
    }
    try {
        entry_file = app.entry_path(project_root);
    } except Exception {
        return True;
    }
    return os.path.abspath(file_path) != os.path.abspath(entry_file);
}

def _scope_notice(message: str) {
    console.print(f"jac run: {message}", file=sys.stderr, style="muted");
}

def _pin_run_scope(filename: str, takeover: (bool | None)) -> None {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig, get_config, pin_project_scope }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.runtime.runtime { JacRuntime as Jac }

    file_path = Path(filename).resolve();
    Jac.set_full_target_path(str(file_path));

    existing_config = get_config();
    active_profile = existing_config.profile_override if existing_config else None;

    try {
        owner = JacConfig.resolve(start_path=file_path.parent, profile=active_profile);
        ambient = JacConfig.resolve(start_path=Path.cwd(), profile=active_profile);
    } except (OSError, KeyError, ValueError) as e {
        console.warning(f"Failed to discover config from {file_path.parent}: {e}");
        return;
    }

    chosen = owner;
    notice = "";
    if takeover is False {
        chosen = None;
        context = owner or ambient;
        if context is not None {
            notice = (
                f"{file_path.name} runs standalone (--no-takeover); it will not "
                f"touch the project {_project_label(context)}"
            );
        }
    } elif owner is None {
        if ambient is not None {
            if takeover {
                chosen = ambient;
                notice = (
                    f"takeover: {file_path.name} runs as the project "
                    f"{_project_label(ambient)}, rewriting its client build"
                );
            } elif _project_serves(ambient) {
                notice = (
                    f"{file_path.name} is outside the project "
                    f"{_project_label(ambient)}; running it standalone "
                    "(--takeover runs it as this project)"
                );
            }
        }
    } elif takeover or _takes_over_app(owner, str(file_path)) {
        notice = (
            f"takeover: {file_path.name} runs as the project "
            f"{_project_label(owner)}, rewriting its client build "
            "(--no-takeover runs it standalone)"
        );
    }
    if notice {
        _scope_notice(notice);
    }

    pin_project_scope(chosen);
    if chosen is not None {
        add_venv_to_path(chosen);
    }
}

def _default_codespace_is_native -> bool {
    import from jaclang.project.config { get_config, PlacementConfig }
    cfg = get_config();
    effective = cfg.placement.default_codespace
        if cfg is not None
        else PlacementConfig().default_codespace;
    return effective == 'native';
}

def _populate_native_argv(engine: ExecutionEngine, argv: list[str]) -> None {
    import ctypes;

    argc_addr = int(engine.get_global_value_address("__jac_argc"));
    argv_addr = int(engine.get_global_value_address("__jac_argv"));
    if argc_addr == 0 or argv_addr == 0 {
        return;
    }

    argc = len(argv);
    c_strings = [ctypes.c_char_p(arg.encode("utf-8")) for arg in argv];
    c_argv = (ctypes.c_char_p * argc)(*c_strings);

    argc_ptr = ctypes.cast(argc_addr, ctypes.POINTER(ctypes.c_int32));
    argc_ptr[0] = argc;
    argv_ptr = ctypes.cast(argv_addr, ctypes.POINTER(ctypes.c_void_p));
    argv_ptr[0] = ctypes.cast(c_argv, ctypes.c_void_p).value;

    setattr(engine, "_jac_argv_refs", (c_strings, c_argv));
}

def _plan_ui(plan: RunPlan) -> str {
    return plan.spec.ui;
}

def _plan_route(plan: RunPlan, app: any) -> str {
    if app is None {
        return "";
    }
    return app.effective_route() if plan.spec.has_server else "";
}

def _print_plan(plan: RunPlan, app: any) {
    if app is not None and not app.implicit {
        console.print(f"app          : {app.name}");
    }
    console.print(f"kind         : {plan.kind}");
    console.print(f"action       : {plan.action}");
    console.print(f"summary      : {plan.summary}");
    if plan.entry_path {
        console.print(f"entry-point  : {plan.entry_path}");
    }
    ui = _plan_ui(plan);
    if ui {
        console.print(f"ui           : {ui}");
    }
    platform = str(plan.flags.get("platform", "") or "");
    if platform {
        console.print(f"platform     : {platform}");
    }
    route = _plan_route(plan, app);
    if route {
        console.print(f"route        : {route}");
    }
    console.print(f"equivalent   : {plan.command_line()}");
}

def _workspace_plans(cfg: any, project_root: str) -> list[RunPlan] {
    import from jaclang.project.kinds { plan_app_run, plan_workspace }
    try {
        return plan_workspace(cfg, project_root);
    } except ValueError {}
    plans: list[RunPlan] = [];
    for app in cfg.apps.values() {
        try {
            plans.append(plan_app_run(cfg, project_root, app));
        } except ValueError {}
    }
    return plans;
}

def _show_workspace(cfg: any, project_root: str) -> int {
    header = ["app", "kind", "entry_rel", "action", "ui", "route"];
    rows: list[list[str]] = [];
    planned: set[str] = set();
    for plan in _workspace_plans(cfg, project_root) {
        app = cfg.app(plan.app);
        planned.add(plan.app);
        entry_rel = (
            os.path.relpath(plan.entry_path, project_root) if plan.entry_path else "-"
        );
        rows.append(
            [
                plan.app,
                plan.kind,
                entry_rel,
                plan.action,
                _plan_ui(plan) or "-",
                _plan_route(plan, app) or "-"
            ]
        );
    }
    for (name, unplanned) in cfg.apps.items() {
        if name not in planned {
            app_cfg: any = unplanned;
            rows.append(
                [
                    name,
                    str(app_cfg.kind or "-"),
                    "(no entry)",
                    "-",
                    str(app_cfg.ui() or "-"),
                    "-"
                ]
            );
        }
    }
    widths = [max([len(r[i]) for r in ([header] + rows)]) for i in range(len(header))];
    console.print("  ".join([header[i].ljust(widths[i]) for i in range(len(header))]));
    console.print("  ".join(["-" * w for w in widths]));
    for row in rows {
        console.print("  ".join([row[i].ljust(widths[i]) for i in range(len(header))]));
    }
    if cfg.default_app {
        console.print(f"\ndefault-app  : {cfg.default_app}");
    }
    return 0;
}

def _serve_flag_spelling -> dict[str, str] {
    return {
        "port": "--port",
        "dev": "--dev",
        "api_port": "--api-port",
        "no_client": "--no-client",
        "faux": "--faux",
        "host": "--host",
        "platform": "--platform",
        "fleet": "--fleet",
        "workers": "--workers"
    };
}

def _flag_list(names: list[str]) -> str {
    return ", ".join(sorted(names));
}

def _port_is_explicit(port: (int | None), cfg: any) -> bool {
    if port is None {
        return False;
    }
    if cfg is None {
        return True;
    }
    raw = getattr(cfg, "_raw_data", {}).get("serve", {});
    return not (isinstance(raw, dict) and raw.get("port") == port);
}

def _serve_overrides(
    port: (int | None),
    dev: (bool | None),
    api_port: (int | None),
    no_client: (bool | None),
    faux: (bool | None),
    host: (str | None),
    platform: (str | None),
    fleet: bool,
    cfg: any,
    workers: (str | None) = None
) -> dict[str, any] {
    over: dict[str, any] = {};
    if _port_is_explicit(port, cfg) {
        over["port"] = port;
    }
    if dev is not None {
        over["dev"] = dev;
    }
    if api_port is not None {
        over["api_port"] = api_port;
    }
    if no_client is not None {
        over["no_client"] = no_client;
    }
    if faux is not None {
        over["faux"] = faux;
    }
    if host is not None {
        over["host"] = host;
    }
    if platform is not None {
        over["platform"] = platform;
    }
    if fleet {
        over["fleet"] = True;
    }
    if workers is not None {
        over["workers"] = workers;
    }
    return over;
}

def _entry_flags_used(
    entry_name: str, nd: str, root_id: str, debug_mode: bool
) -> list[str] {
    used: list[str] = [];
    if entry_name {
        used.append("--entry");
    }
    if nd {
        used.append("--node");
    }
    if root_id {
        used.append("--root");
    }
    if debug_mode {
        used.append("--debug");
    }
    return used;
}

def _kind_serve_flags(
    plan: (RunPlan | None), kind_serves: bool, serve_mode: (bool | None)
) -> dict[str, any] {
    if not kind_serves or plan is None {
        return {};
    }
    if serve_mode is not True {
        return dict(plan.flags);
    }
    return {
        k: v
        for (k, v) in plan.flags.items()
        if k != "dev"
    };
}

def _serve_with(
    entry_path: str,
    plan_flags: dict[str, any],
    over: dict[str, any],
    main: bool,
    app_name: str,
    takeover: bool = False
) -> int {
    import from jaclang.project.providers { initialize_provider_registry }

    if not entry_path {
        console.error(
            "Nothing to serve: no entry-point resolved.\n"
            "  Name a file or an app, or set the app's entry-point in jac.toml."
        );
        return 1;
    }
    initialize_provider_registry();

    kw: dict[str, any] = {
        "port": 0,
        "dev": False,
        "api_port": 0,
        "no_client": False,
        "faux": False,
        "host": "",
        "platform": "",
        "takeover": False,
        "fleet": False,
        "workers": ""
    };
    for (k, v) in plan_flags.items() {
        if k in kw {
            kw[k] = v;
        }
    }
    for (k, v) in over.items() {
        if k not in kw {
            raise ValueError(f"serve override {k!r} is not a serve argument");
        }
        kw[k] = v;
    }
    kw["takeover"] = takeover;
    return serve(filename=entry_path, main=main, app=app_name, **kw);
}

def _build_plan(plan: RunPlan) -> int {
    if plan.verb == "native" {
        import from jaclang.cli.commands.native_build { native_build }
        out = plan.flags.get("output", "");
        if out {
            out_dir = os.path.dirname(out);
            if out_dir {
                os.makedirs(out_dir, exist_ok=True);
            }
        }
        return native_build(
            filename=plan.entry_path, output=out, lib=plan.flags.get("lib", False)
        );
    }
    if plan.verb == "build" {
        import from jaclang.cli.commands.build { build }
        return build(
            target=plan.app,
            projection=plan.flags.get("as", "jab"),
            platform=plan.flags.get("platform", None)
        );
    }

    console.error(f"Project kind '{plan.kind}' has no build verb '{plan.verb}'.");
    return 1;
}

def _show_run(
    plan: (RunPlan | None), app: any, target: str, file: str, want_serve: bool
) -> int {
    if plan is None {
        act = "serve" if want_serve else "execute";
        console.print(f"jac run {target}  ->  {act} (explicit file; no app claims it)");
        return 0;
    }
    _print_plan(plan, app);
    if want_serve and plan.action != "serve" {
        console.print("override     : --serve forces serving");
    }
    if (not want_serve) and plan.action == "serve" {
        console.print("override     : --no-serve forces execution");
    }
    if (not want_serve) and plan.action == "build" and file {
        console.print("override     : a named file executes; a bare run builds");
    }
    return 0;
}

def _run_jab(
    filename: str, port: (int | None), args: list[str], serve_only: bool
) -> int {
    import from jaclang.dist.jab { materialize_jab }

    try {
        img_root = materialize_jab(filename);
    } except Exception as e {
        console.error(f"Cannot load {filename}: {e}");
        return 1;
    }
    return run_jab_image(img_root, port, args, serve_only, filename);
}
