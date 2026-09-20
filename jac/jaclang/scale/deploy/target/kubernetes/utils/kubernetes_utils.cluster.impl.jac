import from jaclang.cli.console { console }
import from jaclang.scale._optdeps.kubernetes { client }
import from jaclang.scale.deploy.target.kubernetes.cluster_provider {
    AWSProvider,
    ClusterProvider,
    LocalProvider
}

impl cluster_type -> str {
    try {
        v1 = client.CoreV1Api();
        nodes = v1.list_node();
        node_items: list[any] = nodes.items;
        if not node_items {
            return 'local';
        }
        for nd in node_items {
            provider_id: str = nd.spec.provider_id or '';
            if provider_id.startswith('aws://') {
                return 'aws';
            }
        }
        for nd in node_items {
            labels: dict[str, str] = nd.metadata.labels or {};
            if (
                ('topology.kubernetes.io/region' in labels)
                and any(
                    (region in labels.get('topology.kubernetes.io/region', ''))
                    for region in ['us-', 'eu-', 'ap-', 'ca-', 'sa-']
                )
                and (
                    ('karpenter.sh/provisioner-name' in labels)
                    or (
                        ('kubernetes.io/os' in labels)
                        and ('node.kubernetes.io/instance-type' in labels)
                    )
                )
            ) {
                return 'aws';
            }
        }
        return 'local';
    } except ApiException as exc {
        console.print(
            f"[warn] could not read cluster nodes to detect the provider "
            f"(HTTP {exc.status} {exc.reason}). {_LOCAL_FALLBACK_NOTE}"
        );
        return 'local';
    } except Exception as exc {
        console.print(
            f"[warn] provider detection failed "
            f"({type(exc).__name__}: {exc}). {_LOCAL_FALLBACK_NOTE}"
        );
        return 'local';
    }
}

impl get_cluster_provider -> ClusterProvider {
    if cluster_type() == 'aws' {
        return AWSProvider();
    }
    return LocalProvider();
}

impl _resolve_current_rs_hashes(namespace: str, selector: str) -> set {
    apps_v1 = client.AppsV1Api();
    rs_items: list[any] = apps_v1.list_namespaced_replica_set(
        namespace=namespace, label_selector=selector
    ).items;
    best: dict[str, tuple[int, any]] = {};
    for rs in rs_items {
        rs_labels: dict[str, str] = rs.metadata.labels or {};
        app_val = rs_labels.get("app", "");
        if not app_val {
            continue;
        }
        rs_annotations: dict[str, str] = rs.metadata.annotations or {};
        rev_str = rs_annotations.get("deployment.kubernetes.io/revision", "0");
        try {
            rev = int(rev_str);
        } except (ValueError, TypeError) {
            rev = 0;
        }
        prev = best.get(app_val);
        if prev is None or rev > prev[0] {
            best[app_val] = (rev, rs);
        }
    }
    pending: set[str] = set();
    for (_, rs) in best.values() {
        best_labels: dict[str, str] = rs.metadata.labels or {};
        h = best_labels.get("pod-template-hash");
        if h {
            pending.add(h);
        }
    }
    return pending;
}

impl _refresh_rs_hashes(
    namespace: str, selector: str, current: (set | None)
) -> (set | None) {
    try {
        return _resolve_current_rs_hashes(namespace, selector);
    } except Exception as exc {
        console.print(f"[warn] RS hash refresh failed, keeping prior hash set: {exc}");
        return current;
    }
}
