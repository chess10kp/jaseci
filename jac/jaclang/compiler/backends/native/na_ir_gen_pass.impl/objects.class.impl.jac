import from jaclang.compiler.expr_keys { type_tag_borrows }


impl NaIRGenPass._devirt_closed_world(arch_name: str) -> bool {
    arch = self.arch_ast_map.get(arch_name);
    if arch is None {
        return False;
    }
    return arch.access_type == SymbolAccess.PRIVATE;
}

impl NaIRGenPass._native_archetypes(module: uni.Module) -> list[uni.Archetype] {
    result: dict[(str, uni.Archetype)] = {};

    for stmt in ModuleFacts.iter_context_stmts(module, CodeContext.NATIVE) {
        if isinstance(stmt, uni.Archetype) {
            aname = stmt.name.value if stmt.name else "unknown";
            if aname not in result or stmt.body is not None {
                result[aname] = stmt;
            }
        }
    }

    for arch in ModuleFacts.shared_archetypes_for_context(module, CodeContext.NATIVE) {
        aname = arch.name.value if arch.name else "unknown";
        if aname not in result {
            result[aname] = arch;
        }
    }

    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.module, self.prog);
    out: list[uni.Archetype] = [];
    for a in result.values() {
        if a.type_params {
            aname = a.name.value if a.name else "unknown";
            if layout_reg.get_layout(aname) is None {
                continue;
            }
        }
        out.append(a);
    }
    return out;
}

impl NaIRGenPass._forward_declare_archetype_names(module: uni.Module) -> None {
    for arch in self._native_archetypes(module) {
        aname = arch.name.value if arch.name else None;
        if aname is not None and aname not in self.struct_types {
            struct_type = self.llvm_module.context.get_identified_type(aname);
            self.struct_types[aname] = struct_type;
        }
    }
}

impl NaIRGenPass._register_archetypes(module: uni.Module) -> None {
    archetypes: list[uni.Archetype] = self._native_archetypes(module);
    arch_map: dict[(str, uni.Archetype)] = {};
    for arch in archetypes {
        arch_map[arch.name.value if arch.name else "unknown"] = arch;
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        struct_type = self.llvm_module.context.get_identified_type(arch_name);
        self.struct_types[arch_name] = struct_type;
        self.has_native_code = True;
    }

    self._compute_osp_model(archetypes);

    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    layout_reg = get_layout_registry(self.module, self.prog);
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self.arch_ast_map[arch_name] = arch;
    }

    topo_order = layout_reg.get_topo_order();
    for topo_name in topo_order {
        if topo_name in arch_map {
            self._codegen_archetype(arch_map[topo_name]);
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                        and isinstance(stmt.signature, uni.FuncSignature) {
                        self._forward_declare_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
                        method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                        if method_name is not None {
                            full_name = f"{arch_name}.{method_name}";
                            struct_ptr = self.struct_types[arch_name].as_pointer();
                            fnty = ir.FunctionType(ir.VoidType(), [struct_ptr]);
                            func = ir.Function(self.llvm_module, fnty, name=full_name);
                            func.args[0].name = "self";
                            self.func_symtab[full_name] = func;
                            self.method_funcs[full_name] = func;
                            self.has_native_code = True;
                        }
                    } elif isinstance(stmt.signature, uni.EventSignature) {
                        self._forward_declare_event_method(arch_name, stmt);
                        if arch.arch_kind is not None {
                            self._emit_osp_thunk(arch_name, stmt);
                        }
                    } else {
                        _sig_kind = (
                            type(stmt.signature).__name__
                                if stmt.signature is not None
                                else "no-signature"
                        );
                        _m_name = stmt.name_ref.sym_name if stmt.name_ref else "?";
                        self.ctx.emit(
                            E5092,
                            node_override=stmt,
                            kind="archetype method",
                            name=f"{arch_name}.{_m_name} ({_sig_kind})"
                        );
                    }
                }
            }
        }
        for (_slot, _accvar, _acc) in archetype_accessors(arch) {
            self._forward_declare_method(arch_name, _acc, field=_accvar);
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        self._emit_struct_release_fn(arch_name);
        self._emit_trace_fn(arch_name);
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=True);
    }

    for topo_name in topo_order {
        if self._arch_has_vtable(topo_name) {
            self._build_vtable(topo_name);
        }
    }

    import from jaclang.compiler.passes.layout_pass { get_layout_registry as _no_glr }
    _no_reg = _no_glr(self.module, self.prog);
    for (base_name, layout) in self.vtable_layouts.items() {
        if not self._devirt_closed_world(base_name) {
            continue;
        }
        non_overridden: set[str] = set();
        _no_base_lay = _no_reg.get_layout(base_name);
        for method_name in layout {
            defining_class = self._resolve_method_owner(base_name, method_name);
            if defining_class is None {
                continue;
            }
            _no_base_owner = defining_class;
            if _no_base_lay is not None {
                _no_bmi = _no_base_lay.method_index.get(method_name);
                if _no_bmi is not None and _no_bmi < len(_no_base_lay.methods) {
                    _no_base_owner = _no_base_lay.methods[_no_bmi].owner
                        or defining_class;
                }
            }

            overridden = False;
            for child_name in _no_reg.mro_order {
                if child_name == base_name
                    or base_name not in _no_reg.get_mro(child_name) {
                    continue;
                }
                _no_cl = _no_reg.get_layout(child_name);
                if _no_cl is None {
                    continue;
                }
                _no_cmi = _no_cl.method_index.get(method_name);
                if _no_cmi is None or _no_cmi >= len(_no_cl.methods) {
                    continue;
                }
                if _no_cl.methods[_no_cmi].owner != _no_base_owner {
                    overridden = True;
                    break;
                }
                child_arch = self.arch_ast_map.get(child_name);
                if child_arch is not None and child_arch.body is not None {
                    for stmt in child_arch.body {
                        if isinstance(stmt, uni.Ability) {
                            mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                            if mn == method_name {
                                overridden = True;
                                break;
                            }
                        }
                    }
                }
                if not overridden and child_arch is not None {
                    for (_slot, _accvar, _acc) in archetype_accessors(child_arch) {
                        if _slot == method_name {
                            overridden = True;
                            break;
                        }
                    }
                }
                if overridden {
                    break;
                }
            }
            if not overridden {
                non_overridden.add(method_name);
            }
        }
        if non_overridden {
            self._non_overridden_methods[base_name] = non_overridden;
        }
    }

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if self._arch_has_vtable(arch_name) {
            self._emit_vtable_global(arch_name);
        }
    }

    self._forward_declare_functions(module);

    self._register_osp_kernel_module();
    self._emit_osp_setup();
    import from jaclang.compiler.native_scope { scope_lowering_active }
    if scope_lowering_active() {
        self.module.gen.jc_layout = self._build_jc_layout();
    }

    self._predemote_capability_constructors();
    self._codegen_constructors_first(archetypes);

    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is not None {
            for stmt in arch.body {
                if isinstance(stmt, uni.Ability) {
                    if stmt.signature is not None
                        and isinstance(stmt.signature, uni.FuncSignature) {
                        self._codegen_method(arch_name, stmt);
                    } elif isinstance(stmt.signature, uni.EventSignature) {
                        self._codegen_event_method(arch_name, stmt);
                    } elif stmt.signature is None and stmt.body is not None {
                        self._codegen_no_sig_method(arch_name, stmt);
                    }
                }
            }
        }
        for (_slot, _accvar, _acc) in archetype_accessors(arch) {
            self._codegen_method(arch_name, _acc, field=_accvar);
        }
    }

    for arch in archetypes {
        self._visit_nonprimary_ancestor_methods(arch, declare=False);
    }

    self._generate_inherited_method_wrappers();
}

