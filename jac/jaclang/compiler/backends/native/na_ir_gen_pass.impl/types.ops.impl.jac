impl NaIRGenPass._entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;

    _gc = self._gen_ctx;
    if _gc is not None and func is _gc.resume_fn {
        i64 = ir.IntType(64);
        size = self._abi_sizeof(var_type);
        offset = (_gc.cursor + 7) // 8 * 8;
        _gc.cursor = offset + size;
        _gc.slots.append((name, offset, var_type));
        cur_block = self.builder.block;
        entry_block = func.entry_basic_block;
        if entry_block.instructions {
            self.builder.position_before(entry_block.instructions[0]);
        } else {
            self.builder.position_at_start(entry_block);
        }
        raw = self.builder.gep(
            _gc.frame_i8, [ir.Constant(i64, offset)], name=f"{name}.slot"
        );
        slot = self.builder.bitcast(raw, var_type.as_pointer(), name=f"{name}.frame");
        self.builder.position_at_end(cur_block);
        return slot;
    }

    entry_block = func.entry_basic_block;

    cur_block = self.builder.block;

    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);

    self.builder.store(self._zero_const(var_type), alloca);

    self.builder.position_at_end(cur_block);
    return alloca;
}

impl NaIRGenPass._stack_entry_alloca(var_type: ir.Type, name: str) -> ir.Value {
    func = self.builder.function;
    entry_block = func.entry_basic_block;
    cur_block = self.builder.block;
    if entry_block.instructions {
        self.builder.position_before(entry_block.instructions[0]);
    } else {
        self.builder.position_at_start(entry_block);
    }
    alloca = self.builder.alloca(var_type, name=name);
    self.builder.position_at_end(cur_block);
    return alloca;
}

impl NaIRGenPass._abi_sizeof(t: ir.Type) -> int {
    if isinstance(t, (ir.IntType, ir.DoubleType, ir.PointerType, ir.FloatType)) {
        return 8;
    }
    if isinstance(t, ir.ArrayType) {
        return t.count * ((self._abi_sizeof(t.element) + 7) // 8 * 8);
    }
    elems = t.elements if isinstance(t, (ir.Aggregate, ir.VectorType)) else None;
    if elems is not None {
        total = 0;
        for e in elems {
            assert isinstance(e, ir.Type);
            total += (self._abi_sizeof(e) + 7) // 8 * 8;
        }
        return total;
    }
    raise RuntimeError(
        f"native codegen internal error: _abi_sizeof has no layout for {t!r}. "
        f"A generator-frame slot of unknown size would silently corrupt "
        f"adjacent slots; teach _abi_sizeof this type instead."
    );
}

impl NaIRGenPass._consume_bool(val: ir.Value) -> ir.Value {
    result = self._to_bool(val);
    self._release_owned_args([val], op="condition");
    return result;
}

impl NaIRGenPass._to_bool(val: ir.Value) -> ir.Value {
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        return self.builder.icmp_signed(
            "!=",
            self.builder.extract_value(
                val, len(list(self._str_desc_ty.elements)) - 1, name="s.tlen"
            ),
            ir.Constant(ir.IntType(64), 0),
            name="s.truthy"
        );
    }
    if isinstance(val.type, ir.IntType) and val.type.width == 1 {
        return val;
    }
    if self?.jacval_type and val.type == self.jacval_type {
        return self._jacval_truthy(val);
    }
    _tb_opt = self._opt_payload_of(val.type);
    if _tb_opt is not None {
        _tb_tag = self.builder.extract_value(val, 0, name="tobool.opt.tag");
        _tb_set = self.builder.icmp_signed(
            "!=", _tb_tag, ir.Constant(ir.IntType(8), 0), name="tobool.opt.set"
        );
        _tb_func = self.builder.basic_block.function;
        _tb_entry = self.builder.basic_block;
        _tb_pay_bb = _tb_func.append_basic_block(name="tobool.opt.payload");
        _tb_merge_bb = _tb_func.append_basic_block(name="tobool.opt.done");
        self.builder.cbranch(_tb_set, _tb_pay_bb, _tb_merge_bb);
        self.builder.position_at_start(_tb_pay_bb);
        _tb_pv = self.builder.extract_value(val, 1, name="tobool.opt.pv");
        _tb_t = self._to_bool(_tb_pv);
        _tb_pay_end = self.builder.basic_block;
        self.builder.branch(_tb_merge_bb);
        self.builder.position_at_start(_tb_merge_bb);
        _tb_phi = self.builder.phi(ir.IntType(1), name="tobool.opt");
        _tb_phi.add_incoming(ir.Constant(ir.IntType(1), 0), _tb_entry);
        _tb_phi.add_incoming(_tb_t, _tb_pay_end);
        return _tb_phi;
    }
    if isinstance(val.type, ir.IntType) {
        return self.builder.icmp_unsigned(
            "!=", val, ir.Constant(val.type, 0), name="tobool"
        );
    }
    if isinstance(val.type, (ir.DoubleType, ir.FloatType)) {
        return self.builder.fcmp_unordered(
            "!=", val, ir.Constant(val.type, 0.0), name="tobool"
        );
    }
    if isinstance(val.type, ir.PointerType) {
        _is_container = False;
        for (_, _lt) in self.list_types.items() {
            if val.type == _lt.as_pointer() {
                _is_container = True;
                break;
            }
        }
        if not _is_container {
            for (_, _dt) in self.dict_types.items() {
                if val.type == _dt.as_pointer() {
                    _is_container = True;
                    break;
                }
            }
        }
        if not _is_container {
            for (_, _st) in self.set_types.items() {
                if val.type == _st.as_pointer() {
                    _is_container = True;
                    break;
                }
            }
        }
        if _is_container {
            _i32 = ir.IntType(32);
            _tc_null = self.builder.icmp_unsigned(
                "==", val, ir.Constant(val.type, None), name="tobool.cont.null"
            );
            _tc_func = self.builder.basic_block.function;
            _tc_entry = self.builder.basic_block;
            _tc_len_bb = _tc_func.append_basic_block(name="tobool.cont.len");
            _tc_end_bb = _tc_func.append_basic_block(name="tobool.cont.end");
            self.builder.cbranch(_tc_null, _tc_end_bb, _tc_len_bb);
            self.builder.position_at_start(_tc_len_bb);
            _len_ptr = self.builder.gep(
                val, [ir.Constant(_i32, 0), ir.Constant(_i32, 0)], name="tobool.len.ptr"
            );
            _len = self.builder.load(_len_ptr, name="tobool.len");
            _tc_nonempty = self.builder.icmp_unsigned(
                "!=", _len, ir.Constant(ir.IntType(64), 0), name="tobool.cont.nonempty"
            );
            _tc_len_end = self.builder.basic_block;
            self.builder.branch(_tc_end_bb);
            self.builder.position_at_start(_tc_end_bb);
            _tc_phi = self.builder.phi(ir.IntType(1), name="tobool");
            _tc_phi.add_incoming(ir.Constant(ir.IntType(1), 0), _tc_entry);
            _tc_phi.add_incoming(_tc_nonempty, _tc_len_end);
            return _tc_phi;
        }

        if self._is_bytes_value(val) {
            return self._emit_bytes_truthy(val);
        }

        if val.type == ir.IntType(8).as_pointer() {
            return self._call_str_truthy(self.builder, val, name="tobool.str");
        }

        null_ptr = ir.Constant(val.type, None);
        return self.builder.icmp_unsigned("!=", val, null_ptr, name="tobool");
    }
    return val;
}

impl NaIRGenPass._jacval_truthy(jv: ir.Value) -> ir.Value {
    b = self.builder;
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    tag = b.extract_value(jv, 0, name="jv.truthy.tag");
    payload = b.extract_value(jv, 1, name="jv.truthy.payload");
    func = b.function;
    str_bb = func.append_basic_block(name="jv.truthy.str");
    cont_chk_bb = func.append_basic_block(name="jv.truthy.cont.chk");
    cont_len_bb = func.append_basic_block(name="jv.truthy.cont.len");
    scalar_bb = func.append_basic_block(name="jv.truthy.scalar");
    merge_bb = func.append_basic_block(name="jv.truthy.end");

    is_str = b.icmp_unsigned("==", tag, ir.Constant(i8, 2), name="jv.truthy.isstr");
    str_nn = b.icmp_unsigned(
        "!=", payload, ir.Constant(i64, 0), name="jv.truthy.str.nn"
    );
    do_str = b.and_(is_str, str_nn, name="jv.truthy.dostr");
    b.cbranch(do_str, str_bb, cont_chk_bb);

    b.position_at_end(str_bb);
    str_ptr = b.inttoptr(payload, i8.as_pointer(), name="jv.truthy.strp");
    _slen = self._call_str_len(b, str_ptr, name="jv.truthy.slen");
    str_res = b.icmp_unsigned("!=", _slen, ir.Constant(i64, 0), name="jv.truthy.snz");
    str_exit_bb = b.block;
    b.branch(merge_bb);

    b.position_at_end(cont_chk_bb);
    is_list = b.icmp_unsigned("==", tag, ir.Constant(i8, 3), name="jv.truthy.islist");
    is_dict = b.icmp_unsigned("==", tag, ir.Constant(i8, 4), name="jv.truthy.isdict");
    is_set = b.icmp_unsigned("==", tag, ir.Constant(i8, 5), name="jv.truthy.isset");
    is_cont = b.or_(
        b.or_(is_list, is_dict, name="jv.truthy.ld"), is_set, name="jv.truthy.iscont"
    );
    cont_nonnull = b.icmp_unsigned(
        "!=", payload, ir.Constant(i64, 0), name="jv.truthy.cont.nn"
    );
    read_len = b.and_(is_cont, cont_nonnull, name="jv.truthy.readlen");
    b.cbranch(read_len, cont_len_bb, scalar_bb);

    b.position_at_end(cont_len_bb);
    len_ptr = b.inttoptr(payload, i64.as_pointer(), name="jv.truthy.lenp");
    cont_len = b.load(len_ptr, name="jv.truthy.len");
    len_res = b.icmp_unsigned(
        "!=", cont_len, ir.Constant(i64, 0), name="jv.truthy.lennz"
    );
    b.branch(merge_bb);

    b.position_at_end(scalar_bb);
    is_none = b.icmp_unsigned("==", tag, ir.Constant(i8, 8), name="jv.truthy.isnone");
    is_float = b.icmp_unsigned("==", tag, ir.Constant(i8, 1), name="jv.truthy.isfloat");
    as_f64 = b.bitcast(payload, ir.DoubleType(), name="jv.truthy.f64");
    f_nz = b.fcmp_unordered(
        "!=", as_f64, ir.Constant(ir.DoubleType(), 0.0), name="jv.truthy.fnz"
    );
    p_nz = b.icmp_unsigned("!=", payload, ir.Constant(i64, 0), name="jv.truthy.pnz");
    num_res = b.select(is_float, f_nz, p_nz, name="jv.truthy.num");
    scalar_res = b.select(
        is_none, ir.Constant(i1, 0), num_res, name="jv.truthy.scalar"
    );
    b.branch(merge_bb);

    b.position_at_end(merge_bb);
    phi = b.phi(i1, name="jv.truthy");
    phi.add_incoming(str_res, str_exit_bb);
    phi.add_incoming(len_res, cont_len_bb);
    phi.add_incoming(scalar_res, scalar_bb);
    return phi;
}

impl NaIRGenPass._jacval_is_none(jv: ir.Value, negate: bool) -> ir.Value {
    i8 = ir.IntType(8);
    tag = self.builder.extract_value(jv, 0, name="jv.nonetest.tag");
    cmp_op = "!=" if negate else "==";
    return self.builder.icmp_unsigned(
        cmp_op, tag, ir.Constant(i8, 8), name="jv.nonetest"
    );
}

impl NaIRGenPass._zero_const(ty: ir.Type) -> ir.Constant {
    if isinstance(ty, (ir.PointerType, ir.Aggregate)) {
        return ir.Constant(ty, None);
    }
    return ir.Constant(ty, 0);
}

impl NaIRGenPass._coerce_type(val: ir.Value, target_type: ir.Type) -> ir.Value {
    _was_owned = self._is_owned(val);
    _result = self._coerce_type_inner(val, target_type);
    if _was_owned and _result is not val {
        self._mark_owned(_result);
    }
    return _result;
}

