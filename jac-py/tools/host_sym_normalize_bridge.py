#!/usr/bin/env python3
"""Host symtable normalization bridge for jac-python oracle tests.

Runs under the pinned CPython interpreter so compiler_symtable differential
tests do not depend on ::py:: blocks inside the sealed jac runtime.
"""

from __future__ import annotations

import json
import sys


def block_info(st) -> dict:
    children = []
    out: dict = {
        "name": st.get_name(),
        "type": st.get_type().value,
        "lineno": st.get_lineno(),
        "nested": st.is_nested(),
        "symbols": {},
        "children": children,
    }
    if hasattr(st, "get_parameters"):
        out["parameters"] = list(st.get_parameters())
        out["locals"] = list(st.get_locals())
        out["globals"] = list(st.get_globals())
        out["nonlocals"] = list(st.get_nonlocals())
        out["frees"] = list(st.get_frees())
    for name in sorted(st.get_identifiers()):
        sym = st.lookup(name)
        out["symbols"][name] = {
            "local": sym.is_local(),
            "global": sym.is_global(),
            "free": sym.is_free(),
            "parameter": sym.is_parameter(),
            "nonlocal": sym.is_nonlocal(),
            "declared_global": sym.is_declared_global(),
            "referenced": sym.is_referenced(),
            "assigned": sym.is_assigned(),
        }
    for ch in st.get_children():
        if ch.get_type().value == "annotation":
            continue
        children.append(block_info(ch))
    return out


def main() -> None:
    import symtable

    mode = sys.argv[1] if len(sys.argv) > 1 else "exec"
    source = sys.stdin.read()
    top = symtable.symtable(source, "<t>", mode)
    sys.stdout.write(json.dumps(block_info(top)))


if __name__ == "__main__":
    main()
