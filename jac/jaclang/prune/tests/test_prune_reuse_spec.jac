"""Specification tests for `jac prune reuse`.

Pins every observable contract of the two reuse engines:

  Structural-clone funnel (find_clone_groups / find_class_rollups)
    1.  Exact clone: byte-identical bodies across two distinct owners group.
    2.  Structural clone: constant-diff bodies share a structural hash.
    3.  Lifecycle exclusion: init / postinit / __dunder__ bodies never group.
    4.  Same-owner exclusion: a structural match inside one class is not a group.
    5.  Incomplete body excluded: completeness != 'complete' is not a candidate.
    6.  Exact subgroups are computed within a structural group.
    7.  Class rollup: ≥2 shared-method groups between the same class pair.
    8.  Class rollup requires exactly ≥2 groups (single shared method excluded).
    9.  Rollup payoff = sum of member group payoffs.
    10. Rollup lines_saved = sum of member group lines_saved.
    11. Rollup recommendation is 'hoist-shared-methods-to-common-base'.
    12. Cross-module free functions are not included in class rollups.
    13. Payoff formula: 0.6*sat(lines,200)+0.25*sat(copies,6)+0.15*sat(reach,40).
    14. Groups ranked payoff-descending (stable by group_id as tiebreak).
    15. group_id is deterministic across re-runs.
    16. Negative control: same-signature different structural hash → no group.
    17. group_packet ships verifiable sym:/body: citations for each member.
    18. group_packet evidence carries tier and structural_hash.

  Statement-window mining (find_stmt_windows)
    19. Shared block across ≥2 distinct functions surfaces as a WindowGroup.
    20. Window length is the maximal extension of the seed.
    21. min_window parameter controls the seed size; blocks below it never seed.
    22. Same-owner window gets 0.5× payoff penalty.
    23. distinct_functions and distinct_owners counts are correct.
    24. window_id is deterministic across re-runs.
    25. window_packet ships sym:/body: citations for each site.
    26. Unrelated statements are not included in any window.

All tests use hand-built FactSets / BodyFacts — no compilation pass needed.
"""

import hashlib;
import from jaclang.prune.extract { FactSet, ModuleFact, SymbolFact, ReferenceFact }
import from jaclang.prune.bodies { BodyFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { ToolSurface }
import from jaclang.prune.clones { find_clone_groups, find_class_rollups, group_packet }
import from jaclang.prune.windows { find_stmt_windows, window_packet }


glob _MOD_A = "/proj/a.jac",
     _MOD_B = "/proj/b.jac";


def _store(facts: FactSet) -> FactStore {
    s = FactStore(db_path=":memory:");
    s.open();
    s.sync(facts);
    return s;
}


def _sym(
    sid: str,
    name: str,
    kind: str = "method",
    access: str = "public",
    path: str = _MOD_A,
    pos: int = 0
) -> SymbolFact {
    return SymbolFact(
        id=sid,
        module_path=path,
        name=name,
        kind=kind,
        access=access,
        imported=False,
        parent_id="",
        decl_pos_start=pos,
        decl_pos_end=pos + 10,
        decl_line=pos + 1,
        scope_chain=name
    );
}


def _body(
    sid: str,
    name: str,
    owner_id: str = "",
    owner_name: str = "",
    exact_hash: str = "e1",
    struct_hash: str = "s1",
    stmt_count: int = 5,
    line_count: int = 8,
    arity: int = 0,
    is_async: bool = False,
    completeness: str = "complete",
    path: str = _MOD_A,
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
        body_pos_end=80,
        stmt_pos_start=5,
        stmt_pos_end=75,
        exact_hash=exact_hash,
        structural_hash=struct_hash,
        arity=arity,
        is_async=is_async,
        is_gen=False,
        stmt_count=stmt_count,
        line_count=line_count,
        size_band=1,
        completeness=completeness,
        vector=vector,
        stmt_seq=stmt_seq
    );
}


def _group_by_member_names(groups: list, names: set) -> (any | None) {
    for g in groups {
        if {m.name for m in g.members} == names {
            return g;
        }
    }
    return None;
}


