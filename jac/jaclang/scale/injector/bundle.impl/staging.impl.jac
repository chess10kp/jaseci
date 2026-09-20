impl det_tar_member(info: tarfile.TarInfo) -> tarfile.TarInfo {
    info.mtime = 0;
    info.uid = 0;
    info.gid = 0;
    info.uname = "";
    info.gname = "";
    return info;
}


impl open_det_tar(buf: io.BytesIO) -> tuple[tarfile.TarFile, any] {
    gz = gzip.GzipFile(fileobj=buf, mode="wb", mtime=0);
    return (tarfile.open(fileobj=gz, mode="w"), gz);
}


impl add_source_members(
    tar: tarfile.TarFile, base: Path, sources: (list[Path] | None) = None
) {
    for path in (sources if sources is not None else bundle_source_files(base)) {
        tar.add(str(path), arcname=str(path.relative_to(base)), filter=det_tar_member);
    }
}


impl stage_roots_in_use -> list[str] {
    return list(_stage_roots);
}


impl _stage_root_prefix -> str {
    return f"{STAGE_PREFIX}{os.getpid()}-";
}


impl _stage_root_pid(name: str) -> int {
    if not name.startswith(STAGE_PREFIX) {
        return 0;
    }
    parts = name[len(STAGE_PREFIX):].split("-");
    if len(parts) < 2 or not parts[0].isdigit() {
        return 0;
    }
    return int(parts[0]);
}


impl _pid_alive(pid: int) -> bool {
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except OSError {
        return True;
    }
}


impl _stage_root_expired(stage_root: Path) -> bool {
    try {
        return (time.time() - stage_root.stat().st_mtime) > STAGE_REAP_AGE_S;
    } except OSError {
        return False;
    }
}


impl reap_stale_stage_roots -> int {
    removed = 0;
    holder = Path(tempfile.gettempdir());
    try {
        entries = sorted(holder.iterdir());
    } except OSError {
        return 0;
    }
    for `entry in entries {
        if not `entry.is_dir() or not `entry.name.startswith(STAGE_PREFIX) {
            continue;
        }
        pid = _stage_root_pid(`entry.name);
        if pid == 0 {
            if not _stage_root_expired(`entry) {
                continue;
            }
        } elif _pid_alive(pid) {
            continue;
        }
        shutil.rmtree(str(`entry), ignore_errors=True);
        if not `entry.exists() {
            removed += 1;
        }
    }
    if removed {
        logger.info(
            f"removed {removed} deploy staging director(ies) left by dead runs"
        );
    }
    return removed;
}


impl remove_stage_root(stage_root: Path) {
    shutil.rmtree(str(stage_root), ignore_errors=True);
    if str(stage_root) in _stage_roots {
        _stage_roots.remove(str(stage_root));
    }
}


impl _remove_stage_roots{
    for path in list(_stage_roots) {
        shutil.rmtree(path, ignore_errors=True);
    }
    _stage_roots.clear();
}


impl _stage_app(base: Path, sanitized_toml: (str | None)) -> Path {
    reap_stale_stage_roots();
    stage_root = Path(tempfile.mkdtemp(prefix=_stage_root_prefix()));
    if not _stage_roots {
        import atexit;
        atexit.register(_remove_stage_roots);
    }
    _stage_roots.append(str(stage_root));
    stage = stage_root / "app";
    try {
        for path in bundle_source_files(base) {
            dest = stage / path.relative_to(base);
            dest.parent.mkdir(parents=True, exist_ok=True);
            shutil.copy2(str(path), str(dest));
        }
        stage.mkdir(parents=True, exist_ok=True);
        if sanitized_toml is not None {
            (stage / "jac.toml").write_text(sanitized_toml, encoding="utf-8");
        } else {
            (stage / "jac.toml").write_text(PLACEHOLDER_JAC_TOML, encoding="utf-8");
        }
        for (rel, text) in nested_sanitized_tomls(base).items() {
            dest = stage / Path(rel);
            dest.parent.mkdir(parents=True, exist_ok=True);
            dest.write_text(text, encoding="utf-8");
        }
        marker = stage / "__init__.jac";
        if not marker.exists() {
            marker.write_text("");
        }
        return stage_root;
    } except Exception {
        remove_stage_root(stage_root);
        raise;
    }
}
