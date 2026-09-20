import from jaclang.scale._optdeps.kubernetes { client }

impl run_kubectl_command(args: list[str], cwd: str | Path | None = None) -> None {
    import shutil;
    import subprocess;
    if (shutil.which('kubectl') is None) {
        raise RuntimeError('kubectl is required to seed the bundle PVC.');
    }

    try {
        subprocess.run(
            ['kubectl', *args], check=True, text=True, cwd=str(cwd) if cwd else None
        );
    } except subprocess.CalledProcessError as exc {
        raise RuntimeError(
            f"kubectl command failed: {' '.join(['kubectl', *args])}"
        ) from exc;
    }
}

impl wait_for_pod_deletion(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, timeout: int = 120
) -> None {
    start_time = time.time();
    while ((time.time() - start_time) < timeout) {
        try {
            core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                return;
            }
            raise;
        }
        time.sleep(2);
    }
    raise TimeoutError(f"Timed out waiting for pod '{pod_name}' deletion.");
}

impl wait_for_pod_phase(
    core_v1: client.CoreV1Api,
    namespace: str,
    pod_name: str,
    target_phases: set[str],
    timeout: int = 180
) -> None {
    start_time = time.time();
    last_pod: any = None;
    while ((time.time() - start_time) < timeout) {
        try {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        } except ApiException as exc {
            if (exc.status == 404) {
                time.sleep(2);
                continue;
            }
            raise;
        }
        last_pod = pod;
        phase = (pod.status.phase or '').strip();
        if (phase in target_phases) {
            return;
        }
        if (phase == 'Failed') {
            raise RuntimeError(
                f"Sync pod '{pod_name}' entered Failed state."
                    + describe_pod_status(core_v1, namespace, pod_name, pod)
            );
        }
        time.sleep(2);
    }
    raise TimeoutError(
        f"Timed out while waiting for pod '{pod_name}' to reach phase {target_phases}."
            + describe_pod_status(core_v1, namespace, pod_name, last_pod)
    );
}

impl describe_pod_status(
    core_v1: client.CoreV1Api, namespace: str, pod_name: str, pod: any = None
) -> str {
    lines: list[str] = [];
    object_names = [pod_name];
    try {
        if pod is None {
            pod = core_v1.read_namespaced_pod(pod_name, namespace);
        }
        lines.append(f"phase={(pod.status.phase or '?')}");
        for cond in (pod.status.conditions or []) {
            if (cond.status or '') != 'True' and cond.reason {
                lines.append(
                    f"condition {cond.type}={cond.status} ({cond.reason}: {cond.message
                        or ''})"
                );
            }
        }
        container_states = (pod.status.init_container_statuses or [])
            + (pod.status.container_statuses or []);
        for cs in container_states {
            waiting = cs.state.waiting if cs.state else None;
            if waiting and waiting.reason {
                lines.append(
                    f"container '{cs.name}' waiting: {waiting.reason} ({waiting.message
                        or ''})"
                );
            }
        }
        for vol in ((pod.spec.volumes if pod.spec else None) or []) {
            claim = vol.persistent_volume_claim;
            if not claim {
                continue;
            }
            claim_name = claim.claim_name;
            object_names.append(claim_name);
            try {
                pvc = core_v1.read_namespaced_persistent_volume_claim(
                    claim_name, namespace
                );
                modes = ",".join(pvc.spec.access_modes or []);
                lines.append(
                    f"pvc '{claim_name}' phase={(pvc.status.phase or '?')} "
                    f"accessModes=[{modes}] storageClass={pvc.spec.storage_class_name
                        or '(default)'}"
                );
            } except Exception as exc {
                lines.append(f"(could not read pvc '{claim_name}': {exc})");
            }
        }
    } except Exception as exc {
        lines.append(f"(could not read pod: {exc})");
    }
    try {
        for obj_name in object_names {
            events = core_v1.list_namespaced_event(
                namespace, field_selector=f"involvedObject.name={obj_name}"
            );
            for ev in (events.items or []) {
                lines.append(
                    f"event [{obj_name}/{ev.reason or '?'}] {ev.message or ''}"
                );
            }
        }
    } except Exception as exc {
        lines.append(f"(could not read events: {exc})");
    }
    if not lines {
        return '';
    }
    return " Pod diagnostics: " + "; ".join(lines);
}
