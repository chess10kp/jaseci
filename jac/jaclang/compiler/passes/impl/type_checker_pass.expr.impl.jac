impl TypeCheckPass.exit_special_var_ref with SpecialVarRef exit {
    self.evaluator.get_type_of_expression(here);
}

impl TypeCheckPass.exit_name with Name exit {
    if here.__class__ is not Name {
        return;
    }
    if here.sym is None {
        if isinstance(here.parent, AtomTrailer) and here.parent.right is here {
            return;
        }
        if isinstance(here.parent, HasVar)
            and here.parent.defer
            and here is not here.parent.name {
            return;
        }
        if isinstance(here.parent, KWPair) and here.parent.key is here {
            return;
        }
        if isinstance(here.parent, SubTag) {
            return;
        }

        if isinstance(here.parent, ModulePath) {
            return;
        }
        if isinstance(here.parent, JsxElementName) {
            return;
        }
        if isinstance(here.parent, ModuleCode) and here.parent.name is here {
            return;
        }
        self.evaluator.get_type_of_expression(here);
    }
    if here.sym is not None {
        self._check_comptime_only_use(here);
        self._check_type_only_value_use(here);
    }
}

impl TypeCheckPass.exit_edge_ref_trailer with EdgeRefTrailer exit {
    for chain in here.chain {
        if isinstance(chain, FilterCompr) {
            self.evaluator.get_type_of_expression(chain);
        }
    }
}

impl TypeCheckPass.exit_formatted_value with FormattedValue exit {
    self.evaluator.get_type_of_expression(here.format_part);
}

impl TypeCheckPass.exit_filter_compr with FilterCompr exit {
    self.evaluator.get_type_of_expression(here);
}

impl TypeCheckPass.enter_lambda_expr with LambdaExpr entry {
    if _lambda_needs_context(here) {
        self._lambda_depth += 1;
    }
}

impl TypeCheckPass.exit_lambda_expr with LambdaExpr exit {
    if _lambda_needs_context(here) {
        self._lambda_depth -= 1;
    }
}

impl TypeCheckPass.exit_gen_compr with GenCompr exit {
    if self._lambda_depth == 0 {
        self.evaluator.get_type_of_expression(here);
    }
}

impl TypeCheckPass.exit_func_call with FuncCall exit {
    import from jaclang.compiler.symbol_utils {
        CallKind,
        classify_call,
        ability_of_symbol,
        resolve_expr_symbol
    }

    if self._lambda_depth > 0 {
        here.call_kind = classify_call(here).value;
        here.chunks_recv_type = _chunks_receiver_type(here);
        here.callee_decl = ability_of_symbol(resolve_expr_symbol(here.target));
        return;
    }
    self.evaluator.get_type_of_expression(here);

    here.call_kind = classify_call(here).value;

    here.chunks_recv_type = _chunks_receiver_type(here);

    here.callee_decl = ability_of_symbol(resolve_expr_symbol(here.target));

    if here.call_kind == CallKind.INTRINSIC.value {
        self._check_intrinsic_call(here);
    }

    if (
        here.callee_decl is not None
        and here.callee_decl.is_comptime
        and not self._in_comptime_context(here)
    ) {
        cname = here.callee_decl.name_ref.sym_name
            if here.callee_decl.name_ref
            else "?";
        self.evaluator.ct_site_error(
            here,
            f"call to comptime def '{cname}' at runtime",
            self.evaluator.ct_demand(here),
            allow_deferred=False
        );
    }

    tgt_t = here.target.type;
    if (
        isinstance(tgt_t, ClassType)
        and not tgt_t.is_instance()
        and tgt_t.shared.ct_params
        and tgt_t.private.ct_args is None
        and not self.evaluator.ct_quiet
    ) {
        self.ctx.emit(
            E0033,
            node_override=here,
            what=f"instantiation of '{tgt_t.shared.class_name}'",
            reason=f": comptime parameters {tgt_t.shared.ct_params} must be given as {tgt_t.shared.class_name}[...]"
        );
    }
    if isinstance(here.target, AtomTrailer) and not here.target.is_attr {
        if isinstance(here.target.right, IndexSlice) {
            idx_slice: IndexSlice = here.target.right;
            for slice in idx_slice.slices {
                slice_item: Slice = slice;
                if slice_item.start {
                    self.evaluator.validate_typevar_in_type_expr(slice_item.start);
                }
            }
        }
    }
}