impl NaIRGenPass._constructor_slots -> tuple[str, ...] {
    return ("init", "__init__", "postinit", "__post_init__", );
}

impl NaIRGenPass._constructor_ability_for(cls: str, slot: str) -> (uni.Ability | None) {
    for _cn in self._mro_of(cls) {
        _arch = self.arch_ast_map.get(_cn);
        if _arch is None or _arch.body is None {
            continue;
        }
        for _st in _arch.body {
            if isinstance(_st, uni.Ability)
                and _st.name_ref is not None
                and _st.name_ref.sym_name == slot {
                return _st;
            }
        }
    }
    return None;
}

impl NaIRGenPass._predemote_capability_constructors -> None {
    """Demote capability-blocked constructors before any body is lowered.

    Every other seam demotes at its own body-codegen point, which is enough
    because a call site that binds too early still resolves its callee by name.
    A construction site does not: it reads `init`/`postinit` straight out of
    `method_funcs` while lowering some OTHER archetype's body, so a constructor
    that only demoted later would already have been bound -- silently, to what
    becomes an abort stub. Running the constructor half of the capability
    partition up front makes the refusal independent of which archetype the
    backend reaches first.
    """;
    if not self._capability_demotions {
        return;
    }
    _slots = self._constructor_slots();
    for _full in list(self.method_funcs.keys()) {
        (_cls, _dot, _slot) = _full.rpartition(".");
        if not _dot or _slot not in _slots {
            continue;
        }
        _ability = self._constructor_ability_for(_cls, _slot);
        if _ability is None {
            continue;
        }
        _viols = self._capability_demotions.get(id(_ability));
        if _viols is None {
            continue;
        }
        _func = self.method_funcs.get(_full);
        if _func is None {
            continue;
        }
        self._claimed_capability_demotions.add(id(_ability));
        self._predemote_capability_unit(
            _full,
            _func,
            _viols,
            keep_func=_slot in self.vtable_method_indices.get(_cls, {})
        );
    }
}

impl NaIRGenPass._codegen_constructors_first(archetypes: list[uni.Archetype]) -> None {
    """Lower every constructor body before any other body is lowered.

    The companion to `_predemote_capability_constructors`, for the demotions
    the capability partition cannot predict: a structured error or an emitter
    exception while lowering a constructor. Those only surface at the
    constructor's own codegen point, and a construction site lowered before
    that point would already hold a direct reference to what becomes an abort
    stub. Lowering constructors first means every non-constructor body sees a
    settled answer from `_demoted_init_of`. A constructor that constructs
    another class whose constructor demotes later in this same pass is the one
    case left, and it is bounded by construction order among constructors.
    """;
    _slots = self._constructor_slots();
    for arch in archetypes {
        arch_name = arch.name.value if arch.name else "unknown";
        if arch.body is None {
            continue;
        }
        for stmt in arch.body {
            if isinstance(stmt, uni.Ability)
                and isinstance(stmt.signature, uni.FuncSignature)
                and stmt.name_ref is not None
                and stmt.name_ref.sym_name in _slots {
                self._codegen_method(arch_name, stmt);
            }
        }
    }
}

impl NaIRGenPass._demoted_init_of(type_name: str) -> (str | None) {
    """The demoted initializer a `type_name()` would have needed, or None.

    Walks the MRO the way the construction site does and stops at the first
    class that provides an initializer at all, so a live `init` on a subclass
    still wins over a demoted one further up. The skipped-methods check comes
    first per candidate because a demotion that kept its function (a virtual
    slot) leaves the abort stub sitting in `method_funcs`.
    """;
    if not self._native_skipped_methods {
        return None;
    }
    for _cn in self._mro_of(type_name) {
        for _mn in ("init", "__init__") {
            _cand = f"{_cn}.{_mn}";
            if _cand in self._native_skipped_methods {
                return _cand;
            }
            if _cand in self.method_funcs {
                return None;
            }
        }
    }
    return None;
}

impl NaIRGenPass._visit_nonprimary_ancestor_methods(
    arch: uni.Archetype, declare: bool
) -> None {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    import from jaclang.compiler.symbol_utils { collect_method_names }
    layout_reg = get_layout_registry(self.module, self.prog);
    arch_name = arch.name.value if arch.name else "unknown";
    mro = self._mro_of(arch_name);
    if len(mro) < 2 {
        return;
    }
    provided_methods = collect_method_names(arch);
    for anc in mro[1:] {
        if layout_reg.is_primary_ancestor(arch_name, anc) {
            anc_arch = self.arch_ast_map.get(anc);
            if anc_arch is not None {
                provided_methods.update(collect_method_names(anc_arch));
            }
        }
    }
    for ancestor_name in mro[1:] {
        if layout_reg.is_primary_ancestor(arch_name, ancestor_name) {
            continue;
        }
        ancestor_arch = self.arch_ast_map.get(ancestor_name);
        if ancestor_arch is None or ancestor_arch.body is None {
            continue;
        }
        for stmt in ancestor_arch.body {
            if isinstance(stmt, uni.Ability)
                and stmt.signature is not None
                and isinstance(stmt.signature, uni.FuncSignature) {
                method_name = stmt.name_ref.sym_name if stmt.name_ref else None;
                if method_name is not None and method_name not in provided_methods {
                    full_name = f"{arch_name}.{method_name}";
                    if declare and full_name not in self.method_funcs {
                        self._forward_declare_method(arch_name, stmt);
                    } elif not declare and full_name in self.method_funcs {
                        self._codegen_method(arch_name, stmt);
                    }
                    provided_methods.add(method_name);
                }
            }
        }

        for (_slot, _accvar, _acc) in archetype_accessors(ancestor_arch) {
            if _slot in provided_methods {
                continue;
            }
            full_name = f"{arch_name}.{_slot}";
            if declare and full_name not in self.method_funcs {
                self._forward_declare_method(arch_name, _acc, field=_accvar);
            } elif not declare and full_name in self.method_funcs {
                self._codegen_method(arch_name, _acc, field=_accvar);
            }
            provided_methods.add(_slot);
        }
    }
}

