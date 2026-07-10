"""Phase-6 tests: the feedback ledger (record every finding's fate, read it back,
count outcomes). Pure JSONL round-trip - no CLI, no compile.
"""

import os;
import from jaclang.prune.feedback { FeedbackEntry, FeedbackLog, entry_from_candidate }
import from jaclang.prune.finding { Finding, classify }
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _TMP = os.path.join(os.path.dirname(__file__), "_feedback_scratch.jsonl");


def _clean {
    if os.path.exists(_TMP) {
        os.remove(_TMP);
    }
}


test "ledger appends fates and reads them back, counting outcomes" {
    _clean();
    try {
        log = FeedbackLog(path=_TMP);
        log.record_all(
            [
                FeedbackEntry(
                    fingerprint="fp1",
                    detector="unused-imports",
                    symbol_id="a",
                    name="x",
                    module_path="/m.jac",
                    risk="1",
                    disposition="1",
                    source="detector",
                    outcome="applied"
                ),
                FeedbackEntry(
                    fingerprint="fp2",
                    detector="private-dead-defs",
                    symbol_id="b",
                    name="y",
                    module_path="/m.jac",
                    risk="1",
                    disposition="1",
                    source="detector",
                    outcome="applied"
                )
            ]
        );
        # a second run appends (does not truncate)
        log.record_all(
            [
                FeedbackEntry(
                    fingerprint="fp3",
                    detector="unused-imports",
                    symbol_id="c",
                    name="z",
                    module_path="/n.jac",
                    risk="1",
                    disposition="3",
                    source="detector",
                    outcome="validation-failed"
                )
            ]
        );
        recs = log.read_all();
        assert len(recs) == 3 , len(recs);
        assert recs[0]["fingerprint"] == "fp1";
        counts = log.outcome_counts();
        assert counts["applied"] == 2 , counts;
        assert counts["validation-failed"] == 1 , counts;
    } finally {
        _clean();
    }
}


test "entry_from_candidate captures fingerprint, source and fate" {
    f = Finding(
        detector="unused-imports",
        symbol_id="sid",
        name="foo",
        module_path="/m.jac",
        kind="import",
        message="m",
        pos_start=0,
        pos_end=1,
        line=1
    );
    c = classify(f, RiskTier.SAFE);
    e = entry_from_candidate(c, "applied");
    assert e.fingerprint == f.fingerprint();
    assert e.outcome == "applied";
    assert e.source == "detector";
    assert e.disposition == str(Disposition.AUTO_FIX.value);
    d = e.as_dict();
    assert d["detector"] == "unused-imports";
    assert d["name"] == "foo";
}


test "reading a missing ledger returns empty, not an error" {
    _clean();
    log = FeedbackLog(path=_TMP);
    assert log.read_all() == [];
    assert log.outcome_counts() == {};
}
