"""P3 object-core runtime parity driver (TODO.md item 5 / FIXME M11).

Runs ``layer0_replay_p3_runtime_gate.jac`` via ``jac run`` so Layer-1 replay
probes execute on a clean ceval slate.
"""

from __future__ import annotations

import subprocess
import sys
import unittest
from pathlib import Path

_TOOLS = Path(__file__).resolve().parents[1]
if str(_TOOLS) not in sys.path:
    sys.path.insert(0, str(_TOOLS))

from jac_subprocess import REPO_ROOT, resolve_jac, subprocess_env

GATE_JAC = REPO_ROOT / "jac-py" / "jacpython" / "layer0_replay_p3_runtime_gate.jac"


class P3RuntimeGate(unittest.TestCase):
    def test_runtime_probes_match_cpython(self) -> None:
        env = subprocess_env(profile="jacpython", include_dev_source=True)
        cpython = env.get("JACPYTHON_CPYTHON")
        if not cpython:
            self.skipTest("JACPYTHON_CPYTHON not set")
        jac_bin = resolve_jac()
        if jac_bin is None:
            self.skipTest("jac binary not found (set $JAC or install jac-kit)")
        proc = subprocess.run(
            [str(jac_bin), "run", str(GATE_JAC)],
            cwd=REPO_ROOT,
            env=env,
            capture_output=True,
            text=True,
            check=False,
        )
        detail = (proc.stderr or proc.stdout or "jac run failed").strip()
        self.assertEqual(
            proc.returncode,
            0,
            msg=detail,
        )
        self.assertIn("P3 runtime probes: all stems OK", proc.stdout)


if __name__ == "__main__":
    unittest.main()
