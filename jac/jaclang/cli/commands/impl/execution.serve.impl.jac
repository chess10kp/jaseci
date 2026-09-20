import os;
import from pathlib { Path }
import from jaclang.cli.console { console, use_line_buffered_output }
import from jaclang.cli.commands.cli_helpers { proc_file as _proc_file }
import from jaclang.server.build_status { BuildMonitor }
import from jaclang.server.assembly {
    gateway_colocates as _gateway_colocates,
    service_apps as _service_apps
}
import from jaclang.project.kinds { RunPlan }


def _serve_app(cfg: any, app: str, filename: str) -> any {
    if cfg is None {
        return None;
    }
    if app {
        named = cfg.app(app);
        if named is not None {
            return named;
        }
    }
    return cfg.app_for_path(os.path.abspath(filename));
}

def _serve_fleet(
    cfg: any,
    served: any,
    filename: str,
    port: int,
    fleet: bool,
    dev: bool = False,
    no_client: bool = False
) -> (int | None) {
    if cfg is None or served is None {
        if fleet {
            console.error(
                "--fleet has nothing to run: no jac.toml app claims this file.\n"
                "  Declare [apps.<name>] kind = \"service\" entries and run an app."
            );
            return 1;
        }
        return None;
    }
    services = _service_apps(cfg, served);
    if not services {
        if fleet {
            console.error(
                "--fleet has nothing to run: no service apps are declared.\n"
                "  Declare them as [apps.<name>] kind = \"service\" in jac.toml."
            );
            return 1;
        }
        return None;
    }
    if not fleet and _gateway_colocates(cfg) {
        return None;
    }
    import from jaclang.project.kinds { plan_app_run }
    import from jaclang.scale.plugin { scale_local_serve }

    project_root = (
        str(cfg.project_root)
            if cfg.project_root
            else os.path.dirname(os.path.abspath(filename))
    );
    try {
        served_plan = plan_app_run(
            cfg, project_root, served, entry_override=os.path.abspath(filename)
        );
        members: list[RunPlan] = [
            plan_app_run(cfg, project_root, svc) for svc in services
        ];
    } except ValueError as e {
        console.error(f"Cannot assemble the service fleet: {e}");
        return 1;
    }
    return scale_local_serve(
        served_plan, members, port=port, dev=dev, no_client=no_client
    );
}

