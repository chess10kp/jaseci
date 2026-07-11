"""T3 fuzzy (token-overlap) clone-tier tests.

Unit-tests the pure similarity helpers (shingling, Jaccard, bucket key,
group id) and drives the end-to-end tier over `fuzzyprog.jac`: a gapped clone
pair groups, a pure-structural (T2) pair is excluded, a dissimilar pair does
not group, the threshold gates membership, and the run is deterministic.
"""

import os;
import hashlib;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.fuzzy {
    find_fuzzy_clone_groups,
    fuzzy_packet,
    fuzzy_summary,
    _shingles,
    _jaccard,
    _bucket_key,
    _group_id
}


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


test "shingles are k-grams; a too-short stream is a single shingle" {
    sh = _shingles(["a", "b", "c", "d"], 3);
    assert sh == {"a\x1fb\x1fc", "b\x1fc\x1fd"} , sh;
    assert _shingles(["a", "b"], 3) == {"a\x1fb"};
    assert _shingles([], 3) == set();
}


test "jaccard is intersection-over-union; empty side is zero" {
    a = {"x", "y", "z"};
    b = {"y", "z", "w"};
    assert _jaccard(a, b) == 0.5 , _jaccard(a, b);
    assert _jaccard(a, a) == 1.0;
    assert _jaccard(a, set()) == 0.0;
    assert _jaccard(set(), set()) == 0.0;
}


test "bucket key partitions on arity, async, generator, size band" {
    r1 = {"arity": 2, "is_async": False, "is_gen": False, "size_band": 1};
    r2 = {"arity": 2, "is_async": False, "is_gen": False, "size_band": 1};
    r3 = {"arity": 2, "is_async": True, "is_gen": False, "size_band": 1};
    assert _bucket_key(r1) == _bucket_key(r2);
    assert _bucket_key(r1) != _bucket_key(r3);
}


test "group id is stable across member order and prefixed reuse:fzy:" {
    a = _group_id(["s2", "s1", "s3"], 0.8);
    b = _group_id(["s3", "s1", "s2"], 0.8);
    assert a == b , (a, b);
    assert a.startswith("reuse:fzy:");
    assert _group_id(["s1", "s2"], 0.8) != _group_id(["s1", "s2"], 0.9);
}


test "gapped clone pair forms the one fuzzy group" {
    store = _fixture("fuzzyprog.jac");
    (groups, skipped) = find_fuzzy_clone_groups(store);
    store.close();
    assert len(skipped) == 0 , skipped;
    assert len(groups) == 1 , [[m.name for m in g.members] for g in groups];
    g = groups[0];
    assert {m.name for m in g.members} == {"scan_wide", "scan_narrow"};
    assert g.kind == "fuzzy";
    assert len(g.structural_hashes) == 2 , g.structural_hashes;
    assert g.min_similarity >= 0.8 , g.min_similarity;
    assert g.mean_similarity >= 0.8;
    assert g.copies_saved == 1;
}


test "pure-structural (T2) pair is excluded from the fuzzy tier" {
    store = _fixture("fuzzyprog.jac");
    (groups, _skipped) = find_fuzzy_clone_groups(store);
    store.close();
    # price_a/price_b share one structural hash -> T2's job, never fuzzy.
    assert _group_by_names(groups, {"price_a", "price_b"}) is None;
}


test "dissimilar pair does not group" {
    store = _fixture("fuzzyprog.jac");
    (groups, _skipped) = find_fuzzy_clone_groups(store);
    store.close();
    assert _group_by_names(groups, {"far_a", "far_b"}) is None;
}


test "raising the threshold above the pair similarity drops the group" {
    store = _fixture("fuzzyprog.jac");
    (groups, _skipped) = find_fuzzy_clone_groups(store, threshold=0.95);
    store.close();
    assert len(groups) == 0 , [[m.name for m in g.members] for g in groups];
}


test "the run is deterministic (stable group ids across runs)" {
    store = _fixture("fuzzyprog.jac");
    (g1, _s1) = find_fuzzy_clone_groups(store);
    (g2, _s2) = find_fuzzy_clone_groups(store);
    store.close();
    assert [g.group_id for g in g1] == [g.group_id for g in g2];
}


test "packet carries per-member citations and similarity evidence" {
    store = _fixture("fuzzyprog.jac");
    (groups, _skipped) = find_fuzzy_clone_groups(store);
    g = groups[0];
    packet = fuzzy_packet(store, g);
    store.close();
    assert packet["tier"] == "fuzzy";
    assert packet["evidence"]["min_similarity"] >= 0.8;
    assert len(packet["structural_hashes"]) == 2;
    assert len(packet["members"]) == 2;
    for m in packet["members"] {
        assert ("body:" + str(m["symbol_id"])) in m["citations"];
    }
    assert ("sym:" + str(g.members[0].symbol_id)) in packet["citations"];
}


test "summary is machine-quiet and self-describing" {
    store = _fixture("fuzzyprog.jac");
    (groups, _skipped) = find_fuzzy_clone_groups(store);
    store.close();
    s = fuzzy_summary(groups[0]);
    assert s["kind"] == "fuzzy";
    assert s["member_count"] == 2;
    assert s["min_similarity"] >= 0.8;
    assert s["payoff"] >= 0.0;
}
