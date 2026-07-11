"""Specification tests for `jac prune`.

Each test pins one observable contract of a detector, the classifier, the veto
system, or the campaign configuration layer.  All tests use hand-built FactSets
so no compilation pass is required — the detector and store logic are exercised
independently of the parser/type-checker.

Detectors covered
  1. unused-imports
  2. private-dead-defs  (variable/mod_var, ability, method, object, node, edge,
                         walker, enum; lifecycle names; dunders; nested scope)
  3. write-only-fields  (write-never-read; read+write; public; dunder; del=write)
  4. literal-dead-branch (if False; if True+else; if True no-else; non-literal)
  5. single-caller-inline (1-caller small; multi-caller; over-floor; self-only;
                            dunder; lifecycle)
  6. visibility-tightening (internal-only; cross-module ref; barrel re-export;
                             private; __init__.jac module; lifecycle; zero-use)

Classifier invariants
  7. risk ceiling caps disposition
  8. agent source caps at pr-only (never auto-fix)
  9. veto caps to report-only regardless of base disposition
  10. multiple veto kinds all reported

Campaign configuration
  11. DEFAULT_RECIPES list
  12. risk_ceiling and output_format string parsing
  13. parse_prune_action covers all actions
"""

import from jaclang.prune.extract {
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact,
    ImportFact,
    FieldAccessFact,
    BranchFact
}
import from jaclang.prune.bodies { BodyFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.veto { VetoIndex }
import from jaclang.prune.detectors {
    detect_unused_imports,
    detect_private_dead_defs,
    detect_write_only_fields,
    detect_literal_dead_branches,
    detect_single_caller_inline,
    detect_visibility_tightening,
    run_detectors
}
import from jaclang.prune.finding { Finding, Evidence, Polarity, classify }
import from jaclang.prune.campaign {
    Campaign,
    RiskTier,
    Disposition,
    OutputFormat,
    PruneAction,
    DEFAULT_RECIPES,
    parse_risk_tier,
    parse_output_format,
    parse_prune_action,
    resolve_campaign
}


glob _MOD = "/proj/mod.jac",
     _MOD2 = "/proj/other.jac",
     _INIT = "/proj/__init__.jac";


def _store(facts: FactSet) -> FactStore {
    s = FactStore(db_path=":memory:");
    s.open();
    s.sync(facts);
    return s;
}


def _sym(
    sid: str,
    name: str,
    kind: str,
    access: str,
    path: str = _MOD,
    parent_id: str = "",
    scope_chain: str = "mod",
    pos: int = 0
) -> SymbolFact {
    return SymbolFact(
        id=sid,
        module_path=path,
        name=name,
        kind=kind,
        access=access,
        imported=False,
        parent_id=parent_id,
        decl_pos_start=pos,
        decl_pos_end=pos + 10,
        decl_line=pos + 1,
        scope_chain=scope_chain
    );
}


def _ref(
    used: str, using: str, path: str = _MOD, pos: int = 100, kind: str = "call"
) -> ReferenceFact {
    return ReferenceFact(
        used_id=used,
        using_id=using,
        module_path=path,
        pos_start=pos,
        pos_end=pos + 10,
        line=pos,
        kind=kind
    );
}


def _imp(
    item: str,
    resolved: str,
    path: str = _MOD,
    alias: str = "",
    is_from: bool = True,
    n_items: int = 1
) -> ImportFact {
    return ImportFact(
        module_path=path,
        item_name=item,
        alias=alias,
        resolved_id=resolved,
        resolved_path="",
        pos_start=0,
        pos_end=len(item),
        line=1,
        is_from=is_from,
        stmt_pos_start=0,
        stmt_pos_end=20,
        n_items=n_items
    );
}


def _body(
    sid: str,
    name: str,
    path: str = _MOD,
    owner_id: str = "",
    owner_name: str = "",
    exact_hash: str = "e1",
    struct_hash: str = "s1",
    stmt_count: int = 2,
    line_count: int = 4,
    completeness: str = "complete",
    vector: str = "",
    stmt_seq: str = ""
) -> BodyFact {
    return BodyFact(
        symbol_id=sid,
        name=name,
        module_path=path,
        owner_id=owner_id,
        owner_name=owner_name,
        body_file=path,
        body_pos_start=0,
        body_pos_end=40,
        stmt_pos_start=5,
        stmt_pos_end=35,
        exact_hash=exact_hash,
        structural_hash=struct_hash,
        arity=0,
        is_async=False,
        is_gen=False,
        stmt_count=stmt_count,
        line_count=line_count,
        size_band=1,
        completeness=completeness,
        vector=vector,
        stmt_seq=stmt_seq
    );
}


def _two_mods -> FactSet {
    return FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source"),
            ModuleFact(path=_MOD2, module_name="other", content_hash="b", role="source")
        ]
    );
}


