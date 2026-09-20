impl TypeCheckPass.exit_import with Import exit {
    if here.clib_decls {
        return;
    }
    if here.from_loc {
        self.evaluator.get_type_of_module(here.from_loc);
        for item in here.items {
            if isinstance(item, ModuleItem) {
                self.evaluator.get_type_of_module_item(item);
            }
        }
    } else {
        for item in here.items {
            if isinstance(item, ModulePath) {
                self.evaluator.get_type_of_module(item);
            }
        }
    }
}

impl TypeCheckPass.enter_ability with Ability entry {
    for decor in (here.decorators or []) {
        ty = self.evaluator.get_type_of_expression(decor);
        if (isinstance(ty, ClassType) and ty.is_builtin('staticmethod')) {
            here.is_static = True;
            break;
        }
    }
}

impl TypeCheckPass.exit_ability with Ability exit {
    import from jaclang.compiler.frontend.constant { OwnershipKind }
    self.evaluator.validate_typevar_variance(here);

    self._check_intrinsic_collision(here);

    if (
        isinstance(here.signature, FuncSignature)
        and not here.is_static
        and not here.is_classmethod
    ) {
        owner = here.method_owner;
        if (
            isinstance(owner, Archetype)
            and owner.arch_type.value in ("obj", "node", "edge", "walker")
        ) {
            all_params = here.signature.get_parameters();
            if (
                len(all_params) > 0
                and isinstance(all_params[0].name, Name)
                and all_params[0].name.value == "self"
                and (
                    all_params[0].type_tag is None
                    or all_params[0].type_tag.ownership == OwnershipKind.NONE
                )
            ) {
                self.ctx.emit(
                    E2015,
                    node_override=all_params[0],
                    arch_type=owner.arch_type.value,
                    name=here.name_spec.sym_name
                );
            }
        }
    }

    if (
        isinstance(here.body, ImplDef)
        and here.body.find_parent_of_type(Module) is not self.module
    ) {
        self.ctx.walk_subtree(here.body, self);
    }

    if (
        isinstance(here.signature, FuncSignature)
        and here.signature.return_type is not None
        and here.find_parent_of_type(ImplDef) is None
    ) {
        ret_ann_type = self.evaluator.get_type_of_expression(
            here.signature.return_type
        );
        self._check_bare_generic(here.signature.return_type, ret_ann_type);
        self._check_explicit_any(here.signature.return_type);
    }

    if (
        isinstance(here.signature, FuncSignature)
        and here.signature.return_type is not None
        and not isinstance(here.body, ImplDef)
        and isinstance(here.body, list)
        and len(here.body) > 0
        and not here.is_abstract
    ) {
        is_overload = False;
        for decor in (here.decorators or []) {
            if isinstance(decor, Name) and decor.value == "overload" {
                is_overload = True;
                break;
            }
        }

        import from jaclang.compiler.frontend.module_facts { ModuleFacts }
        is_generator = ModuleFacts.ability_is_generator(here);

        body_stmts: list[CodeBlockStmt] = [
            stmt
            for stmt in here.body
            if isinstance(stmt, CodeBlockStmt)
        ];
        is_stub = self.evaluator._is_ellipsis_only_body(body_stmts);
        if not is_overload and not is_generator and not is_stub {
            ret_type = self.evaluator.get_type_of_expression(
                here.signature.return_type
            );
            ret_inst = self.evaluator._convert_to_instance(ret_type);
            none_type = self.evaluator._convert_to_instance(
                self.evaluator.get_none_type()
            );
            if not self.evaluator.assign_type(none_type, ret_inst) {
                if not self._body_always_returns(body_stmts) {
                    self.ctx.emit(
                        E1004,
                        node_override=here,
                        name=here.name_spec.sym_name,
                        ret_type=str(ret_type)
                    );
                }
            }
        }
    }

    if (
        isinstance(here.signature, EventSignature)
        and here.signature.arch_tag_info is not None
    ) {
        self._check_event_trigger_archetype(here);
    }

    comp_params = self._jsx_component_params(here);
    if comp_params is not None {
        self._check_props_bundle_is_exclusive(here, comp_params);
        if (
            len(comp_params) == 1
            and isinstance(comp_params[0].name, Name)
            and comp_params[0].name.value == "props"
        ) {
            props_param = comp_params[0];
            any_cls = self.evaluator.prefetch.any_class
                if self.evaluator.prefetch
                else None;

            is_untyped_bag = (
                props_param.type_tag is None
                or isinstance(props_param.type, AnyType)
                or (
                    any_cls is not None
                    and isinstance(props_param.type, ClassType)
                    and props_param.type.shared.same_class(any_cls.shared)
                )
            );
            if is_untyped_bag {
                self.ctx.emit(
                    W1052, node_override=props_param, component=here.name_spec.sym_name
                );
            }
        }
    }
}