impl NaIRGenPass._codegen_archetype(nd: uni.Archetype) -> None {
    arch_name = (nd).name.value if (nd).name else "unknown";
    if arch_name in self.struct_field_types {
        return;
    }
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None {
        return;
    }
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _owner_mod = nd.find_parent_of_type(uni.Module) or self.module;
    layout = get_layout_registry(_owner_mod, self.prog).get_layout(arch_name);
    if layout is None {
        return;
    }

    field_types: list[ir.Type] = [];
    field_index_map: dict[(str, int)] = {};
    field_type_map: dict[(str, ir.Type)] = {};
    field_default_map: dict[str, uni.Expr] = {};
    foreign_fields: set = set();
    erased_tv_fields: dict[str, list[str]] = {};

    if layout.vtable_ptr_slot is not None {
        field_types.append(ir.IntType(8).as_pointer().as_pointer());
    }
    if layout.type_tag_slot is not None {
        field_types.append(ir.IntType(64));
        self.osp_type_tag_field[arch_name] = layout.type_tag_slot;
    }
    if layout.reports_slot is not None {
        self._emit_list_helpers("jacval", self.jacval_type);
        _rep_lt = self.list_types.get("jacval");
        if _rep_lt is not None {
            field_types.append(_rep_lt.as_pointer());
            field_index_map["reports"] = layout.reports_slot;
            field_type_map["reports"] = _rep_lt.as_pointer();
            self.osp_reports_field[arch_name] = layout.reports_slot;
        }
    }

    self.parent_field_start[arch_name] = dict(layout.parent_field_start);

    for finfo in layout.fields {
        fname = finfo.name;
        var = finfo.decl_node;
        ftype: ir.Type = ir.IntType(64);
        if isinstance(var, uni.HasVar) and type_tag_borrows(var.type_tag) {
            if arch_name not in self.struct_field_borrow {
                self.struct_field_borrow[arch_name] = set();
            }
            self.struct_field_borrow[arch_name].add(fname);
        }
        if isinstance(var, uni.TypeParam) {
            ftype = self._resolve_jac_type(var.bound);
        } elif isinstance(var, uni.HasVar) and var.type_tag is not None {
            if finfo.owner in self.clib_struct_names {
                _cf_fnty = False;
                try {
                    import from jaclang.compiler.types.types {
                        FunctionType as _ClibFnType
                    }
                    _cf_fnty = isinstance(var?.type, _ClibFnType);
                } except ImportError {}
                if _cf_fnty {
                    ftype = self._lower_clib_function_type(arch_name, fname, var.type);
                } else {
                    ftype = self._resolve_jac_type(var.type_tag);
                }
            } else {
                _fld_mark = len(self.ctx.errors_had);
                ftype = self._resolve_field_type(var);
                _opaque = self._opaque_field_if_unlowerable(
                    arch_name, fname, _fld_mark
                );
                if _opaque is not None {
                    ftype = _opaque;
                    foreign_fields.add(fname);
                }
                if self._foreign_optional_field(var?.type) {
                    foreign_fields.add(fname);
                }
                _etv = self._erased_typevar_names(var?.type);
                if _etv {
                    erased_tv_fields[fname] = _etv;
                }
                if self._nogc_headerless()
                    and self._hasvar_is_own(var)
                    and isinstance(ftype, ir.PointerType) {
                    _fpn = getattr(ftype.pointee, "name", "") or "";
                    _fstruct = self.struct_types.get(_fpn);

                    if _fstruct is not None
                        and _fstruct.is_opaque
                        and _fpn != arch_name
                        and self._arch_is_acyclic(_fpn)
                        and _fpn in self.arch_ast_map {
                        self._codegen_archetype(self.arch_ast_map[_fpn]);
                    }
                    if _fstruct is not None
                        and _fpn != arch_name
                        and _fstruct?.elements is not None
                        and self._arch_is_acyclic(_fpn)
                        and not self._arch_is_osp_name(_fpn)
                        and _fpn not in self.clib_vtable_structs {
                        ftype = _fstruct;
                        if arch_name not in self.struct_field_inline {
                            self.struct_field_inline[arch_name] = set();
                        }
                        self.struct_field_inline[arch_name].add(fname);
                    }
                }
            }
            _ftag = var.type_tag.tag;
            ftag_name = self._get_name(_ftag);
            if ftag_name is not None and ftag_name in self.enum_types {
                if arch_name not in self.struct_field_enum_type {
                    self.struct_field_enum_type[arch_name] = {};
                }
                self.struct_field_enum_type[arch_name][fname] = ftag_name;
            }
            _fek = self._elem_keys_of_annotation(_ftag);
            if _fek {
                if arch_name not in self.struct_field_elem_keys {
                    self.struct_field_elem_keys[arch_name] = {};
                }
                self.struct_field_elem_keys[arch_name][fname] = _fek;
            }
        }
        field_types.append(ftype);
        field_index_map[fname] = finfo.index;
        field_type_map[fname] = ftype;

        if isinstance(var, uni.HasVar)
            and var.value is not None
            and fname not in foreign_fields {
            field_default_map[fname] = var.value;
        }
    }

    if (nd).body is not None {
        for stmt in (nd).body {
            if isinstance(stmt, uni.ArchHas) and stmt.is_static {
                self._register_static_fields(arch_name, stmt);
            } elif isinstance(stmt, uni.ModuleCode) {
                self._register_class_consts(nd, arch_name, stmt);
            }
        }
    }

    for (_esn, _esv) in self._erased_sig_typevars(nd).items() {
        if _esn not in erased_tv_fields {
            erased_tv_fields[_esn] = _esv;
        }
    }

    assert struct_type is not None;
    if arch_name not in self.clib_struct_names or struct_type.is_opaque {
        struct_type.set_body(*field_types);
    }
    self.struct_field_indices[arch_name] = field_index_map;
    self.struct_field_order[arch_name] = [f.name for f in layout.fields];
    import from jaclang.compiler.field_semantics { positional_field_names }
    constructor_fields: list[uni.HasVar] = [];
    for field in layout.fields {
        declaration = field.decl_node;
        if isinstance(declaration, uni.HasVar) {
            constructor_fields.append(declaration);
        }
    }
    self.struct_constructor_order[arch_name] = positional_field_names(
        constructor_fields
    );
    self.struct_field_types[arch_name] = field_type_map;
    self.struct_field_defaults[arch_name] = field_default_map;
    self.struct_field_foreign[arch_name] = foreign_fields;
    self.struct_field_erased_tv[arch_name] = erased_tv_fields;
    self.arch_type_params[arch_name] = [
        tp.name.value
        for tp in (nd.type_params or [])
        if tp?.name is not None
    ];
}

