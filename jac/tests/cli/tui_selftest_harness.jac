"""Shared helpers for native ai_tui_na selftest harness binaries."""

import os;
import sys;
import subprocess;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import from pathlib { Path }


def na_dir -> Path {
    return Path(tui_shared.__file__).resolve().parent.parent / "ai_tui_na";
}


def repo_root(cli_dir: Path) -> Path {
    return cli_dir.parent.parent.parent.parent;
}


def shim_path(root_dir: Path) -> Path {
    shim_dir = (
        root_dir / "jac" / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
    );
    name = "libjacpyembed.dylib" if sys.platform == "darwin" else "libjacpyembed.so";
    return shim_dir / name;
}


def unit_selftest_names -> list[str] {
    return [
        "selftest_width",
        "selftest_keys",
        "selftest_editor",
        "selftest_markdown",
        "selftest_overlay",
        "selftest_autocomplete"
    ];
}


def _iter_na_sources(na_dir: Path) -> list {
    out: list = [];
    for f in os.listdir(na_dir) {
        if f.endswith(".na.jac") {
            out.append(na_dir / f);
        }
    }
    for sub in ("tui", "components") {
        d = na_dir / sub;
        if d.is_dir() {
            for f in os.listdir(d) {
                if f.endswith(".na.jac") {
                    out.append(d / f);
                }
            }
        }
    }
    return out;
}


def binary_stale(na_dir: Path, binary_name: str) -> bool {
    binary = na_dir / "bin" / binary_name;
    if not binary.is_file() {
        return True;
    }
    bin_mtime = binary.stat().st_mtime;
    build_sh = na_dir / "build_unit_selftests.sh";
    if build_sh.is_file() and build_sh.stat().st_mtime > bin_mtime {
        return True;
    }
    for path in _iter_na_sources(na_dir) {
        if path.stat().st_mtime > bin_mtime {
            return True;
        }
    }
    return False;
}


def ensure_unit_selftests(na_dir: Path) {
    stale: bool = False;
    for name in unit_selftest_names() {
        if binary_stale(na_dir, name) {
            stale = True;
        }
    }
    if stale {
        subprocess.run(["bash", str(na_dir / "build_unit_selftests.sh")], check=True);
    }
}


def run_selftest(na_dir: Path, binary_name: str) -> str {
    env = dict(os.environ);
    bindir = str(na_dir / "bin");
    env["LD_LIBRARY_PATH"] = bindir + (
        os.pathsep + env["LD_LIBRARY_PATH"] if env.get("LD_LIBRARY_PATH") else ""
    );
    proc = subprocess.run(
        [str(na_dir / "bin" / binary_name)], capture_output=True, check=True, env=env
    );
    return proc.stdout.decode("utf-8", errors="replace");
}


def parse_pass_fail(output: str) -> tuple[list[str], list[str]] {
    passes: list[str] = [];
    failures: list[str] = [];
    for ln in output.splitlines() {
        s = ln.strip();
        if s.startswith("PASS ") {
            passes.append(s);
        } elif s.startswith("FAIL ") {
            failures.append(s);
        }
    }
    return (passes, failures);
}


def assert_selftest_passes(na_dir: Path, binary_name: str) {
    output = run_selftest(na_dir, binary_name);
    (passes, failures) = parse_pass_fail(output);
    assert passes , f"{binary_name} emitted no PASS lines:\n{output}";
    assert not failures , (
        f"{binary_name} failures:\n" + "\n".join(failures) + "\n\nfull output:\n" + output
    );
}


def parse_fixture_cols(label: str) -> int | None {
    dot = label.rfind(".");
    if dot < 0 {
        return None;
    }
    rest = label[dot + 1:];
    x = rest.find("x");
    if x < 0 {
        return None;
    }
    try {
        return int(rest[:x]);
    } except ValueError {
        return None;
    }
}


def audit_frame_widths(frames: dict[str, bytes]) -> list[str] {
    failures: list[str] = [];
    for label in sorted(frames) {
        cols = parse_fixture_cols(label);
        if cols is None {
            continue;
        }
        text = frames[label].decode("utf-8", errors="replace");
        lines = text.splitlines();
        for (i, line) in enumerate(lines) {
            if not line.strip() {
                continue;
            }
            vw = _visible_width_py(line);
            if vw > cols {
                failures.append(
                    f"{label} row {i + 1}: visible_width={vw} > cols={cols}"
                );
            }
        }
    }
    return failures;
}


def _visible_width_py(s: str) -> int {
    w: int = 0;
    i: int = 0;
    n = len(s);
    while i < n {
        c = ord(s[i]);
        if c == 27 {
            i = _skip_ansi_py(s, i);
            continue;
        }
        if 32 <= c <= 126 {
            w += 1;
            i += 1;
            continue;
        }
        if c >= 194 {
            w += 1;
            i += _utf8_seq_len_py(c);
            continue;
        }
        i += 1;
    }
    return w;
}


def _utf8_seq_len_py(lead: int) -> int {
    if lead >= 240 {
        return 4;
    }
    if lead >= 224 {
        return 3;
    }
    if lead >= 192 {
        return 2;
    }
    return 1;
}


def _skip_ansi_py(s: str, i: int) -> int {
    n = len(s);
    if i + 1 >= n {
        return i + 1;
    }
    intro = ord(s[i + 1]);
    if intro == 91 {
        j = i + 2;
        while j < n and not (64 <= ord(s[j]) <= 126) {
            j += 1;
        }
        return j + 1;
    }
    if intro == 93 or intro == 95 {
        j = i + 2;
        while j < n {
            bc = ord(s[j]);
            if bc == 7 {
                return j + 1;
            }
            if bc == 27 and j + 1 < n and ord(s[j + 1]) == 92 {
                return j + 2;
            }
            j += 1;
        }
        return j;
    }
    return i + 2;
}
