impl ManifestBuilder._build_client_bundle(project_dir: str) {
    import os;
    import shutil;
    import subprocess;
    import from pathlib { Path }
    import from jaclang.cli.console { console }
    import from jaclang.scale.injector.binary { host_toolchain_path }
    import from jaclang.scale.injector.bundle {
        _stage_app,
        release_binary_env,
        remove_stage_root,
        sanitized_jac_toml,
        source_filter_for
    }
    import from jaclang.scale.runtime.context.util { jac_executable }
    client_entry = self._client_entry();
    if client_entry
        and not self._declared_client_entry()
        and not self._has_client_source() {
        client_entry = "";
    }
    if not client_entry {
        if self.client_entry is not None {
            console.print(
                "The deploy declares no client entry (client_entry = \"\"); "
                "skipping the client build."
            );
        } else {
            console.print(
                "The served app has no client target and the project has no "
                "client source (no pages/ or components/ directory, no "
                "[client] table in jac.toml); skipping the client build."
            );
        }
        return;
    }
    base = Path(project_dir);
    entry_rel = Path(client_entry);
    if entry_rel.is_absolute() {
        try {
            entry_rel = entry_rel.relative_to(base);
        } except ValueError {
            raise ValueError(
                f"The client entry '{client_entry}' is outside the project "
                f"tree, so the bundle cannot ship it. Point the served app's "
                f"entry-point at a path inside the project root."
            );
        }
    }
    if ".." in entry_rel.parts {
        raise ValueError(
            f"The client entry '{client_entry}' reaches outside the project "
            f"tree, so the bundle cannot ship it. Point the served app's "
            f"entry-point at a path inside the project root."
        );
    }
    if not (base / entry_rel).is_file() {
        if self._declared_client_entry() {
            raise ValueError(
                f"The client entry '{client_entry}' does not exist under "
                f"{base}, so the deploy would ship a served app with no "
                f"client to serve. Fix the app's entry-point, or set "
                f"client_entry = \"\" to deploy without a client."
            );
        }
        console.print(
            f"No client entry is declared and '{client_entry}' does not "
            f"exist; skipping the client build. Give the served app a client "
            f"by making its kind one that ships a client (web-app, "
            f"web-static, desktop, or mobile under [project] or "
            f"[apps.<name>]) to build one."
        );
        return;
    }
    excluded = source_filter_for(base);
    if excluded.excludes(entry_rel) {
        raise ValueError(
            f"The client entry '{entry_rel.as_posix()}' never ships: "
            f"{excluded.exclusion_reason(entry_rel)}. The client build runs "
            f"on exactly what the bundle ships, so it cannot build from "
            f"this file. Drop the exclusion, or point the served app's "
            f"entry-point at a module the bundle ships."
        );
    }
    for (env_name, keys) in _vite_env_keys(base).items() {
        console.warning(
            f"'{env_name}' declares {', '.join(keys)}, and the client build "
            f"runs on the bundle's staged sources, which never include "
            f".env files, so those compile to undefined in the served JS. "
            f"Values the client needs at build time belong under "
            f"[client.vite.define] in jac.toml; secrets stay server-side "
            f"and never reach the client."
        );
    }
    if self.dry_run {
        console.print(
            f"dry-run: skipped the host client bundle build ({client_entry})."
        );
        return;
    }
    import time;
    pinned = host_toolchain_path(project_dir);
    jac_bin = pinned or jac_executable();
    jac_env = release_binary_env() if pinned else None;
    if pinned {
        console.print(
            "Building with the jac release this app pins, not the one "
            f"running this deploy ({pinned})."
        );
    }
    stage_root = _stage_app(base, sanitized_jac_toml(base));
    stage = str(stage_root / "app");
    dist_candidates = self._client_dist_candidates(stage, entry_rel);
    try {
        for stale in dist_candidates {
            shutil.rmtree(stale, ignore_errors=True);
        }
        dep_error = self._install_app_deps(stage, jac_bin, jac_env);
        if dep_error {
            console.warning(
                f"The app's dependencies did not install on the build host, "
                f"so the client build may fail on a missing import. "
                f"{dep_error}"
            );
        }
        console.print(
            f"Building the client bundle on the host, from the bundle's "
            f"staged sources ({client_entry})."
        );
        attempt = 0;
        while True {
            attempt += 1;
            try {
                result = subprocess.run(
                    [jac_bin, "build", "--as", "client", entry_rel.as_posix()],
                    cwd=stage,
                    capture_output=True,
                    text=True,
                    timeout=900,
                    env=jac_env
                );
            } except subprocess.TimeoutExpired {
                if attempt >= _CLIENT_BUILD_ATTEMPTS {
                    raise RuntimeError(
                        f"client build timed out ({client_entry}) on all "
                        f"{_CLIENT_BUILD_ATTEMPTS} attempts. The pod serves "
                        f"the bundle built here and never rebuilds it - fix "
                        f"the client build and redeploy."
                    );
                }
                console.print(
                    f"Client build timed out (attempt {attempt} of "
                    f"{_CLIENT_BUILD_ATTEMPTS}); retrying."
                );
                time.sleep(_CLIENT_BUILD_RETRY_PAUSE_S);
                continue;
            }
            if result.returncode == 0 {
                break;
            }
            output = ((result.stdout or "") + "\n" + (result.stderr or "")).strip();
            tail = _output_tail(result);
            if (
                attempt < _CLIENT_BUILD_ATTEMPTS
                and _is_transient_client_build_failure(output)
            ) {
                console.print(
                    f"Client build hit a transient install/network failure "
                    f"(attempt {attempt} of {_CLIENT_BUILD_ATTEMPTS}); "
                    f"retrying.\n{tail}"
                );
                time.sleep(_CLIENT_BUILD_RETRY_PAUSE_S);
                continue;
            }
            cause = (
                f"\nIts dependencies did not install on this host first, "
                f"which is the likely cause: {dep_error}"
                    if dep_error
                    else ""
            );
            parked = _membership_diagnosis(output, base, excluded);
            raise RuntimeError(
                f"client build failed ({client_entry}, exit "
                f"{result.returncode}). The pod serves the bundle built "
                f"here and never rebuilds it - fix the client build and "
                f"redeploy.\n{tail}{cause}{parked}"
            );
        }
        dist = "";
        for candidate in dist_candidates {
            if os.path.isfile(os.path.join(candidate, "index.html")) {
                dist = candidate;
                break;
            }
        }
        if not dist {
            looked = ", ".join([os.path.relpath(d, stage) for d in dist_candidates]);
            raise RuntimeError(
                f"client build produced no index.html under {looked} "
                f"({client_entry}); the gateway would have nothing to serve."
            );
        }
        target = os.path.join(project_dir, ".jac", "client", "dist");
        incoming = target + ".incoming";
        outgoing = target + ".outgoing";
        os.makedirs(os.path.dirname(target), exist_ok=True);
        shutil.rmtree(incoming, ignore_errors=True);
        shutil.rmtree(outgoing, ignore_errors=True);
        shutil.copytree(dist, incoming);
        if os.path.isdir(target) {
            os.replace(target, outgoing);
        }
        os.replace(incoming, target);
        shutil.rmtree(outgoing, ignore_errors=True);
    } finally {
        remove_stage_root(stage_root);
    }
    console.print("Client bundle built; shipping it to the gateway pod.");
}


