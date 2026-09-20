import asyncio;
import json;
import os;
import from jaclang.runtime.constants { Constants as Con }
import from jaclang.server.net { PORT_RETRY_LIMIT }
import from jaclang.server.serving.server { ServingServer }


impl JacAPIServer.postinit -> None {
    import from jaclang.server.identity.config { configure_identity, signing_secret }
    import from jaclang.server.task_scheduler { Scheduler }
    if self.settings is None {
        overrides: dict[str, any] = {};
        if self.port > 0 {
            overrides['port'] = self.port;
        }
        overrides['strict_port'] = self.strict_port;
        self.settings = ServeSettings.load(self.base_path, overrides);
    }
    self.port = self.settings.port;
    configure_identity(self.settings.auth, self.base_path);
    signing_secret();
    _warm_persistence();
    self.user_manager = UserManager(
        base_path=self.base_path, provision_unknown_users=self.is_sv_sibling
    );
    _um = self.user_manager;
    def _shared_root_id -> (str | None) {
        found = _um.get_root_id(Con.GUEST.value);
        if found is None {
            _um.ensure_internal_user(Con.GUEST.value, '__no_password__');
            found = _um.get_root_id(Con.GUEST.value);
        }
        return found;
    }
    Jac.set_shared_root_resolver(_shared_root_id);
    self.introspector = ModuleIntrospector(
        self.module_name,
        self.base_path,
        module_file=self.module_file,
        discover_endpoints=not self.settings.static_only
    );
    self.execution_manager = ExecutionManager(
        base_path=self.base_path, user_manager=self.user_manager
    );
    self.scheduler = Scheduler.instance();
    self.drain = DrainState(timeout=self.settings.timeouts.drain);
    if self.extensions is None {
        self.extensions = list(Jac.get_server_extensions());
    }
}

impl JacAPIServer.resolved_settings -> ServeSettings {
    if self.settings is None {
        self.settings = ServeSettings.load(self.base_path);
    }
    return self.settings;
}

impl JacAPIServer.identity -> UserManager {
    return self.user_manager;
}

impl JacAPIServer.require_app -> ServingApp {
    if self.app is None {
        raise RuntimeError('build_app() has not run');
    }
    return self.app;
}

impl JacAPIServer.add_endpoint(ep: JEndPoint) -> None {
    self._endpoints.append(ep);
    self.require_app().add_endpoint(ep);
}

impl JacAPIServer.add_ws_endpoint(path: str, handler: Callable[..., any]) -> None {
    self.require_app().add_ws_endpoint(WSEndPoint(path=path, handler=handler));
}

impl JacAPIServer.add_middleware(fn: Callable[..., any]) -> None {
    self.require_app().add_middleware(fn);
}

impl JacAPIServer.add_shutdown_hook(fn: Callable[..., any]) -> None {
    self.require_app().add_shutdown_hook(fn);
}

impl JacAPIServer._install_middleware -> None {
    import from jaclang.server.middleware { jwt_middleware, request_context_middleware }
    self.add_middleware(request_context_middleware());
    self.add_middleware(jwt_middleware(self.user_manager));
}

