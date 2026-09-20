impl KEDAAutoscaler._trigger_key{
    return trigger.name or f"{trigger.type}-{trigger_index}";
}

impl KEDAAutoscaler._trigger_auth_name{
    key = f"{app_name}/{self._trigger_key(trigger, trigger_index)}";
    short_hash = hashlib.sha256(key.encode()).hexdigest()[:8];
    return f"{app_name[:20].rstrip('-')}-{short_hash}-ta";
}

impl KEDAAutoscaler._validate_triggers{
    seen: dict[str, int] = {};
    for (i, trigger) in enumerate(spec.triggers) {
        key = self._trigger_key(trigger, i);
        if key in seen {
            raise ValueError(
                f"Trigger '{key}' in autoscaler spec for '{app_name}' collides with the trigger "
                f"at index {seen[
                    key
                ]}; each trigger must resolve to a unique name so their "
                "TriggerAuthentication resources do not overwrite one another."
            );
        }
        seen[key] = i;
    }
}

impl KEDAAutoscaler._get_cluster_key{
    try {
        import from kubernetes.client { Configuration }
        return Configuration.get_default_copy().host or "default";
    } except (ImportError, AttributeError) {
        return "default";
    }
}

impl KEDAAutoscaler.preflight{
    install_warning = [
        "KEDA CRDs not found on cluster. "
        "Install KEDA from the official docs, then redeploy: "
        "https://keda.sh/docs/latest/deploy/"
    ];
    cluster_key = self._get_cluster_key();
    if cluster_key in KEDAAutoscaler._preflight_cache {
        if KEDAAutoscaler._preflight_cache[cluster_key] {
            return [];
        }
        return install_warning;
    }
    api = self._custom_api or client.CustomObjectsApi();
    try {
        api.list_cluster_custom_object(
            group="keda.sh", version="v1alpha1", plural="scaledobjects"
        );
        KEDAAutoscaler._preflight_cache[cluster_key] = True;
        return [];
    } except ApiException as e {
        if e.status in [404, 422] {
            KEDAAutoscaler._preflight_cache[cluster_key] = False;
            return install_warning;
        }
        if e.status == 403 {
            return [
                "Permission denied (403) discovering KEDA core "
                "(keda.sh/v1alpha1 ScaledObject). Grant RBAC list/get on "
                "this resource to the jac-scale service account."
            ];
        }
        raise;
    }
}

impl KEDAAutoscaler._build_trigger{
    if trigger.type == "cpu" {
        value = trigger.metadata.get(
            "averageUtilization", str(DEFAULT_CPU_UTILIZATION_TARGET)
        );
        keda_trigger = {
            "type": "cpu",
            "metricType": "Utilization",
            "metadata": {"value": str(value)}
        };
    } elif trigger.type == "memory" {
        value = trigger.metadata.get(
            "averageUtilization", str(DEFAULT_MEMORY_UTILIZATION_TARGET)
        );
        keda_trigger = {
            "type": "memory",
            "metricType": "Utilization",
            "metadata": {"value": str(value)}
        };
    } else {
        keda_trigger = {
            "type": trigger.type,
            "metadata": {k: str(v) for (k, v) in trigger.metadata.items()}
        };
    }
    if trigger.name {
        keda_trigger["name"] = trigger.name;
    }
    if trigger.auth and trigger.auth.secret_refs {
        auth_name = self._trigger_auth_name(app_name, trigger, trigger_index);
        keda_trigger["authenticationRef"] = {"name": auth_name};
    }
    return keda_trigger;
}

impl KEDAAutoscaler._owner_label_value{
    if len(name) <= 63 {
        return name;
    }
    return f"so-{hashlib.sha256(name.encode()).hexdigest()[:16]}";
}

impl KEDAAutoscaler._scaled_object_name{
    return spec.autoscaler_name or self.resource_name_for(app_name);
}

impl KEDAAutoscaler._build_manifests{
    app_name = spec.app_name or spec.scale_target_name;
    self._validate_triggers(spec, app_name);
    scaled_obj_name = self._scaled_object_name(spec, app_name);
    keda_triggers: list[dict[str, any]] = [];
    for (i, trigger) in enumerate(spec.triggers) {
        keda_triggers.append(self._build_trigger(trigger, app_name, i));
    }

