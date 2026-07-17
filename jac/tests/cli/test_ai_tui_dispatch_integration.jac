"""Integration smoke: stub embed host renders in a pty and quits cleanly.

Delegates to scripts/ai_tui_pty_smoke.py (Python pty logic). The native tty
layer opens --tty or /dev/tty, so the harness passes --tty with the pty slave.

Skipped when libjacpyembed shim or embed host is unavailable.
"""

import os;
import sys;
import importlib;
import subprocess;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


def _na_dir -> Path {
    return Path(tui_shared.__file__).resolve().parent.parent / "ai_tui_na";
}


def _repo_root(na_dir: Path) -> Path {
    return na_dir.parent.parent.parent.parent;
}


def _shim_path(repo_root: Path) -> Path {
    shim_dir = (
        repo_root / "jac" / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
    );
    name = "libjacpyembed.dylib" if sys.platform == "darwin" else "libjacpyembed.so";
    return shim_dir / name;
}


def _pty_smoke_script(repo_root: Path) -> Path {
    return repo_root / "scripts" / "ai_tui_pty_smoke.py";
}


test "stub embed host renders in pty and quits on ctrl-c" {
    if sys.platform == "win32" {
        pytest.skip("pty integration requires POSIX");
    }
    na_dir = _na_dir();
    repo = _repo_root(na_dir);
    if not _shim_path(repo).is_file() {
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    script = _pty_smoke_script(repo);
    if not script.is_file() {
        pytest.skip("scripts/ai_tui_pty_smoke.py missing");
    }

    cli_root = na_dir.parent;
    shared_mod = importlib.import_module("jaclang.cli.ai_tui.tui_shared");
    ensure = getattr(shared_mod, "_ensure_embed_host");
    ensure(str(cli_root));

    bindir = na_dir / "bin";
    if not (bindir / "jac-ai-tui").is_file() {
        pytest.skip("embed host binary missing after ensure");
    }

    proc = subprocess.run(
        [sys.executable, str(script), str(bindir)], capture_output=True, text=True
    );
    assert proc.returncode == 0 , (
        "pty smoke failed\nstdout:\n" + proc.stdout + "\nstderr:\n" + proc.stderr
    );
}
