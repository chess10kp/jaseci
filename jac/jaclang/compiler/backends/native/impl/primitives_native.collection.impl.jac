import from jaclang.compiler.frontend.diagnostics { E5092 }


glob SORT_KEY_MSG: str = "comparison requires orderable key values (int, float, bool, str, bytes, tuple, list, set, or frozenset)";

impl NativeListEmitter.emit_append(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or not args {
        return None;
    }

    _boxed_val = p._box_value_tuple(args[0]);
    if p._reject_ptr_into_raw_slot(
        None, _boxed_val, helpers["elem_type"], "list append"
    ) {
        return ir.Constant(ir.IntType(64), 0);
    }
    val = p._coerce_type(_boxed_val, helpers["elem_type"]);

    _append_loc = getattr(args[0], 'jac_loc', "");
    p._rc_call_with_ctx(helpers["append"], [target, val], op="append", loc=_append_loc);

    if isinstance(_boxed_val.type, ir.PointerType)
        and p._is_owned(_boxed_val)
        and not p._nogc_headerless() {
        p._emit_rc_release_simple(_boxed_val, op="append", loc=_append_loc);
    }
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeListEmitter.emit_extend(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    src = args[0];
    if p._opt_payload_of(src.type) is not None {
        src = p._coerce_type(src, target.type);
    }
    if not isinstance(src.type, ir.PointerType) or src.type.is_opaque {
        return None;
    }
    if not isinstance(src.type.pointee, ir.BaseStructType) {
        src = p._coerce_type(src, target.type);
        if not isinstance(src.type, ir.PointerType)
            or src.type.is_opaque
            or not isinstance(src.type.pointee, ir.BaseStructType) {
            return None;
        }
    }
    src_len_ptr = b.gep(
        src, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ext.src.len.ptr"
    );
    src_len = b.load(src_len_ptr, name="ext.src.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="ext.loop");
    body_bb = func.append_basic_block(name="ext.body");
    done_bb = func.append_basic_block(name="ext.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="ext.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, src_len, name="ext.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    src_helpers = helpers;
    if src.type != target.type {
        for (_sk, _sty) in p.list_types.items() {
            if src.type == _sty.as_pointer() {
                _sh = p.list_helpers.get(_sk);
                if _sh is not None {
                    src_helpers = _sh;
                }
                break;
            }
        }
    }
    elem: ir.Value = b.call(src_helpers["get"], [src, idx], name="ext.elem");
    if elem.type != helpers["elem_type"] {
        elem = p._coerce_type(elem, helpers["elem_type"]);
    }
    _aos_struct = p._aos_elem_struct(ctx.type_key);
    b.call(
        helpers["push"] if _aos_struct is not None else helpers["append"],
        [target, elem]
    );
    next_idx = b.add(idx, ir.Constant(i64, 1), name="ext.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    if _aos_struct is not None and src_helpers is helpers {
        b.store(ir.Constant(i64, 0), src_len_ptr);
    }
    p._release_owned_args(args, op="extend_arg");
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_insert(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if len(args) < 2 {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    insert_idx = args[0];
    if p._reject_ptr_into_raw_slot(
        None, args[1], helpers["elem_type"], "list insert"
    ) {
        return ir.Constant(i64, 0);
    }
    insert_val = p._coerce_type(args[1], helpers["elem_type"]);
    _aos_struct = p._aos_elem_struct(ctx.type_key);
    if _aos_struct is not None {
        return self._emit_aos_insert(
            ctx, target, p._coerce_type(insert_idx, i64), insert_val, _aos_struct
        );
    }

    b.call(helpers["append"], [target, insert_val]);

    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ins.len.ptr"
    );
    new_len = b.load(len_ptr, name="ins.newlen");
    last_idx = b.sub(new_len, ir.Constant(i64, 1), name="ins.last");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="ins.loop");
    body_bb = func.append_basic_block(name="ins.body");
    done_bb = func.append_basic_block(name="ins.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    si = b.phi(i64, name="ins.si");
    si.add_incoming(last_idx, entry_bb);
    at_pos = b.icmp_signed("<=", si, insert_idx, name="ins.atpos");
    b.cbranch(at_pos, done_bb, body_bb);
    b.position_at_start(body_bb);
    prev = b.sub(si, ir.Constant(i64, 1), name="ins.prev");
    prev_val = b.call(helpers["get"], [target, prev], name="ins.pval");
    b.call(helpers["set"], [target, si, prev_val]);
    si.add_incoming(prev, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);

    b.call(helpers["set"], [target, insert_idx, insert_val]);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_remove(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    if p._aos_elem_struct(ctx.type_key) is not None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rem.len.ptr"
    );
    list_len = b.load(len_ptr, name="rem.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    find_bb = func.append_basic_block(name="rem.find");
    find_body = func.append_basic_block(name="rem.find.body");
    found_bb = func.append_basic_block(name="rem.found");
    shift_bb = func.append_basic_block(name="rem.shift");
    shift_body = func.append_basic_block(name="rem.shift.body");
    done_bb = func.append_basic_block(name="rem.done");
    b.branch(find_bb);

    b.position_at_start(find_bb);
    fi = b.phi(i64, name="rem.fi");
    fi.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", fi, list_len, name="rem.atend");
    b.cbranch(at_end, done_bb, find_body);
    b.position_at_start(find_body);
    elem = b.call(helpers["get"], [target, fi], name="rem.elem");
    eq = b.icmp_signed("==", elem, search_val, name="rem.eq");
    next_fi = b.add(fi, ir.Constant(i64, 1), name="rem.nextfi");
    fi.add_incoming(next_fi, find_body);
    b.cbranch(eq, found_bb, find_bb);

    b.position_at_start(found_bb);

    if isinstance(helpers["elem_type"], ir.PointerType) {
        if p.rc_release_simple_fn is None {
            p._emit_rc_helpers();
        }
        _i8p_lr = ir.IntType(8).as_pointer();
        _lr_elem = b.call(helpers["get"], [target, fi], name="rem_rel_elem");
        _lr_cast = b.bitcast(_lr_elem, _i8p_lr, name="rem_rel_cast");
        b.call(p.rc_release_simple_fn, [_lr_cast]);
    }
    shift_start = b.add(fi, ir.Constant(i64, 1), name="rem.shstart");
    b.branch(shift_bb);
    b.position_at_start(shift_bb);
    si = b.phi(i64, name="rem.si");
    si.add_incoming(shift_start, found_bb);
    shift_end = b.icmp_unsigned(">=", si, list_len, name="rem.shend");
    b.cbranch(shift_end, done_bb, shift_body);
    b.position_at_start(shift_body);
    prev = b.sub(si, ir.Constant(i64, 1), name="rem.prev");
    if isinstance(helpers["elem_type"], ir.PointerType) {
        _sh_dpp = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="sh_dpp"
        );
        _sh_da = b.load(_sh_dpp, name="sh_da");
        _sh_src = b.gep(_sh_da, [si], name="sh_src");
        _sh_val = b.load(_sh_src, name="sh_val");
        _sh_dst = b.gep(_sh_da, [prev], name="sh_dst");
        b.store(_sh_val, _sh_dst);
    } else {
        val = b.call(helpers["get"], [target, si], name="rem.val");
        b.call(helpers["set"], [target, prev, val]);
    }
    next_si = b.add(si, ir.Constant(i64, 1), name="rem.nextsi");
    si.add_incoming(next_si, shift_body);
    b.branch(shift_bb);

    b.position_at_start(done_bb);

    found_phi = b.phi(i64, name="rem.found");
    found_phi.add_incoming(ir.Constant(i64, 0), find_bb);
    found_phi.add_incoming(ir.Constant(i64, 1), shift_bb);
    was_found = b.icmp_unsigned(
        "!=", found_phi, ir.Constant(i64, 0), name="rem.wasfound"
    );
    new_len = b.sub(list_len, ir.Constant(i64, 1), name="rem.newlen");
    final_len = b.select(was_found, new_len, list_len, name="rem.finallen");
    b.store(final_len, len_ptr);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_pop(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pop.len.ptr"
    );
    cur_len = b.load(len_ptr, name="pop.len");
    new_len = b.sub(cur_len, ir.Constant(i64, 1), name="pop.newlen");

    pop_idx = new_len;
    if args {
        raw_idx = p._coerce_type(args[0], i64);
        is_neg = b.icmp_signed("<", raw_idx, ir.Constant(i64, 0), name="pop.idx.neg");
        adj_idx = b.add(raw_idx, cur_len, name="pop.idx.adj");
        pop_idx = b.select(is_neg, adj_idx, raw_idx, name="pop.idx");
    }
    _aos_struct = p._aos_elem_struct(ctx.type_key);
    if _aos_struct is not None {
        return self._emit_aos_pop(ctx, target, args, _aos_struct);
    }
    popped = b.call(helpers["get"], [target, pop_idx], name="pop.val");

    is_ptr = p._elem_kind(helpers["elem_type"]) != "raw";
    func = b.basic_block.function;
    shift_start = b.add(pop_idx, ir.Constant(i64, 1), name="pop.shstart");
    shift_bb = func.append_basic_block(name="pop.shift");
    shift_body = func.append_basic_block(name="pop.shift.body");
    done_bb = func.append_basic_block(name="pop.shift.done");
    entry_bb = b.basic_block;
    b.branch(shift_bb);
    b.position_at_start(shift_bb);
    si = b.phi(i64, name="pop.si");
    si.add_incoming(shift_start, entry_bb);
    at_end = b.icmp_unsigned(">=", si, cur_len, name="pop.shend");
    b.cbranch(at_end, done_bb, shift_body);
    b.position_at_start(shift_body);
    prev = b.sub(si, ir.Constant(i64, 1), name="pop.prev");
    if is_ptr {
        _dpp = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="pop.dpp"
        );
        _da = b.load(_dpp, name="pop.da");
        _src = b.gep(_da, [si], name="pop.src");
        _val = b.load(_src, name="pop.shval");
        _dst = b.gep(_da, [prev], name="pop.dst");
        b.store(_val, _dst);
    } else {
        _v = b.call(helpers["get"], [target, si], name="pop.shval");
        b.call(helpers["set"], [target, prev, _v]);
    }
    next_si = b.add(si, ir.Constant(i64, 1), name="pop.nextsi");
    si.add_incoming(next_si, shift_body);
    b.branch(shift_bb);
    b.position_at_start(done_bb);
    b.store(new_len, len_ptr);
    if is_ptr {
        p._mark_owned(popped);
    }
    return popped;
}

impl NativeListEmitter.emit_clear(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    helpers = p.list_helpers.get(ctx.type_key);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="clear.len.ptr"
    );

    if helpers is not None
        and p._elem_kind(helpers["elem_type"]) != "raw"
        and not p._nogc_headerless() {
        _cur_len_c = b.load(len_ptr, name="clr_len");
        _data_pp_c = b.gep(
            target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="clr_data_pp"
        );
        _data_arr_c = b.load(_data_pp_c, name="clr_data");
        _func_c = b.basic_block.function;
        _clr_loop_bb = _func_c.append_basic_block("clr_loop");
        _clr_body_bb = _func_c.append_basic_block("clr_body");
        _clr_end_bb = _func_c.append_basic_block("clr_end");
        _clr_i_a = p._entry_alloca(i64, "clr_i");
        b.store(ir.Constant(i64, 0), _clr_i_a);
        b.branch(_clr_loop_bb);

        p.builder.position_at_end(_clr_loop_bb);
        b = p.builder;
        _li_c = b.load(_clr_i_a, name="clr_li");
        _clr_cmp = b.icmp_unsigned(">=", _li_c, _cur_len_c, name="clr_done");
        b.cbranch(_clr_cmp, _clr_end_bb, _clr_body_bb);

        p.builder.position_at_end(_clr_body_bb);
        b = p.builder;
        _li2_c = b.load(_clr_i_a, name="clr_li2");
        _ep_c = b.gep(_data_arr_c, [_li2_c], name="clr_ep");
        _ev_c = b.load(_ep_c, name="clr_ev");
        p._emit_elem_release(b, helpers["elem_type"], _ev_c);
        _li3_c = b.load(_clr_i_a, name="clr_li3");
        _ni_c = b.add(_li3_c, ir.Constant(i64, 1), name="clr_ni");
        b.store(_ni_c, _clr_i_a);
        b.branch(_clr_loop_bb);

        p.builder.position_at_end(_clr_end_bb);
        b = p.builder;
    }
    b.store(ir.Constant(i64, 0), len_ptr);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_index(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="idx.len.ptr"
    );
    list_len = b.load(len_ptr, name="idx.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="idx.loop");
    check_bb = func.append_basic_block(name="idx.check");
    found_bb = func.append_basic_block(name="idx.found");
    done_bb = func.append_basic_block(name="idx.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="idx.i");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="idx.atend");
    b.cbranch(at_end, done_bb, check_bb);
    b.position_at_start(check_bb);
    elem = b.call(helpers["get"], [target, idx], name="idx.elem");
    eq = b.icmp_signed("==", elem, search_val, name="idx.eq");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="idx.next");
    b.cbranch(eq, found_bb, loop_bb);
    idx.add_incoming(next_idx, check_bb);
    b.position_at_start(found_bb);
    b.branch(done_bb);
    b.position_at_start(done_bb);
    result = b.phi(i64, name="idx.result");
    result.add_incoming(ir.Constant(i64, -1), loop_bb);
    result.add_incoming(idx, found_bb);

    miss = b.icmp_signed("==", result, ir.Constant(i64, -1), name="idx.miss");
    p._emit_runtime_raise(miss, "ValueError", "list.index(x): x not in list");
    return result;
}

impl NativeListEmitter.emit_count(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    i32 = ir.IntType(32);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="cnt.len.ptr"
    );
    list_len = b.load(len_ptr, name="cnt.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="cnt.loop");
    body_bb = func.append_basic_block(name="cnt.body");
    inc_bb = func.append_basic_block(name="cnt.inc");
    done_bb = func.append_basic_block(name="cnt.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="cnt.idx");
    count = b.phi(i64, name="cnt.count");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    count.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, list_len, name="cnt.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [target, idx], name="cnt.elem");
    eq = b.icmp_signed("==", elem, search_val, name="cnt.eq");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="cnt.next");
    b.cbranch(eq, inc_bb, loop_bb);
    idx.add_incoming(next_idx, body_bb);
    count.add_incoming(count, body_bb);
    b.position_at_start(inc_bb);
    new_count = b.add(count, ir.Constant(i64, 1), name="cnt.inc");
    next_idx2 = b.add(idx, ir.Constant(i64, 1), name="cnt.next2");
    idx.add_incoming(next_idx2, inc_bb);
    count.add_incoming(new_count, inc_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return count;
}

impl NativeListEmitter.emit_sort(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None or p._elem_kind(helpers["elem_type"]) == "jacval" {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    elem_type = helpers["elem_type"];

    _kw: dict[str, UniNode] = ctx?.call_kwargs or {};
    _key_node = _kw.get("key");
    _rev_node = _kw.get("reverse");
    _unknown_kw = [
        k
        for k in _kw.keys()
        if k not in ("key", "reverse")
    ];
    if _unknown_kw {
        p.ctx.emit(
            E5092,
            node_override=_key_node or _rev_node,
            kind="sort keyword argument",
            name=", ".join(_unknown_kw)
        );
        return None;
    }
    key_fn: (ir.Function | None) = None;
    if _key_node is not None {
        _key_val = p._codegen_expr(_key_node);
        _key_caps = p._pending_lambda_captures;
        p._pending_lambda_captures = None;
        if (
            not isinstance(_key_val, ir.Function)
            or _key_caps is not None
            or len(_key_val.args) != 1
        ) {
            p.ctx.emit(
                E5092,
                node_override=_key_node,
                kind="sort key",
                name="key= (only a capture-free single-parameter lambda works)"
            );
            return None;
        }
        key_fn = _key_val;
    }
    rev_i1: (ir.Value | None) = None;
    if _rev_node is not None {
        _rev_val = p._codegen_expr(_rev_node);
        if _rev_val is not None {
            rev_i1 = p._to_bool(_rev_val);
        }
    }
    if key_fn is None {
        return self._emit_value_sort(ctx, target, rev_i1);
    }
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="sort.len.ptr"
    );
    list_len = b.load(len_ptr, name="sort.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;

    outer_bb = func.append_basic_block(name="sort.outer");
    inner_start = func.append_basic_block(name="sort.inner.start");
    inner_bb = func.append_basic_block(name="sort.inner");
    inner_body = func.append_basic_block(name="sort.inner.body");
    swap_bb = func.append_basic_block(name="sort.swap");
    no_swap = func.append_basic_block(name="sort.noswap");
    inner_next = func.append_basic_block(name="sort.inner.next");
    outer_next = func.append_basic_block(name="sort.outer.next");
    done_bb = func.append_basic_block(name="sort.done");
    len_m1 = b.sub(list_len, one, name="sort.lenm1");
    trivial = b.icmp_unsigned("<=", list_len, one, name="sort.trivial");
    b.cbranch(trivial, done_bb, outer_bb);

    b.position_at_start(outer_bb);
    oi = b.phi(i64, name="sort.oi");
    oi.add_incoming(zero, entry_bb);
    outer_end = b.icmp_unsigned(">=", oi, len_m1, name="sort.oend");
    b.cbranch(outer_end, done_bb, inner_start);

    b.position_at_start(inner_start);
    inner_limit = b.sub(len_m1, oi, name="sort.ilimit");
    b.branch(inner_bb);

    b.position_at_start(inner_bb);
    ji = b.phi(i64, name="sort.ji");
    ji.add_incoming(zero, inner_start);
    inner_end = b.icmp_unsigned(">=", ji, inner_limit, name="sort.iend");
    b.cbranch(inner_end, outer_next, inner_body);

    b.position_at_start(inner_body);
    j1 = b.add(ji, one, name="sort.j1");
    ej = b.call(helpers["get"], [target, ji], name="sort.ej");
    ej1 = b.call(helpers["get"], [target, j1], name="sort.ej1");

    cj: ir.Value = ej;
    cj1: ir.Value = ej1;
    cmp_type = elem_type;
    if key_fn is not None {
        _kp_type = key_fn.args[0].type;
        cj = b.call(key_fn, [p._coerce_type(ej, _kp_type)], name="sort.kj");
        cj1 = b.call(key_fn, [p._coerce_type(ej1, _kp_type)], name="sort.kj1");
        cmp_type = key_fn.function_type.return_type;

        if cj.type != cmp_type {
            cmp_type = cj.type;
        }
    }

    cj = p._cast_to_list_elem(b, cj, cmp_type, "sort.cj");
    cj1 = p._cast_to_list_elem(b, cj1, cmp_type, "sort.cj1");
    _key_ret = p._sort_key_return_type(_key_node) if key_fn is not None else None;
    _key_orderable = p._sort_key_orderable(_key_ret);
    if _key_orderable is False
        or (_key_orderable is None and not p._sort_key_supported(cmp_type)) {
        p.ctx.emit(E5092, node_override=_key_node, kind="sort key", name=SORT_KEY_MSG);
        return None;
    }
    _cmp_float = isinstance(cmp_type, (ir.DoubleType, ir.FloatType));
    _cmp_unsigned = key_fn is not None and p._sort_key_unsigned(_key_node);
    if _cmp_float {
        (cj, cj1) = p._promote_to_float(cj, cj1, unsigned=_cmp_unsigned);
    }
    _sort_errs = len(p.ctx.errors_had);
    cmp_gt: (ir.Value | None) = p._emit_comparison(
        Tok.GT, cj, cj1, _cmp_float, unsigned=_cmp_unsigned, key_ret=_key_ret
    );
    cmp_lt: (ir.Value | None) = None;
    if cmp_gt is not None and rev_i1 is not None {
        cmp_lt = p._emit_comparison(
            Tok.LT, cj, cj1, _cmp_float, unsigned=_cmp_unsigned, key_ret=_key_ret
        );
    }
    if cmp_gt is None or (rev_i1 is not None and cmp_lt is None) {
        if key_fn is not None {
            p._release_owned_operands(cj, cj1, op="sort_key");
        }
        if len(p.ctx.errors_had) == _sort_errs {
            p.ctx.emit(
                E5092, node_override=_key_node, kind="sort key", name=SORT_KEY_MSG
            );
        }
        return None;
    }
    needs_swap = cmp_gt
        if rev_i1 is None
        else b.select(rev_i1, cmp_lt, cmp_gt, name="sort.dir");
    if key_fn is not None {
        p._release_owned_operands(cj, cj1, op="sort_key");
    }
    b.cbranch(needs_swap, swap_bb, no_swap);

    b.position_at_start(swap_bb);
    b.call(helpers["set"], [target, ji, ej1]);
    b.call(helpers["set"], [target, j1, ej]);
    b.branch(inner_next);
    b.position_at_start(no_swap);
    b.branch(inner_next);

    b.position_at_start(inner_next);
    next_ji = b.add(ji, one, name="sort.nji");
    ji.add_incoming(next_ji, inner_next);
    b.branch(inner_bb);

    b.position_at_start(outer_next);
    next_oi = b.add(oi, one, name="sort.noi");
    oi.add_incoming(next_oi, outer_next);
    b.branch(outer_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter._emit_value_sort(
    self: NativeListEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    reverse: (ir.Value | None)
) -> ir.Value {
    p = ctx.pass_ref;
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    zero = ir.Constant(i64, 0);
    one = ir.Constant(i64, 1);
    length = b.load(b.gep(target, [ir.Constant(i32, 0), ir.Constant(i32, 0)]));
    data = b.load(b.gep(target, [ir.Constant(i32, 0), ir.Constant(i32, 2)]));
    assert isinstance(data.type, ir.PointerType) and not data.type.is_opaque;
    elem_type = data.type.pointee;
    itemsize = p._abi_sizeof(elem_type);
    fn = b.basic_block.function;
    allocate = fn.append_basic_block("sort.allocate");
    outer = fn.append_basic_block("sort.merge.pass");
    pass_start = fn.append_basic_block("sort.merge.start");
    pair = fn.append_basic_block("sort.merge.pair");
    pair_start = fn.append_basic_block("sort.merge.pair.start");
    merge = fn.append_basic_block("sort.merge.item");
    left_check = fn.append_basic_block("sort.merge.left.check");
    right_check = fn.append_basic_block("sort.merge.right.check");
    compare = fn.append_basic_block("sort.merge.compare");
    take_left = fn.append_basic_block("sort.merge.left");
    take_right = fn.append_basic_block("sort.merge.right");
    advance = fn.append_basic_block("sort.merge.advance");
    pair_done = fn.append_basic_block("sort.merge.pair.done");
    pass_done = fn.append_basic_block("sort.merge.pass.done");
    publish = fn.append_basic_block("sort.publish");
    done = fn.append_basic_block("sort.done");
    width_slot = p._entry_alloca(i64, "sort.width");
    base_slot = p._entry_alloca(i64, "sort.base");
    left_slot = p._entry_alloca(i64, "sort.left");
    right_slot = p._entry_alloca(i64, "sort.right");
    output_slot = p._entry_alloca(i64, "sort.output");
    source_slot = p._entry_alloca(data.type, "sort.source");
    target_slot = p._entry_alloca(data.type, "sort.target");
    b.cbranch(b.icmp_unsigned("<=", length, one), done, allocate);
    b.position_at_start(allocate);
    too_large = b.icmp_unsigned(
        ">", length, ir.Constant(i64, 9223372036854775807 // (itemsize * 2))
    );
    p._emit_runtime_raise(too_large, "MemoryError", "sort workspace is too large");
    nbytes = b.mul(length, ir.Constant(i64, itemsize));
    malloc = p._get_or_declare_extern("malloc", i8p, [i64]);
    free = p._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    memcpy = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    raw = b.call(malloc, [b.mul(nbytes, ir.Constant(i64, 2))], name="sort.workspace");
    p._emit_runtime_raise(
        b.icmp_unsigned("==", raw, ir.Constant(i8p, None)),
        "MemoryError",
        "cannot allocate sort workspace"
    );
    first = b.bitcast(raw, data.type);
    second = b.gep(first, [length]);
    b.call(memcpy, [raw, b.bitcast(data, i8p), nbytes]);
    b.store(first, source_slot);
    b.store(second, target_slot);
    b.store(one, width_slot);
    b.branch(outer);
    b.position_at_start(outer);
    width = b.load(width_slot);
    b.cbranch(b.icmp_unsigned("<", width, length), pass_start, publish);
    b.position_at_start(pass_start);
    b.store(zero, base_slot);
    b.branch(pair);
    b.position_at_start(pair);
    base = b.load(base_slot);
    b.cbranch(b.icmp_unsigned("<", base, length), pair_start, pass_done);
    b.position_at_start(pair_start);
    middle_raw = b.add(base, width);
    middle = b.select(b.icmp_unsigned("<", middle_raw, length), middle_raw, length);
    end_raw = b.add(middle, width);
    end = b.select(b.icmp_unsigned("<", end_raw, length), end_raw, length);
    source = b.load(source_slot);
    destination = b.load(target_slot);
    b.store(base, left_slot);
    b.store(middle, right_slot);
    b.store(base, output_slot);
    b.branch(merge);
    b.position_at_start(merge);
    output = b.load(output_slot);
    b.cbranch(b.icmp_unsigned("<", output, end), left_check, pair_done);
    b.position_at_start(left_check);
    left = b.load(left_slot);
    right = b.load(right_slot);
    b.cbranch(b.icmp_unsigned(">=", left, middle), take_right, right_check);
    b.position_at_start(right_check);
    b.cbranch(b.icmp_unsigned(">=", right, end), take_left, compare);
    b.position_at_start(compare);
    a = b.load(b.gep(source, [left]));
    c = b.load(b.gep(source, [right]));
    if isinstance(elem_type, (ir.DoubleType, ir.FloatType)) {
        before = b.fcmp_ordered("<", c, a);
        after = b.fcmp_ordered("<", a, c);
    } elif isinstance(elem_type, ir.PointerType) {
        result = p._call_str_cmp(
            b, b.bitcast(a, i8p), b.bitcast(c, i8p), name="sort.compare"
        );
        before = b.icmp_signed(">", result, ir.Constant(i32, 0));
        after = b.icmp_signed("<", result, ir.Constant(i32, 0));
    } else {
        collection = ctx.receiver_node;
        if collection is None and ctx.arg_nodes {
            collection = ctx.arg_nodes[0];
        }
        elements = p._nogc_type_arg_mangles(collection);
        shape = p._scalar_shape_named(elements[0] if elements else ctx.type_key);
        unsigned = (elements and elements[0] == "bool")
            or (shape is not None and not shape.signed);
        before = b.icmp_unsigned("<", c, a) if unsigned else b.icmp_signed("<", c, a);
        after = b.icmp_unsigned("<", a, c) if unsigned else b.icmp_signed("<", a, c);
    }
    choose_right = before if reverse is None else b.select(reverse, after, before);
    b.cbranch(choose_right, take_right, take_left);
    b.position_at_start(take_left);
    b.store(b.load(b.gep(source, [left])), b.gep(destination, [output]));
    b.store(b.add(left, one), left_slot);
    b.branch(advance);
    b.position_at_start(take_right);
    b.store(b.load(b.gep(source, [right])), b.gep(destination, [output]));
    b.store(b.add(right, one), right_slot);
    b.branch(advance);
    b.position_at_start(advance);
    b.store(b.add(output, one), output_slot);
    b.branch(merge);
    b.position_at_start(pair_done);
    b.store(end, base_slot);
    b.branch(pair);
    b.position_at_start(pass_done);
    previous = b.load(source_slot);
    b.store(b.load(target_slot), source_slot);
    b.store(previous, target_slot);
    b.store(b.mul(width, ir.Constant(i64, 2)), width_slot);
    b.branch(outer);
    b.position_at_start(publish);
    b.call(memcpy, [b.bitcast(data, i8p), b.bitcast(b.load(source_slot), i8p), nbytes]);
    b.call(free, [raw]);
    b.branch(done);
    b.position_at_start(done);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_reverse(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="rev.len.ptr"
    );
    list_len = b.load(len_ptr, name="rev.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="rev.loop");
    body_bb = func.append_basic_block(name="rev.body");
    done_bb = func.append_basic_block(name="rev.done");
    j_init = b.sub(list_len, ir.Constant(i64, 1), name="rev.j.init");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    i_phi = b.phi(i64, name="rev.i");
    j_phi = b.phi(i64, name="rev.j");
    i_phi.add_incoming(ir.Constant(i64, 0), entry_bb);
    j_phi.add_incoming(j_init, entry_bb);
    cond = b.icmp_signed("<", i_phi, j_phi, name="rev.cond");
    b.cbranch(cond, body_bb, done_bb);
    b.position_at_start(body_bb);
    val_i = b.call(helpers["get"], [target, i_phi], name="rev.val.i");
    val_j = b.call(helpers["get"], [target, j_phi], name="rev.val.j");
    b.call(helpers["set"], [target, i_phi, val_j]);
    b.call(helpers["set"], [target, j_phi, val_i]);
    next_i = b.add(i_phi, ir.Constant(i64, 1), name="rev.next.i");
    next_j = b.sub(j_phi, ir.Constant(i64, 1), name="rev.next.j");
    i_phi.add_incoming(next_i, body_bb);
    j_phi.add_incoming(next_j, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter.emit_copy(
    self: NativeListEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.list_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    new_list = b.call(helpers["new"], [], name="copy.new");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="copy.len.ptr"
    );
    src_len = b.load(len_ptr, name="copy.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="copy.loop");
    body_bb = func.append_basic_block(name="copy.body");
    done_bb = func.append_basic_block(name="copy.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="copy.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, src_len, name="copy.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    elem = b.call(helpers["get"], [target, idx], name="copy.elem");
    b.call(helpers["append"], [new_list, elem]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="copy.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_get(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    key = p._coerce_type(args[0], helpers["key_type"]);
    found_i1 = b.call(helpers["contains"], [target, key], name="dget.found");
    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="dget.yes");
    notfound_bb = func.append_basic_block(name="dget.no");
    done_bb = func.append_basic_block(name="dget.done");
    b.cbranch(found_i1, found_bb, notfound_bb);

    val_type = helpers["val_type"];

    wrap_optional = (len(args) < 2) and (not isinstance(val_type, ir.PointerType));
    result_type = p._jac_optional_type(val_type) if wrap_optional else val_type;

    b.position_at_start(found_bb);
    val: ir.Value = b.call(helpers["get"], [target, key], name="dget.val");
    if wrap_optional {
        _tagged = b.insert_value(
            ir.Constant(result_type, None),
            ir.Constant(ir.IntType(8), 1),
            0,
            name="dget.some.tag"
        );
        val = b.insert_value(_tagged, val, 1, name="dget.some");
    }
    b.branch(done_bb);

    b.position_at_start(notfound_bb);
    if wrap_optional {
        default_val: ir.Value = ir.Constant(result_type, None);
    } elif len(args) >= 2 {
        default_val = p._coerce_type(args[1], val_type);
    } else {
        default_val = ir.Constant(val_type, None);
    }
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(result_type, name="dget.result");
    result.add_incoming(val, found_bb);
    result.add_incoming(default_val, notfound_bb);
    retained = b.extract_value(result, 1, name="dget.payload")
        if wrap_optional
        else result;
    p._emit_elem_retain(b, val_type, retained);
    p._release_owned_args(args, op="dict_get_arg");
    p._release_owned_args([target], op="dict_get_receiver");
    if p._elem_kind(val_type) != "raw" {
        p._mark_owned(result);
    }
    return result;
}

impl NativeDictEmitter.emit_keys(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    key_type = helpers["key_type"];
    if isinstance(key_type, ir.PointerType) {
        kt_name = "ptr";
        key_type = ir.IntType(8).as_pointer();
    } elif isinstance(key_type, ir.DoubleType) {
        kt_name = "f64";
    } else {
        kt_name = "i64";
    }
    p._emit_list_helpers(kt_name, key_type);
    lhelpers = p.list_helpers.get(kt_name);
    if lhelpers is None {
        return None;
    }
    new_list = b.call(lhelpers["new"], [], name="dkeys.list");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dkeys.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dkeys.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dkeys.loop");
    body_bb = func.append_basic_block(name="dkeys.body");
    done_bb = func.append_basic_block(name="dkeys.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dkeys.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="dkeys.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key: ir.Value = b.call(helpers["get_key"], [target, idx], name="dkeys.key");
    key = p._cast_to_list_elem(b, key, lhelpers["elem_type"], "dkeys.key");
    b.call(lhelpers["append"], [new_list, key]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dkeys.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_values(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);

    val_type = helpers["val_type"];
    if isinstance(val_type, ir.PointerType) {
        vt_name = "ptr";
        val_type = ir.IntType(8).as_pointer();
    } elif isinstance(val_type, ir.DoubleType) {
        vt_name = "f64";
    } else {
        vt_name = "i64";
    }
    p._emit_list_helpers(vt_name, val_type);
    lhelpers = p.list_helpers.get(vt_name);
    if lhelpers is None {
        return None;
    }
    new_list = b.call(lhelpers["new"], [], name="dvals.list");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dvals.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dvals.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dvals.loop");
    body_bb = func.append_basic_block(name="dvals.body");
    done_bb = func.append_basic_block(name="dvals.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dvals.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="dvals.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [target, idx], name="dvals.key");
    val: ir.Value = b.call(helpers["get"], [target, key], name="dvals.val");
    val = p._cast_to_list_elem(b, val, lhelpers["elem_type"], "dvals.val");
    b.call(lhelpers["append"], [new_list, val]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dvals.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_items(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];

    tuple_type = ir.LiteralStructType([key_type, val_type]);

    p._emit_list_helpers("ptr", i8p);
    lhelpers = p.list_helpers.get("ptr");
    if lhelpers is None {
        return None;
    }
    new_list = b.call(lhelpers["new"], [], name="ditems.list");

    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ditems.len.ptr"
    );
    dict_len = b.load(len_ptr, name="ditems.len");

    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="ditems.loop");
    body_bb = func.append_basic_block(name="ditems.body");
    done_bb = func.append_basic_block(name="ditems.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="ditems.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="ditems.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);

    key = b.call(helpers["get_key"], [target, idx], name="ditems.key");
    val = b.call(helpers["get"], [target, key], name="ditems.val");

    pair: ir.Value = ir.Constant(tuple_type, ir.Undefined);
    pair = b.insert_value(pair, key, 0, name="ditems.key.field");
    pair = b.insert_value(pair, val, 1, name="ditems.val.field");
    boxed = p._box_value_tuple(pair);
    tup_i8p = b.bitcast(boxed, i8p, name="ditems.i8p");
    b.call(lhelpers["append"], [new_list, tup_i8p]);
    p._emit_rc_release_simple(boxed, op="dict_items", loc="");
    next_idx = b.add(idx, ir.Constant(i64, 1), name="ditems.next");
    idx.add_incoming(next_idx, b.basic_block);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_list;
}

impl NativeDictEmitter.emit_pop(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    key = p._coerce_type(args[0], helpers["key_type"]);
    val_type = helpers["val_type"];
    has_default = len(args) >= 2;

    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="dpop.yes");
    notfound_bb = func.append_basic_block(name="dpop.no");
    done_bb = func.append_basic_block(name="dpop.done");

    found_i1 = b.call(helpers["contains"], [target, key], name="dpop.found");
    b.cbranch(found_i1, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    popped_val = b.call(helpers["pop"], [target, key], name="dpop.val");
    _found_pred = b.basic_block;
    b.branch(done_bb);

    b.position_at_start(notfound_bb);
    if has_default {
        default_val = p._coerce_type(args[1], val_type);
    } else {
        p._emit_runtime_raise(
            ir.Constant(ir.IntType(1), 1), "KeyError", "key not found"
        );
        if p._elem_kind(val_type) != "raw" {
            default_val = ir.Constant(val_type, None);
        } else {
            default_val = ir.Constant(val_type, 0);
        }
    }
    _notfound_pred = b.basic_block;
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(val_type, name="dpop.result");
    result.add_incoming(popped_val, _found_pred);
    result.add_incoming(default_val, _notfound_pred);
    p._release_owned_args([key], op="dict_method_key");
    return result;
}

impl NativeDictEmitter.emit_remove(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    key = p._coerce_type(args[0], helpers["key_type"]);
    found_i1 = b.call(helpers["contains"], [target, key], name="drem.has");
    _not_found = b.not_(found_i1, name="drem.miss");
    p._emit_runtime_raise(_not_found, "KeyError", "key not found");
    b.call(helpers["remove"], [target, key]);
    p._release_owned_args([key], op="dict_method_key");
    return None;
}

impl NativeDictEmitter.emit_popitem(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    key_type = helpers["key_type"];
    val_type = helpers["val_type"];

    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dpi.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dpi.len");

    is_empty = b.icmp_signed("==", dict_len, ir.Constant(i64, 0), name="dpi.empty");
    p._emit_runtime_raise(is_empty, "KeyError", "popitem(): dictionary is empty");

    last_idx = b.sub(dict_len, ir.Constant(i64, 1), name="dpi.last");
    last_key = b.call(helpers["get_key"], [target, last_idx], name="dpi.key");

    last_key_out: ir.Value = last_key;
    if isinstance(key_type, ir.PointerType) {
        _i8p_pi = ir.IntType(8).as_pointer();
        if p._nogc_headerless() {
            if (
                isinstance(key_type.pointee, ir.IntType) and key_type.pointee.width == 8
            ) {
                _key_copy = p._call_str_dup(
                    b, b.bitcast(last_key, _i8p_pi, name="dpi.k.src"), name="dpi.k.copy"
                );
                last_key_out = b.bitcast(_key_copy, key_type, name="dpi.k.out");
            }
        } else {
            if p.rc_retain_fn is None {
                p._emit_rc_helpers();
            }
            b.call(p.rc_retain_fn, [b.bitcast(last_key, _i8p_pi, name="dpi.k.ret")]);
        }
    }

    last_val = b.call(helpers["pop"], [target, last_key], name="dpi.val");

    tuple_type = ir.LiteralStructType([key_type, val_type]);
    null_ptr = ir.Constant(tuple_type.as_pointer(), None);
    size_gep = b.gep(null_ptr, [ir.Constant(i32, 1)], name="dpi.sizeof.gep");
    size = b.ptrtoint(size_gep, i64, name="dpi.sizeof");
    raw_ptr = b.call(p.rc_alloc_fn, [size], name="dpi.alloc");
    tuple_ptr = b.bitcast(raw_ptr, tuple_type.as_pointer(), name="dpi.ptr");
    k_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dpi.k.ptr"
    );
    v_ptr = b.gep(
        tuple_ptr, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="dpi.v.ptr"
    );
    b.store(last_key_out, k_ptr);
    b.store(last_val, v_ptr);

    kt_str = "i8p"
        if isinstance(key_type, ir.PointerType)
        else ("f64" if isinstance(key_type, ir.DoubleType) else "i64");
    vt_str = "i8p"
        if isinstance(val_type, ir.PointerType)
        else ("f64" if isinstance(val_type, ir.DoubleType) else "i64");
    tkey = f"{kt_str}.{vt_str}";
    if tkey not in p.tuple_types {
        p.tuple_types[tkey] = tuple_type;
    }
    return tuple_ptr;
}

impl NativeDictEmitter.emit_setdefault(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    key = p._coerce_type(args[0], helpers["key_type"]);
    val_type = helpers["val_type"];
    if len(args) >= 2 {
        default_val = p._coerce_type(args[1], val_type);
    } elif p._elem_kind(val_type) != "raw" {
        default_val = ir.Constant(val_type, None);
    } else {
        return None;
    }

    found = b.call(helpers["contains"], [target, key], name="sdef.found");
    func = b.basic_block.function;
    found_bb = func.append_basic_block(name="sdef.yes");
    notfound_bb = func.append_basic_block(name="sdef.no");
    done_bb = func.append_basic_block(name="sdef.done");
    b.cbranch(found, found_bb, notfound_bb);

    b.position_at_start(found_bb);
    existing = b.call(helpers["get"], [target, key], name="sdef.existing");
    b.branch(done_bb);

    b.position_at_start(notfound_bb);
    b.call(helpers["set"], [target, key, default_val]);
    b.branch(done_bb);

    b.position_at_start(done_bb);
    result = b.phi(val_type, name="sdef.result");
    result.add_incoming(existing, found_bb);
    result.add_incoming(default_val, notfound_bb);
    p._emit_take_ref(result, op="dict_setdefault_result");
    p._release_owned_args(args, op="dict_setdefault_arg");
    return result;
}

impl NativeDictEmitter.emit_update(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    other = args[0];
    len_ptr = b.gep(
        other, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dupd.len.ptr"
    );
    other_len = b.load(len_ptr, name="dupd.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dupd.loop");
    body_bb = func.append_basic_block(name="dupd.body");
    done_bb = func.append_basic_block(name="dupd.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dupd.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, other_len, name="dupd.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [other, idx], name="dupd.key");
    val = b.call(helpers["get"], [other, key], name="dupd.val");
    b.call(helpers["set"], [target, key, val]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dupd.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return ir.Constant(i64, 0);
}

impl NativeDictEmitter.emit_clear(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);

    b.call(helpers["clear"], [target]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeDictEmitter.emit_copy(
    self: NativeDictEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.dict_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    new_dict = b.call(helpers["new"], [], name="dcopy.new");
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="dcopy.len.ptr"
    );
    dict_len = b.load(len_ptr, name="dcopy.len");
    func = b.basic_block.function;
    entry_bb = b.basic_block;
    loop_bb = func.append_basic_block(name="dcopy.loop");
    body_bb = func.append_basic_block(name="dcopy.body");
    done_bb = func.append_basic_block(name="dcopy.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.phi(i64, name="dcopy.idx");
    idx.add_incoming(ir.Constant(i64, 0), entry_bb);
    at_end = b.icmp_unsigned(">=", idx, dict_len, name="dcopy.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    key = b.call(helpers["get_key"], [target, idx], name="dcopy.key");
    val = b.call(helpers["get"], [target, key], name="dcopy.val");
    b.call(helpers["set"], [new_dict, key, val]);
    next_idx = b.add(idx, ir.Constant(i64, 1), name="dcopy.next");
    idx.add_incoming(next_idx, body_bb);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
    return new_dict;
}

impl NativeDictEmitter.emit_fromkeys(
    self: NativeDictEmitter, ctx: NativeEmitCtx, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeSetEmitter.emit_add(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None or not args {
        return None;
    }
    if p._reject_ptr_into_raw_slot(None, args[0], helpers["elem_type"], "set add") {
        return ir.Constant(ir.IntType(64), 0);
    }
    val = p._coerce_type(args[0], helpers["elem_type"]);
    get_builder(p).call(helpers["add"], [target, val]);

    if isinstance(val.type, ir.PointerType)
        and p._is_owned(val)
        and not p._nogc_headerless() {
        _b_sa = get_builder(p);
        _i8p_sa = ir.IntType(8).as_pointer();
        _rc_sa = _b_sa.bitcast(val, _i8p_sa, name="sadd_own_rel_cast");
        if p.rc_release_simple_fn is None {
            p._emit_rc_helpers();
        }
        _b_sa.call(p.rc_release_simple_fn, [_rc_sa]);
    }
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter._emit_set_elem_loop(
    self: NativeSetEmitter,
    ctx: NativeEmitCtx,
    src_set: ir.Value,
    prefix: str,
    body_cb: object
) -> None {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    n = b.call(helpers["len"], [src_set], name=f"{prefix}.len");
    iv = b.alloca(i64, name=f"{prefix}.i");
    b.store(ir.Constant(i64, 0), iv);
    func = b.basic_block.function;
    loop_bb = func.append_basic_block(name=f"{prefix}.loop");
    body_bb = func.append_basic_block(name=f"{prefix}.body");
    done_bb = func.append_basic_block(name=f"{prefix}.done");
    b.branch(loop_bb);
    b.position_at_start(loop_bb);
    idx = b.load(iv, name=f"{prefix}.idx");
    at_end = b.icmp_unsigned(">=", idx, n, name=f"{prefix}.atend");
    b.cbranch(at_end, done_bb, body_bb);
    b.position_at_start(body_bb);
    idx_b = b.load(iv, name=f"{prefix}.idx.b");
    ev = b.call(helpers["get"], [src_set, idx_b], name=f"{prefix}.ev");
    body_cb(b, ev);
    b.store(b.add(idx_b, ir.Constant(i64, 1), name=f"{prefix}.next"), iv);
    b.branch(loop_bb);
    b.position_at_start(done_bb);
}

impl NativeSetEmitter.emit_remove(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    _has_e = b.call(helpers["contains"], [target, search_val], name="srem.has");
    miss = b.not_(_has_e, name="srem.miss");
    p._emit_runtime_raise(miss, "KeyError", "element not in set");
    b = get_builder(p);
    b.call(helpers["remove"], [target, search_val]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_discard(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    search_val = p._coerce_type(args[0], helpers["elem_type"]);
    b.call(helpers["remove"], [target, search_val]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_pop(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();
    elem_type = helpers["elem_type"];
    set_len = b.call(helpers["len"], [target], name="spop.len");
    is_empty = b.icmp_unsigned("==", set_len, ir.Constant(i64, 0), name="spop.empty");
    p._emit_runtime_raise(is_empty, "KeyError", "pop from an empty set");
    b = get_builder(p);
    last_idx = b.sub(set_len, ir.Constant(i64, 1), name="spop.last");
    last_val = b.call(helpers["get"], [target, last_idx], name="spop.val");
    out_val: ir.Value = last_val;
    if isinstance(elem_type, ir.PointerType) {
        if p._nogc_headerless() {
            if isinstance(elem_type.pointee, ir.IntType)
                and elem_type.pointee.width == 8 {
                _sdup = p._get_or_declare_extern("strdup", i8p, [i8p]);
                out_val = b.call(
                    _sdup, [b.bitcast(last_val, i8p, name="spop.src")], name="spop.dup"
                );
                out_val = b.bitcast(out_val, elem_type, name="spop.copy");
            }
        } else {
            if p.rc_retain_fn is None {
                p._emit_rc_helpers();
            }
            b.call(p.rc_retain_fn, [b.bitcast(last_val, i8p, name="spop.keep")]);
        }
    }
    b.call(helpers["remove"], [target, last_val]);
    return out_val;
}

impl NativeSetEmitter.emit_clear(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_union(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="sunion.new");

    def _add_elem(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [new_set, ev]);
    }
    self._emit_set_elem_loop(ctx, target, "su.a", _add_elem);
    self._emit_set_elem_loop(ctx, args[0], "su.b", _add_elem);
    return new_set;
}

impl NativeSetEmitter.emit_intersection(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="sinter.new");
    other = args[0];

    def _keep_common(b2: ir.IRBuilder, ev: ir.Value) {
        func = b2.basic_block.function;
        hit = b2.call(helpers["contains"], [other, ev], name="si.inother");
        add_bb = func.append_basic_block(name="si.add");
        skip_bb = func.append_basic_block(name="si.skip");
        b2.cbranch(hit, add_bb, skip_bb);
        b2.position_at_start(add_bb);
        b2.call(helpers["add"], [new_set, ev]);
        b2.branch(skip_bb);
        b2.position_at_start(skip_bb);
    }
    self._emit_set_elem_loop(ctx, target, "si", _keep_common);
    return new_set;
}

impl NativeSetEmitter.emit_difference(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="sdiff.new");
    other = args[0];

    def _keep_missing(b2: ir.IRBuilder, ev: ir.Value) {
        func = b2.basic_block.function;
        hit = b2.call(helpers["contains"], [other, ev], name="sd.inother");
        add_bb = func.append_basic_block(name="sd.add");
        skip_bb = func.append_basic_block(name="sd.skip");
        b2.cbranch(hit, skip_bb, add_bb);
        b2.position_at_start(add_bb);
        b2.call(helpers["add"], [new_set, ev]);
        b2.branch(skip_bb);
        b2.position_at_start(skip_bb);
    }
    self._emit_set_elem_loop(ctx, target, "sd", _keep_missing);
    return new_set;
}

impl NativeSetEmitter.emit_symmetric_difference(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="ssymd.new");
    other = args[0];

    def _only_in(probe: ir.Value, prefix: str) -> object {
        def _cb(b2: ir.IRBuilder, ev: ir.Value) {
            func = b2.basic_block.function;
            hit = b2.call(helpers["contains"], [probe, ev], name=f"{prefix}.in");
            add_bb = func.append_basic_block(name=f"{prefix}.add");
            skip_bb = func.append_basic_block(name=f"{prefix}.skip");
            b2.cbranch(hit, skip_bb, add_bb);
            b2.position_at_start(add_bb);
            b2.call(helpers["add"], [new_set, ev]);
            b2.branch(skip_bb);
            b2.position_at_start(skip_bb);
        }
        return _cb;
    }
    self._emit_set_elem_loop(ctx, target, "ssymd.a", _only_in(other, "ssymd.a"));
    self._emit_set_elem_loop(ctx, other, "ssymd.b", _only_in(target, "ssymd.b"));
    return new_set;
}

impl NativeSetEmitter.emit_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }

    def _add_elem(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, args[0], "supd", _add_elem);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_intersection_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    kept = self.emit_intersection(ctx, target, [args[0]]);
    if kept is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);

    def _re_add(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, kept, "siupd", _re_add);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_difference_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    kept = self.emit_difference(ctx, target, [args[0]]);
    if kept is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);

    def _re_add(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, kept, "sdupd", _re_add);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter.emit_symmetric_difference_update(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    result = self.emit_symmetric_difference(ctx, target, [args[0]]);
    if result is None {
        return None;
    }
    b = get_builder(p);
    b.call(helpers["clear"], [target]);

    def _re_add(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [target, ev]);
    }
    self._emit_set_elem_loop(ctx, result, "ssdupd", _re_add);
    return ir.Constant(ir.IntType(64), 0);
}

impl NativeSetEmitter._emit_set_relation(
    self: NativeSetEmitter,
    ctx: NativeEmitCtx,
    iter_set: ir.Value,
    probe_set: ir.Value,
    prefix: str,
    chk: str,
    exit_on_hit: bool
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    i64 = ir.IntType(64);
    res_a = b.alloca(i64, name=f"{prefix}.res");
    b.store(ir.Constant(i64, 1), res_a);

    def _probe(b2: ir.IRBuilder, ev: ir.Value) {
        func = b2.basic_block.function;
        hit = b2.call(helpers["contains"], [probe_set, ev], name=f"{prefix}.{chk}");
        fail_bb = func.append_basic_block(name=f"{prefix}.fail");
        keep_bb = func.append_basic_block(name=f"{prefix}.keep");
        if exit_on_hit {
            b2.cbranch(hit, fail_bb, keep_bb);
        } else {
            b2.cbranch(hit, keep_bb, fail_bb);
        }
        b2.position_at_start(fail_bb);
        b2.store(ir.Constant(i64, 0), res_a);
        b2.branch(keep_bb);
        b2.position_at_start(keep_bb);
    }
    self._emit_set_elem_loop(ctx, iter_set, prefix, _probe);
    b = get_builder(p);
    return b.load(res_a, name=f"{prefix}.result");
}

impl NativeSetEmitter.emit_issubset(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    return self._emit_set_relation(ctx, target, args[0], "ssub", "inother", False);
}

impl NativeSetEmitter.emit_issuperset(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    return self._emit_set_relation(ctx, args[0], target, "ssup", "inself", False);
}

impl NativeSetEmitter.emit_isdisjoint(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    if not args {
        return None;
    }
    return self._emit_set_relation(ctx, target, args[0], "sdisj", "inother", True);
}

impl NativeSetEmitter.emit_copy(
    self: NativeSetEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    p = ctx.pass_ref;
    helpers = p.set_helpers.get(ctx.type_key);
    if helpers is None {
        return None;
    }
    b = get_builder(p);
    new_set = b.call(helpers["new"], [], name="scopy.new");

    def _add_elem(b2: ir.IRBuilder, ev: ir.Value) {
        b2.call(helpers["add"], [new_set, ev]);
    }
    self._emit_set_elem_loop(ctx, target, "scopy", _add_elem);
    return new_set;
}

impl NativeFrozensetEmitter._get_set_emitter(
    self: NativeFrozensetEmitter, ctx: NativeEmitCtx
) -> (NativeSetEmitter | None) {
    regs = ctx.pass_ref._native_emitters;
    se = regs.get("set") if regs is not None else None;
    return se if isinstance(se, NativeSetEmitter) else None;
}

impl NativeFrozensetEmitter.emit_union(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_union(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_intersection(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_intersection(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_difference(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_difference(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_symmetric_difference(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_symmetric_difference(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_issubset(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_issubset(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_issuperset(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_issuperset(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_isdisjoint(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_isdisjoint(ctx, target, args) if se is not None else None;
}

impl NativeFrozensetEmitter.emit_copy(
    self: NativeFrozensetEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value]
) -> (ir.Value | None) {
    se = self._get_set_emitter(ctx);
    return se.emit_copy(ctx, target, args) if se is not None else None;
}

impl NativeTupleEmitter._get_struct_info(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value
) -> (ir.LiteralStructType | None) {
    if isinstance(target.type, ir.PointerType)
        and isinstance(target.type.pointee, ir.LiteralStructType) {
        return target.type.pointee;
    }

    p = ctx.pass_ref;
    st = p.tuple_types.get(ctx.type_key);
    return st;
}

impl NativeTupleEmitter.emit_count(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    st = self._get_struct_info(ctx, target);
    if st is None or not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    n = len(st.elements);
    count: ir.Value = ir.Constant(i64, 0);
    val = args[0];
    for i in range(n) {
        ep = b.gep(
            target,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
            name=f"tc.{i}.ptr"
        );
        elem = b.load(ep, name=f"tc.{i}");
        val_c = p._coerce_type(val, elem.type);
        if isinstance(elem.type, ir.IntType) {
            eq = b.icmp_signed("==", val_c, elem, name=f"tc.{i}.eq");
        } elif isinstance(elem.type, ir.DoubleType) {
            eq = b.fcmp_ordered("==", val_c, elem, name=f"tc.{i}.eq");
        } else {
            return None;
        }
        inc = b.zext(eq, i64, name=f"tc.{i}.inc");
        count = b.add(count, inc, name=f"tc.{i}.cnt");
    }
    return count;
}

impl NativeTupleEmitter.emit_index(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    st = self._get_struct_info(ctx, target);
    if st is None or not args {
        return None;
    }
    p = ctx.pass_ref;
    b = get_builder(p);
    i64 = ir.IntType(64);
    n = len(st.elements);
    val = args[0];

    result: ir.Value = ir.Constant(i64, -1);
    for i in range(n - 1, -1, -1) {
        ep = b.gep(
            target,
            [ir.Constant(ir.IntType(32), 0), ir.Constant(ir.IntType(32), i)],
            name=f"ti.{i}.ptr"
        );
        elem = b.load(ep, name=f"ti.{i}");
        val_c = p._coerce_type(val, elem.type);
        if isinstance(elem.type, ir.IntType) {
            eq = b.icmp_signed("==", val_c, elem, name=f"ti.{i}.eq");
        } elif isinstance(elem.type, ir.DoubleType) {
            eq = b.fcmp_ordered("==", val_c, elem, name=f"ti.{i}.eq");
        } else {
            return None;
        }
        result = b.select(eq, ir.Constant(i64, i), result, name=f"ti.{i}.sel");
    }
    return result;
}

impl NativeTupleEmitter.emit_op_add(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_mul(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_eq(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_ne(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_lt(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_gt(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_le(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_ge(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

impl NativeTupleEmitter.emit_op_contains(
    self: NativeTupleEmitter, ctx: NativeEmitCtx, target: ir.Value, args: list[ir.Value]
) -> (ir.Value | None) {
    return None;
}

def _aos_size_of(b: ir.IRBuilder, elem_struct: ir.Type, tag: str) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    return b.ptrtoint(
        b.gep(
            ir.Constant(elem_struct.as_pointer(), None),
            [ir.Constant(i32, 1)],
            name=f"{tag}.szT.p"
        ),
        i64,
        name=f"{tag}.szT"
    );
}

def _aos_data_ptr(b: ir.IRBuilder, target: ir.Value, tag: str) -> ir.Value {
    i32 = ir.IntType(32);
    return b.load(
        b.gep(target, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name=f"{tag}.data.p"),
        name=f"{tag}.data"
    );
}

def _aos_memmove(
    p: NaIRGenPass,
    b: ir.IRBuilder,
    data: ir.Value,
    dst_idx: ir.Value,
    src_idx: ir.Value,
    count: ir.Value,
    sz: ir.Value,
    tag: str
) {
    i8p = ir.IntType(8).as_pointer();
    i64 = ir.IntType(64);
    _memmove = p._get_or_declare_extern("memmove", i8p, [i8p, i8p, i64]);
    b.call(
        _memmove,
        [
            b.bitcast(
                b.gep(data, [dst_idx], name=f"{tag}.dst"), i8p, name=f"{tag}.dst8"
            ),
            b.bitcast(
                b.gep(data, [src_idx], name=f"{tag}.src"), i8p, name=f"{tag}.src8"
            ),
            b.mul(count, sz, name=f"{tag}.bytes")
        ]
    );
}

impl NativeListEmitter._emit_aos_pop(
    self: NativeListEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    args: list[ir.Value],
    elem_struct: ir.Type
) -> ir.Value {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    helpers = p.list_helpers[ctx.type_key];
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="pop.len.ptr"
    );
    cur_len = b.load(len_ptr, name="pop.len");
    new_len = b.sub(cur_len, ir.Constant(i64, 1), name="pop.newlen");
    pop_idx = new_len;
    if args {
        raw_idx = p._coerce_type(args[0], i64);
        is_neg = b.icmp_signed("<", raw_idx, ir.Constant(i64, 0), name="pop.idx.neg");
        pop_idx = b.select(
            is_neg, b.add(raw_idx, cur_len, name="pop.idx.adj"), raw_idx, name="pop.idx"
        );
    }
    sz = _aos_size_of(b, elem_struct, "pop");
    _malloc = p._get_or_declare_extern("malloc", i8p, [i64]);
    _memcpy = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    shell8 = b.call(_malloc, [sz], name="pop.shell8");
    elem_ptr = b.call(helpers["get"], [target, pop_idx], name="pop.elem");
    b.call(_memcpy, [shell8, b.bitcast(elem_ptr, i8p, name="pop.elem8"), sz]);
    data = _aos_data_ptr(b, target, "pop");
    tail = b.sub(new_len, pop_idx, name="pop.tail");
    _aos_memmove(
        p,
        b,
        data,
        pop_idx,
        b.add(pop_idx, ir.Constant(i64, 1), name="pop.from"),
        tail,
        sz,
        "pop.sh"
    );
    b.store(new_len, len_ptr);
    popped = b.bitcast(shell8, elem_struct.as_pointer(), name="pop.val");
    p._mark_owned(popped);
    return popped;
}

impl NativeListEmitter._emit_aos_del_at(
    self: NativeListEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    del_idx: ir.Value,
    elem_struct: ir.Type
) -> ir.Value {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    helpers = p.list_helpers[ctx.type_key];
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="delat.len.ptr"
    );
    cur_len = b.load(len_ptr, name="delat.len");
    new_len = b.sub(cur_len, ir.Constant(i64, 1), name="delat.newlen");
    _fields_fn = helpers.get("drop_fields");
    if _fields_fn is not None {
        elem_ptr = b.call(helpers["get"], [target, del_idx], name="delat.elem");
        b.call(_fields_fn, [b.bitcast(elem_ptr, i8p, name="delat.elem8")]);
    }
    sz = _aos_size_of(b, elem_struct, "delat");
    data = _aos_data_ptr(b, target, "delat");
    tail = b.sub(new_len, del_idx, name="delat.tail");
    _aos_memmove(
        p,
        b,
        data,
        del_idx,
        b.add(del_idx, ir.Constant(i64, 1), name="delat.from"),
        tail,
        sz,
        "delat.sh"
    );
    b.store(new_len, len_ptr);
    return ir.Constant(i64, 0);
}

impl NativeListEmitter._emit_aos_insert(
    self: NativeListEmitter,
    ctx: NativeEmitCtx,
    target: ir.Value,
    insert_idx: ir.Value,
    insert_val: ir.Value,
    elem_struct: ir.Type
) -> ir.Value {
    p = ctx.pass_ref;
    b = get_builder(p);
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    helpers = p.list_helpers[ctx.type_key];
    b.call(helpers["push"], [target, insert_val]);
    len_ptr = b.gep(
        target, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="ins.len.ptr"
    );
    new_len = b.load(len_ptr, name="ins.newlen");
    last_idx = b.sub(new_len, ir.Constant(i64, 1), name="ins.last");
    sz = _aos_size_of(b, elem_struct, "ins");
    data = _aos_data_ptr(b, target, "ins");
    tail = b.sub(last_idx, insert_idx, name="ins.tail");
    _aos_memmove(
        p,
        b,
        data,
        b.add(insert_idx, ir.Constant(i64, 1), name="ins.to"),
        insert_idx,
        tail,
        sz,
        "ins.sh"
    );
    _memcpy = p._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    slot = b.gep(data, [insert_idx], name="ins.slot");
    b.call(
        _memcpy,
        [
            b.bitcast(slot, i8p, name="ins.slot8"),
            b.bitcast(insert_val, i8p, name="ins.src8"),
            sz
        ]
    );
    _free = p._get_or_declare_extern("free", ir.VoidType(), [i8p]);
    b.call(_free, [b.bitcast(insert_val, i8p, name="ins.shell8")]);
    return ir.Constant(i64, 0);
}
