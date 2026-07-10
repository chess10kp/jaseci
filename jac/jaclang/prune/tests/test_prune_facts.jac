"""Phase-2 tests: fact extraction (golden dumps over a fixture program) and the
SQLite fact store (query helpers + module-granular staleness).

The golden test compiles `fixtures/factprog.jac`, extracts facts, and pins
symbol kinds, a specific def-use count, the read/write field split, and import
resolution. The store tests build hand-authored FactSets so query and staleness
behaviour is checked without a compile.
"""

import os;
import hashlib;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract {
    FactSet,
    ModuleFact,
    SymbolFact,
    ReferenceFact,
    ImportFact,
    FieldAccessFact,
    extract_facts
}
import from jaclang.prune.factstore { FactStore }


glob FIX_PATH = os.path.join(
         os.path.dirname(__file__), "fixtures", "factprog.jac"
     );


def _extract_fixture -> FactSet {
    # compile the fixture into its own program, then extract facts over a
    # single-source manifest keyed by the exact hub path (so in-scope checks
    # in the walker match).
    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=FIX_PATH,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = FIX_PATH;
    for k in prog.mod.hub.keys() {
        if k.endswith("factprog.jac") {
            key = cast(LiteralString, k);
        }
    }
    with open(key, "rb") as f {
        h = hashlib.sha256(f.read()).hexdigest();
    }
    man = Manifest(
        project_root=os.path.dirname(key),
        entries=[
            ManifestEntry(
                path=key, role=FileRole.SOURCE, content_hash=h, module_name="factprog"
            )
        ]
    );
    return extract_facts(prog, man);
}


def _sym_by_name(facts: FactSet, name: str) -> (SymbolFact | None) {
    for s in facts.symbols {
        if s.name == name {
            return s;
        }
    }
    return None;
}


test "extraction records symbols with their compiler kinds" {
    facts = _extract_fixture();
    kinds = {s.name: s.kind for s in facts.symbols};
    assert kinds.get("used_helper") == "ability" , kinds;
    assert kinds.get("Box") == "object" , kinds;
    assert kinds.get("stored") == "field" , kinds;
    assert kinds.get("writeonly") == "field" , kinds;
}


test "def-use: a helper called twice has use_count 2" {
    facts = _extract_fixture();
    helper = _sym_by_name(facts, "used_helper");
    assert helper is not None;
    helper = cast(SymbolFact, helper);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    assert store.use_count(helper.id) == 2;
    assert store.external_use_count(helper.id) == 2;
    store.close();
}


test "read/write split: write-only field has zero reads" {
    facts = _extract_fixture();
    stored = _sym_by_name(facts, "stored");
    writeonly = _sym_by_name(facts, "writeonly");
    assert stored is not None;
    assert writeonly is not None;
    stored = cast(SymbolFact, stored);
    writeonly = cast(SymbolFact, writeonly);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    # stored is read (peek) and written (fill); writeonly is only written
    assert store.field_rw_counts(stored.id) == (1, 1);
    assert store.field_rw_counts(writeonly.id) == (0, 1);
    store.close();
}


test "import resolution: an unused resolved import is flagged" {
    facts = _extract_fixture();
    sqrt_sym = None;
    for im in facts.imports {
        if im.item_name == "sqrt" {
            sqrt_sym = im;
        }
    }
    assert sqrt_sym is not None;
    sqrt_sym = cast(ImportFact, sqrt_sym);
    assert sqrt_sym.resolved_id != "";
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    names = {d["item_name"] for d in store.unused_import_items()};
    assert "sqrt" in names , names;
    store.close();
}


# ---- pure-store tests (no compile) ----
def _mini_factset(mod_hash: str) -> FactSet {
    # one module, one symbol used once from within itself
    fs = FactSet();
    fs.modules.append(
        ModuleFact(
            path="/x/m.jac",
            module_name="m",
            content_hash=mod_hash,
            role="source",
            deps=[],
            fact_hash=mod_hash
        )
    );
    fs.symbols.append(
        SymbolFact(
            id="sym1",
            module_path="/x/m.jac",
            name="foo",
            kind="ability",
            access="private",
            imported=False,
            parent_id="",
            decl_pos_start=0,
            decl_pos_end=10,
            decl_line=1,
            scope_chain="m"
        )
    );
    fs.refs.append(
        ReferenceFact(
            used_id="sym1",
            using_id="",
            module_path="/x/m.jac",
            pos_start=50,
            pos_end=53,
            line=5,
            kind="call"
        )
    );
    return fs;
}


test "staleness: unchanged module is skipped on re-sync" {
    store = FactStore(db_path=":memory:");
    store.open();
    (refreshed1, skipped1) = store.sync(_mini_factset("hashA"));
    assert refreshed1 == ["/x/m.jac"];
    assert skipped1 == [];
    # same content hash -> cached, no rewrite
    (refreshed2, skipped2) = store.sync(_mini_factset("hashA"));
    assert refreshed2 == [];
    assert skipped2 == ["/x/m.jac"];
    # changed content hash -> refreshed again
    (refreshed3, skipped3) = store.sync(_mini_factset("hashB"));
    assert refreshed3 == ["/x/m.jac"];
    store.close();
}


test "re-sync replaces a module's rows rather than duplicating them" {
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(_mini_factset("hashA"));
    store.sync(_mini_factset("hashB"));
    counts = store.counts();
    # exactly one symbol / one ref survive (old rows cleared before re-insert)
    assert counts["symbols"] == 1 , counts;
    assert counts["refs"] == 1 , counts;
    assert store.use_count("sym1") == 1;
    store.close();
}
