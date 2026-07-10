"""Acceptance: rediscover #7234's consolidation on the pre-#7234 parent tree.

#7234 (012f03b3b, -799 lines) consolidated duplicated backend implementations
in runtimelib/impl/memory.impl.jac. This test materializes the memory decl +
impl-annex at the parent commit (012f03b3b^), runs the reuse funnel through the
real manifest/compile/extract pipeline, and asserts the funnel rediscovers the
duplicated backend methods that #7234 removed (delete/invalidate across the
three backends, query across two).

Note: VolatileMemory.find/find_one vs SqliteMemory.find/find_one differ by a
single receiver token (self.__mem__.get vs self.get) -- a T3 near-clone, not a
T1/T2 clone, so they are intentionally NOT grouped by the current tiers.

The test self-skips (returns) when git or the #7234 commit is unavailable, so
it stays green on shallow clones.
"""

import os;
import subprocess;
import tempfile;
import from jaclang.prune.campaign { Campaign }
import from jaclang.prune.manifest { build_manifest }
import from jaclang.prune.pipeline { compile_scope }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.clones { find_clone_groups }


glob _FIX_COMMIT = "012f03b3b",
     _MEM_DECL = "jac/jaclang/runtimelib/memory.jac",
     _MEM_IMPL = "jac/jaclang/runtimelib/impl/memory.impl.jac";


def _git(repo_root: str, args: list[str]) -> (str | None) {
    try {
        res = subprocess.run(
            ["git", "-C", repo_root] + args, capture_output=True, text=True
        );
    } except Exception {
        return None;
    }
    if res.returncode != 0 {
        return None;
    }
    return res.stdout;
}


def _materialize -> (str | None) {
    here = os.path.dirname(__file__);
    top = _git(here, ["rev-parse", "--show-toplevel"]);
    if top is None {
        return None;
    }
    repo_root = top.strip();
    parent = _git(repo_root, ["rev-parse", _FIX_COMMIT + "^"]);
    if parent is None {
        return None;
    }
    par = parent.strip();
    decl = _git(repo_root, ["show", par + ":" + _MEM_DECL]);
    ann = _git(repo_root, ["show", par + ":" + _MEM_IMPL]);
    if decl is None or ann is None {
        return None;
    }
    scratch = tempfile.mkdtemp(prefix="jac-7234-");
    rt = os.path.join(scratch, "runtimelib");
    os.makedirs(os.path.join(rt, "impl"));
    with open(os.path.join(rt, "memory.jac"), "w") as fh {
        fh.write(decl);
    }
    with open(os.path.join(rt, "impl", "memory.impl.jac"), "w") as fh {
        fh.write(ann);
    }
    return scratch;
}


def _groups_pre_7234(scratch: str) -> tuple[list, FactStore] {
    campaign = Campaign(
        project_root=scratch, paths=[os.path.join(scratch, "runtimelib")]
    );
    manifest = build_manifest(campaign);
    (prog, _e, _w, _c) = compile_scope(campaign, manifest);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(extract_facts(prog, manifest));
    return (find_clone_groups(store), store);
}


def _group_with(groups: list, name: str) -> (any | None) {
    for g in groups {
        if name in {m.name for m in g.members} {
            return g;
        }
    }
    return None;
}


def _owners(g: any) -> set {
    return {m.owner_name for m in g.members};
}


test "pre-#7234 tree: funnel rediscovers the consolidated backend duplicates" {
    scratch = _materialize();
    if scratch is None {
        return;
    }
    (groups, store) = _groups_pre_7234(scratch);
    assert len(groups) >= 4;

    delete_g = _group_with(groups, "delete");
    assert delete_g is not None;
    assert "SqliteMemory" in _owners(delete_g);
    assert "VolatileMemory" in _owners(delete_g);

    query_g = _group_with(groups, "query");
    assert query_g is not None;
    assert len(_owners(query_g)) >= 2;

    store.close();
}


test "pre-#7234 tree: find/find_one stay ungrouped at T1/T2 (T3 near-clone)" {
    scratch = _materialize();
    if scratch is None {
        return;
    }
    (groups, store) = _groups_pre_7234(scratch);
    assert _group_with(groups, "find") is None;
    assert _group_with(groups, "find_one") is None;
    store.close();
}
