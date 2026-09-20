impl ESListEmitter.emit_append(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "push", args);
}

impl ESListEmitter.emit_extend(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".push(..." + args[0] + ")";
}

impl ESListEmitter.emit_insert(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "splice", [args[0], "0", args[1]]);
}

impl ESListEmitter.emit_remove(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "remove", [target] + args);
}

impl ESListEmitter.emit_pop(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "pop", []);
    }
    return _mcall(target, "splice", [args[0], "1"]) + "[0]";
}

impl ESListEmitter.emit_clear(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".length = 0";
}

impl ESListEmitter.emit_index(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "index", [target] + args);
}

impl ESListEmitter.emit_count(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "count", [target] + args);
}

impl ESListEmitter.emit_sort(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "sort", []);
    }
    return _rt("list", "sort", [target] + args);
}

impl ESListEmitter.emit_reverse(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "reverse", []);
}

impl ESListEmitter.emit_copy(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + "]";
}

impl ESListEmitter.emit_op_add(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + ", ..." + args[0] + "]";
}

impl ESListEmitter.emit_op_mul(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "repeat", [target, args[0]]);
}

impl ESListEmitter.emit_op_eq(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "eq", [target, args[0]]);
}

impl ESListEmitter.emit_op_ne(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("list", "eq", [target, args[0]]);
}

impl ESListEmitter.emit_op_lt(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "lt", [target, args[0]]);
}

impl ESListEmitter.emit_op_gt(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "gt", [target, args[0]]);
}

impl ESListEmitter.emit_op_le(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "le", [target, args[0]]);
}

impl ESListEmitter.emit_op_ge(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "ge", [target, args[0]]);
}

impl ESListEmitter.emit_op_contains(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

impl ESListEmitter.emit_op_iadd(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target + ".push(..." + args[0] + ")";
}

impl ESListEmitter.emit_op_imul(
    self: ESListEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("list", "imul", [target, args[0]]);
}

impl ESDictEmitter.emit_get(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "get", [target] + args);
}

impl ESDictEmitter.emit_keys(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.keys(" + target + ")";
}

impl ESDictEmitter.emit_values(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.values(" + target + ")";
}

impl ESDictEmitter.emit_items(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.entries(" + target + ")";
}

impl ESDictEmitter.emit_pop(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "pop", [target] + args);
}

impl ESDictEmitter.emit_popitem(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "popitem", [target]);
}

impl ESDictEmitter.emit_setdefault(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "setdefault", [target] + args);
}

impl ESDictEmitter.emit_update(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.assign(" + target + ", " + args[0] + ")";
}

impl ESDictEmitter.emit_clear(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "clear", [target]);
}

impl ESDictEmitter.emit_copy(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "{..." + target + "}";
}

impl ESDictEmitter.emit_fromkeys(
    self: ESDictEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("dict", "fromkeys", args);
}

impl ESDictEmitter.emit_op_or(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "{..." + target + ", ..." + args[0] + "}";
}

impl ESDictEmitter.emit_op_eq(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("dict", "eq", [target, args[0]]);
}

impl ESDictEmitter.emit_op_ne(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("dict", "eq", [target, args[0]]);
}

impl ESDictEmitter.emit_op_contains(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(args[0], "in", target);
}

impl ESDictEmitter.emit_op_ior(
    self: ESDictEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Object.assign(" + target + ", " + args[0] + ")";
}

impl ESSetEmitter.emit_add(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "add", args);
}

impl ESSetEmitter.emit_remove(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "remove", [target] + args);
}

impl ESSetEmitter.emit_discard(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "delete", args);
}

impl ESSetEmitter.emit_pop(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "pop", [target]);
}

impl ESSetEmitter.emit_clear(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "clear", []);
}

impl ESSetEmitter.emit_union(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target] + args);
}

impl ESSetEmitter.emit_intersection(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target] + args);
}

impl ESSetEmitter.emit_difference(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target] + args);
}

