impl ManifestBuilder.check_pod_config(app_config: AppConfig, image: str) {
    self.project_dir = self.project_dir or app_config.code_folder;
    pod_specs = self.generate_service_pod_specs(app_config, image);
    deployments = {
        svc_name: self._build_deployment_manifest(svc_name, pod_spec)
        for (svc_name, pod_spec) in pod_specs.items()
    };
    self._check_pod_config_resolves(deployments, self._build_user_secret_manifest());
}


impl ManifestBuilder._check_pod_config_resolves(
    deployments: dict[str, dict[str, any]], user_secret: dict[str, any] | None
) {
    import from pathlib { Path }
    import from jaclang.scale.injector.bundle {
        nested_sanitized_tomls,
        sanitized_jac_toml,
        source_filter_for,
        unresolved_toml_references
    }
    base = Path(self.project_dir);
    base_toml = sanitized_jac_toml(base);
    if base_toml is None {
        return;
    }
    nested = nested_sanitized_tomls(base);
    excluded = source_filter_for(base);
    secret_keys = set(dict(dict(user_secret or {}).get("stringData", {})).keys());
    affected: dict[str, list[str]] = {};
    for (svc_name, deployment) in deployments.items() {
        container = deployment["spec"]["template"]["spec"]["containers"][0];
        environ = self._pod_environ(container, secret_keys);
        if environ is None {
            continue;
        }
        tomls = self._pod_tomls(base, excluded, "jac.toml", base_toml, environ);
        nearest = self._nearest_nested_toml(nested, environ.get("JAC_SV_FILE", ""));
        if nearest {
            tomls.update(
                self._pod_tomls(base, excluded, nearest, nested[nearest], environ)
            );
        }
        for (rel, text) in tomls.items() {
            for problem in unresolved_toml_references(text, environ) {
                affected.setdefault(f"{rel}: {problem}", []).append(svc_name);
            }
        }
    }
    if not affected {
        return;
    }
    lines: list[str] = [];
    for (problem, pods) in affected.items() {
        scope = "every pod" if len(pods) == len(deployments) else ", ".join(pods);
        lines.append(f"  {problem} ({scope})");
    }
    raise ValueError(
        "jac.toml reads environment variables the deployed pods will not have, "
        "so these settings cannot resolve at boot:\n"
            + "\n".join(lines)
            + "\nSupply each one through [scale.secrets] or the app's env, or give "
            "it a ${VAR:-default}."
    );
}


impl ManifestBuilder._pod_environ(
    container: dict[str, any], secret_keys: set[str]
) -> dict[str, str] | None {
    environ: dict[str, str] = {
        name: ""
        for name in ("HOSTNAME", "KUBERNETES_SERVICE_HOST", "KUBERNETES_SERVICE_PORT")
    };
    for `entry in container.get("env", []) or [] {
        environ[str(`entry.get("name"))] = str(`entry.get("value", ""));
    }
    for source in container.get("envFrom", []) or [] {
        if dict(source.get("secretRef") or {}).get("name")
            != self._user_secret_name() {
            return None;
        }
        for key in secret_keys {
            environ.setdefault(key, "");
        }
    }
    if self.k8s_config.database_enabled() {
        environ.setdefault(DATABASE_URL_ENV, "");
    }
    return environ;
}


impl ManifestBuilder._pod_tomls(
    base: any, excluded: any, toml_rel: str, toml_text: str, environ: dict[str, str]
) -> dict[str, str] {
    import tomllib;
    import from pathlib { Path, PurePosixPath }
    environment = dict(tomllib.loads(toml_text).get("environment", {}) or {});
    profile = environ.get("JAC_PROFILE", "").strip()
        or str(environment.get("default_profile", "") or "").strip();
    names = [f"jac.{profile}.toml"] if profile else [];
    names.append("jac.local.toml");
    folder = PurePosixPath(toml_rel).parent;
    tomls = {toml_rel: toml_text};
    for name in names {
        rel = (folder / name).as_posix();
        path = Path(base) / rel;
        if path.is_file() and not excluded.excludes(Path(rel)) {
            tomls[rel] = path.read_text(encoding="utf-8");
        }
    }
    return tomls;
}


impl ManifestBuilder._nearest_nested_toml(nested: dict[str, str], sv_file: str) -> str {
    import from pathlib { PurePosixPath }
    nearest = "";
    for rel in nested {
        if sv_file
            and PurePosixPath(sv_file).is_relative_to(PurePosixPath(rel).parent)
            and len(rel) > len(nearest) {
            nearest = rel;
        }
    }
    return nearest;
}


impl ManifestBuilder._serve_env(
    svc_name: str, svc_cfg: dict[str, any]
) -> list[dict[str, any]] {
    settings = self._serve_settings();
    workers = str(svc_cfg.get("workers") or settings.workers.count);
    env: list[dict[str, any]] = [
        {"name": "JAC_SERVE_WORKERS", "value": workers},
        {"name": "JAC_SERVE_ACCESS_LOG_FORMAT", "value": "json"},
        {"name": "JAC_SERVE_ACCESS_LOG_SUPPRESS_HEALTH", "value": "1"},
        {"name": "JAC_SERVE_DRAIN_TIMEOUT", "value": str(self._drain_timeout())}
    ];
    threads = svc_cfg.get("threads");
    if threads is not None {
        env.append({"name": "JAC_SERVE_THREADS", "value": str(threads)});
    }
    trusted = list(settings.proxy.trusted);
    if svc_name != GATEWAY_NAME {
        trusted = trusted or ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"];
    }
    if trusted {
        env.append({"name": "JAC_SERVE_PROXY_TRUSTED", "value": ",".join(trusted)});
    }
    return env;
}


impl ManifestBuilder._shared_volumes_config -> list[dict[str, any]] {
    raw = self._gateway_cfg().get("shared_volumes", []);
    if not isinstance(raw, list) {
        return [];
    }
    out: list[dict[str, any]] = [];
    for `entry in raw {
        if isinstance(`entry, dict) {
            out.append(dict(`entry));
        }
    }
    return out;
}


