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

    def packet_citations -> list[str] {
        if self.citations {
            return self.citations;
        }
        return ["sym:" + self.symbol_id] if self.symbol_id else [];
    }
}


def _q(question: str, how: str, expect: str) -> dict {
    return {"q": question, "how": how, "expect": expect};
}


def _grep_string_lit(name: str) -> str {
    return f"grep -rn '\"{name}\"' --include='*.jac' <root>";
}


def verify_questions(f: Finding) -> list[dict] {
    det = f.detector;
    nm = f.name;
    if det == "unused-imports" {
        return [
            _q(
                f"Is '{nm}' referenced dynamically (string literal / getattr) anywhere in scope?",
                _grep_string_lit(nm),
                "no hits outside the decl module; any hit = dynamic-dispatch risk"
            ),
            _q(
                "Is the import a try/except importability probe (name intentionally unused)?",
                "open the import site; look for an enclosing try { ... } except ImportError",
                "not inside a try/except import guard"
            )
        ];
    }
    if det == "private-dead-defs" {
        return [
            _q(
                f"Is '{nm}' invoked reflectively (getattr / registry / string dispatch)?",
                _grep_string_lit(nm),
                "no dynamic reference; only the decl site appears"
            ),
            _q(
                f"Is '{nm}' a test/entry hook discovered by name convention?",
                "check for test-runner or plugin naming conventions on the name",
                "not a convention-discovered hook"
            )
        ];
    }
    if det == "dead-enum-variants" {
        return [
            _q(
                f"Is the variant '{nm}' selected by string value or serialized externally?",
                _grep_string_lit(nm),
                "no external/string selection of the variant"
            ),
            _q(
                "Is this enum part of a public API surface (persisted / wire format)?",
                "check whether the enum crosses a module/package boundary or is serialized",
                "internal enum only"
            )
        ];
    }
    if det == "write-only-fields" {
        return [
            _q(
                f"Is field '{nm}' read via getattr / serialization / reflection?",
                _grep_string_lit(nm),
                "no reflective or serialized read of the field"
            )
        ];
    }
    if det == "literal-dead-branch" {
        return [
            _q(
                "Is the literal condition a deliberate feature flag or debug toggle?",
                "read the branch; confirm the constant is not a config-swappable flag",
                "constant is a true dead branch, not a toggle"
            )
        ];
    }
    if det == "single-caller-inline" {
        return [
            _q(
                f"Does the sole caller of '{nm}' do real work around the call, or purely forward?",
                "read the caller body; confirm it is a thin forward with no added logic",
                "caller forwards with negligible surrounding logic"
            ),
            _q(
                f"Is '{nm}' referenced anywhere besides the one static call site?",
                _grep_string_lit(nm),
                "no other (dynamic) references"
            )
        ];
    }
    if det == "visibility-tightening" {
        return [
            _q(
                f"Is '{nm}' an entry point invoked via a registry (CLI command / plugin)?",
                "check for a decorator/registry registration keyed on the name",
                "not registry-dispatched"
            ),
            _q(
                f"Is '{nm}' re-exported by a package __init__.jac as public API?",
                f"grep -rn '{nm}' --include='__init__.jac' <root>",
                "not re-exported (safe to demote)"
            )
        ];
    }
    if det == "duplicated-constant-blobs" {
        return [
            _q(
                "Are the duplicated literals semantically the same constant, or coincidental?",
                "compare the cited sites; confirm one canonical meaning",
                "same logical constant at every site"
            )
        ];
    }
    if det == "duplicate-docstrings" {
        return [
            _q(
                "Do the symbols sharing this doc genuinely have the same contract?",
                "read each cited symbol; confirm the doc is not a stale copy-paste",
                "same contract, one canonical doc is correct"
            )
        ];
    }
    if det == "module-cohesion" {
        return [
            _q(
                "Do the disconnected clusters (or the tight seam) reflect real subsystems?",
                "read the cited representative symbols per cluster / the two modules",
                "clusters are independent concerns, not incidental helpers"
            )
        ];
    }
    if det.startswith("agent-") {
        return [
            _q(
                "Do the cited facts independently support this redundancy claim?",
                "resolve each citation and confirm the structural relationship holds",
                "every citation checks out; claim reproduces from facts"
            )
        ];
    }
    return [
        _q(
            f"Is '{nm}' referenced dynamically anywhere in scope?",
            _grep_string_lit(nm),
            "no dynamic reference outside the decl module"
        )
    ];
}


def reuse_verify_questions(tier: str) -> list[dict] {
    out = [
        _q(
            "Are all members complete bodies (not decl-only stubs) and semantically equivalent?",
            "read each cited member body; confirm identical intent modulo the deltas",
            "every member is a real, equivalent implementation"
        ),
        _q(
            "Do the members share an owner relation (same owner / sibling archetypes with a common base) enabling a pull-up?",
            "compare member owner_id / owner_name; check for a shared base archetype",
            "a hosting seam exists (shared owner or common base), else extract-helper only"
        ),
        _q(
            "Do the deltas reduce to parameters, or include callee/behavior differences (harder merge)?",
            "inspect each member's `vector` delta slots; note literal-only vs callee deltas",
            "literal-only deltas parameterize cleanly; callee deltas need a hook"
        ),
        _q(
            "Have the members drifted deliberately (would merging discard an intended divergence)?",
            "git log -p over the member spans; look for divergent edits post-copy",
            "no intended divergence; the copies are still meant to stay in lockstep"
        )
    ];
    if "fuzz" in tier or tier == "t3" {
        out.append(
            _q(
                "Is the shared material contiguous (real shared logic) or coincidental shingle overlap?",
                "compare the members' struct_tokens; check longest-common-subsequence contiguity",
                "shared tokens form a contiguous block, not scattered coincidences"
            )
        );
    }
    return out;
}


obj Candidate {
    has finding: Finding,
        risk: RiskTier,
        disposition: Disposition,
        trace: list[str] = [];

    def as_dict(cite_index: dict | None = None) -> dict {
        f = self.finding;
        idx = cite_index if cite_index is not None else {};
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
            "verify": verify_questions(f),
            "citations": f.packet_citations(),
            "cite_index": idx,
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
    if detector == "module-cohesion" {
        trace.append("module-cohesion seam-review (advisory) -> moderate/report-only");
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
