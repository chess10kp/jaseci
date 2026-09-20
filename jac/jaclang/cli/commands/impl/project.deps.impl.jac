import os;
import from pathlib { Path }
import from jaclang.cli.console { console }


impl install(
    packages: list[str] = [],
    editable: list[any] = [],
    dev: bool = False,
    extras: list[str] = [],
    no_save: bool = False,
    git: str = "",
    npm: bool | None = None,
    shadcn: bool = False,
    verbose: bool = False,
    force_reinstall: bool = False,
    no_cache_dir: bool = False,
    pre: bool = False,
    dry_run: bool = False,
    no_deps: bool = False,
    quiet: bool = False,
    prefer_binary: bool = False,
    install_global: bool = False,
    scale: bool = False,
    plan: bool = False,
    as_json: bool = False
) -> int {
    if plan {
        return deps(scale=scale, as_json=as_json);
    }
    if shadcn or npm {
        channel = "--shadcn" if shadcn else "--npm";

        flag_checks: list[tuple[bool, str]] = [
            (no_save, "--no-save"),
            (dry_run, "--dry-run")
        ];
        if shadcn {
            flag_checks.append((install_global, "--global"));
        }
        ineffective: list[str] = [
            flag
            for (enabled, flag) in flag_checks
            if enabled
        ];
        if ineffective {
            console.warning(
                f"{', '.join(ineffective)} has no effect with {channel} "
                "(it applies only to Python venv installs)."
            );
        }
    }
    if shadcn {
        import from jaclang.cli.shadcn.cli { run_shadcn_add }
        return run_shadcn_add(packages);
    }
    if npm {
        import from jaclang.client.cli { run_npm_add }
        return run_npm_add(packages, dev, install_global);
    }
    import from pathlib { Path }
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv {
        ensure_venv,
        get_venv_site_packages,
        make_git_spec
    }
    import from jaclang.project.providers {
        InstallContext,
        get_provider_registry,
        get_python_provider,
        resolve_plan
    }

    flag_defs: list[tuple[bool, str]] = [
        (force_reinstall, "--force-reinstall"),
        (no_cache_dir, "--no-cache-dir"),
        (pre, "--pre"),
        (dry_run, "--dry-run"),
        (no_deps, "--no-deps"),
        (quiet, "--quiet"),
        (prefer_binary, "--prefer-binary"),

    ];
    install_flags: list[str] = [
        flag
        for (enabled, flag) in flag_defs
        if enabled
    ];
    python = get_python_provider();
    ctx = InstallContext(verbose=verbose, install_flags=install_flags);
    global_ctx = InstallContext(
        verbose=verbose, install_flags=install_flags, target="global"
    );

    if packages or git {
        if editable {
            console.error(
                "Cannot mix package names or --git with -e/--editable in a single command. "
                "Run them separately: 'jac install <pkg>' then 'jac install -e <path>'."
            );
            return 1;
        }
        save = not (no_save or install_global or dry_run);
        if extras {
            console.warning(
                "--extras has no effect with package names; "
                "declare optional groups in jac.toml instead."
            );
        }
        if dev and not save {
            console.warning(
                "--dev has no effect with --no-save/--global/--dry-run "
                "(nothing is recorded in jac.toml)."
            );
        }
        if install_global {
            specs: list[str] = list(packages);
            if git {
                specs.append(make_git_spec(git));
            }
            console.print(
                f"\nInstalling {len(specs)} package(s) into the global site",
                style="bold"
            );
            if not python.install_specs(None, specs, global_ctx) {
                return 1;
            }
            if dry_run {
                console.success("Dry run complete (nothing installed).");
                return 0;
            }
            console.success("Package(s) installed into the global site");
            return 0;
        }
        config = get_config();
        if config is None {
            console.error(
                "No jac.toml found",
                hint="Run 'jac create' first; packages install into the project's .jac/venv (or pass --global)."
            );
            return 1;
        }
        if git {
            if len(packages) > 1 {
                console.error(
                    f"Pass at most one name with --git (used as the dependency "
                    f"alias); got {len(packages)}: {', '.join(packages)}.",
                    hint="Install additional packages separately: 'jac install <pkg>'."
                );
                return 1;
            }
            if packages {
                pkg_name = packages[0];
            } else {
                pkg_name = git.rstrip("/").split("/")[-1];
                if pkg_name.endswith(".git") {
                    pkg_name = pkg_name[:-4];
                }
            }
            console.print(f"\nAdding {pkg_name} from git", style="bold");
            console.print(f"  Repository: {git}", style="muted");
            with console.status(
                f"Installing {pkg_name}...", spinner="dots"
            ) as status {
                git_success = python.install_specs(config, [make_git_spec(git)], ctx);
            }
            if not git_success {
                console.error(f"Failed to install {pkg_name}");
                return 1;
            }
            if dry_run {
                console.success("Dry run complete (nothing installed).");
                return 0;
            }
            console.print(f"  ✔ {pkg_name}", style="success");
            if save {
                config.add_dependency(pkg_name, git, dev=dev, dep_type="git");
                config.save();
                console.print(
                    f"\n  ✔ Updated jac.toml [dependencies.git]", style="muted"
                );
            }
            return 0;
        }
        if not save {
            console.print(
                f"\nInstalling {len(packages)} package(s) into {config.get_venv_dir()}",
                style="bold"
            );
            return 0 if python.install_specs(config, packages, ctx) else 1;
        }
        console.print(f"\nAdding {len(packages)} Python package(s)", style="bold");
        parsed = [python.parse_spec(pkg_spec) for pkg_spec in packages];
        with console.status(
            f"Installing {len(packages)} package(s)...", spinner="dots"
        ) as status {
            recorded = python.add_packages(config, parsed, dev, ctx);
        }
        if recorded is None {
            console.error("Failed to install package(s)");
            return 1;
        }
        for ((name, _), version_str) in zip(parsed, recorded) {
            console.print(f"  ✔ {name} ({version_str})", style="success");
        }
        try {
            config.save();
            section = "dev-dependencies" if dev else "dependencies";
            console.print(f"\n  ✔ Updated jac.toml [{section}]", style="muted");
        } except Exception as e {
            console.error(f"Could not save jac.toml: {e}");
            return 1;
        }
        return 0;
    }

    editable = [p for group in (editable or []) for p in group];
    if editable {
        import from jaclang.dist.publish.builder { WheelBuilder }

        editable_targets: list[tuple[JacConfig, Path]] = [];
        all_dep_specs: list[str] = [];
        for editable_path in editable {
            src_dir: Path = Path(editable_path).resolve();
            if not src_dir.is_dir() {
                console.error(
                    f"'{editable_path}' is not a directory.",
                    hint=f"Use 'jac install {editable_path}' to install from PyPI, or pass a local path to -e."
                );
                return 1;
            }
            config = get_config(start_path=src_dir, force_discover=True);
            if config is None {
                console.error(
                    "No jac.toml found",
                    hint=f"Make sure {src_dir} contains a jac.toml."
                );
                return 1;
            }
            dep_specs = python.specs_for(
                [
                    d
                    for d in python.resolve(config, include_dev=dev)
                    if d.source == "pypi"
                ]
            );
            if extras {
                try {
                    extra_deps = python.resolve_extras(config, extras);
                    dep_specs.extend(python.specs_for(extra_deps));
                } except ValueError as e {
                    console.warning(
                        f"  Skipping extras for {config.project.name}: {e}"
                    );
                }
            }
            all_dep_specs.extend(dep_specs);
            editable_targets.append((config, src_dir));
            console.print(
                f"\nEditable: {config.project.name} ({src_dir})", style="bold"
            );
        }

        if install_global {
            if all_dep_specs {
                console.print(
                    f"\n  Installing {len(
                        all_dep_specs
                    )} dependencies into the global site...",
                    style="muted"
                );
                if not python.install_specs(None, all_dep_specs, global_ctx) {
                    return 1;
                }
            }
            if dry_run {
                console.print(
                    "  ✔ Dry run complete (nothing installed).", style="success"
                );
                return 0;
            }
            import site;
            site_pkgs = Path(site.getsitepackages()[0]);
        } else {
            host_config = get_config(force_discover=True);
            if host_config is None {
                console.error(
                    "No jac.toml found",
                    hint="Run 'jac create' first; `jac install -e` links into the current project's .jac/venv (or pass --global)."
                );
                return 1;
            }
            if all_dep_specs {
                console.print(
                    f"\n  Installing {len(all_dep_specs)} dependencies into {host_config.get_venv_dir()}...",
                    style="muted"
                );
                if not python.install_specs(host_config, all_dep_specs, ctx) {
                    return 1;
                }
            }
            if dry_run {
                console.print(
                    "  ✔ Dry run complete (nothing installed).", style="success"
                );
                return 0;
            }
            ensure_venv(host_config.get_venv_dir(), verbose);
            site_pkgs = get_venv_site_packages(host_config.get_venv_dir());
        }

        for (config, src_dir) in editable_targets {
            WheelBuilder(config=config).install_editable(src_dir, site_pkgs);
            console.print(f"  ✔ Linked {src_dir}", style="success");
        }
        console.print("  ✔ Editable install complete.", style="success");
        return 0;
    }

    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    console.print(f"\nInstalling dependencies for {config.project.name}", style="bold");
    console.print(f"  Virtual environment: {config.get_venv_dir()}", style="muted");
    console.print();
    try {
        dep_plan = resolve_plan(config, include_dev=dev, extras=extras, scale=scale);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    if extras {
        console.print(f"  Extras: {', '.join(extras)}", style="muted");
    }
    if dep_plan.is_empty() {
        console.info("No dependencies to install.");
        return 0;
    }

    install_success = True;
    python_deps = dep_plan.for_ecosystem("python");
    if python_deps {
        with console.status(
            f"Installing {len(python_deps)} package(s)...", spinner="dots"
        ) as status {
            install_success = python.install_all(config, python_deps, ctx);
        }
    }

    if dry_run {
        return 0 if install_success else 1;
    }
    plugin_failed = False;
    for provider in get_provider_registry().all() {
        if provider.name == "python" {
            continue;
        }
        if provider.name == "npm" and npm is False {
            console.print("\n  Skipping npm dependencies (--no-npm)", style="muted");
            continue;
        }
        provider_deps = dep_plan.for_ecosystem(provider.name);
        if not provider_deps {
            continue;
        }
        console.print(f"\n  Installing {provider.name} dependencies", style="muted");
        try {
            provider.install_all(config, provider_deps, ctx);
            console.print(
                f"  ✔ {provider.name} dependencies installed", style="success"
            );
        } except Exception as e {
            console.error(f"  ✗ {provider.name} dependencies failed: {e}");
            plugin_failed = True;
        }
    }
    if install_success and not plugin_failed {
        console.success("All dependencies installed");
        return 0;
    } else {
        console.error("Some dependencies failed to install");
        return 1;
    }
}

