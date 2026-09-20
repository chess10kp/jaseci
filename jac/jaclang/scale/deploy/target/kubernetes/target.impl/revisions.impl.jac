impl _revision_sort_key(item: dict[str, any]) -> int {
    return int(item.get("revision", 0));
}


impl fleet_revert_order(names: list[str]) -> list[str] {
    gateway = f"{k8s_safe_name(GATEWAY_NAME)}-deployment";
    services: list[str] = [];
    has_gateway = False;
    for name in sorted(set(names)) {
        if str(name) == gateway {
            has_gateway = True;
        } else {
            services.append(str(name));
        }
    }
    return services + ([gateway] if has_gateway else []);
}


impl app_bundle_digest(bundle_keys: list[str]) -> str {
    for key in bundle_keys {
        text = str(key);
        if text.startswith("bundles/") and text.endswith(".jab") {
            return text.rsplit("/", 1)[-1][:-len(".jab")];
        }
    }
    return "";
}


impl releases_from_revisions(entries: list[dict[str, any]]) -> list[dict[str, any]] {
    by_digest: dict[str, dict[str, any]] = {};
    for item in entries {
        digest = str(item.get("bundle_digest", "") or "");
        if not digest {
            continue;
        }
        name = str(item.get("deployment", "") or "");
        revision = int(item.get("revision", 0) or 0);
        if digest not in by_digest {
            by_digest[digest] = {
                "bundle_digest": digest,
                "revision": revision,
                "created": str(item.get("created", "") or ""),
                "deployments": {}
            };
        }
        release = by_digest[digest];
        if revision > int(release["deployments"].get(name, 0) or 0) {
            release["deployments"][name] = revision;
        }
        if revision > int(release["revision"]) {
            release["revision"] = revision;
            release["created"] = str(item.get("created", "") or "");
        }
    }
    return sorted(by_digest.values(), key=_revision_sort_key, reverse=True);
}


impl fleet_targets_for_release(
    releases: list[dict[str, any]], revision: int, expected: list[str]
) -> dict[str, any] {
    for release in releases {
        if int(release.get("revision", 0) or 0) != int(revision) {
            continue;
        }
        held = dict(release.get("deployments", {}) or {});
        missing = [
            name
            for name in expected
            if name not in held
        ];
        if missing {
            return {"ok": False, "missing": sorted(missing), "targets": {}};
        }
        return {"ok": True, "missing": [], "targets": held};
    }
    return {"ok": False, "missing": list(expected), "targets": {}};
}


impl restorable_pod_template(template: dict[str, any]) -> dict[str, any] {
    cleaned = dict(template);
    metadata = dict(cleaned.get("metadata") or {});
    labels = dict(metadata.get("labels") or {});
    labels.pop("pod-template-hash", None);
    annotations = dict(metadata.get("annotations") or {});
    annotations.pop(CONFIG_REVISION_ANNOTATION, None);
    metadata["labels"] = labels;
    if annotations {
        metadata["annotations"] = annotations;
    } else {
        metadata.pop("annotations", None);
    }
    cleaned["metadata"] = metadata;
    return cleaned;
}


impl KubernetesTarget.reap_superseded_deployments(
    apps_v1: any, namespace: str, bundle: dict[str, any]
) {
    applied: dict[str, str] = {};
    for dep in bundle.get("deployments", {}).values() {
        try {
            selector = str(dep["spec"]["selector"]["matchLabels"]["app"]);
            applied[selector] = str(dep["metadata"]["name"]);
        } except Exception {
            continue;
        }
    }
    if not applied {
        return;
    }

    try {
        existing = apps_v1.list_namespaced_deployment(namespace=namespace).items;
    } except Exception as e {
        if self.logger {
            self.logger.warn(
                f"Could not list Deployments to reap superseded ones: {e}",
                {"namespace": namespace}
            );
        }
        return;
    }

    for dep in existing {
        try {
            name = str(dep.metadata.name);
            labels = dict(dep.metadata.labels or {});
            selector = str((dep.spec.selector.match_labels or {}).get("app", ""));
        } except Exception {
            continue;
        }
        if labels.get("managed") != "jac-scale" {
            continue;
        }
        current = applied.get(selector);
        if current is None or current == name {
            continue;
        }
        delete_resource(apps_v1, "Deployment", name, namespace);
        self._emit(
            "apply",
            "ok",
            f"Removed superseded Deployment '{name}'",
            detail={"superseded_by": current, "selector": selector}
        );
        if self.logger {
            self.logger.info(
                f"Removed superseded Deployment '{name}'; '{current}' now "
                f"solely backs the 'app={selector}' Service",
                {"namespace": namespace}
            );
        }
    }
}


