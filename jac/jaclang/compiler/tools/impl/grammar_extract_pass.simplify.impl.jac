impl GrammarExtractPass.simplify_expr(expr: GExpr) -> GExpr {
    if isinstance(expr, GSeq) {
        flat: list[GExpr] = [];
        for item in expr.items {
            simplified = GrammarExtractPass.simplify_expr(item);
            if isinstance(simplified, GSeq) {
                flat.extend(simplified.items);
            } else {
                flat.append(simplified);
            }
        }
        if len(flat) == 0 {
            return GSeq(items=[]);
        }
        if len(flat) == 1 {
            return flat[0];
        }
        return GSeq(items=flat);
    }
    if isinstance(expr, GAlt) {
        flat2: list[GExpr] = [];
        seen: set = set();
        for choice in expr.choices {
            simplified = GrammarExtractPass.simplify_expr(choice);
            if isinstance(simplified, GAlt) {
                for inner_c in simplified.choices {
                    key = repr(inner_c);
                    if key not in seen {
                        flat2.append(inner_c);
                        seen.add(key);
                    }
                }
            } else {
                key2 = repr(simplified);
                if key2 not in seen {
                    flat2.append(simplified);
                    seen.add(key2);
                }
            }
        }

        wrapped: set = set();
        for c in flat2 {
            if isinstance(c, (GOpt, GStar)) {
                wrapped.add(repr(c.inner));
            }
        }
        if len(wrapped) > 0 {
            flat2 = [
                c
                for c in flat2
                if isinstance(c, (GOpt, GStar)) or repr(c) not in wrapped
            ];
        }

        has_opt = False;
        has_star = False;
        for c in flat2 {
            if isinstance(c, GOpt) {
                has_opt = True;
            }
            if isinstance(c, GStar) {
                has_star = True;
            }
        }
        if has_opt and len(flat2) > 1 {
            hoisted: list[GExpr] = [];
            for c in flat2 {
                inner_c = c.inner if isinstance(c, GOpt) else c;
                if isinstance(inner_c, GAlt) {
                    hoisted.extend(inner_c.choices);
                } else {
                    hoisted.append(inner_c);
                }
            }
            if has_star {
                return GAlt(choices=hoisted);
            }
            return GOpt(inner=GAlt(choices=hoisted));
        }
        if len(flat2) == 1 {
            return flat2[0];
        }
        return GAlt(choices=flat2);
    }
    if isinstance(expr, GOpt) {
        simplified_opt = GrammarExtractPass.simplify_expr(expr.inner);

        if isinstance(simplified_opt, GStar) {
            return simplified_opt;
        }
        return GOpt(inner=simplified_opt);
    }
    if isinstance(expr, GStar) {
        simplified_inner = GrammarExtractPass.simplify_expr(expr.inner);

        if isinstance(simplified_inner, GOpt) {
            simplified_inner = simplified_inner.inner;
        }

        if isinstance(simplified_inner, GSeq) and len(simplified_inner.items) == 2 {
            first = simplified_inner.items[0];
            second = simplified_inner.items[1];
            if isinstance(second, GStar)
                and isinstance(second.inner, GSeq)
                and len(second.inner.items) == 2
                and repr(second.inner.items[1]) == repr(first) {
                return GStar(inner=GSeq(items=[first, second.inner.items[0]]));
            }
        }
        return GStar(inner=simplified_inner);
    }
    if isinstance(expr, GPlus) {
        return GPlus(inner=GrammarExtractPass.simplify_expr(expr.inner));
    }
    return expr;
}

impl GrammarExtractPass._compute_rule_firsts(
    rules: list[GrammarRule]
) -> dict[str, tuple[set[str], bool]] {
    firsts: dict[str, tuple[set[str], bool]] = {};
    saved = self._rule_firsts;
    self._rule_firsts = {};
    for rule in rules {
        firsts[rule.name] = self.compute_first_set(rule.body);
    }
    self._rule_firsts = saved;
    return firsts;
}

impl GrammarExtractPass._stage_simplify(rules: list[GrammarRule]) -> list[GrammarRule] {
    result: list[GrammarRule] = [];
    for rule in rules {
        result.append(
            GrammarRule(
                name=rule.name, body=GrammarExtractPass.simplify_expr(rule.body)
            )
        );
    }
    return result;
}

