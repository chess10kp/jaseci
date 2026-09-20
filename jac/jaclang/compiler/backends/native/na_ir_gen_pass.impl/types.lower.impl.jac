import from jaclang.compiler.expr_keys { type_tag_borrows }


impl NaIRGenPass._lower_type(t: any) -> (ir.Type | None) {
    if t is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types {
            ClassType as _ClassType,
            UnionType as _UnionType,
            FunctionType as _FunctionType,
            NeverType as _NeverType,
            AnyType as _AnyType,
            TypeVarType as _TypeVarType,
            EnumMemberType as _EnumMemberType
        }
    } except ImportError {
        return None;
    }
    if isinstance(t, _TypeVarType) {
        _sol = self._mono_solution;
        if _sol is not None and t.name in _sol {
            return self._lower_type(_sol[t.name]);
        }
        if t.bound is not None {
            bound = self._lower_type(t.bound);
            if isinstance(bound, ir.PointerType) {
                return ir.IntType(8).as_pointer();
            }
        }
        return None;
    }
    mangled = self._mangled_of(t);

    key = (t, mangled) if isinstance(t, TypeBase) and mangled is not None else None;
    if key is not None and key in self._lowered_type_cache {
        return self._lowered_type_cache[key];
    }
    lowered: (ir.Type | None) = None;
    if isinstance(t, _NeverType) {
        lowered = ir.VoidType();
    } elif isinstance(t, _AnyType) {
        lowered = self.jacval_type;
    } elif isinstance(t, _EnumMemberType) {
        lowered = self._lower_type(t.enum_class) if t.enum_class is not None else None;
    } elif isinstance(t, _ClassType) {
        lowered = self._lower_class_type(t);
    } elif isinstance(t, _UnionType) {
        lowered = ir.VoidType();
        _members: list[TypeBase] = [];
        for m in (t.types or []) {
            if isinstance(m, _ClassType)
                and m.shared.class_name in ("NoneType", "None") {
                continue;
            }
            _members.append(m);
        }
        _had_none = len(_members) < len(t.types or []);
        if _members {
            _mreprs: list[ir.Type] = [];
            for _m in _members {
                _mr = self._lower_type(_m);
                if self._str_desc_ty is not None and _mr == self._str_desc_ty {
                    _mr = ir.IntType(8).as_pointer();
                }
                _mreprs.append(_mr);
            }
            _mlow = self._unify_repr_lowering(_mreprs);
            if (
                _had_none
                and len(_members) == 1
                and _mlow is not None
                and not isinstance(_mlow, ir.VoidType)
                and _mlow != self.jacval_type
            ) {
                lowered = self._jac_optional_type(_mlow);
            } else {
                lowered = _mlow;
            }
        }
    } elif isinstance(t, _FunctionType) {
        lowered = self._lower_function_type(t);
    }
    if key is not None and lowered is not None {
        self._lowered_type_cache[key] = lowered;
    }
    return lowered;
}

impl NaIRGenPass._unify_repr_lowering(reprs: list[ir.Type]) -> (ir.Type | None) {
    """One representation for a set of lowerings that share a slot.

    Members that share a lowering keep it. An all-pointer set keeps the
    first member's layout only when every member is the same kind of
    pointer, or when every member is callable: a closure struct and a raw
    function pointer meet at one calling convention once the raw function
    is wrapped into a closure (`_coerce_type` does the wrapping), so the
    closure layout is the union's layout and boxing them would leave
    nothing callable behind. Any other mix, including two headered heap
    kinds such as `list | Expr` in the unitree, boxes to a tagged jacval so
    the payload is never reinterpreted through the wrong layout.
    """;
    if not reprs {
        return None;
    }
    _first = reprs[0];
    _rest = reprs[1:];
    if _first is None or not _rest {
        return _first;
    }
    _shared = True;
    _all_ptr = isinstance(_first, ir.PointerType);
    for _r in _rest {
        if _r is None {
            return _first;
        }
        if _r != _first {
            _shared = False;
        }
        if not isinstance(_r, ir.PointerType) {
            _all_ptr = False;
        }
    }
    if _shared or not self?.jacval_type {
        return _first;
    }
    if _all_ptr {
        _kinds = [self._ptr_box_kind(_first)];
        for _r in _rest {
            _kinds.append(self._ptr_box_kind(_r));
        }
        _same_kind = True;
        _all_callable = True;
        for _k in _kinds {
            if _k != _kinds[0] {
                _same_kind = False;
            }
            if _k != 7 {
                _all_callable = False;
            }
        }
        if _same_kind {
            return _first;
        }

        if _all_callable {
            for _r in reprs {
                if self._closure_struct_of(_r) is not None {
                    return _r;
                }
            }
            return _first;
        }
    }
    return self.jacval_type;
}

impl NaIRGenPass._ptr_box_kind(rt: any) -> int {
    if isinstance(rt, ir.PointerType) and isinstance(rt.pointee, ir.FunctionType) {
        return 7;
    }
    if self._closure_struct_of(rt) is not None {
        return 7;
    }
    for (_, ltype) in self.list_types.items() {
        if rt == ltype.as_pointer() {
            return 3;
        }
    }
    for (_, dtype) in self.dict_types.items() {
        if rt == dtype.as_pointer() {
            return 4;
        }
    }
    for (_, stype) in self.set_types.items() {
        if rt == stype.as_pointer() {
            return 5;
        }
    }
    for (_, structt) in self.struct_types.items() {
        if rt == structt.as_pointer() {
            return 6;
        }
    }
    return 2;
}

impl NaIRGenPass._type_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    return self._mangled_of(expr.type);
}

impl NaIRGenPass._enum_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    import from jaclang.compiler.types.types {
        ClassType as EnumClassType,
        EnumMemberType,
        TypeBase,
        UnionType
    }
    t = self._flow_narrowed_type_of(expr);
    if not isinstance(t, TypeBase) {
        return None;
    }
    pending: list[TypeBase] = [t];
    enum_class: EnumClassType | None = None;
    while pending {
        member = pending.pop();
        if isinstance(member, UnionType) {
            pending.extend(member.types);
            continue;
        }
        candidate = member.enum_class if isinstance(member, EnumMemberType) else member;
        if not isinstance(candidate, EnumClassType) or not candidate.is_enum_class() {
            return None;
        }
        if enum_class is not None and candidate.shared is not enum_class.shared {
            return None;
        }
        enum_class = candidate;
    }
    return enum_class.shared.class_name if enum_class is not None else None;
}

impl NaIRGenPass._tuple_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    tk = self._mangled_of(expr.type);
    if tk is None or not tk.startswith("tuple[") {
        return None;
    }
    lowered = self._lower_type(expr.type);
    if lowered is None
        or not isinstance(lowered, ir.PointerType)
        or not isinstance(lowered.pointee, ir.LiteralStructType) {
        return None;
    }
    elems = lowered.pointee.elements;
    return f"Tuple.{len(elems)}." + ".".join([str(x) for x in elems]);
}

