import from time { time }
import from jaclang.prune.spanedit { make_edit, apply_edits }
import from jaclang.prune.validate {
    Baseline,
    snapshot_baseline,
    validate_batch,
    select_affected_tests_from_prog
}


glob PROBE_TOP_K = 5;


obj MemberProbe {
    has symbol_id: str,
        status: str,
        failed_stage: str = "",
        detail: str = "",
        new_diags: list[str] = [],
        affected_tests: list[str] = [];

    def as_dict -> dict {
        return {
            "symbol_id": self.symbol_id,
            "status": self.status,
            "failed_stage": self.failed_stage,
            "detail": self.detail,
            "new_diags": self.new_diags,
            "affected_tests": self.affected_tests
        };
    }
}


obj GroupProbe {
    has group_id: str,
        status: str,
        members: list[MemberProbe] = [],
        wall_ms: int = 0;

    def as_dict -> dict {
        return {
            "group_id": self.group_id,
            "status": self.status,
            "members": [m.as_dict() for m in self.members],
            "wall_ms": self.wall_ms
        };
    }
}


def _read(path: str) -> (bytes | None) {
    try {
        with open(path, "rb") as fh {
            return fh.read();
        }
    } except Exception {
        return None;
    }
}


def _write(path: str, data: bytes) {
    with open(path, "wb") as fh {
        fh.write(data);
    }
}


def _line_indent(data: bytes, pos: int) -> int {
    ls = data.rfind(b"\n", 0, pos) + 1;
    i = ls;
    n = 0;
    while i < pos and data[i:i + 1] == b" " {
        n += 1;
        i += 1;
    }
    return n;
}


def _reindent(block: bytes, delta: int) -> bytes {
    if delta == 0 {
        return block;
    }
    lines = block.split(b"\n");
    out: list[bytes] = [lines[0]];
    for ln in lines[1:] {
        if ln.strip() == b"" {
            out.append(ln);
        } elif delta > 0 {
            out.append(b" " * delta + ln);
        } else {
            k = 0;
            m = -delta;
            while k < m and k < len(ln) and ln[k:k + 1] == b" " {
                k += 1;
            }
            out.append(ln[k:]);
        }
    }
    return b"\n".join(out);
}


def _group_status(mprobes: list[MemberProbe]) -> str {
    if not mprobes {
        return "skipped";
    }
    any_failed = False;
    any_skipped = False;
    any_passed = False;
    for m in mprobes {
        if m.status == "failed" {
            any_failed = True;
        } elif m.status == "skipped" {
            any_skipped = True;
        } elif m.status == "passed" {
            any_passed = True;
        }
    }
    if any_failed {
        return "failed";
    }
    if any_passed and any_skipped {
        return "partial";
    }
    if any_passed {
        return "passed";
    }
    return "skipped";
}


def _probe_member(
    a_block: bytes,
    a_indent: int,
    b: any,
    source_set: set,
    source_paths: list[str],
    test_paths: list[str],
    prog: any,
    baseline: Baseline
) -> MemberProbe {
    if b.body_file.endswith(".impl.jac") {
        return MemberProbe(
            symbol_id=b.symbol_id,
            status="skipped",
            detail="impl-annex substitution unsupported"
        );
    }
    if b.body_file not in source_set {
        return MemberProbe(
            symbol_id=b.symbol_id, status="skipped", detail="body outside source scope"
        );
    }
    data_b = _read(b.body_file);
    if data_b is None {
        return MemberProbe(
            symbol_id=b.symbol_id, status="skipped", detail="body file unreadable"
        );
    }
    b_indent = _line_indent(data_b, b.stmt_pos_start);
    repl = _reindent(a_block, b_indent - a_indent);
    edit = make_edit(
        data_b,
        b.stmt_pos_start,
        b.stmt_pos_end,
        replacement=repl,
        note="probe:" + b.symbol_id
    );
    res = apply_edits(data_b, [edit]);
    if not res.ok {
        return MemberProbe(
            symbol_id=b.symbol_id, status="skipped", detail="; ".join(res.errors)
        );
    }
    _write(b.body_file, res.data);
    vres = None;
    err = "";
    try {
        vres = validate_batch([b.body_file], source_paths, baseline, run_format=False);
    } except Exception as e {
        err = str(e);
    }
    _write(b.body_file, data_b);

    affected = select_affected_tests_from_prog(prog, [b.body_file], test_paths);
    if vres is None {
        return MemberProbe(
            symbol_id=b.symbol_id,
            status="failed",
            failed_stage="exception",
            detail=err,
            affected_tests=affected
        );
    }
    if vres.ok {
        return MemberProbe(
            symbol_id=b.symbol_id, status="passed", affected_tests=affected
        );
    }
    stage = vres.failed_stage();
    detail = "";
    for s in vres.stages {
        if not s.ok {
            detail = s.detail;
        }
    }
    return MemberProbe(
        symbol_id=b.symbol_id,
        status="failed",
        failed_stage=stage,
        detail=detail,
        new_diags=vres.new_diags[:8],
        affected_tests=affected
    );
}


def probe_group(
    group: any,
    source_paths: list[str],
    test_paths: list[str],
    prog: any,
    baseline: Baseline
) -> GroupProbe {
    start = time();
    members = group.members;
    if len(members) < 2 {
        return GroupProbe(group_id=group.group_id, status="skipped", members=[]);
    }
    canonical = members[0];
    data_a = _read(canonical.body_file);
    if data_a is None {
        return GroupProbe(
            group_id=group.group_id,
            status="skipped",
            members=[
                MemberProbe(
                    symbol_id=canonical.symbol_id,
                    status="skipped",
                    detail="canonical body unreadable"
                )
            ]
        );
    }
    a_block = data_a[canonical.stmt_pos_start:canonical.stmt_pos_end];
    a_indent = _line_indent(data_a, canonical.stmt_pos_start);
    source_set = set(source_paths);
    mprobes: list[MemberProbe] = [];
    for b in members[1:] {
        mprobes.append(
            _probe_member(
                a_block,
                a_indent,
                b,
                source_set,
                source_paths,
                test_paths,
                prog,
                baseline
            )
        );
    }
    return GroupProbe(
        group_id=group.group_id,
        status=_group_status(mprobes),
        members=mprobes,
        wall_ms=int((time() - start) * 1000)
    );
}


def probe_groups(
    groups: list,
    source_paths: list[str],
    test_paths: list[str],
    prog: any,
    top_k: int = 0
) -> dict[str, GroupProbe] {
    limit = top_k if top_k > 0 else PROBE_TOP_K;
    targets = groups[:limit];
    out: dict[str, GroupProbe] = {};
    if not targets {
        return out;
    }
    baseline = snapshot_baseline(source_paths);
    for g in targets {
        out[g.group_id] = probe_group(g, source_paths, test_paths, prog, baseline);
    }
    return out;
}
