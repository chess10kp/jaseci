import from jaclang.scale.deploy.autoscale.autoscaler {
    Autoscaler,
    AutoscalerSpec,
    DEFAULT_CPU_UTILIZATION_TARGET,
    DEFAULT_MEMORY_UTILIZATION_TARGET
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    delete_resource,
    k8s_manifest
}

obj HPAAutoscaler(Autoscaler) {
    has logger: (Logger | None) = None;

    def _build_manifests(spec: AutoscalerSpec) -> list[dict[str, any]];
    def apply(spec: AutoscalerSpec) -> bool;
    def destroy(app_name: str, namespace: str) -> None;
    def destroy_collection(namespace: str, label_selector: str) -> None;
    def resource_name_for(target: str) -> str;
}
