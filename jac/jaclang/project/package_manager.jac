import copy;
import hashlib;
import json;
import os;
import shutil;
import tempfile;
import uuid;
import from pathlib { Path }
import from jaclang.project.config { JacConfig, serialize_toml }
import from jaclang.project.dependency_model {
    DependencyEdge,
    DependencyNode,
    DependencySpec,
    LockGraph,
    PackageOperation,
    ProviderRequirement,
    ResolutionContext,
    ResolutionPlan,
    canonical_dependency_id,
    validate_dependency_spec,
    validate_import_root
}
import from jaclang.project.jac_provider {
    JacDepProvider,
    manifest_jac_specs,
    parse_jac_spec,
    pth_path
}
import from jaclang.project.jac_store { JacDepError, materialize, snapshot_path }
import from jaclang.project.lockfile { jac_lock_rows, read_lock }
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    get_provider_registry
}


def _manifest_entry(spec: DependencySpec) -> dict[str, any] {
    dep_entry: dict[str, any] = {};
    if spec.source == "path" {
        dep_entry["path"] = spec.source_location;
    } else {
        dep_entry["git"] = spec.source_location;
        if spec.ref {
            dep_entry["ref"] = spec.ref;
        }
        if spec.commit {
            dep_entry["commit"] = spec.commit;
        }
    }
    if spec.version_constraint {
        dep_entry["version"] = spec.version_constraint;
    }
    if spec.import_root {
        dep_entry["package"] = spec.import_root;
    }
    return dep_entry;
}


def _manifest_document(
    config: JacConfig, main_specs: list[DependencySpec], dev_specs: list[DependencySpec]
) -> dict[str, any] {
    doc = copy.deepcopy(config._raw_data);
    if not isinstance(doc, dict) {
        doc = {};
    }
    dependencies = doc.get("dependencies", {});
    dependencies = dependencies if isinstance(dependencies, dict) else {};
    dependencies["jac"] = {spec.alias: _manifest_entry(spec) for spec in main_specs};
    doc["dependencies"] = dependencies;
    dev_doc = doc.get("dev-dependencies", {});
    dev_doc = dev_doc if isinstance(dev_doc, dict) else {};
    if dev_specs {
        dev_doc["jac"] = {spec.alias: _manifest_entry(spec) for spec in dev_specs};
    } elif "jac" in dev_doc {
        del dev_doc["jac"];
    }

    if dev_doc {
        doc["dev-dependencies"] = dev_doc;
    } else {
        if "dev-dependencies" in doc {
            doc.pop("dev-dependencies", None);
        }
    }
    return doc;
}


def _config_for_manifest(config: JacConfig, doc: dict[str, any]) -> JacConfig {
    text = serialize_toml(doc);
    candidate = JacConfig.from_toml_str(text, config.toml_path);
    candidate.project_root = config.project_root;
    return candidate;
}


def dependency_spec_from_cli(spec: str, dev: bool = False) -> DependencySpec {
    (alias, dep_value) = parse_jac_spec(spec);
    source = "path" if "path" in dep_value else "git";
    location = str(dep_value.get(source, ""));
    result = DependencySpec(
        ecosystem="jac",
        alias=alias,
        source=source,
        source_location=location,
        ref=str(dep_value.get("ref", "")),
        commit=str(dep_value.get("commit", "")),
        version_constraint=str(dep_value.get("version", "")),
        import_root=str(dep_value.get("package", "")),
        dev=dev
    );
    try {
        return validate_dependency_spec(result);
    } except ValueError as e {
        raise JacDepError(str(e)) from None;
    }
}


def _node_dict(graph_node: DependencyNode) -> dict[str, any] {
    return {
        "id": graph_node.id,
        "ecosystem": graph_node.ecosystem,
        "alias": graph_node.alias,
        "project_name": graph_node.project_name,
        "source": graph_node.source,
        "source_location": graph_node.source_location,
        "ref": graph_node.ref,
        "commit": graph_node.commit,
        "tree": graph_node.tree,
        "version": graph_node.version,
        "import_root": graph_node.import_root,
        "dev": graph_node.dev
    };
}


def _edge_dict(graph_edge: DependencyEdge) -> dict[str, any] {
    return {
        "from_id": graph_edge.from_id,
        "to_id": graph_edge.to_id,
        "kind": graph_edge.kind,
        "requirement": graph_edge.requirement,
        "dev": graph_edge.dev
    };
}


