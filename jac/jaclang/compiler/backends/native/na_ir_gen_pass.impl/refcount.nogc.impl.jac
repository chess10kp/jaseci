glob _NOGC_OSP_ENGINE_STRUCTS: tuple[str, ...] = (
         "Slot",
         "Plan",
         "WalkerDesc",
         "NodeDesc",
         "WalkScope",
         "OspRuntime",
         "Frame",
         "OspEngine",
         "OspGraph",
         "Adj",
         "EdgeRow"
     ),
     _NOGC_CONTAINER_DROP_OPS: tuple[str, ...] = (
         "scope_exit",
         "field_set",
         "iter_end",
         "overwrite",
         "fori_coll",
         "binop_lhs",
         "binop_rhs",
         "binop_list",
         "for_reset",
         "call_arg",
         "list_method_arg",
         "last_use",
         "del_stmt"
     ),
     _NOGC_TEMP_FREE_OPS: tuple[str, ...] = (
         "binop_lhs",
         "binop_rhs",
         "binop_list",
         "str_rhs",
         "ba_aug"
     );

impl NaIRGenPass._nogc_borrow_local_assign(nd: object) -> bool {
    if not self._nogc_headerless() or not isinstance(nd, uni.Assignment) {
        return False;
    }
    if len(nd.target) != 1 or not isinstance(nd.target[0], uni.Name) {
        return False;
    }
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    _sym = nd.target[0].sym;
    if _sym is not None and is_borrow_kind(_sym.ownership) {
        return True;
    }
    return isinstance(nd.value, uni.UnaryExpr) and is_borrow_kind(nd.value.ownership);
}

impl NaIRGenPass._emit_magic_check(
    b: ir.IRBuilder, ptr: ir.Value, name_prefix: str = "mc"
) -> ir.Value {
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _slot = b.gep(
        ptr, [ir.Constant(i64, HDR_ALLOC_ID_OFF)], name=f"{name_prefix}.slot"
    );
    _ptr = b.bitcast(_slot, i64_ptr, name=f"{name_prefix}.ptr");
    _val = b.load(_ptr, name=f"{name_prefix}.val");
    _hi = b.lshr(_val, ir.Constant(i64, 32), name=f"{name_prefix}.hi");
    _hi = b.and_(_hi, ir.Constant(i64, 0xFFFF), name=f"{name_prefix}.hi.magic");
    return b.icmp_unsigned(
        "==", _hi, ir.Constant(i64, HDR_MAGIC), name=f"{name_prefix}.ok"
    );
}

impl NaIRGenPass._nogc_owned_world -> bool {
    if not self._nogc_headerless() {
        return False;
    }
    _opts = self.prog.options;
    if bool(getattr(_opts, "kernel_unit", False)) {
        return False;
    }
    try {
        return bool(_opts.nogc_enforced_for(self.module.name));
    } except Exception {
        return False;
    }
}

impl NaIRGenPass._nogc_drop_op_active(op: str) -> bool {
    if op not in _NOGC_CONTAINER_DROP_OPS {
        return False;
    }
    if op == "field_set" {
        return self._nogc_owned_world();
    }
    return True;
}

impl NaIRGenPass._arch_is_osp_name(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.module, self.prog).get_layout(arch_name);
    return lay is not None and lay.is_osp;
}

impl NaIRGenPass._arch_is_walker_name(arch_name: str) -> bool {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.module, self.prog).get_layout(arch_name);
    return lay is not None and lay.arch_type == "walker";
}

impl NaIRGenPass._nogc_headerless -> bool {
    return getattr(self.module.gen, "nogc_enforced", False)
        and self._gc_mode() == "none";
}

