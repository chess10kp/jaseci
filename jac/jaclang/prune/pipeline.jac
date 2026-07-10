import os;

import from jaclang.prune.campaign { Campaign }
import from jaclang.prune.manifest { Manifest, FileRole }
import from jaclang.prune.finding { Candidate, classify }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.agent { AgentModel }


obj Analysis {
    has candidates: list[Candidate],
        suppressed: int,
        manifest: Manifest,
        prog: any,
        errs: int,
        warns: int,
        compiled: int,
        store: (FactStore | None) = None,
        detector_input: int = 0,
        agent_ledger: int = 0;
}


def facts_db_path(campaign: Campaign) -> str {
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


def compile_source_paths(
    source_paths: list[str], on_error: any = None
) -> tuple[any, int, int, int] {
    import from jaclang.jac0core.program { JacProgram }
    import from jaclang.jac0core.compile_options { CompileOptions }
    import from jaclang.jac0core.bccache { discover_base_file }

    prog = JacProgram();
    prog._track_dependencies = True;
    compiled = 0;
    for file_path in source_paths {
        if file_path in prog.mod.hub {
            continue;
        }
        compile_path = file_path;
        try {
            base_path = discover_base_file(file_path);
            if base_path is not None {
                compile_path = base_path;
            }
            prog.compile(
                file_path=compile_path,
                options=CompileOptions(
                    type_check=True, no_cgen=True, force_target_program=True
                )
            );
            compiled += 1;
        } except Exception as e {
            if on_error {
                on_error(file_path, e);
            }
        }
    }
    return (prog, len(prog.errors_had), len(prog.warnings_had), compiled);
}


def compile_scope(
    campaign: Campaign, manifest: Manifest, on_error: any = None
) -> tuple[any, int, int, int] {
    paths = [e.path for e in manifest.by_role(FileRole.SOURCE)];
    return compile_source_paths(paths, on_error=on_error);
}


def build_analysis(
    campaign: Campaign,
    manifest: Manifest,
    *,
    agent: bool = False,
    judge: (AgentModel | None) = None,
    keep_store_open: bool = False
) -> Analysis {
    import from jaclang.prune.extract { extract_facts }
    import from jaclang.prune.veto { build_veto_index }
    import from jaclang.prune.detectors { run_detectors }
    import from jaclang.prune.suppress { filter_suppressed }
    import from jaclang.prune.factquery { ToolSurface }
    import from jaclang.prune.agent { AgentAnalyzer }

    (prog, errs, warns, compiled) = compile_scope(campaign, manifest);
    facts = extract_facts(prog, manifest);
    store: FactStore | None = FactStore(db_path=facts_db_path(campaign));
    store.open();
    store.sync(facts);
    veto = build_veto_index(manifest, campaign.project_root);
    det_findings = run_detectors(store, veto, campaign.recipes);
    (kept, suppressed) = filter_suppressed(det_findings, campaign);

    findings = kept;
    detector_input = len(kept);
    agent_ledger = 0;
    if agent {
        tools = ToolSurface(store=store);
        model = judge if judge is not None else AgentModel();
        analyzer = AgentAnalyzer(tools=tools, model=model);
        findings = analyzer.analyze(kept);
        agent_ledger = len(analyzer.ledger);
    }

    candidates = [classify(f, campaign.risk_ceiling) for f in findings];
    if not keep_store_open {
        store.close();
        store = None;
    }
    return Analysis(
        candidates=candidates,
        suppressed=len(suppressed),
        manifest=manifest,
        prog=prog,
        errs=errs,
        warns=warns,
        compiled=compiled,
        store=store,
        detector_input=detector_input,
        agent_ledger=agent_ledger
    );
}
