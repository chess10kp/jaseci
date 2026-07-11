"""Scope-coverage awareness: a subtree scoped without its consumers makes
cross-module detectors (visibility-tightening) read as mass-dead. These tests
pin the coverage computation, the per-finding `scope_partial` stamp, and the
report-level warning that lets a run say its cross-module numbers are partial.

A temp project of two real SOURCE modules is scoped to one file (partial) or to
the whole root (full), driving `scope_coverage` and the full pipeline. A temp
dir is used rather than the fixture dir because files under a `fixtures/` path
classify as non-live, which would zero out the project-live count.
"""

import os;
import tempfile;
import from jaclang.prune.campaign { Campaign, RiskTier }
import from jaclang.prune.manifest { build_manifest, scope_coverage }
import from jaclang.prune.pipeline { build_analysis }


def _write(dir: str, name: str, body: str) -> str {
    path = os.path.join(dir, name);
    with open(path, "w", encoding="utf-8") as f {
        f.write(body);
    }
    return path;
}


"""Create a temp project with two live modules and return
(root, modA_path, modB_path). modA declares public symbols with no cross-module
references; modB is an unrelated second live module."""
def _project -> tuple[str, str, str] {
    proj = tempfile.mkdtemp();
    a = _write(
        proj,
        "mod_a.jac",
        "def used_here -> int {\n    return only_here();\n}\n\n"
        "def only_here -> int {\n    return 2;\n}\n"
    );
    b = _write(proj, "mod_b.jac", "def b_entry -> int {\n    return 7;\n}\n");
    return (proj, a, b);
}


test "coverage: a subtree of the project is partial" {
    (proj, a, b) = _project();
    camp = Campaign(project_root=proj, paths=[a]);
    cov = scope_coverage(camp, build_manifest(camp));
    assert cov.is_partial();
    assert cov.in_scope_live == 1;
    assert cov.project_live == 2;
    assert cov.outside_count() == 1;
}


test "coverage: no explicit paths is full coverage, never partial" {
    (proj, a, b) = _project();
    camp = Campaign(project_root=proj, paths=[]);
    cov = scope_coverage(camp, build_manifest(camp));
    assert not cov.is_partial();
    assert cov.outside_count() == 0;
    assert cov.in_scope_live == cov.project_live;
    assert cov.project_live == 2;
}


# A partial-scope visibility-tightening run must stamp every cross-module finding
# and surface a one-line warning, so an agent (or human) never reads a
# subtree-scoped "no cross-module refs" as ground truth.
test "coverage: partial run stamps visibility findings and warns" {
    (proj, a, b) = _project();
    camp = Campaign(
        project_root=proj,
        paths=[a],
        recipes=["visibility-tightening"],
        risk_ceiling=RiskTier.RISKY
    );
    analysis = build_analysis(camp, build_manifest(camp));
    assert analysis.scope_partial();
    assert analysis.scope_partial_findings() > 0;
    assert "partial scope" in analysis.scope_warning();
    stamped = [
        c
        for c in analysis.candidates
        if bool(c.finding.plan_meta.get("scope_partial", False))
    ];
    assert len(stamped) == analysis.scope_partial_findings();
    for c in stamped {
        assert c.finding.detector == "visibility-tightening";
    }
}


# The warning is scoped to cross-module detectors: a per-module detector
# (unused-imports) produces no scope-sensitive findings, so no stamp and no
# warning even under a partial scope.
test "coverage: per-module detectors are not stamped and do not warn" {
    (proj, a, b) = _project();
    camp = Campaign(
        project_root=proj,
        paths=[a],
        recipes=["unused-imports"],
        risk_ceiling=RiskTier.RISKY
    );
    analysis = build_analysis(camp, build_manifest(camp));
    assert analysis.scope_partial();
    assert analysis.scope_partial_findings() == 0;
    assert analysis.scope_warning() == "";
    for c in analysis.candidates {
        assert not bool(c.finding.plan_meta.get("scope_partial", False));
    }
}
