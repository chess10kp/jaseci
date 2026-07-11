import os;
import from time { time }
import from jaclang.cli.console { console }
import from jaclang.prune.campaign {
    Campaign,
    Disposition,
    OutputFormat,
    PruneAction,
    resolve_campaign,
    load_prune_config,
    parse_prune_action,
    risk_tier_label
}
import from jaclang.prune.manifest { Manifest, FileRole, build_manifest, role_label }
import from jaclang.prune.pipeline {
    Analysis,
    build_analysis,
    compile_scope,
    facts_db_path
}


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
    apply: bool = False,
    model: str = "heuristic",
    group: str = "",
    probe: bool = False,
    history: bool = False,
    windows: bool = False,
    fuzzy: bool = False,
    limit: int = 200,
    decision: str = "",
    cite: str = "",
    note: str = "",
    fate: str = ""
) -> int {
    paths = paths or [];
    if isinstance(paths, str) {
        paths = [paths];
    }
    parsed_action = parse_prune_action(action);
    if parsed_action is None {
        console.error(
            f"Unknown prune action '{action}'.",
            hint="Available actions: report, facts, fix, analyze, reuse, list, show"
        );
        return 2;
    }

    show_target = "";
    if parsed_action == PruneAction.SHOW or parsed_action == PruneAction.VERDICT {
        if paths {
            show_target = paths[0];
            paths = paths[1:];
        } else {
            show_target = group;
        }
    }

    campaign = _make_campaign(
        paths, exclude or [], recipes or [], risk_ceiling, output
    );

    if parsed_action == PruneAction.REPORT {
        return _run_report(campaign);
    } elif parsed_action == PruneAction.FACTS {
        return _run_facts(campaign);
    } elif parsed_action == PruneAction.FIX {
        return _run_fix(campaign, preview=preview, apply=apply);
    } elif parsed_action == PruneAction.ANALYZE {
        return _run_analyze(campaign, model=model);
    } elif parsed_action == PruneAction.REUSE {
        return _run_reuse(
            campaign,
            group=group,
            probe=probe,
            history=history,
            windows=windows,
            fuzzy=fuzzy
        );
    } elif parsed_action == PruneAction.LIST {
        return _run_list(campaign, limit=limit);
    } elif parsed_action == PruneAction.SHOW {
        return _run_show(campaign, show_target);
    } elif parsed_action == PruneAction.VERDICT {
        return _run_verdict(
            campaign, show_target, decision=decision, cite=cite, note=note, fate=fate
        );
    }
    return 2;
}


def _reuse_context(campaign: Campaign) -> tuple {
    import from jaclang.prune.extract { extract_facts }
    import from jaclang.prune.factstore { FactStore }
    manifest = build_manifest(campaign);
    if not manifest.entries {
        return (None, None, None);
    }
    def on_compile_error(path: str, err: any) {
        console.warning(f"compile failed: {path}: {err}");
    }
    (prog, errs, warns, compiled) = compile_scope(
        campaign, manifest, on_error=on_compile_error
    );
    facts = extract_facts(prog, manifest);
    store = FactStore(db_path=facts_db_path(campaign));
    store.open();
    store.sync(facts);
    return (store, prog, manifest);
}


def _reuse_scope_paths(manifest: Manifest) -> tuple[list[str], list[str]] {
    source_paths = [e.path for e in manifest.by_role(FileRole.SOURCE)];
    test_paths = [e.path for e in manifest.by_role(FileRole.TEST)];
    return (source_paths, test_paths);
}


def _reorder_by_tandem(groups: list, histories: dict) -> list {
    def key(g: any) -> tuple {
        h = histories.get(g.group_id);
        ratio = 0.0;
        tandem = 0;
        if h is not None and h.get("available") {
            ratio = h.get("tandem_ratio", 0.0);
            tandem = h.get("tandem_commits", 0);
        }
        return (-ratio, -tandem, -g.payoff, g.group_id);
    }
    return sorted(groups, key=key);
}


