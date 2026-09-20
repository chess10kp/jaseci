impl NativeIntEmitter.emit_to_bytes(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero64 = ir.Constant(i64, 0);
    one64 = ir.Constant(i64, 1);
    eight64 = ir.Constant(i64, 8);
    mask_ff = ir.Constant(i64, 0xFF);
    length = p._coerce_type(args[0], i64);
    byteorder = args[1];

    bv = p._bytes_alloc(length);
    buf = p._bytes_data_ptr(bv);

    big_str = p._make_global_string("big");
    cmp_res = p._call_str_cmp(b, byteorder, big_str, name="tb.cmp");
    is_big = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="tb.isbig");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="tb.loop");
    body_bb = func.append_basic_block(name="tb.body");
    done_bb = func.append_basic_block(name="tb.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="tb.idx");
    idx.add_incoming(zero64, entry_bb);
    at_end = b.icmp_unsigned(">=", idx, length, name="tb.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);

    shift_amt = b.mul(idx, eight64, name="tb.shift");
    shifted = b.lshr(target, shift_amt, name="tb.shifted");
    byte_val = b.and_(shifted, mask_ff, name="tb.byte");
    byte_i8 = b.trunc(byte_val, i8, name="tb.i8");

    big_pos = b.sub(b.sub(length, one64, name="tb.lm1"), idx, name="tb.bigpos");
    store_pos = b.select(is_big, big_pos, idx, name="tb.pos");
    byte_ptr = b.gep(buf, [store_pos], name="tb.ptr");
    b.store(byte_i8, byte_ptr);
    next_idx = b.add(idx, one64, name="tb.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return bv;
}

impl NativeIntEmitter.emit_as_integer_ratio(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    one = ir.Constant(i64, 1);
    tuple_type = ir.LiteralStructType([i64, i64]);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="iair.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="iair.sizeof");
    p._set_rc_ctx("as_integer_ratio", "");
    raw_ptr = b.call(p.rc_alloc_fn, [size], name="iair.alloc");
    p._clear_rc_ctx();
    tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="iair.ptr");
    n_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="iair.n.ptr"
    );
    d_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="iair.d.ptr"
    );
    b.store(target, n_ptr);
    b.store(one, d_ptr);
    tkey = "i64.i64";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }
    return tuple_ptr;
}

