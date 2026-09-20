impl TypeEvaluator._merge_catalog_field_params(
    tab: CatScope, param_map: dict[str, Parameter], skip_deferred: bool
) -> None {
    import from jaclang.compiler.frontend.constant { SymbolType }
    import from jaclang.compiler.types.stubcat.format { SYMF_DEFER, SYMF_HAS_DEFAULT }
    import from jaclang.compiler.types.stubcat.reader { CatProvider }
    names = tab.names_in_scope.copy();
    for (name, sym) in names.items() {
        if sym.sym_type != SymbolType.HAS_VAR {
            continue;
        }
        prov = sym.provider;
        bits = prov.symbits if isinstance(prov, CatProvider) else 0;
        if skip_deferred and (bits & SYMF_DEFER) != 0 {
            param_map.pop(name, None);
            continue;
        }
        if prov is not None and prov.property_kind() != 0 {
            continue;
        }
        param_type = self.get_type_of_symbol(sym);
        param_map[name] = Parameter(
            name=name,
            category=ParameterCategory.Positional,
            param_type=param_type,
            default_value=None,
            is_self=False,
            param_kind=ParamKind.NORMAL,
            has_default=(bits & SYMF_HAS_DEFAULT) != 0
        );
    }
}

impl TypeEvaluator._build_field_params(
    class_type: ClassType, skip_deferred: bool = True
) -> dict[str, Parameter] {
    import from jaclang.compiler.field_semantics { field_initialization }
    import from jaclang.compiler.types.stubcat.reader { CatScope }
    param_map: dict[str, Parameter] = {};
    for cls in class_type.shared.mro[::-1] {
        cat_tab = cls.shared.symbol_table;
        if isinstance(cat_tab, CatScope) {
            self._merge_catalog_field_params(cat_tab, param_map, skip_deferred);
            continue;
        }
        scope = cls.shared.symbol_table;
        if not isinstance(scope, Archetype) {
            continue;
        }
        for has_var in scope.get_has_vars() {
            if skip_deferred and has_var.defer {
                param_map.pop(has_var.name.value, None);
                continue;
            }

            if has_var.accessors {
                continue;
            }
            param_type: TypeBase | None = None;
            if has_var.type_tag {
                var_type_expr = has_var.type_tag.tag;
                type_cls = self.get_type_of_expression(var_type_expr);
                param_type = self._convert_to_instance(type_cls);
            }
            initialization = field_initialization(has_var);
            if skip_deferred and not initialization.participates_in_init {
                param_map.pop(has_var.name.value, None);
                continue;
            }
            default_value = initialization.default_expr;
            if default_value is None {
                default_value = initialization.factory_expr;
            }
            param_kind = ParamKind.KWONLY
                if initialization.keyword_only
                else ParamKind.NORMAL;
            param_map[has_var.name.value] = Parameter(
                name=has_var.name.value,
                category=ParameterCategory.Positional,
                param_type=param_type,
                default_value=default_value,
                is_self=False,
                param_kind=param_kind,
            );
        }
    }
    seen_default = False;
    for parameter in param_map.values() {
        if parameter.param_kind == ParamKind.KWONLY {
            continue;
        }
        if parameter.default_value is not None {
            seen_default = True;
        } elif seen_default {
            parameter.param_kind = ParamKind.KWONLY;
        }
    }
    return param_map;
}

impl TypeEvaluator._build_typeddict_fields(
    class_type: ClassType
) -> dict[str, TypeBase] {
    fields: dict[str, TypeBase] = {};
    for cls in class_type.shared.mro[::-1] {
        if cls.shared.class_name == "TypedDict" {
            continue;
        }
        scope = cls.shared.symbol_table;
        if not isinstance(scope, Archetype) {
            continue;
        }
        for has_var in scope.get_has_vars() {
            if has_var.accessors {
                continue;
            }
            field_type: TypeBase = UnknownType();
            if has_var.type_tag {
                field_type = self._convert_to_instance(
                    self.get_type_of_expression(has_var.type_tag.tag)
                );
            }
            fields[has_var.name.value] = field_type;
        }
    }
    return fields;
}

