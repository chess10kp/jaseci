impl TypeEvaluator._is_type_alias_annotation(
    annotation_type: TypeBase, tag_expr: Expr
) -> bool {
    if self._type_alias_tag_ident(tag_expr) != "TypeAlias" {
        return False;
    }
    if self._is_typing_special_form(annotation_type, "_SpecialForm") {
        return True;
    }
    is_special_form = (
        isinstance(annotation_type, ClassType)
        and self.prefetch is not None
        and self.prefetch.callable_class is not None
        and annotation_type.shared.same_class(self.prefetch.callable_class.shared)
    );
    return is_special_form or isinstance(annotation_type, UnknownType);
}

impl TypeEvaluator._type_alias_tag_ident(tag_expr: Expr) -> (str | None) {
    if isinstance(tag_expr, AtomTrailer) and tag_expr.is_attr {
        right = tag_expr.right;
        return right.value if isinstance(right, Name) else None;
    }
    if isinstance(tag_expr, Name) {
        sym = tag_expr.sym;
        if sym is not None and isinstance(sym.decl, Name) {
            mod_item = sym.decl.find_parent_of_type(ModuleItem);
            if mod_item is not None and isinstance(mod_item.name, Name) {
                return mod_item.name.value;
            }
        }
        return tag_expr.value;
    }
    return None;
}

impl TypeEvaluator._brand_distinct_alias(
    node_: TypeAlias, resolved: TypeBase
) -> TypeBase {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if not isinstance(resolved, ClassType)
        or not JAC_TYPE_REGISTRY.is_primitive(resolved.shared.class_name) {
        return resolved;
    }
    key = f"{node_.loc.mod_path}::{node_.name.value}";
    private = ClassDetailsPrivate(
        type_args=(
            resolved.private.type_args[:] if resolved.private.type_args else None
        ),
        alias_name=resolved.private.alias_name,
        literal_value=resolved.private.literal_value,
        distinct_key=key
    );
    return ClassType(_shared=resolved.shared, private=private, flags=resolved.flags);
}

impl TypeEvaluator._distinct_brand_mismatch(
    src_type: TypeBase, dest_type: TypeBase
) -> bool {
    if not isinstance(dest_type, ClassType) {
        return False;
    }
    dest_brand = dest_type.private.distinct_key;
    if dest_brand is None {
        return False;
    }
    src_brand = (
        src_type.private.distinct_key if isinstance(src_type, ClassType) else None
    );
    return src_brand != dest_brand;
}

impl TypeEvaluator._resolve_type_alias_rhs(value: Expr) -> TypeBase {
    if isinstance(value, (String, MultiString)) {
        type_str = literal_string_value(value);
        if type_str is None {
            return UnknownType();
        }
        resolved = self._try_resolve_forward_ref(value);
        if resolved is not None {
            return resolved;
        }
        scope = value.find_parent_of_type(UniScopeNode);
        if scope {
            parsed = self._resolve_string_type_expr(type_str, scope);
            if parsed is not None {
                return parsed;
            }
        }
        return UnknownType();
    }

    mod = value.find_parent_of_type(Module);
    is_stub = mod is not None and mod.is_raised_from_py;
    if is_stub {
        self._diagnostic_suppression_depth += 1;
        try {
            return self.get_type_of_expression(value);
        } finally {
            self._diagnostic_suppression_depth -= 1;
        }
    }
    return self.get_type_of_expression(value);
}

impl TypeEvaluator._resolve_string_type_expr(
    type_str: str, scope: UniScopeNode
) -> TypeBase | None {
    import from jaclang.compiler.frontend.parser.parser { parse_expression }
    import from jaclang.compiler.frontend.unitree { SubTag }
    (expression, had_error, _parser_diags, _lex_diags) = parse_expression(
        type_str, scope.loc.mod_path
    );

    owned_nodes = expression.flatten();
    annotation = SubTag(tag=expression, kid=[expression]);
    owned_nodes.append(annotation);
    self._diagnostic_suppression_depth += 1;
    try {
        if had_error {
            return None;
        }
        annotation.set_parent(scope);
        result = self._type_from_union_annotation_arg(expression);
        return None if isinstance(result, UnknownType) else result;
    } finally {
        self._diagnostic_suppression_depth -= 1;
        for owned in owned_nodes {
            del [edge owned<-->];
        }
    }
}

impl TypeEvaluator._enum_member_attr_type(
    base_type: EnumMemberType, member_name: str
) -> (TypeBase | None) {
    if member_name in ('name', '_name_') {
        if self.prefetch.str_class is None {
            return None;
        }
        return self._convert_to_instance(self.prefetch.str_class);
    }
    if member_name in ('value', '_value_') {
        return self._convert_to_instance(base_type.get_value_type());
    }
    enum_cls = base_type.enum_class;
    if enum_cls is None {
        return None;
    }
    if enum_cls.shared.enum_members and member_name in enum_cls.shared.enum_members {
        return EnumMemberType(
            enum_class=enum_cls,
            member_info=enum_cls.shared.enum_members[member_name],
            flags=TypeFlags.Instance
        );
    }
    if member := self._lookup_class_member(enum_cls, member_name) {
        return self.get_type_of_symbol(member.symbol);
    }
    return None;
}