impl ManifestBuilder._shared_volumes_for_service(
    svc_name: str
) -> tuple[list[dict[str, any]], list[dict[str, any]]] {
    volumes: list[dict[str, any]] = [];
    mounts: list[dict[str, any]] = [];
    for vol in self._shared_volumes_config() {
        apps = vol.get("apps", []);
        if not isinstance(apps, list) {
            continue;
        }
        if svc_name not in apps {
            continue;
        }
        name = str(vol.get("name", "")).strip();
        mount_path = str(vol.get("mount_path", "")).strip();
        if not name or not mount_path {
            continue;
        }
        vol_name = k8s_safe_name(name);
        host_path = str(vol.get("host_path", "")).strip();
        if host_path {
            volumes.append(
                {
                    "name": vol_name,
                    "hostPath": {"path": host_path, "type": "DirectoryOrCreate"}
                }
            );
        } else {
            volumes.append(
                {"name": vol_name, "persistentVolumeClaim": {"claimName": vol_name}}
            );
        }
        mount_entry: dict[str, any] = {"name": vol_name, "mountPath": mount_path};
        sub_path = str(vol.get("sub_path", "")).strip();
        if sub_path {
            mount_entry["subPath"] = sub_path;
        }
        mounts.append(mount_entry);
    }
    return (volumes, mounts);
}


impl ManifestBuilder._build_shared_pvc_manifests -> dict[str, dict[str, any]] {
    pvcs: dict[str, dict[str, any]] = {};
    for vol in self._shared_volumes_config() {
        name = str(vol.get("name", "")).strip();
        if not name {
            continue;
        }

        mount_path = str(vol.get("mount_path", "")).strip();
        if not mount_path {
            continue;
        }
        apps = vol.get("apps", []);
        if not isinstance(apps, list) or not apps {
            continue;
        }

        if str(vol.get("host_path", "")).strip() {
            continue;
        }
        size = str(vol.get("size", "1Gi")).strip() or "1Gi";
        access_mode = str(vol.get("access_mode", "ReadWriteOnce")).strip()
            or "ReadWriteOnce";
        storage_class = str(vol.get("storage_class", "")).strip();
        pvc_name = k8s_safe_name(name);

        spec: dict[str, any] = {
            "accessModes": [access_mode],
            "resources": {"requests": {"storage": size}}
        };
        if storage_class {
            spec["storageClassName"] = storage_class;
        }
        pvcs[pvc_name] = k8s_manifest(
            "PersistentVolumeClaim",
            pvc_name,
            {"spec": spec},
            self.k8s_config.namespace,
            {
                "app": "jac-scale-shared",
                "managed": "jac-scale",
                "jac-scale.role": "shared-volume",
                "jac-scale.owner": k8s_safe_name(self.k8s_config.app_name)
            }
        );
    }
    return pvcs;
}


impl ManifestBuilder._build_user_secret_manifest -> dict[str, any] | None {
    data: dict[str, str] = {k: str(v) for (k, v) in self.secrets.items()};
    data["JAC_SERVE_AUTH_SECRET"] = self._signing_secret();
    return k8s_manifest(
        "Secret",
        f"{self.k8s_config.app_name}-secrets",
        {"type": "Opaque", "stringData": data},
        self.k8s_config.namespace,
        {
            "app": "jac-scale-user-secrets",
            "managed": "jac-scale",
            "jac-scale.role": "user-secrets"
        }
    );
}


