import from jaclang.compiler.frontend.const_fold { fold_const }

impl NaIRGenPass._emit_float_pow(
    base: ir.Value, exp: ir.Value, unsigned: bool = False
) -> ir.Value {
    f64 = ir.DoubleType();
    (fleft, fright) = self._promote_to_float(base, exp, unsigned=unsigned);
    if isinstance(fleft.type, ir.FloatType) {
        f32 = ir.FloatType();
        powf_fn = self._get_or_declare_extern("powf", f32, [f32, f32]);
        return self.builder.call(powf_fn, [fleft, fright], name="pow.f32");
    }
    pow_fn = self._get_or_declare_extern("pow", f64, [f64, f64]);
    return self.builder.call(pow_fn, [fleft, fright], name="pow.f");
}

impl NaIRGenPass._emit_pow_zero_guard(base: ir.Value) -> None {
    if isinstance(base.type, ir.IntType) {
        is_zero = self.builder.icmp_signed(
            "==", base, ir.Constant(base.type, 0), name="pow.zero.b"
        );
    } else {
        fzero = ir.Constant(base.type, 0.0);
        is_zero = self.builder.fcmp_ordered("==", base, fzero, name="pow.zero.b");
    }
    self._emit_runtime_raise(
        is_zero, "ZeroDivisionError", "0.0 cannot be raised to a negative power"
    );
}

impl NaIRGenPass._codegen_int_pow(
    base: ir.Value, exp: ir.Value, unsigned: bool = False, checked: bool = False
) -> ir.Value {
    int_ty = base.type;
    one = ir.Constant(int_ty, 1);
    func = self.builder.function;

    result_alloca = self._entry_alloca(int_ty, "pow.result");
    counter_alloca = self._entry_alloca(int_ty, "pow.counter");
    self.builder.store(one, result_alloca);
    self.builder.store(ir.Constant(int_ty, 0), counter_alloca);

    cond_bb = func.append_basic_block(name="pow.cond");
    body_bb = func.append_basic_block(name="pow.body");
    end_bb = func.append_basic_block(name="pow.end");
    self.builder.branch(cond_bb);

    self.builder.position_at_end(cond_bb);
    counter = self.builder.load(counter_alloca, name="pow.i");
    cmp = self.builder.icmp_signed("<", counter, exp, name="pow.cmp");
    self.builder.cbranch(cmp, body_bb, end_bb);

    self.builder.position_at_end(body_bb);
    cur_result = self.builder.load(result_alloca, name="pow.cur");
    new_result = (
        self._emit_overflow_op("mul", cur_result, base, unsigned)
            if checked
            else self.builder.mul(cur_result, base, name="pow.mul")
    );
    self.builder.store(new_result, result_alloca);
    cur_counter = self.builder.load(counter_alloca, name="pow.ci");
    next_counter = self.builder.add(cur_counter, one, name="pow.inc");
    self.builder.store(next_counter, counter_alloca);
    self.builder.branch(cond_bb);

    self.builder.position_at_end(end_bb);
    return self.builder.load(result_alloca, name="pow.final");
}

impl NaIRGenPass._complex_aug_token(aug_op: str) -> (str | None) {
    return {
        "+=": Tok.PLUS,
        "-=": Tok.MINUS,
        "*=": Tok.STAR_MUL,
        "/=": Tok.DIV,
        "**=": Tok.STAR_POW
    }.get(
        aug_op
    );
}

impl NaIRGenPass._emit_complex_value(re: ir.Value, im: ir.Value) -> ir.Value {
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    raw = self.builder.call(
        self.rc_alloc_fn, [ir.Constant(i64, 16)], name="cp.res.raw"
    );
    ptr = self.builder.bitcast(
        raw, self.complex_struct_type.as_pointer(), name="cp.res.ptr"
    );
    self.builder.store(re, self.builder.gep(ptr, [z0, z0], name="cp.res.rp"));
    self.builder.store(im, self.builder.gep(ptr, [z0, z1], name="cp.res.ip"));
    return ptr;
}

impl NaIRGenPass._load_complex_parts(ptr: ir.Value) -> tuple[(ir.Value, ir.Value)] {
    i32 = ir.IntType(32);
    z0 = ir.Constant(i32, 0);
    z1 = ir.Constant(i32, 1);
    re = self.builder.load(self.builder.gep(ptr, [z0, z0], name="c.re.p"), name="c.re");
    im = self.builder.load(self.builder.gep(ptr, [z0, z1], name="c.im.p"), name="c.im");
    return (re, im);
}