impl NaIRGenPass._set_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    return self._spec_of(expr, ("set", "frozenset"), self.set_types);
}

impl NaIRGenPass._dict_key_of(expr: (uni.UniNode | None)) -> (str | None) {
    return self._spec_of(expr, ("dict", ), self.dict_types);
}

impl NaIRGenPass._list_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    return self._spec_of(expr, ("list", "bytearray", "Sequence"), self.list_types);
}

impl NaIRGenPass._spec_of(
    expr: (uni.UniNode | None),
    names: tuple[str, ...],
    registry: dict[str, ir.IdentifiedStructType]
) -> (str | None) {
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    _t = expr.type;
    tk = self._mangled_of(_t);
    matched = self._spec_name_match(tk or "", names);
    if not matched {
        _sole = self._opt_sole_member(_t);
        if _sole is not None {
            _t = _sole;
            tk = self._mangled_of(_t);
            matched = self._spec_name_match(tk or "", names);
        }
    }
    if not matched {
        _agreed = self._spec_union_agreement(_t, names);
        if _agreed is not None {
            _t = _agreed;
            tk = self._mangled_of(_t);
            matched = True;
        }
    }
    if not matched {
        return None;
    }
    lowered = self._lower_type(_t);
    if lowered is None {
        return None;
    }
    for (spec, st) in registry.items() {
        if lowered == st.as_pointer() {
            return spec;
        }
    }
    return None;
}