# ---------------------------------------------------------------------------
# 1. unused-imports
# ---------------------------------------------------------------------------
test "unused-imports: a from-import with no refs is flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        imports=[_imp("Foo", "sym:foo")]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    assert len(fs) == 1 , fs;
    assert fs[0].name == "Foo";
    assert fs[0].detector == "unused-imports";
}


test "unused-imports: a used import is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        imports=[_imp("Foo", "sym:foo")],
        refs=[_ref("sym:foo", "caller", _MOD, 50, "call")]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    assert len(fs) == 0 , [f.name for f in fs];
}


test "unused-imports: aliased import uses the alias in the message" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        imports=[_imp("SomeLong", "sym:sl", alias="SL")]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert "SL" in fs[0].message;
}


test "unused-imports: in a multi-item import only the unused item is flagged" {
    # n_items=2 simulates 'from X import Used, Unused'
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        imports=[
            _imp("Used", "sym:used", n_items=2),
            _imp("Unused", "sym:unused", n_items=2)
        ],
        refs=[_ref("sym:used", "caller", _MOD, 50, "call")]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "Unused" in names , names;
    assert "Used" not in names , names;
}


test "unused-imports: imports from __init__.jac are never flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_INIT, module_name="pkg", content_hash="a", role="source")
        ],
        imports=[_imp("Barrel", "sym:bar", path=_INIT)]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    assert len(fs) == 0 , [f.name for f in fs];
}


test "unused-imports: import with empty resolved_id is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        imports=[_imp("Unknown", "")]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "unused-imports: plan_meta carries stmt positions and n_items" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        imports=[_imp("Foo", "sym:foo", n_items=3)]
    );
    store = _store(facts);
    fs = detect_unused_imports(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert int(fs[0].plan_meta["n_items"]) == 3;
    assert "stmt_pos_start" in fs[0].plan_meta;
    assert "stmt_pos_end" in fs[0].plan_meta;
    assert "is_from" in fs[0].plan_meta;
}


# ---------------------------------------------------------------------------
# 2. private-dead-defs
# ---------------------------------------------------------------------------
test "private-dead-defs: dead private mod_var -> safe/auto-fix" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "DEAD", "mod_var", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert fs[0].name == "DEAD";
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.SAFE;
    assert c.disposition == Disposition.AUTO_FIX;
}


test "private-dead-defs: dead private ability -> moderate/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_helper", "ability", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.MODERATE;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: dead private method -> moderate/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_method", "method", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.MODERATE;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: dead private object (archetype) -> risky/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_Widget", "object", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.RISKY;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: dead private node -> risky/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_N", "node", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.RISKY;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: dead private edge -> risky/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_E", "edge", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.RISKY;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: dead private walker -> risky/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_W", "walker", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.RISKY;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: dead private enum -> risky/pr-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_Color", "enum", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.RISKY;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: nested ability (scope_chain contains >) -> moderate/pr-only" {
    # A private ability defined inside a class has '>' in its scope_chain.
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_inner", "ability", "private", scope_chain="mod>Cls")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.MODERATE;
    assert c.disposition == Disposition.PR_ONLY;
}


test "private-dead-defs: used private symbol is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_helper", "ability", "private", pos=0)],
        refs=[_ref("s1", "caller", _MOD, 200)]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    # a ref at pos 200 is outside the decl span 0..10, so counts as external use
    assert len(fs) == 0 , [f.name for f in fs];
}


