impl TypeEvaluator._assign_callable(
    src_func: FunctionType, dest_func: FunctionType, strict: bool = False
) -> bool {
    if dest_func.is_gradual_callable_form() {
        if dest_func.return_type and src_func.return_type {
            return self.assign_type(
                src_func.return_type, dest_func.return_type, strict
            );
        }
        return True;
    }

    if src_func.is_gradual_callable_form() {
        return False;
    }

    src_params = [
        p
        for p in (src_func.parameters or [])
        if not p.is_self and not p.is_cls
    ];
    dest_params = [
        p
        for p in (dest_func.parameters or [])
        if not p.is_self and not p.is_cls
    ];

    overlap = min(len(src_params), len(dest_params));
    for i in range(overlap) {
        dest_param = dest_params[i];
        src_param = src_params[i];

        if dest_param.param_type is None or src_param.param_type is None {
            continue;
        }

        if not self.assign_type(dest_param.param_type, src_param.param_type, strict) {
            return False;
        }
    }

    if len(src_params) > len(dest_params) {
        for i in range(len(dest_params), len(src_params)) {
            src_param = src_params[i];
            if not src_param.is_optional {
                return False;
            }
        }
    }

    if dest_func.return_type and src_func.return_type {
        dest_ret = self._convert_to_instance(dest_func.return_type);

        if self.is_none_type(dest_ret) {
            return True;
        }
        src_ret = self._convert_to_instance(src_func.return_type);
        if not self.assign_type(src_ret, dest_ret, strict) {
            return False;
        }
    }
    return True;
}

impl TypeEvaluator._assign_class(
    src_type: ClassType, dest_type: ClassType, strict: bool = False
) -> bool {
    unwrapped_dest: TypeBase = dest_type;
    unwrapped_src: TypeBase = src_type;
    if self.prefetch.final_class is not None
        and dest_type.shared.same_class(self.prefetch.final_class.shared) {
        if len(dest_type.private.type_args) > 0 {
            unwrapped_dest = dest_type.private.type_args[0];
        }
    }
    if self.prefetch.final_class is not None
        and src_type.shared.same_class(self.prefetch.final_class.shared) {
        if len(src_type.private.type_args) > 0 {
            unwrapped_src = src_type.private.type_args[0];
        }
    }

    if not isinstance(unwrapped_src, ClassType)
        or not isinstance(unwrapped_dest, ClassType) {
        return self.assign_type(unwrapped_src, unwrapped_dest, strict);
    }
    src_type = unwrapped_src;
    dest_type = unwrapped_dest;

    if self._distinct_brand_mismatch(src_type, dest_type) {
        return False;
    }
    if src_type.shared.same_class(dest_type.shared) {
        if dest_type.is_literal_type() {
            if not src_type.is_literal_type() {
                return False;
            }

            return src_type.get_literal_value() == dest_type.get_literal_value();
        }

        if src_type.private.type_args and dest_type.private.type_args {
            if len(src_type.private.type_args) == len(dest_type.private.type_args) {
                for i in range(len(src_type.private.type_args)) {
                    src_arg = self._convert_to_instance(src_type.private.type_args[i]);
                    dest_arg = self._convert_to_instance(
                        dest_type.private.type_args[i]
                    );
                    if not self.assign_type(src_arg, dest_arg, strict) {
                        return False;
                    }
                }
            }
        }
        return True;
    }

    if self.is_sub_class(dest_type, src_type) {
        if dest_type.private.type_args {
            specialized = specialize_for_base_class(src_type, dest_type);
            src_args = specialized.private.type_args;
            if src_args and len(src_args) == len(dest_type.private.type_args) {
                for i in range(len(src_args)) {
                    src_arg = self._convert_to_instance(src_args[i]);
                    dest_arg = self._convert_to_instance(
                        dest_type.private.type_args[i]
                    );

                    tp = dest_type.shared.type_params[i]
                        if (
                            dest_type.shared.type_params
                            and i < len(dest_type.shared.type_params)
                        )
                        else None;
                    if tp and tp.is_covariant {
                        if not self.assign_type(src_arg, dest_arg, strict) {
                            return False;
                        }
                    } elif tp and tp.is_contravariant {
                        if not self.assign_type(dest_arg, src_arg, strict) {
                            return False;
                        }
                    } else {
                        if not self.assign_type(src_arg, dest_arg, strict) {
                            return False;
                        }
                    }
                }
            }
        }
        return True;
    }

    if src_type.is_builtin() and dest_type.is_builtin() {
        import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
        src_name = src_type.shared.class_name;
        dest_name = dest_type.shared.class_name;
        if JAC_TYPE_REGISTRY.is_numeric(src_name)
            and JAC_TYPE_REGISTRY.is_numeric(dest_name) {
            return JAC_TYPE_REGISTRY.widens_to(src_name, dest_name);
        }
    }

    if self._is_protocol_class(dest_type) {
        if class_implements_protocol(src_type, dest_type, self) {
            return True;
        }

        for mro_cls in src_type.shared.mro {
            if not mro_cls.shared.same_class(src_type.shared) {
                if class_implements_protocol(mro_cls, dest_type, self) {
                    return True;
                }
            }
        }
    }
    return False;
}