def _run_reuse(
    campaign: Campaign,
    group: str = "",
    probe: bool = False,
    history: bool = False,
    windows: bool = False,
    fuzzy: bool = False
) -> int {
    import json;
    import from jaclang.prune.clones {
        find_clone_groups,
        find_class_rollups,
        group_summary,
        group_packet,
        rollup_summary
    }
    import from jaclang.prune.probe { probe_group, probe_groups }
    import from jaclang.prune.history { git_root, group_history, annotate_histories }
    import from jaclang.prune.windows {
        find_stmt_windows,
        window_summary,
        window_packet
    }
    import from jaclang.prune.fuzzy {
        find_fuzzy_clone_groups,
        fuzzy_summary,
        fuzzy_packet
    }
    import from jaclang.prune.validate { snapshot_baseline }

    start = time();
    as_json = campaign.output_format == OutputFormat.JSON;
    quiet = campaign.output_format != OutputFormat.TABLE;
    if not quiet {
        console.print_header("jac prune - reuse (structural duplicates, report-only)");
        console.info(f"project root: {campaign.project_root}");
    }

    (store, prog, manifest) = _reuse_context(campaign);
    if store is None {
        if as_json {
            console.print("[]");
        } else {
            console.warning("No .jac files found in scope.");
        }
        return 0;
    }

    groups = find_clone_groups(store);

    if group and group.startswith("reuse:win:") {
        wins = find_stmt_windows(store);
        wtarget = None;
        for w in wins {
            if w.window_id == group {
                wtarget = w;
            }
        }
        if wtarget is None {
            store.close();
            console.print("{}")
                if as_json
                else console.error(f"No statement window with id '{group}'.");
            return 2;
        }
        packet = window_packet(wtarget, store);
        store.close();
        console.print(json.dumps(packet, indent=2));
        return 0;
    }

    if group and group.startswith("reuse:fzy:") {
        (fz_groups, _fz_skipped) = find_fuzzy_clone_groups(store);
        ftarget = None;
        for fg in fz_groups {
            if fg.group_id == group {
                ftarget = fg;
            }
        }
        if ftarget is None {
            store.close();
            console.print("{}")
                if as_json
                else console.error(f"No fuzzy clone group with id '{group}'.");
            return 2;
        }
        packet = fuzzy_packet(store, ftarget);
        store.close();
        console.print(json.dumps(packet, indent=2));
        return 0;
    }

    if group {
        target = None;
        for g in groups {
            if g.group_id == group {
                target = g;
            }
        }
        if target is None {
            store.close();
            if as_json {
                console.print("{}");
            } else {
                console.error(f"No clone group with id '{group}'.");
            }
            return 2;
        }
        probe_dict = None;
        if probe {
            (source_paths, test_paths) = _reuse_scope_paths(manifest);
            baseline = snapshot_baseline(source_paths);
            probe_dict = probe_group(
                target, source_paths, test_paths, prog, baseline
            ).as_dict();
        }
        history_dict = None;
        if history {
            repo = git_root(campaign.project_root);
            if repo is not None {
                history_dict = group_history(target, repo).as_dict();
            }
        }
        packet = group_packet(store, target, probe=probe_dict, history=history_dict);
        store.close();
        console.print(json.dumps(packet, indent=2));
        return 0;
    }

    probes: dict = {};
    if probe {
        (source_paths, test_paths) = _reuse_scope_paths(manifest);
        gp = probe_groups(groups, source_paths, test_paths, prog);
        for (gid, res) in gp.items() {
            probes[gid] = res.as_dict();
        }
    }

    histories: dict = {};
    if history {
        repo = git_root(campaign.project_root);
        if repo is not None {
            hs = annotate_histories(groups, repo);
            for (gid, h) in hs.items() {
                histories[gid] = h.as_dict();
            }
            groups = _reorder_by_tandem(groups, histories);
        }
    }

    win_groups: list = [];
    if windows {
        win_groups = find_stmt_windows(store);
    }

    fuzzy_groups: list = [];
    fuzzy_skipped: list = [];
    if fuzzy {
        (fuzzy_groups, fuzzy_skipped) = find_fuzzy_clone_groups(store);
    }

    rollups = find_class_rollups(groups);
    if as_json {
        payload = {
            "groups": [
                group_summary(
                    g, probe=probes.get(g.group_id), history=histories.get(g.group_id)
                ) for g in groups
            ],
            "rollups": [rollup_summary(r) for r in rollups]
        };
        if windows {
            payload["windows"] = [window_summary(w) for w in win_groups];
        }
        if fuzzy {
            payload["fuzzy"] = [fuzzy_summary(fg) for fg in fuzzy_groups];
            payload["fuzzy_skipped_buckets"] = fuzzy_skipped;
        }
        store.close();
        console.print(json.dumps(payload, indent=2));
        return 0;
    }

    store.close();
    if not groups and not win_groups and not fuzzy_groups {
        console.success("No structural duplicates found. 🎉");
        console.print_elapsed_time(time() - start);
        return 0;
    }
    if groups {
        rows: list[list[str]] = [];
        for g in groups {
            members = ", ".join(
                [f"{m.owner_name or '<mod>'}.{m.name}" for m in g.members]
            );
            row = [g.kind, str(len(g.members)), str(g.lines_saved), f"{g.payoff:.2f}"];
            if probe {
                pr = probes.get(g.group_id);
                row.append(pr.get("status", "-") if pr is not None else "-");
            }
            if history {
                h = histories.get(g.group_id);
                if h is not None and h.get("available") {
                    row.append(str(h.get("tandem_commits", 0)));
                } else {
                    row.append("-");
                }
            }
            row.append(members);
            rows.append(row);
        }
        header = ["kind", "copies", "~lines", "payoff"];
        if probe {
            header.append("probe");
        }
        if history {
            header.append("tandem");
        }
        header.append("members");
        console.print_table(
            header, rows, title=f"Structural-duplicate candidates ({len(groups)})"
        );
    }
    if win_groups {
        wrows = [
            [
                str(w.length),
                str(len(w.sites)),
                f"{w.payoff:.2f}",
                ", ".join([f"{s.owner_name or '<mod>'}.{s.name}" for s in w.sites])
            ] for w in win_groups
        ];
        console.print_table(
            ["stmts", "sites", "payoff", "functions"],
            wrows,
            title=f"Repeated statement-window blocks ({len(win_groups)})"
        );
    }
    if fuzzy_groups {
        frows = [
            [
                str(len(fg.members)),
                f"{fg.min_similarity:.2f}",
                str(fg.lines_saved),
                f"{fg.payoff:.2f}",
                ", ".join([f"{m.owner_name or '<mod>'}.{m.name}" for m in fg.members])
            ] for fg in fuzzy_groups
        ];
        console.print_table(
            ["copies", "min~sim", "~lines", "payoff", "members"],
            frows,
            title=f"Fuzzy near-clone candidates ({len(fuzzy_groups)})"
        );
        if fuzzy_skipped {
            console.warning(
                f"{len(fuzzy_skipped)} oversized bucket(s) skipped for fuzzy "
                "comparison (bound the cost); re-run scoped to inspect them."
            );
        }
    }
    if rollups {
        rrows = [
            [", ".join(r.class_names), str(r.shared_method_count), str(r.lines_saved)]
            for r in rollups
        ];
        console.print_table(
            ["classes", "shared methods", "~lines"],
            rrows,
            title=f"Class-hoist rollups ({len(rollups)})"
        );
    }
    console.info(
        "Report-only by construction: every group cites verified fact IDs; the "
        "tool loads no model and applies nothing."
    );
    console.print_elapsed_time(time() - start);
    return 0;
}


