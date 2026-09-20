impl TypeEvaluator._get_enclosing_class(nd: UniNode) -> Archetype | None {
    impl_ := nd.find_parent_of_type(ImplDef);
    if impl_ and isinstance(impl_.decl_link, Archetype) {
        return impl_.decl_link;
    }
    return nd.find_parent_of_type(Archetype);
}

impl TypeEvaluator._get_enclosing_method(nd: UniNode) -> Ability | None {
    enclosing_fn = self._get_enclosing_function(nd);
    while enclosing_fn and (not enclosing_fn.is_method) {
        enclosing_fn = self._get_enclosing_function(enclosing_fn);
    }
    if enclosing_fn and enclosing_fn.is_method {
        return enclosing_fn;
    }
    return None;
}

impl TypeEvaluator._get_enclosing_return_scope(
    nd: UniNode
) -> Ability | LambdaExpr | None {
    while nd := nd.parent {
        if isinstance(nd, LambdaExpr) {
            return nd;
        }
        if isinstance(nd, Ability) {
            return nd;
        }
        if isinstance(nd, ImplDef) and isinstance(nd.decl_link, Ability) {
            return nd.decl_link;
        }
    }
    return None;
}

impl TypeEvaluator._get_declared_return_type(
    scope: Ability | LambdaExpr
) -> TypeBase | None {
    if isinstance(scope, LambdaExpr) {
        if (
            isinstance(scope.signature, FuncSignature)
            and scope.signature.return_type is not None
        ) {
            return self._convert_to_instance(
                self.get_type_of_expression(scope.signature.return_type)
            );
        }
        return None;
    }

    if (
        isinstance(scope, Ability)
        and (scope.accessor_kind == "property")
        and (
            (scope.signature is None)
            or (
                isinstance(scope.signature, FuncSignature)
                and (scope.signature.return_type is None)
            )
        )
    ) {
        hv = scope.find_parent_of_type(HasVar);
        if hv and hv.type_tag {
            return self._convert_to_instance(
                self.get_type_of_expression(hv.type_tag.tag)
            );
        }
    }

    if (
        isinstance(scope, Ability)
        and isinstance(scope.signature, FuncSignature)
        and isinstance(scope.signature.return_type, Expr)
    ) {
        return self._unwrap_type_guard_return(
            self._convert_to_instance(
                self.get_type_of_expression(scope.signature.return_type)
            )
        );
    }

    fn_type_base = self.get_type_of_ability(scope);
    if not isinstance(fn_type_base, FunctionType) {
        return None;
    }
    result = fn_type_base.return_type;
    return self._convert_to_instance(result) if result is not None else None;
}

impl TypeEvaluator._get_enclosing_function(nd: UniNode) -> Ability | None {
    while nd := nd.parent {
        if isinstance(nd, Ability) {
            return nd;
        }
        if isinstance(nd, ImplDef) and isinstance(nd.decl_link, Ability) {
            return nd.decl_link;
        }
    }
    return None;
}

impl TypeEvaluator._resolution_scope_for(expr: UniNode) -> UniScopeNode | None {
    scope = expr.find_parent_of_type(UniScopeNode);
    if scope is None {
        return None;
    }
    if isinstance(scope, Archetype) and scope.base_classes {
        cur: UniNode | None = expr;
        while cur is not None and cur.parent is not scope {
            cur = cur.parent;
        }
        if cur is not None {
            for base in scope.base_classes {
                if base is cur {
                    if isinstance(expr, Name) and scope.type_params {
                        for tp in scope.type_params {
                            if tp.name.value == expr.value {
                                return scope;
                            }
                        }
                    }
                    return scope.parent_scope or scope;
                }
            }
        }
    }
    return scope;
}

impl TypeEvaluator._is_expr_self(expr: Expr) -> bool {
    if (
        isinstance(expr, Name)
        and (expr.value == TOKEN_MAP[Tok.KW_SELF])
        and (fn := self._get_enclosing_method(expr))
        and (not fn.is_static)
        and (not fn.is_cls_method)
    ) {
        return True;
    }
    return False;
}

impl TypeEvaluator._is_expr_super(expr: Expr) -> bool {
    if (
        isinstance(expr, Name)
        and (expr.value == TOKEN_MAP[Tok.KW_SUPER])
        and (fn := self._get_enclosing_method(expr))
        and (not fn.is_static)
        and (not fn.is_cls_method)
    ) {
        return True;
    }
    return False;
}

