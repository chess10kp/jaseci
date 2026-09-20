impl KubernetesTarget._gateway_cfg -> dict[str, any] {
    import from jaclang.scale.config.config_loader { normalize_gateway_config }
    if self.gateway_config is not None {
        return normalize_gateway_config(self.gateway_config);
    }
    return get_scale_config().get_gateway_config();
}


impl KubernetesTarget.deploy(app_config: AppConfig) -> DeploymentResult {
    app_name = app_config.app_name or self.k8s_config.app_name;
    if self.k8s_config.shared_ingress and not self.k8s_config.domain {
        return DeploymentResult(
            success=False,
            message="shared_ingress=True requires a domain: set 'domain' "
            "under [scale.kubernetes] in jac.toml."
        );
    }
    import from jaclang.scale.injector.binary { deploy_generation_refusal }
    refusal = deploy_generation_refusal(app_config.code_folder);
    if refusal {
        return DeploymentResult(success=False, message=refusal);
    }
    if self.logger {
        self.logger.info(
            f"Deploying app '{app_name}' to Kubernetes",
            {"namespace": self.k8s_config.namespace}
        );
    }

    if not self.dry_run {
        self._emit("runtime", "start", "Resolving the pod jac runtime");
        try {
            import from jaclang.scale.config.dev_config { resolve_dev_channel }
            import from jaclang.scale.injector.binary {
                node_arch,
                preflight_pod_runtime
            }
            self._load_cluster_config();
            pinned = preflight_pod_runtime(
                app_config.code_folder,
                resolve_dev_channel(app_config.code_folder).value,
                node_arch()
            );
        } except Exception as e {
            self._emit("runtime", "error", str(e));
            return DeploymentResult(success=False, message=str(e));
        }
        self._emit(
            "runtime",
            "ok",
            f"Pod runtime jac {pinned}" if pinned else "Pod runtime resolved"
        );
    }

    self._emit("config", "start", "Checking the config the pods load");
    try {
        self._manifest_builder(app_config).check_pod_config(
            app_config, self.k8s_config.python_image
        );
    } except Exception as e {
        self._emit("config", "error", f"pod config check failed: {e}");
        return DeploymentResult(success=False, message=f"pod config check failed: {e}");
    }
    self._emit("config", "ok", "Pod config resolves");

    self._emit("provision", "start", "Provisioning backends");
    try {
        self._deploy_context = DatabaseProvisioner(
            k8s_target=self, logger=self.logger
        ).provision(
            app_name
        );
    } except Exception as e {
        self._emit("provision", "error", f"database provisioning failed: {e}");
        return DeploymentResult(
            success=False, message=f"database provisioning failed: {e}"
        );
    }
    self._emit("provision", "ok", "Backends provisioned");

    self._emit("bundle", "start", "Generating manifests");
    try {
        bundle = self.generate_manifests(app_config);
    } except Exception as e {
        self._emit("bundle", "error", f"manifest generation failed: {e}");
        return DeploymentResult(
            success=False, message=f"manifest generation failed: {e}"
        );
    }
    self._emit(
        "bundle",
        "ok",
        "Manifests generated",
        detail={"services": len(bundle.get("pod_specs", {}))}
    );

    self._emit("apply", "start", "Applying manifests to the cluster");
    try {
        self.apply_manifests(bundle);
    } except Exception as e {
        self._emit("apply", "error", f"manifest apply failed: {e}");
        return DeploymentResult(
            success=False, message=f"manifest apply failed: {e}", details=bundle
        );
    }
    self._emit("apply", "ok", "Manifests applied");

    observability_err: str = "";
    try {
        self._deploy_observability(app_name);
    } except Exception as e {
        observability_err = str(e);
        bundle["observability_error"] = observability_err;
        self._emit("observability", "warn", f"observability stack deploy failed: {e}");
        if self.logger {
            self.logger.warn(
                f"Observability stack deploy reported a non-fatal error: {e}",
                {"app_name": app_name}
            );
        }
    }

    self._emit("rollout", "start", "Waiting for the fleet to become ready");
    try {
        self._wait_for_fleet_rollout(bundle);
    } except Exception as e {
        self._emit("rollout", "error", f"fleet did not become ready: {e}");
        return DeploymentResult(
            success=False, message=f"fleet did not become ready: {e}", details=bundle
        );
    }
    self._emit("rollout", "ok", "Fleet is ready");

    service_url = self.get_service_url(app_name) if bundle.get("ingress") else None;
    access_hint = None if service_url else self.port_forward_hint();

    svc_count = len(bundle["pod_specs"]) - 1;
    success_msg = (
        f"Applied {svc_count} service Deployment+Service pair(s) "
        f"plus 1 gateway in namespace '{self.k8s_config.namespace}'."
    );