impl JacAPIServer.build_app -> ServingApp {
    import from jaclang.server.middleware { metrics_middleware }
    import from jaclang.server.serving.drain { drain_middleware }
    import from jaclang.server.serving.middleware {
        cors_middleware,
        custom_headers_middleware
    }
    import from jaclang.server.serving.openapi { register_docs_endpoints }
    import from jaclang.project.config { JacConfig }
    settings = self.resolved_settings();
    self.introspector.load();
    self.introspector.dev_mode = settings.dev;
    app = ServingApp(
        title=f"{self.module_name} API",
        version='1.0.0',
        multipart_spool_bytes=settings.limits.multipart_spool_bytes
    );
    if not settings.docs_enabled or self.introspector.has_client_route('/docs') {
        app.docs_url = None;
    }
    if not settings.docs_enabled {
        app.openapi_url = None;
    }
    self.app = app;
    self._endpoints = [];
    self._install_middleware();
    self.register_endpoints();
    for ext in (self.extensions or []) {
        ext.register(self);
    }
    self.add_middleware(drain_middleware(self.drain, self.module_name));
    self.add_middleware(
        cors_middleware(
            allow_origins=list(settings.cors_origins),
            allow_credentials=True,
            allow_methods=['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
            allow_headers=['Content-Type', 'Authorization', 'X-Request-Id']
        )
    );
    config = JacConfig.discover(Path(self.base_path) if self.base_path else None);
    if config
        and config.environments
        and 'response' in config.environments
        and 'headers' in config.environments['response'] {
        pairs = [
            (str(hn), str(hv))
            for (hn, hv) in config.environments['response']['headers'].items()
        ];
        if pairs {
            self.add_middleware(custom_headers_middleware(pairs));
        }
    }
    if self.metrics is not None {
        self.add_middleware(metrics_middleware(self.metrics, self.metrics_path));
    }
    if settings.dev {
        _self = self;
        async def hmr_refresh_middleware(request: any, call_next: any) -> any {
            if _self._hmr_pending {
                _self._refresh_dev_endpoints();
            }
            next_fn: any = call_next;
            return await next_fn(request);
        }
        self.add_middleware(hmr_refresh_middleware);
    }
    self._configure_openapi_security();
    register_docs_endpoints(app);
    return app;
}

impl JacAPIServer.register_endpoints -> None {
    import from jaclang.server.endpoints.auth { register_auth_endpoints }
    import from jaclang.server.endpoints.colocated { register_colocated_endpoints }
    import from jaclang.server.endpoints.introspection {
        register_introspection_endpoints
    }
    import from jaclang.server.endpoints.pages {
        register_diagnostics_endpoints,
        register_graph_endpoints,
        register_page_endpoints
    }
    import from jaclang.server.endpoints.walkers {
        register_function_endpoints,
        register_walker_endpoints
    }
    import from jaclang.server.serving.health { register_health_endpoints }
    settings = self.resolved_settings();
    register_health_endpoints(self.require_app(), self.drain);
    if settings.static_only {
        register_page_endpoints(self);
        return;
    }
    register_diagnostics_endpoints(self);
    register_auth_endpoints(self);
    register_introspection_endpoints(self);
    register_walker_endpoints(self);
    register_function_endpoints(self);
    register_colocated_endpoints(self);
    if settings.graph_enabled {
        register_graph_endpoints(self);
    }
    register_page_endpoints(self);
}

impl JacAPIServer._configure_openapi_security -> None {
    app = self.require_app();
    app.openapi_security = {
        'BearerAuth': {
            'type': 'http',
            'scheme': 'bearer',
            'bearerFormat': 'JWT',
            'description': "Enter your JWT token (without 'Bearer ' prefix)"
        }
    };
    app.openapi_cache = None;
}

impl JacAPIServer.enable_hmr(hot_reloader: any) -> None {
    self._hot_reloader = hot_reloader;
    def on_change(event: any) {
        self._hmr_pending = True;
        logger.debug(f"Change detected: {event.path}");
    }
    hot_reloader.watcher.add_callback(on_change);
}

impl JacAPIServer._refresh_dev_endpoints -> None {
    self._hmr_pending = False;
    self.introspector.load(force_reload=True);
    if self.app is None {
        return;
    }
    app = self.require_app();
    app.clear_routes();
    self._endpoints = [];
    import from jaclang.server.serving.openapi { register_docs_endpoints }
    self.register_endpoints();
    for ext in (self.extensions or []) {
        ext.register(self);
    }
    self._configure_openapi_security();
    register_docs_endpoints(app);
}

impl JacAPIServer.load_module(force_reload: bool = False) -> None {
    self.introspector.load(force_reload);
}

impl JacAPIServer.module.getter -> object {
    return self.introspector._module;
}

impl JacAPIServer.get_functions -> dict[str, Callable[(..., any)]] {
    return self.introspector.get_functions();
}

impl JacAPIServer.get_walkers -> dict[str, type[WalkerArchetype]] {
    return self.introspector.get_walkers();
}

impl JacAPIServer.print_endpoint_docs -> None {
    print_endpoint_docs(self);
}

impl JacAPIServer._ensure_sv_siblings -> None {
    if self.is_sv_sibling {
        return;
    }
    import from jaclang.server { sv_client }
    visited: set[str] = set();
    frontier: list[str] = sv_client.get_consumer_providers(self.module_name);
    while frontier {
        wave: list[str] = [
            p
            for p in frontier
            if p not in visited
        ];
        if not wave {
            break;
        }
        for p in wave {
            visited.add(p);
        }
        sv_client.ensure_all(wave);
        next_frontier: list[str] = [];
        for provider in wave {
            for transitive in sv_client.get_consumer_providers(provider) {
                if transitive not in visited {
                    next_frontier.append(transitive);
                }
            }
        }
        frontier = next_frontier;
    }
}

impl JacAPIServer._ensure_client_bundle -> None {
    import from jaclang.runtime.prepared { application_for }
    module_path: str = getattr(self.introspector._module, '__file__', '');
    if module_path and application_for(module_path) is not None {
        return;
    }

