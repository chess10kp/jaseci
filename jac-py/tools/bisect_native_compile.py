#!/usr/bin/env python3
"""Bisect native compile failures in a CPython Lib/*.py file."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

from jac_subprocess import REPO_ROOT, subprocess_env

JAC = "jac"


def compile_probe(src: str, label: str) -> str:
    body_json = json.dumps(src)
    probe = f"""\
import from product_compile {{ compile_source }}
import from objects {{ is_error, PyError }}

with entry {{
    co = compile_source({body_json}, {json.dumps(label)}, "exec", 0);
    if is_error(co) {{
        e = co as PyError;
        print(e.exception.type_name + ": " + e.exception.message);
    }} else {{
        print("OK");
    }}
}}
"""
    with tempfile.NamedTemporaryFile(
        mode="w", suffix=".jac", dir=REPO_ROOT / "jac-py" / "jacpython", delete=False
    ) as f:
        f.write(probe)
        path = Path(f.name)
    try:
        proc = subprocess.run(
            [JAC, "run", str(path)],
            cwd=REPO_ROOT,
            capture_output=True,
            text=True,
            env=subprocess_env(profile="jacpython", include_dev_source=False),
        )
        out = (proc.stdout + proc.stderr).strip().splitlines()
        for line in reversed(out):
            if line.startswith(("OK", "ValueError:", "SyntaxError:", "NotImplementedError:", "SystemError:")):
                return line
        return out[-1] if out else f"exit {proc.returncode}"
    finally:
        path.unlink(missing_ok=True)


def bisect_file(path: Path) -> None:
    lines = path.read_text().splitlines(keepends=True)
    lo, hi = 0, len(lines)
    print(f"bisect {path} ({len(lines)} lines)")
    while hi - lo > 1:
        mid = (lo + hi) // 2
        chunk = "".join(lines[:mid])
        result = compile_probe(chunk, f"{path.name}:{mid}")
        print(f"  lines 0..{mid}: {result}")
        if result == "OK":
            lo = mid
        else:
            hi = mid
    culprit = lines[lo]
    print(f"first failing line {lo + 1}: {culprit!r}")
    # try minimal context around culprit
    start = max(0, lo - 20)
    end = min(len(lines), lo + 20)
    snippet = "".join(lines[start:end])
    print(f"context {start + 1}..{end}: {compile_probe(snippet, 'context')}")


def main() -> int:
    target = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO_ROOT / "reference/cpython/Lib/difflib.py"
    bisect_file(target)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
