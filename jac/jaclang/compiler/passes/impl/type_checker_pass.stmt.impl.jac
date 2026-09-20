impl TypeCheckPass.exit_return_stmt with ReturnStmt exit {
    scope = self.evaluator._get_enclosing_return_scope(here);
    if scope is None {
        return;
    }

    if isinstance(scope, Ability) {
        if (
            isinstance(scope.signature, EventSignature)
            and here.expr
            and not isinstance(here.expr, Null)
        ) {
            if not (
                scope.in_client_context()
                and scope.signature.event.name == Tok.KW_ENTRY
                and not scope.is_async
            ) {
                self.ctx.emit(W2014, node_override=here);
            }
            return;
        }

        if (
            here.expr
            and not isinstance(here.expr, Null)
            and isinstance(scope.parent, (Module, Archetype, Enum, ImplDef))
        ) {
            has_annotation = (
                isinstance(scope.signature, FuncSignature)
                and scope.signature.return_type is not None
            );
            if not has_annotation {
                self.ctx.emit(E1003, node_override=here);
                return;
            }
        }
    }

    return_type = self.evaluator._get_declared_return_type(scope);
    if return_type is None {
        return;
    }

    import from jaclang.compiler.frontend.module_facts { ModuleFacts }
    if isinstance(scope, Ability) and ModuleFacts.ability_is_generator(scope) {
        gen_return = get_declared_generator_return_type(return_type);
        if gen_return is not None {
            return_type = self.evaluator._convert_to_instance(gen_return);
        } elif is_generator_family_type(return_type) {
            return;
        }
    }

    returning_type = self.evaluator._convert_to_instance(
        self.evaluator.get_none_type()
    );
    if here.expr {
        returning_type = self.evaluator.get_type_of_expression(
            here.expr, expected_type=return_type
        );
    }

    verdict = self.evaluator.assign_expr(
        here.expr,
        returning_type,
        return_type,
        strict=self.evaluator._is_strict_site(here)
    );
    if not verdict.ok and not verdict.diagnosed {
        if self.evaluator._is_awaitable_type(returning_type)
            and not self.evaluator._is_awaitable_type(return_type) {
            self.ctx.emit(
                E1042,
                node_override=here,
                actual=str(returning_type),
                expected=str(return_type)
            );
            return;
        }
        self.ctx.emit(
            E1002,
            node_override=here,
            actual=str(returning_type),
            expected=str(return_type)
        );
    }
}

impl TypeCheckPass.exit_in_for_stmt with InForStmt exit {
    if isinstance(here.target, Name) {
        self.evaluator.get_type_of_expression(here.target);
    } elif isinstance(here.target, (TupleVal, ListVal)) {
        self._eval_unpacking_names(here.target);
        self.evaluator.get_type_of_expression(here.target);
    }

    collection_type = self.evaluator.get_type_of_expression(here.collection);

    if here.is_comptime {
        cv = self.evaluator.ct_demand(here.collection);
        if not self.evaluator.ct_site_error(
            here.collection, "comptime for collection", cv
        )
            and cv is not None
            and not cv.is_deferred
            and not self.evaluator.ct_quiet
            and not hasattr(cv.v, "__iter__") {
            self.ctx.emit(
                E0108,
                node_override=here.collection,
                reason=f"comptime for needs a sequence, got {type(cv.v).__name__}"
            );
        }
    }

    iter_method = "__aiter__" if here.is_async else "__iter__";
    if isinstance(collection_type, TypeVarType) {
        if collection_type.constraints {
            for constraint_type in collection_type.constraints {
                if isinstance(constraint_type, ClassType) {
                    iter_result = self.evaluator.get_type_of_magic_method_call(
                        constraint_type, iter_method, [], None
                    );
                    if iter_result is None {
                        self.ctx.emit(
                            E1021, node_override=here, type=str(constraint_type)
                        );
                    }
                }
            }
        } elif collection_type.bound and isinstance(collection_type.bound, ClassType) {
            iter_result = self.evaluator.get_type_of_magic_method_call(
                collection_type.bound, iter_method, [], here.collection
            );
            if iter_result is None {
                self.ctx.emit(
                    E1021, node_override=here, type=str(collection_type.bound)
                );
            }
        } else {
            self.ctx.emit(E1021, node_override=here, type=collection_type.name);
        }
    } elif not isinstance(collection_type, UnknownType)
        and not self.evaluator.is_any_type(collection_type) {
        is_enum = (
            isinstance(collection_type, ClassType) and collection_type.is_enum_class()
        );
        if not is_enum {
            iter_result = self.evaluator.get_type_of_magic_method_call(
                collection_type, iter_method, [], here.collection
            );
            if iter_result is None {
                self.ctx.emit(
                    E1022,
                    node_override=here,
                    type=str(collection_type),
                    method=iter_method
                );
            }
        }
    }
}

