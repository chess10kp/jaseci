impl MonitoringDeployer._deploy_loki(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    loki_name = f"{app_name}-loki";
    loki_sa_name = f"{loki_name}-sa";
    labels = app_labels(loki_name);

    loki_config_yaml = (
        "auth_enabled: false\n"
        "server:\n"
        "  http_listen_port: 3100\n"
        "  grpc_listen_port: 9096\n"
        "common:\n"
        "  path_prefix: /loki\n"
        "  storage:\n"
        "    filesystem:\n"
        "      chunks_directory: /loki/chunks\n"
        "      rules_directory: /loki/rules\n"
        "  replication_factor: 1\n"
        "  ring:\n"
        "    instance_addr: 127.0.0.1\n"
        "    kvstore:\n"
        "      store: inmemory\n"
        "schema_config:\n"
        "  configs:\n"
        "    - from: 2020-10-24\n"
        "      store: tsdb\n"
        "      object_store: filesystem\n"
        "      schema: v13\n"
        "      index:\n"
        "        prefix: index_\n"
        "        period: 24h\n"
        "limits_config:\n"
        "  reject_old_samples: true\n"
        "  reject_old_samples_max_age: 168h\n"
    );
    apply_config_map(
        core_v1,
        f"{loki_name}-config",
        namespace,
        labels,
        {'loki.yaml': loki_config_yaml}
    );

    apply_service_account(
        core_v1,
        loki_sa_name,
        namespace,
        labels,
        {'automountServiceAccountToken': False}
    );

    loki_deployment = workload_manifest(
        "Deployment",
        loki_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'loki',
                    'image': 'grafana/loki:3.4.2',
                    'securityContext': restricted_container_security(10001),
                    'args': ['-config.file=/etc/loki/loki.yaml'],
                    'ports': [{'containerPort': 3100, 'name': 'http'}],
                    'readinessProbe': {
                        'httpGet': {'path': '/ready', 'port': 3100},
                        'initialDelaySeconds': 15,
                        'timeoutSeconds': 5
                    },
                    'livenessProbe': {
                        'httpGet': {'path': '/ready', 'port': 3100},
                        'initialDelaySeconds': 15,
                        'timeoutSeconds': 5
                    },
                    'volumeMounts': [
                        {'name': 'loki-config-vol', 'mountPath': '/etc/loki'},
                        {'name': 'loki-data', 'mountPath': '/loki'},
                        {'name': 'tmp', 'mountPath': '/tmp'}
                    ]
                }
            ],
            [
                {
                    'name': 'loki-config-vol',
                    'configMap': {'name': f"{loki_name}-config"}
                },
                {'name': 'loki-data', 'emptyDir': {}},
                {'name': 'tmp', 'emptyDir': {}}
            ],
            service_account=loki_sa_name,
            automount=False
        ),
        {'app': loki_name}
    );
    patch_k8s_resource(apps_v1, "Deployment", loki_deployment, namespace);

    apply_service(core_v1, f"{loki_name}-service", namespace, labels, [svc_port(3100)]);

    self._log(f"Loki deployed for '{app_name}'");
}
