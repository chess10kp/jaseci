import re;
import hashlib;
import from jaclang.scale._optdeps.kubernetes { client }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.observability.logger { Logger }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    app_labels,
    apply_cluster_rbac,
    apply_config_map,
    apply_k8s_resource,
    apply_secret,
    apply_service,
    apply_service_account,
    delete_resource,
    patch_k8s_resource,
    pod_spec,
    restricted_container_security,
    svc_port,
    workload_manifest
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }


obj MonitoringDeployer {
    has k8s_config: KubernetesConfig,
        logger: (Logger | None) = None;

    def _log(msg: str);
    def _deploy_prometheus(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        provider: ClusterProvider,
        scrape_target_service: str = ""
    );

    def _deploy_kube_state_metrics(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    );

    def _deploy_node_exporter(
        app_name: str, namespace: str, apps_v1: any, core_v1: any
    );

    def _deploy_grafana(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _deploy_tempo(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _deploy_loki(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def _deploy_alloy(app_name: str, namespace: str, apps_v1: any, core_v1: any);
    def deploy(
        app_name: str,
        namespace: str,
        apps_v1: any,
        core_v1: any,
        provider: ClusterProvider,
        scrape_target_service: str = ""
    );

    def destroy(app_name: str, namespace: str, apps_v1: any, core_v1: any);
}
