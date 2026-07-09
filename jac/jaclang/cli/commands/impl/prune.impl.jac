import os;
import from time { time }
import from jaclang.cli.console { console }
import from jaclang.prune.campaign {
    Campaign,
    resolve_campaign,
    load_prune_config,
    risk_tier_label
}
import from jaclang.prune.manifest { Manifest, FileRole, build_manifest, role_label }


def _resolve_root(paths: list[str]) -> str {
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    start = paths[0] if paths else None;
    found = find_jac_project_root(start);
    if found {
        return found;
    }
    return os.path.abspath(paths[0]) if paths else os.getcwd();
}


def _make_campaign(
    paths: list[str],
    exclude: list[str],
    recipes: list[str],
    risk_ceiling: str,
    output: str
) -> Campaign {
    abs_paths = [os.path.abspath(p) for p in paths];
    project_root = _resolve_root(abs_paths);
    toml_cfg = load_prune_config(project_root);
    return resolve_campaign(
        paths=abs_paths,
        project_root=project_root,
        toml_config=toml_cfg,
        exclude=exclude or None,
        recipes=recipes or None,
        risk_ceiling=risk_ceiling,
        output_format=output
    );
}


def _print_manifest_summary(manifest: Manifest) {
    counts = manifest.role_counts();
    order = [
        FileRole.SOURCE,
        FileRole.IMPL_ANNEX,
        FileRole.TEST,
        FileRole.FIXTURE,
        FileRole.GENERATED,
        FileRole.VENDORED,
        FileRole.DOCS,

    ];
    rows: list[list[str]] = [];
    for role in order {
        label = role_label(role);
        n = counts.get(label, 0);
        if n > 0 {
            rows.append([label, str(n)]);
        }
    }
    rows.append(["TOTAL", str(len(manifest.entries))]);
    console.print_table(["role", "files"], rows, title="Ingestion manifest");
    console.info(
        f"{len(manifest.live_entries())} live files (source + impl annex) in scope"
    );
}


impl prune(
    action: str = "report",
    paths: (list | None) = None,
    exclude: (list | None) = None,
    recipes: (list | None) = None,
    risk_ceiling: str = "",
    output: str = "",
    preview: bool = False,
    apply: bool = False
) -> int {
    paths = paths or [];
    if isinstance(paths, str) {
        paths = [paths];
    }
    campaign = _make_campaign(
        paths, exclude or [], recipes or [], risk_ceiling, output
    );

    if action == "report" {
        return _run_report(campaign);
    } elif action == "facts" {
        return _run_facts(campaign);
    } elif action == "fix" {
        return _run_fix(campaign, preview=preview, apply=apply);
    }
    console.error(
        f"Unknown prune action '{action}'.",
        hint="Available actions: report, facts, fix"
    );
    return 2;
}


def _run_report(campaign: Campaign) -> int {
    start = time();
    console.print_header("jac prune — report");
    console.info(f"project root: {campaign.project_root}");
    console.info(f"recipes: {', '.join(campaign.recipes)}");
    console.info(f"risk ceiling: {risk_tier_label(campaign.risk_ceiling)}");

    manifest = build_manifest(campaign);
    if not manifest.entries {
        console.warning("No .jac files found in scope.");
        return 0;
    }
    _print_manifest_summary(manifest);

    (prog, errs, warns, compiled) = _compile_scope(campaign, manifest);
    console.print("");
    console.info(
        f"compiled {compiled} entry module(s): {errs} error(s), {warns} warning(s)"
    );
    console.print("");
    console.warning(
        "Detectors not wired yet (Phase 3). This is the Phase-1 ingestion stub."
    );
    console.print_elapsed_time(time() - start);
    return 0;
}


def _compile_scope(
    campaign: Campaign, manifest: Manifest
) -> tuple[any, int, int, int] {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }

    prog = JacProgram();
    prog._track_dependencies = True;
    compiled = 0;
    for entry in manifest.by_role(FileRole.SOURCE) {
        if entry.path in prog.mod.hub {
            continue;
        }
        try {
            prog.compile(
                file_path=entry.path,
                options=CompileOptions(
                    type_check=True, no_cgen=True, force_target_program=True
                )
            );
            compiled += 1;
        } except Exception as e {
            console.warning(f"compile failed: {entry.module_name}: {e}");
        }
    }
    return (prog, len(prog.errors_had), len(prog.warnings_had), compiled);
}


def _facts_db_path(campaign: Campaign) -> str {
    cache_dir = os.path.join(campaign.project_root, ".jac");
    if not os.path.isdir(cache_dir) {
        try {
            os.makedirs(cache_dir, exist_ok=True);
        } except Exception {
            return os.path.join(campaign.project_root, "prune.db");
        }
    }
    return os.path.join(cache_dir, "prune.db");
}


def _run_facts(campaign: Campaign) -> int {
    import from jaclang.prune.extract { extract_facts }
    import from jaclang.prune.factstore { FactStore }

    start = time();
    console.print_header("jac prune — facts");
    console.info(f"project root: {campaign.project_root}");

    manifest = build_manifest(campaign);
    if not manifest.entries {
        console.warning("No .jac files found in scope.");
        return 0;
    }
    _print_manifest_summary(manifest);

    (prog, errs, warns, compiled) = _compile_scope(campaign, manifest);
    console.info(f"compiled {compiled} module(s): {errs} error(s), {warns} warning(s)");

    facts = extract_facts(prog, manifest);
    db_path = _facts_db_path(campaign);
    store = FactStore(db_path=db_path);
    store.open();
    (refreshed, skipped) = store.sync(facts);
    row_counts = store.counts();
    store.close();

    console.print("");
    console.info(f"fact store: {db_path}");
    console.info(
        f"{len(refreshed)} module(s) refreshed, {len(skipped)} unchanged (cached)"
    );
    rows: list[list[str]] = [];
    for tbl in [
        "modules",
        "symbols",
        "refs",
        "imports",
        "field_accesses",
        "module_deps"
    ] {
        rows.append([tbl, str(row_counts.get(tbl, 0))]);
    }
    console.print_table(["table", "rows"], rows, title="Fact store");
    console.print_elapsed_time(time() - start);
    return 0;
}


def _run_fix(campaign: Campaign, preview: bool = False, apply: bool = False) -> int {
    console.error(
        "Fix mode is not implemented yet (Phases 4-5).",
        hint="Use 'jac prune report' for the current ingestion stub."
    );
    return 2;
}
