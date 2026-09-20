impl MonitoringDeployer._log(msg: str) {
    if self.logger {
        self.logger.info(msg);
    }
}


impl MonitoringDeployer._deploy_prometheus(
    app_name: str,
    namespace: str,
    apps_v1: any,
    core_v1: any,
    provider: ClusterProvider,
    scrape_target_service: str = ""
) {
    prometheus_name = f"{app_name}-prometheus";
    ksm_name = f"{app_name}-kube-state-metrics";
    ne_name = f"{app_name}-node-exporter";
    service_port = provider.prometheus_scrape_port(self.k8s_config.container_port);
    scrape_target = scrape_target_service or f"{app_name}-service";

    scrape_config = (
        "global:\n"
        "  scrape_interval: 15s\n"
        "  evaluation_interval: 15s\n"
        "scrape_configs:\n"
        f"  - job_name: '{app_name}'\n"
        "    static_configs:\n"
        f"      - targets: ['{scrape_target}:{service_port}']\n"
        "    metrics_path: '/metrics'\n"
        "    basic_auth:\n"
        f"      username: '{self.k8s_config.admin_username}'\n"
        "      password_file: /etc/prometheus/scrape-secret/password\n"
    );
    if self.k8s_config.k8s_metrics_enabled {
        scrape_config = scrape_config
            + (
                f"  - job_name: 'kube-state-metrics'\n"
                "    static_configs:\n"
                f"      - targets: ['{ksm_name}-service:8080']\n"
                "    metrics_path: '/metrics'\n"
                f"  - job_name: 'node-exporter'\n"
                "    static_configs:\n"
                f"      - targets: ['{ne_name}-service:9100']\n"
                "    metrics_path: '/metrics'\n"
            );

        scrape_config = scrape_config
            + (
                "  - job_name: 'kubernetes-cadvisor'\n"
                "    scheme: https\n"
                "    tls_config:\n"
                "      insecure_skip_verify: true\n"
                "    authorization:\n"
                "      credentials_file: /var/run/secrets/kubernetes.io/serviceaccount/token\n"
                "    kubernetes_sd_configs:\n"
                "      - role: node\n"
                "    relabel_configs:\n"
                "      - action: labelmap\n"
                "        regex: __meta_kubernetes_node_label_(.+)\n"
                "        target_label: __address__\n"
                "        replacement: kubernetes.default.svc:443\n"
                "      - source_labels: [__meta_kubernetes_node_name]\n"
                "        regex: (.+)\n"
                "        target_label: __metrics_path__\n"
                "        replacement: /api/v1/nodes/${1}/proxy/metrics/cadvisor\n"
            );
    }

    config_hash = hashlib.md5(scrape_config.encode()).hexdigest()[:12];
    labels = app_labels(prometheus_name);

    apply_config_map(
        core_v1,
        f"{prometheus_name}-config",
        namespace,
        labels,
        {'prometheus.yml': scrape_config}
    );
    apply_secret(
        core_v1,
        f"{prometheus_name}-scrape-secret",
        namespace,
        labels,
        {'password': self.k8s_config.prometheus_admin_password}
    );
    apply_cluster_rbac(
        core_v1,
        prometheus_name,
        namespace,
        [
            {
                'apiGroups': [''],
                'resources': [
                    'nodes',
                    'nodes/proxy',
                    'nodes/metrics',
                    'services',
                    'endpoints',
                    'pods'
                ],
                'verbs': ['get', 'list', 'watch']
            },
            {'nonResourceURLs': ['/metrics', '/metrics/cadvisor'], 'verbs': ['get']}
        ],
        sa_fields={'automountServiceAccountToken': True}
    );

    prometheus_deployment = workload_manifest(
        "Deployment",
        prometheus_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'prometheus',
                    'image': 'prom/prometheus:v3.14.0',
                    'securityContext': restricted_container_security(65534),
                    'args': [
                        '--config.file=/etc/prometheus/prometheus.yml',
                        '--storage.tsdb.path=/prometheus',
                        '--web.console.libraries=/usr/share/prometheus/console_libraries',
                        '--web.console.templates=/usr/share/prometheus/consoles',
                        '--web.enable-lifecycle'
                    ],
                    'ports': [{'containerPort': 9090}],
                    'volumeMounts': [
                        {
                            'name': 'prometheus-config-vol',
                            'mountPath': '/etc/prometheus'
                        },
                        {
                            'name': 'prometheus-scrape-secret',
                            'mountPath': '/etc/prometheus/scrape-secret',
                            'readOnly': True
                        },
                        {'name': 'prometheus-data', 'mountPath': '/prometheus'},
                        {'name': 'tmp', 'mountPath': '/tmp'}
                    ]
                }
            ],
            [
                {
                    'name': 'prometheus-config-vol',
                    'configMap': {'name': f"{prometheus_name}-config"}
                },
                {
                    'name': 'prometheus-scrape-secret',
                    'secret': {'secretName': f"{prometheus_name}-scrape-secret"}
                },
                {'name': 'prometheus-data', 'emptyDir': {}},
                {'name': 'tmp', 'emptyDir': {}}
            ],
            service_account=f"{prometheus_name}-sa",
            automount=True
        ),
        {'app': prometheus_name},
        {'checksum/config': config_hash}
    );
    patch_k8s_resource(apps_v1, "Deployment", prometheus_deployment, namespace);

    apply_service(
        core_v1, f"{prometheus_name}-service", namespace, labels, [svc_port(9090)]
    );

    self._log(f"Prometheus deployed for '{app_name}'");
}


