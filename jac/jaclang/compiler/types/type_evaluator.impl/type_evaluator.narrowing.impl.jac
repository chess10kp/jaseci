def _find_cfg_node_for(at_node: UniNode) -> UniCFGNode | None {
    cur: UniNode | None = at_node;
    while cur is not None {
        if isinstance(cur, UniCFGNode) and not isinstance(cur, InnerCompr) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl TypeEvaluator.flow_pred_never_returns(pred: UniCFGNode) -> bool {
    if not isinstance(pred, ExprStmt) {
        return False;
    }
    call = pred.expr;
    if not isinstance(call, FuncCall) {
        return False;
    }
    import from jaclang.compiler.symbol_utils { resolve_expr_symbol }
    sym = resolve_expr_symbol(call.target);
    if sym is None {
        return False;
    }
    callee_type = self.get_type_of_symbol(sym);
    if isinstance(callee_type, FunctionType) {
        return isinstance(callee_type.return_type, NeverType);
    }
    return False;
}

impl TypeEvaluator.get_narrowed_type(
    symbol: Symbol, at_node: UniNode
) -> TypeBase | None {
    import from jaclang.compiler.types.type_evaluator { NarrowingTarget }
    sym_id = id(symbol);

    if sym_id in self._and_narrowing_overrides {
        return self._and_narrowing_overrides[sym_id];
    }
    if sym_id in self._flow_pending_symbols {
        return None;
    }
    symbol_type = self.get_type_of_symbol(symbol);
    if not isinstance(
        symbol_type, (UnionType, ClassType, FunctionType, UnknownType, AnyType)
    ) {
        return None;
    }
    self._flow_pending_symbols.add(sym_id);
    try {
        narrowing_target = NarrowingTarget(
            key=symbol.sym_name, declared_type=symbol_type, symbol=symbol
        );
        flow_node = _find_cfg_node_for(at_node);
        if flow_node is not None {
            return self._get_type_from_flow_node(narrowing_target, flow_node, set());
        }
        return None;
    } finally {
        self._flow_pending_symbols.discard(sym_id);
    }
}

impl TypeEvaluator.get_narrowed_type_for_expr(
    expr: Expr, declared_type: TypeBase, at_node: UniNode
) -> TypeBase | None {
    import from jaclang.compiler.types.type_evaluator { NarrowingTarget }
    import from jaclang.compiler.symbol_utils { reference_key_deps }
    if not isinstance(declared_type, (UnionType, ClassType, FunctionType)) {
        return None;
    }
    key = self.create_key_for_reference(expr);
    if key is None {
        return None;
    }
    if key in self._flow_pending_keys {
        return None;
    }
    self._flow_pending_keys.add(key);
    try {
        narrowing_target = NarrowingTarget(
            key=key,
            declared_type=declared_type,
            deps=frozenset(reference_key_deps(expr)),
        );
        flow_node = _find_cfg_node_for(at_node);
        if flow_node is not None {
            return self._get_type_from_flow_node(narrowing_target, flow_node, set());
        }
        return None;
    } finally {
        self._flow_pending_keys.discard(key);
    }
}

impl TypeEvaluator._node_encloses(outer: UniNode, inner: UniNode) -> bool {
    cur: UniNode | None = inner;
    while cur is not None {
        if cur is outer {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl TypeEvaluator._get_type_from_flow_node(
    target: NarrowingTarget, flow_node: UniCFGNode, visited: set
) -> TypeBase | None {
    import from jaclang.compiler.types.type_evaluator { NarrowingTarget }
    key = target.key;

    flow_node_id = id(flow_node);
    sym = target.symbol;
    sym_key: tuple[int, int] = (flow_node_id, id(sym) if sym is not None else 0);
    txt_key: tuple[int, str] = (flow_node_id, key);
    if sym is not None {
        if sym_key in self._flow_node_type_cache {
            return self._flow_node_type_cache[sym_key];
        }
    } elif txt_key in self._flow_key_type_cache {
        return self._flow_key_type_cache[txt_key];
    }
    if flow_node_id in visited {
        return None;
    }

    if len(visited) > 256 {
        return None;
    }
    visited.add(flow_node_id);
    if not flow_node.bb_in {
        if sym is not None {
            self._flow_node_type_cache[sym_key] = None;
        } else {
            self._flow_key_type_cache[txt_key] = None;
        }
        visited.discard(flow_node_id);
        return None;
    }

    is_loop_header: bool = isinstance(
        flow_node, (InForStmt, IterForStmt, WhileStmt, ForeverStmt)
    );
    incoming_types: list[TypeBase] = [];
    has_unnarrowed_pred: bool = False;
    for pred in flow_node.bb_in {
        if pred is flow_node {
            has_unnarrowed_pred = True;
            continue;
        }

        if self.flow_pred_never_returns(pred) {
            continue;
        }

        if isinstance(pred, CfgExpr) and not pred.bb_in {
            continue;
        }
        if is_loop_header and self._node_encloses(flow_node, pred) {
            continue;
        }

        if isinstance(pred, (WhileStmt, ForeverStmt, InForStmt, IterForStmt))
            and self._loop_body_writes_target(pred, target) {
            if (
                isinstance(pred, WhileStmt) and pred.body and flow_node is pred.body[0]
            ) {
                predicate = self._find_predicate_for(target, pred.condition);
                if predicate is not None {
                    narrowed = self._apply_narrowing(predicate, None, True, target);
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                        continue;
                    }
                }
            }
            has_unnarrowed_pred = True;
            continue;
        }

        if key not in pred.affected_symbols and not isinstance(pred, CfgExpr) {
            has_unnarrowed_pred = True;
            continue;
        }

        pred_narrowed = self._get_type_from_flow_node(target, pred, visited);

        if isinstance(pred, CfgExpr) {
            predicate = self._find_predicate_for(target, pred.expr);
            if predicate is not None {
                is_true_edge = flow_node is pred.sc_true_target;
                is_false_edge = flow_node is pred.sc_false_target;
                if is_true_edge or is_false_edge {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, is_true_edge, target
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } elif pred_narrowed is not None {
                        incoming_types.append(pred_narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                }
            }
        }

        if isinstance(pred, IfStmt) and not isinstance(flow_node, CfgExpr) {
            predicate = self._find_predicate_for(target, pred.condition);
            if predicate is not None {
                edge_kind = self._classify_edge(pred, flow_node);
                if edge_kind in ("true", "false") {
                    narrowed = self._apply_narrowing(
                        predicate, pred_narrowed, edge_kind == "true", target
                    );
                    if narrowed is not None {
                        incoming_types.append(narrowed);
                    } elif pred_narrowed is not None {
                        incoming_types.append(pred_narrowed);
                    } else {
                        has_unnarrowed_pred = True;
                    }
                    continue;
                }
            }
        }

        if isinstance(pred, WhileStmt) and not isinstance(flow_node, CfgExpr) {
            predicate = self._find_predicate_for(target, pred.condition);
            if predicate is not None and pred.body and flow_node is pred.body[0] {
                narrowed = self._apply_narrowing(
                    predicate, pred_narrowed, True, target
                );
                if narrowed is not None {
                    incoming_types.append(narrowed);
                } else {
                    has_unnarrowed_pred = True;
                }
                continue;
            }
        }

        if isinstance(pred, AssertStmt) {
            predicate = self._find_predicate_for(target, pred.condition);
            if predicate is not None {
                narrowed = self._apply_narrowing(
                    predicate, pred_narrowed, True, target
                );
                if narrowed is not None {
                    incoming_types.append(narrowed);
                } else {
                    has_unnarrowed_pred = True;
                }
                continue;
            }
        }

        if isinstance(pred, Assignment)
            and pred.value
            and not self._node_encloses(pred, flow_node) {
            import from jaclang.compiler.symbol_utils {
                collect_assignment_target_keys,
                find_destructure_index_path,
            }
            target_key_matched = False;
            flat_target_matched = False;
            destructure_path: list[int] | None = None;
            for t in pred.target {
                written_keys = collect_assignment_target_keys(t);
                if key in written_keys {
                    target_key_matched = True;
                    if (
                        (isinstance(t, Name) and t.value == key)
                        or (
                            isinstance(t, AtomTrailer)
                            and t.is_attr
                            and self.create_key_for_reference(t) == key
                        )
                    ) {
                        flat_target_matched = True;
                    } else {
                        destructure_path = find_destructure_index_path(t, key);
                    }
                    break;
                }

                if target.deps and (target.deps & written_keys) {
                    target_key_matched = True;
                    break;
                }
            }
            if target_key_matched {
                narrowed_from_assignment: TypeBase | None = None;
                assigned_type: TypeBase | None = None;
                if flat_target_matched {
                    assigned_type = self.get_type_of_expression(pred.value);
                } elif destructure_path is not None and len(destructure_path) > 0 {
                    assigned_type = self._extract_tuple_element_type_path(
                        self.get_type_of_expression(pred.value), destructure_path
                    );
                }
                if (
                    assigned_type is not None
                    and not isinstance(assigned_type, UnknownType)
                ) {
                    declared_type = target.declared_type;
                    assigned_type = self._widen_literal_for_declaration(assigned_type);

                    _decl_extern = (
                        isinstance(declared_type, ClassType)
                        and declared_type.is_class_instance()
                        and isinstance(declared_type.shared.symbol_table, Archetype)
                        and declared_type.shared.symbol_table.find_parent_of_type(
                            Import
                        )
                            is not None
                    );
                    import from jaclang.compiler.types.fixed_width { numeric_name_of }
                    _decl_num = numeric_name_of(declared_type);
                    _assigned_num = numeric_name_of(assigned_type);
                    if _decl_extern {
                        narrowed_from_assignment = None;
                    } elif _decl_num is not None and _assigned_num is not None {
                        narrowed_from_assignment = None;
                    } elif self.is_none_type(declared_type) {
                        narrowed_from_assignment = assigned_type;
                    } elif (
                        self.assign_type(assigned_type, declared_type)
                        and not self.assign_type(declared_type, assigned_type)
                    ) {
                        narrowed_from_assignment = assigned_type;
                    } elif (
                        flat_target_matched
                        and self.is_explicit_any(assigned_type)
                        and self._union_contains_none(declared_type)
                    ) {
                        none_cls = self.prefetch.none_type_class;
                        if none_cls is not None {
                            narrowed_from_assignment = self.exclude_type_from_union(
                                declared_type, self._convert_to_instance(none_cls)
                            );
                        }
                    }
                }
                if narrowed_from_assignment is not None {
                    incoming_types.append(narrowed_from_assignment);
                } else {
                    has_unnarrowed_pred = True;
                }
                continue;
            }
        }

        if isinstance(pred, MatchStmt) {
            match_key = self.create_key_for_reference(pred.target);
            if match_key is not None and match_key == key {
                match_case: MatchCase | None;
                if isinstance(flow_node, MatchCase) {
                    match_case = flow_node;
                } else {
                    match_case = flow_node.find_parent_of_type(MatchCase);
                }
                if match_case is not None and match_case.pattern {
                    pattern_type = self._get_type_from_match_pattern(
                        match_case.pattern
                    );
                    if pattern_type is not None {
                        incoming_types.append(pattern_type);
                        continue;
                    }
                }
            }
        }

        _after_if_write = (
            isinstance(pred, IfStmt)
            and not isinstance(flow_node, CfgExpr)
            and self._loop_body_writes_target(pred, target)
            and not self._node_encloses(pred, flow_node)
        );
        if _after_if_write and isinstance(pred, IfStmt) {
            exit_t = self._if_exit_type(target, pred, pred_narrowed, set());
            if exit_t is not None {
                incoming_types.append(exit_t);
            } else {
                has_unnarrowed_pred = True;
            }
            continue;
        }
        if pred_narrowed is not None {
            incoming_types.append(pred_narrowed);
        } else {
            has_unnarrowed_pred = True;
        }
    }

    incoming_types = [
        t
        for t in incoming_types
        if not isinstance(t, NeverType)
    ];

    result: TypeBase | None = None;
    if len(incoming_types) == 0 {
        result = None;
    } elif has_unnarrowed_pred {
        result = None;
    } elif len(incoming_types) == 1 {
        result = incoming_types[0];
    } else {
        result = self._union_narrowed_types(incoming_types);
    }
    if not (isinstance(result, UnknownType) and result.is_incomplete) {
        if sym is not None {
            self._flow_node_type_cache[sym_key] = result;
        } else {
            self._flow_key_type_cache[txt_key] = result;
        }
    }
    visited.discard(flow_node_id);
    return result;
}

impl TypeEvaluator._if_exit_type(
    target: NarrowingTarget, stmt: IfStmt, entry_type: TypeBase | None, visited: set
) -> TypeBase | None {
    import from jaclang.compiler.types.type_evaluator { NarrowingTarget }
    arm_types: list[TypeBase] = [];
    if stmt.body {
        then_t = self._get_type_from_flow_node(target, stmt.body[-1], visited);
        if then_t is None {
            return None;
        }
        arm_types.append(then_t);
    }
    eb = stmt.else_body;
    if eb is None {
        fall_t = entry_type;
        predicate = self._find_predicate_for(target, stmt.condition);
        if predicate is not None {
            narrowed_f = self._apply_narrowing(predicate, entry_type, False, target);
            if narrowed_f is not None {
                fall_t = narrowed_f;
            }
        }
        if fall_t is None {
            return None;
        }
        arm_types.append(fall_t);
    } elif isinstance(eb, ElseIf) {
        else_t = self._if_exit_type(target, eb, entry_type, visited);
        if else_t is None {
            return None;
        }
        arm_types.append(else_t);
    } elif isinstance(eb, ElseStmt) {
        if eb.body {
            else_t = self._get_type_from_flow_node(target, eb.body[-1], visited);
            if else_t is None {
                return None;
            }
            arm_types.append(else_t);
        } elif entry_type is not None {
            arm_types.append(entry_type);
        } else {
            return None;
        }
    }
    if not arm_types {
        return None;
    }
    if len(arm_types) == 1 {
        return arm_types[0];
    }
    return self._union_narrowed_types(arm_types);
}

impl TypeEvaluator._loop_body_writes_target(
    loop_node: UniCFGNode, target: NarrowingTarget
) -> bool {
    import from jaclang.compiler.symbol_utils { collect_assignment_target_keys }
    cache_key = id(loop_node);
    written = self._loop_written_keys_cache.get(cache_key);
    if written is None {
        keys: set[str] = set();
        for asgn in loop_node.get_all_sub_nodes(Assignment) {
            for t in asgn.target {
                keys.update(collect_assignment_target_keys(t));
            }
        }

        for_nodes: list[InForStmt] = loop_node.get_all_sub_nodes(InForStmt);
        if isinstance(loop_node, InForStmt) {
            for_nodes.append(loop_node);
        }
        for f in for_nodes {
            keys.update(collect_assignment_target_keys(f.target));
        }
        for compr in loop_node.get_all_sub_nodes(AssignCompr) {
            for kw in (compr.assigns or []) {
                if kw.key is not None {
                    keys.update(collect_assignment_target_keys(kw.key));
                }
            }
        }
        written = keys;
        self._loop_written_keys_cache[cache_key] = written;
    }
    if target.key in written {
        return True;
    }
    return bool(target.deps and (target.deps & written));
}

impl TypeEvaluator._classify_edge(pred: IfStmt, succ: UniCFGNode) -> str {
    if pred.body and succ is pred.body[0] {
        return "true";
    }

    if isinstance(pred.else_body, ElseIf) and succ is pred.else_body {
        return "false";
    }
    if isinstance(pred.else_body, ElseStmt)
        and pred.else_body.body
        and succ is pred.else_body.body[0] {
        return "false";
    }

    cur: UniNode | None = succ;
    while cur is not None and cur is not pred {
        if pred.else_body is not None and cur is pred.else_body {
            return "false";
        }
        cur = cur.parent;
    }
    if cur is pred {
        return "true";
    }

    body_empty = not pred.body;
    else_empty = isinstance(pred.else_body, ElseStmt) and not pred.else_body.body;
    has_else_branch = pred.else_body is not None;
    if body_empty and (else_empty or not has_else_branch) {
        return "unconditional";
    }
    if body_empty {
        return "true";
    }
    if else_empty or not has_else_branch {
        return "false";
    }
    return "unconditional";
}

impl TypeEvaluator.create_key_for_reference(expr: Expr) -> str | None {
    if isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        return self.create_key_for_reference(expr.value);
    }
    if isinstance(expr, Name) {
        return expr.value;
    }
    if isinstance(expr, AtomTrailer) and expr.is_attr {
        base_key = self.create_key_for_reference(expr.target);
        if base_key and isinstance(expr.right, Name) {
            return f"{base_key}.{expr.right.value}";
        }
    }
    if isinstance(expr, AtomTrailer) and not expr.is_attr {
        import from jaclang.compiler.symbol_utils { int_subscript_suffix }
        base_key = self.create_key_for_reference(expr.target);
        if base_key and isinstance(expr.right, IndexSlice) {
            suffix = int_subscript_suffix(expr.right);
            if suffix {
                return f"{base_key}{suffix}";
            }
        }
    }

    if (
        isinstance(expr, BinaryExpr)
        and isinstance(expr.op, Token)
        and expr.op.name == "WALRUS_EQ"
        and isinstance(expr.left, Name)
    ) {
        return expr.left.value;
    }
    return None;
}

impl TypeEvaluator._find_symbol_by_key(key: str, condition: Expr) -> Symbol | None {
    if isinstance(condition, FuncCall) and condition.params {
        first_arg = condition.params[0];
        if isinstance(first_arg, Name) and first_arg.sym {
            return first_arg.sym;
        }
    }
    return None;
}

impl TypeEvaluator.classify_condition(condition: Expr) -> ConditionInfo | None {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    import from jaclang.compiler.types.type_evaluator { ConditionInfo, NarrowingKind }

    if isinstance_info := self._extract_isinstance_info(condition) {
        (key, narrow_type, exact) = isinstance_info;
        return ConditionInfo(
            kind=NarrowingKind.ISINSTANCE,
            key=key,
            narrow_type=narrow_type,
            narrows_on_false=exact
        );
    }

    if callable_key := self._extract_callable_info(condition) {
        return ConditionInfo(kind=NarrowingKind.CALLABLE, key=callable_key,);
    }

    if hasattr_info := self._extract_hasattr_info(condition) {
        (h_key, h_attr) = hasattr_info;
        return ConditionInfo(kind=NarrowingKind.HASATTR, key=h_key, attr_name=h_attr);
    }

    if guard_info := self._extract_type_guard_info(condition) {
        (g_key, g_type, g_is_type_is) = guard_info;
        return ConditionInfo(
            kind=(NarrowingKind.TYPE_IS if g_is_type_is else NarrowingKind.TYPE_GUARD),
            key=g_key,
            narrow_type=g_type
        );
    }

    if (
        isinstance(condition, CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
        and isinstance(condition.rights[0], Null)
    ) {
        narrowing_key = self.create_key_for_reference(condition.left);
        if narrowing_key is not None {
            op_name = condition.ops[0].name;
            if op_name == Tok.KW_IS or op_name == Tok.EE {
                return ConditionInfo(kind=NarrowingKind.NONE_IS, key=narrowing_key);
            } elif op_name == Tok.KW_ISN or op_name == Tok.NE {
                return ConditionInfo(kind=NarrowingKind.NONE_IS_NOT, key=narrowing_key);
            }
        }
    }

    if (
        isinstance(condition, CompareExpr)
        and len(condition.ops) == 1
        and len(condition.rights) == 1
    ) {
        left_key = self.create_key_for_reference(condition.left);
        right_expr = condition.rights[0];
        if left_key is not None
            and isinstance(right_expr, (String, Int, Float, Bool)) {
            literal_type = self.get_type_of_expression(right_expr);
            op_name = condition.ops[0].name;
            if op_name == Tok.EE {
                return ConditionInfo(
                    kind=NarrowingKind.LITERAL_EQ,
                    key=left_key,
                    narrow_type=literal_type
                );
            } elif op_name == Tok.NE {
                return ConditionInfo(
                    kind=NarrowingKind.LITERAL_NE,
                    key=left_key,
                    narrow_type=literal_type
                );
            }
        }
    }

    if isinstance(condition, (Name, AtomTrailer)) {
        narrowing_key = self.create_key_for_reference(condition);
        if narrowing_key is not None {
            return ConditionInfo(kind=NarrowingKind.TRUTHINESS, key=narrowing_key);
        }
    }

    if (
        isinstance(condition, BinaryExpr)
        and isinstance(condition.op, Token)
        and condition.op.name == "WALRUS_EQ"
        and isinstance(condition.left, Name)
    ) {
        return ConditionInfo(kind=NarrowingKind.TRUTHINESS, key=condition.left.value,);
    }
    return None;
}

impl TypeEvaluator._find_predicate_for(
    target: NarrowingTarget, condition: Expr
) -> NarrowingPredicate | None {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    import from jaclang.compiler.types.type_evaluator {
        NarrowingKind,
        NarrowingPredicate,
        NarrowingTarget
    }
    key = target.key;
    if isinstance(condition, CfgExpr) {
        return self._find_predicate_for(target, condition.expr);
    }

    if isinstance(condition, AtomUnit) and isinstance(condition.value, Expr) {
        return self._find_predicate_for(target, condition.value);
    }

    if (
        isinstance(condition, UnaryExpr)
        and isinstance(condition.op, Token)
        and condition.op.name == Tok.NOT
    ) {
        inner_pred = self._find_predicate_for(target, condition.operand);
        if inner_pred is not None {
            return NarrowingPredicate(
                key=inner_pred.key,
                narrow_type=inner_pred.narrow_type,
                is_inverted=not inner_pred.is_inverted,
                attr_name=inner_pred.attr_name,
                narrows_on_true=inner_pred.narrows_on_false,
                narrows_on_false=inner_pred.narrows_on_true,
                replaces_declared=inner_pred.replaces_declared
            );
        }
        return None;
    }

    if isinstance(condition, BoolExpr) {
        match condition.op.name {
            case Tok.KW_AND:
                and_preds = [
                    self._find_predicate_for(target, val) for val in condition.values
                ];
                and_matched = [
                    p
                    for p in and_preds
                    if p is not None
                ];
                if not and_matched {
                    return None;
                }

                positive_preds = [
                    p
                    for p in and_matched
                    if not p.is_inverted
                ];
                if not positive_preds {
                    most_specific = and_matched[0];
                } else {
                    most_specific = positive_preds[0];
                    for pred in positive_preds[1:] {
                        intersection = self._narrow_member_to(
                            most_specific.narrow_type, pred.narrow_type
                        );
                        if intersection is not None
                            and self._type_matches_isinstance(
                                pred.narrow_type, intersection
                            ) {
                            most_specific = pred;
                        }
                    }
                }

                covers_false = len(and_matched) == len(and_preds)
                    and all(
                        self._narrowing_equivalent(p, most_specific)
                        for p in and_matched
                    );
                return NarrowingPredicate(
                    key=most_specific.key,
                    narrow_type=most_specific.narrow_type,
                    is_inverted=most_specific.is_inverted,
                    attr_name=most_specific.attr_name,
                    narrows_on_true=most_specific.narrows_on_true,
                    narrows_on_false=(most_specific.narrows_on_false and covers_false),
                    replaces_declared=most_specific.replaces_declared
                );

            case Tok.KW_OR:
                all_preds = [
                    self._find_predicate_for(target, val) for val in condition.values
                ];
                matched = [
                    p
                    for p in all_preds
                    if p is not None
                ];
                if not matched {
                    return None;
                }

                covers_true = len(matched) == len(all_preds);
                positive = [
                    p
                    for p in matched
                    if not p.is_inverted
                ];
                if len(positive) == len(matched) {
                    narrowed_types: list[TypeBase] = [p.narrow_type for p in positive];
                    if len(narrowed_types) == 1 {
                        union_type = narrowed_types[0];
                    } else {
                        union_type = UnionType(types=narrowed_types);
                    }
                    return NarrowingPredicate(
                        key=key,
                        narrow_type=union_type,
                        is_inverted=False,
                        narrows_on_true=(
                            covers_true and all(p.narrows_on_true for p in positive)
                        ),
                        narrows_on_false=all(p.narrows_on_false for p in positive),
                        replaces_declared=any(p.replaces_declared for p in positive)
                    );
                }

                chosen: NarrowingPredicate = matched[0];
                for p in matched {
                    if p.key == key {
                        chosen = p;
                        break;
                    }
                }
                return NarrowingPredicate(
                    key=chosen.key,
                    narrow_type=chosen.narrow_type,
                    is_inverted=chosen.is_inverted,
                    attr_name=chosen.attr_name,
                    narrows_on_true=(len(all_preds) == 1 and chosen.narrows_on_true),
                    narrows_on_false=chosen.narrows_on_false,
                    replaces_declared=chosen.replaces_declared
                );

        }
    }

    info = self.classify_condition(condition);
    if info is not None and info.key == key {
        match info.kind {
            case NarrowingKind.ISINSTANCE
                | NarrowingKind.TYPE_IS
                | NarrowingKind.TYPE_GUARD:
                narrowed_type = info.narrow_type;
                if narrowed_type is None {
                    return None;
                }
                return NarrowingPredicate(
                    key=key,
                    narrow_type=narrowed_type,
                    is_inverted=False,
                    narrows_on_false=info.narrows_on_false
                        and info.kind != NarrowingKind.TYPE_GUARD,
                    replaces_declared=info.kind == NarrowingKind.TYPE_GUARD
                );

            case NarrowingKind.CALLABLE:
                if not isinstance(condition, FuncCall) or not condition.params {
                    return None;
                }
                argument = condition.params[0];
                if not isinstance(argument, Expr) {
                    return None;
                }
                expr_type = self.get_type_of_expression(argument);
                callable_type = self._filter_union_to_callables(expr_type);
                if not isinstance(callable_type, NeverType) {
                    return NarrowingPredicate(
                        key=key, narrow_type=callable_type, is_inverted=False
                    );
                }

            case NarrowingKind.HASATTR:
                return NarrowingPredicate(
                    key=key,
                    narrow_type=target.declared_type,
                    is_inverted=False,
                    attr_name=info.attr_name
                );

            case NarrowingKind.NONE_IS:
                if self.prefetch and self.prefetch.none_type_class {
                    none_inst = self._convert_to_instance(
                        self.prefetch.none_type_class
                    );
                    return NarrowingPredicate(
                        key=key, narrow_type=none_inst, is_inverted=False
                    );
                }

            case NarrowingKind.NONE_IS_NOT:
                if self.prefetch and self.prefetch.none_type_class {
                    none_inst = self._convert_to_instance(
                        self.prefetch.none_type_class
                    );
                    return NarrowingPredicate(
                        key=key, narrow_type=none_inst, is_inverted=True
                    );
                }

            case NarrowingKind.LITERAL_EQ:
                literal_type = info.narrow_type;
                if literal_type is None {
                    return None;
                }
                return NarrowingPredicate(
                    key=key,
                    narrow_type=literal_type,
                    is_inverted=False,
                    narrows_on_false=False
                );

            case NarrowingKind.LITERAL_NE:
                literal_type = info.narrow_type;
                if literal_type is None {
                    return None;
                }
                return NarrowingPredicate(
                    key=key,
                    narrow_type=literal_type,
                    is_inverted=True,
                    narrows_on_true=False
                );

            case NarrowingKind.TRUTHINESS:
                if self.prefetch and self.prefetch.none_type_class {
                    if (
                        isinstance(condition, BinaryExpr)
                        and isinstance(condition.op, Token)
                        and condition.op.name == "WALRUS_EQ"
                    ) {
                        check_type = self.get_type_of_expression(condition.right);
                    } else {
                        check_type = target.declared_type;
                    }
                    if self._union_contains_none(check_type) {
                        none_inst = self._convert_to_instance(
                            self.prefetch.none_type_class
                        );
                        return NarrowingPredicate(
                            key=key, narrow_type=none_inst, is_inverted=True
                        );
                    }
                }

        }
    }
    return None;
}

impl TypeEvaluator._narrowing_equivalent(
    left: NarrowingPredicate, right: NarrowingPredicate
) -> bool {
    """Report whether two predicates narrow a target identically.

    A conjunction's false edge is `not A or not B`, so it may only narrow
    when every conjunct negates to the same thing. Mutual `isinstance`
    matching is the equivalence used: it holds for the same class and for two
    references to it that were converted to instances separately.
    """;
    if left is right {
        return True;
    }
    if left.key != right.key or left.is_inverted != right.is_inverted {
        return False;
    }
    if left.attr_name != right.attr_name {
        return False;
    }
    if left.replaces_declared != right.replaces_declared {
        return False;
    }
    if left.narrows_on_true != right.narrows_on_true
        or left.narrows_on_false != right.narrows_on_false {
        return False;
    }
    if left.attr_name is not None {
        return True;
    }
    return self._type_matches_isinstance(left.narrow_type, right.narrow_type)
        and self._type_matches_isinstance(right.narrow_type, left.narrow_type);
}

impl TypeEvaluator._apply_narrowing(
    predicate: NarrowingPredicate,
    incoming: TypeBase | None,
    is_true_branch: bool,
    target: NarrowingTarget
) -> TypeBase | None {
    import from jaclang.compiler.types.type_evaluator {
        NarrowingPredicate,
        NarrowingTarget
    }

    if is_true_branch and not predicate.narrows_on_true {
        return None;
    }
    if not is_true_branch and not predicate.narrows_on_false {
        return None;
    }

    is_positive: bool = (
        is_true_branch if not predicate.is_inverted else not is_true_branch
    );

    if predicate.attr_name is not None {
        base_type: TypeBase = (
            incoming if incoming is not None else target.declared_type
        );
        return self._filter_union_for_hasattr(
            base_type, predicate.attr_name, is_positive
        );
    }
    if is_positive {
        if predicate.replaces_declared {
            return predicate.narrow_type;
        }
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = target.declared_type;
        }

        narrowed = self._narrow_type_to(base_type, predicate.narrow_type);
        if narrowed is not None {
            return narrowed;
        }

        return self._specialize_narrow_from_base(base_type, predicate.narrow_type);
    } else {
        base_type: TypeBase;
        if incoming is not None {
            base_type = incoming;
        } else {
            base_type = target.declared_type;
        }
        result = self.exclude_type_from_union(base_type, predicate.narrow_type);
        if result is base_type {
            return incoming;
        }
        return result;
    }
}

impl TypeEvaluator._specialize_narrow_from_base(
    base_type: TypeBase, narrow_type: TypeBase
) -> TypeBase {
    """Carry a member's type arguments onto the narrow target it sits above.

    A member the target derives from is narrowed to the bare target class,
    which loses the member's arguments -- `isinstance(x, list)` over an
    `Expr | Sequence[T]` yields `list`, dropping `T`. The container protocols
    are exactly that shape (`list` is a `Sequence`, `dict` a `Mapping`), and
    a value that is both a `Sequence[T]` and a `list` is a `list[T]`, so the
    member's arguments carry over when the target declares the same number of
    parameters.
    """;
    if not isinstance(narrow_type, ClassType)
        or (narrow_type.private.type_args or []) {
        return narrow_type;
    }
    want = len(narrow_type.shared.type_params or []);
    if want == 0 {
        return narrow_type;
    }
    members = (
        base_type.types
            if isinstance(base_type, UnionType) and base_type.types
            else [base_type]
    );
    for m in members {
        if not isinstance(m, ClassType) {
            continue;
        }
        args: list[TypeBase] = m.private.type_args or [];
        if len(args) != want or m.shared.same_class(narrow_type.shared) {
            continue;
        }
        if self.is_sub_class(m, narrow_type) {
            return narrow_type.specialize_generics(list(args));
        }
    }
    return narrow_type;
}

impl TypeEvaluator._narrow_type_to(
    base_type: TypeBase, narrow_type: TypeBase
) -> TypeBase | None {
    """Narrow a declared type against an isinstance filter, member by member.

    Narrowing the union as a whole threw the declared type away whenever no
    member matched: `isinstance(x, Marker)` on an `x: Carrier | None` became
    a bare `Marker` and every `Carrier` member went missing. Each member is
    now narrowed on its own and the surviving results are re-joined.
    """;
    members = (
        base_type.types
            if isinstance(base_type, UnionType) and base_type.types
            else [base_type]
    );
    results: list[TypeBase] = [];
    for m in members {
        narrowed_member = self._narrow_member_to(m, narrow_type);
        if narrowed_member is not None {
            results.append(narrowed_member);
        }
    }
    if not results {
        return None;
    }
    return self._union_narrowed_types(results);
}

impl TypeEvaluator._narrow_member_to(
    member: TypeBase, narrow_type: TypeBase
) -> TypeBase | None {
    """Narrow one declared member against the filter, or a tuple of filters.

    A tuple filter is a disjunction, so the member is narrowed against every
    alternative it is related to and the results joined. A member related to
    none of them drops: the value cannot be that member and pass the guard,
    unless it is an instance of a class deriving from both, which this
    checker does not model.
    """;
    if isinstance(narrow_type, UnionType) and narrow_type.types {
        related: list[TypeBase] = [];
        for t in narrow_type.types {
            part = self._narrow_member_to(member, t);
            if part is not None {
                related.append(part);
            }
        }
        if not related {
            return None;
        }
        return self._union_narrowed_types(related);
    }
    if isinstance(narrow_type, ClassType) {
        if isinstance(member, FunctionType)
            and self._lookup_class_member(narrow_type, "__call__") is not None {
            return narrow_type;
        }
        if isinstance(member, ClassType)
            and member.is_builtin("type")
            and narrow_type.is_instantiable_class() {
            return narrow_type;
        }
    }
    if self._type_matches_isinstance(member, narrow_type) {
        return member;
    }
    if not isinstance(member, ClassType) or not isinstance(narrow_type, ClassType) {
        return None;
    }
    if self.is_sub_class(member, narrow_type) {
        return self._specialize_narrow_from_base(member, narrow_type);
    }
    return None;
}

impl TypeEvaluator._type_matches_isinstance(
    t: TypeBase, target_type: TypeBase
) -> bool {
    if isinstance(target_type, UnionType) and target_type.types {
        for target_t in target_type.types {
            if self._type_matches_isinstance(t, target_t) {
                return True;
            }
        }
        return False;
    }

    if isinstance(t, ClassType) and isinstance(target_type, ClassType) {
        if target_type.is_builtin("type") and not target_type.is_instantiable_class() {
            return t.is_instantiable_class() or t.is_builtin("type");
        }
        if t.shared.same_class(target_type.shared) {
            return True;
        }

        if self.is_sub_class(target_type, t) {
            return True;
        }
    }

    if t is target_type {
        return True;
    }
    return False;
}

impl TypeEvaluator._type_has_attribute(t: TypeBase, attr_name: str) -> bool {
    if not isinstance(t, ClassType) {
        return False;
    }
    if self._lookup_class_member(t, attr_name) is not None {
        return True;
    }
    if self._get_getattr_return_type(t) is not None {
        return True;
    }
    return False;
}

impl TypeEvaluator._filter_union_for_hasattr(
    base_type: TypeBase, attr_name: str, keep_with_attr: bool
) -> TypeBase | None {
    matching: list[TypeBase] = [];
    if isinstance(base_type, UnionType) and base_type.types {
        for t in base_type.types {
            if self._type_has_attribute(t, attr_name) == keep_with_attr {
                matching.append(t);
            }
        }
    } else {
        if self._type_has_attribute(base_type, attr_name) == keep_with_attr {
            matching.append(base_type);
        }
    }
    if len(matching) == 0 {
        return None;
    } elif len(matching) == 1 {
        return matching[0];
    } else {
        return UnionType(types=matching);
    }
}

impl TypeEvaluator._union_narrowed_types(types_list: list[TypeBase]) -> TypeBase {
    if len(types_list) == 0 {
        return NeverType();
    }
    if len(types_list) == 1 {
        return types_list[0];
    }

    flat: list[TypeBase] = [];
    for t in types_list {
        if isinstance(t, UnionType) and t.types {
            flat.extend(t.types);
        } else {
            flat.append(t);
        }
    }

    unique: list[TypeBase] = [];
    for t in flat {
        if not self._type_in_list(t, unique) {
            unique.append(t);
        }
    }
    if len(unique) == 1 {
        return unique[0];
    }
    return UnionType(types=unique);
}

impl TypeEvaluator.exclude_type_from_union(
    original: TypeBase, to_exclude: TypeBase
) -> TypeBase {
    members = original.types if isinstance(original, UnionType) else [original];
    remaining = [
        member
        for member in members
        if not self._type_matches_isinstance(member, to_exclude)
    ];
    if len(remaining) == len(members) {
        return original;
    }
    return self._union_narrowed_types(remaining);
}

impl TypeEvaluator._get_type_from_match_pattern(
    pattern: MatchPattern
) -> TypeBase | None {
    if isinstance(pattern, MatchArch) {
        class_type = self.get_type_of_expression(pattern.name);
        return self._convert_to_instance(class_type);
    }

    if isinstance(pattern, MatchOr) and pattern.patterns {
        pattern_types: list[TypeBase] = [];
        for sub_pattern in pattern.patterns {
            sub_type = self._get_type_from_match_pattern(sub_pattern);
            if sub_type is not None {
                pattern_types.append(sub_type);
            }
        }
        if len(pattern_types) == 0 {
            return None;
        } elif len(pattern_types) == 1 {
            return pattern_types[0];
        } else {
            return UnionType(types=pattern_types);
        }
    }

    if isinstance(pattern, MatchAs) and pattern.pattern {
        return self._get_type_from_match_pattern(pattern.pattern);
    }

    if isinstance(pattern, MatchWild) {
        return None;
    }

    return None;
}

impl TypeEvaluator._union_contains_none(union_type: TypeBase) -> bool {
    if not isinstance(union_type, UnionType) or not union_type.types {
        return False;
    }
    if not self.prefetch or not self.prefetch.none_type_class {
        return False;
    }
    none_shared = self.prefetch.none_type_class.shared;
    for t in union_type.types {
        if isinstance(t, ClassType) and t.shared.same_class(none_shared) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator._extract_isinstance_info(
    condition: Expr
) -> tuple[str, TypeBase, bool] | None {
    if not isinstance(condition, FuncCall) {
        return None;
    }
    if not isinstance(condition.target, Name)
        or condition.target.value not in ("isinstance", "issubclass") {
        return None;
    }
    if not condition.params or len(condition.params) != 2 {
        return None;
    }

    argument = condition.params[0];
    if not isinstance(argument, Expr) {
        return None;
    }
    narrowing_key = self.create_key_for_reference(argument);
    if narrowing_key is None {
        return None;
    }

    type_arg = condition.params[1];
    if not isinstance(type_arg, Expr) {
        return None;
    }

    alternatives = self._isinstance_class_alternatives(
        self.get_type_of_expression(type_arg)
    );
    if not alternatives {
        return None;
    }
    if condition.target.value == "issubclass" {
        if not all(
            isinstance(alternative, ClassType) for alternative in alternatives
        ) {
            return None;
        }
        alternatives = [
            alternative.clone_as_class()
            for alternative in alternatives
            if isinstance(alternative, ClassType)
        ];
    }
    return (
        narrowing_key,
        alternatives[0] if len(alternatives) == 1 else UnionType(types=alternatives),
        self._isinstance_classinfo_is_exact(type_arg)
    );
}

impl TypeEvaluator._isinstance_classinfo_is_exact(expr: Expr) -> bool {
    if isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        return self._isinstance_classinfo_is_exact(expr.value);
    }
    if isinstance(expr, TupleVal) {
        return all(
            isinstance(value, Expr) and self._isinstance_classinfo_is_exact(value)
            for value in expr.values
        );
    }
    if isinstance(expr, BinaryExpr)
        and isinstance(expr.op, Token)
        and expr.op.value == "|" {
        return self._isinstance_classinfo_is_exact(expr.left)
            and self._isinstance_classinfo_is_exact(expr.right);
    }
    ty = self.get_type_of_expression(expr);
    return isinstance(ty, ClassType) and ty.is_instantiable_class();
}

impl TypeEvaluator._isinstance_class_alternatives(
    arg_type: TypeBase
) -> list[TypeBase] | None {
    if isinstance(arg_type, (AnyType, UnknownType)) {
        return [arg_type];
    }
    if isinstance(arg_type, UnionType) {
        alternatives: list[TypeBase] = [];
        for member in arg_type.types {
            resolved = [self._convert_to_instance(member)]
                if isinstance(member, ClassType)
                    and not self._is_type_subscript(member)
                    and not (member.is_builtin("tuple") and member.private.type_args)
                else self._isinstance_class_alternatives(member);
            if resolved is None {
                return None;
            }
            alternatives.extend(resolved);
        }
        return alternatives;
    }
    if not isinstance(arg_type, ClassType) {
        return None;
    }
    if arg_type.is_instantiable_class() {
        return [self._convert_to_instance(arg_type)];
    }
    if self._is_type_subscript(arg_type) and arg_type.private.type_args {
        return [self._convert_to_instance(arg_type.private.type_args[0])];
    }
    if not arg_type.is_builtin("tuple") {
        return [self._convert_to_instance(arg_type)];
    }
    elements = arg_type.private.type_args;
    if self._tuple_has_variadic_arg(arg_type) {
        elements = elements[:1];
    }
    alternatives: list[TypeBase] = [];
    for element in elements {
        resolved = self._isinstance_class_alternatives(element);
        if resolved is None {
            return None;
        }
        alternatives.extend(resolved);
    }
    return alternatives;
}

impl TypeEvaluator._create_type_guard_type(
    name: str, guarded: TypeBase | None
) -> TypeBase {
    """Model `TypeIs[T]`/`TypeGuard[T]` as a bool that carries the guarded type.

    Both forms are `bool` at runtime and both PEPs require the predicate to
    return one, so the synthesized class derives from `bool`: a predicate's
    result stays usable anywhere a bool is, and a plain `bool` return
    satisfies the annotation. `T` rides along in the type arguments, which is
    where `_extract_type_guard_info` reads it back out at the call site.
    """;
    if not self.prefetch or self.prefetch.bool_class is None {
        return UnknownType();
    }
    base = self._create_special_builtin_type(name, self.prefetch.bool_class);
    private = ClassDetailsPrivate(
        type_args=([guarded] if guarded is not None else []), alias_name=name
    );
    return ClassType(_shared=base.shared, private=private, flags=base.flags);
}

impl TypeEvaluator._unwrap_type_guard_return(ty: TypeBase) -> TypeBase {
    """Give back the bool a `TypeIs[T]`/`TypeGuard[T]` annotation stands for.

    Both PEPs say the predicate returns a bool; the guarded type is a claim
    about the argument, not about the value handed back. Keeping the special
    form out of every declared return type is what lets the rest of the
    compiler -- assignability, the layout pass, the native lane -- go on
    seeing an ordinary bool. `FunctionType.type_guard` carries the claim.
    """;
    if self._type_guard_form_of(ty) is None {
        return ty;
    }
    if not self.prefetch or self.prefetch.bool_class is None {
        return ty;
    }
    return self._convert_to_instance(self.prefetch.bool_class);
}

impl TypeEvaluator._type_guard_form_of(ty: TypeBase) -> str | None {
    if not isinstance(ty, ClassType) {
        return None;
    }
    if ty.is_special_form("TypeIs") {
        return "TypeIs";
    }
    if ty.is_special_form("TypeGuard") {
        return "TypeGuard";
    }
    return None;
}

impl TypeEvaluator._extract_type_guard_info(
    condition: Expr
) -> tuple[str, TypeBase, bool] | None {
    """Read a user-defined type predicate off a call in a condition.

    The guarded argument is the one that binds the callee's first parameter
    after any implicit receiver, which is the parameter both PEPs narrow. A
    call that spells the receiver out takes the same route the argument
    matcher does, so `Cls.pred(inst, x)` narrows `x` and not `inst`.
    """;
    if not isinstance(condition, FuncCall) or not condition.params {
        return None;
    }
    if isinstance(condition.target, Name)
        and condition.target.value
            in ("isinstance", "issubclass", "callable", "hasattr") {
        return None;
    }
    probe_key = id(condition);
    if probe_key in self._type_guard_probes {
        return None;
    }
    self._type_guard_probes.add(probe_key);
    try {
        callee = self.get_type_of_expression(condition.target);
    } finally {
        self._type_guard_probes.discard(probe_key);
    }
    if not isinstance(callee, FunctionType) or callee.type_guard is None {
        return None;
    }
    positional = [
        arg
        for arg in condition.params
        if not isinstance(arg, KWPair)
    ];
    receiver_args = 1 if self._is_unbound_method_call(condition) else 0;
    if len(positional) <= receiver_args {
        return None;
    }
    guard_key = self.create_key_for_reference(positional[receiver_args]);
    if guard_key is None {
        return None;
    }
    return (
        guard_key,
        self._convert_to_instance(callee.type_guard),
        callee.type_guard_is_strict
    );
}

impl TypeEvaluator._extract_callable_info(condition: Expr) -> str | None {
    if not isinstance(condition, FuncCall) {
        return None;
    }
    if not isinstance(condition.target, Name) or condition.target.value != "callable" {
        return None;
    }
    if not condition.params or len(condition.params) != 1 {
        return None;
    }
    argument = condition.params[0];
    return self.create_key_for_reference(argument)
        if isinstance(argument, Expr)
        else None;
}

impl TypeEvaluator._extract_hasattr_info(condition: Expr) -> tuple[str, str] | None {
    if not isinstance(condition, FuncCall) {
        return None;
    }
    if not isinstance(condition.target, Name) or condition.target.value != "hasattr" {
        return None;
    }
    if not condition.params or len(condition.params) != 2 {
        return None;
    }
    argument = condition.params[0];
    if not isinstance(argument, Expr) {
        return None;
    }
    narrowing_key = self.create_key_for_reference(argument);
    if narrowing_key is None {
        return None;
    }

    attr_arg = condition.params[1];
    if (
        isinstance(attr_arg, MultiString)
        and len(attr_arg.strings) == 1
        and isinstance(attr_arg.strings[0], String)
    ) {
        str_node = attr_arg.strings[0];
    } elif isinstance(attr_arg, String) {
        str_node = attr_arg;
    } else {
        return None;
    }
    attr_name = str_node.lit_value;
    if not isinstance(attr_name, str) {
        return None;
    }
    return (narrowing_key, attr_name);
}

impl TypeEvaluator._is_callable_type(t: TypeBase) -> bool {
    if isinstance(t, FunctionType) {
        return True;
    }
    if isinstance(t, ClassType) {
        if (
            self.prefetch
            and self.prefetch.callable_class
            and t.shared.same_class(self.prefetch.callable_class.shared)
        ) {
            return True;
        }

        if t.shared.symbol_table is not None {
            if t.shared.symbol_table.lookup("__call__", deep=False) is not None {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._filter_union_to_callables(union_type: TypeBase) -> TypeBase {
    if isinstance(union_type, UnionType) and union_type.types {
        callables: list[TypeBase] = [
            t
            for t in union_type.types
            if self._is_callable_type(t)
        ];
        if len(callables) == 0 {
            return NeverType();
        } elif len(callables) == 1 {
            return callables[0];
        } else {
            return UnionType(types=callables);
        }
    }
    if self._is_callable_type(union_type) {
        return union_type;
    }
    return NeverType();
}
