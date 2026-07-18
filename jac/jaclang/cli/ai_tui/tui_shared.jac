import from jaclang.cli.ai_tui.ipc_schema {
    CMD_SEND,
    CMD_STOP,
    CMD_RESET,
    CMD_QUIT,
    CMD_APPLY,
    RECEIPT_ACCEPTED,
    RECEIPT_REJECTED_BUSY,
    RECEIPT_REJECTED_EMPTY,
    RECEIPT_REJECTED_ERROR,
    RECEIPT_OK
}

glob _DEBUG_LOG_PATH: str = "";


def _set_debug_log_path(path: str) {
    global _DEBUG_LOG_PATH;
    _DEBUG_LOG_PATH = path.strip();
}


def _debug_log(msg: str) -> None {
    import os;
    import time;

    path = _DEBUG_LOG_PATH;
    if not path {
        return;
    }
    try {
        with open(path, "a", encoding="utf-8") as f {
            stamp = time.strftime("%Y-%m-%d %H:%M:%S");
            f.write(f"[{stamp}] {msg}\n");
        }
    } except Exception { }
}


def _silence_logging_for_tui(debug_path: str = "") {
    import logging;
    import os;
    import sys;

    if debug_path {
        _set_debug_log_path(debug_path);
    }
    root_logger = logging.getLogger();
    debug_path = _DEBUG_LOG_PATH;
    lvl_dbg: int = int(logging.DEBUG);
    lvl_warn: int = int(logging.WARNING);

    for h in list(root_logger.handlers) {
        if h?.stream in (sys.stderr, sys.stdout) {
            root_logger.removeHandler(h);
        }
    }

    if debug_path {
        try {
            fh = logging.FileHandler(debug_path);
            fh.setFormatter(logging.Formatter("%(name)s %(levelname)s: %(message)s"));
            fh.setLevel(lvl_dbg);
            root_logger.addHandler(fh);
            root_logger.setLevel(lvl_dbg);
        } except Exception { }
    } else {
        root_logger.addHandler(logging.NullHandler());
        root_logger.setLevel(lvl_warn);
    }

    try {
        import from loguru { logger as _logu }
        _logu.remove();
        if debug_path {
            _logu.add(debug_path, level="DEBUG");
        }
    } except Exception { }
}


def _list_project_files(project: str) -> str {
    import os;
    import subprocess;

    cap = 2000;
    out_lines: list = [];
    try {
        res = subprocess.run(
            ["git", "-C", project, "ls-files"],
            capture_output=True,
            text=True,
            timeout=5
        );
        if res.returncode == 0 {
            for line in res.stdout.split("\n") {
                s = line.strip();
                if s {
                    out_lines.append(s);
                }
                if len(out_lines) >= cap {
                    break;
                }
            }
        }
    } except Exception as e {
        _debug_log(f"_list_project_files: git ls-files failed: {e}");
    }

    if not out_lines {
        try {
            for entry in os.walk(project) {
                dirpath = entry[0];
                if ".git" in dirpath.split(os.sep) {
                    continue;
                }
                for fn in entry[2] {
                    rel = os.path.relpath(os.path.join(dirpath, fn), project);
                    out_lines.append(rel);
                    if len(out_lines) >= cap {
                        break;
                    }
                }
                if len(out_lines) >= cap {
                    break;
                }
            }
        } except Exception as e {
            _debug_log(f"_list_project_files: os.walk fallback failed: {e}");
        }
    }

    return "\n".join(out_lines);
}


def _first_tty_stream -> any {
    import sys;

    for stream in (sys.stderr, sys.stdin, sys.stdout) {
        try {
            if stream.isatty() {
                return stream;
            }
        } except Exception { }
    }
    return None;
}


def _probe_tty -> dict {
    import os;

    stream = _first_tty_stream();
    if stream is None {
        return {"available": False, "device": ""};
    }
    try {
        return {"available": True, "device": os.ttyname(int(stream.fileno()))};
    } except Exception {
        return {"available": True, "device": ""};
    }
}