impl NaIRGenPass._erased_sig_typevars(nd: uni.Archetype) -> dict[str, list[str]] {
    """The type params a method signature erases, keyed by the slot naming it.

    A sequence of `T` in a signature lays out as the pointer-flavoured list,
    exactly as a bare `T` lays out as a raw pointer, so an instantiation at a
    by-value type is as unsound there as it is in a field. Recording those
    slots alongside the erased fields lets the construction site refuse both
    with one rule.
    """;
    out: dict[str, list[str]] = {};
    if nd.body is None {
        return out;
    }
    for stmt in nd.body {
        if not isinstance(stmt, uni.Ability)
            or not isinstance(stmt.signature, uni.FuncSignature) {
            continue;
        }
        _mname = stmt.name_ref.sym_name if stmt.name_ref else "unnamed";
        for p in stmt.signature.get_parameters() {
            param_type = p.type;
            if p.type_tag is None
                or not isinstance(param_type, ClassType)
                or self._erased_seq_type(param_type) is None {
                continue;
            }
            _pname = p.name.value if p.name else "arg";
            _star = "*" if p.is_vararg else "";
            out[f"{_mname}({_star}{_pname})"] = self._erased_typevar_names(
                (param_type.private.type_args or [None])[0]
            );
        }
    }
    return out;
}

impl NaIRGenPass._reject_scalar_type_args(nd: uni.UniNode, type_name: str) -> bool {
    _erased: any = self.struct_field_erased_tv.get(type_name) or {};
    if not _erased {
        return False;
    }
    _params: any = self.arch_type_params.get(type_name) or [];
    if not _params {
        return False;
    }
    _args = self._container_type_args(nd?.type);
    if not _args {
        return False;
    }
    for (fname, tv_names) in _erased.items() {
        for tv_name in tv_names {
            if tv_name not in _params {
                continue;
            }
            _idx = _params.index(tv_name);
            if _idx >= len(_args) {
                continue;
            }
            _solved = self._lower_type(_args[_idx]);
            if _solved is None or isinstance(_solved, ir.PointerType) {
                continue;
            }
            return self._emit_scalar_type_arg_refusal(
                nd, type_name, fname, tv_name, _args[_idx]
            );
        }
    }
    return False;
}

impl NaIRGenPass._emit_scalar_type_arg_refusal(
    nd: uni.UniNode, type_name: str, fname: str, tv_name: str, arg: any
) -> bool {
    self.ctx.emit(
        E5092,
        node_override=nd,
        kind="type argument",
        name=f"{type_name}[{arg}]",
        help_text=(
            f"A generic archetype is type-erased natively: one struct is "
            f"shared by every instantiation, so a slot typed by '{tv_name}' "
            f"-- here '{type_name}.{fname}' -- is a raw pointer. A pointer "
            f"slot cannot carry '{arg}', whose native representation is a "
            f"value rather than a reference, and for an optional slot the "
            f"null that spells None would alias a zero payload. Instantiate "
            f"'{type_name}' at an archetype type, or declare '{fname}' with "
            f"a concrete type."
        )
    );
    return True;
}

impl NaIRGenPass._register_static_fields(arch_name: str, archhas: uni.ArchHas) -> None {
    for var in archhas.vars {
        fname = var.name.value if var.name else "field";
        full_name = f"{arch_name}.{fname}";
        if full_name in self.static_fields {
            continue;
        }
        ftype: ir.Type = ir.IntType(64);
        if var.type_tag is not None {
            ftype = self._resolve_decl_type(var.type_tag, var.value);
        } elif var.value is not None {
            inferred = self._infer_global_init_type(var.value);
            if inferred is not None {
                ftype = inferred;
            }
        }

        if full_name in self.llvm_module.globals {
            continue;
        }
        gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);

        gv.linkage = "";
        const_init = self._codegen_const_expr(var.value, ftype)
            if var.value is not None
            else None;
        if const_init is not None {
            gv.initializer = const_init;
        } else {
            gv.initializer = ir.Constant(ftype, None);
        }
        self.static_fields[full_name] = gv;
        self.static_field_types[full_name] = ftype;
        self.global_vars[full_name] = gv;
        self.global_var_types[full_name] = ftype;
        self.has_native_code = True;

        if var.value is not None and const_init is None {
            if not self?._global_init_nodes {
                self._global_init_nodes: list[tuple[str, uni.Expr, ir.Type]] = [];
            }
            self._global_init_nodes.append((full_name, var.value, ftype));
        }
    }
}

impl NaIRGenPass._register_class_consts(
    nd: uni.Archetype, arch_name: str, block: uni.ModuleCode
) -> None {
    import from jaclang.compiler.passes.layout_pass { class_form_enum_scalar }
    if nd.name is None or class_form_enum_scalar(nd.name.type) is not None {
        return;
    }
    _owns = nd.find_parent_of_type(uni.Module) is self.module;
    for stmt in (block.body or []) {
        if not isinstance(stmt, uni.Assignment) or stmt.value is None {
            continue;
        }
        _targets = stmt.target
            if isinstance(stmt.target, (list, tuple))
            else [(stmt.target)];
        for _t in _targets {
            _fname = self._get_name(_t);
            if _fname is None {
                continue;
            }
            self._register_one_class_const(arch_name, _fname, _t, stmt, _owns);
        }
    }
}

impl NaIRGenPass._register_one_class_const(
    arch_name: str, fname: str, target: uni.UniNode, assign: uni.Assignment, owns: bool
) -> None {
    value = assign.value;
    if value is None {
        return;
    }
    full_name = f"{arch_name}.{fname}";
    if full_name in self.static_fields or full_name in self.llvm_module.globals {
        return;
    }
    ftype = self._infer_global_init_type(target)
        if assign.type_tag is not None
        else None;
    if ftype is None {
        ftype = self._infer_global_init_type(value);
    }
    if ftype is None {
        return;
    }
    gv = ir.GlobalVariable(self.llvm_module, ftype, name=full_name);
    gv.linkage = "";
    self.static_fields[full_name] = gv;
    self.static_field_types[full_name] = ftype;
    self.global_vars[full_name] = gv;
    self.global_var_types[full_name] = ftype;
    self.has_native_code = True;
    if not owns {
        return;
    }
    const_init = self._codegen_const_expr(value, ftype);
    if const_init is None {
        const_init = self._class_const_enum_init(value, ftype);
    }
    gv.initializer = const_init if const_init is not None else ir.Constant(ftype, None);

    if const_init is None {
        if not self?._global_init_nodes {
            self._global_init_nodes: list[tuple[str, uni.Expr, ir.Type]] = [];
        }
        self._global_init_nodes.append((full_name, assign.value, ftype));
    }
}

impl NaIRGenPass._class_const_enum_init(
    value: uni.UniNode, ftype: ir.Type
) -> (ir.Constant | None) {
    if not isinstance(value, uni.AtomTrailer) {
        return None;
    }
    _cls = self._get_name(value.target);
    _mem = self._get_name(value.right);
    if _cls is None or _mem is None {
        return None;
    }
    _full = f"{_cls}.{_mem}";
    if _full not in self.enum_values {
        self._codegen_enum_layout(_cls, None);
    }
    _val: ir.Value | None = self.enum_values.get(_full);
    if _val is None {
        _val = self._codegen_class_form_enum_member(value);
    }
    if not isinstance(_val, ir.Constant) or not isinstance(ftype, ir.IntType) {
        return None;
    }
    return ir.Constant(ftype, _val.constant);
}

