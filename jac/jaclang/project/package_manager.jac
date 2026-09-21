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
    parse_jac_spec
}
import from jaclang.project.jac_store { JacDepError, materialize, snapshot_path }
import from jaclang.project.lockfile {
    _lock_doc,
    harvest_npm_lock,
    harvest_python_lock,
    jac_lock_rows,
    read_lock,
    write_atomic
}
import from jaclang.project.pyvenv { venv_python }
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    capability_dependencies,
    get_provider_registry,
    get_python_provider
}
import from jaclang.project.versioning { norm_pkg_name }


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


def _manifest_config(
    config: JacConfig, main_specs: list[DependencySpec], dev_specs: list[DependencySpec]
) -> JacConfig {
    # Derive the post-operation jac section, then let the config's own
    # document builder render it: JacConfig.to_doc is the single writer of
    # the dependency hoisting/empty-table cleanup, so this file and
    # JacConfig.save cannot drift.
    jac_section: dict[str, any] = {
        spec.alias: _manifest_entry(spec) for spec in main_specs
    };
    if dev_specs {
        jac_section["dev"] = {spec.alias: _manifest_entry(spec) for spec in dev_specs};
    }
    candidate = copy.deepcopy(config);
    candidate.plugin_dependencies = dict(candidate.plugin_dependencies);
    if jac_section {
        candidate.plugin_dependencies["jac"] = jac_section;
    } else {
        candidate.plugin_dependencies.pop("jac", None);
    }
    # to_doc only rewrites hoisted [dependencies.<type>] tables for types
    # still present in plugin_dependencies; drop now-orphaned sub-tables
    # from the raw document so a removed jac section cannot survive the
    # render.
    raw_deps = candidate._raw_data.get("dependencies", {});
    if isinstance(raw_deps, dict) {
        candidate._raw_data["dependencies"] = {
            k: v
            for (k, v) in raw_deps.items()
            if k == "git"
                or not isinstance(v, dict)
                or k in candidate.plugin_dependencies
        };
    }
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
    # Resolve against the interpreter the pins will be installed with: a
    # pip --dry-run probed on the host python can disagree with the project
    # venv's closure when the two differ in version or platform tags.
    probe_python = Path(venv_python(Path(config.get_venv_dir())));
    context = ResolutionContext(
        include_dev=operation.include_dev,
        frozen=operation.frozen,
        update_targets=set(operation.targets),
        manifest_fingerprint=hashlib.sha256(manifest_text.encode("utf-8")).hexdigest(),
        interpreter=str(probe_python) if probe_python.exists() else ""
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
    if operation.frozen {
        # `legacy_version`/`legacy_partial` are set by read_lock only when the
        # file's version is < 2, i.e. a genuine pre-v2 lock; a fingerprintless
        # v2 lock (legacy pipeline output) falls through to the mismatch check.
        if prior.get("legacy_version") or prior.get("legacy_partial", False) {
            raise JacDepError(
                "jac.lock is a pre-v2 lockfile; run 'jac install' to write "
                "the v2 graph before using --frozen"
            );
        }
        if not prior {
            raise JacDepError(
                "no jac.lock found; run 'jac install' before using --frozen"
            );
        }
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
    extras_deps = get_python_provider().resolve_extras(config, operation.extras);
    for extra_dep in extras_deps {
        unresolved_backend.append(
            {
                "consumer_id": "root",
                "ecosystem": "python",
                "name": extra_dep.name,
                "constraint": extra_dep.version,
                "location": str(project_root),
                "dev": False,
                "unresolved": True
            }
        );
    }
    manifest_python_names: set[str] = {
        norm_pkg_name(name) for name in config.dependencies
    };
    if context.include_dev {
        for dev_name in config.dev_dependencies {
            manifest_python_names.add(norm_pkg_name(dev_name));
        }
    }
    for extra_dep in extras_deps {
        manifest_python_names.add(norm_pkg_name(extra_dep.name));
    }
    for cap_dep in capability_dependencies(config, scale=operation.scale) {
        if norm_pkg_name(cap_dep.name) in manifest_python_names {
            continue;
        }
        unresolved_backend.append(
            {
                "consumer_id": "root",
                "ecosystem": "python",
                "name": cap_dep.name,
                "constraint": cap_dep.version,
                "location": str(project_root),
                "dev": False,
                "unresolved": True
            }
        );
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
        if pkg.source == "path" {
            rel_location = os.path.relpath(pkg.key, str(project_root));
            # Keep relative form only when the path dep lives under the
            # project: transitive path deps of fetched git packages resolve
            # into the content store, and a "../.." lock row could never be
            # re-validated on a frozen replay.
            source_location = (
                rel_location if not rel_location.startswith("..") else pkg.key
            );
        } else {
            source_location = pkg.key;
        }
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
    # Carry the harvested pin sections ([python], [python_graph], [npm])
    # forward from the prior lock: commit_plan rewrites jac.lock from this
    # document and must not drop state the plan pipeline does not manage.
    for legacy_section in ("python", "python_graph", "npm") {
        prior_section = prior.get(legacy_section);
        if isinstance(prior_section, dict) and prior_section {
            lock_data[legacy_section] = prior_section;
        }
    }
    return ResolutionPlan(
        nodes=nodes,
        edges=edges,
        manifest_text=manifest_text,
        lock_data=lock_data,
        staged_materializations=staged,
        provider_resolutions=provider_resolutions,
        save_manifest=operation.save,
        dry_run=operation.dry_run
    );
}


def plan_operation(config: JacConfig, operation: PackageOperation) -> ResolutionPlan {
    if operation.ecosystem != "jac" {
        raise JacDepError(
            f"Unsupported package operation ecosystem '{operation.ecosystem}'; "
            "only pure-jac packages are supported here (python and npm deps "
            "go through 'jac install')"
        );
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
    candidate = _manifest_config(config, main_specs, dev_specs);
    manifest_text = serialize_toml(candidate.to_doc());
    return _build_plan(config, operation, candidate, manifest_text);
}

def _publish_packages(active: Path, generation_packages: Path) {
    # Atomically swap `active` to point at the new generation. Mirrored by
    # _recover_generation in dep_roots.py, which replays the same swap from
    # the transaction journal after a crash; keep the two in sync.
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


def commit_plan(config: JacConfig, plan: ResolutionPlan) -> None {
    if plan.dry_run {
        return;
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
        # transaction; frozen replays carry pinned rows only (no version
        # decisions, no network resolution).
        registry = get_provider_registry();
        for (ecosystem, resolution) in plan.provider_resolutions.items() {
            if not resolution.install_plan {
                continue;
            }
            backend_provider = registry.get(ecosystem);
            if backend_provider is None {
                continue;
            }
            # A fresh context on purpose: the plan is already resolved, so
            # this only replays exact pins. It must not inherit the CLI's
            # install flags (a dry-run never reaches commit) and stays
            # quiet regardless of --verbose.
            if not backend_provider.execute_install_plan(
                config, resolution, InstallContext()
            ) {
                raise JacDepError(
                    f"Could not sync '{ecosystem}' dependencies required by "
                    "pure-jac packages into the project environment"
                );
            }
        }
        if plan.save_manifest {
            # Fold the harvested pin sections ([python], [python_graph],
            # [npm]) into the staged lock here instead of rewriting
            # jac.lock after the commit: the backend sync above just
            # changed the venv, so pins read at plan time are already
            # stale, and folding keeps commit_plan the operation's single
            # jac.lock writer.
            harvest = harvest_python_lock(config, config.get_venv_dir());
            if harvest is not None {
                plan.lock_data["python"] = harvest[0];
                plan.lock_data["python_graph"] = harvest[1];
            }
            npm_pins = harvest_npm_lock(config);
            if npm_pins is not None {
                plan.lock_data["npm"] = npm_pins;
            }
        }
        write_atomic(stage / "deps.json", json.dumps(deps_data, indent=2) + "\n");
        if plan.save_manifest {
            # One lockfile writer: the same document builder write_lock uses,
            # so the [jac] compat rows derived from the graph come along.
            write_atomic(
                stage / "jac.lock", serialize_toml(_lock_doc(plan.lock_data)) + "\n"
            );
            write_atomic(stage / "jac.toml", plan.manifest_text);
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
        if plan.save_manifest {
            os.replace(str(stage / "jac.lock"), str(project_root / "jac.lock"));
            os.replace(str(stage / "jac.toml"), str(project_root / "jac.toml"));
        }
        journal.unlink(missing_ok=True);
    } finally {
        if not journal.is_file() {
            shutil.rmtree(stage, ignore_errors=True);
        }
    }
}
