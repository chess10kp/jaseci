impl ManifestBuilder._resolve_scaling(
    svc_name: str, deployment: dict[str, any], service: dict[str, any]
) -> dict[str, any] {
    """Resolve a service's single, mutually-exclusive scaling decision.

        The one place a service's scaling mode is decided. The scale-target
        name is read from the Deployment manifest just built (never rebuilt
        from svc_name), so build, apply, and `jac plan` can never disagree on
        it. The gateway is forced out of HTTP_ACTIVATION here: it is the
        ingress entry point and must stay warm, so it must never inherit the
        shared scale-to-zero default.
        """;
    scale_target: str = deployment["metadata"]["name"];
    service_name: str = service["metadata"]["name"];
    http: dict[str, any] | None = self._get_http_activation_config(svc_name);
    if http is not None and svc_name == GATEWAY_NAME {
        if self.logger {
            self.logger.warn(
                "Ignoring http_activation for the gateway: it is the ingress "
                "entry point and must stay warm. Set http_activation "
                "per-service instead of relying on the shared default."
            );
        }
        http = None;
    }
    if http is not None {
        try {
            build_http_activation_spec(
                http, scale_target, self.k8s_config.namespace, service_name
            );
        } except ValueError as e {
            raise ValueError(f"[service '{svc_name}'] {e}") from e;
        }
        return {
            "mode": ScalingMode.HTTP_ACTIVATION,
            "scale_target_name": scale_target,
            "service_name": service_name,
            "autoscaler": {},
            "http_activation": http
        };
    }
    metric: dict[str, any] | None = self._get_autoscaler_config(svc_name);
    if metric is not None {
        return {
            "mode": ScalingMode.METRIC,
            "scale_target_name": scale_target,
            "service_name": service_name,
            "autoscaler": metric,
            "http_activation": {}
        };
    }
    return {
        "mode": ScalingMode.NONE,
        "scale_target_name": scale_target,
        "service_name": service_name,
        "autoscaler": {},
        "http_activation": {}
    };
}


impl ManifestBuilder._canonical_rules_fingerprint(rules: list[dict[str, any]]) -> str {
    """A rules fingerprint that ignores list ordering, so two services
        with the same match criteria collide in _validate_http_activation_rules
        even when `hosts`/`paths`/`headers`, or the rules themselves, are
        written in a different order -- fields within a rule are AND'd and
        separate rules are OR'd, so reordering never changes what a rule set
        actually matches.
        """;
    import json;
    canonical_rules = [];
    for rule in rules {
        headers = [
            (str(h.get("name", "")), str(h.get("value", "")))
            for h in rule.get("headers", [])
        ];
        canonical_rules.append(
            {
                "hosts": sorted(str(h) for h in rule.get("hosts", [])),
                "paths": sorted(str(p) for p in rule.get("paths", [])),
                "headers": sorted(headers)
            }
        );
    }
    canonical_rules.sort(key=lambda (r) { json.dumps(r, sort_keys=True); });
    return json.dumps(canonical_rules, sort_keys=True);
}


impl ManifestBuilder._validate_http_activation_rules(
    scaling: dict[str, dict[str, any]]
) {
    """Two services sharing the top-level http_activation default with no
        per-service override resolve to identical routing rules; the interceptor
        then has no way to tell which target a matching request belongs to.
        """;
    by_rules: dict[str, list[str]] = {};
    for (svc_name, plan) in scaling.items() {
        if plan.get("mode") != ScalingMode.HTTP_ACTIVATION {
            continue;
        }
        rules = plan.get("http_activation", {}).get("rules", []);
        if not rules {
            continue;
        }
        fingerprint = self._canonical_rules_fingerprint(rules);
        by_rules.setdefault(fingerprint, []).append(svc_name);
    }
    for svc_names in by_rules.values() {
        if len(svc_names) > 1 {
            names = ", ".join(sorted(svc_names));
            raise ValueError(
                f"[http_activation] {names} resolve to identical routing "
                f"rules, most likely all inheriting "
                f"[scale.kubernetes.http_activation]'s rules unchanged. The "
                f"KEDA HTTP Add-on interceptor can't tell which target a "
                f"matching request belongs to when two InterceptorRoutes "
                f"share the same match criteria. Set a distinct "
                f"[services.NAME.http_activation.rules] for at least all "
                f"but one of these services."
            );
        }
    }
}


impl ManifestBuilder._get_autoscaler_config(svc_name: str) -> dict[str, any] | None {
    svc: dict[str, any] = self._service_config(svc_name);

    hpa: dict[str, any] = svc.get("hpa", {});
    if not hpa.get("enabled", True) {
        return None;
    }
    raw_triggers: list[dict[str, any]] = [];
    for item in svc.get("triggers", []) {
        if isinstance(item, dict) {
            raw_triggers.append(dict(item));
        }
    }
    behavior = hpa.get("behavior", {});
    if not isinstance(behavior, dict) {
        if self.logger {
            self.logger.warning(
                f"Ignoring malformed hpa.behavior for '{svc_name}': expected "
                f"a table, got {type(behavior).__name__}"
            );
        }
        behavior = {};
    }
    cfg = self.k8s_config;
    return {
        "min": int(hpa.get("min", cfg.min_replicas)),
        "max": int(hpa.get("max", cfg.max_replicas)),
        "cpu_target": int(hpa.get("cpu_target", cfg.cpu_utilization_target)),
        "memory_target": int(hpa.get("memory_target", cfg.memory_utilization_target)),
        "has_memory_request": bool(
            self._resolved_memory_request(svc, svc_name == GATEWAY_NAME)
        ),
        "triggers": raw_triggers,
        "behavior": dict(behavior)
    };
}