def _snapshot_path_packages(resolved: dict[str, any]) {
    for pkg in resolved.values() {
        if pkg.source != "path" {
            continue;
        }
        fetched = snapshot_path(Path(pkg.pkg_root));
        pkg.pkg_root = fetched.path;
        pkg.tree = fetched.tree;
    }
}


def _build_plan(
    config: JacConfig,
    operation: PackageOperation,
    candidate: JacConfig,
    manifest_text: str
) -> ResolutionPlan {
    project_root = config.project_root or Path.cwd();
    context = ResolutionContext(
        include_dev=operation.include_dev,
        frozen=operation.frozen,
        update_targets=set(operation.targets),
        manifest_fingerprint=hashlib.sha256(manifest_text.encode("utf-8")).hexdigest()
    );
    prior = read_lock(project_root);
    pins = jac_lock_rows(prior);
    if operation.action == "update" and operation.targets {
        refresh: set[str] = set(operation.targets);
        changed = True;
        while changed {
            changed = False;
            graph_edges = prior.get("edges", []);
            if isinstance(graph_edges, list) {
                for graph_edge in graph_edges {
                    if not isinstance(graph_edge, dict) {
                        continue;
                    }
                    parent = str(graph_edge.get("from_id", ""));
                    child = str(graph_edge.get("to_id", ""));
                    if parent.startswith("jac:") and child.startswith("jac:") {
                        parent_name = parent[4:];
                        child_name = child[4:];
                        if parent_name in refresh and child_name not in refresh {
                            refresh.add(child_name);
                            changed = True;
                        }
                    }
                }
            }
            for (name, row) in pins.items() {
                if not isinstance(row, dict) {
                    continue;
                }
                reqs = row.get("requested_by", []);
                if isinstance(reqs, list)
                    and any(str(parent) in refresh for parent in reqs)
                    and name not in refresh {
                    refresh.add(name);
                    changed = True;
                }
            }
        }
        pins = {
            name: row
            for (name, row) in pins.items()
            if name not in refresh
        };
    }
    if operation.frozen and prior.get("legacy_partial", False) {
        raise JacDepError(
            "jac.lock contains legacy harvested Python/npm state; "
            "run 'jac install' to write a v2 graph before using --frozen"
        );
    }
    if operation.frozen {
        recorded_fingerprint = str(prior.get("manifest_fingerprint", ""));
        if recorded_fingerprint != context.manifest_fingerprint {
            raise JacDepError(
                "jac.toml differs from jac.lock manifest_fingerprint; "
                "run 'jac install' to refresh the lockfile"
            );
        }
    }
    registry = get_provider_registry();
    provider = JacDepProvider();
    ctx = InstallContext(
        verbose=False, frozen=operation.frozen, include_dev=operation.include_dev
    );
    resolved = {};
    if operation.action == "update" and operation.targets {
        refresh: set[str] = set(operation.targets);
        while True {
            resolved = provider.resolve_closure(
                candidate, ctx, frozen_pins=pins, collect_only=True
            );
            grew = False;
            for (name, pkg) in resolved.items() {
                if name in refresh {
                    continue;
                }
                if any(str(parent) in refresh for parent in pkg.requested_by) {
                    refresh.add(name);
                    grew = True;
                }
            }
            if not grew {
                break;
            }
            pins = {
                name: row
                for (name, row) in jac_lock_rows(prior).items()
                if name not in refresh
            };
        }
    } else {
        resolved = provider.resolve_closure(
            candidate, ctx, frozen_pins=pins, collect_only=True
        );
    }
    (candidate_main_specs, candidate_dev_specs) = manifest_jac_specs(candidate);
    dev_names: set[str] = {spec.alias for spec in candidate_dev_specs};
    declared_specs: dict[str, DependencySpec] = {
        spec.alias: spec for spec in candidate_main_specs + candidate_dev_specs
    };
    nodes: dict[str, DependencyNode] = {};
    edges: list[DependencyEdge] = [];
    staged: dict[str, any] = {};
    import_roots: dict[str, str] = {};
    unresolved_backend: list[dict[str, any]] = [];
    project_root = config.project_root or Path.cwd();
    for (backend_name, backend_constraint) in config.dependencies.items() {
        unresolved_backend.append(
            {
                "consumer_id": "root",
                "ecosystem": "python",
                "name": str(backend_name),
                "constraint": str(backend_constraint),
                "location": str(project_root),
                "dev": False,
                "unresolved": True
            }
        );
    }
    if context.include_dev {
        for (backend_name, backend_constraint) in config.dev_dependencies.items() {
            unresolved_backend.append(
                {
                    "consumer_id": "root",
                    "ecosystem": "python",
                    "name": str(backend_name),
                    "constraint": str(backend_constraint),
                    "location": str(project_root),
                    "dev": True,
                    "unresolved": True
                }
            );
        }
    }
    npm_raw = config.plugin_dependencies.get("npm", {});
    npm_raw = npm_raw if isinstance(npm_raw, dict) else {};
    for (backend_name, backend_constraint) in npm_raw.items() {
        if backend_name == "dev" or not isinstance(backend_constraint, str) {
            continue;
        }
        unresolved_backend.append(
            {
                "consumer_id": "root",
                "ecosystem": "npm",
                "name": str(backend_name),
                "constraint": str(backend_constraint),
                "location": str(project_root),
                "dev": False,
                "unresolved": True
            }
        );
    }
    npm_dev = npm_raw.get("dev", {});
    if context.include_dev and isinstance(npm_dev, dict) {
        for (backend_name, backend_constraint) in npm_dev.items() {
            if not isinstance(backend_constraint, str) {
                continue;
            }
            unresolved_backend.append(
                {
                    "consumer_id": "root",
                    "ecosystem": "npm",
                    "name": str(backend_name),
                    "constraint": str(backend_constraint),
                    "location": str(project_root),
                    "dev": True,
                    "unresolved": True
                }
            );
        }
    }
    for (alias, pkg) in resolved.items() {
        node_id = canonical_dependency_id("jac", alias);
        project = pkg.manifest.get("project", {});
        project = project if isinstance(project, dict) else {};
        dependency_table = pkg.manifest.get("dependencies", {});
        if isinstance(dependency_table, dict) {
            for backend in ("python", "npm") {
                backend_entries = dependency_table.get(backend, {});
                if not isinstance(backend_entries, dict) {
                    continue;
                }
                for (backend_name, backend_constraint) in backend_entries.items() {
                    unresolved_backend.append(
                        {
                            "consumer_id": node_id,
                            "ecosystem": backend,
                            "name": str(backend_name),
                            "constraint": str(backend_constraint),
                            "unresolved": True
                        }
                    );
                }
            }
        }
        project_name = str(project.get("name", alias));
        declared = declared_specs.get(alias);
        import_root = (
            declared.import_root
                if declared is not None and declared.import_root
                else str(project.get("package", project_name) or project_name)
        );
        try {
            import_root = validate_import_root(import_root);
        } except ValueError as e {
            raise JacDepError(f"Invalid import root for '{alias}': {e}") from None;
        }
        import_base = Path(str(pkg.pkg_root)) / import_root.replace(".", "/");
        if (
            not import_base.is_file()
            and not (import_base / "__init__.jac").is_file()
            and not (Path(str(pkg.pkg_root)) / f"{import_root}.jac").is_file()
        ) {
            raise JacDepError(
                f"Dependency '{alias}' provides no import root '{import_root}'"
            );
        }
        previous = import_roots.get(import_root);
        if previous is not None and previous != node_id {
            raise JacDepError(
                f"Import-root collision: '{import_root}' is provided by "
                f"{previous} and {node_id}"
            );
        }
        import_roots[import_root] = node_id;
        source_location = (
            os.path.relpath(pkg.key, str(project_root))
                if pkg.source == "path"
                else pkg.key
        );
        graph_node = DependencyNode(
            id=node_id,
            ecosystem="jac",
            alias=alias,
            project_name=project_name,
            source=pkg.source,
            source_location=source_location,
            ref=pkg.ref,
            commit=pkg.sha,
            tree=pkg.tree,
            version=pkg.version,
            import_root=import_root,
            dev=alias in dev_names
        );
        nodes[node_id] = graph_node;
        staged[node_id] = {"source": pkg.pkg_root, "tree": pkg.tree, "alias": alias};
        parents = pkg.requested_by or ["root"];
        for parent in parents {
            from_id = "root"
                if parent == "root"
                else canonical_dependency_id("jac", parent);
            graph_edge = DependencyEdge(
                from_id=from_id,
                to_id=node_id,
                kind="dependency",
                requirement="",
                dev=graph_node.dev
            );
            if not any(
                e.from_id == graph_edge.from_id and e.to_id == graph_edge.to_id
                for e in edges
            ) {
                edges.append(graph_edge);
            }
        }
    }
    prior_graph_nodes: dict[str, DependencyNode] = {};
    prior_graph_edges: list[DependencyEdge] = [];
    prior_node_data = prior.get("nodes", {});
    if isinstance(prior_node_data, dict) {
        for (prior_id, prior_value) in prior_node_data.items() {
            if not isinstance(prior_value, dict) {
                continue;
            }
            prior_graph_nodes[str(prior_id)] = DependencyNode(
                id=str(prior_value.get("id", prior_id)),
                ecosystem=str(prior_value.get("ecosystem", "")),
                alias=str(prior_value.get("alias", "")),
                project_name=str(prior_value.get("project_name", "")),
                source=str(prior_value.get("source", "")),
                source_location=str(prior_value.get("source_location", "")),
                ref=str(prior_value.get("ref", "")),
                commit=str(prior_value.get("commit", "")),
                tree=str(prior_value.get("tree", "")),
                version=str(prior_value.get("version", "")),
                import_root=str(prior_value.get("import_root", "")),
                dev=bool(prior_value.get("dev", False))
            );
        }
    }
    prior_edge_data = prior.get("edges", []);
    if isinstance(prior_edge_data, list) {
        for prior_value in prior_edge_data {
            if not isinstance(prior_value, dict) {
                continue;
            }
            prior_graph_edges.append(
                DependencyEdge(
                    from_id=str(prior_value.get("from_id", "")),
                    to_id=str(prior_value.get("to_id", "")),
                    kind=str(prior_value.get("kind", "dependency")),
                    requirement=str(prior_value.get("requirement", "")),
                    dev=bool(prior_value.get("dev", False))
                )
            );
        }
    }
    if not context.include_dev {
        dev_aliases = {spec.alias for spec in candidate_dev_specs}
            - set(resolved.keys());
        for dev_alias in sorted(dev_aliases) {
            dev_id = canonical_dependency_id("jac", dev_alias);
            if dev_id in nodes {
                continue;
            }
            dev_row = pins.get(dev_alias, {});
            if not isinstance(dev_row, dict) or not dev_row {
                continue;
            }
            dev_prior = prior_graph_nodes.get(dev_id);
            dev_declared = declared_specs.get(dev_alias);
            dev_import_root = (
                dev_declared.import_root
                    if dev_declared is not None and dev_declared.import_root
                    else ""
            );
            if dev_prior is not None and dev_prior.import_root {
                dev_import_root = dev_prior.import_root;
            }
            if not dev_import_root {
                dev_import_root = dev_alias;
            }
            try {
                dev_import_root = validate_import_root(dev_import_root);
            } except ValueError as e {
                raise JacDepError(
                    f"Invalid import root for '{dev_alias}': {e}"
                ) from None;
            }
            previous = import_roots.get(dev_import_root);
            if previous is not None and previous != dev_id {
                raise JacDepError(
                    f"Import-root collision: '{dev_import_root}' is provided by "
                    f"{previous} and {dev_id}"
                );
            }
            import_roots[dev_import_root] = dev_id;
            dev_source = "path" if dev_row.get("path") else "git";
            dev_location = str(dev_row.get("path", "") or dev_row.get("git", ""));
            dev_node = DependencyNode(
                id=dev_id,
                ecosystem="jac",
                alias=dev_alias,
                project_name=(
                    dev_prior.project_name
                        if dev_prior is not None and dev_prior.project_name
                        else dev_alias
                ),
                source=dev_source,
                source_location=dev_location,
                ref=str(dev_row.get("ref", "")),
                commit=str(dev_row.get("sha", "")),
                tree=str(dev_row.get("tree", "")),
                version=str(dev_row.get("version", "")),
                import_root=dev_import_root,
                dev=True
            );
            nodes[dev_id] = dev_node;
            for parent in dev_row.get("requested_by", []) or ["root"] {
                parent = str(parent);
                from_id = (
                    "root"
                        if parent == "root"
                        else canonical_dependency_id("jac", parent)
                );
                graph_edge = DependencyEdge(
                    from_id=from_id,
                    to_id=dev_id,
                    kind="dependency",
                    requirement="",
                    dev=True
                );
                if not any(
                    e.from_id == graph_edge.from_id and e.to_id == graph_edge.to_id
                    for e in edges
                ) {
                    edges.append(graph_edge);
                }
            }
        }
    }
    provider_resolutions: dict[str, any] = {};
    for ecosystem in ("python", "npm") {
        backend_provider: EcosystemProvider | None = registry.get(ecosystem);
        if backend_provider is None {
            continue;
        }
        requirements: list[ProviderRequirement] = [
            ProviderRequirement(
                consumer_id=str(item.get("consumer_id", "root")),
                ecosystem=ecosystem,
                name=str(item.get("name", "")),
                constraint=str(item.get("constraint", "")),
                location=str(item.get("location", "")),
                dev=bool(item.get("dev", False))
            )
            for item in unresolved_backend
            if item.get("ecosystem") == ecosystem
        ];
        if not requirements {
            continue;
        }
        resolution = backend_provider.resolve_requirements(
            context,
            requirements,
            LockGraph(
                nodes=prior_graph_nodes,
                edges=prior_graph_edges,
                manifest_fingerprint=str(prior.get("manifest_fingerprint", "")),
                include_dev=bool(prior.get("include_dev", False))
            )
        );
        provider_resolutions[ecosystem] = resolution;
        nodes.update(resolution.nodes);
        edges.extend(resolution.edges);
    }
    lock_data = {
        "version": 2,
        "manifest_fingerprint": context.manifest_fingerprint,
        "include_dev": context.include_dev,
        "nodes": {node_id: _node_dict(node) for (node_id, node) in nodes.items()},
        "edges": [_edge_dict(edge) for edge in edges]
    };
    if unresolved_backend {
        lock_data["unresolved_backend"] = unresolved_backend;
    }
    return ResolutionPlan(
        nodes=nodes,
        edges=edges,
        manifest_text=manifest_text,
        lock_data=lock_data,
        staged_cas_objects=[str(v.get("source", "")) for v in staged.values()],
        staged_materializations={
            ** staged,
            "_save_manifest": operation.save,
            "_dry_run": operation.dry_run
        },
        provider_resolutions=provider_resolutions
    );
}


