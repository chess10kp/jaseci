impl NaIRGenPass._emit_str_len_helpers -> None {
    if self.str_len_fn is not None {
        return;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    _headerless = self._nogc_headerless();

    len_fn = self._define_function("__jac_str_len", ir.FunctionType(i64, [i8_ptr]));
    len_fn.linkage = "private";
    len_fn.args[0].name = "s";
    _l_entry = len_fn.append_basic_block("entry");
    b = ir.IRBuilder(_l_entry);
    if _headerless {
        _l_null = b.icmp_unsigned(
            "==", len_fn.args[0], ir.Constant(i8_ptr, None), name="sl.null"
        );
        _l_zero = len_fn.append_basic_block("zero");
        _l_slow0 = len_fn.append_basic_block("slow");
        b.cbranch(_l_null, _l_zero, _l_slow0);
        b = ir.IRBuilder(_l_zero);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(_l_slow0);
        b.ret(b.call(strlen_fn, [len_fn.args[0]], name="sl.strlen"));
    } else {
        _l_zero = len_fn.append_basic_block("zero");
        _l_sent = len_fn.append_basic_block("check.sentinel");
        _l_magic = len_fn.append_basic_block("check.magic");
        _l_hdr = len_fn.append_basic_block("hdr");
        _l_fast = len_fn.append_basic_block("fast");
        _l_slow = len_fn.append_basic_block("slow");
        _l_null = b.icmp_unsigned(
            "==", len_fn.args[0], ir.Constant(i8_ptr, None), name="sl.null"
        );
        b.cbranch(_l_null, _l_zero, _l_sent);
        b = ir.IRBuilder(_l_zero);
        b.ret(ir.Constant(i64, 0));
        b = ir.IRBuilder(_l_sent);
        _l_rc_slot = b.gep(
            len_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="sl.rc.slot"
        );
        _l_rc = b.load(b.bitcast(_l_rc_slot, i64_ptr, name="sl.rc.p"), name="sl.rc");
        _l_static = b.icmp_unsigned(
            "==", _l_rc, ir.Constant(i64, RC_SENTINEL), name="sl.static"
        );
        b.cbranch(_l_static, _l_hdr, _l_magic);
        b = ir.IRBuilder(_l_magic);
        _l_mc = self._emit_magic_check(b, len_fn.args[0], name_prefix="sl.mc");
        b.cbranch(_l_mc, _l_hdr, _l_slow);
        b = ir.IRBuilder(_l_hdr);
        _l_dt_slot = b.gep(
            len_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="sl.dt.slot"
        );
        _l_dv = b.load(b.bitcast(_l_dt_slot, i64_ptr, name="sl.dt.p"), name="sl.dv");
        _l_odd = b.and_(_l_dv, ir.Constant(i64, STR_LEN_TAG_BIT), name="sl.odd");
        b.cbranch(
            b.icmp_unsigned("!=", _l_odd, ir.Constant(i64, 0), name="sl.has.len"),
            _l_fast,
            _l_slow
        );
        b = ir.IRBuilder(_l_fast);
        b.ret(b.lshr(_l_dv, ir.Constant(i64, STR_LEN_TAG_SHIFT), name="sl.len"));
        b = ir.IRBuilder(_l_slow);
        b.ret(b.call(strlen_fn, [len_fn.args[0]], name="sl.strlen"));
    }
    self.str_len_fn = len_fn;

    tr_fn = self._define_function(
        "__jac_str_truthy", ir.FunctionType(ir.IntType(1), [i8_ptr])
    );
    tr_fn.linkage = "private";
    tr_fn.args[0].name = "s";
    _t_entry = tr_fn.append_basic_block("entry");
    tb = ir.IRBuilder(_t_entry);
    if _headerless {
        tb.ret(
            tb.icmp_unsigned(
                "!=", tr_fn.args[0], ir.Constant(i8_ptr, None), name="st.nn"
            )
        );
    } else {
        _t_zero = tr_fn.append_basic_block("zero");
        _t_sent = tr_fn.append_basic_block("check.sentinel");
        _t_magic = tr_fn.append_basic_block("check.magic");
        _t_hdr = tr_fn.append_basic_block("hdr");
        _t_len = tr_fn.append_basic_block("stamped");
        _t_obj = tr_fn.append_basic_block("object");
        _t_cstr = tr_fn.append_basic_block("cstr");
        _t_null = tb.icmp_unsigned(
            "==", tr_fn.args[0], ir.Constant(i8_ptr, None), name="st.null"
        );
        tb.cbranch(_t_null, _t_zero, _t_sent);
        tb = ir.IRBuilder(_t_zero);
        tb.ret(ir.Constant(ir.IntType(1), 0));
        tb = ir.IRBuilder(_t_sent);
        _t_rc_slot = tb.gep(
            tr_fn.args[0], [ir.Constant(i64, HDR_RC_OFF)], name="st.rc.slot"
        );
        _t_rc = tb.load(tb.bitcast(_t_rc_slot, i64_ptr, name="st.rc.p"), name="st.rc");
        _t_static = tb.icmp_unsigned(
            "==", _t_rc, ir.Constant(i64, RC_SENTINEL), name="st.static"
        );
        tb.cbranch(_t_static, _t_hdr, _t_magic);
        tb = ir.IRBuilder(_t_magic);
        _t_mc = self._emit_magic_check(tb, tr_fn.args[0], name_prefix="st.mc");
        tb.cbranch(_t_mc, _t_hdr, _t_cstr);
        tb = ir.IRBuilder(_t_hdr);
        _t_dt_slot = tb.gep(
            tr_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="st.dt.slot"
        );
        _t_dv = tb.load(tb.bitcast(_t_dt_slot, i64_ptr, name="st.dt.p"), name="st.dv");
        _t_odd = tb.and_(_t_dv, ir.Constant(i64, STR_LEN_TAG_BIT), name="st.odd");
        tb.cbranch(
            tb.icmp_unsigned("!=", _t_odd, ir.Constant(i64, 0), name="st.has.len"),
            _t_len,
            _t_obj
        );
        tb = ir.IRBuilder(_t_len);
        tb.ret(
            tb.icmp_unsigned(
                "!=",
                tb.lshr(_t_dv, ir.Constant(i64, STR_LEN_TAG_SHIFT), name="st.len"),
                ir.Constant(i64, 0),
                name="st.len.nz"
            )
        );
        tb = ir.IRBuilder(_t_obj);
        tb.ret(ir.Constant(ir.IntType(1), 1));
        tb = ir.IRBuilder(_t_cstr);
        tb.ret(
            tb.icmp_unsigned(
                "!=",
                tb.call(strlen_fn, [tr_fn.args[0]], name="st.strlen"),
                ir.Constant(i64, 0),
                name="st.strlen.nz"
            )
        );
    }
    self.str_truthy_fn = tr_fn;
    self._emit_str_stamp_and_new();
}

impl NaIRGenPass._emit_str_stamp_and_new -> None {
    i8 = ir.IntType(8);
    i8_ptr = i8.as_pointer();
    i64 = ir.IntType(64);
    i64_ptr = i64.as_pointer();
    _headerless = self._nogc_headerless();
    stamp_fn = self._define_function(
        "__jac_str_stamp", ir.FunctionType(ir.VoidType(), [i8_ptr, i64])
    );
    stamp_fn.linkage = "private";
    stamp_fn.args[0].name = "s";
    stamp_fn.args[1].name = "n";
    _s_entry = stamp_fn.append_basic_block("entry");
    _s_done = stamp_fn.append_basic_block("done");
    b = ir.IRBuilder(_s_entry);
    if _headerless {
        b.branch(_s_done);
    } else {
        _s_magic = stamp_fn.append_basic_block("check.magic");
        _s_store = stamp_fn.append_basic_block("store");
        _s_null = b.icmp_unsigned(
            "==", stamp_fn.args[0], ir.Constant(i8_ptr, None), name="ss.null"
        );
        b.cbranch(_s_null, _s_done, _s_magic);
        b = ir.IRBuilder(_s_magic);
        _s_mc = self._emit_magic_check(b, stamp_fn.args[0], name_prefix="ss.mc");
        b.cbranch(_s_mc, _s_store, _s_done);
        b = ir.IRBuilder(_s_store);
        _s_enc = b.or_(
            b.shl(stamp_fn.args[1], ir.Constant(i64, STR_LEN_TAG_SHIFT), name="ss.shl"),
            ir.Constant(i64, STR_LEN_TAG_BIT),
            name="ss.enc"
        );
        _s_slot = b.gep(
            stamp_fn.args[0], [ir.Constant(i64, HDR_DTOR_OFF)], name="ss.slot"
        );
        b.store(_s_enc, b.bitcast(_s_slot, i64_ptr, name="ss.slot.p"));
        b.branch(_s_done);
    }
    b = ir.IRBuilder(_s_done);
    b.ret_void();
    self.str_stamp_fn = stamp_fn;

    memcpy_fn = self._get_or_declare_extern("memcpy", i8_ptr, [i8_ptr, i8_ptr, i64]);
    new_fn = self._define_function(
        "__jac_str_new", ir.FunctionType(i8_ptr, [i8_ptr, i64])
    );
    new_fn.linkage = "weak_odr";
    new_fn.args[0].name = "data";
    new_fn.args[1].name = "n";
    _n_entry = new_fn.append_basic_block("entry");
    b = ir.IRBuilder(_n_entry);
    _n_null = b.icmp_unsigned(
        "==", new_fn.args[0], ir.Constant(i8_ptr, None), name="sn.null"
    );
    _n_len = b.select(_n_null, ir.Constant(i64, 0), new_fn.args[1], name="sn.n");
    _n_size = b.add(_n_len, ir.Constant(i64, 1), name="sn.size");
    _n_buf = b.call(self.rc_alloc_fn, [_n_size], name="sn.buf");
    _n_copy = new_fn.append_basic_block("copy");
    _n_fin = new_fn.append_basic_block("finish");
    b.cbranch(
        b.icmp_unsigned("==", _n_len, ir.Constant(i64, 0), name="sn.empty"),
        _n_fin,
        _n_copy
    );
    b = ir.IRBuilder(_n_copy);
    b.call(memcpy_fn, [_n_buf, new_fn.args[0], _n_len]);
    b.branch(_n_fin);
    b = ir.IRBuilder(_n_fin);
    _n_end = b.gep(_n_buf, [_n_len], name="sn.end");
    b.store(ir.Constant(i8, 0), _n_end);
    if not _headerless {
        if self.rc_set_type_fn is not None {
            _i32n = ir.IntType(32);
            _n_tag_gv = self._get_snprintf_fmt("str");
            _n_tag = b.gep(
                _n_tag_gv, [ir.Constant(_i32n, 0), ir.Constant(_i32n, 0)], name="sn.tag"
            );
            b.call(self.rc_set_type_fn, [_n_buf, _n_tag]);
        }
        b.call(stamp_fn, [_n_buf, _n_len]);
    }
    b.ret(_n_buf);
    self.str_new_fn = new_fn;
}

impl NaIRGenPass._call_str_len(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.len"
) -> ir.Value {
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    return b.call(self.str_len_fn, [ptr], name=name);
}

impl NaIRGenPass._call_str_truthy(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.truthy"
) -> ir.Value {
    if self.str_truthy_fn is None {
        self._emit_str_len_helpers();
    }
    return b.call(self.str_truthy_fn, [ptr], name=name);
}

impl NaIRGenPass._stamp_str_len(
    b: ir.IRBuilder, ptr: ir.Value, len_val: ir.Value
) -> None {
    if self._nogc_headerless() {
        return;
    }
    if self.str_stamp_fn is None {
        self._emit_str_len_helpers();
    }
    b.call(self.str_stamp_fn, [ptr, len_val]);
}

impl NaIRGenPass._emit_str_cmp_helper -> None {
    if self.str_cmp_fn is not None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    cmp_fn = self._define_function(
        "__jac_str_cmp", ir.FunctionType(i32, [i8_ptr, i8_ptr])
    );
    cmp_fn.linkage = "private";
    cmp_fn.args[0].name = "a";
    cmp_fn.args[1].name = "b";
    _c_entry = cmp_fn.append_basic_block("entry");
    _c_same = cmp_fn.append_basic_block("same");
    _c_anull = cmp_fn.append_basic_block("check.a");
    _c_alt = cmp_fn.append_basic_block("a.null");
    _c_bnull = cmp_fn.append_basic_block("check.b");
    _c_bgt = cmp_fn.append_basic_block("b.null");
    _c_body = cmp_fn.append_basic_block("body");
    b = ir.IRBuilder(_c_entry);
    b.cbranch(
        b.icmp_unsigned("==", cmp_fn.args[0], cmp_fn.args[1], name="sc.same"),
        _c_same,
        _c_anull
    );
    b = ir.IRBuilder(_c_same);
    b.ret(ir.Constant(i32, 0));
    b = ir.IRBuilder(_c_anull);
    b.cbranch(
        b.icmp_unsigned("==", cmp_fn.args[0], ir.Constant(i8_ptr, None), name="sc.an"),
        _c_alt,
        _c_bnull
    );
    b = ir.IRBuilder(_c_alt);
    b.ret(ir.Constant(i32, -1));
    b = ir.IRBuilder(_c_bnull);
    b.cbranch(
        b.icmp_unsigned("==", cmp_fn.args[1], ir.Constant(i8_ptr, None), name="sc.bn"),
        _c_bgt,
        _c_body
    );
    b = ir.IRBuilder(_c_bgt);
    b.ret(ir.Constant(i32, 1));
    b = ir.IRBuilder(_c_body);
    left_len = self._call_str_len(b, cmp_fn.args[0], name="sc.left.len");
    right_len = self._call_str_len(b, cmp_fn.args[1], name="sc.right.len");
    b.ret(
        self._call_str_cmp3(
            b, cmp_fn.args[0], left_len, cmp_fn.args[1], right_len, name="sc.cmp"
        )
    );
    self.str_cmp_fn = cmp_fn;
}

impl NaIRGenPass._call_str_cmp(
    b: ir.IRBuilder, lhs: ir.Value, rhs: ir.Value, name: str = "s.cmp"
) -> ir.Value {
    if self.str_cmp_fn is None {
        self._emit_str_cmp_helper();
    }
    return b.call(self.str_cmp_fn, [lhs, rhs], name=name);
}

impl NaIRGenPass._emit_str_dup_helper -> None {
    if self.str_dup_fn is not None {
        return;
    }
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    i8_ptr = ir.IntType(8).as_pointer();
    dup_fn = self._define_function("__jac_str_dup", ir.FunctionType(i8_ptr, [i8_ptr]));
    dup_fn.linkage = "private";
    dup_fn.args[0].name = "s";
    _d_entry = dup_fn.append_basic_block("entry");
    _d_null = dup_fn.append_basic_block("null");
    _d_copy = dup_fn.append_basic_block("copy");
    b = ir.IRBuilder(_d_entry);
    b.cbranch(
        b.icmp_unsigned(
            "==", dup_fn.args[0], ir.Constant(i8_ptr, None), name="sd.null"
        ),
        _d_null,
        _d_copy
    );
    b = ir.IRBuilder(_d_null);
    b.ret(ir.Constant(i8_ptr, None));
    b = ir.IRBuilder(_d_copy);
    _d_len = b.call(self.str_len_fn, [dup_fn.args[0]], name="sd.len");
    b.ret(b.call(self.str_new_fn, [dup_fn.args[0], _d_len], name="sd.new"));
    self.str_dup_fn = dup_fn;
}

impl NaIRGenPass._call_str_dup(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.dup"
) -> ir.Value {
    if self.str_dup_fn is None {
        self._emit_str_dup_helper();
    }
    return b.call(self.str_dup_fn, [ptr], name=name);
}

impl NaIRGenPass._emit_str_len_raw_helper -> None {
    if self.str_len_raw_fn is not None {
        return;
    }
    i8_ptr = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8_ptr]);
    raw_fn = self._define_function("__jac_str_len_raw", ir.FunctionType(i64, [i8_ptr]));
    raw_fn.linkage = "private";
    raw_fn.args[0].name = "p";
    _r_entry = raw_fn.append_basic_block("entry");
    _r_zero = raw_fn.append_basic_block("zero");
    _r_scan = raw_fn.append_basic_block("scan");
    b = ir.IRBuilder(_r_entry);
    b.cbranch(
        b.icmp_unsigned(
            "==", raw_fn.args[0], ir.Constant(i8_ptr, None), name="sr.null"
        ),
        _r_zero,
        _r_scan
    );
    b = ir.IRBuilder(_r_zero);
    b.ret(ir.Constant(i64, 0));
    b = ir.IRBuilder(_r_scan);
    b.ret(b.call(strlen_fn, [raw_fn.args[0]], name="sr.strlen"));
    self.str_len_raw_fn = raw_fn;
}

