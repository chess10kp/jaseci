impl NaIRGenPass._read_field_or_refuse(
    nd: uni.UniNode, obj_val: ir.Value, field_name: str, arch_name: str
) -> (ir.Value | None) {
    """Read a field, naming the ancestor when an inherited one is unreachable.

    Only the inherited case speaks up here. Every other way a name can miss
    the layout already has an owner further out that reports it, and claiming
    them from this depth would rename diagnostics this change has no business
    touching.
    """;
    _mark = len(self.ctx.errors_had);
    _val = self._codegen_field_access(obj_val, field_name, arch_name, nd);
    if _val is None and len(self.ctx.errors_had) == _mark {
        _val = self._codegen_class_const_read(obj_val, arch_name, field_name);
        if _val is None {
            self._emit_field_access_refusal(nd, arch_name, field_name);
        }
    }
    return _val;
}

impl NaIRGenPass._unadopted_field_owner(
    arch_name: str, field_name: str
) -> (str | None) {
    """The ancestor that declares a field this class's layout does not hold.

    A subclass whose ancestor lays out in another unit adopts that unit's slot
    assignment, and where the two disagree about the header slots there is no
    assignment to adopt. Naming the ancestor turns the resulting refusal from
    'some attribute did not lower' into the layout fact behind it.
    """;
    _arch = self.arch_ast_map.get(arch_name);
    if _arch is None {
        return None;
    }
    for _base in (_arch.base_classes or []) {
        _bn = self._get_name(_base);
        if _bn is None or _bn == arch_name {
            continue;
        }
        _blay = self._arch_layout(_bn);
        if _blay is not None and field_name in _blay.field_index {
            return _bn;
        }
        _up = self._unadopted_field_owner(_bn, field_name);
        if _up is not None {
            return _up;
        }
    }
    return None;
}

impl NaIRGenPass._emit_field_access_refusal(
    nd: uni.UniNode, arch_name: str, field_name: str
) -> None {
    _owner = self._unadopted_field_owner(arch_name, field_name);
    if _owner is None {
        _decl = self._class_const_declarer(arch_name, field_name);
        if _decl is not None {
            self.ctx.emit(
                E5092,
                node_override=nd,
                kind="class-level attribute read",
                name=field_name,
                help_text=(
                    f"'{field_name}' is a class-level attribute of '{_decl}', "
                    f"not an instance field. Reading it through an instance "
                    f"needs every declaring class in the hierarchy to carry "
                    f"the value in one shape the receiver's vtable can select "
                    f"between, and this hierarchy does not. Read it off the "
                    f"class, or move this code to a @sv/Python context."
                )
            );
        }
        return;
    }
    self.ctx.emit(
        E5092,
        node_override=nd,
        kind="inherited field access",
        name=field_name,
        help_text=(
            f"'{field_name}' is declared by '{_owner}', which lays out in "
            f"another unit with no vtable slot, while '{arch_name}' needs "
            f"that slot for one. No offset satisfies both units, so the "
            f"field is not reachable from here. Read it through an "
            f"'{_owner}'-typed value, or move this code to a @sv/Python "
            f"context."
        )
    );
}

impl NaIRGenPass._class_const_declarer(
    arch_name: str, field_name: str
) -> (str | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    _seen: list[str] = list(self._mro_of(arch_name));
    for _cls in get_layout_registry(self.module, self.prog).mro_order {
        if arch_name in self._mro_of(_cls) and _cls not in _seen {
            _seen.append(_cls);
        }
    }
    for _cls in _seen {
        _arch = self.arch_ast_map.get(_cls);
        if _arch is None or _arch.body is None {
            continue;
        }
        for stmt in _arch.body {
            if not isinstance(stmt, uni.ModuleCode) {
                continue;
            }
            for _a in (stmt.body or []) {
                if not isinstance(_a, uni.Assignment) {
                    continue;
                }
                _tg = _a.target
                    if isinstance(_a.target, (list, tuple))
                    else [(_a.target)];
                for _t in _tg {
                    if self._get_name(_t) == field_name {
                        return _cls;
                    }
                }
            }
        }
    }
    return None;
}

impl NaIRGenPass._emit_heap_object_alloc(
    nd: uni.UniNode, type_name: str, size: ir.Value, headerless: bool
) -> ir.Value {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    if headerless {
        _malloc_fn = self._get_or_declare_extern("malloc", i8p, [i64]);
        raw_ptr: ir.Value = self.builder.call(_malloc_fn, [size], name="raw.ptr");
        self._emit_struct_drop_fn(type_name);
        return raw_ptr;
    }
    _inst_loc = f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
        if nd.loc
        else 0}";
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    _alloc_fn = self.rc_alloc_fn;
    assert _alloc_fn is not None , "rc helpers are emitted before allocation";
    raw_ptr = self._rc_call_with_ctx(
        _alloc_fn, [size], op="new", loc=_inst_loc, name="raw.ptr"
    );
    self._emit_struct_release_fn(type_name);
    _dtor_fn_s = self.struct_release_fns.get(type_name);
    if _dtor_fn_s is not None {
        _dtor_slot_s = self.builder.gep(
            raw_ptr, [ir.Constant(i64, HDR_DTOR_OFF)], name="obj_dtor_slot"
        );
        _dtor_slot_i64_s = self.builder.bitcast(
            _dtor_slot_s, i64.as_pointer(), name="obj_dtor_i64p"
        );
        _dtor_i64_s = self.builder.ptrtoint(_dtor_fn_s, i64, name="obj_dtor_i64");
        self.builder.store(_dtor_i64_s, _dtor_slot_i64_s);
    }
    self._emit_trace_fn(type_name);
    _trace_fn_s = self.struct_trace_fns.get(type_name);
    self._require_trace_fn(
        type_name,
        (
            self._struct_has_ref_fields(type_name)
            and not self._arch_is_acyclic(type_name)
        ),
        _trace_fn_s is not None
    );
    if self.rc_set_type_fn is not None {
        self._emit_set_type_tag(self.builder, raw_ptr, type_name);
    }
    return raw_ptr;
}

impl NaIRGenPass._stack_alloc_target_ok(nd: uni.UniNode) -> bool {
    p = nd.parent;
    if not isinstance(p, uni.Assignment) or p.aug_op is not None or p.value is not nd {
        return False;
    }
    targets = p.target if isinstance(p.target, (list, tuple)) else [(p.target)];
    if len(targets) != 1 or not isinstance(targets[0], uni.Name) {
        return False;
    }
    sym = targets[0].sym;
    return sym is not None and sym.na_stack_ok;
}

impl NaIRGenPass._empty_container_for_field(
    ftype: (ir.Type | None), label: str
) -> (ir.Value | None) {
    if ftype is None or not isinstance(ftype, ir.PointerType) {
        return None;
    }
    for (dict_key, dtype) in self.dict_types.items() {
        if ftype == dtype.as_pointer() {
            dict_ops = self.dict_helpers.get(dict_key);
            return (
                self.builder.call(dict_ops["new"], [], name=f"dict.{label}")
                    if dict_ops is not None
                    else None
            );
        }
    }
    for (list_key, ltype) in self.list_types.items() {
        if ftype == ltype.as_pointer() {
            list_ops = self.list_helpers.get(list_key);
            return (
                self.builder.call(list_ops["new"], [], name=f"list.{label}")
                    if list_ops is not None
                    else None
            );
        }
    }
    for (set_key, stype) in self.set_types.items() {
        if ftype == stype.as_pointer() {
            set_ops = self.set_helpers.get(set_key);
            return (
                self.builder.call(set_ops["new"], [], name=f"set.{label}")
                    if set_ops is not None
                    else None
            );
        }
    }
    return None;
}

