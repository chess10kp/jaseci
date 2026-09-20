impl ESStrEmitter.emit_capitalize(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "capitalize", [target]);
}

impl ESStrEmitter.emit_casefold(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toLowerCase", []);
}

impl ESStrEmitter.emit_lower(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toLowerCase", []);
}

impl ESStrEmitter.emit_upper(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "toUpperCase", []);
}

impl ESStrEmitter.emit_title(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "title", [target]);
}

impl ESStrEmitter.emit_swapcase(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "swapcase", [target]);
}

impl ESStrEmitter.emit_count(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "count", [target] + args);
}

impl ESStrEmitter.emit_find(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) > 1 {
        return _rt("str", "find", [target] + args);
    }
    return _mcall(target, "indexOf", args);
}

impl ESStrEmitter.emit_rfind(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) > 1 {
        return _rt("str", "rfind", [target] + args);
    }
    return _mcall(target, "lastIndexOf", args);
}

impl ESStrEmitter.emit_index(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "index", [target] + args);
}

impl ESStrEmitter.emit_rindex(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rindex", [target] + args);
}

impl ESStrEmitter.emit_startswith(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "startsWith", args);
    }
    return _rt("str", "startswith", [target] + args);
}

impl ESStrEmitter.emit_endswith(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "endsWith", args);
    }
    return _rt("str", "endswith", [target] + args);
}

impl ESStrEmitter.emit_replace(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _mcall(target, "replaceAll", args);
    }
    return _rt("str", "replace", [target] + args);
}

impl ESStrEmitter.emit_strip(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trim", []);
    }
    return _rt("str", "strip", [target] + args);
}

impl ESStrEmitter.emit_lstrip(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trimStart", []);
    }
    return _rt("str", "lstrip", [target] + args);
}

impl ESStrEmitter.emit_rstrip(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "trimEnd", []);
    }
    return _rt("str", "rstrip", [target] + args);
}

impl ESStrEmitter.emit_removeprefix(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "removeprefix", [target] + args);
}

impl ESStrEmitter.emit_removesuffix(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "removesuffix", [target] + args);
}

impl ESStrEmitter.emit_split(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _rt("str", "split", [target]);
    }
    if len(args) == 1 {
        return _mcall(target, "split", args);
    }
    return _rt("str", "split", [target] + args);
}

impl ESStrEmitter.emit_rsplit(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rsplit", [target] + args);
}

impl ESStrEmitter.emit_splitlines(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _mcall(target, "split", ["/\\r?\\n/"]);
    }
    return _rt("str", "splitlines", [target] + args);
}

impl ESStrEmitter.emit_join(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(args[0], "join", [target]);
}

impl ESStrEmitter.emit_partition(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "partition", [target] + args);
}

impl ESStrEmitter.emit_rpartition(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "rpartition", [target] + args);
}

impl ESStrEmitter.emit_format(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "format", [target] + args);
}

impl ESStrEmitter.emit_format_map(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "format_map", [target] + args);
}

impl ESStrEmitter.emit_center(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "center", [target] + args);
}

impl ESStrEmitter.emit_ljust(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "padEnd", args);
    }
    return _mcall(target, "padEnd", args);
}

impl ESStrEmitter.emit_rjust(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return _mcall(target, "padStart", args);
    }
    return _mcall(target, "padStart", args);
}

impl ESStrEmitter.emit_zfill(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "zfill", [target] + args);
}

impl ESStrEmitter.emit_expandtabs(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "expandtabs", [target] + args);
}

impl ESStrEmitter.emit_isalnum(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isalpha(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isascii(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[\\x00-\\x7F]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isdecimal(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isdigit(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[0-9]+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isidentifier(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[a-zA-Z_][a-zA-Z0-9_]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_islower(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "("
        + target
        + " === "
        + target
        + ".toLowerCase() && "
        + target
        + " !== "
        + target
        + ".toUpperCase())";
}

impl ESStrEmitter.emit_isnumeric(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "isnumeric", [target]);
}

impl ESStrEmitter.emit_isprintable(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^[\\x20-\\x7E]*$/.test(" + target + ")";
}

impl ESStrEmitter.emit_isspace(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "/^\\s+$/.test(" + target + ")";
}

impl ESStrEmitter.emit_istitle(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "istitle", [target]);
}

impl ESStrEmitter.emit_isupper(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "("
        + target
        + " === "
        + target
        + ".toUpperCase() && "
        + target
        + " !== "
        + target
        + ".toLowerCase())";
}

impl ESStrEmitter.emit_encode(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new TextEncoder().encode(" + target + ")";
}

impl ESStrEmitter.emit_translate(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "translate", [target] + args);
}

impl ESStrEmitter.emit_maketrans(
    self: ESStrEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("str", "maketrans", args);
}

impl ESStrEmitter.emit_op_add(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "+", args[0]);
}

impl ESStrEmitter.emit_op_mul(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "repeat", [args[0]]);
}

impl ESStrEmitter.emit_op_mod(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("str", "mod", [target, args[0]]);
}

impl ESStrEmitter.emit_op_eq(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "===", args[0]);
}