impl TypeCheckPass._check_intrinsic_call(nd: FuncCall) -> None {
    import from jaclang.compiler.symbol_utils { intrinsic_registry_if_ready }

    intrinsics = intrinsic_registry_if_ready();
    name = nd.target.sym_name if isinstance(nd.target, Name) else None;
    if intrinsics is None or name is None {
        return;
    }
    import from jaclang.compiler.intrinsic_registry { IntrinsicRegistry }

    if not isinstance(intrinsics, IntrinsicRegistry) {
        return;
    }
    intr = intrinsics.get(name);
    if intr is None {
        return;
    }
    positional: list[Expr] = [];
    has_kw = False;
    for p in (nd.params or []) {
        if isinstance(p, KWPair) {
            has_kw = True;
        } else {
            positional.append(p);
        }
    }
    if has_kw {
        self.ctx.emit(
            E5095,
            node_override=nd,
            name=intr.name,
            reason="keyword arguments are not accepted"
        );
    } elif len(positional) != intr.arity() {
        self.ctx.emit(
            E5095,
            node_override=nd,
            name=intr.name,
            reason=f"expected {intr.arity()} argument(s), got {len(positional)}"
        );
    }
    if intr.result_spec != "none" {
        if self.evaluator.na_builtins_module is not None {
            result_cls = self.evaluator._get_type_from_module(
                self.evaluator.na_builtins_module, intr.result_spec
            );
            if not isinstance(result_cls, UnknownType) {
                nd.type = self.evaluator._convert_to_instance(result_cls);
            }
        }
    } else {
        nd.type = self.evaluator._convert_to_instance(self.evaluator.get_none_type());
    }
}

impl TypeCheckPass._check_intrinsic_collision(nd: Ability) -> None {
    import from jaclang.compiler.symbol_utils { intrinsic_registry_if_ready }

    intrinsics = intrinsic_registry_if_ready();
    if intrinsics is None {
        return;
    }
    import from jaclang.compiler.intrinsic_registry { IntrinsicRegistry }

    if not isinstance(intrinsics, IntrinsicRegistry) {
        return;
    }
    name = nd.name_ref.sym_name if nd.name_ref is not None else None;
    if name is None or not intrinsics.is_intrinsic(name) {
        return;
    }
    if str(nd.loc.mod_path).endswith(".pyi") {
        return;
    }
    for w in self.prog.warnings_had {
        if (
            w.code is W6008
            and w.loc.mod_path == nd.loc.mod_path
            and w.loc.first_line == nd.loc.first_line
        ) {
            return;
        }
    }
    self.ctx.emit(W6008, node_override=nd, name=name);
}

impl TypeCheckPass.exit_compare_expr with CompareExpr exit {
    if self._lambda_depth > 0 {
        return;
    }
    _cmp_mod = here.find_parent_of_type(Module);
    if _cmp_mod is None or _cmp_mod.is_raised_from_py {
        return;
    }
    _ord_ops = (Tok.LT, Tok.LTE, Tok.GT, Tok.GTE);
    _mem_ops = (Tok.KW_IN, Tok.KW_NIN);
    operands: list[Expr] = [here.left];
    operands.extend(here.rights);
    for (i, op) in enumerate(here.ops) {
        _opname = op.name if isinstance(op, Token) else str(op);
        if _opname in _mem_ops {
            _optext = op.value if isinstance(op, Token) else str(op);
            self._diag_erased_membership(here, operands[i + 1], _optext);
            continue;
        }
        if _opname not in _ord_ops {
            continue;
        }
        for side in (operands[i], operands[i + 1]) {
            _side_t = self.evaluator.get_type_of_expression(side);
            self.evaluator._diag_unnarrowed_optional(
                here, _side_t, "an ordered operand"
            );
        }
    }
}

impl TypeCheckPass._diag_erased_membership(
    nd: CompareExpr, hay: Expr, op_text: str
) -> None {
    if not self.evaluator._in_native_context()
        or not self.evaluator._is_strict_site(nd) {
        return;
    }
    hay_t = self.evaluator.get_type_of_expression(hay);

    if hay_t is None
        or isinstance(hay_t, UnknownType)
        or hay_t.is_any_type()
        or hay_t.is_any_instance() {
        self.ctx.emit(
            E1124,
            node_override=hay,
            op=op_text,
            type=str(hay_t) if hay_t is not None else "<unknown>"
        );
    }
}