impl NaIRGenPass._spec_name_match(tk: str, names: tuple[str, ...]) -> bool {
    if tk in names {
        return True;
    }
    for nm in names {
        if tk.startswith(nm + "[") {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._opt_sole_member(t: any) -> (TypeBase | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _OsClassType,
            UnionType as _OsUnionType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _OsUnionType) {
        return None;
    }
    _all: list[TypeBase] = t.types or [];
    _members = [
        m
        for m in _all
        if not (
            isinstance(m, _OsClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_members) != 1 or len(_members) == len(_all) {
        return None;
    }
    return _members[0];
}

impl NaIRGenPass._spec_union_agreement(t: any, names: tuple[str, ...]) -> (any | None) {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _SuClassType,
            UnionType as _SuUnionType
        }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _SuUnionType) {
        return None;
    }
    _members = [
        m
        for m in (t.types or [])
        if not (
            isinstance(m, _SuClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_members) < 2 {
        return None;
    }
    _low: any = None;
    for m in _members {
        if not self._spec_name_match(self._mangled_of(m) or "", names) {
            return None;
        }
        _ml = self._lower_type(m);
        if _ml is None {
            return None;
        }
        if _low is None {
            _low = _ml;
        } elif _ml != _low {
            return None;
        }
    }
    return _members[0];
}

impl NaIRGenPass._struct_name_of(expr: (uni.UniNode | None)) -> (str | None) {
    """Which archetype layout a receiver's field access should address.

    Two questions have to be answered together: *which type* to ask about,
    and *which key* that type resolves through. The type is the narrow the
    analysis stamped for this occurrence when there is one, so a receiver
    guarded by `isinstance` addresses the class it was narrowed to. The key
    is then resolved by `_struct_name_for_key`, which sees through a
    parameterised or union-mangled name to the base archetype the layout was
    built for -- a narrow that produces `SubTag[Token]` still has to land on
    `SubTag`.
    """;
    _narrowed = self._struct_name_for_key(
        self._mangled_of(self._flow_narrowed_type_of(expr))
    );
    if (
        isinstance(expr, uni.Name)
        and expr.value == "self"
        and self._self_arch is not None
    ) {
        if _narrowed is not None
            and _narrowed != self._self_arch
            and self._self_arch in self._mro_of(_narrowed) {
            return _narrowed;
        }
        return self._self_arch;
    }
    return _narrowed;
}

impl NaIRGenPass._struct_name_for_key(tk: (str | None)) -> (str | None) {
    if tk is None {
        return None;
    }
    if tk in self.struct_types {
        return tk;
    }
    _arch_parts = [
        part
        for part in self._split_union_key(tk)
        if part in self.struct_types
    ];
    if len(_arch_parts) == 1 {
        return _arch_parts[0];
    }
    if _arch_parts {
        for _anc in self._mro_of(_arch_parts[0]) {
            if _anc not in self.struct_types {
                continue;
            }
            _in_all = True;
            for _other in _arch_parts[1:] {
                if _anc not in self._mro_of(_other) {
                    _in_all = False;
                    break;
                }
            }
            if _in_all {
                return _anc;
            }
        }
        return None;
    }
    for part in self._split_union_key(tk) {
        _base = self._erased_arch_base(part);
        if _base is not None {
            return _base;
        }
    }
    return None;
}

impl NaIRGenPass._erased_arch_base(tk: str) -> (str | None) {
    _open = tk.find("[");
    if _open <= 0 or not tk.endswith("]") {
        return None;
    }
    _base = tk[:_open];
    return _base if _base in self.struct_types else None;
}

impl NaIRGenPass._split_union_key(tk: str) -> list[str] {
    if "|" not in tk {
        return [tk];
    }
    out: list[str] = [];
    depth = 0;
    start = 0;
    for i in range(len(tk)) {
        ch = tk[i];
        if ch == "[" {
            depth += 1;
        } elif ch == "]" {
            depth -= 1;
        } elif ch == "|" and depth == 0 {
            out.append(tk[start:i]);
            start = i + 1;
        }
    }
    out.append(tk[start:]);
    return out;
}

impl NaIRGenPass._flow_narrowed_type_of(
    expr: (uni.UniNode | None)
) -> (TypeBase | None) {
    """The narrow the analysis pipeline stamped on this occurrence.

    `Expr.type` records what the evaluator computed for the expression, and
    for a `Name` that is already the narrowed view -- the symbol's narrow is
    folded into the type that gets stored. A member or subscript reference is
    different: the evaluator stores the *member's* type there and hands the
    narrow to its caller, so `Expr.narrowed_type` is where that answer is
    kept. Reading it is a consumption of a central fact; the backend never
    asks analysis to compute one.
    """;
    if not isinstance(expr, uni.Expr) or expr.type is None {
        return None;
    }
    _nt = expr.narrowed_type;
    return _nt if _nt is not None else expr.type;
}

impl NaIRGenPass._struct_ptr_pointee_name(val: ir.Value) -> (str | None) {
    _vt = val.type;
    if isinstance(_vt, ir.PointerType)
        and isinstance(_vt.pointee, ir.IdentifiedStructType) {
        _name = _vt.pointee.name;
        if _name in self.struct_types and self.struct_types[_name] == _vt.pointee {
            return _name;
        }
    }
    return None;
}

impl NaIRGenPass._struct_array_elem_ptr(ptr: ir.Value, idx_val: ir.Value) -> ir.Value {
    _i64 = ir.IntType(64);
    _wide_idx = (
        idx_val
            if idx_val.type == _i64
            else self.builder.sext(idx_val, _i64, name="arr.idx.i64")
    );
    return self.builder.gep(ptr, [_wide_idx], name="ptr.elem.ptr");
}

impl NaIRGenPass._restore_list_read(
    value: (ir.Value | None), collection: uni.UniNode
) -> (ir.Value | None) {
    """Restore a list element's declared layout from shared container storage.

    Integer list slots use i64 even for sized integers. Reading such a slot
    recovers the declared bits; it is not an implicit narrowing conversion of
    an arbitrary expression. Pointer slots likewise recover their pointee.
    """;
    if value is None {
        return None;
    }
    expected = self._list_elem_llvm_of(collection);
    if isinstance(expected, ir.FloatType) and isinstance(value.type, ir.DoubleType) {
        return self.builder.fptrunc(value, expected, name="list.elem.float");
    }
    if isinstance(expected, ir.IntType)
        and isinstance(value.type, ir.IntType)
        and expected.width < value.type.width {
        return self.builder.trunc(value, expected, name="list.elem.bits");
    }
    if isinstance(expected, ir.PointerType)
        and isinstance(value.type, ir.PointerType)
        and expected != value.type {
        return self.builder.bitcast(value, expected, name="list.elem.ptr");
    }
    return value;
}

impl NaIRGenPass._list_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    return self._typed_elem_llvm_of(expr, "list[");
}

impl NaIRGenPass._iter_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    return self._typed_elem_llvm_of(expr, "Iterator[");
}

impl NaIRGenPass._typed_elem_llvm_of(
    expr: (uni.UniNode | None), prefix: str
) -> (ir.Type | None) {
    """Element storage for a container-typed expression.

    The type reaching here can be a union: a field read off a joined narrow
    (`isinstance(item, (TupleVal, ListVal))` then `item.values`) has one
    member type per narrowed class, and a union carries no `private` of its
    own. Members that agree on the container shape agree on its element type
    too, so the first matching member answers for all of them.

    An optional container (`list[T] | None`, the shape every `has` slot that
    defaults to `None` carries) is the same question asked of one member.
    Its mangle is the union's, so the prefix test has to be retried against
    the sole non-`None` member or the element type erases -- a comprehension
    or for-loop over `x.parts or []` would then walk elements it has no
    layout for. `_opt_sole_member` is the same unwrap `_list_spec_of` uses
    to recognise the container itself, so the two answers stay congruent.
    """;
    _ty = self._flow_narrowed_type_of(expr);
    if _ty is None {
        return None;
    }
    _mg = self._mangled_of(_ty);
    if _mg is None or not _mg.startswith(prefix) {
        _sole = self._opt_sole_member(_ty);
        _sole_mg = self._mangled_of(_sole) if _sole is not None else None;
        if _sole_mg is None or not _sole_mg.startswith(prefix) {
            return None;
        }
        _ty = _sole;
    }
    candidates = _ty.types if isinstance(_ty, UnionType) else [_ty];
    for _cand in candidates {
        if isinstance(_cand, ClassType) and _cand.private.type_args {
            _ty = _cand;
            break;
        }
    }
    if not isinstance(_ty, ClassType) {
        return None;
    }
    args = _ty.private.type_args;
    if not args {
        return None;
    }
    lowered = self._elem_storage_llvm(args[0]);
    if lowered is not None and isinstance(lowered, ir.VoidType) {
        return ir.IntType(64);
    }
    return lowered;
}

impl NaIRGenPass._elem_storage_llvm(t: any) -> (ir.Type | None) {
    if t is None {
        return None;
    }
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EsClassType,
            UnionType as _EsUnionType
        }
    } except ImportError {
        return self._lower_type(t);
    }
    if not isinstance(t, _EsUnionType) {
        return self._lower_type(t);
    }
    _members = [
        m
        for m in (t.types or [])
        if not (
            isinstance(m, _EsClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    _had_none = len(_members) < len(t.types or []);
    if not _members {
        return self._lower_type(t);
    }
    _lowered: list[ir.Type] = [];
    for m in _members {
        _ml = self._lower_type(m);
        if _ml is None {
            return self.jacval_type;
        }
        _lowered.append(_ml);
    }
    _first = _lowered[0];
    _all_same = True;
    _all_ptr = isinstance(_first, ir.PointerType);
    for _ml in _lowered[1:] {
        if _ml != _first {
            _all_same = False;
        }
        if not isinstance(_ml, ir.PointerType) {
            _all_ptr = False;
        }
    }
    if _all_ptr {
        if _all_same and not _had_none {
            return _first;
        }
        return _first if _all_same else ir.IntType(8).as_pointer();
    }
    if _had_none or not _all_same {
        return self.jacval_type;
    }
    return _first;
}

impl NaIRGenPass._static_elem_llvm_of(expr: (uni.UniNode | None)) -> (ir.Type | None) {
    if not isinstance(expr, uni.Expr) {
        return None;
    }
    _t = expr.type;
    if _t is None and isinstance(expr, uni.Name) and expr.sym is not None {
        _decl = expr.sym.decl;
        _t = _decl?.type;
        if _t is None and isinstance(_decl?.parent, (uni.ParamVar, uni.HasVar)) {
            _t = _decl.parent?.type;
        }
    }
    if _t is None {
        return None;
    }
    _names = ("list", "set", "frozenset", "Sequence");
    if not self._spec_name_match(self._mangled_of(_t) or "", _names) {
        _sole = self._opt_sole_member(_t);
        if _sole is None
            or not self._spec_name_match(self._mangled_of(_sole) or "", _names) {
            return None;
        }
        _t = _sole;
    }
    if not isinstance(_t, ClassType) {
        return None;
    }
    _args = _t.private.type_args;
    if not _args {
        return None;
    }
    _low = self._elem_storage_llvm(_args[0]);
    if _low is None or isinstance(_low, ir.VoidType) {
        return None;
    }
    if self?.jacval_type and _low == self.jacval_type {
        return None;
    }
    if self._str_desc_ty is not None and _low == self._str_desc_ty {
        return ir.IntType(8).as_pointer();
    }
    return _low;
}

impl NaIRGenPass._elem_spec_of(expr: (uni.UniNode | None)) -> (str | None) {
    et = self._list_elem_llvm_of(expr);
    if et is None {
        return None;
    }
    if self._str_desc_ty is not None and et == self._str_desc_ty {
        return "ptr";
    }
    if isinstance(et, (ir.DoubleType, ir.FloatType)) {
        return "f64";
    }
    if isinstance(et, ir.PointerType) {
        return "ptr";
    }
    if self?.jacval_type and et == self.jacval_type {
        return "jacval";
    }
    return "i64";
}

impl NaIRGenPass._lower_view_container(t: any) -> (ir.Type | None) {
    try {
        import from jaclang.compiler.types.types { ClassType as _VcClassType }
    } except ImportError {
        return None;
    }
    if not isinstance(t, _VcClassType) or t._shared is None {
        return None;
    }
    if t.shared.class_name not in ("list", "Sequence") {
        return None;
    }
    _args: list[TypeBase] = t.private.type_args or [];
    if not _args {
        return None;
    }
    _elem = self._elem_storage_llvm(_args[0]);
    if _elem is None {
        return None;
    }
    return self._lower_list_for_elem(_elem);
}

impl NaIRGenPass._lower_class_type(t: ClassType) -> (ir.Type | None) {
    cname = t.shared.class_name;
    if t.is_builtin("Node") or t.is_builtin("Edge") or t.is_builtin("Walker") {
        return ir.IntType(8).as_pointer();
    }
    if cname in self.type_map {
        return self.type_map[cname];
    }
    if cname in ("NoneType", "None") {
        return ir.VoidType();
    }

    if cname in ("any", "Any", "object") {
        return self.jacval_type;
    }

    if cname == "File" {
        return self._get_file_struct_type().as_pointer();
    }

    if cname == "BinaryFile" {
        return self._get_binary_file_struct_type().as_pointer();
    }

    if cname == "bytes" {
        return self._get_bytes_struct_type().as_pointer();
    }

    if cname == "bytearray" {
        return self._ensure_bytearray_type();
    }

    _enum_ty = self._ensure_enum_lowered(t);
    if _enum_ty is not None {
        return _enum_ty;
    }
    if cname in self.struct_types {
        return self.struct_types[cname].as_pointer();
    }
    type_args: list[TypeBase] = t.private.type_args or [];

    if cname in ("Iterator", "Iterable") {
        self._ensure_iter_types();
        iterator_type = self._jac_iter_type;
        assert iterator_type is not None;
        return iterator_type.as_pointer();
    }

    if cname in ("list", "Sequence") {
        elem_llvm: ir.Type = ir.IntType(64);
        if type_args {
            _aos_t = self._aos_elem_name(type_args[0]);
            if _aos_t is not None {
                return self._emit_aos_list_helpers(_aos_t).as_pointer();
            }
            _e = self._elem_storage_llvm(type_args[0]);
            if _e is None {
                return None;
            }
            elem_llvm = _e;
        }
        return self._lower_list_for_elem(elem_llvm);
    }

    if cname == "dict" {
        k_llvm: ir.Type = ir.IntType(64);
        v_llvm: ir.Type = ir.IntType(64);
        if len(type_args) >= 2 {
            _k = self._elem_storage_llvm(type_args[0]);
            _v = self._elem_storage_llvm(type_args[1]);
            if _k is None or _v is None {
                return None;
            }
            if self?.jacval_type and _k == self.jacval_type {
                return None;
            }
            k_llvm = _k;
            v_llvm = _v;
        }
        if self._str_desc_ty is not None {
            if k_llvm == self._str_desc_ty {
                k_llvm = ir.IntType(8).as_pointer();
            }
            if v_llvm == self._str_desc_ty {
                v_llvm = ir.IntType(8).as_pointer();
            }
        }

        (k_spec, k_size) = self._hash_key_spec(k_llvm);
        v_spec = self._dict_val_spec(v_llvm);
        self._emit_dict_helpers(k_spec, v_spec, k_llvm, v_llvm, k_size);
        return self.dict_types[f"{k_spec}:{v_spec}"].as_pointer();
    }

    if cname in ("set", "frozenset") {
        elem_llvm: ir.Type = ir.IntType(64);
        if type_args {
            _e = self._elem_storage_llvm(type_args[0]);
            if _e is None {
                return None;
            }
            if self?.jacval_type and _e == self.jacval_type {
                return None;
            }
            elem_llvm = _e;
        }
        if self._str_desc_ty is not None and elem_llvm == self._str_desc_ty {
            elem_llvm = ir.IntType(8).as_pointer();
        }
        (spec, esize) = self._hash_key_spec(elem_llvm);
        self._emit_set_helpers(spec, elem_llvm, esize);
        return self.set_types[spec].as_pointer();
    }

    if cname == "tuple" {
        if not type_args {
            return None;
        }
        _var_seq = self._variadic_tuple_seq_type(type_args);
        if _var_seq is not None {
            return _var_seq;
        }
        elem_types: list[ir.Type] = [];
        for a in type_args {
            _et = self._lower_type(a);
            if _et is None {
                return None;
            }
            if self._str_desc_ty is not None and _et == self._str_desc_ty {
                _et = ir.IntType(8).as_pointer();
            }
            elem_types.append(_et);
        }
        return self._tuple_struct_of(elem_types).as_pointer();
    }
    return None;
}

impl NaIRGenPass._lower_function_type(t: SemanticFunctionType) -> ir.PointerType {
    signature = self._lower_function_signature(t);
    (_sig_name, sig_st, _fnty_env) = self._closure_sig_struct(signature);
    return sig_st.as_pointer();
}

impl NaIRGenPass._lower_function_type_raw(t: SemanticFunctionType) -> ir.PointerType {
    return self._lower_function_signature(t).as_pointer();
}

impl NaIRGenPass._lower_function_signature(t: SemanticFunctionType) -> ir.FunctionType {
    ret_type: ir.Type = ir.VoidType();
    if t.return_type is not None {
        _r = self._lower_type(t.return_type);
        if _r is not None {
            ret_type = _r;
        }
    }
    param_types: list[ir.Type] = [];
    for p in (t.parameters or []) {
        _p = self._lower_type(p.param_type);
        if _p is None {
            param_types.append(ir.IntType(64));
        } else {
            param_types.append(_p);
        }
    }
    return ir.FunctionType(ret_type, param_types);
}

impl NaIRGenPass._aos_elem_of(type_expr: (uni.UniNode | None)) -> (str | None) {
    if not self._nogc_headerless() {
        return None;
    }
    nd = type_expr;
    if isinstance(nd, uni.ParamVar) {
        nd = nd.type_tag;
    }
    if isinstance(nd, uni.SubTag) {
        nd = nd.tag;
    }
    if isinstance(nd, uni.UnaryExpr) {
        nd = nd.operand;
    }
    _t = nd?.type if isinstance(nd, uni.Expr) else None;
    if _t is None {
        return None;
    }
    _sole = self._opt_sole_member(_t);
    if _sole is not None {
        _t = _sole;
    }
    if not isinstance(_t, ClassType) or _t.shared.class_name != "list" {
        return None;
    }
    _args = _t.private.type_args;
    if not _args {
        return None;
    }
    return self._aos_elem_name(_args[0]);
}

impl NaIRGenPass._aos_elem_name(t: any) -> (str | None) {
    if t is None or not self._nogc_owned_world() {
        return None;
    }
    try {
        import from jaclang.compiler.types.types {
            ClassType as _AeClassType,
            TypeVarType as _AeTypeVarType
        }
    } except ImportError {
        return None;
    }
    if isinstance(t, _AeTypeVarType) {
        _sol = self._mono_solution;
        if _sol is None or t.name not in _sol {
            return None;
        }
        return self._aos_elem_name(_sol[t.name]);
    }
    if not isinstance(t, _AeClassType) or t._shared is None {
        return None;
    }
    _tn = t.shared.class_name;
    if _tn not in self.struct_types {
        return None;
    }
    _lay = self._arch_layout(_tn);
    if _lay is None or _lay.is_osp or _lay.arch_type == "walker" {
        return None;
    }
    if self._program_has_subclasses(_tn) {
        return None;
    }
    _fields = self.struct_field_types.get(_tn);
    if _fields is None {
        _fields = self._decl_field_llvm_types(_tn);
    }
    if _fields is None {
        return None;
    }
    for (_fname, _fty) in _fields.items() {
        if isinstance(_fty, ir.PointerType) or self._opt_payload_of(_fty) is not None {
            return None;
        }
    }
    return _tn;
}

impl NaIRGenPass._decl_field_llvm_types(arch_name: str) -> (dict[str, ir.Type] | None) {
    if arch_name in self._aos_deciding {
        return None;
    }
    _lay = self._arch_layout(arch_name);
    if _lay is None {
        return None;
    }
    self._aos_deciding.add(arch_name);
    out: dict[str, ir.Type] = {};
    try {
        for _f in _lay.fields {
            _var = _f.decl_node;
            if _var is None or _var?.type is None {
                return None;
            }
            out[_f.name] = self._resolve_field_type(_var);
        }
    } finally {
        self._aos_deciding.discard(arch_name);
    }
    return out;
}

impl NaIRGenPass._program_has_subclasses(arch_name: str) -> bool {
    if self._subclassed_arch_names is None {
        _names: set[str] = set();
        _mods: list[uni.Module] = list(self.prog.mod.hub.values());
        if self.module not in _mods {
            _mods.append(self.module);
        }
        for _mod in _mods {
            for _arch in _mod.get_all_sub_nodes(uni.Archetype) {
                for _base in (_arch.base_classes or []) {
                    _bn = self._get_name(_base);
                    if _bn is not None {
                        _names.add(_bn);
                    }
                }
            }
        }
        self._subclassed_arch_names = _names;
    }
    return arch_name in self._subclassed_arch_names;
}

impl NaIRGenPass._resolve_sig_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    _ptb = type_expr?.type;
    if _ptb is not None {
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            if self._str_desc_ty is not None and lowered == self._str_desc_ty {
                lowered = ir.IntType(8).as_pointer();
            }
            return lowered;
        }
        if self._foreign_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        if self._typevar_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        _sig_seq = self._erased_seq_type(_ptb);
        if _sig_seq is not None {
            return _sig_seq;
        }
        if not self._type_base_is_unknown(_ptb) {
            _sig_cn = _ptb.shared.class_name if isinstance(_ptb, ClassType) else None;
            if _sig_cn in ("tuple", "list", "dict", "set", "type") {
                _sig_lmark = len(self.ctx.errors_had);
                _sig_res = self._resolve_jac_type(type_expr);
                if len(self.ctx.errors_had) == _sig_lmark {
                    return _sig_res;
                }
                del self.ctx.errors_had[_sig_lmark:];
            }
            return ir.IntType(8).as_pointer();
        }
    }

    _sig_out = self._resolve_jac_type(type_expr);
    if self._str_desc_ty is not None and _sig_out == self._str_desc_ty {
        return ir.IntType(8).as_pointer();
    }
    return _sig_out;
}

impl NaIRGenPass._resolve_jac_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.IntType(64);
    }

    if isinstance(type_expr, uni.SubTag) and type_expr?.tag is not None {
        return self._resolve_jac_type(type_expr.tag);
    }

    _ptb = type_expr?.type;
    if _ptb is not None and not isinstance(type_expr, uni.Expr) {
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            return lowered;
        }
        return self._emit_unlowerable_type(type_expr, _ptb);
    }
    if isinstance(type_expr, uni.Expr) {
        if type_expr.type is None {
            _structural = self._lower_untyped_annotation(type_expr);
            if _structural is not None {
                return _structural;
            }
            return self._emit_unlowerable_type(type_expr, None);
        }
        if type_tag_borrows(type_expr) {
            _view = self._lower_view_container(type_expr.type);
            if _view is not None {
                return _view;
            }
        }
        lowered = self._lower_type(type_expr.type);
        if lowered is not None {
            return lowered;
        }
        return self._emit_unlowerable_type(type_expr, type_expr.type);
    }

    if isinstance(type_expr, (uni.HasVar, uni.ParamVar))
        and type_expr.type_tag is not None {
        return self._resolve_jac_type(type_expr.type_tag.tag);
    }
    return ir.IntType(64);
}

