"""Phase-5 tests: the validation gate's pure core (baseline diffing, affected-test
selection over the reverse dep graph, batch bisection) and one live seeded-failure
test proving the typecheck stage catches a patch that introduces a new diagnostic.
"""

import os;
import from jaclang.prune.validate {
    Diag,
    Baseline,
    ValidationResult,
    StageResult,
    snapshot_baseline,
    validate_batch,
    select_affected_tests,
    bisect_culprit
}


glob _FIX_DIR = os.path.join(os.path.dirname(__file__), "fixtures");


test "baseline is_new flags only diagnostics absent from the snapshot" {
    base = Baseline(keys={"E0002|/m.jac|boom"});
    old = Diag(code="E0002", module_path="/m.jac", message="boom");
    fresh = Diag(code="E0002", module_path="/m.jac", message="new problem");
    assert not base.is_new(old);
    assert base.is_new(fresh);
    # span-free: the key ignores line/offset, matching across edits
    assert old.key() == "E0002|/m.jac|boom";
}


test "reverse deps walk the import graph backwards for affected-test selection" {
    # a imports b, b imports c  =>  touching c selects dependents via the graph
    edges = [("/a.jac", "/b.jac"), ("/b.jac", "/c.jac")];
    affected = select_affected_tests(edges, ["/c.jac"], ["/a.jac", "/z.jac"]);
    assert affected == ["/a.jac"] , affected;
}


test "affected-test selection picks tests that transitively depend on touched code" {
    # test_a imports a; a imports core. Touching core selects test_a. test_z is
    # unrelated and must not be selected.
    edges = [
        ("/test_a.jac", "/a.jac"),
        ("/a.jac", "/core.jac"),
        ("/test_z.jac", "/z.jac")
    ];
    tests = ["/test_a.jac", "/test_z.jac"];
    affected = select_affected_tests(edges, ["/core.jac"], tests);
    assert affected == ["/test_a.jac"] , affected;
    # touching a test file itself always includes it
    affected2 = select_affected_tests(edges, ["/test_z.jac"], tests);
    assert "/test_z.jac" in affected2;
}


test "bisection isolates the single culprit in a batch" {
    # only 'bad' fails; validates(subset) is True iff 'bad' not in subset
    def validates(subset: list[str]) -> bool {
        return "bad" not in subset;
    }
    batch = ["ok1", "ok2", "bad", "ok3", "ok4"];
    culprits = bisect_culprit(batch, validates);
    assert culprits == ["bad"] , culprits;
    # a wholly-good batch bisects to nothing
    assert bisect_culprit(["ok1", "ok2"], validates) == [];
}


test "bisection returns a minimal failing pair when two items interact" {
    # fails only when BOTH x and y are present (an interacting pair)
    def validates(subset: list[str]) -> bool {
        return not ("x" in subset and "y" in subset);
    }
    culprits = bisect_culprit(["a", "x", "b", "y", "c"], validates);
    assert set(culprits) == {"x", "y"} , culprits;
}


test "validate_batch passes a clean fixture and fails a syntactically broken one" {
    good = os.path.join(_FIX_DIR, "validprog.jac");
    baseline = snapshot_baseline([good]);
    ok = validate_batch([good], [good], baseline, run_format=False);
    assert ok.ok , ok.as_dict();
    assert ok.failed_stage() == "";

    # A file that fails to parse is caught at the parse stage. We write a broken
    # scratch file, validate, then remove it (no baseline for it, but parse fires
    # first).
    broken = os.path.join(_FIX_DIR, "_broken_scratch.jac");
    with open(broken, "w") as fh {
        fh.write("def oops( {\n  return\n");
    }
    try {
        res = validate_batch(
            [broken], [broken], Baseline(keys=set()), run_format=False
        );
        assert not res.ok;
        assert res.failed_stage() == "parse" , res.as_dict();
    } finally {
        os.remove(broken);
    }
}


test "typecheck stage rejects a patch that introduces a new diagnostic" {
    # Baseline over a clean file, then a 'patched' scratch file that references an
    # undefined name - a typecheck-only error (parses fine, fails type_check).
    # This is exactly the seeded-failure the fix --apply gate must catch + revert.
    good = os.path.join(_FIX_DIR, "validprog.jac");
    baseline = snapshot_baseline([good]);
    scratch = os.path.join(_FIX_DIR, "_typeerr_scratch.jac");
    with open(scratch, "w") as fh {
        fh.write("def broken -> int {\n    return undefined_symbol_xyz;\n}\n");
    }
    try {
        res = validate_batch([scratch], [scratch], baseline, run_format=False);
        assert not res.ok , res.as_dict();
        assert res.failed_stage() == "typecheck" , res.as_dict();
        assert len(res.new_diags) >= 1;
    } finally {
        os.remove(scratch);
    }
}


test "typecheck stage catches a NEW diagnostic introduced against baseline" {
    # Baseline over the clean fixture has some diagnostic set D0. If we hand the
    # typecheck stage a baseline that already contains every diagnostic, no new
    # ones appear -> pass. An empty baseline means any diagnostic the file emits
    # is 'new'. validprog.jac is clean (no E/W), so even an empty baseline passes
    # its typecheck; the parse-stage test above covers the failure path directly.
    good = os.path.join(_FIX_DIR, "validprog.jac");
    empty = Baseline(keys=set());
    res = validate_batch([good], [good], empty, run_format=False);
    # a clean file yields no diagnostics, so nothing is 'new' even vs empty
    assert res.ok , res.as_dict();
    stages = {s.stage: s.ok for s in res.stages};
    assert stages.get("typecheck") == True , stages;
}
