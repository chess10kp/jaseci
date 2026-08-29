#!/usr/bin/env python3
"""Generate vm_dispatch wiring and ceval_api forwarders for cycle inversion."""
from __future__ import annotations

import re
import textwrap
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "jacpython"
TOOLS = Path(__file__).resolve().parent

SPOKES = [
    "ceval_exec_frame",
    "ceval_bridge_guest",
    "ceval_exceptions",
    "ceval_opcodes_containers",
]

TYPE_SYMS = {
    "PyFrame",
    "PyGenerator",
    "PyYield",
    "PyBuildClass",
    "PyAsyncGenWrappedValue",
    "PyGlobalsProxy",
    "PyBoundMethod",
    "PyNativeBuiltin",
    "PyGenericAlias",
    "PyHostProxy",
    "PyClass",
    "PyUserObj",
    "PyFunction",
    "PyInstanceDict",
    "PyClassMroMethod",
    "PyStaticMethod",
    "PyObjectAttrSlot",
    "PyFuncDictView",
    "PyFuncKwDefaults",
    "PyNativeNew",
    "PyDictMethod",
}

# Mutable process-wide slot; spokes read/write through ceval_api accessors.
GLOB_SYMS = {
    "_handled_exc_stack",
}

# Implemented in ceval_exceptions.jac; spokes import there directly.
EXCLUDED_FUNCS = {
    "recover_exception",
    "error_is_stopiteration",
}

DIRECT_FIXES = {
    "ceval_opcodes_containers": {"recover_exception": "ceval_exceptions"},
}

JAC_BUILTIN_TYPES = {
    "any",
    "bool",
    "str",
    "int",
    "float",
    "None",
    "list",
    "dict",
    "tuple",
}


def parse_module_imports(module: str, source: str) -> list[str]:
    m = re.search(rf"import from {module} \{{([^}}]+)\}}", source, re.DOTALL)
    if not m:
        return []
    return [
        s.strip().rstrip(",")
        for s in m.group(1).replace("\n", " ").split(",")
        if s.strip()
    ]


def parse_spoke_imports(spoke: str) -> list[str]:
    text = (ROOT / f"{spoke}.jac").read_text()
    syms = parse_module_imports("ceval", text)
    syms.extend(parse_module_imports("ceval_api", text))
    return syms


def parse_ceval_defs_api_imports() -> list[str]:
    path = ROOT / "ceval_defs.jac"
    if not path.exists():
        return []
    return parse_module_imports("ceval_api", path.read_text())


def load_objects_types() -> set[str]:
    text = (ROOT / "objects.jac").read_text()
    return set(re.findall(r"^obj\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?:\(|{)", text, re.MULTILINE))