def _run_report(campaign: Campaign) -> int {
    import from jaclang.prune.report { to_json, to_sarif }

    start = time();

    quiet = campaign.output_format != OutputFormat.TABLE;
    if not quiet {
        console.print_header("jac prune - report");
        console.info(f"project root: {campaign.project_root}");
        console.info(f"recipes: {', '.join(campaign.recipes)}");
        console.info(f"risk ceiling: {risk_tier_label(campaign.risk_ceiling)}");
    }

    manifest = build_manifest(campaign);
    if not manifest.entries {
        if not quiet {
            console.warning("No .jac files found in scope.");
        } else {
            console.print(
                "[]" if campaign.output_format == OutputFormat.JSON else "{}"
            );
        }
        return 0;
    }

    analysis = build_analysis(campaign, manifest);
    candidates = analysis.candidates;
    suppressed = analysis.suppressed;
    (errs, warns, compiled) = (analysis.errs, analysis.warns, analysis.compiled);

    if campaign.output_format == OutputFormat.JSON {
        console.print(to_json(candidates, analysis.store));
        return 0;
    }
    if campaign.output_format == OutputFormat.SARIF {
        console.print(to_sarif(candidates, campaign.project_root));
        return 0;
    }

    _print_manifest_summary(manifest);
    console.print("");
    console.info(f"compiled {compiled} module(s): {errs} error(s), {warns} warning(s)");
    _print_findings(campaign, candidates, suppressed);
    console.print_elapsed_time(time() - start);
    return 0;
}