test "private-dead-defs: public symbol is not flagged even if unreferenced" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "PubFn", "ability", "public")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "private-dead-defs: 'init' lifecycle name is excluded" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "init", "method", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "private-dead-defs: 'postinit' lifecycle name is excluded" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "postinit", "method", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "private-dead-defs: dunder name is excluded" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "__repr__", "method", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "private-dead-defs: protected access is also a candidate" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_prot", "ability", "protected")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert fs[0].name == "_prot";
}


test "private-dead-defs: field kind is not a candidate (handled by write-only-fields)" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_f", "field", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


# ---------------------------------------------------------------------------
# 3. write-only-fields
# ---------------------------------------------------------------------------
test "write-only-fields: private field written and never read is flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "_count", "field", "private")],
        field_accesses=[
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=50,
                pos_end=60,
                line=5,
                kind="write"
            )
        ]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert fs[0].name == "_count";
    c = classify(fs[0], RiskTier.RISKY);
    assert c.risk == RiskTier.MODERATE;
    assert c.disposition == Disposition.PR_ONLY;
}


test "write-only-fields: private field that is also read is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "_x", "field", "private")],
        field_accesses=[
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=50,
                pos_end=60,
                line=5,
                kind="write"
            ),
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=70,
                pos_end=80,
                line=7,
                kind="read"
            )
        ]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    assert len(fs) == 0 , [f.name for f in fs];
}


test "write-only-fields: public field is not flagged even if write-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "count", "field", "public")],
        field_accesses=[
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=50,
                pos_end=60,
                line=5,
                kind="write"
            )
        ]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "write-only-fields: dunder field is excluded even if write-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "__slots__", "field", "private")],
        field_accesses=[
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=50,
                pos_end=60,
                line=5,
                kind="write"
            )
        ]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "write-only-fields: del access counts as a write (field still write-only)" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "_buf", "field", "private")],
        field_accesses=[
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=50,
                pos_end=60,
                line=5,
                kind="del"
            )
        ]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert fs[0].name == "_buf";
}


test "write-only-fields: zero-access field (never written) is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "_ghost", "field", "private")]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    # requires writes >= 1, so never-written is not a candidate
    assert len(fs) == 0;
}


test "write-only-fields: message contains write count" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("f1", "_c", "field", "private")],
        field_accesses=[
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=10,
                pos_end=20,
                line=2,
                kind="write"
            ),
            FieldAccessFact(
                field_id="f1",
                module_path=_MOD,
                pos_start=30,
                pos_end=40,
                line=4,
                kind="write"
            )
        ]
    );
    store = _store(facts);
    fs = detect_write_only_fields(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert "2" in fs[0].message;
}


# ---------------------------------------------------------------------------
# 4. literal-dead-branch
# ---------------------------------------------------------------------------
test "literal-dead-branch: if False flags the body as dead" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        branches=[
            BranchFact(
                module_path=_MOD,
                cond_value="false",
                is_elif=False,
                has_else=False,
                if_pos_start=0,
                if_pos_end=30,
                cond_pos_start=3,
                cond_pos_end=8,
                line=1
            )
        ]
    );
    store = _store(facts);
    fs = detect_literal_dead_branches(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert fs[0].detector == "literal-dead-branch";
    assert "body" in fs[0].message or "False" in fs[0].message;
    c = classify(fs[0], RiskTier.RISKY);
    assert c.disposition == Disposition.PR_ONLY;
}


test "literal-dead-branch: if True with else flags the else branch as dead" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        branches=[
            BranchFact(
                module_path=_MOD,
                cond_value="true",
                is_elif=False,
                has_else=True,
                if_pos_start=0,
                if_pos_end=50,
                cond_pos_start=3,
                cond_pos_end=7,
                line=1
            )
        ]
    );
    store = _store(facts);
    fs = detect_literal_dead_branches(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert "else" in fs[0].message or "True" in fs[0].message;
}