impl NaIRGenPass._coerce_type_inner(val: ir.Value, target_type: ir.Type) -> ir.Value {
    if val.type == target_type {
        return val;
    }

    if isinstance(val.type, ir.PointerType)
        and isinstance(target_type, ir.PointerType) {
        _src_nm = getattr(val.type.pointee, "name", "") or "";
        _tgt_nm = getattr(target_type.pointee, "name", "") or "";
        if _src_nm in self.struct_types and _tgt_nm in self.struct_types {
            if _tgt_nm in self._mro_of(_src_nm) or _src_nm in self._mro_of(_tgt_nm) {
                return self.builder.bitcast(val, target_type, name="hier.cast");
            }
        }
    }

    _tseq = self._tuple_seq_coerce(val, target_type);
    if _tseq is not None {
        return _tseq;
    }

    _sd = self._str_desc_ty;
    if _sd is not None {
        _i8p_sd = ir.IntType(8).as_pointer();
        if target_type == _sd and val.type == _i8p_sd {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }

            return self.builder.call(self.str_wrap_fn, [val], name="s.desc");
        }
        if val.type == _sd and target_type == _i8p_sd {
            return self._str_materialize(val);
        }
        if target_type == _sd and self?.jacval_type and val.type == self.jacval_type {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }
            return self.builder.call(
                self.str_wrap_fn, [self._unbox_from_jacval(val, _i8p_sd)], name="s.desc"
            );
        }
        if target_type == _sd
            and isinstance(val.type, ir.IntType)
            and val.type.width == 64 {
            if self.str_unwrap_fn is None {
                self._emit_str_desc_helpers();
            }
            return self.builder.call(
                self.str_wrap_fn,
                [self.builder.inttoptr(val, _i8p_sd, name="s.unbox")],
                name="s.desc"
            );
        }
        if val.type == _sd
            and isinstance(target_type, ir.IntType)
            and target_type.width == 64 {
            return self.builder.ptrtoint(
                self._str_materialize(val), target_type, name="s.box"
            );
        }
    }

    _opt_tgt = self._opt_payload_of(target_type);
    if _opt_tgt is not None {
        _source_payload_type = self._opt_payload_of(val.type);
        if _source_payload_type is not None {
            _source_tag = self.builder.extract_value(val, 0, name="opt.cast.tag");
            _source_present = self.builder.icmp_unsigned(
                "!=", _source_tag, ir.Constant(ir.IntType(8), 0), name="opt.cast.has"
            );
            _source_block = self.builder.block;
            _present_block = self.builder.function.append_basic_block(
                "opt.cast.present"
            );
            _merge_block = self.builder.function.append_basic_block("opt.cast.end");
            self.builder.cbranch(_source_present, _present_block, _merge_block);
            self.builder.position_at_end(_present_block);
            _source_payload = self.builder.extract_value(
                val, 1, name="opt.cast.payload"
            );
            _converted_payload = self._coerce_type_inner(_source_payload, _opt_tgt);
            _converted = self.builder.insert_value(
                ir.Constant(target_type, None),
                ir.Constant(ir.IntType(8), 1),
                0,
                name="opt.cast.tagset"
            );
            _converted = self.builder.insert_value(
                _converted, _converted_payload, 1, name="opt.cast.wrap"
            );
            if isinstance(_opt_tgt, ir.PointerType) {
                _nonnull = self.builder.icmp_unsigned(
                    "!=", _converted_payload, ir.Constant(_opt_tgt, None)
                );
                _converted = self.builder.select(
                    _nonnull, _converted, ir.Constant(target_type, None)
                );
            }
            _converted_block = self.builder.block;
            self.builder.branch(_merge_block);
            self.builder.position_at_end(_merge_block);
            _optional_result = self.builder.phi(target_type, name="opt.cast.result");
            _optional_result.add_incoming(
                ir.Constant(target_type, None), _source_block
            );
            _optional_result.add_incoming(_converted, _converted_block);
            return _optional_result;
        }
        _tgt_is_ptr = isinstance(_opt_tgt, ir.PointerType);
        _tgt_is_jacval = bool(self?.jacval_type) and _opt_tgt == self.jacval_type;
        _val_is_none = isinstance(val.type, ir.VoidType)
            or (
                isinstance(val, ir.Constant)
                and isinstance(val.type, ir.PointerType)
                and val.constant is None
            )
            or (
                isinstance(val.type, ir.PointerType)
                and not _tgt_is_ptr
                and not _tgt_is_jacval
            );
        if _val_is_none {
            return ir.Constant(target_type, None);
        }
        if self?.jacval_type
            and val.type == self.jacval_type
            and _opt_tgt != self.jacval_type {
            _jv_tag = self.builder.extract_value(val, 0, name="opt.jv.tag");
            _jv_is_none = self.builder.icmp_unsigned(
                "==", _jv_tag, ir.Constant(ir.IntType(8), 8), name="opt.jv.isnone"
            );
            _jv_pl = self._unbox_from_jacval(val, _opt_tgt);
            _jv_ov = self.builder.insert_value(
                ir.Constant(target_type, None),
                ir.Constant(ir.IntType(8), 1),
                0,
                name="opt.jv.tagset"
            );
            _jv_ov = self.builder.insert_value(_jv_ov, _jv_pl, 1, name="opt.jv.wrap");
            return self.builder.select(
                _jv_is_none, ir.Constant(target_type, None), _jv_ov, name="opt.jv.sel"
            );
        }
        _pv = self._coerce_type_inner(val, _opt_tgt);
        _ov = self.builder.insert_value(
            ir.Constant(target_type, None),
            ir.Constant(ir.IntType(8), 1),
            0,
            name="opt.tag"
        );
        _ov = self.builder.insert_value(_ov, _pv, 1, name="opt.wrap");
        if _tgt_is_ptr {
            _pv_nn = self.builder.icmp_unsigned(
                "!=", _pv, ir.Constant(_opt_tgt, None), name="opt.wrap.nn"
            );
            return self.builder.select(
                _pv_nn, _ov, ir.Constant(target_type, None), name="opt.wrap.sel"
            );
        }
        if _tgt_is_jacval and isinstance(val.type, ir.PointerType) {
            _object_present = self.builder.icmp_unsigned(
                "!=", val, ir.Constant(val.type, None), name="opt.object.has"
            );
            return self.builder.select(
                _object_present,
                _ov,
                ir.Constant(target_type, None),
                name="opt.object.wrap"
            );
        }
        return _ov;
    }
    _opt_src = self._opt_payload_of(val.type);
    if _opt_src is not None {
        _tag = self.builder.extract_value(val, 0, name="opt.tag.rd");
        _tag_set = self.builder.icmp_signed(
            "!=", _tag, ir.Constant(ir.IntType(8), 0), name="opt.has"
        );
        if isinstance(target_type, ir.IntType) and target_type.width == 1 {
            _pl_t = self.builder.extract_value(val, 1, name="opt.payload.t");
            _pl_b = self._coerce_type_inner(_pl_t, target_type);
            return self.builder.and_(_tag_set, _pl_b, name="opt.truthy");
        }
        _pl = self.builder.extract_value(val, 1, name="opt.payload");
        if self?.jacval_type and target_type == self.jacval_type {
            _boxed = self._box_to_jacval(_pl);
            _none_jv = self.builder.insert_value(
                ir.Constant(self.jacval_type, None),
                ir.Constant(ir.IntType(8), 8),
                0,
                name="opt.none.jv"
            );
            return self.builder.select(_tag_set, _boxed, _none_jv, name="opt.tojv");
        }

        if isinstance(target_type, ir.PointerType)
            and isinstance(_pl.type, ir.PointerType) {
            _pl_c = self._coerce_type_inner(_pl, target_type);
            return self.builder.select(
                _tag_set, _pl_c, ir.Constant(target_type, None), name="opt.ornull"
            );
        }
        _is_none = self.builder.icmp_signed(
            "==", _tag, ir.Constant(ir.IntType(8), 0), name="opt.isnone"
        );
        self._emit_runtime_raise(
            _is_none, "TypeError", "value is None where a value is required"
        );
        return self._coerce_type_inner(_pl, target_type);
    }

    if self?.jacval_type {
        if target_type == self.jacval_type and val.type != self.jacval_type {
            return self._box_to_jacval(val);
        }
        if val.type == self.jacval_type and target_type != self.jacval_type {
            return self._unbox_from_jacval(val, target_type);
        }
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.sitofp(val, target_type, name="cast");
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.FloatType) {
        return self.builder.sitofp(val, target_type, name="cast.f32");
    }

    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast");
    }

    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.IntType) {
        return self.builder.fptosi(val, target_type, name="cast.i");
    }

    if isinstance(val.type, ir.DoubleType) and isinstance(target_type, ir.FloatType) {
        return self.builder.fptrunc(val, target_type, name="fptrunc");
    }

    if isinstance(val.type, ir.FloatType) and isinstance(target_type, ir.DoubleType) {
        return self.builder.fpext(val, target_type, name="fpext");
    }

    _clos_tgt = self._closure_struct_of(target_type);
    if _clos_tgt is not None {
        _src_is_fn = isinstance(val.type, ir.FunctionType)
            or (
                isinstance(val.type, ir.PointerType)
                and isinstance(val.type.pointee, ir.FunctionType)
            );
        if _src_is_fn {
            if self._pending_lambda_captures is not None {
                self._pending_lambda_captures = None;
                self.ctx.emit(
                    E5092,
                    kind="expression",
                    name="capturing lambda used as a value",
                    help_text="This lambda captures enclosing locals that could not be promoted to shared heap cells in this frame, so it cannot escape as a value here. Bind the lambda's inputs through parameters, or use a named nested function."
                );
                return ir.Constant(target_type, None);
            }
            if self.rc_alloc_fn is None {
                self._emit_rc_helpers();
            }
            _wi32 = ir.IntType(32);
            _wi64 = ir.IntType(64);
            _wi8p = ir.IntType(8).as_pointer();
            _wfn = val;
            if isinstance(_wfn.type, ir.FunctionType) {
                _wfn = self.builder.bitcast(
                    _wfn, _wfn.type.as_pointer(), name="clos.wrap.fnp"
                );
            }
            _wclos = self._alloc_iter_struct(_clos_tgt);
            _wfn_slot = self.builder.gep(
                _wclos,
                [ir.Constant(_wi32, 0), ir.Constant(_wi32, 0)],
                name="clos.wrap.fn.slot"
            );
            self.builder.store(
                self.builder.ptrtoint(_wfn, _wi64, name="clos.wrap.fn.i64"), _wfn_slot
            );
            _wenv_slot = self.builder.gep(
                _wclos,
                [ir.Constant(_wi32, 0), ir.Constant(_wi32, 1)],
                name="clos.wrap.env.slot"
            );
            self.builder.store(ir.Constant(_wi8p, None), _wenv_slot);
            self._mark_owned(_wclos);
            return _wclos;
        }
    }

    if isinstance(val.type, ir.PointerType)
        and isinstance(target_type, ir.PointerType) {
        _lc_src = self._spec_from_list_slot_type(val.type);
        _lc_dst = self._spec_from_list_slot_type(target_type);
        if (
            _lc_src is not None
            and _lc_dst is not None
            and _lc_src != _lc_dst
            and (_lc_src == "jacval") != (_lc_dst == "jacval")
        ) {
            _lc_re = self._reflavor_list(val, _lc_src, _lc_dst);
            if _lc_re is not None {
                return _lc_re;
            }
            self.ctx.emit(
                E5092,
                node_override=self.module,
                kind="coercion",
                name=f"list[{_lc_src}] -> list[{_lc_dst}]",
                help_text=(
                    "These list layouts store elements at different slot "
                    "widths, so a cast would corrupt the elements; construct "
                    "the list with the destination's element flavor instead."
                )
            );
            return val;
        }
        return self.builder.bitcast(val, target_type, name="ptrcast");
    }

    if isinstance(val.type, ir.FunctionType)
        and isinstance(target_type, ir.PointerType) {
        return self.builder.bitcast(val, target_type, name="fn.cast");
    }

    if isinstance(val.type, ir.FunctionType) and isinstance(target_type, ir.IntType) {
        fn_ptr = self.builder.bitcast(val, val.type.as_pointer(), name="fn.ptr");
        return self.builder.ptrtoint(fn_ptr, target_type, name="fn.ptrtoint");
    }

    if isinstance(val.type, ir.PointerType)
        and isinstance(val.type.pointee, ir.FunctionType)
        and isinstance(target_type, ir.IntType) {
        return self.builder.ptrtoint(val, target_type, name="fn.ptrtoint");
    }

    if isinstance(val.type, ir.PointerType)
        and not isinstance(target_type, ir.PointerType) {
        if val.type?.pointee and val.type.pointee == target_type {
            return self.builder.load(val, name="struct.unbox");
        }

        if isinstance(target_type, ir.IntType) and val.type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if val.type.pointee == self.struct_types.get(sname)
                    and abi_type == target_type {
                    int_ptr = self.builder.bitcast(
                        val, target_type.as_pointer(), name="struct.abi.cast"
                    );
                    return self.builder.load(int_ptr, name="struct.abi.unbox");
                }
            }
        }

        if isinstance(target_type, ir.IntType) and isinstance(val, ir.Constant) {
            return ir.Constant(target_type, -1);
        }

        if isinstance(target_type, ir.IntType) {
            return self.builder.ptrtoint(val, target_type, name="ptr.toint");
        }
    }

    if not isinstance(val.type, ir.PointerType)
        and isinstance(target_type, ir.PointerType) {
        if isinstance(val.type, ir.LiteralStructType)
            and target_type?.pointee
            and isinstance(target_type.pointee, ir.LiteralStructType)
            and val.type != target_type.pointee
            and len(val.type.elements) == len(target_type.pointee.elements) {
            val = self._coerce_tuple_to_struct(val, target_type.pointee);
        }
        if target_type?.pointee and target_type.pointee == val.type {
            if isinstance(val.type, ir.LiteralStructType) {
                return self._box_value_tuple(val);
            }
            null_ptr = ir.Constant(target_type, None);
            size_gep = self.builder.gep(
                null_ptr, [ir.Constant(ir.IntType(32), 1)], name="clib.sizeof.gep"
            );
            size = self.builder.ptrtoint(size_gep, ir.IntType(64), name="clib.sizeof");

            _clib_loc = getattr(val, 'jac_loc', '');
            allocator = self.rc_alloc_fn;
            assert allocator is not None;
            raw_ptr = self._rc_call_with_ctx(
                allocator, [size], op="box", loc=_clib_loc, name="clib.box.raw"
            );
            typed_ptr = self.builder.bitcast(raw_ptr, target_type, name="clib.box.ptr");
            self.builder.store(val, typed_ptr);

            self._mark_owned(typed_ptr);

            self._emit_set_type_tag(self.builder, raw_ptr, "tuple");
            return typed_ptr;
        }

        if isinstance(val.type, ir.IntType) and target_type?.pointee {
            for (sname, abi_type) in self.clib_struct_abi_types.items() {
                if target_type.pointee == self.struct_types.get(sname)
                    and abi_type == val.type {
                    null_ptr = ir.Constant(target_type, None);
                    size_gep = self.builder.gep(
                        null_ptr,
                        [ir.Constant(ir.IntType(32), 1)],
                        name="clib.sizeof.gep"
                    );
                    size = self.builder.ptrtoint(
                        size_gep, ir.IntType(64), name="clib.sizeof"
                    );
                    allocator = self.rc_alloc_fn;
                    assert allocator is not None;
                    raw_ptr = self._rc_call_with_ctx(
                        allocator, [size], op="box", name="clib.box.raw"
                    );
                    int_ptr = self.builder.bitcast(
                        raw_ptr, val.type.as_pointer(), name="clib.abi.cast"
                    );
                    self.builder.store(val, int_ptr);
                    typed_ptr = self.builder.bitcast(
                        raw_ptr, target_type, name="clib.box.ptr"
                    );

                    self._mark_owned(typed_ptr);

                    self._emit_set_type_tag(self.builder, raw_ptr, sname);
                    return typed_ptr;
                }
            }
        }
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.PointerType) {
        return self.builder.inttoptr(val, target_type, name="int.toptr");
    }

    if isinstance(val.type, ir.IntType) and isinstance(target_type, ir.IntType) {
        if val.type.width < target_type.width {
            if val?.jac_signed {
                return self.builder.sext(val, target_type, name="sext");
            }
            return self.builder.zext(val, target_type, name="zext");
        } elif val.type.width > target_type.width {
            if target_type.width == 1 {
                return self.builder.icmp_signed(
                    "!=", val, ir.Constant(val.type, 0), name="int.truth"
                );
            }
            if isinstance(val, ir.Constant) and isinstance(val.constant, int) {
                _w = target_type.width;
                if -(1 << (_w - 1)) <= val.constant < (1 << _w) {
                    return ir.Constant(target_type, val.constant);
                }
            }
            self.ctx.emit(
                E5092,
                node_override=self.ctx.current_node,
                kind="silent narrowing",
                name=f"{val.type} into {target_type}"
            );
            return val;
        }
    }

    if isinstance(val.type, ir.LiteralStructType)
        and isinstance(target_type, ir.PointerType) {
        boxed = self._box_value_tuple(val);
        return self._coerce_type(boxed, target_type);
    }

    return val;
}

