impl KEDAAutoscaler.apply{
    app_name = spec.app_name or spec.scale_target_name;
    manifests = self._build_manifests(spec);
    warnings = self.preflight();
    if warnings {
        if self.logger {
            self.logger.warn(warnings[0]);
        }
        return False;
    }
    api = self._custom_api or client.CustomObjectsApi();

    try {
        (
            self._v2_api or AutoscalingV2Api()
        ).delete_namespaced_horizontal_pod_autoscaler(
            name=f"{app_name}-hpa", namespace=spec.namespace
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }

    known_kinds = [kind for (kind, _) in KEDAAutoscaler._APPLY_ORDER];
    unknown_kinds = [
        manifest["kind"]
        for manifest in manifests
        if manifest["kind"] not in known_kinds
    ];
    if unknown_kinds {
        raise ValueError(
            f"_build_manifests returned unhandled kind(s) {unknown_kinds}; "
            "add them to KEDAAutoscaler._APPLY_ORDER."
        );
    }
    for (kind, plural) in KEDAAutoscaler._APPLY_ORDER {
        for manifest in manifests {
            if manifest["kind"] == kind {
                self._apply_custom_object(
                    api,
                    "keda.sh",
                    "v1alpha1",
                    spec.namespace,
                    plural,
                    manifest["metadata"]["name"],
                    manifest
                );
            }
        }
    }

    owner = self._scaled_object_name(spec, app_name);
    desired_auth_names: set[str] = set();
    for manifest in manifests {
        if manifest["kind"] == "TriggerAuthentication" {
            desired_auth_names.add(manifest["metadata"]["name"]);
        }
    }
    self._prune_orphan_trigger_auths(api, spec.namespace, owner, desired_auth_names);
    return True;
}

impl KEDAAutoscaler._prune_orphan_trigger_auths{
    selector = f"jac-scale/owner={self._owner_label_value(owner)},managed=jac-scale";
    for item in self._list_custom_items(
        api, "keda.sh", "v1alpha1", namespace, "triggerauthentications", selector
    ) {
        item_name = item["metadata"]["name"];
        if item_name in desired_auth_names {
            continue;
        }
        err = self._delete_custom_object(
            api, "keda.sh", "v1alpha1", namespace, "triggerauthentications", item_name
        );
        if err is not None {
            raise err;
        }
    }
}

impl KEDAAutoscaler.destroy{
    api = self._custom_api or client.CustomObjectsApi();
    scaled_object_name = self.resource_name_for(app_name);
    selector = f"jac-scale/owner={self._owner_label_value(
        scaled_object_name
    )},managed=jac-scale";
    for item in self._list_custom_items(
        api, "keda.sh", "v1alpha1", namespace, "triggerauthentications", selector
    ) {
        err = self._delete_custom_object(
            api,
            "keda.sh",
            "v1alpha1",
            namespace,
            "triggerauthentications",
            item["metadata"]["name"]
        );
        if err is not None {
            raise err;
        }
    }

    err = self._delete_custom_object(
        api, "keda.sh", "v1alpha1", namespace, "scaledobjects", scaled_object_name
    );
    if err is not None {
        raise err;
    }
}

impl KEDAAutoscaler.destroy_collection{
    api = self._custom_api or client.CustomObjectsApi();
    for (group, version, plural) in [
        ("keda.sh", "v1alpha1", "scaledobjects"),
        ("keda.sh", "v1alpha1", "triggerauthentications"),
        ("http.keda.sh", "v1beta1", "interceptorroutes")
    ] {
        tolerated = [404, 422, 403]
            if (group == "http.keda.sh" or best_effort)
            else [404, 422];
        for item in self._list_custom_items(
            api, group, version, namespace, plural, label_selector, tolerated
        ) {
            err = self._delete_custom_object(
                api,
                group,
                version,
                namespace,
                plural,
                item["metadata"]["name"],
                tolerated
            );
            if err is not None {
                raise err;
            }
        }
    }

    try {
        (
            self._v2_api or AutoscalingV2Api()
        ).delete_collection_namespaced_horizontal_pod_autoscaler(
            namespace=namespace, label_selector=label_selector
        );
    } except ApiException as e {
        if e.status not in [404, 422] {
            raise;
        }
    }
}

impl KEDAAutoscaler.resource_name_for{
    return f"{target}-scaledobject";
}

impl KEDAAutoscaler.interceptor_route_name_for{
    return f"{target}-http-route";
}

impl KEDAAutoscaler.http_scaled_object_name_for{
    return f"{target}-http-scaledobject";
}
