"""Unit tests for jac-py/tools/jac_subprocess.py."""

from __future__ import annotations

import os
import sys
import tempfile
import unittest
import unittest.mock
from pathlib import Path

_HERE = Path(__file__).resolve().parent
if str(_HERE) not in sys.path:
    sys.path.insert(0, str(_HERE))

from jac_subprocess import ensure_jacpath, jacpath_entries, subprocess_env
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
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "driver.py").write_text(
                "import subprocess\n"
                "from jac_subprocess import subprocess_env\n"
                "subprocess.run(['jac', 'run', 'example.jac'], env=subprocess_env())\n"
            )
            self.assertEqual(check_file("driver.py", root), [])

    def test_gate_flags_missing_helper(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "driver.py").write_text(
                "import subprocess\n"
                "subprocess.run(['jac', 'test', 'example.jac'])\n"
            )
            errors = check_file("driver.py", root)
            self.assertEqual(len(errors), 1)
            self.assertIn("never calls subprocess_env()", errors[0])

    def test_gate_ignores_compiler_tool_invocations(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            path = root / "driver.py"
            path.write_text(
                "import subprocess\n"
                "subprocess.run(['jac', 'tool', 'py2jac', 'example.py'])\n"
            )
            self.assertFalse(jac_run_test_subprocess_files(path))
            self.assertEqual(check_file("driver.py", root), [])


if __name__ == "__main__":
    unittest.main()