impl ManifestBuilder._client_dist_candidates(stage: str, entry_rel: any) -> list[str] {
    import os;
    client_dir = os.path.join(stage, ".jac", "client");
    candidates: list[str] = [];
    cfg = self._project_config();
    if cfg is not None {
        import from jaclang.project.client_paths { client_workspace_app }
        app = client_workspace_app(
            cfg, os.path.join(self.project_dir, entry_rel.as_posix())
        );
        if app is not None {
            candidates.append(os.path.join(client_dir, app.name, "dist"));
        }
    }
    candidates.append(os.path.join(client_dir, "dist"));
    return candidates;
}


impl ManifestBuilder._declared_client_entry -> str {
    if self.client_entry is not None {
        return self.client_entry.strip();
    }
    root_member = self.fleet.root_member() if self.fleet is not None else None;
    if root_member is not None and root_member.client {
        return root_member.file;
    }
    return "";
}


impl ManifestBuilder._client_entry -> str {
    if self.client_entry is not None {
        return self.client_entry.strip();
    }
    declared = self._declared_client_entry();
    if declared {
        return declared;
    }
    cfg = self._project_config();
    if cfg is not None and cfg.is_workspace {
        return "";
    }
    if cfg is not None {
        entry_point = str(cfg.project.entry_point or "").strip();
        import os;
        import from jaclang.project.apps { resolve_entry_path }
        return os.path.relpath(
            resolve_entry_path(entry_point or "main", self.project_dir),
            self.project_dir
        );
    }
    root_member = self.fleet.root_member() if self.fleet is not None else None;
    if root_member is not None and root_member.file {
        return root_member.file;
    }
    return "main.jac";
}


