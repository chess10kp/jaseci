"""Specification tests for packet-contract v2 §1.1 `cite_index`.

Pins the citation-legend resolver and its wiring into reuse packets:

  1.  cite_one on a `sym:` ID names kind, symbol, module and access.
  2.  cite_one on a `body:` ID reads the body stmt count.
  3.  cite_one on a `mod:` ID names the module.
  4.  cite_one on a `ref:` ID resolves the reference site.
  5.  cite_one with no prefix is treated as a `sym:` ID.
  6.  cite_one on an unresolvable ID returns 'unresolved citation'.
  7.  cite_index dedupes and returns one entry per unique citation.
  8.  cite_index is deterministic / order-independent.
  9.  group_packet carries a cite_index whose keys equal its citations set.

All tests use hand-built FactSets — no compilation pass needed.
"""

import from jaclang.prune.extract { FactSet, ModuleFact, SymbolFact, ReferenceFact }
import from jaclang.prune.bodies { BodyFact }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { cite_one, cite_index }
import from jaclang.prune.clones { find_clone_groups, group_packet }


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
    kind: str = "ability",
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
    path: str = _MOD_A
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
        arity=0,
        is_async=False,
        is_gen=False,
        stmt_count=stmt_count,
        line_count=line_count,
        size_band=1,
        completeness="complete",
        vector="",
        stmt_seq=""
    );
}


# ---------------------------------------------------------------------------
# 1. cite_one on a sym: ID names kind, symbol, module and access
# ---------------------------------------------------------------------------
test "cite_index: cite_one on sym: names kind, symbol, module, access" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one", kind="ability", access="pub", pos=117)]
    );
    store = _store(facts);
    line = cite_one(store, "sym:s1");
    store.close();
    assert line != "unresolved citation" , line;
    assert "find_one" in line , line;
    assert "ability" in line , line;
    assert _MOD_A in line , line;
    assert "pub" in line , line;
    assert "118" in line , line;
}


# ---------------------------------------------------------------------------
# 2. cite_one on a body: ID reads the body stmt count
# ---------------------------------------------------------------------------
test "cite_index: cite_one on body: reports the statement count" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one", pos=117)],
        bodies=[_body("s1", "find_one", stmt_count=12)]
    );
    store = _store(facts);
    line = cite_one(store, "body:s1");
    store.close();
    assert "body of find_one" in line , line;
    assert "12 stmts" in line , line;
    assert _MOD_A in line , line;
}


# ---------------------------------------------------------------------------
# 3. cite_one on a mod: ID names the module
# ---------------------------------------------------------------------------
test "cite_index: cite_one on mod: names the module" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one")]
    );
    store = _store(facts);
    line = cite_one(store, "mod:" + _MOD_A);
    store.close();
    assert "module a" in line , line;
    assert _MOD_A in line , line;
}


# ---------------------------------------------------------------------------
# 4. cite_one on a ref: ID resolves the reference site
# ---------------------------------------------------------------------------
test "cite_index: cite_one on ref: resolves the reference site" {
    ref = ReferenceFact(
        used_id="s1",
        using_id="s2",
        module_path=_MOD_A,
        pos_start=200,
        pos_end=210,
        line=42,
        kind="call"
    );
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one"), _sym("s2", "caller", pos=300)],
        refs=[ref]
    );
    store = _store(facts);
    line = cite_one(store, ref.id);
    store.close();
    assert line != "unresolved citation" , line;
    assert "reference" in line , line;
    assert _MOD_A in line , line;
    assert "42" in line , line;
}


# ---------------------------------------------------------------------------
# 5. cite_one with no prefix is treated as a sym: ID
# ---------------------------------------------------------------------------
test "cite_index: cite_one with no prefix falls back to a symbol lookup" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one")]
    );
    store = _store(facts);
    line = cite_one(store, "s1");
    store.close();
    assert "find_one" in line , line;
}


# ---------------------------------------------------------------------------
# 6. cite_one on an unresolvable ID returns 'unresolved citation'
# ---------------------------------------------------------------------------
test "cite_index: cite_one on unknown IDs returns 'unresolved citation'" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one")]
    );
    store = _store(facts);
    assert cite_one(store, "sym:ghost") == "unresolved citation";
    assert cite_one(store, "body:ghost") == "unresolved citation";
    assert cite_one(store, "mod:/proj/missing.jac") == "unresolved citation";
    assert cite_one(store, "ref:deadbeef") == "unresolved citation";
    assert cite_one(store, "dep:missing") == "unresolved citation";
    store.close();
}


# ---------------------------------------------------------------------------
# 7. cite_index dedupes and returns one entry per unique citation
# ---------------------------------------------------------------------------
test "cite_index: dedupes duplicate citation IDs" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one"), _sym("s2", "find_two", pos=50)],
        bodies=[_body("s1", "find_one"), _body("s2", "find_two")]
    );
    store = _store(facts);
    idx = cite_index(store, ["sym:s1", "sym:s1", "body:s1", "sym:s2", "sym:s2"]);
    store.close();
    assert len(idx) == 3 , idx;
    assert set(idx.keys()) == {"sym:s1", "body:s1", "sym:s2"} , idx;
    assert "find_one" in idx["sym:s1"];
    assert "find_two" in idx["sym:s2"];
}


# ---------------------------------------------------------------------------
# 8. cite_index is deterministic / order-independent
# ---------------------------------------------------------------------------
test "cite_index: is order-independent for the same citation set" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[_sym("s1", "find_one"), _sym("s2", "find_two", pos=50)]
    );
    store = _store(facts);
    a = cite_index(store, ["sym:s1", "sym:s2"]);
    b = cite_index(store, ["sym:s2", "sym:s1"]);
    store.close();
    assert a == b , (a, b);
}


# ---------------------------------------------------------------------------
# 9. group_packet carries a cite_index keyed by its citations
# ---------------------------------------------------------------------------
test "cite_index: group_packet cite_index keys equal its citations set" {
    facts = FactSet(
        modules=[
            ModuleFact(path=_MOD_A, module_name="a", content_hash="ha", role="source")
        ],
        symbols=[
            _sym("s1", "scan", access="pub", pos=0),
            _sym("s2", "scan", access="pub", pos=100)
        ],
        bodies=[
            _body(
                "s1",
                "scan",
                owner_id="cls1",
                owner_name="Alpha",
                exact_hash="EEE",
                struct_hash="SSS",
                stmt_count=7
            ),
            _body(
                "s2",
                "scan",
                owner_id="cls2",
                owner_name="Beta",
                exact_hash="EEE",
                struct_hash="SSS",
                stmt_count=7
            )
        ]
    );
    store = _store(facts);
    groups = find_clone_groups(store);
    assert len(groups) >= 1 , len(groups);
    pkt = group_packet(store, groups[0]);
    idx = pkt["cite_index"];
    cites = pkt["citations"];
    store.close();
    assert set(idx.keys()) == set(cites) , (sorted(idx.keys()), sorted(cites));
    for (cid, one) in idx.items() {
        assert one != "unresolved citation" , (cid, one);
        assert one , cid;
    }
}
