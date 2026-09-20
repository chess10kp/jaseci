impl _optional_dep_gap(exc: BaseException) -> str {
    import sys;
    if not isinstance(exc, ModuleNotFoundError) {
        return "";
    }
    name = str(exc.name or "");
    top = name.split(".")[0] if name else "";
    if not top {
        return "";
    }
    if (top in ("jaclang", "tests")) or top.startswith("_jac_test_pkg") {
        return "";
    }
    if (top in sys.stdlib_module_names) or (top in sys.builtin_module_names) {
        return "";
    }
    return top;
}

impl _under_fixtures(path: str) -> bool {
    parts = os.path.abspath(path).split(os.sep);
    return "fixtures" in parts[:-1];
}

impl _is_named_test_file(filename: str) -> bool {
    import from jaclang.jac0core.ext_registry { is_jac, is_test }
    return (filename.startswith("test_") and is_jac(filename)) or is_test(filename);
}

impl _suite_source(filepath: str) -> str {
    import from jaclang.jac0core.ext_registry { is_test }
    if is_test(os.path.basename(filepath)) {
        try {
            import from jaclang.compiler.driver.bccache { discover_base_file }
            base = discover_base_file(filepath);
            if base {
                return os.path.realpath(base);
            }
        } except Exception {}
    }
    return os.path.realpath(filepath);
}

impl _iter_candidate_files(start: str, ignore: (list[str] | None) = None) -> list[str] {
    import from jaclang.jac0core.ext_registry { is_impl, is_jac }
    ignored: list[str] = ignore or [];
    found: list[str] = [];
    for (dirpath, dirnames, filenames) in os.walk(start, topdown=True) {
        dirnames[:] = [
            d
            for d in dirnames
            if not d.startswith(".") and (d not in ("__pycache__", "node_modules"))
        ];
        dirnames.sort();
        for fn in sorted(filenames) {
            if not is_jac(fn) or is_impl(fn) {
                continue;
            }
            full = os.path.join(dirpath, fn);
            if _should_ignore(full, ignored) {
                continue;
            }
            found.append(os.path.abspath(full));
        }
    }
    return found;
}

impl discover(
    paths: (list[str] | None) = None,
    directory: (str | list[str]) = "",
    ignore: (list[str] | None) = None
) -> TestPlan {
    import from jaclang.jac0core.ext_registry { is_jac }
    targets: list[str] = paths or [];
    ignored: list[str] = ignore or [];
    explicit: set[str] = set();
    ordered: list[str] = [];
    seen: set[str] = set();
    def _add(path: str) -> None {
        key = _suite_source(path);
        if key in seen {
            return;
        }
        seen.add(key);
        ordered.append(os.path.abspath(path));
    }
    for raw in targets {
        full = os.path.abspath(raw);
        if os.path.isdir(full) {
            for cand in _iter_candidate_files(full, ignored) {
                if _under_fixtures(cand) {
                    continue;
                }
                if not _is_named_test_file(os.path.basename(cand)) {
                    continue;
                }
                _add(cand);
            }
        } elif not os.path.exists(full) {
            raise FileNotFoundError(f"no such test target: {raw}");
        } elif not is_jac(full) {
            raise ValueError(f"not a .jac file: {raw}");
        } elif not _should_ignore(full, ignored) {
            explicit.add(full);
            _add(full);
        }
    }
    roots = [directory] if isinstance(directory, str) else list(directory);
    for rt in roots {
        if not rt {
            continue;
        }
        root_dir = os.path.abspath(rt);
        for cand in _iter_candidate_files(root_dir, ignored) {
            if _under_fixtures(cand) {
                continue;
            }
            _add(cand);
        }
    }
    return TestPlan(files=ordered, explicit=explicit);
}
