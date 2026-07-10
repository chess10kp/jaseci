"""R-A structural-duplicate funnel tests.

Compiles the clone fixtures, extracts body facts, syncs them, and runs the
candidate funnel. Pins the three #7234 clone shapes (exact cross-class,
structural constant-diff, impl-annex), the negative control, exact-in-
structural containment, class rollup, packet citations, and determinism.
"""

import os;
import hashlib;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { ToolSurface }
import from jaclang.prune.clones { find_clone_groups, find_class_rollups, group_packet }


def _fixture(basename: str) -> FactStore {
    fpath = os.path.join(os.path.dirname(__file__), "fixtures", basename);
    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=fpath,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = fpath;
    for k in prog.mod.hub.keys() {
        if k.endswith(basename) {
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
                path=key,
                role=FileRole.SOURCE,
                content_hash=h,
                module_name=basename[:-4]
            )
        ]
    );
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    return store;
}


def _group_by_names(groups: list, names: set) -> (any | None) {
    for g in groups {
        got = {m.name for m in g.members};
        if got == names {
            return g;
        }
    }
    return None;
}


test "exact cross-class clones group with a byte-identical subgroup" {
    store = _fixture("cloneprog.jac");
    groups = find_clone_groups(store);
    g = _group_by_names(groups, {"find"});
    assert g is not None;
    assert g.kind == "exact" , g.kind;
    owners = {m.owner_name for m in g.members};
    assert owners == {"VolatileStore", "SqliteStore"} , owners;
    # every member shares one exact subgroup (byte-identical)
    assert len(g.exact_subgroups) == 1;
    assert len(g.exact_subgroups[0]) == 2;
    assert g.copies_saved == 1;
    store.close();
}


test "structural constant-diff siblings group; vectors carry the deltas" {
    store = _fixture("cloneprog.jac");
    groups = find_clone_groups(store);
    g = _group_by_names(groups, {"emit_sub", "emit_super", "emit_disjoint"});
    assert g is not None;
    assert g.kind == "structural" , g.kind;
    # no byte-identical subgroup: the three differ in constants
    assert g.exact_subgroups == [] , g.exact_subgroups;
    assert g.copies_saved == 2;
    # the per-member vectors differ exactly at the relation constant
    tags = {m.vector[1] for m in g.members};
    assert tags == {"'ssub'", "'ssup'", "'sdis'"} , tags;
    store.close();
}


test "negative control: same-signature different behavior does not group" {
    store = _fixture("cloneprog.jac");
    groups = find_clone_groups(store);
    for g in groups {
        assert "tally" not in {m.name for m in g.members};
    }
    store.close();
}


test "impl-annex bodies group even though bytes live in the .impl.jac" {
    store = _fixture("annexprog.jac");
    groups = find_clone_groups(store);
    g = _group_by_names(groups, {"scan"});
    assert g is not None;
    assert g.kind == "exact";
    # the cited body span points at the annex file, not the decl file
    for m in g.members {
        assert m.body_file.endswith("annexprog.impl.jac") , m.body_file;
    }
    store.close();
}


test "class rollup recommends hoisting shared methods to a base" {
    store = _fixture("cloneprog.jac");
    groups = find_clone_groups(store);
    rollups = find_class_rollups(groups);
    assert len(rollups) == 1 , len(rollups);
    r = rollups[0];
    assert set(r.class_names) == {"VolatileStore", "SqliteStore"} , r.class_names;
    assert r.shared_method_count == 2 , r.shared_method_count;
    assert r.recommendation == "hoist-shared-methods-to-common-base";
    store.close();
}


test "packet ships verifiable citations; fabrications are rejected" {
    store = _fixture("cloneprog.jac");
    groups = find_clone_groups(store);
    tools = ToolSurface(store=store);
    g = _group_by_names(groups, {"find"});
    pkt = group_packet(store, cast(any, g));
    assert tools.verify_citations(pkt["citations"]);
    assert not tools.verify_citation("body:deadbeefdeadbeef");
    # every member carries a decl (sym:) and body (body:) citation
    for m in pkt["members"] {
        assert len(m["citations"]) == 2;
        assert m["citations"][0].startswith("sym:");
        assert m["citations"][1].startswith("body:");
    }
    store.close();
}


test "funnel is deterministic across a re-run" {
    store1 = _fixture("cloneprog.jac");
    ids1 = [g.group_id for g in find_clone_groups(store1)];
    store1.close();
    store2 = _fixture("cloneprog.jac");
    ids2 = [g.group_id for g in find_clone_groups(store2)];
    store2.close();
    assert ids1 == ids2 , (ids1, ids2);
    # three groups, ranked top-payoff first (structural emitters lead)
    assert len(ids1) == 3 , ids1;
}