def _require_tty -> str | None {
    import from jaclang.cli.console { console }
    probe = _probe_tty();
    if not probe["available"] {
        console.error(
            "jac ai --tui needs an interactive terminal (stdin or stderr must be a TTY)"
        );
        return None;
    }
    return str(probe["device"]);
}


def _build_embed_argv(req: any, seams: dict | None = None) -> list[str] {
    import os;

    argv: list[str] = [];
    project = os.path.normpath(str(req?.cwd or os.getcwd()));
    argv.append("--project");
    argv.append(project);
    _model = str(req?.model or "");
    if _model {
        argv.append("-m");
        argv.append(_model);
    }
    n_ctx = int(req?.n_ctx or 0);
    if n_ctx > 0 {
        argv.append("--n-ctx");
        argv.append(str(n_ctx));
    }
    s: any = seams;
    if s is None {
        s = _embed_byllm_seams();
    }
    if s.get("src") {
        argv.append("--byllm-src");
        argv.append(str(s["src"]));
    }
    if s.get("deps") {
        argv.append("--byllm-deps");
        argv.append(str(s["deps"]));
    }
    _debug = str(req?.debug_log or "");
    if _debug {
        argv.append("--debug-log");
        argv.append(_debug);
    }
    _tty = str(req?.tty or "");
    if not _tty {
        probe = _probe_tty();
        _tty = str(probe.get("device", "") or "");
    }
    if _tty {
        argv.append("--tty");
        argv.append(_tty);
    }
    return argv;
}


def _cmd_send(payload: str, stop_evt: any, proc: any) -> str {
    import from jaclang.cli.ai_agent { ui_send }
    try {
        ok = ui_send(payload);
        _debug_log(f"ui_send({payload!r}) -> {ok}");
        if ok {
            return RECEIPT_ACCEPTED;
        }
        if not payload.strip() {
            return RECEIPT_REJECTED_EMPTY;
        }
        return RECEIPT_REJECTED_BUSY;
    } except Exception as e {
        _debug_log(f"ui_send({payload!r}) error: {e}");
        return RECEIPT_REJECTED_ERROR + ":" + type(e).__name__;
    }
}

def _cmd_stop(payload: str, stop_evt: any, proc: any) -> str {
    import from jaclang.cli.ai_agent { ui_stop }
    try {
        ui_stop();
        _debug_log("ui_stop()");
        return RECEIPT_OK;
    } except Exception as e {
        _debug_log(f"ui_stop error: {e}");
        return RECEIPT_REJECTED_ERROR + ":" + type(e).__name__;
    }
}

def _cmd_reset(payload: str, stop_evt: any, proc: any) -> str {
    import from jaclang.cli.ai_agent { ui_reset }
    try {
        ui_reset();
        _debug_log("ui_reset()");
        return RECEIPT_OK;
    } except Exception as e {
        _debug_log(f"ui_reset error: {e}");
        return RECEIPT_REJECTED_ERROR + ":" + type(e).__name__;
    }
}

def _cmd_quit(payload: str, stop_evt: any, proc: any) -> str {
    import from jaclang.cli.ai_agent { ui_stop }
    stop_evt.set();
    try {
        ui_stop();
        _debug_log("ui_stop() before quit");
    } except Exception as e {
        _debug_log(f"ui_stop before quit error: {e}");
    }
    if proc is not None {
        try {
            proc.terminate();
            _debug_log("proc.terminate()");
        } except Exception as e {
            _debug_log(f"proc.terminate error: {e}");
        }
    }
    return RECEIPT_OK;
}

