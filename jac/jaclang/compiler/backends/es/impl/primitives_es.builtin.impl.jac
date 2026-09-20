impl ESBuiltinEmitter.emit_print(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    import from jaclang.runtime.scalars { shape_of }
    names: list[str] = ctx.arg_type_names or [];
    shown: list[str] = [];
    for (i, a) in enumerate(args) {
        shape = shape_of(names[i]) if i < len(names) else None;
        if shape is not None
            and shape.sized
            and not shape.is_float
            and shape.width == 64 {
            shown.append("String(" + a + ")");
        } else {
            shown.append(a);
        }
    }
    return _fcall("console.log", shown);
}

impl ESBuiltinEmitter.emit_sized_cast(
    self: ESBuiltinEmitter, name: str, args: list[str]
) -> (str | None) {
    return _rt("fw", "cast_" + name, [args[0] if args else "0"]);
}

impl ESBuiltinEmitter.emit_wrapping(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, op: str, args: list[str]
) -> (str | None) {
    import from jaclang.runtime.scalars { is_sized }
    sized_name: (str | None) = None;
    for n in (ctx.arg_type_names or []) {
        if is_sized(n) {
            sized_name = n;
            break;
        }
    }
    if sized_name is None or not args {
        return None;
    }
    call_args = ['"' + sized_name + '"', args[0]];
    call_args.append(args[1] if len(args) > 1 else "undefined");
    call_args.append("'" + op + "'");
    return _rt("fw", "wrapping", call_args);
}

impl ESBuiltinEmitter.emit_wrapping_add(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return self.emit_wrapping(ctx, "+", args);
}

impl ESBuiltinEmitter.emit_wrapping_sub(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return self.emit_wrapping(ctx, "-", args);
}

impl ESBuiltinEmitter.emit_wrapping_mul(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return self.emit_wrapping(ctx, "*", args);
}

impl ESBuiltinEmitter.emit_wrapping_shl(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return self.emit_wrapping(ctx, "<<", args);
}

impl ESBuiltinEmitter.emit_wrapping_neg(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return self.emit_wrapping(ctx, "neg", args);
}

impl ESBuiltinEmitter.emit_input(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _fcall("prompt", args);
}

impl ESBuiltinEmitter.emit_len(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if not args {
        return None;
    }

    arg_type = (ctx.arg_type_names or [""])[0] if ctx.arg_type_names else "";
    if arg_type == "dict" {
        return "Object.keys(" + args[0] + ").length";
    }
    if arg_type in ("set", "frozenset") {
        return args[0] + ".size";
    }
    if arg_type in ("str", "list", "tuple", "bytes", "bytearray", "range") {
        return args[0] + ".length";
    }
    return _rt("builtin", "len", args);
}

impl ESBuiltinEmitter.emit_abs(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    import from jaclang.runtime.scalars { is_sized }
    names: list[str] = ctx.arg_type_names or [];
    if args and names and is_sized(names[0]) {
        return _rt("fw", "abs_" + names[0], [args[0]]);
    }
    return "Math.abs(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_round(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 1 {
        return "Math.round(" + args[0] + ")";
    }
    return _rt("builtin", "round", args);
}

impl ESBuiltinEmitter.emit_min(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _min_max_call("min", ctx, args);
}

impl ESBuiltinEmitter.emit_max(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _min_max_call("max", ctx, args);
}

impl ESBuiltinEmitter.emit_sum(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "sum", args);
}

impl ESBuiltinEmitter.emit_sorted(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "sorted", args);
}

impl ESBuiltinEmitter.emit_reversed(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "[..." + args[0] + "].reverse()";
}

impl ESBuiltinEmitter.emit_enumerate(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "enumerate", args);
}

impl ESBuiltinEmitter.emit_zip(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "zip", args);
}

impl ESBuiltinEmitter.emit_map(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _one_arg_cb(args[0], args[1], "map", "_f(_v)");
    }
    return _rt("builtin", "map", args);
}

impl ESBuiltinEmitter.emit_filter(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return _one_arg_cb(args[0], args[1], "filter", "_f ? _f(_v) : _v");
    }
    return _rt("builtin", "filter", args);
}

impl ESBuiltinEmitter.emit_any(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _mcall(args[0], "some", ["Boolean"]);
}

impl ESBuiltinEmitter.emit_all(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _mcall(args[0], "every", ["Boolean"]);
}

impl ESBuiltinEmitter.emit_isinstance(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) != 2 {
        return None;
    }
    return _rt("builtin", "isinstance", args);
}

impl ESBuiltinEmitter.emit_issubclass(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) != 2 {
        return None;
    }
    return _rt("builtin", "issubclass", args);
}

