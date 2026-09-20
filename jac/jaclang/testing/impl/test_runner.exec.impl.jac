impl install_warning_filters -> None {
    import warnings;
    warnings.resetwarnings();
    warnings.simplefilter("error");
    categories: dict[(str, type[Warning])] = {
        "DeprecationWarning": DeprecationWarning,
        "ResourceWarning": ResourceWarning
    };
    for (message, category, module) in _WARNING_IGNORES {
        warnings.filterwarnings(
            "ignore",
            message=message,
            category=categories.get(category, Warning),
            module=module
        );
    }
}

impl _cleanup_test_bases -> None {
    import shutil;
    while _TEST_BASES {
        path = _TEST_BASES.pop();
        if os.path.isdir(path) {
            shutil.rmtree(path, ignore_errors=True);
        } else {
            try {
                os.unlink(path);
            } except OSError {}
        }
    }
}

impl _fresh_jac_state(clear_modules: bool = True) -> None {
    import tempfile;
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.runtime.runtime { JacRuntime, JacRuntimeInterface }
    import from jaclang.project.config { get_explicit_config, set_config }
    import from jaclang.server.session { mark_scratch_base }
    if not _CONFIG_PIN_BASELINE {
        _CONFIG_PIN_BASELINE.append(get_explicit_config());
    } else {
        set_config(_CONFIG_PIN_BASELINE[0]);
    }
    JacRuntime.reset_process_state(clear_modules=clear_modules);
    fresh_base = tempfile.mkdtemp(prefix="jac-test-base-");
    _TEST_BASES.append(fresh_base);
    mark_scratch_base(fresh_base);
    JacRuntime.set_base_path(fresh_base);
    JacRuntime.set_full_target_path(None);
    JacRuntime.program = JacProgram();
    JacRuntime.exec_ctx = JacRuntimeInterface.create_j_context(
        user_root=None, base_path_dir=fresh_base, full_target_path=None
    );
}

impl _capture_begin -> dict[(str, any)] {
    import sys;
    import tempfile;
    for stream in (sys.stdout, sys.stderr) {
        try {
            stream.flush();
        } except Exception {}
    }
    sink: any = None;
    if _CRASH_LOG[0] {
        sink = open(_CRASH_LOG[0], "w+b");
    } else {
        sink = tempfile.TemporaryFile();
    }
    state: dict[(str, any)] = {
        "sink": sink,
        "out": os.dup(1),
        "err": os.dup(2),
        "sys_out": sys.stdout,
        "sys_err": sys.stderr
    };
    os.dup2(sink.fileno(), 1);
    os.dup2(sink.fileno(), 2);
    made_out = os.fdopen(os.dup(1), "w", encoding="utf-8", errors="replace");
    made_err = os.fdopen(os.dup(2), "w", encoding="utf-8", errors="replace");
    state["made_out"] = made_out;
    state["made_err"] = made_err;
    sys.stdout = made_out;
    sys.stderr = made_err;
    return state;
}

impl _capture_end(state: dict[(str, any)]) -> str {
    import sys;
    import logging;

    loggers = [logging.getLogger(), *logging.Logger.manager.loggerDict.values()];
    for logger in loggers {
        if not isinstance(logger, logging.Logger) {
            continue;
        }
        for handler in logger.handlers {
            if not isinstance(handler, logging.StreamHandler) {
                continue;
            }
            for (captured, original) in [
                (state["made_out"], state["sys_out"]),
                (state["made_err"], state["sys_err"])
            ] {
                if handler.stream is captured {
                    handler.setStream(original);
                }
            }
        }
    }
    for stream in (state["made_out"], state["made_err"]) {
        try {
            stream.flush();
            stream.close();
        } except Exception {}
    }
    sys.stdout = state["sys_out"];
    sys.stderr = state["sys_err"];
    os.dup2(state["out"], 1);
    os.dup2(state["err"], 2);
    os.close(state["out"]);
    os.close(state["err"]);
    sink = state["sink"];
    text = "";
    try {
        sink.flush();
        sink.seek(0);
        text = sink.read().decode("utf-8", "replace");
    } except Exception {
        text = "";
    }
    try {
        sink.close();
    } except Exception {}
    return text;
}

impl _project_root_for(start_dir: str) -> str {
    current = os.path.realpath(start_dir);
    while True {
        if os.path.exists(os.path.join(current, "jac.toml")) {
            return current;
        }
        parent = os.path.dirname(current);
        if parent == current {
            return "";
        }
        current = parent;
    }
}

