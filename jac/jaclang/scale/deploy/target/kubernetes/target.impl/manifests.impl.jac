impl KubernetesTarget.generate_manifests(app_config: AppConfig) -> dict[str, any] {
    import from jaclang.scale.injector.binary { resolve_pod_base_image }
    self.k8s_config.python_image = resolve_pod_base_image(
        app_config.code_folder, self.k8s_config.python_image, probe=not self.dry_run
    );
    return self._manifest_builder(app_config).generate_manifests(
        app_config, self.k8s_config.python_image
    );
}


impl KubernetesTarget._manifest_builder(app_config: AppConfig) -> ManifestBuilder {
    return ManifestBuilder(
        k8s_config=self.k8s_config,
        secrets=self.secrets,
        deploy_context=self._context_with_env(),
        logger=self.logger,
        project_dir=app_config.code_folder,
        fleet=self.fleet,
        gateway_config=self.gateway_config,
        app_overrides=dict(self.app_overrides),
        dry_run=self.dry_run
    );
}


impl KubernetesTarget._context_with_env -> DeployContext {
    if not self.env {
        return self._deploy_context;
    }
    ctx = DeployContext(
        env_list=list(self._deploy_context.env_list),
        init_containers=self._deploy_context.init_containers
    );
    present = {`entry.get("name") for `entry in ctx.env_list};
    for (env_name, env_value) in self.env.items() {
        if env_name not in present {
            ctx.env_list.append({"name": env_name, "value": str(env_value)});
        }
    }
    return ctx;
}


impl KubernetesTarget._resolve_service_triggers(
    svc_name: str, cfg: dict[str, any]
) -> list[Trigger] {
    is_gateway = svc_name == GATEWAY_NAME;
    has_memory_request = bool(cfg.get("has_memory_request", True));
    effective_extra: list[dict[str, any]] = self.k8s_config.extra_triggers
        if is_gateway
        else [];
    triggers: list[Trigger] = [];
    if not cfg.get("triggers", []) and not effective_extra {
        triggers = [
            Trigger(
                type="cpu",
                metadata={
                    "averageUtilization": str(
                        cfg.get("cpu_target", self.k8s_config.cpu_utilization_target)
                    )
                }
            )
        ];
        if has_memory_request {
            triggers.append(
                Trigger(
                    type="memory",
                    metadata={
                        "averageUtilization": str(
                            cfg.get(
                                "memory_target",
                                self.k8s_config.memory_utilization_target
                            )
                        )
                    }
                )
            );
        }
    }
    raw_triggers: list[dict[str, any]] = cfg.get("triggers", []) or [];
    for raw in raw_triggers + effective_extra {
        t = Trigger(
            type=str(raw.get("type", "")),
            metadata=dict(raw.get("metadata", {})),
            name=raw.get("name")
        );
        if t.type == "memory" and not has_memory_request {
            if self.logger {
                self.logger.warn(
                    f"Skipping 'memory' trigger for '{svc_name}': "
                    "memory_request resolves empty (explicitly set to "
                    "\"\"); HPA cannot compute memory utilization "
                    "without a request baseline"
                );
            }
            continue;
        }
        raw_auth: dict[str, any] = raw.get("auth") or {};
        if raw_auth {
            t.auth = TriggerAuth(secret_refs=dict(raw_auth.get("secret_refs", {})));
        }
        triggers.append(t);
    }
    return triggers;
}


impl KubernetesTarget._autoscaler_spec(
    svc_name: str, plan: dict[str, any], autoscaler: any, namespace: str
) -> AutoscalerSpec {
    """Build the AutoscalerSpec for a METRIC-mode service from its already-
        resolved scaling plan, so the scale target here is the same Deployment
        name apply_manifests actually applied -- never re-derived from svc_name,
        which is exactly the drift that caused apply_http_activation to 404 on
        a real cluster before _resolve_scaling existed.
        """;
    k8s_name = k8s_safe_name(svc_name);
    cfg: dict[str, any] = dict(plan.get("autoscaler", {}));
    return AutoscalerSpec(
        scale_target_name=str(plan.get("scale_target_name", "")),
        autoscaler_name=autoscaler.resource_name_for(k8s_name),
        app_name=k8s_name,
        namespace=namespace,
        min_replicas=int(cfg.get("min", self.k8s_config.min_replicas)),
        max_replicas=int(cfg.get("max", self.k8s_config.max_replicas)),
        idle_replicas=self.k8s_config.idle_replicas,
        polling_interval=self.k8s_config.autoscaler_polling_interval,
        cooldown_period=self.k8s_config.autoscaler_cooldown,
        initial_cooldown_period=self.k8s_config.autoscaler_initial_cooldown,
        scale_up_stabilization=self.k8s_config.autoscaler_scale_up_stabilization,
        scale_up_max_pods=self.k8s_config.autoscaler_scale_up_max_pods,
        triggers=self._resolve_service_triggers(svc_name, cfg),
        behavior_overlay=cfg.get("behavior", {})
    );
}