impl TypeCheckPass.exit_binary_expr with BinaryExpr exit {
    if self._lambda_depth > 0 {
        return;
    }
    self.evaluator.get_type_of_expression(here);
}

impl TypeCheckPass.exit_atom_trailer with AtomTrailer exit {
    if self._lambda_depth > 0 {
        return;
    }
    self.evaluator.get_type_of_expression(here);
    _at_mod = here.find_parent_of_type(Module);
    if (
        not here.is_attr
        and _at_mod is not None
        and not _at_mod.is_raised_from_py
        and isinstance(here.right, IndexSlice)
        and not here.right.is_range
        and here.right.slices
        and here.right.slices[0].start is not None
    ) {
        _idx_expr = here.right.slices[0].start;
        _idx_t = self.evaluator.get_type_of_expression(_idx_expr);
        if isinstance(_idx_t, UnionType) {
            _base_t = self.evaluator.get_type_of_expression(here.target);
            if isinstance(_base_t, ClassType)
                and _base_t.is_class_instance()
                and not _base_t.is_any_type()
                and self.evaluator.get_type_of_magic_method_call(
                    _base_t, "__getitem__", [_idx_expr], None
                )
                    is None {
                self.evaluator._diag_unnarrowed_optional(
                    here, _idx_t, "a subscript index"
                );
            }
        }
    }
}