    import sys;
    import time;
    import from jaclang.cli.banners { JAC_DISCORD_URL }
    import from jaclang.cli.console { console }
    import from jaclang.client.client_diagnostics { format_build_diagnostics }
    import from jaclang.project.config { get_config }
    settings = self.resolved_settings();
    if settings.dev or settings.no_client or settings.client_dist {
        return;
    }
    client_exports = self.introspector._client_manifest.get('exports', []);
    if not client_exports {
        return;
    }
    import from jaclang.project.client_paths { client_app_dir_for }
    config = get_config();
    dist_dir = client_app_dir_for(config) / 'dist'
        if config
        else Path(self.base_path) / '.jac' / 'client' / 'dist';
    if (dist_dir / 'manifest.json').exists() {
        console.print("  ✔ PWA bundle already built", style="success");
        return;
    }
    started = time.time();
    try {
        with console.status("Building client bundle...", spinner="dots") as _status {
            self.introspector.ensure_bundle();
        }
        console.print(
            f"  ✔ Client bundle ready ({time.time() - started:.1f}s)", style="success"
        );
    } except Exception as e {
        project_dir = config.project_root if config else Path.cwd();
        console.warning("Failed to build client bundle");
        console.print(file=sys.stderr);
        console.print(
            format_build_diagnostics(str(project_dir), str(e), config), file=sys.stderr
        );
        console.warning(
            'Client pages will not be available until this is fixed.', emoji=True
        );
        console.info('Try again after running: jac clean --all', emoji=True);
        console.info(
            f"If it still doesn't work, ask for help at {JAC_DISCORD_URL}", emoji=True
        );
    }
}

impl JacAPIServer._ensure_internal_users -> None {
    import from jaclang.server.identity.user_manager { SYSTEM_USER, UserRole }
    self.user_manager.ensure_internal_user(Con.GUEST.value, '__no_password__');
    self.user_manager.ensure_internal_user(
        SYSTEM_USER, '__no_login__', role=UserRole.SYSTEM.value
    );
}

impl JacAPIServer._register_scheduled_tasks -> None {
    import from jaclang.server.identity.user_manager { SYSTEM_USER }
    import from jaclang.server.task_scheduler { ScheduleSpec }
    _self = self;
    def _make_target(name: str, is_walker: bool) -> Callable[[], None] {
        async def _run -> any {
            intro = _self.introspector;
            registry: dict[str, any] = (
                dict(intro._walkers) if is_walker else dict(intro._functions)
            );
            if name not in registry {
                return {'error': f"'{name}' is no longer registered"};
            }
            ctx = Jac.create_j_context(user_root=None);
            token = Jac.push_request_context(ctx);
            try {
                if is_walker {
                    return await _self.execution_manager.spawn_walker(
                        registry[name], {}, SYSTEM_USER
                    );
                }
                return await _self.execution_manager.execute_function(
                    registry[name], {}, SYSTEM_USER
                );
            } finally {
                try {
                    ctx.close();
                } finally {
                    Jac.reset_request_context(token);
                }
            }
        }
        def target {
            outcome = asyncio.run(_run());
            if (
                isinstance(outcome, dict)
                and 'error' in outcome
                and outcome.get('error_code') != 'execution_error'
            ) {
                logger.error(f"scheduled {name} failed: {outcome.get('error')}");
            }
        }
        return target;
    }
    self.introspector.load();
    registries: list[tuple[dict[str, any], bool]] = [
        (dict(self.introspector._walkers), True),
        (dict(self.introspector._functions), False)
    ];
    for (registry, is_walker) in registries {
        for (name, item) in registry.items() {
            spec = item?.schedule_spec;
            if not isinstance(spec, ScheduleSpec) {
                continue;
            }
            self.scheduler.register(
                name, _make_target(name, is_walker), spec, is_walker
            );
        }
    }
    if self.scheduler.has_pending() {
        logger.info(
            f"static scheduler: {len(self.scheduler._tasks)} task(s) registered"
        );
    }
    import from jaclang.server.identity.identity_storage { PgIdentityStorage }
    storage = self.user_manager._identity_storage;
    store: any = storage.store if isinstance(storage, PgIdentityStorage) else None;
    if store is not None {
        _store: any = store;
        def _lease(key: str, ttl: int) -> bool {
            import os;
            import socket;
            return bool(
                _store.kv_acquire_lease(
                    key, ttl, f"{socket.gethostname()}:{os.getpid()}"
                )
            );
        }
        self.scheduler.lease = _lease;
    }
}

impl JacAPIServer._validate_or_raise -> None {
    import from jaclang.server.settings { ServeConfigError }
    settings = self.resolved_settings();
    problems = settings.validate();
    for ext in (self.extensions or []) {
        problems.extend(ext.validate(self));
    }
    if problems {
        raise ServeConfigError(
            "cannot start the server:\n" + '\n'.join(f"  - {p}" for p in problems)
        );
    }
}

impl JacAPIServer._prepare_to_serve(dev: bool, no_client: bool) -> ServeSettings {
    import from jaclang.server.serving.accesslog { configure_access_logging }
    settings = self.resolved_settings();
    settings.dev = dev;
    settings.no_client = no_client;
    self.introspector.load();
    self._validate_or_raise();
    configure_access_logging(
        enabled=settings.access_log.enabled,
        format=settings.access_log.format,
        suppress_health_checks=settings.access_log.suppress_health_checks
    );
    self._ensure_sv_siblings();
    self._ensure_internal_users();
    self._ensure_client_bundle();
    self.build_app();
    self._register_scheduled_tasks();
    return settings;
}

impl JacAPIServer.serve_background(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[..., None] | None = None,
    port_retries: int = 0
) -> Callable[[], None] {
    import from jaclang.server.outbox { start_worker_if_bridging, stop_worker }
    settings = self._prepare_to_serve(dev, no_client);
    serving = ServingServer(
        app=self.require_app(), settings=settings, drain=self.drain
    );
    self.server = serving;
    self.scheduler.start_if_pending();
    start_worker_if_bridging();
    for ext in (self.extensions or []) {
        ext.on_worker_start(self);
    }
    def _ready(bound_port: int) {
        self.port = bound_port;
        if on_ready is not None {
            on_ready(bound_port);
        }
    }
    stop_transport = serving.serve_background(
        on_ready=_ready, port_retries=port_retries
    );
    def _stop {
        stop_transport();
        self.scheduler.stop();
        stop_worker();
    }
    return _stop;
}

impl JacAPIServer.start(
    dev: bool = False,
    no_client: bool = False,
    on_ready: Callable[..., None] | None = None
) -> int {
    import from jaclang.cli.console { console }
    import from jaclang.server.serving.supervisor { WorkerSupervisor }
    settings = self._prepare_to_serve(dev, no_client);

    def _announce(bound_port: int) {
        self.port = bound_port;
        scheme = settings.scheme();
        shown_host = 'localhost'
            if settings.host in ('0.0.0.0', '::')
            else settings.host;
        console.print(
            f"Jac API Server running on {scheme}://{shown_host}:{bound_port}"
                + (
                    f" ({settings.workers.count} workers, "
                    f"{settings.workers.threads} threads each)"
                        if settings.workers.multi_process()
                        else ''
                )
        );
        if on_ready {
            try {
                on_ready(bound_port);
            } except TypeError {
                on_ready();
            }
        }
    }

    port_retries = 0 if settings.strict_port else PORT_RETRY_LIMIT;
    if settings.workers.multi_process() {
        supervisor = WorkerSupervisor(
            settings=settings, worker_main=self._worker_main, on_ready=_announce
        );
        return supervisor.run(port_retries=port_retries);
    }
    code = self._worker_main(None, on_ready=_announce, port_retries=port_retries);
    console.print('\nShutting down server...');
    return code;
}

impl JacAPIServer._worker_main(
    handle: (WorkerHandle | None),
    on_ready: (Callable[[int], None] | None) = None,
    port_retries: int = 0
) -> int {
    import from jaclang.server.outbox { start_worker_if_bridging, stop_worker }
    settings = self.resolved_settings();
    serving = ServingServer(
        app=self.require_app(),
        settings=settings,
        drain=self.drain,
        sock=handle.listener if handle is not None else None,
        request_budget=handle.request_budget if handle is not None else 0,
        heartbeat=handle.heartbeat if handle is not None else None
    );
    self.server = serving;
    self.scheduler.start_if_pending();
    start_worker_if_bridging();
    for ext in (self.extensions or []) {
        ext.on_worker_start(self);
    }
    def _ready(bound_port: int) {
        self.port = bound_port;
        if on_ready is not None {
            on_ready(bound_port);
        }
        if handle is not None and handle.notify_ready is not None {
            handle.notify_ready();
        }
    }
    try {
        return serving.run(on_ready=_ready, port_retries=port_retries);
    } finally {
        self.scheduler.stop();
        stop_worker();
    }
}

impl JacAPIServer.request_stop -> None {
    if self.server is not None {
        self.server.request_stop();
    }
}


impl print_endpoint_docs(server: JacAPIServer) -> None {
    import from jaclang.cli.console { console }
    server.introspector.load();
    functions = server.introspector.get_functions();
    walkers = server.introspector.get_walkers();
    client_exports = server.introspector._client_manifest.get('exports', []);
    """Print section header.""";
    def section(title: str, auth: str = '') {
        console.print(f"{title}{f' ({auth})' if auth else ''}{('-' * 80)}");
    }
    """Print endpoint with description.""";
    def endpoint(method: str, path: str, desc: str, details: str = '') {
        console.print(f"{method:6} {path}");
        console.print(f"       {desc}");
        if details {
            console.print(f"       {details}");
        }
    }
    """Format parameter info.""";
    def format_param(name: str, info: dict[(str, any)]) -> str {
        req = 'required' if info['required'] else 'optional';
        `default = f", default: {info['default']}" if info.get('default') else '';
        return f"{name}: {info['type']} ({req}{`default})";
    }
    console.print(('\n' + ('=' * 80)));
    console.print(f"JAC API SERVER - {server.module_name}");
    console.print(('=' * 80));
    section('AUTHENTICATION');
    endpoint(
        'POST',
        '/user/register',
        'Create new user account',
        'Body: { "identities": [{ "type": "username", "value": str }], "credential": { "type": "password", "password": str } }'
    );
    endpoint(
        'POST',
        '/user/login',
        'Authenticate and get token',
        'Body: { "identity": { "type": "username", "value": str }, "credential": { "type": "password", "password": str } }'
    );
    endpoint(
        'GET',
        '/user/me',
        'Get authenticated user information',
        'Requires:  Authorization header with Bearer token'
    );
    section('INTROSPECTION', 'Authenticated');
    endpoint('GET', '/functions', 'List all functions → string[]');
    endpoint('GET', '/walkers', 'List all walkers → string[]');
    if functions {
        section('FUNCTIONS', 'Authenticated');
        for (name, func) in functions.items() {
            sig = server.introspector.introspect_callable(func);
            sig_params: dict[str, dict[str, any]] = sig['parameters'];
            params = [format_param(n, i) for (n, i) in sig_params.items()];
            params_str = ', '.join(params) if params else 'none';
            endpoint('GET', f"/function/{name}", 'Get signature');
            endpoint(
                'POST',
                f"/function/{name}",
                f"Call function → {sig['return_type']}",
                f"Args: {{ {params_str} }}" if params else 'No arguments'
            );
        }
    }
    if walkers {
        section('WALKERS', 'Authenticated');
        for (name, walker_cls) in walkers.items() {
            info = server.introspector.introspect_walker(walker_cls);
            info_fields: dict[str, dict[str, any]] = info['fields'];
            fields = [format_param(n, i) for (n, i) in info_fields.items()];
            fields_str = ', '.join(fields[:3]);
            if (len(fields) > 3) {
                fields_str += f", ... (+{(len(fields) - 3)} more)";
            }
            endpoint('GET', f"/walker/{name}", 'Get walker fields');
            endpoint(
                'POST',
                f"/walker/{name}",
                'Spawn walker',
                f"Fields: {{ {fields_str} }}" if fields else 'No fields'
            );
        }
    }
    import from jaclang.project.config { get_config }
    import from jaclang.server.endpoints.colocated {
        colocated_providers,
        provider_route
    }
    import from jaclang.server.static_files { sibling_app_names }
    config = get_config();
    root_app = server.introspector.resolve_root_app();
    section('CLIENT PAGES', 'Public');
    if client_exports {
        funcs_list = ', '.join(sorted(client_exports)[:8]);
        if (len(client_exports) > 8) {
            funcs_list += f" (+{(len(client_exports) - 8)} more)";
        }
        console.print(f"Available ({len(client_exports)}): {funcs_list}");
        endpoint(
            'GET',
            '/cl/<name>',
            'Render HTML for client function',
            'Example: /cl/App?arg1=value1'
        );
    } else {
        console.print(
            "\nNo client functions. Define with 'cl def' for browser-side rendering."
        );
    }
    for sibling in sibling_app_names(config, server.base_path) {
        endpoint('GET', f"/cl/{sibling}/", f"Sibling app bundle: dist/{sibling}");
    }
    for provider_app in colocated_providers() {
        route = provider_route(config, provider_app);
        endpoint('POST', f"{route}/walker/<name>", f"Colocated app {provider_app}");
    }
    section('STATIC');
    if root_app {
        endpoint('GET', '/', f'Serves client app: {root_app}');
    } else {
        endpoint('GET', '/', 'API information and endpoint list');
    }
    endpoint('GET', '/static/client.js', 'Client JavaScript bundle');
    total = 2 + 2 + (len(functions) * 2) + (len(walkers) * 2) + 2;
    console.print(('\n' + ('=' * 80)));
    console.print(
        f"TOTAL: {len(functions)} functions · {len(walkers)} walkers · {len(
            client_exports
        )} client functions · {total} endpoints"
    );
    console.print(('=' * 80));
    console.print('\nAuth: Bearer token (Authorization: Bearer <token>)\n');
}
