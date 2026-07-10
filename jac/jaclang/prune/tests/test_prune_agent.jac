"""Phase-3b tests: the fact-store tool surface, the deterministic redundancy
generators, the agent loop runner, and the two authority-containment invariants
(citation verification drops hallucinated cites; agent findings can never reach
auto-fix).

The generators + tool surface are exercised against hand-built in-memory fact
stores (no model, no compile) - that is the whole point of the surface being
pure. One end-to-end test compiles `agentprog.jac`, runs the real extraction,
and confirms the redundant-layer chain is found and cited. A replay test pins a
scripted golden run.
"""

import os;
import hashlib;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract {
    extract_facts,
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact
}
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { ToolSurface }
import from jaclang.prune.finding { Finding, classify }
import from jaclang.prune.campaign { RiskTier, Disposition }
import from jaclang.prune.agent {
    Hypothesis,
    Verdict,
    AgentModel,
    HeuristicModel,
    ReplayModel,
    AgentAnalyzer,
    gen_wrapper_chains,
    gen_parallel_impls,
    gen_finding_clusters
}


glob _FIX_DIR = os.path.join(os.path.dirname(__file__), "fixtures");


def _sym(sid: str, mod: str, name: str, kind: str) -> SymbolFact {
    return SymbolFact(
        id=sid,
        module_path=mod,
        name=name,
        kind=kind,
        access="pub",
        imported=False,
        parent_id="",
        decl_pos_start=0,
        decl_pos_end=1,
        decl_line=1,
        scope_chain=""
    );
}


def _call(using: str, used: str, mod: str) -> ReferenceFact {
    return ReferenceFact(
        used_id=used,
        using_id=using,
        module_path=mod,
        pos_start=0,
        pos_end=1,
        line=1,
        kind="call"
    );
}