impl NaIRGenPass._resolve_decl_type(
    type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
) -> ir.Type {
    if self._quiet_glob_type(type_expr) is None {
        widened = self._widened_tuple_decl_type(type_expr, value);
        if widened is not None {
            return widened;
        }
    }
    return self._resolve_jac_type(type_expr);
}

impl NaIRGenPass._widened_tuple_decl_type(
    type_expr: (uni.UniNode | None), value: (uni.UniNode | None)
) -> (ir.Type | None) {
    if value is None or type_expr is None {
        return None;
    }
    nd = type_expr;
    if isinstance(nd, uni.SubTag) {
        nd = nd.tag;
    }
    _tb = nd?.type;
    if _tb is None {
        if not (isinstance(nd, uni.Name) and nd.value == "tuple") {
            return None;
        }
    } else {
        try {
            import from jaclang.compiler.types.types { ClassType as _WdClassType }
        } except ImportError {
            return None;
        }
        if not isinstance(_tb, _WdClassType)
            or _tb.shared.class_name != "tuple"
            or (_tb.private.type_args or []) {
            return None;
        }
    }
    if isinstance(value, uni.TupleVal) and not value.values {
        return self._tuple_struct_of([]).as_pointer();
    }
    return self._infer_global_init_type(value);
}

impl NaIRGenPass._tuple_struct_of(elem_types: list[ir.Type]) -> ir.LiteralStructType {
    elem_types = [
        ir.IntType(8).as_pointer() if isinstance(t, ir.VoidType) else t
        for t in elem_types
    ];
    tuple_key = f"Tuple.{len(elem_types)}." + ".".join([str(x) for x in elem_types]);
    if tuple_key not in self.tuple_types {
        self.tuple_types[tuple_key] = ir.LiteralStructType(elem_types);
    }
    return self.tuple_types[tuple_key];
}