impl NaIRGenPass._call_str_len_raw(
    b: ir.IRBuilder, ptr: ir.Value, name: str = "s.rlen"
) -> ir.Value {
    if self.str_len_raw_fn is None {
        self._emit_str_len_raw_helper();
    }
    return b.call(self.str_len_raw_fn, [ptr], name=name);
}

impl NaIRGenPass._str_desc_type -> ir.IdentifiedStructType {
    if self._str_desc_ty is not None {
        return self._str_desc_ty;
    }
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    st = self.llvm_module.context.get_identified_type("JacStr");
    st.set_body(
        *[
            i64 if fname == "len" else i8p
            for fname in JACSTR_DESC_FIELDS[self._str_desc_kind()]
        ]
    );
    self._str_desc_ty = st;
    return st;
}

impl NaIRGenPass._str_desc_kind -> str {
    return "jacstr2" if self._nogc_headerless() else "jacstr3";
}

impl NaIRGenPass._emit_str_desc_helpers -> None {
    if self.str_wrap_fn is not None {
        return;
    }
    if self.str_len_fn is None {
        self._emit_str_len_helpers();
    }
    if self.str_len_raw_fn is None {
        self._emit_str_len_raw_helper();
    }
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    desc = self._str_desc_type();
    _hl = self._nogc_headerless();
    _dfields = JACSTR_DESC_FIELDS[self._str_desc_kind()];
    _di = _dfields.index("data");
    _li = _dfields.index("len");
    _z = ir.Constant(i32, 0);
    for (fname, len_fn) in (
        ("__jac_str_wrap", self.str_len_fn),
        ("__jac_str_wrap_raw", self.str_len_raw_fn)
    ) {
        wf = self._define_function(fname, ir.FunctionType(desc, [i8p]));
        wf.linkage = "private";
        wf.args[0].name = "s";
        wb = ir.IRBuilder(wf.append_basic_block("entry"));
        wlen = wb.call(len_fn, [wf.args[0]], name="w.len");
        slot = wb.alloca(desc, name="w.slot");
        if not _hl {
            wb.store(
                wf.args[0], wb.gep(slot, [_z, ir.Constant(i32, 0)], name="w.root")
            );
        }
        wb.store(wf.args[0], wb.gep(slot, [_z, ir.Constant(i32, _di)], name="w.data"));
        wb.store(wlen, wb.gep(slot, [_z, ir.Constant(i32, _li)], name="w.lenp"));
        wb.ret(wb.load(slot, name="w.desc"));
        if fname == "__jac_str_wrap" {
            self.str_wrap_fn = wf;
        } else {
            self.str_wrap_raw_fn = wf;
        }
    }
    uf = self._define_function("__jac_str_unwrap", ir.FunctionType(i8p, [desc]));
    uf.linkage = "private";
    uf.args[0].name = "d";
    _u_entry = uf.append_basic_block("entry");
    _u_null = uf.append_basic_block("null");
    _u_probe = uf.append_basic_block("probe");
    _u_pass = uf.append_basic_block("pass");
    _u_copy = uf.append_basic_block("copy");
    ub = ir.IRBuilder(_u_entry);
    _u_data = ub.extract_value(uf.args[0], _di, name="u.data");
    _u_len = ub.extract_value(uf.args[0], _li, name="u.len");
    ub.cbranch(
        ub.icmp_unsigned("==", _u_data, ir.Constant(i8p, None), name="u.isnull"),
        _u_null,
        _u_probe
    );
    ub = ir.IRBuilder(_u_null);
    ub.ret(ir.Constant(i8p, None));
    ub = ir.IRBuilder(_u_probe);
    _u_end = ub.load(ub.gep(_u_data, [_u_len], name="u.endp"), name="u.end");
    ub.cbranch(
        ub.icmp_unsigned("==", _u_end, ir.Constant(i8, 0), name="u.hasnul"),
        _u_pass,
        _u_copy
    );
    ub = ir.IRBuilder(_u_pass);
    ub.ret(_u_data);
    ub = ir.IRBuilder(_u_copy);
    ub.ret(ub.call(self.str_new_fn, [_u_data, _u_len], name="u.copy"));
    self.str_unwrap_fn = uf;

