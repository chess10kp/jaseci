impl resolve_fleet_entries(project_dir: str, fleet: any) -> dict[str, str] {
    base = Path(project_dir).resolve();
    excluded = source_filter_for(base);
    members = [path.relative_to(base).as_posix() for path in bundle_source_files(base)];
    return check_fleet_entries(base, members, excluded, fleet);
}


impl _fleet_entry_rel(base: Path, app: str, file: str) -> str {
    raw = Path(file);
    if raw.is_absolute() {
        try {
            return raw.resolve().relative_to(base.resolve()).as_posix();
        } except ValueError {
            raise ValueError(
                f"App '{app}' boots '{file}', which resolves outside the deployed "
                f"tree '{base}', so the bundle cannot ship it and every '{app}' "
                "pod would crash-loop on boot. Deploy from the project root."
            );
        }
    }
    rel = Path(raw.as_posix()).as_posix();
    if rel.startswith("./") {
        rel = rel[2:];
    }
    if ".." in Path(rel).parts {
        raise ValueError(
            f"App '{app}' boots '{file}', which reaches outside the deployed "
            f"tree, so the bundle cannot ship it."
        );
    }
    return rel;
}


impl check_fleet_entries(
    base: Path,
    members: list[str],
    excluded: BundleSourceFilter,
    fleet: (FleetSpec | None)
) -> dict[str, str] {
    if fleet is None or fleet.is_empty() {
        return {};
    }
    member_set: set[str] = set(members);
    resolved: dict[str, str] = {};
    for (app, member) in fleet.members.items() {
        if not member.file {
            raise ValueError(
                f"App '{app}' has no entry file, so every '{app}' pod would "
                "crash-loop on boot. Set [apps.{app}] entry-point."
            );
        }
        rel = _fleet_entry_rel(base, app, member.file);
        if rel in member_set {
            resolved[app] = rel;
            continue;
        }
        if not (base / rel).is_file() {
            raise ValueError(
                f"App '{app}' boots '{rel}', but no such file exists in the "
                f"project, so every '{app}' pod would crash-loop on boot. Add "
                f"the module or fix [apps.{app}] entry-point."
            );
        }
        raise ValueError(
            f"App '{app}' boots '{rel}', but the bundle does not ship it "
            f"({excluded.exclusion_reason(Path(rel))}), so every '{app}' pod "
            "would crash-loop on boot. Ship the file, or point the app at a "
            "module the bundle ships."
        );
    }
    return resolved;
}