impl TypeCheckPass.exit_type_alias with TypeAlias exit {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if not here.is_distinct {
        return;
    }
    resolved = self.evaluator._resolve_type_alias_rhs(here.value);
    if not isinstance(resolved, ClassType)
        or not JAC_TYPE_REGISTRY.is_primitive(resolved.shared.class_name) {
        self.ctx.emit(E1107, node_override=here.value, base=str(resolved));
    }
}

impl TypeCheckPass.exit_archetype with Archetype exit {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    cls_type = self.evaluator.get_type_of_class(here);
    if isinstance(cls_type, ClassType)
        and here.arch_type.name == Tok.KW_OBJECT
        and not cls_type.shared.is_from_stdlib_stub
        and cls_type.shared.base_classes {
        for base in cls_type.shared.base_classes {
            if isinstance(base, ClassType)
                and base.is_builtin()
                and JAC_TYPE_REGISTRY.is_primitive(base.shared.class_name) {
                self.ctx.emit(
                    E1106,
                    node_override=here.name,
                    name=here.name.value,
                    base=base.shared.class_name
                );
            }
        }
    }
    if (
        isinstance(here.body, ImplDef)
        and here.body.find_parent_of_type(Module) is not self.module
    ) {
        self.ctx.walk_subtree(here.body, self);
    }
}

impl TypeCheckPass.exit_enum with Enum exit {
    cls_type = self.evaluator.get_type_of_enum(here);

    for child in here.kid {
        if isinstance(child, Assignment) {
            for target in child.target {
                self.evaluator.get_type_of_expression(target);
            }
        }
    }
    if (
        isinstance(here.body, ImplDef)
        and here.body.find_parent_of_type(Module) is not self.module
    ) {
        self.ctx.walk_subtree(here.body, self);
    }
}

impl TypeCheckPass.exit_param_var with ParamVar exit {
    if (sym := here.sym) {
        declared_type = self.evaluator.get_type_of_symbol(sym);
        here.type = declared_type;

        if (
            here.type_tag
            and here.type_tag.tag
            and here.find_parent_of_type(ImplDef) is None
        ) {
            self._check_bare_generic(here.type_tag.tag, declared_type);
            self._check_explicit_any(here.type_tag.tag);
        }
        if here.value is not None and here.type_tag and here.type_tag.tag {
            default_type = self.evaluator.get_type_of_expression(
                here.value, expected_type=declared_type
            );
            self.evaluator.assign_expr(here.value, default_type, declared_type);
        }
    }
}

impl TypeCheckPass.exit_has_var with HasVar exit {
    import from jaclang.compiler.field_semantics { field_initialization }
    if (here.defer and here.kid and isinstance(here.kid[-1], Name)) {
        postinit_nd: Name = here.kid[-1];
        if postinit_nd.sym is None {
            arch = here.parent.parent if isinstance(here.parent, ArchHas) else None;
            if isinstance(arch, Archetype) {
                postinit_sym = arch.names_in_scope.get("__post_init__");
                if postinit_sym is not None {
                    postinit_nd.sym = postinit_sym;
                }
            } elif isinstance(arch, ImplDef)
                and isinstance(arch.decl_link, Archetype) {
                if (postinit_sym := arch.decl_link.names_in_scope.get("__post_init__"))
                    is not None {
                    postinit_nd.sym = postinit_sym;
                }
            }
        }
    }
    if (sym := here.sym) {
        declared_type = self.evaluator.get_type_of_symbol(sym);
        here.type = declared_type;

        if here.type_tag and here.type_tag.tag {
            self._check_bare_generic(here.type_tag.tag, declared_type);
            self._check_explicit_any(here.type_tag.tag);
        }

        self._check_walker_reports_shape(here, declared_type);

        if here.value is not None and here.type is not None {
            if here.find_parent_of_type(Import) is not None {
                return;
            }
            initialization = field_initialization(here);
            value_expr = initialization.default_expr;
            is_factory = False;
            if value_expr is None {
                value_expr = initialization.factory_expr;
                is_factory = True;
            }
            if value_expr is None {
                return;
            }
            right_type = self.evaluator.get_type_of_expression(
                value_expr, expected_type=here.type if not is_factory else None
            );
            if is_factory {
                if isinstance(right_type, FunctionType) {
                    self.evaluator.match_args_to_params(None, value_expr, right_type);
                    right_type = right_type.return_type or UnknownType();
                } elif isinstance(right_type, ClassType) {
                    call = FuncCall(
                        target=value_expr,
                        params=None,
                        genai_call=None,
                        kid=[value_expr]
                    );
                    call.set_parent(here);
                    try {
                        right_type = self.evaluator._validate_call_type(
                            call, right_type
                        );
                    } finally {
                        del [edge call-->];
                    }
                }
            }
            verdict = self.evaluator.assign_expr(
                value_expr,
                right_type,
                here.type,
                strict=self.evaluator._is_strict_site(here)
            );
            if not verdict.ok and not verdict.diagnosed {
                self.ctx.emit(
                    E1001,
                    node_override=here,
                    actual=str(right_type),
                    expected=str(here.type)
                );
            }
        }
    }
}