    if not _hl {
        mf = self._define_function(
            "__jac_str_materialize", ir.FunctionType(i8p, [desc])
        );
        mf.linkage = "private";
        mb = ir.IRBuilder(mf.append_basic_block("entry"));
        null_bb = mf.append_basic_block("null");
        probe_bb = mf.append_basic_block("probe");
        keep_bb = mf.append_basic_block("keep");
        copy_bb = mf.append_basic_block("copy");
        owner = mb.extract_value(mf.args[0], 0, name="owner");
        data = mb.extract_value(mf.args[0], _di, name="data");
        size = mb.extract_value(mf.args[0], _li, name="size");
        mb.cbranch(
            mb.icmp_unsigned("==", data, ir.Constant(i8p, None)), null_bb, probe_bb
        );
        mb.position_at_end(null_bb);
        mb.ret(ir.Constant(i8p, None));
        mb.position_at_end(probe_bb);
        terminator = mb.load(mb.gep(data, [size]));
        complete = mb.and_(
            mb.icmp_unsigned("==", data, owner),
            mb.icmp_unsigned("==", terminator, ir.Constant(i8, 0))
        );
        mb.cbranch(complete, keep_bb, copy_bb);
        mb.position_at_end(keep_bb);
        self._emit_elem_retain(mb, i8p, owner);
        mb.ret(owner);
        mb.position_at_end(copy_bb);
        mb.ret(mb.call(self.str_new_fn, [data, size], name="copy"));
        self.str_materialize_fn = mf;
    }