impl TypeCheckPass.exit_assignment with Assignment exit {
    if here.is_enum_stmt {
        return;
    }
    if here.is_comptime and here.value is not None {
        first = here.target[0] if here.target else None;
        label = first.value if isinstance(first, Name) else "binding";
        self.evaluator.ct_site_error(
            here.value,
            f"initializer of comptime binding '{label}'",
            self.evaluator.ct_demand(here.value)
        );
    }
    if ((len(here.target) == 1) and (here.value is not None)) {
        target = here.target[0];

        is_unannotated_reassign = False;

        if isinstance(target, Name) and target.sym {
            left_type = self.evaluator.get_type_of_symbol(target.sym);

            if (
                target.sym.decl.name_of is not target
                and (
                    (
                        isinstance(target.sym.decl.name_of.parent, Assignment)
                        and target.sym.decl.name_of.parent.type_tag is None
                    )
                    or isinstance(target.sym.decl.name_of.parent, InForStmt)
                )
            ) {
                is_unannotated_reassign = True;

                left_type = self.evaluator._widen_literal_for_declaration(left_type);
            }

            if isinstance(left_type, UnknownType) and left_type.is_incomplete {
                return;
            }

            if hover_type := self.evaluator._get_type_of_lhs_assignment(target) {
                target.type = self.evaluator._convert_to_instance(hover_type);
            } else {
                target.type = left_type;
            }

            if here.type_tag and here.type_tag.tag {
                self._check_bare_generic(here.type_tag.tag, left_type);
                self._check_explicit_any(here.type_tag.tag);
            }
        } elif isinstance(target, (TupleVal, ListVal)) {
            self._eval_unpacking_names(target);
            right_type = self.evaluator.get_type_of_expression(here.value);
            if not isinstance(right_type, UnknownType)
                and not right_type.is_any_instance() {
                iter_result = self.evaluator.get_type_of_magic_method_call(
                    right_type, "__iter__", [], here.value
                );
                if iter_result is None {
                    self.ctx.emit(E1020, node_override=here, type=str(right_type));
                }
            }
            return;
        } else {
            if here.type_tag and here.type_tag.tag {
                declared_type = self.evaluator.get_type_of_expression(
                    here.type_tag.tag
                );

                self._check_bare_generic(here.type_tag.tag, declared_type);
                self._check_explicit_any(here.type_tag.tag);

                declared_inst = self.evaluator._convert_to_instance(declared_type);
                target.type = declared_inst;

                if isinstance(target, AtomTrailer) {
                    chain = target.as_attr_list;
                    if len(chain) >= 2 {
                        chain_last = chain[-1];
                        if isinstance(chain_last, Expr) {
                            chain_last.type = declared_inst;
                        }
                    }
                }
                left_type = declared_inst;
            } else {
                left_type = self.evaluator.get_type_of_expression(target);
                if isinstance(target, Name) and target.sym is not None {
                    sym_declared = self.evaluator.get_type_of_symbol(target.sym);
                    if (
                        sym_declared is not None
                        and not isinstance(sym_declared, (UnknownType, AnyType))
                    ) {
                        left_type = sym_declared;
                    }
                }
                if isinstance(target, AtomTrailer) and target.is_attr {
                    if isinstance(target.right, Name) and target.right.sym {
                        target_sym = target.right.sym;
                        prop_result = self.evaluator.get_property_write_type(
                            target_sym
                        );
                        if prop_result.kind == PropertyWriteKind.WRITABLE {
                            write_type = prop_result.write_type;
                            if write_type is not None {
                                left_type = write_type;
                            }
                        } elif prop_result.kind == PropertyWriteKind.READ_ONLY {
                            self.ctx.emit(
                                E1005, node_override=target, name=target.right.value
                            );
                            return;
                        } else {
                            declared = self.evaluator.get_type_of_symbol(target_sym);
                            if declared {
                                left_type = declared;
                            }
                        }
                    } elif isinstance(target.right, Name) {
                        setter_base = self.evaluator.get_type_of_expression(
                            target.target
                        );
                        if isinstance(setter_base, ClassType)
                            and setter_base.is_class_instance() {
                            if setter_member
                                := self.evaluator._lookup_class_member(
                                    setter_base, "__setattr__"
                                ) {
                                if setter_member.class_type.shared.class_name
                                    != "object" {
                                    setter_ty = self.evaluator.get_type_of_symbol(
                                        setter_member.symbol
                                    );
                                    if isinstance(setter_ty, FunctionType)
                                        and setter_ty.parameters {
                                        setter_val = setter_ty.parameters[-1];
                                        if setter_val.param_type is not None {
                                            left_type = setter_val.param_type;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        right_type = self.evaluator.get_type_of_expression(
            here.value, expected_type=left_type
        );

        if isinstance(right_type, TypeVarType) and isinstance(here.value, FuncCall) {
            caller_type = self.evaluator.get_type_of_expression(here.value.target);
            is_typevar_call = self.evaluator.is_typevar_class(caller_type);
            if is_typevar_call {
                if not isinstance(target, Name) {
                    self.ctx.emit(E1060, node_override=target, name=right_type.name);
                } else {
                    name_target: Name = target;
                    if name_target.value != right_type.name {
                        self.ctx.emit(
                            E1061,
                            node_override=name_target,
                            name=right_type.name,
                            var=name_target.value
                        );
                    }
                }
            }
        }

        if here.aug_op and isinstance(left_type, TypeVarType) {
            op_name = AUG_OPERATOR_MAP.get(here.aug_op.name);

            if left_type.constraints {
                for constraint_type in left_type.constraints {
                    if isinstance(constraint_type, ClassType) {
                        if op_name {
                            result = self.evaluator.get_type_of_magic_method_call(
                                constraint_type, op_name, [here.value], None
                            );
                            if result is None {
                                self.ctx.emit(
                                    E1010,
                                    node_override=here,
                                    op=here.aug_op.name,
                                    type=str(constraint_type)
                                );
                            }
                        }
                    }
                }
            } elif left_type.bound and isinstance(left_type.bound, ClassType) {
                if op_name {
                    result = self.evaluator.get_type_of_magic_method_call(
                        left_type.bound, op_name, [here.value], here.value
                    );
                    if result is None {
                        self.ctx.emit(
                            E1010,
                            node_override=here,
                            op=here.aug_op.name,
                            type=str(left_type.bound)
                        );
                    }
                } else {
                    self.ctx.emit(
                        E1010,
                        node_override=here,
                        op=here.aug_op.name,
                        type=str(left_type.bound)
                    );
                }
            } else {
                self.ctx.emit(
                    E1010, node_override=here, op=here.aug_op.name, type=left_type.name
                );
            }
        } else {
            is_evolving_reassign = is_unannotated_reassign
                and (
                    self.evaluator.is_none_type(left_type)
                    or (isinstance(target, Name) and target.value == "_")
                );
            is_module_fallback_rebind = (
                isinstance(target, Name)
                and target.sym is not None
                and isinstance(left_type, ModuleType)
                and any(
                    d.name_of.find_parent_of_type(Import) is not None
                    for d in target.sym.defn
                )
            );
            if (
                here.aug_op is None
                and not is_evolving_reassign
                and not is_module_fallback_rebind
            ) {
                verdict = self.evaluator.assign_expr(
                    here.value,
                    right_type,
                    left_type,
                    strict=self.evaluator._is_strict_site(here)
                );
                if (
                    not verdict.ok
                    and not verdict.diagnosed
                    and not self.evaluator.slice_assignment_is_valid(target, here.value)
                ) {
                    if self.evaluator._is_awaitable_type(right_type) {
                        self.ctx.emit(
                            E1042, actual=str(right_type), expected=str(left_type)
                        );
                    } else {
                        self.ctx.emit(
                            E1001, actual=str(right_type), expected=str(left_type)
                        );
                    }
                }
            }
        }

        aug_op = here.aug_op;
        if aug_op is not None {
            if (
                not isinstance(left_type, (UnknownType, AnyType))
                and not isinstance(right_type, (UnknownType, AnyType))
                and not left_type.is_any_instance()
                and not right_type.is_any_instance()
            ) {
                aug_magic = AUG_OPERATOR_MAP.get(aug_op.name);
                if aug_magic is not None {
                    result = self.evaluator.get_type_of_magic_method_call(
                        left_type, aug_magic, [here.value], here.value
                    );
                    if result is None {
                        base_op = AUG_TO_BINARY_MAP.get(aug_op.name);
                        if base_op is not None {
                            if base_op in ARITHMETIC_OPERATORS
                                or base_op in BITWISE_OPERATORS
                                or base_op in SHIFT_OPERATORS {
                                if aug_op.value == "**=" {
                                    promoted = get_pow_result_type(
                                        self.evaluator,
                                        left_type,
                                        right_type,
                                        here.value,
                                        target,
                                        here
                                    );
                                } else {
                                    promoted = get_numeric_promotion_type(
                                        self.evaluator,
                                        left_type,
                                        right_type,
                                        base_op,
                                        target,
                                        here.value,
                                        here
                                    );
                                }
                                if promoted is not None {
                                    result = promoted;
                                }
                            }
                            if result is None {
                                binary_methods = BINARY_OPERATOR_MAP.get(base_op);
                                if binary_methods is not None {
                                    (magic, rmagic) = binary_methods;
                                    result = self.evaluator.get_type_of_magic_method_call(
                                        left_type, magic, [here.value], here.value
                                    );
                                    if result is None {
                                        result = self.evaluator.get_type_of_magic_method_call(
                                            right_type, rmagic, [here.value], here.value
                                        );
                                    }
                                }
                            }
                        }
                        if result is None {
                            self.ctx.emit(
                                E1011,
                                node_override=here,
                                op=aug_op.value,
                                left=str(left_type),
                                right=str(right_type)
                            );
                        }
                    }
                    if result is not None and not isinstance(result, UnknownType) {
                        verdict = self.evaluator.assign_expr(
                            here.value, result, left_type
                        );
                        if not verdict.ok and not verdict.diagnosed {
                            self.ctx.emit(
                                E1001, actual=str(result), expected=str(left_type)
                            );
                        }
                    }
                }
            }
        }
    } else {
        for target in here.target {
            if isinstance(target, Name) and target.sym {
                target_type = self.evaluator.get_type_of_symbol(target.sym);
                if not (
                    isinstance(target_type, UnknownType) and target_type.is_incomplete
                ) {
                    target.type = target_type;
                }
            } elif isinstance(target, (TupleVal, ListVal)) {
                self._eval_unpacking_names(target);
            } else {
                self.evaluator.get_type_of_expression(target);
            }
        }
    }
}

impl TypeCheckPass.exit_yield_expr with YieldExpr exit {
    if here.expr is None {
        return;
    }
    yielded_type = self.evaluator.get_type_of_expression(here.expr);
    scope = self.evaluator._get_enclosing_return_scope(here);
    if scope is None {
        return;
    }

    return_type = self.evaluator._get_declared_return_type(scope);
    if return_type is None or isinstance(return_type, UnknownType) {
        return;
    }

    is_async = isinstance(scope, Ability) and scope.is_async;
    yield_type = get_generator_yield_type(return_type, is_async);
    if yield_type is None
        and isinstance(return_type, ClassType)
        and return_type.is_builtin(
            [
                "Generator",
                "AsyncGenerator",
                "AwaitableGenerator",
                "Iterator",
                "AsyncIterator",
                "Iterable",
                "AsyncIterable",

            ]
        ) {
        return;
    }
    expected_yield = (
        self.evaluator._convert_to_instance(yield_type)
            if yield_type is not None
            else return_type
    );

    if not here.with_from {
        if not self.evaluator.assign_type(
            yielded_type, expected_yield, strict=self.evaluator._is_strict_site(here)
        ) {
            self.ctx.emit(
                E1093,
                node_override=here,
                actual=str(yielded_type),
                expected=str(expected_yield)
            );
        }
    }
}

impl TypeCheckPass.exit_sub_tag with SubTag exit {
    if isinstance(here.tag, Expr) {
        self.evaluator.validate_typevar_in_type_expr(here.tag);

        if here.tag?.type is None {
            self.evaluator.get_type_of_expression(here.tag);
        }
    }
}

impl TypeCheckPass._eval_unpacking_names(container: Expr) -> None {
    if isinstance(container, (TupleVal, ListVal)) {
        for val in container.values {
            if isinstance(val, Name) {
                self.evaluator.get_type_of_expression(val);
            } elif isinstance(val, UnaryExpr)
                and isinstance(val.op, Token)
                and val.op.name == Tok.STAR_MUL.value
                and isinstance(val.operand, Expr) {
                self.evaluator.get_type_of_expression(val.operand);
            } elif isinstance(val, (TupleVal, ListVal)) {
                self._eval_unpacking_names(val);
            }
        }
    }
}

impl TypeCheckPass._stamp_fixed_width -> None {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import from jaclang.compiler.types.fixed_width { numeric_name_of }
    stack: list[UniNode] = [self.module];
    while stack {
        nd = stack.pop();
        if isinstance(nd, Expr) {
            name = numeric_name_of(nd.type);
            if name is not None and JAC_TYPE_REGISTRY.is_sized(name) {
                nd.fw = name;
                nd.fw_safe = self._provably_in_range(nd, name);
            }
        }
        for k in nd.kid {
            stack.append(k);
        }
    }
}

impl TypeCheckPass._provably_in_range(nd: Expr, name: str) -> bool {
    import from jaclang.compiler.types.fixed_width { interval_of_expr, interval_of_op }
    if isinstance(nd, BinaryExpr) and isinstance(nd.op, Token) {
        op = FW_INTERVAL_OPS.get(nd.op.name);
        if op is None {
            return False;
        }
        return interval_of_op(
            op, interval_of_expr(nd.left), interval_of_expr(nd.right), name
        );
    }
    if isinstance(nd, UnaryExpr) and isinstance(nd.op, Token) {
        if nd.op.name != Tok.MINUS {
            return False;
        }
        return interval_of_op("neg", interval_of_expr(nd.operand), (0, 0), name);
    }
    return False;
}

def _lambda_value_body(nd: LambdaExpr) -> bool {
    if isinstance(nd.body, Expr) or nd.tail_return_expr() is not None {
        return True;
    }
    return isinstance(nd.body, list)
        and len(nd.body) == 1
        and isinstance(nd.body[0], ReturnStmt)
        and nd.body[0].expr is not None;
}

def _lambda_needs_context(nd: LambdaExpr) -> bool {
    return nd.signature is not None
        and any(param.type_tag is None for param in nd.signature.get_parameters())
        and _lambda_value_body(nd);
}

def _chunks_receiver_type(nd: FuncCall) -> (str | None) {
    if not (
        isinstance(nd.target, AtomTrailer)
        and nd.target.is_attr
        and isinstance(nd.target.right, Name)
        and nd.target.right.sym_name == "chunks"
        and nd.params is not None
        and len(nd.params) == 1
    ) {
        return None;
    }
    try {
        recv = nd.target.target.type;
        if recv is None {
            return None;
        }
        return recv.mangle();
    } except Exception {
        return None;
    }
}