impl TypeCheckPass.exit_raise_stmt with RaiseStmt exit {
    if here.cause {
        cause_type = self.evaluator.get_type_of_expression(here.cause);
        if isinstance(cause_type, ClassType)
            and not isinstance(cause_type, UnknownType) {
            is_exception = False;
            for cls in cause_type.shared.mro {
                if isinstance(cls, ClassType)
                    and (
                        cls.is_builtin("BaseException") or cls.is_builtin("Exception")
                    ) {
                    is_exception = True;
                    break;
                }
            }
            if not is_exception {
                self.ctx.emit(E1090, node_override=here, type=str(cause_type));
            }
        }
    }
}

impl TypeCheckPass.enter_with_stmt with WithStmt entry {
    enter_method = "__aenter__" if here.is_async else "__enter__";
    for item in here.exprs {
        ctx_item: ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if ctx_item.alias is None
            or not isinstance(ctx_item.alias, Name)
            or isinstance(expr_type, UnknownType) {
            continue;
        }

        enter_ret = self.evaluator.get_type_of_magic_method_call(
            expr_type, enter_method, [], ctx_item.expr
        );
        if enter_ret is not None {
            if here.is_async {
                enter_ret = self.evaluator._unwrap_awaitable_type(
                    enter_ret, ctx_item.expr
                );
            }
            ctx_item.alias.type = enter_ret;
        } else {
            ctx_item.alias.type = expr_type;
        }
    }
}

impl TypeCheckPass.enter_if_stmt with IfStmt entry {
    if here.__class__ is not IfStmt {
        return;
    }
    if here.is_comptime {
        self._resolve_comptime_if(here);
    }
}

impl TypeCheckPass.enter_else_if with ElseIf entry {
    if here.is_comptime {
        self._resolve_comptime_if(here);
    }
}

impl TypeCheckPass._resolve_comptime_if(nd: IfStmt) -> None {
    cv = self.evaluator.ct_demand(nd.condition);
    if self.evaluator.ct_site_error(nd.condition, "comptime if condition", cv) {
        return;
    }
    if cv is None or cv.is_deferred {
        return;
    }
    taken = bool(cv.v);
    nd.ct_taken = taken;
    if taken {
        if nd.else_body is not None {
            nd.else_body.ct_pruned = True;
        }
    } else {
        for stmt in nd.body {
            stmt.ct_pruned = True;
        }
    }
    nd._invalidate_sub_node_tab();
}

impl TypeCheckPass._in_comptime_context(nd: UniNode) -> bool {
    cur: (UniNode | None) = nd;
    prev: (UniNode | None) = None;
    while cur is not None {
        if isinstance(cur, Assignment) and cur.is_comptime and prev is cur.value {
            return True;
        }
        if isinstance(cur, IfStmt) and cur.is_comptime and prev is cur.condition {
            return True;
        }
        if isinstance(cur, InForStmt) and cur.is_comptime and prev is cur.collection {
            return True;
        }
        if isinstance(cur, AssertStmt) and cur.is_comptime {
            return True;
        }
        if isinstance(cur, Ability) and cur.is_comptime {
            return True;
        }
        if isinstance(cur, Import) {
            return True;
        }
        if isinstance(cur, FuncCall) and prev is not None and prev is not cur.target {
            callee = cur.callee_decl;
            if callee is not None and isinstance(callee.signature, FuncSignature) {
                for p in callee.signature.get_parameters() {
                    if p.is_comptime {
                        return True;
                    }
                }
            }
        }
        prev = cur;
        cur = cur.parent;
    }
    return False;
}

impl TypeCheckPass._check_comptime_only_use(nd: Name) -> None {
    sym = nd.sym;
    if sym is None or nd.ct_value is not None {
        return;
    }
    if isinstance(nd.parent, FuncCall) and nd.parent.target is nd {
        return;
    }
    local: (Symbol | None) = None;
    try {
        local = nd.sym_tab.lookup(nd.sym_name, deep=True);
    } except ValueError {
        local = None;
    }
    is_ct_import = False;
    is_ct_def = False;
    for cand in (local, sym) {
        if cand is None {
            continue;
        }
        decl = cand.decl;
        if isinstance(decl, Name) and decl is nd {
            return;
        }
        imp = decl.find_parent_of_type(Import) if isinstance(decl, Name) else None;
        if imp is not None and imp.is_comptime {
            is_ct_import = True;
        }
        owner = decl.name_of;
        if isinstance(owner, Ability) and owner.is_comptime {
            is_ct_def = True;
        }
    }
    if not is_ct_import and not is_ct_def {
        return;
    }
    if self._in_comptime_context(nd) or self.evaluator.ct_quiet {
        return;
    }
    what = (
        f"comptime-imported name '{nd.value}' used at runtime"
            if is_ct_import
            else f"comptime def '{nd.value}' used at runtime"
    );
    self.ctx.emit(E0033, node_override=nd, what=what, reason="");
}

