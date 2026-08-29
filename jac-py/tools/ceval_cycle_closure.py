#!/usr/bin/env python3
"""Phase 0: closure inventory for ceval import-cycle inversion."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "jacpython"
CEVAL = ROOT / "ceval.jac"

SPOKE_IMPORTS: dict[str, list[str]] = {
    "ceval_exec_frame": [],
    "ceval_bridge_guest": [],
    "ceval_exceptions": [],
    "ceval_opcodes_containers": [],
}

FRAME_EXEC_REFS = {
    "exec_code_frame",
    "run_frame",
    "run_frame_inner",
    "jac_frame_chain_slot",
    "jac_current_frame",
}


def parse_spoke_imports() -> None:
    for spoke in list(SPOKE_IMPORTS):
        text = (ROOT / f"{spoke}.jac").read_text()
        m = re.search(
            rf"import from ceval \{{([^}}]+)\}}",
            text,
            re.DOTALL,
        )
        if not m:
            continue
        syms = [s.strip().rstrip(",") for s in m.group(1).split("\n") if s.strip()]
        SPOKE_IMPORTS[spoke] = [s for s in syms if s]


def find_def_starts(text: str) -> dict[str, int]:
    """Map top-level def/obj names to line numbers (1-based)."""
    names: dict[str, int] = {}
    for i, line in enumerate(text.splitlines(), 1):
        m = re.match(r"^(def|obj|glob)\s+([A-Za-z_][A-Za-z0-9_]*)", line)
        if m:
            names[m.group(2)] = i
    return names


def extract_body(text: str, start_line: int, names: dict[str, int]) -> str:
    lines = text.splitlines()
    # Find next top-level def/obj/glob after start_line
    sorted_starts = sorted(
        (ln, n) for n, ln in names.items() if ln > start_line
    )
    end = sorted_starts[0][0] - 1 if sorted_starts else len(lines)
    return "\n".join(lines[start_line - 1 : end])


def callee_refs(body: str) -> set[str]:
    # Rough identifier call/reference scan
    return set(re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\b", body))


def main() -> int:
    parse_spoke_imports()
    all_back = sorted({s for syms in SPOKE_IMPORTS.values() for s in syms})
    print(f"Total back-edge symbols: {len(all_back)}")
    for spoke, syms in SPOKE_IMPORTS.items():
        print(f"  {spoke}: {len(syms)}")

    text = CEVAL.read_text()
    names = find_def_starts(text)
    ceval_syms = set(names.keys())

    missing = [s for s in all_back if s not in ceval_syms]
    if missing:
        print(f"\nWARNING: not found in ceval.jac: {missing}")

    # Classify
    types = [s for s in all_back if s.startswith("Py")]
    globs = [s for s in all_back if s.startswith("_")]
    funcs = [s for s in all_back if s not in types and s not in globs]
    print(f"\nTypes ({len(types)}): {', '.join(types)}")
    print(f"Globs ({len(globs)}): {', '.join(globs)}")
    print(f"Functions ({len(funcs)}): {len(funcs)} symbols")

    # Closure expansion
    closure: set[str] = set()
    work = list(funcs + globs + types)
    while work:
        sym = work.pop()
        if sym in closure or sym not in names:
            continue
        closure.add(sym)
        body = extract_body(text, names[sym], names)
        for ref in callee_refs(body):
            if ref in ceval_syms and ref not in closure:
                work.append(ref)

    print(f"\nClosure size (defs in ceval): {len(closure)} symbols")

    frame_hits = sorted(closure & FRAME_EXEC_REFS)
    print(f"Frame-exec references in closure: {frame_hits or 'NONE'}")

    # Lines estimate
    total_lines = 0
    for sym in sorted(closure, key=lambda s: names.get(s, 0)):
        if sym in names:
            body = extract_body(text, names[sym], names)
            total_lines += len(body.splitlines())
    print(f"Estimated closure lines: {total_lines}")

    # What's in closure but not in back-edge set
    extra = sorted(closure - set(all_back))
    print(f"\nClosure extras (deps not directly imported by spokes): {len(extra)}")
    if extra:
        print("  " + ", ".join(extra[:40]))
        if len(extra) > 40:
            print(f"  ... and {len(extra) - 40} more")

    rec = "STATIC_MOVE (ceval_ops.jac)" if total_lines <= 1500 and not frame_hits else "REGISTRY (vm_dispatch.jac)"
    print(f"\nPhase 0 recommendation: {rec}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