impl NaIRGenPass._method_slot_name(
    method: uni.Ability, field: (uni.HasVar | None)
) -> str {
    if field is not None {
        _fname = field.name.value if field.name else "field";
        _slot = accessor_slot_name(_fname, method);
        if _slot is not None {
            return _slot;
        }
    }
    return method.name_ref.sym_name if method.name_ref else "unnamed";
}

impl NaIRGenPass._method_receiver_type(arch_name: str) -> ir.Type | None {
    enum_type = self.enum_types.get(arch_name);
    if enum_type is not None {
        return enum_type;
    }
    arch = self.arch_ast_map.get(arch_name);
    if arch is not None {
        scalar = self._ensure_enum_lowered(arch.name.type);
        if scalar is not None {
            return scalar;
        }
    }
    struct_type = self.struct_types.get(arch_name);
    return struct_type.as_pointer() if struct_type is not None else None;
}

impl NaIRGenPass._forward_declare_method(
    arch_name: str,
    method: uni.Ability,
    field: (uni.HasVar | None) = None,
    imported: bool = False
) -> None {
    if method.is_comptime {
        return;
    }
    method_name = self._method_slot_name(method, field);
    full_name = f"{arch_name}.{method_name}";

    if method.type_params {
        self._generic_methods[full_name] = method;
        self.has_native_code = True;
        return;
    }
    if full_name in self.method_funcs {
        return;
    }
    if full_name in self._native_skipped_methods {
        return;
    }
    sig = method.signature;
    receiver_type = self._method_receiver_type(arch_name);
    if receiver_type is None or (sig is None and field is None) {
        return;
    }

    _is_static = method.is_static or method.is_classmethod;

    _m_params = sig.get_parameters() if isinstance(sig, uni.FuncSignature) else [];
    if (
        not _is_static
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "self"
    ) {
        _m_params = _m_params[1:];
    }
    if (
        method.is_classmethod
        and _m_params
        and _m_params[0].name
        and _m_params[0].name.value == "cls"
    ) {
        _m_params = _m_params[1:];
    }

    _sig_mark = len(self.ctx.errors_had);
    _saved_sig_kind = self._sig_decl_kind;
    self._sig_decl_kind = "signature type";

    param_types: list[ir.Type] = [] if _is_static else [receiver_type];
    for p in _m_params {
        param_types.append(
            self._resolve_sig_type(p) if p.type_tag is not None else ir.IntType(64)
        );
    }

    ret_type = self._resolve_sig_type(sig.return_type)
        if isinstance(sig, uni.FuncSignature)
        else ir.IntType(64);

    if sig is None and field is not None {
        if method.accessor_kind == "property" {
            ret_type = self._resolve_sig_type(field);
        } elif method.accessor_kind == "setter" {
            param_types.append(self._resolve_sig_type(field));
        }
    }
    self._sig_decl_kind = _saved_sig_kind;
    fnty = ir.FunctionType(ret_type, param_types);
    func = ir.Function(self.llvm_module, fnty, name=full_name);

    _base = 0 if _is_static else 1;
    if not _is_static {
        func.args[0].name = "self";
    }
    for (i, p) in enumerate(_m_params) {
        func.args[i + _base].name = p.name.value if p.name else f"arg{i}";
    }
    if len(func.args) > _base + len(_m_params) {
        func.args[_base + len(_m_params)].name = "value";
    }
    self._apply_ownership_param_attrs(func, _m_params, _base);
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
    self._record_linked_decl(func, method);
    if _is_static {
        self.static_methods[full_name] = True;
    }

    if len(self.ctx.errors_had) > _sig_mark {
        self._demote_method_if_unlowerable(
            full_name,
            func,
            _sig_mark,
            keep_func=method_name in self.vtable_method_indices.get(arch_name, {}),
            stub_body=not imported
        );
    }
}

impl NaIRGenPass._codegen_method(
    arch_name: str,
    method: uni.Ability,
    symbol_override: (str | None) = None,
    field: (uni.HasVar | None) = None
) -> None {
    if method.is_comptime {
        return;
    }
    method_name = self._method_slot_name(method, field);

    full_name = symbol_override or f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }
    if full_name in self._native_skipped_methods or func.blocks {
        return;
    }

    _pre_viols = self._capability_demotions.get(id(method));
    if _pre_viols is not None {
        self._claimed_capability_demotions.add(id(method));
        _pre_virtual = method_name in self.vtable_method_indices.get(arch_name, {});
        if self._predemote_capability_unit(
            full_name, func, _pre_viols, keep_func=_pre_virtual
        ) {
            return;
        }
    }

    state = self._enter_function(func);
    try {
        self._self_arch = arch_name;

        self._attach_di_subprogram(
            func, full_name, method.loc.first_line if method.loc else 0
        );

        _scan_body = ModuleFacts.unwrap_body(method);
        if _scan_body is not None {
            _scan_owner = method.body
                if isinstance(method.body, uni.ImplDef)
                else method;
            self._scan_closure_escapes(_scan_owner, _scan_body);
        }

        _is_static = method.is_static or method.is_classmethod;
        _base = 0;
        sig = method.signature;
        _body_params = sig.get_parameters()
            if isinstance(sig, uni.FuncSignature)
            else [];
        _self_param: (uni.ParamVar | None) = None;
        if (
            not _is_static
            and _body_params
            and _body_params[0].name
            and _body_params[0].name.value == "self"
        ) {
            _self_param = _body_params[0];
            _body_params = _body_params[1:];
        }
        self._self_owned = _self_param is not None
            and self._nogc_owned_param(_self_param);
        if not _is_static {
            self._bind_function_parameter(
                "self", func.args[0], borrowed=not self._self_owned
            );
            _base = 1;
        }
        if (
            method.is_classmethod
            and _body_params
            and _body_params[0].name
            and _body_params[0].name.value == "cls"
        ) {
            _body_params = _body_params[1:];
        }

        _bound_params: list[tuple[(str, bool)]] = [
            (
                (p.name.value if p.name else f"arg{i}"),
                bool(p.name?.sym?.param_rebound),

            ) for (i, p) in enumerate(_body_params)
        ];
        if sig is None and len(func.args) > _base + len(_bound_params) {
            _bound_params.append(("value", False, ));
        }
        for (i, (param_name, _p_rebound)) in enumerate(_bound_params) {
            arg_val = func.args[i + _base];
            self._bind_function_parameter(param_name, arg_val, rebound=_p_rebound);
        }

        _is_virtual = method_name in self.vtable_method_indices.get(arch_name, {});
        _local_mark = len(self.ctx.errors_had);

        try {
            body = ModuleFacts.unwrap_body(method);
            if body is not None {
                self._codegen_body(body);
            }

            if not self.builder.block.is_terminated {
                _mth_loc = f"{os.path.basename(self.module.loc.mod_path)}:{method.loc.last_line
                    if method.loc
                    else 0}";

                self._emit_scope_cleanup(skip_var=None, loc=_mth_loc);
                ret_type = func.return_value.type;
                if isinstance(ret_type, ir.VoidType) {
                    self.builder.ret_void();
                } else {
                    self.builder.ret(self._zero_const(ret_type));
                }
            }

            self._finalize_di_locations(
                func, method.loc.first_line if method.loc else 1
            );
        } except Exception as _codegen_exc {
            if self._na_debug_on() {
                import sys;
                import traceback;
                sys.stderr.write(f"NA_DEBUG raise {full_name}\n");
                traceback.print_exc(file=sys.stderr);
            }
            self.ctx.emit(
                E5092,
                node_override=method,
                kind="method (native emitter error in)",
                name=full_name,
                help_text=f"The native backend raised {type(_codegen_exc).__name__} "
                f"while lowering this method; it falls back to its Python "
                f"implementation. Original error: {_codegen_exc}"
            );
        }
    } finally {
        self._leave_function(state);
    }

    self._demote_method_if_unlowerable(
        full_name, func, _local_mark, keep_func=_is_virtual
    );
}

