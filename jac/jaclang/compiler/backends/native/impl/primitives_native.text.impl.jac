impl NativeStrEmitter.emit_capitalize(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
    tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
    slen = p._call_str_len(b, target, name="cap.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="cap.alloc.sz");
    p._set_rc_ctx("capitalize", "");
    result = p._str_alloc(b, alloc_size, name="cap.buf");
    p._clear_rc_ctx();
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="cap.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    first_bb = func.append_basic_block(name="cap.first");
    loop_bb = func.append_basic_block(name="cap.loop");
    body_bb = func.append_basic_block(name="cap.body");
    done_bb = func.append_basic_block(name="cap.done");
    b.cbranch(is_empty, done_bb, first_bb);

    b.position_at_start(first_bb);
    first_ch = b.load(target, name="cap.first.ch");
    first_i32 = b.zext(first_ch, i32, name="cap.first.i32");
    upper_ch = b.call(toupper_fn, [first_i32], name="cap.first.upper");
    upper_i8 = b.trunc(upper_ch, i8, name="cap.first.i8");
    b.store(upper_i8, result);
    b.branch(loop_bb);

    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="cap.idx");
    idx.add_incoming(ir.Constant(i64, 1), first_bb);
    cond = b.icmp_unsigned("<", idx, slen, name="cap.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="cap.src.ptr");
    ch = b.load(src_ptr, name="cap.ch");
    ch_i32 = b.zext(ch, i32, name="cap.ch.i32");
    lower_ch = b.call(tolower_fn, [ch_i32], name="cap.lower");
    lower_i8 = b.trunc(lower_ch, i8, name="cap.lower.i8");
    dst_ptr = b.gep(result, [idx], name="cap.dst.ptr");
    b.store(lower_i8, dst_ptr);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="cap.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_casefold(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_case_transform(ctx, target, "tolower");
}

impl NativeStrEmitter.emit_lower(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_case_transform(ctx, target, "tolower");
}

impl NativeStrEmitter.emit_upper(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_case_transform(ctx, target, "toupper");
}

impl NativeStrEmitter._emit_case_transform(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, cfunc_name: str
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    slen = p._call_str_len(b, target, name="case.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="case.alloc.sz");
    p._set_rc_ctx("upper_lower", "");
    result = p._str_alloc(b, alloc_size, name="case.buf");
    p._clear_rc_ctx();
    transform_fn = p._get_or_declare_extern(cfunc_name, i32, [i32]);
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="case.loop");
    body_bb = func.append_basic_block(name="case.body");
    done_bb = func.append_basic_block(name="case.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="case.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    cond = b.icmp_unsigned("<", idx, slen, name="case.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="case.src.ptr");
    ch = b.load(src_ptr, name="case.ch");
    ch_i32 = b.zext(ch, i32, name="case.ch.i32");
    transformed = b.call(transform_fn, [ch_i32], name="case.transformed");
    ch_out = b.trunc(transformed, i8, name="case.ch.out");
    dst_ptr = b.gep(result, [idx], name="case.dst.ptr");
    b.store(ch_out, dst_ptr);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="case.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_title(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
    tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="title.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="title.alloc");
    p._set_rc_ctx("title", "");
    result = p._str_alloc(b, alloc_size, name="title.buf");
    p._clear_rc_ctx();
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="title.loop");
    body_bb = func.append_basic_block(name="title.body");
    done_bb = func.append_basic_block(name="title.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="title.idx");
    at_boundary = b.phi(i64, name="title.boundary");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_boundary.add_incoming(ir.Constant(i64, 1), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="title.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="title.src.ptr");
    ch = b.load(src_ptr, name="title.ch");
    ch_i32 = b.zext(ch, i32, name="title.ch.i32");
    is_alpha = b.call(isalpha_fn, [ch_i32], name="title.isalpha");
    is_alpha_bool = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="title.isalp"
    );
    is_boundary = b.icmp_unsigned(
        "!=", at_boundary, ir.Constant(i64, 0), name="title.isbnd"
    );
    upper_ch = b.call(toupper_fn, [ch_i32], name="title.upper");
    lower_ch = b.call(tolower_fn, [ch_i32], name="title.lower");
    should_upper = b.and_(is_boundary, is_alpha_bool, name="title.shup");
    pick1 = b.select(should_upper, upper_ch, ch_i32, name="title.pick1");
    should_lower = b.and_(
        b.not_(is_boundary, name="title.notbnd"), is_alpha_bool, name="title.shlo"
    );
    pick2 = b.select(should_lower, lower_ch, pick1, name="title.pick2");
    out_i8 = b.trunc(pick2, i8, name="title.out");
    dst_ptr = b.gep(result, [idx], name="title.dst.ptr");
    b.store(out_i8, dst_ptr);
    new_boundary = b.select(
        is_alpha_bool, ir.Constant(i64, 0), ir.Constant(i64, 1), name="title.newbnd"
    );
    next_idx = b.add(idx, ir.Constant(i64, 1), name="title.next");
    idx.add_incoming(next_idx, body_bb);
    at_boundary.add_incoming(new_boundary, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_swapcase(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    toupper_fn = p._get_or_declare_extern("toupper", i32, [i32]);
    tolower_fn = p._get_or_declare_extern("tolower", i32, [i32]);
    islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
    isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
    slen = p._call_str_len(b, target, name="swap.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="swap.alloc.sz");
    p._set_rc_ctx("swapcase", "");
    result = p._str_alloc(b, alloc_size, name="swap.buf");
    p._clear_rc_ctx();
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="swap.loop");
    body_bb = func.append_basic_block(name="swap.body");
    done_bb = func.append_basic_block(name="swap.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="swap.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    cond = b.icmp_unsigned("<", idx, slen, name="swap.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    src_ptr = b.gep(target, [idx], name="swap.src.ptr");
    ch = b.load(src_ptr, name="swap.ch");
    ch_i32 = b.zext(ch, i32, name="swap.ch.i32");
    is_low = b.call(islower_fn, [ch_i32], name="swap.islow");
    is_low_bool = b.icmp_signed("!=", is_low, ir.Constant(i32, 0), name="swap.islo");
    upper_ch = b.call(toupper_fn, [ch_i32], name="swap.upper");
    is_up = b.call(isupper_fn, [ch_i32], name="swap.isup");
    is_up_bool = b.icmp_signed("!=", is_up, ir.Constant(i32, 0), name="swap.isup.b");
    lower_ch = b.call(tolower_fn, [ch_i32], name="swap.lower");

    pick1 = b.select(is_up_bool, lower_ch, ch_i32, name="swap.pick1");
    pick2 = b.select(is_low_bool, upper_ch, pick1, name="swap.pick2");
    out_i8 = b.trunc(pick2, i8, name="swap.out");
    dst_ptr = b.gep(result, [idx], name="swap.dst.ptr");
    b.store(out_i8, dst_ptr);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="swap.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    p._str_finish(b, result, slen);
    return result;
}

impl NativeStrEmitter.emit_count(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    sub_len = p._call_str_len(b, args[0], name="cnt.sub.len");
    null_ptr = ir.Constant(i8p, None);
    func = b.basic_block.function;
    empty_bb = func.append_basic_block(name="cnt.empty");
    scan_bb = func.append_basic_block(name="cnt.scan");
    loop_bb = func.append_basic_block(name="cnt.loop");
    found_bb = func.append_basic_block(name="cnt.found");
    done_bb = func.append_basic_block(name="cnt.done");

    is_empty = b.icmp_unsigned("==", sub_len, ir.Constant(i64, 0), name="cnt.isempty");
    b.cbranch(is_empty, empty_bb, scan_bb);
    b.position_at_start(empty_bb);
    tgt_len = p._call_str_len(b, target, name="cnt.tgt.len");
    empty_count = b.add(tgt_len, ir.Constant(i64, 1), name="cnt.empty.n");
    b.branch(done_bb);
    b.position_at_start(scan_bb);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    cur_ptr = b.phi(i8p, name="cnt.cur");
    count = b.phi(i64, name="cnt.count");
    cur_ptr.add_incoming(target, scan_bb);
    count.add_incoming(ir.Constant(i64, 0), scan_bb);
    found = b.call(strstr_fn, [cur_ptr, args[0]], name="cnt.found.ptr");
    is_null = b.icmp_unsigned("==", found, null_ptr, name="cnt.null");
    b.cbranch(is_null, done_bb, found_bb);
    b.position_at_start(found_bb);
    new_count = b.add(count, ir.Constant(i64, 1), name="cnt.inc");
    found_int = b.ptrtoint(found, i64, name="cnt.fnd.int");
    next_int = b.add(found_int, sub_len, name="cnt.next.int");
    next_ptr = b.inttoptr(next_int, i8p, name="cnt.next.ptr");
    cur_ptr.add_incoming(next_ptr, found_bb);
    count.add_incoming(new_count, found_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="cnt.result");
    result.add_incoming(empty_count, empty_bb);
    result.add_incoming(count, loop_bb);
    return result;
}

impl NativeStrEmitter.emit_find(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    search_from = target;
    if len(args) >= 2 {
        slen = p._call_str_len(b, target, name="find.slen");
        start = p._coerce_type(args[1], i64);
        neg = b.icmp_signed("<", start, ir.Constant(i64, 0), name="find.st.neg");
        wrapped = b.add(start, slen, name="find.st.wrap");
        start = b.select(neg, wrapped, start, name="find.st.pos");
        below = b.icmp_signed("<", start, ir.Constant(i64, 0), name="find.st.lo");
        start = b.select(below, ir.Constant(i64, 0), start, name="find.st.lo.c");
        above = b.icmp_signed(">", start, slen, name="find.st.hi");
        start = b.select(above, slen, start, name="find.st.hi.c");
        search_from = b.gep(target, [start], name="find.from");
    }
    found = b.call(strstr_fn, [search_from, args[0]], name="find.ptr");
    null_ptr = ir.Constant(i8p, None);
    is_null = b.icmp_unsigned("==", found, null_ptr, name="find.null");
    target_int = b.ptrtoint(target, i64, name="find.tgt.int");
    found_int = b.ptrtoint(found, i64, name="find.fnd.int");
    diff = b.sub(found_int, target_int, name="find.diff");
    return b.select(is_null, ir.Constant(i64, -1), diff, name="find.result");
}

impl NativeStrEmitter.emit_rfind(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    slen = p._call_str_len(b, target, name="rfind.slen");
    sub_len = p._call_str_len(b, args[0], name="rfind.sub.len");
    null_ptr = ir.Constant(i8p, None);
    target_int = b.ptrtoint(target, i64, name="rfind.tgt.int");
    func = b.basic_block.function;
    entry_bb = b.basic_block;

    empty_bb = func.append_basic_block(name="rfind.empty");
    search_bb = func.append_basic_block(name="rfind.search");
    loop_bb = func.append_basic_block(name="rfind.loop");
    found_bb = func.append_basic_block(name="rfind.found");
    done_bb = func.append_basic_block(name="rfind.done");
    is_empty = b.icmp_unsigned(
        "==", sub_len, ir.Constant(i64, 0), name="rfind.isempty"
    );
    b.cbranch(is_empty, empty_bb, search_bb);
    b.position_at_start(empty_bb);
    b.branch(done_bb);
    b.position_at_start(search_bb);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    cur_ptr = b.phi(i8p, name="rfind.cur");
    last_pos = b.phi(i64, name="rfind.last");
    cur_ptr.add_incoming(target, search_bb);
    last_pos.add_incoming(ir.Constant(i64, -1), search_bb);
    found = b.call(strstr_fn, [cur_ptr, args[0]], name="rfind.found.ptr");
    is_null = b.icmp_unsigned("==", found, null_ptr, name="rfind.null");
    b.cbranch(is_null, done_bb, found_bb);
    b.position_at_start(found_bb);
    found_int = b.ptrtoint(found, i64, name="rfind.fnd.int");
    new_pos = b.sub(found_int, target_int, name="rfind.pos");
    next_int = b.add(found_int, sub_len, name="rfind.next.int");
    next_ptr = b.inttoptr(next_int, i8p, name="rfind.next.ptr");
    cur_ptr.add_incoming(next_ptr, found_bb);
    last_pos.add_incoming(new_pos, found_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="rfind.result");
    result.add_incoming(slen, empty_bb);
    result.add_incoming(last_pos, loop_bb);
    return result;
}

impl NativeStrEmitter.emit_index(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    found = b.call(strstr_fn, [target, args[0]], name="index.ptr");
    null_ptr = ir.Constant(i8p, None);
    is_null = b.icmp_unsigned("==", found, null_ptr, name="index.null");
    p._emit_runtime_raise(is_null, "ValueError", "substring not found");
    target_int = b.ptrtoint(target, i64, name="index.tgt.int");
    found_int = b.ptrtoint(found, i64, name="index.fnd.int");
    return b.sub(found_int, target_int, name="index.result");
}

impl NativeStrEmitter.emit_rindex(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);

    rfind_result = self.emit_rfind(ctx, target, args);
    if rfind_result is None {
        return None;
    }
    is_neg = b.icmp_signed("<", rfind_result, ir.Constant(i64, 0), name="rindex.neg");
    p._emit_runtime_raise(is_neg, "ValueError", "substring not found");
    return rfind_result;
}

impl NativeStrEmitter.emit_startswith(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_affix(ctx, target, args, suffix=False);
}

impl NativeStrEmitter.emit_endswith(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_affix(ctx, target, args, suffix=True);
}

impl NativeStrEmitter._emit_affix(
    self: NativeStrEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value],
    suffix: bool
) -> (ir.Value | None) {
    if not args or len(args) > 3 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    candidates: list[ir.Value] = [];
    if isinstance(args[0].type, ir.LiteralStructType) {
        for (index, typ) in enumerate(args[0].type.elements) {
            if typ != i8p {
                return None;
            }
            candidates.append(b.extract_value(args[0], index, name="affix.item"));
        }
    } elif args[0].type == i8p {
        candidates.append(args[0]);
    } else {
        return None;
    }
    for bound in args[1:] {
        if not isinstance(bound.type, ir.IntType) {
            return None;
        }
    }
    length = p._call_str_len(b, target, name="affix.length");
    start = p._coerce_type(args[1], i64) if len(args) > 1 else zero;
    end = p._coerce_type(args[2], i64) if len(args) > 2 else length;
    start = b.select(b.icmp_signed("<", start, zero), b.add(start, length), start);
    start = b.select(b.icmp_signed("<", start, zero), zero, start);
    end = b.select(b.icmp_signed("<", end, zero), b.add(end, length), end);
    end = b.select(b.icmp_signed("<", end, zero), zero, end);
    end = b.select(b.icmp_signed(">", end, length), length, end);
    available = b.sub(end, start);
    bounds_ok = b.and_(
        b.icmp_signed("<=", start, end), b.icmp_signed("<=", start, length)
    );
    fn = b.basic_block.function;
    match_bb = fn.append_basic_block("affix.match");
    miss = fn.append_basic_block("affix.miss");
    done = fn.append_basic_block("affix.done");
    memcmp = p._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    for candidate in candidates {
        size = p._call_str_len(b, candidate, name="affix.size");
        compare = fn.append_basic_block("affix.compare");
        next_candidate = fn.append_basic_block("affix.next");
        fits = b.and_(bounds_ok, b.icmp_signed("<=", size, available));
        b.cbranch(fits, compare, next_candidate);
        b.position_at_end(compare);
        offset = b.sub(end, size) if suffix else start;
        data = b.gep(target, [offset], name="affix.data");
        compared = b.call(memcmp, [data, candidate, size]);
        b.cbranch(
            b.icmp_signed("==", compared, ir.Constant(i32, 0)), match_bb, next_candidate
        );
        b.position_at_end(next_candidate);
    }
    b.branch(miss);
    b.position_at_end(match_bb);
    b.branch(done);
    b.position_at_end(miss);
    b.branch(done);
    b.position_at_end(done);
    result = b.phi(i64, name="affix.result");
    result.add_incoming(ir.Constant(i64, 1), match_bb);
    result.add_incoming(zero, miss);
    return result;
}

impl NativeStrEmitter.emit_replace(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    old_str = args[0];
    new_str = args[1];

    count_val: ir.Value = ir.Constant(i64, -1) if len(args) < 3 else args[2];
    target_len = p._call_str_len(b, target, name="repl.tgt.len");
    old_len = p._call_str_len(b, old_str, name="repl.old.len");
    new_len = p._call_str_len(b, new_str, name="repl.new.len");

    generous_factor = b.add(new_len, ir.Constant(i64, 1), name="repl.factor");
    generous_size = b.mul(target_len, generous_factor, name="repl.generous");
    alloc_size = b.add(generous_size, ir.Constant(i64, 1), name="repl.alloc");
    p._set_rc_ctx("replace", "");
    result = p._str_alloc(b, alloc_size, name="repl.buf");
    p._clear_rc_ctx();
    null_ptr = ir.Constant(i8p, None);
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="repl.loop");
    found_bb = func.append_basic_block(name="repl.found");
    notfound_bb = func.append_basic_block(name="repl.notfound");
    done_bb = func.append_basic_block(name="repl.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    src = b.phi(i8p, name="repl.src");
    dst_off = b.phi(i64, name="repl.dst.off");
    remaining = b.phi(i64, name="repl.remaining");
    src.add_incoming(target, entry_bb);
    dst_off.add_incoming(ir.Constant(i64, 0), entry_bb);
    remaining.add_incoming(count_val, entry_bb);

    count_exhausted = b.icmp_signed(
        "==", remaining, ir.Constant(i64, 0), name="repl.exhausted"
    );
    found = b.call(strstr_fn, [src, old_str], name="repl.found.ptr");
    is_null = b.icmp_unsigned("==", found, null_ptr, name="repl.null");
    no_replace = b.or_(count_exhausted, is_null, name="repl.no.repl");
    b.cbranch(no_replace, notfound_bb, found_bb);
    b.position_at_start(found_bb);
    src_int = b.ptrtoint(src, i64, name="repl.src.int");
    found_int = b.ptrtoint(found, i64, name="repl.fnd.int");
    prefix_len = b.sub(found_int, src_int, name="repl.pfx.len");
    dst_ptr = b.gep(result, [dst_off], name="repl.dst.ptr");
    b.call(memcpy_fn, [dst_ptr, src, prefix_len]);
    dst_off2 = b.add(dst_off, prefix_len, name="repl.off2");
    dst_ptr2 = b.gep(result, [dst_off2], name="repl.dst.ptr2");
    b.call(memcpy_fn, [dst_ptr2, new_str, new_len]);
    dst_off3 = b.add(dst_off2, new_len, name="repl.off3");
    next_src_int = b.add(found_int, old_len, name="repl.next.int");
    next_src = b.inttoptr(next_src_int, i8p, name="repl.next.src");

    next_remaining = b.sub(remaining, ir.Constant(i64, 1), name="repl.next.rem");
    src.add_incoming(next_src, found_bb);
    dst_off.add_incoming(dst_off3, found_bb);
    remaining.add_incoming(next_remaining, found_bb);
    b.branch(loop_bb);
    b.position_at_start(notfound_bb);
    remain_len = p._call_str_len_raw(b, src, name="repl.remain.len");
    dst_ptr3 = b.gep(result, [dst_off], name="repl.dst.ptr3");
    b.call(memcpy_fn, [dst_ptr3, src, remain_len]);
    final_len = b.add(dst_off, remain_len, name="repl.final.len");
    p._str_finish(b, result, final_len);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    return result;
}

impl NativeStrEmitter.emit_strip(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    charset = args[0] if args else None;
    return ctx.pass_ref._codegen_str_strip_chars(target, charset, True, True);
}

impl NativeStrEmitter.emit_lstrip(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    charset = args[0] if args else None;
    return ctx.pass_ref._codegen_str_strip_chars(target, charset, True, False);
}

impl NativeStrEmitter.emit_rstrip(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    charset = args[0] if args else None;
    return ctx.pass_ref._codegen_str_strip_chars(target, charset, False, True);
}

impl NativeStrEmitter.emit_removeprefix(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    strncmp_fn = p._get_or_declare_extern("strncmp", i32, [i8p, i8p, i64]);
    strcpy_fn = p._get_or_declare_extern("strcpy", i8p, [i8p, i8p]);
    prefix_len = p._call_str_len(b, args[0], name="rmpfx.pfx.len");
    target_len = p._call_str_len(b, target, name="rmpfx.tgt.len");
    too_long = b.icmp_unsigned(">", prefix_len, target_len, name="rmpfx.toolong");
    func = b.basic_block.function;
    check_bb = func.append_basic_block(name="rmpfx.check");
    match_bb = func.append_basic_block(name="rmpfx.match");
    nomatch_bb = func.append_basic_block(name="rmpfx.nomatch");
    done_bb = func.append_basic_block(name="rmpfx.done");
    b.cbranch(too_long, nomatch_bb, check_bb);
    b.position_at_start(check_bb);
    cmp = b.call(strncmp_fn, [target, args[0], prefix_len], name="rmpfx.cmp");
    is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="rmpfx.eq");
    b.cbranch(is_match, match_bb, nomatch_bb);

    b.position_at_start(match_bb);
    rest_len = b.sub(target_len, prefix_len, name="rmpfx.rest.len");
    alloc_m = b.add(rest_len, ir.Constant(i64, 1), name="rmpfx.alloc.m");
    p._set_rc_ctx("removeprefix", "");
    result_m = p._str_alloc(b, alloc_m, name="rmpfx.buf.m");
    p._clear_rc_ctx();
    rest_ptr = b.gep(target, [prefix_len], name="rmpfx.rest.ptr");
    b.call(strcpy_fn, [result_m, rest_ptr]);
    p._str_finish(b, result_m, rest_len);
    b.branch(done_bb);

    b.position_at_start(nomatch_bb);
    alloc_n = b.add(target_len, ir.Constant(i64, 1), name="rmpfx.alloc.n");
    p._set_rc_ctx("removeprefix", "");
    result_n = p._str_alloc(b, alloc_n, name="rmpfx.buf.n");
    p._clear_rc_ctx();
    b.call(strcpy_fn, [result_n, target]);
    p._str_finish(b, result_n, target_len);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i8p, name="rmpfx.result");
    result_phi.add_incoming(result_m, match_bb);
    result_phi.add_incoming(result_n, nomatch_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_removesuffix(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    suffix_len = p._call_str_len(b, args[0], name="rmsfx.sfx.len");
    target_len = p._call_str_len(b, target, name="rmsfx.tgt.len");
    too_long = b.icmp_unsigned(">", suffix_len, target_len, name="rmsfx.toolong");
    func = b.basic_block.function;
    check_bb = func.append_basic_block(name="rmsfx.check");
    match_bb = func.append_basic_block(name="rmsfx.match");
    nomatch_bb = func.append_basic_block(name="rmsfx.nomatch");
    done_bb = func.append_basic_block(name="rmsfx.done");
    b.cbranch(too_long, nomatch_bb, check_bb);
    b.position_at_start(check_bb);
    offset = b.sub(target_len, suffix_len, name="rmsfx.offset");
    end_ptr = b.gep(target, [offset], name="rmsfx.end.ptr");
    cmp = p._call_str_cmp(b, end_ptr, args[0], name="rmsfx.cmp");
    is_match = b.icmp_signed("==", cmp, ir.Constant(i32, 0), name="rmsfx.eq");
    b.cbranch(is_match, match_bb, nomatch_bb);

    b.position_at_start(match_bb);
    new_len = b.sub(target_len, suffix_len, name="rmsfx.newlen");
    alloc_m = b.add(new_len, ir.Constant(i64, 1), name="rmsfx.alloc.m");
    p._set_rc_ctx("removesuffix", "");
    result_m = p._str_alloc(b, alloc_m, name="rmsfx.buf.m");
    p._clear_rc_ctx();
    b.call(memcpy_fn, [result_m, target, new_len]);
    p._str_finish(b, result_m, new_len);
    b.branch(done_bb);

    b.position_at_start(nomatch_bb);
    alloc_n = b.add(target_len, ir.Constant(i64, 1), name="rmsfx.alloc.n");
    p._set_rc_ctx("removesuffix", "");
    result_n = p._str_alloc(b, alloc_n, name="rmsfx.buf.n");
    p._clear_rc_ctx();
    b.call(memcpy_fn, [result_n, target, target_len]);
    p._str_finish(b, result_n, target_len);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i8p, name="rmsfx.result");
    result_phi.add_incoming(result_m, match_bb);
    result_phi.add_incoming(result_n, nomatch_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_split(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if args {
        return ctx.pass_ref._codegen_str_split(
            target, args[0], args[1] if len(args) > 1 else None
        );
    }
    return None;
}

impl NativeStrEmitter.emit_rsplit(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if args {
        return ctx.pass_ref._codegen_str_split(
            target, args[0], args[1] if len(args) > 1 else None, True
        );
    }
    return None;
}

impl NativeStrEmitter.emit_splitlines(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    nl_sep = p._make_global_string("\n", name_prefix=".nl.sep");
    return p._codegen_str_split(target, nl_sep);
}

impl NativeStrEmitter.emit_join(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);

    p._emit_list_helpers("ptr", i8p);
    lhelpers = p.list_helpers.get("ptr");
    if lhelpers is None {
        return None;
    }
    the_list = args[0];
    sep_len = p._call_str_len(b, target, name="jn.seplen");
    list_len = b.call(lhelpers["len"], [the_list], name="jn.listlen");
    func = b.basic_block.function;

    is_empty = b.icmp_unsigned("==", list_len, zero, name="jn.isempty");
    empty_bb = func.append_basic_block(name="jn.empty");
    pass1_bb = func.append_basic_block(name="jn.pass1");
    done_bb = func.append_basic_block(name="jn.done");
    b.cbranch(is_empty, empty_bb, pass1_bb);

    b.position_at_start(empty_bb);
    p._set_rc_ctx("join", "");
    empty_buf = p._str_alloc(b, one, name="jn.empty.buf");
    p._clear_rc_ctx();
    p._str_finish(b, empty_buf, zero);
    b.branch(done_bb);

    b.position_at_start(pass1_bb);
    entry_p1 = b.basic_block;
    loop1_bb = func.append_basic_block(name="jn.len.loop");
    body1_bb = func.append_basic_block(name="jn.len.body");
    pass2_start = func.append_basic_block(name="jn.p2start");
    b.branch(loop1_bb);
    b.position_at_start(loop1_bb);
    p1_idx = b.phi(i64, name="jn.p1.idx");
    p1_total = b.phi(i64, name="jn.p1.total");
    p1_idx.add_incoming(zero, entry_p1);
    p1_total.add_incoming(zero, entry_p1);
    p1_end = b.icmp_unsigned(">=", p1_idx, list_len, name="jn.p1.end");
    b.cbranch(p1_end, pass2_start, body1_bb);
    b.position_at_start(body1_bb);
    elem = b.call(lhelpers["get"], [the_list, p1_idx], name="jn.p1.elem");
    elen = p._call_str_len(b, elem, name="jn.p1.elen");
    new_total = b.add(p1_total, elen, name="jn.p1.ntot");
    next_p1 = b.add(p1_idx, one, name="jn.p1.next");
    p1_idx.add_incoming(next_p1, body1_bb);
    p1_total.add_incoming(new_total, body1_bb);
    b.branch(loop1_bb);

    b.position_at_start(pass2_start);
    total_phi = b.phi(i64, name="jn.total");
    total_phi.add_incoming(p1_total, loop1_bb);
    sep_count = b.sub(list_len, one, name="jn.sepcount");
    sep_total = b.mul(sep_len, sep_count, name="jn.septotal");
    grand_total = b.add(total_phi, sep_total, name="jn.grand");
    alloc_sz = b.add(grand_total, one, name="jn.alloc");
    p._set_rc_ctx("join", "");
    buf = p._str_alloc(b, alloc_sz, name="jn.buf");
    p._clear_rc_ctx();

    entry_p2 = b.basic_block;
    loop2_bb = func.append_basic_block(name="jn.cp.loop");
    body2_bb = func.append_basic_block(name="jn.cp.body");
    sep_check = func.append_basic_block(name="jn.cp.sep");
    sep_copy = func.append_basic_block(name="jn.cp.sepcopy");
    next_iter = func.append_basic_block(name="jn.cp.next");
    copy_done = func.append_basic_block(name="jn.cp.done");
    b.branch(loop2_bb);
    b.position_at_start(loop2_bb);
    p2_idx = b.phi(i64, name="jn.p2.idx");
    p2_off = b.phi(i64, name="jn.p2.off");
    p2_idx.add_incoming(zero, entry_p2);
    p2_off.add_incoming(zero, entry_p2);
    p2_end = b.icmp_unsigned(">=", p2_idx, list_len, name="jn.p2.end");
    b.cbranch(p2_end, copy_done, body2_bb);
    b.position_at_start(body2_bb);
    elem2 = b.call(lhelpers["get"], [the_list, p2_idx], name="jn.p2.elem");
    elen2 = p._call_str_len(b, elem2, name="jn.p2.elen");
    dst2 = b.gep(buf, [p2_off], name="jn.p2.dst");
    b.call(memcpy_fn, [dst2, elem2, elen2]);
    off_after_elem = b.add(p2_off, elen2, name="jn.p2.off2");
    b.branch(sep_check);

    b.position_at_start(sep_check);
    next_p2 = b.add(p2_idx, one, name="jn.p2.next");
    is_last = b.icmp_unsigned(">=", next_p2, list_len, name="jn.p2.islast");
    b.cbranch(is_last, next_iter, sep_copy);
    b.position_at_start(sep_copy);
    sep_dst = b.gep(buf, [off_after_elem], name="jn.p2.sepdst");
    b.call(memcpy_fn, [sep_dst, target, sep_len]);
    off_after_sep = b.add(off_after_elem, sep_len, name="jn.p2.off3");
    b.branch(next_iter);

    b.position_at_start(next_iter);
    merged_off = b.phi(i64, name="jn.p2.moff");
    merged_off.add_incoming(off_after_elem, sep_check);
    merged_off.add_incoming(off_after_sep, sep_copy);
    p2_idx.add_incoming(next_p2, next_iter);
    p2_off.add_incoming(merged_off, next_iter);
    b.branch(loop2_bb);

    b.position_at_start(copy_done);
    final_off = b.phi(i64, name="jn.final.off");
    final_off.add_incoming(p2_off, loop2_bb);
    p._str_finish(b, buf, final_off);
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(i8p, name="jn.result");
    result.add_incoming(empty_buf, empty_bb);
    result.add_incoming(buf, copy_done);
    return result;
}

impl NativeStrEmitter.emit_partition(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    sep_val = args[0];
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    p._emit_list_helpers("ptr", i8p);
    lh = p.list_helpers.get("ptr");
    if lh is None {
        return None;
    }
    result_list = b.call(lh["new"], [], name="part.list");
    sep_len = p._call_str_len(b, sep_val, name="part.seplen");
    str_len = p._call_str_len(b, target, name="part.strlen");
    found_ptr = b.call(strstr_fn, [target, sep_val], name="part.found");
    null_i8p = ir.Constant(i8p, None);
    is_found = b.icmp_unsigned("!=", found_ptr, null_i8p, name="part.isfound");
    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="part.yes");
    notfound_bb = func.append_basic_block(name="part.no");
    merge_bb = func.append_basic_block(name="part.merge");
    b.cbranch(is_found, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    base_int = b.ptrtoint(target, i64, name="part.base");
    found_int = b.ptrtoint(found_ptr, i64, name="part.fint");
    before_len = b.sub(found_int, base_int, name="part.blen");
    before_alloc = b.add(before_len, ir.Constant(i64, 1), name="part.balloc");
    before_ptr = p._str_alloc(b, before_alloc, name="part.before");
    b.call(memcpy_fn, [before_ptr, target, before_len]);
    p._str_finish(b, before_ptr, before_len);
    after_off = b.add(before_len, sep_len, name="part.aoff");
    after_len = b.sub(str_len, after_off, name="part.alen");
    after_alloc = b.add(after_len, ir.Constant(i64, 1), name="part.aalloc");
    after_ptr = p._str_alloc(b, after_alloc, name="part.after");
    after_src = b.gep(target, [after_off], name="part.asrc");
    b.call(memcpy_fn, [after_ptr, after_src, after_len]);
    p._str_finish(b, after_ptr, after_len);
    b.call(lh["append"], [result_list, before_ptr]);
    b.call(lh["append"], [result_list, sep_val]);
    b.call(lh["append"], [result_list, after_ptr]);
    b.branch(merge_bb);

    b.position_at_start(notfound_bb);
    empty1 = p._str_alloc(b, ir.Constant(i64, 1), name="part.e1");
    p._str_finish(b, empty1, ir.Constant(i64, 0));
    empty2 = p._str_alloc(b, ir.Constant(i64, 1), name="part.e2");
    p._str_finish(b, empty2, ir.Constant(i64, 0));
    b.call(lh["append"], [result_list, target]);
    b.call(lh["append"], [result_list, empty1]);
    b.call(lh["append"], [result_list, empty2]);
    b.branch(merge_bb);
    b.position_at_start(merge_bb);
    return result_list;
}

impl NativeStrEmitter.emit_rpartition(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    sep_val = args[0];
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    p._emit_list_helpers("ptr", i8p);
    lh = p.list_helpers.get("ptr");
    if lh is None {
        return None;
    }
    result_list = b.call(lh["new"], [], name="rpart.list");
    sep_len = p._call_str_len(b, sep_val, name="rpart.seplen");
    str_len = p._call_str_len(b, target, name="rpart.strlen");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="rpart.loop");
    body_bb = func.append_basic_block(name="rpart.body");
    done_bb = func.append_basic_block(name="rpart.done");
    found_bb = func.append_basic_block(name="rpart.yes");
    notfound_bb = func.append_basic_block(name="rpart.no");
    merge_bb = func.append_basic_block(name="rpart.merge");

    last_match_alloca = b.alloca(i8p, name="rpart.last");
    b.store(ir.Constant(i8p, None), last_match_alloca);
    cur_alloca = b.alloca(i8p, name="rpart.cur");
    b.store(target, cur_alloca);
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    cur_ptr = b.load(cur_alloca, name="rpart.curp");
    found_ptr = b.call(strstr_fn, [cur_ptr, sep_val], name="rpart.found");
    null_i8p = ir.Constant(i8p, None);
    is_found = b.icmp_unsigned("!=", found_ptr, null_i8p, name="rpart.isf");
    b.cbranch(is_found, body_bb, done_bb);
    b.position_at_start(body_bb);
    b.store(found_ptr, last_match_alloca);
    next_ptr = b.gep(found_ptr, [ir.Constant(i64, 1)], name="rpart.next");
    b.store(next_ptr, cur_alloca);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    last_match = b.load(last_match_alloca, name="rpart.last.v");
    is_any = b.icmp_unsigned("!=", last_match, null_i8p, name="rpart.isany");
    b.cbranch(is_any, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    base_int = b.ptrtoint(target, i64, name="rpart.base");
    last_int = b.ptrtoint(last_match, i64, name="rpart.lint");
    before_len = b.sub(last_int, base_int, name="rpart.blen");
    before_alloc = b.add(before_len, ir.Constant(i64, 1), name="rpart.balloc");
    before_ptr = p._str_alloc(b, before_alloc, name="rpart.before");
    b.call(memcpy_fn, [before_ptr, target, before_len]);
    p._str_finish(b, before_ptr, before_len);
    after_off = b.add(before_len, sep_len, name="rpart.aoff");
    after_len = b.sub(str_len, after_off, name="rpart.alen");
    after_alloc = b.add(after_len, ir.Constant(i64, 1), name="rpart.aalloc");
    after_ptr = p._str_alloc(b, after_alloc, name="rpart.after");
    after_src = b.gep(target, [after_off], name="rpart.asrc");
    b.call(memcpy_fn, [after_ptr, after_src, after_len]);
    p._str_finish(b, after_ptr, after_len);
    b.call(lh["append"], [result_list, before_ptr]);
    b.call(lh["append"], [result_list, sep_val]);
    b.call(lh["append"], [result_list, after_ptr]);
    b.branch(merge_bb);

    b.position_at_start(notfound_bb);
    empty1 = p._str_alloc(b, ir.Constant(i64, 1), name="rpart.e1");
    p._str_finish(b, empty1, ir.Constant(i64, 0));
    empty2 = p._str_alloc(b, ir.Constant(i64, 1), name="rpart.e2");
    p._str_finish(b, empty2, ir.Constant(i64, 0));
    b.call(lh["append"], [result_list, empty1]);
    b.call(lh["append"], [result_list, empty2]);
    b.call(lh["append"], [result_list, target]);
    b.branch(merge_bb);
    b.position_at_start(merge_bb);
    return result_list;
}

impl NativeStrEmitter.emit_format(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return target;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    strstr_fn = p._get_or_declare_extern("strstr", i8p, [i8p, i8p]);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    snprintf_fn = p._get_or_declare_extern(
        "snprintf", i32, [i8p, i64, i8p], var_arg=True
    );
    placeholder = p._make_global_string("{}");
    ph_len = ir.Constant(i64, 2);
    null_ptr = ir.Constant(i8p, None);

    str_args: list[ir.Value] = [];
    for arg in args {
        if isinstance(arg.type, ir.IntType) and arg.type.width > 1 {
            buf = p._str_alloc(b, ir.Constant(i64, 32), name="fmt.ibuf");
            fmt_s = p._make_global_string("%ld");
            ibuf_n32 = b.call(
                snprintf_fn, [buf, ir.Constant(i64, 32), fmt_s, arg], name="fmt.ibuf.n"
            );
            p._str_finish(b, buf, b.sext(ibuf_n32, i64, name="fmt.ibuf.n64"));
            str_args.append(buf);
        } elif isinstance(arg.type, ir.DoubleType) {
            str_args.append(p._emit_float_repr(arg));
        } else {
            str_args.append(arg);
        }
    }

    current = target;
    for i in range(len(str_args)) {
        arg_str = str_args[i];
        arg_len = p._call_str_len(b, arg_str, name=f"fmt.a{i}.len");
        cur_len = p._call_str_len(b, current, name=f"fmt.c{i}.len");

        alloc_sz = b.add(
            b.sub(cur_len, ph_len, name=f"fmt.sub{i}"),
            b.add(arg_len, ir.Constant(i64, 1), name=f"fmt.aln{i}"),
            name=f"fmt.alloc{i}"
        );
        result = p._str_alloc(b, alloc_sz, name=f"fmt.res{i}");

        found = b.call(strstr_fn, [current, placeholder], name=f"fmt.fnd{i}");
        is_null = b.icmp_unsigned("==", found, null_ptr, name=f"fmt.null{i}");
        func = b.basic_block.function;
        replace_bb = func.append_basic_block(name=f"fmt.repl{i}");
        skip_bb = func.append_basic_block(name=f"fmt.skip{i}");
        merge_bb = func.append_basic_block(name=f"fmt.merge{i}");
        b.cbranch(is_null, skip_bb, replace_bb);

        b.position_at_start(replace_bb);
        cur_int = b.ptrtoint(current, i64, name=f"fmt.ci{i}");
        fnd_int = b.ptrtoint(found, i64, name=f"fmt.fi{i}");
        pfx_len = b.sub(fnd_int, cur_int, name=f"fmt.pfx{i}");
        b.call(memcpy_fn, [result, current, pfx_len]);
        dst2 = b.gep(result, [pfx_len], name=f"fmt.d2.{i}");
        b.call(memcpy_fn, [dst2, arg_str, arg_len]);
        dst3_off = b.add(pfx_len, arg_len, name=f"fmt.d3o{i}");
        dst3 = b.gep(result, [dst3_off], name=f"fmt.d3.{i}");
        sfx_start_int = b.add(fnd_int, ph_len, name=f"fmt.sfxi{i}");
        sfx_start = b.inttoptr(sfx_start_int, i8p, name=f"fmt.sfx{i}");
        sfx_len = p._call_str_len_raw(b, sfx_start, name=f"fmt.slen{i}");
        b.call(memcpy_fn, [dst3, sfx_start, sfx_len]);
        total_len = b.add(dst3_off, sfx_len, name=f"fmt.tlen{i}");
        p._str_finish(b, result, total_len);
        b.branch(merge_bb);

        b.position_at_start(skip_bb);

        b.call(memcpy_fn, [result, current, cur_len]);
        p._str_finish(b, result, cur_len);
        b.branch(merge_bb);
        b.position_at_start(merge_bb);
        current = result;
    }
    return current;
}

impl NativeStrEmitter.emit_format_map(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeStrEmitter.emit_center(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="center.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="center.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="center.pad");
    nopad_bb = func.append_basic_block(name="center.nopad");
    done_bb = func.append_basic_block(name="center.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);

    b.position_at_start(pad_bb);
    total_pad = b.sub(width, slen, name="center.totalpad");
    half = b.udiv(total_pad, ir.Constant(i64, 2), name="center.half");
    tp_and_w = b.and_(total_pad, width, name="center.tpw");
    adj = b.and_(tp_and_w, ir.Constant(i64, 1), name="center.adj");
    left_pad = b.add(half, adj, name="center.lpad");
    right_pad = b.sub(total_pad, left_pad, name="center.rpad");
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="center.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="center.buf");

    b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 32), left_pad]);

    str_ptr = b.gep(buf_pad, [left_pad], name="center.str.ptr");
    b.call(memcpy_fn, [str_ptr, target, slen]);

    right_ptr = b.gep(str_ptr, [slen], name="center.rpad.ptr");
    b.call(memset_fn, [right_ptr, ir.Constant(ir.IntType(32), 32), right_pad]);

    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);

    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="center.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="center.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="center.result");
    result.add_incoming(buf_pad, pad_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_ljust(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="ljust.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="ljust.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="ljust.pad");
    nopad_bb = func.append_basic_block(name="ljust.nopad");
    done_bb = func.append_basic_block(name="ljust.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);

    b.position_at_start(pad_bb);
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="ljust.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="ljust.buf");
    b.call(memcpy_fn, [buf_pad, target, slen]);
    pad_ptr = b.gep(buf_pad, [slen], name="ljust.pad.ptr");
    pad_len = b.sub(width, slen, name="ljust.pad.len");
    b.call(memset_fn, [pad_ptr, ir.Constant(ir.IntType(32), 32), pad_len]);
    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);

    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="ljust.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="ljust.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="ljust.result");
    result.add_incoming(buf_pad, pad_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_rjust(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="rjust.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="rjust.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="rjust.pad");
    nopad_bb = func.append_basic_block(name="rjust.nopad");
    done_bb = func.append_basic_block(name="rjust.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);
    b.position_at_start(pad_bb);
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="rjust.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="rjust.buf");
    pad_len = b.sub(width, slen, name="rjust.pad.len");
    b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 32), pad_len]);
    str_dst = b.gep(buf_pad, [pad_len], name="rjust.str.dst");
    b.call(memcpy_fn, [str_dst, target, slen]);
    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);
    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="rjust.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="rjust.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="rjust.result");
    result.add_incoming(buf_pad, pad_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_zfill(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i8p = i8.as_pointer();
    i64 = ir.IntType(64);
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    memset_fn = p._get_or_declare_extern("memset", i8p, [i8p, ir.IntType(32), i64]);
    slen = p._call_str_len(b, target, name="zfill.len");
    width = args[0];
    needs_pad = b.icmp_unsigned("<", slen, width, name="zfill.needspad");
    func = b.basic_block.function;
    pad_bb = func.append_basic_block(name="zfill.pad");
    nopad_bb = func.append_basic_block(name="zfill.nopad");
    done_bb = func.append_basic_block(name="zfill.done");
    b.cbranch(needs_pad, pad_bb, nopad_bb);

    b.position_at_start(pad_bb);
    alloc_pad = b.add(width, ir.Constant(i64, 1), name="zfill.alloc");
    buf_pad = p._str_alloc(b, alloc_pad, name="zfill.buf");
    first_ch = b.load(target, name="zfill.first");
    is_plus = b.icmp_unsigned("==", first_ch, ir.Constant(i8, 43), name="zfill.plus");
    is_minus = b.icmp_unsigned("==", first_ch, ir.Constant(i8, 45), name="zfill.minus");
    has_sign = b.or_(is_plus, is_minus, name="zfill.hassign");
    pad_len = b.sub(width, slen, name="zfill.pad.len");

    sign_off = b.select(
        has_sign, ir.Constant(i64, 1), ir.Constant(i64, 0), name="zfill.soff"
    );

    sign_bb = func.append_basic_block(name="zfill.sign");
    nosign_bb = func.append_basic_block(name="zfill.nosign");
    merge_bb = func.append_basic_block(name="zfill.merge");
    b.cbranch(has_sign, sign_bb, nosign_bb);
    b.position_at_start(sign_bb);
    b.store(first_ch, buf_pad);
    b.call(
        memset_fn,
        [
            b.gep(buf_pad, [ir.Constant(i64, 1)], name="zfill.z1"),
            ir.Constant(ir.IntType(32), 48),
            pad_len
        ]
    );
    src_rest = b.gep(target, [ir.Constant(i64, 1)], name="zfill.src.rest");
    rest_len = b.sub(slen, ir.Constant(i64, 1), name="zfill.rest.len");
    dst_rest = b.gep(
        buf_pad,
        [b.add(pad_len, ir.Constant(i64, 1), name="zfill.doff")],
        name="zfill.dst.rest"
    );
    b.call(memcpy_fn, [dst_rest, src_rest, rest_len]);
    b.branch(merge_bb);
    b.position_at_start(nosign_bb);
    b.call(memset_fn, [buf_pad, ir.Constant(ir.IntType(32), 48), pad_len]);
    dst_nosign = b.gep(buf_pad, [pad_len], name="zfill.dst.ns");
    b.call(memcpy_fn, [dst_nosign, target, slen]);
    b.branch(merge_bb);
    b.position_at_start(merge_bb);
    p._str_finish(b, buf_pad, width);
    b.branch(done_bb);

    b.position_at_start(nopad_bb);
    alloc_nopad = b.add(slen, ir.Constant(i64, 1), name="zfill.alloc.np");
    buf_nopad = p._str_alloc(b, alloc_nopad, name="zfill.buf.np");
    b.call(memcpy_fn, [buf_nopad, target, slen]);
    p._str_finish(b, buf_nopad, slen);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i8p, name="zfill.result");
    result.add_incoming(buf_pad, merge_bb);
    result.add_incoming(buf_nopad, nopad_bb);
    return result;
}

