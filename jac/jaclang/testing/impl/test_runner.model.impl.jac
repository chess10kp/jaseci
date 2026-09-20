impl TestOutcome.is_failure -> bool {
    return self.status in (FAILED, ERROR, CRASHED);
}

impl TestOutcome.to_wire -> dict[(str, any)] {
    return {
        "file": self.file,
        "name": self.name,
        "status": self.status,
        "message": self.message,
        "duration": self.duration
    };
}

impl TestOutcome.from_wire(payload: dict[(str, any)]) -> TestOutcome {
    return TestOutcome(
        file=payload["file"],
        name=payload["name"],
        status=payload["status"],
        message=payload.get("message", ""),
        duration=payload.get("duration", 0.0)
    );
}

impl TestPlan.is_empty -> bool {
    return not self.files;
}

impl NameFilter.postinit -> None {
    self.tree = _parse_filter_expr(self.expr);
}

impl NameFilter.matches(name: str) -> bool {
    if self.tree is None {
        return True;
    }
    return _eval_filter(self.tree, name.lower());
}

impl _tokenize_filter(expr: str) -> list[str] {
    toks: list[str] = [];
    cur = "";
    for ch in expr {
        if ch in "()" {
            if cur {
                toks.append(cur);
                cur = "";
            }
            toks.append(ch);
        } elif ch.isspace() {
            if cur {
                toks.append(cur);
                cur = "";
            }
        } else {
            cur += ch;
        }
    }
    if cur {
        toks.append(cur);
    }
    return toks;
}

impl _parse_filter_expr(expr: str) -> any {
    text = expr.strip();
    if not text {
        return None;
    }
    toks = _tokenize_filter(text);
    if not toks {
        return None;
    }
    pos = [0];
    tree: any = None;
    try {
        tree = _parse_or(toks, pos);
    } except ValueError {
        return ("word", text.lower());
    }
    if pos[0] != len(toks) {
        return ("word", text.lower());
    }
    return tree;
}

impl _parse_or(toks: list[str], pos: list[int]) -> any {
    tree = _parse_and(toks, pos);
    while (pos[0] < len(toks)) and (toks[pos[0]] == "or") {
        pos[0] += 1;
        tree = ("or", tree, _parse_and(toks, pos));
    }
    return tree;
}

impl _parse_and(toks: list[str], pos: list[int]) -> any {
    tree = _parse_not(toks, pos);
    while (pos[0] < len(toks)) and (toks[pos[0]] == "and") {
        pos[0] += 1;
        tree = ("and", tree, _parse_not(toks, pos));
    }
    return tree;
}

impl _parse_not(toks: list[str], pos: list[int]) -> any {
    if pos[0] >= len(toks) {
        raise ValueError("unexpected end of filter expression");
    }
    tok = toks[pos[0]];
    if tok == "not" {
        pos[0] += 1;
        return ("not", _parse_not(toks, pos));
    }
    if tok == "(" {
        pos[0] += 1;
        tree = _parse_or(toks, pos);
        if (pos[0] >= len(toks)) or (toks[pos[0]] != ")") {
            raise ValueError("unbalanced parenthesis in filter expression");
        }
        pos[0] += 1;
        return tree;
    }
    if tok in (")", "and", "or") {
        raise ValueError(f"unexpected token {tok!r} in filter expression");
    }
    pos[0] += 1;
    return ("word", tok.lower());
}

impl _eval_filter(expr_node: any, name: str) -> bool {
    kind = expr_node[0];
    if kind == "word" {
        return expr_node[1] in name;
    }
    if kind == "not" {
        return not _eval_filter(expr_node[1], name);
    }
    if kind == "and" {
        return _eval_filter(expr_node[1], name) and _eval_filter(expr_node[2], name);
    }
    return _eval_filter(expr_node[1], name) or _eval_filter(expr_node[2], name);
}

impl _build_selector(test_name: str, filter: str) -> (NameFilter | None) {
    expr = "";
    if test_name {
        parts = test_name.split();
        expr = " and ".join(parts) if parts else test_name;
    } elif filter {
        expr = filter;
    }
    if not expr {
        return None;
    }
    return NameFilter(expr=expr);
}

impl _should_ignore(path: str, ignore: list[str]) -> bool {
    if not ignore {
        return False;
    }
    target = os.path.abspath(path);
    for raw in ignore {
        if not raw {
            continue;
        }
        `entry = os.path.abspath(raw);
        if (target == `entry) or target.startswith(`entry + os.sep) {
            return True;
        }
    }
    return False;
}

impl strict_mode -> bool {
    return os.environ.get(STRICT_ENV, "").strip().lower() in ("1", "true", "yes", "on");
}

impl _match_patterns(files: list[str], patterns: (list[str] | None)) -> set[str] {
    import fnmatch;
    matched: set[str] = set();
    for raw in (patterns or []) {
        if not raw {
            continue;
        }
        pat = os.path.abspath(raw);
        for path in files {
            if path in matched {
                continue;
            }
            if fnmatch.fnmatch(path, pat) or path.startswith(pat + os.sep) {
                matched.add(path);
            }
        }
    }
    return matched;
}