impl KubernetesTarget.render_autoscaler_manifests(
    bundle: dict[str, any]
) -> list[dict[str, any]] {
    out: list[dict[str, any]] = [];
    scaling: dict[str, any] = bundle.get("scaling", {});
    for svc_name in scaling.keys() {
        plan: dict[str, any] = dict(scaling.get(svc_name, {}));
        if plan.get("mode") != ScalingMode.METRIC {
            continue;
        }
        autoscaler = AutoscalerFactory.create(
            self.k8s_config.autoscaler_engine, self.k8s_config.to_dict(), None
        );
        out.extend(
            autoscaler._build_manifests(
                self._autoscaler_spec(
                    svc_name, plan, autoscaler, self.k8s_config.namespace
                )
            )
        );
    }
    return out;
}


impl KubernetesTarget.apply_manifests(bundle: dict[str, any]) {
    self._load_cluster_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();
    policy_v1 = client.PolicyV1Api();
    networking_v1 = client.NetworkingV1Api();
    namespace: str = self.k8s_config.namespace;

    try {
        core_v1.list_namespace(_request_timeout=5);
    } except Exception as e {
        raise RuntimeError(
            f"Kubernetes API server is unreachable.\n"
            f"  - Verify cluster: kubectl cluster-info\n"
            f"  - For minikube:   minikube status\n"
            f"  - For EKS/GKE:    re-run your kubeconfig refresh "
            f"(aws eks update-kubeconfig / gcloud container clusters get-credentials)\n"
            f"Original error: {e}"
        );
    }

    ensure_namespace_exists(namespace, k8s_safe_name(self.k8s_config.app_name));
    self.ensure_alb_readiness_gates(core_v1, namespace);

    ops_rbac = bundle.get("ops_rbac");
    if ops_rbac {
        self._apply_ops_rbac(namespace, ops_rbac);
    }

    pvcs: dict[str, dict[str, any]] = bundle.get("pvcs", {}) or {};
    for (pvc_name, pvc_manifest) in pvcs.items() {
        self._apply_or_replace_pvc(core_v1, namespace, pvc_manifest);
        if self.logger {
            self.logger.info(
                f"Applied PVC for shared volume '{pvc_name}'",
                {"name": pvc_manifest["metadata"]["name"]}
            );
        }
    }

    injector = bundle.get("injector");
    if injector is not None {
        injector.seed(k8s_safe_name(self.k8s_config.app_name), namespace);
        if self.logger {
            self.logger.info(
                "Seeded source bundle onto the bundle PVC",
                {"app_name": k8s_safe_name(self.k8s_config.app_name)}
            );
        }
    }

    config_revision: str = "";
    user_secret = bundle.get("user_secret");
    if user_secret {
        config_revision = create_k8s_secret(
            core_v1,
            namespace,
            user_secret["metadata"]["name"],
            user_secret["stringData"]
        );
        if not config_revision {
            raise RuntimeError(
                f"Applied the Secret for '{self.k8s_config.app_name}' but "
                "could not read the "
                "revision it returned, so a config change could not be made "
                "to reach running pods. Refusing to deploy workloads rather "
                "than reporting a success that leaves the old config live."
            );
        }
        if self.logger {
            self.logger.info(
                f"Applied Secret for user-defined [scale.secrets] "
                f"({len(user_secret['stringData'])} keys)",
                {"name": user_secret["metadata"]["name"]}
            );
        }
    }

    services: dict[str, dict[str, any]] = bundle["services"];
    for (svc_name, svc_manifest) in services.items() {
        patch_k8s_resource(core_v1, "Service", svc_manifest, namespace);
        if self.logger {
            self.logger.info(
                f"Applied Service for '{svc_name}'",
                {"name": svc_manifest["metadata"]["name"]}
            );
        }
    }

    scaling: dict[str, any] = bundle.get("scaling", {});

    deployments: dict[str, dict[str, any]] = bundle["deployments"];
    for (svc_name, raw_manifest) in deployments.items() {
        dep_manifest = with_config_revision(raw_manifest, config_revision);
        patch_body = None;
        if dict(scaling.get(svc_name, {})).get("mode") == ScalingMode.HTTP_ACTIVATION {
            patch_body = dict(dep_manifest);
            patch_body["spec"] = {
                k: v
                for (k, v) in dep_manifest["spec"].items()
                if k != "replicas"
            };
        }
        patch_k8s_resource(apps_v1, "Deployment", dep_manifest, namespace, patch_body);
        if self.logger {
            self.logger.info(
                f"Applied Deployment for '{svc_name}'",
                {"name": dep_manifest["metadata"]["name"]}
            );
        }
    }

