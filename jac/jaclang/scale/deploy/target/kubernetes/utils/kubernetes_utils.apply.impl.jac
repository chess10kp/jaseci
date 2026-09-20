import from jaclang.scale._optdeps.kubernetes { client }

impl apply_service(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    ports: list[dict[str, any]]
) -> None {
    apply_k8s_resource(
        core_v1,
        "Service",
        name,
        service_manifest(name, namespace, ports, labels),
        namespace=namespace,
        replace=False
    );
}

impl apply_config_map(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    data: dict[str, str]
) -> None {
    apply_k8s_resource(
        core_v1,
        "ConfigMap",
        name,
        k8s_manifest("ConfigMap", name, {'data': data}, namespace, labels),
        namespace=namespace
    );
}

impl apply_secret(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    string_data: dict[str, str],
    replace: bool = True
) -> None {
    apply_k8s_resource(
        core_v1,
        "Secret",
        name,
        k8s_manifest(
            "Secret",
            name,
            {'type': 'Opaque', 'stringData': string_data},
            namespace,
            labels
        ),
        namespace=namespace,
        replace=replace
    );
}

impl apply_service_account(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    fields: (dict[str, any] | None) = None
) -> None {
    apply_k8s_resource(
        core_v1,
        "ServiceAccount",
        name,
        k8s_manifest("ServiceAccount", name, fields, namespace, labels),
        namespace=namespace,
        replace=False
    );
}

impl apply_cluster_rbac(
    core_v1: any,
    name: str,
    namespace: str,
    rules: list[dict[str, any]],
    sa_name: str = "",
    sa_fields: (dict[str, any] | None) = None,
    replace: bool = True
) -> None {
    sa_name = sa_name or f"{name}-sa";
    labels = app_labels(name);
    apply_service_account(core_v1, sa_name, namespace, labels, sa_fields);
    rbac_v1 = client.RbacAuthorizationV1Api();
    cr_name = f"{namespace}-{name}";
    apply_k8s_resource(
        rbac_v1,
        "ClusterRole",
        cr_name,
        k8s_manifest("ClusterRole", cr_name, {'rules': rules}, labels=labels),
        replace=replace
    );
    apply_k8s_resource(
        rbac_v1,
        "ClusterRoleBinding",
        cr_name,
        k8s_manifest(
            "ClusterRoleBinding",
            cr_name,
            {
                'roleRef': {
                    'apiGroup': 'rbac.authorization.k8s.io',
                    'kind': 'ClusterRole',
                    'name': cr_name
                },
                'subjects': [
                    {'kind': 'ServiceAccount', 'name': sa_name, 'namespace': namespace}
                ]
            },
            labels=labels
        ),
        replace=replace
    );
}