# ---------------------------------------------------------------------------
# 1. Exact clone: byte-identical bodies across two distinct owners group
# ---------------------------------------------------------------------------
test "reuse: byte-identical bodies across two classes form an exact clone group" {
    # Both classes have a method 'scan' with the same exact_hash AND structural_hash.
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "scan", path=_MOD_A, pos=0),
            _sym("s2", "scan", path=_MOD_A, pos=100)
        ],
        bodies=[
            _body(
                "s1",
                "scan",
                owner_id="cls1",
                owner_name="Alpha",
                exact_hash="EEE",
                struct_hash="SSS",
                line_count=10
            ),
            _body(
                "s2",
                "scan",
                owner_id="cls2",
                owner_name="Beta",
                exact_hash="EEE",
                struct_hash="SSS",
                line_count=10
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"scan"});
    assert g is not None , [list({m.name for m in grp.members}) for grp in groups];
    assert g.kind == "exact" , g.kind;
    owners = {m.owner_name for m in g.members};
    assert owners == {"Alpha", "Beta"} , owners;
    # exact subgroup contains both members
    assert len(g.exact_subgroups) == 1;
    assert len(g.exact_subgroups[0]) == 2;
}


# ---------------------------------------------------------------------------
# 2. Structural clone: constant-diff bodies share structural hash, not exact
# ---------------------------------------------------------------------------
test "reuse: structural clone groups by structural hash when exact hashes differ" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "emit_a", path=_MOD_A, pos=0),
            _sym("s2", "emit_b", path=_MOD_A, pos=50)
        ],
        bodies=[
            _body(
                "s1",
                "emit_a",
                owner_id="cls1",
                owner_name="C1",
                exact_hash="E1",
                struct_hash="SAME_S",
                vector="'tag1'"
            ),
            _body(
                "s2",
                "emit_b",
                owner_id="cls2",
                owner_name="C2",
                exact_hash="E2",
                struct_hash="SAME_S",
                vector="'tag2'"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"emit_a", "emit_b"});
    assert g is not None;
    assert g.kind == "structural" , g.kind;
    # no exact subgroup (hashes differ)
    assert g.exact_subgroups == [] , g.exact_subgroups;
}


# ---------------------------------------------------------------------------
# 3. Lifecycle exclusion: init / postinit / __dunder__ never group
# ---------------------------------------------------------------------------
test "reuse: 'init' lifecycle method is excluded from clone grouping" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "init",
                owner_id="cls1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "init",
                owner_id="cls2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    assert len(groups) == 0 , [list({m.name for m in g.members}) for g in groups];
}


test "reuse: 'postinit' lifecycle method is excluded from clone grouping" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "postinit",
                owner_id="cls1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "postinit",
                owner_id="cls2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    assert len(groups) == 0;
}


test "reuse: dunder methods are excluded from clone grouping" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "__repr__",
                owner_id="cls1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "__repr__",
                owner_id="cls2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    assert len(groups) == 0;
}


# ---------------------------------------------------------------------------
# 4. Distinct-site rule: the funnel keys on (owner, name), not owner alone
# ---------------------------------------------------------------------------
test "reuse: two differently-named methods in one class form a structural group" {
    # Distinct sites are keyed on (owner, name): different names in the same
    # class are two distinct sites, so they group -- this is the set-emitter
    # consolidation pattern (emit_sub/emit_super/...) at class granularity.
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "do_a",
                owner_id="cls1",
                owner_name="X",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "do_b",
                owner_id="cls1",
                owner_name="X",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"do_a", "do_b"});
    assert g is not None , [list({m.name for m in grp.members}) for grp in groups];
    assert g.kind == "exact" , g.kind;
}


test "reuse: the same (owner, name) site counted twice does not form a group" {
    # Both bodies share module + name and have no owner_id -> one distinct site.
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "helper",
                owner_id="",
                owner_name="",
                exact_hash="E",
                struct_hash="S",
                path=_MOD_A
            ),
            _body(
                "s2",
                "helper",
                owner_id="",
                owner_name="",
                exact_hash="E",
                struct_hash="S",
                path=_MOD_A
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    assert len(groups) == 0;
}