impl serve(
    filename: str,
    port: int = 0,
    main: bool = True,
    faux: bool = False,
    dev: bool = False,
    api_port: int = 0,
    no_client: bool = False,
    host: str = "",
    platform: str = "",
    takeover: bool = False,
    fleet: bool = False,
    app: str = "",
    workers: str = ""
) -> int {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    import from pathlib { Path }
    import from jaclang.compiler.frontend.codeinfo { set_effective_default_codespace }
    import from jaclang.project.config { get_config }

    use_line_buffered_output();
    set_effective_default_codespace('server');

    if filename.endswith(".jab") {
        if dev {
            console.error(
                "A sealed .jab never serves in dev mode; run the project "
                "source with --dev instead."
            );
            return 1;
        }
        return _run_jab(filename, port, [], serve_only=True);
    }
    if not Path(filename).exists() {
        console.error(f"couldn't read `{filename}`: No such file or directory");
        return 1;
    }

    _discover_config_from_file(filename);
    cfg = get_config();
    served = _serve_app(cfg, app, filename);
    if served is not None {
        import from jaclang.client.cli { run_client_start }
        client_rc = run_client_start(
            served, host, platform, port, api_port, dev, no_client
        );
        if client_rc is not None {
            return client_rc;
        }
    }

    import from jaclang.scale.runtime.provider { mark_scale_runtime }
    mark_scale_runtime();
    fleet_rc = _serve_fleet(cfg, served, filename, port, fleet, dev, no_client);
    if fleet_rc is not None {
        return fleet_rc;
    }

    if takeover {
        import from jaclang.server.session { takeover_project }
        tk_base = Jac.get_base_path_dir() or (os.path.split(filename)[0] or './');
        tk_target = Jac.get_full_target_path() or filename;
        evicted = takeover_project(tk_base, tk_target);
        if evicted {
            console.info(
                f"takeover: evicted {evicted} session(s) holding this"
                " project's database"
            );
        }
    }
    (base, mod, mach) = _proc_file(filename);

    try {
        console.print("Preparing application...", style="bold");
        import from jaclang.compiler.driver.application { prepare_application }
        import from jaclang.server.assembly { service_apps }
        project_root = str(cfg.project_root) if cfg and cfg.project_root else base;
        services = service_apps(cfg, served) if cfg and served else [];
        prepared = prepare_application(
            filename,
            Jac.get_program(),
            project_root,
            [svc.entry_path(project_root) for svc in services],
            not no_client and not faux and (served is None or served.kind == "web-app"),
            dev
        );
        console.print("Initializing application...", style="bold");
        import from jaclang.runtime.prepared { initialize_application }
        mod = initialize_application(prepared, cfg, served).__name__;
        if Jac.get_program().errors_had {
            for error in Jac.get_program().errors_had {
                console.error(error.pretty_print());
            }
            mach.close();
            return 1;
        }
    } except Exception as e {
        if Jac.get_program().errors_had {
            for error in Jac.get_program().errors_had {
                console.error(error.pretty_print());
            }
        } else {
            import from jaclang.runtime.traceback_render { dump_traceback }
            console.error(f"Error loading {filename}: {e}");
            console.error(dump_traceback(e));
        }
        mach.close();
        return 1;
    }

    try {
        mach.mem.unit_exit();
    } except Exception {}

    port_pinned = port > 0;
    port = port if port_pinned else 8000;
    if dev and not no_client {
        vite_port = port;
        actual_api_port = api_port if api_port > 0 else port + 1;
        api_port_pinned = api_port > 0;
    } else {
        actual_api_port = port;
        vite_port = 0;
        api_port_pinned = port_pinned;
    }

    import from jaclang.server.settings { ServeConfigError, ServeSettings }
    overrides: dict[str, any] = {
        'port': actual_api_port,
        'strict_port': api_port_pinned,
        'dev': dev,
        'no_client': no_client
    };
    if host {
        overrides['host'] = host;
    }
    if workers {
        overrides['workers'] = workers;
    }
    try {
        settings = ServeSettings.load(base, overrides);
    } except ServeConfigError as e {
        console.error(f"cannot start the server:\n{e}");
        mach.close();
        return 1;
    }
    ServerClass = Jac.get_api_server_class();
    server = ServerClass(module_name=mod, base_path=base, settings=settings);
    if prepared.client_compiler is not None or (dev and not no_client) {
        server.introspector._bundle_builder = Jac.get_client_bundle_builder();
    }
    if prepared.client_compiler is not None {
        server.introspector._bundle_builder._compiler = prepared.client_compiler;
    }
    if faux {
        try {
            server.print_endpoint_docs();
        } except Exception as e {
            import from jaclang.runtime.traceback_render { dump_traceback }
            console.error(f"Error generating endpoint documentation: {e}");
            console.error(dump_traceback(e));
            mach.close();
            return 1;
        }
        mach.close();
        return 0;
    }

    hot_reloader = None;

    vite_holder: list[any] = [];
    if dev {
        if not _ensure_watchdog_installed() {
            mach.close();
            return 1;
        }
        try {
            import from jaclang.server.hmr { HotReloader }
            import from jaclang.server.watcher { JacFileWatcher }

            watcher = JacFileWatcher(watch_paths=[base]);
            client_compiler = None;
            if not no_client {
                try {
                    client_compiler = server.introspector._bundle_builder._get_compiler();
                } except Exception as e {
                    console.warning(
                        f"Client compiler unavailable, HMR uses legacy mode: {e}"
                    );
                }
            }
            hot_reloader = HotReloader(
                base_path=base,
                module_name=mod,
                entry_path=os.path.realpath(filename),
                watcher=watcher,
                client_compiler=client_compiler
            );
            hot_reloader.start();

            if server?.enable_hmr {
                server.enable_hmr(hot_reloader);
            }
        } except ImportError as e {
            console.error(f"Error: Could not initialize HMR: {e}");
            console.error(
                "\nMake sure 'watchdog' is installed by running: jac install --dev"
            );
            mach.close();
            return 1;
        } except Exception as e {
            console.warning(f"HMR initialization failed: {e}");
        }
    }

    def _announce_ready(actual_port: int) {
        primary_port = actual_port;
        if dev and not no_client {
            free_vite_port = _find_free_port(
                vite_port, skip_port=actual_port, strict=port_pinned
            );
            declared_paths: list[str] = [];
            claimed_paths: list[str] = [];
            try {
                import from jaclang.client.vite_bundler { DEV_PROXY_PREFIXES }
                declared_paths = server.introspector.declared_api_paths();
                claimed_paths = server.introspector.client_claimed_paths(
                    DEV_PROXY_PREFIXES
                );
            } except Exception as e {
                console.warning(f"Could not read declared API paths: {e}");
            }
            (started_vite, bound_port) = _start_vite_dev_server(
                base, free_vite_port, actual_port, declared_paths, claimed_paths
            );
            if started_vite {
                vite_holder.append(started_vite);
            }
            primary_port = bound_port;
        }
        _print_startup_message(
            dev=dev,
            no_client=no_client,
            primary_port=primary_port,
            api_port=actual_port,
            base_path=base
        );
    }
    try {
        return int(
            server.start(dev=dev, no_client=no_client, on_ready=_announce_ready)
        );
    } except ServeConfigError as e {
        console.error(str(e));
        if hot_reloader is not None {
            hot_reloader.stop();
        }
        mach.close();
        return 1;
    } except KeyboardInterrupt {
        console.print('\nShutting down');
        return 0;
    } except Exception as e {
        import from jaclang.runtime.traceback_render { dump_traceback }
        import from jaclang.server.net { PortInUseError }
        if isinstance(e, PortInUseError) {
            raise;
        }
        console.error(f"Server error: {e}");
        console.error(dump_traceback(e));
        return 1;
    } finally {
        try {
            if hot_reloader is not None {
                hot_reloader.stop();
            }
        } finally {
            import subprocess;
            for started_vite in vite_holder {
                started_vite.terminate();
                try {
                    started_vite.`wait(timeout=5);
                } except subprocess.TimeoutExpired {
                    started_vite.kill();
                    started_vite.`wait();
                }
            }
            mach.close();
        }
    }
}

