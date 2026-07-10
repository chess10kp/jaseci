"""R-1 correctness tests: scope safety, ordering, migration, completeness,
fact-hash staleness, and the ref/dep citation substrate.

These are pure-store tests over hand-authored FactSets (no compile) plus one
raw-sqlite migration test, so behaviour is checked deterministically without a
type-check pass.
"""

import os;
import sqlite3;
import tempfile;
import from jaclang.prune.extract {
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact,
    ImportFact,
    ref_fact_id,
    dep_fact_id
}
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { ToolSurface }


def _sym(sid: str, path: str, name: str) -> SymbolFact {
    return SymbolFact(
        id=sid,
        module_path=path,
        name=name,
        kind="ability",
        access="private",
        imported=False,
        parent_id="",
        decl_pos_start=0,
        decl_pos_end=10,
        decl_line=1,
        scope_chain=name
    );
}


def _ref(used: str, using: str, path: str, ps: int) -> ReferenceFact {
    return ReferenceFact(
        used_id=used,
        using_id=using,
        module_path=path,
        pos_start=ps,
        pos_end=ps + 3,
        line=ps,
        kind="call"
    );
}


def _two_module_facts -> FactSet {
    # Module A declares a1; module B declares b1 and calls a1 (cross-module).
    # A also calls a1 internally. B depends on A.
    fs = FactSet();
    fs.modules.append(
        ModuleFact(
            path="/x/a.jac",
            module_name="a",
            content_hash="ca",
            role="source",
            deps=[],
            fact_hash="fa"
        )
    );
    fs.modules.append(
        ModuleFact(
            path="/x/b.jac",
            module_name="b",
            content_hash="cb",
            role="source",
            deps=["/x/a.jac"],
            fact_hash="fb"
        )
    );
    fs.symbols.append(_sym("a1", "/x/a.jac", "afn"));
    fs.symbols.append(_sym("b1", "/x/b.jac", "bfn"));
    fs.refs.append(_ref("a1", "a1", "/x/a.jac", 50));  # A calls A
    fs.refs.append(_ref("a1", "b1", "/x/b.jac", 60));  # B calls A
    fs.refs.append(_ref("b1", "b1", "/x/b.jac", 70));  # B calls B
    return fs;
}


test "scope contamination: narrowing to A hides B's rows, edges, and counts" {
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(_two_module_facts());
    # full scope: a1 is used from both modules
    assert store.use_count("a1") == 2;
    assert sorted(store.callers_of("a1")) == ["a1", "b1"];
    # narrow to A only: the B->A reference and all B rows vanish
    store.set_scope(["/x/a.jac"]);
    assert store.use_count("a1") == 1;
    assert store.callers_of("a1") == ["a1"];
    det = {d["id"] for d in store.symbols_for_detection()};
    assert det == {"a1"} , det;
    # B's own outgoing dep edge is out of scope; A has none
    assert store.module_dep_edges() == [];
    # b1's self-call is invisible under scope A
    assert store.use_count("b1") == 0;
    store.close();
}


test "out-of-scope rows stay physically cached but invisible to queries" {
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(_two_module_facts());
    store.set_scope(["/x/a.jac"]);
    # scoped queries see only A ...
    assert len(store.symbols_for_detection()) == 1;
    # ... but the rows for B are still physically present in the DB
    counts = store.counts();
    assert counts["symbols"] == 2 , counts;
    assert counts["refs"] == 3 , counts;
    store.close();
}


test "fact-hash keys staleness, not content hash" {
    store = FactStore(db_path=":memory:");
    store.open();
    fs1 = FactSet();
    fs1.modules.append(
        ModuleFact(
            path="/x/m.jac",
            module_name="m",
            content_hash="SAME",
            role="source",
            deps=[],
            fact_hash="h1"
        )
    );
    (r1, s1) = store.sync(fs1);
    assert r1 == ["/x/m.jac"];
    # identical content hash, different fact hash -> must re-extract
    fs2 = FactSet();
    fs2.modules.append(
        ModuleFact(
            path="/x/m.jac",
            module_name="m",
            content_hash="SAME",
            role="source",
            deps=[],
            fact_hash="h2"
        )
    );
    (r2, s2) = store.sync(fs2);
    assert r2 == ["/x/m.jac"] , (r2, s2);
    # unchanged fact hash -> skipped
    (r3, s3) = store.sync(fs2);
    assert s3 == ["/x/m.jac"] , (r3, s3);
    store.close();
}