impl NaIRGenPass._codegen_instantiation(
    nd: (uni.FuncCall | uni.Name),
    type_name_override: (str | None) = None,
    ctor_params: (list[uni.Expr | uni.KWPair] | None) = None
) -> (ir.Value | None) {
    _is_call = isinstance(nd, uni.FuncCall);
    type_name = type_name_override
        if type_name_override is not None
        else self._get_name(nd.target if isinstance(nd, uni.FuncCall) else nd);
    if type_name is None or type_name not in self.struct_types {
        return None;
    }
    if self._reject_scalar_type_args(nd, type_name) {
        return None;
    }
    _demoted_init = self._demoted_init_of(type_name);
    if _demoted_init is not None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="constructor",
            name=f"{type_name}() via {_demoted_init}",
            help_text=(
                "The initializer was demoted to its Python implementation, so "
                "native construction has no initializer to call and would "
                "leave the object half-built. Construct this class from a "
                "Python/@sv context, or make the initializer lowerable."
            )
        );
        return None;
    }
    struct_type = self.struct_types[type_name];
    struct_ptr_type = struct_type.as_pointer();

    params = ctor_params
        if ctor_params is not None
        else ((nd.params or []) if isinstance(nd, uni.FuncCall) else []);
    _has_init = (
        f"{type_name}.init" in self.method_funcs
        or f"{type_name}.__init__" in self.method_funcs
    );
    _pos_field_pairs: list[tuple[str, uni.UniNode]] = [];
    if not _has_init {
        _pos_args = [
            p
            for p in params
            if not isinstance(p, uni.KWPair)
        ];
        if _pos_args and self._pyb_base_of(type_name) is not None {
            self.ctx.emit(
                E5092,
                node_override=nd,
                kind="constructor call",
                name=type_name,
                help_text=(
                    f"'{type_name}' inherits from a Python-side base, so its "
                    f"constructor arguments cannot be matched positionally; "
                    f"use keyword arguments."
                )
            );
            return None;
        }
        if _pos_args {
            _order = self.struct_constructor_order.get(type_name);
            if _order is None or len(_pos_args) > len(_order) {
                self.ctx.emit(
                    E5092,
                    node_override=nd,
                    kind="constructor call",
                    name=type_name,
                    help_text=f"Positional arguments to '{type_name}' lower natively only up to its declared has-field count and only when its field layout is visible to this module."
                );
                return None;
            }
            for (_pi, _pv) in enumerate(_pos_args) {
                _pos_field_pairs.append((_order[_pi], _pv));
            }
        }
    }

    _vt_struct = type_name in self.clib_vtable_structs;
    _stack_ok = (
        not _vt_struct
        and self._stack_alloc_target_ok(nd)
        and self._arch_is_acyclic(type_name)
        and not self._struct_has_ref_fields(type_name)
        and not self._arch_has_vtable(type_name)
        and not self._arch_is_osp_name(type_name)
        and self._drop_hook_for(type_name) is None
        and not self.struct_field_inline.get(type_name, None)
        and self._pyb_base_of(type_name) is None
    );
    _headerless = self._nogc_headerless() and not self._arch_is_osp_name(type_name);
    if _stack_ok and _headerless {
        obj_ptr = self._entry_alloca(struct_type, f"stk.{type_name}");
        self.rc_stack_promotions += 1;
        _tgt_asgn = nd.find_parent_of_type(uni.Assignment);
        if _tgt_asgn is not None
            and len(_tgt_asgn.target) == 1
            and isinstance(_tgt_asgn.target[0], uni.Name) {
            self.nogc_no_free_vars.add(_tgt_asgn.target[0].sym_name);
        }
    } elif _stack_ok {
        self.rc_stack_promotions += 1;
        _i8 = ir.IntType(8);
        _i32s = ir.IntType(32);
        _i64s = ir.IntType(64);
        _hdr_arr = ir.ArrayType(_i8, HDR_TOTAL);
        _slab_ty = ir.LiteralStructType([_hdr_arr, struct_type]);
        _slab = self._entry_alloca(_slab_ty, f"stk.{type_name}");
        obj_ptr = self.builder.gep(
            _slab, [ir.Constant(_i32s, 0), ir.Constant(_i32s, 1)], name="stk.obj"
        );
        _stk_i8 = self.builder.bitcast(obj_ptr, _i8.as_pointer(), name="stk.i8");
        _stk_rc_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_RC_OFF)], name="stk.rc.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, RC_SENTINEL),
            self.builder.bitcast(_stk_rc_slot, _i64s.as_pointer(), name="stk.rc.p")
        );
        _stk_dtor_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_DTOR_OFF)], name="stk.dtor.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_dtor_slot, _i64s.as_pointer(), name="stk.dtor.p")
        );
        _stk_aid_slot = self.builder.gep(
            _stk_i8, [ir.Constant(_i64s, HDR_ALLOC_ID_OFF)], name="stk.aid.slot"
        );
        self.builder.store(
            ir.Constant(_i64s, 0),
            self.builder.bitcast(_stk_aid_slot, _i64s.as_pointer(), name="stk.aid.p")
        );
        if self.rc_set_type_fn is not None {
            self._emit_set_type_tag(self.builder, _stk_i8, type_name);
        }
    } else {
        null_ptr = ir.Constant(struct_ptr_type, None);
        size_gep = self.builder.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="sizeof.gep"
        );
        size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="sizeof");
        _region_eligible = (
            not _vt_struct
            and id(nd) != self._managed_ctor_node
            and not self._arch_is_walker_name(type_name)
            and not bool(getattr(self.prog.options, "kernel_unit", False))
        );
        if not _region_eligible {
            raw_ptr = self._emit_heap_object_alloc(nd, type_name, size, _headerless);
        } else {
            _i8p_a = ir.IntType(8).as_pointer();
            _func_a = self.builder.function;
            _heap_bb = _func_a.append_basic_block(name="alloc.heap");
            _rgn_bb = _func_a.append_basic_block(name="alloc.region");
            _merge_bb = _func_a.append_basic_block(name="alloc.merge");
            _cur = self._region_current();
            self.builder.cbranch(
                self.builder.icmp_unsigned(
                    "==", _cur, ir.Constant(_i8p_a, None), name="alloc.nocur"
                ),
                _heap_bb,
                _rgn_bb
            );
            self.builder.position_at_end(_heap_bb);
            _heap_raw = self._emit_heap_object_alloc(nd, type_name, size, _headerless);
            _heap_end = self.builder.block;
            self.builder.branch(_merge_bb);
            self.builder.position_at_end(_rgn_bb);
            _rgn_raw = self._region_alloc_object(_cur, size, type_name);
            _rgn_end = self.builder.block;
            self.builder.branch(_merge_bb);
            self.builder.position_at_end(_merge_bb);
            _phi = self.builder.phi(_i8p_a, name="alloc.raw");
            _phi.add_incoming(_heap_raw, _heap_end);
            _phi.add_incoming(_rgn_raw, _rgn_end);
            raw_ptr = _phi;
        }
        obj_ptr = self.builder.bitcast(raw_ptr, struct_ptr_type, name="obj.ptr");
    }

    vtable_global = self._vtable_global_for(type_name);
    if vtable_global is not None {
        vtable_base = self.builder.gep(
            vtable_global,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.base"
        );
        vtable_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="vtable.slot"
        );
        self.builder.store(vtable_base, vtable_slot);
    }

    _tt_idx = self.osp_type_tag_field.get(type_name);
    if _tt_idx is not None {
        if self._osp_ensure_fn is not None {
            self.builder.call(self._osp_ensure_fn, []);
        }
        _tt_slot = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _tt_idx)],
            name="type_tag.slot"
        );

        _tt_val = stable_osp_tag(type_name);
        self.builder.store(ir.Constant(ir.IntType(64), _tt_val), _tt_slot);

        if not self._arch_is_walker_name(type_name) {
            self._osp_make_immortal(obj_ptr);
        }
    }

    _rep_idx = self.osp_reports_field.get(type_name);
    if _rep_idx is not None {
        _rep_h = self.list_helpers.get("jacval");
        if _rep_h is not None {
            _rep_list = self._rc_call_with_ctx(
                _rep_h["new"], [], op="new", loc="", name="reports.init"
            );
            self.builder.store(
                _rep_list,
                self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), _rep_idx)
                    ],
                    name="reports.slot"
                )
            );
        }
    }

    field_indices = self.struct_field_indices.get(type_name, {});
    field_types = self.struct_field_types.get(type_name, {});
    field_defaults = self.struct_field_defaults.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());

    set_fields: set[str] = set();
    _field_inits: list[tuple[str, uni.UniNode]] = list(_pos_field_pairs);
    for param in params {
        if isinstance(param, uni.KWPair) {
            _kn = param.key.sym_name if param.key else None;
            if _kn is not None {
                _field_inits.append((_kn, param.value));
            }
        }
    }
    if isinstance(nd, uni.FuncCall) {
        for (_ct_name, _ct_expr) in self._ct_ctor_slots(nd.target) {
            _field_inits.append((_ct_name, _ct_expr));
        }
    }
    for (key_name, init_expr) in _field_inits {
        if key_name not in field_indices or key_name in set_fields {
            continue;
        }
        if self._refuse_opaque_field(init_expr, type_name, key_name) {
            continue;
        }
        if key_name in foreign_fields {
            continue;
        }
        val = self._codegen_expr(init_expr);
        if val is None {
            val = self._empty_container_for_field(
                field_types.get(key_name), f"ctor.{key_name}"
            );
            if val is None {
                continue;
            }
        }
        idx = field_indices[key_name];
        ftype = field_types[key_name];

        if key_name in self.struct_field_inline.get(type_name, set()) {
            _inl_fp = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"field.{key_name}"
            );
            self._store_inline_field(type_name, key_name, _inl_fp, val, False);
            self._nogc_consume_local(init_expr);
            set_fields.add(key_name);
            continue;
        }

        _is_clib_cb = (
            type_name in self.clib_vtable_structs
            and isinstance(ftype, ir.PointerType)
            and isinstance(ftype.pointee, ir.FunctionType)
        );
        if _is_clib_cb {
            val = self._clib_coerce_callback(val, ftype);
        } else {
            val = self._coerce_type(val, ftype);
        }

        self._emit_take_ref(
            val,
            op="ctor_field",
            loc=f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
                if nd.loc
                else 0}"
        );
        field_ptr = self.builder.gep(
            obj_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{key_name}"
        );
        self.builder.store(val, field_ptr);
        self._nogc_consume_local(init_expr);
        set_fields.add(key_name);
    }

    for (fname, default_expr) in field_defaults.items() {
        if fname not in set_fields {
            val = self._codegen_expr(default_expr);

            if val is None {
                val = self._empty_container_for_field(
                    field_types.get(fname), f"dflt.{fname}"
                );
            }
            if val is not None
                and fname in self.struct_field_inline.get(type_name, set()) {
                _inl_fp = self.builder.gep(
                    obj_ptr,
                    [
                        ir.Constant(ir.IntType(32), 0),
                        ir.Constant(ir.IntType(32), field_indices[fname])
                    ],
                    name=f"field.{fname}"
                );
                self._store_inline_field(type_name, fname, _inl_fp, val, False);
                set_fields.add(fname);
                continue;
            }
            if val is not None {
                idx = field_indices[fname];
                ftype = field_types[fname];

                _is_clib_cb_d = (
                    type_name in self.clib_vtable_structs
                    and isinstance(ftype, ir.PointerType)
                    and isinstance(ftype.pointee, ir.FunctionType)
                );
                if _is_clib_cb_d {
                    val = self._clib_coerce_callback(val, ftype);
                } else {
                    val = self._coerce_type(val, ftype);
                }

                self._emit_take_ref(
                    val,
                    op="ctor_field",
                    loc=f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
                field_ptr = self.builder.gep(
                    obj_ptr,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                    name=f"default.{fname}"
                );
                self.builder.store(val, field_ptr);
                set_fields.add(fname);
            }
        }
    }

    for (fname, idx) in field_indices.items() {
        if fname not in set_fields {
            ftype = field_types[fname];
            zero_val = ir.Constant(ftype, None);
            field_ptr = self.builder.gep(
                obj_ptr,
                [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
                name=f"zero.{fname}"
            );
            self.builder.store(zero_val, field_ptr);
        }
    }

    if not self._codegen_pyb_shadow_init(
        nd, type_name, obj_ptr, params, field_indices
    ) {
        return None;
    }

    init_fn: (ir.Function | None) = None;
    _init_owner: str = type_name;
    for _init_cls in self._mro_of(type_name) {
        for candidate in [f"{_init_cls}.init", f"{_init_cls}.__init__"] {
            if candidate in self.method_funcs {
                init_fn = self.method_funcs[candidate];
                _init_owner = _init_cls;
                break;
            }
        }
        if init_fn is not None {
            break;
        }
    }
    if init_fn is not None and _init_owner != type_name {
        import from jaclang.compiler.passes.layout_pass {
            get_layout_registry as _ci_glr
        }
        if not _ci_glr(self.module, self.prog).is_primary_ancestor(
            type_name, _init_owner
        ) {
            self.ctx.emit(
                E5092,
                node_override=nd,
                kind="constructor",
                name=f"{type_name}() via {_init_owner}.init",
                help_text=(
                    "The inherited initializer belongs to an ancestor that is "
                    "not layout-prefix-compatible with this class, so calling "
                    "it directly would address the wrong field offsets."
                )
            );
            return None;
        }
    }
    if init_fn is not None {
        init_args: list[ir.Value] = [obj_ptr];
        init_sig = self._arch_init_sig_of(_init_owner) if _is_call else None;
        if init_sig is not None {
            _init_pos: list[uni.Expr] = [];
            _init_kw: dict[str, uni.Expr] = {};
            for param in params {
                if isinstance(param, uni.KWPair) {
                    _k = param.key.sym_name if param.key is not None else None;
                    if _k is not None {
                        _init_kw[_k] = param.value;
                    }
                } else {
                    _init_pos.append(param);
                }
            }
            _sig_params = init_sig.get_parameters();
            for (pix, sp) in enumerate(_sig_params) {
                _slot = 1 + pix;
                _expected = init_fn.args[_slot].type
                    if _slot < len(init_fn.args)
                    else ir.IntType(64);
                _chosen: (uni.Expr | None) = None;
                if pix < len(_init_pos) {
                    _chosen = _init_pos[pix];
                } elif sp.name.sym_name in _init_kw {
                    _chosen = _init_kw[sp.name.sym_name];
                } elif sp.value is not None {
                    _chosen = sp.value;
                }
                _val = self._codegen_expr(_chosen) if _chosen is not None else None;
                if _val is not None {
                    init_args.append(_val);
                } else {
                    init_args.append(self._default_arg_fallback(_expected));
                }
            }
            for pix in range(len(_sig_params), len(_init_pos)) {
                _extra = self._codegen_expr(_init_pos[pix]);
                if _extra is not None {
                    init_args.append(_extra);
                }
            }
        } else {
            for param in params {
                if not isinstance(param, uni.KWPair) {
                    val = self._codegen_expr(param);
                    if val is not None {
                        init_args.append(val);
                    }
                }
            }
            _fill = len(init_args);
            while _fill < len(init_fn.args) {
                init_args.append(self._default_arg_fallback(init_fn.args[_fill].type));
                _fill += 1;
            }
        }

        coerced_args: list[ir.Value] = [];
        for (i, arg) in enumerate(init_args) {
            if i < len(init_fn.args) {
                coerced_args.append(self._coerce_type(arg, init_fn.args[i].type));
            } else {
                coerced_args.append(arg);
            }
        }
        self.builder.call(init_fn, coerced_args, name="call.init");
        if not self._nogc_headerless() {
            self._release_owned_args(coerced_args[1:], op="call_arg");
        }
        self._emit_err_check(self._linked_callee_decl(init_fn));
    }

    _pi_auto = init_fn is None;
    for _pi_cls in self._mro_of(type_name) {
        _pi_arch = self.arch_ast_map.get(_pi_cls);
        if _pi_arch is None {
            continue;
        }
        _pi_own_init = False;
        if _pi_arch.body is not None {
            for _pi_stmt in _pi_arch.body {
                if isinstance(_pi_stmt, uni.Ability)
                    and _pi_stmt.name_ref is not None
                    and _pi_stmt.name_ref.sym_name in ("init", "__init__") {
                    _pi_own_init = True;
                    break;
                }
            }
        }
        if _pi_own_init {
            _pi_auto = False;
            break;
        }
        _pi_fielded = False;
        for _pi_var in _pi_arch.get_has_vars() {
            if not _pi_var.accessors {
                _pi_fielded = True;
                break;
            }
        }
        if _pi_fielded {
            _pi_auto = True;
            break;
        }
    }
    _pi_full: (str | None) = None;
    if _pi_auto {
        for _pi_cls in self._mro_of(type_name) {
            for pname in [f"{_pi_cls}.__post_init__", f"{_pi_cls}.postinit"] {
                if pname in self._native_skipped_methods {
                    self.ctx.emit(
                        E5092,
                        node_override=nd,
                        kind="constructor",
                        name=f"{type_name}() via {pname}",
                        help_text=(
                            "The post-initializer was demoted to its Python "
                            "implementation, so native construction has no "
                            "post-initializer to call and would leave the "
                            "object half-built. Construct this class from a "
                            "Python/@sv context, or make the post-initializer "
                            "lowerable."
                        )
                    );
                    return None;
                }
                if pname in self.method_funcs {
                    _pi_full = pname;
                    break;
                }
            }
            if _pi_full is not None {
                break;
            }
        }
    }
    if _pi_full is not None {
        postinit_fn = self._receiver_routed_method_fn(
            nd, _pi_full, ["__post_init__", "postinit"], type_name
        );
        if postinit_fn is None {
            return None;
        }
        self.builder.call(
            postinit_fn, [self._coerce_type(obj_ptr, postinit_fn.args[0].type)]
        );
        self._emit_err_check(self._linked_callee_decl(postinit_fn));
    }
    return obj_ptr;
}

impl NaIRGenPass._unregistered_class_target(target: uni.UniNode) -> (str | None) {
    """The class a `Cls.method(...)` names when the native lane has no `Cls`.

    The native import walk registers a struct type for an imported archetype
    only when it walked that archetype's module; a module it classified
    Python-side (a Python base, a `::py::` body) leaves nothing behind, so the
    class name resolves to no native type at all. That is the same crossing a
    cross-module free-function call makes, and the free-function form refuses
    out loud -- this lookup is what lets the class-qualified form say the same
    thing instead of dropping the call on the floor.

    Only a name that resolves to an archetype declared in *another* Jac module
    answers, so an instance receiver, an enum, and an in-module class that has
    simply not been registered yet all stay out of it.
    """;
    import os;
    name = self._get_name(target);
    if name is None or name in self.struct_types or name in self.local_vars {
        return None;
    }
    if not isinstance(target, uni.Expr) {
        return None;
    }
    import from jaclang.compiler.symbol_utils { resolve_expr_symbol }
    sym = resolve_expr_symbol(target);
    decl = sym.decl if sym is not None else None;
    if decl is None {
        return None;
    }
    arch = decl.find_parent_of_type(uni.Archetype);
    if arch is None or arch.name is None or arch.name.value != name {
        return None;
    }
    decl_mod = decl.find_parent_of_type(uni.Module);
    path = decl_mod.loc.mod_path if decl_mod is not None else None;
    if not path or not path.endswith(".jac") {
        return None;
    }
    own_path = os.path.realpath(self.module.loc.mod_path) if self.module?.loc else "";
    if os.path.realpath(path) == own_path {
        return None;
    }
    return name;
}

impl NaIRGenPass._codegen_method_call(nd: uni.FuncCall) -> (ir.Value | None) {
    result = self._codegen_method_call_inner(nd);
    if result is not None
        and nd.callee_decl is not None
        and nd.callee_decl.receiver_mode == OwnershipKind.OWN
        and isinstance(nd.target, uni.AtomTrailer)
        and not self.builder.block.is_terminated {
        self._nogc_consume_local(nd.target.target);
    }
    return result;
}

impl NaIRGenPass._codegen_method_call_inner(nd: uni.FuncCall) -> (ir.Value | None) {
    trailer = nd.target;
    if not isinstance(trailer, uni.AtomTrailer) or not trailer.is_attr {
        return None;
    }
    import from jaclang.compiler.symbol_utils { imported_module_name }
    module_name = imported_module_name(trailer.target);
    target_name = module_name or self._get_name(trailer.target);
    method_name = self._get_name(trailer.right);
    if method_name is None {
        return None;
    }
    if target_name == "super" and self._self_arch is not None {
        _sup_names = [method_name];
        if method_name == "postinit" {
            _sup_names.append("__post_init__");
        } elif method_name == "init" {
            _sup_names.append("__init__");
        }
        _sup_full: (str | None) = None;
        for _cn in self._mro_of(self._self_arch)[1:] {
            for _mn in _sup_names {
                _cand = f"{_cn}.{_mn}";
                if _cand in self.method_funcs
                    and _cand not in self._native_skipped_methods {
                    _sup_full = _cand;
                    break;
                }
            }
            if _sup_full is not None {
                break;
            }
        }
        _self_slot = self.local_vars.get("self");
        if _sup_full is not None and _self_slot is not None {
            _self_val = self.builder.load(_self_slot, name="super.self");
            return self._emit_class_routed_call(
                nd, _sup_full, _sup_names, _self_val, self._self_arch
            );
        }
        if self._pyb_base_of(self._self_arch) is not None {
            _pyb_sup = self._codegen_pyb_super_call(nd, method_name);
            if _pyb_sup is not None {
                return _pyb_sup;
            }
            return None;
        }
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=f"super.{method_name}",
            help_text=(
                "No MRO ancestor of this class provides a native lowering "
                "of this method, so the super call cannot lower."
            )
        );
        return None;
    }
    if method_name == "partition" {
        import from jaclang.compiler.expr_keys { is_builtin_region_type }
        if is_builtin_region_type(trailer.target.type) {
            _pt_recv = self._codegen_expr(trailer.target);
            if _pt_recv is None {
                return None;
            }
            return self._region_partition(_pt_recv);
        }
    }
    if (
        method_name in ("get", "keys", "values", "items", "setdefault", "update", "pop")
        and self._type_key_of(trailer.target) in ("any", "Any")
    ) {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{method_name} (on an `any` receiver)",
            help_text=(
                "Method calls on an `any`-typed dict are not lowered natively "
                "yet; annotate the receiver with a concrete dict[...] type or "
                "move this code to a @sv/Python context."
            )
        );
        return None;
    }

    if (
        target_name is not None
        and target_name in self.struct_types
        and target_name not in self.local_vars
    ) {
        _sfull: (str | None) = None;
        _mnames = [method_name];
        if method_name == "postinit" {
            _mnames.append("__post_init__");
        } elif method_name == "init" {
            _mnames.append("__init__");
        }
        for _cn in self._mro_of(target_name) {
            _cand = f"{_cn}.{method_name}";
            if _cand in self.static_methods {
                _sfull = _cand;
                break;
            }
        }
        if _sfull is not None
            and (
                _sfull in self._native_skipped_methods
                or _sfull not in self.method_funcs
            ) {
            self.ctx.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=_sfull,
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted "
                    f"to its Python implementation; it cannot be called from "
                    f"native code. Call it from a Python/@sv context instead."
                )
            );
            return None;
        }
        if _sfull is None {
            for _cn in self._mro_of(target_name) {
                for _mn in _mnames {
                    _icand = f"{_cn}.{_mn}";
                    if _icand in self.method_funcs
                        and _icand not in self._native_skipped_methods {
                        _sfull = _icand;
                        break;
                    }
                }
                if _sfull is not None {
                    break;
                }
            }
        }
        if _sfull is not None {
            return self._emit_class_routed_call(nd, _sfull, _mnames, None, None);
        }
    }

    _xmod_cls = self._unregistered_class_target(trailer.target);
    if _xmod_cls is not None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="method",
            name=f"{_xmod_cls}.{method_name}",
            help_text=(
                f"'{_xmod_cls}' is declared in a module the native lane did "
                f"not lower, so it has no native '{method_name}' to call. A "
                f"free function from that module refuses here for the same "
                f"reason. Call it from a Python/@sv context, or move the "
                f"shared code into a module the native lane can lower."
            )
        );
        return None;
    }

    _fld_struct = self._struct_name_of(trailer.target);
    if (
        _fld_struct is not None
        and _fld_struct in self.struct_field_types
        and method_name in self.struct_field_types[_fld_struct]
    ) {
        _fld_ty = self.struct_field_types[_fld_struct][method_name];
        if (
            isinstance(_fld_ty, ir.PointerType)
            and isinstance(_fld_ty.pointee, ir.FunctionType)
        ) {
            _obj_v = self._codegen_expr(trailer.target);
            if _obj_v is not None {
                _idx = self.struct_field_indices[_fld_struct][method_name];
                _fld_ptr = self.builder.gep(
                    _obj_v,
                    [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), _idx)],
                    name=f"{method_name}.fldptr"
                );
                _fnp = self.builder.load(_fld_ptr, name=f"{method_name}.fn");
                _fn_ty = _fld_ty.pointee;
                _is_clib = _fld_struct in self.clib_struct_names;
                _cargs: list[ir.Value] = [];
                for (_i, _p) in enumerate(nd.params or []) {
                    _pv = self._codegen_expr(_p);
                    if _pv is not None {
                        if _i < len(_fn_ty.args) {
                            _pv = (
                                self._clib_fnptr_arg(_pv, _fn_ty.args[_i])
                                    if _is_clib
                                    else self._coerce_type(_pv, _fn_ty.args[_i])
                            );
                        }
                        _cargs.append(_pv);
                    }
                }
                _r = self.builder.call(_fnp, _cargs, name=f"icall.{method_name}");
                if isinstance(_fn_ty.return_type, ir.VoidType) {
                    return None;
                }
                if _is_clib {
                    return self._clib_fnptr_ret(_fld_struct, method_name, _r);
                }
                return _r;
            }
        }
    }

    if (
        target_name == "sys"
        and self?._native_stdlib_modules
        and "sys" in self._native_stdlib_modules
    ) {
        if method_name == "exit" {
            arg_vals = self._codegen_call_args(nd);
            return self._emit_sys_exit(arg_vals);
        }
    }

    if (
        module_name == "math"
        and self._native_stdlib_modules
        and "math" in self._native_stdlib_modules
    ) {
        _mres = self._emit_math_call(method_name, nd);
        if _mres is not None {
            return _mres;
        }
    }

    if (
        module_name == "time"
        and self._native_stdlib_modules
        and "time" in self._native_stdlib_modules
        and method_name in NATIVE_TIME_FUNCS
    ) {
        return self._emit_time_call(method_name, nd);
    }

    if module_name == "os.path"
        or (
            isinstance(trailer.target, uni.AtomTrailer)
            and trailer.target.is_attr
            and imported_module_name(trailer.target.target) == "os"
            and self._get_name(trailer.target.right) == "path"
            and self?._native_stdlib_modules
            and "os" in self._native_stdlib_modules
        ) {
        if method_name not in NATIVE_OSPATH_FUNCS {
            self.ctx.emit(
                E5090, node_override=nd, kind="os.path member", name=method_name
            );
            return None;
        }
        return self._emit_ospath_call(method_name, nd);
    }

    if (
        isinstance(trailer.target, uni.AtomTrailer)
        and trailer.target.is_attr
        and imported_module_name(trailer.target.target) == "os"
        and self._get_name(trailer.target.right) == "environ"
        and self?._native_stdlib_modules
        and "os" in self._native_stdlib_modules
    ) {
        _env_res = self._emit_os_environ_call(method_name, nd);
        if _env_res is not None {
            return _env_res;
        }
    }

    if (
        module_name == "os"
        and self._native_stdlib_modules
        and "os" in self._native_stdlib_modules
        and method_name in NATIVE_OS_FUNCS
    ) {
        return self._emit_os_call(method_name, nd);
    }

    if (
        module_name == "random"
        and self._native_stdlib_modules
        and "random" in self._native_stdlib_modules
        and method_name in NATIVE_RANDOM_FUNCS
    ) {
        return self._emit_random_call(method_name, nd);
    }

    if (
        module_name == "struct"
        and self._native_stdlib_modules
        and "struct" in self._native_stdlib_modules
        and method_name in NATIVE_STRUCT_FUNCS
    ) {
        return self._emit_struct_call(method_name, nd);
    }

    if target_name == "int" and method_name == "from_bytes" {
        arg_vals = self._codegen_call_args(nd);
        if arg_vals {
            _emitter = self._ensure_emitters().get("int");
            if isinstance(_emitter, NativeIntEmitter) {
                _ctx = NativeEmitCtx(pass_ref=self, type_key="");
                result = _emitter.emit_from_bytes(_ctx, arg_vals);
                if result is not None {
                    return result;
                }
            }
        }
    }
    if target_name == "float" and method_name == "fromhex" {
        arg_vals = self._codegen_call_args(nd);
        if arg_vals {
            _emitter = self._ensure_emitters().get("float");
            if isinstance(_emitter, NativeFloatEmitter) {
                _ctx = NativeEmitCtx(pass_ref=self, type_key="");
                result = _emitter.emit_fromhex(_ctx, arg_vals);
                if result is not None {
                    return result;
                }
            }
        }
    }

    list_spec = self._list_spec_of(trailer.target);
    if list_spec == "u8" and method_name in ("append", "extend") {
        _ba_recv = self._codegen_receiver(trailer.target);
        if _ba_recv is not None {
            _ba_res = self._dispatch_bytearray_method(method_name, _ba_recv, nd);
            if _ba_res is not None {
                return _ba_res;
            }
        }
    }
    if list_spec is not None {
        list_val = self._codegen_receiver(trailer.target);
        if list_val is not None {
            _shape_spec = self._infer_list_elem_type(list_val);
            elem_type_name: str | None = _shape_spec
                if _shape_spec is not None
                else list_spec;
            arg_vals = self._codegen_call_args(nd);
            _orig_args = list(arg_vals);

            _prep_idx = -1;
            if method_name == "append" and arg_vals {
                _prep_idx = 0;
            } elif method_name == "insert" and len(arg_vals) > 1 {
                _prep_idx = 1;
            }
            if _prep_idx >= 0 {
                _prep_params = list(nd.params or []);
                if _prep_idx < len(_prep_params) {
                    _prep_e = _prep_params[_prep_idx];
                    _prep_e = (
                        _prep_e.value if isinstance(_prep_e, uni.KWPair) else _prep_e
                    );
                    arg_vals[_prep_idx] = self._nogc_elem_prep(
                        _prep_e, arg_vals[_prep_idx]
                    );
                }
            }

            _elem_struct = self.var_list_elem_struct.get(target_name)
                if target_name is not None
                else None;
            if _elem_struct is not None
                and isinstance(_elem_struct, ir.PointerType)
                and isinstance(_elem_struct.pointee, ir.LiteralStructType) {
                _tidx = -1;
                if method_name == "append" and arg_vals {
                    _tidx = 0;
                } elif method_name == "insert" and len(arg_vals) > 1 {
                    _tidx = 1;
                }
                if _tidx >= 0 {
                    arg_vals[_tidx] = self._coerce_tuple_to_struct(
                        arg_vals[_tidx], _elem_struct.pointee
                    );
                }
            }
            if method_name == "append" {
                self._set_rc_ctx(
                    "append",
                    f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
                        if nd.loc
                        else 0}"
                );
            }
            result = self._dispatch_primitive_method(
                "list",
                method_name,
                list_val,
                arg_vals,
                elem_type_name,
                kwargs=self._split_call_kwargs(nd),
                kw_node=nd
            );

            self._clear_rc_ctx();
            if result is not None {
                if method_name == "pop"
                    and isinstance(_elem_struct, ir.PointerType)
                    and isinstance(result.type, ir.PointerType) {
                    result = self._coerce_type(result, _elem_struct);
                }
                if method_name == "insert" and not self._nogc_headerless() {
                    self._release_owned_args(_orig_args, op="list_method_arg");
                }
                self._release_owned_args([list_val], op="list_method_receiver");
                return result;
            }
        }
    }

    set_spec = self._set_spec_of(trailer.target);
    if set_spec is not None {
        elem_type_name = set_spec;
        set_val = self._codegen_receiver(trailer.target);
        if set_val is not None {
            arg_vals = self._codegen_call_args(nd);
            if method_name == "add" and arg_vals {
                _sprep_params = list(nd.params or []);
                if _sprep_params {
                    _sprep_e = _sprep_params[0];
                    _sprep_e = (
                        _sprep_e.value if isinstance(_sprep_e, uni.KWPair) else _sprep_e
                    );
                    arg_vals[0] = self._nogc_elem_prep(_sprep_e, arg_vals[0]);
                }
            }
            result = self._dispatch_primitive_method(
                "set", method_name, set_val, arg_vals, elem_type_name
            );
            if result is not None {
                return result;
            }
        }
    }

    tuple_type_key = self._tuple_key_of(trailer.target);
    if tuple_type_key is not None {
        tuple_val = self._codegen_receiver(trailer.target);
        if tuple_val is not None {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "tuple", method_name, tuple_val, arg_vals, tuple_type_key
            );
            if result is not None {
                return result;
            }
        }
    }

    dict_type_key: (str | None) = self._dict_key_of(trailer.target);
    if dict_type_key is None and target_name is not None {
        probe_val = self._codegen_receiver(trailer.target);
        if probe_val is not None {
            dict_type_info = self._infer_dict_type(probe_val);
            if dict_type_info is not None {
                dict_type_key = f"{dict_type_info[0]}:{dict_type_info[1]}";
            }
        }
    }
    if dict_type_key is not None {
        dict_val = self._codegen_receiver(trailer.target);
        dict_type_key = self._dict_key_reconcile(dict_type_key, dict_val);
        if dict_val is not None and dict_type_key is not None {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "dict", method_name, dict_val, arg_vals, dict_type_key
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("int") {
        int_val = self._codegen_receiver(trailer.target);
        if int_val is not None and isinstance(int_val.type, ir.IntType) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "int", method_name, int_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("float") {
        float_val = self._codegen_receiver(trailer.target);
        if float_val is not None and isinstance(float_val.type, ir.DoubleType) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "float", method_name, float_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("complex") {
        cval = self._codegen_receiver(trailer.target);
        if cval is not None and cval.type == self.complex_struct_type.as_pointer() {
            result = self._dispatch_primitive_method(
                "complex", method_name, cval, [], ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in ("count", "index") {
        if self._type_key_of(trailer.target) == "range" {
            rng_val = self._codegen_receiver(trailer.target);
            if rng_val is not None {
                arg_vals = self._codegen_call_args(nd);
                result = self._dispatch_primitive_method(
                    "range", method_name, rng_val, arg_vals, ""
                );
                if result is not None {
                    return result;
                }
            }
        }
    }

    if method_name in self._primitive_method_names("bytes") {
        bytes_val = self._codegen_receiver(trailer.target);
        if bytes_val is not None and self._is_bytes_value(bytes_val) {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "bytes", method_name, bytes_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    if method_name in self._primitive_method_names("str") {
        str_val = self._str_norm_optional(self._codegen_receiver(trailer.target));
        if str_val is not None
            and self._opt_payload_of(str_val.type) == ir.IntType(8).as_pointer() {
            str_val = self._coerce_type(str_val, ir.IntType(8).as_pointer());
        }
        if str_val is not None and str_val.type == ir.IntType(8).as_pointer() {
            arg_vals = self._codegen_call_args(nd);
            result = self._dispatch_primitive_method(
                "str", method_name, str_val, arg_vals, ""
            );
            if result is not None {
                return result;
            }
        }
    }

    type_name: (str | None) = self._enum_name_of(trailer.target)
        or self._struct_name_of(trailer.target);
    obj_val: (ir.Value | None) = None;
    if type_name is None {
        obj_val = self._codegen_receiver(trailer.target);
        if obj_val is not None {
            type_name = self._infer_type_name(obj_val);

            if type_name is None {
                elem_type_name = self._infer_list_elem_type(obj_val);
                if elem_type_name is not None {
                    arg_vals = self._codegen_call_args(nd);
                    if method_name == "append" {
                        self._set_rc_ctx(
                            "append",
                            f"{os.path.basename(self.module.loc.mod_path)}:{nd.loc.first_line
                                if nd.loc
                                else 0}"
                        );
                    }
                    result = self._dispatch_primitive_method(
                        "list", method_name, obj_val, arg_vals, elem_type_name
                    );
                    self._clear_rc_ctx();
                    if result is not None {
                        return result;
                    }
                }
            }
        }
    }
    if type_name is None {
        return None;
    }

    func = self._resolve_method(type_name, method_name);
    _is_mono_method = False;
    if func is None {
        _gm_owner: (str | None) = None;
        for _gm_cur in self._mro_of(type_name) {
            if f"{_gm_cur}.{method_name}" in self._generic_methods {
                _gm_owner = _gm_cur;
                break;
            }
        }
        if _gm_owner is not None {
            _gm_errs = len(self.ctx.errors_had);
            func = self._instantiate_generic_method(nd, _gm_owner, method_name);
            if func is None {
                if len(self.ctx.errors_had) == _gm_errs {
                    self.ctx.emit(
                        E5092,
                        node_override=nd,
                        kind="method",
                        name=f"{_gm_owner}.{method_name}"
                    );
                }
                return None;
            }
            _is_mono_method = True;
        }
    }
    _demoted = False;
    if func is None {
        if f"{type_name}.{method_name}" in self._native_skipped_methods {
            _demoted = True;
        } else {
            _owner = self._resolve_method_owner(type_name, method_name);
            if _owner is not None
                and f"{_owner}.{method_name}" in self._native_skipped_methods {
                _demoted = True;
            }
        }
    }
    if func is None {
        if _demoted {
            self.ctx.emit(
                E5092,
                node_override=nd,
                kind="method",
                name=f"{type_name}.{method_name}",
                help_text=(
                    f"'{method_name}' has no native lowering and was demoted to "
                    f"its Python implementation; it cannot be called from native "
                    f"code. Call it from a Python/@sv context instead."
                )
            );
            return None;
        }
        if self._pyb_base_of(type_name) is not None {
            return self._codegen_pyb_method_call(nd, type_name, method_name);
        }
        return None;
    }

    if obj_val is None {
        obj_val = self._codegen_receiver(trailer.target);
    }
    if obj_val is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.method.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
    }

    args: list[ir.Value] = [obj_val]
        + self._codegen_bound_args(nd, func, self_offset=1);

    if self._arch_has_vtable(type_name) and not _is_mono_method {
        result = self._codegen_virtual_call(obj_val, method_name, args, type_name);
        if result is not None {
            if isinstance(func.return_value.type, ir.VoidType) {
                return ir.Constant(ir.IntType(64), 0);
            }

            return result;
        }
    }

    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(args) {
        if i < len(func.args) {
            coerced.append(self._coerce_type(arg, func.args[i].type));
        } else {
            coerced.append(arg);
        }
    }
    _release = self._transfer_own_args(
        nd, func, coerced, list(coerced), offset=len(coerced) - len(nd.params or [])
    );
    result = self.builder.call(func, coerced, name=f"call.{method_name}");

    self._release_owned_args(_release, op="call_arg");
    self._emit_err_check(self._callee_ability_of(nd) or self._linked_callee_decl(func));

    if isinstance(func.return_value.type, ir.VoidType) {
        return ir.Constant(ir.IntType(64), 0);
    }

    return result;
}

impl NaIRGenPass._emit_obj_str(val: ir.Value) -> (ir.Value | None) {
    type_name = self._infer_type_name(val);
    if type_name is None {
        return None;
    }

    func = self._resolve_method(type_name, "__str__");

    i8p = ir.IntType(8).as_pointer();
    is_null = self.builder.icmp_unsigned(
        "==", val, ir.Constant(val.type, None), name="objstr.isnull"
    );
    fn = self.builder.basic_block.function;
    null_bb = fn.append_basic_block(name="objstr.null");
    live_bb = fn.append_basic_block(name="objstr.live");
    cont_bb = fn.append_basic_block(name="objstr.cont");
    self.builder.cbranch(is_null, null_bb, live_bb);

    self.builder.position_at_end(null_bb);
    none_s = self._make_global_string("None", name_prefix=".objstr.none");
    null_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(live_bb);
    if func is None {
        live_res = self._emit_default_obj_repr(val, type_name);
    } else {
        was_owned = self._is_owned(val);
        if was_owned {
            val.is_owned = False;
        }
        result = None;
        if self._arch_has_vtable(type_name) {
            result = self._codegen_virtual_call(val, "__str__", [val], type_name);
        }
        if result is None {
            coerced = [self._coerce_type(val, func.args[0].type)];
            result = self.builder.call(func, coerced, name="call.__str__");
        }
        if was_owned {
            val.is_owned = True;
        }
        live_res = result;
    }
    live_res = self._coerce_type(live_res, i8p);
    live_end = self.builder.basic_block;
    self.builder.branch(cont_bb);

    self.builder.position_at_end(cont_bb);
    phi = self.builder.phi(i8p, name="objstr.result");
    phi.add_incoming(none_s, null_end);
    phi.add_incoming(live_res, live_end);

    return self._mark_owned(phi);
}

impl NaIRGenPass._emit_default_obj_repr(val: ir.Value, type_name: str) -> ir.Value {
    b = self.builder;
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);

    allocator = self.rc_alloc_fn;
    assert allocator is not None;
    buf_len = len(type_name) + 48;
    buf = self._rc_call_with_ctx(
        allocator,
        [ir.Constant(i64, buf_len)],
        op="obj_repr",
        loc="",
        name="obj.repr.buf"
    );
    self._emit_set_type_tag(b, buf, "str");
    snprintf = self._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
    );
    fmt = self._make_global_string(
        "<%s object at 0x%llx>", name_prefix=".obj.repr.fmt"
    );
    name_g = self._make_global_string(type_name, name_prefix=".obj.repr.name");
    addr = b.ptrtoint(val, i64, name="obj.repr.addr");
    b.call(
        snprintf,
        [buf, ir.Constant(i64, buf_len), fmt, name_g, addr],
        name="obj.repr.snprintf"
    );
    return self._mark_owned(buf);
}

impl NaIRGenPass._opt_unwrap_attr(obj_val: ir.Value) -> ir.Value {
    _ua_opt = self._opt_payload_of(obj_val.type);
    if _ua_opt is None {
        return obj_val;
    }
    _ua_tag = self.builder.extract_value(obj_val, 0, name="attr.opt.tag");
    _ua_none = self.builder.icmp_signed(
        "==", _ua_tag, ir.Constant(ir.IntType(8), 0), name="attr.opt.none"
    );
    self._emit_runtime_raise(
        _ua_none, "AttributeError", "'NoneType' object has no attribute"
    );
    return self.builder.extract_value(obj_val, 1, name="attr.opt.val");
}

impl NaIRGenPass._opt_unwrap_guarded(
    val: (ir.Value | None), what: str, msg: str
) -> (ir.Value | None) {
    """Payload of an optional container, guarded by the absence CPython raises on.

    `has parts: (list[Item] | None)` lowers to a `JacOpt` -- a presence tag
    beside the container pointer -- so a loop, comprehension or slice reading
    the slot receives the wrapper, not a list. Handing that wrapper to the
    container helpers is what used to raise `Type of #1 arg mismatch` out of
    the builder and cost the whole function an ICE. Unwrapping here restores
    the container the rest of the lowering expects; the `None` arm raises
    rather than reading a null, so the two pathways agree on the absent case
    as well as the present one.
    """;
    if val is None {
        return None;
    }
    if self._opt_payload_of(val.type) is None {
        return val;
    }
    _uw_tag = self.builder.extract_value(val, 0, name=f"{what}.opt.tag");
    _uw_none = self.builder.icmp_signed(
        "==", _uw_tag, ir.Constant(ir.IntType(8), 0), name=f"{what}.opt.none"
    );
    self._emit_runtime_raise(_uw_none, "TypeError", msg);
    return self.builder.extract_value(val, 1, name=f"{what}.opt.val");
}

impl NaIRGenPass._opt_unwrap_iterable(
    coll_val: (ir.Value | None)
) -> (ir.Value | None) {
    return self._opt_unwrap_guarded(
        coll_val, "iter", "'NoneType' object is not iterable"
    );
}

impl NaIRGenPass._opt_unwrap_subscript(val: (ir.Value | None)) -> (ir.Value | None) {
    return self._opt_unwrap_guarded(
        val, "sub", "'NoneType' object is not subscriptable"
    );
}

impl NaIRGenPass._accessor_slot_of(
    type_name: str, field_name: str, kind: str
) -> (str | None) {
    _slot = f"{field_name}.{ACCESSOR_SLOT_SUFFIX[kind]}";
    _lay = self._arch_layout(type_name);
    if _lay is not None and _slot in _lay.method_index {
        return _slot;
    }

    return _slot if self._resolve_method(type_name, _slot) is not None else None;
}

impl NaIRGenPass._codegen_accessor_call(
    obj_val: ir.Value, type_name: str, slot: str, args: list[ir.Value]
) -> (ir.Value | None) {
    func = self._resolve_method(type_name, slot);
    if func is None {
        return None;
    }
    _all_args: list[ir.Value] = [obj_val] + args;
    if self._arch_has_vtable(type_name) {
        result = self._codegen_virtual_call(obj_val, slot, _all_args, type_name);
        if result is not None {
            return self._mark_reference_owned(result);
        }
    }
    coerced: list[ir.Value] = [];
    for (i, arg) in enumerate(_all_args) {
        coerced.append(
            self._coerce_type(arg, func.args[i].type) if i < len(func.args) else arg
        );
    }
    return self._mark_reference_owned(
        self.builder.call(func, coerced, name=f"acc.{slot}")
    );
}

impl NaIRGenPass._receiver_union_parts(nd: (uni.UniNode | None)) -> (list[str] | None) {
    if not isinstance(nd, uni.AtomTrailer) or not isinstance(nd.target, uni.Expr) {
        return None;
    }
    _rk = self._mangled_of(self._flow_narrowed_type_of(nd.target));
    if _rk is None or "|" not in _rk {
        return None;
    }
    _rp = [
        p
        for p in self._split_union_key(_rk)
        if p in self.struct_types
    ];
    return _rp if len(_rp) >= 2 else None;
}

impl NaIRGenPass._codegen_union_member(
    obj_val: ir.Value, field_name: str, nd: uni.AtomTrailer, parts: list[str]
) -> (ir.Value | None) {
    """Read each union member through its own field layout or accessor.""";
    source_receiver = obj_val;
    result_type = self._lower_type(nd.type);
    if result_type is None {
        return None;
    }
    arms: list[str] = [];
    for member in parts {
        slot = self._accessor_slot_of(member, field_name, "property");
        if slot is not None {
            if self._resolve_method(member, slot) is None {
                return None;
            }
        } elif field_name not in self.struct_field_indices.get(member, {}) {
            return None;
        }
        arms.append(member);
    }
    receiver = self._narrow_receiver_ptr(obj_val, parts[0]);
    if receiver is None {
        return None;
    }
    obj_val = receiver;
    if self._emit_runtime_class_name_fn() is None {
        return None;
    }
    b = self.builder;
    self._emit_runtime_raise(
        b.icmp_unsigned("==", obj_val, ir.Constant(obj_val.type, None)),
        "AttributeError",
        "'NoneType' object has no attribute"
    );
    done = b.append_basic_block(name="union.property.done");
    incoming: list[tuple[ir.Value, ir.Block]] = [];
    for member in arms {
        hit = b.append_basic_block(name="union.property.hit");
        next_arm = b.append_basic_block(name="union.property.next");
        matches = self._isinstance_class_name_hit(obj_val, [member]);
        if matches is None {
            return None;
        }
        b.cbranch(matches, hit, next_arm);
        b.position_at_end(hit);
        value = self._codegen_field_access(obj_val, field_name, member);
        if value is None {
            return None;
        }
        if not self._is_owned(value) {
            self._emit_rc_retain(value, op="union_member", loc="");
        }
        value = self._coerce_type(value, result_type);
        incoming.append((value, b.block));
        b.branch(done);
        b.position_at_end(next_arm);
    }
    self._emit_runtime_raise(
        ir.Constant(ir.IntType(1), 1),
        "AttributeError",
        f"object has no attribute '{field_name}'"
    );
    incoming.append((self._default_arg_fallback(result_type), b.block));
    b.branch(done);
    b.position_at_end(done);
    result = b.phi(result_type, name="union.property.value");
    for (value, block) in incoming {
        result.add_incoming(value, block);
    }
    self._release_owned_args([source_receiver], op="call_arg");
    return self._mark_reference_owned(result);
}

impl NaIRGenPass._emit_dispatched_field_ptr(
    obj_val: ir.Value,
    type_name: str,
    field_name: str,
    ftype: (ir.Type | None),
    parts: (list[str] | None) = None
) -> (ir.Value | None) {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry as _df_glr }
    reg = _df_glr(self.module, self.prog);
    _base_lay = reg.get_layout(type_name);
    if _base_lay is None or not _base_lay.has_vtable {
        return None;
    }
    _base_idx = _base_lay.field_index.get(field_name);
    if _base_idx is None and ftype is not None {
        return None;
    }
    _variants: list[tuple[str, ir.GlobalVariable | None, int, ir.Type]] = [];
    _uniform = True;
    for _cls in reg.mro_order {
        _cls_mro = self._mro_of(_cls);
        if parts {
            _dom_ok = False;
            for _pp in parts {
                if _pp in _cls_mro {
                    _dom_ok = True;
                    break;
                }
            }
            if not _dom_ok {
                continue;
            }
        } elif type_name not in _cls_mro {
            continue;
        }
        _lay = reg.get_layout(_cls);
        if _lay is None or _cls not in self.struct_types {
            continue;
        }
        _ci = _lay.field_index.get(field_name);
        if _ci is None {
            continue;
        }
        _vt = self._vtable_global_for(_cls) if _lay.has_vtable else None;
        if _vt is None {
            continue;
        }
        _cls_elems = self.struct_types[_cls].elements;
        if _cls_elems is None or _ci >= len(_cls_elems) {
            continue;
        }
        if ftype is None {
            if field_name in self.struct_field_inline.get(_cls, set()) {
                return None;
            }
            _vf = _cls_elems[_ci];
            if _variants and _vf != _variants[0][3] {
                return None;
            }
            _variants.append((_cls, _vt, _ci, _vf));
        } else {
            _variants.append((_cls, _vt, _ci, ftype));
        }
        if _base_idx is None or _ci != _base_idx {
            _uniform = False;
        }
    }
    if ftype is None {
        if not _variants {
            return None;
        }
        ftype = _variants[0][3];
    }
    if field_name == "affected_symbols" and self._na_debug_on() {
        import sys as _df_sys;
        _df_sys.stderr.write(
            f"DFDIAG {type_name}.{field_name}: base_idx={_base_idx} "
            f"variants={len(_variants)} uniform={_uniform}\n"
        );
    }
    if _uniform or not _variants {
        return None;
    }
    i32 = ir.IntType(32);
    _fp_t = ftype.as_pointer();
    b = self.builder;
    _df_vpp = b.gep(
        obj_val, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="df.vt.pp"
    );
    _df_vtp = b.load(_df_vpp, name="df.vt");
    _df_fnc = b.block.function;
    _df_done = _df_fnc.append_basic_block(name=f"df.{field_name}.done");
    _df_incoming: list[tuple[ir.Value, ir.Block]] = [];
    for (_vc, _vt, _ci, _vft) in _variants {
        _df_hit = _df_fnc.append_basic_block(name=f"df.{field_name}.{_vc}");
        _df_nxt = _df_fnc.append_basic_block(name=f"df.{field_name}.n.{_vc}");
        _df_eq = b.icmp_unsigned(
            "==",
            _df_vtp,
            b.bitcast(_vt, _df_vtp.type, name="df.cand"),
            name=f"df.eq.{_vc}"
        );
        b.cbranch(_df_eq, _df_hit, _df_nxt);
        b.position_at_end(_df_hit);
        _df_typed = b.bitcast(
            obj_val, self.struct_types[_vc].as_pointer(), name=f"df.self.{_vc}"
        );
        _df_p = b.gep(
            _df_typed, [ir.Constant(i32, 0), ir.Constant(i32, _ci)], name=f"df.p.{_vc}"
        );
        _df_pc = b.bitcast(_df_p, _fp_t, name=f"df.pc.{_vc}");
        _df_incoming.append((_df_pc, b.block));
        b.branch(_df_done);
        b.position_at_end(_df_nxt);
    }

    if _base_idx is not None {
        _df_fb_recv = obj_val;
        if type_name in self.struct_types {
            _df_fb_recv = b.bitcast(
                obj_val, self.struct_types[type_name].as_pointer(), name="df.self.fb"
            );
        }
        _df_fb = b.gep(
            _df_fb_recv,
            [ir.Constant(i32, 0), ir.Constant(i32, _base_idx)],
            name="df.p.fb"
        );
        _df_fbc = b.bitcast(_df_fb, _fp_t, name="df.pc.fb");
        _df_incoming.append((_df_fbc, b.block));
    } else {
        self._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1),
            "AttributeError",
            f"object has no attribute '{field_name}'"
        );
        _df_incoming.append((ir.Constant(_fp_t, None), b.block));
    }
    b.branch(_df_done);
    b.position_at_end(_df_done);
    _df_phi = b.phi(_fp_t, name=f"df.{field_name}.ptr");
    for (_pv, _pb) in _df_incoming {
        _df_phi.add_incoming(_pv, _pb);
    }
    return _df_phi;
}

impl NaIRGenPass._narrow_receiver_ptr(
    obj_val: ir.Value, type_name: str
) -> (ir.Value | None) {
    obj_val = self._opt_unwrap_attr(obj_val);

    if (
        self?.jacval_type
        and obj_val.type == self.jacval_type
        and type_name in self.struct_types
    ) {
        obj_val = self._unbox_from_jacval(
            obj_val, self.struct_types[type_name].as_pointer()
        );
    }
    if isinstance(obj_val.type, ir.IntType) and (type_name in self.struct_types) {
        obj_val = self.builder.inttoptr(
            obj_val, self.struct_types[type_name].as_pointer(), name="osp.handle.ptr"
        );
    }

    target_struct = self.struct_types.get(type_name);
    if target_struct is not None
        and isinstance(obj_val.type, ir.PointerType)
        and obj_val.type.pointee is not target_struct {
        obj_val = self.builder.bitcast(
            obj_val, target_struct.as_pointer(), name=f"narrow.{type_name}"
        );
    }

    if isinstance(obj_val.type, ir.PointerType) {
        null_ptr = ir.Constant(obj_val.type, None);
        is_null = self.builder.icmp_unsigned(
            "==", obj_val, null_ptr, name="null.field.chk"
        );
        self._emit_runtime_raise(
            is_null, "AttributeError", "'NoneType' object has no attribute"
        );
        return obj_val;
    }
    return None;
}

impl NaIRGenPass._class_const_global(
    arch_name: str, field_name: str
) -> (ir.GlobalVariable | None) {
    for _cn in self._mro_of(arch_name) {
        _gv = self.static_fields.get(f"{_cn}.{field_name}");
        if _gv is not None {
            return _gv;
        }
    }
    return None;
}

impl NaIRGenPass._class_const_variants(
    arch_name: str, field_name: str
) -> tuple[list[tuple[str, ir.GlobalVariable, ir.GlobalVariable]], bool] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    reg = get_layout_registry(self.module, self.prog);
    out: list[tuple[str, ir.GlobalVariable, ir.GlobalVariable]] = [];
    _whole = True;
    for _cls in reg.mro_order {
        if _cls == arch_name or arch_name not in self._mro_of(_cls) {
            continue;
        }
        _gv = self._class_const_global(_cls, field_name);
        if _gv is None {
            continue;
        }
        _vt = self._vtable_global_for(_cls);
        if _vt is None {
            _whole = False;
            continue;
        }
        out.append((_cls, _vt, _gv));
    }
    return (out, _whole, );
}

