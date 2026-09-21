import json;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.project.dependency_model {
    DependencyEdge,
    DependencyNode,
    ProviderRequirement,
    ProviderResolution,
    ResolutionContext,
    canonical_dependency_id,
    normalize_dependency_name
}
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    ResolvedDependency,
    manifest_plugin_deps
}
import from jaclang.client.client_bundle { ClientBundleError }

glob CORE_RUNTIME_DEPS: dict[str, str] = {
         "react": "^19.2.0",
         "react-dom": "^19.2.0",
         "react-router-dom": "^6.22.0",
         "react-error-boundary": "^5.0.0"
     },
     OPTIONAL_RUNTIME_DEPS: dict[str, str] = {
         "@tanstack/react-form": "^1.33.0",
         "zod": "^4.3.6"
     },
     CORE_DEV_DEPS: dict[str, str] = {
         "vite": "^6.4.1",
         "@vitejs/plugin-react": "^4.7.0",
         "typescript": "^5.3.3",
         "@types/react": "^19.2.0",
         "@types/react-dom": "^19.2.0"
     },
     LEGACY_META_PACKAGES: set = {"jac-client-node", "@jac-client/dev-deps"};


def target_scoped_npm_deps(config: JacConfig, target_name: str) -> dict[str, str] {
    npm_plugin_deps: dict[str, str] = dict(config.plugin_dependencies.get("npm", {}));
    deps: dict[str, str] = {};
    key1 = str(target_name or "").strip();
    keys = [key1, key1.replace("_", "-"), key1.replace("-", "_")];
    for key in dict.fromkeys(keys) {
        if key == "" {
            continue;
        }
        section = npm_plugin_deps.get(key, {});
        if isinstance(section, dict) {
            for (name, version) in section.items() {
                if isinstance(version, str) {
                    deps[name] = version;
                }
            }
        }
    }
    return deps;
}


def _app_wants_client(config: JacConfig, app: any) -> bool {
    import from jaclang.project.kinds { kind_has_client }
    return app.implicit or kind_has_client(app.kind);
}


def app_npm_deps(config: JacConfig) -> list[tuple[str, str, str, bool]] {
    import from jaclang.client.targets.registry { KIND_TARGET }
    (base_deps, base_dev) = manifest_plugin_deps(config, "npm");
    out: list[tuple[str, str, str, bool]] = [];
    seen: dict[tuple[str, bool], tuple[str, str]] = {};

    def _add(name: str, version: str, origin: str, dev: bool) {
        key = (name, dev);
        first = seen.get(key);
        if first is not None {
            if first[1] != version {
                import from jaclang.cli.console { console }
                console.warning(
                    f"npm dependency '{name}' is pinned to '{first[1]}' by "
                    f"{first[0]} and to '{version}' by {origin}; using "
                    f"'{first[1]}' ({first[0]} was declared first)"
                );
            }
            return;
        }
        seen[key] = (origin, version);
        out.append((name, version, origin, dev));
    }

    for app in (list(config.apps.values()) or [config.resolve_app("")]) {
        if not _app_wants_client(config, app) {
            continue;
        }
        target_name = KIND_TARGET.get(config.resolved_kind(app), "web");
        effective = (
            config.effective_for_app(app.name) if app.name in config.apps else config
        );
        for (name, version) in target_scoped_npm_deps(effective, target_name).items() {
            _add(name, version, f"target:{target_name}", False);
        }
        if app.implicit {
            continue;
        }
        (app_deps, app_dev) = manifest_plugin_deps(effective, "npm");
        for (name, version) in app_deps.items() {
            if name not in base_deps {
                _add(name, version, f"app:{app.name}", False);
            }
        }
        for (name, version) in app_dev.items() {
            if name not in base_dev {
                _add(name, version, f"app:{app.name}", True);
            }
        }
    }
    return out;
}


def regenerate_and_install(project_dir: Path) {
    import from jaclang.client.vite_bundler { ViteBundler }
    import from jaclang.client { get_bun }
    import from jaclang.client.bun_installer { bun_unavailable_message }

    bun = get_bun();
    if not bun {
        raise RuntimeError(bun_unavailable_message()) from None;
    }

    bundler = ViteBundler(project_dir);
    bundler.create_package_json();

    try {
        bundler.install_packages(force=True);
    } except ClientBundleError as e {
        raise RuntimeError(f"Failed to install packages: {e}") from e;
    }
}