    if not keda_triggers {
        keda_triggers.append(
            {
                "type": "cpu",
                "metricType": "Utilization",
                "metadata": {"value": str(DEFAULT_CPU_UTILIZATION_TARGET)}
            }
        );
    }
    scaled_obj_spec: dict[str, any] = {
        "scaleTargetRef": {
            "apiVersion": "apps/v1",
            "kind": spec.target_kind,
            "name": spec.scale_target_name
        },
        "minReplicaCount": spec.min_replicas,
        "maxReplicaCount": spec.max_replicas,
        "pollingInterval": spec.polling_interval,
        "cooldownPeriod": spec.cooldown_period,
        "triggers": keda_triggers,
        "advanced": {
            "horizontalPodAutoscalerConfig": {
                "behavior": Autoscaler._build_behavior(spec)
            }
        }
    };

    if spec.idle_replicas is not None {
        scaled_obj_spec["idleReplicaCount"] = spec.idle_replicas;
    }

    if spec.initial_cooldown_period > 0 {
        scaled_obj_spec["initialCooldownPeriod"] = spec.initial_cooldown_period;
    }

    scaled_object = k8s_manifest(
        "ScaledObject",
        scaled_obj_name,
        {"spec": scaled_obj_spec},
        spec.namespace,
        {"app": spec.scale_target_name, ** Autoscaler._managed_labels()},
        api_version="keda.sh/v1alpha1"
    );

    manifests: list[dict[str, any]] = [scaled_object];
    for (i, trigger) in enumerate(spec.triggers) {
        auth_manifest = self._build_trigger_auth_manifest(
            trigger, spec.namespace, app_name, i, scaled_obj_name
        );
        if auth_manifest is not None {
            manifests.append(auth_manifest);
        }
    }
    return manifests;
}

impl KEDAAutoscaler._build_trigger_auth_manifest{
    if not trigger.auth {
        return None;
    }
    if not trigger.auth.secret_refs {
        return None;
    }
    auth_name = self._trigger_auth_name(app_name, trigger, trigger_index);
    secret_target_refs: list[dict[str, any]] = [];
    for (param, ref) in trigger.auth.secret_refs.items() {
        if not isinstance(ref, dict) {
            raise ValueError(
                f"auth.secret_refs['{param}'] must be a table {{name = '...', key = '...'}}, got {type(
                    ref
                ).__name__}"
            );
        }
        secret_target_refs.append(
            {"parameter": param, "name": ref.get("name", ""), "key": ref.get("key", "")}
        );
    }
    return k8s_manifest(
        "TriggerAuthentication",
        auth_name,
        {"spec": {"secretTargetRef": secret_target_refs}},
        namespace,
        {
            "app": app_name,
            "jac-scale/owner": self._owner_label_value(owner),
            ** Autoscaler._managed_labels()
        },
        api_version="keda.sh/v1alpha1"
    );
}

impl KEDAAutoscaler._apply_custom_object{
    try {
        api.get_namespaced_custom_object(
            group=group, version=version, namespace=namespace, plural=plural, name=name
        );
        api.patch_namespaced_custom_object(
            group=group,
            version=version,
            namespace=namespace,
            plural=plural,
            name=name,
            body=body
        );
    } except ApiException as e {
        if e.status == 404 {
            api.create_namespaced_custom_object(
                group=group,
                version=version,
                namespace=namespace,
                plural=plural,
                body=body
            );
        } else {
            raise;
        }
    }
}

impl KEDAAutoscaler._list_custom_items{
    tolerated = tolerated or [404, 422];
    try {
        listing = api.list_namespaced_custom_object(
            group=group,
            version=version,
            namespace=namespace,
            plural=plural,
            label_selector=selector
        );
        return listing.get("items", []) if isinstance(listing, dict) else [];
    } except ApiException as e {
        if e.status not in tolerated {
            raise;
        }
        return [];
    }
}

impl KEDAAutoscaler._delete_custom_object{
    # Returns the error instead of raising so callers can defer (e.g. delete
    # both HTTP-activation resources before reporting the worst failure).
    tolerated = tolerated or [404, 422];
    try {
        api.delete_namespaced_custom_object(
            group=group, version=version, namespace=namespace, plural=plural, name=name
        );
        return None;
    } except ApiException as e {
        if e.status in tolerated {
            return None;
        }
        return e;
    }
}
