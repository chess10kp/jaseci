"""Phase-4 tests: span-edit engine, patch planner, and end-to-end application.

Three layers:
  * engine - hash guard, overlap rejection, bottom-up multi-edit application
    (pure, no compile);
  * planner - import item surgery (first/middle/last/sole) + dead-def whole-line
    deletion with leading-comment ownership (pure, byte-level);
  * end-to-end - compile `fixprog.jac`, detect -> classify -> plan -> apply, and
    assert the patched bytes re-parse with zero E-codes and the dead symbols are
    gone while live ones survive (the Phase-4 success criterion).
"""

import os;
import hashlib;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { build_veto_index }
import from jaclang.prune.detectors { run_detectors }
import from jaclang.prune.finding { Finding, classify }
import from jaclang.prune.campaign { RiskTier, Disposition }
import from jaclang.prune.spanedit { SpanEdit, make_edit, apply_edits, hash_span }
import from jaclang.prune.planner { plan_candidate, build_plan }


glob _FIX_DIR = os.path.join(os.path.dirname(__file__), "fixtures");


# ---- engine ----------------------------------------------------------------
test "apply_edits deletes bottom-up and keeps offsets valid" {
    data = b"import os;\nimport ast;\nx = 1;\n";
    e1 = make_edit(data, 0, 11, b"", "del os");
    e2 = make_edit(data, 11, 23, b"", "del ast");
    r = apply_edits(data, [e1, e2]);
    assert r.ok , r.errors;
    assert r.data == b"x = 1;\n" , r.data;
}


test "apply_edits rejects overlapping edits" {
    data = b"abcdefghij";
    e1 = make_edit(data, 0, 5);
    e2 = make_edit(data, 3, 8);
    r = apply_edits(data, [e1, e2]);
    assert not r.ok;
    assert any("overlap" in msg for msg in r.errors) , r.errors;
}


test "apply_edits refuses a stale plan via the pre-text hash guard" {
    original = b"glob X = 5;\n";
    edit = make_edit(original, 0, 11, b"");
    # the file changed since the plan was built -> hash guard must fire
    changed = b"glob Y = 9;\n";
    r = apply_edits(changed, [edit]);
    assert not r.ok;
    assert any("hash mismatch" in msg for msg in r.errors) , r.errors;
}


test "hash_span is stable and content-addressed" {
    data = b"hello world";
    assert hash_span(data, 0, 5) == hash_span(b"hello", 0, 5);
    assert hash_span(data, 0, 5) != hash_span(data, 6, 11);
}


# ---- planner: import item surgery ------------------------------------------
def _import_finding(
    item: str, istart: int, iend: int, n_items: int, ss: int, se: int
) -> Finding {
    return Finding(
        detector="unused-imports",
        symbol_id="sym",
        name=item,
        module_path="/m.jac",
        kind="import",
        message="",
        pos_start=istart,
        pos_end=iend,
        line=1,
        plan_meta={
            "stmt_pos_start": ss,
            "stmt_pos_end": se,
            "n_items": n_items,
            "is_from": True
        }
    );
}


def _apply_one(data: bytes, f: Finding) -> str {
    c = classify(f, RiskTier.RISKY);
    (edits, reason) = plan_candidate(c, data);
    assert reason == "" , reason;
    r = apply_edits(data, edits);
    assert r.ok , r.errors;
    return r.data.decode();
}


test "import item surgery removes first / middle / last / aliased items" {
    s = b"import from math { sqrt, cos, tan }";
    n = len(s);
    first = _apply_one(
        s, _import_finding("sqrt", s.index(b"sqrt"), s.index(b"sqrt") + 4, 3, 0, n)
    );
    mid = _apply_one(
        s, _import_finding("cos", s.index(b"cos"), s.index(b"cos") + 3, 3, 0, n)
    );
    last = _apply_one(
        s, _import_finding("tan", s.index(b"tan"), s.index(b"tan") + 3, 3, 0, n)
    );
    assert first == "import from math { cos, tan }" , first;
    assert mid == "import from math { sqrt, tan }" , mid;
    assert last == "import from math { sqrt, cos }" , last;

    s2 = b"import from math { sqrt, cos as cosine }";
    aliased = _apply_one(
        s2,
        _import_finding("cos", s2.index(b"cos"), s2.index(b"cos") + 3, 2, 0, len(s2))
    );
    assert aliased == "import from math { sqrt }" , aliased;
}


