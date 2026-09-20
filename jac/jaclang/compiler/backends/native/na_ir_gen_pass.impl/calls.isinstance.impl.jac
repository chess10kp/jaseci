glob _NA_ABC_OPAQUE: tuple[str, ...] = (
         "Iterable",
         "Iterator",
         "Reversible",
         "Generator",
         "Container",
         "Collection",
         "Sized",
         "Hashable",
         "Callable",
         "Awaitable",
         "Coroutine",
         "AsyncIterable",
         "AsyncIterator",
         "AsyncGenerator",
         "MappingView",
         "KeysView",
         "ItemsView",
         "ValuesView",
         "Buffer"
     );

glob _NA_ABC_REDUCTIONS: dict[str, tuple[str, ...]] = {
         "Sequence": ("list", "tuple", "str", "bytes", "bytearray"),
         "MutableSequence": ("list", "bytearray"),
         "Mapping": ("dict", ),
         "MutableMapping": ("dict", ),
         "Set": ("set", "frozenset"),
         "AbstractSet": ("set", "frozenset"),
         "MutableSet": ("set", ),
         "ByteString": ("bytes", "bytearray")
     };

impl NaIRGenPass._jacval_tags_for_type(name: str) -> list[int] {
    if name == "int" {
        return [0, 7];
    }
    if name == "bool" {
        return [7];
    }
    if name == "float" {
        return [1];
    }
    if name == "str" {
        return [2];
    }
    if name == "list" {
        return [3];
    }
    if name == "dict" {
        return [4];
    }
    if name == "set" or name == "frozenset" {
        return [5];
    }
    if name == "NoneType" {
        return [8];
    }
    return [];
}

impl NaIRGenPass._isinstance_static_verdict(
    name: str, operand: ir.Value
) -> (bool | None) {
    """Answer the arms whose native representation carries no JacVal tag.

    A native tuple is an unboxed literal struct and a `bytes` / `bytearray` is
    a pointer to its own runtime struct, so none of the three is reachable
    through a tag compare -- but each is fully decided by the operand's LLVM
    type, which is known here. Returning `True`/`False` settles that arm at
    compile time; `None` means the name is not one of these and falls through
    to the tag and vtable machinery.
    """;
    if name == "tuple" {
        return self._tuple_struct_of_value(operand) is not None;
    }
    if name == "bytes" {
        return self._is_bytes_value(operand);
    }
    if name == "bytearray" {
        _ba = self.list_types.get("u8");
        return _ba is not None and operand.type == _ba.as_pointer();
    }
    return None;
}

impl NaIRGenPass._isinstance_abc_reduction(
    type_expr: uni.UniNode, name: str
) -> (list[str] | None) {
    """The native shapes an `isinstance` arm naming a stdlib ABC reduces to.

    A `collections.abc` class is a Python object no native unit can host, so a
    check against one is only answerable by reducing it to the finite set of
    native runtime shapes that inhabit it. `_NA_ABC_REDUCTIONS` holds the
    reductions that are exact rather than approximate: every entry is a
    container ABC whose members, among values a native unit can hold, are
    precisely the listed builtins. Protocol-shaped ABCs are deliberately absent
    -- an archetype with `__iter__` inhabits `Iterable` too, so a builtin-only
    answer there would be silently wrong. Those sit in `_NA_ABC_OPAQUE`.

    `None` means the arm is not a stdlib ABC and the caller should treat it as
    it always has. An empty list means it is one this backend refuses to guess
    at, and the caller turns that into a diagnostic rather than an answer.
    """;
    if name in self.struct_types or name in self.enum_types {
        return None;
    }
    try {
        import from jaclang.compiler.types.types { ClassType as _AbcClassType }
    } except ImportError {
        return None;
    }
    t = type_expr.type if isinstance(type_expr, uni.Expr) else None;
    if not isinstance(t, _AbcClassType) or t._shared is None {
        return None;
    }
    if not t.shared.is_from_stdlib_stub {
        return None;
    }
    cn = t.shared.class_name;
    if cn in _NA_ABC_REDUCTIONS {
        return list(_NA_ABC_REDUCTIONS[cn]);
    }
    if cn in _NA_ABC_OPAQUE {
        return [];
    }
    return None;
}

