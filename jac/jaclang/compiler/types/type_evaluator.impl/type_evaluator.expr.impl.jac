impl TypeEvaluator._walk_compr_clauses(comprs: list[InnerCompr]) -> None {
    for compr in comprs {
        self.get_type_of_expression(compr.collection);
        if isinstance(compr.target, (Name, TupleVal, ListVal)) {
            self.get_type_of_expression(compr.target);
        }
        if compr.conditional {
            for cond in compr.conditional {
                self.get_type_of_expression(cond);
            }
        }
    }
}

impl TypeEvaluator._null_ok_attr_type(
    expr: AtomTrailer, base_type: (TypeBase | None) = None
) -> TypeBase {
    if base_type is not None and self.is_any_type(base_type) {
        expr.right.type = AnyType();
        return expr.right.type;
    }
    none_type = self.prefetch.none_type_class;
    if none_type is not None {
        expr.right.type = self._convert_to_instance(none_type);
        return expr.right.type;
    }
    return UnknownType();
}

impl TypeEvaluator._get_type_of_expression_core(
    expr: Expr, expected_type: TypeBase | None = None
) -> TypeBase {
    if isinstance(expr, BuiltinType) and expr.value == "any" {
        if expr.sym is None and self.typing_module is not None {
            if symbol := lookup_symtab(self.typing_module, "Any", self.typing_module) {
                symbol.add_use(expr);
                expr.sym = symbol;
                if symbol.decl and symbol.decl.name_of {
                    expr.name_of = symbol.decl.name_of;
                }
            }
        }
        if self.prefetch and self.prefetch.any_class is not None {
            return self.prefetch.any_class;
        }
        return AnyType();
    }
    match expr {
        case CfgExpr():
            return self._get_type_of_expression_core(expr.expr, expected_type);

        case String():
            if self.prefetch and self.prefetch.str_class {
                if isinstance(expr.lit_value, bytes) {
                    if self.prefetch.bytes_class {
                        return self._convert_to_instance(self.prefetch.bytes_class);
                    }
                    return UnknownType();
                }

                if isinstance(expr.lit_value, str) {
                    ann_parent = expr.parent
                        if not isinstance(expr.parent, MultiString)
                        else expr.parent.parent;
                    if isinstance(ann_parent, (SubTag, FuncSignature)) {
                        resolved = self._try_resolve_forward_ref(expr);
                        if resolved is not None {
                            return resolved;
                        }
                    }
                }

                str_class = self.prefetch.str_class;
                if isinstance(str_class, ClassType) {
                    literal_type = str_class.clone_with_literal(expr.lit_value);
                    return self._convert_to_instance(literal_type);
                }
                return self._convert_to_instance(str_class);
            }

        case MultiString():
            if self.prefetch and self.prefetch.str_class {
                for s in expr.strings {
                    if isinstance(s, String) and isinstance(s.lit_value, bytes) {
                        if self.prefetch.bytes_class {
                            return self._convert_to_instance(self.prefetch.bytes_class);
                        }
                        return UnknownType();
                    }
                }

                if (
                    isinstance(expr.parent, (SubTag, FuncSignature))
                    and len(expr.strings) == 1
                    and isinstance(expr.strings[0], String)
                    and isinstance(expr.strings[0].lit_value, str)
                ) {
                    resolved = self._try_resolve_forward_ref(expr.strings[0]);
                    if resolved is not None {
                        return resolved;
                    }
                }
                str_class = self.prefetch.str_class;
                if isinstance(str_class, ClassType) {
                    all_literal = True;
                    combined_value = "";
                    for s in expr.strings {
                        if isinstance(s, String) {
                            if isinstance(s.lit_value, bytes) {
                                all_literal = False;
                                break;
                            }
                            combined_value += s.lit_value;
                        } elif isinstance(s, FString) {
                            if not self._is_fstring_all_literal(s) {
                                all_literal = False;
                                break;
                            }
                            all_literal = True;
                        }
                    }
                    if all_literal
                        and not any(isinstance(s, FString) for s in expr.strings) {
                        literal_type = str_class.clone_with_literal(combined_value);
                        return self._convert_to_instance(literal_type);
                    } elif all_literal {
                        if self.prefetch.literal_string_class {
                            return self._convert_to_instance(
                                self.prefetch.literal_string_class
                            );
                        }
                    }
                }
                return self._convert_to_instance(str_class);
            }

        case FString():
            if self.prefetch and self.prefetch.str_class {
                if self._is_fstring_all_literal(expr) {
                    if self.prefetch.literal_string_class {
                        return self._convert_to_instance(
                            self.prefetch.literal_string_class
                        );
                    }
                }
                return self._convert_to_instance(self.prefetch.str_class);
            }

        case Int():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_int(expr));
            }

        case Float():
            if self.prefetch {
                return self._convert_to_instance(self.get_type_of_float(expr));
            }

        case Null():
            if self.prefetch and self.prefetch.none_type_class {
                return self._convert_to_instance(self.prefetch.none_type_class);
            }

        case ListVal():
            if self.prefetch and self.prefetch.list_class {
                list_inst = self._convert_to_instance(self.prefetch.list_class);
                if isinstance(list_inst, ClassType) and not expr.values {
                    expected_elem = self._get_expected_element_type(
                        expected_type, self.prefetch.list_class
                    );
                    if expected_elem is not None {
                        list_inst.private.type_args = [expected_elem];
                    } else {
                        flow_elem = self._infer_list_elem_from_mutations(expr);
                        if flow_elem is not None {
                            list_inst.private.type_args = [flow_elem];
                        }
                    }
                }
                if isinstance(list_inst, ClassType) and expr.values {
                    elem_types: list[TypeBase] = [];
                    expected_elem = self._get_expected_element_type(
                        expected_type, self.prefetch.list_class
                    );
                    for _val in expr.values {
                        elem_type = self.get_type_of_expression(
                            _val, expected_type=expected_elem
                        );

                        if expected_elem is None {
                            elem_type = self._container_value_type(elem_type, expr);
                        }
                        if not isinstance(elem_type, UnknownType)
                            and not self._type_in_list(elem_type, elem_types) {
                            elem_types.append(elem_type);
                        }
                    }
                    if expected_elem is not None and elem_types {
                        all_compatible = True;
                        for et in elem_types {
                            if not self.assign_type(et, expected_elem) {
                                all_compatible = False;
                                break;
                            }
                        }
                        if all_compatible {
                            list_inst.private.type_args = [expected_elem];
                        } else {
                            if len(elem_types) == 1 {
                                list_inst.private.type_args = [elem_types[0]];
                            } elif len(elem_types) > 1 {
                                list_inst.private.type_args = [
                                    UnionType(types=elem_types)
                                ];
                            }
                        }
                    } else {
                        if len(elem_types) == 1 {
                            list_inst.private.type_args = [elem_types[0]];
                        } elif len(elem_types) > 1 {
                            list_inst.private.type_args = [UnionType(types=elem_types)];
                        }
                    }
                }
                return list_inst;
            }

        case DictVal():
            if self.prefetch and self.prefetch.dict_class {
                dict_inst = self._convert_to_instance(self.prefetch.dict_class);
                if isinstance(dict_inst, ClassType) and not expr.kv_pairs {
                    expected_kv_e = self._get_expected_kv_types(
                        expected_type, self.prefetch.dict_class
                    );
                    if expected_kv_e is not None {
                        dict_inst.private.type_args = list(expected_kv_e);
                    }
                }
                if isinstance(dict_inst, ClassType) and expr.kv_pairs {
                    key_types: list[TypeBase] = [];
                    val_types: list[TypeBase] = [];
                    for _kv in expr.kv_pairs {
                        if _kv.key {
                            kt = self._container_value_type(
                                self.get_type_of_expression(_kv.key), expr
                            );
                            if not isinstance(kt, UnknownType)
                                and not self._type_in_list(kt, key_types) {
                                key_types.append(kt);
                            }
                            vt = self._container_value_type(
                                self.get_type_of_expression(_kv.value), expr
                            );
                            if not isinstance(vt, UnknownType)
                                and not self._type_in_list(vt, val_types) {
                                val_types.append(vt);
                            }
                        } else {
                            st = self.get_type_of_expression(_kv.value);
                            if (
                                isinstance(st, ClassType)
                                and st.is_builtin("dict")
                                and st.private.type_args
                                and len(st.private.type_args) >= 2
                            ) {
                                skt = st.private.type_args[0];
                                if not isinstance(skt, UnknownType)
                                    and not self._type_in_list(skt, key_types) {
                                    key_types.append(skt);
                                }
                                svt = st.private.type_args[1];
                                if not isinstance(svt, UnknownType)
                                    and not self._type_in_list(svt, val_types) {
                                    val_types.append(svt);
                                }
                            }
                        }
                    }

                    expected_kv = self._get_expected_kv_types(
                        expected_type, self.prefetch.dict_class
                    );
                    if expected_kv is not None and (key_types or val_types) {
                        all_ok = True;
                        for kt in key_types {
                            if not self.assign_type(kt, expected_kv[0]) {
                                all_ok = False;
                                break;
                            }
                        }
                        if all_ok {
                            for vt in val_types {
                                if not self.assign_type(vt, expected_kv[1]) {
                                    all_ok = False;
                                    break;
                                }
                            }
                        }
                        if all_ok {
                            dict_inst.private.type_args = list(expected_kv);
                        } elif key_types or val_types {
                            k_arg = key_types[0]
                                if len(key_types) == 1
                                else UnionType(types=key_types)
                                    if key_types
                                    else UnknownType();
                            v_arg = val_types[0]
                                if len(val_types) == 1
                                else UnionType(types=val_types)
                                    if val_types
                                    else UnknownType();
                            dict_inst.private.type_args = [k_arg, v_arg];
                        }
                    } elif key_types or val_types {
                        k_arg = key_types[0]
                            if len(key_types) == 1
                            else UnionType(types=key_types)
                                if key_types
                                else UnknownType();
                        v_arg = val_types[0]
                            if len(val_types) == 1
                            else UnionType(types=val_types)
                                if val_types
                                else UnknownType();
                        dict_inst.private.type_args = [k_arg, v_arg];
                    }
                }
                return dict_inst;
            }

        case TupleVal():
            if self.prefetch and self.prefetch.tuple_class {
                tuple_inst = self._convert_to_instance(self.prefetch.tuple_class);
                if isinstance(tuple_inst, ClassType) and expr.values {
                    elem_types_t: list[TypeBase] = [];
                    for _val in expr.values {
                        et = self._container_value_type(
                            self.get_type_of_expression(
                                _val.value if isinstance(_val, KWPair) else _val
                            ),
                            expr
                        );
                        if not isinstance(et, UnknownType) {
                            elem_types_t.append(et);
                        }
                    }

                    if (
                        isinstance(expected_type, ClassType)
                        and self.prefetch.tuple_class
                        and expected_type.shared.same_class(
                            self.prefetch.tuple_class.shared
                        )
                        and expected_type.private.type_args
                        and elem_types_t
                    ) {
                        all_ok = True;
                        exp_args = expected_type.private.type_args;
                        for (i, et) in enumerate(elem_types_t) {
                            exp_elem = exp_args[i]
                                if i < len(exp_args)
                                else exp_args[-1];
                            if not self.assign_type(
                                et, self._convert_to_instance(exp_elem)
                            ) {
                                all_ok = False;
                                break;
                            }
                        }
                        if all_ok {
                            tuple_inst.private.type_args = expected_type.private.type_args;
                        } else {
                            tuple_inst.private.type_args = elem_types_t;
                        }
                    } elif elem_types_t {
                        tuple_inst.private.type_args = elem_types_t;
                    }
                }
                return tuple_inst;
            }

        case SetVal():
            if self.prefetch and self.prefetch.set_class {
                set_inst = self._convert_to_instance(self.prefetch.set_class);
                if isinstance(set_inst, ClassType) and not expr.values {
                    expected_elem_se = self._get_expected_element_type(
                        expected_type, self.prefetch.set_class
                    );
                    if expected_elem_se is not None {
                        set_inst.private.type_args = [expected_elem_se];
                    }
                }
                if isinstance(set_inst, ClassType) and expr.values {
                    set_elem_types: list[TypeBase] = [];
                    for _val in expr.values {
                        et = self._container_value_type(
                            self.get_type_of_expression(_val), expr
                        );
                        if not isinstance(et, UnknownType)
                            and not self._type_in_list(et, set_elem_types) {
                            set_elem_types.append(et);
                        }
                    }

                    expected_elem_s = self._get_expected_element_type(
                        expected_type, self.prefetch.set_class
                    );
                    if expected_elem_s is not None and set_elem_types {
                        all_ok = True;
                        for et in set_elem_types {
                            if not self.assign_type(et, expected_elem_s) {
                                all_ok = False;
                                break;
                            }
                        }
                        if all_ok {
                            set_inst.private.type_args = [expected_elem_s];
                        } else {
                            if len(set_elem_types) == 1 {
                                set_inst.private.type_args = [set_elem_types[0]];
                            } elif len(set_elem_types) > 1 {
                                set_inst.private.type_args = [
                                    UnionType(types=set_elem_types)
                                ];
                            }
                        }
                    } else {
                        if len(set_elem_types) == 1 {
                            set_inst.private.type_args = [set_elem_types[0]];
                        } elif len(set_elem_types) > 1 {
                            set_inst.private.type_args = [
                                UnionType(types=set_elem_types)
                            ];
                        }
                    }
                }
                return set_inst;
            }

        case SetCompr():
            if self.prefetch and self.prefetch.set_class {
                set_inst = self._convert_to_instance(self.prefetch.set_class);
                self._walk_compr_clauses(expr.compr);
                elem_type = self._container_value_type(
                    self.get_type_of_expression(expr.out_expr), expr
                );
                if isinstance(set_inst, ClassType)
                    and not isinstance(elem_type, UnknownType) {
                    set_inst.private.type_args = [
                        self._widen_literal_for_declaration(elem_type)
                    ];
                }
                return set_inst;
            }

        case GenCompr():
            if self.prefetch and self.prefetch.generator_class {
                gen_inst = self._convert_to_instance(self.prefetch.generator_class);
                self._walk_compr_clauses(expr.compr);
                elem_type = self._container_value_type(
                    self.get_type_of_expression(expr.out_expr), expr
                );
                none_inst = self._convert_to_instance(self.prefetch.none_type_class)
                    if self.prefetch.none_type_class
                    else UnknownType();
                if isinstance(gen_inst, ClassType)
                    and not isinstance(elem_type, UnknownType) {
                    gen_inst.private.type_args = [
                        self._widen_literal_for_declaration(elem_type),
                        none_inst,
                        none_inst
                    ];
                }
                return gen_inst;
            }

        case ListCompr():
            if self.prefetch and self.prefetch.list_class {
                list_inst = self._convert_to_instance(self.prefetch.list_class);
                self._walk_compr_clauses(expr.compr);

                expected_elem_lc = self._get_expected_element_type(
                    expected_type, self.prefetch.list_class
                );
                elem_type = self._container_value_type(
                    self.get_type_of_expression(expr.out_expr, expected_elem_lc), expr
                );
                if isinstance(list_inst, ClassType) {
                    if expected_elem_lc is not None
                        and (
                            isinstance(elem_type, UnknownType)
                            or self.assign_type(elem_type, expected_elem_lc)
                        ) {
                        list_inst.private.type_args = [expected_elem_lc];
                    } elif not isinstance(elem_type, UnknownType) {
                        list_inst.private.type_args = [
                            self._widen_literal_for_declaration(elem_type)
                        ];
                    }
                }
                return list_inst;
            }

        case DictCompr():
            if self.prefetch and self.prefetch.dict_class {
                dict_inst = self._convert_to_instance(self.prefetch.dict_class);
                self._walk_compr_clauses(expr.compr);
                if isinstance(expr.kv_pair, KVPair) and expr.kv_pair.key is not None {
                    key_type = self._container_value_type(
                        self.get_type_of_expression(expr.kv_pair.key), expr
                    );
                    val_type = self._container_value_type(
                        self.get_type_of_expression(expr.kv_pair.value), expr
                    );
                    if isinstance(dict_inst, ClassType)
                        and not isinstance(key_type, UnknownType)
                        and not isinstance(val_type, UnknownType) {
                        dict_inst.private.type_args = [key_type, val_type];
                    }
                }
                return dict_inst;
            }

        case LambdaExpr():
            return_type: TypeBase = UnknownType();
            parameters: list[Parameter] = [];
            has_unresolved_param = False;

            expected_func: FunctionType | None = None;
            if (isinstance(expected_type, FunctionType) and expected_type.parameters) {
                expected_func = expected_type;
            }
            if isinstance(expr.signature, FuncSignature) {
                if isinstance(expr.signature.return_type, Expr) {
                    return_type = self._convert_to_instance(
                        self.get_type_of_expression(expr.signature.return_type)
                    );
                }
                sig_params = expr.signature.get_parameters();
                seeded_param = False;
                for (idx, param) in enumerate(sig_params) {
                    param_type: TypeBase | None = None;
                    if param.type_tag {
                        param_type = self._convert_to_instance(
                            self.get_type_of_expression(param.type_tag.tag)
                        );
                    } elif (
                        expected_func
                        and expected_func.parameters
                        and idx < len(expected_func.parameters)
                    ) {
                        param_type = expected_func.parameters[idx].param_type;
                        if param_type is not None {
                            param.name.type = param_type;
                            param.type = param_type;
                            seeded_param = True;
                        }
                    }
                    if param_type is None {
                        has_unresolved_param = True;
                    }
                    parameters.append(
                        Parameter(
                            name=param.name.value,
                            category=ParameterCategory.Positional,
                            param_type=param_type,
                            default_value=param.value,
                        )
                    );
                }

                if seeded_param {
                    seed_body_node: UniNode | None = None;
                    if isinstance(expr.body, Expr) {
                        seed_body_node = expr.body;
                    } elif isinstance(expr.body, list) and len(expr.body) == 1 {
                        seed_body_node = expr.body[0];
                    } else {
                        seed_body_node = expr.tail_return_expr();
                    }
                    if seed_body_node is not None {
                        self._invalidate_expr_type_cache(seed_body_node);
                    }
                }
            }

            if has_unresolved_param {
                return FunctionType(
                    func_name="<lambda>",
                    return_type=UnknownType(),
                    parameters=parameters,
                );
            }
            if isinstance(expr.body, Expr) {
                body_type = self.get_type_of_expression(expr.body);
                if isinstance(return_type, UnknownType) {
                    return_type = body_type;
                }
            } elif isinstance(return_type, UnknownType) {
                return_type = self._infer_lambda_block_return_type(expr.body);
            } elif (tail_expr := expr.tail_return_expr()) is not None {
                tail_type = self.get_type_of_expression(
                    tail_expr, expected_type=return_type
                );
                verdict = self.assign_expr(
                    tail_expr, tail_type, return_type, strict=self._is_strict_site(expr)
                );
                if not verdict.ok and not verdict.diagnosed {
                    self.emit_diag(
                        E1002,
                        tail_expr,
                        actual=str(tail_type),
                        expected=str(return_type)
                    );
                }
            }
            return FunctionType(
                func_name="<lambda>", return_type=return_type, parameters=parameters,
            );

        case JsxElement():
            if self.prefetch and self.prefetch.jsx_element_class {
                if expr.name and expr.name.parts {
                    for part in expr.name.parts {
                        if isinstance(part, Name) {
                            tag_val = part.value or "";
                            is_mobui = self._is_mobui_module(part);
                            if tag_val and (tag_val[0].isupper() or is_mobui) {
                                self.get_type_of_expression(part);
                            } elif tag_val {
                                self._resolve_intrinsic_jsx_tag(part, tag_val);
                            }
                        }
                    }
                }
                self._validate_jsx_props(expr, expected_type);
                return self._convert_to_instance(self.prefetch.jsx_element_class);
            }

        case Bool():
            if self.prefetch and self.prefetch.bool_class {
                return self._convert_to_instance(self.prefetch.bool_class);
            }

        case IndexSlice():
            if expr.is_range {
                if self.prefetch and self.prefetch.slice_class {
                    return self._convert_to_instance(self.prefetch.slice_class);
                }
                return UnknownType();
            }
            if expr.slices and expr.slices[0].start is not None {
                return self.get_type_of_expression(expr.slices[0].start);
            }
            return UnknownType();

        case AtomTrailer():
            base_type = self.get_type_of_expression(expr.target);

            if isinstance(expr.target, Name) and expr.target.sym {
                if narrowed := self.get_narrowed_type(expr.target.sym, expr) {
                    base_type = narrowed;
                }
            } elif not isinstance(expr.target, Name)
                and isinstance(base_type, (UnionType, ClassType)) {
                if narrowed
                    := self.get_narrowed_type_for_expr(expr.target, base_type, expr) {
                    base_type = narrowed;
                }
            }

            if isinstance(base_type, TypeVarType) and base_type.is_self {
                _sf_arch: Archetype | Enum | None = expr.find_parent_of_type(Archetype);
                if _sf_arch is None {
                    _sf_impl = expr.find_parent_of_type(ImplDef);
                    if _sf_impl is not None
                        and isinstance(_sf_impl.decl_link, Ability) {
                        _sf_arch = _sf_impl.decl_link.method_owner;
                    }
                }
                if isinstance(_sf_arch, Archetype) {
                    _sf_cls = self.get_type_of_class(_sf_arch);
                    if isinstance(_sf_cls, ClassType) {
                        base_type = _sf_cls
                            if (
                                isinstance(expr.target, Name)
                                and expr.target.value == "Self"
                            )
                            else _sf_cls.clone_as_instance();
                    }
                }
            }

            if expr.is_attr {
                if isinstance(base_type, UnknownType) {
                    assert isinstance(expr.right, Name);

                    if base_type.is_diagnosed {
                        return UnknownType(is_diagnosed=True);
                    }
                    if base_type.is_incomplete {
                        return UnknownType(is_incomplete=True);
                    }
                    target_already_unknown = (
                        isinstance(expr.target.type, UnknownType)
                        and isinstance(expr.target, (AtomTrailer, FuncCall))
                    );

                    if not target_already_unknown {
                        self.emit_diag(E1032, expr.right, attr=expr.right.value);
                    }
                    return UnknownType();
                }

                full_narrowed: TypeBase | None = None;

                assert isinstance(expr.right, Name);
                if isinstance(base_type, AnyType) {
                    expr.right.type = AnyType(is_foreign=base_type.is_foreign);
                    return expr.right.type;
                }
                if isinstance(base_type, ModuleType) {
                    if base_type.is_external or base_type.symbol_table is None {
                        if not base_type.is_external {
                            submodule = self._resolve_submodule_attr(
                                base_type, expr.right.value
                            );
                            if submodule is not None {
                                expr.right.type = submodule;
                                return submodule;
                            }
                        }
                        expr.right.type = AnyType(is_foreign=True);
                        return expr.right.type;
                    }

                    member_sym = lookup_symtab(
                        base_type.symbol_table, expr.right.value, self.builtins_module
                    );
                    if (
                        member_sym is None
                        and isinstance(base_type.symbol_table, Module)
                    ) {
                        member_sym = self._resolve_star_import_symbol(
                            base_type.symbol_table, expr.right.value
                        );
                    }
                    if member_sym is not None {
                        sym = member_sym;
                        sym_type = self.get_type_of_symbol(sym);

                        if special_form
                            := self._get_special_form_type(sym.sym_name, sym_type) {
                            sym.add_use(expr.right);
                            expr.right.type = special_form;
                            return special_form;
                        }

                        if isinstance(sym_type, FunctionType) {
                            overloaded_fns: list[FunctionType] = [sym_type];

                            def_sym = self.resolve_to_definition_symbol(sym);
                            overload_scope = base_type.symbol_table;
                            if def_sym.parent_tab is not None {
                                overload_scope = def_sym.parent_tab;
                            }
                            all_syms = collect_member_syms(
                                overload_scope, def_sym.sym_name
                            );
                            for overload_symbol in all_syms {
                                if overload_symbol == def_sym {
                                    continue;
                                }
                                overload_type = self.get_type_of_symbol(
                                    overload_symbol
                                );
                                if isinstance(overload_type, FunctionType) {
                                    overloaded_fns.append(overload_type);
                                }
                            }
                            if len(overloaded_fns) > 1 {
                                overloaded_ty: OverloadedType | None = OverloadedType(
                                    overloads=overloaded_fns
                                );
                                sym.add_use(expr.right);
                                expr.right.type = overloaded_ty;
                                return overloaded_ty;
                            }
                        }

                        sym.add_use(expr.right);
                        if isinstance(sym_type, UnknownType)
                            and sym_type.is_incomplete {
                            return sym_type;
                        }
                        expr.right.type = sym_type;
                        return sym_type;
                    }

                    if submod_type
                        := self._resolve_submodule_attr(base_type, expr.right.value) {
                        expr.right.type = submod_type;
                        return submod_type;
                    }
                    module_cls = self._get_type_from_module(
                        self.types_module, "ModuleType"
                    );
                    if isinstance(module_cls, ClassType) {
                        module_inst = self._convert_to_instance(module_cls);
                        if isinstance(module_inst, ClassType) {
                            if module_member
                                := self._lookup_object_member(
                                    module_inst, expr.right.value
                                ) {
                                module_member.symbol.add_use(expr.right);

                                if prop_ret
                                    := self.get_getter_type_from_property(
                                        module_member.symbol
                                    ) {
                                    expr.right.type = self.specialize_member_type(
                                        prop_ret, module_inst
                                    );
                                    return expr.right.type;
                                }
                                expr.right.type = self.get_type_of_member(
                                    module_member, module_inst
                                );
                                return expr.right.type;
                            }
                        }
                    }
                    return UnknownType();
                } elif base_type.is_instantiable_class() {
                    assert isinstance(base_type, ClassType);
                    lookup_type = self._get_type_for_member_lookup(base_type);
                    if member
                        := self._lookup_class_member(lookup_type, expr.right.value) {
                        if lookup_type.is_enum_class() {
                            member_name = expr.right.value;
                            if (
                                lookup_type.shared.enum_members
                                and member_name in lookup_type.shared.enum_members
                            ) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                member_info = lookup_type.shared.enum_members[
                                    member_name
                                ];
                                return EnumMemberType(
                                    enum_class=lookup_type,
                                    member_info=member_info,
                                    flags=TypeFlags.Instance
                                );
                            }
                        }

                        member_ty = self._get_method_with_overloads(
                            member, lookup_type
                        );
                        member.symbol.add_use(expr.right);
                        expr.right.type = member_ty;
                        return expr.right.type;
                    }
                    if lookup_type.is_enum_class() {
                        enum_meta_ty = self._synthesize_enum_metaclass_attr(
                            lookup_type, expr.right.value
                        );
                        if enum_meta_ty is not None {
                            expr.right.type = enum_meta_ty;
                            return enum_meta_ty;
                        }
                    }
                    if expr.is_null_ok {
                        return self._null_ok_attr_type(expr, lookup_type);
                    }
                    if expr.right.value == "init" {
                        if dunder_init
                            := self._lookup_class_member(lookup_type, "__init__") {
                            self._set_symbol_to_expr(expr.right, dunder_init.symbol);
                            expr.right.type = self.get_type_of_member(
                                dunder_init, lookup_type
                            );
                            return expr.right.type;
                        }
                    }
                    if isinstance(lookup_type, ClassType)
                        and lookup_type.is_instantiable_class()
                        and self.prefetch is not None
                        and self.prefetch.type_class is not None {
                        meta_cls = self._metaclass_of(lookup_type)
                            or self.prefetch.type_class;
                        meta_inst = self._convert_to_instance(meta_cls);
                        if isinstance(meta_inst, ClassType) {
                            if meta_member
                                := self._lookup_object_member(
                                    meta_inst, expr.right.value
                                ) {
                                meta_member.symbol.add_use(expr.right);
                                expr.right.type = self.get_type_of_symbol(
                                    meta_member.symbol
                                );
                                return expr.right.type;
                            }
                        }
                    }
                    if not self.is_any_type(lookup_type) {
                        _has_tvars = (
                            isinstance(lookup_type, ClassType)
                            and lookup_type.private.type_args is not None
                            and any(
                                isinstance(a, TypeVarType)
                                for a in lookup_type.private.type_args
                            )
                        );
                        if not _has_tvars {
                            self.emit_diag(
                                E1030,
                                expr.right,
                                base_type=str(lookup_type),
                                attr=expr.right.value
                            );
                        }
                    }
                    if self.is_any_type(lookup_type)
                        and self.prefetch.any_class is not None {
                        return self.prefetch.any_class;
                    }
                    return UnknownType();
                } elif base_type.is_class_instance() {
                    assert isinstance(base_type, ClassType);
                    _attr_arch = base_type.shared.symbol_table;
                    if isinstance(_attr_arch, Archetype)
                        and _attr_arch.find_parent_of_type(Import) is not None {
                        if _ext_member
                            := self._lookup_class_member(base_type, expr.right.value) {
                            _ext_member.symbol.add_use(expr.right);
                        }
                        expr.right.type = self._extern_member_type(
                            _attr_arch, expr.right.sym_name
                        );
                        return expr.right.type;
                    }
                    if (
                        self.prefetch.final_class
                        and base_type.shared.same_class(
                            self.prefetch.final_class.shared
                        )
                        and base_type.private.type_args
                    ) {
                        inner = base_type.private.type_args[0];
                        if isinstance(inner, ClassType) {
                            base_type = inner;
                        }
                    }
                    if base_type.is_enum_class() {
                        attr_name = expr.right.value;
                        if attr_name in ('name', '_name_') {
                            if self.prefetch.str_class is None {
                                return UnknownType();
                            }
                            expr.right.type = self._convert_to_instance(
                                self.prefetch.str_class
                            );
                            return expr.right.type;
                        }
                        if attr_name in ('value', '_value_') {
                            enum_value_type = self._resolve_enum_value_type(base_type);
                            if enum_value_type is not None {
                                expr.right.type = self._convert_to_instance(
                                    enum_value_type
                                );
                            } else {
                                expr.right.type = AnyType();
                            }
                            return expr.right.type;
                        }
                    }
                    if self._is_type_subscript(base_type) {
                        lookup_type = self._get_type_for_member_lookup(base_type);
                        if member
                            := self._lookup_class_member(
                                lookup_type, expr.right.value
                            ) {
                            value = self._set_symbol_to_expr(expr.right, member.symbol);
                            return value;
                        }
                    }
                    if member
                        := self._lookup_object_member(base_type, expr.right.value) {
                        if (
                            expr.right.value in ('init', '__init__')
                            and base_type.is_data_class()
                        ) {
                            has_explicit_init = (
                                'init' in base_type.shared.symbol_table.names_in_scope
                                or '__init__'
                                    in base_type.shared.symbol_table.names_in_scope
                            );

                            has_any_has_vars = any(
                                self._scope_has_fields(cls.shared.symbol_table)
                                for cls in base_type.shared.mro
                                if cls.shared.class_name != "object"
                            );

                            if not has_explicit_init and has_any_has_vars {
                                implicit_init_type = self._create_object_init_method(
                                    base_type
                                );
                                expr.right.type = implicit_init_type;
                                return implicit_init_type;
                            }
                        }
                        member_ty = self._get_method_with_overloads(member, base_type);

                        if prop_return_type
                            := self.get_getter_type_from_property(member.symbol) {
                            prop_return_type = self.specialize_member_type(
                                prop_return_type,
                                base_type,
                                self.declaring_class_of(member.symbol, base_type)
                            );
                            member.symbol.add_use(expr.right);

                            cfg_narrowed = self.get_narrowed_type_for_expr(
                                expr, prop_return_type, expr
                            );
                            expr.right.type = cfg_narrowed or prop_return_type;
                            return expr.right.type;
                        }

                        member.symbol.add_use(expr.right);

                        if full_narrowed is None
                            and not isinstance(member_ty, OverloadedType) {
                            cfg_narrowed = self.get_narrowed_type_for_expr(
                                expr, member_ty, expr
                            );
                            if cfg_narrowed is not None {
                                full_narrowed = cfg_narrowed;
                            }
                        }

                        expr.right.type = full_narrowed or member_ty;
                        return expr.right.type;
                    }
                    if (
                        expr.right.value in ('init', '__init__')
                        and base_type.is_data_class()
                    ) {
                        implicit_init_type = self._create_object_init_method(base_type);
                        expr.right.type = implicit_init_type;
                        return implicit_init_type;
                    }
                    if base_type.is_typeddict() {
                        if expr.right.value in ("get", "pop", "setdefault") {
                            synth = self._synthesize_typeddict_method(
                                base_type, expr.right.value
                            );
                            if synth is not None {
                                expr.right.type = synth;
                                return synth;
                            }
                        }
                        td_dict = self._typeddict_as_dict(base_type);
                        if (
                            td_dict is not None
                            and (
                                td_member
                                := self._lookup_object_member(td_dict, expr.right.value)
                            )
                        ) {
                            td_member_ty = self.get_type_of_member(td_member, td_dict);
                            expr.right.type = td_member_ty;
                            return td_member_ty;
                        }
                    }
                    if expr.right.value == "init"
                        and isinstance(base_type, ClassType) {
                        if dunder_init
                            := self._lookup_object_member(base_type, "__init__") {
                            self._set_symbol_to_expr(expr.right, dunder_init.symbol);
                            expr.right.type = self.get_type_of_member(
                                dunder_init, base_type
                            );
                            return expr.right.type;
                        }
                    }
                    if getattr_return := self._get_getattr_return_type(base_type) {
                        expr.right.type = getattr_return;
                        expr.right.is_getattr_resolved = True;
                        return getattr_return;
                    }
                    if expr.is_null_ok {
                        return self._null_ok_attr_type(expr, base_type);
                    }
                    if not self.is_any_type(base_type) {
                        _has_tvars = (
                            isinstance(base_type, ClassType)
                            and base_type.private.type_args is not None
                            and any(
                                isinstance(a, TypeVarType)
                                for a in base_type.private.type_args
                            )
                        );
                        if not _has_tvars {
                            self.emit_diag(
                                E1030,
                                expr.right,
                                base_type=str(base_type),
                                attr=expr.right.value
                            );
                        }
                    }
                    if self.is_any_type(base_type)
                        and self.prefetch.any_class is not None {
                        return self.prefetch.any_class;
                    }
                    return UnknownType();
                } elif isinstance(base_type, EnumMemberType) {
                    return self._enum_member_attr_type(base_type, expr.right.value)
                        or UnknownType();
                } elif isinstance(base_type, UnionType) and base_type.types {
                    member_types: list[TypeBase] = [];
                    missing_types: list[str] = [];
                    decl_for_ide: NameAtom | None = None;
                    for union_member in base_type.types {
                        if self.is_explicit_any(union_member)
                            or isinstance(union_member, UnknownType) {
                            member_types.append(union_member);
                            continue;
                        }
                        if isinstance(union_member, EnumMemberType) {
                            enum_member_type = self._enum_member_attr_type(
                                union_member, expr.right.value
                            );
                            if enum_member_type is not None {
                                member_types.append(enum_member_type);
                            } else {
                                missing_types.append(str(union_member));
                            }
                            continue;
                        }
                        if isinstance(union_member, ClassType) {
                            lookup_type = self._get_type_for_member_lookup(
                                union_member
                            );
                            member = self._lookup_class_member(
                                lookup_type, expr.right.value
                            );
                            if member is None
                                and lookup_type.is_instantiable_class()
                                and self.prefetch is not None {
                                union_meta_cls = self._metaclass_of(lookup_type)
                                    or self.prefetch.type_class;
                                if union_meta_cls is not None {
                                    lookup_type = union_meta_cls.clone_as_instance();
                                    member = self._lookup_object_member(
                                        lookup_type, expr.right.value
                                    );
                                }
                            }
                            if member is not None {
                                prop_ret = self.get_getter_type_from_property(
                                    member.symbol
                                )
                                    if not lookup_type.is_instantiable_class()
                                    else None;
                                if prop_ret is not None {
                                    member_types.append(
                                        self.specialize_member_type(
                                            prop_ret,
                                            lookup_type,
                                            self.declaring_class_of(
                                                member.symbol, lookup_type
                                            )
                                        )
                                    );
                                } else {
                                    member_types.append(
                                        self._get_method_with_overloads(
                                            member, lookup_type
                                        )
                                    );
                                }
                                if decl_for_ide is None {
                                    decl_for_ide = member.symbol.decl;
                                }
                                continue;
                            }
                        }
                        missing_types.append(str(union_member));
                    }
                    all_union_members_have_field = len(member_types)
                        == len(base_type.types);
                    if all_union_members_have_field {
                        if decl_for_ide and decl_for_ide.sym {
                            decl_for_ide.sym.add_use(expr.right);
                        }

                        unique_types = list({str(t): t for t in member_types}.values());
                        all_same_type = len(unique_types) == 1;
                        expr.right.type = unique_types[0]
                            if all_same_type
                            else UnionType(types=unique_types);
                        return expr.right.type;
                    }
                    if expr.is_null_ok {
                        if member_types and self.prefetch.none_type_class is not None {
                            with_none = list(member_types);
                            with_none.append(
                                self._convert_to_instance(self.prefetch.none_type_class)
                            );
                            uniq = list({str(t): t for t in with_none}.values());
                            expr.right.type = uniq[0]
                                if len(uniq) == 1
                                else UnionType(types=uniq);
                            return expr.right.type;
                        }
                        return self._null_ok_attr_type(expr, base_type);
                    }
                    self.emit_diag(
                        E1099,
                        expr.right,
                        attr=expr.right.value,
                        type=str(base_type),
                        missing=", ".join(missing_types)
                    );
                    if member_types {
                        if decl_for_ide and decl_for_ide.sym {
                            decl_for_ide.sym.add_use(expr.right);
                        }
                        unique_types = list({str(t): t for t in member_types}.values());
                        all_same_type = len(unique_types) == 1;
                        expr.right.type = unique_types[0]
                            if all_same_type
                            else UnionType(types=unique_types);
                        return expr.right.type;
                    }
                    return UnknownType();
                } elif isinstance(base_type, TypeVarType) {
                    attr_name = expr.right.value;
                    if base_type.is_param_spec and attr_name in ("args", "kwargs") {
                        return AnyType();
                    }
                    if base_type.constraints {
                        found_member: ClassMember | None = None;
                        for constraint_type in base_type.constraints {
                            if isinstance(constraint_type, ClassType) {
                                if member
                                    := self._lookup_object_member(
                                        constraint_type, attr_name
                                    ) {
                                    if found_member is None {
                                        found_member = member;
                                    }
                                } else {
                                    self.emit_diag(
                                        E1031,
                                        expr,
                                        attr=attr_name,
                                        type=str(constraint_type)
                                    );
                                }
                            }
                        }
                        if found_member {
                            self._set_symbol_to_expr(expr.right, found_member.symbol);
                            return self.get_type_of_symbol(found_member.symbol);
                        }
                        return UnknownType();
                    }
                    if base_type.bound {
                        bound_type = base_type.bound;
                        if isinstance(bound_type, ClassType) {
                            if member
                                := self._lookup_object_member(bound_type, attr_name) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                return self.get_type_of_symbol(member.symbol);
                            }

                            self.emit_diag(
                                E1031, expr, attr=attr_name, type=str(bound_type)
                            );
                            return UnknownType();
                        } elif isinstance(bound_type, UnionType) {
                            for member_type in bound_type.types {
                                if isinstance(member_type, ClassType) {
                                    if not self._lookup_object_member(
                                        member_type, attr_name
                                    ) {
                                        self.emit_diag(
                                            E1031,
                                            expr,
                                            attr=attr_name,
                                            type=str(member_type)
                                        );
                                    }
                                }
                            }
                            return UnknownType();
                        }
                    }
                    universal_attrs = {
                        "__class__",
                        "__doc__",
                        "__dict__",
                        "__module__",
                        "__sizeof__",
                        "__str__",
                        "__repr__",
                        "__hash__",
                        "__eq__",
                        "__ne__",
                        "__init__",
                        "__new__"
                    };
                    if attr_name in universal_attrs {
                        if self.prefetch.object_class {
                            if member
                                := self._lookup_object_member(
                                    self.prefetch.object_class.clone_as_instance(),
                                    attr_name
                                ) {
                                self._set_symbol_to_expr(expr.right, member.symbol);
                                return self.get_type_of_symbol(member.symbol);
                            }
                        }
                        return UnknownType();
                    }
                    self.emit_diag(E1031, expr, attr=attr_name, type=base_type.name);
                    return UnknownType();
                } elif isinstance(base_type, (FunctionType, OverloadedType)) {
                    import from jaclang.compiler.types.type_utils { PropertyWriteKind }
                    if expr.right.value in ("setter", "getter", "deleter")
                        and isinstance(expr.target, Name)
                        and (expr.target.sym is not None)
                        and self._classify_property_symbol(expr.target.sym)
                            != PropertyWriteKind.NOT_PROPERTY {
                        return base_type;
                    }
                    if self.prefetch and self.prefetch.function_class {
                        if member
                            := self._lookup_object_member(
                                self.prefetch.function_class.clone_as_instance(),
                                expr.right.value
                            ) {
                            self._set_symbol_to_expr(expr.right, member.symbol);
                            return self.get_type_of_symbol(member.symbol);
                        }
                    }
                    self.emit_diag(
                        E1031, expr, attr=expr.right.value, type=str(base_type)
                    );
                    return UnknownType();
                }
            } elif expr.is_null_ok {
                return self._null_ok_attr_type(expr, base_type);
            } elif isinstance(expr.right, AssignCompr) {
                if not isinstance(base_type, ClassType) {
                    self.emit_diag(E1034, expr, type=str(base_type));
                    return base_type;
                }
                if len(base_type.private.type_args) == 1 {
                    sequence_of = self._convert_to_instance(
                        base_type.private.type_args[0]
                    );
                    for assign in expr.right.assigns {
                        if assign.key is not None {
                            if member
                                := self._lookup_object_member(
                                    sequence_of, assign.key.sym_name
                                ) {
                                self._set_symbol_to_expr(assign.key, member.symbol);
                            } else {
                                self.emit_diag(
                                    E1033,
                                    assign.key,
                                    member=assign.key.sym_name,
                                    type=str(sequence_of)
                                );
                            }
                            dest_type = self.get_type_of_expression(assign.key);
                            src_type = self.get_type_of_expression(assign.value);
                            if not self.assign_type(src_type, dest_type) {
                                self.emit_diag(
                                    E1035,
                                    assign.value,
                                    src=str(src_type),
                                    dest=str(dest_type)
                                );
                            }
                        }
                    }
                }
                for assign in expr.right.assigns {
                    self.get_type_of_expression(assign.value);
                }
                return base_type;
            } elif isinstance(expr.right, FilterCompr) {
                filter_result = self.get_type_of_expression(expr.right);
                if not isinstance(filter_result, UnknownType) {
                    return filter_result;
                }
                return base_type;
            } else {
                if isinstance(base_type, UnknownType) and base_type.is_incomplete {
                    return UnknownType(is_incomplete=True);
                }
                if (
                    isinstance(base_type, ClassType)
                    and base_type.is_special_form("Callable")
                )
                    or (
                        isinstance(base_type, FunctionType)
                        and base_type.is_gradual_callable_form()
                    ) {
                    type_args_expr: Expr | None = None;
                    if isinstance(expr.right, IndexSlice) and expr.right.slices {
                        type_args_expr = expr.right.slices[0].start;
                    }
                    return self._create_callable_type(type_args_expr, expr);
                }
                if (
                    isinstance(base_type, ClassType)
                    and base_type.shared.is_builtin_class
                    and base_type.shared.class_name == "_SpecialForm"
                ) {
                    target_name: str | None = None;
                    if isinstance(expr.target, Name) and expr.target.sym {
                        target_name = expr.target.sym.sym_name;
                    } elif (
                        isinstance(expr.target, AtomTrailer)
                        and expr.target.is_attr
                        and isinstance(expr.target.right, Name)
                    ) {
                        target_name = expr.target.right.value;
                    }
                    if target_name == "Union" or target_name == "Optional" {
                        union_args: list[TypeBase] = [];
                        if isinstance(expr.right, IndexSlice) and expr.right.slices {
                            ua_vals = expr.right.slices[0].start;
                            for val in self._annotation_args(ua_vals) {
                                union_args.append(
                                    self._type_from_union_annotation_arg(val)
                                );
                            }
                        }
                        if target_name == "Optional"
                            and self.prefetch.none_type_class {
                            union_args.append(
                                self._convert_to_instance(self.prefetch.none_type_class)
                            );
                        }
                        if len(union_args) == 1 {
                            return union_args[0];
                        }
                        if len(union_args) > 1 {
                            return UnionType(types=union_args);
                        }
                    }

                    if target_name == "ClassVar" {
                        if isinstance(expr.right, IndexSlice) and expr.right.slices {
                            inner_type_expr = expr.right.slices[0].start;
                            if inner_type_expr is not None {
                                return self._convert_to_instance(
                                    self.get_type_of_expression(inner_type_expr)
                                );
                            }
                        }

                        return UnknownType();
                    }

                    if target_name is not None
                        and (target_name == "TypeIs" or target_name == "TypeGuard") {
                        guarded: TypeBase | None = None;
                        if isinstance(expr.right, IndexSlice) and expr.right.slices {
                            guard_expr = expr.right.slices[0].start;
                            if guard_expr is not None {
                                guarded = self._convert_to_instance(
                                    self.get_type_of_expression(guard_expr)
                                );
                            }
                        }
                        return self._create_type_guard_type(target_name, guarded);
                    }

                    if target_name == "Literal" {
                        lit_types: list[TypeBase] = [];
                        if isinstance(expr.right, IndexSlice) and expr.right.slices {
                            lit_vals = expr.right.slices[0].start;
                            val_exprs = self._annotation_args(lit_vals);
                            for val in val_exprs {
                                if lt := self._literal_type_from_expr(val) {
                                    lit_types.append(lt);
                                }
                            }
                        }
                        if len(lit_types) == 1 {
                            return lit_types[0];
                        }
                        if len(lit_types) > 1 {
                            return UnionType(types=lit_types);
                        }
                        return UnknownType();
                    }
                }
                if base_type.is_any_instance()
                    and self.prefetch.any_class is not None {
                    return self.prefetch.any_class;
                }
                if isinstance(base_type, ClassType)
                    and base_type.is_instantiable_class() {
                    type_args: list[TypeBase] = [];
                    slot_vals: list[Expr] = [];
                    if isinstance(expr.right, IndexSlice) and expr.right.slices {
                        type_args_vals = expr.right.slices[0].start;
                        slot_vals = self._annotation_args(type_args_vals);
                    }
                    ct_args = self._ct_args_for_class(base_type, slot_vals);
                    for (si, val) in enumerate(slot_vals) {
                        if ct_args is not None and si in ct_args[1] {
                            continue;
                        }
                        type_args.append(self._type_from_union_annotation_arg(val));
                    }
                    specialized = base_type.specialize_generics(type_args);
                    if ct_args is not None {
                        specialized.private.ct_args = ct_args[0];
                    }
                    return specialized;
                }
                if isinstance(expr.right, IndexSlice) and expr.right.is_range {
                    return self.get_type_of_expression(expr.target);
                }
                if isinstance(base_type, TypeVarType) {
                    if base_type.constraints {
                        any_subscriptable = False;
                        for constraint_type in base_type.constraints {
                            if isinstance(constraint_type, ClassType) {
                                result = self.get_type_of_magic_method_call(
                                    constraint_type, "__getitem__", [expr.right], None
                                );
                                if result {
                                    any_subscriptable = True;
                                } else {
                                    self.emit_diag(
                                        E1040, expr, type=str(constraint_type)
                                    );
                                }
                            }
                        }
                        return UnknownType();
                    }
                    if base_type.bound {
                        bound_type = base_type.bound;
                        if isinstance(bound_type, ClassType) {
                            result = self.get_type_of_magic_method_call(
                                bound_type, "__getitem__", [expr.right], expr
                            );
                            if result {
                                return result;
                            }

                            self.emit_diag(E1040, expr, type=str(bound_type));
                            return UnknownType();
                        }
                    }

                    self.emit_diag(E1040, expr, type=base_type.name);
                    return UnknownType();
                }
                subscript_arg: Expr = expr.right;
                if (
                    isinstance(expr.right, IndexSlice)
                    and not expr.right.is_range
                    and expr.right.slices
                ) {
                    slice_start = expr.right.slices[0].start;
                    if slice_start is not None {
                        subscript_arg = slice_start;
                    }
                }
                if isinstance(base_type, AnyType) {
                    return AnyType(is_foreign=base_type.is_foreign);
                }
                if isinstance(base_type, UnknownType) {
                    return UnknownType(
                        is_diagnosed=base_type.is_diagnosed,
                        is_incomplete=base_type.is_incomplete
                    );
                }
                if (
                    isinstance(base_type, ClassType)
                    and base_type.is_class_instance()
                    and base_type.is_typeddict()
                ) {
                    td_result = self._get_typeddict_indexed_type(
                        base_type, subscript_arg, expr
                    );
                    if td_result is not None {
                        return td_result;
                    }
                }
                if tuple_elem
                    := self._tuple_literal_index_type(base_type, subscript_arg) {
                    return tuple_elem;
                }
                result = self.get_type_of_magic_method_call(
                    base_type, "__getitem__", [subscript_arg], expr
                );
                if result and not isinstance(result, UnknownType) {
                    return result;
                }
                if isinstance(base_type, ClassType) {
                    if base_type.is_builtin("str") {
                        return base_type;
                    }
                    if base_type.is_builtin("bytes") {
                        if self.prefetch and self.prefetch.int_class {
                            return self._convert_to_instance(self.prefetch.int_class);
                        }
                    }
                }
                return result or UnknownType();
            }

        case AtomUnit():
            if isinstance(expr.value, Ability) {
                return self.get_type_of_ability(expr.value);
            }
            return self.get_type_of_expression(expr.value);

        case FuncCall():
            result = self.validate_call_args(expr);
            if not expr.params and expected_type is not None {
                constructor = self.get_type_of_expression(expr.target);
                if isinstance(constructor, ClassType)
                    and constructor.is_instantiable_class()
                    and constructor.is_builtin(["list", "set", "frozenset", "dict"]) {
                    expected = self._get_expected_container_type(
                        expected_type, constructor
                    );
                    if expected is not None and expected.private.type_args {
                        return expected.clone_as_instance();
                    }
                }
            }
            return result;

        case AwaitExpr():
            target_type = self.get_type_of_expression(expr.target);

            if isinstance(target_type, TypeVarType) {
                if target_type.constraints {
                    for constraint_type in target_type.constraints {
                        if isinstance(constraint_type, ClassType) {
                            result = self.get_type_of_magic_method_call(
                                constraint_type, "__await__", [], None
                            );
                            if not result {
                                self.emit_diag(E1041, expr, type=str(constraint_type));
                            }
                        }
                    }
                    return UnknownType();
                }
                if target_type.bound and isinstance(target_type.bound, ClassType) {
                    result = self.get_type_of_magic_method_call(
                        target_type.bound, "__await__", [], None
                    );
                    if result {
                        return result;
                    }

                    self.emit_diag(E1041, expr, type=str(target_type.bound));
                    return UnknownType();
                }

                self.emit_diag(E1041, expr, type=target_type.name);
                return UnknownType();
            }

            return self._unwrap_awaitable_type(target_type, expr);

        case CastExpr():
            self.get_type_of_expression(expr.value);
            target_type = self.get_type_of_expression(expr.cast_type);
            if not (
                target_type.is_any_type()
                or isinstance(target_type, UnknownType)
                or is_annotation_type(self, target_type)
            ) {
                self.emit_diag(E1044, expr.cast_type, type=str(target_type));
            }
            return self._convert_to_instance(target_type);

        case BinaryExpr():
            return get_type_of_binary_operation(self, expr);

        case CompareExpr():
            operand_types: list[TypeBase] = [self.get_type_of_expression(expr.left)];
            for right in expr.rights {
                operand_types.append(self.get_type_of_expression(right));
            }
            for i in range(len(expr.ops)) {
                op = expr.ops[i];
                left_type = operand_types[i];
                right_type = operand_types[i + 1];

                if (
                    isinstance(left_type, UnknownType)
                    or isinstance(right_type, UnknownType)
                    or left_type.is_any_type()
                    or right_type.is_any_type()
                    or left_type.is_any_instance()
                    or right_type.is_any_instance()
                ) {
                    continue;
                }

                if op.name in (Tok.KW_IS, Tok.KW_ISN) {
                    continue;
                }

                if op.name in (Tok.KW_IN, Tok.KW_NIN) {
                    is_enum = (
                        isinstance(right_type, ClassType) and right_type.is_enum_class()
                    );
                    if not is_enum {
                        _in_item = expr.left if i == 0 else expr.rights[i - 1];
                        result = self.get_type_of_magic_method_call(
                            right_type, "__contains__", [_in_item], None
                        );
                        if result is None {
                            self.emit_diag(
                                E1111, expr, op=op.value, type=str(right_type)
                            );
                        }
                    }
                    continue;
                }

                if op.name in BINARY_OPERATOR_MAP {
                    if both_numeric(left_type, right_type) {
                        unify_numeric_operands(
                            self,
                            left_type,
                            right_type,
                            expr.left if i == 0 else expr.rights[i - 1],
                            expr.rights[i],
                            expr,
                            op.value
                        );
                        continue;
                    }
                    (magic, rmagic) = BINARY_OPERATOR_MAP[op.name];
                    result = self.get_type_of_magic_method_call(
                        left_type, magic, [expr.rights[i]], None
                    );
                    if result is None {
                        result = self.get_type_of_magic_method_call(
                            right_type,
                            rmagic,
                            [expr.left if i == 0 else expr.rights[i - 1]],
                            None
                        );
                    }
                    if result is None and op.name in (Tok.EE, Tok.NE) {
                        continue;
                    }
                    if result is None {
                        self.emit_diag(
                            E1110,
                            expr,
                            op=op.value,
                            left=str(left_type),
                            right=str(right_type)
                        );
                    }
                }
            }

            if self.prefetch and self.prefetch.bool_class {
                return self._convert_to_instance(self.prefetch.bool_class);
            }
            return UnknownType();

        case IfElseExpr():
            self.get_type_of_expression(expr.condition.expr);
            true_type = self.get_type_of_expression(expr.value.expr);
            false_type = self.get_type_of_expression(expr.else_value.expr);

            unique_types: list[TypeBase] = [];
            for branch_type in [true_type, false_type] {
                self._collect_unique_types(branch_type, unique_types);
            }
            if len(unique_types) == 1 {
                return unique_types[0];
            }
            if len(unique_types) > 1 {
                return UnionType(types=unique_types);
            }
            return true_type;

        case BoolExpr():
            is_and = isinstance(expr.op, Token) and expr.op.name == Tok.KW_AND;
            is_or = isinstance(expr.op, Token) and expr.op.name == Tok.KW_OR;
            operand_types: list[TypeBase] = [];
            num_values = len(expr.values);

            and_override_keys: list[int] = [];
            for i in range(num_values) {
                op_type = self.get_type_of_expression(expr.values[i].expr);

                if is_and and i < num_values - 1 {
                    import from jaclang.compiler.types.type_evaluator {
                        NarrowingKind,
                        NarrowingPredicate,
                        NarrowingTarget
                    }
                    operand_expr = expr.values[i].expr;
                    cond_info = self.classify_condition(operand_expr);
                    if cond_info is not None
                        and cond_info.kind
                            in (
                                NarrowingKind.ISINSTANCE,
                                NarrowingKind.TYPE_IS,
                                NarrowingKind.TYPE_GUARD
                            )
                        and cond_info.narrow_type is not None {
                        narrowed_sym = self._find_symbol_by_key(
                            cond_info.key, operand_expr
                        );
                        if narrowed_sym is not None {
                            sym_type = self.get_type_of_symbol(narrowed_sym);
                            predicate = NarrowingPredicate(
                                key=cond_info.key,
                                narrow_type=cond_info.narrow_type,
                                replaces_declared=(
                                    cond_info.kind == NarrowingKind.TYPE_GUARD
                                )
                            );
                            target = NarrowingTarget(
                                key=cond_info.key,
                                declared_type=sym_type,
                                symbol=narrowed_sym
                            );
                            narrowed = self._apply_narrowing(
                                predicate, sym_type, True, target
                            );
                            if narrowed is not None {
                                sym_id = id(narrowed_sym);
                                self._and_narrowing_overrides[sym_id] = narrowed;
                                and_override_keys.append(sym_id);
                            }
                        }
                    }
                }

                if is_or
                    and i < num_values - 1
                    and self.prefetch.none_type_class is not None {
                    none_type = self._convert_to_instance(
                        self.prefetch.none_type_class
                    );
                    if none_type is not None {
                        op_type = self.exclude_type_from_union(op_type, none_type);
                    }
                }
                self._collect_unique_types(op_type, operand_types);
            }

            for key in and_override_keys {
                self._and_narrowing_overrides.pop(key, None);
            }
            if len(operand_types) == 1 {
                return operand_types[0];
            } elif len(operand_types) > 1 {
                return UnionType(types=operand_types);
            }
            return UnknownType();

        case UnaryExpr():
            if isinstance(expr.op, Token) {
                if expr.op.name == Tok.BW_AND {
                    _ref_t = self.get_type_of_expression(expr.operand);
                    if (
                        isinstance(_ref_t, ClassType)
                        and _ref_t.is_builtin("str")
                        and _ref_t.is_instance()
                    ) {
                        return AnyType();
                    }
                    return _ref_t;
                }
                if expr.ownership in (OwnershipKind.OWN, OwnershipKind.IMM) {
                    return self.get_type_of_expression(expr.operand);
                }
                if expr.op.name == Tok.NOT {
                    operand_type = self.get_type_of_expression(expr.operand);
                    if (
                        not isinstance(operand_type, UnknownType)
                        and self.prefetch
                        and self.prefetch.bool_class
                    ) {
                        return self._convert_to_instance(self.prefetch.bool_class);
                    }
                    return operand_type;
                }
                if expr.op.name in (Tok.MINUS, Tok.BW_NOT, Tok.PLUS) {
                    operand_type = self.get_type_of_expression(expr.operand);
                    op_name = "__neg__"
                        if expr.op.name == Tok.MINUS
                        else ("__pos__" if expr.op.name == Tok.PLUS else "__invert__");

                    if isinstance(operand_type, TypeVarType) {
                        if operand_type.constraints {
                            for constraint_type in operand_type.constraints {
                                if isinstance(constraint_type, ClassType) {
                                    result = self.get_type_of_magic_method_call(
                                        constraint_type, op_name, [], None
                                    );
                                    if not result {
                                        self.emit_diag(
                                            E1010,
                                            expr,
                                            op=op_name,
                                            type=str(constraint_type)
                                        );
                                    }
                                }
                            }
                            return UnknownType();
                        }
                        if operand_type.bound
                            and isinstance(operand_type.bound, ClassType) {
                            result = self.get_type_of_magic_method_call(
                                operand_type.bound, op_name, [], None
                            );
                            if result {
                                return result;
                            }

                            self.emit_diag(
                                E1010, expr, op=op_name, type=str(operand_type.bound)
                            );
                            return UnknownType();
                        }

                        self.emit_diag(E1010, expr, op=op_name, type=operand_type.name);
                        return UnknownType();
                    }
                    if isinstance(operand_type, UnknownType)
                        and not operand_type.is_diagnosed
                        and not operand_type.is_incomplete {
                        self.emit_diag(E1010, expr, op=op_name, type=str(operand_type));
                        return UnknownType(is_diagnosed=True);
                    }
                    if expr.op.name == Tok.MINUS and is_unsigned_type(operand_type) {
                        self.emit_diag(E1129, expr, type=str(operand_type));
                        return UnknownType(is_diagnosed=True);
                    }
                    return operand_type;
                }
            }

        case FilterCompr():
            if expr.f_type {
                filter_type = self.get_type_of_expression(expr.f_type);
                if isinstance(filter_type, ClassType) {
                    for cmp in expr.compares {
                        self._bind_filter_compare(cmp, filter_type);
                        self.get_type_of_expression(cmp);
                    }

                    if self.prefetch and self.prefetch.list_class {
                        list_type = self.prefetch.list_class.clone_as_instance();
                        filter_inst = self._convert_to_instance(filter_type);
                        list_type.private.type_args = [filter_inst];
                        return list_type;
                    }
                }
            }

        case Name() | SpecialVarRef():
            if isinstance(expr, SpecialVarRef) {
                if expr.name == Tok.KW_ROOT {
                    return self._get_type_of_root(expr);
                }

                if expr.name in (Tok.KW_HERE, Tok.KW_VISITOR) {
                    if (method := self._get_enclosing_method(expr)) {
                        if isinstance(method.signature, EventSignature) {
                            if arch := method.signature.arch_tag_info {
                                if isinstance(arch, TupleVal) {
                                    member_insts: list[TypeBase] = [];
                                    for member in self._annotation_args(arch) {
                                        member_insts.append(
                                            self._convert_to_instance(
                                                self.get_type_of_expression(member)
                                            )
                                        );
                                    }
                                    if len(member_insts) == 1 {
                                        return member_insts[0];
                                    }
                                    if member_insts {
                                        return UnionType(types=member_insts);
                                    }
                                }
                                type_arch_cls = self.get_type_of_expression(arch);
                                type_arch_inst = self._convert_to_instance(
                                    type_arch_cls
                                );
                                if isinstance(type_arch_cls, ClassType) {
                                    class_symbol = type_arch_cls.get_class_symbol();
                                    if class_symbol is not None {
                                        self._set_symbol_to_expr(expr, class_symbol);
                                    }
                                }
                                return type_arch_inst;
                            } else {
                                cls_: Archetype | None = self._get_enclosing_class(
                                    expr
                                );
                                if cls_ {
                                    peer_class: ClassType | None = None;
                                    if cls_.sym_category == SymbolType.WALKER_ARCH {
                                        peer_class = self.prefetch.node_class;
                                    } elif cls_.sym_category == SymbolType.NODE_ARCH {
                                        peer_class = self.prefetch.walker_class;
                                    }
                                    if peer_class is not None {
                                        peer_symbol = peer_class.get_class_symbol();
                                        if peer_symbol is not None {
                                            self._set_symbol_to_expr(expr, peer_symbol);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if self._is_expr_self(expr) {
                return self._get_type_of_self(expr);
            }

            if self._is_expr_super(expr) {
                return self._get_type_of_super(expr);
            }

            if scope := self._resolution_scope_for(expr) {
                symbol = lookup_symtab(scope, expr.value, self.builtins_module);

                if symbol is not None
                    and symbol.decl is not None
                    and isinstance(symbol.decl.name_of, HasVar) {
                    field = symbol.decl.name_of;
                    if field.type_tag is not None
                        and expr.find_parent_of_type(SubTag) is field.type_tag {
                        owner = field.find_parent_of_type(Archetype);
                        if owner is not None
                            and owner.sym_tab.parent_scope is not None {
                            symbol = lookup_symtab(
                                owner.sym_tab.parent_scope,
                                expr.value,
                                self.builtins_module
                            );
                        }
                    }
                }

                if (
                    symbol is not None
                    and symbol.decl is not None
                    and isinstance(symbol.decl.name_of, ParamVar)
                    and expr.find_parent_of_type(FuncSignature) is not None
                    and expr.find_parent_of_type(FuncSignature)
                        is symbol.decl.name_of.find_parent_of_type(FuncSignature)
                ) {
                    _ann_fn = symbol.decl.name_of.find_parent_of_type(Ability);
                    _use_fn = expr.find_parent_of_type(Ability);
                    if (
                        _ann_fn is not None
                        and _use_fn is not None
                        and _ann_fn is _use_fn
                        and _use_fn.sym_tab is not None
                        and _use_fn.sym_tab.parent_scope is not None
                    ) {
                        symbol = lookup_symtab(
                            _use_fn.sym_tab.parent_scope,
                            expr.value,
                            self.builtins_module
                        );
                    }
                }

                if self._in_native_context()
                    and (symbol is None or symbol.parent_tab is self.builtins_module) {
                    na_sym = self.na_builtins_module.names_in_scope.get(expr.value);
                    if na_sym is not None {
                        symbol = na_sym;
                    }
                }

                if symbol is None and expr.value == "Self" {
                    import from jaclang.compiler.types.type_utils {
                        synthesize_self_type_var
                    }
                    if expr.find_parent_of_type(Archetype) is not None {
                        expr.type = synthesize_self_type_var();
                        return expr.type;
                    }
                }

                if symbol is None or symbol.parent_tab is self.builtins_module {
                    _js_name = expr.value;
                    if _js_name == "import" {
                        _js_name = "__import_meta__";
                    }
                    js_sym = self.js_globals_module.names_in_scope.get(_js_name);
                    if js_sym is not None and expr.in_client_context() {
                        symbol = js_sym;
                    }
                }
                if symbol {
                    symbol = self.resolve_imported_symbols(symbol);
                    symbol.add_use(expr);

                    if expr.sym is None {
                        expr.sym = symbol;

                        if symbol.decl and symbol.decl.name_of {
                            expr.name_of = symbol.decl.name_of;
                        }
                    }

                    symbol_type = self.get_type_of_symbol(symbol);

                    if special_form
                        := self._get_special_form_type(symbol.sym_name, symbol_type) {
                        if isinstance(special_form, TypeVarType) {
                            return special_form;
                        }
                        symbol_type = special_form;
                    }

                    if isinstance(expr, Name) {
                        if lhs_type := self._get_type_of_lhs_assignment(expr) {
                            return self._convert_to_instance(lhs_type);
                        }
                    }

                    if narrowed := self.get_narrowed_type(symbol, expr) {
                        symbol_type = narrowed;
                    }
                    if isinstance(symbol_type, FunctionType) {
                        overloaded_ty: OverloadedType | None = None;
                        overloaded_fns: list[FunctionType] = [symbol_type];

                        def_sym = self.resolve_to_definition_symbol(symbol);
                        symbol_scope: UniScopeNode | None = def_sym.parent_tab;
                        if symbol_scope is None and def_sym.decl {
                            symbol_scope = def_sym.decl.find_parent_of_type(
                                UniScopeNode
                            );
                        }
                        if symbol_scope {
                            all_syms = collect_member_syms(
                                symbol_scope, def_sym.sym_name
                            );
                            for overload_symbol in all_syms {
                                if overload_symbol == def_sym {
                                    continue;
                                }
                                overload_type = self.get_type_of_symbol(
                                    overload_symbol
                                );
                                if isinstance(overload_type, FunctionType) {
                                    overloaded_fns.append(overload_type);
                                }
                            }
                        }
                        if len(overloaded_fns) > 1 {
                            overloaded_ty = OverloadedType(overloads=overloaded_fns);
                        }
                        return overloaded_ty or symbol_type;
                    }
                    return symbol_type;
                }
            }

        case AwaitExpr():
            return self.get_type_of_expression(expr.target);

        case ConcurrentExpr():
            return self.get_type_of_expression(expr.target);

        case YieldExpr():
            if expr.expr is not None {
                return self.get_type_of_expression(expr.expr);
            }
            return UnknownType();

        case EdgeRefTrailer():
            if self.prefetch and self.prefetch.list_class {
                element_type: TypeBase = AnyType();
                for chain_item in expr.chain {
                    if isinstance(chain_item, FilterCompr) and chain_item.f_type {
                        ft = self.get_type_of_expression(chain_item.f_type);
                        if isinstance(ft, ClassType) {
                            element_type = self._convert_to_instance(ft);
                        }
                    } elif (
                        isinstance(chain_item, EdgeOpRef)
                        and expr.edges_only
                        and chain_item.filter_cond is not None
                        and chain_item.filter_cond.f_type is not None
                    ) {
                        ft = self.get_type_of_expression(chain_item.filter_cond.f_type);
                        if isinstance(ft, ClassType) and ft.is_edge_type() {
                            element_type = self._convert_to_instance(ft);
                        }
                    } elif (
                        isinstance(chain_item, EdgeOpRef)
                        and not expr.edges_only
                        and chain_item.filter_cond is not None
                        and chain_item.filter_cond.f_type is not None
                    ) {
                        ft = self.get_type_of_expression(chain_item.filter_cond.f_type);
                        if isinstance(ft, ClassType) and ft.is_edge_type() {
                            ep = self._edge_endpoint_type(ft, chain_item.edge_dir);
                            if ep is not None {
                                element_type = self._convert_to_instance(ep);
                            }
                        }
                    }
                }
                list_type = self.prefetch.list_class.clone_as_instance();
                list_type.private.type_args = [element_type];
                return list_type;
            }
            return UnknownType();

    }

    return UnknownType();
}

impl TypeEvaluator._bind_filter_compare(cmp: Expr, filter_type: ClassType) -> None {
    if not isinstance(cmp, CompareExpr) {
        term = self._filter_order_name(cmp);
        if term is not None {
            self._bind_filter_member(term, filter_type);
            return;
        }
        self.emit_diag(E5094, cmp, reason="not a comparison or an ordering term");
        return;
    }
    if len(cmp.ops) != 1 {
        self.emit_diag(E5094, cmp, reason="chained comparisons are not admitted");
        return;
    }
    left = cmp.left;
    if isinstance(left, TupleVal) {
        parts = list(left.values);
        if not parts {
            self.emit_diag(
                E5094, left, reason="a composite key needs at least one field name"
            );
            return;
        }
        for part in parts {
            if not isinstance(part, Name) {
                self.emit_diag(
                    E5094,
                    part,
                    reason="a composite key must be a tuple of declared field names"
                );
                return;
            }
        }
        for part in parts {
            if isinstance(part, Name) {
                self._bind_filter_member(part, filter_type);
            }
        }
        arity = len(parts);
        right = cmp.rights[0] if cmp.rights else None;
        if (not isinstance(right, TupleVal)) or len(right.values) != arity {
            self.emit_diag(
                E5094,
                cmp,
                reason=f"a composite key of arity {arity} needs a tuple value of the same arity"
            );
        }
        return;
    }
    if not isinstance(left, Name) {
        self.emit_diag(E5094, left, reason="left side must be a declared field name");
        return;
    }
    self._bind_filter_member(left, filter_type);
}

impl TypeEvaluator._filter_order_name(expr: Expr) -> (Name | None) {
    inner = expr;
    if isinstance(inner, UnaryExpr) {
        if inner.op.name != Tok.MINUS {
            return None;
        }
        inner = inner.operand;
    }
    return inner if isinstance(inner, Name) else None;
}

impl TypeEvaluator._bind_filter_member(target: Name, filter_type: ClassType) -> None {
    if sym := filter_type.lookup_member_symbol(target.value) {
        self._set_symbol_to_expr(target, sym);
        return;
    }
    self.emit_diag(E1033, target, member=target.value, type=str(filter_type));
}

impl TypeEvaluator._widen_literal_for_declaration(ty: TypeBase) -> TypeBase {
    if isinstance(ty, ClassType) {
        if ty.is_literal_type() {
            return ty.clone_with_literal(None);
        }
        if ty.is_builtin("LiteralString")
            and self.prefetch is not None
            and self.prefetch.str_class is not None {
            return self._convert_to_instance(self.prefetch.str_class);
        }
        if ty.private.type_args {
            widened_args = [
                self._widen_literal_for_declaration(arg) for arg in ty.private.type_args
            ];
            changed = any(
                new_arg is not old_arg
                for (new_arg, old_arg) in zip(widened_args, ty.private.type_args)
            );
            if changed {
                return ty.specialize_generics(widened_args);
            }
        }
        return ty;
    }
    if isinstance(ty, UnionType) and ty.types is not None {
        widened = [self._widen_literal_for_declaration(member) for member in ty.types];
        return UnionType(types=widened);
    }
    return ty;
}

impl TypeEvaluator._get_type_of_symbol(symbol: Symbol) -> TypeBase {
    if len(symbol.defn) > 1 {
        has_import = False;
        for cand in symbol.defn {
            if cand.name_of.find_parent_of_type(Import) is not None {
                has_import = True;
                break;
            }
        }
        if has_import {
            binding_types: list[TypeBase] = [];
            for cand in symbol.defn {
                cand_type = self._get_type_of_symbol_decl(symbol, cand);
                if isinstance(cand_type, UnknownType) {
                    continue;
                }
                if not self._type_in_list(cand_type, binding_types) {
                    binding_types.append(cand_type);
                }
            }
            has_none = False;
            has_value = False;
            for bt in binding_types {
                if self.is_none_type(bt) {
                    has_none = True;
                } else {
                    has_value = True;
                }
            }
            if len(binding_types) > 1 and has_none and has_value {
                return UnionType(types=binding_types);
            }
        }
    }
    return self._get_type_of_symbol_decl(symbol, symbol.decl);
}

impl TypeEvaluator._get_type_of_symbol_decl(
    symbol: Symbol, decl: NameAtom
) -> TypeBase {
    node_ = decl.name_of;
    match node_ {
        case Enum():
            return self.get_type_of_enum(node_);

        case Archetype():
            return self.get_type_of_class(node_);

        case TypeParam():
            if node_.is_comptime {
                if node_.bound is not None {
                    return self._convert_to_instance(
                        self.get_type_of_expression(node_.bound)
                    );
                }
                return UnknownType();
            }
            return self._type_var_from_param(node_);

        case TypeAlias():
            if node_.value is not None {
                resolved = self._resolve_type_alias_rhs(node_.value);
                if node_.is_distinct {
                    return self._brand_distinct_alias(node_, resolved);
                }
                return resolved;
            }
            return UnknownType();

        case Ability():
            return self.get_type_of_ability(node_);

        case ParamVar():
            if node_.type_tag {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                if node_.is_vararg {
                    if self.prefetch.list_class is None {
                        return UnknownType();
                    }
                    param_type = self.prefetch.list_class.clone_as_instance();
                    param_type.private.type_args = [annotation_type];
                    return param_type;
                } elif node_.is_kwargs {
                    if self.prefetch.dict_class is None
                        or self.prefetch.str_class is None {
                        return UnknownType();
                    }
                    param_type = self.prefetch.dict_class.clone_as_instance();
                    param_type.private.type_args = [
                        self.prefetch.str_class,
                        annotation_type
                    ];
                    return param_type;
                }
                return self._convert_to_instance(annotation_type);
            }

            if node_.name.type is not None {
                return node_.name.type;
            }

        case Name():
            if node_.type is not None {
                return node_.type;
            }

            if enum_member_type := self._get_enum_member_type_for_decl(node_) {
                return enum_member_type;
            }

            if (
                isinstance(node_.parent, UnaryExpr)
                and isinstance(node_.parent.op, Token)
                and node_.parent.op.name == Tok.STAR_MUL
                and isinstance(node_.parent.parent, (TupleVal, ListVal))
            ) {
                star_container = node_.parent.parent;
                while isinstance(star_container.parent, (TupleVal, ListVal)) {
                    star_container = star_container.parent;
                }
                star_assignment = star_container.parent;
                if (
                    isinstance(star_assignment, Assignment)
                    and star_assignment.value is not None
                ) {
                    rhs_type = self.get_type_of_expression(star_assignment.value);
                    if elem
                        := self._get_iterable_element_type(
                            rhs_type, star_assignment.value
                        ) {
                        if self.prefetch.list_class is None {
                            return UnknownType();
                        }
                        star_type = self.prefetch.list_class.clone_as_instance();
                        star_type.private.type_args = [elem];
                        return star_type;
                    }
                }
            }

            if isinstance(node_.parent, (TupleVal, ListVal)) {
                unpack_container = node_.parent;
                while isinstance(unpack_container.parent, (TupleVal, ListVal)) {
                    unpack_container = unpack_container.parent;
                }
                unpack_assignment = unpack_container.parent;
                if (
                    isinstance(unpack_assignment, Assignment)
                    and unpack_assignment.value is not None
                ) {
                    idx = -1;
                    for (vi, v) in enumerate(unpack_container.values) {
                        if v is node_ {
                            idx = vi;
                            break;
                        }
                    }
                    if idx >= 0 {
                        rhs_type = self.get_type_of_expression(unpack_assignment.value);
                        extracted = self._extract_tuple_element_type(rhs_type, idx);
                        if (
                            extracted is not None
                            and not isinstance(extracted, UnknownType)
                        ) {
                            return extracted;
                        }

                        if elem
                            := self._get_iterable_element_type(
                                rhs_type, unpack_assignment.value
                            ) {
                            return elem;
                        }
                        if extracted is not None {
                            return extracted;
                        }
                    }
                } elif isinstance(unpack_assignment, (InForStmt, InnerCompr)) {
                    collection_type = self.get_type_of_expression(
                        unpack_assignment.collection
                    );
                    elem_type = self._get_iterable_element_type(
                        collection_type,
                        unpack_assignment,
                        is_async=unpack_assignment.is_async
                    );
                    if elem_type is not None {
                        unpack_path: list[int] = [];
                        path_cur: UniNode = node_;
                        path_parent = path_cur.parent;
                        path_ok = True;
                        while path_parent is not None {
                            if not isinstance(path_parent, (TupleVal, ListVal)) {
                                path_ok = False;
                                break;
                            }
                            found = -1;
                            for (vi, v) in enumerate(path_parent.values) {
                                if v is path_cur {
                                    found = vi;
                                    break;
                                }
                            }
                            if found < 0 {
                                path_ok = False;
                                break;
                            }
                            unpack_path.insert(0, found);
                            if path_parent is unpack_container {
                                break;
                            }
                            path_cur = path_parent;
                            path_parent = path_cur.parent;
                        }
                        if path_ok and unpack_path {
                            if elem
                                := self._extract_tuple_element_type_path(
                                    elem_type, unpack_path
                                ) {
                                return elem;
                            }
                        }
                    }
                }
            }

            if isinstance(node_.parent, Assignment) {
                if node_.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.type_tag.tag
                    );

                    if (
                        self._is_type_alias_annotation(
                            annotation_type, node_.parent.type_tag.tag
                        )
                        and node_.parent.value is not None
                    ) {
                        return self._resolve_type_alias_rhs(node_.parent.value);
                    }
                    declared_inst = self._convert_to_instance(annotation_type);

                    if (
                        isinstance(declared_inst, ClassType)
                        and self.prefetch.final_class is not None
                        and declared_inst.shared.same_class(
                            self.prefetch.final_class.shared
                        )
                    ) {
                        final_args = declared_inst.private.type_args;
                        if final_args {
                            return self._convert_to_instance(final_args[0]);
                        }
                        if node_.parent.value is not None {
                            return self.get_type_of_expression(node_.parent.value);
                        }
                    }

                    if (
                        isinstance(declared_inst, ClassType)
                        and declared_inst.is_builtin("list")
                        and not declared_inst.private.type_args
                        and isinstance(node_.parent.value, ListVal)
                        and not node_.parent.value.values
                    ) {
                        value_type = self.get_type_of_expression(
                            node_.parent.value, expected_type=declared_inst
                        );
                        if (
                            isinstance(value_type, ClassType)
                            and value_type.is_builtin("list")
                            and value_type.private.type_args
                        ) {
                            return value_type;
                        }
                    }
                    return declared_inst;
                } else {
                    if node_.parent.value is not None {
                        return self._widen_literal_for_declaration(
                            self.get_type_of_expression(node_.parent.value)
                        );
                    }
                }
            }

            if (
                isinstance(node_.parent, AtomTrailer)
                and node_.parent.parent
                and isinstance(node_.parent.parent, Assignment)
            ) {
                if node_.parent.parent.type_tag is not None {
                    annotation_type = self.get_type_of_expression(
                        node_.parent.parent.type_tag.tag
                    );
                    return self._convert_to_instance(annotation_type);
                } else {
                    if node_.parent.parent.value is not None {
                        return self._widen_literal_for_declaration(
                            self.get_type_of_expression(node_.parent.parent.value)
                        );
                    }
                }
            }

            if (
                isinstance(node_.parent, BinaryExpr)
                and isinstance(node_.parent.op, Token)
                and node_.parent.op.name == "WALRUS_EQ"
                and node_.parent.left is node_
            ) {
                return self.get_type_of_expression(node_.parent.right);
            }

            if isinstance(node_.parent, (InForStmt, InnerCompr)) {
                collection_type = self.get_type_of_expression(node_.parent.collection);

                if self.is_any_type(collection_type)
                    and self.prefetch.any_class is not None {
                    node_.type = self.prefetch.any_class;
                    return self.prefetch.any_class;
                }

                if isinstance(collection_type, AnyType) {
                    elem_any = AnyType(is_foreign=collection_type.is_foreign);
                    node_.type = elem_any;
                    return elem_any;
                }
                if isinstance(collection_type, UnknownType) {
                    elem_unknown = UnknownType(
                        is_diagnosed=collection_type.is_diagnosed,
                        is_incomplete=collection_type.is_incomplete
                    );
                    node_.type = elem_unknown;
                    return elem_unknown;
                }

                if isinstance(collection_type, ClassType)
                    and collection_type.is_instantiable_class()
                    and collection_type.is_enum_class() {
                    instance_type = collection_type.clone_as_instance();
                    node_.type = instance_type;
                    return instance_type;
                }

                element_type = self._get_iterable_element_type(
                    collection_type, node_.parent, is_async=node_.parent.is_async
                );
                if element_type is not None {
                    node_.type = element_type;
                    return element_type;
                }
                return UnknownType();
            }

            if isinstance(node_.parent, Except) and node_.parent.ex_type {
                ex_type = self.get_type_of_expression(node_.parent.ex_type);
                return self._convert_to_instance(ex_type);
            }

            if isinstance(node_.parent, ModulePath) {
                mod_path_type = self.get_type_of_module(node_.parent);
                return node_.type or mod_path_type;
            }
            if isinstance(node_.parent, ModuleItem) {
                return self.get_type_of_module_item(node_.parent);
            }

        case HasVar():
            if node_.type_tag is not None {
                annotation_type = self.get_type_of_expression(node_.type_tag.tag);
                return self._convert_to_instance(annotation_type);
            } else {
                if node_.value is not None {
                    return self.get_type_of_expression(node_.value);
                }
            }

    }

    return UnknownType();
}

impl TypeEvaluator._get_enum_member_type_for_decl(
    node_: Name
) -> (EnumMemberType | None) {
    assignment = node_.parent;
    if not isinstance(assignment, Assignment) or not assignment.is_enum_stmt {
        return None;
    }

    if node_ not in assignment.target {
        return None;
    }
    container = assignment.parent;
    enum_node: Enum | None = None;
    if isinstance(container, Enum) {
        enum_node = container;
    } elif isinstance(container, ImplDef) and isinstance(container.decl_link, Enum) {
        enum_node = container.decl_link;
    }
    if enum_node is None {
        return None;
    }
    enum_type = self.get_type_of_enum(enum_node);
    member_info = enum_type.shared.enum_members.get(node_.sym_name)
        if enum_type.shared.enum_members
        else None;
    if member_info is None {
        return None;
    }
    return EnumMemberType(enum_class=enum_type, member_info=member_info);
}

impl TypeEvaluator.get_type_of_magic_method_call(
    obj_type: TypeBase,
    method_name: str,
    arg_nodes: (Sequence[Expr | KWPair] | None),
    node_for_error: UniNode | None = None,
) -> TypeBase | None {
    if isinstance(obj_type, UnionType) {
        result_types: list[TypeBase] = [];
        for member_type in obj_type.types {
            result = self.get_type_of_magic_method_call(
                member_type, method_name, arg_nodes, node_for_error
            );
            if result is not None and not self._type_in_list(result, result_types) {
                result_types.append(result);
            }
        }
        if len(result_types) == 1 {
            return result_types[0];
        } elif len(result_types) > 1 {
            return UnionType(types=result_types);
        }
        return None;
    }
    if obj_type.category == TypeCategory.Class {
        assert isinstance(obj_type, ClassType);
        owner_type = obj_type;
        if obj_type.is_instantiable_class() {
            meta_owner = self._metaclass_of(obj_type);
            if meta_owner is not None {
                meta_member = self._lookup_class_member(meta_owner, method_name);
                if (
                    meta_member is not None
                    and meta_member.class_type.shared.class_name
                        not in ("type", "object")
                ) {
                    owner_type = meta_owner;
                }
            }
        }
        if member := self._lookup_class_member(owner_type, method_name) {
            member_ty = self.get_type_of_symbol(member.symbol);

            overloaded_fns: list[FunctionType] = [];
            if isinstance(member_ty, FunctionType) {
                member_ty = member_ty.specialize(obj_type);
                overloaded_fns.append(member_ty);
                for overload in member.overloads {
                    overload_member_ty = self.get_type_of_symbol(overload);
                    if isinstance(overload_member_ty, FunctionType) {
                        overload_member_ty = overload_member_ty.specialize(obj_type);
                        overloaded_fns.append(overload_member_ty);
                    }
                }

                _fallback_result: TypeBase | None = None;
                for fn in overloaded_fns {
                    if not self._overload_accepts_receiver(fn, obj_type) {
                        continue;
                    }
                    arg_param_match = self.match_args_to_params(
                        arg_nodes, node_for_error, fn, checking_overload=True
                    );
                    if not arg_param_match.argument_errors {
                        solved = self._receiver_type_var_bindings(fn, obj_type);
                        if self.validate_arg_types(
                            arg_param_match,
                            checking_overload=True,
                            solved_type_vars=solved
                        ) {
                            ret_ty = fn.return_type;
                            if solved and ret_ty is not None {
                                ret_ty = apply_solved_type_vars(ret_ty, solved);
                            }
                            if not isinstance(ret_ty, UnknownType) {
                                return ret_ty or UnknownType();
                            }
                            if _fallback_result is None {
                                _fallback_result = ret_ty;
                            }
                        }
                    }
                }
                if _fallback_result is not None {
                    return _fallback_result;
                }

                return None;
            }

            return None;
        }
    }
    return None;
}

impl TypeEvaluator.get_type_of_expression(
    node_: Expr, expected_type: TypeBase | None = None
) -> TypeBase {
    if node_ is None {
        return UnknownType();
    }

    if isinstance(node_, Ability) {
        return self.get_type_of_ability(node_);
    }

    if node_.type is not None {
        contextual_call = False;
        if expected_type is not None
            and isinstance(node_, FuncCall)
            and not node_.params {
            constructor = node_.target.type;
            contextual_call = isinstance(constructor, ClassType)
                and constructor.is_instantiable_class()
                and constructor.is_builtin(["list", "set", "frozenset", "dict"]);
        }
        if expected_type is None
            or (
                not contextual_call
                and not isinstance(
                    node_, (ListVal, DictVal, SetVal, TupleVal, ListCompr, LambdaExpr, )
                )
            ) {
            if isinstance(node_.type, (UnionType, ClassType, FunctionType)) {
                if narrowed
                    := self.get_narrowed_type_for_expr(node_, node_.type, node_) {
                    node_.narrowed_type = narrowed;
                    return narrowed;
                }
            }
            return node_.type;
        }
    }
    result = self._get_type_of_expression_core(node_, expected_type);
    if isinstance(result, UnknownType) and result.is_incomplete {
        return result;
    }
    if isinstance(result, UnknownType) {
        mod = node_.find_parent_of_type(Module);
        is_pattern_wildcard = (
            isinstance(node_, Name)
            and node_.value == '_'
            and node_.find_parent_of_type(MatchPattern) is not None
        );
        is_annotation_ellipsis = isinstance(node_, Ellipsis)
            and (
                node_.find_parent_of_type(SubTag) is not None
                or node_.find_parent_of_type(FuncSignature) is not None
            );
        if (mod is None or not mod.is_raised_from_py)
            and not is_pattern_wildcard
            and not is_annotation_ellipsis {
            self.emit_diag(W1051, node_);
        }
    }
    node_.type = result;
    if node_.ct_value is None {
        node_.ct_value = self.ct_eval.try_eval(node_);
    }

    if isinstance(result, (UnionType, ClassType, FunctionType)) {
        if narrowed := self.get_narrowed_type_for_expr(node_, result, node_) {
            node_.narrowed_type = narrowed;
            return narrowed;
        }
    }
    return result;
}

impl TypeEvaluator.eval_expr with Expr entry {
    self.get_type_of_expression(here);
}
