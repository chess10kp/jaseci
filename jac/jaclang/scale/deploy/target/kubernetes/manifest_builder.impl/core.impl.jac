impl ManifestBuilder.generate_manifests(
    app_config: AppConfig, image: str
) -> dict[str, any] {
    self.project_dir = self.project_dir or app_config.code_folder;
    fleet = self._fleet(app_config);
    self._bundle_files();
    injector = self._prepare_injector(app_config);
    self._bundle_object_key = injector._object_key;

    pod_specs = self.generate_service_pod_specs(app_config, image);
    deployments: dict[str, dict[str, any]] = {};
    services: dict[str, dict[str, any]] = {};
    scaling: dict[str, dict[str, any]] = {};
    pdbs: dict[str, dict[str, any]] = {};

    for (svc_name, pod_spec) in pod_specs.items() {
        deployments[svc_name] = self._build_deployment_manifest(svc_name, pod_spec);
        services[svc_name] = self._build_service_manifest(svc_name);
        scaling[svc_name] = self._resolve_scaling(
            svc_name, deployments[svc_name], services[svc_name]
        );
        pdb = self._build_pdb_manifest(svc_name, scaling[svc_name].get("mode"));
        if pdb is not None {
            pdbs[svc_name] = pdb;
        }
    }
    self._validate_http_activation_rules(scaling);

    bundle: dict[str, any] = {
        "deployments": deployments,
        "services": services,
        "scaling": scaling,
        "pdbs": pdbs,
        "pod_specs": pod_specs,
        "fleet": fleet,
        "gateway_config": self._gateway_cfg()
    };

    bundle["injector"] = injector;
    for manifest in injector.extra_manifests(
        k8s_safe_name(self.k8s_config.app_name), self.k8s_config.namespace
    ) {
        if manifest.get("kind") == "PersistentVolumeClaim" {
            pvcs_from_injector = bundle.get("pvcs", {});
            pvcs_from_injector[manifest["metadata"]["name"]] = manifest;
            bundle["pvcs"] = pvcs_from_injector;
        }
    }

    shared_pvcs = self._build_shared_pvc_manifests();
    if shared_pvcs {
        merged_pvcs = bundle.get("pvcs", {});
        merged_pvcs.update(shared_pvcs);
        bundle["pvcs"] = merged_pvcs;
    }
    user_secret = self._build_user_secret_manifest();
    if user_secret is not None {
        bundle["user_secret"] = user_secret;
    }
    ingress_cfg: dict[str, any] = self._gateway_cfg().get("ingress", {});
    ingress = self._build_ingress_manifest(ingress_cfg);
    if ingress is not None {
        bundle["ingress"] = ingress;
    }

    if getattr(self.k8s_config, "ops_console", False) {
        import from jaclang.scale.deploy.target.kubernetes.ops_rbac { build_ops_rbac }
        bundle["ops_rbac"] = build_ops_rbac(
            self.k8s_config.app_name,
            self.k8s_config.namespace,
            self._service_account_name(),
            bool(getattr(self.k8s_config, "ops_console_mutations", False))
        );
    } elif getattr(self.k8s_config, "ops_console_mutations", False) {
        if self.logger {
            self.logger.warning(
                "[scale.kubernetes].ops_console_mutations is set but "
                "ops_console is false; no Ops Console RBAC will be provisioned. "
                "Set ops_console = true to enable it."
            );
        }
    }
    self._check_pod_config_resolves(deployments, user_secret);
    return bundle;
}


impl merge_manifest_overlay(base: any, overlay: any) -> any {
    if isinstance(base, dict) and isinstance(overlay, dict) {
        merged = dict(base);
        for (key, value) in overlay.items() {
            merged[key] = merge_manifest_overlay(base.get(key), value)
                if key in base
                else value;
        }
        return merged;
    }
    if (
        isinstance(base, list)
        and isinstance(overlay, list)
        and _is_named_list(base)
        and _is_named_list(overlay)
    ) {
        overlay_by_name = {item["name"]: item for item in overlay};
        merged_list: list[any] = [];
        for item in base {
            item_name = item["name"];
            if item_name in overlay_by_name {
                merged_list.append(
                    merge_manifest_overlay(item, overlay_by_name.pop(item_name))
                );
            } else {
                merged_list.append(item);
            }
        }
        for item in overlay {
            if item["name"] in overlay_by_name {
                merged_list.append(item);
            }
        }
        return merged_list;
    }
    return overlay;
}


impl with_config_revision(manifest: dict[str, any], revision: str) -> dict[str, any] {
    if not revision {
        return manifest;
    }
    return dict(
        merge_manifest_overlay(
            manifest,
            {
                "spec": {
                    "template": {
                        "metadata": {
                            "annotations": {CONFIG_REVISION_ANNOTATION: str(revision)}
                        }
                    }
                }
            }
        )
    );
}


impl _is_named_list(items: list[object]) -> bool {
    if not items {
        return False;
    }
    for item in items {
        if not isinstance(item, dict) or "name" not in item {
            return False;
        }
    }
    return True;
}
