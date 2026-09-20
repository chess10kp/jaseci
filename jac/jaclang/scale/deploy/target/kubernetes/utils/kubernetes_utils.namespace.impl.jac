import from jaclang.cli.console { console }
import from jaclang.scale._optdeps.kubernetes { client }

impl delete_namespace(namespace: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        try {
            config.load_kube_config();
        } except ConfigException {
            config.load_incluster_config();
        }
        core_v1 = client.CoreV1Api();
        core_v1.delete_namespace(name=namespace);
        console.print(f"Namespace '{namespace}' deleted successfully.");
    } except ApiException as e {
        if (e.status == 404) {
            console.print(f"Namespace '{namespace}' not found, skipping deletion.");
        } else {
            raise;
        }
    }
}

impl default_pss_labels -> dict[str, str] {
    return {
        PSS_ENFORCE_LABEL: "baseline",
        PSS_WARN_LABEL: "restricted",
        PSS_SOURCE_LABEL: "baseline"
    };
}

impl privileged_pss_labels(existing: dict[str, str]) -> dict[str, str] | None {
    current = existing.get(PSS_ENFORCE_LABEL, "");
    if current == "privileged" {
        return {};
    }
    if current and current != existing.get(PSS_SOURCE_LABEL, "") {
        return None;
    }
    return {PSS_ENFORCE_LABEL: "privileged", PSS_SOURCE_LABEL: "privileged"};
}

impl ensure_namespace_exists(namespace: str, owner: str) -> None {
    if (namespace == 'default') {
        return;
    }
    try {
        core_v1 = client.CoreV1Api();
        existing_ns = core_v1.read_namespace(name=namespace);
        console.print(f"Namespace '{namespace}' already exists.");

        existing_labels: dict[str, any] = dict(
            getattr(existing_ns.metadata, "labels", {}) or {}
        );
        patch_labels: dict[str, any] = {};
        for (label, value) in default_pss_labels().items() {
            if not existing_labels.get(label) {
                patch_labels[label] = value;
            }
        }
        if patch_labels and not existing_labels.get(PSS_ENFORCE_LABEL) {
            patch_labels[PSS_SOURCE_LABEL] = "baseline";
        }
        if patch_labels {
            try {
                core_v1.patch_namespace(
                    name=namespace, body={'metadata': {'labels': patch_labels}}
                );
            } except ApiException as patch_err {
                console.print(
                    f"Warning: could not apply PSS labels to namespace '{namespace}': {patch_err}"
                );
            }
        }
    } except ApiException as e {
        if (e.status == 404) {
            console.print(f"Namespace '{namespace}' not found. Creating it...");
            create_labels: dict[str, any] = dict(default_pss_labels());
            if owner {
                create_labels[NAMESPACE_OWNER_LABEL] = owner;
            }
            core_v1.create_namespace(
                body={
                    'apiVersion': 'v1',
                    'kind': 'Namespace',
                    'metadata': {'name': namespace, 'labels': create_labels}
                }
            );
            console.print(f"Namespace '{namespace}' created successfully.");
        } else {
            raise;
        }
    }
}

impl namespace_is_owned(core_v1: client.CoreV1Api, namespace: str, owner: str) -> bool {
    if (namespace == 'default') or not owner {
        return False;
    }
    try {
        ns = core_v1.read_namespace(name=namespace);
    } except ApiException as e {
        if (e.status == 404) {
            return False;
        }
        raise;
    }
    labels: dict[str, any] = dict(getattr(ns.metadata, "labels", {}) or {});
    return labels.get(NAMESPACE_OWNER_LABEL) == owner;
}