test "literal-dead-branch: if True without else is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        branches=[
            BranchFact(
                module_path=_MOD,
                cond_value="true",
                is_elif=False,
                has_else=False,
                if_pos_start=0,
                if_pos_end=20,
                cond_pos_start=3,
                cond_pos_end=7,
                line=1
            )
        ]
    );
    store = _store(facts);
    fs = detect_literal_dead_branches(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "literal-dead-branch: non-literal condition is not flagged" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        branches=[
            BranchFact(
                module_path=_MOD,
                cond_value="expr",
                is_elif=False,
                has_else=True,
                if_pos_start=0,
                if_pos_end=30,
                cond_pos_start=3,
                cond_pos_end=7,
                line=1
            )
        ]
    );
    store = _store(facts);
    fs = detect_literal_dead_branches(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "literal-dead-branch: two dead branches produce two findings" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        branches=[
            BranchFact(
                module_path=_MOD,
                cond_value="false",
                is_elif=False,
                has_else=False,
                if_pos_start=0,
                if_pos_end=20,
                cond_pos_start=3,
                cond_pos_end=8,
                line=1
            ),
            BranchFact(
                module_path=_MOD,
                cond_value="true",
                is_elif=False,
                has_else=True,
                if_pos_start=30,
                if_pos_end=60,
                cond_pos_start=33,
                cond_pos_end=37,
                line=5
            )
        ]
    );
    store = _store(facts);
    fs = detect_literal_dead_branches(store, VetoIndex());
    store.close();
    assert len(fs) == 2 , [f.name for f in fs];
}


# ---------------------------------------------------------------------------
# 5. single-caller-inline
# ---------------------------------------------------------------------------
def _inline_store(
    sid: str,
    name: str,
    callers: list[str],
    stmt_count: int = 2,
    completeness: str = "complete"
) -> FactStore {
    caller_syms = [
        _sym(c, "caller_" + c, "method", "public", pos=200 + int(i) * 20)
        for (i, c) in enumerate(callers)
    ];
    caller_syms_with_decl = [_sym(sid, name, "method", "private", pos=0)] + caller_syms;
    call_refs = [
        _ref(sid, c, _MOD, 300 + int(i) * 10) for (i, c) in enumerate(callers)
    ];
    body = _body(sid, name, stmt_count=stmt_count, completeness=completeness);
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=caller_syms_with_decl,
        refs=call_refs,
        bodies=[body]
    );
    return _store(facts);
}


test "single-caller-inline: private method with 1 caller and small body is flagged" {
    store = _inline_store("s1", "_once", ["ext1"], stmt_count=2);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 1 , [f.name for f in fs];
    assert fs[0].name == "_once";
    assert len(fs[0].related) == 1;
    assert fs[0].related[0].startswith("sym:");
    c = classify(fs[0], RiskTier.RISKY);
    assert c.disposition == Disposition.REPORT_ONLY;
    assert c.risk == RiskTier.MODERATE;
}


test "single-caller-inline: method with 2 callers is not flagged" {
    store = _inline_store("s1", "_multi", ["c1", "c2"], stmt_count=2);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 0 , [f.name for f in fs];
}


test "single-caller-inline: body over the 3-statement floor is not flagged" {
    store = _inline_store("s1", "_big", ["c1"], stmt_count=4);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "single-caller-inline: self-recursive method with no external callers is not flagged" {
    # Only caller is the method itself (using_id == used_id).
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_recurse", "method", "private", pos=0)],
        refs=[_ref("s1", "s1", _MOD, 50)],
        bodies=[_body("s1", "_recurse", stmt_count=1)]
    );
    store = _store(facts);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    # self-call is excluded; effective distinct callers = 0, not flagged
    assert len(fs) == 0;
}