def _find_matching_paren(text: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    while i < len(text):
        ch = text[i]
        if ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def _split_params(param_blob: str) -> list[str]:
    parts: list[str] = []
    cur: list[str] = []
    depth = 0
    for ch in param_blob:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            piece = "".join(cur).strip()
            if piece:
                parts.append(piece)
            cur = []
        else:
            cur.append(ch)
    tail = "".join(cur).strip()
    if tail:
        parts.append(tail)
    return parts


def _param_name(param: str) -> str:
    head = param.split("=", 1)[0].strip()
    if ":" in head:
        head = head.split(":", 1)[0].strip()
    return head


def parse_param_names(header: str) -> list[str]:
    if "(" not in header:
        return []
    open_idx = header.index("(")
    close_idx = _find_matching_paren(header, open_idx)
    if close_idx < 0:
        return []
    return [_param_name(p) for p in _split_params(header[open_idx + 1 : close_idx])]


def normalize_types_in_sig(header: str, objects_types: set[str]) -> str:
    allowed = objects_types | JAC_BUILTIN_TYPES | {"PyObj"}

    def repl(match: re.Match[str]) -> str:
        name = match.group(0)
        if name in allowed:
            return name
        return "PyObj"

    return re.sub(r"\b[A-Z][A-Za-z0-9_]*\b", repl, header)


def collect_sig_types(header: str) -> set[str]:
    found = set(re.findall(r"\b[A-Z][A-Za-z0-9_]*\b", header))
    return {t for t in found if t not in JAC_BUILTIN_TYPES}


def load_ceval_signatures() -> dict[str, dict[str, str | list[str]]]:
    sigs: dict[str, dict[str, str | list[str]]] = {}
    for path in (
        ROOT / "ceval.jac",
        ROOT / "ceval_defs.jac",
        ROOT / "ceval_exceptions.jac",
        ROOT / "ceval_exec_frame.jac",
    ):
        if not path.exists():
            continue
        text = path.read_text()
        for m in re.finditer(
            r"^(def|glob)\s+([A-Za-z_][A-Za-z0-9_]*)",
            text,
            re.MULTILINE,
        ):
            kind, name = m.group(1), m.group(2)
            line_start = m.start()
            line_end = text.find("\n", m.end())
            if line_end == -1:
                line_end = len(text)
            source_line = text[line_start:line_end].strip()

            # Inline ::py:: helpers use Python's trailing colon, not a Jac
            # brace. Treating the next Jac brace as their header terminator
            # copied whole Python blocks into ceval_api.jac.
            if kind == "def" and source_line.endswith(":"):
                params = [
                    p
                    for p in parse_param_names(source_line)
                    if p.isidentifier()
                ]
                ret_match = re.search(r"->\s*([^:]+):$", source_line)
                ret = ret_match.group(1).strip() if ret_match else "any"
                if ret not in JAC_BUILTIN_TYPES:
                    ret = "any"
                typed = ", ".join(f"{param}: any" for param in params)
                header = f"def {name}({typed}) -> {ret}"
            else:
                brace = text.find("{", m.end())
                semi = text.find(";", m.end())
                if semi != -1 and (brace == -1 or semi < brace):
                    end = semi
                else:
                    end = brace if brace != -1 else len(text)
                header = text[line_start:end].strip().rstrip(";")

            if kind == "glob":
                sigs[name] = {"kind": "glob", "header": header, "params": []}
                continue

            params = parse_param_names(header)
            sigs[name] = {"kind": "def", "header": header, "params": params}

    return sigs


def format_import_block(types: set[str]) -> list[str]:
    ordered = sorted(types)
    if "PyObj" in ordered:
        ordered.remove("PyObj")
    ordered = ["PyObj", *ordered]
    lines = ["import from objects {"]
    for name in ordered:
        lines.append(f"    {name},")
    lines.extend(
        [
            "}",
            "import from vm_dispatch { ceval_ops, }",
            "",
        ]
    )
    return lines


def forwarder_body(name: str, params: list[str]) -> str:
    if params:
        args = ", ".join(params)
        return f'    return (ceval_ops["{name}"] as any)({args});'
    return f'    return (ceval_ops["{name}"] as any)();'


def glob_accessors(name: str, glob_header: str, objects_types: set[str]) -> list[str]:
    type_match = re.search(r":\s*([^=]+?)\s*=", glob_header)
    ann = type_match.group(1).strip() if type_match else "any"
    ann = normalize_types_in_sig(ann, objects_types)
    lines = [
        f"def {name} -> {ann} {{",
        f'    return ceval_ops["{name}"] as {ann};',
        "}",
        "",
        f"def {name}_set(value: {ann}) {{",
        f'    ceval_ops["{name}"] = value;',
        "}",
        "",
    ]
    return lines


def registration_entries(func_syms: set[str], glob_syms: set[str]) -> list[str]:
    lines = ["with entry {"]
    for name in sorted(func_syms):
        lines.append(f'    ceval_ops["{name}"] = {name};')
    for name in sorted(glob_syms):
        lines.append(f'    ceval_ops["{name}"] = {name};')
    lines.append("}")
    return lines


def patch_ceval_jac(reg_block: str) -> None:
    path = ROOT / "ceval.jac"
    text = path.read_text()
    import_line = "import from vm_dispatch { ceval_ops, }"

    if import_line not in text:
        anchor = "import from ceval_exec_frame {"
        idx = text.find(anchor)
        if idx == -1:
            raise RuntimeError("ceval.jac: could not find ceval_exec_frame import anchor")
        line_start = text.rfind("\n", 0, idx) + 1
        text = text[:line_start] + import_line + "\n" + text[line_start:]

    marker = "# ceval_ops registration (generated by tools/gen_ceval_cycle_fix.py)"
    if marker in text:
        start = text.index(marker)
        end = text.find("\n", text.index("}", start)) + 1
        text = text[:start].rstrip() + "\n\n"
    else:
        text = text.rstrip() + "\n\n"

    # Drop any prior hand-written ceval_ops with entry blocks.
    text = re.sub(
        r"\nwith entry \{\n(?:    ceval_ops\[[^\]]+\] = [^;]+;\n)+\}\n?",
        "\n",
        text,
    )

    text += marker + "\n" + reg_block + "\n"
    path.write_text(text)


def load_ceval_impl_names() -> set[str]:
    text = (ROOT / "ceval.jac").read_text()
    names = set(re.findall(r"^def\s+([A-Za-z_][A-Za-z0-9_]*)", text, re.MULTILINE))
    names.update(re.findall(r"^glob\s+([A-Za-z_][A-Za-z0-9_]*)", text, re.MULTILINE))
    # Functions imported by ceval are valid registry implementations too. This
    # keeps ceval_defs acyclic when a moved archetype needs exception policy.
    names.update(parse_module_imports("ceval_exceptions", text))
    names.update(parse_module_imports("ceval_exec_frame", text))
    return names


def collect_func_syms() -> set[str]:
    func_syms: set[str] = set()
    for spoke in SPOKES:
        text = (ROOT / f"{spoke}.jac").read_text()
        for source in ("ceval", "ceval_api"):
            for s in parse_module_imports(source, text):
                if s in TYPE_SYMS or s in GLOB_SYMS or s in EXCLUDED_FUNCS:
                    continue
                func_syms.add(s)
    for s in parse_ceval_defs_api_imports():
        if s in EXCLUDED_FUNCS:
            continue
        func_syms.add(s)
    return func_syms


def main() -> None:
    all_syms: dict[str, set[str]] = {}
    func_syms = collect_func_syms()
    glob_syms_needed: set[str] = set()

    for spoke in SPOKES:
        text = (ROOT / f"{spoke}.jac").read_text()
        spoke_syms: set[str] = set()
        for source in ("ceval", "ceval_api", "ceval_defs"):
            spoke_syms.update(parse_module_imports(source, text))
        all_syms[spoke] = spoke_syms
        for s in parse_module_imports("ceval", text):
            if s in GLOB_SYMS:
                glob_syms_needed.add(s)

    sigs = load_ceval_signatures()
    # format_exception_text lives in tracebackmodule but is re-exported through ceval_ops.
    if "format_exception_text" in func_syms and "format_exception_text" not in sigs:
        sigs["format_exception_text"] = {
            "kind": "def",
            "header": "def format_exception_text(exc: PyObj) -> PyObj",
            "params": ["exc"],
        }
    objects_types = load_objects_types()

    missing = sorted(s for s in func_syms if s not in sigs)
    if missing:
        print("Missing signatures:", missing)

    missing_globs = sorted(s for s in glob_syms_needed if s not in sigs)
    if missing_globs:
        print("Missing glob signatures:", missing_globs)

    vm_dispatch = textwrap.dedent(
        """\
        # VM operation registry breaking ceval<->spoke import cycles.
        # ceval.jac wires ceval_ops at module load via `with entry`; spokes
        # import forwarders from ceval_api.jac (which reads this dict) instead
        # of importing ceval directly. Dict item assignment mutates in place
        # (same idiom as compiler_dispatch.jac).
        glob ceval_ops: dict[str, any] = {};

        # Frame chain accessor: ceval_exec_frame owns the slot; PyFrame in
        # ceval_defs reads it through this getter so ceval_defs stays acyclic.
        glob _frame_chain_slot: list[any] = [];

        def jac_frame_chain_slot_ref() -> list[any] {
            return _frame_chain_slot;
        }
        """
    )
    (ROOT / "vm_dispatch.jac").write_text(vm_dispatch)
    print("Wrote vm_dispatch.jac")

    import_types: set[str] = set()
    lines = [
        "# Forwarding API for ceval spokes (jac-py/PLAN.md §4).",
        "# Thin wrappers over vm_dispatch.ceval_ops so spokes never import ceval.",
        "",
    ]

    body_chunks: list[str] = []

    for name in sorted(func_syms):
        entry = sigs.get(name)
        if not entry:
            hdr = f"def {name}()"
            params: list[str] = []
        else:
            hdr = str(entry["header"])
            params = list(entry.get("params") or [])
        hdr = normalize_types_in_sig(hdr, objects_types)
        import_types |= collect_sig_types(hdr)
        body_chunks.append(hdr + " {")
        body_chunks.append(forwarder_body(name, params))
        body_chunks.append("}")
        body_chunks.append("")

    for name in sorted(glob_syms_needed):
        entry = sigs.get(name)
        glob_header = str(entry["header"]) if entry else f"glob {name}: any = None;"
        import_types |= collect_sig_types(glob_header)
        body_chunks.extend(glob_accessors(name, glob_header, objects_types))

    lines.extend(format_import_block(import_types))
    lines.extend(body_chunks)

    (ROOT / "ceval_api.jac").write_text("\n".join(lines))
    print(f"Wrote ceval_api.jac with {len(func_syms)} forwarders and {len(glob_syms_needed)} glob accessors")

    ceval_impls = load_ceval_impl_names()
    reg_funcs = {s for s in func_syms if s in ceval_impls}
    reg_globs = {s for s in glob_syms_needed if s in ceval_impls}
    reg_lines = registration_entries(reg_funcs, reg_globs)
    reg_path = TOOLS / "ceval_ops_registration.jac.fragment"
    reg_text = "\n".join(reg_lines)
    reg_path.write_text(reg_text)
    print(f"Wrote registration fragment ({len(reg_funcs) + len(reg_globs)} entries)")

    patch_ceval_jac(reg_text)
    print("Patched ceval.jac with vm_dispatch import and ceval_ops registration")

    unwired = sorted((func_syms | glob_syms_needed) - reg_funcs - reg_globs)
    if unwired:
        print("\nForwarders without ceval.jac impl (not registered):", unwired)

    wired = sorted(reg_funcs) + sorted(reg_globs)
    print(f"\nWired symbols ({len(wired)}):")
    for sym in wired:
        print(f"  {sym}")

    for spoke in SPOKES:
        syms = sorted(all_syms[spoke])
        types = [s for s in syms if s in TYPE_SYMS]
        globs = [s for s in syms if s in GLOB_SYMS]
        funcs = [
            s
            for s in syms
            if s not in TYPE_SYMS
            and s not in GLOB_SYMS
            and s not in EXCLUDED_FUNCS
            and s not in DIRECT_FIXES.get(spoke, {})
        ]
        fixes = DIRECT_FIXES.get(spoke, {})
        print(f"\n{spoke}:")
        print(f"  types -> ceval_defs: {types}")
        print(f"  globs -> ceval_api accessors: {globs}")
        print(f"  funcs -> ceval_api: {len(funcs)}")
        if fixes:
            print(f"  direct: {fixes}")
        excluded = [s for s in syms if s in EXCLUDED_FUNCS]
        if excluded:
            print(f"  excluded (ceval_exceptions): {excluded}")


if __name__ == "__main__":
    main()