impl NaIRGenPass._isinstance_target_names(
    nd: uni.FuncCall, operand: ir.Value, type_arg: uni.UniNode
) -> (list[str] | None) {
    """Flatten the type argument into the type names the check has to test.

    A tuple argument contributes each of its arms; a stdlib ABC arm expands to
    the native shapes it reduces to, and keeps its own name too whenever some
    archetype names it in an MRO, so a user type registered under the ABC still
    answers through the vtable arm. `None` means a diagnostic was emitted.
    """;
    raw: list[uni.UniNode] = list(type_arg.values or [])
        if isinstance(type_arg, uni.TupleVal)
        else [type_arg];
    pyb_operand = self._isinstance_operand_is_pyb(nd, operand);
    names: list[str] = [];
    for v in raw {
        nm = self._isinstance_type_name(v);
        if nm is None {
            continue;
        }
        reduced = self._isinstance_abc_reduction(v, nm);
        if reduced is None {
            if nm not in names {
                names.append(nm);
            }
            continue;
        }
        if not reduced or pyb_operand {
            self.ctx.emit(
                E5092,
                node_override=nd,
                kind="builtin call",
                name=f"isinstance against `{nm}`",
                help_text=(
                    "This operand's class inherits a Python-side base, so which abstract base classes it inhabits is decided by an MRO this native unit only holds a shadow handle to. Test the concrete type instead (`list`, `dict`, an archetype), or move the code to a @sv/Python context."
                        if pyb_operand
                        else "This abstract base class has no exact answer over native values -- an archetype can inhabit it without naming it, so a native check would have to guess. Test the concrete type instead (`list`, `dict`, an archetype), or move the code to a @sv/Python context."
                )
            );
            return None;
        }
        for _b in reduced {
            if _b not in names {
                names.append(_b);
            }
        }
        if nm not in names and self._vtable_candidates([nm]) {
            names.append(nm);
        }
    }
    return names;
}

impl NaIRGenPass._isinstance_operand_is_pyb(
    nd: uni.FuncCall, operand: ir.Value
) -> bool {
    """Does the operand's class reach its bases through the Python bridge?

    A class with a Python-side base carries an MRO this unit never modelled --
    `PyBase(ABC)` in the interop fixtures is exactly that shape -- so which
    abstract base classes such an instance inhabits is not answerable from the
    native layout. Only the reduction cares: an archetype arm still answers
    through the vtable, whose MRO covers the layout-trusted bases.
    """;
    arch = self._isinstance_operand_arch(nd, operand);
    if arch is None {
        return False;
    }
    for cand in self._mro_of(arch) {
        if self._pyb_base_of(cand) is not None {
            return True;
        }
    }
    return False;
}

impl NaIRGenPass._isinstance_type_name(nd: uni.UniNode) -> (str | None) {
    if (
        isinstance(nd, uni.FuncCall)
        and self._get_name(nd.target) == "type"
        and nd.params
        and len(nd.params) == 1
        and isinstance(nd.params[0], uni.Null)
    ) {
        import from jaclang.compiler.symbol_utils { classify_call, CallKind }
        if classify_call(nd) == CallKind.BUILTIN {
            return "NoneType";
        }
        return None;
    }
    _mn_nd = nd;
    while isinstance(_mn_nd, uni.AtomUnit) and _mn_nd.value is not None {
        _mn_nd = _mn_nd.value;
    }
    if self._mono_mangle_map
        and isinstance(_mn_nd, uni.Name)
        and _mn_nd.sym is not None {
        nd = _mn_nd;
        _mn_sym = _mn_nd.sym;
        assert _mn_sym is not None;
        _mn_decl = _mn_sym.decl.name_of if _mn_sym.decl is not None else None;
        if isinstance(_mn_decl, uni.ParamVar) and _mn_decl.type_tag is not None {
            _mn_tag: uni.UniNode = _mn_decl.type_tag.tag;
            while isinstance(_mn_tag, uni.AtomUnit) and _mn_tag.value is not None {
                _mn_tag = _mn_tag.value;
            }
            if (
                isinstance(_mn_tag, uni.AtomTrailer)
                and isinstance(_mn_tag.target, uni.Name)
                and _mn_tag.target.value == "type"
                and isinstance(_mn_tag.right, uni.IndexSlice)
                and len(_mn_tag.right.slices) == 1
            ) {
                _mn_inner = _mn_tag.right.slices[0].start;
                if isinstance(_mn_inner, uni.Name)
                    and _mn_inner.value in self._mono_mangle_map {
                    return self._mono_mangle_map[_mn_inner.value];
                }
            }
        }
    }
    _alias_nm = self._arch_alias_target(nd);
    if _alias_nm is not None {
        return _alias_nm;
    }
    return self._get_name(nd);
}