impl NaIRGenPass._codegen_class_const_read(
    obj_val: ir.Value, type_name: str, field_name: str
) -> (ir.Value | None) {
    _own = self._class_const_global(type_name, field_name);
    (_variants, _whole) = self._class_const_variants(type_name, field_name);
    if not _whole or (_own is None and not _variants) {
        return None;
    }
    _ty = _own.value_type if _own is not None else _variants[0][2].value_type;
    _uniform = True;
    for (_vc, _vt, _gv) in _variants {
        if _gv.value_type != _ty {
            return None;
        }
        if _gv is not _own {
            _uniform = False;
        }
    }
    if _uniform and _own is not None {
        return self.builder.load(_own, name=f"cconst.{field_name}");
    }
    if not self._arch_has_vtable(type_name) {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }

    i32 = ir.IntType(32);
    b = self.builder;
    _cc_vpp = b.gep(_recv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="cc.vt.pp");
    _cc_vtp = b.load(_cc_vpp, name="cc.vt");
    _cc_fn = b.block.function;
    _cc_done = _cc_fn.append_basic_block(name=f"cc.{field_name}.done");
    _cc_incoming: list[tuple[ir.Value, ir.Block]] = [];
    for (_vc, _vt, _gv) in _variants {
        _cc_hit = _cc_fn.append_basic_block(name=f"cc.{field_name}.{_vc}");
        _cc_nxt = _cc_fn.append_basic_block(name=f"cc.{field_name}.n.{_vc}");
        _cc_eq = b.icmp_unsigned(
            "==",
            _cc_vtp,
            b.bitcast(_vt, _cc_vtp.type, name="cc.cand"),
            name=f"cc.eq.{_vc}"
        );
        b.cbranch(_cc_eq, _cc_hit, _cc_nxt);
        b.position_at_end(_cc_hit);
        _cc_incoming.append((b.load(_gv, name=f"cc.{field_name}.{_vc}.v"), b.block));
        b.branch(_cc_done);
        b.position_at_end(_cc_nxt);
    }
    if _own is not None {
        _cc_incoming.append((b.load(_own, name=f"cc.{field_name}.fb"), b.block));
    } else {
        self._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1),
            "AttributeError",
            f"class has no attribute '{field_name}'"
        );
        _cc_incoming.append((self._default_arg_fallback(_ty), b.block));
    }
    b.branch(_cc_done);
    b.position_at_end(_cc_done);
    _cc_phi = b.phi(_ty, name=f"cc.{field_name}");
    for (_pv, _pb) in _cc_incoming {
        _cc_phi.add_incoming(_pv, _pb);
    }
    return _cc_phi;
}

