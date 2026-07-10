import re;

import from jaclang.prune.finding { Evidence, Polarity }
import from jaclang.prune.manifest { Manifest, FileRole }


glob _STRING_LIT_RE: any = re.compile(
         r"(?s)'''.*?'''|\"\"\".*?\"\"\"|'(?:\\.|[^'\\])*'|\"(?:\\.|[^\"\\])*\""
     ),
     _WORD_RE: any = re.compile(r"[A-Za-z_][A-Za-z0-9_]*"),
     _IDENTIFIER_RE: any = re.compile(r"[A-Za-z_][A-Za-z0-9_]*"),
     _DYNAMIC_MARKERS = ["getattr(", "::py::", "globals()", "locals()", "vars("];


def _read(path: str) -> str {
    try {
        with open(path, "r", encoding="utf-8", errors="ignore") as f {
            return f.read();
        }
    } except Exception {
        return "";
    }
}


def _words(text: str) -> set {
    return set(_WORD_RE.findall(text));
}


def _unquote(literal: str) -> str {
    if literal.startswith("'''") or literal.startswith("\"\"\"") {
        return literal[3:-3];
    }
    return literal[1:-1];
}


def _string_literal_identifiers(text: str) -> set[str] {
    out: set[str] = set();
    for lit in _STRING_LIT_RE.findall(text) {
        value = _unquote(str(lit));
        if _IDENTIFIER_RE.fullmatch(value) {
            out.add(value);
        }
    }
    return out;
}


obj VetoIndex {
    has string_names_by_module: dict[str, set[str]] = {},
        fixture_words: set = set(),
        config_words: set = set(),
        dynamic_modules: set = set();

    def _mention_evidence(name: str, module_path: str) -> (Evidence | None) {
        local_names = self.string_names_by_module.get(module_path, set());
        if name in local_names {
            return Evidence(
                kind="string-mention",
                polarity=Polarity.VETOES,
                detail=f"'{name}' is a standalone string literal in this module"
            );
        }
        if name in self.fixture_words {
            return Evidence(
                kind="fixture-mention",
                polarity=Polarity.VETOES,
                detail=f"'{name}' appears in fixture text"
            );
        }
        if name in self.config_words {
            return Evidence(
                kind="config-mention",
                polarity=Polarity.VETOES,
                detail=f"'{name}' appears in jac.toml (possible entry point)"
            );
        }
        return None;
    }

    def check_symbol(name: str, module_path: str) -> list[Evidence] {
        out: list[Evidence] = [];
        if module_path in self.dynamic_modules {
            out.append(
                Evidence(
                    kind="dynamic-dispatch",
                    polarity=Polarity.VETOES,
                    detail="module uses getattr / inline-python (reflective access)"
                )
            );
        }
        ment = self._mention_evidence(name, module_path);
        if ment is not None {
            out.append(ment);
        }
        return out;
    }
}


def build_veto_index(manifest: Manifest, project_root: str = "") -> VetoIndex {
    import os;
    idx = VetoIndex();
    for entry in manifest.entries {
        if entry.role == FileRole.VENDORED {
            continue;
        }
        text = _read(entry.path);
        if not text {
            continue;
        }
        if entry.role == FileRole.FIXTURE {
            idx.fixture_words |= _words(text);
            continue;
        }

        idx.string_names_by_module[entry.path] = _string_literal_identifiers(text);
        if any(m in text for m in _DYNAMIC_MARKERS) {
            idx.dynamic_modules.add(entry.path);
        }
    }
    if project_root {
        toml_path = os.path.join(project_root, "jac.toml");
        if os.path.exists(toml_path) {
            idx.config_words |= _words(_read(toml_path));
        }
    }
    return idx;
}
