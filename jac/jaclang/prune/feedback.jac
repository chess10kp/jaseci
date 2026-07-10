import os;
import json;
import from typing { cast }
import from jaclang.prune.finding { Candidate }


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
        reason: str = "";

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
            "reason": self.reason
        };
    }
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