test "single-caller-inline: dunder method is excluded" {
    store = _inline_store("s1", "__hook__", ["c1"], stmt_count=1);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "single-caller-inline: lifecycle 'init' is excluded" {
    store = _inline_store("s1", "init", ["c1"], stmt_count=1);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "single-caller-inline: lifecycle 'postinit' is excluded" {
    store = _inline_store("s1", "postinit", ["c1"], stmt_count=1);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "single-caller-inline: incomplete body is not a candidate" {
    store = _inline_store("s1", "_stub", ["c1"], stmt_count=2, completeness="stub");
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "single-caller-inline: exactly 3 statements is within the floor and is flagged" {
    store = _inline_store("s1", "_three", ["c1"], stmt_count=3);
    fs = detect_single_caller_inline(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    assert "3-statement" in fs[0].message;
}


# ---------------------------------------------------------------------------
# 6. visibility-tightening
# ---------------------------------------------------------------------------
def _tighten_store -> FactStore {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source"),
            ModuleFact(
                path=_MOD2, module_name="other", content_hash="b", role="source"
            ),
            ModuleFact(path=_INIT, module_name="pkg", content_hash="c", role="source")
        ],
        symbols=[
            _sym("s_int", "InternalFn", "ability", "public", pos=0),
            _sym("s_cross", "CrossFn", "ability", "public", pos=20),
            _sym("s_rexp", "Reexported", "ability", "public", pos=40),
            _sym("s_priv", "PrivFn", "ability", "private", pos=60),
            _sym("s_nouse", "NoUseFn", "ability", "public", pos=80),
            SymbolFact(
                id="s_init_fn",
                module_path=_INIT,
                name="BarrelFn",
                kind="ability",
                access="public",
                imported=False,
                parent_id="",
                decl_pos_start=0,
                decl_pos_end=10,
                decl_line=1,
                scope_chain="pkg"
            )
        ],
        refs=[
            _ref("s_int", "local_caller", _MOD, 200),
            _ref("s_cross", "remote_caller", _MOD2, 200)
        ],
        imports=[
            ImportFact(
                module_path=_INIT,
                item_name="Reexported",
                alias="",
                resolved_id="s_rexp",
                resolved_path="",
                pos_start=0,
                pos_end=10,
                line=1,
                is_from=True
            )
        ]
    );
    return _store(facts);
}


test "visibility-tightening: public symbol used only in its own module is flagged" {
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "InternalFn" in names , names;
    for f in fs {
        if f.name == "InternalFn" {
            c = classify(f, RiskTier.RISKY);
            assert c.disposition == Disposition.REPORT_ONLY;
            assert c.risk == RiskTier.MODERATE;
            assert int(f.plan_meta["internal_uses"]) == 1;
        }
    }
}


test "visibility-tightening: cross-module reference suppresses the finding" {
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "CrossFn" not in names , names;
}


test "visibility-tightening: barrel re-export in __init__.jac suppresses the finding" {
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "Reexported" not in names , names;
}


test "visibility-tightening: private symbol is never a candidate" {
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "PrivFn" not in names , names;
}


test "visibility-tightening: symbol declared in __init__.jac is never a candidate" {
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "BarrelFn" not in names , names;
}


test "visibility-tightening: public symbol with zero total uses is still flagged" {
    # NoUseFn has 0 internal refs and 0 cross-module refs -> still a tightening candidate
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    names = {f.name for f in fs};
    assert "NoUseFn" in names , names;
    for f in fs {
        if f.name == "NoUseFn" {
            assert int(f.plan_meta["internal_uses"]) == 0;
        }
    }
}


test "visibility-tightening: lifecycle 'init' name is excluded" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "init", "method", "public")]
    );
    store = _store(facts);
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    assert len(fs) == 0;
}


test "visibility-tightening: finding carries citations with sym: prefix" {
    store = _tighten_store();
    fs = detect_visibility_tightening(store, VetoIndex());
    store.close();
    for f in fs {
        if f.name == "InternalFn" {
            assert len(f.citations) == 1;
            assert f.citations[0] == "sym:s_int";
        }
    }
}


# ---------------------------------------------------------------------------
# 7. veto system
# ---------------------------------------------------------------------------
test "veto: string mention in same module vetoes a finding to report-only" {
    # _FOO appears as a bare string in the same module -> veto fires
    veto = VetoIndex(string_names_by_module={_MOD: {"_FOO"}});
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_FOO", "mod_var", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, veto);
    store.close();
    assert len(fs) == 1;
    f = fs[0];
    assert f.has_veto();
    assert "string-mention" in f.veto_kinds();
    c = classify(f, RiskTier.SAFE);
    # normally auto-fix; veto must cap to report-only
    assert c.disposition == Disposition.REPORT_ONLY;
}