    if observability_err {
        success_msg = (
            f"{success_msg} "
            f"NOTE: observability stack deploy failed - "
            f"`{observability_err}`. The app is running but pod logs "
            f"are not being shipped to Loki. Re-run `jac scale deploy <file.jac>` "
            f"once the underlying issue is fixed."
        );
    }
    return DeploymentResult(
        success=True,
        service_url=service_url,
        access_hint=access_hint,
        message=success_msg,
        details=bundle
    );
}


impl KubernetesTarget._scan_for_crash_loop(
    core_v1: any,
    ns: str,
    current_hashes: set,
    fleet_app_names: set,
    companion_app_names: set | None = None
) -> dict[str, any] {
    imagepull_reasons: set = {"ImagePullBackOff", "ErrImagePull", "InvalidImageName"};
    transient_reasons: set = {"PodInitializing", "ContainerCreating"};
    crash = "";
    crash_pod = None;
    pulls: dict[str, any] = {};
    creating: dict[str, any] = {};
    phases: list[str] = [];
    states: list[str] = [];
    try {
        for p in core_v1.list_namespaced_pod(namespace=ns).items {
            if p.metadata?.deletion_timestamp is not None {
                continue;
            }
            pod_name = str(p.metadata.name);
            labels: dict[str, any] = p.metadata.labels or {};
            app = str(labels.get("app", ""));
            in_fleet = (app in fleet_app_names) if fleet_app_names else True;
            if current_hashes and app in fleet_app_names {
                pod_hash = labels.get("pod-template-hash");
                if pod_hash is not None and pod_hash not in current_hashes {
                    continue;
                }
            }
            phase = str(p.status.phase or '?');
            statuses: list[any] = list(p.status.init_container_statuses or [])
                + list(p.status.container_statuses or []);
            pod_reason = "";
            pod_crash = "";
            pod_crash_restarts = 0;
            pod_pull = "";
            pod_pull_reason = "";
            for cs in statuses {
                waiting = cs.state.waiting if cs.state else None;
                reason = (waiting.reason if waiting else "") or "";
                restarts = cs.restart_count or 0;
                states.append(f"{pod_name}/{cs.name}={phase}/{reason}/{restarts}");
                if reason and reason not in transient_reasons {
                    pod_reason = reason;
                }

                owned = in_fleet
                    or (companion_app_names is not None and app in companion_app_names);
                crashing = owned and restarts >= 3 and reason not in imagepull_reasons;
                if crashing and not pod_crash {
                    pod_crash = str(cs.name);
                    pod_crash_restarts = restarts;
                } elif reason in imagepull_reasons and not pod_pull and in_fleet {
                    pod_pull = str(cs.name);
                    pod_pull_reason = reason;
                }
            }
            if pod_pull {
                pulls[pod_name] = (pod_pull, pod_pull_reason, p);
            }

            reasons = [
                str(
                    (cs.state.waiting.reason if cs.state and cs.state.waiting else "")
                        or ""
                ) for cs in statuses
            ];
            stuck_creating = (
                bool(statuses)
                and not pod_reason
                and not pod_pull
                and ("ContainerCreating" in reasons)
                and ("PodInitializing" not in reasons)
            );
            if phase == "Pending" and stuck_creating and in_fleet {
                creating[pod_name] = p;
            }
            if pod_crash and not crash {
                crash = (
                    f"pod '{pod_name}' container '{pod_crash}' "
                    f"crash-looping ({pod_crash_restarts} restarts)"
                );
                crash_pod = p;
            }
            if app {
                token = f"{app}={phase}";
                if pod_reason {
                    token = f"{app}={phase}/{pod_reason}";
                }
                phases.append(token);
            }
        }
    } except Exception {
        _ = 0;
    }
    return {
        "crash": crash,
        "crash_pod": crash_pod,
        "pulls": pulls,
        "creating": creating,
        "phases": phases,
        "states": states
    };
}


impl KubernetesTarget._pod_mount_wedged(core_v1: any, ns: str, pod_name: str) -> bool {
    import from datetime { datetime, timezone }
    try {
        evs = core_v1.list_namespaced_event(
            namespace=ns, field_selector=f"involvedObject.name={pod_name}"
        ).items;
    } except Exception {
        return False;
    }
    now = datetime.now(timezone.utc);
    for e in evs {
        if str(e.reason or "") not in {"FailedMount", "FailedAttachVolume"} {
            continue;
        }

        ts = e.last_timestamp or e.event_time or e.first_timestamp;
        if ts is None {
            continue;
        }
        try {
            age = (now - ts).total_seconds();
        } except Exception {
            continue;
        }
        if age <= 360 {
            return True;
        }
    }
    return False;
}