impl TypeCheckPass._check_walker_reports_shape(
    nd: HasVar, declared_type: object
) -> None {
    if nd.name.value != "reports" {
        return;
    }
    arch = nd.parent.parent if isinstance(nd.parent, ArchHas) else None;
    if isinstance(arch, ImplDef) and isinstance(arch.decl_link, Archetype) {
        arch = arch.decl_link;
    }
    if not isinstance(arch, Archetype) {
        return;
    }
    if arch.arch_kind != "walker" {
        return;
    }

    if isinstance(declared_type, UnknownType) {
        return;
    }
    if isinstance(declared_type, ClassType) {
        if declared_type.is_any_type() or declared_type.is_builtin("list") {
            return;
        }
    }
    self.ctx.emit(E1112, node_override=nd, type=str(declared_type));
}

impl TypeCheckPass._enclosing_walker_report_elem_type(
    nd: UniNode
) -> (TypeBase | None) {
    arch = nd.find_parent_of_type(Archetype);
    if arch is None {
        impl_def = nd.find_parent_of_type(ImplDef);
        if impl_def is not None and isinstance(impl_def.decl_link, Archetype) {
            arch = impl_def.decl_link;
        }
    }
    if not isinstance(arch, Archetype) or arch.arch_kind != "walker" {
        return None;
    }
    for has_var in arch.get_has_vars() {
        if has_var.name.value != "reports" {
            continue;
        }
        if has_var.sym is None {
            return None;
        }
        declared = self.evaluator.get_type_of_symbol(has_var.sym);
        if (
            isinstance(declared, ClassType)
            and declared.is_builtin("list")
            and declared.private
            and declared.private.type_args
            and len(declared.private.type_args) >= 1
        ) {
            return declared.private.type_args[0];
        }
        return None;
    }
    return None;
}

impl TypeCheckPass.exit_impl_def with ImplDef exit {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }

    if not (
        here.decl_link
        and isinstance(here.decl_link, Ability)
        and isinstance(here.decl_link.name_ref, SpecialVarRef)
        and here.decl_link.name_ref.name == Tok.KW_POST_INIT
    ) {
        return;
    }

    archetype = here.decl_link.find_parent_of_type(Archetype);
    if not archetype {
        return;
    }
    arch: Archetype = archetype;

    deferred_fields: dict[str, HasVar] = {};
    for has_var_node in arch.get_has_vars() {
        has_var: HasVar = has_var_node;
        if has_var.defer {
            deferred_fields[has_var.name.value] = has_var;
        }
    }
    if not deferred_fields {
        return;
    }

    assigned: set[str] = set();
    for trailer in here.get_all_sub_nodes(AtomTrailer) {
        atom_trailer: AtomTrailer = trailer;
        if not (atom_trailer.parent and isinstance(atom_trailer.parent, Assignment)) {
            continue;
        }
        if atom_trailer != atom_trailer.parent.target[0] {
            continue;
        }
        chain: list[AstSymbolNode] = atom_trailer.as_attr_list;
        if len(chain) >= 2 and chain[0].sym_name == 'self' {
            assigned.add(chain[1].sym_name);
        }
    }

    for (field_name, field_node) in deferred_fields.items() {
        if field_name not in assigned {
            self.ctx.emit(
                E1095,
                node_override=here,
                field=field_name,
                arch=arch.name_spec.sym_name
            );
        }
    }
}
