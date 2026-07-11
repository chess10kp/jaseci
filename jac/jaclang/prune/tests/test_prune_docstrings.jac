"""Tier-3 tests (phase 3.4): the duplicate-docstrings / `sem`-string detector.

Duplicate exact-match docstrings or byLLM `sem` annotations on *different*
symbols are a high-precision "same concept, implemented twice" signal. These
tests drive the real detector through the real extractor (no hand-built fact
objects, so they survive the internal fact-schema refactors in flight).

Coverage is via `sem` strings (`semprog.jac`): the detector groups by
(text_hash, source) and requires >= 2 *distinct* symbol IDs, which `sem`
annotations on two different `def`s satisfy inside a single compiled module.

Why sem and not archetype/module docstrings: in the current compiler the leading
triple-quoted docstring on an `obj`/`def` is dropped by the parser (no `.doc`
survives), and a module has exactly one docstring whose owning symbol id is
empty - so two
module docstrings collapse to a single distinct id and never form a group.
`sem` targets carry real, distinct symbol ids, so they are the reliable
end-to-end path. The docstring-source behavior is otherwise identical machinery.

Public contract asserted:
  * detector id "duplicate-docstrings";
  * two symbols sharing a sem string group; a unique sem string does not;
  * plan_meta carries site_count / module_count / kinds / length / text_hash;
  * related cites the sharing symbols ("sym:<id>");
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
import from jaclang.prune.detectors { detect_duplicate_docstrings, run_detectors }
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
    fs = detect_duplicate_docstrings(store, veto);
    store.close();
    return fs;
}


test "identical sem strings on two defs group into one finding" {
    fs = _findings(["semprog.jac"]);
    assert len(fs) == 1 , [f.name for f in fs];
    f = fs[0];
    assert f.detector == "duplicate-docstrings";
}


test "the sem-duplicate finding reports its reach and source kind" {
    f = _findings(["semprog.jac"])[0];
    assert int(f.plan_meta["site_count"]) == 2 , f.plan_meta;
    assert int(f.plan_meta["module_count"]) == 1 , f.plan_meta;
    assert "sem" in cast(list, f.plan_meta["kinds"]) , f.plan_meta["kinds"];
    assert int(f.plan_meta["length"]) >= 16 , f.plan_meta;
}


test "the sem-duplicate finding cites both sharing symbols" {
    f = _findings(["semprog.jac"])[0];
    assert len(f.related) == 2 , f.related;
    for r in f.related {
        assert str(r).startswith("sym:") , r;
    }
}


test "a unique sem string is never grouped" {
    # semprog carries make_alpha/make_beta with identical sem text plus a
    # distinct make_gamma; only the pair may surface, so exactly one finding.
    fs = _findings(["semprog.jac"]);
    assert len(fs) == 1 , [f.name for f in fs];
}


test "a sem duplicate is a report-only / moderate advisory" {
    f = _findings(["semprog.jac"])[0];
    cand = classify(f, RiskTier.RISKY);
    assert cand.disposition == Disposition.REPORT_ONLY;
    assert cand.risk == RiskTier.MODERATE;
}


test "the detector is deterministic across a re-run" {
    a = sorted([f.name for f in _findings(["semprog.jac"])]);
    b = sorted([f.name for f in _findings(["semprog.jac"])]);
    assert a == b , (a, b);
}


test "run_detectors dispatches the duplicate-docstrings recipe" {
    (store, veto) = _prep(["semprog.jac"]);
    direct = detect_duplicate_docstrings(store, veto);
    viareg = run_detectors(store, veto, ["duplicate-docstrings"]);
    store.close();
    assert len(viareg) == len(direct) , (len(viareg), len(direct));
    assert len(viareg) == 1;
}