impl NaIRGenPass._enum_union_tags(
    operand_expr: uni.UniNode, names: list[str]
) -> tuple[list[int], list[str]] {
    try {
        import from jaclang.compiler.types.types {
            ClassType as _EnClassType,
            EnumMemberType as _EnMemberType,
            UnionType as _EnUnionType
        }
    } except ImportError {
        return ([], names, );
    }
    t = operand_expr.type if isinstance(operand_expr, uni.Expr) else None;
    members: list[TypeBase] = [];
    if isinstance(t, _EnUnionType) {
        members = list(t.types or []);
    } elif t is not None {
        members = [t];
    }
    if not members {
        return ([], names, );
    }
    member_rows: list[tuple[str, bool, list[int]]] = [];
    for m in members {
        cls = m.enum_class if isinstance(m, _EnMemberType) else m;
        if not isinstance(cls, _EnClassType) or cls._shared is None {
            return ([], names, );
        }
        cn = cls.shared.class_name;
        if cls.is_enum_class() {
            member_rows.append((cn, True, [0], ));
        } elif cn in ("NoneType", "None") {
            member_rows.append((cn, False, [8], ));
        } elif cn == "bool" {
            member_rows.append((cn, False, [7], ));
        } elif cn == "int" {
            member_rows.append((cn, False, [0, 7], ));
        } elif cn == "float" {
            member_rows.append((cn, False, [1], ));
        } elif cn == "str" {
            member_rows.append((cn, False, [2], ));
        } elif cn in ("list", "dict", "set", "tuple") {
            member_rows.append((cn, False, [3, 4, 5], ));
        } else {
            member_rows.append((cn, False, [6], ));
        }
    }
    resolved: list[int] = [];
    still: list[str] = [];
    for nm in names {
        hit = False;
        for row in member_rows {
            if row[0] == nm and row[1] {
                clash = False;
                for other in member_rows {
                    if other[0] != nm and (0 in other[2]) {
                        clash = True;
                        break;
                    }
                }
                hit = not clash;
                break;
            }
        }
        if hit {
            if 0 not in resolved {
                resolved.append(0);
            }
        } else {
            still.append(nm);
        }
    }
    return (resolved, still, );
}

impl NaIRGenPass._emit_isinstance(nd: uni.FuncCall) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);
    if len(params) < 2 {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    operand = self._codegen_expr(params[0]);
    if operand is None {
        return None;
    }
    if self._opt_payload_of(operand.type) is None {
        if not isinstance(operand.type, ir.PointerType) {
            return self._emit_isinstance_core(nd, operand);
        }

        _nn_fn = self.builder.block.function;
        _nn_bb = _nn_fn.append_basic_block("isinst.nn");
        _nn_done_bb = _nn_fn.append_basic_block("isinst.nn.done");
        _nn_ok = self.builder.icmp_unsigned(
            "!=", operand, ir.Constant(operand.type, None), name="isinst.nonnull"
        );
        _nn_entry = self.builder.block;
        self.builder.cbranch(_nn_ok, _nn_bb, _nn_done_bb);
        self.builder.position_at_end(_nn_bb);
        _nn_inner = self._emit_isinstance_core(nd, operand);
        _nn_inner_bb = self.builder.block;
        self.builder.branch(_nn_done_bb);
        self.builder.position_at_end(_nn_done_bb);
        if _nn_inner is None {
            return None;
        }
        _nn_res = self.builder.phi(i1, name="isinst.nn.res");
        _nn_res.add_incoming(ir.Constant(i1, 0), _nn_entry);
        _nn_res.add_incoming(_nn_inner, _nn_inner_bb);
        return _nn_res;
    }
    fn = self.builder.block.function;
    some_bb = fn.append_basic_block("isinst.opt.some");
    done_bb = fn.append_basic_block("isinst.opt.done");
    opt_tag = self.builder.extract_value(operand, 0, name="isinst.opt.tag");
    opt_set = self.builder.icmp_signed(
        "!=", opt_tag, ir.Constant(i8, 0), name="isinst.opt.set"
    );
    payload = self.builder.extract_value(operand, 1, name="isinst.opt.val");
    entry_bb = self.builder.block;
    self.builder.cbranch(opt_set, some_bb, done_bb);
    self.builder.position_at_end(some_bb);
    inner = self._emit_isinstance_core(nd, payload);
    inner_bb = self.builder.block;
    self.builder.branch(done_bb);
    self.builder.position_at_end(done_bb);
    if inner is None {
        return None;
    }
    res = self.builder.phi(i1, name="isinst.opt.res");
    res.add_incoming(ir.Constant(i1, 0), entry_bb);
    res.add_incoming(inner, inner_bb);
    return res;
}