def _print_findings(campaign: Campaign, candidates: list, suppressed_count: int) {
    import from jaclang.prune.report { table_rows, summarize }
    console.print("");
    if not candidates {
        console.success("No findings. Nothing to prune. 🎉");
        if suppressed_count > 0 {
            console.info(f"({suppressed_count} finding(s) suppressed)");
        }
        return;
    }
    rows = table_rows(candidates, campaign.project_root);
    console.print_table(
        ["detector", "risk", "disposition", "location", "message"],
        rows,
        title=f"Findings ({len(candidates)})"
    );
    summary = summarize(candidates);
    console.info(
        f"{summary.get('auto-fix', 0)} auto-fix · "
        f"{summary.get('pr-only', 0)} pr-only · "
        f"{summary.get('report-only', 0)} report-only" + (
            f" · {suppressed_count} suppressed" if suppressed_count > 0 else ""
        )
    );
}


def _run_analyze(campaign: Campaign, model: str = "heuristic") -> int {
    import from jaclang.prune.agent { parse_agent_judge, build_judge }
    import from jaclang.prune.report { to_json }

    start = time();
    judge = build_judge(parse_agent_judge(model));
    quiet = campaign.output_format != OutputFormat.TABLE;
    if not quiet {
        console.print_header("jac prune - analyze (agent redundancy, report-only)");
        console.info(f"project root: {campaign.project_root}");
        console.info(f"judge: {model}");
    }

    manifest = build_manifest(campaign);
    if not manifest.entries {
        if not quiet {
            console.warning("No .jac files found in scope.");
        } else {
            console.print("[]");
        }
        return 0;
    }

    analysis = build_analysis(campaign, manifest, agent=True, judge=judge);
    candidates = analysis.candidates;

    if campaign.output_format == OutputFormat.JSON {
        console.print(to_json(candidates, analysis.store));
        return 0;
    }

    console.info(
        f"compiled {analysis.compiled} module(s); "
        f"{analysis.detector_input} detector finding(s) fed to the loop"
    );
    _print_findings(campaign, candidates, 0);
    console.info(
        f"{analysis.agent_ledger} hypotheses judged "
        f"({len(candidates)} confirmed, "
        f"{analysis.agent_ledger - len(candidates)} abstained/rejected/dropped)"
    );
    console.info(
        "Agent findings are advisory (report-only / pr-only) - every claim cites "
        "verified fact IDs; none can auto-fix."
    );
    console.print_elapsed_time(time() - start);
    return 0;
}