impl NaIRGenPass._resolve_field_type(var: uni.UniNode) -> ir.Type {
    _ptb = var?.type;
    if _ptb is not None {
        try {
            import from jaclang.compiler.types.types { FunctionType as _FieldFnType }
            if isinstance(_ptb, _FieldFnType) {
                return self._lower_function_type_raw(_ptb);
            }
        } except ImportError {}
        lowered = self._lower_type(_ptb);
        if lowered is not None {
            if self._str_desc_ty is not None and lowered == self._str_desc_ty {
                lowered = ir.IntType(8).as_pointer();
            }
            return lowered;
        }
        if self._foreign_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        if self._typevar_optional_field(_ptb) {
            return ir.IntType(8).as_pointer();
        }
        try {
            import from jaclang.compiler.types.types { TypeVarType as _RfTypeVarType }
            if isinstance(_ptb, _RfTypeVarType) {
                return ir.IntType(8).as_pointer();
            }
        } except ImportError {}
        if not self._type_base_is_unknown(_ptb) {
            return self._emit_unlowerable_type(var, _ptb);
        }
    }

    _hv_tag = (
        var.type_tag.tag
            if isinstance(var, (uni.HasVar, uni.ParamVar)) and var.type_tag is not None
            else None
    );
    if _hv_tag is not None and _hv_tag?.type is None {
        _structural = self._lower_untyped_annotation(_hv_tag);
        if _structural is not None {
            if self._str_desc_ty is not None and _structural == self._str_desc_ty {
                _structural = ir.IntType(8).as_pointer();
            }
            return _structural;
        }

        _hv_opt = False;
        _hv_scan: list[uni.UniNode] = [_hv_tag];
        while _hv_scan {
            _hv_cur = _hv_scan.pop();
            if isinstance(_hv_cur, uni.AtomUnit) and _hv_cur.value is not None {
                _hv_cur = _hv_cur.value;
            }
            if isinstance(_hv_cur, uni.BinaryExpr)
                and isinstance(_hv_cur.op, uni.Token)
                and _hv_cur.op.value == "|" {
                _hv_scan.append(_hv_cur.left);
                _hv_scan.append(_hv_cur.right);
            } elif isinstance(_hv_cur, uni.Null)
                or (
                    isinstance(_hv_cur, uni.Name)
                    and _hv_cur.value in ("None", "NoneType")
                ) {
                _hv_opt = True;
            }
        }
        if _hv_opt {
            return ir.IntType(8).as_pointer();
        }
        return ir.IntType(64);
    }
    _rf_out = self._resolve_jac_type(var);
    if self._str_desc_ty is not None and _rf_out == self._str_desc_ty {
        return ir.IntType(8).as_pointer();
    }
    return _rf_out;
}

