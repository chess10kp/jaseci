import re;
import from jaclang.scale._optdeps.kubernetes { client }

def _kind_stem(kind: str) -> str {
    # "ClusterRoleBinding" -> "cluster_role_binding", the method-name stem
    # the python k8s client uses for every verb.
    return re.sub(r'(?<!^)(?=[A-Z])', '_', kind).lower();
}

def _ns_kwarg(namespace: (str | None)) -> dict[str, any] {
    return {"namespace": namespace} if namespace else {};
}

impl apply_k8s_resource(
    api: any,
    kind: str,
    name: str,
    body: dict[str, any],
    namespace: (str | None) = None,
    replace: bool = True
) -> None {
    # kubectl-apply semantics for the python k8s client: read the resource,
    # replace its manifest when present, create it on 404. `kind` is the
    # CamelCase resource kind ("ConfigMap", "ClusterRole", ...); namespaced
    # resources pass `namespace`, cluster-scoped leave it None.
    # `replace=False` makes this create-only for resources k8s forbids
    # updating in place (services, PVCs, service accounts).
    stem = ("namespaced_" + _kind_stem(kind)) if namespace else _kind_stem(kind);
    ns_kw = _ns_kwarg(namespace);
    try {
        getattr(api, "read_" + stem)(name=name, **ns_kw);
        if replace {
            getattr(api, "replace_" + stem)(name=name, body=body, **ns_kw);
        }
    } except ApiException as e {
        if e.status == 404 {
            getattr(api, "create_" + stem)(body=body, **ns_kw);
        } else {
            raise;
        }
    }
}

impl patch_k8s_resource(
    api: any,
    kind: str,
    manifest: dict[str, any],
    namespace: (str | None) = None,
    patch_body: (dict[str, any] | None) = None
) -> None {
    # Strategic-merge PATCH variant of apply_k8s_resource: a missing resource
    # is created. `patch_body`, when given, is what gets PATCHed while `manifest`
    # is what gets CREATEd -- e.g. a copy with `spec.replicas` stripped so the
    # patch leaves an externally-scaled field (KEDA's ScaledObject) alone.
    stem = ("namespaced_" + _kind_stem(kind)) if namespace else _kind_stem(kind);
    ns_kw = _ns_kwarg(namespace);
    name = manifest["metadata"]["name"];
    try {
        getattr(api, "patch_" + stem)(name=name, body=patch_body or manifest, **ns_kw);
    } except ApiException as e {
        if e.status == 404 {
            getattr(api, "create_" + stem)(body=manifest, **ns_kw);
        } else {
            raise;
        }
    }
}

impl delete_resource(api: any, kind: str, name: str, namespace: str = "") -> None {
    stem = ("namespaced_" + _kind_stem(kind)) if namespace else _kind_stem(kind);
    try {
        if namespace {
            getattr(api, "delete_" + stem)(name, namespace);
        } else {
            getattr(api, "delete_" + stem)(name);
        }
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }
}

impl delete_collection_if_exists(
    delete_func: Callable, namespace: str, selector: str
) -> None {
    try {
        delete_func(namespace=namespace, label_selector=selector);
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }
}

impl create_k8s_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str]
) -> str {
    if not secret_data {
        return "";
    }
    secret_body = {
        'apiVersion': 'v1',
        'kind': 'Secret',
        'metadata': {
            'name': secret_name,
            'namespace': namespace,
            'labels': {'managed': 'jac-scale'}
        },
        'type': 'Opaque',
        'stringData': secret_data
    };
    applied: any = None;
    try {
        applied = core_v1.create_namespaced_secret(
            namespace=namespace, body=secret_body
        );
    } except ApiException as e {
        if e.status == 409 {
            applied = core_v1.replace_namespaced_secret(
                name=secret_name, namespace=namespace, body=secret_body
            );
        } else {
            raise;
        }
    }
    return str(applied.metadata.resource_version or "") if applied else "";
}

impl delete_k8s_secret(
    core_v1: client.CoreV1Api, namespace: str, secret_name: str
) -> None {
    try {
        core_v1.delete_namespaced_secret(name=secret_name, namespace=namespace);
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }
}
