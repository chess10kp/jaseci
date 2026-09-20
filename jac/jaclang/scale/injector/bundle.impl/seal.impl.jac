impl seal_step_env -> dict[str, str] {
    import from jaclang.server.session { SCRATCH_ENV }
    env = release_binary_env();
    env[SCRATCH_ENV] = "1";
    return env;
}


impl release_binary_env -> dict[str, str] {
    return {
        k: v
        for (k, v) in os.environ.items()
        if k not in _EXCLUDE_ENV
    };
}


impl _child_tree_script(
    jac_path: Path,
    work_dir: Path,
    timeout_s: int,
    rel_candidates: tuple[str, ...],
    fallback: Path
) -> Path {
    probe = work_dir / "_seal_probe.jac";
    try {
        probe.write_text('import jaclang;\nwith entry { print(jaclang.__file__); }\n');
        result = subprocess.run(
            [str(jac_path), "run", str(probe)],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=seal_step_env(),
            cwd=str(work_dir)
        );
    } except Exception {
        return fallback;
    } finally {
        probe.unlink(missing_ok=True);
    }
    if result.returncode != 0 {
        return fallback;
    }
    for line in reversed((result.stdout or "").splitlines()) {
        candidate = line.strip();
        if not candidate.endswith("__init__.py") {
            continue;
        }
        pkg_dir = Path(candidate).parent;
        for rel in rel_candidates {
            script = pkg_dir / rel;
            if script.is_file() {
                return script;
            }
        }
    }
    return fallback;
}


impl _legacy_sealer_script_for(
    jac_path: Path, stage_root: Path, timeout_s: int
) -> Path {
    return _child_tree_script(
        jac_path,
        stage_root,
        timeout_s,
        ("dist/precompile_bytecode.jac", "utils/precompile_bytecode.jac"),
        Path(str(__file__)).parent.parent.parent / "dist" / "precompile_bytecode.jac"
    );
}


impl _precompile_app(
    base: Path, seal_binary: bytes, sanitized_toml: (str | None), timeout_s: int
) -> Path {
    stage_root = _stage_app(base, sanitized_toml);
    stage = stage_root / "app";
    try {
        jac_path = stage_root / ".seal-jac";
        jac_path.write_bytes(seal_binary);
        jac_path.chmod(0o755);

        manifest_script = stage_root / "_serve_payloads.jac";
        manifest_script.write_text(
            "import from pathlib { Path }\n"
                + "import from jaclang.project.config { get_config_for_path }\n"
                + "import from jaclang.dist.seal { bake_serve_payloads }\n"
                + "with entry {\n"
                + "    project = Path('app').resolve();\n"
                + "    config = get_config_for_path(project);\n"
                + "    if not bake_serve_payloads(config, project, bake_client=False) {\n"
                + "        raise RuntimeError('Serving metadata preparation failed');\n"
                + "    }\n}\n"
        );
        prepared = subprocess.run(
            [str(jac_path), "run", str(manifest_script)],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=seal_step_env(),
            cwd=str(stage_root)
        );
        manifest_script.unlink();
        if prepared.returncode != 0 {
            raise RuntimeError(
                "App serving metadata preparation failed: "
                    + (prepared.stderr or prepared.stdout).strip()[-4000:]
            );
        }

        result = subprocess.run(
            [str(jac_path), "precompile", str(stage_root), "--seal"],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=seal_step_env(),
            cwd=str(stage_root)
        );
        if (
            result.returncode != 0
            and "invalid choice: 'precompile'" in (result.stderr or "")
        ) {
            logger.warning(
                "Seal binary predates 'jac precompile'; falling back to its "
                "legacy sealer script."
            );
            script = _legacy_sealer_script_for(jac_path, stage_root, timeout_s);
            result = subprocess.run(
                [str(jac_path), "run", str(script), str(stage_root), "--seal"],
                capture_output=True,
                text=True,
                timeout=timeout_s,
                env=seal_step_env(),
                cwd=str(stage_root)
            );
        }
        jac_path.unlink();
        if (
            result.returncode != 0
            or not (stage / "_precompiled" / "MANIFEST.json").is_file()
        ) {
            for stream_line in (
                (result.stderr or "") + "\n" + (result.stdout or "")
            ).splitlines() {
                if stream_line.strip() {
                    logger.error(f"seal stderr: {stream_line.rstrip()}");
                }
            }
            raise RuntimeError(
                f"App seal did not complete, so the deploy cannot produce a "
                f".jab: {(result.stderr or result.stdout).strip()[-2000:]}"
            );
        }
        for line in (result.stdout or "").splitlines()[-12:] {
            if line.strip() {
                logger.info(f"seal: {line.strip()}");
            }
        }
        return stage;
    } except Exception {
        remove_stage_root(stage_root);
        raise;
    }
}


impl fat_bundle_setting(project_dir: str) -> tuple[bool, bool] {
    import from jaclang.project.config { get_config_for_path }

    try {
        config = get_config_for_path(Path(project_dir));
    } except Exception as exc {
        logger.warning(f"fat_bundle check skipped, jac.toml unparseable: {exc}");
        return (False, False);
    }
    if config is None {
        return (False, False);
    }
    section = config.get_section("scale");
    if section is None or "fat_bundle" not in section {
        return (True, False);
    }
    return (bool(section.get("fat_bundle")), True);
}


impl fat_bundle_enabled(project_dir: str) -> bool {
    (enabled, _) = fat_bundle_setting(project_dir);
    return enabled;
}


