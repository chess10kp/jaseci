import hashlib;
import from jaclang.prune.campaign { RiskTier, Disposition, risk_tier_label }


enum Polarity { SUPPORTS = 1, VETOES = 2, }


glob POLARITY_LABELS: dict[Polarity, str] = {
         Polarity.SUPPORTS: "supports",
         Polarity.VETOES: "vetoes",

     };


def polarity_label(p: Polarity) -> str {
    return POLARITY_LABELS.get(p, "supports");
}


glob DISPOSITION_LABELS: dict[Disposition, str] = {
         Disposition.AUTO_FIX: "auto-fix",
         Disposition.PR_ONLY: "pr-only",
         Disposition.REPORT_ONLY: "report-only",

     };


def disposition_label(d: Disposition) -> str {
    return DISPOSITION_LABELS.get(d, "report-only");
}


obj Evidence {
    has kind: str,
        polarity: Polarity,
        detail: str;

    def as_dict -> dict {
        return {
            "kind": self.kind,
            "polarity": polarity_label(self.polarity),
            "detail": self.detail
        };
    }
}


obj Finding {
    has detector: str,
        symbol_id: str,
        name: str,
        module_path: str,
        kind: str,
        message: str,
        pos_start: int,
        pos_end: int,
        line: int,
        access: str = "",
        scope_chain: str = "",
        source: str = "detector",
        evidence: list[Evidence] = [],
        plan_meta: dict = {},
        citations: list[str] = [],
        related: list[str] = [];

    def add(ev: Evidence) {
        self.evidence.append(ev);
    }

    def has_veto -> bool {
        return bool(any(e.polarity == Polarity.VETOES for e in self.evidence));
    }

    def veto_kinds -> list[str] {
        return [
            e.kind
            for e in self.evidence
            if e.polarity == Polarity.VETOES
        ];
    }

    def fingerprint -> str {
        anchor = self.symbol_id
        or f"{self.module_path}:{self.pos_start}-{self.pos_end}";
        key = f"{self.detector}|{anchor}";
        return hashlib.sha256(key.encode("utf-8")).hexdigest()[:16];
    }
}


obj Candidate {
    has finding: Finding,
        risk: RiskTier,
        disposition: Disposition,
        trace: list[str] = [];

    def as_dict -> dict {
        f = self.finding;
        return {
            "detector": f.detector,
            "fingerprint": f.fingerprint(),
            "symbol_id": f.symbol_id,
            "name": f.name,
            "kind": f.kind,
            "module_path": f.module_path,
            "line": f.line,
            "pos_start": f.pos_start,
            "pos_end": f.pos_end,
            "message": f.message,
            "risk": risk_tier_label(self.risk),
            "disposition": disposition_label(self.disposition),
            "source": f.source,
            "evidence": [e.as_dict() for e in f.evidence],
            "citations": f.citations,
            "related": f.related,
            "trace": self.trace
        };
    }
}


glob _ARCHETYPE_KINDS = {"object", "node", "edge", "walker", "enum"},
     _DYNAMIC_KINDS = {"ability", "method"};


def _base_disposition(
    detector: str, f: Finding, trace: list[str]
) -> tuple[RiskTier, Disposition] {
    if detector.startswith("agent-") {
        trace.append(f"{detector} (agent redundancy) -> moderate/pr-only");
        return (RiskTier.MODERATE, Disposition.PR_ONLY);
    }
    if detector == "unused-imports" {
        trace.append("unused-import -> safe/auto-fix");
        return (RiskTier.SAFE, Disposition.AUTO_FIX);
    }
    if detector == "write-only-fields" {
        trace.append("write-only private field -> moderate/pr-only");
        return (RiskTier.MODERATE, Disposition.PR_ONLY);
    }
    if detector == "dead-enum-variants" {
        trace.append("dead enum variant (may be external API) -> moderate/pr-only");
        return (RiskTier.MODERATE, Disposition.PR_ONLY);
    }
    if detector == "literal-dead-branch" {
        trace.append("literal-condition branch -> moderate/pr-only");
        return (RiskTier.MODERATE, Disposition.PR_ONLY);
    }
    if detector == "single-caller-inline" {
        trace.append(
            "single-caller inline candidate (advisory) -> moderate/report-only"
        );
        return (RiskTier.MODERATE, Disposition.REPORT_ONLY);
    }
    if detector == "visibility-tightening" {
        trace.append(
            "visibility-tightening candidate (advisory) -> moderate/report-only"
        );
        return (RiskTier.MODERATE, Disposition.REPORT_ONLY);
    }
    if detector == "duplicated-constant-blobs" {
        trace.append("duplicated-constant-blob (advisory) -> moderate/report-only");
        return (RiskTier.MODERATE, Disposition.REPORT_ONLY);
    }
    if detector == "duplicate-docstrings" {
        trace.append("duplicate-docstrings (advisory) -> moderate/report-only");
        return (RiskTier.MODERATE, Disposition.REPORT_ONLY);
    }
    if detector == "private-dead-defs" {
        nested = ">" in f.scope_chain;
        if f.kind in _ARCHETYPE_KINDS {
            trace.append(f"private dead {f.kind} (archetype) -> risky/pr-only");
            return (RiskTier.RISKY, Disposition.PR_ONLY);
        }
        if f.kind in _DYNAMIC_KINDS or nested {
            trace.append(
                f"private dead {f.kind} (dynamic-dispatch/nested) -> moderate/pr-only"
            );
            return (RiskTier.MODERATE, Disposition.PR_ONLY);
        }
        trace.append("private dead top-level variable -> safe/auto-fix");
        return (RiskTier.SAFE, Disposition.AUTO_FIX);
    }
    trace.append("unknown detector -> report-only");
    return (RiskTier.MODERATE, Disposition.REPORT_ONLY);
}


def _rank(d: Disposition) -> int {
    if d == Disposition.AUTO_FIX {
        return 3;
    }
    if d == Disposition.PR_ONLY {
        return 2;
    }
    return 1;
}


def _cap(d: Disposition, ceiling: Disposition) -> Disposition {
    return d if _rank(d) <= _rank(ceiling) else ceiling;
}


def classify(f: Finding, risk_ceiling: RiskTier) -> Candidate {
    trace: list[str] = [];
    (risk, disp) = _base_disposition(f.detector, f, trace);

    if f.source == "agent" {
        capped = _cap(disp, Disposition.PR_ONLY);
        if capped != disp {
            trace.append("agent source -> capped at pr-only");
        }
        disp = capped;
    }

    if f.has_veto() {
        if disp != Disposition.REPORT_ONLY {
            trace.append(
                f"veto ({', '.join(f.veto_kinds())}) -> capped at report-only"
            );
        }
        disp = Disposition.REPORT_ONLY;
    }

    if int(risk.value) > int(risk_ceiling.value) {
        if disp != Disposition.REPORT_ONLY {
            trace.append(
                f"risk {risk_tier_label(risk)} exceeds ceiling "
                f"{risk_tier_label(risk_ceiling)} -> report-only"
            );
        }
        disp = Disposition.REPORT_ONLY;
    }

    return Candidate(finding=f, risk=risk, disposition=disp, trace=trace);
}
