impl TypeEvaluator._lookup_object_member(
    base_type: TypeBase, member: str
) -> ClassMember | None {
    if isinstance(base_type, ClassType) and base_type.is_class_instance() {
        return self._lookup_class_member(base_type, member);
    }
    return None;
}

impl TypeEvaluator._lookup_class_member(
    base_type: ClassType, member: str
) -> ClassMember | None {
    import from jaclang.compiler.types.type_utils { ensure_mro_fresh }
    self._heal_ancestry(base_type);
    ensure_mro_fresh(base_type);
    for cls in base_type.shared.mro {
        overloaded_syms: list[Symbol] = [];
        if sym := cls.lookup_member_symbol(member, overloaded_syms) {
            return ClassMember(sym, cls, overloaded_syms);
        }
    }

    import keyword;
    if keyword.iskeyword(member) {
        for cls in base_type.shared.mro {
            escaped_syms: list[Symbol] = [];
            if sym := cls.lookup_member_symbol(member + "_", escaped_syms) {
                return ClassMember(sym, cls, escaped_syms);
            }
        }
    }
    return None;
}

impl TypeEvaluator._is_type_subscript(class_type: ClassType) -> bool {
    return (
        class_type.is_builtin("type")
        and class_type.private.type_args is not None
        and len(class_type.private.type_args) >= 1
    );
}

impl TypeEvaluator._get_type_for_member_lookup(object_type: ClassType) -> ClassType {
    if self._is_type_subscript(object_type) {
        inner_type = object_type.private.type_args[0];

        if isinstance(inner_type, ClassType) {
            lookup_type = inner_type;
            if not lookup_type.is_instantiable() {
                lookup_type = lookup_type.clone_as_class();
            }
            return lookup_type;
        }
    }
    return object_type;
}

impl TypeEvaluator.get_type_of_member(
    member: ClassMember, class_type: ClassType
) -> TypeBase {
    raw_type = self.get_type_of_symbol(member.symbol);
    if isinstance(raw_type, FunctionType) {
        params: list[Parameter] = raw_type.parameters or [];
        is_static_cls = (
            len(params) >= 1
            and params[0].is_cls
            and not (raw_type.function_flags & FunctionTypeFlags.ClassMethod)
        );
        is_static = bool(raw_type.function_flags & FunctionTypeFlags.StaticMethod);
        if is_static_cls or is_static {
            solution = build_type_var_solution(class_type);
            return apply_solved_type_vars(
                raw_type,
                solution,
                None,
                shadowed_type_var_names(
                    solution, self.declaring_class_of(member.symbol, class_type)
                )
            );
        }
    }
    return self.specialize_member_type(
        raw_type, class_type, self.declaring_class_of(member.symbol, class_type)
    );
}

impl TypeEvaluator.declaring_class_of(
    symbol: Symbol, base_type: ClassType
) -> (ClassType | None) {
    if symbol.decl is None {
        return None;
    }
    arch = symbol.decl.find_parent_of_type(Archetype);
    if arch is None {
        return None;
    }
    for cls in base_type.shared.mro {
        if cls.shared.symbol_table is arch {
            return cls;
        }
    }
    return None;
}

impl TypeEvaluator.specialize_member_type(
    member_type: TypeBase,
    class_type: ClassType,
    declaring_class: (ClassType | None) = None
) -> TypeBase {
    solution = build_type_var_solution(class_type);

    return apply_solved_type_vars(
        member_type,
        solution,
        class_type,
        shadowed_type_var_names(solution, declaring_class)
    );
}

impl TypeEvaluator._get_getattr_return_type(base_type: ClassType) -> TypeBase | None {
    if member := self._lookup_class_member(base_type, "__getattr__") {
        getattr_type = self.get_type_of_symbol(member.symbol);
        if isinstance(getattr_type, FunctionType) {
            return getattr_type.return_type or UnknownType();
        }
    }