impl NaIRGenPass._promote_to_float(
    left: ir.Value, right: ir.Value, unsigned: bool = False
) -> tuple[(ir.Value, ir.Value)] {
    target: ir.Type = (
        ir.FloatType()
            if isinstance(left.type, ir.FloatType)
                and isinstance(right.type, ir.FloatType)
            else ir.DoubleType()
    );
    return (
        self._to_float_type(left, target, unsigned),
        self._to_float_type(right, target, unsigned)
    );
}

impl NaIRGenPass._to_float_type(
    val: ir.Value, target: ir.Type, unsigned: bool
) -> ir.Value {
    if val.type == target {
        return val;
    }
    if isinstance(val.type, ir.IntType) {
        if unsigned or val.type.width == 1 {
            return self.builder.uitofp(val, target, name="u2f");
        }
        return self.builder.sitofp(val, target, name="s2f");
    }
    if isinstance(val.type, ir.FloatType) and isinstance(target, ir.DoubleType) {
        return self.builder.fpext(val, target, name="fpext");
    }
    if isinstance(val.type, ir.DoubleType) and isinstance(target, ir.FloatType) {
        return self.builder.fptrunc(val, target, name="fptrunc");
    }
    return val;
}

impl NaIRGenPass._unify_int_widths(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    left_type = left.type;
    right_type = right.type;
    assert isinstance(left_type, ir.IntType) and isinstance(right_type, ir.IntType);
    _i32 = ir.IntType(32);
    if left_type.width == 1 and right_type.width == 1 {
        left = self.builder.zext(left, _i32, name="bool.widen");
        right = self.builder.zext(right, _i32, name="bool.widen");
    } elif left_type.width == 1 and right_type.width > 1 {
        left = self.builder.zext(left, right_type, name="bool.widen");
    } elif right_type.width == 1 and left_type.width > 1 {
        right = self.builder.zext(right, left_type, name="bool.widen");
    }
    return (left, right);
}

impl NaIRGenPass._int_lt_gt_pair(
    left: ir.Value, right: ir.Value, unsigned: bool, name: str
) -> tuple[(ir.Value, ir.Value)] {
    if unsigned {
        return (
            self.builder.icmp_unsigned("<", left, right, name=f"{name}.lt"),
            self.builder.icmp_unsigned(">", left, right, name=f"{name}.gt"),

        );
    }
    return (
        self.builder.icmp_signed("<", left, right, name=f"{name}.lt"),
        self.builder.icmp_signed(">", left, right, name=f"{name}.gt"),

    );
}

impl NaIRGenPass._codegen_int_floor_divmod(
    left: ir.Value, right: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    int_ty = left.type;
    q = self.builder.sdiv(left, right, name="floordiv.quot");
    r = self.builder.srem(left, right, name="floordiv.rem");
    izero = ir.Constant(int_ty, 0);
    rone = ir.Constant(int_ty, 1);
    r_ne_zero = self.builder.icmp_signed("!=", r, izero, name="floordiv.r.nz");
    r_neg = self.builder.icmp_signed("<", r, izero, name="floordiv.r.neg");
    b_neg = self.builder.icmp_signed("<", right, izero, name="floordiv.b.neg");
    sign_diff = self.builder.icmp_unsigned("!=", r_neg, b_neg, name="floordiv.sdiff");
    need_adj = self.builder.and_(r_ne_zero, sign_diff, name="floordiv.adj");
    q_one_less = self.builder.sub(q, rone, name="floordiv.q.dec");
    q_final = self.builder.select(need_adj, q_one_less, q, name="floordiv.q");
    r_plus_b = self.builder.add(r, right, name="floordiv.r.fix");
    r_final = self.builder.select(need_adj, r_plus_b, r, name="floordiv.r");
    return (q_final, r_final);
}

impl NaIRGenPass._codegen_float_floor_div(left: ir.Value, right: ir.Value) -> ir.Value {
    raw = self.builder.fdiv(left, right, name="ffloordiv.raw");
    floor_fn = self._get_or_declare_extern("floor", ir.DoubleType(), [ir.DoubleType()]);
    return self.builder.call(floor_fn, [raw], name="ffloordiv");
}

impl NaIRGenPass._codegen_float_floor_mod(left: ir.Value, right: ir.Value) -> ir.Value {
    floored = self._codegen_float_floor_div(left, right);
    prod = self.builder.fmul(right, floored, name="fmod.prod");
    return self.builder.fsub(left, prod, name="fmod");
}

