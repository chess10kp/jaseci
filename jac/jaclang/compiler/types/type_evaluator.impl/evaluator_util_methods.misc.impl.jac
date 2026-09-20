impl TypeEvaluator._try_resolve_forward_ref(
    expr: String | MultiString
) -> TypeBase | None {
    name = literal_string_value(expr);
    if not isinstance(name, str) or not name {
        return None;
    }
    scope = expr.find_parent_of_type(UniScopeNode);
    if not scope {
        return None;
    }
    symbol = lookup_symtab(scope, name, self.builtins_module);
    if not symbol {
        return None;
    }
    symbol = self.resolve_imported_symbols(symbol);
    if not symbol.decl or not symbol.decl.name_of {
        return None;
    }

    resolved = self.get_type_of_symbol(symbol);
    if isinstance(resolved, UnknownType) {
        if resolved.is_incomplete {
            return resolved;
        }
        return None;
    }
    return resolved;
}

impl TypeEvaluator._annotation_args(expr: Expr | None) -> list[Expr] {
    if expr is None {
        return [];
    }
    if not isinstance(expr, TupleVal) {
        return [expr];
    }
    args: list[Expr] = [];
    for item in expr.values {
        if not isinstance(item, Expr) {
            self.emit_diag(E1038, item);
            return [];
        }
        args.append(item);
    }
    return args;
}

impl TypeEvaluator._type_from_union_annotation_arg(val: Expr) -> TypeBase {
    string_expr: String | None = None;
    if isinstance(val, MultiString) and val.strings {
        if (
            len(val.strings) == 1
            and isinstance(val.strings[0], String)
            and isinstance(val.strings[0].lit_value, str)
        ) {
            string_expr = val.strings[0];
        }
    } elif isinstance(val, String) and isinstance(val.lit_value, str) {
        string_expr = val;
    }
    if string_expr is not None {
        fwd = self._try_resolve_forward_ref(string_expr);
        if fwd is not None {
            return self._convert_to_instance(fwd);
        }
    }
    return self._convert_to_instance(self.get_type_of_expression(val));
}

impl TypeEvaluator.emit_diag(
    diag: DiagnosticInfo, nd: UniNode, **kwargs: object
) -> None {
    if self._pass is not None and self._diagnostic_suppression_depth == 0 {
        self._pass.emit(diag, node_override=nd, **kwargs);
    }
}

impl TypeEvaluator._invalidate_expr_type_cache(node_: UniNode) -> None {
    if isinstance(node_, Expr) {
        node_.type = None;
        node_.ct_value = None;
    }
    for kid in node_.kid {
        self._invalidate_expr_type_cache(kid);
    }
}

impl TypeEvaluator._resolve_from_path(from_mod: ModulePath) -> Path {
    if from_mod.level > 0 and not from_mod.path {
        base = Path(from_mod.loc.mod_path).parent;
        for _ in range(max(from_mod.level - 1, 0)) {
            base = base.parent;
        }
        return base;
    }

    return Path(from_mod.resolve_relative_path());
}

impl TypeEvaluator._resolve_client_npm_module(node_: ModulePath) -> (str | None) {
    spec = node_.string_path_value or node_.dot_path_str;
    if not spec {
        return None;
    }
    if not node_.in_client_context() {
        return None;
    }
    mod_path = node_.loc.mod_path if node_.loc else None;
    if not mod_path {
        return None;
    }
    import from jaclang.project.modresolver { resolve_client_npm_package }
    base = self._client_npm_base(spec, mod_path);
    if base is None {
        return None;
    }
    return resolve_client_npm_package(spec, base);
}

impl TypeEvaluator._client_npm_base(spec: str, mod_path: str) -> (str | None) {
    import from jaclang.project.modresolver { has_client_npm_package }
    if has_client_npm_package(spec, mod_path) {
        return mod_path;
    }
    entry_path = self._client_entry_mod_path();
    if (
        entry_path
        and entry_path != mod_path
        and has_client_npm_package(spec, entry_path)
    ) {
        return entry_path;
    }
    return None;
}

impl TypeEvaluator._client_entry_mod_path -> (str | None) {
    main_mod = self.program.mod.main;
    if main_mod and main_mod.loc {
        return main_mod.loc.mod_path or None;
    }
    return None;
}

impl TypeEvaluator._is_fstring_all_literal(fstring: FString) -> bool {
    for part in fstring.parts {
        if isinstance(part, String) {
            continue;
        }
        if isinstance(part, FormattedValue) {
            part_type = self.get_type_of_expression(part.format_part);
            if isinstance(part_type, ClassType) {
                if part_type.is_literal_type() {
                    continue;
                }
                if self.prefetch and self.prefetch.literal_string_class {
                    if isinstance(self.prefetch.literal_string_class, ClassType) {
                        if part_type.shared
                            == self.prefetch.literal_string_class.shared {
                            continue;
                        }
                    }
                }
            }

            return False;
        }
    }
    return True;
}
