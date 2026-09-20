impl MonitoringDeployer._deploy_grafana(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    grafana_name = f"{app_name}-grafana";
    prometheus_name = f"{app_name}-prometheus";
    grafana_secret_name = f"{grafana_name}-secret";
    labels = app_labels(grafana_name);

    apply_secret(
        core_v1,
        grafana_secret_name,
        namespace,
        labels,
        {
            'GF_SECURITY_ADMIN_USER': 'admin',
            'GF_SECURITY_ADMIN_PASSWORD': self.k8s_config.prometheus_admin_password
        },
        replace=False
    );

    prometheus_url = f"http://{prometheus_name}-service:9090";
    loki_name = f"{app_name}-loki";
    loki_url = f"http://{loki_name}-service:3100";
    datasource_yaml = (
        "apiVersion: 1\n"
        "datasources:\n"
        "  - name: Prometheus\n"
        "    uid: prometheus\n"
        "    type: prometheus\n"
        f"    url: {prometheus_url}\n"
        "    isDefault: true\n"
        "    access: proxy\n"
        "    editable: true\n"
    );
    if self.k8s_config.loki_enabled {
        datasource_yaml = datasource_yaml
            + (
                "  - name: Loki\n"
                "    uid: loki\n"
                "    type: loki\n"
                f"    url: {loki_url}\n"
                "    access: proxy\n"
                "    editable: true\n"
            );
    }

    if self.k8s_config.tracing_enabled {
        tempo_name = f"{app_name}-tempo";
        tempo_url = f"http://{tempo_name}-service:3200";
        tempo_ds = (
            "  - name: Tempo\n"
            "    uid: tempo\n"
            "    type: tempo\n"
            f"    url: {tempo_url}\n"
            "    access: proxy\n"
            "    editable: true\n"
            "    jsonData:\n"
            "      nodeGraph:\n"
            "        enabled: true\n"
        );
        if self.k8s_config.loki_enabled {
            tempo_ds = tempo_ds
                + (
                    "      tracesToLogsV2:\n"
                    "        datasourceUid: loki\n"
                    "        filterByTraceID: true\n"
                    "        spanStartTimeShift: \"-1h\"\n"
                    "        spanEndTimeShift: \"1h\"\n"
                );
        }
        datasource_yaml = datasource_yaml + tempo_ds;
    }
    apply_config_map(
        core_v1,
        f"{grafana_name}-datasources",
        namespace,
        labels,
        {'datasource.yaml': datasource_yaml}
    );

    dashboard_provider_yaml = (
        "apiVersion: 1\n"
        "providers:\n"
        "  - name: 'jac-scale'\n"
        "    orgId: 1\n"
        "    folder: 'Jac Scale'\n"
        "    type: file\n"
        "    disableDeletion: false\n"
        "    updateIntervalSeconds: 10\n"
        "    options:\n"
        "      path: /var/lib/grafana/dashboards\n"
    );
    apply_config_map(
        core_v1,
        f"{grafana_name}-dashboard-provider",
        namespace,
        labels,
        {'provider.yaml': dashboard_provider_yaml}
    );

    pfx = re.sub(r'[^a-zA-Z0-9]', '_', namespace);
    pfx = re.sub(r'_+', '_', pfx).strip('_');
    if pfx and pfx[0].isdigit() {
        pfx = f"_{pfx}";
    }
    ds = '{"type":"prometheus","uid":"prometheus"}';

    app_dashboard_json = (
        '{"title":"Jac Scale - App Metrics","uid":"jac-scale-app",'
        '"schemaVersion":36,"refresh":"10s","time":{"from":"now-1h","to":"now"},'
        '"panels":['
        '{"id":1,"type":"timeseries","title":"HTTP Request Rate (req/s)",'
        '"gridPos":{"x":0,"y":0,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"reqps"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (method,path)",'
        '"legendFormat":"{{method}} {{path}}",'
        f'"datasource":{ds}'
        + '}]},'
        '{"id":2,"type":"timeseries","title":"Error Rate (5xx req/s)",'
        '"gridPos":{"x":12,"y":0,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"reqps"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"sum(rate({pfx}_http_requests_total'
        + '{status_code=~\\"5..\\"}[1m]))",'
        '"legendFormat":"5xx errors",'
        f'"datasource":{ds}'
        + '}]},'
        '{"id":3,"type":"timeseries","title":"Request Latency p50/p95/p99",'
        '"gridPos":{"x":0,"y":8,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"s"}},'
        f'"datasource":{ds},'
        '"targets":['
        f'{{"refId":"A","expr":"histogram_quantile(0.50,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
        f'"legendFormat":"p50","datasource":{ds}'
        + '},'
        f'{{"refId":"B","expr":"histogram_quantile(0.95,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
        f'"legendFormat":"p95","datasource":{ds}'
        + '},'
        f'{{"refId":"C","expr":"histogram_quantile(0.99,rate({pfx}_http_request_duration_seconds_bucket[5m]))",'
        f'"legendFormat":"p99","datasource":{ds}'
        + '}]},'
        '{"id":4,"type":"stat","title":"Active Requests",'
        '"gridPos":{"x":12,"y":8,"w":6,"h":8},'
        f'"datasource":{ds},'
        f'"targets":[{{"refId":"A","expr":"{pfx}_http_requests_in_progress",'
        f'"legendFormat":"active","datasource":{ds}'
        + '}]},'
        '{"id":5,"type":"timeseries","title":"Requests by Status Code",'
        '"gridPos":{"x":0,"y":16,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"reqps"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (status_code)",'
        f'"legendFormat":"{{{{status_code}}}}","datasource":{ds}'
        + '}]},'
        '{"id":6,"type":"timeseries","title":"Requests by Path",'
        '"gridPos":{"x":12,"y":16,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"reqps"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"sum(rate({pfx}_http_requests_total[1m])) by (path)",'
        f'"legendFormat":"{{{{path}}}}","datasource":{ds}'
        + '}]},'
        '{"id":7,"type":"timeseries","title":"p95 Latency by Path",'
        '"gridPos":{"x":0,"y":24,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"s"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,path))",'
        f'"legendFormat":"{{{{path}}}}","datasource":{ds}'
        + '}]},'
        '{"id":8,"type":"timeseries","title":"p95 Latency by Method",'
        '"gridPos":{"x":12,"y":24,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"s"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"histogram_quantile(0.95,sum(rate({pfx}_http_request_duration_seconds_bucket[5m])) by (le,method))",'
        f'"legendFormat":"{{{{method}}}}","datasource":{ds}'
        + '}]},'
        '{"id":9,"type":"timeseries","title":"Average Request Duration",'
        '"gridPos":{"x":0,"y":32,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"s"}},'
        f'"datasource":{ds},'
        f'"expr":"rate({pfx}_http_request_duration_seconds_sum[5m]) / rate({pfx}_http_request_duration_seconds_count[5m])",'
        f'"legendFormat":"avg latency","datasource":{ds}'
        + '}]},'
        '{"id":10,"type":"timeseries","title":"Average Latency per Path",'
        '"gridPos":{"x":12,"y":32,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"s"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        f'"expr":"sum(rate({pfx}_http_request_duration_seconds_sum[5m])) by (path) / sum(rate({pfx}_http_request_duration_seconds_count[5m])) by (path)",'
        f'"legendFormat":"{{{{path}}}}","datasource":{ds}'
        + '}]},'
        '{"id":11,"type":"heatmap","title":"Request Duration Heatmap",'
        '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
        f'"datasource":{ds},'
        '"options":{"calculate":false,"yAxis":{"unit":"s"}},'
        '"targets":[{"refId":"A",'
        f'"expr":"sum(increase({pfx}_http_request_duration_seconds_bucket[1m])) by (le)",'
        '"format":"heatmap",'
        f'"legendFormat":"{{{{le}}}}","datasource":{ds}'
        + '}]}' ']}'
    );

    k8s_dashboard_json = (
        '{"title":"Kubernetes Cluster Metrics","uid":"k8s-cluster",'
        '"schemaVersion":36,"refresh":"30s","time":{"from":"now-1h","to":"now"},'
        '"panels":['
        '{"id":1,"type":"timeseries","title":"Node CPU Usage (%)",'
        '"gridPos":{"x":0,"y":0,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"(1 - avg(rate(node_cpu_seconds_total'
        + '{mode=\\"idle\\"}[5m])) by (instance)) * 100",'
        f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
        + '}]},'
        '{"id":2,"type":"timeseries","title":"Node Memory Usage (%)",'
        '"gridPos":{"x":12,"y":0,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",'
        f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
        + '}]},'
        '{"id":3,"type":"stat","title":"Running Pods",'
        '"gridPos":{"x":0,"y":8,"w":6,"h":4},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_pod_status_phase'
        + '{phase=\\"Running\\"} == 1) or vector(0)",'
        f'"legendFormat":"Running","datasource":{ds}'
        + '}]},'
        '{"id":4,"type":"stat","title":"Pending Pods",'
        '"gridPos":{"x":6,"y":8,"w":6,"h":4},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_pod_status_phase'
        + '{phase=\\"Pending\\"} == 1) or vector(0)",'
        f'"legendFormat":"Pending","datasource":{ds}'
        + '}]},'
        '{"id":5,"type":"stat","title":"Failed Pods",'
        '"gridPos":{"x":12,"y":8,"w":6,"h":4},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_pod_status_phase'
        + '{phase=\\"Failed\\"} == 1) or vector(0)",'
        f'"legendFormat":"Failed","datasource":{ds}'
        + '}]},'
        '{"id":6,"type":"timeseries","title":"Deployment Available Replicas",'
        '"gridPos":{"x":0,"y":12,"w":12,"h":8},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"kube_deployment_status_replicas_available",'
        f'"legendFormat":"{{{{deployment}}}}","datasource":{ds}'
        + '}]},'
        '{"id":7,"type":"timeseries","title":"Pod Container Restarts (last 1h)",'
        '"gridPos":{"x":12,"y":12,"w":12,"h":8},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"sum(increase(kube_pod_container_status_restarts_total[1h])) by (pod) > 0",'
        f'"legendFormat":"{{{{pod}}}}","datasource":{ds}'
        + '}]},'
        '{"id":8,"type":"timeseries","title":"Node Disk Read/Write (Bps)",'
        '"gridPos":{"x":0,"y":20,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"Bps"}},'
        f'"datasource":{ds},'
        '"targets":['
        '{"refId":"A",'
        '"expr":"sum(rate(node_disk_read_bytes_total[5m])) by (instance)",'
        f'"legendFormat":"{{{{instance}}}} read","datasource":{ds}'
        + '},'
        '{"refId":"B",'
        '"expr":"sum(rate(node_disk_written_bytes_total[5m])) by (instance)",'
        f'"legendFormat":"{{{{instance}}}} write","datasource":{ds}'
        + '}]},'
        '{"id":9,"type":"timeseries","title":"Node Network Receive/Transmit (Bps)",'
        '"gridPos":{"x":12,"y":20,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"Bps"}},'
        f'"datasource":{ds},'
        '"targets":['
        '{"refId":"A",'
        '"expr":"sum(rate(node_network_receive_bytes_total[5m])) by (instance)",'
        f'"legendFormat":"{{{{instance}}}} rx","datasource":{ds}'
        + '},'
        '{"refId":"B",'
        '"expr":"sum(rate(node_network_transmit_bytes_total[5m])) by (instance)",'
        f'"legendFormat":"{{{{instance}}}} tx","datasource":{ds}'
        + '}]},'
        '{"id":10,"type":"timeseries","title":"Pod CPU Requests (cores)",'
        '"gridPos":{"x":0,"y":28,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"short"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"sum(kube_pod_container_resource_requests'
        + '{resource=\\"cpu\\"}) by (pod)",'
        f'"legendFormat":"{{{{pod}}}}","datasource":{ds}'
        + '}]},'
        '{"id":11,"type":"timeseries","title":"Pod Memory Requests (bytes)",'
        '"gridPos":{"x":12,"y":28,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"bytes"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"sum(kube_pod_container_resource_requests'
        + '{resource=\\"memory\\"}) by (pod)",'
        f'"legendFormat":"{{{{pod}}}}","datasource":{ds}'
        + '}]},'
        '{"id":12,"type":"stat","title":"Total Nodes",'
        '"gridPos":{"x":0,"y":36,"w":6,"h":4},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_node_info) or vector(0)",'
        f'"legendFormat":"nodes","datasource":{ds}'
        + '}]},'
        '{"id":13,"type":"stat","title":"Ready Nodes",'
        '"gridPos":{"x":6,"y":36,"w":6,"h":4},'
        '"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},'
        '"thresholds":{"steps":[{"color":"red","value":0},{"color":"green","value":1}]}}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_node_status_condition'
        + '{condition=\\"Ready\\",status=\\"true\\"} == 1) or vector(0)",'
        f'"legendFormat":"ready","datasource":{ds}'
        + '}]},'
        '{"id":14,"type":"stat","title":"Not-Ready Nodes",'
        '"gridPos":{"x":12,"y":36,"w":6,"h":4},'
        '"fieldConfig":{"defaults":{"color":{"mode":"thresholds"},'
        '"thresholds":{"steps":[{"color":"green","value":0},{"color":"red","value":1}]}}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_node_status_condition'
        + '{condition=\\"Ready\\",status=\\"false\\"} == 1) or vector(0)",'
        f'"legendFormat":"not-ready","datasource":{ds}'
        + '}]},'
        '{"id":15,"type":"timeseries","title":"Pods per Node",'
        '"gridPos":{"x":0,"y":40,"w":24,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"short"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"count(kube_pod_info'
        + '{node!=\\"\\"}) by (node)",'
        f'"legendFormat":"{{{{node}}}}","datasource":{ds}'
        + '}]},'
        '{"id":16,"type":"timeseries","title":"Node CPU Usage (%) per Node",'
        '"gridPos":{"x":0,"y":48,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"(1 - avg(rate(node_cpu_seconds_total'
        + '{mode=\\"idle\\"}[5m])) by (instance)) * 100",'
        f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
        + '}]},'
        '{"id":17,"type":"timeseries","title":"Node Memory Usage (%) per Node",'
        '"gridPos":{"x":12,"y":48,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"percent","min":0,"max":100}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"(1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes) * 100",'
        f'"legendFormat":"{{{{instance}}}}","datasource":{ds}'
        + '}]},'
        '{"id":18,"type":"timeseries","title":"CPU Requests per Node (cores)",'
        '"gridPos":{"x":0,"y":56,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"short"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"sum(kube_pod_container_resource_requests'
        + '{resource=\\"cpu\\"}) by (node)",'
        f'"legendFormat":"{{{{node}}}}","datasource":{ds}'
        + '}]},'
        '{"id":19,"type":"timeseries","title":"Memory Requests per Node (bytes)",'
        '"gridPos":{"x":12,"y":56,"w":12,"h":8},'
        '"fieldConfig":{"defaults":{"unit":"bytes"}},'
        f'"datasource":{ds},'
        '"targets":[{"refId":"A",'
        '"expr":"sum(kube_pod_container_resource_requests'
        + '{resource=\\"memory\\"}) by (node)",'
        f'"legendFormat":"{{{{node}}}}","datasource":{ds}'
        + '}]}' ']}'
    );

    lds = '{"type":"loki","uid":"loki"}';
    logs_dashboard_json = (
        '{"title":"Pod Logs","uid":"pod-logs",'
        '"schemaVersion":36,"refresh":"30s","time":{"from":"now-1h","to":"now"},'
        '"panels":['
        '{"id":1,"type":"timeseries","title":"Log Volume (lines/min)",'
        '"gridPos":{"x":0,"y":0,"w":24,"h":6},'
        '"fieldConfig":{"defaults":{"unit":"short"}},'
        f'"datasource":{lds},'
        '"targets":[{"refId":"A",'
        '"expr":"sum(count_over_time({namespace=~\\".+\\"}[1m])) by (namespace,pod)",'
        f'"legendFormat":"{{{{namespace}}}}/{{{{pod}}}}","datasource":{lds}'
        + '}]},'
        '{"id":2,"type":"logs","title":"All Pod Logs",'
        '"gridPos":{"x":0,"y":6,"w":24,"h":20},'
        f'"datasource":{lds},'
        '"options":{"dedupStrategy":"none","showLabels":true,'
        '"showCommonLabels":false,"wrapLogMessage":true,"sortOrder":"Descending"},'
        '"targets":[{"refId":"A",'
        '"expr":"{namespace=~\\".+\\"}",'
        f'"datasource":{lds}'
        + '}]}]}'
    );

    dashboard_data: dict[str, str] = {'jac-scale.json': app_dashboard_json};
    if self.k8s_config.k8s_metrics_enabled {
        dashboard_data['k8s-metrics.json'] = k8s_dashboard_json;
    }
    if self.k8s_config.loki_enabled {
        dashboard_data['pod-logs.json'] = logs_dashboard_json;
    }

    apply_config_map(
        core_v1, f"{grafana_name}-dashboard", namespace, labels, dashboard_data
    );

    grafana_sa_name = f"{grafana_name}-sa";
    apply_service_account(
        core_v1,
        grafana_sa_name,
        namespace,
        labels,
        {'automountServiceAccountToken': False}
    );

    grafana_deployment = workload_manifest(
        "Deployment",
        grafana_name,
        namespace,
        pod_spec(
            [
                {
                    'name': 'grafana',
                    'image': 'grafana/grafana:13.2.0',
                    'securityContext': restricted_container_security(472),
                    'ports': [{'containerPort': 3000}],
                    'envFrom': [{'secretRef': {'name': grafana_secret_name}}],
                    'env': [
                        {
                            'name': 'GF_SERVER_ROOT_URL',
                            'value': f"http://{self.k8s_config.domain}/grafana"
                                if self.k8s_config.domain
                                else '%(protocol)s://%(domain)s/grafana'
                        },
                        {'name': 'GF_SERVER_SERVE_FROM_SUB_PATH', 'value': 'true'}
                    ],
                    'volumeMounts': [
                        {
                            'name': 'grafana-datasources-vol',
                            'mountPath': '/etc/grafana/provisioning/datasources'
                        },
                        {
                            'name': 'grafana-dashboard-provider-vol',
                            'mountPath': '/etc/grafana/provisioning/dashboards'
                        },
                        {
                            'name': 'grafana-dashboard-vol',
                            'mountPath': '/var/lib/grafana/dashboards'
                        },
                        {'name': 'grafana-data', 'mountPath': '/var/lib/grafana'},
                        {'name': 'tmp', 'mountPath': '/tmp'}
                    ]
                }
            ],
            [
                {
                    'name': 'grafana-datasources-vol',
                    'configMap': {'name': f"{grafana_name}-datasources"}
                },
                {
                    'name': 'grafana-dashboard-provider-vol',
                    'configMap': {'name': f"{grafana_name}-dashboard-provider"}
                },
                {
                    'name': 'grafana-dashboard-vol',
                    'configMap': {'name': f"{grafana_name}-dashboard"}
                },
                {'name': 'grafana-data', 'emptyDir': {}},
                {'name': 'tmp', 'emptyDir': {}}
            ],
            service_account=grafana_sa_name,
            automount=False
        ),
        {'app': grafana_name}
    );
    patch_k8s_resource(apps_v1, "Deployment", grafana_deployment, namespace);

    apply_service(
        core_v1, f"{grafana_name}-service", namespace, labels, [svc_port(3000)]
    );

    self._log(
        f"Grafana deployed for '{app_name}' (ClusterIP service "
        f"{grafana_name}-service:3000; served at /grafana when the app "
        "ingress is deployed, otherwise reach it via kubectl port-forward)"
    );
}