def _bootstrap_project_deps(project_path: Path) -> bool {
    import from jaclang.project.config { get_config, set_config }
    prev = os.getcwd();
    prev_cfg = get_config();
    try {
        os.chdir(str(project_path));

        set_config(get_config(start_path=project_path, force_discover=True));
        return install() == 0;
    } except Exception as e {
        console.warning(f"Could not install dependencies: {e}");
        console.print(
            "  Run 'jac install' in the project directory when ready.\n", style="muted"
        );
        return False;
    } finally {
        os.chdir(prev);
        set_config(prev_cfg);
    }
}

impl remove(
    packages: list[str] = [], dev: bool = False, npm: bool = False, shadcn: bool = False
) -> int {
    if shadcn {
        import from jaclang.cli.shadcn.cli { run_shadcn_remove }
        return run_shadcn_remove(packages);
    }
    if npm {
        import from jaclang.client.cli { run_npm_remove }
        return run_npm_remove(packages, dev);
    }
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { InstallContext, get_python_provider }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project."
        );
        return 1;
    }
    if not packages {
        console.error("No packages specified.");
        return 1;
    }
    python = get_python_provider();
    ctx = InstallContext();
    for name in packages {
        if python.remove_package(config, name, dev, ctx) {
            console.success(f"Removed {name} from jac.toml");
        } else {
            console.error(f"Package {name} not found in dependencies");
        }
    }
    try {
        config.save();
        console.success("Updated jac.toml");
    } except Exception as e {
        console.error(f"Could not save jac.toml: {e}");
        return 1;
    }
    return 0;
}

