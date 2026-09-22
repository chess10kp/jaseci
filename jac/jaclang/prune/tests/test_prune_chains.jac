"""if-chain-dispatch detector tests.

Covers the extractor on the chainprog fixture (seq-if runs, elif chains,
or/and boolean chains) and the detector's threshold/veto rules on synthetic
chain facts.
"""

import os;
import from jaclang.prune.campaign { Campaign, RiskTier, Disposition }
import from jaclang.prune.manifest { build_manifest }
import from jaclang.prune.pipeline { compile_scope }
import from jaclang.prune.extract { FactSet, ModuleFact, SymbolFact, extract_facts }
import from jaclang.prune.chains { ChainFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { VetoIndex }
import from jaclang.prune.detectors { detect_if_chain_dispatch }
import from jaclang.prune.finding { classify }


glob _MOD = "/pkg/chains.jac",
     _FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "chainprog.jac");


def _chain(
    shape: str,
    n_arms: int,
    selector: str = "op",
    n_total: int = 0,
    const_arms: int = 0,
    uniform: int = 1,
    ordered: int = 0,
    mixed: int = 0,
    owner: str = "dispatch",
    pos: int = 1
) -> ChainFact {
    return ChainFact(
        module_path=_MOD,
        owner_id="s1",
        owner_name=owner,
        shape=shape,
        n_arms=n_arms,
        n_total=n_total or n_arms,
        selector=selector,
        const_arms=const_arms or n_arms,
        uniform_returns=uniform,
        ordered_ops=ordered,
        mixed_selector=mixed,
        pos_start=pos,
        pos_end=pos + 40,
        line=pos
    );
}


def _store(chains: list) -> FactStore {
    facts = FactSet(
        modules=[
            ModuleFact(
                path=_MOD, module_name="pkg.chains", content_hash="a", role="source"
            )
        ],
        symbols=[
            SymbolFact(
                id="s1",
                module_path=_MOD,
                name="dispatch",
                kind="ability",
                access="public",
                imported=False,
                parent_id="",
                decl_pos_start=1,
                decl_pos_end=10,
                decl_line=1,
                scope_chain=""
            )
        ],
        chains=chains
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    return store;
}


def _fixture_store -> FactStore {
    campaign = Campaign(project_root=_FIXTURE, paths=[_FIXTURE]);
    manifest = build_manifest(campaign);
    (prog, _e, _w, _c) = compile_scope(campaign, manifest);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(extract_facts(prog, manifest));
    return store;
}


test "extractor finds seq-if, elif, and bool chains in the fixture" {
    store = _fixture_store();
    rows = store.if_chains();
    store.close();
    seq = [
        r
        for r in rows
        if r["shape"] == "seq-if"
    ];
    assert len(seq) == 1 , [dict(r) for r in rows];
    assert str(seq[0]["owner_name"]) == "seq_dispatch";
    assert int(seq[0]["n_arms"]) == 5;
    elifs = [
        r
        for r in rows
        if r["shape"] == "elif-chain"
    ];
    assert len(elifs) == 1 , [dict(r) for r in rows];
    ors = [
        r
        for r in rows
        if r["shape"] == "or-chain"
    ];
    assert len(ors) == 3 , [dict(r) for r in rows];
    ands = [
        r
        for r in rows
        if r["shape"] == "and-chain"
    ];
    assert len(ands) == 1 , [dict(r) for r in rows];
    assert int(ands[0]["n_arms"]) == 4;
}


test "extractor records veto signals on trap shapes" {
    store = _fixture_store();
    rows = store.if_chains();
    store.close();
    mixed = [
        r
        for r in rows
        if str(r["owner_name"]) == "mixed_selectors"
    ];
    assert len(mixed) == 1;
    assert bool(mixed[0]["mixed_selector"]);
    for r in rows {
        assert str(r["owner_name"]) not in {"ordered_guards", "side_effect_arms"} , dict(
            r
        );
    }
}


test "detector fires on clean dispatch chains" {
    store = _store(
        [
            _chain("seq-if", 5, pos=1),
            _chain("or-chain", 24, owner="has_target", pos=60),
            _chain("and-chain", 4, owner="negated", pos=120)
        ]
    );
    findings = detect_if_chain_dispatch(store, VetoIndex());
    store.close();
    assert len(findings) == 3 , [f.name for f in findings];
    shapes = {f.plan_meta["shape"] for f in findings};
    assert shapes == {"seq-if", "or-chain", "and-chain"};
    for f in findings {
        assert f.detector == "if-chain-dispatch";
        assert "op" in f.message;
    }
}


test "detector vetoes ordered, mixed, non-uniform, and short chains" {
    store = _store(
        [
            _chain("or-chain", 5, ordered=1, pos=1),
            _chain("or-chain", 5, mixed=1, pos=60),
            _chain("elif-chain", 6, uniform=0, pos=120),
            _chain("or-chain", 3, pos=180)
        ]
    );
    findings = detect_if_chain_dispatch(store, VetoIndex());
    store.close();
    assert len(findings) == 0 , [f.name for f in findings];
}


test "if-chain-dispatch is report-only under every risk ceiling" {
    store = _store([_chain("seq-if", 5)]);
    findings = detect_if_chain_dispatch(store, VetoIndex());
    store.close();
    assert len(findings) == 1;
    candidate = classify(findings[0], RiskTier.SAFE);
    assert candidate.disposition == Disposition.REPORT_ONLY;
    assert candidate.risk == RiskTier.MODERATE;
}