impl NaIRGenPass._demote_method_if_unlowerable(
    full_name: str,
    func: ir.Function,
    local_mark: int,
    keep_func: bool = False,
    stub_body: bool = True
) -> bool {
    if len(self.ctx.errors_had) <= local_mark {
        return False;
    }
    _own = list(self.ctx.errors_had[local_mark:]);

    _na_debug = self._na_debug_on();
    if self._seam_warnings_on()
        and not self.prog.options.native_required_for(self.module.loc.mod_path) {
        import from jaclang.cli.console { console }
        _why = "; ".join(str(e) for e in _own);
        console.warning(
            f"native seam -- demoting {full_name} to Python-only "
            f"(un-lowerable): {_why}"
        );
    }
    if _na_debug {
        import sys;
        sys.stderr.write(f"NA_DEBUG demote {full_name}\n");
        for _diag in _own {
            sys.stderr.write(f"NA_DEBUG   {_diag.pretty_print()}\n");
        }
    }
    if stub_body {
        try {
            import from jaclang.compiler.driver.na_coverage { na_coverage_seam }
            _first_code = _own[0].code.code if _own[0].code is not None else "";
            _code_tag = f"[{_first_code}] " if _first_code else "";
            na_coverage_seam(
                self.module.loc.mod_path,
                f"{full_name}: {_code_tag}" + str(_own[0]).split('\n')[0]
            );
        } except Exception {}
    }
    if not self.prog.options.native_required_for(self.module.loc.mod_path) {
        del self.ctx.errors_had[local_mark:];
    }

    if stub_body {
        NativeLoweringIssue(
            symbol=full_name,
            kind=NativeLoweringKind.CALLABLE,
            source=self.module.loc.mod_path,
            code=_own[0].code.code if _own[0].code is not None else "",
            detail=_own[0].pretty_print()
        ).record(
            self.llvm_module
        );
        func.blocks.clear();
        blk = func.append_basic_block(name="entry");
        b = ir.IRBuilder(blk);
        self._get_or_declare_extern("abort", ir.VoidType(), []);
        b.call(self.extern_funcs["abort"], []);
        b.unreachable();
    }
    if not keep_func {
        self.method_funcs.pop(full_name, None);
    }
    self.func_symtab.pop(full_name, None);
    self._native_skipped_methods.add(full_name);
    return True;
}

impl NaIRGenPass._seam_warnings_on -> bool {
    """Whether a seam this run takes should also be announced on stderr.""";
    if self._na_debug_on() or bool(self.prog.options.native_debug) {
        return True;
    }
    try {
        import from jaclang.project.config { get_config }
        _cfg = get_config();
        if _cfg and _cfg.check {
            return bool(_cfg.check.warn_native_seams);
        }
    } except Exception {}
    return True;
}

impl NaIRGenPass._opaque_field_if_unlowerable(
    arch_name: str, fname: str, local_mark: int
) -> (ir.Type | None) {
    """Spend a field declaration's refusal on the field, not on the module.

    A `has` type with no native layout sits outside every ability body, so
    `_demote_method_if_unlowerable` has nothing to take it from and the
    diagnostic used to survive to the end of the run, where a non-empty
    `errors_had` withholds the module's IR. The declaration owns it here the
    way #8285 made a signature's declaration own its own: the slot erases to
    an opaque pointer, the field is recorded so that every read and write of
    it refuses inside the callable that performs it, and the refusal is
    re-published as a coverage seam keyed on the field rather than swallowed.

    An erased slot is storage the native side never writes, so the field also
    joins `struct_field_foreign` -- the constructor, the tracer, the arena and
    the reference counter all already skip that set.
    """;
    if len(self.ctx.errors_had) <= local_mark {
        return None;
    }
    _own = list(self.ctx.errors_had[local_mark:]);
    _first = _own[0];
    _code = _first.code.code if _first.code is not None else "";
    _why = str(_first).split('\n')[0];

    if self._seam_warnings_on()
        and not self.prog.options.native_required_for(self.module.loc.mod_path) {
        import from jaclang.cli.console { console }
        console.warning(
            f"native seam -- erasing field {arch_name}.{fname} to an "
            f"opaque slot (un-lowerable declaration): "
                + "; ".join(str(e) for e in _own)
        );
    }
    try {
        import from jaclang.compiler.driver.na_coverage { na_coverage_seam }
        na_coverage_seam(
            self.module.loc.mod_path,
            f"{arch_name}.{fname}: " + (f"[{_code}] " if _code else "") + _why
        );
    } except Exception {}
    NativeLoweringIssue(
        symbol=f"{arch_name}.{fname}",
        kind=NativeLoweringKind.FIELD,
        source=self.module.loc.mod_path,
        code=_code,
        detail=_own[0].pretty_print()
    ).record(
        self.llvm_module
    );
    if not self.prog.options.native_required_for(self.module.loc.mod_path) {
        del self.ctx.errors_had[local_mark:];
    }
    if arch_name not in self.struct_field_opaque {
        self.struct_field_opaque[arch_name] = {};
    }
    self.struct_field_opaque[arch_name][fname] = _why;
    return ir.IntType(8).as_pointer();
}

