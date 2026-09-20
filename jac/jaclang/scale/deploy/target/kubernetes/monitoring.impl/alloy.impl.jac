impl MonitoringDeployer._deploy_alloy(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    loki_name = f"{app_name}-loki";
    alloy_name = f"{app_name}-alloy";
    loki_push_url = f"http://{loki_name}-service:3100/loki/api/v1/push";
    tempo_name = f"{app_name}-tempo";
    tempo_otlp_endpoint = f"{tempo_name}-service:4317";

    alloy_header = (
        "logging {\n" "  level  = \"info\"\n" "  format = \"logfmt\"\n" "}\n" "\n"
    );

    alloy_logs_lane = (
        "discovery.kubernetes \"pods\" {\n"
        "  role = \"pod\"\n"
        "}\n"
        "\n"
        "discovery.relabel \"pods\" {\n"
        "  targets = discovery.kubernetes.pods.targets\n"
        "\n"
        "  rule {\n"
        "    source_labels = [\"__meta_kubernetes_pod_node_name\"]\n"
        "    target_label  = \"__host__\"\n"
        "  }\n"
        "\n"
        "  rule {\n"
        "    action = \"labelmap\"\n"
        "    regex  = \"__meta_kubernetes_pod_label_(.+)\"\n"
        "  }\n"
        "\n"
        "  rule {\n"
        "    source_labels = [\"__meta_kubernetes_namespace\"]\n"
        "    target_label  = \"namespace\"\n"
        "  }\n"
        "\n"
        "  rule {\n"
        "    source_labels = [\"__meta_kubernetes_pod_name\"]\n"
        "    target_label  = \"pod\"\n"
        "  }\n"
        "\n"
        "  rule {\n"
        "    source_labels = [\"__meta_kubernetes_pod_container_name\"]\n"
        "    target_label  = \"container\"\n"
        "  }\n"
        "\n"
        "  rule {\n"
        "    action        = \"replace\"\n"
        "    separator     = \"/\"\n"
        "    source_labels = [\n"
        "      \"__meta_kubernetes_pod_uid\",\n"
        "      \"__meta_kubernetes_pod_container_name\",\n"
        "    ]\n"
        "    target_label = \"__path__\"\n"
        "    replacement  = \"/var/log/pods/*$1/*.log\"\n"
        "  }\n"
        "}\n"
        "\n"
        "local.file_match \"pods\" {\n"
        "  path_targets = discovery.relabel.pods.output\n"
        "}\n"
        "\n"
        "loki.source.file \"pods\" {\n"
        "  targets    = local.file_match.pods.targets\n"
        "  forward_to = [loki.process.cri.receiver]\n"
        "}\n"
        "\n"
        "loki.process \"cri\" {\n"
        "  forward_to = [loki.write.default.receiver]\n"
        "\n"
        "  // Strip the containerd CRI wrapper (timestamp + stream + tag\n"
        "  // + content). After this stage the line body is whatever the\n"
        "  // app wrote to stdout.\n"
        "  stage.cri {}\n"
        "\n"
        "  // Lift top-level keys out of structured-JSON log lines.\n"
        "  // Non-JSON lines fall through unmolested (variables stay unset).\n"
        "  stage.json {\n"
        "    expressions = {\n"
        "      ts       = \"ts\",\n"
        "      level    = \"level\",\n"
        "      service  = \"service\",\n"
        "      trace_id = \"trace_id\",\n"
        "    }\n"
        "  }\n"
        "\n"
        "  // Use the app-emitted timestamp when present (defends against\n"
        "  // node clock skew); lines without a valid ts keep the agent's.\n"
        "  stage.timestamp {\n"
        "    source            = \"ts\"\n"
        "    format            = \"RFC3339Nano\"\n"
        "    action_on_failure = \"skip\"\n"
        "  }\n"
        "\n"
        "  // Promote bounded-cardinality fields to Loki labels. trace_id\n"
        "  // is deliberately NOT a label (one stream per request); query\n"
        "  // it via `{namespace=ns} | json | trace_id=\"...\"`.\n"
        "  stage.labels {\n"
        "    values = {\n"
        "      service = \"\",\n"
        "      level   = \"\",\n"
        "    }\n"
        "  }\n"
        "}\n"
        "\n"
        "loki.write \"default\" {\n"
        "  endpoint {\n"
        f"    url = \"{loki_push_url}\"\n"
        "  }\n"
        "}\n"
    );

    if not self.k8s_config.loki_enabled {
        alloy_logs_lane = "";
    }

    alloy_otel_lane = "";
    if self.k8s_config.tracing_enabled {
        alloy_otel_lane = (
            "\n"
            "otelcol.receiver.otlp \"default\" {\n"
            "  grpc { endpoint = \"0.0.0.0:4317\" }\n"
            "  http { endpoint = \"0.0.0.0:4318\" }\n"
            "  output {\n"
            "    traces = [otelcol.processor.batch.default.input]\n"
            "  }\n"
            "}\n"
            "\n"
            "otelcol.processor.batch \"default\" {\n"
            "  output {\n"
            "    traces = [otelcol.exporter.otlp.tempo.input]\n"
            "  }\n"
            "}\n"
            "\n"
            "otelcol.exporter.otlp \"tempo\" {\n"
            "  client {\n"
            f"    endpoint = \"{tempo_otlp_endpoint}\"\n"
            "    tls { insecure = true }\n"
            "  }\n"
            "}\n"
        );
    }

    alloy_config_river = alloy_header + alloy_logs_lane + alloy_otel_lane;
    labels = app_labels(alloy_name);
    apply_config_map(
        core_v1,
        f"{alloy_name}-config",
        namespace,
        labels,
        {'config.alloy': alloy_config_river}
    );

    apply_cluster_rbac(
        core_v1,
        alloy_name,
        namespace,
        [
            {
                'apiGroups': [''],
                'resources': [
                    'nodes',
                    'nodes/proxy',
                    'pods',
                    'namespaces',
                    'services',
                    'endpoints'
                ],
                'verbs': ['get', 'watch', 'list']
            }
        ],
        replace=False
    );

    alloy_ports = [{'containerPort': 12345, 'name': 'http'}];
    if self.k8s_config.tracing_enabled {
        alloy_ports.append({'containerPort': 4317, 'name': 'otlp-grpc'});
        alloy_ports.append({'containerPort': 4318, 'name': 'otlp-http'});
    }

    alloy_daemonset = workload_manifest(
        "DaemonSet",
        alloy_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'alloy',
                    'image': 'grafana/alloy:v1.6.0',
                    'securityContext': {
                        'runAsUser': 0,
                        'allowPrivilegeEscalation': False,
                        'capabilities': {'drop': ['ALL']}
                    },
                    'args': [
                        'run',
                        '--server.http.listen-addr=0.0.0.0:12345',
                        '--storage.path=/tmp/alloy',
                        '/etc/alloy/config.alloy'
                    ],
                    'ports': alloy_ports,
                    'volumeMounts': [
                        {'name': 'alloy-config-vol', 'mountPath': '/etc/alloy'},
                        {
                            'name': 'varlogpods',
                            'mountPath': '/var/log/pods',
                            'readOnly': True
                        },
                        {
                            'name': 'varlogcontainers',
                            'mountPath': '/var/lib/docker/containers',
                            'readOnly': True
                        }
                    ]
                }
            ],
            [
                {
                    'name': 'alloy-config-vol',
                    'configMap': {'name': f"{alloy_name}-config"}
                },
                {'name': 'varlogpods', 'hostPath': {'path': '/var/log/pods'}},
                {
                    'name': 'varlogcontainers',
                    'hostPath': {'path': '/var/lib/docker/containers'}
                }
            ],
            service_account=f"{alloy_name}-sa",
            automount=True,
            tolerations=[{'operator': 'Exists', 'effect': 'NoSchedule'}]
        ),
        labels
    );
    apply_k8s_resource(
        apps_v1,
        "DaemonSet",
        alloy_name,
        alloy_daemonset,
        namespace=namespace,
        replace=False
    );

    if self.k8s_config.tracing_enabled {
        apply_service(
            core_v1,
            f"{alloy_name}-service",
            namespace,
            labels,
            [svc_port(4317, 'otlp-grpc'), svc_port(4318, 'otlp-http')]
        );
    }

    self._log(f"Alloy deployed for '{app_name}'");
}
