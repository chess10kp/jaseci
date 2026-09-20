impl KEDAAutoscaler._capabilities_cache_key{
    return (
        f"{self._get_cluster_key()}::{self.http_scaler_address}"
        f"::{self.interceptor_service_address}::{id(self._custom_api)}"
        f"::{id(self._core_api)}"
    );
}

impl KEDAAutoscaler.discover_capabilities{
    cluster_key = self._capabilities_cache_key();
    if not refresh and cluster_key in self._capabilities_cache {
        return self._capabilities_cache[cluster_key];
    }

    api = self._custom_api or client.CustomObjectsApi();
    core_api = self._core_api or client.CoreV1Api();
    caps = KEDACapabilities();

    keda_docs_url = "https://keda.sh/http-add-on/0.15/getting-started/";
    http_addon_docs_url = "https://keda.sh/http-add-on/0.15/getting-started/";
    install_core_cmd = (
        "helm repo add kedacore https://kedacore.github.io/charts && "
        "helm repo update && helm install keda kedacore/keda -n keda "
        f"--create-namespace --wait (see {keda_docs_url} for current instructions)"
    );
    install_addon_cmd = (
        "helm install http-add-on kedacore/keda-add-ons-http -n keda --wait "
        f"(see {http_addon_docs_url} for current instructions)"
    );
    upgrade_addon_cmd = (
        "helm upgrade http-add-on kedacore/keda-add-ons-http -n keda --wait "
        f"(see {http_addon_docs_url} for current instructions)"
    );

    try {
        api.list_cluster_custom_object(
            group="keda.sh", version="v1alpha1", plural="scaledobjects"
        );
        caps.core_available = True;
    } except ApiException as e {
        if e.status == 403 {
            caps.errors.append(
                "Permission denied (403) discovering KEDA core "
                "(keda.sh/v1alpha1 ScaledObject). Grant RBAC list/get on "
                "this resource to the jac-scale service account."
            );
        } elif e.status in [404, 422] {
            caps.warnings.append(
                f"KEDA core not found on cluster. Install it with: {install_core_cmd}"
            );
        } else {
            raise;
        }
    }

    http_addon_status: (int | None) = None;
    for version in SUPPORTED_HTTP_INTERCEPTOR_API_VERSIONS {
        try {
            api.list_cluster_custom_object(
                group="http.keda.sh", version=version, plural="interceptorroutes"
            );
            caps.http_addon_available = True;
            caps.interceptor_route_api_version = version;
            break;
        } except ApiException as e {
            http_addon_status = e.status;
            if e.status == 403 {
                caps.errors.append(
                    "Permission denied (403) discovering the KEDA HTTP Add-on "
                    f"(http.keda.sh/{version} InterceptorRoute). Grant RBAC "
                    "list/get on this resource to the jac-scale service account."
                );
                break;
            } elif e.status not in [404, 422] {
                raise;
            }
        }
    }

    if not caps.http_addon_available and http_addon_status in [404, 422] {
        try {
            api.list_cluster_custom_object(
                group="http.keda.sh", version="v1alpha1", plural="httpscaledobjects"
            );
            caps.warnings.append(
                "Legacy KEDA HTTP Add-on detected (http.keda.sh/v1alpha1 "
                "HTTPScaledObject); jac-scale requires v1beta1 "
                f"InterceptorRoute. Upgrade with: {upgrade_addon_cmd}"
            );
        } except ApiException as e {
            if e.status == 403 {
                caps.errors.append(
                    "Permission denied (403) probing the legacy KEDA HTTP "
                    "Add-on API (http.keda.sh/v1alpha1 HTTPScaledObject) "
                    "while checking for an outdated install. Grant RBAC "
                    "list/get on this resource to the jac-scale service "
                    "account."
                );
            } elif e.status in [404, 422] {
                caps.warnings.append(
                    f"KEDA HTTP Add-on not found on cluster. Install it with: {install_addon_cmd}"
                );
            } else {
                raise;
            }
        }
    }

    if caps.http_addon_available {
        caps.external_scaler_address = self.http_scaler_address;
        caps.interceptor_service_address = self.interceptor_service_address;
        scaler_error = self._check_service_address(core_api, self.http_scaler_address);
        if scaler_error is not None {
            caps.errors.append(scaler_error);
        }
        interceptor_error = self._check_service_address(
            core_api, self.interceptor_service_address
        );
        if interceptor_error is not None {
            caps.errors.append(interceptor_error);
        }
    }

    self._capabilities_cache[cluster_key] = caps;
    return caps;
}

impl KEDAAutoscaler.invalidate_capabilities{
    self._capabilities_cache.pop(self._capabilities_cache_key(), None);
}

impl KEDAAutoscaler.format_capabilities{
    if caps.core_available and caps.http_addon_available and not caps.errors {
        return "KEDA HTTP Add-on capabilities ready: core and HTTP Add-on both available.";
    }
    if caps.errors {
        return f"KEDA HTTP Add-on not ready: {caps.errors[0]}";
    }
    if caps.warnings {
        return f"KEDA HTTP Add-on not ready: {caps.warnings[0]}";
    }
    return "KEDA HTTP Add-on capabilities unknown.";
}
