impl MonitoringDeployer._deploy_tempo(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    tempo_name = f"{app_name}-tempo";
    tempo_sa_name = f"{tempo_name}-sa";
    labels = app_labels(tempo_name);

    tempo_config_yaml = (
        "server:\n"
        "  http_listen_port: 3200\n"
        "distributor:\n"
        "  receivers:\n"
        "    otlp:\n"
        "      protocols:\n"
        "        grpc:\n"
        "          endpoint: 0.0.0.0:4317\n"
        "        http:\n"
        "          endpoint: 0.0.0.0:4318\n"
        "ingester:\n"
        "  trace_idle_period: 10s\n"
        "  max_block_duration: 5m\n"
        "compactor:\n"
        "  compaction:\n"
        "    block_retention: 48h\n"
        "storage:\n"
        "  trace:\n"
        "    backend: local\n"
        "    local:\n"
        "      path: /var/tempo/blocks\n"
        "    wal:\n"
        "      path: /var/tempo/wal\n"
        "usage_report:\n"
        "  reporting_enabled: false\n"
    );
    apply_config_map(
        core_v1,
        f"{tempo_name}-config",
        namespace,
        labels,
        {'tempo.yaml': tempo_config_yaml}
    );

    apply_service_account(
        core_v1,
        tempo_sa_name,
        namespace,
        labels,
        {'automountServiceAccountToken': False}
    );

    tempo_deployment = workload_manifest(
        "Deployment",
        tempo_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'tempo',
                    'image': 'grafana/tempo:2.7.0',
                    'securityContext': restricted_container_security(10001),
                    'args': ['-config.file=/etc/tempo/tempo.yaml'],
                    'ports': [
                        {'containerPort': 3200, 'name': 'http'},
                        {'containerPort': 4317, 'name': 'otlp-grpc'},
                        {'containerPort': 4318, 'name': 'otlp-http'}
                    ],
                    'readinessProbe': {
                        'httpGet': {'path': '/ready', 'port': 3200},
                        'initialDelaySeconds': 15,
                        'timeoutSeconds': 5
                    },
                    'livenessProbe': {
                        'httpGet': {'path': '/ready', 'port': 3200},
                        'initialDelaySeconds': 15,
                        'timeoutSeconds': 5
                    },
                    'volumeMounts': [
                        {'name': 'tempo-config-vol', 'mountPath': '/etc/tempo'},
                        {'name': 'tempo-data', 'mountPath': '/var/tempo'},
                        {'name': 'tmp', 'mountPath': '/tmp'}
                    ]
                }
            ],
            [
                {
                    'name': 'tempo-config-vol',
                    'configMap': {'name': f"{tempo_name}-config"}
                },
                {'name': 'tempo-data', 'emptyDir': {}},
                {'name': 'tmp', 'emptyDir': {}}
            ],
            service_account=tempo_sa_name,
            automount=False
        ),
        {'app': tempo_name}
    );
    patch_k8s_resource(apps_v1, "Deployment", tempo_deployment, namespace);

    apply_service(
        core_v1,
        f"{tempo_name}-service",
        namespace,
        labels,
        [
            svc_port(3200, 'http'),
            svc_port(4317, 'otlp-grpc'),
            svc_port(4318, 'otlp-http')
        ]
    );

    self._log(f"Tempo deployed for '{app_name}'");
}