impl GrammarExtractPass._stage_unwrap_top_opt(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    result: list[GrammarRule] = [];
    for rule in rules {
        body = rule.body;
        if isinstance(body, GOpt)
            and isinstance(body.inner, GAlt)
            and rule.name in self._none_returning {
            result.append(GrammarRule(name=rule.name, body=body.inner));
        } else {
            result.append(rule);
        }
    }
    return result;
}

impl GrammarExtractPass._stage_dedup_tokens(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    rule_map: dict[str, GrammarRule] = {};
    for rule in rules {
        rule_map[rule.name] = rule;
    }
    result: list[GrammarRule] = [];
    for rule in rules {
        result.append(
            GrammarRule(
                name=rule.name,
                body=self._dedup_parent_child_tokens(rule.body, rule_map)
            )
        );
    }
    return result;
}

impl GrammarExtractPass._compute_rule_firsts_deep(
    rules: list[GrammarRule]
) -> dict[str, tuple[set[str], bool]] {
    firsts: dict[str, tuple[set[str], bool]] = {};
    for rule in rules {
        firsts[rule.name] = (set(), False);
    }
    saved_map = self._rule_firsts;
    saved_rule = self._current_rule;
    self._rule_firsts = firsts;
    self._current_rule = "";
    for _i in range(50) {
        changed = False;
        for rule in rules {
            computed = self.compute_first_set(rule.body);
            if computed != firsts[rule.name] {
                firsts[rule.name] = computed;
                changed = True;
            }
        }
        if not changed {
            break;
        }
    }
    self._rule_firsts = saved_map;
    self._current_rule = saved_rule;
    return firsts;
}

impl GrammarExtractPass._guard_tok_set(expr: GExpr) -> set | None {
    if isinstance(expr, GTok) and expr.from_guard {
        return set([expr.name]);
    }
    if isinstance(expr, GAlt) and len(expr.choices) > 0 {
        toks: set = set();
        for c in expr.choices {
            if not (isinstance(c, GTok) and c.from_guard) {
                return None;
            }
            toks.add(c.name);
        }
        return toks;
    }
    return None;
}

impl GrammarExtractPass._stage_elide_covered_guards(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    deep = self._compute_rule_firsts_deep(rules);
    saved = self._rule_firsts;
    self._rule_firsts = deep;
    result: list[GrammarRule] = [];
    for rule in rules {
        self._current_rule = rule.name;
        result.append(
            GrammarRule(name=rule.name, body=self._elide_guards_in_expr(rule.body))
        );
    }
    self._current_rule = "";
    self._rule_firsts = saved;
    return result;
}

impl GrammarExtractPass._elide_guards_in_expr(expr: GExpr) -> GExpr {
    if isinstance(expr, GSeq) {
        new_items: list[GExpr] = [];
        n = len(expr.items);
        for (i, item) in enumerate(expr.items) {
            guard_toks = self._guard_tok_set(item);
            if guard_toks is not None and len(guard_toks) > 0 and i + 1 < n {
                rest = GSeq(items=[expr.items[j] for j in range(i + 1, n)]);
                rest_first = self.compute_first_set(rest);
                if guard_toks.issubset(rest_first[0]) {
                    continue;
                }
            }
            new_items.append(self._elide_guards_in_expr(item));
        }
        if len(new_items) == 1 {
            return new_items[0];
        }
        return GSeq(items=new_items);
    }
    if isinstance(expr, GAlt) {
        return GAlt(choices=[self._elide_guards_in_expr(c) for c in expr.choices]);
    }
    if isinstance(expr, GOpt) {
        return GOpt(inner=self._elide_guards_in_expr(expr.inner));
    }
    if isinstance(expr, GStar) {
        return GStar(inner=self._elide_guards_in_expr(expr.inner));
    }
    if isinstance(expr, GPlus) {
        return GPlus(inner=self._elide_guards_in_expr(expr.inner));
    }
    return expr;
}

impl GrammarExtractPass._stage_inline_aliases(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    mapping: dict[str, str] = {};
    for rule in rules {
        if isinstance(rule.body, GRef) and rule.body.name != rule.name {
            mapping[rule.name] = rule.body.name;
        }
    }
    if len(mapping) == 0 {
        return rules;
    }
    resolved: dict[str, str] = {};
    for alias in mapping {
        target = mapping[alias];
        seen: set = {alias};
        while target in mapping and target not in seen {
            seen.add(target);
            target = mapping[target];
        }
        if target != alias {
            resolved[alias] = target;
        }
    }
    result: list[GrammarRule] = [];
    for rule in rules {
        if rule.name in resolved {
            continue;
        }
        result.append(
            GrammarRule(name=rule.name, body=self._replace_refs(rule.body, resolved))
        );
    }
    return result;
}

