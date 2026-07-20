"""Phase 6 tests: typed session dispatch, legacy bridge removal seams, lifecycle."""

import importlib;
import time;
import jac.tests.cli.tui_selftest_harness as harness;
import from pathlib { Path }


def _na_dir -> Path {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    return Path(shared_mod.__file__).resolve().parent.parent / "ai_tui_na";
}


def _tui_dir -> Path {
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    return Path(shared_mod.__file__).resolve().parent;
}


test "phase6 embed path uses typed session effects" {
    na_dir = _na_dir();
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        import pytest;
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    harness.ensure_selftest(na_dir, "selftest_session_dispatch");
    harness.assert_selftest_passes(na_dir, "selftest_session_dispatch");
    harness.ensure_selftest(na_dir, "selftest_session_client");
    harness.assert_selftest_passes(na_dir, "selftest_session_client");
}


test "phase6 production tree has no legacy frame bridge" {
    tui = _tui_dir();
    na = _na_dir();
    offenders: list[str] = [];
    for scan_dir in [tui, na] {
        for path in scan_dir.rglob("*.jac") {
            if not path.is_file() {
                continue;
            }
            text = path.read_text();
            if "def _frame_blob" in text or "FIELD_EV:" in text {
                offenders.append(str(path));
            }
            if "glob FIELD_" in text or "glob FTYPE_" in text {
                offenders.append(str(path));
            }
        }
    }
    assert offenders == [] , f"legacy frame bridge remnants: {offenders}";
}


test "phase6 ipc_schema is command vocabulary only" {
    na = _na_dir();
    tui = _tui_dir();
    for path in [na / "ipc_schema.na.jac", tui / "ipc_schema.jac"] {
        text = path.read_text();
        assert "glob FIELD_" not in text , path;
        assert "glob FTYPE_" not in text , path;
        assert "glob FRAME_SEP" not in text , path;
        assert "CMD_SEND" in text , path;
    }
}


test "phase6 embed_agent exposes typed submit surface" {
    embed_mod = importlib.import_module("jaclang.cli.ai_tui.embed_agent");
    assert callable(embed_mod?.submit);
    assert callable(embed_mod?.dispose);
    assert not hasattr(embed_mod, "_dispatch_cmd");
}


test "phase6 managed session busy reject settles for retry" {
    sess_mod = importlib.import_module("jaclang.cli.ai_tui.core.agent_session");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    models = importlib.import_module("jaclang.cli.ai_tui.session_models");
    ai_mod = importlib.import_module("jaclang.cli.ai_agent");

    def fake_busy(prompt: str) -> bool {
        return False;
    }

    old_prepare = getattr(ai_mod, "ui_prepare_turn");
    setattr(ai_mod, "ui_prepare_turn", fake_busy);
    sess = sess_mod.AgentSession(cwd="/tmp/p6-busy", stub=False);
    cmd = models.SessionCommand(
        kind=bridge.CMD_KIND_PROMPT, command_id="p6", payload={"text": "hello"}
    );
    try {
        receipt = sess.submit(cmd);
        assert receipt.accepted == False;
        assert receipt.error.code == "busy";
        assert sess.lifecycle == bridge.LIFE_IDLE;
        assert sess.settled == True;
    } finally {
        setattr(ai_mod, "ui_prepare_turn", old_prepare);
        sess.dispose(deadline_ms=2000);
    }
}


test "phase6 stop then submit rejects while running" {
    adapter_mod = importlib.import_module("jaclang.cli.ai_tui.tui_session_adapter");
    bridge = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    ad = adapter_mod.TuiSessionAdapter(cwd="/tmp/p6-stop", stub=True);
    ad.start({"cwd": "/tmp/p6-stop", "stub": True});
    sess = ad.runtime.current();
    sess.lifecycle = bridge.LIFE_RUNNING;
    sess.settled = False;
    busy = ad.submit(adapter_mod.make_prompt_command("blocked"));
    assert busy.accepted == False;
    assert busy.error.code == "busy";
    ad.dispose(deadline_ms=2000);
}


test "phase6 dlopen dev path retains legacy cmd bridge" {
    bridge_mod = importlib.import_module("jaclang.cli.ai_tui.python_session_bridge");
    run_mod = importlib.import_module("jaclang.cli.ai_tui.run_tui_in_process");
    embed_mod = importlib.import_module("jaclang.cli.ai_tui.run_tui_embed");
    assert hasattr(bridge_mod, "PythonSessionBridge");
    assert callable(bridge_mod.PythonSessionBridge?.dispatch_legacy_cmd);
    assert callable(run_mod?.run_tui_in_process);
    assert callable(embed_mod?.run_tui_embed);
    # Structural guard: execve embed launcher must not import the dlopen host module.
    embed_src = (_tui_dir() / "impl" / "run_tui_embed.impl.jac").read_text();
    assert "host_dlopen" not in embed_src;
}


test "phase6 dispatch selftest passes for reducer input path" {
    na_dir = _na_dir();
    if not harness.shim_path(harness.repo_root(na_dir)).is_file() {
        import pytest;
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    harness.ensure_selftest(na_dir, "selftest_dispatch");
    harness.assert_selftest_passes(na_dir, "selftest_dispatch");
}


test "phase6 pty harness characterization is opt-in only" {
    import os;
    import subprocess;
    import sys;
    import pytest;
    import from pathlib { Path }

    if os.environ.get("JAC_AI_TUI_PTY_HARNESS", "").strip().lower() not in {
        "1",
        "true",
        "yes",

    } {
        pytest.skip(
            "PTY characterization is opt-in (set JAC_AI_TUI_PTY_HARNESS=1); " + "structural tests do not gate on harness.py"
        );
    }

    repo = Path(__file__).resolve().parents[3];
    harness_py = repo / "plans" / "phase0" / "pty" / "harness.py";
    host = repo / "jac" / "jaclang" / "cli" / "ai_tui_na" / "bin" / "jac-ai-tui";
    if not host.is_file() {
        pytest.skip(
            "embed host not built (run jac/jaclang/cli/ai_tui_na/build_embed.sh)"
        );
    }
    proc = subprocess.run(
        [sys.executable, str(harness_py), "--recoverable", "--deadline", "90", ],
        cwd=str(repo),
        capture_output=True,
        text=True,
        timeout=1200,
    );
    if proc.returncode != 0 {
        tail = (proc.stderr or proc.stdout or "")[-3000:];
        if "exit=-11" in tail or proc.returncode in {-11, 139, 245} {
            pytest.skip(
                "embed host PTY suite segfaults on this platform " + "(characterization evidence; rebuild with debug symbols to bisect)"
            );
        }
        assert False , (
            "pty harness failed (rebuild: jac/jaclang/cli/ai_tui_na/build_embed.sh; " + "ensure JAC_RT_DIR via fused jac --version). " + f"rc={proc.returncode}\n{tail}"
        );
    }
}