impl NativeStrEmitter.emit_expandtabs(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    slen = p._call_str_len(b, target, name="et.len");

    if args {
        tabsize = args[0];
    } else {
        tabsize = ir.Constant(i64, 8);
    }

    ts_or_one = b.select(
        b.icmp_unsigned("==", tabsize, zero), one, tabsize, name="et.ts1"
    );
    worst = b.mul(slen, ts_or_one, name="et.worst");
    alloc_sz = b.add(worst, one, name="et.alloc");
    buf = p._str_alloc(b, alloc_sz, name="et.buf");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="et.loop");
    check_tab = func.append_basic_block(name="et.check.tab");
    do_tab = func.append_basic_block(name="et.do.tab");
    tab_loop = func.append_basic_block(name="et.tab.loop");
    tab_write = func.append_basic_block(name="et.tab.write");
    tab_done = func.append_basic_block(name="et.tab.done");
    check_nl = func.append_basic_block(name="et.check.nl");
    do_nl = func.append_basic_block(name="et.do.nl");
    do_char = func.append_basic_block(name="et.do.char");
    next_bb = func.append_basic_block(name="et.next");
    done_bb = func.append_basic_block(name="et.done");
    b.branch(loop_bb);

    b.position_at_start(loop_bb);
    si = b.phi(i64, name="et.si");
    di = b.phi(i64, name="et.di");
    col = b.phi(i64, name="et.col");
    si.add_incoming(zero, entry_bb);
    di.add_incoming(zero, entry_bb);
    col.add_incoming(zero, entry_bb);

    cp = b.gep(target, [si], name="et.cp");
    ch = b.load(cp, name="et.ch");
    is_end = b.icmp_unsigned("==", ch, ir.Constant(i8, 0), name="et.end");
    b.cbranch(is_end, done_bb, check_tab);

    b.position_at_start(check_tab);
    is_tab = b.icmp_unsigned("==", ch, ir.Constant(i8, 9), name="et.istab");
    b.cbranch(is_tab, do_tab, check_nl);

    b.position_at_start(do_tab);
    is_ts_zero = b.icmp_unsigned("==", tabsize, zero, name="et.ts0");

    col_mod = b.urem(col, ts_or_one, name="et.colmod");
    spaces_calc = b.sub(tabsize, col_mod, name="et.spcalc");
    spaces = b.select(is_ts_zero, zero, spaces_calc, name="et.spaces");
    b.branch(tab_loop);

    b.position_at_start(tab_loop);
    ti = b.phi(i64, name="et.ti");
    di_t = b.phi(i64, name="et.di.t");
    ti.add_incoming(zero, do_tab);
    di_t.add_incoming(di, do_tab);
    ti_done = b.icmp_unsigned(">=", ti, spaces, name="et.tidone");
    b.cbranch(ti_done, tab_done, tab_write);

    b.position_at_start(tab_write);
    dp = b.gep(buf, [di_t], name="et.dp.tw");
    b.store(ir.Constant(i8, 32), dp);
    next_ti = b.add(ti, one, name="et.nti");
    next_di_t = b.add(di_t, one, name="et.ndi.t");
    ti.add_incoming(next_ti, tab_write);
    di_t.add_incoming(next_di_t, tab_write);
    b.branch(tab_loop);

    b.position_at_start(tab_done);
    new_col_tab = b.add(col, spaces, name="et.col.tab");
    next_si_tab = b.add(si, one, name="et.si.tab");
    b.branch(next_bb);

    b.position_at_start(check_nl);
    is_nl = b.icmp_unsigned("==", ch, ir.Constant(i8, 10), name="et.isnl");
    is_cr = b.icmp_unsigned("==", ch, ir.Constant(i8, 13), name="et.iscr");
    is_line_end = b.or_(is_nl, is_cr, name="et.isle");
    b.cbranch(is_line_end, do_nl, do_char);

    b.position_at_start(do_nl);
    dp_nl = b.gep(buf, [di], name="et.dp.nl");
    b.store(ch, dp_nl);
    next_di_nl = b.add(di, one, name="et.ndi.nl");
    next_si_nl = b.add(si, one, name="et.si.nl");
    b.branch(next_bb);

    b.position_at_start(do_char);
    dp_ch = b.gep(buf, [di], name="et.dp.ch");
    b.store(ch, dp_ch);
    next_di_ch = b.add(di, one, name="et.ndi.ch");
    next_col_ch = b.add(col, one, name="et.col.ch");
    next_si_ch = b.add(si, one, name="et.si.ch");
    b.branch(next_bb);

    b.position_at_start(next_bb);
    new_si = b.phi(i64, name="et.new.si");
    new_di = b.phi(i64, name="et.new.di");
    new_col = b.phi(i64, name="et.new.col");
    new_si.add_incoming(next_si_tab, tab_done);
    new_si.add_incoming(next_si_nl, do_nl);
    new_si.add_incoming(next_si_ch, do_char);
    new_di.add_incoming(di_t, tab_done);
    new_di.add_incoming(next_di_nl, do_nl);
    new_di.add_incoming(next_di_ch, do_char);
    new_col.add_incoming(new_col_tab, tab_done);
    new_col.add_incoming(zero, do_nl);
    new_col.add_incoming(next_col_ch, do_char);
    b.branch(loop_bb);
    si.add_incoming(new_si, next_bb);
    di.add_incoming(new_di, next_bb);
    col.add_incoming(new_col, next_bb);

    b.position_at_start(done_bb);
    done_di = b.phi(i64, name="et.done.di");
    done_di.add_incoming(di, loop_bb);
    p._str_finish(b, buf, done_di);
    return buf;
}