def _run_list(campaign: Campaign, limit: int = 200) -> int {
    import from jaclang.prune.report { list_rows, list_json }

    start = time();
    as_json = campaign.output_format == OutputFormat.JSON;
    quiet = campaign.output_format != OutputFormat.TABLE;
    if not quiet {
        console.print_header("jac prune - list (ranked finding index)");
        console.info(f"project root: {campaign.project_root}");
    }

    manifest = build_manifest(campaign);
    if not manifest.entries {
        if as_json {
            console.print('{"findings": [], "shown": 0, "total": 0, "suppressed": 0}');
        } else {
            console.warning("No .jac files found in scope.");
        }
        return 0;
    }

    analysis = build_analysis(campaign, manifest);
    candidates = analysis.candidates;

    if as_json {
        console.print(list_json(candidates, campaign.project_root, limit));
        return 0;
    }

    (rows, suppressed) = list_rows(candidates, campaign.project_root, limit);
    if not rows {
        console.success("No findings. Nothing to prune. 🎉");
        console.print_elapsed_time(time() - start);
        return 0;
    }
    console.print_table(
        ["fingerprint", "disposition", "confidence", "location", "message"],
        rows,
        title=f"Ranked findings ({len(candidates)})"
    );
    if suppressed > 0 {
        console.info(
            f"{suppressed} more suppressed by rank; raise --limit to see them."
        );
    }
    console.info("Drill into any row with: jac prune show <fingerprint> -o json");
    console.print_elapsed_time(time() - start);
    return 0;
}


def _run_show(campaign: Campaign, target: str) -> int {
    if not target {
        console.error(
            "show requires a target.", hint="jac prune show <fingerprint|group_id>"
        );
        return 2;
    }
    if target.startswith("reuse:") {
        return _show_reuse(campaign, target);
    }
    return _show_finding(campaign, target);
}


def _show_finding(campaign: Campaign, fingerprint: str) -> int {
    import json;
    import from jaclang.prune.factquery { cite_index }

    as_json = campaign.output_format != OutputFormat.TABLE;
    manifest = build_manifest(campaign);
    if not manifest.entries {
        if as_json {
            console.print("{}");
        } else {
            console.warning("No .jac files found in scope.");
        }
        return 2;
    }

    analysis = build_analysis(campaign, manifest);
    target = None;
    for c in analysis.candidates {
        if c.finding.fingerprint() == fingerprint {
            target = c;
        }
    }
    if target is None {
        if as_json {
            console.print("{}");
        } else {
            console.error(f"No finding with fingerprint '{fingerprint}'.");
        }
        return 2;
    }
    idx = cite_index(analysis.store, target.finding.packet_citations())
        if analysis.store is not None
        else {};
    console.print(json.dumps(target.as_dict(idx), indent=2));
    return 0;
}


def _show_reuse(campaign: Campaign, target: str) -> int {
    import json;
    import from jaclang.prune.clones { find_clone_groups, group_packet }
    import from jaclang.prune.windows { find_stmt_windows, window_packet }
    import from jaclang.prune.fuzzy { find_fuzzy_clone_groups, fuzzy_packet }

    (store, prog, manifest) = _reuse_context(campaign);
    if store is None {
        console.print("{}");
        return 2;
    }

    packet = None;
    if target.startswith("reuse:win:") {
        for w in find_stmt_windows(store) {
            if w.window_id == target {
                packet = window_packet(w, store);
            }
        }
    } elif target.startswith("reuse:fzy:") {
        (fz_groups, _skipped) = find_fuzzy_clone_groups(store);
        for fg in fz_groups {
            if fg.group_id == target {
                packet = fuzzy_packet(store, fg);
            }
        }
    } else {
        for g in find_clone_groups(store) {
            if g.group_id == target {
                packet = group_packet(store, g);
            }
        }
    }
    store.close();

    if packet is None {
        if campaign.output_format == OutputFormat.TABLE {
            console.error(f"No reuse group with id '{target}'.");
        } else {
            console.print("{}");
        }
        return 2;
    }
    console.print(json.dumps(packet, indent=2));
    return 0;
}