obj NpmProvider(EcosystemProvider) {
    has name: str = "npm",
        manifest_key: str = "npm",
        cli_flag: str = "--npm";

    def install_global(packages: list[str], dev: bool) -> bool {
        # Global npm tools live in the shared jac npm root (~/.jac/npm),
        # outside any project manifest and jac.lock, mirroring the python
        # provider's --global path (which also skips the lock).
        import subprocess;
        import from jaclang.cli.console { console }
        import from jaclang.client.bun_installer { get_bun, bun_unavailable_message }
        import from jaclang.project.tool_paths { node_root }
        bun = get_bun();
        if bun is None {
            console.error(bun_unavailable_message());
            return False;
        }
        dest = node_root("global");
        assert dest is not None , "the global npm root is always resolvable";
        dest.mkdir(parents=True, exist_ok=True);
        pkg_json = dest / "package.json";
        if not pkg_json.exists() {
            pkg_json.write_text(
                '{\n  "name": "jac-global-tools",\n  "private": true\n}\n',
                encoding="utf-8"
            );
        }
        cmd: list[str] = [bun, "add"];
        if dev {
            cmd.append("--dev");
        }
        cmd.extend(packages);
        console.print(
            f"\n📦 Installing {len(packages)} npm tool(s) globally into {dest}",
            style="bold"
        );
        result = subprocess.run(cmd, cwd=str(dest));
        if result.returncode != 0 {
            console.error("Global npm install failed.");
            return False;
        }
        return True;
    }

    override def resolve_requirements(
        context: ResolutionContext,
        requirements: list[ProviderRequirement],
        prior_lock: any
    ) -> ProviderResolution {
        resolution = ProviderResolution();
        selected: list[ProviderRequirement] = [
            requirement
            for requirement in requirements
            if requirement.ecosystem == self.name
        ];
        if not selected {
            return resolution;
        }
        project_root = Path(selected[0].location or Path.cwd());
        lock_path = project_root / "package-lock.json";
        lock_payload: dict[str, any] = {};
        if lock_path.is_file() {
            lock_payload = json.loads(lock_path.read_text(encoding="utf-8"));
        }
        package_rows = lock_payload.get("packages", {});
        package_rows = package_rows if isinstance(package_rows, dict) else {};
        by_name: dict[str, str] = {};
        # One pass builds the node table; dependency edges are collected
        # here and resolved in a second pass because a child may appear
        # before its parent in the lockfile.
        child_requirements: list[tuple[str, dict[str, any]]] = [];
        for (package_path, package_data) in package_rows.items() {
            if (
                not isinstance(package_data, dict)
                or not package_path.startswith("node_modules/")
            ) {
                continue;
            }
            package_name = package_path[len("node_modules/"):];
            if "/node_modules/" in package_name {
                package_name = package_name.rsplit("/node_modules/", 1)[1];
            }
            normalized = normalize_dependency_name(self.name, package_name);
            node_id = canonical_dependency_id(self.name, normalized);
            by_name[normalized] = node_id;
            resolution.nodes[node_id] = DependencyNode(
                id=node_id,
                ecosystem=self.name,
                alias=normalized,
                project_name=package_name,
                source="npm",
                source_location=str(lock_path),
                version=str(package_data.get("version", "")),
                dev=bool(package_data.get("dev", False))
            );
            resolution.install_plan.append(
                {
                    "id": node_id,
                    "name": package_name,
                    "version": str(package_data.get("version", "")),
                    "resolved": str(package_data.get("resolved", "")),
                    "integrity": str(package_data.get("integrity", ""))
                }
            );
            child_requirements.append(
                (normalized, package_data.get("dependencies", {}))
            );
        }
        for requirement in selected {
            normalized = normalize_dependency_name(self.name, requirement.name);
            node_id: str = by_name.get(normalized) or "";
            if not node_id {
                node_id = canonical_dependency_id(self.name, normalized);
                resolution.nodes[node_id] = DependencyNode(
                    id=node_id,
                    ecosystem=self.name,
                    alias=normalized,
                    project_name=requirement.name,
                    source="npm",
                    source_location=str(lock_path),
                    version=requirement.constraint,
                    dev=requirement.dev
                );
            }
            resolution.edges.append(
                DependencyEdge(
                    from_id=requirement.consumer_id or "root",
                    to_id=node_id,
                    kind="requirement",
                    requirement=requirement.constraint,
                    dev=requirement.dev
                )
            );
        }
        for (parent_name, children) in child_requirements {
            from_id: str = by_name.get(parent_name) or "";
            if not from_id {
                continue;
            }
            for (child_name, child_constraint) in children.items() {
                to_id = by_name.get(normalize_dependency_name(self.name, child_name));
                if to_id is not None {
                    resolution.edges.append(
                        DependencyEdge(
                            from_id=from_id,
                            to_id=to_id,
                            kind="dependency",
                            requirement=str(child_constraint)
                        )
                    );
                }
            }
        }
        return resolution;
    }

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        (deps, dev_deps) = manifest_plugin_deps(config, "npm");
        is_client = "client" in config.plugins;
        resolved: list[ResolvedDependency] = [];
        for (pkg, version) in deps.items() {
            if is_client and pkg in LEGACY_META_PACKAGES {
                continue;
            }
            resolved.append(
                ResolvedDependency(
                    name=pkg,
                    version=version,
                    ecosystem="npm",
                    source="npm",
                    origin="manifest"
                )
            );
        }

        for (pkg, version) in dev_deps.items() {
            if is_client and pkg in LEGACY_META_PACKAGES {
                continue;
            }
            resolved.append(
                ResolvedDependency(
                    name=pkg,
                    version=version,
                    ecosystem="npm",
                    source="npm",
                    origin="manifest",
                    dev=True
                )
            );
        }
        if is_client {
            core_runtime = {** CORE_RUNTIME_DEPS, ** OPTIONAL_RUNTIME_DEPS};
            for (pkg, version) in core_runtime.items() {
                if pkg not in deps {
                    resolved.append(
                        ResolvedDependency(
                            name=pkg,
                            version=version,
                            ecosystem="npm",
                            source="npm",
                            origin="self-heal:client-core"
                        )
                    );
                }
            }
            for (pkg, version) in CORE_DEV_DEPS.items() {
                if pkg not in dev_deps {
                    resolved.append(
                        ResolvedDependency(
                            name=pkg,
                            version=version,
                            ecosystem="npm",
                            source="npm",
                            origin="self-heal:client-core",
                            dev=True
                        )
                    );
                }
            }
            for (pkg, version, origin, is_dev) in app_npm_deps(config) {
                resolved.append(
                    ResolvedDependency(
                        name=pkg,
                        version=version,
                        ecosystem="npm",
                        source="npm",
                        origin=origin,
                        dev=is_dev
                    )
                );
            }
        }
        return resolved;
    }

    override def parse_spec(spec: str) -> tuple[str, str] {
        import re;
        spec = spec.strip();
        scoped = re.`match(r"^(@[a-zA-Z0-9_-]+/[a-zA-Z0-9_.-]+)@(.+)$", spec);
        if scoped {
            return (scoped.group(1), scoped.group(2));
        }
        plain = re.`match(r"^([a-zA-Z0-9_.-]+)@(.+)$", spec);
        if plain {
            return (plain.group(1), plain.group(2));
        }
        return (spec, "");
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        if not deps {
            return True;
        }

        import os;
        if os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL") {
            return True;
        }
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        regenerate_and_install(Path(str(config.project_root)));
        return True;
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        package_version: str = version or "latest";

        (deps, dev_deps) = manifest_plugin_deps(config, "npm");
        previous = (dev_deps if dev else deps).get(name);
        config.add_dependency(name, package_version, dev=dev, dep_type="npm");
        config.save();
        try {
            regenerate_and_install(Path(str(config.project_root)));
        } except Exception {
            if previous is not None {
                config.add_dependency(name, previous, dev=dev, dep_type="npm");
            } else {
                config.remove_dependency(name, dev=dev, dep_type="npm");
            }
            config.save();
            raise;
        }
        return package_version;
    }

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        if config.project_root is None {
            raise RuntimeError("No project root found");
        }
        (deps, dev_deps) = manifest_plugin_deps(config, "npm");
        previous = (dev_deps if dev else deps).get(name);
        if not config.remove_dependency(name, dev=dev, dep_type="npm") {
            return False;
        }
        config.save();
        try {
            regenerate_and_install(Path(str(config.project_root)));
        } except Exception {
            if previous is not None {
                config.add_dependency(name, previous, dev=dev, dep_type="npm");
                config.save();
            }
            raise;
        }
        return True;
    }
}