impl TypeEvaluator._has_typeddict_special_form_base(node_: Archetype) -> bool {
    for base_expr in node_.base_classes or [] {
        base_name: str | None = None;
        if isinstance(base_expr, Name) {
            base_name = base_expr.value;
        } elif (
            isinstance(base_expr, AtomTrailer) and isinstance(base_expr.right, Name)
        ) {
            base_name = base_expr.right.value;
        }
        if base_name == "TypedDict" {
            base_t = self.get_type_of_expression(base_expr);
            if (
                isinstance(base_t, ClassType)
                and base_t.shared.class_name == "_SpecialForm"
            ) {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._typeddict_value_union(base_type: ClassType) -> TypeBase {
    field_types = list((base_type.shared.typeddict_fields or {}).values());
    if not field_types {
        return UnknownType();
    }
    if len(field_types) == 1 {
        return field_types[0];
    }
    return UnionType(types=field_types);
}

impl TypeEvaluator._get_typeddict_indexed_type(
    base_type: ClassType, key_expr: Expr, err_node: UniNode
) -> TypeBase | None {
    key_type = self.get_type_of_expression(key_expr);
    if not (isinstance(key_type, ClassType) and key_type.is_builtin("str")) {
        return None;
    }
    fields: dict[str, TypeBase] = base_type.shared.typeddict_fields or {};
    lit = key_type.get_literal_value();
    if not isinstance(lit, str) {
        return self._typeddict_value_union(base_type);
    }
    if lit in fields {
        return fields[lit];
    }
    self.emit_diag(E1043, err_node, type=base_type.shared.class_name, key=lit);
    return UnknownType();
}

impl TypeEvaluator._synthesize_typeddict_method(
    base_type: ClassType, method: str
) -> OverloadedType | None {
    if not (self.prefetch and self.prefetch.str_class) {
        return None;
    }
    none_inst: TypeBase = UnknownType();
    if self.prefetch.none_type_class {
        none_inst = self._convert_to_instance(self.prefetch.none_type_class);
    }
    object_inst: TypeBase = UnknownType();
    if self.prefetch.object_class {
        object_inst = self._convert_to_instance(self.prefetch.object_class);
    }

    def param(name: str, ty: TypeBase, is_self: bool = False) -> Parameter {
        return Parameter(
            name=name,
            category=ParameterCategory.Positional,
            param_type=ty,
            is_self=is_self,
            param_kind=ParamKind.NORMAL if is_self else ParamKind.POSONLY,
        );
    }

    def func(params: list[Parameter], ret: TypeBase) -> FunctionType {
        return FunctionType(
            func_name=method,
            return_type=ret,
            parameters=params,
            function_flags=FunctionTypeFlags.SynthesizedMethod,
        );
    }

    self_p = param("self", base_type, is_self=True);
    default_p = param("default", object_inst);

    def overloads_for(key_ty: TypeBase, value: TypeBase) -> list[FunctionType] {
        key_p = param("key", key_ty);
        with_default = func([self_p, key_p, default_p], value);
        if method == "setdefault" {
            return [with_default];
        }
        return [
            func([self_p, key_p], UnionType(types=[value, none_inst])),
            with_default
        ];
    }

    overloads: list[FunctionType] = [];
    for (field_name, field_type) in (base_type.shared.typeddict_fields or {}).items() {
        key_lit = self._convert_to_instance(
            self.prefetch.str_class.clone_with_literal(field_name)
        );
        overloads.extend(overloads_for(key_lit, field_type));
    }
    str_inst = self._convert_to_instance(self.prefetch.str_class);
    overloads.extend(overloads_for(str_inst, self._typeddict_value_union(base_type)));
    return OverloadedType(overloads=overloads);
}

impl TypeEvaluator._typeddict_as_dict(base_type: ClassType) -> ClassType | None {
    if not (self.prefetch and self.prefetch.dict_class and self.prefetch.str_class) {
        return None;
    }
    str_inst = self._convert_to_instance(self.prefetch.str_class);
    dict_type = self.prefetch.dict_class.specialize_generics(
        [str_inst, self._typeddict_value_union(base_type)]
    );
    return dict_type.clone_as_instance();
}

impl TypeEvaluator._scope_has_fields(tab: UniScopeNode | None) -> bool {
    import from jaclang.compiler.types.stubcat.reader { CatScope }
    import from jaclang.compiler.frontend.constant { SymbolType }
    if isinstance(tab, Archetype) {
        return bool(tab.get_has_vars());
    }
    if isinstance(tab, CatScope) {
        for sym in tab.names_in_scope.values() {
            if sym.sym_type == SymbolType.HAS_VAR {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._create_object_init_method(class_type: ClassType) -> FunctionType {
    param_map = self._build_field_params(class_type, skip_deferred=True);
    parameters = list(param_map.values());

    ret_type: TypeBase = UnknownType();
    if self.prefetch and self.prefetch.none_type_class {
        ret_type = self._convert_to_instance(self.prefetch.none_type_class);
    }
    return FunctionType(
        func_name="__init__",
        return_type=ret_type,
        parameters=parameters,
        function_flags=FunctionTypeFlags.SynthesizedMethod,
    );
}

impl TypeEvaluator._create_namedtuple_new_method(
    class_type: ClassType
) -> FunctionType {
    parameters: list[Parameter] = [];

    parameters.append(
        Parameter(
            name="cls",
            category=ParameterCategory.Positional,
            param_type=class_type,
            is_cls=True,
            param_kind=ParamKind.NORMAL,
        )
    );
    param_map = self._build_field_params(class_type, skip_deferred=False);
    parameters.extend(list(param_map.values()));
    return FunctionType(
        func_name="__new__",
        return_type=class_type.clone_as_instance(),
        parameters=parameters,
        function_flags=FunctionTypeFlags.SynthesizedMethod,
    );
}