impl NaIRGenPass._emit_nogc_field_drops(
    b: ir.IRBuilder, type_name: str, _dobj: ir.Value
) -> None {
    i8p = ir.IntType(8).as_pointer();
    _hook = self._drop_hook_for(type_name);
    if _hook is not None {
        b.call(_hook, [b.bitcast(_dobj, _hook.args[0].type)]);
    }
    field_types = self.struct_field_types.get(type_name, {});
    field_indices = self.struct_field_indices.get(type_name, {});
    foreign_fields = self.struct_field_foreign.get(type_name, set());
    borrow_fields = self.struct_field_borrow.get(type_name, set());
    i32 = ir.IntType(32);
    for (fname, ftype) in field_types.items() {
        if fname in borrow_fields {
            continue;
        }
        if fname in self.struct_field_inline.get(type_name, set()) {
            _in_idx = field_indices.get(fname, -1);
            _in_name = getattr(ftype, "name", "") or "";
            _in_dropf = self._emit_struct_drop_fields_fn(_in_name)
                if _in_name
                else None;
            if _in_dropf is not None and _in_idx >= 0 {
                _in_fp = b.gep(
                    _dobj,
                    [ir.Constant(i32, 0), ir.Constant(i32, _in_idx)],
                    name=f"drop.{fname}.p"
                );
                b.call(_in_dropf, [b.bitcast(_in_fp, i8p, name=f"drop.{fname}.i8")]);
            }
            continue;
        }
        if fname in foreign_fields {
            continue;
        }
        _opt_payload = self._opt_ptr_payload_of(ftype);
        if _opt_payload is not None and not self._nogc_owned_world() {
            continue;
        }
        _ptr_ty = _opt_payload if _opt_payload is not None else ftype;
        if not isinstance(_ptr_ty, ir.PointerType) {
            continue;
        }
        idx = field_indices.get(fname, -1);
        if idx < 0 {
            continue;
        }
        _fld_drop = self._nogc_drop_fn_for(_ptr_ty, type_name);
        if _fld_drop is None {
            continue;
        }
        fp = b.gep(
            _dobj, [ir.Constant(i32, 0), ir.Constant(i32, idx)], name=f"drop.{fname}.p"
        );
        fv = b.load(fp, name=f"drop.{fname}");
        if _opt_payload is not None {
            fv = b.extract_value(fv, 1, name=f"drop.{fname}.pv");
        }
        fv_i8 = b.bitcast(fv, i8p, name=f"drop.{fname}.i8");
        b.call(_fld_drop, [fv_i8]);
    }
}

impl NaIRGenPass._nogc_drop_fn_for(
    ptr_ty: ir.PointerType, self_type: str = ""
) -> (ir.Function | None) {
    _pname = getattr(ptr_ty.pointee, "name", "") or "";
    if _pname in self.struct_types or (_pname and _pname == self_type) {
        return self._emit_struct_drop_fn(_pname);
    }
    if _pname.startswith("List.")
        or _pname.startswith("Dict.")
        or _pname.startswith("Set.") {
        return self._emit_container_drop_fn(_pname);
    }
    return None;
}

impl NaIRGenPass._nogc_elem_drop_slot_ty -> ir.Type {
    return ir.FunctionType(ir.VoidType(), [ir.IntType(8).as_pointer()]).as_pointer();
}

impl NaIRGenPass._nogc_type_arg_mangles_of_str(m: str) -> list[str] {
    _open = m.find("[");
    if _open < 0 or not m.endswith("]") {
        return [];
    }
    _inner = m[_open + 1:-1];
    _args: list[str] = [];
    _depth = 0;
    _cur = "";
    for _ch in _inner {
        if _ch == "[" {
            _depth += 1;
        } elif _ch == "]" {
            _depth -= 1;
        }
        if _ch == "," and _depth == 0 {
            _args.append(_cur.strip());
            _cur = "";
        } else {
            _cur += _ch;
        }
    }
    if _cur.strip() {
        _args.append(_cur.strip());
    }
    return _args;
}

impl NaIRGenPass._nogc_type_arg_mangles(expr: uni.UniNode | None) -> list[str] {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return [];
    }
    return self._nogc_type_arg_mangles_of_str(expr.type.mangle());
}

impl NaIRGenPass._drop_spec_for_mangle(mangle: str) -> (tuple[str, ir.Type] | None) {
    if mangle == "int" or mangle == "bool" {
        return ("i64", ir.IntType(64));
    }

