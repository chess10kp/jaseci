"""Real-source detector tests: drive the full CLI pipeline over genuinely
compiled Jac fixtures instead of hand-built `FactSet` objects.

Most detector unit tests inject `FactSet`s directly, which exercises detector
*logic* but never the fact-*extraction* layer (`extract.jac`) that turns real
code into those facts. The two precision bugs found in the first dogfood
campaign (side-effect imports, decl-signature type uses) were extraction-shaped:
they slipped past every FactSet test and only surfaced on a live run. These
tests close that gap by compiling real `.jac` source through `build_manifest` +
`build_analysis` -- the exact path `jac prune` runs -- and asserting on the
classified candidates.

Fixtures:
  sigtypeprog.jac + typesupply.jac -- import-extraction edges (annotation-only
      uses in every syntactic shape, plus truly-dead and genuinely-used imports).
  vislib.jac + viscon.jac         -- cross-module reference attribution for the
      visibility-tightening detector.
"""

import os;
import from jaclang.prune.campaign { Campaign, RiskTier, Disposition }
import from jaclang.prune.manifest { build_manifest }
import from jaclang.prune.pipeline { build_analysis }


glob _FIX = os.path.join(os.path.dirname(__file__), "fixtures");


def _paths(names: list[str]) -> list[str] {
    return [os.path.join(_FIX, n) for n in names];
}


"""Compile `names` through the real pipeline and return candidates indexed by
(detector, symbol name)."""
def _analyze(
    names: list[str], recipes: list[str], ceiling: RiskTier = RiskTier.RISKY
) -> dict {
    camp = Campaign(
        project_root=_FIX, paths=_paths(names), recipes=recipes, risk_ceiling=ceiling
    );
    analysis = build_analysis(camp, build_manifest(camp));
    out: dict = {};
    for c in analysis.candidates {
        out[(c.finding.detector, c.finding.name)] = c;
    }
    return out;
}


def _names_for(cands: dict, detector: str) -> set {
    return {
        k[1]
        for k in cands.keys()
        if k[0] == detector
    };
}


# ---------------------------------------------------------------------------
# Import extraction (dogfood Bug B): annotation-position uses must keep the
# import live. A regression that stops recording type-position references would
# flip these imports to auto-fix and silently delete a still-needed import.
# ---------------------------------------------------------------------------
test "real-source: a truly dead stdlib import is auto-fixable" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    key = ("unused-imports", "sqrt");
    assert key in cands , list(cands.keys());
    assert cands[key].disposition == Disposition.AUTO_FIX;
}


test "real-source: an imported-but-never-referenced symbol is auto-fixable" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    key = ("unused-imports", "Unused");
    assert key in cands , list(cands.keys());
    assert cands[key].disposition == Disposition.AUTO_FIX;
}


test "real-source: import used only in a parameter annotation is not flagged" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    assert ("unused-imports", "Payload") not in cands , list(cands.keys());
}


test "real-source: import used only in a return annotation is not flagged" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    assert ("unused-imports", "Retval") not in cands , list(cands.keys());
}


test "real-source: import used only inside list[T] is not flagged" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    assert ("unused-imports", "Elem") not in cands , list(cands.keys());
}


test "real-source: import used only in a T | None union is not flagged" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    assert ("unused-imports", "Optel") not in cands , list(cands.keys());
}


test "real-source: a called import (getpid) is never flagged" {
    cands = _analyze(["sigtypeprog.jac", "typesupply.jac"], ["unused-imports"]);
    assert ("unused-imports", "getpid") not in cands , list(cands.keys());
}


# ---------------------------------------------------------------------------
# Visibility tightening across two real modules.
# ---------------------------------------------------------------------------
test "real-source: a public symbol used only within its own module is flagged" {
    cands = _analyze(["vislib.jac", "viscon.jac"], ["visibility-tightening"]);
    flagged = _names_for(cands, "visibility-tightening");
    assert "only_local" in flagged , flagged;
    assert cands[("visibility-tightening", "only_local")].disposition == Disposition.REPORT_ONLY;
}


test "real-source: visibility findings never reach an auto-fix disposition" {
    cands = _analyze(["vislib.jac", "viscon.jac"], ["visibility-tightening"]);
    for (k, c) in cands.items() {
        if k[0] == "visibility-tightening" {
            assert c.disposition != Disposition.AUTO_FIX , k;
        }
    }
}


# Cross-module from-import attribution. `exported_used` IS called cross-module
# from viscon.jac, so demoting it from :pub would break that import. Real
# extraction records the use against viscon's local import *alias*, not the
# declaring symbol in vislib; the alias bridge (imports.source_module_path +
# item_name -> declaring symbol) re-attributes that use, so `exported_used` must
# NOT be flagged for tightening. This was a characterized extraction gap until
# the source_module_path bridge landed.
test "real-source: a cross-module from-import use is attributed to the declaring symbol" {
    cands = _analyze(["vislib.jac", "viscon.jac"], ["visibility-tightening"]);
    flagged = _names_for(cands, "visibility-tightening");
    assert "exported_used" not in flagged , flagged;
}
