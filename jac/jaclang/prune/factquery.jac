import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.finding { Finding }


obj SymbolView {
    has id: str,
        name: str,
        kind: str,
        access: str,
        module_path: str,
        scope_chain: str,
        decl_line: int,
        callers: list[str],
        callees: list[str];

    def fan_in -> int {
        return len(self.callers);
    }

    def fan_out -> int {
        return len(self.callees);
    }

    def as_dict -> dict {
        return {
            "id": self.id,
            "name": self.name,
            "kind": self.kind,
            "access": self.access,
            "module_path": self.module_path,
            "scope_chain": self.scope_chain,
            "decl_line": self.decl_line,
            "fan_in": self.fan_in(),
            "fan_out": self.fan_out(),
            "callers": self.callers,
            "callees": self.callees
        };
    }
}


obj ToolSurface {
    has store: FactStore,
        _view_cache: dict[str, SymbolView] = {};

    def query_symbol(symbol_id: str) -> (SymbolView | None) {
        cached = self._view_cache.get(symbol_id);
        if cached is not None {
            return cached;
        }
        row = self.store.symbol_row(symbol_id);
        if row is None {
            return None;
        }
        view = SymbolView(
            id=str(row["id"]),
            name=str(row["name"]),
            kind=str(row["kind"]),
            access=str(row["access"]),
            module_path=str(row["module_path"]),
            scope_chain=str(row["scope_chain"]),
            decl_line=int(row["decl_line"]),
            callers=self.store.callers_of(symbol_id),
            callees=self.store.callees_of(symbol_id)
        );
        self._view_cache[symbol_id] = view;
        return view;
    }

    def callers_of(symbol_id: str) -> list[str] {
        return self.store.callers_of(symbol_id);
    }

    def callees_of(symbol_id: str) -> list[str] {
        return self.store.callees_of(symbol_id);
    }

    def module_summary(path: str) -> dict {
        return {
            "module_path": path,
            "module_name": self.store.module_name(path),
            "symbols": self.store.symbols_in_module(path),
            "deps": self.store.deps_of(path)
        };
    }

    def findings_in(path: str, findings: list[Finding]) -> list[Finding] {
        return [
            f
            for f in findings
            if f.module_path == path
        ];
    }

    def fetch_span(module_path: str, pos_start: int, pos_end: int) -> str {
        try {
            with open(module_path, "rb") as fh {
                data = fh.read();
            }
        } except Exception {
            return "";
        }
        start = max(0, pos_start);
        end = min(len(data), pos_end) if pos_end > 0 else len(data);
        if end < start {
            return "";
        }
        return data[start:end].decode("utf-8", errors="replace");
    }

    def verify_citation(citation: str) -> bool {
        if citation.startswith("ref:") {
            return self.store.ref_exists(citation);
        }
        if citation.startswith("dep:") {
            return self.store.dep_exists(citation);
        }
        if citation.startswith("sym:") {
            return self.store.symbol_exists(citation[4:]);
        }
        return self.store.symbol_exists(citation);
    }

    def verify_citations(citations: list[str]) -> bool {
        for cid in citations {
            if not self.verify_citation(cid) {
                return False;
            }
        }
        return True;
    }
}