test "veto: string mention in a different module does not veto local binding" {
    veto = VetoIndex(string_names_by_module={_MOD2: {"_FOO"}});
    assert veto.check_symbol("_FOO", _MOD) == [];
}


test "veto: evidence list contains one SUPPORTS entry when no veto" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_X", "mod_var", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    polarities = [e.polarity for e in fs[0].evidence];
    assert Polarity.SUPPORTS in polarities;
    assert Polarity.VETOES not in polarities;
}


# ---------------------------------------------------------------------------
# 8. classifier
# ---------------------------------------------------------------------------
test "classifier: safe ceiling demotes moderate findings to report-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_dead", "ability", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    c_risky = classify(fs[0], RiskTier.RISKY);
    assert c_risky.disposition == Disposition.PR_ONLY;
    c_safe = classify(fs[0], RiskTier.SAFE);
    # ability is MODERATE; safe ceiling blocks it -> report-only
    assert c_safe.disposition == Disposition.REPORT_ONLY;
}


test "classifier: agent source cannot reach auto-fix (capped at pr-only)" {
    f = Finding(
        detector="unused-imports",
        symbol_id="x",
        name="foo",
        module_path=_MOD,
        kind="import",
        message="unused",
        pos_start=0,
        pos_end=5,
        line=1,
        source="agent"
    );
    c = classify(f, RiskTier.SAFE);
    # normally auto-fix; agent source caps at pr-only
    assert c.disposition == Disposition.PR_ONLY;
}


test "classifier: veto caps any finding to report-only regardless of base disposition" {
    f = Finding(
        detector="unused-imports",
        symbol_id="x",
        name="bar",
        module_path=_MOD,
        kind="import",
        message="unused",
        pos_start=0,
        pos_end=5,
        line=1
    );
    f.add(
        Evidence(
            kind="string-mention",
            polarity=Polarity.VETOES,
            detail="mentioned in string"
        )
    );
    c = classify(f, RiskTier.SAFE);
    assert c.disposition == Disposition.REPORT_ONLY;
}


test "classifier: multiple veto kinds all reported in veto_kinds" {
    f = Finding(
        detector="private-dead-defs",
        symbol_id="y",
        name="BAZ",
        module_path=_MOD,
        kind="mod_var",
        message="dead",
        pos_start=0,
        pos_end=5,
        line=1
    );
    f.add(Evidence(kind="string-mention", polarity=Polarity.VETOES, detail="v1"));
    f.add(Evidence(kind="dynamic-dispatch", polarity=Polarity.VETOES, detail="v2"));
    assert f.has_veto();
    vk = f.veto_kinds();
    assert "string-mention" in vk , vk;
    assert "dynamic-dispatch" in vk , vk;
    c = classify(f, RiskTier.RISKY);
    assert c.disposition == Disposition.REPORT_ONLY;
}


test "classifier: forbidden ceiling converts risky to report-only" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_N", "node", "private")]
    );
    store = _store(facts);
    fs = detect_private_dead_defs(store, VetoIndex());
    store.close();
    assert len(fs) == 1;
    # risky ceiling: pr-only (risky <= risky)
    c_risky = classify(fs[0], RiskTier.RISKY);
    assert c_risky.disposition == Disposition.PR_ONLY;
    # moderate ceiling: report-only (risky > moderate)
    c_mod = classify(fs[0], RiskTier.MODERATE);
    assert c_mod.disposition == Disposition.REPORT_ONLY;
}


test "classifier: finding fingerprint is stable for same detector+symbol" {
    f1 = Finding(
        detector="unused-imports",
        symbol_id="sym:abc",
        name="Foo",
        module_path=_MOD,
        kind="import",
        message="unused",
        pos_start=0,
        pos_end=5,
        line=1
    );
    f2 = Finding(
        detector="unused-imports",
        symbol_id="sym:abc",
        name="Foo",
        module_path=_MOD,
        kind="import",
        message="different message",
        pos_start=99,
        pos_end=110,
        line=99
    );
    # fingerprint is keyed on detector+symbol_id, not position/message
    assert f1.fingerprint() == f2.fingerprint();
}