impl TypeEvaluator._is_unbound_method_call(expr: FuncCall) -> bool {
    if isinstance(expr.target, AtomTrailer) and expr.target.is_attr {
        base_type = self.get_type_of_expression(expr.target.target);
        if isinstance(base_type, ClassType) and base_type.is_instantiable_class() {
            if isinstance(expr.target.right, Name) {
                member = self._lookup_class_member(base_type, expr.target.right.value);
                if member {
                    decl = member.symbol.decl;
                    node_ = decl.name_of if decl is not None else None;
                    if isinstance(node_, HasVar) {
                        return False;
                    }
                    member_type = self.get_type_of_symbol(member.symbol);
                    if not isinstance(member_type, FunctionType) {
                        return False;
                    }
                    if member_type.function_flags
                        & (
                            FunctionTypeFlags.StaticMethod
                            | FunctionTypeFlags.ClassMethod
                        ) {
                        return False;
                    }

                    if isinstance(node_, Ability)
                        and (
                            node_.is_static
                            or node_.is_cls_method
                            or `any(
                                isinstance(dec, Name)
                                    and dec.sym_name == "staticmethod"
                                for dec in (node_.decorators or ())
                            )
                        ) {
                        return False;
                    }
                    params = member_type.parameters;
                    if params and params[0].is_self {
                        return True;
                    }
                    if params and params[0].is_cls {
                        return False;
                    }

                    import from jaclang.compiler.types.stubcat.format {
                        SYMF_INSTANCE_METHOD
                    }
                    prov: any = member.symbol.provider;
                    if int(getattr(prov, "symbits", 0) or 0) & SYMF_INSTANCE_METHOD {
                        return True;
                    }
                    if not isinstance(node_, Ability) or not node_.is_method {
                        return False;
                    }
                    sig = node_.signature;
                    if isinstance(sig, FuncSignature) and sig.is_in_py_class {
                        return False;
                    }
                    return True;
                }
            }
        }
    }
    return False;
}

impl TypeEvaluator._set_symbol_to_expr(expr: NameAtom, sym: Symbol) -> TypeBase {
    sym.add_use(expr);
    sym_type = self.get_type_of_symbol(sym);
    if isinstance(sym_type, UnknownType) and sym_type.is_incomplete {
        return sym_type;
    }
    expr.type = sym_type;
    return sym_type;
}

impl TypeEvaluator.resolve_imported_symbols(sym: Symbol) -> Symbol {
    if (isinstance(sym.decl, Name) and sym.decl.find_parent_of_type(ModuleItem)) {
        mod_item = sym.decl.find_parent_of_type(ModuleItem);
        assert (mod_item is not None);
        self.get_type_of_module(mod_item.from_mod_path);
        if isinstance(mod_item.name, Name) and mod_item.name.sym {
            return mod_item.name.sym;
        }

        self.get_type_of_module_item(mod_item);
        if isinstance(mod_item.name, Name) and mod_item.name.sym {
            return mod_item.name.sym;
        }
        return sym;
    }
    return sym;
}

impl TypeEvaluator._set_module_item_symbol_and_type(
    node_: ModuleItem, sym: Symbol
) -> TypeBase {
    if isinstance(node_.name, Name) {
        node_.name.sym = sym;
    }
    if node_.alias {
        node_.alias.sym = sym;
    }
    sym_type = self.get_type_of_symbol(sym);
    if binding := node_.binding_name {
        if not (isinstance(sym_type, UnknownType) and sym_type.is_incomplete) {
            binding.type = sym_type;
            self._apply_import_binding_kind(
                node_,
                binding,
                sym.binding_kind,
                node_.from_mod_path.dot_path_str,
                resolved_decl_of(sym)
            );
        }
    }
    return sym_type;
}

impl TypeEvaluator._is_ellipsis_only_body(body: Sequence[CodeBlockStmt]) -> bool {
    has_ellipsis = False;
    for stmt in body {
        if isinstance(stmt, Semi) {
            continue;
        }
        if isinstance(stmt, ExprStmt) and isinstance(stmt.expr, Ellipsis) {
            has_ellipsis = True;
            continue;
        }
        return False;
    }
    return has_ellipsis;
}

impl TypeEvaluator._infer_lambda_block_return_type(
    body: Sequence[CodeBlockStmt]
) -> TypeBase {
    none_type = self._convert_to_instance(self.get_none_type());
    return_types: list[TypeBase] = [];
    always_returns = self._collect_return_types(body, return_types);

    non_semi = [
        s
        for s in body
        if not isinstance(s, Semi)
    ];
    if (len(non_semi) == 1 and isinstance(non_semi[0], ExprStmt)) {
        return_types.append(
            self._convert_to_instance(self.get_type_of_expression(non_semi[0].expr))
        );
        always_returns = True;
    }

    if not return_types {
        return none_type;
    }

    if not always_returns {
        return_types.append(none_type);
    }

    seen: list[TypeBase] = [];
    for rt in return_types {
        is_dup = False;
        for s in seen {
            if str(rt) == str(s) {
                is_dup = True;
                break;
            }
        }
        if not is_dup {
            seen.append(rt);
        }
    }

    if len(seen) == 1 {
        return seen[0];
    }

    return UnionType(types=seen);
}

impl TypeEvaluator._collect_return_types(
    stmts: Sequence[CodeBlockStmt], out: list[TypeBase]
) -> bool {
    for stmt in stmts {
        if isinstance(stmt, (Ability, LambdaExpr)) {
            continue;
        }

        if isinstance(stmt, ReturnStmt) {
            if stmt.expr and not isinstance(stmt.expr, Null) {
                out.append(self.get_type_of_expression(stmt.expr));
            }

            return True;
        }

        if isinstance(stmt, RaiseStmt) {
            return True;
        }

        if isinstance(stmt, ExprStmt)
            and isinstance(self.get_type_of_expression(stmt.expr), NeverType) {
            return True;
        }

        if isinstance(stmt, IfStmt) {
            if_returns = self._collect_return_types(list(stmt.body), out);
            else_returns = self._collect_if_else_returns(stmt.else_body, out);
            if if_returns and else_returns {
                return True;
            }
            continue;
        }

        if isinstance(stmt, MatchStmt) {
            if stmt.cases {
                all_return = True;
                for `case in stmt.cases {
                    mc: MatchCase = `case;
                    if not self._collect_return_types(list(mc.body), out) {
                        all_return = False;
                    }
                }
                if all_return {
                    return True;
                }
            }
            continue;
        }

        if isinstance(stmt, SwitchStmt) {
            if stmt.cases {
                has_default = False;
                all_return = True;
                for `case in stmt.cases {
                    sc: SwitchCase = `case;
                    if sc.pattern is None {
                        has_default = True;
                    }
                    if not self._collect_return_types(list(sc.body), out) {
                        all_return = False;
                    }
                }
                if has_default and all_return {
                    return True;
                }
            }
            continue;
        }

        if isinstance(stmt, TryStmt) {
            try_returns = self._collect_return_types(list(stmt.body), out);
            if try_returns {
                if not stmt.excepts or len(stmt.excepts) == 0 {
                    return True;
                }
                all_except = True;
                for exc in stmt.excepts {
                    ex: Except = exc;
                    if not self._collect_return_types(list(ex.body), out) {
                        all_except = False;
                    }
                }
                if all_except {
                    return True;
                }
            }
            continue;
        }

        if isinstance(stmt, WithStmt) {
            if self._collect_return_types(list(stmt.body), out) {
                return True;
            }
            continue;
        }

        if isinstance(stmt, OpenStmt) {
            if self._collect_return_types(list(stmt.body), out) {
                return True;
            }
            continue;
        }

        if isinstance(stmt, (IterForStmt, InForStmt, WhileStmt, ForeverStmt)) {
            self._collect_return_types(list(stmt.body), out);
            _is_infinite_loop = isinstance(stmt, ForeverStmt)
                or (
                    isinstance(stmt, WhileStmt)
                    and isinstance(stmt.condition, Bool)
                    and stmt.condition.lit_value
                );
            if _is_infinite_loop {
                _has_break = False;
                import from jaclang.compiler.frontend.constant { Tokens as _Tok }
                _loop_types = (WhileStmt, ForeverStmt, IterForStmt, InForStmt);
                for _ctrl in stmt.get_all_sub_nodes(CtrlStmt) {
                    if _ctrl.ctrl.name != _Tok.KW_BREAK {
                        continue;
                    }
                    _anc = _ctrl.parent;
                    while _anc is not None and _anc is not stmt {
                        if isinstance(_anc, _loop_types) {
                            break;
                        }
                        _anc = _anc.parent;
                    }
                    if _anc is stmt {
                        _has_break = True;
                        break;
                    }
                }
                if not _has_break {
                    return True;
                }
            }
            continue;
        }
    }
    return False;
}

impl TypeEvaluator._collect_if_else_returns(
    else_body: ElseIf | ElseStmt | None, out: list[TypeBase]
) -> bool {
    if else_body is None {
        return False;
    }
    if isinstance(else_body, ElseStmt) {
        return self._collect_return_types(list(else_body.body), out);
    }
    if isinstance(else_body, ElseIf) {
        if_returns = self._collect_return_types(list(else_body.body), out);
        else_returns = self._collect_if_else_returns(else_body.else_body, out);
        return if_returns and else_returns;
    }
    return False;
}
