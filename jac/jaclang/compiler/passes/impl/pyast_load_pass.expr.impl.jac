impl PyastBuildPass.proc_keyword(nd: py_ast.keyword) -> KWPair {
    arg = None;
    if nd.arg {
        arg = self.name_node(nd, nd.arg, is_kwesc=(nd.arg in _reserved_keywords));
    }
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return KWPair(key=arg, value=value, kid=[arg, value] if arg else [value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_comprehension(nd: py_ast.comprehension) -> InnerCompr {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
    valid: (list[Expr] | None) = None;
    if (len(nd.ifs) != 0) {
        ifs_list = [self.convert(ifs) for ifs in nd.ifs];
        valid = [
            ifs
            for ifs in ifs_list
            if isinstance(ifs, Expr)
        ];
    } else {
        valid = None;
    }
    is_async = nd.is_async > 0;
    if (isinstance(target, Expr) and isinstance(iter, Expr)) {
        kid: list[UniNode] = [target, iter];
        conds: list[Expr] = valid or [];
        kid.extend(conds);
        return InnerCompr(
            is_async=is_async,
            target=target,
            collection=iter,
            conditional=valid,
            kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_not_in(nd: py_ast.NotIn) -> Token {
    return self.operator(Tok.KW_NIN, 'not in');
}

impl PyastBuildPass.proc_not_eq(nd: py_ast.NotEq) -> Token {
    return self.operator(Tok.NE, '!=');
}

impl PyastBuildPass.proc_lt_e(nd: py_ast.LtE) -> Token {
    return self.operator(Tok.LTE, '<=');
}

impl PyastBuildPass.proc_lt(nd: py_ast.Lt) -> Token {
    return self.operator(Tok.LT, '<');
}

impl PyastBuildPass.proc_is_not(nd: py_ast.IsNot) -> Token {
    return self.operator(Tok.KW_ISN, 'is not');
}

impl PyastBuildPass.proc_is(nd: py_ast.Is) -> Token {
    return self.operator(Tok.KW_IS, 'is');
}

impl PyastBuildPass.proc_in(nd: py_ast.In) -> Token {
    return self.operator(Tok.KW_IN, 'in');
}

impl PyastBuildPass.proc_gt_e(nd: py_ast.GtE) -> Token {
    return self.operator(Tok.GTE, '>=');
}

impl PyastBuildPass.proc_gt(nd: py_ast.Gt) -> Token {
    return self.operator(Tok.GT, '>');
}

impl PyastBuildPass.proc_eq(nd: py_ast.Eq) -> Token {
    return self.operator(Tok.EE, '==');
}

impl PyastBuildPass.proc_u_sub(nd: py_ast.USub) -> Token {
    return self.operator(Tok.MINUS, '-');
}

impl PyastBuildPass.proc_u_add(nd: py_ast.UAdd) -> Token {
    return self.operator(Tok.PLUS, '+');
}

impl PyastBuildPass.proc_not(nd: py_ast.Not) -> Token {
    return self.operator(Tok.NOT, 'not');
}

impl PyastBuildPass.proc_invert(nd: py_ast.Invert) -> Token {
    return self.operator(Tok.BW_NOT, '~');
}

impl PyastBuildPass.proc_sub(nd: py_ast.Sub) -> Token {
    return self.operator(Tok.MINUS, '-');
}

impl PyastBuildPass.proc_r_shift(nd: py_ast.RShift) -> Token {
    return self.operator(Tok.RSHIFT, '>>');
}

impl PyastBuildPass.proc_pow(nd: py_ast.Pow) -> Token {
    return self.operator(Tok.STAR_POW, '**');
}

impl PyastBuildPass.proc_mat_mult(nd: py_ast.MatMult) -> Token {
    return self.operator(Tok.DECOR_OP, '@');
}

impl PyastBuildPass.proc_mult(nd: py_ast.Mult) -> Token {
    return self.operator(Tok.STAR_MUL, '*');
}

impl PyastBuildPass.proc_mod(nd: py_ast.Mod) -> Token {
    return self.operator(Tok.MOD, '%');
}

impl PyastBuildPass.proc_l_shift(nd: py_ast.LShift) -> Token {
    return self.operator(Tok.LSHIFT, '<<');
}

impl PyastBuildPass.proc_floor_div(nd: py_ast.FloorDiv) -> Token {
    return self.operator(Tok.FLOOR_DIV, '//');
}

impl PyastBuildPass.proc_div(nd: py_ast.Div) -> Token {
    return self.operator(Tok.DIV, '/');
}

impl PyastBuildPass.proc_bit_xor(nd: py_ast.BitXor) -> Token {
    return self.operator(Tok.BW_XOR, '^');
}

impl PyastBuildPass.proc_bit_or(nd: py_ast.BitOr) -> Token {
    return self.operator(Tok.BW_OR, '|');
}

impl PyastBuildPass.proc_bit_and(nd: py_ast.BitAnd) -> Token {
    return self.operator(Tok.BW_AND, '&');
}

impl PyastBuildPass.proc_add(nd: py_ast.Add) -> Token {
    return self.operator(Tok.PLUS, '+');
}

impl PyastBuildPass.proc_or(nd: py_ast.Or) -> Token {
    return self.operator(Tok.KW_OR, 'or');
}

impl PyastBuildPass.proc_and(nd: py_ast.And) -> Token {
    return self.operator(Tok.KW_AND, 'and');
}

impl PyastBuildPass.proc_arguments(nd: py_ast.arguments) -> FuncSignature {
    def _apply_kind(params: list[UniNode], kind: ParamKind) -> list[ParamVar] {
        typed: list[ParamVar] = [];
        for param in params {
            param_var = cast(ParamVar, param);
            param_var.param_kind = kind;
            typed.append(param_var);
        }
        return typed;
    }
    posonlyargs = _apply_kind(
        [self.convert(arg) for arg in nd.posonlyargs], ParamKind.POSONLY
    );
    args = _apply_kind([self.convert(arg) for arg in nd.args], ParamKind.NORMAL);
    vararg_node = self.convert(nd.vararg) if nd.vararg else None;
    vararg: (ParamVar | None) = None;
    if (vararg_node and isinstance(vararg_node, ParamVar)) {
        vararg = vararg_node;
        vararg.param_kind = ParamKind.VARARG;
        _unpack = Token(
            orig_src=self.orig_src,
            name=Tok.STAR_MUL,
            value='*',
            line=vararg.loc.first_line,
            end_line=vararg.loc.last_line,
            col_start=vararg.loc.col_start,
            col_end=vararg.loc.col_end,
            pos_start=0,
            pos_end=0
        );
        vararg.add_kids_left([_unpack], role=UnpackRole);
    }
    kwonlyargs = _apply_kind(
        [self.convert(arg) for arg in nd.kwonlyargs], ParamKind.KWONLY
    );
    for i in range(len(kwonlyargs)) {
        kwa = kwonlyargs[i];
        kwd = nd.kw_defaults[i];
        kwdefault = self.convert(kwd) if kwd else None;

        if (kwdefault and isinstance(kwa, ParamVar) and isinstance(kwdefault, Expr)) {
            kwa.add_kids_right([kwdefault], role=ValueRole);
        }
    }
    kwarg_node = self.convert(nd.kwarg) if nd.kwarg else None;
    kwarg: (ParamVar | None) = None;
    if (kwarg_node and isinstance(kwarg_node, ParamVar)) {
        kwarg = kwarg_node;
        kwarg.param_kind = ParamKind.KWARG;
        _unpack = Token(
            orig_src=self.orig_src,
            name=Tok.STAR_POW,
            value='**',
            line=kwarg.loc.first_line,
            end_line=kwarg.loc.last_line,
            col_start=kwarg.loc.col_start,
            col_end=kwarg.loc.col_end,
            pos_start=0,
            pos_end=0
        );
        kwarg.add_kids_left([_unpack], role=UnpackRole);
    }
    defaults = [self.convert(expr) for expr in nd.defaults];
    for para in [*posonlyargs, *args][::-1] {
        if not defaults {
            break;
        }
        `default = defaults.pop();

        if (`default and isinstance(para, ParamVar) and isinstance(`default, Expr)) {
            para.add_kids_right([`default], role=ValueRole);
        }
    }
    if (kwonlyargs or args or posonlyargs or vararg or kwarg) {
        kids = [];
        kids.extend(posonlyargs) if posonlyargs else None;
        kids.extend(args) if args else None;
        kids.append(vararg) if vararg else None;
        kids.extend(kwonlyargs) if kwonlyargs else None;
        kids.append(kwarg) if kwarg else None;
        return FuncSignature(
            posonly_params=posonlyargs,
            params=args,
            varargs=vararg,
            kwonlyargs=kwonlyargs,
            kwargs=kwarg,
            return_type=None,
            kid=kids
        );
    } else {
        return FuncSignature(
            posonly_params=posonlyargs,
            params=[],
            varargs=vararg,
            kwonlyargs=kwonlyargs,
            kwargs=kwarg,
            return_type=None,
            kid=[self.operator(Tok.LPAREN, '('), self.operator(Tok.RPAREN, ')')]
        );
    }
}

impl PyastBuildPass.proc_arg(nd: py_ast.arg) -> ParamVar {
    name = self.name_node(nd, nd.arg, is_kwesc=(nd.arg in _reserved_keywords));
    self.in_type_annotation = True;
    ann_expr = self.convert(nd.annotation)
        if nd.annotation
        else self.name_node(nd, 'Any');
    self.in_type_annotation = False;
    if not isinstance(ann_expr, Expr) {
        raise RuntimeError(self.ctx.ice('Expected annotation to be an expression'));
    }
    annot = SubTag[Expr](tag=ann_expr, kid=[ann_expr]);
    paramvar = ParamVar(
        name=name, type_tag=annot, unpack=None, value=None, kid=[name, annot]
    );
    return paramvar;
}

impl PyastBuildPass.proc_yield_from(nd: py_ast.YieldFrom) -> YieldExpr {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return YieldExpr(expr=value, with_from=True, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_yield(nd: py_ast.Yield) -> YieldExpr {
    value = self.convert(nd.value) if nd.value else None;
    if isinstance(value, Expr) {
        return YieldExpr(expr=value, with_from=False, kid=[value]);
    } elif not value {
        return YieldExpr(
            expr=None, with_from=False, kid=[self.operator(Tok.KW_YIELD, 'yield')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_tuple(nd: py_ast.Tuple) -> TupleVal {
    elts = [self.convert(elt) for elt in nd.elts];
    if (len(nd.elts) != 0) {
        valid_elts = [
            i
            for i in elts
            if isinstance(i, (Expr, KWPair))
        ];
        if (len(elts) != len(valid_elts)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in tuple elts'));
        }
        kid = elts;
    } else {
        l_paren = self.operator(Tok.LPAREN, '(');
        r_paren = self.operator(Tok.RPAREN, ')');
        valid_elts = [];
        kid = [l_paren, r_paren];
    }
    return TupleVal(values=valid_elts, kid=kid);
}

impl PyastBuildPass.proc_subscript(nd: py_ast.Subscript) -> AtomTrailer {
    value = self.convert(nd.value);
    slice = self.convert(nd.slice);
    if (not isinstance(slice, IndexSlice) and isinstance(slice, Expr)) {
        slice_node = Slice(start=slice, stop=None, step=None, kid=[slice]);
        slice = IndexSlice(slices=[slice_node], is_range=False, kid=[slice_node]);
    }
    if (
        not isinstance(slice, IndexSlice)
        and isinstance(slice, TupleVal)
        and slice.values
    ) {
        slices: list[Slice] = [];
        for index_slice in slice.values {
            if not isinstance(index_slice, IndexSlice) {
                raise RuntimeError(self.ctx.ice());
            }
            slices.append(index_slice.slices[0]);
        }
        slice = IndexSlice(slices=slices, is_range=True, kid=list(slices));
    }
    if (isinstance(value, Expr) and isinstance(slice, IndexSlice)) {
        return AtomTrailer(
            target=value,
            right=slice,
            is_attr=False,
            is_null_ok=False,
            kid=[value, slice]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_starred(nd: py_ast.Starred) -> UnaryExpr {
    star_tok = self.operator(Tok.STAR_MUL, '*');
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return UnaryExpr(operand=value, op=star_tok, kid=[value, star_tok]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_slice(nd: py_ast.Slice) -> IndexSlice {
    lower = self.convert(nd.lower) if nd.lower else None;
    upper = self.convert(nd.upper) if nd.upper else None;
    step = self.convert(nd.step) if nd.step else None;
    valid_kid = [
        i
        for i in [lower, upper, step]
        if i
    ];
    if not valid_kid {
        valid_kid = [self.operator(Tok.COLON, ':')];
    }
    if (
        (isinstance(lower, Expr) or (lower is None))
        and (isinstance(upper, Expr) or (upper is None))
        and (isinstance(step, Expr) or (step is None))
    ) {
        slice_node = Slice(start=lower, stop=upper, step=step, kid=valid_kid);
        return IndexSlice(slices=[slice_node], is_range=True, kid=[slice_node]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass._proc_compr(
    nd: PyComprehensionNode, compr_cls: type[ComprT]
) -> ComprT {
    elt = self.convert(nd.elt);
    generators = [self.convert(gen) for gen in nd.generators];
    valid = [
        gen
        for gen in generators
        if isinstance(gen, InnerCompr)
    ];
    if (len(generators) != len(valid)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in list comp generators'));
    }
    if isinstance(elt, Expr) {
        return compr_cls(out_expr=elt, compr=valid, kid=[elt, *valid]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_set_comp(nd: py_ast.SetComp) -> ListCompr {
    return self._proc_compr(nd, SetCompr);
}

impl PyastBuildPass.proc_set(nd: py_ast.Set) -> SetVal {
    if (len(nd.elts) != 0) {
        elts = [self.convert(i) for i in nd.elts];
        valid = [
            i
            for i in elts
            if isinstance(i, Expr)
        ];
        if (len(valid) != len(elts)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in set body'));
        }
        kid: list[UniNode] = [*valid];
    } else {
        valid = [];
        l_brace = self.operator(Tok.LBRACE, '{');
        r_brace = self.operator(Tok.RBRACE, '}');
        kid = [l_brace, r_brace];
    }
    return SetVal(values=valid, kid=kid);
}

impl PyastBuildPass.proc_named_expr(nd: py_ast.NamedExpr) -> AtomUnit {
    target = self.convert(nd.target);
    value = self.convert(nd.value);
    if (isinstance(value, Expr) and isinstance(target, Name)) {
        op = self.operator(Tok.WALRUS_EQ, ':=');
        if isinstance(value, IfElseExpr) {
            value = AtomUnit(
                value=value,
                kid=[
                    self.operator(Tok.LPAREN, '('),
                    value,
                    self.operator(Tok.RPAREN, ')')
                ]
            );
        }
        expr = BinaryExpr(left=target, op=op, right=value, kid=[target, op, value]);
        return AtomUnit(
            value=expr,
            kid=[self.operator(Tok.LPAREN, '('), expr, self.operator(Tok.RPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_name(nd: py_ast.Name) -> Name {
    should_escape = (
        (nd.id in _reserved_keywords)
        and not self.in_type_annotation
        and not self.in_match_pattern
        and not self.in_fstring_expr
    );
    ret = self.name_node(nd, nd.id, is_kwesc=should_escape);
    return ret;
}

impl PyastBuildPass.proc_list_comp(nd: py_ast.ListComp) -> ListCompr {
    return self._proc_compr(nd, ListCompr);
}

impl PyastBuildPass.proc_list(nd: py_ast.List) -> ListVal {
    elts = [self.convert(elt) for elt in nd.elts];
    valid_elts = [
        elt
        for elt in elts
        if isinstance(elt, Expr)
    ];
    if (len(valid_elts) != len(elts)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in list elements'));
    }
    l_square = self.operator(Tok.LSQUARE, '[');
    r_square = self.operator(Tok.RSQUARE, ']');
    return ListVal(
        values=valid_elts, kid=[*valid_elts] if valid_elts else [l_square, r_square]
    );
}

impl PyastBuildPass.proc_lambda(nd: py_ast.Lambda) -> LambdaExpr {
    args = self.convert(nd.args);
    body = self.convert(nd.body);
    if (isinstance(args, FuncSignature) and isinstance(body, Expr)) {
        body_stmt = ExprStmt(expr=body, in_fstring=False, kid=[body]);
        return LambdaExpr(signature=args, body=[body_stmt], kid=[args, body_stmt]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_joined_str(nd: py_ast.JoinedStr) -> MultiString {
    ast_seg = self._get_source_segment(nd);
    if (ast_seg is None) {
        ast_seg = 'f""';
    }
    fstr_match = re.`match('(?i)(fr|rf|f)(\'{3}|\\"{3}|\'|\\")', ast_seg);

    valid: list[(String | FormattedValue)] = [];
    for i in nd.values {
        if (isinstance(i, py_ast.Constant) and isinstance(i.value, str)) {
            escaped_value = self._get_source_segment(i);
            if escaped_value is None {
                raw_repr = repr(i.value);
                escaped_value = raw_repr[1:-1];
            }

            valid.append(
                String(
                    orig_src=self.orig_src,
                    name='STRING',
                    value=escaped_value,
                    line=i.lineno,
                    end_line=i.end_lineno or i.lineno,
                    col_start=i.col_offset,
                    col_end=(i.col_offset + len(i.value)),
                    pos_start=0,
                    pos_end=0
                )
            );
        } elif isinstance(i, py_ast.FormattedValue) {
            converted = self.convert(i);
            if isinstance(converted, FormattedValue) {
                valid.append(converted);
            }
        } else {
            raise RuntimeError(self.ctx.ice('Invalid node in joined str'));
        }
    }
    if fstr_match {
        (prefix, quote) = fstr_match.groups();
        start = fstr_match.group(0);
        end = quote;
    } else {
        start = "f'";
        end = "'";
    }
    all_content = ''.join(
        part.lit_value
        for part in valid
        if isinstance(part, String)
    );
    has_single = "'" in all_content;
    has_double = '"' in all_content;
    is_triple = len(end) == 3;
    if (has_single and has_double and not is_triple) {
        if ("'" in end) {
            start = 'f"""';
            end = '"""';
        } else {
            start = "f'''";
            end = "'''";
        }
    } elif ((("'" in end) and has_single) or (('"' in end) and has_double)) {
        if ("'" in end) {
            start = start.replace("'", '"');
            end = end.replace("'", '"');
        } else {
            start = start.replace('"', "'");
            end = end.replace('"', "'");
        }
    }
    tok_start = self.operator(Tok.STRING, start);
    tok_end = self.operator(Tok.STRING, end);
    fstr = FString(
        start=tok_start,
        parts=valid,
        end=tok_end,
        kid=[tok_start, *valid, tok_end] if valid else [EmptyToken()]
    );
    return MultiString(strings=[fstr], kid=[fstr]);
}

impl PyastBuildPass.proc_generator_exp(nd: py_ast.GeneratorExp) -> GenCompr {
    return self._proc_compr(nd, GenCompr);
}

impl PyastBuildPass.proc_dict_comp(nd: py_ast.DictComp) -> DictCompr {
    key = self.convert(nd.key);
    value = self.convert(nd.value);
    if (isinstance(key, Expr) and isinstance(value, Expr)) {
        kv_pair = KVPair(key=key, value=value, kid=[key, value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    generators = [self.convert(i) for i in nd.generators];
    valid = [
        i
        for i in generators
        if isinstance(i, InnerCompr)
    ];
    if (len(valid) != len(generators)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in dict compr generators'));
    }
    return DictCompr(kv_pair=kv_pair, compr=valid, kid=[kv_pair, *valid]);
}

impl PyastBuildPass.proc_dict(nd: py_ast.Dict) -> DictVal {
    keys = [self.convert(i) if i else None for i in nd.keys];
    values = [self.convert(i) for i in nd.values];
    valid_keys = [
        i
        for i in keys
        if (isinstance(i, Expr) or (i is None))
    ];
    valid_values = [
        i
        for i in values
        if isinstance(i, Expr)
    ];
    kvpair: list[KVPair] = [];
    for i in range(len(values)) {
        key_pluck = valid_keys[i];
        kvp = KVPair(
            key=key_pluck,
            value=valid_values[i],
            kid=[key_pluck, valid_values[i]] if key_pluck else [valid_values[i]]
        );
        kvpair.append(kvp);
    }
    return DictVal(
        kv_pairs=kvpair,
        kid=[*kvpair]
            if len(kvpair)
            else [self.operator(Tok.LBRACE, '{'), self.operator(Tok.RBRACE, '}')]
    );
}

impl PyastBuildPass.proc_constant(nd: py_ast.Constant) -> Literal {
    type_mapping: dict[type, type[Literal]] = {
        int: Int,
        float: Float,
        str: String,
        bytes: String,
        bool: Bool,
        type(None): Null
    };
    value_type = type(nd.value);
    if (value_type in type_mapping) {
        if (value_type is None) {
            token_type = 'NULL';
        } elif (value_type is str) {
            token_type = 'STRING';
        } else {
            token_type = f"{value_type.__name__.upper()}";
        }
        if (value_type is str) {
            value = self._get_source_segment(nd);
            if value is None {
                raw_repr = repr(nd.value);
                quote = "'" if raw_repr.startswith("'") else '"';
                value = f"{quote}{raw_repr[1:-1]}{quote}";
            } else {
                value = self._strip_string_continuations(value);
            }
        } else {
            value = str(nd.value);
        }
        return type_mapping[value_type](
            orig_src=self.orig_src,
            name=token_type,
            value=value,
            line=nd.lineno,
            end_line=nd.end_lineno or nd.lineno,
            col_start=nd.col_offset,
            col_end=(nd.col_offset + len(str(nd.value))),
            pos_start=0,
            pos_end=0
        );
    } elif (nd.value == Ellipsis) {
        return UniEllipsis(
            orig_src=self.orig_src,
            name=Tok.ELLIPSIS,
            value='...',
            line=nd.lineno,
            end_line=nd.end_lineno or nd.lineno,
            col_start=nd.col_offset,
            col_end=(nd.col_offset + 3),
            pos_start=0,
            pos_end=0
        );
    } else {
        raise RuntimeError(self.ctx.ice('Invalid type for constant'));
    }
}

impl PyastBuildPass.proc_compare(nd: py_ast.Compare) -> AtomUnit {
    left = self.convert(nd.left);
    comparators = [self.convert(comparator) for comparator in nd.comparators];
    valid_comparators = [
        comparator
        for comparator in comparators
        if isinstance(comparator, Expr)
    ];
    ops = [self.convert(op) for op in nd.ops];
    valid_ops = [
        op
        for op in ops
        if isinstance(op, Token)
    ];
    kids = [left, *valid_ops, *valid_comparators];
    if (
        isinstance(left, Expr)
        and (len(ops) == len(valid_ops))
        and (len(comparators) == len(valid_comparators))
    ) {
        expr = CompareExpr(
            left=left, rights=valid_comparators, ops=valid_ops, kid=kids
        );
        return AtomUnit(
            value=expr,
            kid=[self.operator(Tok.RPAREN, '('), expr, self.operator(Tok.LPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_call(nd: py_ast.Call) -> FuncCall {
    func = self.convert(nd.func);
    params_in: list[(Expr | KWPair)] = [];
    args = [self.convert(arg) for arg in nd.args];
    keywords = [self.convert(keyword) for keyword in nd.keywords];
    for i in args {
        if isinstance(i, Expr) {
            params_in.append(i);
        }
    }
    for i in keywords {
        if isinstance(i, KWPair) {
            params_in.append(i);
        }
    }
    kids = [func, *params_in] if (len(params_in) != 0) else [func];
    if isinstance(func, Expr) {
        return FuncCall(target=func, params=params_in, genai_call=None, kid=kids);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_bool_op(nd: py_ast.BoolOp) -> AtomUnit {
    op = self.convert(nd.op);
    values = [self.convert(value) for value in nd.values];
    valid = [
        value
        for value in values
        if isinstance(value, Expr)
    ];
    if (isinstance(op, Token) and (len(valid) == len(values))) {
        cfg_vals = [CfgExpr(expr=v, kid=[v]) for v in valid];
        expr = BoolExpr(op=op, values=cfg_vals, kid=[op, *cfg_vals]);
        return AtomUnit(
            value=expr,
            kid=[self.operator(Tok.RPAREN, '('), expr, self.operator(Tok.LPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_unary_op(nd: py_ast.UnaryOp) -> UnaryExpr {
    op = self.convert(nd.op);
    operand = self.convert(nd.operand);
    if (isinstance(op, Token) and isinstance(operand, Expr)) {
        return UnaryExpr(op=op, operand=operand, kid=[op, operand]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_bin_op(nd: py_ast.BinOp) -> (AtomUnit | BinaryExpr) {
    left = self.convert(nd.left);
    op = self.convert(nd.op);
    right = self.convert(nd.right);
    if (isinstance(left, Expr) and isinstance(op, Token) and isinstance(right, Expr)) {
        unwrapped_left = left;
        if (
            isinstance(left, AtomUnit)
            and isinstance(left.value, BinaryExpr)
            and isinstance(left.value.op, Token)
            and (left.value.op.value == op.value)
        ) {
            unwrapped_left = left.value;
        }
        value = BinaryExpr(
            left=unwrapped_left, op=op, right=right, kid=[unwrapped_left, op, right]
        );
        return AtomUnit(
            value=value,
            kid=[self.operator(Tok.RPAREN, '('), value, self.operator(Tok.LPAREN, ')')]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_await(nd: py_ast.Await) -> AwaitExpr {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return AwaitExpr(target=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_attribute(nd: py_ast.Attribute) -> AtomTrailer {
    value = self.convert(nd.value);
    if (
        isinstance(value, FuncCall)
        and isinstance(value.target, Name)
        and (value.target.value == 'super')
    ) {
        tok = self.name_node(nd, 'super', name_tok=Tok.KW_SUPER);
        value = SpecialVarRef(var=tok);
    }
    attribute = self.name_node(
        nd,
        'init' if (nd.attr == '__init__') else nd.attr,
        name_tok=Tok.KW_INIT if (nd.attr == '__init__') else Tok.NAME,
        col_end=(nd.col_offset + len(nd.attr)),
        is_kwesc=(nd.attr == 'init')
    );
    if isinstance(value, Expr) {
        return AtomTrailer(
            target=value,
            right=attribute,
            is_attr=True,
            is_null_ok=False,
            kid=[value, attribute]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_aug_assign(nd: py_ast.AugAssign) -> Assignment {
    import from jaclang.compiler.frontend.constant { TOKEN_MAP }
    target = self.convert(nd.target);
    op = self.convert(nd.op);
    if isinstance(op, Token) {
        op.name = self.aug_op_map(TOKEN_MAP, op);
    }
    value = self.convert(nd.value);
    if (
        isinstance(value, Expr) and isinstance(target, Expr) and isinstance(op, Token)
    ) {
        return Assignment(
            target=[target],
            type_tag=None,
            mutable=False,
            aug_op=op,
            value=value,
            kid=[target, op, value]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_template_str(nd: py_ast.AST) -> UniNode {
    raise RuntimeError(
        self.ctx.ice("Python 3.14 t-strings (PEP 750) are not supported in Jac")
    );
}

impl PyastBuildPass.proc_interpolation(nd: py_ast.AST) -> UniNode {
    raise RuntimeError(
        self.ctx.ice("Python 3.14 t-string interpolations are not supported in Jac")
    );
}