impl TypeEvaluator._is_protocol_class(cls_type: ClassType) -> bool {
    for base_cls in cls_type.shared.base_classes {
        if not isinstance(base_cls, ClassType) or base_cls._shared is None {
            continue;
        }

        if self.prefetch.protocol_class is not None
            and base_cls.shared.same_class(self.prefetch.protocol_class.shared) {
            return True;
        }

        if base_cls.shared.is_builtin_class
            and base_cls.shared.class_name in ('Protocol', '_SpecialForm') {
            return True;
        }
    }

    class_name = cls_type.shared.class_name;
    if (cls_type.shared.is_from_stdlib_stub or cls_type.shared.is_builtin_class)
        and (class_name.startswith('Supports') or class_name.startswith('_Supports')) {
        return True;
    }

    for mro_cls in cls_type.shared.mro {
        if isinstance(mro_cls, ClassType) {
            if (mro_cls.shared.is_builtin_class or mro_cls.shared.is_from_stdlib_stub)
                and mro_cls.shared.class_name in ('Protocol', '_SpecialForm') {
                return True;
            }
        }
    }
    return False;
}

impl TypeEvaluator._solve_protocol_type_args(
    src_type: ClassType, proto_type: ClassType, bindings: dict[str, TypeBase]
) -> bool {
    proto_symtab = proto_type.shared.symbol_table;
    if not isinstance(proto_symtab, UniScopeNode) {
        return False;
    }

    solved = False;
    for (name, sym) in proto_symtab.names_in_scope.items() {
        proto_func: TypeBase | None = None;
        if sym.provider is not None {
            cat_func = self.get_type_of_symbol(sym);
            if isinstance(cat_func, FunctionType) {
                proto_func = cat_func;
            }
        } elif sym.decl and isinstance(sym.decl.name_of, Ability) {
            proto_func = self.get_type_of_ability(sym.decl.name_of);
        }
        if proto_func is None {
            continue;
        }

        member = self._lookup_class_member(src_type, name);
        if member is None {
            continue;
        }

        impl_func = self.get_type_of_symbol(member.symbol);
        if isinstance(impl_func, FunctionType) {
            impl_func = impl_func.specialize(src_type);
        }

        if isinstance(proto_func, FunctionType)
            and isinstance(impl_func, FunctionType) {
            if self.assign_type_to_type_var(proto_func, impl_func, bindings) {
                solved = True;
            }
        }
    }
    return solved;
}

impl TypeEvaluator.is_sub_class(super_cls: ClassType, sub_cls: ClassType) -> bool {
    import from jaclang.compiler.types.type_utils { ensure_mro_fresh }
    self._heal_ancestry(sub_cls);
    ensure_mro_fresh(sub_cls);
    for cls in sub_cls.shared.mro {
        if cls.shared.same_class(super_cls.shared) {
            return True;
        }
    }
    return False;
}

impl TypeEvaluator._heal_ancestry(cls: ClassType) -> None {
    import from jaclang.compiler.types.type_utils { ensure_mro_fresh }
    attempted: set[int] = set();
    while True {
        healed = False;
        if cls.shared._provisional and id(cls.shared) not in attempted {
            attempted.add(id(cls.shared));
            self._heal_class_bases(cls);
            healed = True;
        }
        ensure_mro_fresh(cls);
        for ancestor in list(cls.shared.mro or []) {
            if ancestor.shared._provisional and id(ancestor.shared) not in attempted {
                attempted.add(id(ancestor.shared));
                self._heal_class_bases(ancestor);
                healed = True;
            }
        }
        if not healed {
            return;
        }
    }
}