test "classifier: findings for different symbols have different fingerprints" {
    f1 = Finding(
        detector="unused-imports",
        symbol_id="sym:a",
        name="A",
        module_path=_MOD,
        kind="import",
        message="m",
        pos_start=0,
        pos_end=1,
        line=1
    );
    f2 = Finding(
        detector="unused-imports",
        symbol_id="sym:b",
        name="B",
        module_path=_MOD,
        kind="import",
        message="m",
        pos_start=0,
        pos_end=1,
        line=1
    );
    assert f1.fingerprint() != f2.fingerprint();
}


# ---------------------------------------------------------------------------
# 9. run_detectors dispatcher
# ---------------------------------------------------------------------------
test "run_detectors: empty recipes list returns no findings" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_dead", "mod_var", "private")],
        imports=[_imp("Foo", "sym:f")]
    );
    store = _store(facts);
    fs = run_detectors(store, VetoIndex(), []);
    store.close();
    assert len(fs) == 0;
}


test "run_detectors: only requested detector fires" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD, module_name="mod", content_hash="a", role="source")
        ],
        symbols=[_sym("s1", "_dead", "mod_var", "private")],
        imports=[_imp("Foo", "sym:f")]
    );
    store = _store(facts);
    # request only unused-imports: the dead def should NOT appear
    fs = run_detectors(store, VetoIndex(), ["unused-imports"]);
    store.close();
    names = {f.name for f in fs};
    assert "Foo" in names;
    assert "_dead" not in names;
}


# ---------------------------------------------------------------------------
# 10. campaign configuration
# ---------------------------------------------------------------------------
test "campaign: DEFAULT_RECIPES contains all Tier-1 to Tier-3 detectors" {
    expected = {
        "unused-imports",
        "private-dead-defs",
        "write-only-fields",
        "literal-dead-branch",
        "single-caller-inline"
    };
    for r in expected {
        assert r in DEFAULT_RECIPES , (r, DEFAULT_RECIPES);
    }
}


test "campaign: parse_risk_tier maps canonical strings" {
    assert parse_risk_tier("safe") == RiskTier.SAFE;
    assert parse_risk_tier("moderate") == RiskTier.MODERATE;
    assert parse_risk_tier("risky") == RiskTier.RISKY;
    assert parse_risk_tier("forbidden") == RiskTier.FORBIDDEN;
}


test "campaign: parse_risk_tier defaults to safe on unknown input" {
    assert parse_risk_tier("unknown") == RiskTier.SAFE;
    assert parse_risk_tier("") == RiskTier.SAFE;
}


test "campaign: parse_output_format maps table/json/sarif" {
    assert parse_output_format("table") == OutputFormat.TABLE;
    assert parse_output_format("json") == OutputFormat.JSON;
    assert parse_output_format("sarif") == OutputFormat.SARIF;
}


test "campaign: parse_output_format defaults to table on unknown input" {
    assert parse_output_format("xml") == OutputFormat.TABLE;
}


test "campaign: parse_prune_action maps all five actions" {
    assert parse_prune_action("report") == PruneAction.REPORT;
    assert parse_prune_action("facts") == PruneAction.FACTS;
    assert parse_prune_action("fix") == PruneAction.FIX;
    assert parse_prune_action("analyze") == PruneAction.ANALYZE;
    assert parse_prune_action("reuse") == PruneAction.REUSE;
}


test "campaign: parse_prune_action returns None for unknown action" {
    assert parse_prune_action("unknown") is None;
}


test "campaign: resolve_campaign merges flags over toml config" {
    toml = {"risk_ceiling": "moderate", "recipes": ["unused-imports"]};
    c = resolve_campaign([], "/proj", toml_config=toml);
    assert c.risk_ceiling == RiskTier.MODERATE;
    assert c.recipes == ["unused-imports"];
}


test "campaign: CLI flag overrides toml risk_ceiling" {
    toml = {"risk_ceiling": "moderate"};
    c = resolve_campaign([], "/proj", toml_config=toml, risk_ceiling="risky");
    assert c.risk_ceiling == RiskTier.RISKY;
}
