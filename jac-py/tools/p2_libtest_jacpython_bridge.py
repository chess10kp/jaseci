#!/usr/bin/env python3
"""Run one libtest snippet through layer_p2_libtest (JacPython ceval path)."""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_JACPYTHON = _REPO / "jac-py" / "jacpython"
_LAYER_TEST = _JACPYTHON / "layer_p2_libtest.jac"


def _resolve_jac() -> Path | None:
    """$JAC override, then PATH (CI sealed binary), then the dev venv."""
    env_bin = os.environ.get("JAC")
    if env_bin:
        return Path(env_bin)
    on_path = shutil.which("jac")
    if on_path:
        return Path(on_path)
    venv_bin = _REPO / ".venv" / "bin" / "jac"
    return venv_bin if venv_bin.is_file() else None


def _run_env() -> dict[str, str]:
    env = dict(os.environ)
    jac_src = _REPO / "jac"
    if env.get("JAC_NO_DEV_SOURCE", "").strip() not in ("1", "true", "True"):
        env["PYTHONPATH"] = str(jac_src)
        env["JAC_DEV_SOURCE"] = str(jac_src)
    cp = os.environ.get("JACPYTHON_CPYTHON")
    if cp:
        env["JACPYTHON_CPYTHON"] = cp
    return env


def _run_named_test(snippet_name: str) -> tuple[bool, str]:
    """Run the matching built-in test in layer_p2_libtest.jac."""
    jac = _resolve_jac()
    if jac is None:
        return False, "jac binary not found (set $JAC or install jac-kit)"
    if not _LAYER_TEST.is_file():
        return False, f"missing {_LAYER_TEST}"
    proc = subprocess.run(
        [str(jac), "test", str(_LAYER_TEST), "-f", snippet_name],
        cwd=_REPO,
        capture_output=True,
        text=True,
        timeout=120,
        env=_run_env(),
    )
    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or "").strip()
    if proc.returncode != 0:
        return False, stderr or stdout or f"exit {proc.returncode}"
    return True, "ok"


def _run_inline(source: str, expect: str) -> tuple[bool, str]:
    """Fallback: wrap arbitrary source in a one-off jac run entry."""
    jac = _resolve_jac()
    if jac is None:
        return False, "jac binary not found (set $JAC or install jac-kit)"
    # Jac braces must live in plain strings: when this bridge is invoked from
    # ``jac test`` the fallback interpreter may be JacPython, which does not
    # collapse f-string ``{{`` escapes the way CPython does.
    entry = (
        "import from layer_p2_libtest { p2_libtest_expect_ok }\n"
        "with entry {\n"
        f"    (ok, detail) = p2_libtest_expect_ok({source!r}, {expect!r});\n"
        "    if ok {\n"
        '        print("PASS:" + detail);\n'
        "    } else {\n"
        '        print("FAIL:" + detail);\n'
        "    }\n"
        "}\n"
    )
    with tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".jac",
        prefix="libtest_snippet_",
        dir=_JACPYTHON,
        delete=False,
        encoding="utf-8",
    ) as handle:
        handle.write(entry + "\n")
        path = Path(handle.name)
    try:
        proc = subprocess.run(
            [str(jac), "run", str(path)],
            cwd=_REPO,
            capture_output=True,
            text=True,
            timeout=120,
            env=_run_env(),
        )
    finally:
        path.unlink(missing_ok=True)
    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or proc.stdout or "").strip()
    if proc.returncode != 0:
        return False, stderr or stdout or f"exit {proc.returncode}"
    if stdout.startswith("PASS:"):
        return True, stdout[5:]
    if stdout.startswith("FAIL:"):
        return False, stdout[5:]
    return False, stdout or "missing PASS/FAIL marker"


def _run(source: str, expect: str, snippet_name: str | None) -> tuple[bool, str]:
    if snippet_name:
        return _run_named_test(snippet_name)
    return _run_inline(source, expect)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="embedded Python snippet")
    parser.add_argument("--expect", default="ok", help="expected stdout")
    parser.add_argument(
        "--snippet-name",
        default="",
        help="libtest snippet name; runs the built-in layer_p2_libtest test",
    )
    args = parser.parse_args(argv)
    name = args.snippet_name.strip() or None
    ok, detail = _run(args.source, args.expect, name)
    if ok:
        print(detail)
        return 0
    print(detail, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