impl NaIRGenPass._emit_binary_op(
    op: str,
    left: ir.Value,
    right: ir.Value,
    unsigned: bool = False,
    checked: bool = False
) -> (ir.Value | None) {
    left = self._str_norm(left);
    right = self._str_norm(right);
    if isinstance(left.type, ir.PointerType)
        or isinstance(right.type, ir.PointerType) {
        _dunder_res = self._emit_arch_dunder_binop(op, left, right);
        if _dunder_res is not None {
            return _dunder_res;
        }
    }

    left_payload = self._opt_payload_of(left.type);
    right_payload = self._opt_payload_of(right.type);
    if left_payload is not None {
        left = self._coerce_type(left, left_payload);
    }
    if right_payload is not None {
        right = self._coerce_type(right, right_payload);
    }
    i8p_type = ir.IntType(8).as_pointer();
    if op == Tok.PLUS and left.type == i8p_type and right.type == i8p_type {
        _i8p_cc = ir.IntType(8).as_pointer();
        _i64_cc = ir.IntType(64);
        memcpy_cc = self._get_or_declare_extern(
            "memcpy", _i8p_cc, [_i8p_cc, _i8p_cc, _i64_cc]
        );
        len1 = self._call_str_len(self.builder, left, name="len1");
        len2 = self._call_str_len(self.builder, right, name="len2");
        total = self.builder.add(len1, len2, name="total_len");
        buf_size = self.builder.add(
            total, ir.Constant(ir.IntType(64), 1), name="buf_size"
        );
        _concat_loc = getattr(left, 'jac_loc', getattr(right, 'jac_loc', ''));
        self._set_rc_ctx("str_concat", _concat_loc);
        buf = self._str_alloc(self.builder, buf_size, name="concat.buf");
        self._clear_rc_ctx();
        self.builder.call(memcpy_cc, [buf, left, len1]);
        _cc_dst2 = self.builder.gep(buf, [len1], name="concat.dst2");
        self.builder.call(memcpy_cc, [_cc_dst2, right, len2]);
        self._str_finish(self.builder, buf, total);

        self._mark_owned(buf);
        return buf;
    }

    if op == Tok.PLUS and self._is_bytes_value(left) and self._is_bytes_value(right) {
        i8p = ir.IntType(8).as_pointer();
        i64 = ir.IntType(64);
        llen = self._bytes_len_val(left);
        rlen = self._bytes_len_val(right);
        total = self.builder.add(llen, rlen, name="by.cat.total");
        result = self._bytes_alloc(total);
        dst = self._bytes_data_ptr(result);
        memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
        self.builder.call(memcpy_fn, [dst, self._bytes_data_ptr(left), llen]);
        rdst = self.builder.gep(dst, [llen], name="by.cat.rdst");
        self.builder.call(memcpy_fn, [rdst, self._bytes_data_ptr(right), rlen]);
        return result;
    }

    if op == Tok.STAR_MUL {
        by_val: (ir.Value | None) = None;
        rep_val: (ir.Value | None) = None;
        if self._is_bytes_value(left) and isinstance(right.type, ir.IntType) {
            by_val = left;
            rep_val = right;
        } elif self._is_bytes_value(right) and isinstance(left.type, ir.IntType) {
            by_val = right;
            rep_val = left;
        }
        if by_val is not None and rep_val is not None {
            return self._emit_bytes_repeat(by_val, rep_val);
        }
    }

    if op == Tok.STAR_MUL {
        str_val: (ir.Value | None) = None;
        int_val: (ir.Value | None) = None;
        if left.type == i8p_type and isinstance(right.type, ir.IntType) {
            str_val = left;
            int_val = right;
        } elif right.type == i8p_type and isinstance(left.type, ir.IntType) {
            str_val = right;
            int_val = left;
        }
        if str_val is not None and int_val is not None {
            i8 = ir.IntType(8);
            i8p = i8.as_pointer();
            i64 = ir.IntType(64);
            memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
            slen = self._call_str_len(self.builder, str_val, name="rep.slen");

            _rep_neg = self.builder.icmp_signed(
                "<", int_val, ir.Constant(i64, 0), name="rep.neg"
            );
            int_val = self.builder.select(
                _rep_neg, ir.Constant(i64, 0), int_val, name="rep.n"
            );
            total = self.builder.mul(slen, int_val, name="rep.total");
            alloc = self.builder.add(total, ir.Constant(i64, 1), name="rep.alloc");
            self._set_rc_ctx("str_repeat", "");
            buf = self._str_alloc(self.builder, alloc, name="rep.buf");
            self._clear_rc_ctx();
            func = self.builder.basic_block.function;
            entry_bb = self.builder.basic_block;
            loop_bb = func.append_basic_block(name="rep.loop");
            body_bb = func.append_basic_block(name="rep.body");
            done_bb = func.append_basic_block(name="rep.done");
            self.builder.branch(loop_bb);
            self.builder.position_at_start(loop_bb);
            offset = self.builder.phi(i64, name="rep.off");
            count = self.builder.phi(i64, name="rep.cnt");
            offset.add_incoming(ir.Constant(i64, 0), entry_bb);
            count.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = self.builder.icmp_unsigned(">=", count, int_val, name="rep.atend");
            self.builder.cbranch(at_end, done_bb, body_bb);
            self.builder.position_at_start(body_bb);
            dst = self.builder.gep(buf, [offset], name="rep.dst");
            self.builder.call(memcpy_fn, [dst, str_val, slen]);
            new_off = self.builder.add(offset, slen, name="rep.newoff");
            new_cnt = self.builder.add(count, ir.Constant(i64, 1), name="rep.newcnt");
            offset.add_incoming(new_off, body_bb);
            count.add_incoming(new_cnt, body_bb);
            self.builder.branch(loop_bb);
            self.builder.position_at_start(done_bb);
            self._str_finish(self.builder, buf, total);
            return buf;
        }
    }

    if op == Tok.STAR_MUL {
        for (lmul_key, lmul_helpers) in self.list_helpers.items() {
            lmul_type = self.list_types.get(lmul_key);
            if lmul_type is None {
                continue;
            }
            lmul_list: (ir.Value | None) = None;
            lmul_int: (ir.Value | None) = None;
            if left.type == lmul_type.as_pointer()
                and isinstance(right.type, ir.IntType) {
                lmul_list = left;
                lmul_int = right;
            } elif right.type == lmul_type.as_pointer()
                and isinstance(left.type, ir.IntType) {
                lmul_list = right;
                lmul_int = left;
            }
            if lmul_list is not None and lmul_int is not None {
                i64 = ir.IntType(64);
                lmul_new = self.builder.call(lmul_helpers["new"], [], name="lmul.new");
                lmul_len = self.builder.call(
                    lmul_helpers["len"], [lmul_list], name="lmul.len"
                );
                func = self.builder.basic_block.function;
                lmul_entry_bb = self.builder.basic_block;
                lmul_outer_bb = func.append_basic_block(name="lmul.outer");
                lmul_iinit_bb = func.append_basic_block(name="lmul.iinit");
                lmul_inner_bb = func.append_basic_block(name="lmul.inner");
                lmul_ibody_bb = func.append_basic_block(name="lmul.ibody");
                lmul_onext_bb = func.append_basic_block(name="lmul.onext");
                lmul_done_bb = func.append_basic_block(name="lmul.done");
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_outer_bb);
                lmul_rep = self.builder.phi(i64, name="lmul.rep");
                lmul_rep.add_incoming(ir.Constant(i64, 0), lmul_entry_bb);
                lmul_rend = self.builder.icmp_signed(
                    ">=", lmul_rep, lmul_int, name="lmul.rend"
                );
                self.builder.cbranch(lmul_rend, lmul_done_bb, lmul_iinit_bb);
                self.builder.position_at_start(lmul_iinit_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_inner_bb);
                lmul_ei = self.builder.phi(i64, name="lmul.ei");
                lmul_ei.add_incoming(ir.Constant(i64, 0), lmul_iinit_bb);
                lmul_eend = self.builder.icmp_unsigned(
                    ">=", lmul_ei, lmul_len, name="lmul.eend"
                );
                self.builder.cbranch(lmul_eend, lmul_onext_bb, lmul_ibody_bb);
                self.builder.position_at_start(lmul_ibody_bb);
                lmul_elem = self.builder.call(
                    lmul_helpers["get"], [lmul_list, lmul_ei], name="lmul.elem"
                );
                self._rc_call_with_ctx(
                    lmul_helpers["append"], [lmul_new, lmul_elem], op="list_mul"
                );
                lmul_ne = self.builder.add(
                    lmul_ei, ir.Constant(i64, 1), name="lmul.ne"
                );
                lmul_ei.add_incoming(lmul_ne, lmul_ibody_bb);
                self.builder.branch(lmul_inner_bb);
                self.builder.position_at_start(lmul_onext_bb);
                lmul_nr = self.builder.add(
                    lmul_rep, ir.Constant(i64, 1), name="lmul.nr"
                );
                lmul_rep.add_incoming(lmul_nr, lmul_onext_bb);
                self.builder.branch(lmul_outer_bb);
                self.builder.position_at_start(lmul_done_bb);
                return self._mark_owned(lmul_new);
            }
        }
    }

    if op == Tok.PLUS {
        for (list_key, helpers) in self.list_helpers.items() {
            list_type = self.list_types.get(list_key);
            if list_type is not None
                and left.type == list_type.as_pointer()
                and right.type == list_type.as_pointer() {
                i64 = ir.IntType(64);
                new_list = self.builder.call(helpers["new"], [], name="lcat.new");

                left_len = self.builder.call(helpers["len"], [left], name="lcat.llen");
                func = self.builder.basic_block.function;
                entry_bb = self.builder.basic_block;
                loop1_bb = func.append_basic_block(name="lcat.l1");
                body1_bb = func.append_basic_block(name="lcat.b1");
                mid_bb = func.append_basic_block(name="lcat.mid");
                loop2_bb = func.append_basic_block(name="lcat.l2");
                body2_bb = func.append_basic_block(name="lcat.b2");
                done_bb = func.append_basic_block(name="lcat.done");
                self.builder.branch(loop1_bb);
                self.builder.position_at_start(loop1_bb);
                i1 = self.builder.phi(i64, name="lcat.i1");
                i1.add_incoming(ir.Constant(i64, 0), entry_bb);
                end1 = self.builder.icmp_unsigned(">=", i1, left_len, name="lcat.end1");
                self.builder.cbranch(end1, mid_bb, body1_bb);
                self.builder.position_at_start(body1_bb);
                e1 = self.builder.call(helpers["get"], [left, i1], name="lcat.e1");
                self._rc_call_with_ctx(
                    helpers["append"], [new_list, e1], op="list_cat"
                );
                n1 = self.builder.add(i1, ir.Constant(i64, 1), name="lcat.n1");
                i1.add_incoming(n1, body1_bb);
                self.builder.branch(loop1_bb);

                self.builder.position_at_start(mid_bb);
                right_len = self.builder.call(
                    helpers["len"], [right], name="lcat.rlen"
                );
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(loop2_bb);
                i2 = self.builder.phi(i64, name="lcat.i2");
                i2.add_incoming(ir.Constant(i64, 0), mid_bb);
                end2 = self.builder.icmp_unsigned(
                    ">=", i2, right_len, name="lcat.end2"
                );
                self.builder.cbranch(end2, done_bb, body2_bb);
                self.builder.position_at_start(body2_bb);
                e2 = self.builder.call(helpers["get"], [right, i2], name="lcat.e2");
                self._rc_call_with_ctx(
                    helpers["append"], [new_list, e2], op="list_cat"
                );
                n2 = self.builder.add(i2, ir.Constant(i64, 1), name="lcat.n2");
                i2.add_incoming(n2, body2_bb);
                self.builder.branch(loop2_bb);
                self.builder.position_at_start(done_bb);
                return self._mark_owned(new_list);
            }
        }
    }

    for (sk, st) in self.set_types.items() {
        if left.type == st.as_pointer() and right.type == st.as_pointer() {
            _ctx = NativeEmitCtx(pass_ref=self, type_key=sk);
            _se = self._ensure_emitters().get("set");
            if isinstance(_se, NativeSetEmitter) {
                if op == Tok.BW_OR {
                    return _se.emit_union(_ctx, left, [right]);
                }
                if op == Tok.BW_AND {
                    return _se.emit_intersection(_ctx, left, [right]);
                }
                if op == Tok.MINUS {
                    return _se.emit_difference(_ctx, left, [right]);
                }
                if op == Tok.BW_XOR {
                    return _se.emit_symmetric_difference(_ctx, left, [right]);
                }
            }
            break;
        }
    }

    ctype_ptr = self.complex_struct_type.as_pointer();
    if left.type == ctype_ptr and right.type == ctype_ptr {
        f64 = ir.DoubleType();
        i64 = ir.IntType(64);
        i32 = ir.IntType(32);
        z0 = ir.Constant(i32, 0);
        z1 = ir.Constant(i32, 1);
        ar = self.builder.load(
            self.builder.gep(left, [z0, z0], name="c.ar.p"), name="c.ar"
        );
        ai = self.builder.load(
            self.builder.gep(left, [z0, z1], name="c.ai.p"), name="c.ai"
        );
        br = self.builder.load(
            self.builder.gep(right, [z0, z0], name="c.br.p"), name="c.br"
        );
        bi = self.builder.load(
            self.builder.gep(right, [z0, z1], name="c.bi.p"), name="c.bi"
        );
        rr: (ir.Value | None) = None;
        ri: (ir.Value | None) = None;
        if op == Tok.PLUS {
            rr = self.builder.fadd(ar, br, name="c.add.r");
            ri = self.builder.fadd(ai, bi, name="c.add.i");
        } elif op == Tok.MINUS {
            rr = self.builder.fsub(ar, br, name="c.sub.r");
            ri = self.builder.fsub(ai, bi, name="c.sub.i");
        } elif op == Tok.STAR_MUL {
            rr = self.builder.fsub(
                self.builder.fmul(ar, br, name="c.m1"),
                self.builder.fmul(ai, bi, name="c.m2"),
                name="c.mul.r"
            );
            ri = self.builder.fadd(
                self.builder.fmul(ar, bi, name="c.m3"),
                self.builder.fmul(ai, br, name="c.m4"),
                name="c.mul.i"
            );
        } elif op == Tok.DIV {
            denom = self.builder.fadd(
                self.builder.fmul(br, br, name="c.d1"),
                self.builder.fmul(bi, bi, name="c.d2"),
                name="c.denom"
            );
            rr = self.builder.fdiv(
                self.builder.fadd(
                    self.builder.fmul(ar, br, name="c.d3"),
                    self.builder.fmul(ai, bi, name="c.d4"),
                    name="c.div.rn"
                ),
                denom,
                name="c.div.r"
            );
            ri = self.builder.fdiv(
                self.builder.fsub(
                    self.builder.fmul(ai, br, name="c.d5"),
                    self.builder.fmul(ar, bi, name="c.d6"),
                    name="c.div.in"
                ),
                denom,
                name="c.div.i"
            );
        }
        if rr is not None and ri is not None {
            raw = self.builder.call(
                self.rc_alloc_fn, [ir.Constant(i64, 16)], name="c.res.raw"
            );
            ptr = self.builder.bitcast(raw, ctype_ptr, name="c.res.ptr");
            self.builder.store(rr, self.builder.gep(ptr, [z0, z0], name="c.res.rp"));
            self.builder.store(ri, self.builder.gep(ptr, [z0, z1], name="c.res.ip"));
            return ptr;
        }
    }

    if self?.jacval_type
        and (left.type == self.jacval_type or right.type == self.jacval_type) {
        self.ctx.emit(
            E5092,
            node_override=self.ctx.current_node,
            kind="binary operator",
            name=f"{op} on a tagged `any` operand"
        );
        return None;
    }

    is_float = isinstance(left.type, (ir.DoubleType, ir.FloatType))
        or isinstance(right.type, (ir.DoubleType, ir.FloatType))
        or op == Tok.DIV;
    if is_float {
        (left, right) = self._promote_to_float(left, right, unsigned=unsigned);
    }
    if is_float {
        if op == Tok.PLUS {
            return self.builder.fadd(left, right, name="fadd");
        } elif op == Tok.MINUS {
            return self.builder.fsub(left, right, name="fsub");
        } elif op == Tok.STAR_MUL {
            return self.builder.fmul(left, right, name="fmul");
        } elif op == Tok.DIV {
            fzero = ir.Constant(right.type, 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fdiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float division by zero"
            );
            return self.builder.fdiv(left, right, name="fdiv");
        } elif op == Tok.MOD {
            fzero = ir.Constant(right.type, 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="fmod.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float modulo by zero"
            );
            return self._codegen_float_floor_mod(left, right);
        } elif op == Tok.FLOOR_DIV {
            fzero = ir.Constant(right.type, 0.0);
            is_zero = self.builder.fcmp_ordered(
                "==", right, fzero, name="ffloordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "float floor division by zero"
            );
            return self._codegen_float_floor_div(left, right);
        }
    } else {
        if not isinstance(left.type, ir.IntType)
            or not isinstance(right.type, ir.IntType) {
            self.ctx.emit(
                E5092,
                node_override=self.ctx.current_node,
                kind="integer operator layout",
                name=f"{op} on {left.type} vs {right.type}"
            );
            return None;
        }
        (left, right) = self._unify_int_widths(left, right);
        if op == Tok.LSHIFT {
            if checked {
                return self._emit_checked_shl(left, right, unsigned);
            }
            return self.builder.shl(left, right, name="shl");
        } elif op == Tok.RSHIFT {
            if checked {
                return self._emit_shr(left, right, unsigned);
            }
            return self.builder.ashr(left, right, name="ashr");
        }
        if left.type != right.type {
            self.ctx.emit(
                E5092,
                node_override=self.ctx.current_node,
                kind="integer operator layout",
                name=f"{op} on {left.type} vs {right.type}"
            );
            return None;
        }
        int_ty = left.type;
        if op == Tok.PLUS {
            return self._emit_overflow_op("add", left, right, unsigned);
        } elif op == Tok.MINUS {
            return self._emit_overflow_op("sub", left, right, unsigned);
        } elif op == Tok.STAR_MUL {
            return self._emit_overflow_op("mul", left, right, unsigned);
        } elif op == Tok.FLOOR_DIV {
            izero = ir.Constant(int_ty, 0);
            is_zero = self.builder.icmp_signed(
                "==", right, izero, name="floordiv.zero.chk"
            );
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            (q, _) = self._emit_int_divmod(left, right, unsigned);
            return q;
        } elif op == Tok.MOD {
            izero = ir.Constant(int_ty, 0);
            is_zero = self.builder.icmp_signed("==", right, izero, name="mod.zero.chk");
            self._emit_runtime_raise(
                is_zero, "ZeroDivisionError", "integer division or modulo by zero"
            );
            (_, r) = self._emit_int_divmod(left, right, unsigned, trap_min=False);
            return r;
        }
    }

    if op == Tok.BW_AND {
        return self.builder.and_(left, right, name="bwand");
    }
    if op == Tok.BW_OR {
        return self.builder.or_(left, right, name="bwor");
    }
    if op == Tok.BW_XOR {
        return self.builder.xor(left, right, name="bwxor");
    }

    if op == Tok.KW_AND {
        return self.builder.and_(left, right, name="and");
    }
    if op == Tok.KW_OR {
        return self.builder.or_(left, right, name="or");
    }

    self.ctx.emit(
        E5092, node_override=self.ctx.current_node, kind="binary operator", name=op
    );
    return None;
}

