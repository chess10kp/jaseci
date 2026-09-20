impl KubernetesTarget._destroy_fleet_workloads(
    namespace: str, apps_v1: any, core_v1: any, policy_v1: any, networking_v1: any
) {
    ms_selector: str = "managed=jac-scale";

    delete_collection_if_exists(
        apps_v1.delete_collection_namespaced_deployment, namespace, FLEET_SELECTOR
    );

    try {
        AutoscalerFactory.create(
            self.k8s_config.autoscaler_engine, self.k8s_config.to_dict(), self.logger
        ).destroy_collection(
            namespace, ms_selector
        );
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }

    if self.k8s_config.autoscaler_engine != "keda" {
        try {
            KEDAAutoscaler(logger=self.logger).destroy_collection(
                namespace, ms_selector, best_effort=True
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
    }

    delete_collection_if_exists(
        policy_v1.delete_collection_namespaced_pod_disruption_budget,
        namespace,
        ms_selector
    );
    delete_collection_if_exists(
        networking_v1.delete_collection_namespaced_ingress, namespace, ms_selector
    );

    try {
        services = core_v1.list_namespaced_service(
            namespace=namespace, label_selector=ms_selector
        );
        for svc in (services.items or []) {
            delete_resource(core_v1, "Service", svc.metadata.name, namespace);
        }
    } except ApiException as e {
        if e.status != 404 {
            raise;
        }
    }

    delete_collection_if_exists(
        core_v1.delete_collection_namespaced_config_map,
        namespace,
        "managed=jac-scale,jac-scale.role=source"
    );
}


impl KubernetesTarget._destroy_monitoring(
    app_name: str, namespace: str, apps_v1: any, core_v1: any, strict: bool = False
) -> bool {
    try {
        monitoring = MonitoringDeployer(self.k8s_config, self.logger);
        monitoring.destroy(app_name, namespace, apps_v1, core_v1);
        return True;
    } except Exception as e {
        if strict {
            raise;
        }
        if self.logger {
            self.logger.warning(
                f"Observability stack destroy failed, leaving its "
                f"cluster-scoped RBAC in place: {e}",
                {"app_name": app_name}
            );
        }
        return False;
    }
}


impl KubernetesTarget._postgres_pvc_name(app_name: str) -> str {
    """Name the PVC the postgres volumeClaimTemplates entry creates.""";
    pg_name: str = f"{app_name}-postgres";
    return f"{pg_name}-data-{pg_name}-0";
}


impl KubernetesTarget._app_pvc_names(app_name: str) -> list[str] {
    return [
        bundle_pvc_name(k8s_safe_name(app_name)),
        self._postgres_pvc_name(app_name)
    ];
}


impl KubernetesTarget._destroy_pvcs(
    pvc_names: list[str], namespace: str, core_v1: any
) {
    for pvc_name in pvc_names {
        delete_resource(core_v1, 'PersistentVolumeClaim', pvc_name, namespace);
    }
}


impl KubernetesTarget._destroy_app_pvcs(app_name: str, namespace: str, core_v1: any) {
    self._destroy_pvcs(self._app_pvc_names(app_name), namespace, core_v1);
}


impl KubernetesTarget._report_unowned_shared_volumes(namespace: str, core_v1: any) {
    if not self.logger {
        return;
    }
    try {
        pvcs = core_v1.list_namespaced_persistent_volume_claim(
            namespace=namespace,
            label_selector="managed=jac-scale,jac-scale.role=shared-volume,"
            "!jac-scale.owner"
        );
    } except ApiException {
        return;
    }
    names: list[str] = [pvc.metadata.name for pvc in pvcs.items];
    if names {
        self.logger.warning(
            f"Kept shared volumes that name no app: {', '.join(names)}. They "
            f"predate volume ownership, so another app in this namespace may "
            f"own them. Label one with 'jac-scale.owner' or delete it by hand.",
            {"namespace": namespace}
        );
    }
}


impl KubernetesTarget._destroy_shared_volume_pvcs(
    app_name: str, namespace: str, core_v1: any, sole_tenant: bool
) {
    shared: str = "managed=jac-scale,jac-scale.role=shared-volume";
    selectors: list[str] = [f"{shared},jac-scale.owner={k8s_safe_name(app_name)}"];
    if sole_tenant {
        selectors.append(f"{shared},!jac-scale.owner");
    } else {
        self._report_unowned_shared_volumes(namespace, core_v1);
    }
    for selector in selectors {
        delete_collection_if_exists(
            core_v1.delete_collection_namespaced_persistent_volume_claim,
            namespace,
            selector
        );
    }
}


impl KubernetesTarget._list_managed(
    lister: any, namespace: str, selector: str
) -> list[any] {
    """List the objects a lister returns, tolerating a kind the cluster lacks.""";
    try {
        return lister(namespace=namespace, label_selector=selector).items;
    } except ApiException as e {
        if e.status == 404 {
            return [];
        }
        raise;
    }
}


impl KubernetesTarget._foreign_app_resources(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) -> list[str] {
    """Name the jac-scale resources in this namespace another app owns.""";
    owner: str = k8s_safe_name(app_name);
    our_bundle: str = bundle_pvc_name(owner);
    our_postgres: str = f"{app_name}-postgres";
    managed: str = "managed=jac-scale";
    found: list[str] = [];
    for pvc in self._list_managed(
        core_v1.list_namespaced_persistent_volume_claim, namespace, managed
    ) {
        labels: dict[str, str] = pvc.metadata.labels or {};
        role: str = labels.get("jac-scale.role", "");
        volume_owner: str = labels.get("jac-scale.owner", "");
        foreign_bundle: bool = (
            role == "bundle-store" and pvc.metadata.name != our_bundle
        );
        foreign_volume: bool = (
            role == "shared-volume" and bool(volume_owner) and volume_owner != owner
        );
        if foreign_bundle or foreign_volume {
            found.append(f"PersistentVolumeClaim/{pvc.metadata.name}");
        }
    }
    for sts in self._list_managed(
        apps_v1.list_namespaced_stateful_set, namespace, managed
    ) {
        if sts.metadata.name != our_postgres {
            found.append(f"StatefulSet/{sts.metadata.name}");
        }
    }
    return found;
}


impl KubernetesTarget._co_tenants_best_effort(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) -> list[str] {
    try {
        return self._foreign_app_resources(app_name, namespace, apps_v1, core_v1);
    } except ApiException {
        return [];
    }
}


impl KubernetesTarget._warn_co_tenant_workloads_removed(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    if not self.logger {
        return;
    }
    co_tenants: list[str] = self._co_tenants_best_effort(
        app_name, namespace, apps_v1, core_v1
    );
    if not co_tenants {
        return;
    }
    self.logger.warning(
        f"Another app has resources in '{namespace}': "
        f"{', '.join(co_tenants)}. Its data was kept, but this removed its "
        f"deployments, autoscalers and disruption budgets along with this "
        f"app's, so redeploy it to restore service.",
        {"app_name": app_name}
    );
}


impl KubernetesTarget._destroy_ops_rbac(app_name: str, namespace: str) {
    rbac_v1 = client.RbacAuthorizationV1Api();
    ms_selector: str = f"managed=jac-scale,app={app_name}";
    for delete_collection in [
        rbac_v1.delete_collection_namespaced_role_binding,
        rbac_v1.delete_collection_namespaced_role
    ] {
        delete_collection_if_exists(delete_collection, namespace, ms_selector);
    }
}


impl KubernetesTarget._wait_for_namespace_deletion(
    namespace: str, core_v1: any, timeout: int = 300
) -> bool {
    elapsed = 0.0;
    poll = 2.0;
    while elapsed < timeout {
        try {
            core_v1.read_namespace(name=namespace);
        } except ApiException as e {
            if e.status == 404 {
                return True;
            }
            raise;
        }
        time.sleep(poll);
        elapsed = elapsed + poll;
    }
    return False;
}


impl KubernetesTarget._reclaim_namespace(namespace: str, core_v1: any) -> bool {
    try {
        delete_namespace(namespace);
    } except ApiException as e {
        if e.status != 403 {
            raise;
        }
        return False;
    }
    if self._wait_for_namespace_deletion(namespace, core_v1) {
        if self.logger {
            self.logger.info(f"Namespace '{namespace}' deleted");
        }
    } elif self.logger {
        self.logger.warning(
            f"Timed out waiting for namespace '{namespace}' to be deleted"
        );
    }
    return True;
}


impl KubernetesTarget._destroy_app_database(
    app_name: str, namespace: str, apps_v1: any, core_v1: any
) {
    pg_name: str = f"{app_name}-postgres";
    delete_resource(apps_v1, 'StatefulSet', pg_name, namespace);
    delete_resource(core_v1, 'Service', f"{pg_name}-service", namespace);
    delete_k8s_secret(core_v1, namespace, f"{pg_name}-secret");
    delete_k8s_secret(core_v1, namespace, f"{app_name}-external-db");
    delete_resource(core_v1, 'ServiceAccount', f"{pg_name}-sa", namespace);
}


impl KubernetesTarget._destroy_in_shared_namespace(
    app_name: str, namespace: str, apps_v1: any, core_v1: any, sole_tenant: bool
) {
    self._destroy_app_database(app_name, namespace, apps_v1, core_v1);
    self._destroy_app_pvcs(app_name, namespace, core_v1);
    self._destroy_shared_volume_pvcs(app_name, namespace, core_v1, sole_tenant);
    self._destroy_ops_rbac(app_name, namespace);
    delete_k8s_secret(core_v1, namespace, f"{app_name}-secrets");
}


impl KubernetesTarget.destroy(app_name: str, component: str = "") {
    if self.logger {
        self.logger.info(
            f"Destroying microservice topology in namespace "
            f"'{self.k8s_config.namespace}'",
            {"app_name": app_name}
        );
    }

    self._load_cluster_config();
    apps_v1 = client.AppsV1Api();
    core_v1 = client.CoreV1Api();
    policy_v1 = client.PolicyV1Api();
    networking_v1 = client.NetworkingV1Api();
    namespace: str = self.k8s_config.namespace;

    if component {
        self._destroy_named_component(
            app_name, namespace, component, apps_v1, core_v1, policy_v1, networking_v1
        );
        return;
    }

    self._destroy_fleet_workloads(
        namespace, apps_v1, core_v1, policy_v1, networking_v1
    );

    monitoring_reclaimed = self._destroy_monitoring(
        app_name, namespace, apps_v1, core_v1
    );
    owner: str = k8s_safe_name(app_name);

    created_namespace: bool = namespace_is_owned(core_v1, namespace, owner);
    co_tenants: list[str] = (
        self._foreign_app_resources(app_name, namespace, apps_v1, core_v1)
            if created_namespace
            else []
    );
    sole_tenant: bool = created_namespace and not co_tenants;

    if sole_tenant {
        if monitoring_reclaimed {
            if self._reclaim_namespace(namespace, core_v1) {
                return;
            }
            if self.logger {
                self.logger.warning(
                    f"Not permitted to delete namespace '{namespace}', so "
                    f"this app's resources inside it are removed instead",
                    {"app_name": app_name}
                );
            }
        } elif self.logger {
            self.logger.warning(
                f"Keeping namespace '{namespace}': its monitoring RBAC is "
                f"cluster-scoped and is named after this namespace, so "
                f"deleting it now would orphan roles nothing can attribute",
                {"app_name": app_name}
            );
        }
    } elif co_tenants and self.logger {
        self.logger.warning(
            f"Keeping namespace '{namespace}': this app created it, but "
            f"{', '.join(co_tenants)} in it belongs to another app. That "
            f"app's database and volumes are kept, but workloads in this "
            f"namespace were removed, so redeploy it to restore service.",
            {"app_name": app_name}
        );
    } elif not created_namespace {
        self._warn_co_tenant_workloads_removed(app_name, namespace, apps_v1, core_v1);
    }
    self._destroy_in_shared_namespace(
        app_name, namespace, apps_v1, core_v1, sole_tenant
    );
}


impl KubernetesTarget._destroy_named_component(
    app_name: str,
    namespace: str,
    component: str,
    apps_v1: any,
    core_v1: any,
    policy_v1: any,
    networking_v1: any
) {
    if component == 'application' {
        self._destroy_fleet_workloads(
            namespace, apps_v1, core_v1, policy_v1, networking_v1
        );
        self._warn_co_tenant_workloads_removed(app_name, namespace, apps_v1, core_v1);
    } elif component == 'database' {
        self._destroy_app_database(app_name, namespace, apps_v1, core_v1);
        self._destroy_pvcs([self._postgres_pvc_name(app_name)], namespace, core_v1);
    } elif component == 'monitoring' {
        self._destroy_monitoring(app_name, namespace, apps_v1, core_v1, strict=True);
    } else {
        raise ValueError(
            f"Unknown component: '{component}'. Valid choices: application, "
            f"database, monitoring"
        );
    }
    if self.logger {
        self.logger.info(f"Component '{component}' of '{app_name}' destroyed");
    }
}