impl NaIRGenPass._codegen_complex_pow(
    base: ir.Value, exp: ir.Value
) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    i64 = ir.IntType(64);
    ctype_ptr = self.complex_struct_type.as_pointer();

    _cb = base if base.type == ctype_ptr else self._emit_make_complex(base);
    _ce = exp if exp.type == ctype_ptr else self._emit_make_complex(exp);
    if _cb is None or _ce is None {
        return None;
    }

    (ar, ai) = self._load_complex_parts(_cb);
    (wr, wi) = self._load_complex_parts(_ce);

    hypot_fn = self._get_or_declare_extern("hypot", f64, [f64, f64]);
    floor_fn = self._get_or_declare_extern("floor", f64, [f64]);
    fabs_fn = self._get_or_declare_extern("fabs", f64, [f64]);
    log_fn = self._get_or_declare_extern("log", f64, [f64]);
    atan2_fn = self._get_or_declare_extern("atan2", f64, [f64, f64]);
    exp_fn = self._get_or_declare_extern("exp", f64, [f64]);
    cos_fn = self._get_or_declare_extern("cos", f64, [f64]);
    sin_fn = self._get_or_declare_extern("sin", f64, [f64]);

    fzero = ir.Constant(f64, 0.0);
    fone = ir.Constant(f64, 1.0);
    mag = self.builder.call(hypot_fn, [ar, ai], name="cp.len");
    theta = self.builder.call(atan2_fn, [ai, ar], name="cp.theta");
    func = self.builder.function;

    res_r = self._entry_alloca(f64, "cp.res.r");
    res_i = self._entry_alloca(f64, "cp.res.i");

    zero_bb = func.append_basic_block(name="cp.zero");
    nonzero_bb = func.append_basic_block(name="cp.nonzero");
    done_bb = func.append_basic_block(name="cp.done");
    is_zero = self.builder.fcmp_ordered("==", mag, fzero, name="cp.iszero");
    self.builder.cbranch(is_zero, zero_bb, nonzero_bb);

    self.builder.position_at_end(zero_bb);
    bad_exp = self.builder.or_(
        self.builder.fcmp_ordered("<", wr, fzero, name="cp.wrneg"),
        self.builder.fcmp_ordered("!=", wi, fzero, name="cp.winz"),
        name="cp.badexp"
    );
    self._emit_runtime_raise(
        bad_exp, "ZeroDivisionError", "zero to a negative or complex power"
    );

    zr = self.builder.select(
        self.builder.fcmp_ordered("==", wr, fzero, name="cp.wrzero"),
        fone,
        fzero,
        name="cp.zr"
    );
    self.builder.store(zr, res_r);
    self.builder.store(fzero, res_i);
    self.builder.branch(done_bb);

    self.builder.position_at_end(nonzero_bb);
    wr_floor = self.builder.call(floor_fn, [wr], name="cp.wrfloor");

    is_int_exp = self.builder.and_(
        self.builder.fcmp_ordered("==", wi, fzero, name="cp.wizero"),
        self.builder.and_(
            self.builder.fcmp_ordered("==", wr, wr_floor, name="cp.wrint"),
            self.builder.fcmp_ordered(
                "<=",
                self.builder.call(fabs_fn, [wr], name="cp.wrabs"),
                ir.Constant(f64, 100.0),
                name="cp.wrsml"
            ),
            name="cp.wrchk"
        ),
        name="cp.isintexp"
    );
    int_bb = func.append_basic_block(name="cp.int");
    gen_bb = func.append_basic_block(name="cp.gen");
    self.builder.cbranch(is_int_exp, int_bb, gen_bb);

    self.builder.position_at_end(int_bb);
    acc_r = self._entry_alloca(f64, "cp.acc.r");
    acc_i = self._entry_alloca(f64, "cp.acc.i");
    cur_r = self._entry_alloca(f64, "cp.cur.r");
    cur_i = self._entry_alloca(f64, "cp.cur.i");
    n_ctr = self._entry_alloca(i64, "cp.n");
    self.builder.store(fone, acc_r);
    self.builder.store(fzero, acc_i);
    self.builder.store(ar, cur_r);
    self.builder.store(ai, cur_i);
    n_abs = self.builder.call(fabs_fn, [wr], name="cp.nabs");
    self.builder.store(self.builder.fptosi(n_abs, i64, name="cp.ni"), n_ctr);
    loop_bb = func.append_basic_block(name="cp.iloop");
    odd_bb = func.append_basic_block(name="cp.iodd");
    even_bb = func.append_basic_block(name="cp.ieven");
    idone_bb = func.append_basic_block(name="cp.idone");
    self.builder.branch(loop_bb);

    self.builder.position_at_end(loop_bb);
    n_cur = self.builder.load(n_ctr, name="cp.n.cur");
    n_pos = self.builder.icmp_signed(">", n_cur, ir.Constant(i64, 0), name="cp.n.pos");
    self.builder.cbranch(n_pos, odd_bb, idone_bb);

    self.builder.position_at_end(odd_bb);
    n_bit = self.builder.and_(
        self.builder.load(n_ctr, name="cp.n.ld"), ir.Constant(i64, 1), name="cp.n.bit"
    );
    is_odd = self.builder.icmp_signed(
        "!=", n_bit, ir.Constant(i64, 0), name="cp.n.odd"
    );
    mul_bb = func.append_basic_block(name="cp.imul");
    self.builder.cbranch(is_odd, mul_bb, even_bb);

    self.builder.position_at_end(mul_bb);
    a_r = self.builder.load(acc_r, name="cp.a.r");
    a_i = self.builder.load(acc_i, name="cp.a.i");
    c_r = self.builder.load(cur_r, name="cp.c.r");
    c_i = self.builder.load(cur_i, name="cp.c.i");
    self.builder.store(
        self.builder.fsub(
            self.builder.fmul(a_r, c_r, name="cp.m1"),
            self.builder.fmul(a_i, c_i, name="cp.m2"),
            name="cp.mr"
        ),
        acc_r
    );
    self.builder.store(
        self.builder.fadd(
            self.builder.fmul(a_r, c_i, name="cp.m3"),
            self.builder.fmul(a_i, c_r, name="cp.m4"),
            name="cp.mi"
        ),
        acc_i
    );
    self.builder.branch(even_bb);

    self.builder.position_at_end(even_bb);
    c2_r = self.builder.load(cur_r, name="cp.c2.r");
    c2_i = self.builder.load(cur_i, name="cp.c2.i");
    self.builder.store(
        self.builder.fsub(
            self.builder.fmul(c2_r, c2_r, name="cp.s1"),
            self.builder.fmul(c2_i, c2_i, name="cp.s2"),
            name="cp.sr"
        ),
        cur_r
    );
    self.builder.store(
        self.builder.fmul(
            ir.Constant(f64, 2.0),
            self.builder.fmul(c2_r, c2_i, name="cp.s3"),
            name="cp.si"
        ),
        cur_i
    );
    self.builder.store(
        self.builder.ashr(
            self.builder.load(n_ctr, name="cp.n.sh"),
            ir.Constant(i64, 1),
            name="cp.n.next"
        ),
        n_ctr
    );
    self.builder.branch(loop_bb);

    self.builder.position_at_end(idone_bb);
    fin_r = self.builder.load(acc_r, name="cp.f.r");
    fin_i = self.builder.load(acc_i, name="cp.f.i");
    neg_exp = self.builder.fcmp_ordered("<", wr, fzero, name="cp.negexp");
    inv_bb = func.append_basic_block(name="cp.inv");
    st_bb = func.append_basic_block(name="cp.istore");
    self.builder.cbranch(neg_exp, inv_bb, st_bb);

    self.builder.position_at_end(inv_bb);

    (inv_r, inv_i) = self._emit_complex_div_parts(fone, fzero, fin_r, fin_i);
    self.builder.store(inv_r, res_r);
    self.builder.store(inv_i, res_i);
    self.builder.branch(done_bb);

    self.builder.position_at_end(st_bb);
    self.builder.store(fin_r, res_r);
    self.builder.store(fin_i, res_i);
    self.builder.branch(done_bb);

    self.builder.position_at_end(gen_bb);
    lnr = self.builder.call(log_fn, [mag], name="cp.lnr");
    a = self.builder.fsub(
        self.builder.fmul(wr, lnr, name="cp.a1"),
        self.builder.fmul(wi, theta, name="cp.a2"),
        name="cp.a"
    );
    ang = self.builder.fadd(
        self.builder.fmul(wr, theta, name="cp.b1"),
        self.builder.fmul(wi, lnr, name="cp.b2"),
        name="cp.ang"
    );
    m = self.builder.call(exp_fn, [a], name="cp.mag");
    grr = self.builder.fmul(
        m, self.builder.call(cos_fn, [ang], name="cp.cos"), name="cp.grr"
    );
    gri = self.builder.fmul(
        m, self.builder.call(sin_fn, [ang], name="cp.sin"), name="cp.gri"
    );
    self.builder.store(grr, res_r);
    self.builder.store(gri, res_i);
    self.builder.branch(done_bb);

    self.builder.position_at_end(done_bb);
    out_r = self.builder.load(res_r, name="cp.out.r");
    out_i = self.builder.load(res_i, name="cp.out.i");
    return self._emit_complex_value(out_r, out_i);
}