impl ESBuiltinEmitter.emit_type(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "typeof " + args[0];
}

impl ESBuiltinEmitter.emit_id(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "id", args);
}

impl ESBuiltinEmitter.emit_jid(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "jid", args);
}

impl ESBuiltinEmitter.emit_new(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Reflect.construct(undefined, [])";
    }
    cls = args[0];
    ctor_args = "[" + ", ".join(args[1:]) + "]";
    return "Reflect.construct(" + cls + ", " + ctor_args + ")";
}

impl ESBuiltinEmitter.emit_unsafe_html(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "unsafe_html", args);
}

impl ESBuiltinEmitter.emit_hash(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "hash", args);
}

impl ESBuiltinEmitter.emit_repr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "repr", args);
}

impl ESBuiltinEmitter.emit_chr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "String.fromCodePoint(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_ord(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + ".codePointAt(0)";
}

impl ESBuiltinEmitter.emit_hex(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "'0x' + (" + args[0] + ").toString(16)";
}

impl ESBuiltinEmitter.emit_oct(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "'0o' + (" + args[0] + ").toString(8)";
}

impl ESBuiltinEmitter.emit_bin(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "'0b' + (" + args[0] + ").toString(2)";
}

impl ESBuiltinEmitter.emit_pow(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return args[0] + " ** " + args[1];
    }
    return _rt("builtin", "pow", args);
}

impl ESBuiltinEmitter.emit_divmod(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "[Math.floor("
        + args[0]
        + " / "
        + args[1]
        + "), "
        + args[0]
        + " % "
        + args[1]
        + "]";
}

impl ESBuiltinEmitter.emit_iter(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + "[Symbol.iterator]()";
}

impl ESBuiltinEmitter.emit_next(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "next", args);
}

impl ESBuiltinEmitter.emit_callable(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "typeof " + args[0] + " === 'function'";
}

impl ESBuiltinEmitter.emit_getattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 2 {
        return args[0] + "[" + args[1] + "]";
    }
    return "(" + args[0] + "[" + args[1] + "] ?? " + args[2] + ")";
}

impl ESBuiltinEmitter.emit_setattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[0] + "[" + args[1] + "] = " + args[2];
}

impl ESBuiltinEmitter.emit_hasattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return args[1] + " in " + args[0];
}

impl ESBuiltinEmitter.emit_delattr(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return "delete " + args[0] + "[" + args[1] + "]";
}

impl ESBuiltinEmitter.emit_vars(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "vars", args);
}

impl ESBuiltinEmitter.emit_dir(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return _rt("builtin", "dir", []);
    }
    return "Object.getOwnPropertyNames(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_open(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "open", args);
}

impl ESBuiltinEmitter.emit_format(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "format", args);
}

impl ESBuiltinEmitter.emit_ascii(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "ascii", args);
}

impl ESBuiltinEmitter.emit_str(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return '""';
    }
    return "String(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_int(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "0";
    }

    return _rt("builtin", "int", args);
}

impl ESBuiltinEmitter.emit_float(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "0.0";
    }

    return _rt("builtin", "float", args);
}

impl ESBuiltinEmitter.emit_bool(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "false";
    }

    return _rt("builtin", "bool", args);
}

impl ESBuiltinEmitter.emit_list(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "[]";
    }

    return "Array.from(" + _rt("builtin", "iter", args) + ")";
}

impl ESBuiltinEmitter.emit_dict(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "{}";
    }

    return _rt("builtin", "dict", args);
}

impl ESBuiltinEmitter.emit_set(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Set()";
    }
    return "new Set(" + _rt("builtin", "iter", args) + ")";
}

impl ESBuiltinEmitter.emit_tuple(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Object.freeze([])";
    }
    return "Object.freeze(Array.from(" + args[0] + "))";
}

impl ESBuiltinEmitter.emit_frozenset(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "Object.freeze(new Set())";
    }
    return "Object.freeze(new Set(" + args[0] + "))";
}

impl ESBuiltinEmitter.emit_bytes(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Uint8Array()";
    }
    return "new Uint8Array(" + args[0] + ")";
}

impl ESBuiltinEmitter.emit_complex(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "complex", args);
}

impl ESBuiltinEmitter.emit_range(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "range", args);
}

impl ESBuiltinEmitter.emit_slice(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    return _rt("builtin", "slice", args);
}

impl ESBuiltinEmitter.emit_bytearray(
    self: ESBuiltinEmitter, ctx: ESEmitCtx, args: list[str]
) -> (str | None) {
    if len(args) == 0 {
        return "new Uint8Array()";
    }
    return "new Uint8Array(" + args[0] + ")";
}