impl NaIRGenPass._refuse_opaque_field(
    nd: (uni.UniNode | None), type_name: (str | None), fname: str
) -> bool {
    """Refuse a touch of an erased slot, inside the callable that touches it.

    The slot carries no value the native side put there, so answering with
    its bits would be wrong rather than merely un-lowered. Emitting here puts
    the diagnostic inside the enclosing callable's demotion window, which is
    what turns one un-lowerable declaration into a seam per method that reads
    or writes it instead of a dead module.
    """;
    if type_name is None {
        return False;
    }
    for _cn in self._mro_of(type_name) {
        _why = self.struct_field_opaque.get(_cn, {}).get(fname);
        if _why is not None {
            self.ctx.emit(
                E5092, node_override=nd, kind="erased field", name=f"{_cn}.{fname}"
            );
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._codegen_no_sig_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    if func is None {
        return;
    }

    state = self._enter_function(func);
    try {
        self._self_arch = arch_name;
        self._attach_di_subprogram(
            func, full_name, method.loc.first_line if method.loc else 0
        );

        _scan_body = ModuleFacts.unwrap_body(method);
        if _scan_body is not None {
            _scan_owner = method.body
                if isinstance(method.body, uni.ImplDef)
                else method;
            self._scan_closure_escapes(_scan_owner, _scan_body);
        }

        self._bind_function_parameter("self", func.args[0]);

        body = ModuleFacts.unwrap_body(method);
        if body is not None {
            self._codegen_body(body);
        }

        if not self.builder.block.is_terminated {
            _nosig_loc = f"{os.path.basename(self.module.loc.mod_path)}:{method.loc.last_line
                if method.loc
                else 0}";

            self._emit_scope_cleanup(skip_var=None, loc=_nosig_loc);
            self.builder.ret_void();
        }

        self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    } finally {
        self._leave_function(state);
    }
}

impl NaIRGenPass._trigger_member_structs(tag: (uni.UniNode | None)) -> list[str] {
    out: list[str] = [];
    if tag is None {
        return out;
    }
    parts: list[uni.UniNode] = [];
    if isinstance(tag, uni.TupleVal) {
        parts = list(tag.values or []);
    } elif isinstance(tag, uni.BinaryExpr) and getattr(tag.op, "value", "") == "|" {
        parts = [tag.left, tag.right];
    } else {
        parts = [tag];
    }
    for part in parts {
        if isinstance(part, uni.TupleVal)
            or (
                isinstance(part, uni.BinaryExpr)
                and getattr(part.op, "value", "") == "|"
            ) {
            for nm in self._trigger_member_structs(part) {
                if nm not in out {
                    out.append(nm);
                }
            }
            continue;
        }
        name = self._get_name(part);
        if name is not None and name in self.struct_types and name not in out {
            out.append(name);
        }
    }
    return out;
}

impl NaIRGenPass._trigger_struct_names(method: uni.Ability) -> list[str] {
    names = method.event_trigger_type_names();
    if names is None {
        sig = method.signature;
        tag = sig.arch_tag_info if isinstance(sig, uni.EventSignature) else None;
        return self._trigger_member_structs(tag);
    }
    return [
        nm
        for nm in names
        if nm in self.struct_types
    ];
}

impl NaIRGenPass._mro_of(arch_name: str) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    mro = get_layout_registry(self.module, self.prog).get_mro(arch_name);
    return mro or [arch_name];
}

impl NaIRGenPass._arch_layout(arch_name: str) -> (ArchetypeLayout | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }

    _owner = None;
    _arch_nd = self.arch_ast_map.get(arch_name);
    if _arch_nd is not None {
        _owner = _arch_nd.find_parent_of_type(uni.Module);
    }
    for _cand in [_owner, self.module] {
        if _cand is None {
            continue;
        }
        lay = get_layout_registry(_cand, self.prog).get_layout(arch_name);
        if lay is not None {
            return lay;
        }
    }
    return None;
}

impl NaIRGenPass._arch_has_vtable(arch_name: str) -> bool {
    if arch_name not in self.struct_types {
        return False;
    }
    lay = self._arch_layout(arch_name);
    return lay is not None and lay.has_vtable;
}

impl NaIRGenPass._union_layout_conflict(members: list[str]) -> (str | None) {
    if len(members) <= 1 {
        return None;
    }
    base = members[0];
    base_idx = self.struct_field_indices.get(base, {});
    base_types = self.struct_field_types.get(base, {});
    for fname in base_idx {
        for other in members[1:] {
            other_idx = self.struct_field_indices.get(other, {});
            if fname not in other_idx {
                continue;
            }
            other_types = self.struct_field_types.get(other, {});
            if other_idx[fname] != base_idx[fname]
                or base_types.get(fname) != other_types.get(fname) {
                return fname;
            }
        }
    }
    return None;
}

impl NaIRGenPass._forward_declare_event_method(
    arch_name: str, method: uni.Ability
) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    if full_name in self.method_funcs {
        return;
    }
    sig = method.signature;
    struct_type = self.struct_types.get(arch_name);
    if struct_type is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    loc_type: ir.Type = ir.IntType(8).as_pointer();
    if sig.arch_tag_info is not None {
        _members = self._trigger_struct_names(method);
        if _members {
            loc_type = self.struct_types[_members[0]].as_pointer();
        } else {
            loc_type = self._resolve_jac_type(sig.arch_tag_info);
        }
    }
    fnty = ir.FunctionType(ir.VoidType(), [struct_type.as_pointer(), loc_type]);
    func = ir.Function(self.llvm_module, fnty, name=full_name);
    func.args[0].name = "self";
    func.args[1].name = "here" if sig.from_walker else "visitor";
    self.method_funcs[full_name] = func;
    self.func_symtab[full_name] = func;
}

impl NaIRGenPass._codegen_event_method(arch_name: str, method: uni.Ability) -> None {
    method_name = method.name_ref.sym_name if method.name_ref else "unnamed";
    full_name = f"{arch_name}.{method_name}";
    func = self.method_funcs.get(full_name);
    sig = method.signature;
    if func is None or not isinstance(sig, uni.EventSignature) {
        return;
    }
    _pre_viols = self._capability_demotions.get(id(method));
    if _pre_viols is not None {
        self._claimed_capability_demotions.add(id(method));
        if self._predemote_capability_unit(
            full_name, func, _pre_viols, keep_func=True
        ) {
            return;
        }
    }
    state = self._enter_function(func);
    self._self_arch = arch_name;
    try {
        self._attach_di_subprogram(
            func, full_name, method.loc.first_line if method.loc else 0
        );
        _scan_body = ModuleFacts.unwrap_body(method);
        if _scan_body is not None {
            _scan_owner = method.body
                if isinstance(method.body, uni.ImplDef)
                else method;
            self._scan_closure_escapes(_scan_owner, _scan_body);
        }
        self._bind_function_parameter("self", func.args[0]);

        loc_name = "here" if sig.from_walker else "visitor";
        loc_arg = func.args[1];
        self._bind_function_parameter(loc_name, loc_arg);
        _grow_anchor = loc_arg if sig.from_walker else func.args[0];
        self._region_enter(self._region_of_value(_grow_anchor));
        self.region_open_stack.append(len(self.loop_stack));
        if sig.arch_tag_info is not None {
            _members = self._trigger_struct_names(method);
            _conflict = self._union_layout_conflict(_members);
            if _conflict is not None {
                self.ctx.emit(
                    E5091,
                    node_override=sig.arch_tag_info,
                    members=", ".join(_members),
                    field=_conflict
                );
            }
        }
        body = ModuleFacts.unwrap_body(method);
        if body is not None {
            self._codegen_body(body);
        }
        self.region_open_stack.pop();
        if not self.builder.block.is_terminated {
            self._region_leave();
            _ev_loc = f"{os.path.basename(self.module.loc.mod_path)}:{method.loc.last_line
                if method.loc
                else 0}";
            self._emit_scope_cleanup(skip_var=None, loc=_ev_loc);
            self.builder.ret_void();
        }
        self._finalize_di_locations(func, method.loc.first_line if method.loc else 1);
    } finally {
        self._leave_function(state);
    }
}