impl ESStrEmitter.emit_op_ne(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "!==", args[0]);
}

impl ESStrEmitter.emit_op_lt(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<", args[0]);
}

impl ESStrEmitter.emit_op_gt(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">", args[0]);
}

impl ESStrEmitter.emit_op_le(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, "<=", args[0]);
}

impl ESStrEmitter.emit_op_ge(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _binop(target, ">=", args[0]);
}

impl ESStrEmitter.emit_op_contains(
    self: ESStrEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _mcall(target, "includes", [args[0]]);
}

impl ESBytesEmitter.emit_decode(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "new TextDecoder("
        + (args[0] if len(args) > 0 else "")
        + ").decode("
        + target
        + ")";
}

impl ESBytesEmitter.emit_hex(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "hex", [target] + args);
}

impl ESBytesEmitter.emit_fromhex(
    self: ESBytesEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("bytes", "fromhex", args);
}

impl ESBytesEmitter.emit_count(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "count", [target] + args);
}

impl ESBytesEmitter.emit_find(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "find", [target] + args);
}

impl ESBytesEmitter.emit_rfind(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rfind", [target] + args);
}

impl ESBytesEmitter.emit_index(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "index", [target] + args);
}

impl ESBytesEmitter.emit_rindex(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rindex", [target] + args);
}

impl ESBytesEmitter.emit_startswith(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "startswith", [target] + args);
}

impl ESBytesEmitter.emit_endswith(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "endswith", [target] + args);
}

impl ESBytesEmitter.emit_replace(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "replace", [target] + args);
}

impl ESBytesEmitter.emit_strip(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "strip", [target] + args);
}

impl ESBytesEmitter.emit_lstrip(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lstrip", [target] + args);
}

impl ESBytesEmitter.emit_rstrip(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rstrip", [target] + args);
}

impl ESBytesEmitter.emit_removeprefix(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "removeprefix", [target] + args);
}

impl ESBytesEmitter.emit_removesuffix(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "removesuffix", [target] + args);
}

impl ESBytesEmitter.emit_split(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "split", [target] + args);
}

impl ESBytesEmitter.emit_rsplit(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rsplit", [target] + args);
}

impl ESBytesEmitter.emit_splitlines(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "splitlines", [target] + args);
}

impl ESBytesEmitter.emit_join(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "join", [target] + args);
}

impl ESBytesEmitter.emit_partition(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "partition", [target] + args);
}

impl ESBytesEmitter.emit_rpartition(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rpartition", [target] + args);
}

impl ESBytesEmitter.emit_capitalize(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "capitalize", [target]);
}

impl ESBytesEmitter.emit_lower(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lower", [target]);
}

impl ESBytesEmitter.emit_upper(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "upper", [target]);
}

impl ESBytesEmitter.emit_title(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "title", [target]);
}

impl ESBytesEmitter.emit_swapcase(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "swapcase", [target]);
}

impl ESBytesEmitter.emit_isalnum(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isalnum", [target]);
}

impl ESBytesEmitter.emit_isalpha(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isalpha", [target]);
}

impl ESBytesEmitter.emit_isascii(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isascii", [target]);
}

impl ESBytesEmitter.emit_isdigit(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isdigit", [target]);
}

impl ESBytesEmitter.emit_islower(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "islower", [target]);
}

impl ESBytesEmitter.emit_isspace(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isspace", [target]);
}

impl ESBytesEmitter.emit_istitle(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "istitle", [target]);
}

impl ESBytesEmitter.emit_isupper(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "isupper", [target]);
}

impl ESBytesEmitter.emit_center(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "center", [target] + args);
}

impl ESBytesEmitter.emit_ljust(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "ljust", [target] + args);
}

impl ESBytesEmitter.emit_rjust(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "rjust", [target] + args);
}

impl ESBytesEmitter.emit_zfill(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "zfill", [target] + args);
}

impl ESBytesEmitter.emit_expandtabs(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "expandtabs", [target] + args);
}

impl ESBytesEmitter.emit_translate(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "translate", [target] + args);
}

impl ESBytesEmitter.emit_maketrans(
    self: ESBytesEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("bytes", "maketrans", args);
}

impl ESBytesEmitter.emit_op_add(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "add", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_mul(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "mul", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_mod(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "mod", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_eq(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "eq", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_ne(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return "!" + _rt("bytes", "eq", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_lt(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "lt", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_gt(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "gt", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_le(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "le", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_ge(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "ge", [target, args[0]]);
}

impl ESBytesEmitter.emit_op_contains(
    self: ESBytesEmitter, ctx: ESEmitCtx, target: str, args: list[str]
) -> (str | None) {
    return _rt("bytes", "contains", [target, args[0]]);
}