def _verdict_finding_packet(campaign: Campaign, fingerprint: str) -> dict | None {
    import from jaclang.prune.factquery { cite_index }
    manifest = build_manifest(campaign);
    if not manifest.entries {
        return None;
    }
    analysis = build_analysis(campaign, manifest);
    for c in analysis.candidates {
        if c.finding.fingerprint() == fingerprint {
            idx = cite_index(analysis.store, c.finding.packet_citations())
                if analysis.store is not None
                else {};
            return c.as_dict(idx);
        }
    }
    return None;
}


def _verdict_reuse_packet(campaign: Campaign, target: str) -> dict | None {
    import from jaclang.prune.clones { find_clone_groups, group_packet }
    import from jaclang.prune.windows { find_stmt_windows, window_packet }
    import from jaclang.prune.fuzzy { find_fuzzy_clone_groups, fuzzy_packet }

    (store, prog, manifest) = _reuse_context(campaign);
    if store is None {
        return None;
    }
    packet = None;
    if target.startswith("reuse:win:") {
        for w in find_stmt_windows(store) {
            if w.window_id == target {
                packet = window_packet(w, store);
            }
        }
    } elif target.startswith("reuse:fzy:") {
        (fz_groups, _skipped) = find_fuzzy_clone_groups(store);
        for fg in fz_groups {
            if fg.group_id == target {
                packet = fuzzy_packet(store, fg);
            }
        }
    } else {
        for g in find_clone_groups(store) {
            if g.group_id == target {
                packet = group_packet(store, g);
            }
        }
    }
    store.close();
    return packet;
}


def _verdict_meta(target: str, packet: dict) -> dict {
    p: any = packet;
    if target.startswith("reuse:") {
        members = p.get("members", []);
        first: any = members[0] if members else {};
        return {
            "fingerprint": target,
            "detector": f"reuse-{p.get('kind', 'window')}",
            "symbol_id": str(p.get("canonical_member", "")),
            "name": target,
            "module_path": str(first.get("module_path", "")),
            "risk": "moderate",
            "disposition": "report-only",
            "source": "reuse"
        };
    }
    return {
        "fingerprint": str(p.get("fingerprint", target)),
        "detector": str(p.get("detector", "")),
        "symbol_id": str(p.get("symbol_id", "")),
        "name": str(p.get("name", "")),
        "module_path": str(p.get("module_path", "")),
        "risk": str(p.get("risk", "")),
        "disposition": str(p.get("disposition", "")),
        "source": str(p.get("source", ""))
    };
}


def _run_verdict(
    campaign: Campaign,
    target: str,
    decision: str = "",
    cite: str = "",
    note: str = "",
    fate: str = ""
) -> int {
    import from jaclang.prune.feedback {
        FeedbackLog,
        verdict_entry,
        valid_decision,
        valid_fate,
        citation_gate
    }
    import from jaclang.prune.suppress {
        suppression_write_path,
        append_suppression_token
    }

    if not target {
        console.error(
            "verdict requires a target.",
            hint="jac prune verdict <fingerprint|group_id> --decision … --cite …"
        );
        return 2;
    }
    if not valid_decision(decision) {
        console.error(
            f"invalid --decision '{decision}'.",
            hint="one of: accept, reject, contested"
        );
        return 2;
    }
    if not valid_fate(fate) {
        console.error(
            f"invalid --fate '{fate}'.",
            hint="one of: landed-unchanged, landed-modified, abandoned, reverted"
        );
        return 2;
    }
    cited = [
        c.strip()
        for c in cite.split(",")
        if c.strip()
    ];
    if not cited {
        console.error(
            "a verdict must cite at least one fact ID.",
            hint="--cite sym:…,ref:… (IDs from the finding's packet)"
        );
        return 2;
    }

    packet = _verdict_reuse_packet(campaign, target)
        if target.startswith("reuse:")
        else _verdict_finding_packet(campaign, target);
    if packet is None {
        console.error(
            f"no finding or reuse group with id '{target}'.",
            hint="run 'jac prune list' (or 'reuse') to get valid ids"
        );
        return 2;
    }

    missing = citation_gate(cited, packet);
    if missing {
        console.error(
            "citation gate: cited fact ID(s) not present in the packet — "
            f"{', '.join(missing)}",
            hint="every --cite must appear in the packet's citations/cite_index"
        );
        return 2;
    }

    meta = _verdict_meta(target, packet);
    entry = verdict_entry(meta, decision, cited, note=note, fate=fate);
    log = FeedbackLog(
        path=os.path.join(campaign.project_root, ".jac", "prune-feedback.jsonl")
    );
    if not log.record_all([entry]) {
        console.error("failed to write the verdict to the ledger.");
        return 1;
    }

    console.success(
        f"recorded verdict-{decision.strip().lower()} on {target} "
        f"({len(cited)} citation(s))."
    );
    if fate.strip() {
        console.info(f"fate: {fate.strip().lower()}");
    }
    if decision.strip().lower() == "reject" {
        m: any = meta;
        sp = suppression_write_path(campaign);
        if append_suppression_token(sp, str(m.get("fingerprint", target))) {
            console.info(f"suppressed permanently -> {sp}");
        } else {
            console.warning("could not append the rejection to the suppression file.");
        }
    }
    return 0;
}


