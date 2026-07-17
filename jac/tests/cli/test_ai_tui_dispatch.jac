"""Native dispatch harness regression for reduce_input key routing.

Runs bin/selftest_dispatch (built by build_dispatch_selftest.sh): a native
binary that exercises handle_key -> reduce_input without booting embedded
CPython. Guards ctrl-c quit, ipc command queueing, editor insert, overlay
focus, and movement before reducer if/elif -> match refactors.

Requires jac nacompile + libjacpyembed shim (same toolchain as golden render).
Skipped when the shim is absent.
"""

import os;
import sys;
import subprocess;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


def _na_dir -> Path {
    return Path(tui_shared.__file__).resolve().parent.parent / "ai_tui_na";
}


def _repo_root(na_dir: Path) -> Path {
    # ai_tui_na -> cli -> jaclang -> jac -> repo root
    return na_dir.parent.parent.parent.parent;
}


def _shim_path(repo_root: Path) -> Path {
    shim_dir = (
        repo_root / "jac" / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
    );
    name = "libjacpyembed.dylib" if sys.platform == "darwin" else "libjacpyembed.so";
    return shim_dir / name;
}


def _dispatch_closure_sources(na_dir: Path) -> list {
    names = [
        "selftest_dispatch.na.jac",
        "input.na.jac",
        "reducer.na.jac",
        "commands.na.jac",
        "keys.na.jac",
        "overlay.na.jac",
        "editor.na.jac",
        "state.na.jac",
        "runtime.na.jac",
        "focus.na.jac",
        "autocomplete.na.jac",
        "select_list.na.jac",
        "input_types.na.jac",
        "ipc_schema.na.jac",
        "transport.na.jac",
        "util.na.jac"
    ];
    out: list = [];
    for name in names {
        p = na_dir / name;
        if p.is_file() {
            out.append(p);
        }
    }
    return out;
}


def _binary_stale(na_dir: Path) -> bool {
    binary = na_dir / "bin" / "selftest_dispatch";
    if not binary.is_file() {
        return True;
    }
    bin_mtime = binary.stat().st_mtime;
    for path in _dispatch_closure_sources(na_dir) {
        if path.stat().st_mtime > bin_mtime {
            return True;
        }
    }
    build_sh = na_dir / "build_dispatch_selftest.sh";
    if build_sh.is_file() and build_sh.stat().st_mtime > bin_mtime {
        return True;
    }
    return False;
}


def _ensure_binary(na_dir: Path) {
    if _binary_stale(na_dir) {
        subprocess.run(
            ["bash", str(na_dir / "build_dispatch_selftest.sh")], check=True
        );
    }
}


def _run_selftest(na_dir: Path) -> str {
    env = dict(os.environ);
    bindir = str(na_dir / "bin");
    env["LD_LIBRARY_PATH"] = bindir + (
        os.pathsep + env["LD_LIBRARY_PATH"] if env.get("LD_LIBRARY_PATH") else ""
    );
    proc = subprocess.run(
        [str(na_dir / "bin" / "selftest_dispatch")],
        capture_output=True,
        check=True,
        env=env
    );
    return proc.stdout.decode("utf-8", errors="replace");
}


test "native dispatch harness passes all key-routing assertions" {
    na_dir = _na_dir();
    if not _shim_path(_repo_root(na_dir)).is_file() {
        pytest.skip("libjacpyembed shim not built (run zig build in jac/)");
    }
    _ensure_binary(na_dir);
    output = _run_selftest(na_dir);

    lines: list[str] = [];
    for ln in output.splitlines() {
        if ln.strip() {
            lines.append(ln.strip());
        }
    }
    assert lines , f"dispatch selftest emitted no output:\n{output}";

    failures: list[str] = [];
    passes: list[str] = [];
    for ln in lines {
        if ln.startswith("FAIL ") {
            failures.append(ln);
        } elif ln.startswith("PASS ") {
            passes.append(ln);
        }
    }
    assert passes , f"no PASS lines in dispatch selftest output:\n{output}";
    assert not failures , (
        "dispatch selftest failures:\n" + "\n".join(failures) + "\n\nfull output:\n" + output
    );
}
