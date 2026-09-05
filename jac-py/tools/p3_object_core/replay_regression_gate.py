#!/usr/bin/env python3
"""P3 Layer-0/1 replay regression driver.

Runs ``layer0_replay.jac`` one test per ``jac test`` subprocess so each case
gets a fresh ceval slate. ``jac test`` on the whole file keeps
``clear_modules=False`` between cases; replay pins mutate ceval state and the
accumulated graph can hang or OOM CI before the first progress line lands (same
rationale as ``replay_gate.py`` choosing ``jac run`` over ``jac test``).
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
REPLAY_JAC = REPO_ROOT / "jac-py" / "jacpython" / "layer0_replay.jac"
_TEST_NAME_RE = re.compile(r'^test "([^"]+)"', re.MULTILINE)
# Wall-clock budget per isolated ``jac test`` subprocess (seconds).
_SUBPROCESS_TIMEOUT = int(os.environ.get("REPLAY_REGRESSION_TIMEOUT", "180"))


def _resolve_jac() -> Path | None:
    """$JAC override, then PATH (CI installs jac-kit), then the dev venv."""
    env_bin = os.environ.get("JAC")
    if env_bin:
        return Path(env_bin)
    on_path = shutil.which("jac")
    if on_path:
        return Path(on_path)
    venv_bin = REPO_ROOT / ".venv" / "bin" / "jac"
    return venv_bin if venv_bin.is_file() else None


def replay_test_names() -> list[str]:
    text = REPLAY_JAC.read_text(encoding="utf-8")
    names = _TEST_NAME_RE.findall(text)
    if not names:
        raise RuntimeError(f"no tests found in {REPLAY_JAC}")
    return names


def run_replay_regressions(
    *,
    jac_bin: Path,
    env: dict[str, str],
    max_tests: int | None = None,
    verbose: bool = True,
) -> None:
    names = replay_test_names()
    if max_tests is not None:
        names = names[:max_tests]
    failures: list[str] = []
    for idx, name in enumerate(names, start=1):
        prefix = f"[{idx}/{len(names)}]"
        print(f"{prefix} {name}", flush=True)
        cmd = [str(jac_bin), "test", str(REPLAY_JAC), "--filter", name]
        if verbose:
            cmd.insert(2, "--verbose")
        try:
            proc = subprocess.run(
                cmd,
                cwd=REPO_ROOT,
                env=env,
                text=True,
                capture_output=True,
                check=False,
                timeout=_SUBPROCESS_TIMEOUT,
            )
        except subprocess.TimeoutExpired as exc:
            detail = (exc.stdout or "") + (exc.stderr or "")
            print(f"{prefix} TIMEOUT after {_SUBPROCESS_TIMEOUT}s", flush=True)
            if detail.strip():
                print(detail.strip(), flush=True)
            raise SystemExit(
                f"layer0_replay regression timed out at {name} "
                f"(>{_SUBPROCESS_TIMEOUT}s)"
            )
        detail = (proc.stdout or proc.stderr or "").strip()
        if proc.returncode != 0:
            failures.append(name)
            print(f"{prefix} FAILED (exit {proc.returncode})", flush=True)
            if detail:
                print(detail, flush=True)
            raise SystemExit(
                f"layer0_replay regression failed at {name} (exit {proc.returncode})"
            )
        print(f"{prefix} OK", flush=True)
    if failures:
        joined = "\n  - ".join(failures)
        raise SystemExit(f"layer0_replay regression failures ({len(failures)}):\n  - {joined}")
    print(f"layer0_replay regression: {len(names)} tests OK", flush=True)


class ReplayRegressionGate(unittest.TestCase):
    def test_layer0_layer1_replay_regressions(self) -> None:
        jac_bin = _resolve_jac()
        if jac_bin is None:
            self.skipTest("jac binary not found (set $JAC or install jac-kit)")
        env = os.environ.copy()
        env.setdefault("JACPATH", "jac-py/jacpython")
        max_tests = int(env["REPLAY_REGRESSION_MAX"]) if "REPLAY_REGRESSION_MAX" in env else None
        try:
            run_replay_regressions(
                jac_bin=jac_bin,
                env=env,
                max_tests=max_tests,
            )
        except SystemExit as exc:
            self.fail(str(exc))


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--max",
        type=int,
        default=None,
        help="run only the first N tests (local smoke)",
    )
    parser.add_argument(
        "--quiet",
        action="store_true",
        help="omit per-test jac --verbose",
    )
    args = parser.parse_args(argv)
    jac_bin = _resolve_jac()
    if jac_bin is None:
        print("jac binary not found (set $JAC or install jac-kit)", file=sys.stderr)
        return 2
    env = os.environ.copy()
    env.setdefault("JACPATH", "jac-py/jacpython")
    try:
        run_replay_regressions(
            jac_bin=jac_bin,
            env=env,
            max_tests=args.max,
            verbose=not args.quiet,
        )
    except SystemExit as exc:
        print(exc, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