impl NativeStrEmitter._emit_char_test(
    self: NativeStrEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    cfunc_name: str,
    prefix: str,
    empty_is_true: bool = False
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    test_fn = p._get_or_declare_extern(cfunc_name, i32, [i32]);
    slen = p._call_str_len(b, target, name=f"{prefix}.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name=f"{prefix}.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name=f"{prefix}.loop");
    body_bb = func.append_basic_block(name=f"{prefix}.body");
    fail_bb = func.append_basic_block(name=f"{prefix}.fail");
    pass_bb = func.append_basic_block(name=f"{prefix}.pass");
    done_bb = func.append_basic_block(name=f"{prefix}.done");
    if empty_is_true {
        b.cbranch(is_empty, pass_bb, loop_bb);
    } else {
        b.cbranch(is_empty, fail_bb, loop_bb);
    }
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name=f"{prefix}.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name=f"{prefix}.atend");
    b.cbranch(at_end, pass_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name=f"{prefix}.ch.ptr");
    ch = b.load(ch_ptr, name=f"{prefix}.ch");
    ch_i32 = b.zext(ch, i32, name=f"{prefix}.ch.i32");
    result = b.call(test_fn, [ch_i32], name=f"{prefix}.test");
    is_ok = b.icmp_signed("!=", result, ir.Constant(i32, 0), name=f"{prefix}.ok");
    next_idx = b.add(idx, ir.Constant(i64, 1), name=f"{prefix}.next");
    idx.add_incoming(next_idx, body_bb);
    b.cbranch(is_ok, loop_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(pass_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name=f"{prefix}.final");
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    result_phi.add_incoming(ir.Constant(i64, 1), pass_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isalnum(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isalnum", "isalnum");
}

impl NativeStrEmitter.emit_isalpha(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isalpha", "isalpha");
}

impl NativeStrEmitter.emit_isascii(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    slen = p._call_str_len(b, target, name="isascii.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="isascii.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="isascii.loop");
    body_bb = func.append_basic_block(name="isascii.body");
    fail_bb = func.append_basic_block(name="isascii.fail");
    pass_bb = func.append_basic_block(name="isascii.pass");
    done_bb = func.append_basic_block(name="isascii.done");
    b.cbranch(is_empty, pass_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="isascii.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="isascii.atend");
    b.cbranch(at_end, pass_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="isascii.ch.ptr");
    ch = b.load(ch_ptr, name="isascii.ch");
    ch_ext = b.zext(ch, i64, name="isascii.ch.ext");
    is_ok = b.icmp_unsigned("<", ch_ext, ir.Constant(i64, 128), name="isascii.ok");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="isascii.next");
    idx.add_incoming(next_idx, body_bb);
    b.cbranch(is_ok, loop_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(pass_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="isascii.final");
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    result_phi.add_incoming(ir.Constant(i64, 1), pass_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isdecimal(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isdigit", "isdecimal");
}

impl NativeStrEmitter.emit_isdigit(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isdigit", "isdigit");
}

impl NativeStrEmitter.emit_isidentifier(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    isalnum_fn = p._get_or_declare_extern("isalnum", i32, [i32]);
    slen = p._call_str_len(b, target, name="isid.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="isid.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    first_bb = func.append_basic_block(name="isid.first");
    loop_bb = func.append_basic_block(name="isid.loop");
    body_bb = func.append_basic_block(name="isid.body");
    fail_bb = func.append_basic_block(name="isid.fail");
    pass_bb = func.append_basic_block(name="isid.pass");
    done_bb = func.append_basic_block(name="isid.done");
    b.cbranch(is_empty, fail_bb, first_bb);

    b.position_at_start(first_bb);
    first_ch = b.load(target, name="isid.first.ch");
    first_i32 = b.zext(first_ch, i32, name="isid.first.i32");
    is_alpha = b.call(isalpha_fn, [first_i32], name="isid.first.alpha");
    is_alpha_ok = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="isid.first.aok"
    );
    is_underscore = b.icmp_unsigned(
        "==", first_ch, ir.Constant(i8, 95), name="isid.first.under"
    );
    first_ok = b.or_(is_alpha_ok, is_underscore, name="isid.first.ok");
    b.cbranch(first_ok, loop_bb, fail_bb);

    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="isid.idx");
    idx.add_incoming(ir.Constant(i64, 1), first_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="isid.atend");
    b.cbranch(at_end, pass_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="isid.ch.ptr");
    ch = b.load(ch_ptr, name="isid.ch");
    ch_i32 = b.zext(ch, i32, name="isid.ch.i32");
    is_an = b.call(isalnum_fn, [ch_i32], name="isid.isalnum");
    is_an_ok = b.icmp_signed("!=", is_an, ir.Constant(i32, 0), name="isid.an.ok");
    is_under = b.icmp_unsigned("==", ch, ir.Constant(i8, 95), name="isid.under");
    ch_ok = b.or_(is_an_ok, is_under, name="isid.ch.ok");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="isid.next");
    idx.add_incoming(next_idx, body_bb);
    b.cbranch(ch_ok, loop_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(pass_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="isid.final");
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    result_phi.add_incoming(ir.Constant(i64, 1), pass_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_islower(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="islower.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="islower.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="islower.loop");
    body_bb = func.append_basic_block(name="islower.body");
    fail_bb = func.append_basic_block(name="islower.fail");
    check_bb = func.append_basic_block(name="islower.check");
    done_bb = func.append_basic_block(name="islower.done");
    b.cbranch(is_empty, fail_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="islower.idx");
    has_cased = b.phi(i64, name="islower.hascased");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    has_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="islower.atend");
    b.cbranch(at_end, check_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="islower.ch.ptr");
    ch = b.load(ch_ptr, name="islower.ch");
    ch_i32 = b.zext(ch, i32, name="islower.ch.i32");
    is_upper = b.call(isupper_fn, [ch_i32], name="islower.isupper");
    is_upper_bool = b.icmp_signed(
        "!=", is_upper, ir.Constant(i32, 0), name="islower.isup"
    );
    next_idx = b.add(idx, ir.Constant(i64, 1), name="islower.next");
    is_alpha = b.call(isalpha_fn, [ch_i32], name="islower.isalpha");
    is_alpha_bool = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="islower.isalp"
    );
    new_cased = b.select(
        is_alpha_bool, ir.Constant(i64, 1), has_cased, name="islower.newcased"
    );
    idx.add_incoming(next_idx, body_bb);
    has_cased.add_incoming(new_cased, body_bb);
    b.cbranch(is_upper_bool, fail_bb, loop_bb);
    b.position_at_start(check_bb);
    has_any = b.icmp_unsigned(
        "!=", has_cased, ir.Constant(i64, 0), name="islower.hasany"
    );
    b.cbranch(has_any, done_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="islower.final");
    result_phi.add_incoming(ir.Constant(i64, 1), check_bb);
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isnumeric(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isdigit", "isnumeric");
}

impl NativeStrEmitter.emit_isprintable(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(
        ctx, target, "isprint", "isprintable", empty_is_true=True
    );
}

impl NativeStrEmitter.emit_isspace(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return self._emit_char_test(ctx, target, "isspace", "isspace");
}

impl NativeStrEmitter.emit_istitle(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    isupper_fn = p._get_or_declare_extern("isupper", i32, [i32]);
    islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="istitle.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="istitle.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="istitle.loop");
    body_bb = func.append_basic_block(name="istitle.body");
    fail_bb = func.append_basic_block(name="istitle.fail");
    check_bb = func.append_basic_block(name="istitle.check");
    done_bb = func.append_basic_block(name="istitle.done");
    b.cbranch(is_empty, fail_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="istitle.idx");
    prev_cased = b.phi(i64, name="istitle.prevcased");
    has_cased = b.phi(i64, name="istitle.hascased");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    prev_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    has_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="istitle.atend");
    b.cbranch(at_end, check_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="istitle.ch.ptr");
    ch = b.load(ch_ptr, name="istitle.ch");
    ch_i32 = b.zext(ch, i32, name="istitle.ch.i32");
    is_up = b.call(isupper_fn, [ch_i32], name="istitle.isup");
    is_up_bool = b.icmp_signed("!=", is_up, ir.Constant(i32, 0), name="istitle.upbool");
    is_lo = b.call(islower_fn, [ch_i32], name="istitle.islo");
    is_lo_bool = b.icmp_signed("!=", is_lo, ir.Constant(i32, 0), name="istitle.lobool");
    is_al = b.call(isalpha_fn, [ch_i32], name="istitle.isal");
    is_al_bool = b.icmp_signed("!=", is_al, ir.Constant(i32, 0), name="istitle.albool");
    prev_was_cased = b.icmp_unsigned(
        "!=", prev_cased, ir.Constant(i64, 0), name="istitle.pwc"
    );
    upper_after_cased = b.and_(is_up_bool, prev_was_cased, name="istitle.uac");
    not_prev_cased = b.not_(prev_was_cased, name="istitle.npc");
    lower_after_noncased = b.and_(is_lo_bool, not_prev_cased, name="istitle.lanc");
    bad = b.or_(upper_after_cased, lower_after_noncased, name="istitle.bad");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="istitle.next");
    new_prev = b.select(
        is_al_bool, ir.Constant(i64, 1), ir.Constant(i64, 0), name="istitle.newprev"
    );
    new_has = b.select(
        is_al_bool, ir.Constant(i64, 1), has_cased, name="istitle.newhas"
    );
    idx.add_incoming(next_idx, body_bb);
    prev_cased.add_incoming(new_prev, body_bb);
    has_cased.add_incoming(new_has, body_bb);
    b.cbranch(bad, fail_bb, loop_bb);
    b.position_at_start(check_bb);
    has_any = b.icmp_unsigned(
        "!=", has_cased, ir.Constant(i64, 0), name="istitle.hasany"
    );
    b.cbranch(has_any, done_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="istitle.final");
    result_phi.add_incoming(ir.Constant(i64, 1), check_bb);
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_isupper(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    islower_fn = p._get_or_declare_extern("islower", i32, [i32]);
    isalpha_fn = p._get_or_declare_extern("isalpha", i32, [i32]);
    slen = p._call_str_len(b, target, name="isupper.len");
    is_empty = b.icmp_unsigned("==", slen, ir.Constant(i64, 0), name="isupper.empty");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="isupper.loop");
    body_bb = func.append_basic_block(name="isupper.body");
    fail_bb = func.append_basic_block(name="isupper.fail");
    check_bb = func.append_basic_block(name="isupper.check");
    done_bb = func.append_basic_block(name="isupper.done");
    b.cbranch(is_empty, fail_bb, loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="isupper.idx");
    has_cased = b.phi(i64, name="isupper.hascased");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    has_cased.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, slen, name="isupper.atend");
    b.cbranch(at_end, check_bb, body_bb);
    b.position_at_start(body_bb);
    ch_ptr = b.gep(target, [idx], name="isupper.ch.ptr");
    ch = b.load(ch_ptr, name="isupper.ch");
    ch_i32 = b.zext(ch, i32, name="isupper.ch.i32");
    is_low = b.call(islower_fn, [ch_i32], name="isupper.islow");
    is_low_bool = b.icmp_signed("!=", is_low, ir.Constant(i32, 0), name="isupper.islo");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="isupper.next");
    is_alpha = b.call(isalpha_fn, [ch_i32], name="isupper.isalpha");
    is_alpha_bool = b.icmp_signed(
        "!=", is_alpha, ir.Constant(i32, 0), name="isupper.isalp"
    );
    new_cased = b.select(
        is_alpha_bool, ir.Constant(i64, 1), has_cased, name="isupper.newcased"
    );
    idx.add_incoming(next_idx, body_bb);
    has_cased.add_incoming(new_cased, body_bb);
    b.cbranch(is_low_bool, fail_bb, loop_bb);
    b.position_at_start(check_bb);
    has_any = b.icmp_unsigned(
        "!=", has_cased, ir.Constant(i64, 0), name="isupper.hasany"
    );
    b.cbranch(has_any, done_bb, fail_bb);
    b.position_at_start(fail_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result_phi = b.phi(i64, name="isupper.final");
    result_phi.add_incoming(ir.Constant(i64, 1), check_bb);
    result_phi.add_incoming(ir.Constant(i64, 0), fail_bb);
    return result_phi;
}

impl NativeStrEmitter.emit_encode(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    n = p._call_str_len(b, target, name="enc.len");
    return p._bytes_from_raw(target, n);
}

impl NativeStrEmitter.emit_decode(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return target;
}

impl NativeStrEmitter.emit_translate(
    self: NativeStrEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeStrEmitter.emit_maketrans(
    self: NativeStrEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_decode(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    n = p._bytes_len_val(target);
    alloc_sz = b.add(n, ir.Constant(i64, 1), name="dec.alloc");
    p._set_rc_ctx("bytes_decode", "");
    new_str = p._str_alloc(b, alloc_sz, name="dec.str");
    p._clear_rc_ctx();
    memcpy_fn = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    b.call(memcpy_fn, [new_str, p._bytes_data_ptr(target), n]);
    dec_end = b.gep(new_str, [n], name="dec.end");
    b.store(ir.Constant(ir.IntType(8), 0), dec_end);

    p._stamp_str_len(b, new_str, n);
    p._mark_owned(new_str);
    return new_str;
}

impl NativeBytesEmitter.emit_hex(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_fromhex(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_count(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_find(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rfind(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_index(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rindex(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_startswith(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_endswith(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_replace(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_strip(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_lstrip(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rstrip(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_removeprefix(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_removesuffix(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_split(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rsplit(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_splitlines(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_join(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_partition(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rpartition(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_capitalize(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_lower(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_upper(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_title(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_swapcase(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isalnum(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isalpha(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isascii(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isdigit(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_islower(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isspace(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_istitle(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_isupper(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_center(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_ljust(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_rjust(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_zfill(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_expandtabs(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_translate(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeBytesEmitter.emit_maketrans(
    self: NativeBytesEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}
