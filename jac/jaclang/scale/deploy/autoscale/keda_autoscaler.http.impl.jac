impl KEDAAutoscaler.apply_http_activation{
    self._validate_http_activation_spec(spec);

    caps = self.discover_capabilities();
    if caps.errors {
        raise ValueError(
            "KEDA HTTP Add-on capability check failed:\n" + "\n".join(caps.errors)
        );
    }
    if not caps.core_available or not caps.http_addon_available {
        if self.logger {
            for warning in caps.warnings {
                self.logger.warn(warning);
            }
        }
        return False;
    }

    api = self._custom_api or client.CustomObjectsApi();
    apps_api = self._apps_api or client.AppsV1Api();
    core_api = self._core_api or client.CoreV1Api();

    target_readers = {
        "Deployment": "read_namespaced_deployment",
        "StatefulSet": "read_namespaced_stateful_set"
    };
    try {
        if spec.scale_target_kind in target_readers {
            getattr(apps_api, target_readers[spec.scale_target_kind])(
                name=spec.scale_target_name, namespace=spec.namespace
            );
        } elif spec.scale_target_plural is not None {
            (custom_group, _, custom_version) = spec.scale_target_api_version.rpartition(
                "/"
            );
            api.get_namespaced_custom_object(
                group=custom_group,
                version=custom_version,
                namespace=spec.namespace,
                plural=spec.scale_target_plural,
                name=spec.scale_target_name
            );
        } else {
            raise ValueError(
                f"Cannot verify scale_target_kind='{spec.scale_target_kind}' "
                f"exists before apply. Set scale_target_plural on "
                f"HTTPActivationSpec to enable validation for this custom "
                f"resource, or use scale_target_kind='Deployment' or "
                f"'StatefulSet'."
            );
        }
    } except ApiException as e {
        if e.status == 404 {
            raise ValueError(
                f"Scale target '{spec.scale_target_name}' "
                f"({spec.scale_target_kind}) not found in namespace "
                f"'{spec.namespace}'."
            );
        }
        raise;
    }

    try {
        core_api.read_namespaced_service(
            name=spec.target.service, namespace=spec.namespace
        );
    } except ApiException as e {
        if e.status == 404 {
            raise ValueError(
                f"Service '{spec.target.service}' not found in namespace "
                f"'{spec.namespace}'."
            );
        }
        raise;
    }

    route_manifest = self._build_interceptor_route(spec);
    self._apply_custom_object(
        api,
        "http.keda.sh",
        "v1beta1",
        spec.namespace,
        "interceptorroutes",
        route_manifest["name"],
        route_manifest["body"]
    );

    scaled_obj_manifest = self._build_http_scaled_object(spec);
    self._apply_custom_object(
        api,
        "keda.sh",
        "v1alpha1",
        spec.namespace,
        "scaledobjects",
        scaled_obj_manifest["name"],
        scaled_obj_manifest["body"]
    );

    return True;
}

impl KEDAAutoscaler.destroy_http_activation{
    api = self._custom_api or client.CustomObjectsApi();

    interceptor_error = self._delete_custom_object(
        api,
        "http.keda.sh",
        "v1beta1",
        namespace,
        "interceptorroutes",
        self.interceptor_route_name_for(target)
    );
    scaled_object_error = self._delete_custom_object(
        api,
        "keda.sh",
        "v1alpha1",
        namespace,
        "scaledobjects",
        self.http_scaled_object_name_for(target)
    );

    if interceptor_error is not None and interceptor_error.status != 403 {
        raise interceptor_error;
    }
    if scaled_object_error is not None and scaled_object_error.status != 403 {
        raise scaled_object_error;
    }
    pending_error = interceptor_error or scaled_object_error;
    if pending_error is not None {
        raise pending_error;
    }
}