impl TypeEvaluator._heal_class_bases(cls: ClassType) -> None {
    import from jaclang.compiler.frontend.unitree { Archetype }
    import from jaclang.compiler.types.type_utils { linearize_mro, mro_signature }
    shared = cls.shared;
    node_ = shared.symbol_table;
    if not isinstance(node_, Archetype) {
        shared._provisional = False;
        return;
    }
    if shared._heal_stamp in (id(self), -id(self)) {
        return;
    }
    shared._heal_stamp = -id(self);
    shared._provisional = False;
    bases: list[TypeBase] = [];
    unresolved = False;
    for base_expr in node_.base_classes or [] {
        memo = base_expr.type;
        if isinstance(memo, UnknownType) and not memo.is_diagnosed {
            base_expr.type = None;
        }
        base_type = self.get_type_of_expression(base_expr);
        if isinstance(base_type, UnknownType) and not base_type.is_diagnosed {
            unresolved = True;
        }
        bases.append(base_type);
    }
    if unresolved {
        shared._provisional = True;
        shared._heal_stamp = 0;
        return;
    }
    shared._heal_stamp = id(self);
    if not [
        b
        for b in bases
        if isinstance(b, ClassType)
    ]
        and self.prefetch
        and self.prefetch.object_class
        and not shared.same_class(self.prefetch.object_class.shared) {
        bases.append(self.prefetch.object_class);
    }
    shared.base_classes = bases;
    rebuilt = linearize_mro(cls);
    if len(rebuilt) > len(shared.mro) {
        shared.mro = rebuilt;
    }
    shared._mro_sig = mro_signature(cls);
}

impl TypeEvaluator.slice_assignment_is_valid(target: Expr, value_node: Expr) -> bool {
    if not (
        isinstance(target, AtomTrailer)
        and not target.is_attr
        and isinstance(target.right, IndexSlice)
        and target.right.is_range
    ) {
        return False;
    }
    base_type = self.get_type_of_expression(target.target);
    if isinstance(base_type, ClassType) and not base_type.is_class_instance() {
        return False;
    }
    return self.get_type_of_magic_method_call(
        base_type, "__setitem__", [target.right, value_node], None
    )
        is not None;
}

impl TypeEvaluator.assign_expr(
    expr: Expr | None,
    src_type: TypeBase,
    dest_type: TypeBase,
    strict: bool = False,
    probe: bool = False
) -> AssignVerdict {
    verdict = assign_numeric_expr(self, expr, src_type, dest_type, probe);
    if verdict is not None {
        return verdict;
    }
    return AssignVerdict(ok=self.assign_type(src_type, dest_type, strict));
}

