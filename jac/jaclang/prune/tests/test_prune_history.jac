"""Tandem-edit + divergent-clone history tests (git as payoff/diff oracle).

Builds a throwaway git repo with a two-member clone group, commits a tandem
edit (both members) and then a solo edit (one member), and asserts the
co-change count, union, and last-divergent commit that group_history derives
from git log -L commit sets.
"""

import os;
import subprocess;
import tempfile;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.clones { find_clone_groups }
import from jaclang.prune.history { group_history }


glob _V1 = "def alpha() -> int {\n    x = 1;\n    return x;\n}\n\n"
     "def beta() -> int {\n    x = 1;\n    return x;\n}\n",
     _V2 = "def alpha() -> int {\n    x = 2;\n    return x;\n}\n\n"
     "def beta() -> int {\n    x = 2;\n    return x;\n}\n",
     _V3 = "def alpha() -> int {\n    x = 3;\n    return x;\n}\n\n"
     "def beta() -> int {\n    x = 2;\n    return x;\n}\n";


def _git(repo: str, args: list[str], date: str = "") {
    env = dict(os.environ);
    env["GIT_AUTHOR_NAME"] = "t";
    env["GIT_AUTHOR_EMAIL"] = "t@t";
    env["GIT_COMMITTER_NAME"] = "t";
    env["GIT_COMMITTER_EMAIL"] = "t@t";
    if date {
        env["GIT_AUTHOR_DATE"] = date;
        env["GIT_COMMITTER_DATE"] = date;
    }
    subprocess.run(["git", "-C", repo] + args, capture_output=True, text=True, env=env);
}


def _write(path: str, text: str) {
    with open(path, "w") as fh {
        fh.write(text);
    }
}


def _build_repo -> tuple[str, str] {
    repo = tempfile.mkdtemp(prefix="jac-hist-");
    fpath = os.path.join(repo, "twins.jac");
    _git(repo, ["init", "-q"]);
    _write(fpath, _V1);
    _git(repo, ["add", "twins.jac"]);
    _git(
        repo, ["commit", "-q", "-m", "c1 introduce twins"], date="2020-01-01T00:00:00"
    );
    _write(fpath, _V2);
    _git(repo, ["commit", "-qam", "c2 tandem bump"], date="2020-01-02T00:00:00");
    _write(fpath, _V3);
    _git(repo, ["commit", "-qam", "c3 solo drift alpha"], date="2020-01-03T00:00:00");
    return (repo, fpath);
}


def _group(fpath: str) -> tuple[any, FactStore] {
    prog = JacProgram();
    prog._track_dependencies = True;
    prog.compile(
        file_path=fpath,
        options=CompileOptions(type_check=True, no_cgen=True, force_target_program=True)
    );
    key = fpath;
    for k in prog.mod.hub.keys() {
        if k.endswith("twins.jac") {
            key = cast(LiteralString, k);
        }
    }
    man = Manifest(
        project_root=os.path.dirname(key),
        entries=[
            ManifestEntry(
                path=key, role=FileRole.SOURCE, content_hash="x", module_name="twins"
            )
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(extract_facts(prog, man));
    groups = find_clone_groups(store);
    grp = None;
    for g in groups {
        if {m.name for m in g.members} == {"alpha", "beta"} {
            grp = g;
        }
    }
    return (grp, store);
}


test "tandem-edit history counts co-change commits and the divergence point" {
    (repo, fpath) = _build_repo();
    (grp, store) = _group(fpath);
    assert grp is not None;
    h = group_history(grp, repo);
    assert h.available;
    assert h.union_commits == 3;
    assert h.tandem_commits == 2;
    assert 0.66 <= h.tandem_ratio <= 0.67;
    assert "c3" in h.last_divergent_subject;
    diverged = None;
    for m in grp.members {
        if m.symbol_id == h.last_divergent_member {
            diverged = m;
        }
    }
    assert diverged is not None;
    assert diverged.name == "alpha";
    store.close();
}


test "history is unavailable outside a git work tree" {
    (repo, fpath) = _build_repo();
    (grp, store) = _group(fpath);
    assert grp is not None;
    h = group_history(grp, tempfile.mkdtemp(prefix="jac-nogit-"));
    assert not h.available;
    store.close();
}