impl update(packages: list[str] = [], dev: bool = False, verbose: bool = False) -> int {
    import from jaclang.project.config { get_config }
    import from jaclang.project.pyvenv { make_git_spec }
    import from jaclang.project.providers { InstallContext, get_python_provider, _major_minor }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    python = get_python_provider();
    ctx = InstallContext(verbose=verbose);

    specs_to_update: list[str] = [];
    names_to_update: list[str] = [];
    if packages {
        for pkg_spec in packages {
            (name, version) = python.parse_spec(pkg_spec);
            if name in config.dependencies {
                specs_to_update.append(name);
                names_to_update.append(name);
            } elif name in config.dev_dependencies {
                specs_to_update.append(name);
                names_to_update.append(name);
            } elif name in config.git_dependencies {
                git_info = config.git_dependencies[name];
                if isinstance(git_info, dict) and "git" in git_info {
                    specs_to_update.append(
                        make_git_spec(git_info["git"], git_info.get("branch", ""))
                    );
                    names_to_update.append(name);
                }
            } else {
                console.error(f"Package '{name}' not found in dependencies.");
                return 1;
            }
        }
    } else {
        for (name, version) in config.dependencies.items() {
            specs_to_update.append(name);
            names_to_update.append(name);
        }
        if dev {
            for (name, version) in config.dev_dependencies.items() {
                specs_to_update.append(name);
                names_to_update.append(name);
            }
        }
        for (name, git_info) in config.git_dependencies.items() {
            if isinstance(git_info, dict) and "git" in git_info {
                specs_to_update.append(
                    make_git_spec(git_info.get("git", ""), git_info.get("branch", ""))
                );
            }
            names_to_update.append(name);
        }
    }
    if not specs_to_update {
        console.info("No dependencies to update.");
        return 0;
    }
    console.print(
        f"\nUpdating {len(specs_to_update)} package(s) for {config.project.name}",
        style="bold"
    );
    with console.status(
        f"Updating {len(specs_to_update)} package(s)...", spinner="dots"
    ) as status {
        update_success = python.install_specs(config, specs_to_update, ctx);
    }
    if not update_success {
        console.error("Some packages failed to update.");
        return 1;
    }