    if member := self._lookup_class_member(base_type, "__getattribute__") {
        import from jaclang.compiler.types.type_utils { collect_member_syms }
        _ga_owned = False;
        for _ga_cls in base_type.shared.mro {
            if _ga_cls.shared.class_name == "object" {
                continue;
            }
            _ga_tbl = _ga_cls.shared.symbol_table;
            if _ga_tbl is not None
                and collect_member_syms(_ga_tbl, "__getattribute__") {
                _ga_owned = True;
                break;
            }
        }
        if _ga_owned {
            getattr_type = self.get_type_of_symbol(member.symbol);
            if isinstance(getattr_type, FunctionType) {
                return getattr_type.return_type or UnknownType();
            }
        }
    }
    return None;
}

impl TypeEvaluator._resolve_enum_value_type(enum_type: ClassType) -> TypeBase | None {
    val_type = enum_type.shared.enum_value_type;
    if val_type is None and enum_type.shared.enum_members {
        member_types = [
            m.value_type
            for m in enum_type.shared.enum_members.values()
            if m.value_type is not None
        ];
        if member_types
            and all(
                isinstance(t, ClassType)
                    and isinstance(member_types[0], ClassType)
                    and t.shared.same_class(member_types[0].shared)
                for t in member_types
            ) {
            val_type = member_types[0];
        }
    }
    return val_type;
}

impl TypeEvaluator._synthesize_enum_metaclass_attr(
    enum_type: ClassType, attr_name: str
) -> TypeBase | None {
    if not (
        self.prefetch
        and self.prefetch.dict_class
        and self.prefetch.list_class
        and self.prefetch.str_class
    ) {
        return None;
    }
    str_inst = self._convert_to_instance(self.prefetch.str_class);
    if attr_name == "_member_names_" {
        list_type = self.prefetch.list_class.specialize_generics([str_inst]);
        return self._convert_to_instance(list_type);
    }
    if attr_name == "__members__" {
        member_inst = enum_type.clone_as_instance();
        if self.prefetch.mappingproxy_class {
            proxy_type = self.prefetch.mappingproxy_class.specialize_generics(
                [str_inst, member_inst]
            );
            return self._convert_to_instance(proxy_type);
        }
        dict_type = self.prefetch.dict_class.specialize_generics(
            [str_inst, member_inst]
        );
        return self._convert_to_instance(dict_type);
    }
    if attr_name == "_member_map_" {
        member_inst = enum_type.clone_as_instance();
        dict_type = self.prefetch.dict_class.specialize_generics(
            [str_inst, member_inst]
        );
        return self._convert_to_instance(dict_type);
    }
    if attr_name == "_value2member_map_" {
        member_inst = enum_type.clone_as_instance();
        val_type = self._resolve_enum_value_type(enum_type);
        key_type = (
            self._convert_to_instance(val_type) if val_type is not None else AnyType()
        );
        dict_type = self.prefetch.dict_class.specialize_generics(
            [key_type, member_inst]
        );
        return self._convert_to_instance(dict_type);
    }
    return None;
}

impl TypeEvaluator._convert_to_instance(jtype: TypeBase) -> TypeBase {
    return convert_to_instance(jtype);
}

impl TypeEvaluator._metaclass_of(cls_type: ClassType) -> (ClassType | None) {
    import from jaclang.compiler.types.stubcat.reader { CatScope }
    for cls in cls_type.shared.mro {
        arch = cls.shared.symbol_table;
        if isinstance(arch, CatScope) {
            meta_type = arch.metaclass_type();
            if (
                isinstance(meta_type, ClassType)
                and meta_type.shared is not cls_type.shared
            ) {
                return meta_type;
            }
            continue;
        }
        if not isinstance(arch, Archetype) {
            continue;
        }
        for kid in arch.kid {
            if (
                isinstance(kid, KWPair)
                and kid.key is not None
                and kid.key.sym_name == "metaclass"
            ) {
                meta_type = self.get_type_of_expression(kid.value);
                if isinstance(meta_type, ClassType)
                    and meta_type.shared is not cls_type.shared {
                    return meta_type;
                }
            }
        }
    }
    return None;
}

