import os;
import json;
import difflib;

import from jaclang.prune.finding { Candidate, disposition_label, finding_category }
import from jaclang.prune.campaign { risk_tier_label, Disposition }
import from jaclang.prune.factstore { FactStore }
import from jaclang.prune.factquery { cite_index }


def _rel(path: str, root_dir: str) -> str {
    try {
        return os.path.relpath(path, root_dir);
    } except Exception {
        return path;
    }
}


def _disp_order(d: Disposition) -> int {
    if d == Disposition.AUTO_FIX {
        return 0;
    }
    if d == Disposition.PR_ONLY {
        return 1;
    }
    return 2;
}


def sort_key(c: Candidate) -> tuple {
    f = c.finding;
    return (_disp_order(c.disposition), f.detector, f.module_path, f.line);
}


def sorted_candidates(cands: list[Candidate]) -> list[Candidate] {
    return sorted(cands, key=sort_key);
}


def summarize(cands: list[Candidate]) -> dict[str, int] {
    out: dict[str, int] = {"auto-fix": 0, "pr-only": 0, "report-only": 0};
    for c in cands {
        k = disposition_label(c.disposition);
        out[k] = out.get(k, 0) + 1;
    }
    return out;
}


def summarize_categories(cands: list[Candidate]) -> dict[str, int] {
    out: dict[str, int] = {"deletion": 0, "hygiene": 0};
    for c in cands {
        out[finding_category(c.finding.detector)] += 1;
    }
    return out;
}


def table_rows(cands: list[Candidate], root_dir: str) -> list[list[str]] {
    rows: list[list[str]] = [];
    for c in sorted_candidates(cands) {
        f = c.finding;
        loc = f"{_rel(f.module_path, root_dir)}:{f.line}";
        rows.append(
            [
                f.detector,
                risk_tier_label(c.risk),
                disposition_label(c.disposition),
                loc,
                f.message
            ]
        );
    }
    return rows;
}


def confidence_of(c: Candidate) -> float {
    if c.finding.has_veto() {
        return 0.2;
    }
    if c.disposition == Disposition.AUTO_FIX {
        return 0.9;
    }
    if c.disposition == Disposition.PR_ONLY {
        return 0.7;
    }
    return 0.5;
}


def rank_key(c: Candidate) -> tuple {
    f = c.finding;
    return (
        _disp_order(c.disposition),
        -confidence_of(c),
        f.detector,
        f.module_path,
        f.line
    );
}


def ranked_candidates(cands: list[Candidate]) -> list[Candidate] {
    return sorted(cands, key=rank_key);
}


def list_rows(
    cands: list[Candidate], root_dir: str, limit: int
) -> tuple[list[list[str]], int] {
    ordered = ranked_candidates(cands);
    shown = ordered[:limit] if limit > 0 else ordered;
    rows: list[list[str]] = [];
    for c in shown {
        f = c.finding;
        loc = f"{_rel(f.module_path, root_dir)}:{f.line}";
        rows.append(
            [
                f.fingerprint(),
                disposition_label(c.disposition),
                f"{confidence_of(c):.2f}",
                loc,
                f.message
            ]
        );
    }
    return (rows, max(0, len(ordered) - len(shown)));
}


def list_json(cands: list[Candidate], root_dir: str, limit: int) -> str {
    ordered = ranked_candidates(cands);
    shown = ordered[:limit] if limit > 0 else ordered;
    out: list[dict] = [];
    for c in shown {
        f = c.finding;
        out.append(
            {
                "fingerprint": f.fingerprint(),
                "detector": f.detector,
                "disposition": disposition_label(c.disposition),
                "risk": risk_tier_label(c.risk),
                "confidence": confidence_of(c),
                "location": f"{_rel(f.module_path, root_dir)}:{f.line}",
                "message": f.message
            }
        );
    }
    return json.dumps(
        {
            "findings": out,
            "shown": len(shown),
            "total": len(ordered),
            "suppressed": max(0, len(ordered) - len(shown))
        },
        indent=2
    );
}


def render_diff(path: str, before: bytes, after: bytes, root_dir: str) -> str {
    rel = _rel(path, root_dir);
    a = before.decode("utf-8", errors="replace").splitlines(keepends=True);
    b = after.decode("utf-8", errors="replace").splitlines(keepends=True);
    lines = list(difflib.unified_diff(a, b, fromfile=f"a/{rel}", tofile=f"b/{rel}"));
    return "".join(lines);
}


def to_json(cands: list[Candidate], store: FactStore | None = None) -> str {
    out: list[dict] = [];
    for c in sorted_candidates(cands) {
        idx = cite_index(store, c.finding.citations) if store is not None else {};
        out.append(c.as_dict(idx));
    }
    return json.dumps(out, indent=2);
}


def _sarif_level(c: Candidate) -> str {
    return "note" if c.disposition == Disposition.REPORT_ONLY else "warning";
}


def to_sarif(cands: list[Candidate], root_dir: str) -> str {
    ordered = sorted_candidates(cands);
    rule_ids = sorted({c.finding.detector for c in ordered});
    results: list[dict] = [];
    for c in ordered {
        f = c.finding;
        results.append(
            {
                "ruleId": f.detector,
                "level": _sarif_level(c),
                "message": {"text": f.message},
                "locations": [
                    {
                        "physicalLocation": {
                            "artifactLocation": {"uri": _rel(f.module_path, root_dir)},
                            "region": {
                                "startLine": f.line,
                                "charOffset": f.pos_start,
                                "charLength": max(0, f.pos_end - f.pos_start)
                            }
                        }
                    }
                ],
                "properties": {
                    "risk": risk_tier_label(c.risk),
                    "disposition": disposition_label(c.disposition),
                    "fingerprint": f.fingerprint(),
                    "symbol_id": f.symbol_id
                }
            }
        );
    }
    sarif = {
        "version": "2.1.0",
        "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
        "runs": [
            {
                "tool": {
                    "driver": {
                        "name": "jac-prune",
                        "informationUri": "https://jac-lang.org",
                        "rules": [{"id": rid} for rid in rule_ids]
                    }
                },
                "results": results
            }
        ]
    };
    return json.dumps(sarif, indent=2);
}