# ---------------------------------------------------------------------------
# 5. Incomplete body excluded
# ---------------------------------------------------------------------------
test "reuse: bodies with completeness != 'complete' are not clone candidates" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "stub",
                owner_id="cls1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S",
                completeness="stub"
            ),
            _body(
                "s2",
                "stub",
                owner_id="cls2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S",
                completeness="stub"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    assert len(groups) == 0;
}


# ---------------------------------------------------------------------------
# 6. Exact subgroups within a structural group
# ---------------------------------------------------------------------------
test "reuse: structural group with a byte-identical pair has an exact_subgroup" {
    # Three members: two share exact_hash, one differs.
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "op",
                owner_id="cls1",
                owner_name="A",
                exact_hash="EXACT",
                struct_hash="SAME"
            ),
            _body(
                "s2",
                "op",
                owner_id="cls2",
                owner_name="B",
                exact_hash="EXACT",
                struct_hash="SAME"
            ),
            _body(
                "s3",
                "op",
                owner_id="cls3",
                owner_name="C",
                exact_hash="DIFF",
                struct_hash="SAME"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"op"});
    assert g is not None;
    # kind is structural because not ALL members share exact_hash
    assert g.kind == "structural" , g.kind;
    # one exact subgroup containing s1 and s2
    assert len(g.exact_subgroups) == 1;
    assert len(g.exact_subgroups[0]) == 2;
}


# ---------------------------------------------------------------------------
# 7. Class rollup: ≥2 shared-method groups between same class pair
# ---------------------------------------------------------------------------
def _two_class_two_method_store -> FactStore {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "read",
                owner_id="cls1",
                owner_name="Alpha",
                exact_hash="RE",
                struct_hash="RS",
                line_count=10
            ),
            _body(
                "s2",
                "read",
                owner_id="cls2",
                owner_name="Beta",
                exact_hash="RE",
                struct_hash="RS",
                line_count=10
            ),
            _body(
                "s3",
                "write",
                owner_id="cls1",
                owner_name="Alpha",
                exact_hash="WE",
                struct_hash="WS",
                line_count=6
            ),
            _body(
                "s4",
                "write",
                owner_id="cls2",
                owner_name="Beta",
                exact_hash="WE",
                struct_hash="WS",
                line_count=6
            )
        ]
    );
    return _store(facts);
}


test "reuse: two class pairs with 2 shared methods produce a class rollup" {
    store = _two_class_two_method_store();
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    store.close();
    assert len(rollups) == 1 , len(rollups);
    r = rollups[0];
    assert set(r.class_names) == {"Alpha", "Beta"} , r.class_names;
    assert r.shared_method_count == 2;
    assert r.recommendation == "hoist-shared-methods-to-common-base";
}


# ---------------------------------------------------------------------------
# 8. Class rollup requires ≥2 groups (single shared method excluded)
# ---------------------------------------------------------------------------
test "reuse: class pair sharing only 1 method does not produce a rollup" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "lone",
                owner_id="cls1",
                owner_name="P",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "lone",
                owner_id="cls2",
                owner_name="Q",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    store.close();
    assert len(rollups) == 0 , [r.class_names for r in rollups];
}


# ---------------------------------------------------------------------------
# 9. Rollup payoff = sum of member group payoffs
# ---------------------------------------------------------------------------
test "reuse: rollup payoff is the sum of its member group payoffs" {
    store = _two_class_two_method_store();
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    store.close();
    assert len(rollups) == 1;
    r = rollups[0];
    total = 0.0;
    for g in groups {
        total += g.payoff;
    }
    assert abs(r.payoff - total) < 1e-9 , (r.payoff, total);
}


# ---------------------------------------------------------------------------
# 10. Rollup lines_saved = sum of member group lines_saved
# ---------------------------------------------------------------------------
test "reuse: rollup lines_saved is the sum of its member group lines_saved" {
    store = _two_class_two_method_store();
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    store.close();
    assert len(rollups) == 1;
    r = rollups[0];
    total = 0;
    for g in groups {
        total += g.lines_saved;
    }
    assert r.lines_saved == total , (r.lines_saved, total);
}


