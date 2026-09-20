impl app_labels(app: str) -> dict[str, str] {
    return {'app': app, 'managed': MANAGED_LABEL};
}

impl managed_labels -> dict[str, str] {
    return {'managed': MANAGED_LABEL};
}

impl k8s_manifest(
    kind: str,
    name: str,
    fields: (dict[str, any] | None) = None,
    namespace: str = "",
    labels: (dict[str, str] | None) = None,
    annotations: (dict[str, str] | None) = None,
    api_version: str = ""
) -> dict[str, any] {
    metadata: dict[str, any] = {'name': name};
    if namespace {
        metadata['namespace'] = namespace;
    }
    if labels {
        metadata['labels'] = labels;
    }
    if annotations {
        metadata['annotations'] = annotations;
    }
    return {
        'apiVersion': api_version or KIND_API_VERSION[kind],
        'kind': kind,
        'metadata': metadata,
        ** (fields or {})
    };
}

impl pod_security_context -> dict[str, any] {
    return {'seccompProfile': {'type': 'RuntimeDefault'}};
}

impl restricted_container_security(uid: int) -> dict[str, any] {
    # PSS-restricted container securityContext shared by the monitoring stack.
    return {
        'runAsNonRoot': True,
        'runAsUser': uid,
        'readOnlyRootFilesystem': True,
        'allowPrivilegeEscalation': False,
        'capabilities': {'drop': ['ALL']}
    };
}

impl svc_port(port: int, name: str = "") -> dict[str, any] {
    p: dict[str, any] = {'protocol': 'TCP', 'port': port, 'targetPort': port};
    if name {
        p['name'] = name;
    }
    return p;
}

impl service_manifest(
    name: str, namespace: str, ports: list[dict[str, any]], labels: dict[str, str]
) -> dict[str, any] {
    return k8s_manifest(
        "Service",
        name,
        {
            'spec': {
                'type': 'ClusterIP',
                'selector': {'app': labels['app']},
                'ports': ports
            }
        },
        namespace,
        labels
    );
}

impl pod_spec(
    containers: list[dict[str, any]],
    volumes: (list[dict[str, any]] | None) = None,
    service_account: str = "",
    automount: (bool | None) = None,
    tolerations: (list[dict[str, any]] | None) = None
) -> dict[str, any] {
    spec: dict[str, any] = {
        'securityContext': pod_security_context(),
        'containers': containers
    };
    if service_account {
        spec['serviceAccountName'] = service_account;
    }
    if automount is not None {
        spec['automountServiceAccountToken'] = automount;
    }
    if volumes {
        spec['volumes'] = volumes;
    }
    if tolerations {
        spec['tolerations'] = tolerations;
    }
    return spec;
}

impl workload_manifest(
    kind: str,
    name: str,
    namespace: str,
    pod: dict[str, any],
    pod_labels: dict[str, str],
    annotations: (dict[str, str] | None) = None
) -> dict[str, any] {
    template_meta: dict[str, any] = {'labels': pod_labels};
    if annotations {
        template_meta['annotations'] = annotations;
    }
    spec: dict[str, any] = {
        'selector': {'matchLabels': {'app': name}},
        'template': {'metadata': template_meta, 'spec': pod}
    };
    if kind == 'Deployment' {
        spec = {'replicas': 1, ** spec};
    }
    return k8s_manifest(kind, name, {'spec': spec}, namespace, app_labels(name));
}
