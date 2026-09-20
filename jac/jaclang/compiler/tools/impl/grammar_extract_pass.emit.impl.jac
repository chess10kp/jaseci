impl GrammarExtractPass.format_ebnf(expr: GExpr) -> str {
    fmt = GrammarExtractPass.format_ebnf;
    if isinstance(expr, GSeq) {
        parts: list[str] = [];
        for item in expr.items {
            s = fmt(item);

            if isinstance(item, GAlt) and len(item.choices) > 1 {
                s = f"({s})";
            }
            parts.append(s);
        }
        return " ".join(parts);
    }
    if isinstance(expr, GAlt) {
        parts2: list[str] = [];
        for choice in expr.choices {
            parts2.append(fmt(choice));
        }
        return " | ".join(parts2);
    }
    if isinstance(expr, GOpt) {
        inner = fmt(expr.inner);
        if isinstance(expr.inner, (GAlt, GSeq)) {
            return f"({inner})?";
        }
        return f"{inner}?";
    }
    if isinstance(expr, GStar) {
        inner = fmt(expr.inner);
        if isinstance(expr.inner, (GAlt, GSeq)) {
            return f"({inner})*";
        }
        return f"{inner}*";
    }
    if isinstance(expr, GPlus) {
        inner = fmt(expr.inner);
        if isinstance(expr.inner, (GAlt, GSeq)) {
            return f"({inner})+";
        }
        return f"{inner}+";
    }
    if isinstance(expr, GTok) {
        kind = getattr(TokenKind, expr.name, None);
        if kind is not None and kind.value != expr.name {
            val = kind.value;

            if '"' in val {
                return f"'{val}'";
            }
            return f'"{val}"';
        }
        return expr.name;
    }
    if isinstance(expr, GRef) {
        return expr.name;
    }
    return "???";
}

impl GrammarExtractPass.prepare with entry {
    if self.ctx.nested_depth {
        return;
    }
    self.rules = [];
    self.diagnostics = [];
    self._parse_impls = [];
    self._rule_firsts = {};
    self._none_returning = {};
    self._helper_bodies = {};
}

impl GrammarExtractPass._returns_none(nd: uni.ImplDef) -> bool {
    spec = nd.spec;
    if not isinstance(spec, uni.FuncSignature) {
        return False;
    }
    if spec.return_type is None {
        return False;
    }
    rt: uni.UniNode = spec.return_type;
    while True {
        if isinstance(rt, uni.CfgExpr) {
            rt = rt.expr;
            continue;
        }
        if isinstance(rt, uni.AtomUnit) and rt.value is not None {
            rt = rt.value;
            continue;
        }
        break;
    }

    if isinstance(rt, uni.Name) and rt.value == "int" {
        return True;
    }
    stack: list[uni.UniNode] = [spec.return_type];
    while len(stack) > 0 {
        cur = stack.pop();
        if isinstance(cur, uni.Null) {
            return True;
        }
        for k in (cur.kid or []) {
            stack.append(k);
        }
    }
    return False;
}

impl GrammarExtractPass.finish with exit {
    if self.ctx.nested_depth {
        return;
    }
    self.rules = self._interpret_all();

    for _round in range(3) {
        self._rule_firsts = self._compute_rule_firsts(self.rules);
        new_rules = self._interpret_all();
        if repr(new_rules) == repr(self.rules) {
            break;
        }
        self.rules = new_rules;
    }
    for (rule_name, stmts) in self._parse_impls {
        self._collect_strict_diags(rule_name, stmts);
    }
    self.rules = self._stage_simplify(self.rules);
    self.rules = self._stage_unwrap_top_opt(self.rules);
    self.rules = self._stage_dedup_tokens(self.rules);

    self.rules = self._stage_remove_errors(self.rules);
    self.rules = self._stage_elide_covered_guards(self.rules);
    self.rules = self._stage_simplify(self.rules);
    self.rules = self._stage_inline_aliases(self.rules);
    self.rules = self._stage_fold_token_sets(self.rules);
    self.rules = self._stage_remove_unreachable(self.rules);
}

impl GrammarExtractPass._interpret_all -> list[GrammarRule] {
    result: list[GrammarRule] = [];
    for (rule_name, stmts) in self._parse_impls {
        self._current_rule = rule_name;
        grammar_expr = self.interpret_stmts(list(stmts));
        if grammar_expr is not None {
            result.append(GrammarRule(name=rule_name, body=grammar_expr));
        }
    }
    self._current_rule = "";
    return result;
}

impl GrammarExtractPass.emit_diagnostics -> str {
    if len(self.diagnostics) == 0 {
        return "grammar strict check: no findings";
    }
    rows: list[tuple[str, int, str, str]] = [];
    for d in self.diagnostics {
        rows.append((d["rule"], d["line"], d["kind"], d["msg"]));
    }
    rows.sort();
    counts: dict[str, int] = {};
    lines: list[str] = [];
    for (rule, line, kind, msg) in rows {
        lines.append(f"{rule} (line {line}): [{kind}] {msg}");
        counts[kind] = counts.get(kind, 0) + 1;
    }
    summary_parts: list[str] = [];
    for (k, v) in sorted(counts.items()) {
        summary_parts.append(f"{v} {k}");
    }
    header = (
        f"grammar strict check: {len(rows)} finding(s) ({', '.join(summary_parts)})"
    );
    return header + "\n" + "\n".join(lines);
}