impl NaIRGenPass._foreign_optional_field(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _FofClassType,
            UnionType as _FofUnionType,
            UnknownType as _FofUnknownType
        }
    } except ImportError {
        return False;
    }
    if not isinstance(tb, _FofUnionType) {
        return False;
    }
    _members: list[TypeBase] = tb.types or [];
    _non_none = [
        m
        for m in _members
        if not (
            isinstance(m, _FofClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_non_none) == len(_members) or not _non_none {
        return False;
    }
    try {
        import from jaclang.compiler.types.types { TypeVarType as _FofTypeVarType }
    } except ImportError {
        return False;
    }
    for m in _non_none {
        if isinstance(m, _FofUnknownType) {
            continue;
        }
        if isinstance(m, _FofTypeVarType) {
            return False;
        }
        if isinstance(m, _FofClassType) and self._lower_type(m) is None {
            continue;
        }
        return False;
    }
    return True;
}

impl NaIRGenPass._erased_typevar_names(tb: any) -> list[str] {
    try {
        import from jaclang.compiler.types.types { TypeVarType as _EtvTypeVarType }
    } except ImportError {
        return [];
    }
    if isinstance(tb, _EtvTypeVarType) and self._lower_type(tb) is None {
        return [tb.name];
    }
    if not self._typevar_optional_field(tb) {
        return [];
    }
    out: list[str] = [];
    for m in (tb.types or []) {
        if isinstance(m, _EtvTypeVarType) and m.name not in out {
            out.append(m.name);
        }
    }
    return out;
}

impl NaIRGenPass._typevar_optional_field(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _TvoClassType,
            UnionType as _TvoUnionType,
            TypeVarType as _TvoTypeVarType
        }
    } except ImportError {
        return False;
    }
    if not isinstance(tb, _TvoUnionType) {
        return False;
    }
    _members: list[TypeBase] = tb.types or [];
    _non_none = [
        m
        for m in _members
        if not (
            isinstance(m, _TvoClassType)
            and m._shared is not None
            and m.shared.class_name in ("NoneType", "None")
        )
    ];
    if len(_non_none) == len(_members) or not _non_none {
        return False;
    }
    for m in _non_none {
        if not isinstance(m, _TvoTypeVarType) or self._lower_type(m) is not None {
            return False;
        }
    }
    return True;
}

impl NaIRGenPass._erased_seq_type(tb: any) -> (ir.Type | None) {
    """The pointer-element native list a `list[T]` signature slot erases to.

    A generic archetype is laid out once and its `T` slots are raw pointers,
    so a sequence *of* `T` is the pointer-flavoured list -- the same storage
    every erased reference already uses. Answering `None` here leaves the
    slot to the ordinary refusal path, which is what a sequence of anything
    else that fails to lower deserves.
    """;
    try {
        import from jaclang.compiler.types.types { ClassType as _EsqClassType }
    } except ImportError {
        return None;
    }
    if not isinstance(tb, _EsqClassType) or tb._shared is None {
        return None;
    }
    if tb.shared.class_name not in ("list", "Sequence") {
        return None;
    }
    _args: list[TypeBase] = tb.private.type_args or [];
    if len(_args) != 1 or not self._erased_typevar_names(_args[0]) {
        return None;
    }
    self._emit_list_helpers("ptr", ir.IntType(8).as_pointer());
    return self.list_types["ptr"].as_pointer();
}

impl NaIRGenPass._type_base_is_unknown(tb: any) -> bool {
    try {
        import from jaclang.compiler.types.types { UnknownType as _UnknownType }
        return isinstance(tb, _UnknownType);
    } except ImportError {
        return True;
    }
}

impl NaIRGenPass._emit_unlowerable_type(type_expr: uni.UniNode, tb: any) -> ir.Type {
    if isinstance(type_expr, uni.Expr) {
        import from jaclang.compiler.tools.unparse_pass { unparse_node }
        _label = unparse_node(type_expr);
    } else {
        _tag = type_expr?.type_tag;
        _label = self._get_name(_tag?.tag) or str(tb);
    }
    self.ctx.emit(
        E5092, node_override=type_expr, kind=self._sig_decl_kind or "type", name=_label
    );

    import logging as _logging;
    _logging.getLogger("jaclang.native").debug(
        "[NaIRGenPass] _resolve_jac_type: unresolved type %r (type=%s) -- "
        "defaulting to i64; consider adding an explicit type annotation",
        type_expr,
        type(type_expr).__name__,
    );
    return ir.IntType(64);
}

