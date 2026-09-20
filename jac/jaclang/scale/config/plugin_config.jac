import from jaclang.project.config_schema { opt, opt_group }


def _http_activation_nested_schema -> dict[str, any] {
    """The `nested` fields shared verbatim by [scale.kubernetes.http_activation]
    and [apps.NAME.scale.http_activation] -- factored out so
    the two call sites (top-level default, per-app override) can't drift
    out of sync on a field's type/default the way two independent copies
    would.
    """;
    return {
        "enabled": opt("bool", False, "Master switch. Off by default."),
        "min_replicas": opt(
            "int", 0, "Replica floor while inactive. 0 enables true scale-to-zero."
        ),
        "max_replicas": opt("int", 1, "Replica ceiling once activated."),
        "polling_interval": opt(
            "int", 30, "How often KEDA evaluates the HTTP scaling metric, in seconds."
        ),
        "cooldown_period": opt(
            "int", 300, "Seconds of inactivity before scaling back to min_replicas."
        ),
        "target_port": opt(
            "int",
            None,
            "Container port on the target's own generated Service. Exactly one of target_port/target_port_name must be set when enabled."
        ),
        "target_port_name": opt(
            "string",
            None,
            "Named container port on the target's own generated Service, as an alternative to target_port."
        ),
        "concurrency_target": opt(
            "int",
            None,
            "In-flight-request concurrency target. Exactly one of concurrency_target/request_rate_target must be set when enabled."
        ),
        "request_rate_target": opt(
            "int",
            None,
            "Requests-per-window target, as an alternative to concurrency_target."
        ),
        "request_rate_window": opt(
            "string", "1m", "Window duration for request_rate_target."
        ),
        "request_rate_granularity": opt(
            "string", "1s", "Sampling granularity for request_rate_target."
        ),
        "cold_start_status_code": opt(
            "int",
            503,
            "HTTP status the interceptor returns while the target cold-starts, if a placeholder response is configured."
        ),
        "cold_start_body": opt(
            "string",
            None,
            "Static placeholder response body served while the target cold-starts."
        ),
        "cold_start_body_config_map": opt(
            "dict",
            None,
            "ConfigMap reference to source the placeholder response body from, as an alternative to cold_start_body."
        ),
        "cold_start_headers": opt(
            "dict", {}, "Extra headers on the placeholder response."
        ),
        "cold_start_fallback_service": opt(
            "string",
            None,
            "Service name to forward requests to while the target cold-starts, as an alternative to a static placeholder response."
        ),
        "cold_start_fallback_port": opt(
            "int", None, "Port on cold_start_fallback_service."
        ),
        "timeout_readiness": opt(
            "string",
            None,
            "Duration (e.g. \"30s\") the interceptor waits for the target to become ready after scaling up."
        ),
        "timeout_request": opt(
            "string",
            None,
            "Duration the interceptor waits for the forwarded request to complete."
        ),
        "timeout_response_header": opt(
            "string",
            None,
            "Duration the interceptor waits for response headers from the target."
        ),
        "scale_target_kind": opt(
            "string",
            "Deployment",
            "Kind of the scale target. Deployment/StatefulSet work directly; other kinds require scale_target_plural."
        ),
        "scale_target_api_version": opt(
            "string",
            "apps/v1",
            "apiVersion of the scale target, used when scale_target_plural is set for a custom-resource target."
        ),
        "scale_target_plural": opt(
            "string",
            None,
            "Plural resource name for a custom-resource scale target (e.g. \"rollouts\"), enabling existence validation before writing anything."
        ),
        "rules": opt(
            "list",
            [],
            "[[...rules]] array-of-tables. Each entry: hosts (list[str]), paths (list[str]), headers (list of {name, value?}). Fields within one rule are AND'd; separate rules are OR'd. At least one rule is required -- leaving this empty raises an error at build time, since no traffic would ever match and the target would never wake. Use hosts = [\"*\"] for an explicit catch-all."
        )
    };
}


