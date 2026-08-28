import re;

glob JAC_RUNTIME_SPEC: str = "@jac/runtime";

def remap_runtime_imports(js: str, target_spec: str) -> str {
    if target_spec == JAC_RUNTIME_SPEC {
        return js;
    }
    return (
        js.replace(f'from "{JAC_RUNTIME_SPEC}"', f'from "{target_spec}"')
        .replace(f"from '{JAC_RUNTIME_SPEC}'", f"from '{target_spec}'")
    );
}

def imported_symbols_from(js: str, module_spec: str) -> set[str] {
    names: set[str] = set();
    norm = js.replace("'", '"');
    pattern = 'import\\s*\\{([^}]*)\\}\\s*from\\s*"' + re.escape(module_spec) + '"';
    for m in re.finditer(pattern, norm) {
        for part in m.group(1).split(",") {
            piece = part.strip();
            if piece {
                tokens: list[str] = re.split(r"\s+as\s+", piece);
                names.add(tokens[-1].strip());
            }
        }
    }
    return names;
}

def runtime_import_symbols(js: str) -> set[str] {
    return imported_symbols_from(js, JAC_RUNTIME_SPEC);
}

def strip_runtime_imports(js: str) -> str {
    esc = re.escape(JAC_RUNTIME_SPEC);
    return re.sub(
        r'import\s*\{[^}]*\}\s*from\s*["\']' + esc + r'["\'];?\n?',
        "",
        js
    );
}

def _extract_import_lines(js_code: str) -> list[str] {
    imports: list[str] = [];
    for line in js_code.split('\n') {
        trimmed = line.strip();
        if trimmed.startswith('import ') {
            imports.append(line);
        }
    }
    return imports;
}

def merge_runtime_imports(platform_js: str, core_js: str) -> str {
    seen: set[str] = set();
    merged: list[str] = [];
    for line in _extract_import_lines(platform_js) + _extract_import_lines(core_js) {
        if 'client_react_core' in line {
            continue;
        }
        if line in seen {
            continue;
        }
        seen.add(line);
        merged.append(line);
    }
    return '\n'.join(merged);
}