impl ManifestBuilder._has_client_source -> bool {
    root_dir = self.project_dir;
    if not root_dir {
        return False;
    }
    import os;
    if not os.path.isdir(root_dir) {
        return False;
    }
    for probe in ("pages", "components") {
        if os.path.isdir(os.path.join(root_dir, probe)) {
            return True;
        }
    }

    import tomllib;
    try {
        with open(os.path.join(root_dir, "jac.toml"), "rb") as fh {
            return isinstance(tomllib.load(fh).get("client"), dict);
        }
    } except Exception {
        return False;
    }
}


impl ManifestBuilder._bundle_files -> dict[str, str] {
    if self._bundle_files_cache is None {
        import from jaclang.scale.injector.bundle { resolve_fleet_entries }
        self._bundle_files_cache = (
            resolve_fleet_entries(self.project_dir, self.fleet)
                if self.project_dir and self.fleet is not None
                else {}
        );
    }
    return self._bundle_files_cache;
}


impl _output_tail(result: any, lines: int = 15) -> str {
    combined = ((result.stdout or "") + "\n" + (result.stderr or "")).strip();
    return "\n".join(combined.splitlines()[-lines:]);
}


impl _is_transient_client_build_failure(output: str) -> bool {
    lowered = output.lower();
    for marker in _TRANSIENT_CLIENT_BUILD_MARKERS {
        if marker in lowered {
            return True;
        }
    }
    return False;
}


impl _membership_diagnosis(output: str, base: any, excluded: any) -> str {
    import re;
    import from pathlib { Path }
    base_prefix = str(base).replace("\\", "/").rstrip("/") + "/";
    lines: list[str] = [];
    seen: set[str] = set();
    tried: set[str] = set();
    for token in re.findall(r"[\w.\\/-]+", output) {
        cand = token.replace("\\", "/").rstrip(".");
        if cand.startswith(base_prefix) {
            cand = cand[len(base_prefix):];
        }
        if cand in tried {
            continue;
        }
        tried.add(cand);
        variants = [cand];
        if "/" not in cand and "." in cand and not cand.startswith(".") {
            stem = cand.replace(".", "/");
            variants.extend([f"{stem}.jac", f"{stem}.py", stem]);
        }
        for variant in variants {
            if not variant or variant.startswith("/") or ".." in variant.split("/") {
                continue;
            }
            rel = Path(variant);
            if rel.name == "jac.toml" or rel.as_posix() in seen {
                continue;
            }
            if not (base / rel).exists() or not excluded.excludes(rel) {
                continue;
            }
            if excluded.is_build_tree(rel) {
                continue;
            }
            seen.add(rel.as_posix());
            lines.append(f"  - {rel.as_posix()}: {excluded.exclusion_reason(rel)}");
            break;
        }
    }
    if not lines {
        return "";
    }
    shown = lines[:_MEMBERSHIP_DIAGNOSIS_SHOWN];
    if len(lines) > _MEMBERSHIP_DIAGNOSIS_SHOWN {
        shown.append(f"  ... and {len(lines) - _MEMBERSHIP_DIAGNOSIS_SHOWN} more");
    }
    return (
        "\nThe client build ran on the bundle's staged sources, and these "
        "files named in its output never ship:\n"
        + "\n".join(shown)
        + "\nDrop the exclusion or remove the reference. Values the client "
        "needs at build time belong under [client.vite.define] in jac.toml; "
        "secrets stay server-side in [scale.secrets] or pod env and never "
        "reach the client."
    );
}


impl _vite_env_keys(base: any) -> dict[str, list[str]] {
    import from pathlib { Path }
    found: dict[str, list[str]] = {};
    for name in _VITE_BUILD_ENV_FILES {
        env_file: Path = Path(base, name);
        if not env_file.is_file() {
            continue;
        }
        keys: list[str] = [];
        text: str = env_file.read_text(encoding="utf-8", errors="replace");
        for raw in text.splitlines() {
            line: str = raw.strip();
            if line.startswith("export ") {
                line = line[len("export "):].lstrip();
            }
            if not line or line.startswith("#") or "=" not in line {
                continue;
            }
            key = line.split("=", 1)[0].strip();
            if key.startswith("VITE_") and key not in keys {
                keys.append(key);
            }
        }
        if keys {
            found[name] = keys;
        }
    }
    return found;
}