def _cmd_apply(payload: str, stop_evt: any, proc: any) -> str {
    import from jaclang.cli.ai_agent { ui_apply_settings }
    settings: dict = {};
    for part in payload.split(",") {
        eq = part.find("=");
        if eq > 0 {
            k = part[:eq].strip();
            v = part[eq + 1:].strip();
            settings[k] = v;
        }
    }
    try {
        result = ui_apply_settings(
            model=str(settings.get("model", "")),
            n_ctx=str(settings.get("n_ctx", "")),
            api_key=str(settings.get("api_key", "")),
            base_url=str(settings.get("base_url", "")),
            temperature=str(settings.get("temperature", "")),
        );
        _debug_log(f"ui_apply_settings({settings}) -> {result}");
        return RECEIPT_OK;
    } except Exception as e {
        _debug_log(f"ui_apply_settings({settings}) error: {e}");
        return RECEIPT_REJECTED_ERROR + ":" + type(e).__name__;
    }
}

glob _CMD_HANDLERS: dict = {
         CMD_SEND: _cmd_send,
         CMD_STOP: _cmd_stop,
         CMD_RESET: _cmd_reset,
         CMD_QUIT: _cmd_quit,
         CMD_APPLY: _cmd_apply,

     };

def _dispatch_cmd(line: str, stop_evt: any, proc: any) -> str {
    colon = line.find(":");
    if colon > 0 {
        token = line[:colon];
        payload = line[colon + 1:];
    } else {
        token = line;
        payload = "";
    }
    handler = _CMD_HANDLERS.get(token);
    if handler is not None {
        return handler(payload, stop_evt, proc);
    }
    return RECEIPT_REJECTED_ERROR + ":unknown_cmd";
}


def _resolve_jac_build_bin(pkg_root: any) -> str | None {
    import os;

    explicit = os.environ.get("JAC_BIN", "").strip();
    if explicit and os.path.isfile(explicit) and os.access(explicit, int(os.X_OK)) {
        return explicit;
    }
    repo_root = os.path.normpath(os.path.join(str(pkg_root), "..", "..", ".."));
    repo_jac = os.path.join(repo_root, "jac", "zig-out", "bin", "jac");
    if os.path.isfile(repo_jac) and os.access(repo_jac, int(os.X_OK)) {
        return repo_jac;
    }
    return None;
}


def _embed_module_dir(name: str) -> str | None {
    import os;
    import from importlib { util }

    try {
        spec = util.find_spec(name);
    } except Exception {
        return None;
    }
    if spec is None {
        return None;
    }
    spec_a: any = spec;
    locs: any = spec_a?.submodule_search_locations;
    if locs {
        for loc in locs {
            if loc {
                return os.path.dirname(str(loc));
            }
        }
    }
    origin = spec_a?.origin;
    if origin and origin not in ("built-in", "frozen") {
        return os.path.dirname(str(origin));
    }
    return None;
}


def _embed_site_package_dirs -> list[str] {
    import site;

    out: list[str] = [];
    try {
        user_site = str(site.getusersitepackages() or "").strip();
        if user_site and user_site not in out {
            out.append(user_site);
        }
    } except Exception { }
    try {
        for sp in site.getsitepackages() {
            path = str(sp or "").strip();
            if path and path not in out {
                out.append(path);
            }
        }
    } except Exception { }
    return out;
}


def _embed_byllm_seams -> dict {
    import os;

    out: dict = {};
    src = _embed_module_dir("byllm");
    if src {
        out["src"] = src;
    }

    dep_dirs: list = [];
    for mod in [
        "litellm",
        "openai",
        "pydantic",
        "pydantic_core",
        "tokenizers",
        "httpx",
        "tiktoken"
    ] {
        d = _embed_module_dir(mod);
        if d and d not in dep_dirs {
            dep_dirs.append(d);
        }
    }

    for d in _embed_site_package_dirs() {
        if d not in dep_dirs {
            dep_dirs.append(d);
        }
    }
    if not src {
        for d in dep_dirs {
            out["src"] = d;
            break;
        }
    }
    if dep_dirs {
        out["deps"] = os.pathsep.join(dep_dirs);
    }
    return out;
}


