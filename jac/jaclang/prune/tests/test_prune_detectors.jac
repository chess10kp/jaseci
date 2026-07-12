"""Phase-3 tests: Tier-1 detectors, dynamic-use veto, deterministic risk
classifier, and suppression handling.

`detectprog.jac` is a golden fixture exercising one hit per detector plus the
string-mention veto; `suppressprog.jac` covers inline `# jac:ignore` and the
project suppression file. Classifier invariants (agent-cap, veto-cap, ceiling)
are also checked directly with hand-built findings.
"""

import os;
import hashlib;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts, FactSet, ModuleFact, ImportFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { VetoIndex, build_veto_index }
import from jaclang.prune.detectors {
    detect_unused_imports,
    run_detectors,
    detector_names,
    DETECTOR_REGISTRY
}
import from jaclang.prune.finding { Finding, Evidence, Polarity, Candidate, classify }
import from jaclang.prune.campaign { Campaign, RiskTier, Disposition }
import from jaclang.prune.suppress { filter_suppressed }


glob _FIX_DIR = os.path.join(os.path.dirname(__file__), "fixtures"),
     _ALL_RECIPES = [
         "unused-imports",
         "private-dead-defs",
         "write-only-fields",
         "literal-dead-branch"
     ];


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


def _analyze(name: str, ceiling: RiskTier = RiskTier.RISKY) -> dict {
    (prog, man) = _compile_fixture(name);
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    veto = build_veto_index(man, "");
    findings = run_detectors(store, veto, _ALL_RECIPES);
    store.close();
    out: dict = {};
    for f in findings {
        out[f.name] = classify(f, ceiling);
    }
    return out;
}


test "unused-imports flags unused imports, not a used one" {
    cands = _analyze("detectprog.jac");
    assert "sqrt" in cands , list(cands.keys());
    assert "ast" in cands , list(cands.keys());
    assert cands["sqrt"].disposition == Disposition.AUTO_FIX;
    # Prose in a string literal elsewhere in the module is not a dynamic use.
    assert cands["ast"].disposition == Disposition.AUTO_FIX;
    # `os` is used (os.getpid) and must not be flagged
    assert "os" not in cands , list(cands.keys());
}


test "private-dead-defs: auto-fix for a dead private global, pr-only for an ability" {
    cands = _analyze("detectprog.jac");
    assert "DEAD_CONST" in cands;
    assert cands["DEAD_CONST"].disposition == Disposition.AUTO_FIX;
    assert cands["DEAD_CONST"].risk == RiskTier.SAFE;
    # a private unused ability carries dynamic-dispatch risk -> pr-only
    assert cands["_dead_helper"].disposition == Disposition.PR_ONLY;
}


test "write-only-fields flags a written-never-read field, not a read one" {
    cands = _analyze("detectprog.jac");
    assert "wonly" in cands;
    assert cands["wonly"].disposition == Disposition.PR_ONLY;
    # readwrite is both read and written -> not a finding
    assert "readwrite" not in cands;
}


test "literal-dead-branch flags literal-boolean conditions" {
    cands = _analyze("detectprog.jac");
    branch_keys = [
        k
        for k in cands.keys()
        if k.startswith("if(")
    ];
    assert len(branch_keys) == 2 , branch_keys;
    for k in branch_keys {
        assert cands[k].finding.detector == "literal-dead-branch";
        assert cands[k].disposition == Disposition.PR_ONLY;
    }
}


test "string-mention veto needs a standalone local dispatch key" {
    cands = _analyze("detectprog.jac");
    veto_cand = cands["VETOED_CONST"];
    # Dead private global, but its name is a standalone string literal locally.
    assert veto_cand.finding.has_veto();
    assert veto_cand.disposition == Disposition.REPORT_ONLY;
    assert "string-mention" in veto_cand.finding.veto_kinds();
}


test "string mention in another module does not veto a local binding" {
    veto = VetoIndex(string_names_by_module={"/other.jac": {"DEAD_CONST"}});
    assert veto.check_symbol("DEAD_CONST", "/target.jac") == [];
}