impl NaIRGenPass._codegen_field_access(
    obj_val: ir.Value, field_name: str, type_name: str, nd: (uni.UniNode | None) = None
) -> (ir.Value | None) {
    field_indices = self.struct_field_indices.get(type_name);
    _getter = self._accessor_slot_of(type_name, field_name, "property");
    if _getter is None and (field_indices is None or field_name not in field_indices) {
        _uf_recv = self._narrow_receiver_ptr(obj_val, type_name);
        if _uf_recv is not None {
            _uf_ptr = self._emit_dispatched_field_ptr(
                _uf_recv,
                type_name,
                field_name,
                None,
                parts=self._receiver_union_parts(nd)
            );
            if _uf_ptr is not None {
                return self.builder.load(_uf_ptr, name=f"field.{field_name}");
            }
        }
        return None;
    }
    if _getter is None and self._refuse_opaque_field(nd, type_name, field_name) {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }
    obj_val = _recv;
    if _getter is not None {
        return self._codegen_accessor_call(obj_val, type_name, _getter, []);
    }
    field_ptr = self._field_slot_ptr(obj_val, field_name, type_name);
    if field_name in self.struct_field_inline.get(type_name, set()) {
        return field_ptr;
    }
    return self.builder.load(field_ptr, name=f"field.{field_name}");
}

