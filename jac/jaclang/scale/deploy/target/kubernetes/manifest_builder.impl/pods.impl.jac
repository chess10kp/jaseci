impl ManifestBuilder.generate_service_pod_specs(
    app_config: AppConfig, image: str
) -> dict[str, dict[str, any]] {
    fleet = self._fleet(app_config);
    if fleet.is_empty() {
        raise ValueError(
            "Nothing to deploy: the fleet has no apps. Declare [apps] in "
            "jac.toml or set [project].name."
        );
    }

    specs: dict[str, dict[str, any]] = {};
    for svc_name in fleet.names() {
        specs[svc_name] = self._build_service_pod_spec(svc_name, image);
    }
    specs[GATEWAY_NAME] = self._build_gateway_pod_spec(image);

    if self.logger {
        self.logger.info(
            f"Generated {len(specs)} pod-spec stubs "
            f"(1 gateway + {len(fleet.members)} apps)",
            {"image": image, "namespace": self.k8s_config.namespace}
        );
    }
    return specs;
}


impl ManifestBuilder._build_readiness_probe -> dict[str, any] {
    cfg = self.k8s_config;
    return {
        "httpGet": {"path": "/healthz/ready", "port": cfg.container_port},
        "initialDelaySeconds": cfg.readiness_initial_delay,
        "periodSeconds": cfg.readiness_period,
        "timeoutSeconds": 3,
        "failureThreshold": 3
    };
}


impl ManifestBuilder._build_liveness_probe -> dict[str, any] {
    cfg = self.k8s_config;
    return {
        "httpGet": {"path": "/healthz/live", "port": cfg.container_port},
        "initialDelaySeconds": cfg.liveness_initial_delay,
        "periodSeconds": cfg.liveness_period,
        "timeoutSeconds": 3,
        "failureThreshold": cfg.liveness_failure_threshold
    };
}


impl ManifestBuilder._build_startup_probe -> dict[str, any] {
    cfg = self.k8s_config;
    return {
        "httpGet": {"path": "/healthz/live", "port": cfg.container_port},
        "periodSeconds": 10,
        "timeoutSeconds": 3,
        "failureThreshold": 90
    };
}


impl ManifestBuilder._alb_deregistration_cushion -> int {
    cfg = self.k8s_config;
    is_alb = bool(getattr(cfg, "shared_ingress", False))
        and str(getattr(cfg, "shared_ingress_class", "")).lower() == "alb";
    return 20 if is_alb else 0;
}


impl ManifestBuilder._build_prestop_hook -> dict[str, any] {
    cushion = 5 + self._alb_deregistration_cushion();
    return {"exec": {"command": ["sh", "-c", f"sleep {cushion}"]}};
}


impl ManifestBuilder._build_deployment_manifest(
    svc_name: str, pod_spec: dict[str, any]
) -> dict[str, any] {
    k8s_name = k8s_safe_name(svc_name);
    role: str = "gateway" if svc_name == GATEWAY_NAME else "microservice";
    labels: dict[str, str] = {
        ** self._owner_labels(),
        "app": k8s_name,
        "managed": "jac-scale",
        "jac-scale.role": role
    };
    svc_cfg = self._service_config(svc_name);
    replicas: int = int(svc_cfg.get("replicas", 1));
    manifest: dict[str, any] = k8s_manifest(
        "Deployment",
        f"{k8s_name}-deployment",
        {
            "spec": {
                "replicas": replicas,
                "revisionHistoryLimit": self.k8s_config.revision_history_limit,
                "strategy": {
                    "type": "RollingUpdate",
                    "rollingUpdate": {"maxSurge": 1, "maxUnavailable": 0}
                },
                "selector": {"matchLabels": {"app": k8s_name}},
                "template": {"metadata": {"labels": labels}, "spec": pod_spec}
            }
        },
        self.k8s_config.namespace,
        labels
    );
    overlay = svc_cfg.get("deployment_overlay");
    if isinstance(overlay, dict) and overlay {
        manifest = merge_manifest_overlay(manifest, overlay);

        manifest["metadata"]["name"] = f"{k8s_name}-deployment";
        manifest["metadata"]["namespace"] = self.k8s_config.namespace;
        meta_labels = manifest["metadata"].get("labels", {});
        meta_labels.update(labels);
        manifest["metadata"]["labels"] = meta_labels;
        manifest["spec"]["selector"] = {"matchLabels": {"app": k8s_name}};
        tmpl_labels = manifest["spec"]["template"]["metadata"].get("labels", {});
        tmpl_labels.update({"app": k8s_name, "managed": "jac-scale"});
        manifest["spec"]["template"]["metadata"]["labels"] = tmpl_labels;
    }
    return manifest;
}


impl ManifestBuilder._build_service_manifest(svc_name: str) -> dict[str, any] {
    k8s_name = k8s_safe_name(svc_name);
    port: int = self.k8s_config.container_port;
    spec: dict[str, any] = {
        "type": "ClusterIP",
        "selector": {"app": k8s_name},
        "ports": [{"protocol": "TCP", "port": port, "targetPort": port}]
    };

