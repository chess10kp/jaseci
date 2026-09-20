impl ManifestBuilder._gateway_cfg -> dict[str, any] {
    if self.gateway_config is not None {
        return normalize_gateway_config(self.gateway_config);
    }
    return get_scale_config().get_gateway_config();
}


impl ManifestBuilder._project_config -> any {
    import os;
    if not self.project_dir or not os.path.isdir(self.project_dir) {
        return None;
    }
    import from jaclang.scale.injector.bundle { _project_config }
    return _project_config(self.project_dir);
}


impl ManifestBuilder._derive_fleet(app_config: AppConfig) -> FleetSpec {
    cfg = self._project_config();
    if cfg is not None and cfg.is_workspace {
        root_dir = str(cfg.project_root) if cfg.project_root else self.project_dir;
        fleet = fleet_from_config(
            cfg,
            app_config.served_app,
            project_root=root_dir,
            relative_to=self.project_dir
        );
    } else {
        name = app_config.app_name or self.k8s_config.app_name;
        if not name {
            raise ValueError(
                "Cannot name the app's pod: no app_name is set. Set "
                "[project].name in jac.toml."
            );
        }
        fleet = solo_fleet(
            name, app_config.file_name, client=self._has_client_source()
        );
    }
    for (app, cfg_over) in self.app_overrides.items() {
        merged = dict(fleet.overrides.get(app, {}));
        merged.update(dict(cfg_over) if isinstance(cfg_over, dict) else {});
        fleet.overrides[app] = merged;
    }
    return fleet;
}


impl ManifestBuilder._fleet(app_config: AppConfig) -> FleetSpec {
    if self.fleet is None {
        self.fleet = self._derive_fleet(app_config);
    }
    return self.fleet;
}


impl ManifestBuilder._injector_object_key -> str {
    return self._bundle_object_key;
}


impl ManifestBuilder._prepare_injector(app_config: AppConfig) -> PvcInjector {
    import from jaclang.scale.injector.binary_injector { select_injector }
    import from jaclang.scale.injector.pvc_injector { PvcInjector }
    proj = self.project_dir or app_config.code_folder;
    self.project_dir = proj;
    fleet = self._fleet(app_config);
    self._build_client_bundle(proj);
    selection = select_injector(
        self.k8s_config.bundle_storage_class,
        k8s_safe_name(self.k8s_config.app_name),
        self.k8s_config.namespace,
        proj,
        dry_run=self.dry_run,
        access_mode=self.k8s_config.bundle_access_mode,
        fleet=fleet
    );
    injector: PvcInjector = selection[0];
    self._toolchain_object_key = str(selection[1]);
    return injector;
}


impl ManifestBuilder._install_app_deps(
    project_dir: str, jac_bin: str, env: (dict[str, str] | None)
) -> str {
    import subprocess;
    import from jaclang.cli.console { console }
    console.print("Installing the app's dependencies on the build host.");
    try {
        result = subprocess.run(
            [jac_bin, "install"],
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=_DEP_INSTALL_TIMEOUT_S,
            env=env
        );
    } except subprocess.TimeoutExpired {
        return f"'jac install' timed out after {_DEP_INSTALL_TIMEOUT_S}s";
    } except OSError as exc {
        return f"'jac install' could not run: {exc}";
    }
    if result.returncode != 0 {
        return f"'jac install' exited {result.returncode}:\n{_output_tail(result)}";
    }
    return "";
}


impl ManifestBuilder._serve_settings -> ServeSettings {
    if self._serve_settings_cache is None {
        project = get_scale_config().get_jac_config();
        self._serve_settings_cache = ServeSettings.load(
            str(project.project_root or self.project_dir or '.'), config=project
        );
    }
    return self._serve_settings_cache;
}


impl ManifestBuilder._drain_timeout -> int {
    return int(self._serve_settings().timeouts.drain);
}


impl ManifestBuilder._signing_secret -> str {
    import secrets;
    configured = str(self.secrets.get("JAC_SERVE_AUTH_SECRET") or "").strip();
    if configured {
        return configured;
    }
    from_project = self._serve_settings().auth.secret.strip();
    if from_project {
        return from_project;
    }
    if not self._minted_secret {
        self._minted_secret = secrets.token_urlsafe(48);
    }
    return self._minted_secret;
}


impl ManifestBuilder._service_config(svc_name: str) -> dict[str, any] {
    merged: dict[str, any] = {};
    if svc_name == GATEWAY_NAME {
        gw = self._gateway_cfg();
        merged.update(
            {
                key: gw[key]
                for key in GATEWAY_POD_KEYS
                if key in gw
            }
        );
    }
    if self.fleet is not None {
        merged.update(self.fleet.app_config(svc_name));
    }
    extra = self.app_overrides.get(svc_name);
    if isinstance(extra, dict) {
        merged.update(extra);
    }
    return merged;
}


impl ManifestBuilder._user_secret_name -> str {
    return f"{self.k8s_config.app_name}-secrets";
}


impl ManifestBuilder._owner_labels -> dict[str, str] {
    return {
        str(k): str(v)
        for (k, v) in dict[str, any](self.k8s_config.labels or {}).items()
    };
}


impl ManifestBuilder._service_account_name -> str {
    return str(getattr(self.k8s_config, "service_account_name", "") or "").strip();
}
