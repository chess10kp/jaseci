#!/usr/bin/env python3
"""Gate: Python tools that shell out to ``jac run`` / ``jac test`` must use
``jac_subprocess.subprocess_env`` so ``JACPATH`` is never dropped in grandchildren.

Run from repo root:
    python3 jac-py/tools/jac_subprocess_gate.py
"""

from __future__ import annotations

import ast
import subprocess
import sys
from pathlib import Path

from jac_subprocess import REPO_ROOT

# ``jac tool …`` drivers (compiler lift/py2jac) do not exercise jacpython ceval.
JAC_TOOL_ONLY = frozenset(
    {
        "jac-py/tools/py2jac_batch.py",
        "jac-py/tools/lift_p1_corpus.py",
        "jac-py/tools/lift_p2_corpus.py",
        "jac-py/tools/lift_p2_corpus_wave.py",
        "jac-py/tools/lift_p3_objects.py",
    }
)

SCAN_ROOT = Path("jac-py/tools")


def _repo_root() -> Path:
    out = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
        check=True,
    )
    return Path(out.stdout.strip())


def _string_constants(node: ast.AST) -> list[str]:
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return [node.value]
    if isinstance(node, (ast.List, ast.Tuple)):
        out: list[str] = []
        for elt in node.elts:
            out.extend(_string_constants(elt))
        return out
    return []


def _is_subprocess_run(call: ast.Call) -> bool:
    func = call.func
    if isinstance(func, ast.Attribute) and func.attr == "run":
        value = func.value
        if isinstance(value, ast.Name) and value.id == "subprocess":
            return True
    return False


def _jac_run_or_test_invocation(call: ast.Call) -> bool:
    if not call.args:
        return False
    strings = _string_constants(call.args[0])
    if "tool" in strings:
        return False
    return "run" in strings or "test" in strings


def jac_run_test_subprocess_files(path: Path) -> bool:
    try:
        tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    except SyntaxError as exc:
        raise RuntimeError(f"{path}: {exc}") from exc
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and _is_subprocess_run(node):
            if _jac_run_or_test_invocation(node):
                return True
    return False


def check_file(rel: str, repo_root: Path | None = None) -> list[str]:
    if rel in JAC_TOOL_ONLY:
        return []
    root = repo_root or REPO_ROOT
    path = root / rel
    if not path.is_file():
        return [f"{rel}: missing file"]
    if not jac_run_test_subprocess_files(path):
        return []
    text = path.read_text(encoding="utf-8")
    if "subprocess_env(" not in text:
        return [
            f"{rel}: invokes jac run/test via subprocess.run but never calls "
            "subprocess_env() — import from jac_subprocess and build child env there"
        ]
    if "jac_subprocess" not in text:
        return [f"{rel}: must import subprocess_env from jac_subprocess"]
    return []


def main() -> int:
    root = _repo_root()
    errors: list[str] = []
    for path in sorted((root / SCAN_ROOT).rglob("*.py")):
        if path.name.startswith("test_"):
            continue
        rel = path.relative_to(root).as_posix()
        errors.extend(check_file(rel, root))
    if errors:
        print("jac subprocess env gate FAILED:", file=sys.stderr)
        for msg in errors:
            print(f"  - {msg}", file=sys.stderr)
        return 1
    print("jac subprocess env gate OK")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
