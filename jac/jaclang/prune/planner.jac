import os;

import from jaclang.prune.finding { Candidate, Finding }
import from jaclang.prune.campaign { Disposition }
import from jaclang.prune.spanedit { SpanEdit, make_edit }


glob _NL = 10,
     _CR = 13,
     _SP = 32,
     _TAB = 9,
     _HASH = 35,
     _SEMI = 59,
     _COMMA = 44,
     _OPENERS = {40, 91, 123},
     _CLOSERS = {41, 93, 125};


obj FileEdits {
    has path: str,
        edits: list[SpanEdit] = [],
        provenance: list[str] = [];
}


obj PatchPlan {
    has files: dict[str, FileEdits] = {},
        skipped: list[str] = [];

    def edit_count -> int {
        n = 0;
        for fe in self.files.values() {
            n += len(fe.edits);
        }
        return n;
    }

    def file_count -> int {
        return len(self.files);
    }
}


def _is_hspace(b: int) -> bool {
    return b == _SP or b == _TAB;
}


def _is_ws(b: int) -> bool {
    return b == _SP or b == _TAB or b == _NL or b == _CR;
}


def _is_ident(b: int) -> bool {
    return (b >= 48 and b <= 57)
    or (b >= 65 and b <= 90)
    or (b >= 97 and b <= 122)
    or b == 95;
}


def _line_start(data: bytes, pos: int) -> int {
    i = pos;
    while i > 0 and data[i - 1] != _NL {
        i -= 1;
    }
    return i;
}


def _line_end(data: bytes, pos: int) -> int {
    i = pos;
    n = len(data);
    while i < n and data[i] != _NL {
        i += 1;
    }
    if i < n and data[i] == _NL {
        i += 1;
    }
    return i;
}


def _prefix_blank(data: bytes, lo: int, hi: int) -> bool {
    i = lo;
    while i < hi {
        if not _is_hspace(data[i]) {
            return False;
        }
        i += 1;
    }
    return True;
}


def _line_is_comment(data: bytes, ls: int) -> bool {
    i = ls;
    n = len(data);
    while i < n and _is_hspace(data[i]) {
        i += 1;
    }
    return i < n and data[i] == _HASH;
}


def _expand_leading_comments(data: bytes, ls: int) -> int {
    cur = ls;
    while cur > 0 {
        prev_nl = cur - 1;
        pstart = _line_start(data, prev_nl);
        if _prefix_blank(data, pstart, prev_nl) {
            break;
        }
        if not _line_is_comment(data, pstart) {
            break;
        }
        cur = pstart;
    }
    return cur;
}


def _bracket_balanced(data: bytes, lo: int, hi: int) -> bool {
    depth = 0;
    i = lo;
    while i < hi {
        b = data[i];
        if b in _OPENERS {
            depth += 1;
        } elif b in _CLOSERS {
            depth -= 1;
            if depth < 0 {
                return False;
            }
        }
        i += 1;
    }
    return depth == 0;
}


def _rstrip(data: bytes, lo: int, hi: int) -> int {
    j = hi;
    while j > lo and _is_ws(data[j - 1]) {
        j -= 1;
    }
    return j;
}


def _decl_prefix_ok(data: bytes, ls: int, name_start: int) -> bool {
    i = ls;
    while i < name_start {
        b = data[i];
        ok = _is_hspace(b)
        or b == 58
        or (b >= 65 and b <= 90)
        or (b >= 97 and b <= 122);
        if not ok {
            return False;
        }
        i += 1;
    }
    return True;
}


def _plan_dead_def(f: Finding, data: bytes) -> tuple[list[SpanEdit], str] {
    start = f.pos_start;
    end = f.pos_end;
    if start < 0 or end > len(data) or start >= end {
        return ([], "declaration span out of range");
    }
    ls = _line_start(data, start);
    if not _decl_prefix_ok(data, ls, start) {
        return ([], "declaration does not start its line");
    }
    le = _line_end(data, end - 1);
    content_end = _rstrip(data, ls, le);
    if content_end <= ls or data[content_end - 1] != _SEMI {
        return ([], "declaration is not a single-line ';'-terminated statement");
    }
    if not _bracket_balanced(data, ls, content_end) {
        return ([], "declaration spans multiple lines / unbalanced brackets");
    }
    del_start = _expand_leading_comments(data, ls);
    edit = make_edit(data, del_start, le, b"", f"delete dead def '{f.name}'");
    return ([edit], "");
}


