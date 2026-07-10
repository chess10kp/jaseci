"""Statement-window mining tests.

Compiles the window fixture and asserts the miner surfaces the shared
six-statement opening block across build_alpha/build_beta, with correct
site spans, and that window ids are deterministic across a re-run.
"""

import os;
import from typing { LiteralString, cast }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.prune.manifest { Manifest, ManifestEntry, FileRole }
import from jaclang.prune.extract { extract_facts }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.windows { find_stmt_windows, window_packet }


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
    man = Manifest(
        project_root=os.path.dirname(key),
        entries=[
            ManifestEntry(
                path=key,
                role=FileRole.SOURCE,
                content_hash="x",
                module_name=basename[:-4]
            )
        ]
    );
    store = FactStore(db_path=":memory:");
    store.open();
    store.sync(extract_facts(prog, man));
    return store;
}


def _window_by_names(wins: list, names: set) -> (any | None) {
    for w in wins {
        got = {s.name for s in w.sites};
        if got == names {
            return w;
        }
    }
    return None;
}


test "shared opening block surfaces as a statement window across two functions" {
    store = _fixture("windowprog.jac");
    wins = find_stmt_windows(store);
    w = _window_by_names(wins, {"build_alpha", "build_beta"});
    assert w is not None;
    assert w.length == 6;
    assert w.distinct_functions == 2;
    assert len(w.sites) == 2;
    for s in w.sites {
        assert s.line_end > s.line_start;
        assert s.pos_end > s.pos_start;
    }
    store.close();
}


test "unrelated function shares no window" {
    store = _fixture("windowprog.jac");
    wins = find_stmt_windows(store);
    for w in wins {
        names = {s.name for s in w.sites};
        assert "unrelated" not in names;
    }
    store.close();
}


test "window packet carries citations and stable ids across a re-run" {
    store = _fixture("windowprog.jac");
    w1 = _window_by_names(find_stmt_windows(store), {"build_alpha", "build_beta"});
    w2 = _window_by_names(find_stmt_windows(store), {"build_alpha", "build_beta"});
    assert w1 is not None and w2 is not None;
    assert w1.window_id == w2.window_id;
    pkt = window_packet(w1);
    assert pkt["window_id"] == w1.window_id;
    assert len(pkt["citations"]) >= 4;
    assert pkt["sites"][0]["body_file"];
    store.close();
}