impl _package_basedir(start_dir: str) -> str {
    current = os.path.realpath(start_dir);
    while True {
        packaged = False;
        for marker in ("__init__.py", "__init__.jac") {
            if os.path.exists(os.path.join(current, marker)) {
                packaged = True;
            }
        }
        if not packaged {
            return current;
        }
        parent = os.path.dirname(current);
        if parent == current {
            return current;
        }
        current = parent;
    }
}

impl _outermost_package_root(start_dir: str, ceiling: str) -> str {
    current = os.path.realpath(start_dir);
    stop = os.path.realpath(ceiling) if ceiling else "";
    outermost = "";
    while True {
        for marker in ("__init__.py", "__init__.jac") {
            if os.path.exists(os.path.join(current, marker)) {
                outermost = current;
            }
        }
        if stop and (current == stop) {
            break;
        }
        parent = os.path.dirname(current);
        if parent == current {
            break;
        }
        current = parent;
    }
    return os.path.dirname(outermost) if outermost else "";
}

impl _ensure_test_package(base_dir: str) -> str {
    import sys;
    import types;
    import from importlib.machinery { ModuleSpec }
    real_dir = os.path.realpath(base_dir);
    pkg_name = _TEST_PACKAGES.get(real_dir, "");
    if pkg_name and (pkg_name in sys.modules) {
        return pkg_name;
    }
    if not pkg_name {
        pkg_name = f"_jac_test_pkg_{_TEST_PKG_COUNTER[0]}";
        _TEST_PKG_COUNTER[0] += 1;
        _TEST_PACKAGES[real_dir] = pkg_name;
    }
    pkg = types.ModuleType(pkg_name);
    pkg.__path__ = [real_dir];
    pkg.__package__ = pkg_name;
    pkg.__spec__ = ModuleSpec(pkg_name, loader=None, is_package=True);
    pkg.__spec__.submodule_search_locations = [real_dir];
    sys.modules[pkg_name] = pkg;
    return pkg_name;
}

impl JacTestResult._exc_info_to_string(err: any, `test: any) -> str {
    import linecache;
    (exc_type, exc_value, tb) = err;
    entries: list[tuple[str, int, str, str]] = [];
    last: any = None;
    cur = tb;
    while cur is not None {
        frame = cur.tb_frame;
        filename = frame.f_code.co_filename;
        lineno = cur.tb_lineno;
        funcname = frame.f_code.co_name;
        cur = cur.tb_next;
        src = "";
        try {
            src = linecache.getline(filename, lineno).strip();
        } except Exception {
            src = "";
        }
        `entry = (filename, lineno, funcname, src);
        last = `entry;
        vendored = False;
        for marker in (".venv/", "site-packages/", "/unittest/") {
            if marker in filename {
                vendored = True;
            }
        }
        if vendored {
            continue;
        }
        if ("/jaclang/" in filename) and ("/tests/" not in filename) {
            continue;
        }
        entries.append(`entry);
    }
    lines: list[str] = [];
    for (filename, lineno, funcname, src) in entries {
        lines.append(f"  {filename}:{lineno} in {funcname}");
        if src {
            lines.append(f"    {src}");
        }
    }
    if (last is not None) and (not entries or (last != entries[-1])) {
        (filename, lineno, funcname, src) = last;
        lines.append(f"  {filename}:{lineno} in {funcname}");
        if src {
            lines.append(f"    {src}");
        }
    }
    lines.append(f"E   {exc_type.__name__}: {exc_value}");
    return "\n".join(lines);
}

