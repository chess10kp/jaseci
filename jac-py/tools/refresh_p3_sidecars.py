#!/usr/bin/env python3
"""Refresh P3 object-core ``*.c2jac.report.json`` sidecars from checked-in ``.jac``.

The manifest gate reads sidecar ``tier_b_count`` and ``quarantined_functions`` against
``manifest.json`` baselines. Re-running ``lift_p3_objects.py`` can drift when c2jac
changes; this tool mirrors the committed ``# c2jac:`` header and TRAP quarantine sites.

Run from repo root:
    .venv/bin/python jac-py/tools/refresh_p3_sidecars.py
    .venv/bin/python jac-py/tools/refresh_p3_sidecars.py --stem boolobject
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p3_object_core" / "manifest.json"

_TIER_B_HEADER = re.compile(
    r"^#\s+L(?P<line>\d+)\s+\[(?P<code>\w+)\]\s+(?P<msg>.+)$"
)
_QUARANTINE = re.compile(
    r"raise\s+\"c2jac: quarantined function '(?P<name>[^']+)'"
)


def _band_for_code(code: str) -> str:
    if not code.startswith("W"):
        return "hole"
    try:
        num = int(code[1:])
    except ValueError:
        return "hole"
    if 4201 <= num <= 4209:
        return "style"
    if 4210 <= num <= 4219:
        return "behavior"
    return "hole"


def _sidecar_path(jac_path: Path) -> Path:
    return jac_path.with_name(jac_path.stem + ".c2jac.report.json")


def _sites_from_jac(text: str) -> list[dict]:
    sites: list[dict] = []
    for line in text.splitlines():
        m = _TIER_B_HEADER.match(line.strip())
        if not m:
            continue
        code = m.group("code")
        sites.append(
            {
                "code": code,
                "band": _band_for_code(code),
                "line": int(m.group("line")),
                "msg": m.group("msg"),
                "function": None,
                "quarantined": _band_for_code(code) in {"behavior", "hole"},
            }
        )
    return sites


def _quarantined_from_jac(text: str) -> list[str]:
    seen: list[str] = []
    for m in _QUARANTINE.finditer(text):
        name = m.group("name")
        if name not in seen:
            seen.append(name)
    return seen


def _refresh_row(row: dict) -> None:
    jac_path = (_REPO / row["lift_output"]).resolve()
    if not jac_path.is_file():
        raise FileNotFoundError(f"missing lift output {jac_path}")
    text = jac_path.read_text(encoding="utf-8")
    sites = _sites_from_jac(text)
    quarantined = _quarantined_from_jac(text)
    source = row["cpython_path"]
    if not source.startswith("jac-py/"):
        source = f"reference/cpython/{source}"
    payload = {
        "version": 1,
        "source": source,
        "output": row["lift_output"],
        "lenient": True,
        "sites": sites,
        "quarantined_functions": quarantined,
        "tier_b_count": len(sites),
    }
    sidecar = _sidecar_path(jac_path)
    sidecar.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(
        f"{row['stem']}: tier_b={payload['tier_b_count']} "
        f"quarantine={quarantined} -> {sidecar.relative_to(_REPO)}"
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=_MANIFEST)
    parser.add_argument("--stem")
    args = parser.parse_args(argv)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    rows = manifest.get("c2jac_objects_wave", [])
    if args.stem:
        rows = [r for r in rows if r.get("stem") == args.stem]
        if not rows:
            print(f"refresh_p3_sidecars: unknown stem {args.stem!r}", file=sys.stderr)
            return 1
    else:
        rows = [r for r in rows if r.get("status") == "lift"]
    for row in rows:
        _refresh_row(row)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