impl TypeEvaluator.assign_type(
    src_type: TypeBase, dest_type: TypeBase, strict: bool = False
) -> bool {
    if src_type == dest_type {
        return True;
    }

    if isinstance(dest_type, UnknownType) {
        return True;
    }

    if isinstance(src_type, UnknownType)
        and (src_type.is_diagnosed or src_type.is_incomplete) {
        return True;
    }

    if isinstance(src_type, NeverType) {
        return True;
    }

    if self.is_explicit_any(dest_type) {
        return True;
    }

    if isinstance(dest_type, ClassType) and dest_type.is_builtin("object") {
        return True;
    }

    if self.is_explicit_any(src_type) {
        return True;
    }

    if isinstance(dest_type, ClassType) and dest_type.is_class_instance() {
        _ext_arch = dest_type.shared.symbol_table;
        if isinstance(_ext_arch, Archetype)
            and _ext_arch.find_parent_of_type(Import) is not None {
            return True;
        }
    }

    if self._in_native_context() {
        if (
            isinstance(dest_type, FunctionType)
            and isinstance(src_type, ClassType)
            and src_type.is_builtin("int")
        )
            or (
                isinstance(src_type, FunctionType)
                and isinstance(dest_type, ClassType)
                and dest_type.is_builtin("int")
            ) {
            return True;
        }
    }

    _rt_base_kinds: dict[str, tuple[str, ...]] = {
        'Archetype': ('node', 'edge', 'walker', 'object'),
        'NodeArchetype': ('node', ),
        'EdgeArchetype': ('edge', ),
        'WalkerArchetype': ('walker', ),
        'ObjectArchetype': ('object', )
    };
    _rt_dest_tab = (
        dest_type.shared.symbol_table if isinstance(dest_type, ClassType) else None
    );
    _rt_dest_mod = (
        str(_rt_dest_tab.loc.mod_path)
            if (_rt_dest_tab is not None and _rt_dest_tab.loc is not None)
            else ''
    ).replace(
        '\\', '/'
    );
    if (
        isinstance(dest_type, ClassType)
        and dest_type.is_class_instance()
        and dest_type.shared.class_name in _rt_base_kinds
        and _rt_dest_mod.endswith('runtime/archetype.jac')
        and isinstance(src_type, ClassType)
        and src_type.is_class_instance()
    ) {
        import from jaclang.compiler.frontend.constant { SymbolType as _RtSymT }
        _rt_kinds = _rt_base_kinds[dest_type.shared.class_name];
        _rt_cat_map = {
            'node': _RtSymT.NODE_ARCH,
            'edge': _RtSymT.EDGE_ARCH,
            'walker': _RtSymT.WALKER_ARCH,
            'object': _RtSymT.OBJECT_ARCH
        };
        _rt_src_tab = src_type.shared.symbol_table;
        if isinstance(_rt_src_tab, Archetype)
            and any(_rt_src_tab.sym_category == _rt_cat_map[k] for k in _rt_kinds) {
            return True;
        }
        if src_type.shared.is_root_class and 'node' in _rt_kinds {
            return True;
        }
    }

    if isinstance(src_type, ClassType) and src_type.is_class_instance() {
        _ext_src = src_type.shared.symbol_table;
        if isinstance(_ext_src, Archetype)
            and _ext_src.find_parent_of_type(Import) is not None
            and isinstance(dest_type, ClassType)
            and dest_type.is_builtin("int") {
            return True;
        }
    }

    if self.prefetch
        and isinstance(src_type, ClassType)
        and isinstance(dest_type, ClassType) {
        if src_type.is_literal_type()
            and self.prefetch.str_class
            and self.prefetch.literal_string_class {
            if src_type.shared.same_class(self.prefetch.str_class.shared) {
                if dest_type.shared.same_class(
                    self.prefetch.literal_string_class.shared
                ) {
                    return True;
                }
            }
        }

        if src_type.is_literal_type() and not dest_type.is_literal_type() {
            if src_type.shared.same_class(dest_type.shared) {
                return True;
            }
        }

        if src_type.is_literal_type() and dest_type.is_literal_type() {
            if src_type.shared.same_class(dest_type.shared) {
                return src_type.get_literal_value() == dest_type.get_literal_value();
            }
        }

        if not src_type.is_literal_type() and dest_type.is_literal_type() {
            if src_type.shared.same_class(dest_type.shared) {
                return True;
            }
        }

        if self.prefetch.literal_string_class and self.prefetch.str_class {
            if (
                src_type.shared.same_class(self.prefetch.literal_string_class.shared)
                and not dest_type.shared.same_class(
                    self.prefetch.literal_string_class.shared
                )
            ) {
                str_instance = self._convert_to_instance(self.prefetch.str_class);
                if self.assign_type(str_instance, dest_type, strict) {
                    return True;
                }
            }
        }
    }

    if self.prefetch and self.prefetch.jsx_element_class {
        if isinstance(dest_type, ClassType) and isinstance(src_type, ClassType) {
            if dest_type.shared.same_class(self.prefetch.jsx_element_class.shared) {
                if not src_type.shared.same_class(
                    self.prefetch.jsx_element_class.shared
                ) {
                    return False;
                }
            }
        }
    }

    if (
        isinstance(dest_type, FunctionType)
        and dest_type.is_gradual_callable_form()
        and isinstance(src_type, FunctionType)
    ) {
        return True;
    }
    if isinstance(dest_type, FunctionType) {
        if isinstance(src_type, FunctionType) {
            return self._assign_callable(src_type, dest_type, strict);
        }

        if isinstance(src_type, OverloadedType) and src_type.overloads {
            for overload in src_type.overloads {
                if self._assign_callable(overload, dest_type, strict) {
                    return True;
                }
            }
            return False;
        }

        if isinstance(src_type, ClassType) and src_type.is_class_instance() {
            if call_member := self._lookup_object_member(src_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, FunctionType) {
                    return self._assign_callable(call_type, dest_type, strict);
                }
            }
        }

        if isinstance(src_type, ClassType) and src_type.is_instantiable_class() {
            for ctor in self.class_constructor_callables(src_type) {
                if self._assign_callable(ctor, dest_type, strict) {
                    return True;
                }
            }
        }
    }

    if isinstance(src_type, FunctionType) {
        if isinstance(dest_type, ClassType) and dest_type.is_class_instance() {
            if call_member := self._lookup_object_member(dest_type, "__call__") {
                call_type = self.get_type_of_symbol(call_member.symbol);
                if isinstance(call_type, FunctionType) {
                    return self._assign_callable(src_type, call_type, strict);
                }
            }
        }
    }

    if self.is_any_type(dest_type) or self.is_any_type(src_type) {
        return True;
    }

    if isinstance(dest_type, ClassType) and dest_type.is_builtin("object") {
        return True;
    }

    if isinstance(src_type, UnionType) and not isinstance(dest_type, UnionType) {
        for src_member in src_type.types {
            if not self.assign_type(src_member, dest_type, strict) {
                return False;
            }
        }
        return True;
    }

    if isinstance(dest_type, UnionType) {
        if isinstance(src_type, UnionType) {
            for src_type_arg in src_type.types {
                matched = False;
                src_type_inst = self._convert_to_instance(src_type_arg);
                for dest_type_arg in dest_type.types {
                    dest_type_inst = self._convert_to_instance(dest_type_arg);
                    if self.assign_type(src_type_inst, dest_type_inst, strict) {
                        matched = True;
                        break;
                    }
                }

                if not matched {
                    return False;
                }
            }

            return True;
        }
        for union_type in dest_type.types {
            new_dest_type = self._convert_to_instance(union_type);
            if self.assign_type(src_type, new_dest_type, strict) {
                return True;
            }
        }
    }

    if isinstance(src_type, EnumMemberType) and src_type.enum_class is not None {
        if isinstance(dest_type, ClassType) and dest_type.is_enum_class() {
            if src_type.enum_class.shared.same_class(dest_type.shared) {
                return True;
            }
        }

        if isinstance(dest_type, EnumMemberType) and dest_type.enum_class is not None {
            if src_type.enum_class.shared.same_class(dest_type.enum_class.shared) {
                return True;
            }
        }

        if isinstance(dest_type, ClassType)
            and isinstance(
                enum_val_type := src_type.enum_class.shared.enum_value_type, ClassType
            )
            and dest_type.shared.same_class(enum_val_type.shared) {
            return True;
        }
    }

    if self.prefetch and self.prefetch.type_class {
        if isinstance(dest_type, ClassType) and isinstance(src_type, ClassType) {
            if dest_type.shared.same_class(self.prefetch.type_class.shared) {
                if src_type.is_instantiable_class() {
                    if dest_type.private.type_args {
                        target_inner = self._convert_to_instance(
                            dest_type.private.type_args[0]
                        );
                        src_inner = self._convert_to_instance(src_type);
                        return self.assign_type(src_inner, target_inner, strict);
                    }

                    return True;
                }
            }
        }
    }

    if (
        isinstance(src_type, ClassType)
        and src_type.is_enum_class()
        and src_type.is_instantiable()
        and isinstance(dest_type, ClassType)
        and dest_type.is_builtin()
        and dest_type.shared.class_name
            in ("Sized", "Iterable", "Container", "Reversible", "Hashable")
    ) {
        return True;
    }

    if (
        isinstance(dest_type, ClassType)
        and isinstance(src_type, ClassType)
        and src_type.is_class_instance()
        and dest_type.is_class_instance()
    ) {
        _protocol_methods: dict[str, str] = {
            "SupportsIndex": "__index__",
            "SupportsInt": "__int__",
            "SupportsFloat": "__float__",
            "SupportsComplex": "__complex__",
            "SupportsBytes": "__bytes__",
            "SupportsAbs": "__abs__",
            "SupportsRound": "__round__",
            "_SupportsRound1": "__round__",
            "_SupportsRound2": "__round__",
            "Sized": "__len__",
            "Hashable": "__hash__",
            "Iterable": "__iter__",
            "Iterator": "__next__",
            "Reversible": "__reversed__",
            "Container": "__contains__",

        };
        required_method = _protocol_methods.get(dest_type.shared.class_name);
        if required_method {
            if self._lookup_object_member(src_type, required_method) {
                return True;
            }
        }
    }
    if dest_type.is_class_instance() and src_type.is_class_instance() {
        assert isinstance(dest_type, ClassType);
        assert isinstance(src_type, ClassType);
        return self._assign_class(src_type, dest_type, strict);
    }
    return False;
}
