impl MonitoringDeployer.deploy(
    app_name: str,
    namespace: str,
    apps_v1: any,
    core_v1: any,
    provider: ClusterProvider,
    scrape_target_service: str = ""
) {
    if self.k8s_config.monitoring_enabled {
        if self.k8s_config.k8s_metrics_enabled {
            self._deploy_kube_state_metrics(app_name, namespace, apps_v1, core_v1);
            self._deploy_node_exporter(app_name, namespace, apps_v1, core_v1);
        }
        self._deploy_prometheus(
            app_name, namespace, apps_v1, core_v1, provider, scrape_target_service
        );
    }
    if self.k8s_config.tracing_enabled {
        self._deploy_tempo(app_name, namespace, apps_v1, core_v1);
    }
    if self.k8s_config.loki_enabled {
        self._deploy_loki(app_name, namespace, apps_v1, core_v1);
    }

    if self.k8s_config.loki_enabled or self.k8s_config.tracing_enabled {
        self._deploy_alloy(app_name, namespace, apps_v1, core_v1);
    }
    if self.k8s_config.monitoring_enabled
        or self.k8s_config.loki_enabled
        or self.k8s_config.tracing_enabled {
        self._deploy_grafana(app_name, namespace, apps_v1, core_v1);
    }
}


impl MonitoringDeployer.destroy(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    components = [
        f"{app_name}-prometheus",
        f"{app_name}-kube-state-metrics",
        f"{app_name}-node-exporter",
        f"{app_name}-loki",
        f"{app_name}-alloy",
        f"{app_name}-tempo",
        f"{app_name}-grafana"
    ];
    for (api, kind, name) in [
        (apps_v1, 'Deployment', components[0]),
        (core_v1, 'Service', f"{components[0]}-service"),
        (core_v1, 'ConfigMap', f"{components[0]}-config"),
        (core_v1, 'Secret', f"{components[0]}-scrape-secret"),
        (core_v1, 'ServiceAccount', f"{components[0]}-sa"),
        (apps_v1, 'Deployment', components[1]),
        (core_v1, 'Service', f"{components[1]}-service"),
        (core_v1, 'ServiceAccount', f"{components[1]}-sa"),
        (apps_v1, 'DaemonSet', components[2]),
        (core_v1, 'Service', f"{components[2]}-service"),
        (apps_v1, 'Deployment', components[3]),
        (core_v1, 'Service', f"{components[3]}-service"),
        (core_v1, 'ConfigMap', f"{components[3]}-config"),
        (core_v1, 'ServiceAccount', f"{components[3]}-sa"),
        (apps_v1, 'DaemonSet', components[4]),
        (core_v1, 'ConfigMap', f"{components[4]}-config"),
        (core_v1, 'ServiceAccount', f"{components[4]}-sa"),
        (core_v1, 'Service', f"{components[4]}-service"),
        (apps_v1, 'Deployment', components[5]),
        (core_v1, 'Service', f"{components[5]}-service"),
        (core_v1, 'ConfigMap', f"{components[5]}-config"),
        (core_v1, 'ServiceAccount', f"{components[5]}-sa"),
        (apps_v1, 'Deployment', components[6]),
        (core_v1, 'Service', f"{components[6]}-service"),
        (core_v1, 'ConfigMap', f"{components[6]}-datasources"),
        (core_v1, 'ConfigMap', f"{components[6]}-dashboard-provider"),
        (core_v1, 'ConfigMap', f"{components[6]}-dashboard"),
        (core_v1, 'Secret', f"{components[6]}-secret"),
        (core_v1, 'ServiceAccount', f"{components[6]}-sa")
    ] {
        delete_resource(api, kind, name, namespace);
    }

    rbac_v1 = client.RbacAuthorizationV1Api();
    for name in [components[1], components[0], components[4]] {
        cr_name = f"{namespace}-{name}";
        delete_resource(rbac_v1, 'ClusterRole', cr_name);
        delete_resource(rbac_v1, 'ClusterRoleBinding', cr_name);
    }

    self._log(f"Monitoring stack destroyed for '{app_name}'");
}
