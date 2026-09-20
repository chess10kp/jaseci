impl KubernetesTarget._observability_requested -> bool {
    logs_cfg = self._read_gateway_logs_config();
    tracing_cfg = self._read_gateway_tracing_config();
    return bool(self.k8s_config.monitoring_enabled)
        or bool(logs_cfg.get("enabled", False))
        or bool(tracing_cfg.get("enabled", False));
}


impl KubernetesTarget._deploy_observability(app_name: str) -> None {
    if not self._observability_requested() {
        return;
    }

    self._load_cluster_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();

    provider = get_cluster_provider();

    obs_config = self._build_observability_config();

    self._ensure_privileged_namespace(core_v1, obs_config.namespace);
    if self.logger {
        self.logger.info(
            f"Deploying observability stack (Prometheus + Grafana + "
            f"Loki + Alloy) for '{app_name}'",
            {"namespace": obs_config.namespace, "provider": type(provider).__name__}
        );
    }
    monitoring = MonitoringDeployer(obs_config, self.logger);
    monitoring.deploy(
        app_name,
        obs_config.namespace,
        apps_v1,
        core_v1,
        provider,
        scrape_target_service="gateway-service"
    );
}


impl KubernetesTarget.ensure_alb_readiness_gates(core_v1: any, namespace: str) -> None {
    cfg = self.k8s_config;
    is_alb = bool(getattr(cfg, "shared_ingress", False))
        and str(getattr(cfg, "shared_ingress_class", "")).lower() == "alb";
    if not is_alb {
        return;
    }
    gate_label = "elbv2.k8s.aws/pod-readiness-gate-inject";
    try {
        ns = core_v1.read_namespace(name=namespace);
        labels: dict[str, any] = dict(getattr(ns.metadata, "labels", {}) or {});
        if labels.get(gate_label) == "enabled" {
            return;
        }
        core_v1.patch_namespace(
            name=namespace, body={"metadata": {"labels": {gate_label: "enabled"}}}
        );
        if self.logger {
            self.logger.info(
                f"Labeled namespace '{namespace}' for ALB pod readiness "
                f"gates: rollouts now wait for the new pod's ALB target to "
                f"pass health checks before retiring the old pod.",
                {"label": gate_label}
            );
        }
    } except Exception as e {
        if self.logger {
            self.logger.warn(
                f"Could not label namespace '{namespace}' for ALB pod "
                f"readiness gates ({e}); rollouts may briefly serve 502s "
                f"from the ALB while new targets pass health checks.",
                {"label": gate_label}
            );
        }
    }
}


impl KubernetesTarget._ensure_privileged_namespace(
    core_v1: any, namespace: str
) -> None {
    try {
        ns = core_v1.read_namespace(name=namespace);
        labels: dict[str, any] = dict(getattr(ns.metadata, "labels", {}) or {});
        new_labels = privileged_pss_labels(labels);
        if new_labels is None {
            if self.logger {
                current = labels.get(PSS_ENFORCE_LABEL, "");
                self.logger.warn(
                    f"namespace '{namespace}' has "
                    f"{PSS_ENFORCE_LABEL}={current} from outside jac-scale; "
                    f"hostPath DaemonSets (node-exporter, Alloy) may be "
                    f"rejected. Relabel manually with `kubectl label "
                    f"namespace {namespace} "
                    f"{PSS_ENFORCE_LABEL}=privileged "
                    f"--overwrite` if you want to enable them."
                );
            }
            return;
        }
        if not new_labels {
            return;
        }
        patch = {"metadata": {"labels": new_labels}};
        core_v1.patch_namespace(name=namespace, body=patch);
        if self.logger {
            self.logger.info(
                f"Labeled namespace '{namespace}' with "
                "pod-security.kubernetes.io/enforce=privileged "
                "(required for hostPath DaemonSets)"
            );
        }
    } except Exception as e {
        if self.logger {
            self.logger.warn(
                f"Could not label namespace '{namespace}' privileged - "
                f"hostPath DaemonSets may be rejected by PodSecurity. "
                f"Run `kubectl label namespace {namespace} "
                f"pod-security.kubernetes.io/enforce=privileged "
                f"--overwrite` manually. Cause: {e}"
            );
        }
    }
}


impl KubernetesTarget._build_observability_config -> KubernetesConfig {
    overrides: dict[str, any] = dict(self.k8s_config.to_dict());
    overrides["loki_enabled"] = self._read_gateway_logs_config().get("enabled", False);
    overrides["tracing_enabled"] = self._read_gateway_tracing_config().get(
        "enabled", False
    );
    return KubernetesConfig.from_dict(KubernetesConfig, overrides);
}


impl KubernetesTarget._read_gateway_logs_config -> dict[str, any] {
    return dict(self._gateway_cfg().get("logs", {}));
}


impl KubernetesTarget._read_gateway_tracing_config -> dict[str, any] {
    return dict(self._gateway_cfg().get("tracing", {}));
}
