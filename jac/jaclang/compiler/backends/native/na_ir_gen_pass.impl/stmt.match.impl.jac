impl NaIRGenPass._codegen_match(nd: uni.MatchStmt) -> None {
    subj = self._codegen_expr(nd.target);
    if subj is None {
        return;
    }

    subj_alloca = self._entry_alloca(subj.type, "match.subj");
    self.builder.store(subj, subj_alloca);
    subj_ty = self._match_subj_ty(nd.target);
    func = self.builder.function;
    end_bb = func.append_basic_block(name="match.end");
    n = len(nd.cases);
    for (ci, `case) in enumerate(nd.cases) {
        subj_val = self.builder.load(subj_alloca, name="match.subj.l");
        cond = self._match_pattern_cond(`case.pattern, subj_val, subj_ty);
        body_bb = func.append_basic_block(name=f"match.c{ci}.body");
        next_bb = func.append_basic_block(name=f"match.c{ci}.next")
            if ci < n - 1
            else end_bb;
        if cond is None {
            self.builder.branch(next_bb);
            if next_bb is not end_bb {
                self.builder.position_at_end(next_bb);
            }
            continue;
        }
        if `case.guard is not None {
            bind_bb = func.append_basic_block(name=f"match.c{ci}.bind");
            self.builder.cbranch(cond, bind_bb, next_bb);
            self.builder.position_at_end(bind_bb);
            self._bind_match_pattern(`case.pattern, subj_val, subj_ty);
            gval = self._codegen_expr(`case.guard);
            if gval is not None {
                self.builder.cbranch(self._consume_bool(gval), body_bb, next_bb);
            } else {
                self.builder.branch(next_bb);
            }
        } else {
            self.builder.cbranch(cond, body_bb, next_bb);
        }

        self.builder.position_at_end(body_bb);
        if `case.guard is None {
            self._bind_match_pattern(`case.pattern, subj_val, subj_ty);
        }
        if isinstance(`case.body, (list, tuple)) {
            self._codegen_body(`case.body);
        }
        if not self.builder.block.is_terminated {
            self.builder.branch(end_bb);
        }
        if next_bb is not end_bb {
            self.builder.position_at_end(next_bb);
        }
    }
    self.builder.position_at_end(end_bb);
}

impl NaIRGenPass._match_pattern_cond(
    pat: uni.MatchPattern, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    if isinstance(pat, uni.MatchWild) {
        return ir.Constant(i1, 1);
    }
    if isinstance(pat, uni.MatchAs) {
        if pat.pattern is None {
            return ir.Constant(i1, 1);
        }
        return self._match_pattern_cond(pat.pattern, subj, subj_ty);
    }
    if isinstance(pat, uni.MatchValue) {
        return self._match_value_eq(subj, pat.value);
    }
    if isinstance(pat, uni.MatchSingleton) {
        return self._match_value_eq(subj, pat.value);
    }
    if isinstance(pat, uni.MatchOr) {
        result: (ir.Value | None) = None;
        for sub in pat.patterns {
            sub_cond = self._match_pattern_cond(sub, subj, subj_ty);
            if sub_cond is None {
                return None;
            }
            result = sub_cond
                if result is None
                else self.builder.or_(result, sub_cond, name="match.or");
        }
        return result;
    }
    if isinstance(pat, uni.MatchSequence) {
        return self._match_seq_cond(pat, subj, subj_ty);
    }
    if isinstance(pat, uni.MatchMapping) {
        return self._match_map_cond(pat, subj, subj_ty);
    }
    if isinstance(pat, uni.MatchArch) {
        return self._match_arch_cond(pat, subj, subj_ty);
    }

    self.ctx.emit(
        E5092, node_override=pat, kind="match pattern", name=type(pat).__name__
    );
    return None;
}

impl NaIRGenPass._match_subj_ty(expr: (uni.UniNode | None)) -> (TypeBase | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    if expr.type is not None {
        return expr.type;
    }
    if not isinstance(expr, uni.NameAtom) or expr.sym is None {
        return None;
    }
    decl = expr.sym.decl;
    if decl is None {
        return None;
    }
    holder = decl.find_parent_of_type(uni.Assignment)
        or decl.find_parent_of_type(uni.ParamVar)
        or decl.find_parent_of_type(uni.HasVar);
    tag = holder.type_tag if holder is not None else None;
    tag_expr = tag.tag if tag is not None else None;
    if isinstance(tag_expr, uni.Expr) and tag_expr.type is not None {
        try {
            import from jaclang.compiler.types.type_utils { convert_to_instance }
            return convert_to_instance(tag_expr.type);
        } except ImportError {
            return tag_expr.type;
        }
    }
    return None;
}

impl NaIRGenPass._match_seq_parts(
    pat: uni.MatchSequence
) -> tuple[list[uni.MatchPattern], uni.MatchStar | None, list[uni.MatchPattern]] {
    heads: list[uni.MatchPattern] = [];
    tails: list[uni.MatchPattern] = [];
    star: (uni.MatchStar | None) = None;
    for sub in pat.values {
        if isinstance(sub, uni.MatchStar) {
            star = sub;
        } elif star is not None {
            tails.append(sub);
        } else {
            heads.append(sub);
        }
    }
    return (heads, star, tails);
}

impl NaIRGenPass._match_elem_ty_of(
    subj_ty: (TypeBase | None), prefix: str, idx: int
) -> (TypeBase | None) {
    if not isinstance(subj_ty, ClassType) {
        return None;
    }
    mangled = self._mangled_of(subj_ty);
    if mangled is None or not mangled.startswith(prefix) {
        return None;
    }
    targs: list[TypeBase] = subj_ty.private.type_args or [];
    if idx < len(targs) {
        return targs[idx];
    }
    return None;
}

impl NaIRGenPass._match_cast_elem(
    elem: ir.Value, elem_ty: (TypeBase | None)
) -> ir.Value {
    if elem_ty is None or not isinstance(elem.type, ir.PointerType) {
        return elem;
    }
    lowered = self._lower_type(elem_ty);
    if lowered is not None
        and isinstance(lowered, ir.PointerType)
        and lowered != elem.type {
        return self.builder.bitcast(elem, lowered, name="match.elem.cast");
    }
    return elem;
}

impl NaIRGenPass._match_seq_cond(
    pat: uni.MatchSequence, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i64 = ir.IntType(64);
    (heads, star, tails) = self._match_seq_parts(pat);
    spec = self._infer_list_elem_type(subj);
    if spec is None {
        if isinstance(subj.type, ir.PointerType)
            and isinstance(subj.type.pointee, ir.LiteralStructType) {
            return self._match_tuple_seq_cond(pat, subj, subj_ty);
        }
        self.ctx.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchSequence",
            help_text="The match subject could not be resolved to a native list or tuple layout. Annotate the subject with a concrete list[...] type, or move this code to a @sv/Python context."
        );
        return None;
    }
    helpers = self.list_helpers[spec];
    elem_ty = self._match_elem_ty_of(subj_ty, "list[", 0);
    func = self.builder.function;
    res = self._entry_alloca(i1, "match.seq.res");
    self.builder.store(ir.Constant(i1, 0), res);
    merge_bb = func.append_basic_block(name="match.seq.merge");
    len_val = self.builder.call(helpers["len"], [subj], name="match.seq.len");
    n_tails = len(tails);
    min_len = ir.Constant(i64, len(heads) + n_tails);
    len_ok = (
        self.builder.icmp_signed(">=", len_val, min_len, name="match.seq.lenok")
            if star is not None
            else self.builder.icmp_signed(
                "==", len_val, min_len, name="match.seq.lenok"
            )
    );
    chk_bb = func.append_basic_block(name="match.seq.chk");
    self.builder.cbranch(len_ok, chk_bb, merge_bb);
    self.builder.position_at_end(chk_bb);
    for (i, sub_pat) in enumerate(heads) {
        elem: ir.Value = self.builder.call(
            helpers["get"], [subj, ir.Constant(i64, i)], name="match.seq.elem"
        );
        elem = self._match_cast_elem(elem, elem_ty);
        sub_cond = self._match_pattern_cond(sub_pat, elem, elem_ty);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.seq.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    for (j, sub_pat) in enumerate(tails) {
        idx = self.builder.sub(
            len_val, ir.Constant(i64, n_tails - j), name="match.seq.tidx"
        );
        elem = self.builder.call(helpers["get"], [subj, idx], name="match.seq.elem");
        elem = self._match_cast_elem(elem, elem_ty);
        sub_cond = self._match_pattern_cond(sub_pat, elem, elem_ty);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.seq.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    self.builder.store(ir.Constant(i1, 1), res);
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    return self.builder.load(res, name="match.seq.ok");
}

impl NaIRGenPass._match_tuple_seq_cond(
    pat: uni.MatchSequence, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    (heads, star, tails) = self._match_seq_parts(pat);
    if star is not None {
        self.ctx.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchStar",
            help_text="Star sub-patterns over a tuple-typed match subject are not lowered natively; match a list subject instead."
        );
        return None;
    }
    subject_type = subj.type;
    assert isinstance(subject_type, ir.PointerType);
    tuple_type = subject_type.pointee;
    assert isinstance(tuple_type, ir.BaseStructType);
    elements = tuple_type.elements;
    assert elements is not None;
    if len(elements) != len(heads) {
        return ir.Constant(i1, 0);
    }
    loaded = self.builder.load(subj, name="match.tup");
    result: (ir.Value | None) = None;
    for (i, sub_pat) in enumerate(heads) {
        elem = self.builder.extract_value(loaded, i, name="match.tup.elem");
        elem_ty = self._match_elem_ty_of(subj_ty, "tuple[", i);
        elem = self._match_cast_elem(elem, elem_ty);
        sub_cond = self._match_pattern_cond(sub_pat, elem, elem_ty);
        if sub_cond is None {
            return None;
        }
        result = sub_cond
            if result is None
            else self.builder.and_(result, sub_cond, name="match.tup.and");
    }
    return result if result is not None else ir.Constant(i1, 1);
}

impl NaIRGenPass._match_map_key(
    kv: uni.MatchKVPair, helpers: dict[str, any]
) -> (ir.Value | None) {
    key_node = kv.key.value if isinstance(kv.key, uni.MatchValue) else kv.key;
    key_val = self._codegen_expr(key_node) if isinstance(key_node, uni.Expr) else None;
    if key_val is None {
        self.ctx.emit(
            E5092,
            node_override=kv,
            kind="match pattern",
            name="MatchKVPair",
            help_text="Mapping pattern keys must be int/float/str literals to lower natively."
        );
        return None;
    }
    return self._coerce_type(key_val, helpers["key_type"]);
}

impl NaIRGenPass._match_map_cond(
    pat: uni.MatchMapping, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    dict_info = self._infer_dict_type(subj);
    if dict_info is None {
        self.ctx.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchMapping",
            help_text="The match subject could not be resolved to a native dict layout. Annotate the subject with a concrete dict[...] type, or move this code to a @sv/Python context."
        );
        return None;
    }
    (kspec, vspec) = dict_info;
    helpers = self.dict_helpers[f"{kspec}:{vspec}"];
    val_ty = self._match_elem_ty_of(subj_ty, "dict[", 1);
    func = self.builder.function;
    res = self._entry_alloca(i1, "match.map.res");
    self.builder.store(ir.Constant(i1, 0), res);
    merge_bb = func.append_basic_block(name="match.map.merge");
    for kv in pat.values {
        if isinstance(kv, uni.MatchStar) {
            continue;
        }
        key_val = self._match_map_key(kv, helpers);
        if key_val is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        _mk_nd = kv.key.value if isinstance(kv.key, uni.MatchValue) else kv.key;
        (_has_fn, _mkh) = self._static_key_op(helpers, "contains", _mk_nd);
        _has_args = [subj, key_val];
        if _mkh is not None {
            _has_args.append(_mkh);
        }
        has_key = self.builder.call(_has_fn, _has_args, name="match.map.has");
        val_bb = func.append_basic_block(name="match.map.val");
        self.builder.cbranch(has_key, val_bb, merge_bb);
        self.builder.position_at_end(val_bb);
        (_get_fn, _mgh) = self._static_key_op(helpers, "get", _mk_nd);
        _get_args = [subj, key_val];
        if _mgh is not None {
            _get_args.append(_mgh);
        }
        v: ir.Value = self.builder.call(_get_fn, _get_args, name="match.map.get");
        v = self._match_cast_elem(v, val_ty);
        sub_cond = self._match_pattern_cond(kv.value, v, val_ty);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.map.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    self.builder.store(ir.Constant(i1, 1), res);
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    return self.builder.load(res, name="match.map.ok");
}

impl NaIRGenPass._match_arch_fields(
    pat: uni.MatchArch, arch_name: str
) -> (list[tuple[str, uni.MatchPattern]] | None) {
    out: list[tuple[str, uni.MatchPattern]] = [];
    args = list(pat.arg_patterns) if pat.arg_patterns else [];
    if args {
        order = self.struct_field_order.get(arch_name);
        if order is None or len(args) > len(order) {
            return None;
        }
        for (i, sub_pat) in enumerate(args) {
            out.append((order[i], sub_pat));
        }
    }
    for kv in (list(pat.kw_patterns) if pat.kw_patterns else []) {
        fname = self._get_name(kv.key);
        if fname is None {
            return None;
        }
        out.append((fname, kv.value));
    }
    return out;
}

impl NaIRGenPass._match_arch_cond(
    pat: uni.MatchArch, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    arch_name = self._get_name(pat.name);
    if arch_name is None or arch_name not in self.struct_types {
        self.ctx.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchArch",
            help_text="Class patterns lower natively only for archetypes whose native layout is visible to this module, named without dots."
        );
        return None;
    }
    fields = self._match_arch_fields(pat, arch_name);
    if fields is None {
        self.ctx.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchArch",
            help_text=f"The class pattern's fields could not be mapped onto the native layout of '{arch_name}' (positional sub-patterns follow declared has-field order)."
        );
        return None;
    }
    static_name = self._struct_ptr_pointee_name(subj);
    if static_name is None
        and subj_ty is not None
        and isinstance(subj.type, ir.PointerType) {
        tk = self._mangled_of(subj_ty) or "";
        cands = [tk] + (tk.split("|") if "|" in tk else []);
        for part in cands {
            if part in self.struct_types {
                subj = self.builder.bitcast(
                    subj, self.struct_types[part].as_pointer(), name="match.arch.subj"
                );
                static_name = part;
                break;
            }
        }
    }
    if static_name is None {
        self.ctx.emit(
            E5092,
            node_override=pat,
            kind="match pattern",
            name="MatchArch",
            help_text="The match subject's static type could not be resolved to a native archetype layout. Annotate the subject with a concrete archetype type, or move this code to a @sv/Python context."
        );
        return None;
    }
    vt_mode = False;
    target_vtables: list[ir.GlobalVariable] = [];
    if static_name == arch_name and not self._arch_has_vtable(static_name) {
        vt_mode = False;
    } elif self._arch_has_vtable(static_name) {
        target_vtables = self._vtable_candidates([arch_name]);
        if not target_vtables {
            return ir.Constant(i1, 0);
        }
        vt_mode = True;
    } else {
        return ir.Constant(i1, 0);
    }
    func = self.builder.function;
    res = self._entry_alloca(i1, "match.arch.res");
    self.builder.store(ir.Constant(i1, 0), res);
    merge_bb = func.append_basic_block(name="match.arch.merge");
    null_ptr = ir.Constant(subj.type, None);
    nonnull = self.builder.icmp_unsigned("!=", subj, null_ptr, name="match.arch.nn");
    chk_bb = func.append_basic_block(name="match.arch.chk");
    self.builder.cbranch(nonnull, chk_bb, merge_bb);
    self.builder.position_at_end(chk_bb);
    if vt_mode {
        i8_pp = i8.as_pointer().as_pointer();
        op_as = self.builder.bitcast(subj, i8_pp.as_pointer(), name="match.arch.obj");
        vptr = self.builder.load(op_as, name="match.arch.vptr");
        cmp: (ir.Value | None) = None;
        for vt in target_vtables {
            vt_base = self.builder.gep(
                vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="match.arch.vt"
            );
            eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="match.arch.eq");
            cmp = eq
                if cmp is None
                else self.builder.or_(cmp, eq, name="match.arch.or");
        }
        fld_bb = func.append_basic_block(name="match.arch.fld");
        self.builder.cbranch(cmp, fld_bb, merge_bb);
        self.builder.position_at_end(fld_bb);
    }
    for (fname, sub_pat) in fields {
        fv = self._codegen_field_access(subj, fname, arch_name, pat);
        if fv is None {
            self.ctx.emit(
                E5092,
                node_override=pat,
                kind="match pattern",
                name="MatchArch",
                help_text=f"'{arch_name}' has no native field '{fname}'."
            );
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        sub_cond = self._match_pattern_cond(sub_pat, fv, None);
        if sub_cond is None {
            self.builder.branch(merge_bb);
            self.builder.position_at_end(merge_bb);
            return None;
        }
        next_bb = func.append_basic_block(name="match.arch.chk");
        self.builder.cbranch(sub_cond, next_bb, merge_bb);
        self.builder.position_at_end(next_bb);
    }
    self.builder.store(ir.Constant(i1, 1), res);
    self.builder.branch(merge_bb);
    self.builder.position_at_end(merge_bb);
    return self.builder.load(res, name="match.arch.ok");
}

impl NaIRGenPass._match_value_eq(
    subj: ir.Value, value_node: uni.UniNode
) -> (ir.Value | None) {
    _mv = value_node.expr if isinstance(value_node, uni.CfgExpr) else value_node;
    if isinstance(_mv, uni.AtomUnit) {
        _mv = _mv.value;
    }
    if isinstance(_mv, uni.Null)
        and self._opt_payload_of(subj.type) is None
        and not isinstance(subj.type, ir.PointerType)
        and not (bool(self?.jacval_type) and subj.type == self.jacval_type) {
        return ir.Constant(ir.IntType(1), 0);
    }
    pat = self._codegen_expr(value_node);
    if pat is None {
        return None;
    }

    if isinstance(subj.type, ir.IntType)
        and isinstance(pat.type, ir.IntType)
        and subj.type != pat.type {
        pat = self._coerce_type(pat, subj.type);
    }
    is_float = isinstance(subj.type, (ir.DoubleType, ir.FloatType))
        or isinstance(pat.type, (ir.DoubleType, ir.FloatType));
    (lhs, rhs) = (subj, pat);
    if is_float {
        (lhs, rhs) = self._promote_to_float(subj, pat);
    }
    cmp = self._emit_comparison(Tok.EE, lhs, rhs, is_float);
    if cmp is None {
        return None;
    }
    return self._consume_bool(cmp);
}

impl NaIRGenPass._bind_match_pattern(
    pat: uni.MatchPattern, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> None {
    if isinstance(pat, uni.MatchAs) {
        cap_name = self._get_name(pat.name) if pat.name else None;
        if cap_name is not None {
            self._bind_match_capture(cap_name, subj);
        }
        if pat.pattern is not None {
            self._bind_match_pattern(pat.pattern, subj, subj_ty);
        }
    } elif isinstance(pat, uni.MatchSequence) {
        self._bind_match_seq(pat, subj, subj_ty);
    } elif isinstance(pat, uni.MatchMapping) {
        self._bind_match_map(pat, subj, subj_ty);
    } elif isinstance(pat, uni.MatchArch) {
        self._bind_match_arch(pat, subj, subj_ty);
    }
}

impl NaIRGenPass._bind_match_capture(
    cap_name: str, val: ir.Value, owned: bool = False
) -> None {
    alloca = self.local_vars.get(cap_name);
    if alloca is None
        or not isinstance(alloca.type, ir.PointerType)
        or alloca.pointee_type != val.type {
        alloca = self._entry_alloca(val.type, cap_name);
        if isinstance(val.type, ir.PointerType) {
            _func_b = self.builder.function;
            _ebb = _func_b.entry_basic_block;
            _cur_bb = self.builder.block;
            _entry_instrs = list(_ebb.instructions);
            if len(_entry_instrs) >= 2 {
                self.builder.position_before(_entry_instrs[1]);
            } else {
                self.builder.position_at_end(_ebb);
            }
            self.builder.store(ir.Constant(val.type, None), alloca);
            self.builder.position_at_end(_cur_bb);
        }
        self.local_vars[cap_name] = alloca;
    }
    if isinstance(val.type, ir.PointerType) {
        if not owned and not self._is_owned(val) {
            self._emit_rc_retain(val, op="match_bind", loc="");
        }
        old_val = self.builder.load(alloca, name=f"{cap_name}.old");
        self._emit_rc_release_typed(old_val, op="match_bind", loc="");
    }
    self.builder.store(val, alloca);
}

impl NaIRGenPass._bind_match_seq(
    pat: uni.MatchSequence, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> None {
    i64 = ir.IntType(64);
    (heads, star, tails) = self._match_seq_parts(pat);
    spec = self._infer_list_elem_type(subj);
    if spec is None {
        if isinstance(subj.type, ir.PointerType)
            and isinstance(subj.type.pointee, ir.LiteralStructType)
            and star is None
            and len(subj.type.pointee.elements) == len(heads) {
            loaded = self.builder.load(subj, name="match.tup");
            for (i, sub_pat) in enumerate(heads) {
                elem = self.builder.extract_value(loaded, i, name="match.tup.elem");
                elem_ty = self._match_elem_ty_of(subj_ty, "tuple[", i);
                elem = self._match_cast_elem(elem, elem_ty);
                self._bind_match_pattern(sub_pat, elem, elem_ty);
            }
        }
        return;
    }
    helpers = self.list_helpers[spec];
    elem_ty = self._match_elem_ty_of(subj_ty, "list[", 0);
    len_val = self.builder.call(helpers["len"], [subj], name="match.seq.blen");
    n_tails = len(tails);
    for (i, sub_pat) in enumerate(heads) {
        elem: ir.Value = self.builder.call(
            helpers["get"], [subj, ir.Constant(i64, i)], name="match.seq.belem"
        );
        elem = self._match_cast_elem(elem, elem_ty);
        self._bind_match_pattern(sub_pat, elem, elem_ty);
    }
    for (j, sub_pat) in enumerate(tails) {
        idx = self.builder.sub(
            len_val, ir.Constant(i64, n_tails - j), name="match.seq.btidx"
        );
        elem = self.builder.call(helpers["get"], [subj, idx], name="match.seq.belem");
        elem = self._match_cast_elem(elem, elem_ty);
        self._bind_match_pattern(sub_pat, elem, elem_ty);
    }
    star_name = self._get_name(star.name) if star is not None else None;
    if star is None or star_name is None or star_name == "_" {
        return;
    }
    _loc = f"{os.path.basename(self.module.loc.mod_path)}:{star.loc.first_line
        if star.loc
        else 0}";
    rest = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="match.star"
    );
    self._mark_owned(rest);
    func = self.builder.function;
    idx_alloca = self._entry_alloca(i64, "match.star.i");
    self.builder.store(ir.Constant(i64, len(heads)), idx_alloca);
    end_idx = self.builder.sub(
        len_val, ir.Constant(i64, n_tails), name="match.star.end"
    );
    cond_bb = func.append_basic_block(name="match.star.cond");
    body_bb = func.append_basic_block(name="match.star.body");
    done_bb = func.append_basic_block(name="match.star.done");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur = self.builder.load(idx_alloca, name="match.star.cur");
    cont = self.builder.icmp_signed("<", cur, end_idx, name="match.star.lt");
    self.builder.cbranch(cont, body_bb, done_bb);
    self.builder.position_at_end(body_bb);
    elem = self.builder.call(helpers["get"], [subj, cur], name="match.star.elem");
    self.builder.call(helpers["append"], [rest, elem]);
    nxt = self.builder.add(cur, ir.Constant(i64, 1), name="match.star.nxt");
    self.builder.store(nxt, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(done_bb);
    self._bind_match_capture(star_name, rest, owned=True);
}

impl NaIRGenPass._bind_match_map(
    pat: uni.MatchMapping, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> None {
    i64 = ir.IntType(64);
    dict_info = self._infer_dict_type(subj);
    if dict_info is None {
        return;
    }
    (kspec, vspec) = dict_info;
    helpers = self.dict_helpers[f"{kspec}:{vspec}"];
    val_ty = self._match_elem_ty_of(subj_ty, "dict[", 1);
    star: (uni.MatchStar | None) = None;
    matched_keys: list[ir.Value] = [];
    for kv in pat.values {
        if isinstance(kv, uni.MatchStar) {
            star = kv;
            continue;
        }
        key_val = self._match_map_key(kv, helpers);
        if key_val is None {
            continue;
        }
        matched_keys.append(key_val);
        _mk_nd = kv.key.value if isinstance(kv.key, uni.MatchValue) else kv.key;
        (_get_fn, _mgh) = self._static_key_op(helpers, "get", _mk_nd);
        _get_args = [subj, key_val];
        if _mgh is not None {
            _get_args.append(_mgh);
        }
        v: ir.Value = self.builder.call(_get_fn, _get_args, name="match.map.bget");
        v = self._match_cast_elem(v, val_ty);
        self._bind_match_pattern(kv.value, v, val_ty);
    }
    star_name = self._get_name(star.name) if star is not None else None;
    if star is None or star_name is None or star_name == "_" {
        return;
    }
    _loc = f"{os.path.basename(self.module.loc.mod_path)}:{star.loc.first_line
        if star.loc
        else 0}";
    rest = self._rc_call_with_ctx(
        helpers["new"], [], op="new", loc=_loc, name="match.map.rest"
    );
    self._mark_owned(rest);
    func = self.builder.function;
    idx_alloca = self._entry_alloca(i64, "match.map.rest.i");
    self.builder.store(ir.Constant(i64, 0), idx_alloca);
    len_val = self.builder.call(helpers["len"], [subj], name="match.map.blen");
    cond_bb = func.append_basic_block(name="match.rest.cond");
    body_bb = func.append_basic_block(name="match.rest.body");
    copy_bb = func.append_basic_block(name="match.rest.copy");
    incr_bb = func.append_basic_block(name="match.rest.incr");
    done_bb = func.append_basic_block(name="match.rest.done");
    self.builder.branch(cond_bb);
    self.builder.position_at_end(cond_bb);
    cur = self.builder.load(idx_alloca, name="match.rest.cur");
    cont = self.builder.icmp_signed("<", cur, len_val, name="match.rest.lt");
    self.builder.cbranch(cont, body_bb, done_bb);
    self.builder.position_at_end(body_bb);
    k = self.builder.call(helpers["get_key"], [subj, cur], name="match.rest.k");
    skip_cond: (ir.Value | None) = None;
    for mk in matched_keys {
        eqk = self._emit_key_comparison(self.builder, helpers["key_type"], k, mk);
        skip_cond = eqk
            if skip_cond is None
            else self.builder.or_(skip_cond, eqk, name="match.rest.skip");
    }
    if skip_cond is None {
        self.builder.branch(copy_bb);
    } else {
        self.builder.cbranch(skip_cond, incr_bb, copy_bb);
    }
    self.builder.position_at_end(copy_bb);
    v2 = self.builder.call(helpers["get_val"], [subj, cur], name="match.rest.v");
    self.builder.call(helpers["set"], [rest, k, v2]);
    self.builder.branch(incr_bb);
    self.builder.position_at_end(incr_bb);
    nxt = self.builder.add(cur, ir.Constant(i64, 1), name="match.rest.nxt");
    self.builder.store(nxt, idx_alloca);
    self.builder.branch(cond_bb);
    self.builder.position_at_end(done_bb);
    self._bind_match_capture(star_name, rest, owned=True);
}

impl NaIRGenPass._bind_match_arch(
    pat: uni.MatchArch, subj: ir.Value, subj_ty: (TypeBase | None) = None
) -> None {
    arch_name = self._get_name(pat.name);
    if arch_name is None or arch_name not in self.struct_types {
        return;
    }
    fields = self._match_arch_fields(pat, arch_name);
    if fields is None {
        return;
    }
    for (fname, sub_pat) in fields {
        fv = self._codegen_field_access(subj, fname, arch_name, pat);
        if fv is not None {
            self._bind_match_pattern(sub_pat, fv, None);
        }
    }
}