impl ManifestBuilder._peer_dns_url(peer_name: str) -> str {
    import from jaclang.scale.runtime.context.util { k8s_service_dns_url }
    return k8s_service_dns_url(
        k8s_safe_name(peer_name),
        self.k8s_config.namespace,
        self.k8s_config.container_port
    );
}


impl ManifestBuilder._build_env(
    svc_name: str, svc_cfg: dict[str, any]
) -> list[dict[str, any]] {
    env: list[dict[str, any]] = [
        {"name": "JAC_SV_NAME", "value": svc_name},
        {"name": "JAC_SV_SIBLING", "value": "1"},
        {"name": "K8S_APP_NAME", "value": self.k8s_config.app_name},
        {"name": "K8S_NAMESPACE", "value": self.k8s_config.namespace}
    ];
    svc_file: str = self._bundle_files().get(svc_name, "");
    if not svc_file and self.fleet is not None {
        member = self.fleet.member(svc_name);
        svc_file = member.file if member is not None else "";
    }
    if svc_file {
        env.append({"name": "JAC_SV_FILE", "value": svc_file});
    }

    trace_cfg: dict[str, any] = dict(self._gateway_cfg().get("tracing", {}));
    if trace_cfg.get("enabled", False) {
        env.append(
            {
                "name": "OTEL_EXPORTER_OTLP_ENDPOINT",
                "value": f"http://{self.k8s_config.app_name}-alloy-service:4318"
            }
        );
    }

    import from jaclang.scale.runtime.fleet { FLEET_ENV }
    peers: list[str] = [];
    if self.fleet is not None and not self.fleet.is_empty() {
        env.append({"name": FLEET_ENV, "value": self.fleet.to_env()});
        peers = self.fleet.names();
    }
    seen_peer_keys: set = set();
    for peer_name in peers {
        if peer_name == svc_name or peer_name == GATEWAY_NAME {
            continue;
        }
        key = sv_client.peer_url_env_key(peer_name);
        if key in seen_peer_keys {
            continue;
        }
        seen_peer_keys.add(key);
        env.append({"name": key, "value": self._peer_dns_url(peer_name)});
    }

    for `entry in self.deploy_context.env_list {
        env.append(`entry);
    }
    env.extend(self._serve_env(svc_name, svc_cfg));

    extra: dict[str, any] = svc_cfg.get("env", {});
    for (k, v) in extra.items() {
        if k in ("JAC_SV_NAME", "JAC_SV_FILE", "JAC_SV_SIBLING", FLEET_ENV) {
            continue;
        }
        if k.startswith("JAC_APP_") and (k.endswith("_URL") or k.endswith("_ROUTE")) {
            continue;
        }
        env.append({"name": k, "value": str(v)});
    }
    return env;
}


impl ManifestBuilder._resolved_memory_request(
    svc_cfg: dict[str, any], is_gateway: bool
) -> str {
    val = svc_cfg.get("memory_request");
    if val is None {
        val = self.k8s_config.memory_request;
    }
    if val is None {
        val = "2Gi" if is_gateway else "1Gi";
    }
    return str(val) if val else "";
}


impl ManifestBuilder._build_resources(
    svc_cfg: dict[str, any], is_gateway: bool = False
) -> dict[str, any] {
    cfg = self.k8s_config;

    memory_request_val = self._resolved_memory_request(svc_cfg, is_gateway);
    memory_limit_val = svc_cfg.get("memory_limit");
    if memory_limit_val is None {
        memory_limit_val = cfg.memory_limit;
    }
    if memory_limit_val is None {
        memory_limit_val = "8Gi" if is_gateway else "4Gi";
    }
    cpu_request_val = svc_cfg.get("cpu_request");
    if cpu_request_val is None {
        cpu_request_val = cfg.cpu_request;
    }
    if cpu_request_val is None {
        cpu_request_val = "50m";
    }
    cpu_limit_val = svc_cfg.get("cpu_limit");
    if cpu_limit_val is None {
        cpu_limit_val = cfg.cpu_limit;
    }

    requests: dict[str, str] = {};
    limits: dict[str, str] = {};
    if cpu_request_val {
        requests["cpu"] = str(cpu_request_val);
    }
    if memory_request_val {
        requests["memory"] = str(memory_request_val);
    }
    if cpu_limit_val {
        limits["cpu"] = str(cpu_limit_val);
    }
    if memory_limit_val {
        limits["memory"] = str(memory_limit_val);
    }
    out: dict[str, any] = {};
    if requests {
        out["requests"] = requests;
    }
    if limits {
        out["limits"] = limits;
    }
    return out;
}
