impl JacConfig.get_build_dir -> Path {
    import from pathlib { Path }
    base = self.project_root or Path.cwd();
    return base / self.build.dir;
}

impl JacConfig.get_cache_dir -> Path {
    return self.get_build_dir() / self.cache.dir;
}

impl JacConfig.get_venv_dir -> Path {
    return self.get_build_dir() / "venv";
}

impl JacConfig.get_data_dir -> Path {
    return self.get_build_dir() / "data";
}

impl JacConfig.get_client_dir -> Path {
    return self.get_build_dir() / "client";
}

impl JacConfig.is_valid -> bool {
    return self.toml_path is not None and self.toml_path.exists();
}

impl get_config(
    start_path: Path | None = None,
    force_discover: bool = False,
    profile: str | None = None
) -> JacConfig | None {
    if force_discover {
        _config = None;
        _config_explicit = False;
        _config_by_root = {};
    }
    if _config_explicit {
        return _config;
    }
    if _config is None or profile is not None {
        base = start_path or (_config.project_root if _config else None) or Path.cwd();
        _config = get_config_for_path(base, profile=profile);
        if _config is not None and _config.project_root is not None {
            _config.discovered_from_ancestor = (
                _config.project_root.resolve() != base.resolve()
            );
        }
    }
    return _config;
}

impl pin_project_scope(config: JacConfig | None) -> None {
    _config = config;

    _config_explicit = True;

    _config_by_root = {};
}

impl project_scope_is_pinned -> bool {
    return _config_explicit;
}

impl set_config(config: JacConfig | None) -> None {
    _config = config;

    _config_explicit = config is not None;

    _config_by_root = {};
}

impl get_explicit_config -> JacConfig | None {
    return _config if _config_explicit else None;
}

impl get_config_for_dir(start_dir: str) -> JacConfig | None {
    return get_config_for_path(Path(start_dir));
}

impl active_profile_name(config: JacConfig | None) -> str {
    requested = os.environ.get("JAC_PROFILE", "").strip();
    if requested or config is None {
        return requested;
    }
    return config.environment.default_profile or "";
}

impl get_config_for_path(
    start_path: Path, profile: str | None = None, force_discover: bool = False
) -> JacConfig | None {
    explicit = get_explicit_config();
    if explicit is not None {
        project_root = explicit.project_root;
        if project_root is None
            or start_path.resolve().is_relative_to(project_root.resolve()) {
            return explicit;
        }
    }
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, _) = result;
    key = str(project_root);
    cached = _config_by_root.get(key);
    if force_discover
        or key not in _config_by_root
        or (
            profile is not None
            and cached is not None
            and cached.profile_override != profile.strip()
        ) {
        selected = profile
            if profile is not None
            else (cached.profile_override if cached is not None else None);
        _config_by_root[key] = JacConfig.resolve(
            start_path=project_root, profile=selected
        );
        if _config is not None and _config.project_root == project_root {
            _config = _config_by_root[key];
        }
    }
    return _config_by_root[key];
}

impl JacConfig.app(name: str) -> AppConfig | None {
    return self.apps.get(name);
}

impl JacConfig.resolve_app(name: str = "") -> AppConfig {
    names = ", ".join(self.apps.keys());
    if name {
        found = self.apps.get(name);
        if found is None {
            raise ValueError(
                f"Unknown app '{name}'; apps in jac.toml: {names or '(none)'}"
            );
        }
        return found;
    }
    if not self.apps {
        return implicit_app(self);
    }
    if self.default_app and self.default_app in self.apps {
        return self.apps[self.default_app];
    }
    if len(self.apps) == 1 {
        return next(iter(self.apps.values()));
    }
    raise ValueError(
        f"Workspace has {len(self.apps)} apps ({names}); pass an app name or "
        "set [project] default-app"
    );
}

impl JacConfig.resolved_kind(app: AppConfig) -> str {
    if app.kind {
        return app.kind;
    }
    import from jaclang.project.kinds { resolve_app_kind, resolve_entry }
    root_dir = str(self.project_root) if self.project_root else "";
    entry_file = resolve_entry(self, root_dir, app) if root_dir else "";
    return resolve_app_kind(self, app, entry_file);
}

impl JacConfig.effective_for_app(name: str) -> JacConfig {
    import copy;
    app = self.apps.get(name);
    if app is None {
        raise ValueError(
            f"Unknown app '{name}'; apps in jac.toml: "
            f"{', '.join(self.apps.keys()) or '(none)'}"
        );
    }
    data = copy.deepcopy(self._base_data);
    if app.overlays {
        data = _deep_merge(data, copy.deepcopy(app.overlays));
    }
    cfg = _parse_toml_data(data, self.toml_path);
    cfg.discovered_from_ancestor = self.discovered_from_ancestor;
    cfg.profile_override = self.profile_override;
    if self.toml_path is not None {
        cfg.config_files = [self.toml_path];
    }
    for (layer, arg) in list(self._layers) {
        if layer == "profile" {
            cfg.apply_profile(arg);
        } else {
            cfg.apply_profile_overlay(arg or None);
        }
    }
    return cfg;
}

impl JacConfig.app_for_target(entry_path: str = "") -> AppConfig | None {
    if not self.is_workspace or not self.apps {
        return None;
    }
    if not entry_path {
        import from jaclang.runtime.runtime { JacRuntime }
        entry_path = JacRuntime.get_full_target_path() or "";
    }
    if not entry_path {
        return None;
    }
    app = self.app_for_path(os.path.abspath(entry_path));
    return None if app is None or app.implicit else app;
}

impl JacConfig.app_for_path(abs_path: str) -> AppConfig | None {
    import from jaclang.runtime.prepared { origin_for_source }
    abs_path = origin_for_source(abs_path);
    if self.project_root is None {
        return None;
    }
    for app in self.apps.values() {
        if app.contains(str(self.project_root), abs_path) {
            return app;
        }
    }
    return None;
}

impl JacConfig.serving_apps -> list[AppConfig] {
    import from jaclang.project.kinds { kind_spec }
    out: list[AppConfig] = [];
    for app in self.apps.values() {
        spec = kind_spec(self.resolved_kind(app));
        if spec is not None and spec.has_server {
            out.append(app);
        }
    }
    return out;
}

impl JacConfig.default_app.getter -> str {
    return self.project.default_app;
}