def plan_operation(config: JacConfig, operation: PackageOperation) -> ResolutionPlan {
    if operation.ecosystem != "jac" {
        raise JacDepError("Milestone 1 package operations support ecosystem='jac'");
    }
    (main_specs, dev_specs) = manifest_jac_specs(config);
    by_alias: dict[str, DependencySpec] = {
        spec.alias: spec for spec in main_specs + dev_specs
    };
    for spec in operation.specs {
        validate_dependency_spec(spec);
        if spec.alias in by_alias {
            raise JacDepError(f"Duplicate jac dependency alias '{spec.alias}'");
        }
        by_alias[spec.alias] = spec;
        if spec.dev {
            dev_specs.append(spec);
        } else {
            main_specs.append(spec);
        }
    }
    if operation.action == "remove" {
        targets = set(operation.targets);
        before = len(main_specs) + len(dev_specs);
        main_specs = [
            spec
            for spec in main_specs
            if spec.alias not in targets
        ];
        dev_specs = [
            spec
            for spec in dev_specs
            if spec.alias not in targets
        ];
        if before == len(main_specs) + len(dev_specs) {
            raise JacDepError(
                f"No jac dependency matched: {', '.join(sorted(targets))}"
            );
        }
    }
    doc = _manifest_document(config, main_specs, dev_specs);
    manifest_text = serialize_toml(doc);
    candidate = _config_for_manifest(config, doc);
    return _build_plan(config, operation, candidate, manifest_text);
}

