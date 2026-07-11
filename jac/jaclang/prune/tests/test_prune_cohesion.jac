"""Tier-4 (pulled forward) tests: the module-cohesion advisory detector.

Hand-built fact sets exercise the two LCOM-style shapes precisely:
a module whose internal symbols form >=2 disconnected clusters is a split
candidate; two modules coupled to each other more than to themselves are a
merge candidate. Both are report-only seam-review advisories.
"""

import from jaclang.prune.extract { FactSet, ModuleFact, SymbolFact, ReferenceFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { ToolSurface }
import from jaclang.prune.veto { VetoIndex }
import from jaclang.prune.detectors { detect_module_cohesion }
import from jaclang.prune.finding { Finding, classify }
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _MOD_A = "/pkg/a.jac",
     _MOD_X = "/pkg/x.jac",
     _MOD_Y = "/pkg/y.jac";


def _sym(id: str, mod: str, name: str) -> SymbolFact {
    return SymbolFact(
        id=id,
        module_path=mod,
        name=name,
        kind="ability",
        access="public",
        imported=False,
        parent_id="",
        decl_pos_start=0,
        decl_pos_end=10,
        decl_line=1,
        scope_chain=""
    );
}


def _ref(using: str, used: str, mod: str) -> ReferenceFact {
    return ReferenceFact(
        used_id=used,
        using_id=using,
        module_path=mod,
        pos_start=100,
        pos_end=110,
        line=5,
        kind="call"
    );
}


def _store -> FactStore {
    # module A: two disconnected clusters {a1,a2} and {b1,b2} -> split.
    # modules X/Y: 1 intra edge each but 3 cross edges -> merge.
    facts = FactSet(
        modules=[
            ModuleFact(
                path=_MOD_A, module_name="pkg.a", content_hash="a", role="source"
            ),
            ModuleFact(
                path=_MOD_X, module_name="pkg.x", content_hash="x", role="source"
            ),
            ModuleFact(
                path=_MOD_Y, module_name="pkg.y", content_hash="y", role="source"
            )
        ],
        symbols=[
            _sym("a1", _MOD_A, "a1"),
            _sym("a2", _MOD_A, "a2"),
            _sym("b1", _MOD_A, "b1"),
            _sym("b2", _MOD_A, "b2"),
            _sym("x1", _MOD_X, "x1"),
            _sym("x2", _MOD_X, "x2"),
            _sym("y1", _MOD_Y, "y1"),
            _sym("y2", _MOD_Y, "y2")
        ],
        refs=[
            _ref("a1", "a2", _MOD_A),
            _ref("b1", "b2", _MOD_A),
            _ref("x1", "x2", _MOD_X),
            _ref("y1", "y2", _MOD_Y),
            _ref("x1", "y1", _MOD_X),
            _ref("x1", "y2", _MOD_X),
            _ref("x2", "y1", _MOD_X)
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    return store;
}


def _findings -> dict {
    store = _store();
    fs = detect_module_cohesion(store, VetoIndex());
    store.close();
    out: dict = {};
    for f in fs {
        out[f.name] = f;
    }
    return out;
}


test "store: symbol_ref_edges resolves both endpoints, drops unresolved/self" {
    store = _store();
    edges = store.symbol_ref_edges();
    store.close();
    assert len(edges) == 7 , len(edges);
    intra = [
        e
        for e in edges
        if str(e["using_mod"]) == str(e["used_mod"])
    ];
    cross = [
        e
        for e in edges
        if str(e["using_mod"]) != str(e["used_mod"])
    ];
    assert len(intra) == 4 , len(intra);
    assert len(cross) == 3 , len(cross);
}


test "split: a module with two disconnected clusters is flagged" {
    fs = _findings();
    key = "split:" + _MOD_A;
    assert key in fs , list(fs.keys());
    f = fs[key];
    assert f.detector == "module-cohesion";
    assert f.kind == "module";
    assert str(f.plan_meta["shape"]) == "split";
    assert int(f.plan_meta["cluster_count"]) == 2;
    assert list(f.plan_meta["cluster_sizes"]) == [2, 2];
}


test "merge: two modules coupled more than internally are flagged" {
    fs = _findings();
    key = "merge:" + _MOD_X + "|" + _MOD_Y;
    assert key in fs , list(fs.keys());
    f = fs[key];
    assert str(f.plan_meta["shape"]) == "merge";
    assert int(f.plan_meta["cross_edges"]) == 3;
    assert int(f.plan_meta["intra_a"]) == 1;
    assert int(f.plan_meta["intra_b"]) == 1;
    assert f.related == ["mod:" + _MOD_X, "mod:" + _MOD_Y];
}


test "cohesion findings classify as moderate/report-only advisories" {
    fs = _findings();
    for f in fs.values() {
        cand = classify(f, RiskTier.FORBIDDEN);
        assert cand.disposition == Disposition.REPORT_ONLY , f.name;
        assert cand.risk == RiskTier.MODERATE , f.name;
    }
}


test "both citation shapes (sym: split, mod: merge) verify through the tool surface" {
    store = _store();
    tools = ToolSurface(store=store);
    findings = detect_module_cohesion(store, VetoIndex());
    out: dict = {};
    for f in findings {
        out[f.name] = f;
    }
    # split cites one representative symbol per cluster
    split = out["split:" + _MOD_A];
    assert tools.verify_citations(split.related) , split.related;
    # merge cites the two modules; the mod: form must be recognized, not
    # mistaken for a symbol id (regression guard for the missing mod: branch)
    merge = out["merge:" + _MOD_X + "|" + _MOD_Y];
    assert tools.verify_citations(merge.related) , merge.related;
    # a module that is not in the store must not verify
    assert not tools.verify_citations(["mod:/pkg/does-not-exist.jac"]);
    store.close();
}


test "no split when a module is a single connected cluster" {
    # X and Y are each a single 2-node cluster internally -> no split findings.
    fs = _findings();
    assert "split:" + _MOD_X not in fs , list(fs.keys());
    assert "split:" + _MOD_Y not in fs , list(fs.keys());
}


test "no merge when cross-coupling does not exceed internal cohesion" {
    # Rebuild with only one cross edge (< intra of both) -> no merge candidate.
    facts = FactSet(
        modules=[
            ModuleFact(
                path=_MOD_X, module_name="pkg.x", content_hash="x", role="source"
            ),
            ModuleFact(
                path=_MOD_Y, module_name="pkg.y", content_hash="y", role="source"
            )
        ],
        symbols=[
            _sym("x1", _MOD_X, "x1"),
            _sym("x2", _MOD_X, "x2"),
            _sym("y1", _MOD_Y, "y1"),
            _sym("y2", _MOD_Y, "y2")
        ],
        refs=[
            _ref("x1", "x2", _MOD_X),
            _ref("y1", "y2", _MOD_Y),
            _ref("x1", "y1", _MOD_X)
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    fs = detect_module_cohesion(store, VetoIndex());
    store.close();
    for f in fs {
        assert str(f.plan_meta["shape"]) != "merge" , f.name;
    }
}


def _cohesion_finding(name: str, module_path: str) -> Finding {
    return Finding(
        detector="module-cohesion",
        symbol_id="",
        name=name,
        module_path=module_path,
        kind="module",
        message="advisory",
        pos_start=0,
        pos_end=0,
        line=0
    );
}


test "module-cohesion fingerprints do not collide across split and merge" {
    split_f = _cohesion_finding("split:a.jac", "a.jac");
    merge_ab = _cohesion_finding("merge:a.jac|b.jac", "a.jac");
    merge_ac = _cohesion_finding("merge:a.jac|c.jac", "a.jac");
    assert split_f.fingerprint() != merge_ab.fingerprint();
    assert merge_ab.fingerprint() != merge_ac.fingerprint();
}


test "symbol-anchored fingerprint is unchanged by name in the empty-id fallback" {
    f = Finding(
        detector="unused-imports",
        symbol_id="sym:abc",
        name="Foo",
        module_path="/pkg/m.jac",
        kind="import",
        message="unused",
        pos_start=0,
        pos_end=5,
        line=1
    );
    assert f.fingerprint() == "6f59c04f6dc47e0b";
}
