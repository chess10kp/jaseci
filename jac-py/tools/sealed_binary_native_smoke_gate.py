#!/usr/bin/env python3
"""Sealed-binary native smoke gate (PLAN.md Phase 6 / §7).

Runs lightweight native-route contract pins against the shipped jac binary
(``JAC_NO_DEV_SOURCE=1``, ``JAC_TEST_NATIVE=1``) so CI proves the product path
does not silently fall back to host source compile/marshal.

Suites:
  - ``test_runtime_mode.jac`` — ORACLE/BOOTSTRAP/NATIVE routing + marshal tripwires
  - ``layer_d1_smoke.jac`` — native compiler -> VM execution (D1 probes)

Run from repo root:
    python3 jac-py/tools/sealed_binary_native_smoke_gate.py
"""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

_TOOLS = Path(__file__).resolve().parent
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from jac_subprocess import REPO_ROOT, resolve_jac, subprocess_env

SMOKE_SUITES: tuple[Path, ...] = (
    REPO_ROOT / "jac-py" / "jacpython" / "test_runtime_mode.jac",
    REPO_ROOT / "jac-py" / "jacpython" / "layer_d1_smoke.jac",
)


def _run_jac_test(jac_bin: Path, suite: Path) -> subprocess.CompletedProcess[str]:
    env = subprocess_env(profile="jacpython", include_dev_source=False)
    env.setdefault("JAC_TEST_NATIVE", "1")
    return subprocess.run(
        [str(jac_bin), "test", str(suite)],
        cwd=REPO_ROOT,
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


class SealedBinaryNativeSmokeGate(unittest.TestCase):
    def test_smoke_suites_exist(self) -> None:
        for suite in SMOKE_SUITES:
            self.assertTrue(suite.is_file(), f"missing smoke suite {suite}")

    def test_native_route_contract_and_d1_smoke(self) -> None:
        jac_bin = resolve_jac()
        if jac_bin is None:
            self.skipTest("jac binary not found (set $JAC or install jac-kit)")
        for suite in SMOKE_SUITES:
            proc = _run_jac_test(jac_bin, suite)
            detail = (proc.stderr or proc.stdout or "jac test failed").strip()
            self.assertEqual(
                proc.returncode,
                0,
                msg=f"{suite.name}:\n{detail}",
            )


if __name__ == "__main__":
    raise SystemExit(unittest.main())