    incoming = self._define_function("__jac_str_import", ir.FunctionType(i8p, [i8p]));
    incoming.linkage = "private";
    incoming.args[0].name = "source";
    ib = ir.IRBuilder(incoming.append_basic_block("entry"));
    null_bb = incoming.append_basic_block("null");
    copy_bb = incoming.append_basic_block("copy");
    ib.cbranch(
        ib.icmp_unsigned("==", incoming.args[0], ir.Constant(i8p, None)),
        null_bb,
        copy_bb
    );
    ib.position_at_end(null_bb);
    ib.ret(ir.Constant(i8p, None));
    ib.position_at_end(copy_bb);
    raw = ib.call(self.str_wrap_raw_fn, [incoming.args[0]], name="raw");
    data = ib.extract_value(raw, _di, name="raw.data");
    size = ib.extract_value(raw, _li, name="raw.len");
    ib.ret(ib.call(self.str_new_fn, [data, size], name="owned"));
    self.str_import_fn = incoming;
}

impl NaIRGenPass._str_norm(val: ir.Value) -> ir.Value {
    if self._str_desc_ty is None or val.type != self._str_desc_ty {
        return val;
    }
    if self.str_unwrap_fn is None {
        self._emit_str_desc_helpers();
    }
    _normed = self.builder.call(self.str_unwrap_fn, [val], name="s.norm");
    if self._is_owned(val) {
        self._mark_owned(_normed);
    }
    return _normed;
}