test "unused imports in package initializers are not findings" {
    init_path = "/pkg/__init__.jac";
    source_path = "/pkg/module.jac";
    facts = FactSet(
        modules=[
            ModuleFact(
                path=init_path, module_name="pkg", content_hash="a", role="source"
            ),
            ModuleFact(
                path=source_path,
                module_name="pkg.module",
                content_hash="b",
                role="source"
            )
        ],
        imports=[
            ImportFact(
                module_path=init_path,
                item_name="barrel",
                alias="",
                resolved_id="i",
                resolved_path="",
                pos_start=0,
                pos_end=6,
                line=1,
                is_from=False
            ),
            ImportFact(
                module_path=source_path,
                item_name="unused",
                alias="",
                resolved_id="m",
                resolved_path="",
                pos_start=0,
                pos_end=6,
                line=1,
                is_from=False
            )
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    findings = detect_unused_imports(store, VetoIndex());
    store.close();
    assert [f.name for f in findings] == ["unused"];
}


test "risk ceiling caps moderate findings to report-only" {
    cands = _analyze("detectprog.jac", ceiling=RiskTier.SAFE);
    # under a SAFE ceiling, moderate write-only / branch findings are report-only
    assert cands["wonly"].disposition == Disposition.REPORT_ONLY;
    # but a safe-tier auto-fix survives
    assert cands["DEAD_CONST"].disposition == Disposition.AUTO_FIX;
}


test "inline jac:ignore suppresses only matching codes" {
    (prog, man) = _compile_fixture("suppressprog.jac");
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    veto = build_veto_index(man, "");
    findings = run_detectors(store, veto, ["private-dead-defs"]);
    store.close();
    campaign = Campaign(project_root=man.project_root);
    (kept, suppressed) = filter_suppressed(findings, campaign);
    kept_names = {f.name for f in kept};
    suppressed_names = {f.name for f in suppressed};
    # BETA has `# jac:ignore[prune]` -> suppressed; GAMMA's [other] does not match
    assert "BETA" in suppressed_names , suppressed_names;
    assert "ALPHA" in kept_names , kept_names;
    assert "GAMMA" in kept_names , kept_names;
}


test "project suppression file drops a finding by symbol name" {
    (prog, man) = _compile_fixture("suppressprog.jac");
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    findings = run_detectors(store, build_veto_index(man, ""), ["private-dead-defs"]);
    store.close();
    supp_path = os.path.join(man.project_root, "_prune_supp_test.txt");
    with open(supp_path, "w") as f {
        f.write("# test suppressions\nALPHA\n");
    }
    try {
        campaign = Campaign(project_root=man.project_root, suppression_file=supp_path);
        (kept, suppressed) = filter_suppressed(findings, campaign);
        assert "ALPHA" in {f.name for f in suppressed};
    } finally {
        os.remove(supp_path);
    }
}


test "classifier caps agent-sourced findings below auto-fix" {
    f = Finding(
        detector="unused-imports",
        symbol_id="x",
        name="foo",
        module_path="/m.jac",
        kind="import",
        message="m",
        pos_start=0,
        pos_end=1,
        line=1,
        source="agent"
    );
    c = classify(f, RiskTier.SAFE);
    # unused-imports is normally auto-fix; agent source can never reach it
    assert c.disposition == Disposition.PR_ONLY;
}


test "classifier caps any vetoed finding to report-only" {
    f = Finding(
        detector="unused-imports",
        symbol_id="x",
        name="foo",
        module_path="/m.jac",
        kind="import",
        message="m",
        pos_start=0,
        pos_end=1,
        line=1
    );
    f.add(
        Evidence(kind="string-mention", polarity=Polarity.VETOES, detail="mentioned")
    );
    c = classify(f, RiskTier.SAFE);
    assert c.disposition == Disposition.REPORT_ONLY;
}


test "run_detectors skips unknown recipe names" {
    store = FactStore(db_path=":memory:");
    store.open();
    findings = run_detectors(store, VetoIndex(), ["unknown-name"]);
    store.close();
    assert findings == [];
}


test "detector_names lists every registered detector" {
    names = detector_names();
    expected = [
        "unused-imports",
        "private-dead-defs",
        "dead-enum-variants",
        "write-only-fields",
        "literal-dead-branch",
        "single-caller-inline",
        "visibility-tightening",
        "duplicated-constant-blobs",
        "duplicate-docstrings",
        "module-cohesion"
    ];
    for n in expected {
        assert n in names;
    }
    assert len(names) == len(DETECTOR_REGISTRY);
    assert len(names) == 10;
}