def _hand_store(
    mods: list[str], syms: list[SymbolFact], refs: list[ReferenceFact]
) -> FactStore {
    facts = FactSet(
        modules=[
            ModuleFact(path=m, module_name=m, content_hash=m, role="source")
            for m in mods
        ],
        symbols=syms,
        refs=refs
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    return store;
}


test "tool surface returns call-graph neighborhoods" {
    store = _hand_store(
        ["/m.jac"],
        [_sym("A", "/m.jac", "a", "ability"), _sym("B", "/m.jac", "b", "ability")],
        [_call("A", "B", "/m.jac")]
    );
    tools = ToolSurface(store=store);
    va = tools.query_symbol("A");
    vb = tools.query_symbol("B");
    assert va is not None and vb is not None;
    assert va.callees == ["B"] , va.callees;
    assert vb.callers == ["A"] , vb.callers;
    assert vb.fan_in() == 1;
    assert va.fan_in() == 0;
    # unknown id -> None (not a crash)
    assert tools.query_symbol("ZZZ") is None;
    store.close();
}


test "wrapper-chain generator collapses a fan-in-1 forwarding chain" {
    # cli_main -> run_cmd -> dispatch -> real_work, each sole-forwarding.
    syms = [
        _sym("M", "/m.jac", "cli_main", "ability"),
        _sym("R", "/m.jac", "run_cmd", "ability"),
        _sym("D", "/m.jac", "dispatch", "ability"),
        _sym("W", "/m.jac", "real_work", "ability")
    ];
    refs = [
        _call("M", "R", "/m.jac"),
        _call("R", "D", "/m.jac"),
        _call("D", "W", "/m.jac")
    ];
    store = _hand_store(["/m.jac"], syms, refs);
    tools = ToolSurface(store=store);
    hyps = gen_wrapper_chains(tools);
    assert len(hyps) == 1 , [h.task for h in hyps];
    h = hyps[0];
    assert h.task == "redundant-layer" , h.task;
    assert h.anchor_id == "M";
    assert sorted(h.cited) == ["D", "M", "R", "W"] , h.cited;
    store.close();
}


test "wrapper-chain generator flags a lone single-use wrapper" {
    syms = [
        _sym("R", "/m.jac", "run_cmd", "ability"),
        _sym("W", "/m.jac", "real_work", "ability")
    ];
    store = _hand_store(["/m.jac"], syms, [_call("R", "W", "/m.jac")]);
    tools = ToolSurface(store=store);
    hyps = gen_wrapper_chains(tools);
    assert len(hyps) == 1;
    assert hyps[0].task == "single-use-wrapper" , hyps[0].task;
    store.close();
}


test "parallel-impl generator pairs same-name disjoint-caller symbols" {
    # find_path (module A) and find_path (module B): disjoint callers, shared
    # callee 'prim'. Callers ca/cb and prim are also symbols in the store.
    syms = [
        _sym("PA", "/a.jac", "find_path", "ability"),
        _sym("PB", "/b.jac", "find_path", "ability"),
        _sym("PRIM", "/c.jac", "prim", "ability"),
        _sym("CA", "/a.jac", "caller_a", "ability"),
        _sym("CB", "/b.jac", "caller_b", "ability")
    ];
    refs = [
        _call("CA", "PA", "/a.jac"),
        _call("CB", "PB", "/b.jac"),
        _call("PA", "PRIM", "/a.jac"),
        _call("PB", "PRIM", "/b.jac")
    ];
    store = _hand_store(["/a.jac", "/b.jac", "/c.jac"], syms, refs);
    tools = ToolSurface(store=store);
    hyps = gen_parallel_impls(tools);
    assert len(hyps) == 1 , len(hyps);
    h = hyps[0];
    assert h.task == "parallel-impl";
    assert int(h.bundle["shared_callees"]) == 1;
    assert "PA" in h.cited and "PB" in h.cited and "PRIM" in h.cited;
    store.close();
}


def _finding(sid: str, mod: str, name: str) -> Finding {
    return Finding(
        detector="private-dead-defs",
        symbol_id=sid,
        name=name,
        module_path=mod,
        kind="ability",
        message="dead",
        pos_start=0,
        pos_end=1,
        line=1
    );
}


test "finding-cluster generator groups co-located detector findings" {
    syms = [
        _sym("S1", "/m.jac", "h1", "ability"),
        _sym("S2", "/m.jac", "h2", "ability"),
        _sym("S3", "/m.jac", "h3", "ability")
    ];
    store = _hand_store(["/m.jac"], syms, []);
    tools = ToolSurface(store=store);
    findings = [
        _finding("S1", "/m.jac", "h1"),
        _finding("S2", "/m.jac", "h2"),
        _finding("S3", "/m.jac", "h3")
    ];
    hyps = gen_finding_clusters(tools, findings);
    assert len(hyps) == 1;
    assert hyps[0].task == "finding-cluster";
    assert int(hyps[0].bundle["member_count"]) == 3;
    # below threshold -> no cluster
    assert len(gen_finding_clusters(tools, findings[:2])) == 0;
    store.close();
}


test "citation verification drops a finding with an unresolvable fact ID" {
    store = _hand_store(["/m.jac"], [_sym("A", "/m.jac", "a", "ability")], []);
    tools = ToolSurface(store=store);
    analyzer = AgentAnalyzer(tools=tools, model=HeuristicModel());
    good = Hypothesis(
        task="single-use-wrapper", summary="s", anchor_id="A", cited=["A"], bundle={}
    );
    bad = Hypothesis(
        task="single-use-wrapper",
        summary="s",
        anchor_id="A",
        cited=["A", "deadbeefdeadbeef"],
        bundle={}
    );
    confirm = Verdict(decision="confirm", rationale="r", citations=[]);
    assert analyzer._to_finding(good, confirm) is not None;
    assert analyzer._to_finding(bad, confirm) is None;
    store.close();
}


test "agent findings can never reach auto-fix" {
    store = _hand_store(["/m.jac"], [_sym("A", "/m.jac", "a", "ability")], []);
    tools = ToolSurface(store=store);
    analyzer = AgentAnalyzer(tools=tools, model=HeuristicModel());
    hyp = Hypothesis(
        task="single-use-wrapper", summary="s", anchor_id="A", cited=["A"], bundle={}
    );
    f = analyzer._to_finding(hyp, Verdict(decision="confirm", citations=["A"]));
    assert f is not None;
    assert f.source == "agent";
    # even at the most permissive ceiling, source=agent caps below auto-fix
    c = classify(f, RiskTier.FORBIDDEN);
    assert c.disposition == Disposition.PR_ONLY , c.disposition;
}


test "default (no) model abstains -> zero agent findings" {
    syms = [
        _sym("R", "/m.jac", "run_cmd", "ability"),
        _sym("W", "/m.jac", "real_work", "ability")
    ];
    store = _hand_store(["/m.jac"], syms, [_call("R", "W", "/m.jac")]);
    tools = ToolSurface(store=store);
    analyzer = AgentAnalyzer(tools=tools, model=AgentModel());
    out = analyzer.analyze([]);
    assert out == [] , len(out);
    # ...but a hypothesis was still generated and judged (ledger records it)
    assert len(analyzer.ledger) == 1;
    assert analyzer.ledger[0]["decision"] == "abstain";
    store.close();
}


test "replayed golden run confirms exactly the scripted hypothesis" {
    syms = [
        _sym("R", "/m.jac", "run_cmd", "ability"),
        _sym("W", "/m.jac", "real_work", "ability")
    ];
    store = _hand_store(["/m.jac"], syms, [_call("R", "W", "/m.jac")]);
    tools = ToolSurface(store=store);
    hyps = gen_wrapper_chains(tools);
    assert len(hyps) == 1;
    key = hyps[0].key();
    scripted = {key: Verdict(decision="confirm", rationale="r", citations=["R", "W"])};
    analyzer = AgentAnalyzer(tools=tools, model=ReplayModel(scripted=scripted));
    out = analyzer.analyze([]);
    assert len(out) == 1;
    assert out[0].detector == "agent-single-use-wrapper";
    assert out[0].source == "agent";
    assert sorted(out[0].citations) == ["R", "W"];
    store.close();
}


def _compile_fixture(name: str) -> tuple[any, Manifest] {
    path = os.path.join(_FIX_DIR, name);
    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=path,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = path;
    for k in prog.mod.hub.keys() {
        if k.endswith(name) {
            key = k;
        }
    }
    with open(key, "rb") as f {
        h = hashlib.sha256(f.read()).hexdigest();
    }
    modname = name[:-len(".jac")] if name.endswith(".jac") else name;
    man = Manifest(
        project_root=os.path.dirname(key),
        entries=[
            ManifestEntry(
                path=key, role=FileRole.SOURCE, content_hash=h, module_name=modname
            )
        ]
    );
    return (prog, man);
}


test "end-to-end: real extraction finds the wrapper chain in agentprog.jac" {
    (prog, man) = _compile_fixture("agentprog.jac");
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    tools = ToolSurface(store=store);
    analyzer = AgentAnalyzer(tools=tools, model=HeuristicModel());
    out = analyzer.analyze([]);
    store.close();
    chains = [
        f
        for f in out
        if f.detector == "agent-redundant-layer"
    ];
    assert len(chains) == 1 , [f.detector for f in out];
    f = chains[0];
    assert f.name == "cli_main" , f.name;
    assert len(f.citations) == 4 , f.citations;
    assert f.source == "agent";
}