impl NaIRGenPass._emit_isinstance_core(
    nd: uni.FuncCall, operand: ir.Value
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    params: list[uni.Expr | uni.KWPair] = list(nd.params or []);

    type_arg = params[1];
    if not isinstance(type_arg, uni.TupleVal) {
        _rt_res = self._emit_isinstance_runtime(nd, operand, type_arg);
        if _rt_res is not None {
            return _rt_res;
        }
    }
    names = self._isinstance_target_names(nd, operand, type_arg);
    if names is None {
        return None;
    }
    _short = self._isinstance_unprovable_class(
        names, self._isinstance_operand_arch(nd, operand)
    );
    if _short is not None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="builtin call",
            name=f"isinstance against `{'`, `'.join(names)}`",
            help_text=(
                f"`{_short}` subclasses a class another module defines, so this unit linearized it from a base whose own bases it could not see yet -- its ancestor chain stops one link short of the classes named here, and answering from it is how a check reports `False` for a base the operand genuinely derives from. Test the concrete class instead, or declare `{_short}` in the module that defines its base."
            )
        );
        return None;
    }
    tags: list[int] = [];
    unresolved: list[str] = [];
    static_seen = False;
    static_hit = False;
    source_type = params[0].type;
    source_members = source_type.types
        if isinstance(source_type, UnionType)
        else [source_type];
    present_members = [
        member
        for member in source_members
        if not (
            isinstance(member, ClassType)
            and member.shared.class_name in ("None", "NoneType")
        )
    ];
    known_string = len(present_members) == 1
        and isinstance(present_members[0], ClassType)
        and present_members[0].shared.class_name == "str";
    for nm in names {
        verdict = True
            if nm == "str" and known_string
            else self._isinstance_static_verdict(nm, operand);
        if verdict is not None {
            static_seen = True;
            static_hit = static_hit or verdict;
            continue;
        }
        nm_tags = self._jacval_tags_for_type(nm);
        if not nm_tags {
            unresolved.append(nm);
        }
        for t in nm_tags {
            if t not in tags {
                tags.append(t);
            }
        }
    }
    if static_hit {
        if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 1);
    }
    if unresolved {
        (_enum_tags, unresolved) = self._enum_union_tags(params[0], unresolved);
        for _et in _enum_tags {
            if _et not in tags {
                tags.append(_et);
            }
        }
    }
    if unresolved {
        if not tags {
            return self._emit_isinstance_user(nd, operand, unresolved);
        }
        return self._emit_isinstance_mixed(nd, operand, tags, unresolved);
    }
    if not tags {
        if static_seen {
            if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
                self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
            }
            return ir.Constant(i1, 0);
        }
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    if isinstance(operand.type, ir.PointerType) {
        _pt_res = self._emit_isinstance_ptr_tags(operand, tags);
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return _pt_res;
    }
    boxed = self._box_to_jacval(operand);
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    result: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        result = cmp
            if result is None
            else self.builder.or_(result, cmp, name="isinst.or");
    }

    if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    return result;
}