impl NaIRGenPass._field_slot_ptr(
    obj_val: ir.Value, field_name: str, type_name: str
) -> ir.Value {
    idx = self.struct_field_indices[type_name][field_name];
    field_ptr: (ir.Value | None) = None;
    _struct_t = self.struct_types.get(type_name);
    if (
        _struct_t is not None
        and _struct_t.elements is not None
        and idx < len(_struct_t.elements)
        and field_name not in self.struct_field_inline.get(type_name, set())
    ) {
        field_ptr = self._emit_dispatched_field_ptr(
            obj_val, type_name, field_name, _struct_t.elements[idx]
        );
    }
    if field_ptr is None {
        field_ptr = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
    }
    return field_ptr;
}

impl NaIRGenPass._codegen_place_ptr(
    expr: uni.Expr, allow_inline: bool = False
) -> (ir.Value | None) {
    if isinstance(expr, uni.Name) {
        return self.local_vars.get(expr.sym_name);
    }
    if not (isinstance(expr, uni.AtomTrailer) and expr.is_attr) {
        return None;
    }
    field_name = self._get_name(expr.right);
    if field_name is None {
        return None;
    }
    obj_val = self._codegen_expr(expr.target);
    if obj_val is None {
        return None;
    }
    obj_val = self._opt_unwrap_attr(obj_val);
    type_name = self._struct_name_of(expr.target);
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return None;
    }
    field_indices = self.struct_field_indices.get(type_name);
    if field_indices is None or field_name not in field_indices {
        return None;
    }
    if not allow_inline
        and field_name in self.struct_field_inline.get(type_name, set()) {
        return None;
    }
    if self._accessor_slot_of(type_name, field_name, "property") is not None {
        return None;
    }
    _recv = self._narrow_receiver_ptr(obj_val, type_name);
    if _recv is None {
        return None;
    }
    return self._field_slot_ptr(_recv, field_name, type_name);
}

