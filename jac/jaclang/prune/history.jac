import os;
import subprocess;


obj GroupHistory {
    has group_id: str,
        available: bool,
        tandem_commits: int = 0,
        union_commits: int = 0,
        tandem_ratio: float = 0.0,
        last_divergent_commit: str = "",
        last_divergent_member: str = "",
        last_divergent_subject: str = "";

    def as_dict -> dict {
        return {
            "available": self.available,
            "tandem_commits": self.tandem_commits,
            "union_commits": self.union_commits,
            "tandem_ratio": self.tandem_ratio,
            "last_divergent_commit": self.last_divergent_commit,
            "last_divergent_member": self.last_divergent_member,
            "last_divergent_subject": self.last_divergent_subject
        };
    }
}


def git_root(path: str) -> (str | None) {
    start = path if os.path.isdir(path) else os.path.dirname(path);
    try {
        res = subprocess.run(
            ["git", "-C", start, "rev-parse", "--show-toplevel"],
            capture_output=True,
            text=True
        );
    } except Exception {
        return None;
    }
    if res.returncode != 0 {
        return None;
    }
    out = res.stdout.strip();
    return out;
}


def _line_range(path: str, byte_start: int, byte_end: int) -> (tuple[int, int] | None) {
    try {
        with open(path, "rb") as fh {
            data = fh.read();
        }
    } except Exception {
        return None;
    }
    if byte_end > len(data) {
        return None;
    }
    l1 = data[:byte_start].count(b"\n") + 1;
    l2 = data[:byte_end].count(b"\n") + 1;
    return (l1, l2);
}


def _commits_touching(repo: str, path: str, l1: int, l2: int) -> (dict | None) {
    rel = os.path.relpath(path, repo);
    spec = f"-L{l1},{l2}:{rel}";
    try {
        res = subprocess.run(
            ["git", "-C", repo, "log", "-s", spec, "--format=%H%x1f%ct%x1f%s"],
            capture_output=True,
            text=True
        );
    } except Exception {
        return None;
    }
    if res.returncode != 0 {
        return None;
    }
    out: dict = {};
    for line in res.stdout.splitlines() {
        if not line {
            continue;
        }
        parts = line.split("\x1f");
        if len(parts) < 3 {
            continue;
        }
        h = parts[0];
        ct = int(parts[1]) if parts[1].isdigit() else 0;
        out[h] = (ct, parts[2]);
    }
    return out;
}


def group_history(group: any, repo: str) -> GroupHistory {
    member_sets: list[dict] = [];
    for m in group.members {
        rng = _line_range(m.body_file, m.body_pos_start, m.body_pos_end);
        if rng is None {
            continue;
        }
        (l1, l2) = rng;
        commits = _commits_touching(repo, m.body_file, l1, l2);
        if commits is None {
            continue;
        }
        member_sets.append({"symbol_id": m.symbol_id, "commits": commits});
    }
    if len(member_sets) < 2 {
        return GroupHistory(group_id=group.group_id, available=False);
    }

    freq: dict = {};
    meta: dict = {};
    owner: dict = {};
    for ms in member_sets {
        for (h, val) in ms["commits"].items() {
            freq[h] = freq.get(h, 0) + 1;
            meta[h] = val;
            owner[h] = ms["symbol_id"];
        }
    }
    union_commits = len(freq);
    tandem = 0;
    solo: list[str] = [];
    for (h, n) in freq.items() {
        if n >= 2 {
            tandem += 1;
        } else {
            solo.append(h);
        }
    }
    ratio = (tandem / union_commits) if union_commits > 0 else 0.0;

    best_h = "";
    best_ct = -1;
    for h in solo {
        (ct, _subj) = meta[h];
        if ct > best_ct or (ct == best_ct and h < best_h) {
            best_ct = ct;
            best_h = h;
        }
    }
    div_member = "";
    div_subject = "";
    if best_h {
        div_member = owner[best_h];
        (_ct, div_subject) = meta[best_h];
    }
    return GroupHistory(
        group_id=group.group_id,
        available=True,
        tandem_commits=tandem,
        union_commits=union_commits,
        tandem_ratio=ratio,
        last_divergent_commit=best_h,
        last_divergent_member=div_member,
        last_divergent_subject=div_subject
    );
}


def annotate_histories(groups: list, repo: str) -> dict[str, GroupHistory] {
    out: dict[str, GroupHistory] = {};
    for g in groups {
        out[g.group_id] = group_history(g, repo);
    }
    return out;
}