    updated_count = 0;
    for name in names_to_update {
        if name in config.git_dependencies {
            continue;
        }
        installed_version = python.get_installed_version(config, name);
        if installed_version {
            new_spec = f"~={_major_minor(installed_version)}";

            current_spec = config.dependencies.get(
                name, config.dev_dependencies.get(name, "")
            );
            if current_spec.startswith("~=") or not current_spec {
                if name in config.dependencies {
                    config.dependencies[name] = new_spec;
                    updated_count += 1;
                } elif name in config.dev_dependencies {
                    config.dev_dependencies[name] = new_spec;
                    updated_count += 1;
                }
                console.print(
                    f"  ✔ {name} -> {installed_version} ({new_spec})", style="success"
                );
            } else {
                console.print(
                    f"  ✔ {name} -> {installed_version} (spec unchanged: {current_spec})",
                    style="success"
                );
            }
        }
    }
    if updated_count > 0 {
        try {
            config.save();
            console.print(
                f"\n  ✔ Updated {updated_count} version(s) in jac.toml", style="muted"
            );
        } except Exception as e {
            console.error(f"Could not save jac.toml: {e}");
            return 1;
        }
    }
    console.success("Dependencies updated");
    return 0;
}

impl deps(scale: bool = False, as_json: bool = False) -> int {
    import json;
    import from jaclang.project.config { get_config }
    import from jaclang.project.providers { resolve_plan }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found", hint="Run 'jac create' to create a project first."
        );
        return 1;
    }
    try {
        plan = resolve_plan(config, include_dev=True, scale=scale);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    if as_json {
        payload = [
            {
                "name": d.name,
                "version": d.version,
                "ecosystem": d.ecosystem,
                "source": d.source,
                "origin": d.origin,
                "dev": d.dev
            } for d in plan.deps
        ];
        console.print(json.dumps(payload, indent=2));
        return 0;
    }
    if plan.is_empty() {
        console.info("No dependencies resolved for this project.");
        return 0;
    }
    console.print(
        f"\nResolved dependency plan for {config.project.name}", style="bold"
    );
    for ecosystem in plan.ecosystems() {
        eco_deps = plan.for_ecosystem(ecosystem);
        console.print(f"\n  [{ecosystem}] ({len(eco_deps)})", style="info");
        width = max([len(d.name) for d in eco_deps]);
        for d in sorted(eco_deps, key=lambda (d) { (d.origin, d.name); }) {
            dev_marker = "  (dev)" if d.dev else "";
            version = d.version or "*";
            console.print(
                f"    {d.name.ljust(width)}  {version}{dev_marker}  -- {d.origin}",
                style="muted"
            );
        }
    }
    console.print(
        f"\n  {len(plan.deps)} dependencies across "
        f"{len(plan.ecosystems())} ecosystem(s)",
        style="success"
    );
    return 0;
}