    if mangle in ("any", "Any") {
        return ("jacval", self.jacval_type) if self?.jacval_type else None;
    }
    if mangle == "float" {
        return ("f64", ir.DoubleType());
    }
    if mangle == "str"
        or mangle in self.struct_types
        or mangle.startswith("list[")
        or mangle.startswith("dict[")
        or mangle.startswith("set[") {
        return ("ptr", ir.IntType(8).as_pointer());
    }
    return None;
}

impl NaIRGenPass._nogc_stamp_elem_drops(
    cont: ir.Value | None, elem_mangles: list[str]
) -> None {
    if cont is None or self._gc_mode() != "none" {
        return;
    }
    i32 = ir.IntType(32);
    _slot_ty = self._nogc_elem_drop_slot_ty();
    if not isinstance(cont.type, ir.PointerType) {
        return;
    }
    _cont_struct = cont.pointee_type;
    if not isinstance(_cont_struct, ir.IdentifiedStructType) {
        return;
    }
    _layout = self.container_layouts.get(_cont_struct.name);
    if _layout is None {
        return;
    }
    _base = _layout["drop_base"];
    _cont_elems = _cont_struct.elements;
    if _cont_elems is not None
        and _base + len(_layout["data_fields"]) > len(_cont_elems) {
        return;
    }
    _slot_specs: list[tuple[int, str]] = [
        (_base + _k, elem_mangles[_k])
        for _k in range(len(_layout["data_fields"]))
        if _k < len(elem_mangles)
    ];
    for (_idx, _em) in _slot_specs {
        _drop_target = self._drop_fn_for(_em);
        if _drop_target is None {
            continue;
        }
        _fn_cast = self.builder.bitcast(_drop_target, _slot_ty, name="edrop.stamp.fn");
        _sp = self.builder.gep(
            cont, [ir.Constant(i32, 0), ir.Constant(i32, _idx)], name="edrop.stamp.p"
        );
        self.builder.store(_fn_cast, _sp);
    }
}

impl NaIRGenPass._nogc_consume_local(expr: uni.UniNode | None) -> bool {
    if not self._nogc_owned_world() {
        return False;
    }
    if not isinstance(expr, uni.Name)
        or not self._nogc_headerless()
        or not self._is_move_site(expr) {
        return False;
    }
    _slot = self.local_vars.get(expr.sym_name);
    if _slot is None or not isinstance(_slot.type, ir.PointerType) {
        return False;
    }
    _slot_ty = _slot.pointee_type;
    _movable = (
        isinstance(_slot_ty, ir.PointerType)
        or (self._str_desc_ty is not None and _slot_ty == self._str_desc_ty)
        or self._opt_ptr_payload_of(_slot_ty) is not None
    );
    if not _movable {
        return False;
    }
    self.builder.store(ir.Constant(_slot_ty, None), _slot);
    return True;
}

