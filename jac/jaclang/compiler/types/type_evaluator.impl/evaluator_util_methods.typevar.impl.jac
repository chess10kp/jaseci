impl TypeEvaluator._ct_args_for_class(
    base_type: ClassType, slot_vals: list[Expr]
) -> (tuple[dict[str, any], set[int]] | None) {
    if not base_type.shared.ct_params {
        return None;
    }
    arch = base_type.shared.symbol_table;
    if not isinstance(arch, Archetype) {
        return None;
    }
    ct_args: dict[str, any] = {};
    ct_slots: set[int] = set();
    for (i, tp) in enumerate(arch.type_params) {
        if not tp.is_comptime {
            continue;
        }
        ct_slots.add(i);
        pname = tp.sym_name;
        if i >= len(slot_vals) {
            continue;
        }
        val = slot_vals[i];
        cv = self.ct_demand(val);
        self.ct_site_error(val, f"argument for comptime parameter '{pname}'", cv);
        if cv is not None {
            ct_args[pname] = cv.v;
        }
    }
    return (ct_args, ct_slots, );
}

impl TypeEvaluator._extract_ct_params(node_: Archetype) -> (list[str] | None) {
    names: list[str] = [];
    for tp in node_.type_params {
        if tp.is_comptime {
            names.append(tp.sym_name);
        }
    }
    return names;
}

impl TypeEvaluator._type_var_from_param(node_: TypeParam) -> TypeVarType {
    cached = node_.name.type;
    if isinstance(cached, TypeVarType) {
        return cached;
    }
    result = TypeVarType(
        name=node_.sym_name, is_class_type_param=self._is_class_scoped_type_param(node_)
    );

    node_.name.type = result;
    if node_.bound is not None {
        result.bound = self._convert_to_instance(
            self.get_type_of_expression(node_.bound)
        );
    }
    return result;
}

impl TypeEvaluator._extract_type_params(node_: Archetype) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];

    if node_.type_params {
        for tp in node_.type_params {
            if tp.is_comptime {
                continue;
            }
            tv = self._type_var_from_param(tp);
            type_params.append(tv);
        }
        return type_params;
    }

    outer_type_params = self._get_outer_scope_type_params(node_);
    outer_names = {tp.name for tp in outer_type_params};

    seen_names: set[str] = set();
    generic_base: AtomTrailer | None = None;
    for base_class in node_.base_classes {
        if (not isinstance(base_class, AtomTrailer))
            or base_class.is_attr
            or base_class.is_null_ok {
            continue;
        }
        target_type = self.get_type_of_expression(base_class.target);
        is_generic = (
            isinstance(target_type, ClassType)
            and target_type.is_special_form("Generic")
        );
        if (
            not is_generic
            and isinstance(base_class.target, Name)
            and base_class.target.value == "Generic"
        ) {
            is_generic = True;
        }
        if is_generic {
            generic_base = base_class;
            break;
        }
    }
    if generic_base is not None {
        self._collect_typevars_from_base(
            generic_base, outer_names, seen_names, type_params
        );
    }

    for base_class in node_.base_classes {
        if (not isinstance(base_class, AtomTrailer))
            or base_class.is_attr
            or base_class.is_null_ok {
            continue;
        }
        if base_class is generic_base {
            continue;
        }
        self._collect_typevars_from_base(
            base_class, outer_names, seen_names, type_params
        );
    }
    return type_params;
}

impl TypeEvaluator._is_class_scoped_type_param(node_: TypeParam) -> bool {
    owner: UniNode | None = node_.parent;
    while owner is not None {
        if isinstance(owner, Archetype) {
            return True;
        }
        if isinstance(owner, (Ability, TypeAlias)) {
            return False;
        }
        owner = owner.parent;
    }
    return False;
}