impl GrammarExtractPass._replace_refs(expr: GExpr, mapping: dict[str, str]) -> GExpr {
    if isinstance(expr, GRef) and expr.name in mapping {
        return GRef(name=mapping[expr.name]);
    }
    if isinstance(expr, GSeq) {
        return GSeq(items=[self._replace_refs(x, mapping) for x in expr.items]);
    }
    if isinstance(expr, GAlt) {
        return GAlt(choices=[self._replace_refs(c, mapping) for c in expr.choices]);
    }
    if isinstance(expr, GOpt) {
        return GOpt(inner=self._replace_refs(expr.inner, mapping));
    }
    if isinstance(expr, GStar) {
        return GStar(inner=self._replace_refs(expr.inner, mapping));
    }
    if isinstance(expr, GPlus) {
        return GPlus(inner=self._replace_refs(expr.inner, mapping));
    }
    return expr;
}

impl GrammarExtractPass._stage_fold_token_sets(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    raw: list[tuple[int, str, set[str]]] = [];
    for rule in rules {
        body = rule.body;
        if isinstance(body, GAlt) and len(body.choices) >= 4 {
            all_tok = True;
            names: set = set();
            for c in body.choices {
                if isinstance(c, GTok) {
                    names.add(c.name);
                } else {
                    all_tok = False;
                    break;
                }
            }
            if all_tok {
                raw.append((-len(names), rule.name, names));
            }
        }
    }
    if len(raw) == 0 {
        return rules;
    }
    raw.sort();
    candidates: list[tuple[str, set[str]]] = [(`entry[1], `entry[2]) for `entry in raw];
    result: list[GrammarRule] = [];
    for rule in rules {
        result.append(
            GrammarRule(
                name=rule.name,
                body=self._fold_tokens_in_expr(rule.body, candidates, rule.name)
            )
        );
    }
    return result;
}

impl GrammarExtractPass._fold_tokens_in_expr(
    expr: GExpr, candidates: list[tuple[str, set[str]]], current: str
) -> GExpr {
    if isinstance(expr, GAlt) {
        tok_names: set = set();
        for c in expr.choices {
            if isinstance(c, GTok) {
                tok_names.add(c.name);
            }
        }
        folded: dict[str, str] = {};
        for (rname, rset) in candidates {
            if rname == current {
                continue;
            }
            if rset.issubset(tok_names) and len(rset) < len(tok_names) {
                overlap = False;
                for name in rset {
                    if name in folded {
                        overlap = True;
                    }
                }
                if not overlap {
                    for name in rset {
                        folded[name] = rname;
                    }
                }
            }
        }
        if len(folded) > 0 {
            new_choices: list[GExpr] = [];
            emitted: set = set();
            for c in expr.choices {
                if isinstance(c, GTok) and c.name in folded {
                    rname = folded[c.name];
                    if rname not in emitted {
                        new_choices.append(GRef(name=rname));
                        emitted.add(rname);
                    }
                    continue;
                }
                new_choices.append(self._fold_tokens_in_expr(c, candidates, current));
            }
            return GAlt(choices=new_choices);
        }
        return GAlt(
            choices=[
                self._fold_tokens_in_expr(c, candidates, current) for c in expr.choices
            ]
        );
    }
    if isinstance(expr, GSeq) {
        return GSeq(
            items=[
                self._fold_tokens_in_expr(x, candidates, current) for x in expr.items
            ]
        );
    }
    if isinstance(expr, GOpt) {
        return GOpt(inner=self._fold_tokens_in_expr(expr.inner, candidates, current));
    }
    if isinstance(expr, GStar) {
        return GStar(inner=self._fold_tokens_in_expr(expr.inner, candidates, current));
    }
    if isinstance(expr, GPlus) {
        return GPlus(inner=self._fold_tokens_in_expr(expr.inner, candidates, current));
    }
    return expr;
}

impl GrammarExtractPass._stage_remove_errors(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    error_recovery_tokens: set = set(
        ["KW_ELIF", "KW_ELSE", "KW_EXCEPT", "KW_FINALLY", "KW_CASE"]
    );
    result: list[GrammarRule] = [];
    for rule in rules {
        if rule.name == "statement" and isinstance(rule.body, GAlt) {
            filtered: list[GExpr] = [];
            for choice in rule.body.choices {
                if isinstance(choice, GTok) and choice.name in error_recovery_tokens {
                    continue;
                }
                if self._is_redundant_slot_wrap_recovery(choice) {
                    continue;
                }
                filtered.append(choice);
            }
            result.append(GrammarRule(name=rule.name, body=GAlt(choices=filtered)));
        } elif rule.name == "lambda_expr" {
            result.append(
                GrammarRule(
                    name=rule.name, body=self._strip_lambda_body_recovery(rule.body)
                )
            );
        } else {
            result.append(rule);
        }
    }
    return result;
}

impl GrammarExtractPass._strip_lambda_body_recovery(body: GExpr) -> GExpr {
    if not isinstance(body, GSeq) {
        return body;
    }
    items: list[GExpr] = [];
    for item in body.items {
        if isinstance(item, GAlt) and len(item.choices) == 2 {
            braced = item.choices[0];
            recovery = item.choices[1];
            if (
                isinstance(braced, GSeq)
                and len(braced.items) > 0
                and isinstance(braced.items[0], GTok)
                and braced.items[0].name == "LBRACE"
                and isinstance(recovery, GRef)
                and recovery.name == "expression"
            ) {
                items.append(braced);
                continue;
            }
        }
        items.append(item);
    }
    return GSeq(items=items);
}

impl GrammarExtractPass._is_redundant_slot_wrap_recovery(expr: GExpr) -> bool {
    if not isinstance(expr, GSeq) {
        return False;
    }
    items = expr.items;
    if len(items) != 4 {
        return False;
    }
    if not (isinstance(items[0], GTok) and items[0].name == "LBRACE") {
        return False;
    }
    if not (isinstance(items[1], GRef) and items[1].name == "statement") {
        return False;
    }
    if not (
        isinstance(items[2], GOpt)
        and isinstance(items[2].inner, GTok)
        and items[2].inner.name == "SEMI"
    ) {
        return False;
    }
    if not (
        isinstance(items[3], GOpt)
        and isinstance(items[3].inner, GTok)
        and items[3].inner.name == "RBRACE"
    ) {
        return False;
    }
    return True;
}

impl GrammarExtractPass._stage_remove_unreachable(
    rules: list[GrammarRule]
) -> list[GrammarRule] {
    reachable: set = set();
    reachable_map: dict[str, GrammarRule] = {};
    for rule in rules {
        reachable_map[rule.name] = rule;
    }
    worklist: list[str] = ["module"];
    while len(worklist) > 0 {
        name = worklist.pop();
        if name in reachable {
            continue;
        }
        reachable.add(name);
        if name in reachable_map {
            refs = self._collect_refs(reachable_map[name].body);
            for ref_name in refs {
                if ref_name not in reachable {
                    worklist.append(ref_name);
                }
            }
        }
    }
    result: list[GrammarRule] = [];
    for rule in rules {
        if rule.name in reachable {
            result.append(rule);
        }
    }
    return result;
}

impl GrammarExtractPass.compute_first_set(expr: GExpr) -> tuple[set[str], bool] {
    if isinstance(expr, GTok) {
        return (set([expr.name]), False);
    }
    if isinstance(expr, GRef) {
        if expr.name != self._current_rule {
            `entry = self._rule_firsts.get(expr.name);
            if `entry is not None {
                return (set(`entry[0]), `entry[1]);
            }
        }
        return (set(), False);
    }
    if isinstance(expr, GSeq) {
        result: set = set();
        for item in expr.items {
            item_result = self.compute_first_set(item);
            item_first: set = item_result[0];
            item_nullable: bool = item_result[1];
            result.update(item_first);
            if not item_nullable {
                return (result, False);
            }
        }
        return (result, True);
    }
    if isinstance(expr, GAlt) {
        result2: set = set();
        nullable = False;
        for choice in expr.choices {
            c_result = self.compute_first_set(choice);
            c_first: set = c_result[0];
            c_nullable: bool = c_result[1];
            result2.update(c_first);
            if c_nullable {
                nullable = True;
            }
        }
        return (result2, nullable);
    }
    if isinstance(expr, GOpt) {
        inner_result = self.compute_first_set(expr.inner);
        return (inner_result[0], True);
    }
    if isinstance(expr, GStar) {
        inner_result = self.compute_first_set(expr.inner);
        return (inner_result[0], True);
    }
    if isinstance(expr, GPlus) {
        return self.compute_first_set(expr.inner);
    }
    return (set(), False);
}