impl NaIRGenPass._resolve_clib_type(type_expr: (uni.UniNode | None)) -> ir.Type {
    if type_expr is None {
        return ir.VoidType();
    }

    type_name: (str | None) = None;
    if isinstance(type_expr, uni.Name) and type_expr.value == "str" {
        return ir.IntType(8).as_pointer();
    }
    if isinstance(type_expr, uni.Name) {
        type_name = type_expr.value;
    } elif isinstance(type_expr, uni.Token) {
        type_name = type_expr.value;
    }
    if type_name is not None and type_name in self.clib_struct_names {
        if type_name in self.clib_struct_abi_types {
            return self.clib_struct_abi_types[type_name];
        }
        return self.struct_types[type_name];
    }

    if type_name == "bytes" or type_name == "bytearray" {
        return ir.IntType(8).as_pointer();
    }

    if isinstance(type_expr, uni.Expr) {
        signature = type_expr.type;
        if isinstance(signature, SemanticFunctionType) {
            return self._lower_function_type_raw(signature);
        }
    }

    return self._resolve_jac_type(type_expr);
}

impl NaIRGenPass._get_name(nd: (uni.UniNode | None)) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.Name) {
        return nd.value;
    }
    if isinstance(nd, (uni.NameAtom, uni.AstSymbolNode)) {
        return nd.sym_name or None;
    }
    if isinstance(nd, uni.Token) {
        return nd.value or None;
    }
    return None;
}

impl NaIRGenPass._infer_type_name(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (sname, stype) in self.struct_types.items() {
        if val.type == stype.as_pointer() {
            return sname;
        }
    }
    return None;
}

impl NaIRGenPass._infer_list_elem_type(val: ir.Value) -> (str | None) {
    if not isinstance(val.type, ir.PointerType) {
        return None;
    }
    for (ename, ltype) in self.list_types.items() {
        if val.type == ltype.as_pointer() {
            return ename;
        }
    }
    return None;
}

impl NaIRGenPass._infer_compr_elem_struct(compr: uni.InnerCompr) -> (str | None) {
    _coll_tk = self._type_key_of(compr.collection);
    if _coll_tk is not None
        and _coll_tk.startswith("list[")
        and _coll_tk.endswith("]") {
        _inner_tk = _coll_tk[5:-1];
        if _inner_tk in self.struct_types {
            return _inner_tk;
        }
        for part in _inner_tk.split("|") {
            if part in self.struct_types {
                return part;
            }
        }
    }
    return None;
}

impl NaIRGenPass._lower_type_by_name(name: (str | None)) -> (ir.Type | None) {
    if name is None {
        return None;
    }
    if name in self.type_map {
        return self.type_map[name];
    }
    if name in ("None", "NoneType") {
        return ir.VoidType();
    }
    if name in ("any", "Any", "object") {
        return self.jacval_type;
    }
    return None;
}

impl NaIRGenPass._lower_untyped_annotation(nd: uni.UniNode) -> (ir.Type | None) {
    if isinstance(nd, uni.Null) {
        return ir.VoidType();
    }
    if isinstance(nd, uni.AtomUnit) and nd.value is not None {
        return self._lower_untyped_annotation(nd.value);
    }
    if isinstance(nd, uni.BinaryExpr)
        and isinstance(nd.op, uni.Token)
        and nd.op.value == "|" {
        _leaves: list[uni.UniNode] = [];
        _stack: list[uni.UniNode] = [nd];
        while _stack {
            _cur = _stack.pop();
            if isinstance(_cur, uni.AtomUnit) and _cur.value is not None {
                _cur = _cur.value;
            }
            if isinstance(_cur, uni.BinaryExpr)
                and isinstance(_cur.op, uni.Token)
                and _cur.op.value == "|" {
                _stack.append(_cur.left);
                _stack.append(_cur.right);
            } else {
                _leaves.append(_cur);
            }
        }
        _live: list[uni.UniNode] = [];
        _had_none = False;
        for _side in _leaves {
            if isinstance(_side, uni.Null) {
                _had_none = True;
                continue;
            }
            if isinstance(_side, uni.Name) and _side.value in ("None", "NoneType") {
                _had_none = True;
                continue;
            }
            _live.append(_side);
        }
        if not _live {
            return None;
        }
        _lreprs: list[ir.Type] = [];
        for _lv in _live {
            _lr = self._lower_untyped_annotation(_lv);
            if _lr is None {
                return None;
            }
            if self._str_desc_ty is not None and _lr == self._str_desc_ty {
                _lr = ir.IntType(8).as_pointer();
            }
            _lreprs.append(_lr);
        }
        _ulow = self._unify_repr_lowering(_lreprs);
        if _ulow is None {
            return None;
        }
        if _had_none and len(_live) == 1 and not isinstance(_ulow, ir.VoidType) {
            return self._jac_optional_type(_ulow);
        }
        return _ulow;
    }
    if isinstance(nd, uni.AtomTrailer) and isinstance(nd.right, uni.IndexSlice) {
        _base = self._get_name(nd.target);
        if _base in ("list", "Sequence") {
            _elem_ty: ir.Type = ir.IntType(64);
            _slices = nd.right.slices;
            if _slices and _slices[0].start is not None {
                _lowered_elem = self._lower_untyped_annotation(_slices[0].start);
                if _lowered_elem is None {
                    return None;
                }
                _elem_ty = _lowered_elem;
            }
            return self._lower_list_for_elem(_elem_ty);
        }
        if _base == "tuple" {
            _tslices = nd.right.slices;
            if _tslices and _tslices[0].start is not None {
                _tvals: uni.UniNode = _tslices[0].start;
                if isinstance(_tvals, uni.AtomUnit) and _tvals.value is not None {
                    _tvals = _tvals.value;
                }
                _telems = (
                    list(_tvals.values)
                        if isinstance(_tvals, uni.TupleVal)
                        else [_tvals]
                );
                _tlow: list[ir.Type] = [];
                _tok = True;
                for _tv in _telems {
                    _lt = self._lower_untyped_annotation(_tv);
                    if _lt is None {
                        _tok = False;
                        break;
                    }
                    if self._str_desc_ty is not None and _lt == self._str_desc_ty {
                        _lt = ir.IntType(8).as_pointer();
                    }
                    _tlow.append(_lt);
                }
                if _tok and _tlow {
                    return self._tuple_struct_of(_tlow).as_pointer();
                }
            }
            return None;
        }
        if _base == "Callable" {
            _fnslices = nd.right.slices;
            _fnparams_nd: (uni.UniNode | None) = None;
            _fnret_nd: (uni.UniNode | None) = None;
            if len(_fnslices) == 2
                and _fnslices[0].start is not None
                and _fnslices[1].start is not None {
                _fnparams_nd = _fnslices[0].start;
                _fnret_nd = _fnslices[1].start;
            } elif _fnslices and _fnslices[0].start is not None {
                _fnargs: uni.UniNode = _fnslices[0].start;
                if isinstance(_fnargs, uni.AtomUnit) and _fnargs.value is not None {
                    _fnargs = _fnargs.value;
                }
                if isinstance(_fnargs, uni.TupleVal) and len(_fnargs.values) == 2 {
                    _fnparams_nd = _fnargs.values[0];
                    _fnret_nd = _fnargs.values[1];
                }
            }
            if _fnparams_nd is not None and _fnret_nd is not None {
                if isinstance(_fnparams_nd, uni.AtomUnit)
                    and _fnparams_nd.value is not None {
                    _fnparams_nd = _fnparams_nd.value;
                }
                _fnret = self._lower_untyped_annotation(_fnret_nd);
                if _fnret is None {
                    _fnret = ir.VoidType();
                }
                _fnparams: list[ir.Type] = [];
                if isinstance(_fnparams_nd, uni.ListVal) {
                    for _fp in _fnparams_nd.values {
                        _fpl = self._lower_untyped_annotation(_fp);
                        _fnparams.append(_fpl if _fpl is not None else ir.IntType(64));
                    }
                    return ir.FunctionType(_fnret, _fnparams).as_pointer();
                }
            }
            return None;
        }
        if _base == "dict" {
            _dslices = nd.right.slices;
            if _dslices and _dslices[0].start is not None {
                _dkv: uni.UniNode = _dslices[0].start;
                if isinstance(_dkv, uni.AtomUnit) and _dkv.value is not None {
                    _dkv = _dkv.value;
                }
                if isinstance(_dkv, uni.TupleVal) and len(_dkv.values) == 2 {
                    _dk = self._lower_untyped_annotation(_dkv.values[0]);
                    _dv = self._lower_untyped_annotation(_dkv.values[1]);
                    if _dk is not None and _dv is not None {
                        if self._str_desc_ty is not None {
                            if _dk == self._str_desc_ty {
                                _dk = ir.IntType(8).as_pointer();
                            }
                            if _dv == self._str_desc_ty {
                                _dv = ir.IntType(8).as_pointer();
                            }
                        }
                        (_dk_spec, _dk_size) = self._hash_key_spec(_dk);
                        _dv_spec = self._dict_val_spec(_dv);
                        self._emit_dict_helpers(_dk_spec, _dv_spec, _dk, _dv, _dk_size);
                        _dict_ty = self.dict_types.get(f"{_dk_spec}:{_dv_spec}");
                        if _dict_ty is not None {
                            return _dict_ty.as_pointer();
                        }
                    }
                }
            }
            return None;
        }
        if _base in ("set", "frozenset") {
            _sslices = nd.right.slices;
            if _sslices and _sslices[0].start is not None {
                _set_elem = self._lower_untyped_annotation(_sslices[0].start);
                if _set_elem is not None {
                    _set_spec = "i64";
                    if isinstance(_set_elem, ir.DoubleType) {
                        _set_spec = "f64";
                    } elif isinstance(_set_elem, ir.PointerType) {
                        _set_spec = "ptr";
                    }
                    if self._str_desc_ty is not None
                        and _set_elem == self._str_desc_ty {
                        _set_elem = ir.IntType(8).as_pointer();
                        _set_spec = "ptr";
                    }
                    self._emit_set_helpers(_set_spec, _set_elem);
                    _set_ty = self.set_types.get(_set_spec);
                    if _set_ty is not None {
                        return _set_ty.as_pointer();
                    }
                }
            }
            return None;
        }
        return self._lower_untyped_annotation(nd.target);
    }
    _nm = self._get_name(nd);