    self.reap_superseded_deployments(apps_v1, namespace, bundle);

    reap_stale_scaling_resources_for_bundle(
        bundle,
        namespace,
        AutoscalerFactory.create(
            self.k8s_config.autoscaler_engine, self.k8s_config.to_dict(), self.logger
        ),
        KEDAAutoscaler(logger=self.logger)
    );

    for svc_name in scaling.keys() {
        plan: dict[str, any] = dict(scaling.get(svc_name, {}));
        if plan.get("mode") != ScalingMode.METRIC {
            continue;
        }
        autoscaler = AutoscalerFactory.create(
            self.k8s_config.autoscaler_engine, self.k8s_config.to_dict(), self.logger
        );
        spec = self._autoscaler_spec(svc_name, plan, autoscaler, namespace);
        autoscaler_applied = autoscaler.apply(spec);

        if self.logger and autoscaler_applied {
            self.logger.info(
                f"Applied autoscaler for '{svc_name}'", {"name": spec.autoscaler_name}
            );
        }
    }

    apply_http_activations_for_bundle(
        bundle, namespace, KEDAAutoscaler(logger=self.logger)
    );

    pdbs: dict[str, dict[str, any]] = bundle.get("pdbs", {}) or {};
    for (svc_name, pdb_manifest) in pdbs.items() {
        patch_k8s_resource(policy_v1, "PodDisruptionBudget", pdb_manifest, namespace);
        if self.logger {
            self.logger.info(
                f"Applied PDB for '{svc_name}'",
                {"name": pdb_manifest["metadata"]["name"]}
            );
        }
    }

    ingress_manifest: any = bundle.get("ingress");
    if ingress_manifest {
        patch_k8s_resource(networking_v1, "Ingress", ingress_manifest, namespace);
        if self.logger {
            self.logger.info(
                "Applied Ingress for gateway",
                {"name": ingress_manifest["metadata"]["name"]}
            );
        }
    }
}


impl KubernetesTarget._apply_ops_rbac(namespace: str, ops_rbac: dict[str, any]) {
    try {
        rbac_v1 = client.RbacAuthorizationV1Api();
        role = ops_rbac["role"];
        binding = ops_rbac["role_binding"];
        role_name: str = role["metadata"]["name"];
        binding_name: str = binding["metadata"]["name"];

        apply_k8s_resource(rbac_v1, "Role", role_name, role, namespace=namespace);

        apply_k8s_resource(
            rbac_v1, "RoleBinding", binding_name, binding, namespace=namespace
        );

        if self.logger {
            subj = binding["subjects"][0]["name"];
            self.logger.info(
                f"Applied Ops Console RBAC (read-only Role + RoleBinding)",
                {"name": role_name, "serviceAccount": subj}
            );
        }
    } except Exception as e {
        if self.logger {
            self.logger.warning(
                f"Ops Console RBAC not applied ({e}); the in-admin "
                f"deploy-health pages will render a 403 until the Role is "
                f"bound to the gateway ServiceAccount."
            );
        }
    }
}


impl apply_http_activations_for_bundle(
    bundle: dict[str, any], namespace: str, keda: KEDAAutoscaler
) {
    scaling: dict[str, any] = bundle.get("scaling", {});
    for svc_name in scaling.keys() {
        plan: dict[str, any] = dict(scaling.get(svc_name, {}));
        if plan.get("mode") != ScalingMode.HTTP_ACTIVATION {
            continue;
        }
        apply_http_activation_for_target(
            dict(plan.get("http_activation", {})),
            str(plan.get("scale_target_name", "")),
            namespace,
            str(plan.get("service_name", "")),
            keda
        );
    }
}


impl reap_stale_scaling_resources_for_bundle(
    bundle: dict[str, any], namespace: str, autoscaler: any, keda: KEDAAutoscaler
) {
    scaling: dict[str, any] = bundle.get("scaling", {});
    for svc_name in scaling.keys() {
        plan: dict[str, any] = dict(scaling.get(svc_name, {}));
        mode = plan.get("mode");
        scale_target_name = str(plan.get("scale_target_name", ""));
        if mode != ScalingMode.METRIC {
            autoscaler.destroy(k8s_safe_name(svc_name), namespace);
        }
        if mode != ScalingMode.HTTP_ACTIVATION {
            destroy_http_activation_for_target(scale_target_name, namespace, keda);
        }
    }
}