def app_scale_schema -> dict[str, any] {
    return {
        "rpc_timeout": opt("float", 10.0, "App-to-app RPC call timeout in seconds"),
        "http_forward_timeout": opt(
            "float", 30.0, "Gateway-to-app forward timeout in seconds"
        ),
        "replicas": opt("int", 1, "K8s Deployment.spec.replicas"),
        "cpu_request": opt("string", None, "K8s container CPU request, e.g. '100m'"),
        "cpu_limit": opt("string", None, "K8s container CPU limit, e.g. '2000m'"),
        "memory_request": opt(
            "string", None, "K8s container memory request, e.g. '128Mi'"
        ),
        "memory_limit": opt("string", None, "K8s container memory limit, e.g. '4Gi'"),
        "env": opt(
            "dict",
            {},
            "Extra container env vars merged with the auto-set JAC_SV_NAME, JAC_SV_FILE and JAC_APP_<PEER>_URL"
        ),
        "read_cache": opt(
            "bool",
            False,
            "Cache bridged calls whose provider endpoint declares no effects, invalidated when an effectful call to the same provider goes through"
        ),
        "workers": opt(
            "string",
            None,
            "Worker processes for this app's pods (overrides [serve.workers] count). 'auto' sizes from the pod's CPU quota. A CPU-bound app on a 2-core limit wants 2; an I/O-bound one is fine at 1."
        ),
        "threads": opt(
            "string",
            None,
            "Sync-handler threads per worker for this app's pods (overrides [serve.workers] threads)."
        ),
        "hpa": opt_group(
            "Autoscaler settings for this app",
            {
                "enabled": opt("bool", True, "Emit an HPA/ScaledObject for this app"),
                "min": opt("int", 1, "Minimum replicas"),
                "max": opt("int", 3, "Maximum replicas"),
                "cpu_target": opt("int", 50, "CPU utilization target percent"),
                "memory_target": opt(
                    "int",
                    80,
                    "Memory utilization target percent (of the memory request)"
                ),
                "behavior": opt(
                    "dict",
                    {},
                    "Raw HPA behavior fragment deep-merged over generated defaults"
                )
            }
        ),
        "pdb": opt_group(
            "PodDisruptionBudget settings for this app",
            {
                "enabled": opt("bool", True, "Emit a PDB for this app"),
                "max_unavailable": opt(
                    "int",
                    1,
                    "PDB maxUnavailable. A budget that permits evicting every replica protects nothing, so no PDB is emitted when this is at or above the app's replica floor (hpa.min, or replicas when the HPA is off)."
                ),
                "min_available": opt(
                    "int",
                    None,
                    "PDB minAvailable. Set it to keep a floor of healthy pods through voluntary disruption; it wins over max_unavailable."
                )
            }
        ),
        "deployment_overlay": opt(
            "dict",
            {},
            "Raw Deployment-manifest fragment merged into the generated manifest: maps merge recursively, lists whose members all carry `name` merge by that name, anything else replaces; identity fields are reasserted after the merge"
        ),
        "triggers": opt(
            "list",
            [],
            "(KEDA only) Per-app event-driven trigger dicts: `type`, `metadata`, optional `name`, optional `auth.secret_refs`. Requires autoscaler_engine = \"keda\" in [scale.kubernetes]."
        ),
        "http_activation": opt_group(
            "(KEDA HTTP Add-on only) Per-app HTTP scale-to-zero activation. Same keys as [scale.kubernetes.http_activation]; the target Service is always this app's own generated Service. Falls back to [scale.kubernetes.http_activation]'s values for any key left unset.",
            _http_activation_nested_schema()
        )
    };
}


class JacScalePluginConfig {
    static def get_plugin_metadata -> dict[str, any] {
        return {
            "name": "scale",
            "version": "0.1.0",
            "description": "Jac Scale - Deploy and scale Jac applications with Kubernetes"
        };
    }