impl seal_timeout_setting(project_dir: str) -> int {
    import from jaclang.project.config { get_config_for_path }

    try {
        config = get_config_for_path(Path(project_dir));
    } except Exception as exc {
        logger.warning(f"seal_timeout check skipped, jac.toml unparseable: {exc}");
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    if config is None {
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    section = config.get_section("scale");
    if section is None or "seal_timeout" not in section {
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    try {
        val = int(section.get("seal_timeout"));
    } except (TypeError, ValueError) {
        logger.warning("Ignoring non-integer [scale] seal_timeout in jac.toml.");
        return DEFAULT_SEAL_TIMEOUT_S;
    }
    return val if val > 0 else DEFAULT_SEAL_TIMEOUT_S;
}


impl _pod_wheel_platform(pod_arch: str) -> str {
    if not pod_arch {
        return "";
    }
    return f"manylinux_2_36_{pod_arch}";
}


impl _vendor_stage(stage: Path, seal_binary: bytes, platform_tag: str = "") {
    jac_path = stage.parent / ".seal-jac";
    jac_path.write_bytes(seal_binary);
    jac_path.chmod(0o755);
    script = _child_tree_script(
        jac_path,
        stage.parent,
        900,
        ("scale/utils/vendor_wheels.jac", ),
        Path(str(__file__)).parent.parent / "utils" / "vendor_wheels.jac"
    );
    cmd = [str(jac_path), "run", str(script), str(stage)];
    if platform_tag {
        cmd.append(platform_tag);
    }
    try {
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=900,
            env=seal_step_env(),
            cwd=str(stage.parent)
        );
    } finally {
        jac_path.unlink(missing_ok=True);
    }
    if (result.returncode != 0 or not (stage / "_vendor" / "VENDOR.json").is_file()) {
        raise RuntimeError(
            f"Fat bundle vendoring failed, so the deploy cannot ship offline "
            f"deps: {(result.stderr or result.stdout).strip()[-300:]}"
        );
    }

    for line in f"{result.stdout}\n{result.stderr}".splitlines() {
        if line.strip() {
            logger.info(f"vendor: {line.strip()}");
        }
    }
}


impl _resolved_python_specs(stage: Path) -> list[str] {
    import from jaclang.project.config { JacConfig }
    import from jaclang.project.providers { get_python_provider, resolve_plan }
    config = JacConfig.load(stage / "jac.toml");
    deps = resolve_plan(config).for_ecosystem("python");
    return get_python_provider().specs_for(deps);
}


impl _strip_external_record_lines(site: Path) {
    for record in sorted(site.`glob("*.dist-info/RECORD")) {
        lines = record.read_text(encoding="utf-8").splitlines(keepends=True);
        kept = [
            line
            for line in lines
            if not line.startswith("../")
        ];
        if len(kept) != len(lines) {
            record.write_text("".join(kept), encoding="utf-8");
        }
    }
}


impl staged_venv_files(stage: Path) -> list[Path] {
    import from jaclang.project.providers { VENV_DEPS_MARKER }
    import from jaclang.project.pyvenv { get_venv_site_packages }
    venv = stage / ".jac" / "venv";
    marker = venv / VENV_DEPS_MARKER;
    if not marker.is_file() {
        return [];
    }
    site = get_venv_site_packages(venv);
    if not site.is_dir() {
        return [];
    }
    files = [marker];
    for path in sorted(site.rglob("*")) {
        if (
            path.is_file() and path.suffix != ".pyc" and "__pycache__" not in path.parts
        ) {
            files.append(path);
        }
    }
    return files;
}


impl _prune_seed_pip(site: Path, specs: list[str]) {
    import re;
    for spec in specs {
        if re.split(r"[<>=!~\[ ;@]", spec.strip())[0].lower() == "pip" {
            return;
        }
    }
    for item in sorted(site.iterdir()) {
        if item.name == "pip"
            or (item.name.startswith("pip-") and item.name.endswith(".dist-info")) {
            shutil.rmtree(str(item), ignore_errors=True);
        }
    }
}


impl _venv_stage(stage: Path, seal_binary: bytes, timeout_s: int) {
    jac_path = stage.parent / ".seal-jac";
    jac_path.write_bytes(seal_binary);
    jac_path.chmod(0o755);
    env = seal_step_env();

    env["PIP_NO_INDEX"] = "1";
    env["PIP_FIND_LINKS"] = str(stage / "_vendor" / "wheels");
    env["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    try {
        result = subprocess.run(
            [str(jac_path), "install"],
            capture_output=True,
            text=True,
            timeout=timeout_s,
            env=env,
            cwd=str(stage)
        );
    } finally {
        jac_path.unlink(missing_ok=True);
    }
    if result.returncode != 0 {
        raise RuntimeError(
            f"seal-time venv build failed (host cannot install the "
            f"pod-platform wheels?): "
            f"{(result.stderr or result.stdout).strip()[-300:]}"
        );
    }
    venv = stage / ".jac" / "venv";
    import from jaclang.project.pyvenv { get_venv_site_packages }
    site = get_venv_site_packages(venv);
    if not site.is_dir() {
        raise RuntimeError(f"seal-time venv build left no site-packages under {venv}");
    }
    specs = _resolved_python_specs(stage);
    _prune_seed_pip(site, specs);
    _strip_external_record_lines(site);
    import from jaclang.project.providers { write_venv_deps_marker }
    write_venv_deps_marker(venv, specs);
}