impl NaIRGenPass._emit_arch_dunder_binop(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    import from jaclang.compiler.types.operations { BINARY_OPERATOR_MAP }
    _pair = BINARY_OPERATOR_MAP.get(op);
    if _pair is None {
        return None;
    }
    (magic, rmagic) = _pair;

    def _try_dispatch(
        pass_ref: NaIRGenPass, recv: ir.Value, arg: ir.Value, mname: str
    ) -> (ir.Value | None) {
        if not isinstance(recv.type, ir.PointerType) {
            return None;
        }
        arch = pass_ref._infer_type_name(recv);
        if arch is None {
            return None;
        }
        mfn = pass_ref._resolve_method(arch, mname);
        if mfn is None or len(mfn.args) != 2 {
            return None;
        }
        _dargs = [
            pass_ref._coerce_type(recv, mfn.args[0].type),
            pass_ref._coerce_type(arg, mfn.args[1].type)
        ];
        _dres = pass_ref.builder.call(mfn, _dargs, name=f"dunder.{mname}");
        pass_ref._release_owned_args(_dargs, op="call_arg");
        return _dres;
    }

    _res = _try_dispatch(self, left, right, magic);
    if _res is not None {
        return _res;
    }
    return _try_dispatch(self, right, left, rmagic);
}

impl NaIRGenPass._opt_membership_operand(
    left: ir.Value, slot_type: ir.Type
) -> tuple[ir.Value, ir.Value | None] {
    _pt = self._opt_payload_of(left.type);
    if _pt is None or (self?.jacval_type and slot_type == self.jacval_type) {
        return (self._coerce_type(left, slot_type), None);
    }
    i8p = ir.IntType(8).as_pointer();
    _tag = self.builder.extract_value(left, 0, name="opt.in.tag");
    _tag_set = self.builder.icmp_signed(
        "!=", _tag, ir.Constant(ir.IntType(8), 0), name="opt.in.has"
    );
    _pv = self.builder.extract_value(left, 1, name="opt.in.pv");
    if _pv.type == i8p and slot_type == i8p {
        _pv = self.builder.select(
            _tag_set,
            _pv,
            self.builder.bitcast(
                self._make_global_string(""), i8p, name="opt.in.empty"
            ),
            name="opt.in.safe"
        );
    }
    return (self._coerce_type(_pv, slot_type), _tag_set);
}

impl NaIRGenPass._emit_jacval_eq(left: ir.Value, right: ir.Value) -> ir.Value {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i8p = ir.IntType(8).as_pointer();
    ltag = self.builder.extract_value(left, 0, name="jv.eq.ltag");
    rtag = self.builder.extract_value(right, 0, name="jv.eq.rtag");
    lpay = self.builder.extract_value(left, 1, name="jv.eq.lpay");
    rpay = self.builder.extract_value(right, 1, name="jv.eq.rpay");
    tag_eq = self.builder.icmp_signed("==", ltag, rtag, name="jv.eq.tag");
    both_str = self.builder.and_(
        self.builder.icmp_signed("==", ltag, ir.Constant(i8, 2), name="jv.eq.lstr"),
        self.builder.icmp_signed("==", rtag, ir.Constant(i8, 2), name="jv.eq.rstr"),
        name="jv.eq.bothstr"
    );
    func = self.builder.basic_block.function;
    entry_bb = self.builder.basic_block;
    str_bb = func.append_basic_block(name="jv.eq.str");
    bits_bb = func.append_basic_block(name="jv.eq.bits");
    merge_bb = func.append_basic_block(name="jv.eq.done");
    self.builder.cbranch(both_str, str_bb, bits_bb);
    self.builder.position_at_start(str_bb);
    strcmp_fn = self._get_or_declare_extern("strcmp", ir.IntType(32), [i8p, i8p]);
    sres = self.builder.call(
        strcmp_fn,
        [
            self.builder.inttoptr(lpay, i8p, name="jv.eq.lsp"),
            self.builder.inttoptr(rpay, i8p, name="jv.eq.rsp")
        ],
        name="jv.eq.strcmp"
    );
    str_eq = self.builder.icmp_signed(
        "==", sres, ir.Constant(ir.IntType(32), 0), name="jv.eq.streq"
    );
    self.builder.branch(merge_bb);
    self.builder.position_at_start(bits_bb);
    pay_eq = self.builder.icmp_signed("==", lpay, rpay, name="jv.eq.pay");
    bits_eq = self.builder.and_(tag_eq, pay_eq, name="jv.eq.bitseq");
    self.builder.branch(merge_bb);
    self.builder.position_at_start(merge_bb);
    res = self.builder.phi(i1, name="jv.eq");
    res.add_incoming(str_eq, str_bb);
    res.add_incoming(bits_eq, bits_bb);
    return res;
}

impl NaIRGenPass._emit_optional_eq(
    op: str, left: ir.Value, right: ir.Value, is_float: bool
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    _lp = self._opt_payload_of(left.type);
    _rp = self._opt_payload_of(right.type);
    func = self.builder.basic_block.function;
    if _lp is not None and _rp is not None {
        if str(_lp) != str(_rp) {
            return None;
        }
        ltag = self.builder.extract_value(left, 0, name="opt.eq.ltag");
        rtag = self.builder.extract_value(right, 0, name="opt.eq.rtag");
        lset = self.builder.icmp_signed(
            "!=", ltag, ir.Constant(i8, 0), name="opt.eq.lset"
        );
        rset = self.builder.icmp_signed(
            "!=", rtag, ir.Constant(i8, 0), name="opt.eq.rset"
        );
        both_set = self.builder.and_(lset, rset, name="opt.eq.bothset");
        both_none = self.builder.and_(
            self.builder.not_(lset, name="opt.eq.lnone"),
            self.builder.not_(rset, name="opt.eq.rnone"),
            name="opt.eq.bothnone"
        );
        entry_bb = self.builder.basic_block;
        pay_bb = func.append_basic_block(name="opt.eq.payload");
        merge_bb = func.append_basic_block(name="opt.eq.done");
        self.builder.cbranch(both_set, pay_bb, merge_bb);
        self.builder.position_at_start(pay_bb);
        pl = self.builder.extract_value(left, 1, name="opt.eq.lpayload");
        pr = self.builder.extract_value(right, 1, name="opt.eq.rpayload");
        pcmp = self._emit_comparison(Tok.EE, pl, pr, is_float);
        if pcmp is None {
            return None;
        }
        pcmp = self._to_bool(pcmp);
        pay_end = self.builder.basic_block;
        self.builder.branch(merge_bb);
        self.builder.position_at_start(merge_bb);
        res = self.builder.phi(i1, name="opt.eq.res");
        res.add_incoming(both_none, entry_bb);
        res.add_incoming(pcmp, pay_end);
        if op == Tok.NE {
            return self.builder.not_(res, name="opt.eq.ne");
        }
        return res;
    }
    opt_v = left if _lp is not None else right;
    pt = _lp if _lp is not None else _rp;
    assert pt is not None;
    other = right if _lp is not None else left;
    tag = self.builder.extract_value(opt_v, 0, name="opt.eq.tag");
    tag_set = self.builder.icmp_signed(
        "!=", tag, ir.Constant(i8, 0), name="opt.eq.set"
    );
    if isinstance(other, ir.Constant)
        and isinstance(other.type, ir.PointerType)
        and other.constant is None {
        if op == Tok.NE {
            return tag_set;
        }
        return self.builder.not_(tag_set, name="opt.eq.isnone");
    }
    entry_bb = self.builder.basic_block;
    pay_bb = func.append_basic_block(name="opt.eq.payload");
    merge_bb = func.append_basic_block(name="opt.eq.done");
    self.builder.cbranch(tag_set, pay_bb, merge_bb);
    self.builder.position_at_start(pay_bb);
    pv = self.builder.extract_value(opt_v, 1, name="opt.eq.payloadval");
    ov = self._coerce_type(other, pt);
    pcmp = self._emit_comparison(Tok.EE, pv, ov, is_float);
    if pcmp is None {
        return None;
    }
    pcmp = self._to_bool(pcmp);
    pay_end = self.builder.basic_block;
    self.builder.branch(merge_bb);
    self.builder.position_at_start(merge_bb);
    res = self.builder.phi(i1, name="opt.eq.res");
    res.add_incoming(ir.Constant(i1, 0), entry_bb);
    res.add_incoming(pcmp, pay_end);
    if op == Tok.NE {
        return self.builder.not_(res, name="opt.eq.ne");
    }
    return res;
}

