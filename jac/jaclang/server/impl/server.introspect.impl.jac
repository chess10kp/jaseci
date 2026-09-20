import inspect;
import os;
import from inspect { iscoroutine }
import from typing { get_type_hints }
import from jaclang.runtime.object_interop { fields as record_fields, is_record }
import from jaclang.client.artifact { ClientBundleError, MissingBunError }


impl ModuleIntrospector.postinit -> None {
    import threading;
    self._bundle_lock = threading.Lock();
}

impl ModuleIntrospector.load(force_reload: bool = False) -> None {
    import sys;
    loaded = Jac.loaded_modules.get(self.module_name);
    if (loaded is not None and self.module_file) {
        mod_file = loaded?.__file__;
        if not (
            mod_file
            and os.path.exists(mod_file)
            and os.path.realpath(mod_file) == os.path.realpath(self.module_file)
        ) {
            Jac.loaded_modules.pop(self.module_name, None);
            sys.modules.pop(self.module_name, None);
        }
    }
    needs_import = force_reload or (self.module_name not in Jac.loaded_modules);
    import_base = os.path.dirname(os.path.abspath(self.module_file))
        if self.module_file
        else self.base_path;
    if (needs_import and import_base) {
        Jac.jac_import(
            target=self.module_name,
            base_path=os.path.abspath(import_base),
            lng='jac',
            reload_module=force_reload
        );
    }
    module = Jac.loaded_modules.get(self.module_name);
    if (not module or ((self._module is module) and not needs_import)) {
        if module is not None and self._module is module {
            self._check_module_freshness();
        }
        return;
    }
    self._module = module;
    self._load_manifest();
    self._extract_access_levels();
    self._functions = self._collect_functions();
    self._walkers = self._collect_walkers();

    self._collect_cross_boundary_endpoints();
    self._invalidate_bundle();
}

impl ModuleIntrospector._load_manifest -> None {
    self._spa_routes_loaded = False;
    self._spa_route_patterns = None;
    if not self._module {
        return;
    }
    import from jaclang.server.sealed_serve { serve_manifest_for }
    path: str = getattr(self._module, '__file__', '');
    manifest = serve_manifest_for(path) if path else None;
    if manifest is None {
        raise RuntimeError(
            f"No prepared serving metadata for '{path}'. "
                + "Prepare the application before initializing its server."
        );
    }
    self._client_manifest = dict(manifest.get('client', {}) or {});
    self._client_manifest['endpoint_effects'] = manifest.get('endpoint_effects', {});
}

impl ModuleIntrospector._extract_access_levels -> None {
    import from jaclang.server.sealed_serve { serve_manifest_for }
    path: str = getattr(self._module, '__file__', '') if self._module else '';
    manifest = serve_manifest_for(path) if path else None;
    if manifest is None {
        raise RuntimeError(f"No prepared access metadata for '{path}'.");
    }
    self._function_access = dict(manifest.get('func_access', {}) or {});
    self._walker_access = dict(manifest.get('walker_access', {}) or {});
}


impl ModuleIntrospector._register_prepared_bindings(
    sm: dict[str, any], img_root: str
) -> None {
    import from jaclang.runtime.constructs { WalkerArchetype }

    def resolve_prepared(src_path: str, name: str) -> any {
        for loaded in list(Jac.loaded_modules.values()) {
            f = loaded?.__file__;
            if f and os.path.abspath(f) == os.path.abspath(src_path) {
                sym = getattr(loaded, name, None);
                if sym is not None {
                    return sym;
                }
            }
        }
        import from jaclang.runtime.prepared { load_prepared_module }
        module = load_prepared_module(src_path);
        return getattr(module, name);
    }

    for b in sm.get('cross_bindings', []) or [] {
        name = b.get('name');
        rel = b.get('src');
        if not name or not rel {
            continue;
        }
        auth = bool(b.get('auth', True));
        src_path = os.path.join(img_root, rel);
        import from jaclang.runtime.prepared { application_for, source_for_origin }
        application = application_for(self._module.__file__, self._module.__name__)
            if self._module is not None
            else None;
        if application is not None {
            src_path = source_for_origin(application, rel);
        }
        if name in self._walkers or name in self._functions {
            continue;
        }
        try {
            target = resolve_prepared(src_path, name);
        } except Exception {
            logger.exception('Could not load endpoint %s from %s', name, src_path);
            continue;
        }
        if b.get('kind') == 'walker' {
            if isinstance(target, type) and issubclass(target, WalkerArchetype) {
                self._walkers[name] = target;
                self._walker_access[name] = auth;
            }
        } elif callable(target) {
            self._functions[name] = target;
            self._function_access[name] = auth;
        }
    }
}

