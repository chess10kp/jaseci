"""Tier-3 tests (phase 3.3): the duplicated-constant-blobs detector.

These tests drive the *real* detector through the real fact extractor. Because
`detect_duplicated_constant_blobs` only fires on a literal that repeats across
>= 2 distinct modules, and because `JacProgram.compile` in this test harness
never pulls an imported module into `prog.mod.hub` (so a single compile can only
ever see one module), the cross-module fixtures are compiled *separately* and
their `FactSet`s merged before syncing. That merge feeds genuine two-module
literal facts to the store without hand-building any fact objects - so the tests
stay correct even as the internal `LiteralFact` / `literals`-table field names
evolve.

Fixtures:
  * `blob_a.jac` / `blob_b.jac` - each returns the same long SQL string literal
    (double-quoted in a, single-quoted in b, so a value-based hash is required
    to pair them). `blob_a` also holds a large but unique literal and `blob_b` a
    below-floor one; neither may surface.

Public contract asserted (stable across the internal refactors in flight):
  * detector id "duplicated-constant-blobs", Finding.kind == "literal";
  * a literal repeated in one module only is NOT reported (single-copy bloat is
    invisible to this cross-module detector by design);
  * plan_meta carries site_count / module_count / literal_kind / size;
  * related cites the owning symbols ("sym:<id>");
  * the finding classifies report-only / moderate.
"""

import os;
import hashlib;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts, FactSet }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { build_veto_index }
import from jaclang.prune.detectors { detect_duplicated_constant_blobs, run_detectors }
import from jaclang.prune.finding { classify }
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _FIX = os.path.join(os.path.dirname(__file__), "fixtures");


def _extract_one(name: str) -> tuple[any, any] {
    path = os.path.join(_FIX, name);
    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=path,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = path;
    for k in prog.mod.hub.keys() {
        if k.endswith(name) {
            key = cast(LiteralString, k);
        }
    }
    with open(key, "rb") as f {
        h = hashlib.sha256(f.read()).hexdigest();
    }
    entry = ManifestEntry(
        path=key, role=FileRole.SOURCE, content_hash=h, module_name=name[:-4]
    );
    facts = extract_facts(
        prog, Manifest(project_root=os.path.dirname(key), entries=[entry])
    );
    return (facts, entry);
}


def _prep(names: list[str]) -> tuple[FactStore, any] {
    mods: list = [];
    syms: list = [];
    refs: list = [];
    imps: list = [];
    flds: list = [];
    brs: list = [];
    bods: list = [];
    lits: list = [];
    docs: list = [];
    entries: list = [];
    for n in names {
        (facts, entry) = _extract_one(n);
        mods.extend(facts.modules);
        syms.extend(facts.symbols);
        refs.extend(facts.refs);
        imps.extend(facts.imports);
        flds.extend(facts.field_accesses);
        brs.extend(facts.branches);
        bods.extend(facts.bodies);
        lits.extend(facts.literals);
        docs.extend(facts.docstrings);
        entries.append(entry);
    }
    merged = FactSet(
        modules=mods,
        symbols=syms,
        refs=refs,
        imports=imps,
        field_accesses=flds,
        branches=brs,
        bodies=bods,
        literals=lits,
        docstrings=docs
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(merged);
    veto = build_veto_index(Manifest(project_root=_FIX, entries=entries), "");
    return (store, veto);
}


def _findings(names: list[str]) -> list {
    (store, veto) = _prep(names);
    fs = detect_duplicated_constant_blobs(store, veto);
    store.close();
    return fs;
}


glob _PAIR = ["blob_a.jac", "blob_b.jac"];


test "a literal duplicated across two modules yields exactly one blob finding" {
    fs = _findings(_PAIR);
    assert len(fs) == 1 , [f.name for f in fs];
    f = fs[0];
    assert f.detector == "duplicated-constant-blobs";
    assert f.kind == "literal";
}


test "the blob finding reports its cross-module reach and kind" {
    f = _findings(_PAIR)[0];
    assert int(f.plan_meta["site_count"]) == 2 , f.plan_meta;
    assert int(f.plan_meta["module_count"]) == 2 , f.plan_meta;
    assert str(f.plan_meta["literal_kind"]) == "str" , f.plan_meta;
    assert int(f.plan_meta["size"]) >= 40 , f.plan_meta;
}


test "value-based hashing pairs the literal despite mixed quote styles" {
    # blob_a double-quotes the SQL, blob_b single-quotes it; a source-byte hash
    # would never pair them, so a two-site group proves value-based hashing.
    f = _findings(_PAIR)[0];
    assert int(f.plan_meta["site_count"]) == 2 , f.plan_meta;
}


test "the blob finding cites both owning symbols" {
    f = _findings(_PAIR)[0];
    assert len(f.related) == 2 , f.related;
    for r in f.related {
        assert str(r).startswith("sym:") , r;
    }
}


test "a duplicated blob is a report-only / moderate advisory" {
    f = _findings(_PAIR)[0];
    cand = classify(f, RiskTier.RISKY);
    assert cand.disposition == Disposition.REPORT_ONLY;
    assert cand.risk == RiskTier.MODERATE;
}


test "a literal that lives in only one module is not reported" {
    # blob_a alone repeats nothing across modules; single-copy bloat is out of
    # this detector's scope.
    fs = _findings(["blob_a.jac"]);
    assert len(fs) == 0 , [f.name for f in fs];
}


test "the detector is deterministic across a re-run" {
    a = sorted([f.name for f in _findings(_PAIR)]);
    b = sorted([f.name for f in _findings(_PAIR)]);
    assert a == b , (a, b);
}


test "run_detectors dispatches the duplicated-constant-blobs recipe" {
    (store, veto) = _prep(_PAIR);
    direct = detect_duplicated_constant_blobs(store, veto);
    viareg = run_detectors(store, veto, ["duplicated-constant-blobs"]);
    store.close();
    assert len(viareg) == len(direct) , (len(viareg), len(direct));
    assert len(viareg) == 1;
}