impl NaIRGenPass._is_jacval_ty(t: ir.Type) -> bool {
    if not self?.jacval_type {
        return False;
    }
    return isinstance(t, ir.IdentifiedStructType) and t.name == self.jacval_type.name;
}

impl NaIRGenPass._is_jacval_boxable(t: ir.Type) -> bool {
    if self._is_jacval_ty(t) {
        return True;
    }
    if isinstance(t, (ir.IntType, ir.DoubleType, ir.PointerType)) {
        return True;
    }
    _sd = self._str_desc_ty;
    return (
        _sd is not None
        and isinstance(t, ir.IdentifiedStructType)
        and t.name == _sd.name
    );
}

impl NaIRGenPass._emit_jacval_ordering(
    op: str, jv: ir.Value, peer: ir.Value, jv_on_left: bool
) -> (ir.Value | None) {
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    _dbl = ir.DoubleType();
    comparisons: dict[str, str] = {
        Tok.LT: "<",
        Tok.GT: ">",
        Tok.LTE: "<=",
        Tok.GTE: ">="
    };
    _sym = comparisons.get(op, "<");
    _tag = self.builder.extract_value(jv, 0, name="jv.ord.tag");
    _pay = self.builder.extract_value(jv, 1, name="jv.ord.pay");
    _is_flt = self.builder.icmp_signed(
        "==", _tag, ir.Constant(i8, 1), name="jv.ord.isflt"
    );
    _is_int = self.builder.icmp_signed(
        "==", _tag, ir.Constant(i8, 0), name="jv.ord.isint"
    );
    _is_bool = self.builder.icmp_signed(
        "==", _tag, ir.Constant(i8, 7), name="jv.ord.isbool"
    );
    _numeric = self.builder.or_(
        _is_flt,
        self.builder.or_(_is_int, _is_bool, name="jv.ord.intish"),
        name="jv.ord.num"
    );
    self._emit_runtime_raise(
        self.builder.not_(_numeric, name="jv.ord.bad"),
        "TypeError",
        f"'{_sym}' not supported between these operand types"
    );
    _jv_f = self.builder.select(
        _is_flt,
        self.builder.bitcast(_pay, _dbl, name="jv.ord.f.bits"),
        self.builder.sitofp(_pay, _dbl, name="jv.ord.f.conv"),
        name="jv.ord.f"
    );
    if isinstance(peer.type, ir.DoubleType) {
        _fl = _jv_f if jv_on_left else peer;
        _fr = peer if jv_on_left else _jv_f;
        return self._emit_comparison(op, _fl, _fr, True);
    }
    _peer_i = self._coerce_type(peer, i64);
    _peer_f = self.builder.sitofp(_peer_i, _dbl, name="jv.ord.peer.f");
    _il = _pay if jv_on_left else _peer_i;
    _ir_ = _peer_i if jv_on_left else _pay;
    _int_res = self._emit_comparison(op, _il, _ir_, False);
    _ml = _jv_f if jv_on_left else _peer_f;
    _mr = _peer_f if jv_on_left else _jv_f;
    _flt_res = self._emit_comparison(op, _ml, _mr, True);
    if _int_res is None or _flt_res is None {
        return None;
    }
    return self.builder.select(_is_flt, _flt_res, _int_res, name="jv.ord.res");
}

impl NaIRGenPass._emit_mixed_jacval_comparison(
    op: str, left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    _left_boxed = self._is_jacval_ty(left.type);
    _peer = right.type if _left_boxed else left.type;
    if op in (Tok.EE, Tok.NE) and self._is_jacval_boxable(_peer) {
        if _left_boxed {
            right = self._coerce_type(right, self.jacval_type);
        } else {
            left = self._coerce_type(left, self.jacval_type);
        }
        _mx_res = self._emit_jacval_eq(left, right);
        if op == Tok.NE {
            return self.builder.not_(_mx_res, name="jv.mixed.ne");
        }
        return _mx_res;
    }
    if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE)
        and isinstance(_peer, (ir.IntType, ir.DoubleType)) {
        return self._emit_jacval_ordering(
            op,
            left if _left_boxed else right,
            right if _left_boxed else left,
            _left_boxed
        );
    }
    self.ctx.emit(
        E5090,
        kind="comparison",
        name=f"tagged `any` value against {_peer}",
        help_text="The element type of this container could not be inferred, so its values are stored as tagged `any`. Annotate the container (for example `list[int]`) so both sides of the comparison lower to the same representation."
    );
    return None;
}