    if svc_name == GATEWAY_NAME {
        spec["sessionAffinity"] = "ClientIP";
        spec["sessionAffinityConfig"] = {"clientIP": {"timeoutSeconds": 10800}};
    }
    return k8s_manifest(
        "Service",
        f"{k8s_name}-service",
        {"spec": spec},
        self.k8s_config.namespace,
        {** self._owner_labels(), "app": k8s_name, "managed": "jac-scale"}
    );
}


impl ManifestBuilder._pod_entrypoint -> dict[str, any] {
    import from jaclang.scale.injector.bundle { APP_MOUNT_PATH }
    import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        build_service_apt_prefix
    }
    apt_prefix = build_service_apt_prefix(self.k8s_config);
    return {
        "command": ["bash", "-c"],
        "args": [
            "set -euo pipefail; "
            f"cd {APP_MOUNT_PATH}; "
            f"{apt_prefix}"
            'if [ "$JAC_SV_NAME" = "__gateway__" ]; then '
            "  exec jac scale gateway; "
            "else "
            '  SV_FILE="${JAC_SV_FILE:-}"; '
            '  if [ -z "$SV_FILE" ]; then '
            '    echo "jac-scale boot: JAC_SV_FILE is not set on this pod ($JAC_SV_NAME); the deploy bakes it into every service pod, so check for an edited manifest or an overlay that dropped it." >&2; '
            "    exit 1; "
            "  fi; "
            '  if [ ! -f "$SV_FILE" ]; then '
            '    echo "jac-scale boot: app $JAC_SV_NAME resolves to $SV_FILE, which the shipped bundle does not contain; check [apps] in jac.toml and re-deploy." >&2; '
            "    exit 1; "
            "  fi; "
            '  exec jac run --serve "$SV_FILE"; '
            "fi"
        ]
    };
}


impl ManifestBuilder._build_pod_spec(svc_name: str, image: str) -> dict[str, any] {
    drain_t: int = self._drain_timeout();
    svc_cfg = self._service_config(svc_name);
    `entry = self._pod_entrypoint();

    resolved_image: str = self.k8s_config.python_image;
    env_list = self._build_env(svc_name, svc_cfg);

    container: dict[str, any] = {
        "name": k8s_safe_name(svc_name),
        "image": resolved_image,
        "command": `entry["command"],
        "args": `entry["args"],
        "env": env_list,
        "ports": [{"containerPort": self.k8s_config.container_port}],
        "readinessProbe": self._build_readiness_probe(),
        "livenessProbe": self._build_liveness_probe(),
        "lifecycle": {"preStop": self._build_prestop_hook()}
    };
    import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        image_pull_policy
    }
    pull_policy = image_pull_policy(resolved_image);
    if pull_policy {
        container["imagePullPolicy"] = pull_policy;
    }

    container["startupProbe"] = self._build_startup_probe();
    resources = self._build_resources(svc_cfg, svc_name == GATEWAY_NAME);
    if resources {
        container["resources"] = resources;
    }
    (shared_vols, shared_mounts) = self._shared_volumes_for_service(svc_name);

    import from jaclang.scale.injector.bundle { APP_MOUNT_PATH }
    import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        runtime_container_env
    }
    container["workingDir"] = APP_MOUNT_PATH;
    env_list.extend(runtime_container_env());
    if shared_mounts {
        container["volumeMounts"] = shared_mounts;
    }

    container["envFrom"] = [{"secretRef": {"name": self._user_secret_name()}}];
    spec: dict[str, any] = {
        "containers": [container],
        "terminationGracePeriodSeconds": drain_t
            + _EXIT_CUSHION_S
            + self._alb_deregistration_cushion()
    };
    sa_name = self._service_account_name();
    if sa_name {
        spec["serviceAccountName"] = sa_name;
    }
    spec["volumes"] = list(shared_vols);
    spec["initContainers"] = list(self.deploy_context.init_containers);
    if shared_mounts {
        import from jaclang.scale.injector.pvc_injector {
            VOLUME_PERMS_NAME,
            build_volume_perms_init_container,
            runtime_pod_security_context
        }
        spec["initContainers"].insert(
            0,
            build_volume_perms_init_container(
                VOLUME_PERMS_NAME, resolved_image, shared_mounts
            )
        );
        spec["securityContext"] = runtime_pod_security_context();
    }

    import from jaclang.scale.injector.binary_injector { BinaryInjector }
    injector: BinaryInjector = BinaryInjector(
        storage_class=self.k8s_config.bundle_storage_class
    );
    injector._toolchain_object_key = self._toolchain_object_key;
    injector._object_key = self._injector_object_key();
    spec["_jac_meta"] = {
        "app_name": k8s_safe_name(self.k8s_config.app_name),
        "namespace": self.k8s_config.namespace
    };
    spec = injector.mutate_pod_spec(spec, self.k8s_config.python_image);
    spec.pop("_jac_meta", None);

    import from jaclang.scale.deploy.target.kubernetes.runtime_bootstrap {
        build_bootstrap_init_container
    }
    spec["initContainers"].append(
        build_bootstrap_init_container(self.k8s_config, self.k8s_config.python_image)
    );
    return spec;
}


impl ManifestBuilder._build_service_pod_spec(
    svc_name: str, image: str
) -> dict[str, any] {
    return self._build_pod_spec(svc_name, image);
}


impl ManifestBuilder._build_gateway_pod_spec(image: str) -> dict[str, any] {
    return self._build_pod_spec(GATEWAY_NAME, image);
}
