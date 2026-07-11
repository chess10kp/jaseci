"""Packet-contract v2 §4: the `verdict` write-back — vocabulary, the mechanical
citation gate, the verdict ledger entry (with fate taxonomy), and
suppression-on-reject.

Pure over hand-built packets / temp files (no CLI, no compile): the gate is a
mechanical set-membership check against a packet's citations ∪ cite_index keys;
verdict entries round-trip through the JSONL ledger carrying citations + fate;
and a rejection appends its fingerprint to the suppression file.
"""

import os;
import from jaclang.prune.feedback {
    FeedbackLog,
    valid_decision,
    valid_fate,
    packet_citation_ids,
    citation_gate,
    verdict_entry
}
import from jaclang.prune.suppress { load_suppression_file, append_suppression_token }
import from jaclang.prune.finding { Finding }


glob _MOD = "/proj/a.jac";


def _packet(citations: list[str], cite_index_keys: list[str] | None = None) -> dict {
    idx: dict = {};
    keys = cite_index_keys if cite_index_keys is not None else citations;
    for k in keys {
        idx[k] = f"legend for {k}";
    }
    return {
        "fingerprint": "fp-abc",
        "detector": "private-dead-defs",
        "symbol_id": "s1",
        "name": "load_template",
        "module_path": _MOD,
        "risk": "moderate",
        "disposition": "pr-only",
        "source": "detector",
        "citations": citations,
        "cite_index": idx
    };
}


# ---------------------------------------------------------------------------
# 1. decision + fate vocabularies
# ---------------------------------------------------------------------------
test "verdict: decision vocabulary accepts the trichotomy, rejects noise" {
    for good in ["accept", "reject", "contested", "  Accept  ", "REJECT"] {
        assert valid_decision(good) , good;
    }
    for bad in ["", "approve", "yes", "landed"] {
        assert not valid_decision(bad) , bad;
    }
}


test "verdict: fate vocabulary is the Piranha taxonomy (empty allowed)" {
    for good in [
        "",
        "  ",
        "landed-unchanged",
        "landed-modified",
        "abandoned",
        "reverted",
        "  Reverted  "
    ] {
        assert valid_fate(good) , good;
    }
    for bad in ["landed", "applied", "kept", "merged"] {
        assert not valid_fate(bad) , bad;
    }
}


# ---------------------------------------------------------------------------
# 2. packet_citation_ids unions citations with cite_index keys
# ---------------------------------------------------------------------------
test "verdict: available citation set unions citations and cite_index keys" {
    pkt = _packet(["sym:s1", "ref:r1"], cite_index_keys=["sym:s1", "ref:r1", "mod:x"]);
    ids = packet_citation_ids(pkt);
    assert ids == {"sym:s1", "ref:r1", "mod:x"} , ids;
}


# ---------------------------------------------------------------------------
# 3. the mechanical citation gate
# ---------------------------------------------------------------------------
test "verdict: citation gate passes when every cite is in the packet" {
    pkt = _packet(["sym:s1", "body:s1", "ref:r1"]);
    assert citation_gate(["sym:s1", "ref:r1"], pkt) == [];
    assert citation_gate(["sym:s1", "body:s1", "ref:r1"], pkt) == [];
}


test "verdict: citation gate returns the out-of-packet IDs (hallucination check)" {
    pkt = _packet(["sym:s1", "ref:r1"]);
    missing = citation_gate(["sym:s1", "sym:ghost", "ref:phantom"], pkt);
    assert missing == ["sym:ghost", "ref:phantom"] , missing;
}


test "verdict: a cite that only appears in cite_index still passes the gate" {
    pkt = _packet([], cite_index_keys=["sym:s1"]);
    assert citation_gate(["sym:s1"], pkt) == [];
}


# ---------------------------------------------------------------------------
# 3b. every finding is groundable: packet_citations falls back to a self-cite
#     so detectors that publish no evidence IDs are still verdictable
# ---------------------------------------------------------------------------
def _finding(detector: str, sym: str, cites: list[str] | None = None) -> Finding {
    return Finding(
        detector=detector,
        symbol_id=sym,
        name="thing",
        module_path=_MOD,
        kind="ability",
        message="m",
        pos_start=0,
        pos_end=1,
        line=1,
        citations=cites if cites is not None else []
    );
}