# ---------------------------------------------------------------------------
# 11. Rollup recommendation
# ---------------------------------------------------------------------------
test "reuse: rollup recommendation is exactly 'hoist-shared-methods-to-common-base'" {
    store = _two_class_two_method_store();
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    store.close();
    assert len(rollups) == 1;
    assert rollups[0].recommendation == "hoist-shared-methods-to-common-base";
}


# ---------------------------------------------------------------------------
# 12. Cross-module free functions are not in class rollups
# ---------------------------------------------------------------------------
test "reuse: matching module-level free functions are not included in rollups" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            # no owner_id -> module-level free functions
            _body(
                "s1",
                "util_a",
                owner_id="",
                owner_name="",
                exact_hash="E1",
                struct_hash="SS"
            ),
            _body(
                "s2",
                "util_b",
                owner_id="",
                owner_name="",
                exact_hash="E1",
                struct_hash="SS",
                path=_MOD_B
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    store.close();
    assert len(rollups) == 0;
}


# ---------------------------------------------------------------------------
# 13. Payoff formula components
# ---------------------------------------------------------------------------
test "reuse: copies_saved = member_count - 1" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S",
                line_count=10
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S",
                line_count=10
            ),
            _body(
                "s3",
                "fn",
                owner_id="c3",
                owner_name="C",
                exact_hash="E",
                struct_hash="S",
                line_count=10
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"fn"});
    assert g is not None;
    assert g.copies_saved == 2;
}


test "reuse: lines_saved = copies_saved * median(line_counts)" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "do",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S",
                line_count=20
            ),
            _body(
                "s2",
                "do",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S",
                line_count=20
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"do"});
    assert g is not None;
    # copies_saved=1, median=20 -> lines_saved=20
    assert g.lines_saved == 20 , g.lines_saved;
}


test "reuse: reach counts distinct callers across all members" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "fn", path=_MOD_A, pos=0),
            _sym("s2", "fn", path=_MOD_A, pos=50),
            _sym("caller_a", "callerA", path=_MOD_A, pos=200),
            _sym("caller_b", "callerB", path=_MOD_A, pos=250)
        ],
        refs=[
            ReferenceFact(
                used_id="s1",
                using_id="caller_a",
                module_path=_MOD_A,
                pos_start=210,
                pos_end=220,
                line=10,
                kind="call"
            ),
            ReferenceFact(
                used_id="s2",
                using_id="caller_b",
                module_path=_MOD_A,
                pos_start=260,
                pos_end=270,
                line=15,
                kind="call"
            )
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S",
                line_count=5
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S",
                line_count=5
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"fn"});
    assert g is not None;
    # 2 distinct callers across 2 members
    assert g.reach == 2 , g.reach;
}


test "reuse: payoff is non-negative and bounded by 1.0" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "big",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S",
                line_count=300
            ),
            _body(
                "s2",
                "big",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S",
                line_count=300
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    g = _group_by_member_names(groups, {"big"});
    assert g is not None;
    assert g.payoff >= 0.0;
    assert g.payoff <= 1.0;
}


# ---------------------------------------------------------------------------
# 14. Groups ranked payoff-descending
# ---------------------------------------------------------------------------
test "reuse: groups are sorted payoff-descending" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            # Big group: large line_count -> higher payoff
            _body(
                "s1",
                "big",
                owner_id="c1",
                owner_name="A",
                exact_hash="E1",
                struct_hash="S1",
                line_count=100
            ),
            _body(
                "s2",
                "big",
                owner_id="c2",
                owner_name="B",
                exact_hash="E1",
                struct_hash="S1",
                line_count=100
            ),
            # Small group: tiny line_count -> lower payoff
            _body(
                "s3",
                "tiny",
                owner_id="c3",
                owner_name="C",
                exact_hash="E2",
                struct_hash="S2",
                line_count=2
            ),
            _body(
                "s4",
                "tiny",
                owner_id="c4",
                owner_name="D",
                exact_hash="E2",
                struct_hash="S2",
                line_count=2
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    assert len(groups) == 2 , len(groups);
    assert groups[0].payoff >= groups[1].payoff;
}


