"""In-process TUI flip: PythonSessionBridge and optional libtui.so ctypes smoke.

Adapter round-trips run without a real tty. ctypes/tui_init smoke is skipped when
libtui.so is absent, unloadable, or the host has no tty (CI-safe).
"""

import importlib;
import sys;
import time;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


def _na_dir -> Path {
    return Path(tui_shared.__file__).resolve().parent.parent / "ai_tui_na";
}


def _libtui_path(na_dir: Path) -> Path {
    if sys.platform == "darwin" {
        return na_dir / "bin" / "libtui.dylib";
    }
    return na_dir / "bin" / "libtui.so";
}


test "PythonSessionBridge stub start submit poll dispose round-trip" {
    bridge_mod = importlib.import_module("jaclang.cli.ai_tui.python_session_bridge");
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    bridge = bridge_mod.PythonSessionBridge();
    started = bridge.start_from_request(
        {"cwd": "/tmp/inprocess", "stub": True, "model_name": "stub"}
    );
    assert started["ok"] == True;
    assert int(started.get("epoch", 0)) >= 1;

    receipt = bridge.submit_prompt("inprocess-hi");
    assert receipt.accepted == True;

    deadline = time.monotonic() + 2.0;
    while time.monotonic() < deadline {
        if bridge.adapter.runtime is not None {
            if bridge.adapter.runtime.current().settled {
                break;
            }
        }
        time.sleep(0.02);
    }

    batch = schema.decode_batch(bridge.poll_json(64));
    assert batch["kind"] == "session_event_batch";
    assert isinstance(batch["mutations"], list);
    assert len(batch["mutations"]) > 0;

    snap = schema.decode_snapshot(bridge.snapshot_json());
    assert snap["kind"] == "ui_snapshot";

    disposed = bridge.dispose(reason="test", deadline_ms=2000);
    assert disposed["ok"] == True;
    assert disposed["timed_out"] == False;
}


test "dispatch_legacy_cmd maps SEND and STOP to typed submit" {
    bridge_mod = importlib.import_module("jaclang.cli.ai_tui.python_session_bridge");
    schema = importlib.import_module("jaclang.cli.ai_tui.bridge_schema");
    bridge = bridge_mod.PythonSessionBridge();
    bridge.start_from_request({"cwd": "/tmp/legacy-cmd", "stub": True});

    stop_rc = bridge.dispatch_legacy_cmd("STOP:");
    assert stop_rc["accepted"] == True;
    assert stop_rc["disposition"] == schema.DISP_NO_OP;

    send_rc = bridge.dispatch_legacy_cmd("SEND:legacy-prompt");
    assert send_rc["accepted"] == True;
    assert send_rc.get("verb") == "SEND";

    bridge.dispose(deadline_ms=500);
}


test "ctypes loads libtui and resolves tui_init when library exists" {
    if sys.platform == "win32" {
        pytest.skip("dlopen TUI requires POSIX");
    }
    import ctypes;

    na_dir = _na_dir();
    lib_path = _libtui_path(na_dir);
    if not lib_path.is_file() {
        ensure_fn = tui_shared?._ensure_tui_lib;
        if ensure_fn is not None {
            cli_root = na_dir.parent;
            ensured = ensure_fn(cli_root);
            if ensured.ok and ensured.path {
                lib_path = Path(str(ensured.path));
            }
        }
    }
    if not lib_path.is_file() {
        pytest.skip("libtui shared library not built (run ai_tui_na/build_dlopen.sh)");
    }

    try {
        lib = ctypes.CDLL(str(lib_path));
    } except OSError as e {
        pytest.skip(f"libtui present but not loadable: {e}");
    }
    init_fn = lib?.tui_init;
    shutdown_fn = lib?.tui_shutdown;
    assert init_fn is not None , "libtui.so missing tui_init export";
    assert shutdown_fn is not None , "libtui.so missing tui_shutdown export";

    init_fn.argtypes = [
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p,
        ctypes.c_char_p
    ];
    init_fn.restype = ctypes.c_int;
    shutdown_fn.restype = ctypes.c_int;

    probe = tui_shared._probe_tty();
    if not probe.get("available") {
        pytest.skip("no tty available for tui_init smoke");
    }
    tty_dev = str(probe.get("device", "") or "/dev/tty");
    rc = init_fn(b"/tmp", b"", b"", tty_dev.encode("utf-8"));
    try {
        assert rc == 0 , f"tui_init failed with errno {rc} on {tty_dev!r}";
    } finally {
        shutdown_fn();
    }
}
