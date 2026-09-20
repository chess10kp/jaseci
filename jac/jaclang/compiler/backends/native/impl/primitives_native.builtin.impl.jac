impl NativeBuiltinEmitter.emit_print(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_input(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_len(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_abs(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    b = ctx.pass_ref.builder;
    if isinstance(arg_val.type, ir.IntType) {
        if arg_val.type.width == 1 {
            return arg_val;
        }
        if ctx.arg_nodes and ctx.pass_ref._is_sized_node(ctx.arg_nodes[0]) {
            return ctx.pass_ref._emit_checked_abs(arg_val);
        }
        _zero = ir.Constant(arg_val.type, 0);
        _is_neg = b.icmp_signed("<", arg_val, _zero, name="abs.neg");
        _negv = b.neg(arg_val, name="abs.negv");
        return b.select(_is_neg, _negv, arg_val, name="abs");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        fabs_fn = ctx.pass_ref._get_or_declare_extern(
            "fabs", ir.DoubleType(), [ir.DoubleType()]
        );
        return b.call(fabs_fn, [arg_val], name="abs.fresult");
    }
    if isinstance(arg_val.type, ir.FloatType) {
        fabsf_fn = ctx.pass_ref._get_or_declare_extern(
            "fabsf", ir.FloatType(), [ir.FloatType()]
        );
        return b.call(fabsf_fn, [arg_val], name="abs.f32result");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_round(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    if isinstance(arg_val.type, ir.DoubleType) {
        round_fn = p._get_or_declare_extern(
            "round", ir.DoubleType(), [ir.DoubleType()]
        );
        rounded = b.call(round_fn, [arg_val], name="round.f");
        return b.fptosi(rounded, i64, name="round.result");
    }

    if isinstance(arg_val.type, ir.IntType) {
        return arg_val;
    }
    return None;
}

impl NativeBuiltinEmitter.emit_min(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    b = ctx.pass_ref.builder;
    a = args[0];
    v = args[1];
    if isinstance(a.type, ir.IntType) and isinstance(v.type, ir.IntType) {
        cmp = b.icmp_signed("<", a, v, name="min.cmp");
        return b.select(cmp, a, v, name="min.result");
    }
    if isinstance(a.type, ir.DoubleType) and isinstance(v.type, ir.DoubleType) {
        cmp = b.fcmp_ordered("<", a, v, name="min.fcmp");
        return b.select(cmp, a, v, name="min.fresult");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_max(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    b = ctx.pass_ref.builder;
    a = args[0];
    v = args[1];
    if isinstance(a.type, ir.IntType) and isinstance(v.type, ir.IntType) {
        cmp = b.icmp_signed(">", a, v, name="max.cmp");
        return b.select(cmp, a, v, name="max.result");
    }
    if isinstance(a.type, ir.DoubleType) and isinstance(v.type, ir.DoubleType) {
        cmp = b.fcmp_ordered(">", a, v, name="max.fcmp");
        return b.select(cmp, a, v, name="max.fresult");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_sum(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    list_val = args[0];

    helpers: (dict[str, any] | None) = None;
    elem_key: (str | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            elem_key = lk;
            break;
        }
    }
    if helpers is None {
        return None;
    }
    list_len = b.call(helpers["len"], [list_val], name="sum.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="sum.loop");
    body_bb = func.append_basic_block(name="sum.body");
    done_bb = func.append_basic_block(name="sum.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="sum.idx");
    acc = b.phi(i64, name="sum.acc");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    acc.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="sum.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [list_val, idx], name="sum.elem");
    new_acc = b.add(acc, elem, name="sum.add");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="sum.next");
    idx.add_incoming(next_idx, body_bb);
    acc.add_incoming(new_acc, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return acc;
}

impl NativeBuiltinEmitter.emit_sorted(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    list_val = args[0];

    helpers: (dict[str, any] | None) = None;
    elem_key: (str | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            elem_key = lk;
            break;
        }
    }
    if helpers is None {
        return None;
    }
    _le = p._native_emitters.get("list") if p?._native_emitters else None;
    if not isinstance(_le, NativeListEmitter) {
        return None;
    }
    _ctx2 = ctx.__class__(
        pass_ref=p,
        type_key=elem_key or "",
        call_kwargs=(ctx?.call_kwargs or {}),
        arg_nodes=ctx.arg_nodes,
        call_node=ctx.call_node
    );

    sorted_copy = _le.emit_copy(_ctx2, list_val, []);
    if sorted_copy is None {
        return None;
    }
    if _le.emit_sort(_ctx2, sorted_copy, []) is None and (ctx?.call_kwargs or {}) {
        return None;
    }
    return sorted_copy;
}

impl NativeBuiltinEmitter.emit_reversed(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    list_val = args[0];

    helpers: (dict[str, any] | None) = None;
    elem_key: (str | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            elem_key = lk;
            break;
        }
    }
    if helpers is None {
        return None;
    }
    _le = p._native_emitters.get("list") if p?._native_emitters else None;
    if not isinstance(_le, NativeListEmitter) {
        return None;
    }
    _ctx2 = ctx.__class__(pass_ref=p, type_key=elem_key or "");

    rev_copy = _le.emit_copy(_ctx2, list_val, []);
    if rev_copy is None {
        return None;
    }
    _le.emit_reverse(_ctx2, rev_copy, []);
    return rev_copy;
}

impl NativeBuiltinEmitter.emit_enumerate(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_zip(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_map(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_filter(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_any(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    list_val = args[0];
    helpers: (dict[str, any] | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            break;
        }
    }
    if helpers is None {
        return None;
    }
    list_len = b.call(helpers["len"], [list_val], name="any.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="any.loop");
    body_bb = func.append_basic_block(name="any.body");
    found_bb = func.append_basic_block(name="any.found");
    done_bb = func.append_basic_block(name="any.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="any.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="any.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [list_val, idx], name="any.elem");
    is_true = p._to_bool(elem);
    if not (isinstance(is_true.type, ir.IntType) and is_true.type.width == 1) {
        return None;
    }
    body_end = b.basic_block;
    next_idx = b.add(idx, ir.Constant(i64, 1), name="any.next");
    idx.add_incoming(next_idx, body_end);
    b.cbranch(is_true, found_bb, loop_bb);
    b.position_at_start(found_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="any.result");
    result.add_incoming(ir.Constant(i64, 0), loop_bb);
    result.add_incoming(ir.Constant(i64, 1), found_bb);
    return result;
}

impl NativeBuiltinEmitter.emit_all(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    list_val = args[0];
    helpers: (dict[str, any] | None) = None;
    for (lk, lt) in p.list_types.items() {
        if list_val.type == lt.as_pointer() {
            helpers = p.list_helpers.get(lk);
            break;
        }
    }
    if helpers is None {
        return None;
    }
    list_len = b.call(helpers["len"], [list_val], name="all.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="all.loop");
    body_bb = func.append_basic_block(name="all.body");
    false_bb = func.append_basic_block(name="all.false");
    done_bb = func.append_basic_block(name="all.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="all.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="all.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [list_val, idx], name="all.elem");
    is_true = p._to_bool(elem);
    if not (isinstance(is_true.type, ir.IntType) and is_true.type.width == 1) {
        return None;
    }
    body_end = b.basic_block;
    next_idx = b.add(idx, ir.Constant(i64, 1), name="all.next");
    idx.add_incoming(next_idx, body_end);
    b.cbranch(is_true, loop_bb, false_bb);
    b.position_at_start(false_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="all.result");
    result.add_incoming(ir.Constant(i64, 1), loop_bb);
    result.add_incoming(ir.Constant(i64, 0), false_bb);
    return result;
}

impl NativeBuiltinEmitter.emit_isinstance(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_divmod(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    a = args[0];
    v = args[1];
    if isinstance(a.type, ir.IntType) and isinstance(v.type, ir.IntType) {
        izero = ir.Constant(i64, 0);
        is_zero = b.icmp_signed("==", v, izero, name="divmod.zero.chk");
        p._emit_runtime_raise(
            is_zero, "ZeroDivisionError", "integer division or modulo by zero"
        );
        (quot, rem) = p._codegen_int_floor_divmod(a, v);

        tuple_type = ir.LiteralStructType([i64, i64]);
        null_ptr = ir.Constant(tuple_type.as_pointer(), None);
        size_gep = b.gep(
            null_ptr, [ir.Constant(ir.IntType(32), 1)], name="divmod.sizeof.gep"
        );
        size = b.ptrtoint(size_gep, i64, name="divmod.sizeof");
        raw_ptr = b.call(p.rc_alloc_fn, [size], name="divmod.alloc");
        tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="divmod.ptr");

        q_ptr = b.gep(
            tuple_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 0)],
            name="divmod.q.ptr"
        );
        r_ptr = b.gep(
            tuple_ptr,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), 1)],
            name="divmod.r.ptr"
        );
        b.store(quot, q_ptr);
        b.store(rem, r_ptr);

        tkey = f"Tuple.2.i64.i64";
        if tkey not in p.tuple_types {
            p.tuple_types[tkey] = tuple_type;
        }
        return tuple_ptr;
    }
    return None;
}

impl NativeBuiltinEmitter.emit_iter(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_next(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_callable(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_getattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_setattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_hasattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_delattr(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_vars(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_dir(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_open(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_format(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    arg_val = args[0];
    spec_val = args[1];
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    rc_alloc_fn = p.rc_alloc_fn;
    snprintf = p._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, i64, i8p], var_arg=True
    );

    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    spec_len = p._call_str_len(b, spec_val, name="fmt.speclen");

    fmt_size = b.add(spec_len, ir.Constant(i64, 2), name="fmt.fmtsz");
    fmt_buf = b.call(rc_alloc_fn, [fmt_size], name="fmt.fmtbuf");

    b.store(ir.Constant(ir.IntType(8), 37), fmt_buf);

    fmt_rest = b.gep(fmt_buf, [ir.Constant(i64, 1)], name="fmt.rest");
    copy_len = b.add(spec_len, ir.Constant(i64, 1), name="fmt.copylen");
    b.call(memcpy_fn, [fmt_rest, spec_val, copy_len]);

    if isinstance(arg_val.type, ir.IntType) and arg_val.type.width == 1 {
        arg_val = b.zext(arg_val, i64, name="fmt.arg.zext");
    } elif isinstance(arg_val.type, ir.IntType) and arg_val.type.width != 64 {
        arg_val = b.sext(arg_val, i64, name="fmt.arg.sext");
    }
    need32 = b.call(
        snprintf,
        [ir.Constant(i8p, None), ir.Constant(i64, 0), fmt_buf, arg_val],
        name="fmt.need"
    );
    need = b.sext(need32, i64, name="fmt.need64");
    buf_size = b.add(need, ir.Constant(i64, 1), name="fmt.size");
    buf_ptr = p._str_alloc(b, buf_size, name="fmt.buf");
    b.call(snprintf, [buf_ptr, buf_size, fmt_buf, arg_val]);
    p._str_finish(b, buf_ptr, need);
    p._emit_rc_release_simple(fmt_buf, op="fmt_tmp", loc="");
    return buf_ptr;
}

impl NativeBuiltinEmitter.emit_ascii(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return self.emit_repr(ctx, args);
}

impl NativeBuiltinEmitter.emit_str(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();

    if p._is_bytes_value(arg_val) {
        return p._emit_bytes_repr(arg_val);
    }

    if isinstance(arg_val.type, ir.IntType) and arg_val.type.width == 1 {
        true_s = p._make_global_string("True", name_prefix=".str.true");
        false_s = p._make_global_string("False", name_prefix=".str.false");
        return b.select(arg_val, true_s, false_s, name="str.bool");
    }

    if isinstance(arg_val.type, ir.PointerType) {
        if arg_val.type != i8p {
            obj_s = p._emit_obj_str(arg_val);
            if obj_s is not None {
                return obj_s;
            }
            cont_s = p._emit_container_repr(arg_val, ctx.type_key or None);
            if cont_s is not None {
                return cont_s;
            }
            identity = b.bitcast(arg_val, i8p, name="str.identity");
            p._emit_rc_retain(identity, op="builtin_str_id");
            return identity;
        }

        none_s = p._make_global_string("None", name_prefix=".str.none");
        is_null = b.icmp_unsigned(
            "==", arg_val, ir.Constant(i8p, None), name="str.isnone"
        );
        result = b.select(is_null, none_s, arg_val, name="str.ornone");
        p._emit_rc_retain(result, op="builtin_str_id");
        return result;
    }

    if isinstance(arg_val.type, ir.DoubleType) {
        return p._emit_float_repr(arg_val);
    }

    if p?.jacval_type and arg_val.type == p.jacval_type {
        _jv_fn = p._str_jacval_fn();
        if _jv_fn is not None {
            return b.call(_jv_fn, [arg_val], name="str.jacval");
        }
    }
    if isinstance(arg_val.type, ir.LiteralStructType) {
        cont_s = p._emit_container_repr(arg_val, ctx.type_key or None);
        if cont_s is not None {
            return cont_s;
        }
    }
    buf_ptr = p._str_alloc(b, ir.Constant(ir.IntType(64), 32), name="str.buf");
    snprintf = p._get_or_declare_extern(
        "snprintf", ir.IntType(32), [i8p, ir.IntType(64), i8p], var_arg=True
    );

    unsigned = bool(ctx.arg_nodes) and p._is_unsigned_node(ctx.arg_nodes[0]);
    if isinstance(arg_val.type, ir.IntType) and arg_val.type.width < 64 {
        arg_val = b.zext(arg_val, ir.IntType(64))
            if unsigned
            else b.sext(arg_val, ir.IntType(64));
    }
    fmt = p._get_snprintf_fmt("%llu" if unsigned else "%lld");
    fmt_ptr = b.bitcast(fmt, i8p, name="str.fmt.ptr");
    str_n32 = b.call(
        snprintf,
        [buf_ptr, ir.Constant(ir.IntType(64), 32), fmt_ptr, arg_val],
        name="str.snprintf"
    );
    p._str_finish(b, buf_ptr, b.sext(str_n32, ir.IntType(64), name="str.len64"));
    return buf_ptr;
}

impl NativeBuiltinEmitter.emit_int(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);

    if isinstance(arg_val.type, ir.IntType) {
        if arg_val.type.width == 64 {
            return arg_val;
        }
        _src_node = ctx.arg_nodes[0] if ctx.arg_nodes else None;
        if arg_val.type.width > 1 and not p._is_unsigned_node(_src_node) {
            return b.sext(arg_val, i64, name="int.from.int");
        }
        return b.zext(arg_val, i64, name="int.from.int");
    }

    if isinstance(arg_val.type, ir.FloatType) {
        arg_val = b.fpext(arg_val, ir.DoubleType(), name="int.from.f32");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        return b.fptosi(arg_val, i64, name="int.from.float");
    }

    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    strtol_fn = p._get_or_declare_extern("strtol", i64, [i8p, i8p.as_pointer(), i32]);
    endptr_alloca = b.alloca(i8p, name="endptr");
    result_val = b.call(
        strtol_fn, [arg_val, endptr_alloca, ir.Constant(i32, 10)], name="strtol.result"
    );
    endptr_val = b.load(endptr_alloca, name="endptr.val");
    no_parse = b.icmp_unsigned("==", endptr_val, arg_val, name="int.noparse");
    p._emit_runtime_raise(no_parse, "ValueError", "invalid literal for int()");
    end_char = b.load(endptr_val, name="end.char");
    has_trail = b.icmp_unsigned(
        "!=", end_char, ir.Constant(ir.IntType(8), 0), name="int.trail"
    );
    p._emit_runtime_raise(has_trail, "ValueError", "invalid literal for int()");
    return result_val;
}

impl NativeBuiltinEmitter.emit_float(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);

    if isinstance(arg_val.type, ir.PointerType) {
        strtod_fn = p._get_or_declare_extern(
            "strtod", ir.DoubleType(), [i8p, i8p.as_pointer()]
        );
        endptr_alloca = b.alloca(i8p, name="float.endptr");
        result = b.call(strtod_fn, [arg_val, endptr_alloca], name="float.result");
        endptr_val = b.load(endptr_alloca, name="float.endptr.val");
        no_parse = b.icmp_unsigned("==", endptr_val, arg_val, name="float.noparse");
        p._emit_runtime_raise(
            no_parse, "ValueError", "could not convert string to float"
        );
        return result;
    }

    if isinstance(arg_val.type, ir.IntType) {
        _src_node = ctx.arg_nodes[0] if ctx.arg_nodes else None;
        if arg_val.type.width == 1 or p._is_unsigned_node(_src_node) {
            return b.uitofp(arg_val, ir.DoubleType(), name="float.from.uint");
        }
        return b.sitofp(arg_val, ir.DoubleType(), name="float.from.int");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        return arg_val;
    }
    if isinstance(arg_val.type, ir.FloatType) {
        return b.fpext(arg_val, ir.DoubleType(), name="float.from.f32");
    }
    return None;
}

impl NativeBuiltinEmitter.emit_bool(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    arg_val = args[0];
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    if isinstance(arg_val.type, ir.IntType) {
        is_nonzero = b.icmp_signed("!=", arg_val, ir.Constant(i64, 0), name="bool.nz");
        return b.zext(is_nonzero, i64, name="bool.result");
    }
    if isinstance(arg_val.type, ir.DoubleType) {
        is_nonzero = b.fcmp_ordered(
            "!=", arg_val, ir.Constant(ir.DoubleType(), 0.0), name="bool.fnz"
        );
        return b.zext(is_nonzero, i64, name="bool.fresult");
    }
    if isinstance(arg_val.type, ir.PointerType) {
        i8p = ir.IntType(8).as_pointer();
        if arg_val.type == i8p {
            slen = p._call_str_len(b, arg_val, name="bool.slen");
            is_nonempty = b.icmp_unsigned(
                "!=", slen, ir.Constant(i64, 0), name="bool.nonempty"
            );
            return b.zext(is_nonempty, i64, name="bool.sresult");
        }

        if p._is_bytes_value(arg_val) {
            return b.zext(p._emit_bytes_truthy(arg_val), i64, name="bool.byresult");
        }
    }

    return b.zext(p._to_bool(arg_val), i64, name="bool.result");
}

impl NativeBuiltinEmitter.emit_list(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    val = args[0];
    _opt_pl = p._opt_payload_of(val.type);
    if _opt_pl is not None {
        val = b.extract_value(val, 1, name="l.opt.payload");
    }

    source = ctx.arg_nodes[0] if ctx.arg_nodes else None;
    if p._tuple_iter_shape(source, val) {
        sequence = p._tuple_iter_seq(
            source,
            val,
            consume_source=False,
            element_type=p._list_elem_llvm_of(ctx.call_node),
            own_elements=True
        );
        if sequence is None {
            return None;
        }
        result = sequence[0];
        if ctx.call_node is not None and not p._container_is_view(ctx.call_node) {
            p._nogc_stamp_elem_drops(result, p._nogc_type_arg_mangles(ctx.call_node));
        }
        return result;
    }

    if p._jac_iter_type is not None
        and val.type == p._jac_iter_type.as_pointer()
        and ctx.arg_nodes {
        elem_type = p._iter_elem_llvm_of(ctx.arg_nodes[0]);
        if elem_type is None {
            return None;
        }
        list_type = p._lower_list_for_elem(elem_type);
        spec = p._spec_from_container_ptr(list_type);
        if spec is None {
            return None;
        }
        helpers = p.list_helpers.get(spec);
        if helpers is None {
            return None;
        }
        slot_type = ir.IntType(8).as_pointer()
            if elem_type == p._str_desc_ty
            else elem_type;
        slot = p._entry_alloca(slot_type, "list.iter.element");
        result = b.call(helpers["new"], [], name="list.iter.result");
        func = b.basic_block.function;
        condition = func.append_basic_block("list.iter.next");
        body = func.append_basic_block("list.iter.append");
        done = func.append_basic_block("list.iter.done");
        b.branch(condition);
        b.position_at_end(condition);
        available = p._emit_iter_advance(b, val, slot);
        b.cbranch(available, body, done);
        b.position_at_end(body);
        stored_type = helpers["elem_type"];
        assert isinstance(stored_type, ir.Type);
        element = p._coerce_type(b.load(slot), stored_type);
        b.call(helpers["append"], [result, element]);
        b.branch(condition);
        b.position_at_end(done);
        return result;
    }

    for (sk, shelpers) in p.set_helpers.items() {
        stype = p.set_types.get(sk);
        if stype is not None and val.type == stype.as_pointer() {
            p._emit_list_helpers(sk, shelpers["elem_type"]);
            lhelpers = p.list_helpers.get(sk);
            if lhelpers is None {
                return None;
            }
            new_list = b.call(lhelpers["new"], [], name="l2l.new");
            set_len = b.call(shelpers["len"], [val], name="l2l.slen");
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="l2l.loop");
            body_bb = func.append_basic_block(name="l2l.body");
            done_bb = func.append_basic_block(name="l2l.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            idx = b.phi(i64, name="l2l.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = b.icmp_unsigned(">=", idx, set_len, name="l2l.end");
            b.cbranch(at_end, done_bb, body_bb);
            b.position_at_start(body_bb);
            elem = b.call(shelpers["get"], [val, idx], name="l2l.elem");
            b.call(lhelpers["append"], [new_list, elem]);
            nidx = b.add(idx, ir.Constant(i64, 1), name="l2l.nidx");
            idx.add_incoming(nidx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return new_list;
        }
    }

    for (lk, lhelpers) in p.list_helpers.items() {
        ltype = p.list_types.get(lk);
        if ltype is not None and val.type == ltype.as_pointer() {
            _le = p?._native_emitters?.get("list");
            if not isinstance(_le, NativeListEmitter) {
                return None;
            }
            _ctx2 = ctx.__class__(pass_ref=p, type_key=lk);
            return _le.emit_copy(_ctx2, val, []);
        }
    }
    _vp_nm = getattr(val.type.pointee, "name", "")
        if isinstance(val.type, ir.PointerType)
        else "";
    if isinstance(_vp_nm, str) and _vp_nm.startswith("List.") {
        p._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
        _lt_ptr = p.list_types.get("ptr");
        _le3 = p?._native_emitters?.get("list");
        if _lt_ptr is not None and isinstance(_le3, NativeListEmitter) {
            _lv = b.bitcast(val, _lt_ptr.as_pointer(), name="l.union.cast");
            _ctx3 = ctx.__class__(pass_ref=p, type_key="ptr");
            return _le3.emit_copy(_ctx3, _lv, []);
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_dict(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    if not args {
        p._emit_dict_helpers(
            "ptr", "i64", ir.IntType(8).as_pointer(), ir.IntType(64), 0
        );
        helpers = p.dict_helpers.get("ptr:i64");
        if helpers is None {
            return None;
        }
        return b.call(helpers["new"], [], name="dctor.new");
    }

    val = args[0];
    for (dk, dhelpers) in p.dict_helpers.items() {
        dtype = p.dict_types.get(dk);
        if dtype is not None and val.type == dtype.as_pointer() {
            _de = p?._native_emitters?.get("dict");
            if not isinstance(_de, NativeDictEmitter) {
                return None;
            }
            _ctx2 = ctx.__class__(pass_ref=p, type_key=dk);
            return _de.emit_copy(_ctx2, val, []);
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_set(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    val = args[0];

    for (lk, lhelpers) in p.list_helpers.items() {
        ltype = p.list_types.get(lk);
        if ltype is not None and val.type == ltype.as_pointer() {
            elem_type = p._list_elem_llvm_of(ctx.arg_nodes[0])
                if ctx.arg_nodes
                else None;
            if elem_type is None {
                elem_type = lhelpers["elem_type"];
            }
            if p._str_desc_ty is not None and elem_type == p._str_desc_ty {
                elem_type = ir.IntType(8).as_pointer();
            }
            if p.jacval_type is not None and elem_type == p.jacval_type {
                return None;
            }
            (key_spec, key_size) = p._hash_key_spec(elem_type);
            p._emit_set_helpers(key_spec, elem_type, key_size);
            shelpers = p.set_helpers.get(key_spec);
            if shelpers is None {
                return None;
            }
            new_set = b.call(shelpers["new"], [], name="l2s.new");
            list_len = b.call(lhelpers["len"], [val], name="l2s.llen");
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="l2s.loop");
            body_bb = func.append_basic_block(name="l2s.body");
            done_bb = func.append_basic_block(name="l2s.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            idx = b.phi(i64, name="l2s.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = b.icmp_unsigned(">=", idx, list_len, name="l2s.end");
            b.cbranch(at_end, done_bb, body_bb);
            b.position_at_start(body_bb);
            elem: ir.Value = b.call(lhelpers["get"], [val, idx], name="l2s.elem");
            elem = p._cast_to_list_elem(b, elem, elem_type, "l2s.key");
            b.call(shelpers["add"], [new_set, elem]);
            nidx = b.add(idx, ir.Constant(i64, 1), name="l2s.nidx");
            idx.add_incoming(nidx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return new_set;
        }
    }

    for (sk, shelpers) in p.set_helpers.items() {
        stype = p.set_types.get(sk);
        if stype is not None and val.type == stype.as_pointer() {
            _se = p?._native_emitters?.get("set");
            if not isinstance(_se, NativeSetEmitter) {
                return None;
            }
            _ctx2 = ctx.__class__(pass_ref=p, type_key=sk);
            return _se.emit_copy(_ctx2, val, []);
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_tuple(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBuiltinEmitter.emit_frozenset(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return self.emit_set(ctx, args);
}

impl NativeBuiltinEmitter.emit_bytes(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    val = args[0];
    if ("u8" in p.list_types and val.type == p.list_types["u8"].as_pointer()) {
        _src = p._bytearray_src_of(val);
        if _src is not None {
            return p._bytes_from_raw(_src[0], _src[1]);
        }
    }
    for (lk, lhelpers) in p.list_helpers.items() {
        ltype = p.list_types.get(lk);
        if ltype is not None and val.type == ltype.as_pointer() {
            list_len = b.call(lhelpers["len"], [val], name="bytes.len");
            bv = p._bytes_alloc(list_len);
            data = p._bytes_data_ptr(bv);
            func = b.basic_block.function;
            entry_bb = b.basic_block;
            loop_bb = func.append_basic_block(name="bytes.loop");
            body_bb = func.append_basic_block(name="bytes.body");
            done_bb = func.append_basic_block(name="bytes.done");
            b.branch(loop_bb);
            b.position_at_start(loop_bb);
            idx = b.phi(i64, name="bytes.idx");
            idx.add_incoming(ir.Constant(i64, 0), entry_bb);
            at_end = b.icmp_unsigned(">=", idx, list_len, name="bytes.end");
            b.cbranch(at_end, done_bb, body_bb);
            b.position_at_start(body_bb);
            elem = b.call(lhelpers["get"], [val, idx], name="bytes.elem");
            byte_val = b.trunc(elem, i8, name="bytes.trunc");
            bp = b.gep(data, [idx], name="bytes.bp");
            b.store(byte_val, bp);
            nidx = b.add(idx, ir.Constant(i64, 1), name="bytes.nidx");
            idx.add_incoming(nidx, body_bb);
            b.branch(loop_bb);
            b.position_at_start(done_bb);
            return bv;
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_bytearray(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    p._ensure_bytearray_type();
    fns = p._bytearray_runtime_fns();
    buf = p._rc_call_with_ctx(
        p.list_helpers["u8"]["new"], [], op="new", loc="", name="ba.new"
    );
    if not args {
        return buf;
    }
    a0 = args[0];
    if isinstance(a0.type, ir.IntType) {
        n = p._coerce_type(a0, i64);
        b.call(fns["reserve"], [buf, n], name="");
        data_p = b.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="ba.z.data.p"
        );
        data = b.load(data_p, name="ba.z.data");
        b.call(fns["memset"], [data, ir.Constant(i32, 0), n], name="");
        len_p = b.gep(
            buf, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ba.z.len.p"
        );
        b.store(n, len_p);
        return buf;
    }
    src = p._bytearray_src_of(a0);
    if src is not None {
        b.call(fns["extend_raw"], [buf, src[0], src[1]], name="");
        return buf;
    }

    _bv = self.emit_bytes(ctx, [a0]);
    if _bv is not None and p._is_bytes_value(_bv) {
        _bsrc = p._bytearray_src_of(_bv);
        if _bsrc is not None {
            b.call(fns["extend_raw"], [buf, _bsrc[0], _bsrc[1]], name="");
            p._emit_rc_release_simple(_bv, op="ba_ctor_list", loc="");
            return buf;
        }
    }
    return None;
}

impl NativeBuiltinEmitter.emit_complex(
    self: NativeBuiltinEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}