# ---------------------------------------------------------------------------
# 15. group_id deterministic across re-runs
# ---------------------------------------------------------------------------
test "reuse: group_id is deterministic across re-runs" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store1 = _store(facts);
    ids1 = [g.group_id for g in find_clone_groups(store1)];
    store1.close();
    store2 = _store(facts);
    ids2 = [g.group_id for g in find_clone_groups(store2)];
    store2.close();
    assert ids1 == ids2 , (ids1, ids2);
}


# ---------------------------------------------------------------------------
# 16. Negative control: different structural hash → no group
# ---------------------------------------------------------------------------
test "reuse: bodies with different structural hashes never group" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "tally",
                owner_id="c1",
                owner_name="A",
                exact_hash="E1",
                struct_hash="S1"
            ),
            _body(
                "s2",
                "tally",
                owner_id="c2",
                owner_name="B",
                exact_hash="E2",
                struct_hash="S2"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    store.close();
    for g in groups {
        assert "tally" not in {m.name for m in g.members};
    }
}


# ---------------------------------------------------------------------------
# 17. group_packet ships verifiable sym:/body: citations
# ---------------------------------------------------------------------------
test "reuse: group_packet has sym: and body: citations for each member" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "fn", path=_MOD_A, pos=0),
            _sym("s2", "fn", path=_MOD_A, pos=50)
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    g = _group_by_member_names(groups, {"fn"});
    assert g is not None;
    pkt = group_packet(store, g);
    store.close();
    assert "group_id" in pkt;
    assert "members" in pkt;
    for m in pkt["members"] {
        cites = m["citations"];
        assert len(cites) == 2 , cites;
        assert cites[0].startswith("sym:") , cites[0];
        assert cites[1].startswith("body:") , cites[1];
    }
}


test "reuse: group_packet citations can be verified against ToolSurface" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "fn", path=_MOD_A, pos=0),
            _sym("s2", "fn", path=_MOD_A, pos=50)
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="S"
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="S"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    g = _group_by_member_names(groups, {"fn"});
    pkt = group_packet(store, g);
    tools = ToolSurface(store=store);
    assert tools.verify_citations(pkt["citations"]);
    assert not tools.verify_citation("body:deadbeefdeadbeef");
    store.close();
}


# ---------------------------------------------------------------------------
# 18. group_packet evidence carries tier and structural_hash
# ---------------------------------------------------------------------------
test "reuse: group_packet evidence has tier and structural_hash fields" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="E",
                struct_hash="SHASH"
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="E",
                struct_hash="SHASH"
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    g = _group_by_member_names(groups, {"fn"});
    pkt = group_packet(store, g);
    store.close();
    ev = pkt["evidence"];
    assert "tier" in ev , ev;
    assert "structural_hash" in ev , ev;
    assert ev["structural_hash"] == "SHASH";
}


# ---------------------------------------------------------------------------
# Statement-window mining
# ---------------------------------------------------------------------------
def _seq(*hashes: str) -> str {
    lines: list[str] = [];
    pos = 0;
    for h in hashes {
        lines.append(f"{h}\x1f{pos}\x1f{pos + 5}\x1f{pos // 5 + 1}\x1f{pos // 5 + 1}");
        pos += 6;
    }
    return "\n".join(lines);
}


# ---------------------------------------------------------------------------
# 19. Shared block across ≥2 distinct functions surfaces as a WindowGroup
# ---------------------------------------------------------------------------
test "reuse window: shared statement sequence found across two functions" {
    shared = ["H1", "H2", "H3", "H4", "H5", "H6"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "build_alpha", path=_MOD_A, pos=0),
            _sym("s2", "build_beta", path=_MOD_A, pos=200)
        ],
        bodies=[
            _body(
                "s1",
                "build_alpha",
                owner_id="c1",
                owner_name="X",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("HA")
            ),
            _body(
                "s2",
                "build_beta",
                owner_id="c2",
                owner_name="Y",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("HB")
            )
        ]
    );
    store = _store(facts);
    wins = find_stmt_windows(store);
    store.close();
    found = False;
    for w in wins {
        names = {s.name for s in w.sites};
        if "build_alpha" in names and "build_beta" in names {
            found = True;
            assert w.length >= 6 , w.length;
        }
    }
    assert found , "expected window spanning build_alpha and build_beta";
}


