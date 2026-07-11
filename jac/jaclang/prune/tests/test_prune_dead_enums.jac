"""Tests for the dead-enum-variants detector (Tier-3 pull-forward 1a).

`enumprog.jac` declares an enum whose `ORPHAN` variant is never constructed,
read, or matched, while `RED`/`GREEN`/`BLUE` are all live. The detector is a
query-only mirror of `private-dead-defs` over `kind = 'enum_member'`; it needs
no schema change.
"""

import os;
import hashlib;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { build_veto_index }
import from jaclang.prune.detectors { run_detectors }
import from jaclang.prune.finding { classify }
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _FIX_DIR = os.path.join(os.path.dirname(__file__), "fixtures");


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


def _analyze(name: str) -> dict {
    (prog, man) = _compile_fixture(name);
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    veto = build_veto_index(man, "");
    findings = run_detectors(store, veto, ["dead-enum-variants"]);
    store.close();
    out: dict = {};
    for f in findings {
        out[f.name] = classify(f, RiskTier.RISKY);
    }
    return out;
}


test "dead-enum-variants flags only the unreferenced variant" {
    cands = _analyze("enumprog.jac");
    assert "ORPHAN" in cands , list(cands.keys());
    # Live variants are constructed and/or matched, so must not be flagged.
    assert "RED" not in cands , list(cands.keys());
    assert "GREEN" not in cands , list(cands.keys());
    assert "BLUE" not in cands , list(cands.keys());
}


test "dead enum variant is pr-only, never auto-fix" {
    cands = _analyze("enumprog.jac");
    cand = cands["ORPHAN"];
    assert cand.finding.detector == "dead-enum-variants";
    assert cand.finding.kind == "enum_member";
    assert cand.disposition == Disposition.PR_ONLY;
    assert cand.risk == RiskTier.MODERATE;
}