impl NaIRGenPass._str_materialize(val: ir.Value) -> ir.Value {
    if self._nogc_headerless() {
        return self._str_norm(val);
    }
    if self.str_materialize_fn is None {
        self._emit_str_desc_helpers();
    }
    result = self.builder.call(self.str_materialize_fn, [val], name="s.materialized");
    self._release_owned_args([val], op="str_materialize");
    return self._mark_owned(result);
}

impl NaIRGenPass._str_norm_optional(val: ir.Value | None) -> (ir.Value | None) {
    return self._str_norm(val) if val is not None else None;
}

impl NaIRGenPass._str_arg(val: ir.Value | None) -> (ir.Value | None) {
    val = self._str_norm_optional(val);
    if val is not None
        and self._opt_ptr_payload_of(val.type) == ir.IntType(8).as_pointer() {
        return self._coerce_type(val, ir.IntType(8).as_pointer());
    }
    return val;
}

impl NaIRGenPass._membrane_str_out(b: ir.IRBuilder, val: ir.Value) -> ir.Value {
    if self.str_unwrap_fn is None {
        self._emit_str_desc_helpers();
    }
    d = b.call(self.str_wrap_fn, [val], name="mem.out.wrap");
    return b.call(self.str_unwrap_fn, [d], name="mem.out");
}