impl NaIRGenPass._emit_comparison(
    op: str,
    left: ir.Value,
    right: ir.Value,
    is_float: bool,
    unsigned: bool = False,
    key_ret: (TypeBase | None) = None
) -> (ir.Value | None) {
    if self?.jacval_type
        and left.type == self.jacval_type
        and right.type == self.jacval_type
        and op in (Tok.EE, Tok.NE) {
        _jv_res = self._emit_jacval_eq(left, right);
        if op == Tok.NE {
            return self.builder.not_(_jv_res, name="jv.ne");
        }
        return _jv_res;
    }
    if self?.jacval_type
        and self._is_jacval_ty(left.type) != self._is_jacval_ty(right.type)
        and self._opt_payload_of(left.type) is None
        and self._opt_payload_of(right.type) is None {
        return self._emit_mixed_jacval_comparison(op, left, right);
    }
    _l_opt = self._opt_payload_of(left.type);
    _r_opt = self._opt_payload_of(right.type);
    if _l_opt is not None or _r_opt is not None {
        if op in (Tok.EE, Tok.NE) {
            return self._emit_optional_eq(op, left, right, is_float);
        }
        if _l_opt is not None {
            left = self._coerce_type(left, _l_opt);
        }
        if _r_opt is not None {
            right = self._coerce_type(right, _r_opt);
        }
        return self._emit_comparison(op, left, right, is_float);
    }
    _dty = self._str_desc_ty;
    if _dty is not None
        and (left.type == _dty or right.type == _dty)
        and op in (Tok.EE, Tok.NE, Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
        _lp = self._str_cmp_parts_of(left);
        _rp = self._str_cmp_parts_of(right);
        if _lp is not None and _rp is not None {
            _sc3 = self._call_str_cmp3(self.builder, _lp[0], _lp[1], _rp[0], _rp[1]);
            _z32c = ir.Constant(ir.IntType(32), 0);
            _cmp_op = {
                Tok.EE: "==",
                Tok.NE: "!=",
                Tok.LT: "<",
                Tok.GT: ">",
                Tok.LTE: "<=",
                Tok.GTE: ">="
            }[op];
            return self.builder.icmp_signed(_cmp_op, _sc3, _z32c, name="scmp3");
        }
    }
    left = self._str_norm(left);
    right = self._str_norm(right);
    left_type = left.type;
    right_type = right.type;
    left_layout = left_type.pointee
        if isinstance(left_type, ir.PointerType)
        else left_type;
    right_layout = right_type.pointee
        if isinstance(right_type, ir.PointerType)
        else right_type;
    if isinstance(left_layout, ir.LiteralStructType)
        or isinstance(right_layout, ir.LiteralStructType) {
        tcmp_struct: (ir.LiteralStructType | None) = None;
        tcmp_left_val: (ir.Value | None) = None;
        tcmp_right_val: (ir.Value | None) = None;
        if isinstance(left_layout, ir.LiteralStructType)
            and isinstance(right_layout, ir.LiteralStructType)
            and str(left_layout) == str(right_layout) {
            tcmp_struct = left_layout;
            tcmp_left_val = self.builder.load(left, name="tcmp.l.val")
                if isinstance(left_type, ir.PointerType)
                else left;
            tcmp_right_val = self.builder.load(right, name="tcmp.r.val")
                if isinstance(right_type, ir.PointerType)
                else right;
        }
        if tcmp_struct is not None
            and tcmp_left_val is not None
            and tcmp_right_val is not None {
            n = len(tcmp_struct.elements);
            i1_t = ir.IntType(1);
            if op == Tok.EE or op == Tok.NE {
                tuple_equal: ir.Value = ir.Constant(i1_t, 1);
                for i in range(n) {
                    ea = self.builder.extract_value(
                        tcmp_left_val, i, name=f"tcmp.ea.{i}"
                    );
                    eb = self.builder.extract_value(
                        tcmp_right_val, i, name=f"tcmp.eb.{i}"
                    );
                    if isinstance(ea.type, ir.IntType) {
                        eq_i = self.builder.icmp_signed(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        eq_i = self.builder.fcmp_ordered(
                            "==", ea, eb, name=f"tcmp.eq.{i}"
                        );
                    } else {
                        _sub_eq: (ir.Value | None) = self._emit_comparison(
                            Tok.EE, ea, eb, isinstance(ea.type, ir.FloatType)
                        );
                        if _sub_eq is None {
                            self.ctx.emit(
                                E5090,
                                kind="comparison",
                                name=f"tuple element {i}",
                                help_text="This tuple element does not lower to a comparable representation."
                            );
                            return None;
                        }
                        eq_i = _sub_eq;
                    }
                    tuple_equal = self.builder.and_(
                        tuple_equal, eq_i, name=f"tcmp.all.{i}"
                    );
                }
                if op == Tok.NE {
                    return self.builder.not_(tuple_equal, name="tcmp.ne");
                }
                return tuple_equal;
            }
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) and n > 0 {
                _tup_args: list[TypeBase] = self._agg_key_args(key_ret, "tuple") or [];
                func = self.builder.basic_block.function;
                tcmp_true_bb = func.append_basic_block(name="tcmp.lex.true");
                tcmp_false_bb = func.append_basic_block(name="tcmp.lex.false");
                tcmp_done_bb = func.append_basic_block(name="tcmp.lex.done");
                for i in range(n) {
                    ea = self.builder.extract_value(
                        tcmp_left_val, i, name=f"tcmp.lex.ea.{i}"
                    );
                    eb = self.builder.extract_value(
                        tcmp_right_val, i, name=f"tcmp.lex.eb.{i}"
                    );
                    _elem_unsigned = (
                        self._key_elem_unsigned(_tup_args[i])
                            if i < len(_tup_args)
                            else False
                    );
                    if isinstance(ea.type, ir.IntType) {
                        (ea, eb) = self._unify_int_widths(ea, eb);
                        (lt_i, gt_i) = self._int_lt_gt_pair(
                            ea, eb, _elem_unsigned, f"tcmp.{i}"
                        );
                    } elif isinstance(ea.type, ir.DoubleType) {
                        lt_i = self.builder.fcmp_ordered(
                            "<", ea, eb, name=f"tcmp.lt.{i}"
                        );
                        gt_i = self.builder.fcmp_ordered(
                            ">", ea, eb, name=f"tcmp.gt.{i}"
                        );
                    } else {
                        _tup_ord = self._emit_order_pair(
                            ea,
                            eb,
                            isinstance(ea.type, ir.FloatType),
                            unsigned,
                            f"tuple element {i}",
                            _tup_args[i] if i < len(_tup_args) else None
                        );
                        if _tup_ord is None {
                            return None;
                        }
                        (lt_i, gt_i) = _tup_ord;
                    }
                    next_bb = func.append_basic_block(name=f"tcmp.lex.next.{i}");
                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(lt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(gt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    } else {
                        self.builder.cbranch(gt_i, tcmp_true_bb, next_bb);
                        self.builder.position_at_start(next_bb);
                        next2_bb = func.append_basic_block(name=f"tcmp.lex.eq.{i}");
                        self.builder.cbranch(lt_i, tcmp_false_bb, next2_bb);
                        self.builder.position_at_start(next2_bb);
                    }
                }
                if op == Tok.LTE or op == Tok.GTE {
                    self.builder.branch(tcmp_true_bb);
                } else {
                    self.builder.branch(tcmp_false_bb);
                }
                self.builder.position_at_start(tcmp_true_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_false_bb);
                self.builder.branch(tcmp_done_bb);
                self.builder.position_at_start(tcmp_done_bb);
                tcmp_res = self.builder.phi(i1_t, name="tcmp.lex.res");
                tcmp_res.add_incoming(ir.Constant(i1_t, 1), tcmp_true_bb);
                tcmp_res.add_incoming(ir.Constant(i1_t, 0), tcmp_false_bb);
                return tcmp_res;
            }
        }
    }

    if isinstance(left.type, ir.PointerType)
        and isinstance(right.type, ir.PointerType) {
        i8_ptr = ir.IntType(8).as_pointer();

        if self._is_bytes_value(left) and self._is_bytes_value(right) {
            if op == Tok.EE or op == Tok.NE {
                return self._emit_bytes_eq(left, right, negate=op == Tok.NE);
            }
            if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                _sym = "<"
                    if op == Tok.LT
                    else (">" if op == Tok.GT else ("<=" if op == Tok.LTE else ">="));
                _ord = self._emit_bytes_cmp(left, right, _sym);
                _zero = ir.Constant(ir.IntType(32), 0);
                if op == Tok.LT {
                    return self.builder.icmp_signed("<", _ord, _zero, name="by.lt");
                }
                if op == Tok.GT {
                    return self.builder.icmp_signed(">", _ord, _zero, name="by.gt");
                }
                if op == Tok.LTE {
                    return self.builder.icmp_signed("<=", _ord, _zero, name="by.lte");
                }
                return self.builder.icmp_signed(">=", _ord, _zero, name="by.gte");
            }
        }

        if left.type == i8_ptr and right.type == i8_ptr {
            cmp_result = self._call_str_cmp(self.builder, left, right, name="strcmp");
            zero = ir.Constant(ir.IntType(32), 0);
            if op == Tok.EE or op == Tok.NE {
                _sym = "==" if op == Tok.EE else "!=";
                _nm = "streq" if op == Tok.EE else "strne";
                return self.builder.icmp_signed(_sym, cmp_result, zero, name=_nm);
            }
            if op == Tok.LT {
                return self.builder.icmp_signed("<", cmp_result, zero, name="strlt");
            } elif op == Tok.GT {
                return self.builder.icmp_signed(">", cmp_result, zero, name="strgt");
            } elif op == Tok.LTE {
                return self.builder.icmp_signed("<=", cmp_result, zero, name="strle");
            } elif op == Tok.GTE {
                return self.builder.icmp_signed(">=", cmp_result, zero, name="strge");
            }
            return None;
        }

        for (lcmp_key, lcmp_type) in self.list_types.items() {
            if left.type == lcmp_type.as_pointer()
                and right.type == lcmp_type.as_pointer() {
                lcmp_h = self.list_helpers.get(lcmp_key);
                if lcmp_h is None {
                    break;
                }
                i64 = ir.IntType(64);
                i1_t = ir.IntType(1);
                lcmp_la = self.builder.call(lcmp_h["len"], [left], name="lcmp.la");
                lcmp_lb = self.builder.call(lcmp_h["len"], [right], name="lcmp.lb");
                func = self.builder.basic_block.function;
                lcmp_entry_bb = self.builder.basic_block;
                lcmp_et = lcmp_h["elem_type"];
                if op == Tok.EE or op == Tok.NE {
                    lcmp_len_eq = self.builder.icmp_unsigned(
                        "==", lcmp_la, lcmp_lb, name="lcmp.leq"
                    );
                    lcmp_chk_bb = func.append_basic_block(name="lcmp.eq.chk");
                    lcmp_false_bb = func.append_basic_block(name="lcmp.eq.false");
                    lcmp_loop_bb = func.append_basic_block(name="lcmp.eq.loop");
                    lcmp_body_bb = func.append_basic_block(name="lcmp.eq.body");
                    lcmp_ne_bb = func.append_basic_block(name="lcmp.eq.ne");
                    lcmp_next_bb = func.append_basic_block(name="lcmp.eq.next");
                    lcmp_done_bb = func.append_basic_block(name="lcmp.eq.done");
                    self.builder.cbranch(lcmp_len_eq, lcmp_chk_bb, lcmp_false_bb);
                    self.builder.position_at_start(lcmp_chk_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_loop_bb);
                    lcmp_i = self.builder.phi(i64, name="lcmp.eq.i");
                    lcmp_i.add_incoming(ir.Constant(i64, 0), lcmp_chk_bb);
                    lcmp_iend = self.builder.icmp_unsigned(
                        ">=", lcmp_i, lcmp_la, name="lcmp.eq.iend"
                    );
                    self.builder.cbranch(lcmp_iend, lcmp_done_bb, lcmp_body_bb);
                    self.builder.position_at_start(lcmp_body_bb);
                    lcmp_ea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_i], name="lcmp.ea"
                    );
                    lcmp_eb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_i], name="lcmp.eb"
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        lcmp_elem_ne = self.builder.icmp_signed(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_elem_ne = self.builder.fcmp_ordered(
                            "!=", lcmp_ea, lcmp_eb, name="lcmp.ene"
                        );
                    } elif self?.jacval_type and lcmp_et == self.jacval_type {
                        lcmp_elem_ne = self.builder.not_(
                            self._emit_jacval_eq(lcmp_ea, lcmp_eb), name="lcmp.ene"
                        );
                    } else {
                        _lsub_eq: (ir.Value | None) = self._emit_comparison(
                            Tok.EE, lcmp_ea, lcmp_eb, isinstance(lcmp_et, ir.FloatType)
                        );
                        if _lsub_eq is None {
                            self.ctx.emit(
                                E5090,
                                kind="comparison",
                                name="list element",
                                help_text="This list element does not lower to a comparable representation."
                            );
                            return None;
                        }
                        lcmp_elem_ne = self.builder.not_(_lsub_eq, name="lcmp.ene");
                    }
                    self.builder.cbranch(lcmp_elem_ne, lcmp_ne_bb, lcmp_next_bb);
                    self.builder.position_at_start(lcmp_ne_bb);
                    self.builder.branch(lcmp_false_bb);
                    self.builder.position_at_start(lcmp_next_bb);
                    lcmp_ni = self.builder.add(
                        lcmp_i, ir.Constant(i64, 1), name="lcmp.ni"
                    );
                    lcmp_i.add_incoming(lcmp_ni, lcmp_next_bb);
                    self.builder.branch(lcmp_loop_bb);
                    self.builder.position_at_start(lcmp_false_bb);
                    self.builder.branch(lcmp_done_bb);
                    self.builder.position_at_start(lcmp_done_bb);
                    lcmp_result = self.builder.phi(i1_t, name="lcmp.eq.result");
                    lcmp_result.add_incoming(ir.Constant(i1_t, 1), lcmp_loop_bb);
                    lcmp_result.add_incoming(ir.Constant(i1_t, 0), lcmp_false_bb);
                    if op == Tok.NE {
                        return self.builder.not_(lcmp_result, name="lcmp.ne");
                    }
                    return lcmp_result;
                }

                if op in (Tok.LT, Tok.GT, Tok.LTE, Tok.GTE) {
                    if self?.jacval_type and lcmp_et == self.jacval_type {
                        self.ctx.emit(
                            E5092,
                            kind="comparison",
                            name="ordering on tagged-element lists"
                        );
                        return None;
                    }
                    lcmp_lt_len = self.builder.icmp_unsigned(
                        "<", lcmp_la, lcmp_lb, name="lcmp.lex.ltl"
                    );
                    lcmp_min = self.builder.select(
                        lcmp_lt_len, lcmp_la, lcmp_lb, name="lcmp.min"
                    );
                    lcmp_lex_loop = func.append_basic_block(name="lcmp.lex.loop");
                    lcmp_lex_body = func.append_basic_block(name="lcmp.lex.body");
                    lcmp_lex_lbody = func.append_basic_block(name="lcmp.lex.lbody");
                    lcmp_lex_next = func.append_basic_block(name="lcmp.lex.next");
                    lcmp_lex_after = func.append_basic_block(name="lcmp.lex.after");
                    lcmp_lex_true = func.append_basic_block(name="lcmp.lex.true");
                    lcmp_lex_false = func.append_basic_block(name="lcmp.lex.false");
                    lcmp_lex_done = func.append_basic_block(name="lcmp.lex.done");
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_loop);
                    lcmp_li = self.builder.phi(i64, name="lcmp.lex.i");
                    lcmp_li.add_incoming(ir.Constant(i64, 0), lcmp_entry_bb);
                    lcmp_lend = self.builder.icmp_unsigned(
                        ">=", lcmp_li, lcmp_min, name="lcmp.lex.lend"
                    );
                    self.builder.cbranch(lcmp_lend, lcmp_lex_after, lcmp_lex_body);
                    self.builder.position_at_start(lcmp_lex_body);
                    lcmp_lea = self.builder.call(
                        lcmp_h["get"], [left, lcmp_li], name="lcmp.lex.ea"
                    );
                    lcmp_leb = self.builder.call(
                        lcmp_h["get"], [right, lcmp_li], name="lcmp.lex.eb"
                    );
                    _largs: list[TypeBase] = self._agg_key_args(key_ret, "list") or [];
                    _lelem_unsigned = (
                        self._key_elem_unsigned(_largs[0]) if _largs else False
                    );
                    if isinstance(lcmp_et, ir.IntType) {
                        (lcmp_lea, lcmp_leb) = self._unify_int_widths(
                            lcmp_lea, lcmp_leb
                        );
                        (lcmp_lex_lt, lcmp_lex_gt) = self._int_lt_gt_pair(
                            lcmp_lea, lcmp_leb, _lelem_unsigned, "lcmp.lex"
                        );
                    } elif isinstance(lcmp_et, ir.DoubleType) {
                        lcmp_lex_lt = self.builder.fcmp_ordered(
                            "<", lcmp_lea, lcmp_leb, name="lcmp.lex.lt"
                        );
                        lcmp_lex_gt = self.builder.fcmp_ordered(
                            ">", lcmp_lea, lcmp_leb, name="lcmp.lex.gt"
                        );
                    } else {
                        _lst_ord = self._emit_order_pair(
                            lcmp_lea,
                            lcmp_leb,
                            isinstance(lcmp_et, ir.FloatType),
                            unsigned,
                            "list element",
                            _largs[0] if _largs else None
                        );
                        if _lst_ord is None {
                            return None;
                        }
                        (lcmp_lex_lt, lcmp_lex_gt) = _lst_ord;
                    }

                    if op == Tok.LT or op == Tok.LTE {
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_true, lcmp_lex_lbody
                        );
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_false, lcmp_lex_next
                        );
                    } else {
                        self.builder.cbranch(
                            lcmp_lex_gt, lcmp_lex_true, lcmp_lex_lbody
                        );
                        self.builder.position_at_start(lcmp_lex_lbody);
                        self.builder.cbranch(
                            lcmp_lex_lt, lcmp_lex_false, lcmp_lex_next
                        );
                    }
                    self.builder.position_at_start(lcmp_lex_next);
                    lcmp_lni = self.builder.add(
                        lcmp_li, ir.Constant(i64, 1), name="lcmp.lni"
                    );
                    lcmp_li.add_incoming(lcmp_lni, lcmp_lex_next);
                    self.builder.branch(lcmp_lex_loop);
                    self.builder.position_at_start(lcmp_lex_after);

                    if op == Tok.LT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.GT {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } elif op == Tok.LTE {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            "<=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    } else {
                        lcmp_len_res = self.builder.icmp_unsigned(
                            ">=", lcmp_la, lcmp_lb, name="lcmp.llen"
                        );
                    }
                    self.builder.cbranch(lcmp_len_res, lcmp_lex_true, lcmp_lex_false);
                    self.builder.position_at_start(lcmp_lex_true);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_false);
                    self.builder.branch(lcmp_lex_done);
                    self.builder.position_at_start(lcmp_lex_done);
                    lcmp_lex_res = self.builder.phi(i1_t, name="lcmp.lex.res");
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 1), lcmp_lex_true);
                    lcmp_lex_res.add_incoming(ir.Constant(i1_t, 0), lcmp_lex_false);
                    return lcmp_lex_res;
                }
                break;
            }
        }

        for (sk, st) in self.set_types.items() {
            if left.type == st.as_pointer() and right.type == st.as_pointer() {
                shelpers = self.set_helpers.get(sk);
                if shelpers is not None {
                    _ctx = NativeEmitCtx(pass_ref=self, type_key=sk);
                    _se = self._ensure_emitters().get("set");
                    if isinstance(_se, NativeSetEmitter) {
                        i64 = ir.IntType(64);
                        i1_t = ir.IntType(1);
                        if op == Tok.LTE {
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sle"
                            );
                        }
                        if op == Tok.GTE {
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            return self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sge"
                            );
                        }

                        len_a = self.builder.call(
                            shelpers["len"], [left], name="scmp.la"
                        );
                        len_b = self.builder.call(
                            shelpers["len"], [right], name="scmp.lb"
                        );
                        if op == Tok.EE or op == Tok.NE {
                            len_eq = self.builder.icmp_unsigned(
                                "==", len_a, len_b, name="scmp.leq"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="scmp.check");
                            false_bb = func.append_basic_block(name="scmp.false");
                            done_bb = func.append_basic_block(name="scmp.done");
                            self.builder.cbranch(len_eq, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="scmp.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="scmp.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            if op == Tok.NE {
                                return self.builder.not_(result, name="scmp.ne");
                            }
                            return result;
                        }
                        if op == Tok.LT {
                            len_lt = self.builder.icmp_unsigned(
                                "<", len_a, len_b, name="slt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="slt.check");
                            false_bb = func.append_basic_block(name="slt.false");
                            done_bb = func.append_basic_block(name="slt.done");
                            self.builder.cbranch(len_lt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, left, [right]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="slt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="slt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                        if op == Tok.GT {
                            len_gt = self.builder.icmp_unsigned(
                                "<", len_b, len_a, name="sgt.lcmp"
                            );
                            func = self.builder.basic_block.function;
                            check_bb = func.append_basic_block(name="sgt.check");
                            false_bb = func.append_basic_block(name="sgt.false");
                            done_bb = func.append_basic_block(name="sgt.done");
                            self.builder.cbranch(len_gt, check_bb, false_bb);
                            self.builder.position_at_start(check_bb);
                            sub_val = _se.emit_issubset(_ctx, right, [left]);
                            after_bb = self.builder.basic_block;
                            is_sub = self.builder.icmp_unsigned(
                                "!=", sub_val, ir.Constant(i64, 0), name="sgt.issub"
                            );
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(false_bb);
                            self.builder.branch(done_bb);
                            self.builder.position_at_start(done_bb);
                            result = self.builder.phi(i1_t, name="sgt.result");
                            result.add_incoming(is_sub, after_bb);
                            result.add_incoming(ir.Constant(i1_t, 0), false_bb);
                            return result;
                        }
                    }
                }
                break;
            }
        }

        rtype_ptr = self.range_struct_type.as_pointer();
        if left.type == rtype_ptr
            and right.type == rtype_ptr
            and (op == Tok.EE or op == Tok.NE) {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);

            as_ = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 0)], name="rcmp.as.p"),
                name="rcmp.as"
            );
            bs_ = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 0)], name="rcmp.bs.p"),
                name="rcmp.bs"
            );
            ae = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 1)], name="rcmp.ae.p"),
                name="rcmp.ae"
            );
            be = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 1)], name="rcmp.be.p"),
                name="rcmp.be"
            );
            at = self.builder.load(
                self.builder.gep(left, [z0, ir.Constant(i32, 2)], name="rcmp.at.p"),
                name="rcmp.at"
            );
            bt = self.builder.load(
                self.builder.gep(right, [z0, ir.Constant(i32, 2)], name="rcmp.bt.p"),
                name="rcmp.bt"
            );
            seq = self.builder.icmp_signed("==", as_, bs_, name="rcmp.seq");
            eeq = self.builder.icmp_signed("==", ae, be, name="rcmp.eeq");
            teq = self.builder.icmp_signed("==", at, bt, name="rcmp.teq");
            range_equal = self.builder.and_(
                seq, self.builder.and_(eeq, teq, name="rcmp.et"), name="rcmp.all"
            );
            if op == Tok.NE {
                return self.builder.not_(range_equal, name="rcmp.ne");
            }
            return range_equal;
        }

        ctype_ptr = self.complex_struct_type.as_pointer();
        if left.type == ctype_ptr and right.type == ctype_ptr {
            i1_t = ir.IntType(1);
            i32 = ir.IntType(32);
            z0 = ir.Constant(i32, 0);
            z1 = ir.Constant(i32, 1);
            ar = self.builder.load(
                self.builder.gep(left, [z0, z0], name="ceq.ar.p"), name="ceq.ar"
            );
            ai = self.builder.load(
                self.builder.gep(left, [z0, z1], name="ceq.ai.p"), name="ceq.ai"
            );
            br = self.builder.load(
                self.builder.gep(right, [z0, z0], name="ceq.br.p"), name="ceq.br"
            );
            bi = self.builder.load(
                self.builder.gep(right, [z0, z1], name="ceq.bi.p"), name="ceq.bi"
            );
            req = self.builder.fcmp_ordered("==", ar, br, name="ceq.r");
            ieq = self.builder.fcmp_ordered("==", ai, bi, name="ceq.i");
            complex_equal = self.builder.and_(req, ieq, name="ceq.both");
            if op == Tok.EE {
                return complex_equal;
            } elif op == Tok.NE {
                return self.builder.not_(complex_equal, name="ceq.ne");
            }
        }

        if op == Tok.EE {
            return self.builder.icmp_unsigned("==", left, right, name="ptreq");
        } elif op == Tok.NE {
            return self.builder.icmp_unsigned("!=", left, right, name="ptrne");
        }
        return None;
    }
    if is_float {
        if op == Tok.NE {
            return self.builder.fcmp_unordered("!=", left, right, name="fcmp");
        }
        fcmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in fcmp_map {
            return self.builder.fcmp_ordered(fcmp_map[op], left, right, name="fcmp");
        }
    } else {
        icmp_map: dict[(str, str)] = {
            Tok.EE: "==",
            Tok.NE: "!=",
            Tok.LT: "<",
            Tok.GT: ">",
            Tok.LTE: "<=",
            Tok.GTE: ">="
        };
        if op in icmp_map {
            if not isinstance(left.type, ir.IntType)
                or not isinstance(right.type, ir.IntType) {
                self.ctx.emit(
                    E5090,
                    kind="comparison",
                    name=f"{left.type} against {right.type}",
                    help_text="The two sides of this comparison lower to different native representations, so no integer comparison is well formed. Annotate the values (or the container they came from) so both sides agree."
                );
                return None;
            }
            (left, right) = self._unify_int_widths(left, right);
            if left.type != right.type {
                self.ctx.emit(
                    E5090,
                    kind="comparison",
                    name=f"{left.type} against {right.type}",
                    help_text="The two sides of this comparison lower to different integer widths. The checker unifies fixed-width operands, so a mismatch here is a lowering bug."
                );
                return None;
            }
            if unsigned {
                return self.builder.icmp_unsigned(
                    icmp_map[op], left, right, name="icmp"
                );
            }
            return self.builder.icmp_signed(icmp_map[op], left, right, name="icmp");
        }
    }
    return None;
}