impl KubernetesTarget._try_self_heal(
    core_v1: any, ns: str, pod: any, why: str, healed_apps: dict[str, int]
) -> bool {
    app = str((pod.metadata.labels or {}).get("app", "")) or str(pod.metadata.name);
    if healed_apps.get(app, 0) >= 1 or sum(healed_apps.values()) >= 3 {
        return False;
    }
    pod_name = str(pod.metadata.name);
    try {
        core_v1.delete_namespaced_pod(name=pod_name, namespace=ns);
    } except Exception {
        return False;
    }
    healed_apps[app] = healed_apps.get(app, 0) + 1;
    if self.logger {
        self.logger.warn(
            f"Self-heal: deleted wedged pod '{pod_name}' ({why}); "
            f"its ReplicaSet schedules a replacement. One retry per "
            f"service, then the rollout fails as usual.",
            {"namespace": ns, "app": app}
        );
    }
    return True;
}


impl KubernetesTarget._wait_for_fleet_rollout(
    bundle: dict[str, any], timeout: int = 1200, require_full: bool = False
) -> None {
    import time;
    import sys;
    import from kubernetes { client }
    import from jaclang.cli.console { console }

    scaling: dict[str, any] = bundle.get("scaling", {});
    http_activation_svc_names: set = {
        str(svc_name)
        for svc_name in scaling.keys()
        if dict(scaling.get(svc_name, {})).get("mode") == ScalingMode.HTTP_ACTIVATION
    };
    names: list[str] = [];
    app_labels: list[str] = [];
    for (svc_name, dep) in bundle.get("deployments", {}).items() {
        app: str = "";
        try {
            app = str(dep["spec"]["selector"]["matchLabels"]["app"]);
        } except Exception {}
        if not app {
            try {
                app = str((dep["metadata"].get("labels") or {}).get("app") or "");
            } except Exception {}
        }
        if app {
            app_labels.append(app);
        }
        if svc_name not in http_activation_svc_names {
            names.append(str(dep["metadata"]["name"]));
        }
    }
    if not names {
        self._load_cluster_config();
        core_v1 = client.CoreV1Api();
        ns = self.k8s_config.namespace;
        crash = self._scan_for_crash_loop(core_v1, ns, set(), set(app_labels))["crash"];
        if crash {
            raise Exception(
                "Deployment failed: application pods are restarting "
                "(crash loop / bad image); not marking the fleet ready."
            );
        }
        if self.logger {
            self.logger.info(
                "Fleet ready: all services use HTTP activation "
                "(scale to zero until first request); pods healthy."
            );
        }
        return;
    }
    self._load_cluster_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();
    ns = self.k8s_config.namespace;
    total = len(names);
    elapsed = 0;
    ready = 0;
    interactive = bool(sys.stdout.isatty());
    fleet_apps: set = set(app_labels);

    app_name = str(self.k8s_config.app_name or "");
    companion_apps: set = {f"{app_name}-postgres"} if app_name else set();
    pod_selector = "app in ({})".format(", ".join(app_labels)) if app_labels else None;
    imagepull_streak: dict[str, int] = {};
    creating_streak: dict[str, int] = {};
    healed_apps: dict[str, int] = {};
    last_sig = "";
    last_heartbeat = -90;

    current_hashes: set = set();
    if pod_selector {
        try {
            current_hashes = _resolve_current_rs_hashes(ns, pod_selector);
        } except Exception as exc {
            console.print(
                f"[warn] RS hash lookup failed, falling back to broad pod "
                f"scan: {exc}"
            );
        }
    }

    with console.status(f"Rolling out fleet: 0/{total} services ready...") as st {
        while elapsed < timeout {
            ready = 0;
            for name in names {
                try {
                    d = apps_v1.read_namespaced_deployment(name=name, namespace=ns);
                    complete = deployment_rollout_complete(d)
                        if require_full
                        else (d.status.ready_replicas or 0) >= 1;
                    if complete {
                        ready += 1;
                    }
                } except Exception {
                    _ = 0;
                }
            }
            if ready == total {
                if self.logger {
                    self.logger.info(
                        f"Fleet ready: {ready}/{total} deployments serving"
                    );
                }
                return;
            }

            scan = self._scan_for_crash_loop(
                core_v1, ns, current_hashes, fleet_apps, companion_apps
            );
            phase_tokens = scan["phases"];
            state_tokens = scan["states"];
            crash_failure = scan["crash"];
            crash_pod = scan["crash_pod"];

            if crash_failure and pod_selector {
                refreshed = _refresh_rs_hashes(ns, pod_selector, current_hashes);
                current_hashes = refreshed or set();
                recheck = self._scan_for_crash_loop(
                    core_v1, ns, current_hashes, fleet_apps, companion_apps
                );
                crash_failure = recheck["crash"];
                crash_pod = recheck["crash_pod"];
            }

            pulls: dict[str, tuple[str, str, any]] = scan["pulls"];
            imagepull_streak = {k: imagepull_streak.get(k, 0) + 1 for k in pulls};
            pull_failure = "";
            pull_pod = None;
            for (pod_name, info) in pulls.items() {
                if imagepull_streak.get(pod_name, 0) >= 2 {
                    if self._try_self_heal(
                        core_v1,
                        ns,
                        info[2],
                        f"container '{info[0]}' cannot pull image ({info[1]})",
                        healed_apps
                    ) {
                        imagepull_streak.pop(pod_name, None);
                        continue;
                    }
                    pull_failure = (
                        f"pod '{pod_name}' container '{info[0]}' "
                        f"cannot pull image ({info[1]})"
                    );
                    pull_pod = info[2];
                    break;
                }
            }
            creating_now: dict[str, any] = scan.get("creating", {});
            creating_streak = {k: creating_streak.get(k, 0) + 1 for k in creating_now};
            for (pod_name, pod) in creating_now.items() {
                if creating_streak.get(pod_name, 0) >= 30
                    and self._pod_mount_wedged(core_v1, ns, pod_name) {
                    if self._try_self_heal(
                        core_v1,
                        ns,
                        pod,
                        "stuck >5min with FailedMount events",
                        healed_apps
                    ) {
                        creating_streak.pop(pod_name, None);
                    }
                }
            }

            failure = crash_failure or pull_failure;
            failed_pod = crash_pod if crash_failure else pull_pod;
            if failure and failed_pod is not None {
                detail = self._pod_failure_detail(
                    core_v1, ns, str(failed_pod.metadata.name), failed_pod
                );
                raise Exception(f"{failure}.{detail}");
            }

            summary = ", ".join(phase_tokens) if phase_tokens else "scheduling pods";
            line = (
                f"Rolling out fleet: {ready}/{total} ready - {elapsed}s "
                f"elapsed ({summary}) - pods install jac + start the app"
            );
            st.update(line);

            sig = f"{ready}/{total}|" + "|".join(sorted(state_tokens));
            if sig != last_sig or (elapsed - last_heartbeat) >= 90 {
                if not interactive {
                    console.print(line);
                }
                last_sig = sig;
                last_heartbeat = elapsed;
            }
            time.sleep(10);
            elapsed += 10;
        }
    }
    timeout_detail = "";
    try {
        stuck = core_v1.list_namespaced_pod(
            namespace=ns, label_selector=pod_selector
        ).items
            if pod_selector
            else [];
        stuck_pods: list[any] = stuck;
        for p in stuck_pods {
            timeout_detail += (
                f" [pod {p.metadata.name}]"
                + self._pod_failure_detail(core_v1, ns, str(p.metadata.name), p)
            );
        }
    } except Exception {
        _ = 0;
    }
    raise Exception(
        f"timed out after {timeout}s ({ready}/{total} deployments ready)."
        f"{timeout_detail}"
    );
}