def _run_facts(campaign: Campaign) -> int {
    import from jaclang.prune.extract { extract_facts }
    import from jaclang.prune.factstore { FactStore }

    start = time();
    console.print_header("jac prune - facts");
    console.info(f"project root: {campaign.project_root}");

    manifest = build_manifest(campaign);
    if not manifest.entries {
        console.warning("No .jac files found in scope.");
        return 0;
    }
    _print_manifest_summary(manifest);

    def on_compile_error(path: str, err: any) {
        console.warning(f"compile failed: {path}: {err}");
    }
    (prog, errs, warns, compiled) = compile_scope(
        campaign, manifest, on_error=on_compile_error
    );
    console.info(f"compiled {compiled} module(s): {errs} error(s), {warns} warning(s)");

    facts = extract_facts(prog, manifest);
    db_path = facts_db_path(campaign);
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
        "module_deps",
        "bodies",
        "literals",
        "docstrings"
    ] {
        rows.append([tbl, str(row_counts.get(tbl, 0))]);
    }
    console.print_table(["table", "rows"], rows, title="Fact store");
    console.print_elapsed_time(time() - start);
    return 0;
}


def _write(path: str, data: bytes) {
    with open(path, "wb") as fh {
        fh.write(data);
    }
}


def _run_fix(campaign: Campaign, preview: bool = False, apply: bool = False) -> int {
    import from jaclang.prune.planner { build_plan }
    import from jaclang.prune.spanedit { apply_edits }
    import from jaclang.prune.report { render_diff }

    start = time();
    do_apply = apply and not preview;
    mode = "apply" if do_apply else "preview";
    console.print_header(f"jac prune - fix ({mode})");
    console.info(f"project root: {campaign.project_root}");

    manifest = build_manifest(campaign);
    if not manifest.entries {
        console.warning("No .jac files found in scope.");
        return 0;
    }

    analysis = build_analysis(campaign, manifest);
    autofix = [
        c
        for c in analysis.candidates
        if c.disposition == Disposition.AUTO_FIX
    ];
    console.info(
        f"{len(analysis.candidates)} finding(s); {len(autofix)} auto-fix eligible"
    );
    if not autofix {
        console.success("Nothing to auto-fix. 🎉");
        return 0;
    }

    plan = build_plan(autofix);
    for reason in plan.skipped {
        console.warning(f"skipped: {reason}");
    }
    if plan.edit_count() == 0 {
        console.warning("No applicable edits after planning.");
        return 0;
    }
    console.info(
        f"planned {plan.edit_count()} edit(s) across {plan.file_count()} file(s)"
    );

    befores: dict = {};
    patched: dict = {};
    failed = 0;
    for (path, fe) in plan.files.items() {
        try {
            with open(path, "rb") as fh {
                before = fh.read();
            }
        } except Exception as e {
            console.error(f"cannot read {path}: {e}");
            failed += 1;
            continue;
        }
        result = apply_edits(before, fe.edits);
        if not result.ok {
            console.error(f"edit failed for {os.path.basename(path)}:");
            for err in result.errors {
                console.print(f"    {err}");
            }
            failed += 1;
            continue;
        }
        diff = render_diff(path, before, result.data, campaign.project_root);
        console.print("");
        console.print(diff or "(no textual change)");
        befores[path] = before;
        patched[path] = result.data;
    }

    if not do_apply {
        console.print("");
        console.info(
            f"preview only - {plan.edit_count()} edit(s) across "
            f"{plan.file_count()} file(s). Re-run with --apply to write."
        );
        _log_feedback(campaign, autofix, "previewed");
        console.print_elapsed_time(time() - start);
        return 1 if failed else 0;
    }

    (rc, fate) = _apply_validated(
        campaign, manifest, analysis, befores, patched, failed
    );
    _log_feedback(campaign, autofix, fate);
    console.print_elapsed_time(time() - start);
    return rc;
}


