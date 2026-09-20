import time;
import from pathlib { Path }
import from jaclang.scale._optdeps.kubernetes {
    client,
    config,
    ApiException,
    ConfigException
}
import from jaclang.scale.deploy.target.kubernetes.cluster_provider { ClusterProvider }

glob _LOCAL_FALLBACK_NOTE: str = (
         "Falling back to local provider semantics: service URLs will be "
         "reported as localhost node ports and no load balancer endpoint will "
         "be waited for. If this is a managed cluster, the reported URLs will "
         "be wrong."
     );

glob PSS_ENFORCE_LABEL: str = "pod-security.kubernetes.io/enforce",
     PSS_WARN_LABEL: str = "pod-security.kubernetes.io/warn",
     PSS_SOURCE_LABEL: str = "jac-scale.jaseci.org/pss-enforce-source",
     NAMESPACE_OWNER_LABEL: str = "jac-scale.jaseci.org/owned-by",
     MANAGED_LABEL: str = "jac-scale";

glob KIND_API_VERSION: dict[str, str] = {
         "Namespace": "v1",
         "ConfigMap": "v1",
         "Secret": "v1",
         "Service": "v1",
         "ServiceAccount": "v1",
         "PersistentVolumeClaim": "v1",
         "Deployment": "apps/v1",
         "DaemonSet": "apps/v1",
         "StatefulSet": "apps/v1",
         "ReplicaSet": "apps/v1",
         "Role": "rbac.authorization.k8s.io/v1",
         "RoleBinding": "rbac.authorization.k8s.io/v1",
         "ClusterRole": "rbac.authorization.k8s.io/v1",
         "ClusterRoleBinding": "rbac.authorization.k8s.io/v1",
         "Ingress": "networking.k8s.io/v1",
         "IngressClass": "networking.k8s.io/v1",
         "PodDisruptionBudget": "policy/v1"
     };

def app_labels(app: str) -> dict[str, str];

def managed_labels -> dict[str, str];

def k8s_manifest(
    kind: str,
    name: str,
    fields: (dict[str, any] | None) = None,
    namespace: str = "",
    labels: (dict[str, str] | None) = None,
    annotations: (dict[str, str] | None) = None,
    api_version: str = ""
) -> dict[str, any];

def pod_security_context -> dict[str, any];

def restricted_container_security(uid: int) -> dict[str, any];

def svc_port(port: int, name: str = "") -> dict[str, any];

def service_manifest(
    name: str, namespace: str, ports: list[dict[str, any]], labels: dict[str, str]
) -> dict[str, any];

def pod_spec(
    containers: list[dict[str, any]],
    volumes: (list[dict[str, any]] | None) = None,
    service_account: str = "",
    automount: (bool | None) = None,
    tolerations: (list[dict[str, any]] | None) = None
) -> dict[str, any];

def workload_manifest(
    kind: str,
    name: str,
    namespace: str,
    pod: dict[str, any],
    pod_labels: dict[str, str],
    annotations: (dict[str, str] | None) = None
) -> dict[str, any];

def apply_service(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    ports: list[dict[str, any]]
) -> None;

def apply_config_map(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    data: dict[str, str]
) -> None;

def apply_secret(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    string_data: dict[str, str],
    replace: bool = True
) -> None;

def apply_service_account(
    core_v1: any,
    name: str,
    namespace: str,
    labels: dict[str, str],
    fields: (dict[str, any] | None) = None
) -> None;

def apply_cluster_rbac(
    core_v1: any,
    name: str,
    namespace: str,
    rules: list[dict[str, any]],
    sa_name: str = "",
    sa_fields: (dict[str, any] | None) = None,
    replace: bool = True
) -> None;

def patch_k8s_resource(
    api: any,
    kind: str,
    manifest: dict[str, any],
    namespace: (str | None) = None,
    patch_body: (dict[str, any] | None) = None
) -> None;

def delete_resource(api: any, kind: str, name: str, namespace: str = "") -> None;

def delete_collection_if_exists(
    delete_func: Callable, namespace: str, selector: str
) -> None;

def default_pss_labels -> dict[str, str];

def privileged_pss_labels(existing: dict[str, str]) -> dict[str, str] | None;

glob COMPANION_DEFS: list[tuple[str, str, bool]] = [
         ("", "Jaseci App", False),
         ("-postgres", "PostgreSQL", True),
         ("-prometheus", "Prometheus", False),
         ("-grafana", "Grafana", False),
         ("-ingress-nginx", "NGINX Ingress", False),

     ];

def _resolve_current_rs_hashes(namespace: str, selector: str) -> set;

def _refresh_rs_hashes(
    namespace: str, selector: str, current: (set | None)
) -> (set | None);

def create_k8s_secret(
    core_v1: client.CoreV1Api,
    namespace: str,
    secret_name: str,
    secret_data: dict[str, str]
) -> str;

def delete_k8s_secret(
    core_v1: client.CoreV1Api, namespace: str, secret_name: str
) -> None;

def apply_k8s_resource(
    api: any,
    kind: str,
    name: str,
    body: dict[str, any],
    namespace: (str | None) = None,
    replace: bool = True
) -> None;

def ensure_namespace_exists(namespace: str, owner: str) -> None;

def namespace_is_owned(core_v1: client.CoreV1Api, namespace: str, owner: str) -> bool;

def delete_namespace(namespace: str) -> None;

def cluster_type -> str;

def get_cluster_provider -> ClusterProvider;

def parse_storage_quantity(quantity: str) -> int;

def resize_pvc_if_needed(
    core_v1: client.CoreV1Api, namespace: str, pvc_name: str, desired_size: str
) -> None;

def wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None;

def describe_pod_status(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, pod: any = None
) -> str;

def wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None;

def run_kubectl_command(args: list[str], cwd: str | Path | None = None) -> None;