obj EmbedHostResult {
    has ok: bool = False,
        path: str = "",
        error: str = "",
        hint: str = "";
}


glob _EMBED_MIN_TRAILER_BYTES: int = 2_000_000;


def _embed_mtime(path: str, newest: float) -> float {
    import os;

    try {
        m = os.path.getmtime(path);
        if m > newest {
            return m;
        }
    } except Exception { }
    return newest;
}


def _embed_shim_path(cli_root: any) -> str {
    import os;

    return os.path.join(
        str(cli_root),
        "..",
        "runtimelib",
        "client",
        "targets",
        "desktop",
        "native",
        "libjacpyembed.so"
    );
}


def _embed_inputs_newest_mtime(na_dir: str, cli_root: any) -> float {
    import os;
    import glob;

    newest: float = 0.0;
    pattern = os.path.join(na_dir, "**", "*.na.jac");
    for path in glob.glob(pattern, recursive=True) {
        newest = _embed_mtime(path, newest);
    }
    for name in ["build_embed.sh", "_stage_modules.sh"] {
        newest = _embed_mtime(os.path.join(na_dir, name), newest);
    }
    newest = _embed_mtime(_embed_shim_path(cli_root), newest);
    return newest;
}


def _embed_host_bootable(artifact: str) -> bool {
    import os;

    try {
        return os.path.getsize(artifact) >= _EMBED_MIN_TRAILER_BYTES;
    } except Exception {
        return False;
    }
}


def _embed_build_stamp_path(bindir: str) -> str {
    import os;

    return os.path.join(bindir, ".embed_build_stamp");
}


def _read_embed_build_stamp(bindir: str) -> float {
    import os;

    path = _embed_build_stamp_path(bindir);
    try {
        with open(path, encoding="utf-8") as f {
            raw = f.read().strip();
        }
        return float(raw);
    } except Exception {
        return 0.0;
    }
}


def _embed_host_fresh(
    artifact: str, bindir: str, newest_src: float, force: bool
) -> bool {
    import os;

    if force or not os.path.exists(artifact) {
        return False;
    }
    if not _embed_host_bootable(artifact) {
        return False;
    }
    stamp = _read_embed_build_stamp(bindir);
    if stamp + 0.001 < newest_src {
        return False;
    }
    try {
        return os.path.getmtime(artifact) >= newest_src;
    } except Exception {
        return False;
    }
}