impl TypeEvaluator._collect_typevars_from_base(
    base_class: AtomTrailer,
    outer_names: set[str],
    seen_names: set[str],
    type_params: list[TypeVarType]
) -> None {
    if not (isinstance(base_class.right, IndexSlice) and base_class.right.slices) {
        return;
    }
    type_vars = base_class.right.slices[0].start;
    if isinstance(type_vars, TupleVal) {
        for val in self._annotation_args(type_vars) {
            type_var_type = self.get_type_of_expression(val);
            if isinstance(type_var_type, TypeVarType) {
                if type_var_type.name in outer_names {
                    self.emit_diag(E1062, val, name=type_var_type.name);
                }
                if type_var_type.name not in seen_names {
                    seen_names.add(type_var_type.name);

                    class_type_var = TypeVarType(
                        name=type_var_type.name,
                        is_covariant=type_var_type.is_covariant,
                        is_contravariant=type_var_type.is_contravariant,
                        bound=type_var_type.bound,
                        constraints=type_var_type.constraints,
                        is_class_type_param=True
                    );
                    type_params.append(class_type_var);
                }
            }
        }
    } elif type_vars is not None {
        type_var_type = self.get_type_of_expression(type_vars);
        if isinstance(type_var_type, TypeVarType) {
            if type_var_type.name in outer_names {
                self.emit_diag(E1062, type_vars, name=type_var_type.name);
            }
            if type_var_type.name not in seen_names {
                seen_names.add(type_var_type.name);

                class_type_var = TypeVarType(
                    name=type_var_type.name,
                    is_covariant=type_var_type.is_covariant,
                    is_contravariant=type_var_type.is_contravariant,
                    bound=type_var_type.bound,
                    constraints=type_var_type.constraints,
                    is_class_type_param=True
                );
                type_params.append(class_type_var);
            }
        }
    }
}

impl TypeEvaluator._create_callable_type(
    type_args_expr: Expr | None, error_node: Expr
) -> FunctionType {
    param_types: list[TypeBase] = [];
    return_type: TypeBase = UnknownType();
    is_gradual: bool = False;
    if type_args_expr is None {
        is_gradual = True;
        return create_callable_type([], return_type, is_gradual=True);
    }

    if isinstance(type_args_expr, TupleVal) {
        type_arg_values = self._annotation_args(type_args_expr);
        if len(type_arg_values) == 0 {
            self.emit_diag(E1070, error_node);
            return create_callable_type([], UnknownType(), is_gradual=True);
        }

        first_arg = type_arg_values[0];
        if isinstance(first_arg, Ellipsis) {
            is_gradual = True;
        } elif isinstance(first_arg, ListVal) {
            for param_expr in first_arg.values {
                param_type = self.get_type_of_expression(param_expr);
                param_type = self._convert_to_instance(param_type);
                param_types.append(param_type);
            }
        } else {
            resolved_first = self.get_type_of_expression(first_arg);
            if isinstance(resolved_first, TypeVarType) {
                is_gradual = True;
            } elif self.is_paramspec_class(resolved_first)
                or self.is_type_var_tuple_class(resolved_first) {
                is_gradual = True;
            } else {
                self.emit_diag(E1071, first_arg);
                param_type = self._convert_to_instance(resolved_first);
                param_types.append(param_type);
            }
        }

        if len(type_arg_values) >= 2 {
            return_type_expr = type_arg_values[1];
            return_type = self.get_type_of_expression(return_type_expr);
            return_type = self._convert_to_instance(return_type);
        } else {
            self.emit_diag(E1072, error_node);
            return_type = UnknownType();
        }

        if len(type_arg_values) > 2 {
            self.emit_diag(E1073, type_arg_values[2]);
        }
    } else {
        return_type = self.get_type_of_expression(type_args_expr);
        return_type = self._convert_to_instance(return_type);
        is_gradual = True;
    }
    return create_callable_type(param_types, return_type, is_gradual=is_gradual);
}

impl TypeEvaluator._get_special_form_type(
    name: str, symbol_type: TypeBase
) -> TypeBase | None {
    if not self.prefetch {
        return None;
    }

    is_special_form = (
        isinstance(symbol_type, ClassType)
        and self.prefetch.callable_class
        and symbol_type.shared.same_class(self.prefetch.callable_class.shared)
    );

    is_known_special_form_name = name
        in (
            "Self",
            "Callable",
            "Protocol",
            "Final",
            "LiteralString",
            "Union",
            "Optional",
            "Generic",
            "Type",
            "ClassVar",
            "Annotated",
            "Concatenate",
            "TypeGuard",
            "TypeIs",
            "Unpack",
            "Required",
            "NotRequired",
            "Never",
            "NoReturn",
            "Literal",
            "TypeForm",

        );

    if not is_special_form and not is_known_special_form_name {
        return None;
    }

    match name {
        case "Callable":
            return create_callable_type([], AnyType(), is_gradual=True);

        case "Protocol":
            return self.prefetch.protocol_class;

        case "Final":
            return self.prefetch.final_class;

        case "LiteralString":
            return self.prefetch.literal_string_class;

        case "Self":
            return synthesize_self_type_var();

        case "Never":
            return NeverType();

        case "NoReturn":
            return NeverType();

    }
    return None;
}