test "sole-item import deletes the whole statement line" {
    s = b"import os;\nimport from typing { Any }\nx = 1;\n";
    ss = s.index(b"import from typing");
    se = s.index(b"}") + 1;
    f = _import_finding("Any", s.index(b"Any"), s.index(b"Any") + 3, 1, ss, se);
    out = _apply_one(s, f);
    assert out == "import os;\nx = 1;\n" , out;
}


# ---- planner: dead-def deletion --------------------------------------------
def _def_finding(name: str, dstart: int, dend: int) -> Finding {
    return Finding(
        detector="private-dead-defs",
        symbol_id="sym",
        name=name,
        module_path="/m.jac",
        kind="variable",
        message="",
        pos_start=dstart,
        pos_end=dend,
        line=1,
        access="private"
    );
}


test "dead-def deletes the whole line with its owned leading comments" {
    s = b"y = 0;\n# owned one\n# owned two\nglob:priv DEAD = 5;\nz = 1;\n";
    i = s.index(b"DEAD");
    out = _apply_one(s, _def_finding("DEAD", i, i + 4));
    assert out == "y = 0;\nz = 1;\n" , out;
}


test "dead-def refuses a multi-line / non-owning declaration" {
    ml = b"glob:priv DEAD = [\n  1, 2, 3\n];\n";
    i = ml.index(b"DEAD");
    c = classify(_def_finding("DEAD", i, i + 4), RiskTier.RISKY);
    (edits, reason) = plan_candidate(c, ml);
    assert reason != "" , "expected a skip reason for the multi-line decl";
    assert edits == [];
}


# ---- end to end ------------------------------------------------------------
def _compile(path: str) -> tuple[JacProgram, str] {
    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=path,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = path;
    for k in prog.mod.hub.keys() {
        if k.endswith(os.path.basename(path)) {
            key = k;
        }
    }
    return (prog, key);
}


def _manifest_for(key: str) -> Manifest {
    with open(key, "rb") as f {
        h = hashlib.sha256(f.read()).hexdigest();
    }
    return Manifest(
        project_root=os.path.dirname(key),
        entries=[
            ManifestEntry(
                path=key, role=FileRole.SOURCE, content_hash=h, module_name="fixprog"
            )
        ]
    );
}


test "end-to-end: plan + apply auto-fixes, patched file re-parses clean" {
    path = os.path.join(_FIX_DIR, "fixprog.jac");
    (prog, key) = _compile(path);
    man = _manifest_for(key);
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    veto = build_veto_index(man, "");
    findings = run_detectors(store, veto, ["unused-imports", "private-dead-defs"]);
    store.close();

    cands = [classify(f, RiskTier.RISKY) for f in findings];
    autofix = [
        c
        for c in cands
        if c.disposition == Disposition.AUTO_FIX
    ];
    assert len(autofix) >= 3 , [c.finding.name for c in autofix];

    plan = build_plan(autofix);
    with open(key, "rb") as f {
        before = f.read();
    }
    result = apply_edits(before, plan.files[key].edits);
    assert result.ok , result.errors;
    text = result.data.decode();

    # dead symbols gone, live ones survive
    assert "DEAD_GLOBAL" not in text , text;
    assert "cos" not in text , text;
    assert "Any" not in text , text;
    assert "sqrt" in text;
    assert "import os;" in text;

    # the Phase-4 gate: the patched bytes must re-parse with zero E-codes
    tmp = os.path.join(_FIX_DIR, "_fixprog_applied.jac");
    with open(tmp, "wb") as f {
        f.write(result.data);
    }
    try {
        (prog2, _) = _compile(tmp);
        assert len(prog2.errors_had) == 0 , [str(e) for e in prog2.errors_had];
    } finally {
        os.remove(tmp);
    }
}