impl KubernetesTarget._fleet_deployment_names(
    apps_v1: any, namespace: str
) -> list[str] {
    names: list[str] = [];
    try {
        listed = apps_v1.list_namespaced_deployment(
            namespace=namespace, label_selector=FLEET_SELECTOR
        );
        dep_items: list[any] = list(listed?.items or []);
        for dep in dep_items {
            try {
                names.append(str(dep.metadata.name));
            } except Exception {
                continue;
            }
        }
    } except Exception {
        return [];
    }
    return fleet_revert_order(names);
}


impl KubernetesTarget._owned_replica_sets(
    apps_v1: any, namespace: str, strict: bool = False
) -> list[any] {
    owned: list[str] = self._fleet_deployment_names(apps_v1, namespace);
    try {
        listed = list(
            apps_v1.list_namespaced_replica_set(
                namespace=namespace, label_selector="managed=jac-scale"
            ).items
        );
        scoped: list[any] = [];
        for rs in listed {
            rs_any: any = rs;
            try {
                owners = list(rs_any.metadata.owner_references or []);
            } except Exception {
                continue;
            }
            if owners and str(owners[0].name) in owned {
                scoped.append(rs_any);
            }
        }
        return scoped;
    } except Exception as e {
        if strict {
            raise;
        }
        if self.logger {
            self.logger.warn(
                f"Could not list ReplicaSets: {e}", {"namespace": namespace}
            );
        }
        return [];
    }
}


impl KubernetesTarget._revision_entries(strict: bool = False) -> list[dict[str, any]] {
    self._load_cluster_config();
    apps_v1 = client.AppsV1Api();
    namespace: str = self.k8s_config.namespace;
    serializer = client.ApiClient();
    revisions: list[dict[str, any]] = [];

    for rs in self._owned_replica_sets(apps_v1, namespace, strict=strict) {
        try {
            annotations = dict(rs.metadata.annotations or {});
            raw_revision = annotations.get(REVISION_ANNOTATION);
            if raw_revision is None {
                continue;
            }
            owners = list(rs.metadata.owner_references or []);
            deployment = str(owners[0].name) if owners else "";
            pod_spec = serializer.sanitize_for_serialization(rs.spec.template.spec);
            created = rs.metadata.creation_timestamp;
            revisions.append(
                {
                    "deployment": deployment,
                    "revision": int(raw_revision),
                    "replica_set": str(rs.metadata.name),
                    "bundle_keys": bundle_keys_from_pod_spec(dict(pod_spec)),
                    "bundle_digest": app_bundle_digest(
                        bundle_keys_from_pod_spec(dict(pod_spec))
                    ),
                    "created": created.isoformat() if created else "",
                    "replicas": int(rs.spec.replicas or 0)
                }
            );
        } except Exception {
            continue;
        }
    }
    return revisions;
}


impl KubernetesTarget._assert_own_app(app_name: str) {
    mine = str(self.k8s_config.app_name or "");
    if app_name and mine and str(app_name) != mine {
        detail = f"configured for '{mine}', asked about '{app_name}'";
        raise ValueError(
            "This target cannot report or revert another app's revisions "
                + f"({detail}). Build a target for that app."
        );
    }
}


impl KubernetesTarget.list_revisions(app_name: str) -> list[dict[str, any]] {
    self._assert_own_app(app_name);
    return releases_from_revisions(self._revision_entries());
}


impl KubernetesTarget.referenced_bundle_keys(app_name: str) -> set[str] {
    self._assert_own_app(app_name);
    keys: set[str] = set();
    for item in self._revision_entries(strict=True) {
        for key in item.get("bundle_keys", []) {
            keys.add(str(key));
        }
    }
    return keys;
}


impl KubernetesTarget._restore_templates(
    apps_v1: any, namespace: str, names: list[str], undo: dict[str, any]
) -> list[str] {
    stranded: list[str] = [];
    for name in reversed(names) {
        template = undo.get(name);
        if template is None {
            continue;
        }
        try {
            apps_v1.patch_namespaced_deployment(
                name=name,
                namespace=namespace,
                body=[{"op": "replace", "path": "/spec/template", "value": template}]
            );
        } except Exception {
            stranded.append(name);
        }
    }
    return stranded;
}


impl KubernetesTarget.rollback_to(app_name: str, revision: int) -> DeploymentResult {
    self._assert_own_app(app_name);
    self._load_cluster_config();
    apps_v1 = client.AppsV1Api();
    namespace: str = self.k8s_config.namespace;
    serializer = client.ApiClient();

