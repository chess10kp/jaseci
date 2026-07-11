"""Packet-contract v2 §5: `list` ranking + `show` drill-in helpers.

Pure over hand-built Candidates (no compilation): the ranked index orders by
disposition then confidence, caps at a limit while counting the suppressed
tail, and the JSON index round-trips with stable per-row fields.
"""

import json;
import from jaclang.prune.finding { Finding, Evidence, Polarity, classify }
import from jaclang.prune.campaign { RiskTier }
import from jaclang.prune.report {
    confidence_of,
    ranked_candidates,
    list_rows,
    list_json,
    summarize_categories
}
import from jaclang.prune.finding { finding_category }


def _finding(detector: str, sym: str, name: str = "thing") -> Finding {
    return Finding(
        detector=detector,
        symbol_id=sym,
        name=name,
        module_path="pkg/mod.jac",
        kind="ability",
        message=f"{detector} finding",
        pos_start=10,
        pos_end=20,
        line=3
    );
}


def _cand(detector: str, sym: str) -> any {
    return classify(_finding(detector, sym), RiskTier.SAFE);
}


test "list: confidence ranks auto-fix above report-only above vetoed" {
    autofix = _cand("unused-imports", "a");
    advisory = _cand("single-caller-inline", "b");
    assert confidence_of(autofix) > confidence_of(advisory);

    vetoed_f = _finding("unused-imports", "c");
    vetoed_f.add(Evidence(kind="probe-import", polarity=Polarity.VETOES, detail="x"));
    vetoed = classify(vetoed_f, RiskTier.SAFE);
    assert confidence_of(vetoed) < confidence_of(advisory);
}


def _vis(name: str, partial: bool) -> any {
    f = _finding("visibility-tightening", "s_" + name, name);
    if partial {
        f.plan_meta["scope_partial"] = True;
    }
    return classify(f, RiskTier.RISKY);
}


# Calibration (dogfood step 6): an `_`-prefixed public symbol is internal by
# naming convention -> high confidence its demote is right; a non-underscore
# public symbol under a partial scope may be exported API used out of scope ->
# lowest confidence. Ordering must reflect that.
test "confidence: visibility calibration ranks internal-named above public" {
    internal_full = _vis("_helper", False);
    public_full = _vis("PublicApi", False);
    public_partial = _vis("PublicApi", True);
    internal_partial = _vis("_helper", True);
    # internal naming boosts; partial scope on a public name is the biggest hit
    assert confidence_of(internal_full) > confidence_of(public_full);
    assert confidence_of(public_full) > confidence_of(public_partial);
    assert confidence_of(public_partial) < 0.5;
    # an internal-named symbol stays confident even under partial scope
    assert confidence_of(internal_partial) > confidence_of(public_full);
}


test "confidence: a veto still floors visibility confidence below advisory" {
    vetoed_f = _finding("visibility-tightening", "s_v", "PublicApi");
    vetoed_f.plan_meta["scope_partial"] = True;
    vetoed_f.add(
        Evidence(kind="method-dispatched", polarity=Polarity.VETOES, detail="x")
    );
    vetoed = classify(vetoed_f, RiskTier.RISKY);
    assert confidence_of(vetoed) == 0.2;
}


test "list: ranked order puts the auto-fix candidate first" {
    cands = [_cand("single-caller-inline", "b"), _cand("unused-imports", "a")];
    ordered = ranked_candidates(cands);
    assert ordered[0].finding.detector == "unused-imports";
}


test "list: limit caps rows and reports the suppressed tail" {
    cands = [_cand("single-caller-inline", str(i)) for i in range(5)];
    (rows, suppressed) = list_rows(cands, "pkg", 2);
    assert len(rows) == 2;
    assert suppressed == 3;
    for row in rows {
        assert len(row) == 5;
        assert len(row[0]) == 16;
    }
}


test "list: a limit at or above the count suppresses nothing" {
    cands = [_cand("single-caller-inline", str(i)) for i in range(3)];
    (rows, suppressed) = list_rows(cands, "pkg", 200);
    assert len(rows) == 3;
    assert suppressed == 0;
}


test "category: hygiene detectors don't reduce LOC, deletion detectors do" {
    assert finding_category("visibility-tightening") == "hygiene";
    assert finding_category("module-cohesion") == "hygiene";
    for det in [
        "unused-imports",
        "private-dead-defs",
        "dead-enum-variants",
        "write-only-fields",
        "single-caller-inline",
        "duplicated-constant-blobs"
    ] {
        assert finding_category(det) == "deletion" , det;
    }
}


test "category: as_dict carries the finding category" {
    c = _cand("visibility-tightening", "v");
    assert c.as_dict()["category"] == "hygiene";
    assert _cand("unused-imports", "u").as_dict()["category"] == "deletion";
}


test "category: summary splits deletion-bearing from hygiene/advisory" {
    cands = [
        _cand("unused-imports", "a"),
        _cand("dead-enum-variants", "b"),
        _cand("visibility-tightening", "c"),
        _cand("module-cohesion", "d"),
        _cand("visibility-tightening", "e")
    ];
    cats = summarize_categories(cands);
    assert cats["deletion"] == 2 , cats;
    assert cats["hygiene"] == 3 , cats;
}


test "list: JSON index round-trips with shown/total/suppressed and row fields" {
    cands = [_cand("single-caller-inline", str(i)) for i in range(4)];
    payload = json.loads(list_json(cands, "pkg", 2));
    assert payload["total"] == 4;
    assert payload["shown"] == 2;
    assert payload["suppressed"] == 2;
    assert len(payload["findings"]) == 2;
    row = payload["findings"][0];
    for key in ["fingerprint", "detector", "disposition", "confidence", "location"] {
        assert key in row;
    }
}
