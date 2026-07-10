"""Consolidation dry-run (--probe) tests.

Compiles the probe fixture from a scratch copy (so the sandbox edits never
touch a tracked file), builds clone groups, and drives probe_group:
  - the exact cross-class group passes (byte-identical substitution is inert);
  - the type-divergent structural group fails at typecheck with a divergence
    pointer;
  - the fixture bytes are byte-identical after every probe (revert is total).
"""

import os;
import shutil;
import tempfile;
import hashlib;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.clones { find_clone_groups }
import from jaclang.prune.probe { probe_group }
import from jaclang.prune.validate { snapshot_baseline }


obj ProbeEnv {
    has path: str,
        prog: any,
        store: FactStore,
        groups: list;
}


def _sha(path: str) -> str {
    with open(path, "rb") as f {
        return hashlib.sha256(f.read()).hexdigest();
    }
}


def _setup -> ProbeEnv {
    src = os.path.join(os.path.dirname(__file__), "fixtures", "probeprog.jac");
    tmpdir = tempfile.mkdtemp(prefix="jac-probe-");
    dst = os.path.join(tmpdir, "probeprog.jac");
    shutil.copyfile(src, dst);

    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=dst,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = dst;
    for k in prog.mod.hub.keys() {
        if k.endswith("probeprog.jac") {
            key = cast(LiteralString, k);
        }
    }
    man = Manifest(
        project_root=os.path.dirname(key),
        entries=[
            ManifestEntry(
                path=key,
                role=FileRole.SOURCE,
                content_hash=_sha(key),
                module_name="probeprog"
            )
        ]
    );
    facts = extract_facts(prog, man);
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(facts);
    groups = find_clone_groups(store);
    return ProbeEnv(path=key, prog=prog, store=store, groups=groups);
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


test "exact clone group: probe passes (byte-identical substitution)" {
    env = _setup();
    grp = _group_by_names(env.groups, {"read"});
    assert grp is not None;
    baseline = snapshot_baseline([env.path]);
    outcome = probe_group(grp, [env.path], [], env.prog, baseline);
    assert outcome.status == "passed";
    for m in outcome.members {
        assert m.status == "passed";
    }
    env.store.close();
}


test "type-divergent structural group: probe fails at typecheck" {
    env = _setup();
    grp = _group_by_names(env.groups, {"widen_i", "widen_s"});
    assert grp is not None;
    baseline = snapshot_baseline([env.path]);
    outcome = probe_group(grp, [env.path], [], env.prog, baseline);
    assert outcome.status == "failed";
    failed = [
        m
        for m in outcome.members
        if m.status == "failed"
    ];
    assert len(failed) >= 1;
    assert failed[0].failed_stage == "typecheck";
    assert len(failed[0].new_diags) >= 1;
    env.store.close();
}


test "probe reverts the fixture bytes on every path" {
    env = _setup();
    before = _sha(env.path);
    baseline = snapshot_baseline([env.path]);
    for grp in env.groups {
        probe_group(grp, [env.path], [], env.prog, baseline);
    }
    after = _sha(env.path);
    assert before == after;
    env.store.close();
}


test "probe outcome serializes to a JSON-ready dict" {
    env = _setup();
    grp = _group_by_names(env.groups, {"read"});
    assert grp is not None;
    baseline = snapshot_baseline([env.path]);
    d = probe_group(grp, [env.path], [], env.prog, baseline).as_dict();
    assert d["group_id"] == grp.group_id;
    assert d["status"] == "passed";
    assert "members" in d;
    assert d["members"][0]["symbol_id"];
    env.store.close();
}
