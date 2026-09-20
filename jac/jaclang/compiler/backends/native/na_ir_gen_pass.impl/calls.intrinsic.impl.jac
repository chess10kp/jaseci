impl NaIRGenPass._emit_unsupported_builtin_call(
    nd: uni.FuncCall, func_name: str
) -> None {
    self.ctx.emit(
        E5092,
        node_override=nd,
        kind="builtin call",
        name=func_name,
        help_text="This builtin is implemented for some argument types but could not be lowered for the argument(s) at this call site (for example `sum`/`min`/`max` over a `range` rather than a list). Restructure to a supported form, or move the code to a @sv/Python context."
    );
}

impl NaIRGenPass._codegen_intrinsic(
    nd: uni.FuncCall, intr: IntrinsicEntry
) -> (ir.Value | None) {
    import from jaclang.compiler.intrinsic_registry { IntrinsicDispatch }

    positional: list[uni.Expr] = [];
    _has_kw = False;
    for p in (nd.params or []) {
        if isinstance(p, uni.KWPair) {
            _has_kw = True;
        } else {
            positional.append(p);
        }
    }
    if _has_kw {
        self._emit_intrinsic_misuse(nd, intr, "keyword arguments are not accepted");
        return None;
    }
    if len(positional) != intr.arity() {
        self._emit_intrinsic_misuse(
            nd, intr, f"expected {intr.arity()} argument(s), got {len(positional)}"
        );
        return None;
    }
    _emitters: dict[IntrinsicDispatch, Callable[..., (ir.Value | None)]] = {
        IntrinsicDispatch.RC_RUNTIME: self._emit_intrinsic_rc_runtime,
        IntrinsicDispatch.FLOAT_BITS: self._emit_intrinsic_float_bits,
        IntrinsicDispatch.BITS_FLOAT: self._emit_intrinsic_bits_float,
        IntrinsicDispatch.MEM_LOAD: self._emit_intrinsic_mem_load,
        IntrinsicDispatch.MEM_STORE: self._emit_intrinsic_mem_store,
        IntrinsicDispatch.ATOMIC_XCHG: self._emit_intrinsic_atomic_xchg,
        IntrinsicDispatch.CALL_DTOR: self._emit_intrinsic_call_dtor
    };
    handler = _emitters.get(intr.dispatch);
    if handler is None {
        self.ctx.emit(
            E9001,
            node_override=nd,
            pass_name="NaIRGenPass",
            details=f"intrinsic '{intr.name}' registers dispatch key {intr.dispatch.value} with no mapped emitter"
        );
        return None;
    }
    return handler(nd, intr, positional);
}

impl NaIRGenPass._emit_intrinsic_misuse(
    nd: uni.FuncCall, intr: IntrinsicEntry, reason: str
) -> None {
    for e in self.ctx.errors_had {
        if (
            e.code is E5095
            and e.loc.mod_path == nd.loc.mod_path
            and e.loc.first_line == nd.loc.first_line
            and e.loc.col_start == nd.loc.col_start
        ) {
            return;
        }
    }
    self.ctx.emit(E5095, node_override=nd, name=intr.name, reason=reason);
}

impl NaIRGenPass._intrinsic_operand(
    nd: uni.FuncCall, intr: IntrinsicEntry, arg: uni.Expr, spec: str
) -> (ir.Value | None) {
    arg_val = self._codegen_expr(arg);
    if arg_val is None {
        self._emit_intrinsic_misuse(nd, intr, "operand did not lower to a value");
        return None;
    }
    if spec == "i64" and isinstance(arg_val.type, ir.PointerType) {
        arg_val = self.builder.ptrtoint(arg_val, ir.IntType(64), name="intr.addr");
    }
    if not isinstance(arg_val.type, (ir.IntType, ir.FloatType, ir.DoubleType)) {
        self._emit_intrinsic_misuse(
            nd,
            intr,
            f"operand of type {arg_val.type} does not fit registered parameter type {spec}"
        );
        return None;
    }
    if spec == "f64" {
        if not isinstance(arg_val.type, ir.DoubleType) {
            arg_val = self._coerce_type(arg_val, ir.DoubleType());
        }
        return arg_val;
    }
    width = int(spec[1:]);
    if not isinstance(arg_val.type, ir.IntType) or arg_val.type.width != width {
        arg_val = self._coerce_type(arg_val, ir.IntType(width));
    }
    return arg_val;
}

impl NaIRGenPass._emit_intrinsic_rc_runtime(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    if intr.gc_mode_gate is not None and self._gc_mode() != intr.gc_mode_gate {
        return None;
    }
    if self.rc_alloc_fn is None {
        self._emit_rc_helpers();
    }
    self.builder.call(self.llvm_module.get_global(intr.name), []);
    return None;
}

impl NaIRGenPass._emit_intrinsic_float_bits(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    arg_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if arg_val is None {
        return None;
    }
    return self.builder.bitcast(arg_val, ir.IntType(64), name="float_bits");
}

impl NaIRGenPass._emit_intrinsic_bits_float(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    arg_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if arg_val is None {
        return None;
    }
    return self.builder.bitcast(arg_val, ir.DoubleType(), name="bits_float");
}

impl NaIRGenPass._emit_intrinsic_mem_load(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    addr = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    if addr is None {
        return None;
    }
    value_type = ir.IntType(int(intr.result_spec[1:]));
    slot = self.builder.inttoptr(addr, value_type.as_pointer(), name="mem.p");
    return self.builder.load(slot, name="mem.ld");
}

impl NaIRGenPass._emit_intrinsic_mem_store(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    addr = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    val = self._intrinsic_operand(nd, intr, args[1], intr.param_specs[1]);
    if addr is None or val is None {
        return None;
    }
    slot = self.builder.inttoptr(addr, val.type.as_pointer(), name="mem.p");
    self.builder.store(val, slot);
    return None;
}

impl NaIRGenPass._emit_intrinsic_atomic_xchg(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    addr = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    val = self._intrinsic_operand(nd, intr, args[1], intr.param_specs[1]);
    if addr is None or val is None {
        return None;
    }
    i64 = ir.IntType(64);
    slot = self.builder.inttoptr(addr, i64.as_pointer(), name="mem.p");
    return self.builder.atomic_rmw(
        "xchg", slot, val, ordering="acq_rel", name="mem.xchg"
    );
}

impl NaIRGenPass._emit_intrinsic_call_dtor(
    nd: uni.FuncCall, intr: IntrinsicEntry, args: list[uni.Expr]
) -> (ir.Value | None) {
    fn_val = self._intrinsic_operand(nd, intr, args[0], intr.param_specs[0]);
    obj_val = self._intrinsic_operand(nd, intr, args[1], intr.param_specs[1]);
    if fn_val is None or obj_val is None {
        return None;
    }
    i8p = ir.IntType(8).as_pointer();
    dtor_ty = ir.FunctionType(ir.VoidType(), [i8p]).as_pointer();
    fn_ptr = self.builder.inttoptr(fn_val, dtor_ty, name="dtor.fn");
    obj_ptr = self.builder.inttoptr(obj_val, i8p, name="dtor.obj");
    self.builder.call(fn_ptr, [obj_ptr]);
    return None;
}