def _log_feedback(campaign: Campaign, candidates: list, outcome: str) {
    import from jaclang.prune.feedback { FeedbackLog, entry_from_candidate }
    if not candidates {
        return;
    }
    log = FeedbackLog(
        path=os.path.join(campaign.project_root, ".jac", "prune-feedback.jsonl")
    );
    log.record_all([entry_from_candidate(c, outcome) for c in candidates]);
}


def _apply_validated(
    campaign: Campaign,
    manifest: Manifest,
    analysis: Analysis,
    befores: dict,
    patched: dict,
    failed: int
) -> tuple[int, str] {
    import from jaclang.prune.validate {
        snapshot_baseline,
        validate_batch,
        bisect_culprit
    }

    touched = sorted(patched.keys());
    if not touched {
        console.warning("No applicable edits after planning.");
        return ((1 if failed else 0), "skipped");
    }

    source_paths = [e.path for e in manifest.by_role(FileRole.SOURCE)];
    console.print("");
    console.info("validating (baseline snapshot -> apply -> parse -> typecheck)…");
    baseline = snapshot_baseline(source_paths);

    for path in touched {
        _write(path, patched[path]);
    }
    res = validate_batch(touched, source_paths, baseline, run_format=False);

    if res.ok {
        n_tests = _affected_test_count(manifest, analysis, touched);
        console.success(
            f"validated + applied to {len(touched)} file(s): " + " -> ".join(
                [f"{s.stage}✓" for s in res.stages]
            )
        );
        if n_tests > 0 {
            console.info(
                f"{n_tests} affected test file(s) selected - run them "
                "(and your suite by risk policy) before committing."
            );
        }
        return ((1 if failed else 0), "applied");
    }

    for path in touched {
        _write(path, befores[path]);
    }
    console.error(
        f"validation failed at stage '{res.failed_stage()}' - batch reverted."
    );
    for key in res.new_diags[:8] {
        console.print(f"    new: {key}");
    }

    def validates(subset: list) -> bool {
        for p in subset {
            _write(p, patched[p]);
        }
        r = validate_batch(subset, source_paths, baseline, run_format=False);
        for p in subset {
            _write(p, befores[p]);
        }
        return r.ok;
    }

    culprits = bisect_culprit(touched, validates);
    if culprits {
        console.error("culprit file(s):");
        for c in culprits {
            console.print(f"    {os.path.relpath(c, campaign.project_root)}");
        }
    }
    return (1, "validation-failed");
}


def _affected_test_count(
    manifest: Manifest, analysis: Analysis, touched: list[str]
) -> int {
    import from jaclang.prune.validate { select_affected_tests_from_prog }
    test_paths = [e.path for e in manifest.by_role(FileRole.TEST)];
    return len(select_affected_tests_from_prog(analysis.prog, touched, test_paths));
}