impl TypeEvaluator._edge_endpoint_type(
    edge_type: ClassType, edge_dir: EdgeDir
) -> TypeBase | None {
    for cls in edge_type.shared.mro {
        arch = cls.shared.symbol_table;
        if not isinstance(arch, Archetype) {
            continue;
        }
        endpoint: Expr | None = None;
        if edge_dir == EdgeDir.OUT {
            endpoint = arch.tgt_endpoint;
        } elif edge_dir == EdgeDir.IN {
            endpoint = arch.src_endpoint;
        }
        if endpoint is not None {
            ep_type = self.get_type_of_expression(endpoint);
            if isinstance(ep_type, ClassType) {
                return ep_type;
            }
            return None;
        }
    }
    return None;
}

impl TypeEvaluator._is_ability_classmethod(node_: Ability) -> bool {
    if node_.decorators {
        for decorator in node_.decorators {
            decor_type = self.get_type_of_expression(decorator);
            if (
                isinstance(decor_type, ClassType)
                and self.prefetch.classmethod_class is not None
                and self.prefetch.classmethod_class.shared.same_class(decor_type.shared)
            ) {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._is_ability_staticmethod(node_: Ability) -> bool {
    if node_.is_static {
        return True;
    }
    if node_.decorators {
        for decorator in node_.decorators {
            decor_type = self.get_type_of_expression(decorator);
            if (
                isinstance(decor_type, ClassType)
                and decor_type.is_builtin("staticmethod")
            ) {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._classify_property_symbol(symbol: Symbol) -> PropertyWriteKind {
    import from jaclang.compiler.types.type_utils { PropertyWriteKind }
    if symbol.provider is not None {
        return PropertyWriteKind(symbol.provider.property_kind());
    }
    node_ = symbol.decl.name_of;

    if isinstance(node_, HasVar) and node_.accessors {
        for acc in node_.accessors {
            if acc.accessor_kind == "setter" {
                return PropertyWriteKind.WRITABLE;
            }
        }
        return PropertyWriteKind.READ_ONLY;
    }
    if not isinstance(node_, Ability) {
        return PropertyWriteKind.NOT_PROPERTY;
    }
    ability = node_;
    if not ability.decorators {
        return PropertyWriteKind.NOT_PROPERTY;
    }
    for decorator in ability.decorators {
        decorator_type = self.get_type_of_expression(decorator);
        if is_cached_property_decorator_type(decorator_type) {
            return PropertyWriteKind.WRITABLE;
        }
        if is_property_decorator_type(decorator_type) {
            return PropertyWriteKind.READ_ONLY;
        }
    }
    return PropertyWriteKind.NOT_PROPERTY;
}

impl TypeEvaluator.get_getter_type_from_property(symbol: Symbol) -> (TypeBase | None) {
    import from jaclang.compiler.types.type_utils { PropertyWriteKind }
    kind = self._classify_property_symbol(symbol);
    if kind == PropertyWriteKind.NOT_PROPERTY {
        return None;
    }
    if symbol.provider is not None {
        cat_type = self.get_type_of_symbol(symbol);
        if isinstance(cat_type, FunctionType) {
            return cat_type.return_type;
        }
        return None;
    }
    node_ = symbol.decl.name_of;
    if not isinstance(node_, Ability) {
        return None;
    }
    func_type = self.get_type_of_ability(node_);
    if not isinstance(func_type, FunctionType) {
        return None;
    }
    return func_type.return_type;
}

impl TypeEvaluator.get_property_write_type(symbol: Symbol) -> PropertyWriteResult {
    import from jaclang.compiler.types.type_utils {
        PropertyWriteKind,
        PropertyWriteResult
    }
    kind = self._classify_property_symbol(symbol);
    if kind == PropertyWriteKind.NOT_PROPERTY {
        return PropertyWriteResult(kind=PropertyWriteKind.NOT_PROPERTY);
    }
    if symbol.provider is not None {
        write_kind = PropertyWriteKind(symbol.provider.property_write_kind());
        if write_kind == PropertyWriteKind.WRITABLE {
            baked = symbol.provider.property_write_type();
            return PropertyWriteResult(
                kind=PropertyWriteKind.WRITABLE,
                write_type=baked if baked is not None else UnknownType()
            );
        }
        return PropertyWriteResult(kind=PropertyWriteKind.READ_ONLY);
    }

    node_decl = symbol.decl.name_of;
    if isinstance(node_decl, HasVar) and node_decl.accessors {
        if kind == PropertyWriteKind.READ_ONLY {
            return PropertyWriteResult(kind=PropertyWriteKind.READ_ONLY);
        }
        for accessor in node_decl.accessors {
            if accessor.accessor_kind != "setter" {
                continue;
            }
            signature = accessor.signature;
            if isinstance(signature, FuncSignature) {
                parameters = signature.get_parameters();
                if parameters and parameters[-1].type_tag is not None {
                    write_type = self._convert_to_instance(
                        self.get_type_of_expression(parameters[-1].type_tag.tag)
                    );
                    return PropertyWriteResult(
                        kind=PropertyWriteKind.WRITABLE, write_type=write_type
                    );
                }
            }
        }
        if node_decl.type_tag {
            decl_ty = self._convert_to_instance(
                self.get_type_of_expression(node_decl.type_tag.tag)
            );
            return PropertyWriteResult(
                kind=PropertyWriteKind.WRITABLE, write_type=decl_ty
            );
        }
        return PropertyWriteResult(
            kind=PropertyWriteKind.WRITABLE, write_type=UnknownType()
        );
    }

    if kind == PropertyWriteKind.WRITABLE {
        node_ = symbol.decl.name_of;
        if isinstance(node_, Ability) {
            func_type = self.get_type_of_ability(node_);
            if isinstance(func_type, FunctionType)
                and func_type.return_type is not None {
                return PropertyWriteResult(
                    kind=PropertyWriteKind.WRITABLE, write_type=func_type.return_type
                );
            }
        }

        return PropertyWriteResult(
            kind=PropertyWriteKind.WRITABLE, write_type=UnknownType()
        );
    }

    prop_name = symbol.sym_name;
    method_scope = symbol.symbol_table;
    class_scope = method_scope.parent_scope if method_scope is not None else None;
    if class_scope is not None {
        overload_syms = class_scope.names_in_scope_overload.get(prop_name);
        if overload_syms {
            for overload_sym in overload_syms {
                setter_type = self._get_setter_value_type(overload_sym, prop_name);
                if setter_type is not None {
                    return PropertyWriteResult(
                        kind=PropertyWriteKind.WRITABLE, write_type=setter_type
                    );
                }
            }
        }
    }

    return PropertyWriteResult(kind=PropertyWriteKind.READ_ONLY);
}

impl TypeEvaluator._get_setter_value_type(
    symbol: Symbol, prop_name: str
) -> (TypeBase | None) {
    node_ = symbol.decl.name_of;
    if not isinstance(node_, Ability) {
        return None;
    }
    ability = node_;
    if not ability.decorators {
        return None;
    }
    for decorator in ability.decorators {
        if isinstance(decorator, AtomTrailer) and decorator.is_attr {
            if (
                isinstance(decorator.right, Name)
                and decorator.right.value == "setter"
                and isinstance(decorator.target, Name)
                and decorator.target.value == prop_name
            ) {
                func_type = self.get_type_of_ability(ability);
                if isinstance(func_type, FunctionType) and func_type.parameters {
                    for param in func_type.parameters {
                        if not param.is_self and not param.is_cls {
                            return param.param_type;
                        }
                    }
                }
                return None;
            }
        }
    }
    return None;
}