impl ManifestBuilder._get_http_activation_config(
    svc_name: str
) -> dict[str, any] | None {
    svc: dict[str, any] = self._service_config(svc_name);
    per_service: dict[str, any] = svc.get("http_activation", {});
    merged: dict[str, any] = dict(self.k8s_config.http_activation);
    merged.update(per_service);
    if not merged.get("enabled", False) {
        return None;
    }
    return merged;
}


impl ManifestBuilder._build_ingress_manifest(
    ingress_cfg: dict[str, any]
) -> dict[str, any] | None {
    cfg = self.k8s_config;
    enabled: bool = bool(ingress_cfg.get("enabled", False));
    host: str = str(ingress_cfg.get("host", "")).strip();
    ingress_class: str = str(ingress_cfg.get("ingress_class_name", "")).strip();
    annotations: dict[str, str] = {};
    for (k, v) in ingress_cfg.get("annotations", {}).items() {
        annotations[str(k)] = str(v);
    }

    use_shared: bool = (not enabled) and cfg.shared_ingress and bool(cfg.domain);
    if use_shared {
        enabled = True;
        if not host {
            host = cfg.domain;
        }
        if not ingress_class {
            ingress_class = cfg.shared_ingress_class;
        }
        if not annotations {
            for (k, v) in cfg.shared_ingress_annotations.items() {
                annotations[str(k)] = str(v);
            }
        }
    }
    if not enabled {
        return None;
    }

    backend: dict[str, any] = {
        "service": {"name": "gateway-service", "port": {"number": cfg.container_port}}
    };
    path_entry: dict[str, any] = {
        "path": "/",
        "pathType": "Prefix",
        "backend": backend
    };

    rule: dict[str, any] = {"http": {"paths": [path_entry]}};
    if host {
        rule["host"] = host;
    }

    spec: dict[str, any] = {"rules": [rule]};
    if ingress_class {
        spec["ingressClassName"] = ingress_class;
    }

    cert_manager_managed: bool = (
        "cert-manager.io/cluster-issuer" in cfg.shared_ingress_annotations
        or "cert-manager.io/issuer" in cfg.shared_ingress_annotations
    );
    if use_shared and cfg.shared_ingress_tls and host and cert_manager_managed {
        spec["tls"] = [{"hosts": [host], "secretName": "gateway-tls"}];
    }

    return k8s_manifest(
        "Ingress",
        "gateway-ingress",
        {"spec": spec},
        cfg.namespace,
        {"app": "gateway", "managed": "jac-scale", "jac-scale.role": "gateway"},
        annotations
    );
}


impl ManifestBuilder._replica_floor(svc_name: str) -> int {
    svc_cfg = self._service_config(svc_name);
    hpa: dict[str, any] = dict(svc_cfg.get("hpa", {}));
    if hpa.get("enabled", True) {
        return int(hpa.get("min", 1));
    }
    return int(svc_cfg.get("replicas", 1));
}


impl ManifestBuilder._build_pdb_manifest(
    svc_name: str, mode: (ScalingMode | None) = None
) -> dict[str, any] | None {
    cfg: dict[str, any] = self._service_config(svc_name).get("pdb", {});
    if not cfg.get("enabled", True) {
        return None;
    }
    if mode == ScalingMode.HTTP_ACTIVATION {
        if self.logger and cfg {
            self.logger.warn(
                f"No PodDisruptionBudget emitted for '{svc_name}': it is "
                f"HTTP-activated and legitimately scales to zero replicas, "
                f"so a floor-based budget (pdb.max_unavailable / "
                f"min_available) doesn't apply. Disable it explicitly with "
                f"pdb.enabled = false to silence this warning."
            );
        }
        return None;
    }
    floor = self._replica_floor(svc_name);
    raw_min = cfg.get("min_available", None);
    spec = pdb_spec(
        floor,
        int(cfg.get("max_unavailable", 1)),
        None if raw_min is None else int(raw_min)
    );
    if spec is None {
        if self.logger and cfg {
            self.logger.warn(
                f"No PodDisruptionBudget emitted for '{svc_name}': "
                f"max_unavailable={int(cfg.get('max_unavailable', 1))} at a "
                f"replica floor of {floor} would permit evicting every "
                f"replica, so the budget would protect nothing. Raise "
                f"hpa.min, or set pdb.min_available to refuse voluntary "
                f"disruption instead."
            );
        }
        return None;
    }
    k8s_name = k8s_safe_name(svc_name);
    spec["selector"] = {"matchLabels": {"app": k8s_name}};
    return k8s_manifest(
        "PodDisruptionBudget",
        f"{k8s_name}-pdb",
        {"spec": spec},
        self.k8s_config.namespace,
        {"app": k8s_name, "managed": "jac-scale"}
    );
}


impl pdb_spec(
    replica_floor: int, max_unavailable: int, min_available: (int | None) = None
) -> dict[str, any] | None {
    if min_available is not None {
        return {"minAvailable": min_available};
    }
    if max_unavailable >= replica_floor {
        return None;
    }
    return {"maxUnavailable": max_unavailable};
}