impl NaIRGenPass._hasvar_is_own(var: uni.UniNode) -> bool {
    if not isinstance(var, uni.HasVar) {
        return False;
    }
    _tt = var.type_tag;
    if _tt is None {
        return False;
    }
    if _tt.ownership == OwnershipKind.OWN {
        return True;
    }
    _inner = _tt.tag;
    return isinstance(_inner, uni.UnaryExpr) and _inner.ownership == OwnershipKind.OWN;
}

impl NaIRGenPass._store_inline_field(
    type_name: str,
    fname: str,
    field_ptr: ir.Value,
    value: (ir.Value | None),
    drop_old: bool
) -> None {
    i8p = ir.IntType(8).as_pointer();
    _ftype = self.struct_field_types.get(type_name, {}).get(fname);
    _pname = getattr(_ftype, "name", "") or "";
    if drop_old and _pname {
        _dropf = self._emit_struct_drop_fields_fn(_pname);
        if _dropf is not None {
            self.builder.call(
                _dropf, [self.builder.bitcast(field_ptr, i8p, name=f"inl.{fname}.old")]
            );
        }
    }
    if value is None {
        return;
    }
    if isinstance(value.type, ir.PointerType) {
        _src = self.builder.load(value, name=f"inl.{fname}.src");
        self.builder.store(_src, field_ptr);
        _free = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        self.builder.call(
            _free, [self.builder.bitcast(value, i8p, name=f"inl.{fname}.shell")]
        );
    } else {
        self.builder.store(value, field_ptr);
    }
}