impl MonitoringDeployer._deploy_kube_state_metrics(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    ksm_name = f"{app_name}-kube-state-metrics";
    labels = app_labels(ksm_name);

    apply_cluster_rbac(
        core_v1,
        ksm_name,
        namespace,
        [
            {
                'apiGroups': [''],
                'resources': [
                    'configmaps',
                    'secrets',
                    'nodes',
                    'pods',
                    'services',
                    'resourcequotas',
                    'replicationcontrollers',
                    'limitranges',
                    'persistentvolumeclaims',
                    'persistentvolumes',
                    'namespaces',
                    'endpoints'
                ],
                'verbs': ['list', 'watch']
            },
            {
                'apiGroups': ['apps'],
                'resources': [
                    'statefulsets',
                    'daemonsets',
                    'deployments',
                    'replicasets'
                ],
                'verbs': ['list', 'watch']
            },
            {
                'apiGroups': ['batch'],
                'resources': ['cronjobs', 'jobs'],
                'verbs': ['list', 'watch']
            },
            {
                'apiGroups': ['autoscaling'],
                'resources': ['horizontalpodautoscalers'],
                'verbs': ['list', 'watch']
            },
            {
                'apiGroups': ['policy'],
                'resources': ['poddisruptionbudgets'],
                'verbs': ['list', 'watch']
            },
            {
                'apiGroups': ['storage.k8s.io'],
                'resources': ['storageclasses', 'volumeattachments'],
                'verbs': ['list', 'watch']
            }
        ],
        replace=False
    );

    ksm_deployment = workload_manifest(
        "Deployment",
        ksm_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'kube-state-metrics',
                    'image': 'registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.10.1',
                    'securityContext': restricted_container_security(65534),
                    'ports': [
                        {'containerPort': 8080, 'name': 'http-metrics'},
                        {'containerPort': 8081, 'name': 'telemetry'}
                    ],
                    'readinessProbe': {
                        'httpGet': {'path': '/healthz', 'port': 8080},
                        'initialDelaySeconds': 5,
                        'timeoutSeconds': 5
                    },
                    'livenessProbe': {
                        'httpGet': {'path': '/healthz', 'port': 8080},
                        'initialDelaySeconds': 5,
                        'timeoutSeconds': 5
                    }
                }
            ],
            service_account=f"{ksm_name}-sa",
            automount=True
        ),
        labels
    );
    apply_k8s_resource(
        apps_v1,
        "Deployment",
        ksm_name,
        ksm_deployment,
        namespace=namespace,
        replace=False
    );

    apply_service(
        core_v1,
        f"{ksm_name}-service",
        namespace,
        labels,
        [svc_port(8080, 'http-metrics')]
    );

    self._log(f"kube-state-metrics deployed for '{app_name}'");
}


impl MonitoringDeployer._deploy_node_exporter(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    ne_name = f"{app_name}-node-exporter";

    ne_daemonset = workload_manifest(
        "DaemonSet",
        ne_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'node-exporter',
                    'image': 'prom/node-exporter:v1.10.2',
                    'securityContext': restricted_container_security(65534),
                    'args': ['--path.procfs=/host/proc', '--path.sysfs=/host/sys'],
                    'ports': [{'containerPort': 9100, 'name': 'metrics'}],
                    'volumeMounts': [
                        {'name': 'proc', 'mountPath': '/host/proc', 'readOnly': True},
                        {'name': 'sys', 'mountPath': '/host/sys', 'readOnly': True}
                    ]
                }
            ],
            [
                {'name': 'proc', 'hostPath': {'path': '/proc'}},
                {'name': 'sys', 'hostPath': {'path': '/sys'}}
            ],
            automount=False,
            tolerations=[{'operator': 'Exists', 'effect': 'NoSchedule'}]
        ),
        app_labels(ne_name)
    );
    apply_k8s_resource(
        apps_v1, "DaemonSet", ne_name, ne_daemonset, namespace=namespace, replace=False
    );

    apply_service(
        core_v1,
        f"{ne_name}-service",
        namespace,
        {'app': ne_name},
        [svc_port(9100, 'metrics')]
    );

    self._log(f"node-exporter deployed for '{app_name}'");
}