def _watchdog_importable -> bool {
    import importlib;
    try {
        importlib.invalidate_caches();
        import watchdog;
        return True;
    } except ImportError {
        return False;
    }
}

def _ensure_watchdog_installed -> bool {
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv { add_venv_to_path }
    import from jaclang.project.providers { InstallContext, get_python_provider }

    if _watchdog_importable() {
        return True;
    }

    config = get_config();
    if config is None {
        console.error("\n  Error: --dev requires 'watchdog' package.\n");
        console.error("  Install it with: pip install watchdog\n");
        return False;
    }

    console.print(
        "\n  Installing watchdog (required for --dev mode)...\n", style="info"
    );
    python = get_python_provider();
    if python.install_specs(config, ["watchdog>=3.0.0"], InstallContext()) {
        add_venv_to_path(config);
        if _watchdog_importable() {
            console.success("watchdog installed");
            return True;
        }
        console.error(
            "\n  Error: watchdog was installed in the project venv but cannot be imported.\n"
        );
        console.error(
            "  Run 'jac install --dev' using a Jac install that matches the project venv Python version.\n"
        );
        return False;
    }
    console.error("\n  Error: Failed to install watchdog\n");
    return False;
}

def _get_network_ips -> list[str] {
    import socket;
    ips: list[str] = [];
    try {
        hostname = socket.gethostname();
        addrs = socket.getaddrinfo(hostname, None);
        for addr in addrs {
            ip = addr[4][0];
            if not isinstance(ip, str) {
                continue;
            }
            if not ip.startswith('127.') and ':' not in ip {
                if ip not in ips {
                    ips.append(ip);
                }
            }
        }
    } except Exception {}
    return ips;
}