def _ensure_embed_host(cli_root: any, force: bool = False) -> EmbedHostResult {
    import os;
    import fcntl;
    import subprocess;
    import from jaclang.cli.console { console }

    na_dir = os.path.join(str(cli_root), "ai_tui_na");
    bindir = os.path.join(na_dir, "bin");
    artifact = os.path.join(bindir, "jac-ai-tui");
    source = os.path.join(na_dir, "host_embed.na.jac");
    build_sh = os.path.join(na_dir, "build_embed.sh");
    manual_hint = f"bash {build_sh}";

    newest_src = _embed_inputs_newest_mtime(na_dir, cli_root);

    if _embed_host_fresh(artifact, bindir, newest_src, force) {
        return EmbedHostResult(ok=True, path=artifact);
    }
    if not os.path.isfile(source) or not os.path.isfile(build_sh) {
        if os.path.exists(artifact) {
            return EmbedHostResult(ok=True, path=artifact);
        }
        return EmbedHostResult(
            ok=False,
            path=artifact,
            error=f"embed TUI host not found at {artifact}",
            hint=f"Build it with: {manual_hint}"
        );
    }

    try {
        os.makedirs(bindir, exist_ok=True);
    } except Exception { }
    lock_fd: int = -1;
    try {
        lock_fd = os.open(
            os.path.join(bindir, ".build.lock"), os.O_CREAT | os.O_RDWR, 0o644
        );
    } except Exception {
        lock_fd = -1;
    }

    try {
        if lock_fd >= 0 {
            try {
                fcntl.flock(lock_fd, fcntl.LOCK_EX);
            } except Exception { }
        }

        if _embed_host_fresh(artifact, bindir, newest_src, force) {
            return EmbedHostResult(ok=True, path=artifact);
        }

        pre_existed = os.path.exists(artifact);
        if force and pre_existed {
            console.print(
                "[tui] --rebuild-tui set; rebuilding embed host ...", style="dim"
            );
        } elif pre_existed {
            console.print(
                "[tui] embed host is stale; recompiling "
                "(native build, this can take a few minutes) ...",
                style="dim"
            );
        } else {
            console.print(
                "[tui] embed host missing; compiling "
                "(first run, native build, this can take a few minutes) ...",
                style="dim"
            );
        }

        build_env = dict(os.environ);
        jac_bin = _resolve_jac_build_bin(cli_root);
        if jac_bin {
            build_env["JAC_BIN"] = jac_bin;
        }
        try {
            res = subprocess.run(
                ["bash", build_sh],
                cwd=na_dir,
                env=build_env,
                capture_output=True,
                text=True,
                timeout=900,
            );
            if res.returncode != 0 {
                detail = (res.stderr or res.stdout or "").strip();
                if detail {
                    console.error(detail);
                }

                return EmbedHostResult(
                    ok=False,
                    path=artifact,
                    error="embed TUI host compile failed",
                    hint=f"Run manually: {manual_hint}"
                );
            }
        } except Exception as e {
            return EmbedHostResult(
                ok=False,
                path=artifact,
                error=f"embed TUI host compile failed: {e}",
                hint=f"Run manually: {manual_hint}"
            );
        }
        if not os.path.exists(artifact) {
            return EmbedHostResult(
                ok=False,
                path=artifact,
                error=f"embed TUI host not found at {artifact} after compile",
                hint=f"Run manually: {manual_hint}"
            );
        }
        try {
            with open(_embed_build_stamp_path(bindir), "w", encoding="utf-8") as f {
                f.write(f"{newest_src}\n");
            }
        } except Exception { }
        return EmbedHostResult(ok=True, path=artifact);
    } finally {
        if lock_fd >= 0 {
            try {
                fcntl.flock(lock_fd, fcntl.LOCK_UN);
            } except Exception { }
            try {
                os.close(lock_fd);
            } except Exception { }
        }
    }
}


def _dlopen_lib_path(cli_root: any) -> str {
    import os;
    import sys;

    name: str = "libtui.so";
    if sys.platform == "darwin" {
        name = "libtui.dylib";
    } elif sys.platform == "win32" {
        name = "tui.dll";
    }
    return os.path.join(str(cli_root), "ai_tui_na", "bin", name);
}


def _dlopen_build_stamp_path(bindir: str) -> str {
    import os;

    return os.path.join(bindir, ".dlopen_build_stamp");
}


def _read_dlopen_build_stamp(bindir: str) -> float {
    import os;

    path = _dlopen_build_stamp_path(bindir);
    try {
        with open(path, encoding="utf-8") as f {
            raw = f.read().strip();
        }
        return float(raw);
    } except Exception {
        return 0.0;
    }
}


def _dlopen_inputs_newest_mtime(na_dir: str) -> float {
    import os;
    import glob;

    newest: float = 0.0;
    pattern = os.path.join(na_dir, "**", "*.na.jac");
    for path in glob.glob(pattern, recursive=True) {
        newest = _embed_mtime(path, newest);
    }
    for name in ["build_dlopen.sh", "_stage_modules.sh"] {
        newest = _embed_mtime(os.path.join(na_dir, name), newest);
    }
    return newest;
}


def _dlopen_lib_fresh(
    artifact: str, bindir: str, newest_src: float, force: bool
) -> bool {
    import os;

    if force or not os.path.exists(artifact) {
        return False;
    }
    stamp = _read_dlopen_build_stamp(bindir);
    if stamp + 0.001 < newest_src {
        return False;
    }
    try {
        return os.path.getmtime(artifact) >= newest_src;
    } except Exception {
        return False;
    }
}


