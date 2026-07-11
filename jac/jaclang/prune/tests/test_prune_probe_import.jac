"""Probe-import veto test.

An unused import that sits inside a try/except importability guard (a "probe
import") must carry a `probe-import` VETOES Evidence row and be downgraded to
report-only; an ordinary unused import in the same module must not.
"""

import os;
import hashlib;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { build_veto_index }
import from jaclang.prune.detectors { detect_unused_imports }
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


def _findings_by_name(name: str) -> dict {
    (prog, man) = _compile_fixture(name);
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    veto = build_veto_index(man, "");
    findings = detect_unused_imports(store, veto);
    store.close();
    out: dict = {};
    for f in findings {
        out[f.name] = f;
    }
    return out;
}


test "probe-import inside a try/except guard is vetoed, plain unused import is not" {
    by_name = _findings_by_name("probeimportprog.jac");
    # The genuinely-unused normal import (top level) must be present.
    assert "sqrt" in by_name , list(by_name.keys());
    # The probe import inside the try/except ImportError guard must be present.
    assert "pi" in by_name , list(by_name.keys());

    probe = by_name["pi"];
    plain = by_name["sqrt"];

    # Probe import carries the veto; plain unused import does not.
    assert probe.has_veto() , probe.veto_kinds();
    assert "probe-import" in probe.veto_kinds() , probe.veto_kinds();
    assert not plain.has_veto() , plain.veto_kinds();

    # The veto downgrades the probe import to report-only; the plain one stays
    # an auto-fix.
    assert classify(probe, RiskTier.RISKY).disposition == Disposition.REPORT_ONLY;
    assert classify(plain, RiskTier.RISKY).disposition == Disposition.AUTO_FIX;
}
