impl PyastBuildPass.proc_withitem(nd: py_ast.withitem) -> ExprAsItem {
    context_expr = self.convert(nd.context_expr);
    optional_vars = self.convert(nd.optional_vars) if nd.optional_vars else None;
    if (
        isinstance(context_expr, Expr)
        and (isinstance(optional_vars, Expr) or (optional_vars is None))
    ) {
        kid: list[UniNode] = [context_expr];
        if optional_vars is not None {
            kid.append(optional_vars);
        }
        return ExprAsItem(expr=context_expr, alias=optional_vars or None, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_case(nd: py_ast.match_case) -> MatchCase {
    pattern = self.convert(nd.pattern);
    guard = self.convert(nd.guard) if nd.guard else None;
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (
        isinstance(pattern, MatchPattern)
        and (isinstance(guard, Expr) or (guard is None))
    ) {
        kid: list[UniNode] = [pattern];
        if guard is not None {
            kid.append(guard);
        }
        kid.extend(valid);
        return MatchCase(pattern=pattern, guard=guard, body=valid, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_alias(nd: py_ast.alias) -> ExprAsItem {
    name = self.name_node(nd, nd.name);
    asname = self.name_node(nd, nd.asname) if nd.asname else None;
    return ExprAsItem(
        expr=name, alias=asname, kid=[name, asname] if asname else [name]
    );
}

impl PyastBuildPass.proc_try_star(nd: py_ast.TryStar) -> TryStmt {
    return self.proc_try(nd);
}

impl PyastBuildPass.proc_try(nd: (py_ast.Try | py_ast.TryStar)) -> TryStmt {
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(valid) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in try body'));
    }
    valid_body = valid;
    kid: list[UniNode] = [*valid_body];
    if (len(nd.handlers) != 0) {
        handlers = [self.convert(i) for i in nd.handlers];
        valid_handlers = [
            i
            for i in handlers
            if isinstance(i, Except)
        ];
        if (len(handlers) != len(valid_handlers)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in try handlers'));
        }
        excepts = valid_handlers;
        kid.extend(valid_handlers);
    } else {
        excepts = [];
    }
    else_body: (list[CodeBlockStmt] | None) = None;
    elsestmt: (ElseStmt | None) = None;
    if (len(nd.orelse) != 0) {
        orelse = [self.convert(i) for i in nd.orelse];
        valid_orelse = [
            i
            for i in orelse
            if isinstance(i, CodeBlockStmt)
        ];
        if (len(orelse) != len(valid_orelse)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in try orelse'));
        }
        else_body = valid_orelse;
        elsestmt = ElseStmt(body=valid_orelse, kid=valid_orelse);
        kid.extend(valid_orelse);
    } else {
        else_body = None;
    }
    if (len(nd.finalbody) != 0) {
        finalbody = [self.convert(i) for i in nd.finalbody];
        valid_finalbody = [
            i
            for i in finalbody
            if isinstance(i, CodeBlockStmt)
        ];
        if (len(finalbody) != len(valid_finalbody)) {
            raise RuntimeError(self.ctx.ice('Length mismatch in try finalbody'));
        }
        finally_stmt_obj: (FinallyStmt | None) = (
            fin_append := FinallyStmt(body=valid_finalbody, kid=valid_finalbody)
        );
        kid.append(fin_append);
    } else {
        finally_stmt_obj = None;
    }
    ret = TryStmt(
        body=valid_body,
        excepts=excepts,
        else_body=elsestmt if else_body else None,
        awaiting_body=None,
        finally_body=finally_stmt_obj,
        kid=kid
    );
    return ret;
}

impl PyastBuildPass.proc_pass(nd: py_ast.Pass) -> Semi {
    return Semi(
        orig_src=self.orig_src,
        name=Tok.SEMI,
        value=';',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
}

impl PyastBuildPass.proc_nonlocal(nd: py_ast.Nonlocal) -> Semi {
    return self.proc_pass(cast(py_ast.Pass, nd));
}

impl PyastBuildPass.proc_match_value(nd: py_ast.MatchValue) -> MatchValue {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return MatchValue(value=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_star(nd: py_ast.MatchStar) -> MatchStar {
    name = self.name_node(nd, nd.name or '_');
    return MatchStar(name=name, is_list=True, kid=[name]);
}

impl PyastBuildPass.proc_match_singleton(nd: py_ast.MatchSingleton) -> MatchSingleton {
    type = Tok.NULL if (nd.value is None) else Tok.BOOL;
    ret_type = Null if (nd.value is None) else Bool;
    value = ret_type(
        orig_src=self.orig_src,
        name=type,
        value=str(nd.value),
        line=nd.lineno,
        end_line=nd.end_lineno or nd.lineno,
        col_start=nd.col_offset,
        col_end=(nd.col_offset + len(str(nd.value))),
        pos_start=0,
        pos_end=0
    );
    if isinstance(value, (Bool, Null)) {
        return MatchSingleton(value=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_sequence(nd: py_ast.MatchSequence) -> MatchSequence {
    patterns = [self.convert(i) for i in nd.patterns];
    valid = [
        i
        for i in patterns
        if isinstance(i, MatchPattern)
    ];
    if (len(patterns) == len(valid)) {
        return MatchSequence(values=valid, kid=valid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_or(nd: py_ast.MatchOr) -> MatchOr {
    patterns = [self.convert(i) for i in nd.patterns];
    valid = [
        i
        for i in patterns
        if isinstance(i, MatchPattern)
    ];
    return MatchOr(patterns=valid, kid=valid);
}

impl PyastBuildPass.proc_match_mapping(nd: py_ast.MatchMapping) -> MatchMapping {
    values: list[(MatchKVPair | MatchStar)] = [];
    keys = [self.convert(i) for i in nd.keys];
    valid_keys = [
        i
        for i in keys
        if isinstance(i, (MatchPattern, NameAtom, AtomExpr))
    ];
    patterns = [self.convert(i) for i in nd.patterns];
    valid_patterns = [
        i
        for i in patterns
        if isinstance(i, MatchPattern)
    ];
    for i in range(len(valid_keys)) {
        colon_token = Token(
            orig_src=self.orig_src,
            name=Tok.COLON,
            value=":",
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
        kv_pair = MatchKVPair(
            key=valid_keys[i],
            value=valid_patterns[i],
            kid=[valid_keys[i], colon_token, valid_patterns[i]]
        );
        values.append(kv_pair);
    }
    if nd.rest {
        name = self.name_node(nd, nd.rest);
        values.append(MatchStar(name=name, is_list=False, kid=[name]));
    }
    return MatchMapping(values=values, kid=values);
}

impl PyastBuildPass.proc_match_class(nd: py_ast.MatchClass) -> MatchArch {
    self.in_match_pattern = True;
    cls = self.convert(nd.cls);
    self.in_match_pattern = False;
    kid = [cls];
    patterns_list: (list[MatchPattern] | None) = None;
    kw_patterns_list: (list[MatchKVPair] | None) = None;
    if (len(nd.patterns) != 0) {
        patterns = [self.convert(i) for i in nd.patterns];
        valid_patterns = [
            i
            for i in patterns
            if isinstance(i, MatchPattern)
        ];
        if (len(patterns) == len(valid_patterns)) {
            kid.extend(valid_patterns);
            patterns_list = valid_patterns;
        } else {
            raise RuntimeError(self.ctx.ice());
        }
    } else {
        patterns_list = None;
    }
    if len(nd.kwd_patterns) {
        kv_pairs: list[MatchKVPair] = [];
        names: list[Name] = [];
        valid_kwd_patterns: list[MatchPattern] = [];
        kwd_patterns = [self.convert(i) for i in nd.kwd_patterns];
        for i in range(len(nd.kwd_attrs)) {
            kwd_attrs = nd.kwd_attrs[i];
            if isinstance(kwd_patterns[i], MatchPattern) {
                names.append(
                    Name(
                        orig_src=self.orig_src,
                        name=Tok.NAME,
                        value=kwd_attrs,
                        line=nd.lineno,
                        end_line=nd.end_lineno or nd.lineno,
                        col_start=nd.col_offset,
                        col_end=(nd.col_offset + len(kwd_attrs)),
                        pos_start=0,
                        pos_end=0
                    )
                );
                valid_kwd_patterns.append(kwd_patterns[i]);
            }
        }
        for i in range(len(valid_kwd_patterns)) {
            eq_token = Token(
                orig_src=self.orig_src,
                name=Tok.EQ,
                value="=",
                line=0,
                end_line=0,
                col_start=0,
                col_end=0,
                pos_start=0,
                pos_end=0
            );
            kv_pairs.append(
                MatchKVPair(
                    key=names[i],
                    value=valid_kwd_patterns[i],
                    kid=[names[i], eq_token, valid_kwd_patterns[i]]
                )
            );
        }
        kid.extend(kv_pairs);
        kw_patterns_list = kv_pairs;
    } else {
        kw_patterns_list = None;
    }
    if isinstance(cls, (NameAtom, AtomTrailer)) {
        return MatchArch(
            name=cls, arg_patterns=patterns_list, kw_patterns=kw_patterns_list, kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_match_as(nd: py_ast.MatchAs) -> (MatchAs | MatchWild) {
    pattern = self.convert(nd.pattern) if nd.pattern else None;
    name = self.name_node(nd, nd.name or '_');
    if (
        (name.value == '_')
        or ((pattern is not None) and not isinstance(pattern, MatchPattern))
    ) {
        return MatchWild(kid=[name]);
    }
    return MatchAs(
        name=name, pattern=pattern, kid=[name] if (pattern is None) else [name, pattern]
    );
}

impl PyastBuildPass.proc_match(nd: py_ast.Match) -> MatchStmt {
    subject = self.convert(nd.subject);
    cases = [self.convert(i) for i in nd.cases];
    valid = [
        `case
        for `case in cases
        if isinstance(`case, MatchCase)
    ];
    if isinstance(subject, Expr) {
        return MatchStmt(target=subject, cases=valid, kid=[subject, *valid]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_import_from(nd: py_ast.ImportFrom) -> Import {
    lang = self.name_node(nd, 'py', col_end=0);
    modpaths: list[Name] = [];
    if nd.module {
        for i in nd.module.split('.') {
            modpaths.append(self.name_node(nd, i, col_start=0, col_end=0));
        }
    }
    moddots = [self.operator(Tok.DOT, '.') for _ in range(nd.level)];
    modparts = moddots + modpaths;
    path = ModulePath(path=modpaths or None, level=nd.level, alias=None, kid=modparts);
    names = [self.convert(name) for name in nd.names];
    valid_names = [];
    for name in names {
        if (
            isinstance(name, ExprAsItem)
            and isinstance(name.expr, Name)
            and (isinstance(name.alias, Name) or (name.alias is None))
        ) {
            valid_names.append(
                ModuleItem(
                    name=name.expr,
                    alias=name.alias or None,
                    kid=[
                        i
                        for i in name.kid
                        if i
                    ]
                )
            );
        } else {
            raise RuntimeError(self.ctx.ice());
        }
    }
    items = valid_names;
    if not items {
        raise RuntimeError(self.ctx.ice('No valid names in import from'));
    }
    pytag = SubTag[Name](tag=lang, kid=[lang]);
    if ((len(nd.names) == 1) and (nd.names[0].name == '*')) {
        ret = Import(from_loc=None, items=[path], is_absorb=True, kid=[pytag, path]);
        return ret;
    }
    ret = Import(
        from_loc=path, items=items, is_absorb=False, kid=[pytag, path, *items]
    );
    return ret;
}

impl PyastBuildPass.proc_import(nd: py_ast.Import) -> Import {
    names = [self.convert(name) for name in nd.names];
    valid_names = [
        name
        for name in names
        if isinstance(name, ExprAsItem)
    ];
    if (len(valid_names) != len(names)) {
        self.ctx.emit(E5041);
    }
    paths = [];
    for name in valid_names {
        if (
            isinstance(name.expr, Name)
            and (isinstance(name.alias, Name) or (name.alias is None))
        ) {
            segments: list[Name] = [
                self.name_node(nd, part) for part in name.expr.value.split(".")
            ];
            if not segments {
                segments = [name.expr];
            }
            seg_kid: list[UniNode] = list(segments);
            if name.alias {
                seg_kid.append(name.alias);
            }
            paths.append(
                ModulePath(path=segments, level=0, alias=name.alias, kid=seg_kid)
            );
        } else {
            raise RuntimeError(self.ctx.ice());
        }
    }
    ret = Import(from_loc=None, items=paths, is_absorb=False, kid=paths);
    return ret;
}

impl PyastBuildPass.proc_if_exp(nd: py_ast.IfExp) -> IfElseExpr {
    `test = self.convert(nd.`test);
    body = self.convert(nd.body);
    orelse = self.convert(nd.orelse);
    if (
        isinstance(`test, Expr) and isinstance(body, Expr) and isinstance(orelse, Expr)
    ) {
        cond_cfg = CfgExpr(expr=`test, kid=[`test]);
        val_cfg = CfgExpr(expr=body, kid=[body]);
        else_cfg = CfgExpr(expr=orelse, kid=[orelse]);
        return IfElseExpr(
            value=val_cfg,
            condition=cond_cfg,
            else_value=else_cfg,
            kid=[val_cfg, cond_cfg, else_cfg]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_global(nd: py_ast.Global) -> Semi {
    return self.proc_pass(cast(py_ast.Pass, nd));
}

impl PyastBuildPass.proc_formatted_value(nd: py_ast.FormattedValue) -> FormattedValue {
    prev_in_fstring = self.in_fstring_expr;
    self.in_fstring_expr = True;
    value = self.convert(nd.value);
    self.in_fstring_expr = prev_in_fstring;

    fmt_spec: (Expr | None) = None;
    if nd.format_spec {
        if isinstance(nd.format_spec, py_ast.JoinedStr) {
            fmt_parts: list[str] = [];
            for part in nd.format_spec.values {
                if isinstance(part, py_ast.Constant) and isinstance(part.value, str) {
                    fmt_parts.append(part.value);
                } elif isinstance(part, py_ast.FormattedValue) {
                    nested_fmt = self.convert(part);
                    if isinstance(nested_fmt, FormattedValue) {
                        fmt_spec = nested_fmt;
                        break;
                    }
                }
            }
            if (not fmt_spec and fmt_parts) {
                fmt_str = ''.join(fmt_parts);
                fmt_spec = String(
                    orig_src=self.orig_src,
                    name='STRING',
                    value=fmt_str,
                    line=nd.format_spec.lineno,
                    end_line=nd.format_spec.end_lineno or nd.format_spec.lineno,
                    col_start=nd.format_spec.col_offset,
                    col_end=nd.format_spec.end_col_offset or nd.format_spec.col_offset,
                    pos_start=0,
                    pos_end=0
                );
            }
        } else {
            fmt_spec = cast(Expr, self.convert(nd.format_spec));
        }
    }
    if isinstance(value, Expr) {
        kid: list[UniNode] = [value];
        if fmt_spec is not None {
            kid.append(fmt_spec);
        }
        ret = FormattedValue(
            format_part=value, conversion=nd.conversion, format_spec=fmt_spec, kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    return ret;
}

impl PyastBuildPass.proc_expr(nd: py_ast.Expr) -> ExprStmt {
    value = self.convert(nd.value);
    if isinstance(value, Expr) {
        return ExprStmt(expr=value, in_fstring=False, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_except_handler(nd: py_ast.ExceptHandler) -> Except {
    type = self.convert(nd.type) if nd.type else None;
    name: (Name | None) = None;
    if (not type and not nd.name) {
        type = self.name_node(nd, 'Exception');
        name = self.name_node(nd, 'e');
    } else {
        name = self.name_node(nd, nd.name) if nd.name else None;
    }
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(valid) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in except handler body'));
    }
    kid = [
        item
        for item in [type, name, *valid]
        if item
    ];
    if (isinstance(type, Expr) and (isinstance(name, Name) or not name)) {
        return Except(ex_type=type, name=name, body=valid, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_continue(nd: py_ast.Continue) -> CtrlStmt {
    continue_tok = Token(
        orig_src=self.orig_src,
        name=Tok.KW_CONTINUE,
        value='continue',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
    return CtrlStmt(ctrl=continue_tok, kid=[continue_tok]);
}

impl PyastBuildPass.proc_break(nd: py_ast.Break) -> CtrlStmt {
    break_tok = Token(
        orig_src=self.orig_src,
        name=Tok.KW_BREAK,
        value='break',
        line=0,
        end_line=0,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
    return CtrlStmt(ctrl=break_tok, kid=[break_tok]);
}

impl PyastBuildPass.proc_assert(nd: py_ast.Assert) -> AssertStmt {
    `test = self.convert(nd.`test);
    msg = self.convert(nd.msg) if nd.msg else None;
    if (isinstance(`test, Expr) and (isinstance(msg, Expr) or (msg is None))) {
        kid: list[UniNode] = [`test];
        if msg is not None {
            kid.append(msg);
        }
        return AssertStmt(condition=`test, error_msg=msg, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_raise(nd: py_ast.Raise) -> RaiseStmt {
    exc = self.convert(nd.exc) if nd.exc else None;
    cause = self.convert(nd.cause) if nd.cause else None;
    kid: list[(Expr | Token)] = [];
    if isinstance(exc, Expr) {
        kid = [exc];
    }
    if isinstance(cause, Expr) {
        kid.append(cause);
    }
    if not (exc and cause) {
        kid.append(self.operator(Tok.KW_RAISE, 'raise'));
    }
    if (
        (isinstance(cause, Expr) or (cause is None))
        and (isinstance(exc, Expr) or (exc is None))
    ) {
        if (isinstance(exc, Expr) and not nd.cause) {
            return RaiseStmt(
                cause=exc,
                from_target=None,
                kid=[self.operator(Tok.KW_RAISE, 'raise'), exc]
            );
        } else {
            return RaiseStmt(cause=cause, from_target=exc, kid=kid);
        }
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_async_with(nd: py_ast.AsyncWith) -> WithStmt {
    items = [self.convert(item) for item in nd.items];
    valid_items = [
        item
        for item in items
        if isinstance(item, ExprAsItem)
    ];
    if (len(valid_items) != len(items)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in with items'));
    }
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in async for body'));
    }
    return WithStmt(
        is_async=True,
        exprs=valid_items,
        body=valid_body,
        kid=[*valid_items, *valid_body]
    );
}

impl PyastBuildPass.proc_with(nd: py_ast.With) -> WithStmt {
    items = [self.convert(item) for item in nd.items];
    valid_items = [
        item
        for item in items
        if isinstance(item, ExprAsItem)
    ];
    if (len(valid_items) != len(items)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in with items'));
    }
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in async for body'));
    }
    return WithStmt(
        is_async=False,
        exprs=valid_items,
        body=valid_body,
        kid=[*valid_items, *valid_body]
    );
}

impl PyastBuildPass.proc_if(nd: py_ast.If) -> IfStmt {
    `test = self.convert(nd.`test);
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        self.ctx.emit(E5042);
    }
    body2 = valid_body;
    orelse = [self.convert(stmt) for stmt in nd.orelse];
    valid_orelse = [
        stmt
        for stmt in orelse
        if isinstance(stmt, CodeBlockStmt)
    ];
    if valid_orelse {
        first_elm = valid_orelse[0];
        if (isinstance(first_elm, IfStmt) and (len(valid_orelse) == 1)) {
            else_body: ElseIf | ElseStmt | None = ElseIf(
                condition=first_elm.condition,
                body=first_elm.body,
                else_body=first_elm.else_body,
                kid=first_elm.kid
            );
        } else {
            else_body = ElseStmt(body=valid_orelse, kid=valid_orelse);
        }
    } else {
        else_body = None;
    }
    if isinstance(`test, Expr) {
        kid: list[UniNode] = [`test, *body2];
        if else_body is not None {
            kid.append(else_body);
        }
        ret = IfStmt(condition=`test, body=body2, else_body=else_body, kid=kid);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    return ret;
}

impl PyastBuildPass.proc_while(nd: py_ast.While) -> WhileStmt {
    `test = self.convert(nd.`test);
    body = [self.convert(stmt) for stmt in nd.body];
    valid_body = [
        stmt
        for stmt in body
        if isinstance(stmt, CodeBlockStmt)
    ];
    if (len(valid_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in while body'));
    }
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for orelse'));
    }
    fin_orelse = ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
    if isinstance(`test, Expr) {
        return WhileStmt(
            condition=`test,
            body=valid_body,
            else_body=fin_orelse,
            kid=[`test, *valid_body]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_async_for(nd: py_ast.AsyncFor) -> InForStmt {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
    body = [self.convert(i) for i in nd.body];
    val_body = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for body'));
    }
    valid_body = val_body;
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for orelse'));
    }
    fin_orelse = ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
    if (isinstance(target, Expr) and isinstance(iter, Expr)) {
        return InForStmt(
            target=target,
            is_async=True,
            collection=iter,
            body=valid_body,
            else_body=fin_orelse,
            kid=[target, iter, *valid_body, fin_orelse]
                if fin_orelse
                else [target, iter, *valid_body]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_for(nd: py_ast.For) -> InForStmt {
    target = self.convert(nd.target);
    iter = self.convert(nd.iter);
    body = [self.convert(i) for i in nd.body];
    val_body = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_body) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for body'));
    }
    valid_body = val_body;
    orelse = [self.convert(i) for i in nd.orelse];
    val_orelse = [
        i
        for i in orelse
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(val_orelse) != len(orelse)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in for orelse'));
    }
    fin_orelse = ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
    if (isinstance(target, Expr) and isinstance(iter, Expr)) {
        return InForStmt(
            target=target,
            is_async=False,
            collection=iter,
            body=valid_body,
            else_body=fin_orelse,
            kid=[target, iter, *valid_body, fin_orelse]
                if fin_orelse
                else [target, iter, *valid_body]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_ann_assign(nd: py_ast.AnnAssign) -> Assignment {
    target = self.convert(nd.target);
    self.in_type_annotation = True;
    annotation = self.convert(nd.annotation);
    self.in_type_annotation = False;
    if isinstance(annotation, Expr) {
        annotation_subtag = SubTag[Expr](tag=annotation, kid=[annotation]);
    } else {
        raise RuntimeError(self.ctx.ice());
    }
    value = self.convert(nd.value) if nd.value else None;
    if (
        (isinstance(value, (Expr, YieldExpr)) or not value)
        and isinstance(annotation, Expr)
        and isinstance(target, Expr)
    ) {
        assign_value = value if isinstance(value, (Expr, YieldExpr)) else None;
        kid: list[UniNode] = [target, annotation_subtag];
        if assign_value is not None {
            kid.append(assign_value);
        }
        return Assignment(
            target=[target],
            value=assign_value,
            type_tag=annotation_subtag,
            mutable=False,
            kid=kid
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_assign(nd: py_ast.Assign) -> Assignment {
    value = self.convert(nd.value);
    targets = [self.convert(target) for target in nd.targets];
    valid = [
        target
        for target in targets
        if isinstance(target, Expr)
    ];
    if not (len(valid) == len(targets)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in assignment targets'));
    }
    if isinstance(value, Expr) {
        return Assignment(
            target=valid, value=value, type_tag=None, mutable=False, kid=[*valid, value]
        );
    } else {
        raise RuntimeError(self.ctx.ice());
    }
}

impl PyastBuildPass.proc_delete(nd: py_ast.Delete) -> DeleteStmt {
    exprs = [self.convert(target) for target in nd.targets];
    valid_exprs = [
        expr
        for expr in exprs
        if isinstance(expr, Expr)
    ];
    if (not len(valid_exprs) or (len(valid_exprs) != len(exprs))) {
        raise RuntimeError(self.ctx.ice('Length mismatch in delete targets'));
    }
    return DeleteStmt(targets=valid_exprs, kid=[*valid_exprs]);
}

impl PyastBuildPass.proc_return(nd: py_ast.Return) -> (ReturnStmt | None) {
    value = self.convert(nd.value) if nd.value else None;
    if not value {
        return ReturnStmt(expr=None, kid=[self.operator(Tok.KW_RETURN, 'return')]);
    } elif (value and isinstance(value, Expr)) {
        return ReturnStmt(expr=value, kid=[value]);
    } else {
        raise RuntimeError(self.ctx.ice('Invalid return value'));
    }
}

impl PyastBuildPass.proc_class_def(nd: py_ast.ClassDef) -> (Archetype | Enum) {
    name = self.name_node(nd, nd.name);
    arch_type = Token(
        orig_src=self.orig_src,
        name=Tok.KW_CLASS,
        value='class',
        line=nd.lineno,
        end_line=nd.end_lineno or nd.lineno,
        col_start=0,
        col_end=0,
        pos_start=0,
        pos_end=0
    );
    body = [self.convert(i) for i in nd.body];
    for body_stmt in body {
        if (
            isinstance(body_stmt, Ability)
            and isinstance(body_stmt.name_ref, Name)
            and (body_stmt.name_ref.value == '__init__')
        ) {
            tok = self.name_node(nd, 'init', name_tok=Tok.KW_INIT);
            body_stmt._role_set(NameRefRole, SpecialVarRef(var=tok));
        }

        if (
            isinstance(body_stmt, Ability)
            and body_stmt.signature
            and isinstance(body_stmt.signature, FuncSignature)
            and body_stmt.signature.params
        ) {
            for param in body_stmt.signature.params {
                if (
                    (param.name.value == 'self')
                    and param.type_tag
                    and isinstance(param.type_tag.tag, Name)
                ) {
                    param.type_tag.tag.value = name.value;
                }
            }
        }
    }
    doc = body[0].expr
        if (body and isinstance(body[0], ExprStmt) and isinstance(body[0].expr, String))
        else None;
    self.convert_to_doc(doc) if doc else None;
    body = body[1:] if doc else body;
    valid: list[ArchBlockStmt] = self.extract_with_entry(body, ArchBlockStmt)
        if (body and not (isinstance(body[0], Semi) and (len(body) == 1)))
        else [];
    empty_block: Sequence[UniNode] = [
        self.operator(Tok.LBRACE, '{'),
        self.operator(Tok.RBRACE, '}')
    ];
    valid_body = valid or empty_block;
    converted_base_classes = [self.convert(base) for base in nd.bases];
    base_classes: list[Expr] = [
        base
        for base in converted_base_classes
        if isinstance(base, Expr)
    ];
    converted_keywords = [self.convert(kw) for kw in nd.keywords];
    keywords: list[KWPair] = [
        kw
        for kw in converted_keywords
        if isinstance(kw, KWPair)
    ];
    converted_decorators_list = [self.convert(i) for i in nd.decorator_list];
    decorators = [
        i
        for i in converted_decorators_list
        if isinstance(i, Expr)
    ];
    if (len(decorators) != len(converted_decorators_list)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in decorators on class'));
    }
    valid_decorators = decorators or None;
    kid: list[UniNode] = [];
    if valid_decorators {
        kid.extend(valid_decorators);
    }
    kid.append(arch_type);
    kid.append(name);
    kid.extend(base_classes);
    kid.extend(keywords);
    kid.extend(valid_body);
    if doc {
        kid.append(doc);
    }
    return Archetype(
        arch_type=arch_type,
        name=name,
        access=None,
        base_classes=base_classes,
        keywords=keywords,
        body=valid,
        kid=kid,
        doc=doc,
        decorators=valid_decorators
    );
}

impl PyastBuildPass.proc_async_function_def(nd: py_ast.AsyncFunctionDef) -> Ability {
    ability = self.proc_function_def(nd);
    ability.is_async = True;
    return ability;
}

impl PyastBuildPass.proc_function_def(
    nd: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
) -> Ability {
    name = self.name_node(nd, nd.name, is_kwesc=(nd.name in _reserved_keywords));
    body = [self.convert(i) for i in nd.body];
    valid = [
        i
        for i in body
        if isinstance(i, CodeBlockStmt)
    ];
    if (len(valid) != len(body)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in function body'));
    }
    doc: (String | None) = None;
    if (
        len(valid)
        and isinstance(valid[0], ExprStmt)
        and isinstance(valid[0].expr, String)
    ) {
        self.convert_to_doc(valid[0].expr);
        doc = valid[0].expr;
        valid_body = valid[1:];
    } else {
        doc = None;
        valid_body = valid;
    }
    decorators = [self.convert(i) for i in nd.decorator_list];
    valid_dec = [
        i
        for i in decorators
        if isinstance(i, Expr)
    ];
    if (len(valid_dec) != len(decorators)) {
        raise RuntimeError(self.ctx.ice('Length mismatch in decorators on function'));
    }
    valid_decorators = valid_dec or None;
    res = self.convert(nd.args);
    sig: (FuncSignature | None) = res if isinstance(res, FuncSignature) else None;
    self.in_type_annotation = True;
    ret_sig = self.convert(nd.returns) if nd.returns else None;
    if ret_sig is None {
        ret_sig = self.name_node(
            nd, 'object', col_end=nd.col_offset, end_line=nd.lineno
        );
    }
    self.in_type_annotation = False;
    if isinstance(ret_sig, Expr) {
        if not sig {
            sig = FuncSignature(
                posonly_params=[],
                params=[],
                varargs=None,
                kwonlyargs=[],
                kwargs=None,
                return_type=ret_sig,
                kid=[ret_sig]
            );
        } else {
            sig.add_kids_right([ret_sig], role=ReturnTypeRole);
        }
    }
    if not sig {
        raise RuntimeError(self.ctx.ice('Function signature not found'));
    }
    kid = [];
    if doc {
        kid.append(doc);
    }
    if valid_decorators {
        kid.extend(valid_decorators);
    }
    kid.append(name);
    kid.append(sig);
    kid.extend(valid_body);
    ret = Ability(
        name_ref=name,
        is_async=False,
        is_static=False,
        is_classmethod=False,
        is_abstract=False,
        is_override=False,
        access=None,
        signature=sig,
        body=valid_body,
        decorators=valid_decorators,
        doc=doc,
        kid=kid
    );
    return ret;
}

impl PyastBuildPass.proc_module(nd: py_ast.Module) -> Module {
    if not nd.body {
        return Module.make_stub(inject_src=self.orig_src);
    }
    elements: list[UniNode] = [self.convert(i) for i in nd.body];
    elements[0] = elements[0].expr
        if (isinstance(elements[0], ExprStmt) and isinstance(elements[0].expr, String))
        else elements[0];
    doc_str_list = [elements[0]] if isinstance(elements[0], String) else [];
    top_level: tuple[type[ElementStmt], type[EmptyToken]] = (ElementStmt, EmptyToken);
    valid = (doc_str_list + self.extract_with_entry(elements[1:], top_level))
        if doc_str_list
        else self.extract_with_entry(elements[:], top_level);
    doc_str = elements[0] if isinstance(elements[0], String) else None;
    self.convert_to_doc(doc_str) if doc_str else None;
    ret = Module(
        name=self.mod_path.split(os.path.sep)[-1].split('.')[0],
        source=Source('', mod_path=self.mod_path),
        doc=doc_str,
        body=valid[1:] if (valid and isinstance(valid[0], String)) else valid,
        terminals=[],
        kid=valid
    );
    ret.is_raised_from_py = True;
    return self.nu(ret);
}