    if isinstance(nd, uni.Name) and nd.sym is not None and nd.sym.decl is not None {
        _decl_of = nd.sym.decl.name_of;
        if isinstance(_decl_of, uni.Enum) {
            return ir.IntType(64);
        }
        if isinstance(_decl_of, uni.Archetype) {
            _decl_anm = _decl_of.name.value if _decl_of.name else None;
            if _decl_anm is not None and _decl_anm in self.struct_types {
                return self.struct_types[_decl_anm].as_pointer();
            }
        }
        if isinstance(_decl_of, uni.TypeParam)
            or (_decl_of is not None and isinstance(_decl_of.parent, uni.TypeParam)) {
            return ir.IntType(8).as_pointer();
        }
        if _decl_of is not None and isinstance(_decl_of.parent, uni.ModuleItem) {
            _item = _decl_of.parent;
            _orig = _item.name.value if isinstance(_item.name, uni.Name) else None;
            if _orig is not None and _orig != _nm {
                if _orig in self.struct_types {
                    return self.struct_types[_orig].as_pointer();
                }
                _by_name = self._lower_type_by_name(_orig);
                if _by_name is not None {
                    return _by_name;
                }
            }

            if _orig is not None {
                _imp_node = _item.find_parent_of_type(uni.Import);
                _imp_from = _imp_node.from_loc if _imp_node is not None else None;
                _imp_tail = (
                    _imp_from.dot_path_str.split(".")[-1]
                        if _imp_from is not None
                        else None
                );
                if _imp_tail is not None {
                    if self._enum_source_name.get(_orig) == _imp_tail {
                        return ir.IntType(64);
                    }
                    if self._struct_source_name.get(_orig) == _imp_tail {
                        _osrc_st = self.struct_types.get(_orig);
                        if _osrc_st is not None {
                            return _osrc_st.as_pointer();
                        }
                    }
                }
                if _orig in self.struct_types {
                    return self.struct_types[_orig].as_pointer();
                }
                if _orig in self.enum_types {
                    return self.enum_types[_orig];
                }
            }
        }
    }
    _nm_enum = _nm is not None and _nm in self.enum_types;
    _nm_struct = _nm is not None and _nm in self.struct_types;
    if _nm is not None and _nm_enum and not _nm_struct {
        return self.enum_types[_nm];
    }
    if _nm is not None and _nm_struct and not _nm_enum {
        return self.struct_types[_nm].as_pointer();
    }
    if _nm == "bytes" {
        return self._get_bytes_struct_type().as_pointer();
    }
    if _nm == "list" {
        return self._lower_list_for_elem(ir.IntType(64));
    }
    return self._lower_type_by_name(_nm);
}

impl NaIRGenPass._lower_list_for_elem(elem_llvm: ir.Type) -> ir.Type {
    _elem = elem_llvm;
    if self._str_desc_ty is not None and _elem == self._str_desc_ty {
        _elem = ir.IntType(8).as_pointer();
    }
    spec = "i64";
    if isinstance(_elem, (ir.DoubleType, ir.FloatType)) {
        spec = "f64";
    } elif isinstance(_elem, ir.PointerType) {
        spec = "ptr";
    } elif self?.jacval_type and _elem == self.jacval_type {
        spec = "jacval";
    }
    self._emit_list_helpers(spec, _elem);
    return self.list_types[spec].as_pointer();
}