impl NativeIntEmitter.emit_bit_length(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);

    is_neg = b.icmp_signed("<", target, zero, name="bitlen.neg");
    neg_val = b.sub(zero, target, name="bitlen.abs");
    abs_val = b.select(is_neg, neg_val, target, name="bitlen.absv");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="bitlen.loop");
    body_bb = func.append_basic_block(name="bitlen.body");
    done_bb = func.append_basic_block(name="bitlen.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    val = b.phi(i64, name="bitlen.val");
    count = b.phi(i64, name="bitlen.count");
    val.add_incoming(abs_val, entry_bb);
    count.add_incoming(zero, entry_bb);
    is_zero = b.icmp_unsigned("==", val, zero, name="bitlen.iszero");
    b.cbranch(is_zero, done_bb, body_bb);
    b.position_at_start(body_bb);
    new_val = b.lshr(val, one, name="bitlen.shr");
    new_count = b.add(count, one, name="bitlen.inc");
    val.add_incoming(new_val, body_bb);
    count.add_incoming(new_count, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return count;
}

impl NativeIntEmitter.emit_bit_count(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);

    is_neg = b.icmp_signed("<", target, zero, name="bitcnt.neg");
    neg_val = b.sub(zero, target, name="bitcnt.abs");
    abs_val = b.select(is_neg, neg_val, target, name="bitcnt.absv");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="bitcnt.loop");
    body_bb = func.append_basic_block(name="bitcnt.body");
    done_bb = func.append_basic_block(name="bitcnt.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    val = b.phi(i64, name="bitcnt.val");
    count = b.phi(i64, name="bitcnt.count");
    val.add_incoming(abs_val, entry_bb);
    count.add_incoming(zero, entry_bb);
    is_zero = b.icmp_unsigned("==", val, zero, name="bitcnt.iszero");
    b.cbranch(is_zero, done_bb, body_bb);
    b.position_at_start(body_bb);
    bit = b.and_(val, one, name="bitcnt.bit");
    new_count = b.add(count, bit, name="bitcnt.inc");
    new_val = b.lshr(val, one, name="bitcnt.shr");
    val.add_incoming(new_val, body_bb);
    count.add_incoming(new_count, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return count;
}

impl NativeIntEmitter.emit_conjugate(
    self: NativeIntEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return target;
}

impl NativeIntEmitter.emit_from_bytes(
    self: NativeIntEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero64 = ir.Constant(i64, 0);
    one64 = ir.Constant(i64, 1);
    eight64 = ir.Constant(i64, 8);
    bytes_obj = args[0];
    byteorder = args[1];

    if p._is_bytes_value(bytes_obj) {
        length = p._bytes_len_val(bytes_obj);
        bytes_ptr = p._bytes_data_ptr(bytes_obj);
    } else {
        length = p._call_str_len(b, bytes_obj, name="fb.len");
        bytes_ptr = bytes_obj;
    }

    big_str = p._make_global_string("big");
    cmp_res = p._call_str_cmp(b, byteorder, big_str, name="fb.cmp");
    is_big = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="fb.isbig");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="fb.loop");
    body_bb = func.append_basic_block(name="fb.body");
    done_bb = func.append_basic_block(name="fb.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="fb.idx");
    result = b.phi(i64, name="fb.result");
    idx.add_incoming(zero64, entry_bb);
    result.add_incoming(zero64, entry_bb);
    at_end = b.icmp_unsigned(">=", idx, length, name="fb.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);

    byte_ptr = b.gep(bytes_ptr, [idx], name="fb.bptr");
    byte_val = b.load(byte_ptr, name="fb.byte");
    byte_i64 = b.zext(byte_val, i64, name="fb.ext");

    big_shift_idx = b.sub(b.sub(length, one64, name="fb.lm1"), idx, name="fb.bidx");
    shift_idx = b.select(is_big, big_shift_idx, idx, name="fb.sidx");
    shift_amt = b.mul(shift_idx, eight64, name="fb.shift");
    shifted = b.shl(byte_i64, shift_amt, name="fb.shifted");
    new_result = b.or_(result, shifted, name="fb.accum");
    next_idx = b.add(idx, one64, name="fb.next");
    idx.add_incoming(next_idx, body_bb);
    result.add_incoming(new_result, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return result;
}

impl NativeFloatEmitter.emit_is_integer(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    assert b is not None , "Builder should be set in pass_ref";

    truncated = b.fptosi(target, i64, name="isint.trunc");
    roundtripped = b.sitofp(truncated, ir.DoubleType(), name="isint.rt");
    is_eq = b.fcmp_ordered("==", target, roundtripped, name="isint.eq");
    return b.zext(is_eq, i64, name="isint.result");
}

impl NativeFloatEmitter.emit_as_integer_ratio(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    f64 = ir.DoubleType();
    func = b.basic_block.function;

    floor_fn = p._get_or_declare_extern("floor", f64, [f64]);

    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="fair.loop");
    body_bb = func.append_basic_block(name="fair.body");
    done_bb = func.append_basic_block(name="fair.done");
    two = ir.Constant(f64, 2.0);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    num_phi = b.phi(f64, name="fair.num");
    den_phi = b.phi(i64, name="fair.den");
    num_phi.add_incoming(target, entry_bb);
    den_phi.add_incoming(ir.Constant(i64, 1), entry_bb);
    floored = b.call(floor_fn, [num_phi], name="fair.floor");
    is_int = b.fcmp_ordered("==", num_phi, floored, name="fair.isint");
    b.cbranch(is_int, done_bb, body_bb);
    b.position_at_start(body_bb);
    new_num = b.fmul(num_phi, two, name="fair.num2");
    new_den = b.mul(den_phi, ir.Constant(i64, 2), name="fair.den2");
    num_phi.add_incoming(new_num, body_bb);
    den_phi.add_incoming(new_den, body_bb);
    b.branch(loop_bb);

    b.position_at_start(done_bb);
    numer = b.fptosi(num_phi, i64, name="fair.numer");
    tuple_type = ir.LiteralStructType([i64, i64]);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="fair.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="fair.sizeof");
    p._set_rc_ctx("as_integer_ratio", "");
    raw_ptr = b.call(p.rc_alloc_fn, [size], name="fair.alloc");
    p._clear_rc_ctx();
    tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="fair.ptr");
    n_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="fair.n.ptr"
    );
    d_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="fair.d.ptr"
    );
    b.store(numer, n_ptr);
    b.store(den_phi, d_ptr);
    tkey = "i64.i64";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }
    return tuple_ptr;
}

impl NativeFloatEmitter.emit_conjugate(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return target;
}

impl NativeFloatEmitter.emit_hex(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    buf_size = ir.Constant(i64, 64);
    p._set_rc_ctx("float_hex", "");
    buf = p._str_alloc(b, buf_size, name="fhex.buf");
    p._clear_rc_ctx();
    fmt = p._make_global_string("%a");
    snprintf = p._get_or_declare_extern("snprintf", i32, [i8p, i64, i8p], var_arg=True);
    fhex_n32 = b.call(snprintf, [buf, buf_size, fmt, target], name="fhex.len");
    p._str_finish(b, buf, b.sext(fhex_n32, i64, name="fhex.len64"));
    return buf;
}

impl NativeFloatEmitter.emit_fromhex(
    self: NativeFloatEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    f64 = ir.DoubleType();
    i8p = ir.IntType(8).as_pointer();
    strtod_fn = p._get_or_declare_extern("strtod", f64, [i8p, i8p.as_pointer()]);
    null_ptr = ir.Constant(i8p.as_pointer(), None);
    result = b.call(strtod_fn, [args[0], null_ptr], name="fhex.result");
    return result;
}

impl NativeBoolEmitter.emit_op_and(
    self: NativeBoolEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i1 = ir.IntType(1);
    lhs = p._coerce_type(target, i1) if target.type != i1 else target;
    rhs = p._coerce_type(args[0], i1) if args[0].type != i1 else args[0];
    return b.and_(lhs, rhs, name="bool.and");
}