    expected: list[str] = self._fleet_deployment_names(apps_v1, namespace);
    resolved = fleet_targets_for_release(
        self.list_revisions(app_name), revision, expected
    );
    if not resolved.get("ok", False) {
        missing = list(resolved.get("missing", []));
        return DeploymentResult(
            success=False,
            message=(
                f"Cannot roll '{app_name}' back to revision {revision} in "
                f"'{namespace}': no retained revision for "
                f"{', '.join(missing)}. It is older than "
                f"revision_history_limit "
                f"({self.k8s_config.revision_history_limit}), was never "
                "deployed, or the service set changed between releases."
            ),
            details={"missing": missing}
        );
    }

    wanted: dict[str, any] = dict(resolved.get("targets", {}) or {});
    by_name: dict[str, any] = {};
    for rs in self._owned_replica_sets(apps_v1, namespace) {
        try {
            owners = list(rs.metadata.owner_references or []);
            ann = dict(rs.metadata.annotations or {});
        } except Exception {
            continue;
        }
        if not owners {
            continue;
        }
        name = str(owners[0].name);
        if name in wanted and ann.get(REVISION_ANNOTATION) == str(wanted[name]) {
            by_name[name] = rs;
        }
    }
    targets = by_name;

    if len(targets) != len(wanted) {
        return DeploymentResult(
            success=False,
            message=(
                f"Refusing a partial rollback of '{app_name}': "
                f"{len(targets)} of {len(wanted)} deployment(s) resolved. "
                "A half reverted app serves two versions at once."
            )
        );
    }

    reverted: list[str] = [];
    undo: dict[str, any] = {};
    selectors: dict[str, any] = {};
    for name in expected {
        if name not in targets {
            continue;
        }
        rs = targets[name];
        template = restorable_pod_template(
            dict(serializer.sanitize_for_serialization(rs.spec.template))
        );
        try {
            live = apps_v1.read_namespaced_deployment(name=name, namespace=namespace);
            undo[name] = dict(
                serializer.sanitize_for_serialization(live.spec.template)
            );
            selectors[name] = dict(
                serializer.sanitize_for_serialization(live.spec.selector)
            );
            apps_v1.patch_namespaced_deployment(
                name=name,
                namespace=namespace,
                body=[{"op": "replace", "path": "/spec/template", "value": template}]
            );
        } except Exception as e {
            stranded = self._restore_templates(apps_v1, namespace, reverted, undo);
            detail = (
                f" {len(stranded)} deployment(s) are still on revision "
                f"{revision} and the app is serving two versions: "
                f"{', '.join(stranded)}."
                    if stranded
                    else " The already reverted deployments were put back."
            );
            return DeploymentResult(
                success=False,
                message=(
                    f"Reverting '{name}' to revision {revision} failed: {e}."
                    f"{detail}"
                ),
                details={"reverted": reverted, "stranded": stranded}
            );
        }
        reverted.append(name);
    }

    wait_bundle: dict[str, any] = {"deployments": {}};
    for name in reverted {
        wait_bundle["deployments"][name] = {
            "metadata": {"name": name},
            "spec": {"selector": selectors.get(name, {})}
        };
    }
    try {
        self._wait_for_fleet_rollout(wait_bundle, require_full=True);
    } except Exception as e {
        return DeploymentResult(
            success=False,
            message=(
                f"Reverted {len(reverted)} deployment(s) to revision "
                f"{revision}, but the fleet did not come back: {e}"
            ),
            details={"reverted": reverted, "revision": revision}
        );
    }
    return DeploymentResult(
        success=True,
        message=(f"Reverted {len(reverted)} deployment(s) to revision {revision}"),
        details={"reverted": reverted, "revision": revision}
    );
}


impl KubernetesTarget._apply_or_replace_pvc(
    core_v1: any, namespace: str, manifest: dict[str, any]
) {
    name: str = manifest["metadata"]["name"];
    try {
        core_v1.read_namespaced_persistent_volume_claim(name=name, namespace=namespace);
        if self.logger {
            self.logger.info(
                f"PVC '{name}' already exists; skipping patch. To apply "
                f"size/storage-class changes, delete the PVC manually or "
                f"run `jac scale destroy <file.jac>`."
            );
        }
    } except ApiException as e {
        if e.status == 404 {
            core_v1.create_namespaced_persistent_volume_claim(
                namespace=namespace, body=manifest
            );
        } else {
            raise;
        }
    }
}
