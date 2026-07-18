"""Golden-frame display-width characterization (independent of byte equality).

Runs the same harness as test_tui_render_golden.jac but checks the Phase 0
width invariant: visible cells per row must not exceed fixture cols. Many
current goldens exceed cols because framed rows count border glyphs and
truecolor ANSI separately from the native renderer's padding — this test
tracks that debt and fails only when violations *increase*.

See plans/phase0/width/WIDTH.md.
"""

import os;
import sys;
import subprocess;
import pytest;
import jaclang.cli.ai_tui.tui_shared as tui_shared;
import jac.tests.cli.tui_selftest_harness as harness;
import from pathlib { Path }

# Baseline row violations across all fixtures (2026-07-18). Decrease as the
# renderer tightens row widths; increase means a regression.
glob _WIDTH_VIOLATION_CEILING: int = 55;


def _repo_root(cli_dir: Path) -> Path {
    return cli_dir.parent.parent.parent.parent;
}


def _golden_dir(repo_root: Path) -> Path {
    return repo_root / "jac" / "tests" / "golden" / "tui_render";
}


def _shim_path(repo_root: Path) -> Path {
    shim_dir = (
        repo_root / "jac" / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native"
    );
    name = "libjacpyembed.dylib" if sys.platform == "darwin" else "libjacpyembed.so";
    return shim_dir / name;
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


def _binary_stale(na_dir: Path) -> bool {
    binary = na_dir / "bin" / "selftest_render";
    if not binary.is_file() {
        return True;
    }
    bin_mtime = binary.stat().st_mtime;
    for path in _iter_na_sources(na_dir) {
        if path.stat().st_mtime > bin_mtime {
            return True;
        }
    }
    return False;
}


def _ensure_binary(na_dir: Path) {
    if _binary_stale(na_dir) {
        subprocess.run(["bash", str(na_dir / "build_selftest.sh")], check=True);
    }
}


def _run_binary(na_dir: Path) -> bytes {
    proc = subprocess.run(
        [str(na_dir / "bin" / "selftest_render")], capture_output=True, check=True
    );
    return proc.stdout;
}


def _parse_frames(data: bytes) -> dict[str, bytes] {
    frames: dict[str, bytes] = {};
    label: str = "";
    rows: list[bytes] = [];
    in_frame: bool = False;
    for line in data.split(b"\n") {
        if line.startswith(b"===FIXTURE===") and line.endswith(b"===") {
            label = line.split(b"===")[2].decode();
            rows = [];
            in_frame = True;
        } elif line == b"===END===" {
            if in_frame {
                frames[label] = b"\n".join(rows) + b"\n";
            }
            in_frame = False;
        } elif in_frame {
            rows.append(line);
        }
    }
    return frames;
}


test "golden render frames stay within width violation ceiling" {
    cli_dir = Path(tui_shared.__file__).resolve().parent.parent;
    na_dir = cli_dir / "ai_tui_na";
    repo = _repo_root(cli_dir);
    shim = _shim_path(repo);
    if not shim.is_file() {
        pytest.skip(f"native toolchain shim not built ({shim.name}); run `zig build`");
    }

    _ensure_binary(na_dir);
    frames = _parse_frames(_run_binary(na_dir));
    assert frames , "golden harness emitted no frames";

    violations = harness.audit_frame_widths(frames);
    assert len(violations) <= _WIDTH_VIOLATION_CEILING , (
        f"width violations grew to {len(violations)} (ceiling {_WIDTH_VIOLATION_CEILING}):\n" + "\n".join(
            violations[:20]
        ) + ("\n..." if len(violations) > 20 else "")
    );
}