impl run_file(
    filepath: str,
    selector: (NameFilter | None) = None,
    explicit: bool = False,
    xit: bool = False,
    maxfail: (int | None) = None,
    seen_failures: int = 0
) -> list[TestOutcome] {
    import importlib;
    import sys;
    import time;
    import from jaclang.testing.test { JacTestCheck }
    import from jaclang.testing.cl_test_runner { module_is_client, run_cl_test_file }
    import from jaclang.jac0core.ext_registry { base_stem }
    abs_path = os.path.abspath(filepath);
    outcomes: list[TestOutcome] = [];
    is_client = False;
    setup_capture = _capture_begin();
    try {
        _fresh_jac_state();
        JacTestCheck.reset();
        try {
            is_client = bool(module_is_client(abs_path));
        } except Exception {
            is_client = False;
        }
    } finally {
        _capture_end(setup_capture);
    }
    if is_client {
        try {
            results = run_cl_test_file(abs_path);
        } except Exception as exc {
            return [
                TestOutcome(
                    file=abs_path,
                    name=os.path.basename(abs_path),
                    status=ERROR,
                    message=f"{type(exc).__name__}: {exc}"
                )
            ];
        }
        for res in results {
            label = res.description or res.name;
            if (selector is not None) and not selector.matches(label) {
                continue;
            }
            outcomes.append(
                TestOutcome(
                    file=abs_path,
                    name=label,
                    status=PASSED if res.ok else FAILED,
                    message="" if res.ok else (res.error or "client test failed")
                )
            );
        }
        return outcomes;
    }
    source = _suite_source(abs_path);
    base_dir = os.path.dirname(source);
    mod_name = base_stem(os.path.basename(source));
    pkg_name = _ensure_test_package(base_dir);
    qualified = f"{pkg_name}.{mod_name}";
    real_dir = os.path.realpath(base_dir);
    basedir = _package_basedir(real_dir);
    roots: list[str] = [];
    project_root = _project_root_for(real_dir);
    if project_root {
        roots.append(project_root);
    }
    package_root = _outermost_package_root(real_dir, project_root);
    if package_root and (package_root not in roots) {
        roots.append(package_root);
    }
    injected: list[str] = [];
    for `entry in (roots + [basedir, real_dir]) {
        if `entry not in sys.path {
            sys.path.insert(0, `entry);
            injected.append(`entry);
        }
    }
    import_error = "";
    dep_gap = "";
    skip_gap = "";
    capture = _capture_begin();
    try {
        importlib.import_module(qualified);
    } except unittest.SkipTest as exc {
        skip_gap = str(exc) or "skipped at import";
    } except BaseException as exc {
        import from traceback { format_exception }
        import_error = "".join(format_exception(exc)).rstrip();
        dep_gap = _optional_dep_gap(exc);
    }
    import_output = _capture_end(capture);
    try {
        if skip_gap {
            return [
                TestOutcome(
                    file=abs_path,
                    name=os.path.basename(abs_path),
                    status=SKIPPED,
                    message=skip_gap
                )
            ];
        }
        if import_error {
            if dep_gap and not strict_mode() {
                return [
                    TestOutcome(
                        file=abs_path,
                        name=os.path.basename(abs_path),
                        status=SKIPPED,
                        message=(
                            f"missing optional dependency '{dep_gap}'"
                            f" (install it, or set {STRICT_ENV}=1 to fail instead)"
                        )
                    )
                ];
            }
            if import_output.strip() {
                import_error += "\n--- captured output ---\n" + import_output.rstrip();
            }
            return [
                TestOutcome(
                    file=abs_path,
                    name=os.path.basename(abs_path),
                    status=ERROR,
                    message=import_error
                )
            ];
        }
        pending: list[any] = [];
        for (_key, registered) in list(JacTestCheck.test_suite_path.items()) {
            for info in list(registered) {
                pending.append(info);
            }
        }
        for info in pending {
            label = info.display_name;
            if (selector is not None) and not selector.matches(label) {
                continue;
            }
            result = JacTestResult();
            started = time.perf_counter();
            capture = _capture_begin();
            try {
                _fresh_jac_state(clear_modules=False);
                info.test_case.run(result);
            } finally {
                captured = _capture_end(capture);
            }
            elapsed = time.perf_counter() - started;
            status = PASSED;
            message = "";
            if result.skipped {
                status = SKIPPED;
                message = str(result.skipped[0][1]);
            } elif result.failures {
                status = FAILED;
                message = str(result.failures[0][1]);
            } elif result.errors {
                status = ERROR;
                message = str(result.errors[0][1]);
            }
            if (status in (FAILED, ERROR)) and captured.strip() {
                message += "\n--- captured output ---\n" + captured.rstrip();
            }
            outcomes.append(
                TestOutcome(
                    file=abs_path,
                    name=label,
                    status=status,
                    message=message,
                    duration=elapsed
                )
            );
            failed = seen_failures
                + len(
                    [
                        o
                        for o in outcomes
                        if o.is_failure()
                    ]
                );
            if xit and (failed > 0) {
                return outcomes;
            }
            if maxfail and (failed >= maxfail) {
                return outcomes;
            }
        }
    } finally {
        for `entry in injected {
            try {
                sys.path.remove(`entry);
            } except ValueError {}
        }
    }
    return outcomes;
}