test "verdict: a citation-less finding self-cites its own symbol" {
    f = _finding("private-dead-defs", "s1");
    assert f.packet_citations() == ["sym:s1"];
    # so a verdict citing that symbol clears the gate
    pkt = {"citations": f.packet_citations(), "cite_index": {}};
    assert citation_gate(["sym:s1"], pkt) == [];
}


test "verdict: detector-supplied citations win over the self-cite fallback" {
    f = _finding("single-caller-inline", "s1", cites=["sym:s1", "ref:r9"]);
    assert f.packet_citations() == ["sym:s1", "ref:r9"];
}


test "verdict: an anchorless finding has nothing to cite (gate stays closed)" {
    f = _finding("literal-dead-branch", "");
    assert f.packet_citations() == [];
}


# ---------------------------------------------------------------------------
# 4. verdict_entry carries decision, citations, note and fate
# ---------------------------------------------------------------------------
test "verdict: verdict_entry builds a verdict-<decision> ledger row" {
    meta = _packet(["sym:s1"]);
    e = verdict_entry(
        meta, "accept", ["sym:s1"], note="confirmed dead", fate="landed-unchanged"
    );
    assert e.outcome == "verdict-accept" , e.outcome;
    assert e.fingerprint == "fp-abc";
    assert e.detector == "private-dead-defs";
    assert e.citations == ["sym:s1"];
    assert e.reason == "confirmed dead";
    assert e.fate == "landed-unchanged";
    d = e.as_dict();
    assert d["outcome"] == "verdict-accept";
    assert d["citations"] == ["sym:s1"];
    assert d["fate"] == "landed-unchanged";
}


test "verdict: verdict_entry normalizes decision and fate casing" {
    meta = _packet(["sym:s1"]);
    e = verdict_entry(meta, "  Reject  ", ["sym:s1"], fate="  Reverted  ");
    assert e.outcome == "verdict-reject" , e.outcome;
    assert e.fate == "reverted" , e.fate;
}


# ---------------------------------------------------------------------------
# 5. verdict rows round-trip through the JSONL ledger
# ---------------------------------------------------------------------------
glob _LEDGER = os.path.join(os.path.dirname(__file__), "_verdict_scratch.jsonl");


test "verdict: verdict entries round-trip through the ledger with citations + fate" {
    if os.path.exists(_LEDGER) {
        os.remove(_LEDGER);
    }
    try {
        meta = _packet(["sym:s1", "ref:r1"]);
        log = FeedbackLog(path=_LEDGER);
        log.record_all(
            [
                verdict_entry(
                    meta,
                    "accept",
                    ["sym:s1", "ref:r1"],
                    note="dead",
                    fate="landed-modified"
                )
            ]
        );
        recs = log.read_all();
        assert len(recs) == 1 , len(recs);
        assert recs[0]["outcome"] == "verdict-accept";
        assert recs[0]["citations"] == ["sym:s1", "ref:r1"];
        assert recs[0]["fate"] == "landed-modified";
        assert log.outcome_counts()["verdict-accept"] == 1;
    } finally {
        if os.path.exists(_LEDGER) {
            os.remove(_LEDGER);
        }
    }
}


# ---------------------------------------------------------------------------
# 6. suppression-on-reject appends the fingerprint (idempotently)
# ---------------------------------------------------------------------------
glob _SUPPRESS = os.path.join(os.path.dirname(__file__), "_verdict_suppress.txt");


test "verdict: reject appends the fingerprint to the suppression file, once" {
    if os.path.exists(_SUPPRESS) {
        os.remove(_SUPPRESS);
    }
    try {
        assert append_suppression_token(_SUPPRESS, "fp-abc");
        # a second reject of the same fingerprint is a no-op, not a duplicate
        assert append_suppression_token(_SUPPRESS, "fp-abc");
        ss = load_suppression_file(_SUPPRESS);
        assert "fp-abc" in ss.tokens;
        with open(_SUPPRESS) as fh {
            lines = [
                ln
                for ln in fh.read().splitlines()
                if ln.strip()
            ];
        }
        assert len(lines) == 1 , lines;
    } finally {
        if os.path.exists(_SUPPRESS) {
            os.remove(_SUPPRESS);
        }
    }
}


test "verdict: an empty token is never written to the suppression file" {
    if os.path.exists(_SUPPRESS) {
        os.remove(_SUPPRESS);
    }
    try {
        assert not append_suppression_token(_SUPPRESS, "");
        assert not os.path.exists(_SUPPRESS);
    } finally {
        if os.path.exists(_SUPPRESS) {
            os.remove(_SUPPRESS);
        }
    }
}