def _skip_ws_fwd(data: bytes, i: int, limit: int) -> int {
    while i < limit and _is_ws(data[i]) {
        i += 1;
    }
    return i;
}


def _item_end_with_alias(data: bytes, item_end: int, limit: int) -> int {
    j = _skip_ws_fwd(data, item_end, limit);
    if j + 2 <= limit and data[j] == 97 and data[j + 1] == 115 {
        after = j + 2;
        if after >= limit or not _is_ident(data[after]) {
            k = _skip_ws_fwd(data, after, limit);
            start_id = k;
            while k < limit and _is_ident(data[k]) {
                k += 1;
            }
            if k > start_id {
                return k;
            }
        }
    }
    return item_end;
}


def _plan_unused_import(f: Finding, data: bytes) -> tuple[list[SpanEdit], str] {
    meta: any = f.plan_meta;
    n_items = int(meta.get("n_items", 1));
    s_start = int(meta.get("stmt_pos_start", 0));
    s_end = int(meta.get("stmt_pos_end", 0));

    if n_items <= 1 {
        if s_end <= s_start or s_end > len(data) {
            return ([], "statement span out of range");
        }
        ls = _line_start(data, s_start);
        del_start = ls if _prefix_blank(data, ls, s_start) else s_start;
        le = _line_end(data, s_end - 1);
        del_start = _expand_leading_comments(data, del_start)
            if del_start == ls
            else del_start;
        edit = make_edit(data, del_start, le, b"", f"delete unused import '{f.name}'");
        return ([edit], "");
    }

    istart = f.pos_start;
    iend = f.pos_end;
    if istart < s_start or iend > s_end or istart >= iend {
        return ([], "import item span out of range");
    }
    iend = _item_end_with_alias(data, iend, s_end);

    after = _skip_ws_fwd(data, iend, s_end);
    if after < s_end and data[after] == _COMMA {
        del_end = _skip_ws_fwd(data, after + 1, s_end);
        edit = make_edit(data, istart, del_end, b"", f"drop import item '{f.name}'");
        return ([edit], "");
    }

    j = istart;
    while j > s_start and _is_ws(data[j - 1]) {
        j -= 1;
    }
    if j > s_start and data[j - 1] == _COMMA {
        edit = make_edit(data, j - 1, iend, b"", f"drop import item '{f.name}'");
        return ([edit], "");
    }
    return ([], "could not locate a comma to repair");
}


def plan_candidate(c: Candidate, data: bytes) -> tuple[list[SpanEdit], str] {
    if c.disposition != Disposition.AUTO_FIX {
        return ([], "disposition is not auto-fix");
    }
    det = c.finding.detector;
    if det == "unused-imports" {
        return _plan_unused_import(c.finding, data);
    }
    if det == "private-dead-defs" {
        return _plan_dead_def(c.finding, data);
    }
    return ([], f"no planner for detector '{det}'");
}


def build_plan(candidates: list[Candidate]) -> PatchPlan {
    plan = PatchPlan(files={}, skipped=[]);
    cache: dict[str, bytes] = {};
    for c in candidates {
        path = c.finding.module_path;
        fp = c.finding.fingerprint();
        if path not in cache {
            try {
                with open(path, "rb") as fh {
                    cache[path] = fh.read();
                }
            } except Exception as e {
                plan.skipped.append(f"{fp}: cannot read {path}: {e}");
                cache[path] = b"";
            }
        }
        data = cache[path];
        if not data {
            continue;
        }
        (edits, reason) = plan_candidate(c, data);
        if reason != "" {
            plan.skipped.append(f"{fp}: {reason}");
            continue;
        }
        if path not in plan.files {
            plan.files[path] = FileEdits(path=path, edits=[], provenance=[]);
        }
        fe = plan.files[path];
        for e in edits {
            fe.edits.append(e);
        }
        fe.provenance.append(fp);
    }
    return plan;
}
