impl ESIntEmitter.emit_bit_length(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "bit_length", [target]);
}

impl ESIntEmitter.emit_bit_count(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "bit_count", [target]);
}

impl ESIntEmitter.emit_to_bytes(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "to_bytes", [target] + args);
}

impl ESIntEmitter.emit_as_integer_ratio(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "[" + target + ", 1]";
}

impl ESIntEmitter.emit_conjugate(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target;
}

impl ESIntEmitter.emit_from_bytes(
    self: ESIntEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("int", "from_bytes", args);
}

impl ESIntEmitter.emit_op_add(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESIntEmitter.emit_op_sub(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "-", args[0]);
}

impl ESIntEmitter.emit_op_mul(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "*", args[0]);
}

impl ESIntEmitter.emit_op_truediv(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "/", args[0]);
}

impl ESIntEmitter.emit_op_floordiv(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Math.floor(" + target + " / " + args[0] + ")";
}

impl ESIntEmitter.emit_op_mod(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("int", "mod", [target, args[0]]);
}

impl ESIntEmitter.emit_op_pow(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "**", args[0]);
}

impl ESIntEmitter.emit_op_and(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "&", args[0]);
}

impl ESIntEmitter.emit_op_or(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "|", args[0]);
}

impl ESIntEmitter.emit_op_xor(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "^", args[0]);
}

impl ESIntEmitter.emit_op_lshift(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<<", args[0]);
}

impl ESIntEmitter.emit_op_rshift(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">>", args[0]);
}

impl ESIntEmitter.emit_op_eq(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESIntEmitter.emit_op_ne(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESIntEmitter.emit_op_lt(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESIntEmitter.emit_op_gt(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESIntEmitter.emit_op_le(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESIntEmitter.emit_op_ge(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

impl ESIntEmitter.emit_op_neg(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(-" + target + ")";
}

impl ESIntEmitter.emit_op_pos(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(+" + target + ")";
}

impl ESIntEmitter.emit_op_invert(
    self: ESIntEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(~" + target + ")";
}

impl ESFloatEmitter.emit_is_integer(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Number.isInteger(" + target + ")";
}

impl ESFloatEmitter.emit_as_integer_ratio(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "as_integer_ratio", [target]);
}

impl ESFloatEmitter.emit_conjugate(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return target;
}

impl ESFloatEmitter.emit_hex(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "hex", [target]);
}

impl ESFloatEmitter.emit_fromhex(
    self: ESFloatEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("float", "fromhex", args);
}

impl ESFloatEmitter.emit_op_add(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESFloatEmitter.emit_op_sub(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "-", args[0]);
}

impl ESFloatEmitter.emit_op_mul(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "*", args[0]);
}

impl ESFloatEmitter.emit_op_truediv(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "/", args[0]);
}

impl ESFloatEmitter.emit_op_floordiv(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Math.floor(" + target + " / " + args[0] + ")";
}

impl ESFloatEmitter.emit_op_mod(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("float", "mod", [target, args[0]]);
}

impl ESFloatEmitter.emit_op_pow(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "**", args[0]);
}

impl ESFloatEmitter.emit_op_eq(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESFloatEmitter.emit_op_ne(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESFloatEmitter.emit_op_lt(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESFloatEmitter.emit_op_gt(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESFloatEmitter.emit_op_le(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESFloatEmitter.emit_op_ge(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

impl ESFloatEmitter.emit_op_neg(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(-" + target + ")";
}

impl ESFloatEmitter.emit_op_pos(
    self: ESFloatEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "(+" + target + ")";
}

impl ESComplexEmitter.emit_conjugate(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "conjugate", [target]);
}

impl ESComplexEmitter.emit_op_add(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "add", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_sub(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "sub", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_mul(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "mul", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_truediv(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "truediv", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_pow(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "pow", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_eq(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "eq", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_ne(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("complex", "eq", [target, args[0]]);
}

impl ESComplexEmitter.emit_op_neg(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "neg", [target]);
}

impl ESComplexEmitter.emit_op_pos(
    self: ESComplexEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("complex", "pos", [target]);
}

impl ESBoolEmitter.emit_op_and(
    self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "&", args[0]) + ")";
}

impl ESBoolEmitter.emit_op_or(
    self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "|", args[0]) + ")";
}

impl ESBoolEmitter.emit_op_xor(
    self: ESBoolEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "Boolean(" + _binop(target, "^", args[0]) + ")";
}