impl KubernetesTarget._pod_failure_detail(
    core_v1: any, namespace: str, pod_name: str, pod: any = None
) -> str {
    import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
        describe_pod_status
    }
    detail = describe_pod_status(core_v1, namespace, pod_name, pod);
    term_lines: list[str] = [];
    try {
        if pod is None {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        }
        statuses: list[any] = (pod.status.init_container_statuses or [])
            + (pod.status.container_statuses or []);
        for cs in statuses {
            states: list[tuple[str, any]] = [];
            if cs.state and cs.state.terminated {
                states.append(("terminated", cs.state.terminated));
            }
            if cs.last_state and cs.last_state.terminated {
                states.append(("last-terminated", cs.last_state.terminated));
            }
            for (label, term) in states {
                message = (term.message or "").strip();
                if message or term.reason {
                    term_lines.append(
                        f"container '{cs.name}' {label}: "
                        f"{term.reason or '?'} (exit={term.exit_code}) {message}"
                    );
                }
            }
        }
    } except Exception {
        _ = 0;
    }
    if term_lines {
        detail = detail + " " + "; ".join(term_lines);
    }
    return detail;
}


impl deployment_rollout_complete(dep: any) -> bool {
    try {
        status = dep.status;
        if status is None {
            return False;
        }
        if int(status.observed_generation or 0) < int(dep.metadata.generation or 0) {
            return False;
        }
        desired = dep.spec.replicas;
        wanted = int(desired) if desired is not None else 1;
        updated = int(status.updated_replicas or 0);
        current = int(status.replicas or 0);
        available = int(status.available_replicas or 0);
    } except Exception {
        return False;
    }
    return updated >= wanted and current <= updated and available >= updated;
}
