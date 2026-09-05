#!/usr/bin/env python3
"""Run one libtest snippet through layer_p2_libtest (JacPython ceval path)."""
from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

from jac_subprocess import REPO_ROOT, resolve_jac, subprocess_env

_JACPYTHON = REPO_ROOT / "jac-py" / "jacpython"


def _run_inline(source: str, expect: str) -> tuple[bool, str]:
    """Wrap arbitrary source in a one-off jac run entry."""
    jac = resolve_jac()
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
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            timeout=120,
            env=subprocess_env(profile="jacpython"),
        )
    finally:
        path.unlink(missing_ok=True)
    stdout = (proc.stdout or "").strip()
    stderr = (proc.stderr or "").strip()
    if proc.returncode != 0:
        detail = "\n".join(part for part in (stdout, stderr) if part)
        return False, detail or f"exit {proc.returncode}"
    if stdout.startswith("PASS:"):
        return True, stdout[5:]
    if stdout.startswith("FAIL:"):
        return False, stdout[5:]
    return False, stdout or stderr or "missing PASS/FAIL marker"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", help="embedded Python snippet")
    parser.add_argument("--expect", default="ok", help="expected stdout")
    parser.add_argument(
        "--snippet-name",
        default="",
        help="ignored; kept for libtest_runner CLI compatibility",
    )
    args = parser.parse_args(argv)
    ok, detail = _run_inline(args.source, args.expect)
    if ok:
        print(detail)
        return 0
    print(detail, file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