impl NaIRGenPass._codegen_field_aug_assign(
    target: uni.AtomTrailer,
    rhs: ir.Value,
    aug_op: str,
    rhs_node: (uni.Expr | None) = None
) -> (ir.Value | None) {
    field_name = self._get_name(target.right);
    if field_name is None {
        return None;
    }
    type_name: (str | None) = self._struct_name_of(target.target);
    obj_val = self._codegen_expr(target.target);
    if obj_val is None {
        return None;
    }
    if type_name is None {
        type_name = self._infer_type_name(obj_val);
    }
    if type_name is None {
        return None;
    }

    current = self._read_field_or_refuse(target, obj_val, field_name, type_name);
    if current is None {
        return None;
    }

    scalar = self._apply_scalar_aug_op(
        current,
        rhs,
        aug_op,
        rhs_node,
        unsigned=self._is_unsigned_node(target),
        checked=self._is_sized_node(target) or self._is_sized_node(rhs_node)
    );
    if scalar is not None {
        return scalar;
    }

    coerced = self._coerce_type(rhs, current.type);

    if aug_op == "+=" and isinstance(current.type, ir.PointerType) {
        result = self._emit_binary_op(Tok.PLUS, current, coerced);
        return result if result is not None else current;
    }

    return coerced;
}

impl NaIRGenPass._codegen_field_assign(
    target: uni.AtomTrailer,
    value: ir.Value,
    skip_narrow_coerce: bool = False,
    value_node: (uni.Expr | None) = None
) -> None {
    _fa_errs = len(self.ctx.errors_had);
    field_name = self._get_name(target.right);
    _sa_target = self._get_name(target.target);
    if _sa_target is None {
        _sa_tk = self._type_key_of(target.target);
        if _sa_tk is not None {
            _sa_tkn = _sa_tk.replace(" ", "");
            if _sa_tkn.startswith("type[") and _sa_tkn.endswith("]") {
                _sa_target = _sa_tkn[5:-1];
            }
        }
    }
    if _sa_target is not None
        and field_name is not None
        and _sa_target in self.struct_types
        and _sa_target not in self.local_vars {
        for _sa_cn in self._mro_of(_sa_target) {
            _sa_sf = f"{_sa_cn}.{field_name}";
            if _sa_sf in self.static_fields {
                _sa_val = self._coerce_type(value, self.static_field_types[_sa_sf]);
                self.builder.store(_sa_val, self.static_fields[_sa_sf]);
                return;
            }
        }
    }
    obj_val = self._codegen_expr(target.target);
    if obj_val is not None {
        obj_val = self._opt_unwrap_attr(obj_val);
    }
    type_name: (str | None) = self._struct_name_of(target.target);
    union_parts = self._receiver_union_parts(target);
    if union_parts is not None and field_name is not None {
        first = union_parts[0];
        shared_type = self.struct_field_types.get(first, {}).get(field_name);
        shared_borrow = field_name in self.struct_field_borrow.get(first, set());

        if shared_type is not None
            and all(
                self.struct_field_types.get(part, {}).get(field_name) == shared_type
                    and (field_name in self.struct_field_borrow.get(part, set()))
                        == shared_borrow
                    and field_name not in self.struct_field_inline.get(part, set())
                    and self._accessor_slot_of(part, field_name, "setter") is None
                for part in union_parts
            ) {
            type_name = first;
        } else {
            union_parts = None;
        }
    }
    if (
        obj_val is not None
        and self?.jacval_type
        and obj_val.type == self.jacval_type
        and type_name is not None
        and type_name in self.struct_types
    ) {
        obj_val = self._unbox_from_jacval(
            obj_val, self.struct_types[type_name].as_pointer()
        );
    }
    if type_name is None and obj_val is not None {
        type_name = self._infer_type_name(obj_val);
    }
    field_indices = self.struct_field_indices.get(type_name)
        if type_name is not None
        else None;
    _setter = self._accessor_slot_of(type_name, field_name, "setter")
        if (type_name is not None and field_name is not None)
        else None;
    if (
        field_name is None
        or obj_val is None
        or type_name is None
        or (
            _setter is None
            and (field_indices is None or field_name not in field_indices)
        )
    ) {
        if (
            field_name is not None
            and obj_val is not None
            and type_name is not None
            and _setter is None
            and self._pyb_base_of(type_name) is not None
        ) {
            self._codegen_pyb_field_assign(target, value, obj_val);
            return;
        }
        if len(self.ctx.errors_had) == _fa_errs {
            self.ctx.emit(
                E5092,
                node_override=target,
                kind="field assignment",
                name=(field_name or "<field>")
            );
        }
        return;
    }

    if _setter is None and self._refuse_opaque_field(target, type_name, field_name) {
        return;
    }

    if _setter is not None {
        _fs_struct = self.struct_types.get(type_name);
        if _fs_struct is not None
            and isinstance(obj_val.type, ir.PointerType)
            and obj_val.type.pointee != _fs_struct {
            obj_val = self.builder.bitcast(
                obj_val, _fs_struct.as_pointer(), name="acc.recv.cast"
            );
        }
        if self._codegen_accessor_call(obj_val, type_name, _setter, [value]) is None {
            self.ctx.emit(
                E5092,
                node_override=target,
                kind="field assignment",
                name=field_name,
                help_text=f"'{type_name}.{field_name}' is a property whose "
                f"setter has no native lowering."
            );
        }
        return;
    }
    field_types = self.struct_field_types.get(type_name);
    idx = field_indices[field_name];
    ftype = field_types[field_name];

    _fa_struct = self.struct_types.get(type_name);
    if (
        _fa_struct is not None
        and isinstance(obj_val.type, ir.PointerType)
        and obj_val.type.pointee != _fa_struct
    ) {
        obj_val = self.builder.bitcast(
            obj_val, _fa_struct.as_pointer(), name="fa.recv.cast"
        );
    }

    _slot_struct = self.struct_types.get(type_name);
    _slot_elems = _slot_struct?.elements if _slot_struct is not None else None;
    if _slot_elems is not None
        and idx < len(_slot_elems)
        and _slot_elems[idx] != ftype {
        ftype = _slot_elems[idx];
    }

    if field_name in self.struct_field_inline.get(type_name, set()) {
        _inl_fp = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
        self._store_inline_field(type_name, field_name, _inl_fp, value, True);
        self._nogc_consume_local(value_node);
        return;
    }

    _vt_struct = type_name in self.clib_vtable_structs;
    _is_clib_cb = (
        _vt_struct
        and isinstance(ftype, ir.PointerType)
        and isinstance(ftype.pointee, ir.FunctionType)
    );
    if _is_clib_cb {
        value = self._clib_coerce_callback(value, ftype);
    } elif not (skip_narrow_coerce and value.type != ftype) {
        value = self._coerce_type(value, ftype);
    }
    field_ptr: (ir.Value | None) = None;
    if not _vt_struct {
        field_ptr = self._emit_dispatched_field_ptr(
            obj_val, type_name, field_name, ftype, union_parts
        );
    }
    if field_ptr is None {
        field_ptr = self.builder.gep(
            obj_val,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), idx)],
            name=f"field.{field_name}.ptr"
        );
    }

    _borrow_field = field_name in self.struct_field_borrow.get(type_name, set());
    if self._elem_kind(ftype) != "raw" and not _borrow_field {
        self._emit_take_ref(
            value,
            op="field_set",
            loc=f"{os.path.basename(self.module.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
        old_field_val = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        self._set_rc_ctx(
            "field_set",
            f"{os.path.basename(self.module.loc.mod_path)}:{target.loc.first_line
                if target.loc
                else 0}"
        );
        self._emit_elem_release(self.builder, ftype, old_field_val);
        self._clear_rc_ctx();
    }
    _fs_opt = self._opt_payload_of(ftype);
    if _fs_opt is not None
        and isinstance(_fs_opt, ir.PointerType)
        and not _borrow_field {
        _fs_loc = f"{os.path.basename(self.module.loc.mod_path)}:{target.loc.first_line
            if target.loc
            else 0}";
        _fs_new_pv = self.builder.extract_value(
            value, 1, name=f"field.{field_name}.newpv"
        );
        self._emit_take_ref(_fs_new_pv, op="field_set", loc=_fs_loc);
        _fs_old = self.builder.load(field_ptr, name=f"field.{field_name}.old");
        _fs_old_pv = self.builder.extract_value(
            _fs_old, 1, name=f"field.{field_name}.oldpv"
        );
        self._emit_rc_release_simple(_fs_old_pv, op="field_set", loc=_fs_loc);
    }
    self.builder.store(value, field_ptr);
    self._nogc_consume_local(value_node);
}