impl NativeBoolEmitter.emit_op_or(
    self: NativeBoolEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i1 = ir.IntType(1);
    lhs = p._coerce_type(target, i1) if target.type != i1 else target;
    rhs = p._coerce_type(args[0], i1) if args[0].type != i1 else args[0];
    return b.or_(lhs, rhs, name="bool.or");
}

impl NativeBoolEmitter.emit_op_xor(
    self: NativeBoolEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i1 = ir.IntType(1);
    lhs = p._coerce_type(target, i1) if target.type != i1 else target;
    rhs = p._coerce_type(args[0], i1) if args[0].type != i1 else args[0];
    return b.xor(lhs, rhs, name="bool.xor");
}

impl NativeComplexEmitter._load_parts(
    self: NativeComplexEmitter, ctx: NativeEmitCtx, val: ir.Value
) -> (tuple[ir.Value, ir.Value] | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    r = b.load(b.gep(val, [z0, z0], name="cx.rp"), name="cx.r");
    im = b.load(b.gep(val, [z0, z1], name="cx.ip"), name="cx.i");
    return (r, im);
}

impl NativeComplexEmitter._make_complex(
    self: NativeComplexEmitter, ctx: NativeEmitCtx, real: ir.Value, imag: ir.Value
) -> ir.Value {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    ctype = p.complex_struct_type;
    p._set_rc_ctx("complex_new", "");
    raw = b.call(p.rc_alloc_fn, [ir.Constant(i64, 16)], name="cx.raw");
    p._clear_rc_ctx();
    ptr = b.bitcast(raw, ctype.as_pointer(), name="cx.ptr");
    b.store(real, b.gep(ptr, [z0, z0], name="cx.srp"));
    b.store(imag, b.gep(ptr, [z0, z1], name="cx.sip"));
    return ptr;
}

impl NativeComplexEmitter.emit_conjugate(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    parts = self._load_parts(ctx, target);
    if parts is None {
        return None;
    }
    (r, im) = parts;
    ni = ctx.pass_ref.builder.fneg(im, name="conj.ni");
    return self._make_complex(ctx, r, ni);
}

impl NativeComplexEmitter.emit_op_add(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_sub(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_mul(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_truediv(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_pow(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_eq(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_ne(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_neg(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeComplexEmitter.emit_op_pos(
    self: NativeComplexEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeRangeEmitter._load_range(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value
) -> (tuple[ir.Value, ir.Value, ir.Value] | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    z0 = ir.Constant(i32, 0);
    start = b.load(
        b.gep(target, [z0, ir.Constant(i32, 0)], name="rng.sp"), name="rng.start"
    );
    stop = b.load(
        b.gep(target, [z0, ir.Constant(i32, 1)], name="rng.ep"), name="rng.stop"
    );
    step = b.load(
        b.gep(target, [z0, ir.Constant(i32, 2)], name="rng.tp"), name="rng.step"
    );
    return (start, stop, step);
}

impl NativeRangeEmitter._in_range(
    self: NativeRangeEmitter,
    ctx: NativeEmitCtx,
    val: ir.Value,
    start: ir.Value,
    stop: ir.Value,
    step: ir.Value
) -> ir.Value {
    b = ctx.pass_ref.builder;
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    diff = b.sub(val, start, name="rin.diff");
    rem = b.srem(diff, step, name="rin.rem");
    rem_zero = b.icmp_signed("==", rem, ir.Constant(i64, 0), name="rin.remz");
    step_pos = b.icmp_signed(">", step, ir.Constant(i64, 0), name="rin.spos");
    ge_start = b.icmp_signed(">=", val, start, name="rin.ges");
    lt_stop = b.icmp_signed("<", val, stop, name="rin.lts");
    pos_ok = b.and_(ge_start, lt_stop, name="rin.pok");
    le_start = b.icmp_signed("<=", val, start, name="rin.les");
    gt_stop = b.icmp_signed(">", val, stop, name="rin.gts");
    neg_ok = b.and_(le_start, gt_stop, name="rin.nok");
    bounds = b.select(step_pos, pos_ok, neg_ok, name="rin.bounds");
    return b.and_(rem_zero, bounds, name="rin.found");
}

impl NativeRangeEmitter.emit_count(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    parts = self._load_range(ctx, target);
    if parts is None or not args {
        return None;
    }
    (start, stop, step) = parts;
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    val = p._coerce_type(args[0], i64);
    found = self._in_range(ctx, val, start, stop, step);
    return b.zext(found, i64, name="rng.count");
}

impl NativeRangeEmitter.emit_index(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    parts = self._load_range(ctx, target);
    if parts is None or not args {
        return None;
    }
    (start, stop, step) = parts;
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    val = p._coerce_type(args[0], i64);
    diff = b.sub(val, start, name="ri.diff");
    idx = b.sdiv(diff, step, name="ri.idx");
    return idx;
}

impl NativeRangeEmitter.emit_op_eq(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeRangeEmitter.emit_op_ne(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeRangeEmitter.emit_op_contains(
    self: NativeRangeEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}