impl NaIRGenPass._membrane_str_in(b: ir.IRBuilder, val: ir.Value) -> ir.Value {
    if self.str_unwrap_fn is None {
        self._emit_str_desc_helpers();
    }
    result = b.call(self.str_import_fn, [val], name="mem.in");
    return self._mark_owned(result);
}

impl NaIRGenPass._str_alloc(
    b: ir.IRBuilder, size: ir.Value, name: str = "s.buf"
) -> ir.Value {
    _saved = self._builder;
    self._builder = b;
    _buf = self._rc_alloc(size, name=name);
    self._emit_set_type_tag(b, _buf, "str");
    self._builder = _saved;
    return _buf;
}

impl NaIRGenPass._str_finish(
    b: ir.IRBuilder, buf: ir.Value, len_val: ir.Value
) -> None {
    _end = b.gep(buf, [len_val], name="s.end");
    b.store(ir.Constant(ir.IntType(8), 0), _end);
    self._stamp_str_len(b, buf, len_val);
}

impl NaIRGenPass._emit_set_type_tag(
    b: ir.IRBuilder, ptr_i8: ir.Value, type_name: str
) -> None {
    if self.rc_set_type_fn is None {
        return;
    }
    _i32 = ir.IntType(32);
    _tag_gv = self._get_snprintf_fmt(type_name);
    _tag_gep = b.gep(
        _tag_gv, [ir.Constant(_i32, 0), ir.Constant(_i32, 0)], name="tag.gep"
    );
    b.call(self.rc_set_type_fn, [ptr_i8, _tag_gep]);
}