def _ensure_tui_lib(cli_root: any, force: bool = False) -> EmbedHostResult {
    import os;
    import fcntl;
    import subprocess;
    import from jaclang.cli.console { console }

    na_dir = os.path.join(str(cli_root), "ai_tui_na");
    bindir = os.path.join(na_dir, "bin");
    artifact = _dlopen_lib_path(cli_root);
    source = os.path.join(na_dir, "host_dlopen.na.jac");
    build_sh = os.path.join(na_dir, "build_dlopen.sh");
    manual_hint = f"bash {build_sh}";

    newest_src = _dlopen_inputs_newest_mtime(na_dir);

    if _dlopen_lib_fresh(artifact, bindir, newest_src, force) {
        return EmbedHostResult(ok=True, path=artifact);
    }
    if not os.path.isfile(source) or not os.path.isfile(build_sh) {
        if os.path.exists(artifact) {
            return EmbedHostResult(ok=True, path=artifact);
        }
        return EmbedHostResult(
            ok=False,
            path=artifact,
            error=f"in-process TUI library not found at {artifact}",
            hint=f"Build it with: {manual_hint}"
        );
    }

    try {
        os.makedirs(bindir, exist_ok=True);
    } except Exception { }
    lock_fd: int = -1;
    try {
        lock_fd = os.open(
            os.path.join(bindir, ".dlopen_build.lock"), os.O_CREAT | os.O_RDWR, 0o644
        );
    } except Exception {
        lock_fd = -1;
    }

    try {
        if lock_fd >= 0 {
            try {
                fcntl.flock(lock_fd, fcntl.LOCK_EX);
            } except Exception { }
        }

        if _dlopen_lib_fresh(artifact, bindir, newest_src, force) {
            return EmbedHostResult(ok=True, path=artifact);
        }

        pre_existed = os.path.exists(artifact);
        if force and pre_existed {
            console.print(
                "[tui] --rebuild-tui set; rebuilding in-process TUI library ...",
                style="dim"
            );
        } elif pre_existed {
            console.print(
                "[tui] in-process TUI library is stale; recompiling ...", style="dim"
            );
        } else {
            console.print(
                "[tui] in-process TUI library missing; compiling (first run) ...",
                style="dim"
            );
        }

        build_env = dict(os.environ);
        jac_bin = _resolve_jac_build_bin(cli_root);
        if jac_bin {
            build_env["JAC_BIN"] = jac_bin;
        }
        try {
            res = subprocess.run(
                ["bash", build_sh],
                cwd=na_dir,
                env=build_env,
                capture_output=True,
                text=True,
                timeout=900,
            );
            if res.returncode != 0 {
                detail = (res.stderr or res.stdout or "").strip();
                if detail {
                    console.error(detail);
                }
                return EmbedHostResult(
                    ok=False,
                    path=artifact,
                    error="in-process TUI library compile failed",
                    hint=f"Run manually: {manual_hint}"
                );
            }
        } except Exception as e {
            return EmbedHostResult(
                ok=False,
                path=artifact,
                error=f"in-process TUI library compile failed: {e}",
                hint=f"Run manually: {manual_hint}"
            );
        }
        if not os.path.exists(artifact) {
            return EmbedHostResult(
                ok=False,
                path=artifact,
                error=f"in-process TUI library not found at {artifact} after compile",
                hint=f"Run manually: {manual_hint}"
            );
        }
        try {
            with open(_dlopen_build_stamp_path(bindir), "w", encoding="utf-8") as f {
                f.write(f"{newest_src}\n");
            }
        } except Exception { }
        return EmbedHostResult(ok=True, path=artifact);
    } finally {
        if lock_fd >= 0 {
            try {
                fcntl.flock(lock_fd, fcntl.LOCK_UN);
            } except Exception { }
            try {
                os.close(lock_fd);
            } except Exception { }
        }
    }
}
