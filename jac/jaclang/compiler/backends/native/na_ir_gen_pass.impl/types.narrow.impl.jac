impl NaIRGenPass._jac_optional_type(payload: ir.Type) -> ir.Type {
    key = str(payload);
    _existing = self._opt_struct_types.get(key);
    if _existing is not None {
        return _existing;
    }
    n = len(self._opt_struct_types) + 1;
    st = self.llvm_module.context.get_identified_type(f"JacOpt.{n}");
    st.set_body(ir.IntType(8), payload);
    self._opt_struct_types[key] = st;
    return st;
}

impl NaIRGenPass._opt_payload_of(t: ir.Type) -> (ir.Type | None) {
    if isinstance(t, ir.IdentifiedStructType) and t.name.startswith("JacOpt.") {
        elements = t.elements;
        assert elements is not None and len(elements) == 2;
        payload = elements[1];
        assert isinstance(payload, ir.Type);
        return payload;
    }
    return None;
}

impl NaIRGenPass._narrowed_flow_type(nd: uni.UniNode) -> (TypeBase | None) {
    return nd.type if isinstance(nd, uni.Expr) else None;
}

impl NaIRGenPass._narrowing_blocked_by_none_test(nd: uni.UniNode) -> bool {
    _p = nd.parent;
    while isinstance(_p, (uni.AtomUnit, uni.CfgExpr)) {
        _p = _p.parent;
    }
    if not isinstance(_p, uni.CompareExpr) {
        return False;
    }
    _has_id_op = False;
    for _op in (_p.ops or []) {
        if isinstance(_op, uni.Token)
            and _op.name in (Tok.KW_IS, Tok.KW_ISN, Tok.EE, Tok.NE) {
            _has_id_op = True;
            break;
        }
    }
    if not _has_id_op {
        return False;
    }
    for _side in [_p.left, *(_p.rights or [])] {
        _s: uni.UniNode = _side.expr if isinstance(_side, uni.CfgExpr) else _side;
        if isinstance(_s, uni.AtomUnit) {
            _s = _s.value;
        }
        if isinstance(_s, uni.Null) {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._narrowing_stable_in_loops(nd: uni.UniNode, name: str) -> bool {
    _cur: (uni.UniNode | None) = nd;
    _child: (uni.UniNode | None) = None;
    while _cur is not None {
        if isinstance(_cur, (uni.Ability, uni.Module, uni.LambdaExpr)) {
            return True;
        }
        if isinstance(
            _cur, (uni.WhileStmt, uni.ForeverStmt, uni.InForStmt, uni.IterForStmt)
        )
            and self._loop_rebinds_name(_cur, name)
            and not self._body_assigns_before(_cur, _child, name) {
            return False;
        }
        _child = _cur;
        _cur = _cur.parent;
    }
    return True;
}

impl NaIRGenPass._loop_rebinds_name(loop: uni.UniNode, name: str) -> bool {
    _key = (id(loop), name);
    _hit = self._loop_rebind_memo.get(_key);
    if _hit is not None {
        return _hit;
    }
    _found = False;
    for _asn in loop.get_all_sub_nodes(uni.Assignment) {
        for _t in (_asn.target or []) {
            for _tn in (
                [_t] if isinstance(_t, uni.Name) else _t.get_all_sub_nodes(uni.Name)
            ) {
                if _tn.value == name {
                    _found = True;
                    break;
                }
            }
            if _found {
                break;
            }
        }
        if _found {
            break;
        }
    }
    if not _found {
        for _b in loop.get_all_sub_nodes(uni.BinaryExpr) {
            if isinstance(_b.op, uni.Token)
                and _b.op.name == Tok.WALRUS_EQ
                and isinstance(_b.left, uni.Name)
                and _b.left.value == name {
                _found = True;
                break;
            }
        }
    }
    self._loop_rebind_memo[_key] = _found;
    return _found;
}

impl NaIRGenPass._body_assigns_before(
    loop: uni.WhileStmt | uni.ForeverStmt | uni.InForStmt | uni.IterForStmt,
    child: (uni.UniNode | None),
    name: str
) -> bool {
    if isinstance(loop, uni.InForStmt) {
        for _tn in loop.target.get_all_sub_nodes(uni.Name) {
            if _tn.value == name {
                return True;
            }
        }
    }
    _body = loop.body;
    if child is None {
        return False;
    }
    _idx = -1;
    for (_i, _stmt) in enumerate(_body) {
        if _stmt is child {
            _idx = _i;
            break;
        }
    }
    if _idx < 0 {
        return False;
    }
    for _stmt in _body[:_idx] {
        if not isinstance(_stmt, uni.Assignment) {
            continue;
        }
        for _t in (_stmt.target or []) {
            if isinstance(_t, uni.Name) and _t.value == name {
                return True;
            }
        }
    }
    return False;
}

impl NaIRGenPass._apply_flow_narrowing(nd: uni.UniNode, val: ir.Value) -> ir.Value {
    """Retype a read to what the checker narrowed this occurrence to.

    Three storages can arrive here. A `JacOpt` unwraps to its payload and a
    boxed `jacval` unboxes, both of which this has always done. A union whose
    members are all pointers keeps the *first* member's pointer layout rather
    than boxing, so its narrow is a bitcast -- gated below on the analysis
    having actually stamped a narrow for this occurrence, because a bare
    `dict` or `list` annotation lowers to a default flavour that is not the
    one the value already carries, and re-typing to it would hand a jacval
    container the helpers of an integer one.

    Only a `Name` is retyped. A member reference is narrowed by an
    intra-procedural walk that cannot see a callee rebinding the attribute,
    so consuming its narrow here would replace a checked unwrap with a blind
    payload read -- `optional_narrowing.jac`'s `callee_rebinds_attr` is
    exactly that hole. Class resolution off such a narrow is still fine and
    happens in `_struct_name_of`; what is refused here is dropping the tag.
    """;
    _src_opt = self._opt_payload_of(val.type);
    _is_jv = bool(self?.jacval_type) and val.type == self.jacval_type;
    _is_ptr = _src_opt is None and not _is_jv and isinstance(val.type, ir.PointerType);
    if _src_opt is None and not _is_jv and not _is_ptr {
        return val;
    }
    if not isinstance(nd, uni.Name) {
        if _is_jv and isinstance(nd, uni.AtomTrailer) {
            return self._unbox_narrowed_member(nd, val);
        }
        return val;
    }
    _nm = nd.value;
    if _nm not in self.local_vars or _nm in self.closure_cell_vars {
        return val;
    }
    if not self._narrowing_stable_in_loops(nd, _nm) {
        return val;
    }
    if self._narrowing_blocked_by_none_test(nd) {
        return val;
    }
    _nt = self._narrowed_flow_type(nd);
    if _nt is None {
        return val;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return val;
    }
    if not isinstance(_nt, _ClassType)
        or _nt.shared.class_name in ("NoneType", "None") {
        return val;
    }
    _want = self._lower_type(_nt);
    _nt_bare = False;
    if _nt.shared.class_name in ("list", "Sequence") {
        _nt_args: list[TypeBase] = _nt.private.type_args or [];
        _nt_bare = not _nt_args;
        if not _nt_bare and len(_nt_args) == 1 {
            _a0 = _nt_args[0];
            _nt_bare = (
                isinstance(_a0, _ClassType)
                and _a0.shared.class_name in ("any", "Any", "object")
            );
        }
        if _nt_bare and not _is_ptr and self?.jacval_type {
            self._emit_list_helpers("jacval", self.jacval_type);
            _want = self.list_types["jacval"].as_pointer();
        }
    }
    if _want is None or isinstance(_want, ir.VoidType) or _want == val.type {
        return val;
    }
    if _is_ptr {
        if not (isinstance(nd, uni.Expr) and nd.narrowed_type is not None) {
            return val;
        }
        if not (_nt.private.type_args or [])
            or _nt.shared.class_name
                not in ("list", "Sequence", "dict", "set", "frozenset", "tuple")
            or not isinstance(_want, ir.PointerType) {
            return val;
        }
        return self.builder.bitcast(val, _want, name="ptr.narrowed");
    }
    if _src_opt is not None {
        return self.builder.extract_value(val, 1, name="opt.narrowed");
    }
    _ub_want = _want;
    if self._str_desc_ty is not None and _want == self._str_desc_ty {
        _ub_want = ir.IntType(8).as_pointer();
    }
    if not isinstance(
        _ub_want, (ir.IntType, ir.DoubleType, ir.FloatType, ir.PointerType)
    ) {
        return val;
    }
    _ub = self._unbox_from_jacval(val, _ub_want);
    if _ub_want != _want {
        return self._coerce_type(_ub, _want);
    }
    return _ub;
}

impl NaIRGenPass._unbox_narrowed_member(
    nd: uni.AtomTrailer, val: ir.Value
) -> ir.Value {
    """Unbox a member read the checker narrowed to one heap kind.

    A member typed as a mix of heap kinds (`list[Item] | Item`) is stored
    boxed, and the analysis pipeline stamps `narrowed_type` on an occurrence
    it has narrowed (`src.body` after `isinstance(src.body, list)`). Before
    unions boxed, every pointer union carried its first member's layout and
    the narrow was a free reinterpretation; the box needs an explicit unbox
    or the consumer sees a jacval where the checker promised a list, and
    `list(src.body)` refuses to lower. Only a class or container narrow
    unboxes here: an Optional payload read stays a Name-only retype, because
    a callee can rebind an attribute to None between the test and the use
    (`optional_narrowing.jac`'s `callee_rebinds_attr`), and that unwrap must
    keep its tag check.
    """;
    if not isinstance(nd, uni.Expr) or nd.narrowed_type is None {
        return val;
    }
    if self._narrowing_blocked_by_none_test(nd) {
        return val;
    }
    _nt = nd.narrowed_type;
    try {
        import from jaclang.compiler.types.types { ClassType as _ClassType }
    } except ImportError {
        return val;
    }
    if not isinstance(_nt, _ClassType)
        or _nt.shared.class_name in ("NoneType", "None") {
        return val;
    }
    _want = self._lower_type(_nt);
    if _want is None
        or isinstance(_want, ir.VoidType)
        or _want == val.type
        or self._opt_payload_of(_want) is not None
        or not isinstance(_want, ir.PointerType)
        or isinstance(_want.pointee, ir.FunctionType) {
        return val;
    }
    return self._unbox_from_jacval(val, _want);
}

impl NaIRGenPass._opt_ptr_payload_of(t: ir.Type) -> (ir.Type | None) {
    _pt = self._opt_payload_of(t);
    if (
        _pt is not None
        and isinstance(_pt, ir.PointerType)
        and not isinstance(_pt.pointee, ir.FunctionType)
    ) {
        return _pt;
    }
    return None;
}