impl NaIRGenPass._emit_isinstance_ptr_tags(
    operand: ir.Value, tags: list[int]
) -> ir.Value {
    i1 = ir.IntType(1);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i8p = ir.IntType(8).as_pointer();

    _prefixes: dict[int, str] = {3: "list_", 4: "dict_", 5: "set_"};
    if 6 in tags {
        return ir.Constant(i1, 1);
    }
    _want = [
        t
        for t in sorted(tags)
        if t in _prefixes
    ];
    if not _want {
        return ir.Constant(i1, 0);
    }
    b = self.builder;
    raw = b.bitcast(operand, i8p, name="isinst.hdr.raw");
    fn = b.block.function;
    pre_bb = b.block;
    tag_bb = fn.append_basic_block("isinst.hdr.tag");
    cmp_bb = fn.append_basic_block("isinst.hdr.cmp");
    done_bb = fn.append_basic_block("isinst.hdr.done");
    magic_ok = self._emit_magic_check(b, raw, name_prefix="isinst.mc");
    b.cbranch(magic_ok, tag_bb, done_bb);

    b.position_at_end(tag_bb);
    tag_slot = b.gep(raw, [ir.Constant(i64, HDR_TAG_OFF)], name="isinst.tag.slot");
    tag_pp = b.bitcast(tag_slot, i8p.as_pointer(), name="isinst.tag.pp");
    tag_ptr = b.load(tag_pp, name="isinst.tag.name");
    tag_nn = b.icmp_unsigned(
        "!=", tag_ptr, ir.Constant(i8p, None), name="isinst.tag.nn"
    );
    b.cbranch(tag_nn, cmp_bb, done_bb);

    b.position_at_end(cmp_bb);
    memcmp_fn = self._get_or_declare_extern("memcmp", i32, [i8p, i8p, i64]);
    matched: (ir.Value | None) = None;
    for t in _want {
        pfx = _prefixes[t];
        pfx_gv = self._get_snprintf_fmt(pfx);
        pfx_ptr = b.gep(
            pfx_gv, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.pfx"
        );
        cmp_res = b.call(
            memcmp_fn,
            [tag_ptr, pfx_ptr, ir.Constant(i64, len(pfx))],
            name="isinst.memcmp"
        );
        eq = b.icmp_signed("==", cmp_res, ir.Constant(i32, 0), name="isinst.pfx.eq");
        matched = eq if matched is None else b.or_(matched, eq, name="isinst.pfx.or");
    }
    cmp_end_bb = b.block;
    b.branch(done_bb);

    b.position_at_end(done_bb);
    res = b.phi(i1, name="isinst.hdr.res");
    res.add_incoming(ir.Constant(i1, 0), pre_bb);
    res.add_incoming(ir.Constant(i1, 0), tag_bb);
    res.add_incoming(matched, cmp_end_bb);
    return res;
}

