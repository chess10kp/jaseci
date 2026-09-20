impl _is_bundle_required(rel: Path) -> bool {
    parts = rel.parts;
    if (
        len(parts) >= 3
        and parts[0] == ".jac"
        and parts[1] == "client"
        and parts[2] == "dist"
    ) {
        return True;
    }

    if len(parts) >= 2 and parts[0] == ".jac" and parts[1] == "admin" {
        return True;
    }
    return len(parts) == 2 and parts[0] == ".jac" and parts[1] == "serve_manifest.json";
}


impl BundleSourceFilter.parks(rel: Path) -> bool {
    import from jaclang.project.source { path_matches_exclude }

    return path_matches_exclude(rel.as_posix(), self.ignore_patterns);
}


impl BundleSourceFilter.is_build_tree(rel: Path) -> bool {
    return _exclude_dir_root(rel) is not None;
}


impl BundleSourceFilter.excludes_tree(rel: Path) -> bool {
    if self.is_build_tree(rel) {
        return True;
    }
    return self.parks(rel);
}


impl BundleSourceFilter.excludes(rel: Path) -> bool {
    if _is_bundle_required(rel) {
        return False;
    }
    if self.excludes_tree(rel) {
        return True;
    }
    name = rel.name;
    if name in _EXCLUDE_FILES {
        return True;
    }
    if name == ".env" or name.startswith(".env.") {
        return True;
    }
    return name.endswith(_EXCLUDE_SUFFIXES);
}


impl BundleSourceFilter.matching_ignore_pattern(rel: Path) -> str {
    import from jaclang.project.source { path_matches_exclude }

    for pattern in self.ignore_patterns {
        if path_matches_exclude(rel.as_posix(), [pattern]) {
            return pattern;
        }
    }
    return "";
}


impl BundleSourceFilter.exclusion_reason(rel: Path) -> str {
    for part in rel.parts {
        if part in _EXCLUDE_DIRS {
            return f"'{part}/' is a build or cache tree the deploy never ships";
        }
    }
    pattern = self.matching_ignore_pattern(rel);
    if pattern {
        return f"parked by the .jacignore pattern '{pattern}'";
    }
    name = rel.name;
    if name == "jac.toml" {
        return (
            "the deploy ships a sanitized jac.toml with [scale.secrets] "
            "and [dev] stripped"
        );
    }
    if name == ".env" or name.startswith(".env.") {
        return (
            "'.env' files never ship; move deploy values to "
            "[scale.secrets] or pod env"
        );
    }
    if name in _EXCLUDE_FILES or name.endswith(_EXCLUDE_SUFFIXES) {
        return f"'{name}' is key material the deploy never ships";
    }
    return "excluded from the bundle";
}


impl source_filter_for(base: Path) -> BundleSourceFilter {
    import from jaclang.project.source { read_jacignore_patterns }

    return BundleSourceFilter(ignore_patterns=read_jacignore_patterns(str(base)));
}


impl _project_config(project_dir: str) -> any {
    import from jaclang.project.config { get_config_for_path }

    try {
        return get_config_for_path(Path(project_dir));
    } except Exception as exc {
        raise ValueError(
            f"jac.toml under '{project_dir}' cannot be parsed ({exc}), so the "
            "deploy cannot resolve the entry module or the service modules, "
            "and every pod would fail on the same file at boot. Fix jac.toml "
            "and re-deploy."
        ) from exc;
    }
}


impl _entry_module_spec(project_dir: str) -> (tuple[Path, Path] | None) {
    config = _project_config(project_dir);
    if config is None {
        return None;
    }
    proj_root: Path = config.project_root or Path(project_dir);
    if config.apps {
        try {
            app = config.resolve_app("");
        } except ValueError {
            return None;
        }
        return (proj_root.resolve(), Path(app.entry_path(str(proj_root))));
    }
    if not config.project.entry_point {
        return None;
    }
    import from jaclang.project.apps { resolve_entry_path }
    return (
        proj_root.resolve(),
        Path(resolve_entry_path(config.project.entry_point, str(proj_root)))
    );
}


impl entry_module_rel(project_dir: str) -> (Path | None) {
    spec = _entry_module_spec(project_dir);
    if spec is None {
        return None;
    }
    (proj_root, entry_path) = spec;
    try {
        return (proj_root / entry_path).resolve().relative_to(
            Path(project_dir).resolve()
        );
    } except ValueError {
        return None;
    }
}


impl assert_entry_module_ships(base: Path, excluded: BundleSourceFilter) {
    rel = entry_module_rel(str(base));
    if rel is None or not (base / rel).is_file() or not excluded.excludes(rel) {
        return;
    }
    raise ValueError(
        f"The project entry module '{rel.as_posix()}' is excluded from the "
        f"bundle ({excluded.exclusion_reason(rel)}), so the bundle would ship "
        "without an entry point and every pod would crash-loop on boot. Ship "
        "the module (for .jacignore, drop the pattern that matches it), or "
        "point [project] entry-point at a module the bundle ships."
    );
}


impl _exclude_dir_root(rel: Path) -> (str | None) {
    parts = rel.parts;
    depth = 0;
    for part in parts {
        depth += 1;
        if part in _EXCLUDE_DIRS {
            return "/".join(parts[:depth]);
        }
    }
    return None;
}


impl partition_bundle_sources(base: Path) -> tuple[list[Path], list[str]] {
    excluded = source_filter_for(base);
    kept: list[Path] = [];
    pruned: set[str] = set();
    for path in sorted(base.rglob("*")) {
        rel = path.relative_to(base);
        if not excluded.excludes(rel) {
            if path.is_file() {
                kept.append(path);
            }
            continue;
        }
        pruned_tree = _exclude_dir_root(rel);
        if pruned_tree is not None {
            pruned.add(pruned_tree);
        }
    }
    shipped: set[str] = set();
    for path in kept {
        parent = path.relative_to(base).parent;
        while parent.as_posix() not in (".", "") {
            shipped.add(parent.as_posix());
            parent = parent.parent;
        }
    }
    return (
        kept,
        sorted(
            [
                tree
                for tree in pruned
                if tree not in shipped
            ]
        )
    );
}


impl bundle_source_files(base: Path) -> list[Path] {
    (kept, pruned) = partition_bundle_sources(base);
    for pruned_tree in pruned {
        key = f"{base}::{pruned_tree}";
        if key in _reported_prunes {
            continue;
        }
        _reported_prunes.add(key);
        logger.info(
            f"Bundle: nothing under '{pruned_tree}/' ships, because a path segment "
            f"names a build output directory. Rename it if it holds source "
            f"the pods need."
        );
    }
    return kept;
}