impl TypeEvaluator._create_special_builtin_type(
    name: str, base_class: ClassType
) -> ClassType {
    if base_class.shared._derived_special_types is not None {
        cached = base_class.shared._derived_special_types.get(name);
        if cached is not None {
            return cached;
        }
    }
    shared = self._intern_shared(
        ClassDetailsShared(
            class_name=name,
            symbol_table=base_class.shared.symbol_table,
            base_classes=[base_class],
            mro=[],
            is_builtin_class=True
        )
    );
    special_type = ClassType(_shared=shared, flags=base_class.flags);

    special_type.shared.mro = [special_type] + base_class.shared.mro;
    if base_class.shared._derived_special_types is None {
        base_class.shared._derived_special_types = {};
    }
    base_class.shared._derived_special_types[name] = special_type;
    return special_type;
}

impl TypeEvaluator._get_signature_type_params(sig: FuncSignature) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];

    def collect_typevars(expr: Expr) {
        if isinstance(expr, Name) {
            t = self.get_type_of_expression(expr);
            if isinstance(t, TypeVarType) {
                type_params.append(t);
            }
        } elif isinstance(expr, AtomTrailer) and not expr.is_attr {
            if isinstance(expr.right, IndexSlice) {
                for s in expr.right.slices {
                    if s.start {
                        collect_typevars(s.start);
                    }
                }
            }
        } elif isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
            collect_typevars(expr.value);
        } elif isinstance(expr, TupleVal) {
            for v in self._annotation_args(expr) {
                collect_typevars(v);
            }
        } elif isinstance(expr, BinaryExpr) {
            collect_typevars(expr.left);
            collect_typevars(expr.right);
        }
    }

    for param in sig.get_parameters() {
        if isinstance(param, ParamVar) and param.type_tag {
            collect_typevars(param.type_tag.tag);
        }
    }

    if sig.return_type {
        collect_typevars(sig.return_type);
    }

    return type_params;
}

impl TypeEvaluator._get_function_type_params(func: Ability) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];

    for tp in func.type_params {
        if not tp.is_comptime {
            type_params.append(self._type_var_from_param(tp));
        }
    }

    if isinstance(func.signature, FuncSignature) {
        type_params.extend(self._get_signature_type_params(func.signature));
    }

    return type_params;
}

impl TypeEvaluator.validate_typevar_in_type_expr(expr: Expr) -> None {
    if isinstance(expr, Name) {
        resolved_type = self.get_type_of_expression(expr);
        if isinstance(resolved_type, TypeVarType) {
            self.validate_typevar_scope(expr, resolved_type);
        }
    } elif isinstance(expr, AtomTrailer) {
        if not expr.is_attr and isinstance(expr.right, IndexSlice) {
            for slice in expr.right.slices {
                if slice.start {
                    self.validate_typevar_in_type_expr(slice.start);
                }
            }
        }
    } elif isinstance(expr, TupleVal) {
        for val in self._annotation_args(expr) {
            self.validate_typevar_in_type_expr(val);
        }
    } elif isinstance(expr, BinaryExpr) {
        self.validate_typevar_in_type_expr(expr.left);
        self.validate_typevar_in_type_expr(expr.right);
    }
}

impl TypeEvaluator.validate_typevar_variance(func: Ability) -> None {
    if not isinstance(func.parent, Archetype) {
        return;
    }
    enclosing_class = func.parent;

    class_type = self.get_type_of_class(enclosing_class);
    if not class_type or not class_type.shared.type_params {
        return;
    }

    class_tvars: dict[str, TypeVarType] = {};
    for tp in class_type.shared.type_params {
        class_tvars[tp.name] = tp;
    }