impl NaIRGenPass._nogc_elem_prep(
    expr: uni.UniNode | None, val: ir.Value | None
) -> (ir.Value | None) {
    if val is None {
        return val;
    }
    if self._gc_mode() != "none" {
        if isinstance(expr, uni.Name)
            and isinstance(val.type, ir.PointerType)
            and self._is_move_site(expr) {
            _mslot = self.local_vars.get(expr.sym_name);
            if _mslot is not None
                and isinstance(_mslot.type, ir.PointerType)
                and isinstance(_mslot.type.pointee, ir.PointerType) {
                self.builder.store(ir.Constant(_mslot.type.pointee, None), _mslot);
                self._mark_owned(val);
            }
        }
        return val;
    }
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        if self._is_owned(val) or isinstance(expr, uni.FString) {
            return val;
        }
        if self._nogc_consume_local(expr) {
            return val;
        }
        if self.str_new_fn is None {
            self._emit_str_len_helpers();
        }
        _ep_hl = self._nogc_headerless();
        _ep_data = self.builder.extract_value(
            val, 0 if _ep_hl else 1, name="elem.prep.data"
        );
        _ep_len = self.builder.extract_value(
            val, 1 if _ep_hl else 2, name="elem.prep.len"
        );
        _ep_copy = self.builder.call(
            self.str_new_fn, [_ep_data, _ep_len], name="elem.prep.copy"
        );
        self._mark_owned(_ep_copy);
        return _ep_copy;
    }
    if not (
        isinstance(val.type, ir.PointerType)
        and isinstance(val.type.pointee, ir.IntType)
        and val.type.pointee.width == 8
    ) {
        if isinstance(val.type, ir.PointerType)
            and isinstance(expr, uni.Name)
            and expr.sym_name in self.local_vars
            and expr.sym_name not in self.param_vars
            and not self._nogc_consume_local(expr) {
            self.nogc_no_free_vars.add(expr.sym_name);
        }
        return val;
    }
    if isinstance(expr, uni.FString) {
        return val;
    }
    if isinstance(expr, uni.AtomTrailer) and isinstance(expr.right, uni.IndexSlice) {
        _bm = "";
        try {
            _bm = expr.target.type.mangle() if expr.target.type is not None else "";
        } except Exception {
            _bm = "";
        }
        if _bm == "str" {
            return val;
        }
    }
    if self._nogc_consume_local(expr) {
        return val;
    }
    return self._rc_strdup(val, name="elem.copy");
}

impl NaIRGenPass._nogc_emit_drop(val: ir.Value, op: str = "", loc: str = "") -> bool {
    if not isinstance(val.type, ir.PointerType) {
        return False;
    }
    _tn = self._struct_ptr_pointee_name(val);
    if _tn is not None and _tn in _NOGC_OSP_ENGINE_STRUCTS {
        return True;
    }
    _fn: (ir.Function | None) = None;
    if _tn is not None and _tn in self.struct_types {
        _fn = self._emit_struct_drop_fn(_tn);
    } else {
        _pointee = val.type?.pointee;
        _pname = getattr(_pointee, "name", "") or "";
        if _pname.startswith("List.")
            or _pname.startswith("Dict.")
            or _pname.startswith("Set.") {
            _fn = self._emit_container_drop_fn(_pname);
        }
    }
    if _fn is None {
        return False;
    }
    i8p = ir.IntType(8).as_pointer();
    v_i8 = self.builder.bitcast(val, i8p, name="drop.cast");
    self.builder.call(_fn, [v_i8]);
    return True;
}

impl NaIRGenPass._nogc_free_scratch(val: ir.Value, op: str) -> None {
    if op
        not in (
            "print_tmp",
            "fstr_obj_tmp",
            "mstr_old",
            "mstr_val",
            "fstring",
            "str_index",
            "tuple_move_box"
        ) {
        return;
    }
    if not isinstance(val.type, ir.PointerType) {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    _free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    _v_i8 = self.builder.bitcast(val, i8p, name="scratch.free.cast");
    self.builder.call(_free_fn, [_v_i8]);
}

impl NaIRGenPass._nogc_osp_skip(val: ir.Value) -> bool {
    if not getattr(self.module.gen, "nogc_enforced", False) {
        return False;
    }
    import os;
    if os.path.basename(self.module.loc.mod_path or "").startswith("osp_core_") {
        return True;
    }
    _tn = self._struct_ptr_pointee_name(val);
    if _tn is None {
        return False;
    }
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    lay = get_layout_registry(self.module, self.prog).get_layout(_tn);
    return lay is not None and lay.is_osp;
}

impl NaIRGenPass._nogc_opt_slots_owned -> bool {
    return not self._nogc_headerless() or self._nogc_owned_world();
}

impl NaIRGenPass._nogc_str_free_owned(val: ir.Value) -> None {
    _d = val;
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        _d = self.builder.extract_value(val, 0, name="osf.data");
    }
    if not isinstance(_d.type, ir.PointerType) {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    _free_fn = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    self.builder.call(_free_fn, [self.builder.bitcast(_d, i8p, name="osf.cast")]);
}
