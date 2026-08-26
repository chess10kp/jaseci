"""Corpus/gates integrity census (PR #6973 item D).

Static integrity check over test corpora and gate manifests:

- corpus manifests (p1 + p2 waves): unique stems, sources/fixtures exist,
  lift_output/baseline_report paths exist
- staged manifests (p2_staged_manifest*.json): unique stems, every
  ``lift``-staged module has an artifact under ``lifted_dir``
- pinned fuzz corpus: unique case names, case sources parse as Python,
  fuzz_known_reds.json entries are covered by pins
- conformance wave manifests (jac-py/tests): every ``*tests`` entry naming a
  .py/.jac file exists
- gate scripts: string-literal repo-relative path references resolve

Exit code 0 when green, 1 with one issue per line on stderr otherwise.
"""

from __future__ import annotations

import ast
import json
import sys
from collections import defaultdict
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_TESTS = _REPO / "jac-py" / "tests"


def _repo_rel(p: str | Path) -> Path:
    p = Path(p)
    return p if p.is_absolute() else _REPO / p


class Census:
    def __init__(self) -> None:
        self.issues: list[str] = []

    def dupes(self, where: str, items: list[str], label: str) -> None:
        seen: dict[str, int] = defaultdict(int)
        for item in items:
            seen[item] += 1
        dups = sorted(k for k, n in seen.items() if n > 1)
        if dups:
            self.issues.append(f"{where}: duplicate {label}: {dups}")

    def missing(self, where: str, path: str | Path, what: str) -> None:
        if not _repo_rel(path).exists():
            self.issues.append(f"{where}: missing {what}: {path}")


def check_corpus_manifests(c: Census) -> None:
    manifests = sorted(
        [Path("jac-py/tools/p1_corpus/manifest.json")]
        + [Path(p) for p in map(str, _HERE.glob("p2_corpus*/manifest.json"))]
    )
    for mf in manifests:
        d = json.loads(_repo_rel(mf).read_text(encoding="utf-8"))
        c.dupes(str(mf), [f["stem"] for f in d.get("files", [])], "stems")
        for f in d.get("files", []):
            src = f.get("source") or f.get("fixture")
            if src:
                c.missing(str(mf), src, f"source for {f['stem']}")
        for key in ("lift_output", "baseline_report"):
            if d.get(key):
                c.missing(str(mf), d[key], key)


def check_staged_manifests(c: Census) -> None:
    for mf in sorted(_HERE.glob("p2_staged_manifest*.json")):
        d = json.loads(mf.read_text(encoding="utf-8"))
        c.dupes(mf.name, [m["stem"] for m in d["modules"]], "stems")
        lifted = _repo_rel(d["lifted_dir"])
        if not lifted.is_dir():
            c.issues.append(f"{mf.name}: missing lifted_dir {d['lifted_dir']}")
            continue
        present = {p.stem for p in lifted.iterdir() if p.is_file()}
        for m in d["modules"]:
            if m["staging"] == "lift" and m["stem"] not in present:
                c.issues.append(f"{mf.name}: no artifact for lift-stem {m['stem']}")


def check_fuzz_corpus(c: Census) -> None:
    pin = _HERE / "fuzz_corpus_pinned.json"
    d = json.loads(pin.read_text(encoding="utf-8"))
    names = [case["name"] for case in d["cases"]]
    c.dupes(pin.name, names, "case names")
    for case in d["cases"]:
        try:
            ast.parse(case["src"])
        except SyntaxError as e:
            c.issues.append(f"{pin.name}: {case['name']} does not parse: {e}")
    reds = json.loads((_HERE / "fuzz_known_reds.json").read_text(encoding="utf-8"))
    red_names = set(reds) if isinstance(reds, dict) else set(reds)
    uncovered = sorted(red_names - set(names))
    if uncovered:
        c.issues.append(f"fuzz_known_reds.json not covered by pins: {uncovered}")


def _walk_test_refs(c: Census, mf: Path, node: object) -> None:
    if isinstance(node, dict):
        for key, val in node.items():
            if isinstance(val, list) and key.endswith("tests"):
                for ref in val:
                    if (
                        isinstance(ref, str)
                        and (ref.endswith(".py") or ref.endswith(".jac"))
                        and not ref.startswith("/")
                    ):
                        c.missing(mf.name, _TESTS / ref, "test ref")
            _walk_test_refs(c, mf, val)
    elif isinstance(node, list):
        for val in node:
            _walk_test_refs(c, mf, val)


def check_conformance_manifests(c: Census) -> None:
    for mf in sorted(_TESTS.glob("conformance_manifest_wave*.json")):
        d = json.loads(mf.read_text(encoding="utf-8"))
        _walk_test_refs(c, mf, d)


def check_gate_script_refs(c: Census) -> None:
    import re

    pattern = re.compile(r"[\"']([\w\-./]+\.(?:json|jac|py|md|c))[\"']")
    scripts = sorted(set(map(str, _HERE.glob("*gate*.py"))) | set(map(str, _TESTS.rglob("*gate*.py"))))
    for g in scripts:
        # Only repo-relative literals are checked; absolute paths are
        # runtime-written scratch outputs (e.g. /tmp/...), not repo refs.
        for lit in set(pattern.findall(Path(g).read_text(encoding="utf-8"))):
            if "/" not in lit or lit.startswith(("http", "<", "/")):
                continue
            gdir = Path(g).parent
            cands = [_REPO / lit, gdir / lit, gdir.parent / lit]
            if not any(pth.exists() for pth in cands):
                c.issues.append(f"{g}: dangling reference {lit}")


def main() -> int:
    c = Census()
    check_corpus_manifests(c)
    check_staged_manifests(c)
    check_fuzz_corpus(c)
    check_conformance_manifests(c)
    check_gate_script_refs(c)
    if c.issues:
        for issue in c.issues:
            print(issue, file=sys.stderr)
        return 1
    pins = json.loads((_HERE / "fuzz_corpus_pinned.json").read_text(encoding="utf-8"))
    print(f"corpus/gates census: OK ({len(pins['cases'])} pins, manifests+staged+conformance+gates green)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