impl NaIRGenPass._jc_reference_schema(
    ft: ir.Type,
    layouts: dict[str, tuple[list[int], int]],
    semantic: TypeBase | None = None
) -> (dict[str, any] | None) {
    """Combine semantic reference types with the backend's container ABI.""";
    args = semantic.private.type_args or [] if isinstance(semantic, ClassType) else [];
    semantic_name = semantic.shared.class_name
        if isinstance(semantic, ClassType)
        else "";
    if not isinstance(ft, ir.PointerType) {
        return None;
    }
    if isinstance(ft.pointee, ir.IntType) and ft.pointee.width == 8 {
        if semantic_name in self.struct_field_indices {
            return {"code": "obj", "class": semantic_name};
        }
        return {"code": "str"} if semantic_name == "str" else None;
    }
    name = getattr(ft.pointee, "name", "") or "";
    if name in self.struct_field_indices {
        return {"code": "obj", "class": name};
    }
    layout = self.container_layouts.get(name);
    if layout is None {
        return None;
    }
    data_fields = layout["data_fields"];
    (offsets, _) = layouts[name];
    if layout["kind"] == "dense" and len(data_fields) == 1 {
        child = self._jc_reference_schema(
            data_fields[0][1], layouts, args[0] if args else None
        );
        if child is not None {
            return {
                "code": "list",
                "element": child,
                "data_offset": offsets[data_fields[0][0]]
            };
        }
    } elif layout["kind"] == "hash" and len(data_fields) == 2 {
        key = self._jc_reference_schema(
            data_fields[0][1], layouts, args[0] if args else None
        );
        child = self._jc_reference_schema(
            data_fields[1][1], layouts, args[1] if len(args) > 1 else None
        );
        if key is not None and key["code"] == "str" and child is not None {
            return {
                "code": "dict",
                "element": child,
                "key_offset": offsets[data_fields[0][0]],
                "data_offset": offsets[data_fields[1][0]],
                "order_offset": offsets[layout["order_idx"]]
            };
        }
    }
    return None;
}

impl NaIRGenPass._build_jc_layout -> str {
    import json;
    import from jaclang.compiler.backends.native.abi { struct_layouts }
    layouts = struct_layouts(self.llvm_module);
    out: dict[str, any] = {"classes": {}};
    _model = self.module.gen.osp_model;
    _tags = _model.tags if _model is not None else {};
    for arch_name in self.struct_field_indices {
        st = self.struct_types.get(arch_name);
        if st is None or st?.elements is None {
            continue;
        }
        (offsets, total) = layouts[arch_name];
        idx_map = self.struct_field_indices.get(arch_name, {});
        ftypes = self.struct_field_types.get(arch_name, {});
        enum_map = self.struct_field_enum_type.get(arch_name, {});
        arch_layout = self._arch_layout(arch_name);
        semantic_fields = {f.name: f.semantic_type for f in arch_layout.fields}
            if arch_layout is not None
            else {};
        fields: dict[str, dict[str, any]] = {};
        for (fname, fidx) in idx_map.items() {
            if fidx >= len(offsets) {
                continue;
            }
            ft = ftypes.get(fname);
            code = "opaque";
            aux = "";
            if fname in self.struct_field_foreign.get(arch_name, set()) {
                code = "opaque";
            } elif fname in enum_map {
                code = "enum";
                aux = enum_map[fname];
            } elif fname in self.struct_field_erased_tv.get(arch_name, {}) {
                code = "obj";
            } elif (
                isinstance(ft, ir.PointerType)
                and isinstance(ft.pointee, ir.IntType)
                and ft.pointee.width == 8
            ) {
                reference = self._jc_reference_schema(
                    ft, layouts, semantic_fields.get(fname)
                );
                if reference is not None {
                    code = reference["code"];
                    aux = reference.get("class", "");
                }
            } elif getattr(ft, "name", "") == "JacVal" {
                code = "union";
            } elif (
                isinstance(ft, ir.BaseStructType)
                and ft.elements is not None
                and len(ft.elements) == 2
                and isinstance(ft.elements[0], ir.IntType)
                and isinstance(ft.elements[1], ir.PointerType)
            ) {
                code = "optref";
                _opn = getattr(ft.elements[1].pointee, "name", "") or "";
                aux = _opn;
            } elif isinstance(ft, ir.IntType) {
                code = "bool" if ft.width == 1 else "int";
            } elif isinstance(ft, ir.DoubleType) {
                code = "float";
            } elif isinstance(ft, ir.PointerType) {
                _pn = getattr(ft.pointee, "name", "") or "";
                _is_list = False;
                for (_, _lt) in self.list_types.items() {
                    if ft == _lt.as_pointer() {
                        _is_list = True;
                        break;
                    }
                }
                if _is_list {
                    code = "natlist";
                    aux = _pn;
                } elif _pn in self.struct_field_indices {
                    code = "obj";
                    aux = _pn;
                } elif _pn == "jac.str" or _pn.endswith(".str") or _pn == "str" {
                    code = "str";
                } else {
                    code = "ptr";
                    aux = _pn;
                }
            }
            fields[fname] = {
                "index": fidx,
                "offset": offsets[fidx],
                "code": code,
                "aux": aux
            };
            if code == "ptr" and isinstance(ft, ir.PointerType) {
                schema = self._jc_reference_schema(
                    ft, layouts, semantic_fields.get(fname)
                );
                if schema is not None and schema["code"] == "dict" {
                    fields[fname]["code"] = "natdict";
                    fields[fname]["schema"] = schema;
                }
            }
        }
        _lay_tag_idx = self.osp_type_tag_field.get(arch_name);
        out["classes"][arch_name] = {
            "size": total,
            "tag": _tags.get(arch_name, 0),
            "tag_offset": offsets[_lay_tag_idx]
                if (_lay_tag_idx is not None and _lay_tag_idx < len(offsets))
                else -1,
            "fields": fields
        };
    }
    return json.dumps(out);
}
