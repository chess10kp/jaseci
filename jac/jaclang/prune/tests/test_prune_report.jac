"""Report serialization: `to_json` / `to_sarif` shape contracts.

Hand-built Candidates (no compile) covering a deletion detector and a hygiene
detector. Pins the keys the CLI emits so a dropped field or illegal SARIF
level cannot ship silently.
"""

import json;
import from jaclang.prune.finding { Finding, classify }
import from jaclang.prune.campaign { RiskTier }
import from jaclang.prune.report { to_json, to_sarif }


glob _SARIF_LEVELS = {"none", "note", "warning", "error"},
     _JSON_KEYS = [
         "fingerprint",
         "detector",
         "risk",
         "disposition",
         "module_path",
         "line"
     ];


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


def _sample_cands -> list {
    return [
        _cand("unused-imports", "del_a"),
        _cand("private-dead-defs", "del_b"),
        _cand("visibility-tightening", "hyg_a")
    ];
}


test "to_json: round-trips with one entry per candidate and required keys" {
    cands = _sample_cands();
    payload = json.loads(to_json(cands));
    assert isinstance(payload, list);
    assert len(payload) == len(cands);
    for entry in payload {
        for key in _JSON_KEYS {
            assert key in entry , (key, entry.keys());
            assert entry[key] != "" and entry[key] is not None , (key, entry);
        }
    }
}


test "to_sarif: version, tool, legal levels, ruleId, and uri locations" {
    cands = _sample_cands();
    payload = json.loads(to_sarif(cands, "pkg"));
    assert "version" in payload;
    assert payload["version"] != "";
    assert "runs" in payload and len(payload["runs"]) >= 1;
    run = payload["runs"][0];
    assert "tool" in run;
    results = run["results"];
    assert len(results) == len(cands);
    for res in results {
        assert res["level"] in _SARIF_LEVELS , res["level"];
        assert res.get("ruleId") , res;
        locs = res.get("locations", []);
        assert len(locs) >= 1 , res;
        uri = locs[0]["physicalLocation"]["artifactLocation"]["uri"];
        assert uri , locs[0];
    }
}