    def check_expr(expr: Expr, is_return: bool) {
        if isinstance(expr, Name) {
            resolved = self.get_type_of_expression(expr);
            if isinstance(resolved, TypeVarType) and resolved.name in class_tvars {
                tv = class_tvars[resolved.name];
                if is_return and tv.is_contravariant {
                    self.emit_diag(E1080, expr);
                } elif not is_return and tv.is_covariant {
                    self.emit_diag(E1081, expr);
                }
            }
        } elif isinstance(expr, BinaryExpr) and is_return {
            check_expr(expr.left, is_return);
            check_expr(expr.right, is_return);
        }
    }

    if not isinstance(func.signature, FuncSignature) {
        return;
    }

    params = func.signature.get_parameters();
    if params {
        for param in params {
            if param.type_tag and isinstance(param.type_tag.tag, Expr) {
                check_expr(param.type_tag.tag, False);
            }
        }
    }

    if func.signature.return_type {
        check_expr(func.signature.return_type, True);
    } else {
        for ret_stmt in func.get_all_sub_nodes(ReturnStmt) {
            if ret_stmt.expr and isinstance(ret_stmt.expr, Name) {
                resolved = self.get_type_of_expression(ret_stmt.expr);
                if isinstance(resolved, TypeVarType) and resolved.name in class_tvars {
                    tv = class_tvars[resolved.name];
                    if tv.is_contravariant {
                        self.emit_diag(E1080, ret_stmt);
                    }
                }
            }
        }
    }
}

impl TypeEvaluator.validate_typevar_scope(expr: Expr, type_var: TypeVarType) -> None {
    if type_var.is_self {
        if expr.find_parent_of_type(Archetype) is not None
            or expr.find_parent_of_type(ImplDef) is not None {
            return;
        }
    }
    if isinstance(expr, Name) and expr.sym {
        sym_decl = expr.sym.decl;
        if sym_decl {
            is_module_level = False;
            decl_parent = sym_decl.parent;
            while decl_parent {
                if isinstance(decl_parent, Module) {
                    is_module_level = True;
                    break;
                }
                if isinstance(decl_parent, (Archetype, Ability)) {
                    break;
                }
                decl_parent = decl_parent.parent;
            }

            if is_module_level {
                sig_check = expr.parent;
                while sig_check {
                    if isinstance(sig_check, FuncSignature) {
                        return;
                    }
                    if isinstance(sig_check, (Ability, Archetype, Module)) {
                        break;
                    }
                    sig_check = sig_check.parent;
                }
            }
        }
    }

    if self._type_var_bound_in_scope(expr, type_var.name) {
        return;
    }

    self.emit_diag(E1065, expr, name=type_var.name);
}

impl TypeEvaluator._type_var_bound_in_scope(node_: UniNode, name: str) -> bool {
    current: UniNode | None = node_.parent;
    seen: set[int] = set();

    while current {
        if id(current) in seen {
            return False;
        }
        seen.add(id(current));

        if isinstance(current, Ability) {
            for tp in self._get_function_type_params(current) {
                if tp.name == name {
                    return True;
                }
            }
        } elif isinstance(current, Archetype) {
            class_type = self.get_type_of_class(current);
            for tp in class_type.shared.type_params or [] {
                if tp.name == name {
                    return True;
                }
            }
            return False;
        } elif isinstance(current, ImplDef) {
            if isinstance(current.spec, FuncSignature) {
                for tp in self._get_signature_type_params(current.spec) {
                    if tp.name == name {
                        return True;
                    }
                }
            }
            decl = current.decl_link;
            if isinstance(decl, (Ability, Archetype)) {
                current = decl;
                continue;
            }
        }

        current = current.parent;
    }
    return False;
}

impl TypeEvaluator._get_outer_scope_type_params(node_: UniNode) -> list[TypeVarType] {
    type_params: list[TypeVarType] = [];
    current: UniNode | None = node_.parent;

    while current {
        if isinstance(current, Archetype) {
            class_type = self.get_type_of_class(current);
            if class_type.shared.type_params {
                for tp in class_type.shared.type_params {
                    type_params.append(tp);
                }
            }
        } elif isinstance(current, Ability) {
            func_params = self._get_function_type_params(current);
            for tp in func_params {
                type_params.append(tp);
            }
        }
        current = current.parent;
    }
    return type_params;
}
