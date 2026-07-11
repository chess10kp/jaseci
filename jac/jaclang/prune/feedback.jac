import os;
import json;
import from typing { cast }
import from jaclang.prune.finding { Candidate }


glob VERDICT_DECISIONS = {"accept", "reject", "contested"},
     FATE_OUTCOMES = {"landed-unchanged", "landed-modified", "abandoned", "reverted", };


def valid_decision(decision: str) -> bool {
    return decision.strip().lower() in VERDICT_DECISIONS;
}


def valid_fate(fate: str) -> bool {
    return (not fate.strip()) or fate.strip().lower() in FATE_OUTCOMES;
}


obj FeedbackEntry {
    has fingerprint: str,
        detector: str,
        symbol_id: str,
        name: str,
        module_path: str,
        risk: str,
        disposition: str,
        source: str,
        outcome: str,
        reason: str = "",
        citations: list[str] = [],
        fate: str = "";

    def as_dict -> dict {
        return {
            "fingerprint": self.fingerprint,
            "detector": self.detector,
            "symbol_id": self.symbol_id,
            "name": self.name,
            "module_path": self.module_path,
            "risk": self.risk,
            "disposition": self.disposition,
            "source": self.source,
            "outcome": self.outcome,
            "reason": self.reason,
            "citations": self.citations,
            "fate": self.fate
        };
    }
}


def packet_citation_ids(packet: dict) -> set {
    p: any = packet;
    ids: set = set();
    for c in p.get("citations", []) {
        ids.add(str(c));
    }
    idx: any = p.get("cite_index", {});
    for cid in idx.keys() {
        ids.add(str(cid));
    }
    return ids;
}


def citation_gate(cited: list[str], packet: dict) -> list[str] {
    available = packet_citation_ids(packet);
    return [
        c
        for c in cited
        if c not in available
    ];
}


def verdict_entry(
    meta: dict, decision: str, citations: list[str], note: str = "", fate: str = ""
) -> FeedbackEntry {
    d: any = meta;
    return FeedbackEntry(
        fingerprint=str(d.get("fingerprint", "")),
        detector=str(d.get("detector", "")),
        symbol_id=str(d.get("symbol_id", "")),
        name=str(d.get("name", "")),
        module_path=str(d.get("module_path", "")),
        risk=str(d.get("risk", "")),
        disposition=str(d.get("disposition", "")),
        source=str(d.get("source", "")),
        outcome=f"verdict-{decision.strip().lower()}",
        reason=note,
        citations=citations,
        fate=fate.strip().lower()
    );
}


def entry_from_candidate(
    cand: Candidate, outcome: str, reason: str = ""
) -> FeedbackEntry {
    f = cand.finding;
    return FeedbackEntry(
        fingerprint=f.fingerprint(),
        detector=f.detector,
        symbol_id=f.symbol_id,
        name=f.name,
        module_path=f.module_path,
        risk=str(cand.risk.value),
        disposition=str(cand.disposition.value),
        source=f.source,
        outcome=outcome,
        reason=reason
    );
}


obj FeedbackLog {
    has path: str;

    def record_all(entries: list[FeedbackEntry]) -> bool {
        if not entries {
            return True;
        }
        try {
            parent = os.path.dirname(self.path);
            if parent and not os.path.isdir(parent) {
                os.makedirs(parent, exist_ok=True);
            }
            with open(self.path, "a") as fh {
                for e in entries {
                    fh.write(json.dumps(e.as_dict()) + "\n");
                }
            }
        } except Exception {
            return False;
        }
        return True;
    }

    def read_all -> list[dict] {
        out: list[dict] = [];
        if not os.path.exists(self.path) {
            return out;
        }
        try {
            with open(self.path) as fh {
                for line in fh {
                    stripped = line.strip();
                    if stripped {
                        out.append(cast(dict, json.loads(stripped)));
                    }
                }
            }
        } except Exception {
            return out;
        }
        return out;
    }

    def outcome_counts -> dict[str, int] {
        counts: dict[str, int] = {};
        for rec in self.read_all() {
            d: any = rec;
            key = str(d.get("outcome", "unknown"));
            counts[key] = counts.get(key, 0) + 1;
        }
        return counts;
    }
}