impl NaIRGenPass._emit_isinstance_mixed(
    nd: uni.FuncCall, operand: ir.Value, tags: list[int], names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    _by_name = self._isinstance_needs_class_name(names);
    if _by_name and self._nogc_headerless() {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }
    target_vtables = [] if _by_name else self._vtable_candidates(names);
    if not _by_name and not target_vtables {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    boxed = self._box_to_jacval(operand);
    tag = self.builder.extract_value(boxed, 0, name="isinst.tag");
    payload = self.builder.extract_value(boxed, 1, name="isinst.payload");

    prim: (ir.Value | None) = None;
    for t in sorted(tags) {
        cmp = self.builder.icmp_unsigned(
            "==", tag, ir.Constant(i8, t), name="isinst.cmp"
        );
        prim = cmp if prim is None else self.builder.or_(prim, cmp, name="isinst.or");
    }
    if prim is None {
        prim = ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    obj_bb = self.builder.append_basic_block(name="isinst.mix.obj");
    load_bb = self.builder.append_basic_block(name="isinst.mix.load");
    merge_bb = self.builder.append_basic_block(name="isinst.mix.merge");
    is_obj = self.builder.icmp_unsigned(
        "==", tag, ir.Constant(i8, 6), name="isinst.isobj"
    );
    self.builder.cbranch(is_obj, obj_bb, merge_bb);

    self.builder.position_at_end(obj_bb);
    is_null = self.builder.icmp_signed(
        "==", payload, ir.Constant(payload.type, 0), name="isinst.mix.null"
    );
    self.builder.cbranch(is_null, merge_bb, load_bb);

    self.builder.position_at_end(load_bb);
    user_or: (ir.Value | None) = None;
    if _by_name {
        user_or = self._isinstance_class_name_hit(
            self.builder.inttoptr(payload, i8.as_pointer(), name="isinst.mix.obj"),
            names
        );
        if user_or is None {
            self._emit_unsupported_builtin_call(nd, "isinstance");
            return None;
        }
    } else {
        i8_pp = i8.as_pointer().as_pointer();
        slot_pp = self.builder.inttoptr(
            payload, i8_pp.as_pointer(), name="isinst.mix.slot"
        );
        vptr = self.builder.load(slot_pp, name="isinst.mix.vptr");
        for vt in target_vtables {
            vt_base = self.builder.gep(
                vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.mix.vt"
            );
            eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.mix.eq");
            user_or = eq
                if user_or is None
                else self.builder.or_(user_or, eq, name="isinst.mix.uor");
        }
    }
    end_load = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.mix.result");
    result.add_incoming(prim, pre_bb);
    result.add_incoming(ir.Constant(i1, 0), obj_bb);
    result.add_incoming(user_or, end_load);

    if isinstance(operand.type, ir.PointerType) and self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    return result;
}

impl NaIRGenPass._emit_isinstance_user(
    nd: uni.FuncCall, operand: ir.Value, names: list[str]
) -> (ir.Value | None) {
    i1 = ir.IntType(1);
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);

    if not isinstance(operand.type, ir.PointerType) {
        if self?.jacval_type and operand.type == self.jacval_type {
            return self._emit_isinstance_mixed(nd, operand, [], names);
        }
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    if self._isinstance_needs_class_name(names) {
        _nm_hit = (
            None
                if self._nogc_headerless()
                else self._isinstance_class_name_hit(operand, names)
        );
        if _nm_hit is None {
            self._emit_unsupported_builtin_call(nd, "isinstance");
            return None;
        }
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return _nm_hit;
    }

    target_vtables = self._vtable_candidates(names);
    if not target_vtables {
        self._emit_unsupported_builtin_call(nd, "isinstance");
        return None;
    }

    struct_name = self._struct_name_of(nd.params[0] if nd.params else None);
    if (
        struct_name is not None
        and struct_name in self.struct_types
        and not self._arch_has_vtable(struct_name)
    ) {
        if self._is_owned(operand) {
            self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
        }
        return ir.Constant(i1, 0);
    }

    pre_bb = self.builder.block;
    null_ptr = ir.Constant(operand.type, None);
    is_null = self.builder.icmp_unsigned(
        "==", operand, null_ptr, name="isinst.null.chk"
    );
    nonnull_bb = self.builder.append_basic_block(name="isinst.nonnull");
    merge_bb = self.builder.append_basic_block(name="isinst.merge");
    self.builder.cbranch(is_null, merge_bb, nonnull_bb);

    self.builder.position_at_end(nonnull_bb);
    i8_pp = i8.as_pointer().as_pointer();
    op_as = self.builder.bitcast(operand, i8_pp.as_pointer(), name="isinst.obj");
    vptr = self.builder.load(op_as, name="isinst.vptr");
    cmp: (ir.Value | None) = None;
    for vt in target_vtables {
        vt_base = self.builder.gep(
            vt, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="isinst.vt.base"
        );
        eq = self.builder.icmp_unsigned("==", vptr, vt_base, name="isinst.eq");
        cmp = eq if cmp is None else self.builder.or_(cmp, eq, name="isinst.or");
    }

    if self._is_owned(operand) {
        self._emit_rc_release_simple(operand, op="isinstance_arg", loc="");
    }
    end_nonnull = self.builder.block;
    self.builder.branch(merge_bb);

    self.builder.position_at_end(merge_bb);
    result = self.builder.phi(i1, name="isinst.result");
    result.add_incoming(ir.Constant(i1, 0), pre_bb);
    result.add_incoming(cmp, end_nonnull);
    return result;
}

impl NaIRGenPass._spec_from_container_ptr(t: (ir.Type | None)) -> (str | None) {
    if t is None or not isinstance(t, ir.PointerType) {
        return None;
    }
    tables: list[dict[str, ir.IdentifiedStructType]] = [
        self.list_types,
        self.set_types
    ];
    for _tbl in tables {
        for (spec, lt) in _tbl.items() {
            if lt.as_pointer() == t {
                return spec;
            }
        }
    }
    return None;
}

impl NaIRGenPass._container_type_args(t: any) -> list[TypeBase] {
    if t is None {
        return [];
    }
    for _cand in (t?.types or [t]) {
        _priv = _cand?.private;
        if _priv is not None and (_priv?.type_args or []) {
            return list(_priv.type_args);
        }
    }
    return [];
}