impl GrammarExtractPass.format_rule_pretty(
    rule: GrammarRule, sep: str = "::=", max_line: int = 88
) -> str {
    body = GrammarExtractPass.format_ebnf(rule.body);
    prefix = f"{rule.name} {sep} ";
    if len(prefix + body) <= max_line {
        return prefix + body;
    }
    return f"{rule.name} {sep}\n" + self.format_expr_pretty(rule.body, 4, max_line);
}

impl GrammarExtractPass.format_expr_pretty(
    expr: GExpr, indent: int, max_line: int
) -> str {
    pad = " " * indent;
    flat = GrammarExtractPass.format_ebnf(expr);
    if len(pad) + len(flat) <= max_line {
        return pad + flat;
    }
    if isinstance(expr, GAlt) {
        return self.format_alt_pretty(expr.choices, indent, max_line);
    }
    if isinstance(expr, GSeq) {
        return self.format_seq_pretty(expr.items, indent, max_line);
    }
    if isinstance(expr, GOpt) {
        return self.format_group_pretty(expr.inner, indent, max_line, "?");
    }
    if isinstance(expr, GStar) {
        return self.format_group_pretty(expr.inner, indent, max_line, "*");
    }
    if isinstance(expr, GPlus) {
        return self.format_group_pretty(expr.inner, indent, max_line, "+");
    }
    return pad + flat;
}

impl GrammarExtractPass.format_alt_pretty(
    choices: list[GExpr], indent: int, max_line: int
) -> str {
    lines: list[str] = [];
    for (i, choice) in enumerate(choices) {
        if i == 0 {
            prefix = " " * indent;
        } else {
            prefix = " " * indent + "| ";
        }
        choice_flat = GrammarExtractPass.format_ebnf(choice);
        if len(prefix) + len(choice_flat) <= max_line {
            lines.append(prefix + choice_flat);
        } else {
            expanded = self.format_expr_pretty(choice, len(prefix), max_line);
            exp_lines = expanded.split("\n");
            lines.append(prefix + exp_lines[0].lstrip());
            for el in exp_lines[1:] {
                lines.append(el);
            }
        }
    }
    return "\n".join(lines);
}

impl GrammarExtractPass.format_seq_pretty(
    items: list[GExpr], indent: int, max_line: int
) -> str {
    pad = " " * indent;
    lines: list[str] = [];
    cur = pad;
    for item in items {
        item_flat = GrammarExtractPass.format_ebnf(item);
        if isinstance(item, GAlt) and len(item.choices) > 1 {
            item_flat = f"({item_flat})";
        }

        if cur == pad {
            candidate = cur + item_flat;
        } else {
            candidate = cur + " " + item_flat;
        }
        if len(candidate) <= max_line {
            cur = candidate;
            continue;
        }

        if len(pad + item_flat) <= max_line {
            if cur != pad {
                lines.append(cur);
            }
            cur = pad + item_flat;
            continue;
        }

        group_inner: GExpr | None = None;
        suffix = "";
        if isinstance(item, GOpt) and isinstance(item.inner, (GAlt, GSeq)) {
            group_inner = item.inner;
            suffix = "?";
        } elif isinstance(item, GStar) and isinstance(item.inner, (GAlt, GSeq)) {
            group_inner = item.inner;
            suffix = "*";
        } elif isinstance(item, GAlt) and len(item.choices) > 1 {
            group_inner = item;
            suffix = "";
        }
        if group_inner is not None {
            if cur != pad {
                lines.append(cur + " (");
            } else {
                lines.append(pad + "(");
            }

            inner_str = self.format_expr_pretty(group_inner, indent + 4, max_line);
            lines.append(inner_str);
            cur = pad + ")" + suffix;
        } else {
            if cur != pad {
                lines.append(cur);
            }
            expanded = self.format_expr_pretty(item, indent, max_line);
            lines.append(expanded);
            cur = pad;
        }
    }
    if cur != pad {
        lines.append(cur);
    }
    return "\n".join(lines);
}

impl GrammarExtractPass.format_group_pretty(
    inner: GExpr, indent: int, max_line: int, suffix: str
) -> str {
    pad = " " * indent;
    inner_flat = GrammarExtractPass.format_ebnf(inner);
    needs_parens = isinstance(inner, (GAlt, GSeq));
    if not needs_parens {
        return pad + inner_flat + suffix;
    }
    inline = f"({inner_flat}){suffix}";
    if len(pad) + len(inline) <= max_line {
        return pad + inline;
    }
    inner_str = self.format_expr_pretty(inner, indent + 4, max_line);
    return f"{pad}(\n{inner_str}\n{pad}){suffix}";
}

impl GrammarExtractPass.emit_ebnf -> str {
    lines: list[str] = [];
    for rule in self.rules {
        lines.append(self.format_rule_pretty(rule, "::=", 88));
    }
    return "\n\n".join(lines);
}