impl NaIRGenPass._emit_complex_div_parts(
    ar: ir.Value, ai: ir.Value, br: ir.Value, bi: ir.Value
) -> tuple[(ir.Value, ir.Value)] {
    f64 = ir.DoubleType();
    fzero = ir.Constant(f64, 0.0);
    fabs_fn = self._get_or_declare_extern("fabs", f64, [f64]);

    res_r = self._entry_alloca(f64, "cd.res.r");
    res_i = self._entry_alloca(f64, "cd.res.i");

    bzero = self.builder.and_(
        self.builder.fcmp_ordered("==", br, fzero, name="cd.brz"),
        self.builder.fcmp_ordered("==", bi, fzero, name="cd.biz"),
        name="cd.bzero"
    );
    self._emit_runtime_raise(bzero, "ZeroDivisionError", "complex division by zero");

    abs_br = self.builder.call(fabs_fn, [br], name="cd.abr");
    abs_bi = self.builder.call(fabs_fn, [bi], name="cd.abi");
    func = self.builder.function;
    done_bb = func.append_basic_block(name="cd.done");

    re_ge_bb = func.append_basic_block(name="cd.rege");
    im_gt_bb = func.append_basic_block(name="cd.imgt");
    nan_bb = func.append_basic_block(name="cd.nan");
    use_re = self.builder.fcmp_ordered(">=", abs_br, abs_bi, name="cd.uge");
    use_im = self.builder.fcmp_ordered("<", abs_br, abs_bi, name="cd.ult");

    re_or_im = self.builder.or_(use_re, use_im, name="cd.ord");
    mid_bb = func.append_basic_block(name="cd.mid");
    self.builder.cbranch(re_or_im, mid_bb, nan_bb);
    self.builder.position_at_end(mid_bb);
    self.builder.cbranch(use_re, re_ge_bb, im_gt_bb);

    self.builder.position_at_end(re_ge_bb);
    ratio1 = self.builder.fdiv(bi, br, name="cd.ratio1");
    denom1 = self.builder.fadd(
        br, self.builder.fmul(bi, ratio1, name="cd.d1x"), name="cd.denom1"
    );
    self.builder.store(
        self.builder.fdiv(
            self.builder.fadd(
                ar, self.builder.fmul(ai, ratio1, name="cd.n1x"), name="cd.n1"
            ),
            denom1,
            name="cd.r1"
        ),
        res_r
    );
    self.builder.store(
        self.builder.fdiv(
            self.builder.fsub(
                ai, self.builder.fmul(ar, ratio1, name="cd.i1x"), name="cd.i1"
            ),
            denom1,
            name="cd.ri1"
        ),
        res_i
    );
    self.builder.branch(done_bb);

    self.builder.position_at_end(im_gt_bb);
    ratio2 = self.builder.fdiv(br, bi, name="cd.ratio2");
    denom2 = self.builder.fadd(
        self.builder.fmul(br, ratio2, name="cd.d2x"), bi, name="cd.denom2"
    );
    self.builder.store(
        self.builder.fdiv(
            self.builder.fadd(
                self.builder.fmul(ar, ratio2, name="cd.n2x"), ai, name="cd.n2"
            ),
            denom2,
            name="cd.r2"
        ),
        res_r
    );
    self.builder.store(
        self.builder.fdiv(
            self.builder.fsub(
                self.builder.fmul(ai, ratio2, name="cd.i2x"), ar, name="cd.i2"
            ),
            denom2,
            name="cd.ri2"
        ),
        res_i
    );
    self.builder.branch(done_bb);

    self.builder.position_at_end(nan_bb);
    fnan = ir.Constant(f64, float("nan"));
    self.builder.store(fnan, res_r);
    self.builder.store(fnan, res_i);
    self.builder.branch(done_bb);

    self.builder.position_at_end(done_bb);
    out_r = self.builder.load(res_r, name="cd.out.r");
    out_i = self.builder.load(res_i, name="cd.out.i");
    return (out_r, out_i);
}