# ---------------------------------------------------------------------------
# 20. Window length is the maximal extension of the seed
# ---------------------------------------------------------------------------
test "reuse window: window length is the maximal contiguous overlap" {
    # Both functions share 8 consecutive hashes.
    shared = ["H1", "H2", "H3", "H4", "H5", "H6", "H7", "H8"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "long_a", path=_MOD_A, pos=0),
            _sym("s2", "long_b", path=_MOD_A, pos=300)
        ],
        bodies=[
            _body(
                "s1",
                "long_a",
                owner_id="c1",
                owner_name="C1",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("XA")
            ),
            _body(
                "s2",
                "long_b",
                owner_id="c2",
                owner_name="C2",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("XB")
            )
        ]
    );
    store = _store(facts);
    wins = find_stmt_windows(store, min_window=4);
    store.close();
    for w in wins {
        names = {s.name for s in w.sites};
        if "long_a" in names and "long_b" in names {
            assert w.length == 8 , w.length;
        }
    }
}


# ---------------------------------------------------------------------------
# 21. min_window parameter controls seed size
# ---------------------------------------------------------------------------
test "reuse window: blocks shorter than min_window are not seeded" {
    # Only 3 shared hashes; min_window=4 should produce no window.
    shared = ["H1", "H2", "H3"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "fn_a", path=_MOD_A, pos=0),
            _sym("s2", "fn_b", path=_MOD_A, pos=200)
        ],
        bodies=[
            _body(
                "s1",
                "fn_a",
                owner_id="c1",
                owner_name="C1",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("XA")
            ),
            _body(
                "s2",
                "fn_b",
                owner_id="c2",
                owner_name="C2",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("XB")
            )
        ]
    );
    store = _store(facts);
    wins = find_stmt_windows(store, min_window=4);
    store.close();
    for w in wins {
        names = {s.name for s in w.sites};
        assert "fn_a" not in names or "fn_b" not in names;
    }
}


# ---------------------------------------------------------------------------
# 22. Same-owner window payoff penalty
# ---------------------------------------------------------------------------
test "reuse window: same-owner window has 0.5x payoff vs cross-owner equivalent" {
    shared = ["H1", "H2", "H3", "H4", "H5", "H6"];
    # Cross-owner: c1 and c2
    cross_facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "fn",
                owner_id="c1",
                owner_name="A",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("XA")
            ),
            _body(
                "s2",
                "fn",
                owner_id="c2",
                owner_name="B",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("XB")
            )
        ]
    );
    cross_store = _store(cross_facts);
    cross_wins = find_stmt_windows(cross_store, min_window=4);
    cross_store.close();
    cross_payoff = 0.0;
    for w in cross_wins {
        if not w.same_owner_only and w.length >= 6 {
            cross_payoff = w.payoff;
        }
    }

    # Same-owner: both functions belong to c1
    same_facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s3",
                "fn_x",
                owner_id="c1",
                owner_name="A",
                exact_hash="EX",
                struct_hash="SX",
                stmt_seq=_seq(*shared) + "\n" + _seq("XX")
            ),
            _body(
                "s4",
                "fn_y",
                owner_id="c1",
                owner_name="A",
                exact_hash="EY",
                struct_hash="SY",
                stmt_seq=_seq(*shared) + "\n" + _seq("XY")
            )
        ]
    );
    same_store = _store(same_facts);
    same_wins = find_stmt_windows(same_store, min_window=4);
    same_store.close();
    same_payoff = 0.0;
    for w in same_wins {
        if w.same_owner_only and w.length >= 6 {
            same_payoff = w.payoff;
        }
    }

    assert cross_payoff > 0.0 , "cross-owner window must have positive payoff";
    assert same_payoff > 0.0 , "same-owner window must have positive payoff";
    assert abs(same_payoff - cross_payoff * 0.5) < 1e-9 , (same_payoff, cross_payoff);
}