def _write_atomic(path: Path, text: str) {
    path.parent.mkdir(parents=True, exist_ok=True);
    (fd, tmp_name) = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent));
    tmp = Path(tmp_name);
    try {
        with os.fdopen(fd, "w", encoding="utf-8") as stream {
            stream.write(text);
            stream.flush();
            os.fsync(stream.fileno());
        }
        os.replace(str(tmp), str(path));
    } except Exception {
        tmp.unlink(missing_ok=True);
        raise;
    }
}


def _publish_packages(active: Path, generation_packages: Path) {
    pointer = active.with_name(active.name + ".next");
    pointer.unlink(missing_ok=True);
    os.symlink(str(generation_packages), str(pointer));
    old = active.with_name(active.name + ".old");
    if active.is_symlink() or (active.exists() and not active.is_dir()) {
        active.unlink(missing_ok=True);
    } elif active.exists() {
        old.unlink(missing_ok=True);
        os.replace(str(active), str(old));
    }
    os.replace(str(pointer), str(active));
    if old.exists() and old.is_dir() and not old.is_symlink() {
        shutil.rmtree(old, ignore_errors=True);
    } else {
        old.unlink(missing_ok=True);
    }
}


def commit_plan(config: JacConfig, plan: ResolutionPlan) -> bool {
    if plan.staged_materializations.get("_dry_run", False) {
        return True;
    }
    project_root = config.project_root or Path.cwd();
    build = config.get_build_dir();
    deps_root = build / "dependencies";
    tx_id = uuid.uuid4().hex;
    stage = deps_root / "staging" / tx_id;
    generation = deps_root / "generations" / tx_id;
    stage_packages = stage / "packages";
    generation_packages = generation / "packages";
    journal = deps_root / "transaction.json";
    stage_packages.mkdir(parents=True, exist_ok=False);
    generation.mkdir(parents=True, exist_ok=True);
    try {
        rows: list[dict[str, any]] = [];
        for (node_id, item) in plan.staged_materializations.items() {
            if node_id.startswith("_") {
                continue;
            }
            if node_id not in plan.staged_materializations {
                continue;
            }
            graph_node = plan.nodes[node_id];
            destination = stage_packages / graph_node.alias;
            materialize(Path(str(item["source"])), destination);
            rows.append(
                {
                    "id": graph_node.id,
                    "name": graph_node.alias,
                    "generation": tx_id,
                    "alias": graph_node.alias,
                    "import_root": graph_node.import_root,
                    "tree": graph_node.tree,
                    "source": graph_node.source,
                    "root": str(generation_packages / graph_node.alias)
                }
            );
        }
        deps_data = {"version": 2, "generation": tx_id, "packages": rows};
        # Sync the python (and other backend) requirements that the pure-jac
        # packages' own manifests pulled in: the lock records the resolved
        # closure, but without this step the project venv never sees the
        # transitive deps and imports fail at runtime. Runs before the
        # generation is published so a failed sync aborts the whole
        # transaction; frozen replays carry no install plan (they promise the
        # store, not the network).
        registry = get_provider_registry();
        for (ecosystem, resolution) in plan.provider_resolutions.items() {
            if not resolution.install_plan {
                continue;
            }
            backend_provider = registry.get(ecosystem);
            if backend_provider is None {
                continue;
            }
            if not backend_provider.execute_install_plan(
                config, resolution, InstallContext()
            ) {
                raise JacDepError(
                    f"Could not sync '{ecosystem}' dependencies required by "
                    "pure-jac packages into the project environment"
                );
            }
        }
        _write_atomic(stage / "deps.json", json.dumps(deps_data, indent=2) + "\n");
        if plan.staged_materializations.get("_save_manifest", True) {
            _write_atomic(stage / "jac.lock", serialize_toml(plan.lock_data));
            _write_atomic(stage / "jac.toml", plan.manifest_text);
        }
        os.replace(str(stage_packages), str(generation_packages));
        journal.write_text(
            json.dumps(
                {
                    "transaction": tx_id,
                    "generation": str(generation),
                    "stage": str(stage),
                    "active": str(build / "packages")
                },
                indent=2
            )
                + "\n",
            encoding="utf-8"
        );
        _publish_packages(build / "packages", generation_packages);
        os.replace(str(stage / "deps.json"), str(build / "deps.json"));
        if plan.staged_materializations.get("_save_manifest", True) {
            os.replace(str(stage / "jac.lock"), str(project_root / "jac.lock"));
        }
        if plan.staged_materializations.get("_save_manifest", True) {
            os.replace(str(stage / "jac.toml"), str(project_root / "jac.toml"));
        }
        journal.unlink(missing_ok=True);
        pth = pth_path(config);
        if pth is not None {
            pth.unlink(missing_ok=True);
        }
        return True;
    } except Exception {
        raise;
    } finally {
        if not journal.is_file() {
            shutil.rmtree(stage, ignore_errors=True);
        }
    }
}