impl ModuleIntrospector._collect_cross_boundary_endpoints -> None {
    if not (self.discover_endpoints and self._module) {
        return;
    }
    import from jaclang.server.sealed_serve { serve_manifest_for, sealed_root_for }
    path: str = getattr(self._module, '__file__', '');
    manifest = serve_manifest_for(path) if path else None;
    if manifest is None {
        raise RuntimeError(f"No prepared boundary metadata for '{path}'.");
    }
    self._register_prepared_bindings(
        manifest, manifest.get('root') or sealed_root_for(path) or ""
    );
}


impl ModuleIntrospector._collect_functions -> dict[str, Callable[(..., any)]] {
    if not self._module {
        return {};
    }
    functions: dict[(str, Callable[(..., any)])] = {};
    export_names = set(self._client_manifest.get('exports', []));
    for (name, `obj) in inspect.getmembers(self._module) {
        if (inspect.isfunction(`obj) and not name.startswith('_')) {
            if getattr(`obj, '__module__', '').startswith('jaclang.') {
                continue;
            }
            functions[name] = `obj;
            if (name in export_names) {
                self._client_functions[name] = `obj;
            }
        }
    }
    for name in export_names {
        if ((name not in self._client_functions) and hasattr(self._module, name)) {
            attr = getattr(self._module, name);
            if callable(attr) {
                self._client_functions[name] = attr;
            }
        }
    }
    return functions;
}

impl ModuleIntrospector._collect_walkers -> dict[str, type[WalkerArchetype]] {
    import from jaclang.runtime.constructs { WalkerArchetype }
    if not self._module {
        return {};
    }
    walkers: dict[(str, type[WalkerArchetype])] = {};
    for (name, `obj) in inspect.getmembers(self._module) {
        if (
            isinstance(`obj, type)
            and issubclass(`obj, WalkerArchetype)
            and (`obj is not WalkerArchetype)
        ) {
            walkers[name] = `obj;
        }
    }
    return walkers;
}

impl ModuleIntrospector._check_module_freshness -> None {
    import from jaclang.runtime.runtime { JacRuntime as Jac }
    if not self._module {
        return;
    }

    current_module = Jac.loaded_modules.get(self.module_name);
    if (current_module is not None and current_module is not self._module) {
        self._module = current_module;
        self._load_manifest();
        self._extract_access_levels();
        self._functions = self._collect_functions();
        self._walkers = self._collect_walkers();
        self._collect_cross_boundary_endpoints();
        self._invalidate_bundle();
        return;
    }

    needs_refresh = False;
    for (name, cached_cls) in self._walkers.items() {
        current_cls = getattr(self._module, name, None);
        if current_cls is not cached_cls {
            needs_refresh = True;
            break;
        }
    }
    if not needs_refresh {
        _fresh_walkers = self._collect_walkers();
        if set(_fresh_walkers.keys()) != set(self._walkers.keys()) {
            needs_refresh = True;
        }
    }
    if needs_refresh {
        self._load_manifest();
        self._extract_access_levels();
        self._functions = self._collect_functions();
        self._walkers = self._collect_walkers();
        self._collect_cross_boundary_endpoints();
        self._invalidate_bundle();
    }
}

impl ModuleIntrospector.get_functions -> dict[str, Callable[(..., any)]] {
    if not self._functions {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return {
        k: v
        for (k, v) in self._functions.items()
        if not getattr(v, 'schedule_spec', '')
    };
}

impl ModuleIntrospector.get_walkers -> dict[str, type[WalkerArchetype]] {
    if not self._walkers {
        self.load();
    } else {
        self._check_module_freshness();
    }
    return {
        k: v
        for (k, v) in self._walkers.items()
        if not v?.schedule_spec
    };
}

impl ModuleIntrospector.get_client_functions -> dict[str, Callable[(..., any)]] {
    if not self._client_functions {
        self.load();
    }
    return dict(self._client_functions);
}

impl ModuleIntrospector.resolve_root_app(configured: str = "") -> str {
    if configured {
        return configured;
    }

    self.load();
    names = list(self._client_manifest.get('exports', []));
    if not names {
        return "";
    }
    by_lower: dict[(str, str)] = {};
    for n in names {
        by_lower.setdefault(n.lower(), n);
    }
    for candidate in ["app", "index", "main", "home", "root"] {
        if candidate in by_lower {
            return by_lower[candidate];
        }
    }
    return "";
}

impl ModuleIntrospector.introspect_callable(
    func: Callable[(..., any)]
) -> dict[str, any] {
    try {
        sig = inspect.signature(func);
        type_hints = get_type_hints(func);
    } except Exception {
        return {'parameters': {}, 'return_type': 'Any'};
    }
    params = {
        name: {
            'type': getattr(
                type_hints.get(name, any), '__name__', str(type_hints.get(name, any))
            ),
            'required': (param.`default == inspect.Parameter.empty),
            'default': None
                if (param.`default == inspect.Parameter.empty)
                else str(param.`default)
        } for (name, param) in sig.parameters.items()
    };
    return_type = type_hints.get('return', any);
    return {
        'parameters': params,
        'return_type': getattr(return_type, '__name__', str(return_type))
    };
}

impl ModuleIntrospector.introspect_walker(
    walker_cls: type[WalkerArchetype]
) -> dict[str, any] {
    try {
        sig = inspect.signature(walker_cls);
        try {
            type_hints = get_type_hints(walker_cls.init);
        } except Exception {
            type_hints = {};
        }
    } except Exception {
        return {'fields': {}};
    }

    factory_defaults: dict[str, any] = {};
    if is_record(walker_cls) {
        for dc_field in record_fields(walker_cls) {
            if dc_field.default_factory is None {
                continue;
            }
            try {
                factory_defaults[dc_field.name] = dc_field.default_factory();
            } except Exception {
                factory_defaults[dc_field.name] = None;
            }
        }
    }
    fields: dict[str, dict[str, any]] = {};
    for (name, param) in sig.parameters.items() {
        if param.kind
            in (inspect.Parameter.VAR_POSITIONAL, inspect.Parameter.VAR_KEYWORD) {
            continue;
        }

        type_obj = type_hints.get(name, None);
        if type_obj is not None {
            type_name = getattr(type_obj, '__name__', str(type_obj));
        } else {
            annotation = param.annotation;
            if (annotation != inspect.Parameter.empty) {
                type_name = getattr(annotation, '__name__', str(annotation));
            } else {
                type_name = 'Any';
            }
        }
        is_required = param.`default == inspect.Parameter.empty;
        if is_required {
            default_val = None;
        } elif name in factory_defaults {
            default_val = factory_defaults[name];
        } else {
            default_val = param.`default;
        }
        fields[name] = {
            'type': type_name,
            'required': is_required,
            'default': default_val
        };
    }
    fields['_jac_spawn_node'] = {
        'type': 'str (node ID, optional)',
        'required': False,
        'default': 'root'
    };
    return {'fields': fields};
}

impl ModuleIntrospector._invalidate_bundle -> None {
    with self._bundle_lock {
        self._bundle = None;
        self._bundle_error = None;
    }
}

impl ModuleIntrospector.ensure_bundle -> str {
    if not self._module {
        raise RuntimeError('Module not loaded');
    }
    if self._bundle {
        return self._bundle.hash;
    }
    if self.dev_mode {
        raise ClientBundleError(
            'the dev server owns the client in dev mode; the API port does not '
            'build a production bundle'
        );
    }

    entry_epoch = self._bundle_epoch;
    with self._bundle_lock {
        if self._bundle {
            return self._bundle.hash;
        }
        if self._bundle_error is not None and self._bundle_epoch != entry_epoch {
            raise ClientBundleError(self._bundle_error);
        }
        try {
            import from jaclang.client.artifact { prebuilt_bundle }
            import from pathlib { Path }
            self._bundle = prebuilt_bundle(self._module, Path(self._module.__file__));
            if self._bundle is None {
                if self._bundle_builder is None {
                    self._bundle_builder = Jac.get_client_bundle_builder();
                }
                self._bundle = self._bundle_builder.build(self._module);
            }
            self._bundle_error = None;
            self._bundle_epoch += 1;
            return self._bundle.hash;
        } except MissingBunError {
            self._bundle_epoch += 1;
            raise;
        } except Exception as exc {
            self._bundle_error = str(exc)
                or f"{type(exc).__name__} raised with no message";
            self._bundle_epoch += 1;
            raise ClientBundleError(self._bundle_error);
        }
    }
}

impl ModuleIntrospector.render_page(
    function_name: str, args: dict[(str, any)], username: str
) -> dict[str, any] {
    return Jac.render_page(self, function_name, args, username);
}

impl ModuleIntrospector.has_client_route(url_path: str) -> bool {
    if not self._spa_routes_loaded {
        self._spa_route_patterns = self._load_spa_routes();
        self._spa_routes_loaded = True;
    }
    patterns = self._spa_route_patterns;
    if patterns is None {
        return False;
    }
    segments = [
        seg
        for seg in url_path.split('/')
        if seg
    ];
    for pattern in patterns {
        if self._spa_route_matches(pattern, segments) {
            return True;
        }
    }
    return False;
}


impl ModuleIntrospector.spa_fallback_status(url_path: str) -> int {
    if not self._spa_routes_loaded {
        self._spa_route_patterns = self._load_spa_routes();
        self._spa_routes_loaded = True;
    }
    patterns = self._spa_route_patterns;
    if patterns is None {
        return 200;
    }
    segments = [
        seg
        for seg in url_path.split('/')
        if seg
    ];
    for pattern in patterns {
        if self._spa_route_matches(pattern, segments) {
            return 200;
        }
    }
    return 404;
}

impl ModuleIntrospector._load_spa_routes -> (list[str] | None) {
    import from jaclang.server.sealed_serve { serve_manifest_for }
    path: str = getattr(self._module, '__file__', '')
        if self._module
        else str(Path(self.base_path or '.') / (self.module_name + '.jac'));
    manifest = serve_manifest_for(path) if path else None;
    return manifest.get('spa_routes') if manifest is not None else None;
}

impl ModuleIntrospector._spa_route_matches(pattern: str, segments: list[str]) -> bool {
    psegs = [
        seg
        for seg in pattern.split('/')
        if seg
    ];
    for (i, pseg) in enumerate(psegs) {
        if pseg == '*' {
            return True;
        }
        if i >= len(segments) {
            return False;
        }
        if pseg.startswith(':') {
            continue;
        }
        if pseg != segments[i] {
            return False;
        }
    }
    return len(segments) == len(psegs);
}

impl ModuleIntrospector.is_auth_required_for_function(func_name: str) -> bool {
    return self._function_access.get(func_name, True);
}

impl ModuleIntrospector.is_auth_required_for_walker(walker_name: str) -> bool {
    return self._walker_access.get(walker_name, True);
}


impl ModuleIntrospector.restspec_routes -> list[tuple[str, str, any]] {
    routes: list[tuple[str, str, any]] = [];
    try {
        for (name, target) in sorted(self.get_walkers().items()) {
            spec = target?.restspec;
            if spec is not None {
                routes.append((name, 'walker', spec));
            }
        }
        for (name, target) in sorted(self.get_functions().items()) {
            fn_target: any = target;
            fn_spec = fn_target?.restspec;
            if fn_spec is not None {
                routes.append((name, 'function', fn_spec));
            }
        }
    } except Exception {
        return routes;
    }
    return routes;
}


impl ModuleIntrospector.declared_api_paths -> list[str] {
    paths: list[str] = [];
    for (_name, _kind, spec) in self.restspec_routes() {
        path = str(spec.path or '');
        if not path.startswith('/') or path == '/' {
            continue;
        }
        if path not in paths {
            paths.append(path);
        }
    }
    return sorted(paths);
}


impl ModuleIntrospector.client_claimed_paths(candidates: list[str]) -> list[str] {
    claimed: list[str] = [];
    for candidate in candidates {
        try {
            if self.has_client_route(candidate) {
                claimed.append(candidate);
            }
        } except Exception {
            continue;
        }
    }
    return claimed;
}


impl ModuleIntrospector.walker_protocol(walker_name: str) -> APIProtocol {
    walkers = self.get_walkers();
    if walker_name not in walkers {
        return APIProtocol.HTTP;
    }
    restspec: any = target_restspec(walkers[walker_name]);
    if restspec?.protocol {
        return APIProtocol(restspec.protocol);
    }
    return APIProtocol.HTTP;
}

impl ModuleIntrospector.function_protocol(func_name: str) -> APIProtocol {
    functions = self.get_functions();
    if func_name not in functions {
        return APIProtocol.HTTP;
    }
    restspec: any = target_restspec(functions[func_name]);
    if restspec?.protocol {
        return APIProtocol(restspec.protocol);
    }
    return APIProtocol.HTTP;
}


def _warm_persistence {
    try {
        ctx = Jac.get_context();
        anchor = ctx.system_root;
        ctx.mem.commit();
        logger.debug(f"persistent store ready (system root {anchor.id})");
    } except Exception as e {
        logger.warning(
            f"persistent store not reachable while starting up "
            f"({type(e).__name__}: {e}); requests that touch graph state will "
            "provision it on demand"
        );
    }
}