def _count_jac_files(directory: str) -> int {
    import from pathlib { Path }
    try {
        path = Path(directory);
        return len(list(path.rglob('*.jac')));
    } except Exception {
        return 0;
    }
}

def _print_startup_message(
    dev: bool, no_client: bool, primary_port: int, api_port: int, base_path: str = '.'
) {
    import from importlib.metadata { version as pkg_version }

    try {
        version = pkg_version('jaclang');
        console.print(f"\n  jac dev server v{version}\n", style="bold cyan");
    } except Exception {
        console.print(f"\n  jac dev server\n", style="bold cyan");
    }

    urls = [];
    urls.append(("Local", f"http://localhost:{primary_port}/"));

    network_ips = _get_network_ips();
    for ip in network_ips {
        urls.append(("Network", f"http://{ip}:{primary_port}/"));
    }

    console.print_urls(urls);

    console.print();

    if dev and not no_client {
        console.print("  Server ready", style="bold green");
        console.print();
        console.print("  Mode: Development (with HMR)", style="muted");
        console.print(f"    App:  http://localhost:{primary_port}/", style="muted");
        console.print(f"    API:  http://localhost:{api_port}/", style="muted");
        console.print();

        file_count = _count_jac_files(base_path);
        if file_count > 0 {
            console.print_watching("**/*.jac", file_count);
        } else {
            console.print("  Watching for changes", style="info");
        }
    } elif dev and no_client {
        console.print("  Server ready (API only)", style="bold green");
        console.print();
        file_count = _count_jac_files(base_path);
        if file_count > 0 {
            console.print_watching("**/*.jac", file_count);
        } else {
            console.print("  Watching for changes", style="info");
        }
    } elif no_client {
        console.print("  Server ready (no client)", style="bold green");
    } else {
        console.print("  Server ready", style="bold green");
    }

    console.print();
}

def _find_free_port(start: int, skip_port: int = 0, strict: bool = False) -> int {
    import from jaclang.server.net { find_available_port }
    try {
        return find_available_port(
            start, max_retries=50, skip_port=skip_port, strict=strict
        );
    } except OSError as e {
        if strict {
            raise;
        }
        console.warning(f"[Vite] {e}; falling back.");
        return start if start != skip_port else start + 50;
    }
}

def _start_vite_dev_server(
    base_path: str,
    vite_port: int,
    api_port: int,
    api_paths: (list[str] | None) = None,
    client_paths: (list[str] | None) = None
) -> any {
    import from pathlib { Path }

    try {
        import from jaclang.client.vite_bundler { ViteBundler }

        project_dir = Path(base_path);
        bundler = ViteBundler(project_dir);

        client_dir = bundler._get_client_dir();
        entry_file = client_dir / 'build' / 'main.js';

        bundler.create_vite_config(
            entry_file,
            is_dev=True,
            api_port=api_port,
            api_paths=api_paths,
            client_paths=client_paths
        );

        if not (client_dir / 'configs' / 'package.json').exists() {
            bundler.create_package_json();
        }

        try {
            import from jaclang.server.hmr { HotReloader }
            reloader = BuildMonitor.active;
            if reloader is not None {
                reloader.attach_client_bundler(bundler);
            }
        } except Exception as e {
            console.warning(f"Client error events will not reach the terminal: {e}");
        }

        process = bundler.start_dev_server(vite_port, suppress_initial_output=True);
        return (process, bundler.dev_server_port or vite_port);
    } except ImportError as e {
        console.warning(f"client bundler unavailable, skipping Vite dev server: {e}");
        return (None, vite_port);
    } except Exception as e {
        console.warning(f"Could not start Vite dev server: {e}");
        return (None, vite_port);
    }
}