impl NaIRGenPass._emit_order_pair(
    left: ir.Value,
    right: ir.Value,
    is_float: bool,
    unsigned: bool,
    name: str,
    key_ret: (TypeBase | None) = None
) -> (tuple[(ir.Value, ir.Value)] | None) {
    _lt = self._emit_comparison(
        Tok.LT, left, right, is_float, unsigned=unsigned, key_ret=key_ret
    );
    if _lt is None {
        self.ctx.emit(
            E5090,
            kind="comparison",
            name=name,
            help_text="This element does not lower to an orderable representation."
        );
        return None;
    }
    _gt = self._emit_comparison(
        Tok.GT, left, right, is_float, unsigned=unsigned, key_ret=key_ret
    );
    if _gt is None {
        self.ctx.emit(
            E5090,
            kind="comparison",
            name=name,
            help_text="This element does not lower to an orderable representation."
        );
        return None;
    }
    return (_lt, _gt);
}

impl NaIRGenPass._sort_key_supported(ty: ir.Type) -> bool {
    return self._sort_key_supported_d(ty, 0);
}

impl NaIRGenPass._sort_key_supported_d(ty: ir.Type, depth: int) -> bool {
    if depth > 8 {
        return False;
    }
    if isinstance(ty, ir.IntType) or isinstance(ty, (ir.DoubleType, ir.FloatType)) {
        return True;
    }
    if self._is_jacval_ty(ty) {
        return False;
    }
    if self._str_desc_ty is not None and ty == self._str_desc_ty {
        return True;
    }
    if isinstance(ty, ir.LiteralStructType) {
        for tt in self.tuple_types.values() {
            if ty == tt {
                for et in tt.elements {
                    if not self._sort_key_supported_d(et, depth + 1) {
                        return False;
                    }
                }
                return True;
            }
        }
        return False;
    }
    if not isinstance(ty, ir.PointerType) {
        return False;
    }
    if self._bytes_struct_type is not None and ty.pointee == self._bytes_struct_type {
        return True;
    }
    for (lk, lt) in self.list_types.items() {
        if ty.pointee == lt {
            lh = self.list_helpers.get(lk);
            if lh is None {
                return False;
            }
            return self._sort_key_supported_d(lh["elem_type"], depth + 1);
        }
    }
    for (sk, st) in self.set_types.items() {
        if ty.pointee == st {
            return self.set_helpers.get(sk) is not None;
        }
    }

    if ty.pointee == ir.IntType(8) {
        return False;
    }
    return self._sort_key_supported_d(ty.pointee, depth + 1);
}

impl NaIRGenPass._sort_key_return_type(nd: (uni.UniNode | None)) -> (TypeBase | None) {
    import from jaclang.compiler.types.types { FunctionType }
    while isinstance(nd, uni.CfgExpr) {
        nd = nd.expr;
    }
    if isinstance(nd, uni.LambdaExpr) {
        _ret = nd.tail_return_expr();
        return _ret.type if _ret is not None else None;
    }
    if isinstance(nd, uni.Expr) and isinstance(nd.type, FunctionType) {
        return nd.type.return_type;
    }
    return None;
}

impl NaIRGenPass._sort_key_orderable(ty: (TypeBase | None)) -> (bool | None) {
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    if ty is None {
        return None;
    }
    _name = primitive_type_name_of(ty);
    if _name == "str" or _name == "bytes" {
        return True;
    }
    if self._scalar_shape_named(_name) is not None {
        return True;
    }
    if not isinstance(ty, ClassType) {
        return None;
    }
    if _name is None {
        return False;
    }
    if _name not in ("list", "set", "frozenset", "tuple") {
        return False;
    }
    _args = ty.private.type_args or [];
    if not _args {
        return None;
    }
    _orderable: (bool | None) = True;
    for _arg in _args {
        _sub = self._sort_key_orderable(_arg);
        if _sub is False {
            return False;
        }
        if _sub is None {
            _orderable = None;
        }
    }
    return _orderable;
}

impl NaIRGenPass._sort_key_unsigned(nd: (uni.UniNode | None)) -> bool {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    while isinstance(nd, uni.CfgExpr) {
        nd = nd.expr;
    }
    if isinstance(nd, uni.LambdaExpr) {
        return self._is_unsigned_node(nd.tail_return_expr());
    }
    _shape = self._scalar_shape_named(
        primitive_type_name_of(self._sort_key_return_type(nd))
    );
    return _shape is not None
        and _shape.sized
        and not _shape.is_float
        and not _shape.signed;
}

impl NaIRGenPass._agg_key_args(
    key_ret: (TypeBase | None), agg_name: str
) -> (list[TypeBase] | None) {
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    if not isinstance(key_ret, ClassType) {
        return None;
    }
    if primitive_type_name_of(key_ret) != agg_name {
        return None;
    }
    return list(key_ret.private.type_args or []);
}

impl NaIRGenPass._key_elem_unsigned(et: (TypeBase | None)) -> bool {
    import from jaclang.compiler.types.type_utils { primitive_type_name_of }
    _shape = self._scalar_shape_named(primitive_type_name_of(et));
    return _shape is not None
        and _shape.sized
        and not _shape.is_float
        and not _shape.signed;
}
