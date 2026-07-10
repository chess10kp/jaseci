"""Tier-3 tests: the single-caller-inline advisory detector.

`inlineprog.jac` exercises the three cases: a small private method with exactly
one caller (flagged, report-only advisory), a small private method with two
callers (not flagged), and a single-caller private method with a body over the
statement floor (not flagged).
"""

import os;
import hashlib;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { build_veto_index }
import from jaclang.prune.detectors { detect_single_caller_inline }
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


def _findings(name: str) -> dict {
    (prog, man) = _compile_fixture(name);
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    veto = build_veto_index(man, "");
    fs = detect_single_caller_inline(store, veto);
    store.close();
    out: dict = {};
    for f in fs {
        out[f.name] = f;
    }
    return out;
}


test "single-caller-inline flags a small private method with exactly one caller" {
    fs = _findings("inlineprog.jac");
    assert "_only_once" in fs , list(fs.keys());
    f = fs["_only_once"];
    assert f.detector == "single-caller-inline";
    assert len(f.related) == 1;
    assert f.related[0].startswith("sym:");
    assert f.citations == ["sym:" + f.symbol_id];
    cand = classify(f, RiskTier.RISKY);
    assert cand.disposition == Disposition.REPORT_ONLY;
    assert cand.risk == RiskTier.MODERATE;
}


test "single-caller-inline ignores a method with two callers" {
    fs = _findings("inlineprog.jac");
    assert "_multi" not in fs , list(fs.keys());
}


test "single-caller-inline ignores a body over the statement floor" {
    fs = _findings("inlineprog.jac");
    assert "_big" not in fs , list(fs.keys());
}