impl NaIRGenPass._receiver_routed_method_fn(
    nd: uni.UniNode, _sfull: str, _mnames: list[str], _recv_cls: (str | None)
) -> (ir.Function | None) {
    _sfunc = self.method_funcs[_sfull];

    _owner_cls = _sfull.partition(".")[0];
    if (
        _recv_cls is not None
        and _recv_cls != _owner_cls
        and _recv_cls in self.struct_types
        and _sfull not in self.static_methods
    ) {
        import from jaclang.compiler.passes.layout_pass {
            get_layout_registry as _sc_glr
        }
        _sc_reg = _sc_glr(self.module, self.prog);
        if not _sc_reg.is_primary_ancestor(_recv_cls, _owner_cls) {
            _mn_part = _sfull.partition(".")[2];
            _spec_key = f"{_recv_cls}.{_mn_part}${_owner_cls}";
            if _spec_key not in self.method_funcs
                and _spec_key not in self._native_skipped_methods {
                _anc_arch = self.arch_ast_map.get(_owner_cls);
                _anc_meth: (uni.Ability | None) = None;
                if _anc_arch is not None and _anc_arch.body is not None {
                    for _ab in _anc_arch.body {
                        if isinstance(_ab, uni.Ability)
                            and _ab.name_ref is not None
                            and _ab.name_ref.sym_name in _mnames
                            and _ab.signature is not None {
                            _anc_meth = _ab;
                            break;
                        }
                    }
                }
                if _anc_meth is None {
                    self.ctx.emit(
                        E5092,
                        node_override=nd,
                        kind="call",
                        name=_sfull,
                        help_text=(
                            "An unbound ancestor call runs the "
                            "ancestor's body on this receiver, whose "
                            "field layout differs; specializing it "
                            "needs the ancestor's source, which is "
                            "not visible to this unit."
                        )
                    );
                    return None;
                }
                _spec_arg_tys: list[ir.Type] = [
                    self.struct_types[_recv_cls].as_pointer()
                ];
                for _at in _sfunc.function_type.args[1:] {
                    _spec_arg_tys.append(_at);
                }
                _spec_fnty = ir.FunctionType(
                    _sfunc.function_type.return_type, _spec_arg_tys
                );
                _spec_fn = ir.Function(self.llvm_module, _spec_fnty, name=_spec_key);
                for (_sai, _sa) in enumerate(_sfunc.args) {
                    if _sai < len(_spec_fn.args) {
                        _spec_fn.args[_sai].name = _sa.name;
                    }
                }
                self.method_funcs[_spec_key] = _spec_fn;
                self._codegen_method(_recv_cls, _anc_meth, symbol_override=_spec_key);
            }
            _spec_ready = self.method_funcs.get(_spec_key);
            if _spec_ready is None {
                self.ctx.emit(E5092, node_override=nd, kind="call", name=_spec_key);
                return None;
            }
            _sfunc = _spec_ready;
        }
    }
    return _sfunc;
}

impl NaIRGenPass._emit_class_routed_call(
    nd: uni.FuncCall,
    _sfull: str,
    _mnames: list[str],
    _given_recv: (ir.Value | None),
    _given_recv_cls: (str | None)
) -> (ir.Value | None) {
    method_name = _sfull.partition(".")[2];
    _recv_cls: (str | None) = _given_recv_cls;
    if _recv_cls is None {
        _recv_first = (nd.params or [None])[0];
        _recv_cls = (
            self._struct_name_of(_recv_first)
                if _recv_first is not None and not isinstance(_recv_first, uni.KWPair)
                else None
        );
    }
    _sfunc = self._receiver_routed_method_fn(nd, _sfull, _mnames, _recv_cls);
    if _sfunc is None {
        return None;
    }

    _spos: list[uni.UniNode] = [];
    _skw: dict[str, uni.UniNode] = {};
    for _p in (nd.params or []) {
        if isinstance(_p, uni.KWPair) {
            if _p.key is not None {
                _skw[_p.key.sym_name] = _p.value;
            }
        } else {
            _spos.append(_p);
        }
    }
    _sdefaults: dict[str, uni.UniNode] = {};
    _sarch_nd = self.arch_ast_map.get(_sfull.split(".")[0]);
    if _sarch_nd is not None and _sarch_nd.body is not None {
        for _sb in _sarch_nd.body {
            if isinstance(_sb, uni.Ability)
                and _sb.name_ref is not None
                and _sb.name_ref.sym_name in _mnames
                and isinstance(_sb.signature, uni.FuncSignature) {
                for _sprm in _sb.signature.get_parameters() {
                    if isinstance(_sprm, uni.ParamVar)
                        and _sprm.name is not None
                        and _sprm.value is not None {
                        _sdefaults[_sprm.name.value] = _sprm.value;
                    }
                }
                break;
            }
        }
    }
    _sargs: list[ir.Value] = [];
    _bad_arg = False;
    if _given_recv is not None {
        _sargs.append(_given_recv);
    }
    for _p in _spos {
        _pv = self._codegen_expr(_p);
        if _pv is None {
            return None;
        }
        _sargs.append(_pv);
    }
    _used_kw: set[str] = set();
    for _ai in range(len(_sargs), len(_sfunc.args)) {
        _an = _sfunc.args[_ai].name or "";
        if _an in _skw {
            _pv = self._codegen_expr(_skw[_an]);
            if _pv is None {
                return None;
            }
            _used_kw.add(_an);
            _sargs.append(_pv);
        } elif _an in _sdefaults {
            _pv = self._codegen_expr(_sdefaults[_an]);
            if _pv is None {
                _pv = self._default_arg_fallback(_sfunc.args[_ai].type);
            }
            _sargs.append(_pv);
        } else {
            if _an == "" and _skw {
                _bad_arg = True;
            }
            _sargs.append(self._default_arg_fallback(_sfunc.args[_ai].type));
        }
    }
    if _bad_arg or (len(_used_kw) < len(_skw)) {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="call",
            name=_sfull,
            help_text=(
                "A keyword argument on this class-routed call could "
                "not be matched to the callee's parameters, so the "
                "call cannot lower faithfully."
            )
        );
        return None;
    }
    for (_i, _sv) in enumerate(_sargs) {
        if _i < len(_sfunc.args) {
            _sargs[_i] = self._coerce_type(_sv, _sfunc.args[_i].type);
        }
    }
    _release = self._transfer_own_args(
        nd, _sfunc, _sargs, list(_sargs), offset=1 if _given_recv is not None else 0
    );
    _sr = self.builder.call(_sfunc, _sargs, name=f"scall.{method_name}");
    self._release_owned_args(_release, op="call_arg");
    self._emit_err_check(
        self._callee_ability_of(nd) or self._linked_callee_decl(_sfunc)
    );
    if isinstance(_sfunc.return_value.type, ir.VoidType) {
        return None;
    }
    return _sr;
}
