import os;
import re;

import from jaclang.prune.finding { Finding }
import from jaclang.prune.campaign { Campaign }


glob _IGNORE_RE: any = re.compile(r"#\s*jac:ignore(?:\[([^\]]*)\])?");


def _read(path: str) -> str {
    try {
        with open(path, "r", encoding="utf-8", errors="ignore") as f {
            return f.read();
        }
    } except Exception {
        return "";
    }
}


obj SuppressionSet {
    has tokens: set = set();

    def matches(f: Finding) -> bool {
        if f.fingerprint() in self.tokens {
            return True;
        }
        if f.symbol_id and f.symbol_id in self.tokens {
            return True;
        }
        return f.name in self.tokens;
    }
}


def load_suppression_file(path: str) -> SuppressionSet {
    ss = SuppressionSet();
    if not path or not os.path.exists(path) {
        return ss;
    }
    for raw in _read(path).splitlines() {
        s = raw.strip();
        if not s or s.startswith("#") {
            continue;
        }
        ss.tokens.add(s);
    }
    return ss;
}


def _resolve_suppression_path(campaign: Campaign) -> str {
    path = campaign.suppression_file;
    if path {
        if not os.path.isabs(path) {
            path = os.path.join(campaign.project_root, path);
        }
        return path;
    }
    default = os.path.join(campaign.project_root, ".jac", "prune-suppress.txt");
    return default if os.path.exists(default) else "";
}


def suppression_write_path(campaign: Campaign) -> str {
    path = campaign.suppression_file;
    if path {
        if not os.path.isabs(path) {
            path = os.path.join(campaign.project_root, path);
        }
        return path;
    }
    return os.path.join(campaign.project_root, ".jac", "prune-suppress.txt");
}


def append_suppression_token(path: str, token: str) -> bool {
    if not token {
        return False;
    }
    existing = load_suppression_file(path);
    if token in existing.tokens {
        return True;
    }
    try {
        parent = os.path.dirname(path);
        if parent and not os.path.isdir(parent) {
            os.makedirs(parent, exist_ok=True);
        }
        with open(path, "a", encoding="utf-8") as fh {
            fh.write(f"{token}\n");
        }
    } except Exception {
        return False;
    }
    return True;
}


def _module_lines(path: str, line_cache: dict) -> list {
    cached = line_cache.get(path);
    if cached is not None {
        return list(cached);
    }
    ls = _read(path).splitlines();
    line_cache[path] = ls;
    return ls;
}


def _inline_suppressed(f: Finding, line_cache: dict) -> bool {
    lines = _module_lines(f.module_path, line_cache);
    idx = f.line - 1;
    for probe in [idx, idx - 1] {
        if 0 <= probe and probe < len(lines) {
            m = _IGNORE_RE.search(str(lines[probe]));
            if m is not None {
                codes = str(m.group(1) or "").strip();
                if not codes {
                    return True;
                }
                parts = {c.strip() for c in codes.split(",")};
                if "prune" in parts or f.detector in parts {
                    return True;
                }
            }
        }
    }
    return False;
}


def filter_suppressed(
    findings: list[Finding], campaign: Campaign
) -> tuple[list[Finding], list[Finding]] {
    ss = load_suppression_file(_resolve_suppression_path(campaign));
    line_cache: dict = {};
    kept: list[Finding] = [];
    suppressed: list[Finding] = [];
    for f in findings {
        if ss.matches(f) or _inline_suppressed(f, line_cache) {
            suppressed.append(f);
        } else {
            kept.append(f);
        }
    }
    return (kept, suppressed);
}
