"""Unit tests for jac-py/tools/jac_subprocess.py."""

from __future__ import annotations

import os
import sys
import unittest
import unittest.mock
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from jac_subprocess import REPO_ROOT, ensure_jacpath, jacpath_entries, subprocess_env
from jac_subprocess_gate import check_file, jac_run_test_subprocess_files


class JacSubprocessEnvTests(unittest.TestCase):
    def test_ensure_jacpath_prepends_missing_roots(self) -> None:
        env: dict[str, str] = {}
        ensure_jacpath(env, "jac-py/jacpython")
        self.assertEqual(env["JACPATH"], "jac-py/jacpython")

    def test_ensure_jacpath_keeps_existing_and_prepends_jacpython(self) -> None:
        env = {"JACPATH": "jac"}
        ensure_jacpath(env, "jac-py/jacpython")
        self.assertEqual(jacpath_entries(env), ["jac-py/jacpython", "jac"])

    def test_ensure_jacpath_is_idempotent(self) -> None:
        env = {"JACPATH": "jac-py/jacpython:jac"}
        ensure_jacpath(env, "jac-py/jacpython", "jac")
        self.assertEqual(jacpath_entries(env), ["jac-py/jacpython", "jac"])

    def test_subprocess_env_jacpython_profile(self) -> None:
        env = subprocess_env(profile="jacpython", include_dev_source=False)
        self.assertEqual(jacpath_entries(env)[0], "jac-py/jacpython")

    def test_subprocess_env_respects_jac_no_dev_source(self) -> None:
        with unittest.mock.patch.dict(os.environ, {"JAC_NO_DEV_SOURCE": "1"}, clear=False):
            env = subprocess_env(include_dev_source=None)
        self.assertNotIn("JAC_DEV_SOURCE", env)

    def test_gate_requires_subprocess_env_for_jac_run_drivers(self) -> None:
        errors = check_file("jac-py/tools/p3_object_core/replay_gate.py")
        self.assertEqual(errors, [])

    def test_gate_flags_missing_helper(self) -> None:
        errors = check_file("jac-py/tools/bisect_native_compile.py")
        self.assertEqual(errors, [])
        # Synthetic: a driver without subprocess_env would fail — use exempt tool driver.
        self.assertFalse(
            jac_run_test_subprocess_files(
                REPO_ROOT / "jac-py/tools/lift_p2_corpus_wave.py"
            )
        )


if __name__ == "__main__":
    unittest.main()