    static def get_config_schema -> dict[str, any] {
        return {
            "section": "scale",
            "options": {
                "sso": opt_group(
                    "SSO authentication configuration",
                    {
                        "host": opt(
                            "string", "http://localhost:8000", "SSO callback host URL"
                        ),
                        "client_auth_callback_url": opt(
                            "string",
                            "",
                            "Client-side URL the SSO flow redirects back to after provider auth"
                        ),
                        "google": opt_group(
                            "Google OAuth configuration",
                            {
                                "client_id": opt(
                                    "string", "", "Google OAuth client ID"
                                ),
                                "client_secret": opt(
                                    "string", "", "Google OAuth client secret"
                                )
                            }
                        ),
                        "apple": opt_group(
                            "Apple OAuth configuration",
                            {
                                "client_id": opt("string", "", "Apple OAuth client ID"),
                                "client_secret": opt(
                                    "string", "", "Apple OAuth client secret"
                                )
                            }
                        ),
                        "github": opt_group(
                            "GitHub OAuth configuration",
                            {
                                "client_id": opt(
                                    "string", "", "GitHub OAuth client ID"
                                ),
                                "client_secret": opt(
                                    "string", "", "GitHub OAuth client secret"
                                )
                            }
                        ),
                        "firebase": opt_group(
                            "Firebase auth configuration",
                            {
                                "project_id": opt(
                                    "string",
                                    "",
                                    "Firebase project id (also honored via env)"
                                )
                            }
                        )
                    }
                ),
                "database": opt_group(
                    "Database connection configuration",
                    {
                        "url": opt(
                            "string",
                            None,
                            "Postgres connection URL (postgresql://user:pass@host:port/db) for this process, also honored via the JAC_DB_URL env var, which wins at runtime. Setting it here (not via the env var) also makes a deploy of this app point at that database instead of provisioning one; [scale.kubernetes] database_mode overrides that."
                        ),
                        "deploy_mode": opt(
                            "string",
                            "image",
                            "How the k8s target runs Postgres: 'image' (official postgres image), 'embedded' (the app's jac image running `jac db serve`), or implicit 'external' when url is set."
                        ),
                        "postgres_image": opt(
                            "string",
                            "postgres:18",
                            "Image used in deploy_mode='image'."
                        ),
                        "postgres_storage": opt(
                            "string",
                            "2Gi",
                            "PVC size for the provisioned Postgres StatefulSet. Must be a valid Kubernetes quantity, e.g. 2Gi."
                        )
                    }
                ),
                "kubernetes": opt_group(
                    "Kubernetes deployment configuration",
                    {
                        "app_name": opt(
                            "string",
                            None,
                            "Application name for Kubernetes resources. Defaults to a k8s-safe slug of [project].name when unset, or 'jaseci' if no project name is usable"
                        ),
                        "namespace": opt(
                            "string", "default", "Kubernetes namespace for deployment"
                        ),
                        "container_port": opt(
                            "int", 8000, "Container port for the application"
                        ),
                        "database_mode": opt(
                            "string",
                            "auto",
                            "What database the DEPLOYED app gets: 'provision' (a per-app Postgres owned by jac), 'external' (point it at database_url, or [scale.database] url), 'none' (wire no database at all), or 'auto' (external when a url is configured, otherwise provision). The deploying process's own JAC_DB_URL is never consulted."
                        ),
                        "database_url": opt(
                            "string",
                            "",
                            "Connection URL handed to the deployed app in external mode. Highest precedence, above [scale.database] url. A bare Kubernetes service name is namespace-relative: set database_namespace, or write the fully qualified <service>.<namespace>.svc.cluster.local host."
                        ),
                        "database_namespace": opt(
                            "string",
                            "",
                            "Namespace that runs the external database service, used to qualify a bare service name in the url when the app deploys into a different namespace. Defaults to the deploying pod's own namespace when it can be detected."
                        ),
                        "postgres_enabled": opt(
                            "bool",
                            True,
                            "Deprecated, use database_mode. false maps to database_mode = 'none'; true is ignored because it cannot distinguish provisioning from pointing at an external database."
                        ),
                        "autoscaler_engine": opt(
                            "string",
                            "hpa",
                            "Autoscaler engine to use. Built-in: 'hpa' (default, CPU/memory only) or 'keda' (event-driven, supports scale-to-zero). External plugins can register additional engines via AutoscalerFactory.register()."
                        ),
                        "min_replicas": opt(
                            "int", 1, "Minimum pod replicas for the autoscaler."
                        ),
                        "max_replicas": opt(
                            "int", 3, "Maximum pod replicas for the autoscaler."
                        ),
                        "revision_history_limit": opt(
                            "int",
                            10,
                            "How many superseded ReplicaSets Kubernetes keeps per Deployment, which is how far back a rollback can reach. 0 keeps no history and makes a rollback impossible."
                        ),
                        "cpu_utilization_target": opt(
                            "int",
                            50,
                            "CPU utilization percentage for the HPA cpu trigger (engine='hpa') or the KEDA cpu trigger when no explicit cpu trigger is listed. Ignored when engine='keda' and at least one non-cpu trigger is configured without a cpu trigger."
                        ),
                        "memory_utilization_target": opt(
                            "int",
                            80,
                            "Memory utilization percentage (of the container memory request) for the default memory trigger, so pods scale out before hitting their memory limit instead of getting OOM-killed. Applied alongside cpu_utilization_target when no explicit triggers are configured."
                        ),
                        "autoscaler_scale_up_stabilization": opt(
                            "int",
                            60,
                            "HPA scale-up stabilization window in seconds. Prevents the Kubernetes default (double the fleet every 15s) from bursting pods faster than nodes can absorb their memory."
                        ),
                        "autoscaler_scale_up_max_pods": opt(
                            "int",
                            2,
                            "Maximum pods the autoscaler may add per minute. Rate-limits scale-up so a traffic spike cannot OOM the node with a burst of booting pods."
                        ),
                        "idle_replicas": opt(
                            "int",
                            None,
                            "(KEDA only) Replica count when all triggers go inactive. Set to 0 for scale-to-zero. Omit (null) to fall back to min_replicas."
                        ),
                        "autoscaler_polling_interval": opt(
                            "int",
                            30,
                            "(KEDA only) How often KEDA evaluates triggers, in seconds."
                        ),
                        "autoscaler_cooldown": opt(
                            "int",
                            300,
                            "Seconds of continuous inactivity before scaling down to idle_replicas (KEDA); also used as the HPA scale-down stabilization window on both engines."
                        ),
                        "autoscaler_initial_cooldown": opt(
                            "int",
                            0,
                            "(KEDA only) Delay after a fresh deploy before scale-to-zero becomes eligible. Prevents cold-start thrash on slow-booting apps."
                        ),
                        "extra_triggers": opt(
                            "list",
                            [],
                            "(KEDA only) Additional KEDA trigger dicts applied to every service. Each entry: `type` (str), `metadata` (dict[str,str]), optional `name` (str), optional `auth.secret_refs` (dict). For per-app triggers use [[apps.NAME.scale.triggers]] instead."
                        ),
                        "postgres_storage_size": opt(
                            "string",
                            "2Gi",
                            "PVC size for the provisioned Postgres StatefulSet (k8s target)"
                        ),
                        "cpu_request": opt(
                            "string",
                            None,
                            "Container CPU request for the app pod (e.g. '100m')"
                        ),
                        "cpu_limit": opt(
                            "string",
                            None,
                            "Container CPU limit for the app pod (e.g. '1000m')"
                        ),
                        "memory_request": opt(
                            "string",
                            None,
                            "Container memory request for the app pod (e.g. '128Mi')"
                        ),
                        "memory_limit": opt(
                            "string",
                            None,
                            "Container memory limit for the app pod (e.g. '1Gi')"
                        ),
                        "readiness_initial_delay": opt(
                            "int", 10, "Readiness probe initialDelaySeconds"
                        ),
                        "readiness_period": opt(
                            "int", 20, "Readiness probe periodSeconds"
                        ),
                        "liveness_initial_delay": opt(
                            "int", 10, "Liveness probe initialDelaySeconds"
                        ),
                        "liveness_period": opt(
                            "int", 20, "Liveness probe periodSeconds"
                        ),
                        "liveness_failure_threshold": opt(
                            "int", 80, "Liveness probe failureThreshold"
                        ),
                        "health_check_path": opt(
                            "string",
                            "/docs",
                            "HTTP path used for readiness/liveness probes"
                        ),
                        "python_image": opt(
                            "string",
                            "",
                            "Base container image for app pods; empty resolves the default jac image"
                        ),
                        "wait_image": opt(
                            "string", "busybox", "Image used by init/wait containers"
                        ),
                        "bundle_storage_class": opt(
                            "string",
                            "",
                            "StorageClass for the code-bundle PVC; empty uses the cluster default"
                        ),
                        "bundle_access_mode": opt(
                            "string",
                            "ReadWriteMany",
                            "Access mode for the code-bundle PVC"
                        ),
                        "resource_deletion_wait": opt(
                            "int",
                            5,
                            "Seconds to wait between resource deletions on destroy"
                        ),
                        "aws_nlb_wait": opt(
                            "int",
                            60,
                            "Seconds to wait for an AWS NLB to become reachable"
                        ),
                        "app_mount_path": opt(
                            "string",
                            "/app",
                            "Mount path for the application volume inside pods"
                        ),
                        "code_mount_path": opt(
                            "string",
                            "/code",
                            "Mount path for the code bundle volume inside pods"
                        ),
                        "workspace_path": opt(
                            "string",
                            "/code/workspace",
                            "Working directory for the app inside pods"
                        ),
                        "additional_packages": opt(
                            "list",
                            [],
                            "Extra pip packages installed into app pods at startup"
                        ),
                        "loki_enabled": opt(
                            "bool",
                            False,
                            "Deploy the Loki + Alloy log pipeline (see [scale.gateway.logs])"
                        ),
                        "tracing_enabled": opt(
                            "bool",
                            False,
                            "Deploy the tracing stack (see [scale.gateway.tracing])"
                        ),
                        "ingress_node_port": opt(
                            "int",
                            30080,
                            "NodePort used when exposing the app without a LoadBalancer"
                        ),
                        "shared_ingress": opt(
                            "bool",
                            False,
                            "Join a cluster-shared ingress instead of provisioning a dedicated one"
                        ),
                        "shared_ingress_class": opt(
                            "string",
                            "nginx",
                            "IngressClass used when shared_ingress is enabled"
                        ),
                        "shared_ingress_annotations": opt(
                            "dict",
                            {},
                            "Extra annotations applied to the shared ingress"
                        ),
                        "shared_ingress_tls": opt(
                            "bool", False, "Enable TLS on the shared ingress"
                        ),
                        "shared_ingress_skip_reachability": opt(
                            "bool",
                            False,
                            "Skip the post-deploy reachability probe for the shared ingress"
                        ),
                        "ingress_limit_rps": opt(
                            "int",
                            20,
                            "Ingress rate limit: requests per second per client"
                        ),
                        "ingress_limit_burst_multiplier": opt(
                            "int", 5, "Ingress rate limit burst multiplier"
                        ),
                        "ingress_limit_connections": opt(
                            "int", 20, "Ingress concurrent connection limit per client"
                        ),
                        "ingress_session_affinity": opt(
                            "bool",
                            True,
                            "Enable cookie-based session affinity on the ingress"
                        ),
                        "domain": opt(
                            "string",
                            "",
                            "Public domain for the deployment (enables host-based ingress rules)"
                        ),
                        "cert_manager_email": opt(
                            "string",
                            "",
                            "Email used for cert-manager ACME registration when TLS is enabled"
                        ),
                        "service_account_name": opt(
                            "string",
                            "",
                            "ServiceAccount assigned to app pods; empty uses the namespace default"
                        ),
                        "ops_console": opt(
                            "bool", False, "Deploy the experimental ops console"
                        ),
                        "ops_console_mutations": opt(
                            "bool",
                            False,
                            "Allow mutating operations from the ops console"
                        ),
                        "kube_context": opt(
                            "string",
                            "",
                            "kubectl context to deploy with; empty uses the active context"
                        ),
                        "kubeconfig": opt(
                            "string",
                            "",
                            "Path to an explicit kubeconfig file; empty uses the default resolution"
                        ),
                        "labels": opt(
                            "dict",
                            {},
                            "Extra labels applied to every generated Kubernetes resource"
                        ),
                        "http_activation": opt_group(
                            "KEDA HTTP Add-on scale-to-zero activation defaults shared by every fleet app unless overridden per app. Requires the KEDA HTTP Add-on installed separately from core KEDA. For per-app activation use [apps.NAME.scale.http_activation] instead.",
                            _http_activation_nested_schema()
                        )
                    }
                ),
                "secrets": opt(
                    "dict",
                    {},
                    "Environment variable secrets for K8s deployment. Values use ${ENV_VAR} syntax, resolved at deploy time and created as a K8s Secret with envFrom.secretRef."
                ),
                "server": opt_group(
                    "Serving-process logging. Listener, worker, limit and timeout settings live in [serve]",
                    {
                        "structured_logs": opt(
                            "bool",
                            True,
                            "Install jac-scale's JSON log handler on the root logger at serving startup (the format Kubernetes pod log collection expects). Set false when embedding jac-scale in an application that owns its own logging configuration: handlers, levels and formatters are then left untouched."
                        )
                    }
                ),
                "gateway": opt_group(
                    "The gateway that fronts a workspace's service apps: its port, host, drain and forward timeouts, boot budgets, rate limiting, CORS, identity ownership, ingress, observability lanes, shared volumes and the pod settings of the gateway itself. Which apps are services is declared by [apps.<name>] kind = \"service\" (route = /api/<name> by default); per-app overrides live in [apps.<name>.scale].",
                    {
                        "colocate": opt(
                            "bool",
                            True,
                            "Serve the workspace's service apps inside the served app's process (bridged calls stay in-process). Set false to run them as separate local processes behind the gateway on every `jac run`; `jac run --fleet` does the same for one run. Deploys always run as a fleet and ignore this key."
                        ),
                        "gateway_port": opt(
                            "int", 8000, "Gateway port (external-facing)"
                        ),
                        "gateway_host": opt("string", "0.0.0.0", "Gateway host"),
                        "http_forward_timeout": opt(
                            "float",
                            30.0,
                            "Gateway-to-app forward timeout (seconds). Applies to `raw_forward` (built-in passthrough fan-out) and `stream_forward` (path-routed proxy). Distinct from an app's `rpc_timeout`, which controls app-to-app RPC calls. Override per app with [apps.NAME.scale] http_forward_timeout."
                        ),
                        "boot_health_timeout": opt(
                            "float",
                            None,
                            "How long a service app process may take to answer /healthz before it is given up on (seconds); absent uses the process manager default (60). Raise it for apps with an expensive import graph."
                        ),
                        "boot_max_wait": opt(
                            "int",
                            90,
                            "Overall window (seconds) the orchestrator waits for the whole fleet to report healthy at boot before it proceeds anyway. Distinct from `boot_health_timeout`, which is per app."
                        ),
                        "health_monitor_interval": opt(
                            "float",
                            None,
                            "Cadence (seconds) of the background health check that restarts fleet members which died after boot; absent uses the process manager default (10). While any member is not healthy the monitor polls at 2s regardless, and steps back to this cadence once the fleet settles."
                        ),
                        "app_boot_timeout": opt(
                            "float",
                            900.0,
                            "How long the orchestrator waits for the served app (the fleet's root member) to finish booting before it starts the service apps (seconds). The root member compiles the client, and a module another member analyzed first reaches the client backend with its calls unresolved, so it goes first and alone. Like `boot_health_timeout` this is a stall budget, not a wall-clock cap: while the member is still writing to its log the clock resets, so a cold client build is not cut off. Only applies when the root member serves a client (a local `--fleet` run of a web-app); a headless fleet starts every member in parallel."
                        ),
                        "route_refresh_seconds": opt(
                            "float",
                            None,
                            "How often (seconds) the gateway re-reads each member's /openapi.json to learn the root paths it declares; absent uses the default (30)."
                        ),
                        "identity": opt_group(
                            "Who owns user records in a fleet. The gateway serves /user/register and /user/login, so a session token it mints names a user that only the gateway's store knows; an app receiving that token has no local record for the subject.",
                            {
                                "gateway_owned": opt(
                                    "bool",
                                    True,
                                    "A fleet app that receives a signature-valid, unexpired token for a user it does not know provisions that user's root once, instead of rejecting the request. Set false when a deployment manages identity itself and an app should reject unknown subjects."
                                )
                            }
                        ),
                        "ingress": opt_group(
                            "Optional K8s Ingress for the gateway. Default off (no Ingress emitted) so existing deployments don't grow one unexpectedly. HTTP only - TLS via cert-manager / ACM is deployment-specific. Routes all external traffic to gateway-service:container_port; the gateway dispatches each app's route (/api/<name> by default) internally and everything else to the served app.",
                            {
                                "enabled": opt(
                                    "bool",
                                    False,
                                    "Emit an Ingress manifest for the gateway (opt-in)"
                                ),
                                "host": opt(
                                    "string",
                                    None,
                                    "Ingress host rule; omitted means match-any-host"
                                ),
                                "ingress_class_name": opt(
                                    "string",
                                    None,
                                    "IngressClass, e.g. 'nginx', 'alb', 'gce'"
                                ),
                                "annotations": opt(
                                    "dict",
                                    {},
                                    "Controller-specific annotations, e.g. nginx.ingress.kubernetes.io/proxy-body-size"
                                )
                            }
                        ),
                        "rate_limit": opt_group(
                            "Gateway rate limiting (token bucket). Disabled unless `enabled = true`.",
                            {
                                "enabled": opt("bool", False, "Master switch."),
                                "per_ip_rpm": opt(
                                    "int",
                                    60,
                                    "Requests per minute per client IP. 0 disables per-IP limit."
                                ),
                                "per_user_rpm": opt(
                                    "int",
                                    0,
                                    "Additional requests per minute per authenticated user (keyed by Authorization header hash). 0 disables per-user limit."
                                ),
                                "burst_multiplier": opt(
                                    "float",
                                    2.0,
                                    "Bucket capacity = rpm * burst_multiplier / 60 (allows short bursts above the steady rate)."
                                ),
                                "shared": opt(
                                    "bool",
                                    True,
                                    "Keep buckets in the project database so the limit is enforced once across every gateway process and replica. false keeps buckets in process memory, which only makes sense for a single-process dev gateway."
                                ),
                                "exempt_paths": opt(
                                    "list",
                                    ["/health", "/healthz", "/metrics"],
                                    "Paths that bypass rate limiting entirely (monitoring + probes)."
                                ),

                            }
                        ),
                        "cors": opt_group(
                            "CORS middleware on the gateway. Open by default (any origin). Set `allow_origins = []` to disable, or provide a concrete list to restrict.",
                            {
                                "allow_origins": opt(
                                    "list",
                                    ["*"],
                                    "Origins that may access the gateway. Default [\"*\"] allows any. Empty list disables CORS."
                                ),
                                "allow_methods": opt(
                                    "list",
                                    ["*"],
                                    "HTTP methods allowed on cross-origin requests."
                                ),
                                "allow_headers": opt(
                                    "list",
                                    ["*"],
                                    "Request headers allowed on cross-origin requests."
                                ),
                                "allow_credentials": opt(
                                    "bool",
                                    False,
                                    "Allow cookies / Authorization on cross-origin requests. Incompatible with allow_origins = [\"*\"] per spec."
                                ),
                                "expose_headers": opt(
                                    "list",
                                    [],
                                    "Response headers the browser is allowed to read across origins."
                                ),
                                "max_age": opt(
                                    "int",
                                    600,
                                    "How long (seconds) the browser may cache a preflight response."
                                )
                            }
                        ),
                        "logs": opt_group(
                            "Centralised log aggregation via Loki + Grafana Alloy (M-14). Off by default. When enabled, deploys the full monitoring stack (Prometheus + Grafana + Loki + Alloy) into the app namespace; Alloy tails every pod's stdout/stderr from `/var/log/pods` and ships to Loki, queried via Grafana's `Pod Logs` dashboard. v0 uses ephemeral `emptyDir` for Loki storage (suitable for dev/staging); persistent backends land in M-14.c. **Multi-tenant note**: Alloy's ClusterRole reads pods cluster-wide and the dashboard query is `{namespace=~\".+\"}`, so anyone with Grafana access sees logs from every namespace - change the default Grafana password and only enable on clusters where this exposure is acceptable.",
                            {
                                "enabled": opt(
                                    "bool",
                                    False,
                                    "Enable the Loki + Alloy logging pipeline. Implies the full monitoring stack (Prometheus + Grafana) because the Pod Logs dashboard view lives in Grafana."
                                )
                            }
                        ),
                        "tracing": opt_group(
                            "Distributed tracing for the gateway and every fleet app. Off by default.",
                            {
                                "enabled": opt("bool", False, "Enable trace emission"),
                                "endpoint": opt(
                                    "string",
                                    None,
                                    "Collector endpoint traces are shipped to"
                                ),
                                "sample_ratio": opt(
                                    "float",
                                    1.0,
                                    "Fraction of requests to trace (0.0-1.0)"
                                )
                            }
                        ),
                        "shared_volumes": opt(
                            "list",
                            [],
                            "Volume declarations mounted into fleet pods; each entry names the apps that mount it under `apps`."
                        ),
                        "replicas": opt(
                            "int", 1, "K8s Deployment.spec.replicas for the gateway pod"
                        ),
                        "cpu_request": opt(
                            "string", None, "Gateway container CPU request, e.g. '100m'"
                        ),
                        "cpu_limit": opt(
                            "string", None, "Gateway container CPU limit, e.g. '2000m'"
                        ),
                        "memory_request": opt(
                            "string",
                            None,
                            "Gateway container memory request, e.g. '128Mi'"
                        ),
                        "memory_limit": opt(
                            "string", None, "Gateway container memory limit, e.g. '4Gi'"
                        ),
                        "env": opt(
                            "dict", {}, "Extra container env vars for the gateway pod"
                        ),
                        "hpa": opt(
                            "dict",
                            {},
                            "Gateway autoscaler settings; same keys as [apps.NAME.scale.hpa]"
                        ),
                        "pdb": opt(
                            "dict",
                            {},
                            "Gateway PodDisruptionBudget settings; same keys as [apps.NAME.scale.pdb]"
                        ),
                        "deployment_overlay": opt(
                            "dict",
                            {},
                            "Raw Deployment-manifest fragment merged into the generated gateway manifest"
                        )
                    }
                ),
                "websocket": opt_group(
                    "WebSocket serving limits and the cross-pod broadcast backplane",
                    {
                        "backplane": opt(
                            "string",
                            None,
                            "Broadcast backplane: 'memory' (single-pod, in-process fan-out) or 'pg' (cross-pod fan-out over Postgres LISTEN/NOTIFY). Unset auto-selects 'pg' when a scale database resolves, else 'memory'."
                        ),
                        "max_message_bytes": opt(
                            "int",
                            65536,
                            "Maximum decoded inbound WebSocket message size in bytes; larger messages are rejected and the connection closed."
                        ),
                        "max_connections_per_target": opt(
                            "int",
                            5000,
                            "Maximum concurrent connections per WebSocket target (walker or function endpoint)."
                        ),
                        "max_connections_per_user": opt(
                            "int",
                            10,
                            "Maximum concurrent WebSocket connections per authenticated user."
                        ),
                        "max_anonymous_per_target": opt(
                            "int",
                            100,
                            "Maximum concurrent anonymous (unauthenticated) connections per target."
                        ),
                        "target_timeout_seconds": opt(
                            "float",
                            30,
                            "Per-invocation timeout in seconds for the walker/function handling a WebSocket message."
                        ),
                        "messages_per_second": opt(
                            "float",
                            20,
                            "Per-connection inbound message rate limit (token bucket refill rate)."
                        )
                    }
                ),
                "events": opt_group(
                    "Event-streaming broker configuration. Off by default. When enabled, jac-scale exposes publish() / @subscribe via the active stream (PostgresEventStream when a database URL resolves, otherwise LocalEventStream in-memory).",
                    {
                        "enabled": opt(
                            "bool",
                            False,
                            "Enable the event-streaming broker. When false, all publish() calls become no-ops."
                        ),
                        "url": opt(
                            "string",
                            None,
                            "Postgres connection URL for the event stream. If unset, falls back to [scale.database].url / JAC_DB_URL. With no database, LocalEventStream (in-memory) is used."
                        ),
                        "consumer_group": opt(
                            "string",
                            "jac-scale",
                            "Default consumer group name used when @subscribe does not specify one."
                        ),
                        "serializer": opt(
                            "string",
                            "json",
                            "Payload serializer: 'json' (default) or 'msgpack' (requires extra)."
                        ),
                        "retry": opt_group(
                            "Default retry policy applied when a subscription does not provide its own.",
                            {
                                "max_attempts": opt(
                                    "int",
                                    3,
                                    "Number of delivery attempts before the message is sent to the dead-letter topic."
                                ),
                                "backoff_seconds": opt(
                                    "list",
                                    [1.0, 5.0, 30.0],
                                    "Backoff delays per attempt index, clamped to the last value."
                                ),
                                "dead_letter_suffix": opt(
                                    "string",
                                    ".dlq",
                                    "Suffix appended to the topic name to form its dead-letter topic."
                                )
                            }
                        )
                    }
                ),
                "monitoring": opt_group(
                    "Monitoring configuration for the HTTP /metrics endpoint and Kubernetes Prometheus + Grafana stack",
                    {
                        "enabled": opt(
                            "bool",
                            False,
                            "Enable Prometheus metrics collection, /metrics endpoint, and Kubernetes monitoring stack"
                        ),
                        "endpoint": opt(
                            "string",
                            "/metrics",
                            "Path for the Prometheus metrics endpoint"
                        ),
                        "namespace": opt(
                            "string",
                            "jaclang_scale",
                            "Metrics namespace prefix (e.g., myapp_http_requests_total). Sanitized to [a-zA-Z0-9_] before use; a rewritten value logs a warning at startup"
                        ),
                        "walker_metrics": opt(
                            "bool", False, "Enable walker execution timing metrics"
                        ),
                        "histogram_buckets": opt(
                            "list",
                            [
                                0.005,
                                0.01,
                                0.025,
                                0.05,
                                0.075,
                                0.1,
                                0.25,
                                0.5,
                                0.75,
                                1.0,
                                2.5,
                                5.0,
                                10.0
                            ],
                            "Histogram bucket boundaries in seconds for latency metrics"
                        ),
                        "prometheus_admin_password": opt(
                            "string",
                            "Adminpassword123",
                            "Admin password for Grafana when deploying the monitoring stack"
                        ),
                        "k8s_metrics_enabled": opt(
                            "bool",
                            True,
                            "Deploy the Kubernetes monitoring stack (Prometheus + Grafana) alongside the app"
                        )
                    }
                ),
                "webhook": opt_group(
                    "Inbound webhook verification and limits",
                    {
                        "secret": opt(
                            "string",
                            "webhook-secret-key",
                            "Shared secret used to verify webhook signatures"
                        ),
                        "signature_header": opt(
                            "string",
                            "X-Webhook-Signature",
                            "Header carrying the webhook signature"
                        ),
                        "timestamp_header": opt(
                            "string",
                            "X-Webhook-Timestamp",
                            "Header carrying the webhook timestamp"
                        ),
                        "verify_signature": opt(
                            "bool",
                            True,
                            "Reject webhooks whose signature does not verify"
                        ),
                        "replay_tolerance_seconds": opt(
                            "int",
                            300,
                            "Maximum allowed clock skew before a webhook is treated as a replay"
                        ),
                        "max_body_bytes": opt(
                            "int", 1048576, "Maximum webhook body size in bytes"
                        ),
                        "rate_limit_per_minute": opt(
                            "int", 0, "Webhook rate limit per minute; 0 disables"
                        ),
                        "api_key_expiry_days": opt(
                            "int", 365, "Lifetime of generated webhook API keys in days"
                        ),
                        "github_secret": opt(
                            "string",
                            "",
                            "Secret that scheme=\"github\" webhook walkers verify X-Hub-Signature-256 against; the GitHub App's webhook secret"
                        ),
                        "github_signature_header": opt(
                            "string",
                            "X-Hub-Signature-256",
                            "Header carrying the GitHub-style signature for scheme=\"github\" walkers"
                        )
                    }
                ),
                "admin": opt_group(
                    "Bootstrap admin account configuration",
                    {
                        "enabled": opt(
                            "bool",
                            True,
                            "Create the bootstrap admin user on first start"
                        ),
                        "username": opt("string", "admin", "Admin username"),
                        "email": opt(
                            "string", "admin@localhost", "Admin email address"
                        ),
                        "default_password": opt(
                            "string",
                            "changeme",
                            "Initial admin password; must be rotated on first login by default"
                        ),
                        "session_expiry_hours": opt(
                            "int", 24, "Admin session lifetime in hours"
                        ),
                        "require_password_reset": opt(
                            "bool", True, "Force a password change on first admin login"
                        )
                    }
                ),
                "scheduler": opt_group(
                    "Scheduled-job runner configuration",
                    {
                        "enabled": opt(
                            "bool",
                            None,
                            "Declares scheduler use; read at install time for capability detection"
                        ),
                        "collection": opt(
                            "string",
                            "scheduled_jobs",
                            "Collection name where job state is persisted"
                        ),
                        "thread_pool_size": opt(
                            "int", 10, "Worker threads available to the scheduler"
                        ),
                        "misfire_grace_time": opt(
                            "int",
                            60,
                            "Seconds a job may fire late before it is skipped"
                        ),
                        "shutdown_timeout": opt(
                            "int", 10, "Seconds to wait for running jobs on shutdown"
                        ),
                        "system_user_password": opt(
                            "string",
                            "__no_login__",
                            "Password for the internal scheduler system user"
                        ),
                        "user_exists_ttl": opt(
                            "float",
                            30.0,
                            "Seconds the scheduler caches user-existence checks"
                        )
                    }
                ),
                "telemetry": opt_group(
                    "In-process telemetry buffer configuration",
                    {
                        "max_traces": opt(
                            "int", 1000, "Maximum traces retained in memory"
                        )
                    }
                ),
                "emailer": opt_group(
                    "Outbound email (password reset, verification) configuration",
                    {
                        "provider": opt(
                            "string",
                            "",
                            "Emailer provider: empty disables email; 'smtp' or a custom 'module.path:ClassName' enables it"
                        ),
                        "enabled": opt("bool", True, "Enable outbound email"),
                        "from_address": opt(
                            "string", "", "From address on outbound mail"
                        ),
                        "smtp": opt_group(
                            "SMTP transport settings",
                            {
                                "host": opt("string", "localhost", "SMTP server host"),
                                "port": opt("int", 25, "SMTP server port"),
                                "username": opt("string", "", "SMTP username"),
                                "password": opt(
                                    "string",
                                    "",
                                    "SMTP password (EMAILER_SMTP_PASSWORD env overrides)"
                                ),
                                "use_tls": opt("bool", True, "Use STARTTLS"),
                                "timeout": opt(
                                    "float", 10.0, "SMTP connection timeout in seconds"
                                )
                            }
                        )
                    }
                ),
                "auth": opt_group(
                    "Password-auth token and rate-limit configuration",
                    {
                        "reset_token_ttl_seconds": opt(
                            "int", 1800, "Password-reset token lifetime in seconds"
                        ),
                        "verify_token_ttl_seconds": opt(
                            "int", 86400, "Email-verification token lifetime in seconds"
                        ),
                        "reset_url_template": opt(
                            "string",
                            "",
                            "URL template embedded in password-reset emails"
                        ),
                        "verify_url_template": opt(
                            "string", "", "URL template embedded in verification emails"
                        ),
                        "token_collection": opt(
                            "string",
                            "auth_tokens",
                            "Collection name where auth tokens are persisted"
                        ),
                        "forgot_password_rate_per_hour": opt(
                            "int",
                            3,
                            "Forgot-password requests allowed per hour per account"
                        ),
                        "forgot_password_burst": opt(
                            "int", 3, "Forgot-password burst allowance"
                        ),
                        "send_verification_rate_per_hour": opt(
                            "int", 5, "Verification emails allowed per hour per account"
                        ),
                        "send_verification_burst": opt(
                            "int", 5, "Verification email burst allowance"
                        )
                    }
                ),
                "storage": opt(
                    "dict",
                    {},
                    "Persistence storage backend configuration (e.g. backend, type); read at install time for capability detection. Keys are backend-specific and not validated."
                ),
                "deploy": opt(
                    "dict",
                    {},
                    "Deploy intent (e.g. target = 'kubernetes'); read at install time for capability detection. Keys are target-specific and not validated."
                ),
                "tracing": opt(
                    "dict",
                    {},
                    "Tracing intent (enabled = true installs the tracing extras at install time); runtime tracing settings live under [scale.gateway.tracing]."
                ),
                "fat_bundle": opt(
                    "bool",
                    None,
                    "Bundle all dependencies into the deploy artifact; absent lets the deploy pipeline decide"
                ),
                "seal_timeout": opt(
                    "int",
                    None,
                    "Seconds to wait for the code bundle to seal before deploy fails"
                )
            }
        };
    }
}