impl NaIRGenPass._emit_str_cmp3_helper -> None {
    if self.str_cmp3_fn is not None {
        return;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    fn = self._define_function(
        "__jac_str_cmp3", ir.FunctionType(i32, [i8p, i64, i8p, i64])
    );
    fn.linkage = "private";
    fn.args[0].name = "a";
    fn.args[1].name = "al";
    fn.args[2].name = "b";
    fn.args[3].name = "bl";
    _entry = fn.append_basic_block("entry");
    _cmp_bb = fn.append_basic_block("cmp");
    _retr_bb = fn.append_basic_block("retr");
    _tie_bb = fn.append_basic_block("tie");
    b = ir.IRBuilder(_entry);
    _al = fn.args[1];
    _bl = fn.args[3];
    _n = b.select(b.icmp_signed("<", _al, _bl, name="c3.min.p"), _al, _bl, name="c3.n");
    b.cbranch(
        b.icmp_signed(">", _n, ir.Constant(i64, 0), name="c3.has"), _cmp_bb, _tie_bb
    );
    b = ir.IRBuilder(_cmp_bb);
    _r = b.call(memcmp_fn, [fn.args[0], fn.args[2], _n], name="c3.memcmp");
    b.cbranch(
        b.icmp_signed("!=", _r, ir.Constant(i32, 0), name="c3.ne"), _retr_bb, _tie_bb
    );
    b = ir.IRBuilder(_retr_bb);
    b.ret(_r);
    b = ir.IRBuilder(_tie_bb);
    _gt = b.zext(b.icmp_signed(">", _al, _bl, name="c3.gt"), i32, name="c3.gt32");
    _lt = b.zext(b.icmp_signed("<", _al, _bl, name="c3.lt"), i32, name="c3.lt32");
    b.ret(b.sub(_gt, _lt, name="c3.sign"));
    self.str_cmp3_fn = fn;
}

impl NaIRGenPass._call_str_cmp3(
    b: ir.IRBuilder,
    l_data: ir.Value,
    l_len: ir.Value,
    r_data: ir.Value,
    r_len: ir.Value,
    name: str = "s.cmp3"
) -> ir.Value {
    if self.str_cmp3_fn is None {
        self._emit_str_cmp3_helper();
    }
    return b.call(self.str_cmp3_fn, [l_data, l_len, r_data, r_len], name=name);
}

impl NaIRGenPass._str_cmp_parts_of(
    val: ir.Value
) -> (tuple[ir.Value, ir.Value] | None) {
    if self._str_desc_ty is not None and val.type == self._str_desc_ty {
        _hl = self._nogc_headerless();
        _d = self.builder.extract_value(val, 0 if _hl else 1, name="scmp.data");
        _l = self.builder.extract_value(val, 1 if _hl else 2, name="scmp.len");
        return (_d, _l);
    }
    if val.type == ir.IntType(8).as_pointer() {
        return (val, self._call_str_len(self.builder, val, name="scmp.rawlen"));
    }
    return None;
}
