"""Packet-contract v2 §1.2: detector-authored `verify` questions.

Pure over hand-built Findings (no compilation): every finding class emits
well-formed, executable verification questions; `Candidate.as_dict` surfaces
them; and the reuse helper adds the fuzzy-only contiguity check for fuzzy tiers.
"""

import from jaclang.prune.finding {
    Finding,
    Candidate,
    classify,
    verify_questions,
    reuse_verify_questions
}
import from jaclang.prune.campaign { RiskTier, Disposition }


glob _DETECTORS = [
         "unused-imports",
         "private-dead-defs",
         "dead-enum-variants",
         "write-only-fields",
         "literal-dead-branch",
         "single-caller-inline",
         "visibility-tightening",
         "duplicated-constant-blobs",
         "duplicate-docstrings",
         "module-cohesion",
         "agent-redundant-layer"
     ];


def _finding(detector: str, name: str = "load_template") -> Finding {
    return Finding(
        detector=detector,
        symbol_id="deadbeef",
        name=name,
        module_path="pkg/mod.jac",
        kind="ability",
        message="test finding",
        pos_start=10,
        pos_end=20,
        line=3
    );
}


def _well_formed(qs: list[dict]) -> bool {
    if not qs {
        return False;
    }
    for q in qs {
        for key in ["q", "how", "expect"] {
            if key not in q {
                return False;
            }
            if not isinstance(q[key], str) or not q[key] {
                return False;
            }
        }
    }
    return True;
}


test "verify: every detector class emits well-formed questions" {
    for det in _DETECTORS {
        qs = verify_questions(_finding(det));
        assert _well_formed(qs) , det;
    }
}


test "verify: an unknown detector still gets a default question" {
    qs = verify_questions(_finding("some-future-detector"));
    assert _well_formed(qs);
    assert len(qs) == 1;
}


test "verify: the finding name is interpolated into the grep hint" {
    qs = verify_questions(_finding("unused-imports", name="my_helper"));
    joined = " ".join([q["how"] for q in qs] + [q["q"] for q in qs]);
    assert "my_helper" in joined;
}


test "verify: Candidate.as_dict surfaces the verify block" {
    cand = classify(_finding("unused-imports"), RiskTier.RISKY);
    d = cand.as_dict();
    assert "verify" in d;
    assert _well_formed(d["verify"]);
}


test "verify: reuse questions are well-formed for a structural tier" {
    qs = reuse_verify_questions("structural");
    assert _well_formed(qs);
    assert len(qs) == 4;
}


test "verify: a fuzzy tier adds the contiguity (LCS) question" {
    base = reuse_verify_questions("structural");
    fuzzy = reuse_verify_questions("fuzzy");
    assert len(fuzzy) == len(base) + 1;
    joined = " ".join([q["q"] for q in fuzzy] + [q["how"] for q in fuzzy]);
    assert "contiguous" in joined or "struct_tokens" in joined;
}