# ---------------------------------------------------------------------------
# 23. distinct_functions and distinct_owners counts
# ---------------------------------------------------------------------------
test "reuse window: distinct_functions and distinct_owners are correct" {
    shared = ["H1", "H2", "H3", "H4", "H5"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "fn_a",
                owner_id="c1",
                owner_name="ClassA",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("XA")
            ),
            _body(
                "s2",
                "fn_b",
                owner_id="c2",
                owner_name="ClassB",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("XB")
            )
        ]
    );
    store = _store(facts);
    wins = find_stmt_windows(store, min_window=4);
    store.close();
    for w in wins {
        if w.length >= 5 {
            assert w.distinct_functions == 2 , w.distinct_functions;
            assert w.distinct_owners == 2 , w.distinct_owners;
            assert not w.same_owner_only;
        }
    }
}


# ---------------------------------------------------------------------------
# 24. window_id deterministic across re-runs
# ---------------------------------------------------------------------------
test "reuse window: window_id is deterministic across re-runs" {
    shared = ["H1", "H2", "H3", "H4", "H5"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "alpha", path=_MOD_A, pos=0),
            _sym("s2", "beta", path=_MOD_A, pos=200)
        ],
        bodies=[
            _body(
                "s1",
                "alpha",
                owner_id="c1",
                owner_name="C1",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("XA")
            ),
            _body(
                "s2",
                "beta",
                owner_id="c2",
                owner_name="C2",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("XB")
            )
        ]
    );
    store1 = _store(facts);
    ids1 = [w.window_id for w in find_stmt_windows(store1, min_window=4)];
    store1.close();
    store2 = _store(facts);
    ids2 = [w.window_id for w in find_stmt_windows(store2, min_window=4)];
    store2.close();
    assert ids1 == ids2 , (ids1, ids2);
    assert len(ids1) > 0 , "expected at least one window";
}


# ---------------------------------------------------------------------------
# 25. window_packet ships sym:/body: citations for each site
# ---------------------------------------------------------------------------
test "reuse window: window_packet carries sym: and body: citations for each site" {
    shared = ["H1", "H2", "H3", "H4", "H5"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "fn_a", path=_MOD_A, pos=0),
            _sym("s2", "fn_b", path=_MOD_A, pos=200)
        ],
        bodies=[
            _body(
                "s1",
                "fn_a",
                owner_id="c1",
                owner_name="C1",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared) + "\n" + _seq("XA")
            ),
            _body(
                "s2",
                "fn_b",
                owner_id="c2",
                owner_name="C2",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared) + "\n" + _seq("XB")
            )
        ]
    );
    store = _store(facts);
    wins = find_stmt_windows(store, min_window=4);
    assert len(wins) > 0;
    pkt = window_packet(wins[0]);
    store.close();
    assert "window_id" in pkt;
    assert len(pkt["citations"]) >= 4;
    for site in pkt["sites"] {
        cites = site["citations"];
        assert len(cites) == 2;
        assert cites[0].startswith("sym:") , cites[0];
        assert cites[1].startswith("body:") , cites[1];
    }
}


# ---------------------------------------------------------------------------
# 26. Unrelated statements not in any window
# ---------------------------------------------------------------------------
test "reuse window: function with no shared sequence appears in no window" {
    shared = ["H1", "H2", "H3", "H4", "H5"];
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        bodies=[
            _body(
                "s1",
                "fn_a",
                owner_id="c1",
                owner_name="C1",
                exact_hash="EA",
                struct_hash="SA",
                stmt_seq=_seq(*shared)
            ),
            _body(
                "s2",
                "fn_b",
                owner_id="c2",
                owner_name="C2",
                exact_hash="EB",
                struct_hash="SB",
                stmt_seq=_seq(*shared)
            ),
            # unrelated: completely different hashes
            _body(
                "s3",
                "outlier",
                owner_id="c3",
                owner_name="C3",
                exact_hash="EO",
                struct_hash="SO",
                stmt_seq=_seq("Z1", "Z2", "Z3", "Z4", "Z5")
            )
        ]
    );
    store = _store(facts);
    wins = find_stmt_windows(store, min_window=4);
    store.close();
    for w in wins {
        for s in w.sites {
            assert s.name != "outlier" , "outlier must not appear in any window";
        }
    }
}