test "ordering is stable across a DB reopen" {
    tmpdir = tempfile.mkdtemp();
    db = os.path.join(tmpdir, "prune.db");
    store = FactStore(db_path=db);
    store.open();
    store.sync(_two_module_facts());
    order1 = [d["id"] for d in store.symbols_for_detection()];
    edges1 = store.call_edges();
    store.close();
    # reopen: same ordered results, no reliance on insertion order
    store2 = FactStore(db_path=db);
    store2.open();
    store2.set_scope(["/x/a.jac", "/x/b.jac"]);
    order2 = [d["id"] for d in store2.symbols_for_detection()];
    edges2 = store2.call_edges();
    assert order1 == order2 , (order1, order2);
    assert edges1 == edges2 , (edges1, edges2);
    store2.close();
}


test "schema/version mismatch auto-rebuilds without manual deletion" {
    tmpdir = tempfile.mkdtemp();
    db = os.path.join(tmpdir, "prune.db");
    # seed a stale, incompatible DB: an old `modules` shape and a wrong version
    raw = sqlite3.connect(db);
    raw.executescript(
        "CREATE TABLE modules(path TEXT PRIMARY KEY, content_hash TEXT);"
        "CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT);"
        "INSERT INTO meta(key, value) VALUES('version', '0/0');"
    );
    raw.commit();
    raw.close();
    # opening rebuilds the fact tables; a sync into the new shape must succeed
    store = FactStore(db_path=db);
    store.open();
    (refreshed, skipped) = store.sync(_two_module_facts());
    assert sorted(refreshed) == ["/x/a.jac", "/x/b.jac"];
    assert store.module_status("/x/a.jac")["status"] == "complete";
    store.close();
}


test "per-module completeness/status round-trips" {
    store = FactStore(db_path=":memory:");
    store.open();
    fs = FactSet();
    fs.modules.append(
        ModuleFact(
            path="/x/ok.jac",
            module_name="ok",
            content_hash="c1",
            role="source",
            deps=[],
            fact_hash="f1"
        )
    );
    fs.modules.append(
        ModuleFact(
            path="/x/bad.jac",
            module_name="bad",
            content_hash="c2",
            role="source",
            deps=[],
            fact_hash="f2",
            status="error",
            error_count=3
        )
    );
    store.sync(fs);
    assert store.module_status("/x/ok.jac") == {"status": "complete", "error_count": 0};
    assert store.module_status("/x/bad.jac") == {"status": "error", "error_count": 3};
    store.close();
}


test "citation substrate verifies ref:/dep:/sym: and rejects fabrications" {
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(_two_module_facts());
    tools = ToolSurface(store=store);
    # a real ref edge (B calls A at pos 60) verifies by its prefixed id
    real_ref = ref_fact_id("a1", "b1", "/x/b.jac", "call", 60, 63);
    assert tools.verify_citation(real_ref);
    # a real dependency edge B -> A
    real_dep = dep_fact_id("/x/b.jac", "/x/a.jac");
    assert tools.verify_citation(real_dep);
    # symbol citations: prefixed and bare both readable
    assert tools.verify_citation("sym:a1");
    assert tools.verify_citation("a1");
    # fabrications are rejected, and one bad member fails the whole bundle
    assert not tools.verify_citation("ref:deadbeefdeadbeef");
    assert not tools.verify_citation("dep:0000000000000000");
    assert not tools.verify_citation("sym:nonexistent");
    assert not tools.verify_citations([real_ref, "ref:deadbeefdeadbeef"]);
    assert tools.verify_citations([real_ref, real_dep, "a1"]);
    store.close();
}