impl TypeCheckPass._check_type_only_value_use(nd: Name) -> None {
    if isinstance(nd.parent, AtomTrailer) and nd.parent.right is nd {
        return;
    }
    if type_only_import_of(nd) is None or in_type_position(nd) {
        return;
    }
    self.ctx.emit(E1132, node_override=nd, name=nd.sym_name);
}

impl TypeCheckPass.exit_if_stmt with IfStmt exit {
    if here.__class__ is not IfStmt {
        return;
    }
    self.evaluator.get_type_of_expression(here.condition);
}

impl TypeCheckPass.exit_else_if with ElseIf exit {
    self.evaluator.get_type_of_expression(here.condition);
}

impl TypeCheckPass.exit_with_stmt with WithStmt exit {
    enter_method = "__aenter__" if here.is_async else "__enter__";
    exit_method = "__aexit__" if here.is_async else "__exit__";
    for item in here.exprs {
        ctx_item: ExprAsItem = item;
        expr_type = self.evaluator.get_type_of_expression(ctx_item.expr);
        if not isinstance(expr_type, UnknownType) and not expr_type.is_any_instance() {
            enter_result = self.evaluator.get_type_of_magic_method_call(
                expr_type, enter_method, [], ctx_item.expr
            );
            if enter_result is None {
                self.ctx.emit(E1091, node_override=here, type=str(expr_type));
            }

            if isinstance(expr_type, ClassType) {
                has_exit = (
                    self.evaluator._lookup_class_member(expr_type, exit_method)
                        is not None
                    or self.evaluator._lookup_object_member(expr_type, exit_method)
                        is not None
                );
                if not has_exit and not expr_type.is_any_type() {
                    self.ctx.emit(E1092, node_override=here, type=str(expr_type));
                }
            }
        }
    }
}

impl TypeCheckPass.exit_while_stmt with WhileStmt exit {
    self.evaluator.get_type_of_expression(here.condition);
}

impl TypeCheckPass.exit_assert_stmt with AssertStmt exit {
    self.evaluator.get_type_of_expression(here.condition);
    if here.error_msg is not None {
        self.evaluator.get_type_of_expression(here.error_msg);
    }
    if not here.is_comptime {
        return;
    }
    cv = self.evaluator.ct_demand(here.condition);
    if self.evaluator.ct_site_error(here.condition, "comptime assert condition", cv) {
        return;
    }
    if cv is None or cv.is_deferred or bool(cv.v) or self.evaluator.ct_quiet {
        return;
    }
    message = "";
    if here.error_msg is not None {
        mv = self.evaluator.ct_demand(here.error_msg);
        if mv is not None and not mv.is_deferred {
            message = f": {mv.v}";
        }
    }
    self.ctx.emit(E0109, node_override=here, message=message);
}

impl TypeCheckPass.exit_delete_stmt with DeleteStmt exit {
    for target in here.targets {
        self.evaluator.get_type_of_expression(target);
    }
    for leaf in here.leaf_targets() {
        if DeleteStmt.is_location(leaf)
            or isinstance(leaf, (Literal, MultiString, FString)) {
            continue;
        }
        leaf_type = self.evaluator.get_type_of_expression(leaf);
        if not DeleteStmt.type_may_hold_graph(leaf_type) {
            self.ctx.emit(E1133, node_override=leaf, type=str(leaf_type));
        }
    }
}

impl TypeCheckPass.exit_visit_stmt with VisitStmt exit {
    target_type = self.evaluator.get_type_of_expression(here.target);
    path_class = self.evaluator.prefetch.path_class;

    def is_valid_visit_target(t: TypeBase) -> bool {
        if t.is_any_type() or isinstance(t, UnknownType) {
            return True;
        }
        if isinstance(t, ClassType) {
            if t.is_node_type() or t.is_edge_type() {
                return True;
            }
            if path_class is not None and t.shared.same_class(path_class.shared) {
                return True;
            }
            if (
                t.is_builtin()
                and t.shared.class_name in ("list", "tuple", "set", "frozenset")
            ) {
                if t.private.type_args and len(t.private.type_args) > 0 {
                    return all(is_valid_visit_target(a) for a in t.private.type_args);
                }

                return True;
            }
        }
        if isinstance(t, UnionType) {
            return all(is_valid_visit_target(m) for m in t.types);
        }
        return False;
    }

    if not is_valid_visit_target(target_type) {
        self.ctx.emit(E1094, node_override=here, type=str(target_type));
    }
}

impl TypeCheckPass.exit_report_stmt with ReportStmt exit {
    expr_type = self.evaluator.get_type_of_expression(here.expr);
    elem_type = self._enclosing_walker_report_elem_type(here);
    if elem_type is None {
        return;
    }
    if not self.evaluator.assign_type(expr_type, elem_type) {
        self.ctx.emit(
            E1113, node_override=here, actual=str(expr_type), expected=str(elem_type)
        );
    }
}
