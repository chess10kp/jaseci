#!/usr/bin/env python3
"""Lift P3 object-core c2jac wave entries with ``jac tool c2jac``.

Reads ``jac-py/tools/p3_object_core/manifest.json`` ``c2jac_objects_wave`` list.
Each entry is lifted as a single C file (not ``--project``) with P3 include stubs.

Run from repo root:
    .venv/bin/python jac-py/tools/lift_p3_objects.py
    .venv/bin/python jac-py/tools/lift_p3_objects.py --stem boolobject
    .venv/bin/python jac-py/tools/refresh_p3_sidecars.py  # sidecars only, from checked-in .jac
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_REPO = _HERE.parent.parent
_MANIFEST = _HERE / "p3_object_core" / "manifest.json"
_INCLUDES = _HERE / "p3_object_core" / "includes"
_REF_ROOT = "reference/cpython"


def _jac_bin() -> Path:
    venv = _REPO / ".venv" / "bin" / "jac"
    if venv.is_file():
        return venv
    found = shutil.which("jac")
    if found:
        return Path(found)
    raise FileNotFoundError("lift_p3_objects: jac not found (.venv/bin/jac or PATH)")


def _run(cmd: list[str]) -> None:
    proc = subprocess.run(cmd, cwd=_REPO, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed ({proc.returncode}): {' '.join(cmd)}")


def _lift_output_path(row: dict) -> Path:
    return (_REPO / row["lift_output"]).resolve()


def _is_hand_staged(lift_out: Path) -> bool:
    if not lift_out.is_file():
        return False
    first = lift_out.read_text(encoding="utf-8").split("\n", 1)[0]
    return "hand-staged" in first


def _resolve_source(row: dict) -> Path:
    rel = row["cpython_path"]
    if rel.startswith("jac-py/"):
        return (_REPO / rel).resolve()
    corpus = (_HERE / "p3_object_core" / "corpus" / f"{row['stem']}.c").resolve()
    if _is_hand_staged(_lift_output_path(row)) and corpus.is_file():
        return corpus
    return (_REPO / _REF_ROOT / rel).resolve()


def _sidecar_path_for_jac(jac_path: Path) -> Path:
    return jac_path.with_name(jac_path.stem + ".c2jac.report.json")


def _install_sidecar(src: Path, dst: Path, *, output_rel: str, source_rel: str) -> None:
    data = json.loads(src.read_text(encoding="utf-8"))
    data["output"] = output_rel
    data["source"] = source_rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def _lift_row(row: dict, *, sidecar_only: bool) -> None:
    src = _resolve_source(row)
    if not src.is_file():
        raise FileNotFoundError(f"lift_p3_objects: missing source {src}")
    out = _lift_output_path(row)
    src_rel = src.relative_to(_REPO).as_posix()
    out_rel = out.relative_to(_REPO).as_posix()
    jac = _jac_bin()
    if sidecar_only or _is_hand_staged(out):
        with tempfile.TemporaryDirectory(prefix="lift_p3_") as tmp:
            tmp_out = Path(tmp) / out.name
            cmd = [
                str(jac),
                "tool",
                "c2jac",
                src_rel,
                "-o",
                str(tmp_out),
                "-I",
                str(_INCLUDES.relative_to(_REPO)),
            ]
            _run(cmd)
            sidecar_src = _sidecar_path_for_jac(tmp_out)
            sidecar_dst = _sidecar_path_for_jac(out)
            _install_sidecar(sidecar_src, sidecar_dst, output_rel=out_rel, source_rel=src_rel)
            print(f"sidecar {row['stem']} -> {sidecar_dst.relative_to(_REPO)}")
        return
    out.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        str(jac),
        "tool",
        "c2jac",
        src_rel,
        "-o",
        out_rel,
        "-I",
        str(_INCLUDES.relative_to(_REPO)),
    ]
    _run(cmd)
    sidecar = _sidecar_path_for_jac(out)
    print(f"lifted {row['stem']} -> {out_rel}")
    print(f"sidecar -> {sidecar.relative_to(_REPO)}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=_MANIFEST,
        help="P3 object-core manifest JSON",
    )
    parser.add_argument(
        "--stem",
        help="lift one wave entry by stem (default: all status=lift entries)",
    )
    parser.add_argument(
        "--sidecar-only",
        action="store_true",
        help="emit only .c2jac.report.json sidecars (preserve hand-staged .jac)",
    )
    args = parser.parse_args(argv)
    try:
        _jac_bin()
    except FileNotFoundError as exc:
        print(exc, file=sys.stderr)
        return 1
    if not _INCLUDES.is_dir():
        print(f"lift_p3_objects: missing includes {_INCLUDES}", file=sys.stderr)
        return 1
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    wave = manifest.get("c2jac_objects_wave", [])
    if args.stem:
        rows = [r for r in wave if r.get("stem") == args.stem]
        if not rows:
            print(f"lift_p3_objects: unknown stem {args.stem!r}", file=sys.stderr)
            return 1
    else:
        rows = [r for r in wave if r.get("status") == "lift"]
        if not rows:
            print("lift_p3_objects: no status=lift entries in wave", file=sys.stderr)
            return 1
    for row in rows:
        _lift_row(row, sidecar_only=args.sidecar_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