impl NaIRGenPass._codegen_complex_div(
    left: ir.Value, right: ir.Value
) -> (ir.Value | None) {
    (ar, ai) = self._load_complex_parts(left);
    (br, bi) = self._load_complex_parts(right);
    (out_r, out_i) = self._emit_complex_div_parts(ar, ai, br, bi);
    return self._emit_complex_value(out_r, out_i);
}

impl NaIRGenPass._emit_make_complex(v: ir.Value) -> (ir.Value | None) {
    f64 = ir.DoubleType();
    fv = self._coerce_type(v, f64);
    if fv is None {
        return None;
    }
    return self._emit_complex_value(fv, ir.Constant(f64, 0.0));
}

impl NaIRGenPass._codegen_pow(
    base: ir.Value,
    exp: ir.Value,
    exp_node: (uni.Expr | None) = None,
    unsigned: bool = False,
    checked: bool = False
) -> (ir.Value | None) {
    ctype_ptr = self.complex_struct_type.as_pointer();
    if base.type == ctype_ptr or exp.type == ctype_ptr {
        return self._codegen_complex_pow(base, exp);
    }
    f64 = ir.DoubleType();
    is_float_op = isinstance(base.type, (ir.DoubleType, ir.FloatType))
        or isinstance(exp.type, (ir.DoubleType, ir.FloatType));

    if is_float_op {
        exp_known_neg = False;
        if exp_node is not None {
            (rok, rv) = fold_const(exp_node);
            if rok and isinstance(rv, (int, float)) and rv < 0 {
                self._emit_pow_zero_guard(base);
                exp_known_neg = True;
            }
        }
        if not exp_known_neg {
            (fbase, fexp) = self._promote_to_float(base, exp);
            fzero = ir.Constant(f64, 0.0);
            is_neg = self.builder.fcmp_ordered("<", fexp, fzero, name="pow.fneg.chk");
            func = self.builder.function;
            neg_bb = func.append_basic_block(name="pow.fneg");
            pos_bb = func.append_basic_block(name="pow.fpos");
            merge_bb = func.append_basic_block(name="pow.fmerge");
            self.builder.cbranch(is_neg, neg_bb, pos_bb);
            self.builder.position_at_end(neg_bb);
            self._emit_pow_zero_guard(base);
            fres = self._emit_float_pow(base, exp);
            neg_pred = self.builder.block;
            self.builder.branch(merge_bb);
            self.builder.position_at_end(pos_bb);
            fpres = self._emit_float_pow(base, exp);
            pos_pred = self.builder.block;
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            phi = self.builder.phi(f64, name="pow.fres");
            phi.add_incoming(fres, neg_pred);
            phi.add_incoming(fpres, pos_pred);
            return phi;
        }
        return self._emit_float_pow(base, exp);
    }

    exp_known: bool = False;
    exp_val: int = 0;
    if exp_node is not None {
        (rok, rv) = fold_const(exp_node);
        if rok and isinstance(rv, int) {
            exp_known = True;
            exp_val = rv;
        }
    }

    (base, exp) = self._unify_int_widths(base, exp);

    if exp_known {
        if exp_val < 0 {
            self._emit_pow_zero_guard(base);
            return self._emit_float_pow(base, exp, unsigned);
        }
        return self._codegen_int_pow(base, exp, unsigned, checked);
    }
    if unsigned {
        return self._codegen_int_pow(base, exp, True, checked);
    }

    int_ty = base.type;
    izero = ir.Constant(int_ty, 0);
    is_neg = self.builder.icmp_signed("<", exp, izero, name="pow.neg.chk");

    func = self.builder.function;
    neg_bb = func.append_basic_block(name="pow.neg");
    pos_bb = func.append_basic_block(name="pow.pos");
    merge_bb = func.append_basic_block(name="pow.merge");
    self.builder.cbranch(is_neg, neg_bb, pos_bb);

    self.builder.position_at_end(neg_bb);
    self._emit_pow_zero_guard(base);
    fres = self._emit_float_pow(base, exp);
    neg_pred = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(pos_bb);
    iresult = self._codegen_int_pow(base, exp, unsigned, checked);
    pos_pred = self.builder.block;
    i_as_f = self.builder.sitofp(iresult, f64, name="pow.i2f");
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    phi = self.builder.phi(f64, name="pow.res");
    phi.add_incoming(fres, neg_pred);
    phi.add_incoming(i_as_f, pos_pred);
    return phi;
}