impl KEDAAutoscaler._build_routing_rules{
    result: list[dict[str, any]] = [];
    for rule in rules {
        header_matches: list[dict[str, any]] = [];
        for header in rule.headers {
            header_entry: dict[str, any] = {"name": header.name};
            if header.value is not None {
                header_entry["value"] = header.value;
            }
            header_matches.append(header_entry);
        }

        paths = rule.paths or [None];
        for path in paths {
            `entry: dict[str, any] = {};
            if rule.hosts {
                `entry["hosts"] = rule.hosts;
            }
            if path is not None {
                `entry["path"] = {"value": path.value};
            }
            if header_matches {
                `entry["headers"] = header_matches;
            }
            result.append(`entry);
        }
    }
    return result;
}

impl KEDAAutoscaler._build_interceptor_route{
    route_name = self.interceptor_route_name_for(spec.scale_target_name);

    target: dict[str, any] = {"service": spec.target.service};
    if spec.target.port is not None {
        target["port"] = spec.target.port;
    } else {
        target["portName"] = spec.target.port_name;
    }

    scaling_metric: dict[str, any] = {};
    if spec.concurrency is not None {
        scaling_metric["concurrency"] = {"targetValue": spec.concurrency.target_value};
    } elif spec.request_rate is not None {
        scaling_metric["requestRate"] = {
            "targetValue": spec.request_rate.target_value,
            "window": spec.request_rate.rate_window,
            "granularity": spec.request_rate.granularity
        };
    }

    route_spec: dict[str, any] = {
        "target": target,
        "scalingMetric": scaling_metric,
        "rules": self._build_routing_rules(spec.rules)
    };

    if spec.cold_start is not None {
        cold_start: dict[str, any] = {};
        placeholder = spec.cold_start.placeholder;
        if placeholder is not None {
            placeholder_body: dict[str, any] = {"statusCode": placeholder.status_code};
            if placeholder.body is not None {
                placeholder_body["body"] = placeholder.body;
            }
            if placeholder.body_from_config_map is not None {
                placeholder_body["bodyFromConfigMap"] = placeholder.body_from_config_map;
            }
            if placeholder.headers {
                placeholder_body["headers"] = placeholder.headers;
            }
            cold_start["placeholder"] = {"response": placeholder_body};
        }
        fallback_service = spec.cold_start.fallback_service;
        if fallback_service is not None {
            fallback_body: dict[str, any] = {"name": fallback_service.service};
            if fallback_service.port is not None {
                fallback_body["port"] = fallback_service.port;
            } else {
                fallback_body["portName"] = fallback_service.port_name;
            }
            cold_start["fallback"] = {"service": fallback_body};
        }
        if cold_start {
            route_spec["coldStart"] = cold_start;
        }
    }

    if spec.timeouts is not None {
        timeouts: dict[str, any] = {};
        if spec.timeouts.readiness is not None {
            timeouts["readiness"] = spec.timeouts.readiness;
        }
        if spec.timeouts.request is not None {
            timeouts["request"] = spec.timeouts.request;
        }
        if spec.timeouts.response_header is not None {
            timeouts["responseHeader"] = spec.timeouts.response_header;
        }
        if timeouts {
            route_spec["timeouts"] = timeouts;
        }
    }

    return {
        "name": route_name,
        "body": k8s_manifest(
            "InterceptorRoute",
            route_name,
            {"spec": route_spec},
            spec.namespace,
            {"app": spec.scale_target_name, ** Autoscaler._managed_labels()},
            api_version="http.keda.sh/v1beta1"
        )
    };
}

impl KEDAAutoscaler._build_http_scaled_object{
    scaled_obj_name = self.http_scaled_object_name_for(spec.scale_target_name);

    trigger_metadata: dict[str, any] = {
        "scalerAddress": self.http_scaler_address,
        "interceptorRoute": self.interceptor_route_name_for(spec.scale_target_name)
    };
    if spec.concurrency is not None {
        trigger_metadata["targetValue"] = str(spec.concurrency.target_value);
    } elif spec.request_rate is not None {
        trigger_metadata["targetValue"] = str(spec.request_rate.target_value);
        trigger_metadata["window"] = spec.request_rate.rate_window;
        trigger_metadata["granularity"] = spec.request_rate.granularity;
    }

    scaled_obj_spec: dict[str, any] = {
        "scaleTargetRef": {
            "apiVersion": spec.scale_target_api_version,
            "kind": spec.scale_target_kind,
            "name": spec.scale_target_name
        },
        "minReplicaCount": spec.min_replicas,
        "maxReplicaCount": spec.max_replicas,
        "pollingInterval": spec.polling_interval,
        "cooldownPeriod": spec.cooldown_period,
        "triggers": [{"type": "external-push", "metadata": trigger_metadata}]
    };

    return {
        "name": scaled_obj_name,
        "body": k8s_manifest(
            "ScaledObject",
            scaled_obj_name,
            {"spec": scaled_obj_spec},
            spec.namespace,
            {"app": spec.scale_target_name, ** Autoscaler._managed_labels()},
            api_version="keda.sh/v1alpha1"
        )
    };
}

impl KEDAAutoscaler._validate_http_activation_spec{
    if spec.scale_target_kind == "Pod" {
        raise ValueError(
            f"HTTP activation requires a target exposing Kubernetes' /scale "
            f"subresource; got scale_target_kind='Pod' for "
            f"'{spec.scale_target_name}'. Use a Deployment, StatefulSet, or "
            f"compatible custom resource instead."
        );
    }
    if spec.target.port is not None and spec.target.port_name is not None {
        raise ValueError(
            "HTTPServiceTarget must set exactly one of port or port_name, not both."
        );
    }
    if spec.target.port is None and spec.target.port_name is None {
        raise ValueError(
            "HTTPServiceTarget must set exactly one of port or port_name."
        );
    }
    if spec.concurrency is None and spec.request_rate is None {
        raise ValueError(
            "HTTPActivationSpec requires at least one of concurrency or request_rate."
        );
    }
}

impl KEDAAutoscaler._check_service_address{
    (host, _, __) = address.partition(":");
    parts = host.split(".");
    name = parts[0];
    namespace = parts[1] if len(parts) > 1 else "keda";
    try {
        core_api.read_namespaced_service(name=name, namespace=namespace);
        return None;
    } except ApiException as e {
        if e.status == 403 {
            return (
                f"Permission denied (403) checking Service '{name}' in "
                f"namespace '{namespace}'. Verify RBAC grants get/list on "
                f"services for the jac-scale service account."
            );
        }
        if e.status in [404, 422] {
            return f"Service '{name}' not found in namespace '{namespace}' (address: '{address}').";
        }
        raise;
    }
}