impl ESSetEmitter.emit_symmetric_difference(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target] + args);
}

impl ESSetEmitter.emit_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "update", [target] + args);
}

impl ESSetEmitter.emit_intersection_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection_update", [target] + args);
}

impl ESSetEmitter.emit_difference_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference_update", [target] + args);
}

impl ESSetEmitter.emit_symmetric_difference_update(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetric_difference_update", [target] + args);
}

impl ESSetEmitter.emit_issubset(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target] + args);
}

impl ESSetEmitter.emit_issuperset(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target] + args);
}

impl ESSetEmitter.emit_isdisjoint(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isDisjointFrom", [target] + args);
}

impl ESSetEmitter.emit_copy(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new Set(" + target + ")";
}

impl ESSetEmitter.emit_op_or(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target, args[0]]);
}

impl ESSetEmitter.emit_op_and(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target, args[0]]);
}

impl ESSetEmitter.emit_op_sub(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target, args[0]]);
}

impl ESSetEmitter.emit_op_xor(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target, args[0]]);
}

impl ESSetEmitter.emit_op_eq(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "eq", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ne(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("set", "eq", [target, args[0]]);
}

impl ESSetEmitter.emit_op_le(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target, args[0]]);
}

impl ESSetEmitter.emit_op_lt(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_subset", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ge(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target, args[0]]);
}

impl ESSetEmitter.emit_op_gt(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_superset", [target, args[0]]);
}

impl ESSetEmitter.emit_op_contains(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "has", [args[0]]);
}

impl ESSetEmitter.emit_op_ior(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_iand(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection_update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_isub(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference_update", [target, args[0]]);
}

impl ESSetEmitter.emit_op_ixor(
    self: ESSetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetric_difference_update", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_union(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target] + args);
}

impl ESFrozensetEmitter.emit_intersection(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target] + args);
}

impl ESFrozensetEmitter.emit_difference(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target] + args);
}

impl ESFrozensetEmitter.emit_symmetric_difference(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target] + args);
}

impl ESFrozensetEmitter.emit_issubset(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target] + args);
}

impl ESFrozensetEmitter.emit_issuperset(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target] + args);
}

impl ESFrozensetEmitter.emit_isdisjoint(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isDisjointFrom", [target] + args);
}

impl ESFrozensetEmitter.emit_copy(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new Set(" + target + ")";
}

impl ESFrozensetEmitter.emit_op_or(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "union", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_and(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "intersection", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_sub(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "difference", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_xor(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "symmetricDifference", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_eq(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "eq", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_ne(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("set", "eq", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_le(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSubsetOf", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_lt(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_subset", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_ge(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "isSupersetOf", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_gt(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("set", "is_proper_superset", [target, args[0]]);
}

impl ESFrozensetEmitter.emit_op_contains(
    self: ESFrozensetEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "has", [args[0]]);
}

impl ESTupleEmitter.emit_count(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "count", [target] + args);
}

impl ESTupleEmitter.emit_index(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "index", [target] + args);
}

impl ESTupleEmitter.emit_op_add(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[..." + target + ", ..." + args[0] + "]";
}

impl ESTupleEmitter.emit_op_mul(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "repeat", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_eq(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "eq", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_ne(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("tuple", "eq", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_lt(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "lt", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_gt(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "gt", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_le(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "le", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_ge(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("tuple", "ge", [target, args[0]]);
}

impl ESTupleEmitter.emit_op_contains(
    self: ESTupleEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

impl ESRangeEmitter.emit_count(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "count", [target] + args);
}

impl ESRangeEmitter.emit_index(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "index", [target] + args);
}

impl ESRangeEmitter.emit_op_eq(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "eq", [target, args[0]]);
}

impl ESRangeEmitter.emit_op_ne(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("range", "eq", [target, args[0]]);
}

impl ESRangeEmitter.emit_op_contains(
    self: ESRangeEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("range", "contains", [target, args[0]]);
}
