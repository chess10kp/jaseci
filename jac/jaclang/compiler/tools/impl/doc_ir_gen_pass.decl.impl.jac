impl DocIRGenPass.exit_event_signature with uni.EventSignature exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_sem_def with uni.SemDef exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (i in here.target) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.DOT)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name in [Tok.EQ, Tok.KW_IS])) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_impl_def with uni.ImplDef exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if ((i == here.doc) or (here.decorators and (i in here.decorators))) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif self.is_within(i, here.target) {
            parts.append(i.gen.doc_ir);
        } elif (
            isinstance(i, uni.Token)
            and (i.name == Tok.DOT)
            and here.target
            and len(here.target) > 1
        ) {
            parts.append(i.gen.doc_ir);
        } elif (
            in_body
            or (isinstance(here.body, Sequence) and here.body and (i == here.body[0]))
        ) {
            if not in_body {
                parts.pop();
                body_parts.append(self.hard_line());
            }
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                body_parts.pop();
                body_parts.append(i.gen.doc_ir);
                body_parts.append(self.hard_line());
            } else {
                self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
                prev_body_item = i;
            }
            in_body = True;
            if (in_body and isinstance(here.body, Sequence) and (i == here.body[-1])) {
                in_body = False;
                self.trim_trailing_line(body_parts);
                parts.append(self.indent(self.concat(body_parts), ast_node=here));
                parts.append(self.hard_line());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.EventSignature) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (
            isinstance(i, uni.Token)
            and (i.name == Tok.LBRACE)
            and isinstance(here.body, Sequence)
            and not here.body
        ) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_sub_tag with uni.SubTag exit {
    before_colon: list[doc.DocType] = [];
    after_colon: list[doc.DocType] = [];
    seen_colon = False;
    prev_after: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON) and not seen_colon) {
            colon_tok = i.gen.doc_ir;
            seen_colon = True;
        } elif seen_colon {
            if after_colon
                and not (
                    isinstance(prev_after, uni.Token)
                    and (prev_after.name == Tok.BW_AND)
                ) {
                after_colon.append(self.space());
            }
            after_colon.append(i.gen.doc_ir);
            prev_after = i;
        } else {
            before_colon.append(i.gen.doc_ir);
        }
    }
    if seen_colon {
        is_access_modifier = (
            isinstance(here.tag, uni.Token)
            and (here.tag.name in [Tok.KW_PUB, Tok.KW_PRIV, Tok.KW_PROT])
        );
        if is_access_modifier {
            flat = self.concat([*before_colon, colon_tok, *after_colon]);
            broke = self.concat(
                [
                    *before_colon,
                    colon_tok,
                    self.indent(self.concat([self.line(), *after_colon]))
                ]
            );
        } else {
            flat = self.concat([*before_colon, colon_tok, self.space(), *after_colon]);
            broke = self.concat(
                [
                    *before_colon,
                    colon_tok,
                    self.indent(self.concat([self.line(), *after_colon]))
                ]
            );
        }
        here.gen.doc_ir = self.group(self.if_break(broke, flat));
    } else {
        here.gen.doc_ir = self.concat((before_colon + after_colon));
    }
}

impl DocIRGenPass.exit_enum with uni.Enum exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    for i in here.kid {
        if (
            (here.doc and (i is here.doc))
            or (here.decorators and (i in here.decorators))
        ) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
            body_parts.append(self.line());
            in_body = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_body = False;
            if (len(body_parts) and isinstance(body_parts[-1], doc.Line)) {
                body_parts.pop();
            }
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            parts.append(self.line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif in_body {
            body_parts.append(i.gen.doc_ir);
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                body_parts.append(self.line());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LPAREN)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_arch_has with uni.ArchHas exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    first_comma_seen = False;
    semi_doc: (doc.DocType | None) = None;
    for i in here.kid {
        if (i == here.doc) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            if indent_parts {
                indent_parts.pop();
            } elif parts {
                parts.pop();
            }
            semi_doc = i.gen.doc_ir;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            if first_comma_seen {
                indent_parts.pop();
                indent_parts.append(i.gen.doc_ir);
                indent_parts.append(self.hard_line());
            } else {
                parts.pop();
                parts.append(i.gen.doc_ir);
                first_comma_seen = True;
            }
        } elif isinstance(i, uni.HasVar) {
            if first_comma_seen {
                indent_parts.append(i.gen.doc_ir);
                indent_parts.append(self.space());
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    if indent_parts {
        self.trim_trailing_line(indent_parts);
        parts.append(
            self.indent(self.concat([self.hard_line(), *indent_parts]), ast_node=here)
        );
    }
    if semi_doc {
        parts.append(semi_doc);
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_has_var with uni.HasVar exit {
    parts: list[doc.DocType] = [];
    acc_docs: list[doc.DocType] = [];
    lbrace_doc: (doc.DocType | None) = None;
    in_acc = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.KW_POST_INIT)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            lbrace_doc = i.gen.doc_ir;
            in_acc = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_acc = False;
            inner: list[doc.DocType] = [];
            for ad in acc_docs {
                inner.append(self.line());
                inner.append(ad);
            }
            open_doc: doc.DocType = lbrace_doc or self.concat([]);
            block = self.concat(
                [
                    open_doc,
                    self.indent(self.concat(inner), ast_node=here),
                    self.line(),
                    i.gen.doc_ir
                ]
            );
            parts.append(self.space());
            parts.append(self.group(block, ast_node=here));
        } elif in_acc {
            acc_docs.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_param_var with uni.ParamVar exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.KW_COMPTIME)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_func_signature with uni.FuncSignature exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    in_params = False;
    has_parens = False;

    has_any_params = (
        here.params
        or here.varargs
        or here.kwargs
        or here.kwonlyargs
        or here.posonly_params
    );
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LPAREN) and has_any_params) {
            in_params = True;
            parts.append(i.gen.doc_ir);
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.RPAREN) and has_any_params
        ) {
            in_params = False;
            has_parens = True;
            if isinstance(indent_parts[-1], doc.Line) {
                indent_parts.pop();
            }
            parts.append(
                self.indent(
                    self.concat(
                        [self.tight_line(), self.group(self.concat([*indent_parts]))]
                    )
                )
            );
            parts.append(self.tight_line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
            has_parens = True;
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif in_params {
            if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
                indent_parts.append(i.gen.doc_ir);
                indent_parts.append(self.line());
            } else {
                indent_parts.append(i.gen.doc_ir);
            }
        } else {
            if (
                isinstance(i, uni.Token)
                and (i.name == Tok.RETURN_HINT)
                and not has_parens
                and not parts
            ) {
                parts.append(self.space());
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here));
}

impl DocIRGenPass.exit_ability with uni.Ability exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if ((i == here.doc) or (here.decorators and (i in here.decorators))) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (i == here.name_ref) {
            parts.append(i.gen.doc_ir);
            if not isinstance(here.signature, uni.FuncSignature) {
                parts.append(self.space());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
            in_body = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if (len(body_parts) > 0) {
                parts.append(self.hard_line());
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif in_body {
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } elif (
            not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)
        ) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            if (here.accessor_kind == "") {
                parts.append(self.space());
            }
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LSQUARE)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RSQUARE)) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.TypeParam) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_archetype with uni.Archetype exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    prev_item: (uni.UniNode | None) = None;
    in_body = False;
    for i in here.kid {
        if (
            (here.doc and (i is here.doc))
            or (here.decorators and (i in here.decorators))
        ) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (i == here.name) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LPAREN)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RPAREN)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(here.body, Sequence) and (i in here.body)) {
            if not in_body {
                body_parts.append(self.hard_line());
            }
            if (
                (
                    (prev_item and (type(prev_item) is not type(i)))
                    or (prev_item and not self.is_one_line(prev_item))
                )
                and not (
                    prev_item
                    and (self.effective_first_line(i) <= (prev_item.loc.last_line + 1))
                    and (self.effective_first_line(i) < i.loc.first_line)
                )
            ) {
                body_parts.append(self.hard_line());
            }
            body_parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
            prev_item = i;
            in_body = True;
        } elif in_body {
            in_body = False;
            body_parts.pop();
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            parts.append(self.hard_line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (
            not in_body and isinstance(i, uni.Token) and (i.name == Tok.DECOR_OP)
        ) {
            parts.append(i.gen.doc_ir);
        } elif isinstance(i, uni.SubTag) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_type_param with uni.TypeParam exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.KW_COMPTIME)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_type_alias with uni.TypeAlias exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.LSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RSQUARE)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.EQ)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_module_path with uni.ModulePath exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_AS)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_module_item with uni.ModuleItem exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.KW_AS)) {
            parts.append(self.space());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_import with uni.Import exit {
    parts: list[doc.DocType] = [];
    mod_items: list[doc.DocType] = [];
    is_in_items: bool = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            if is_in_items {
                mod_items.pop();
                mod_items.append(i.gen.doc_ir);
                mod_items.append(self.line());
            } else {
                parts.pop();
                parts.append(i.gen.doc_ir);
                parts.append(self.line());
            }
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            is_in_items = False;
            mod_items.pop();
            parts.append(
                self.group(
                    self.concat(
                        [
                            self.indent(self.concat([self.line(), *mod_items])),
                            self.line()
                        ]
                    )
                )
            );
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            is_in_items = True;
            parts.append(i.gen.doc_ir);
        } elif is_in_items {
            mod_items.append(i.gen.doc_ir);
            mod_items.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_module with uni.Module exit {
    parts: list[doc.DocType] = [];
    prev_kid: (uni.UniNode | None) = None;
    first_kid = True;
    for i in here.kid {
        if (
            (isinstance(i, uni.Import) and isinstance(prev_kid, uni.Import))
            or (
                (isinstance(i, uni.GlobalVars) and isinstance(prev_kid, uni.GlobalVars))
                or (prev_kid == here.doc)
            )
        ) {
            if (prev_kid and self.has_gap(prev_kid, i)) {
                parts.append(self.hard_line());
            }
            self._rescue_lost_comments(here, parts, i);
            parts.append(i.gen.doc_ir);
        } else {
            if (
                not first_kid
                and not (
                    prev_kid
                    and self.is_one_line(prev_kid)
                    and not self.has_gap(prev_kid, i)
                )
            ) {
                parts.append(self.hard_line());

                if prev_kid and here.source {
                    src_lines = here.source.code.split('\n');

                    start = prev_kid.loc.last_line;
                    end = self.effective_first_line(i) - 1;
                    consecutive_blanks = 0;
                    for line_idx in range(start, min(end, len(src_lines))) {
                        if not src_lines[line_idx].strip() {
                            consecutive_blanks += 1;
                            if consecutive_blanks >= 2 {
                                parts.append(self.hard_line());
                                break;
                            }
                        } else {
                            consecutive_blanks = 0;
                        }
                    }
                }
            }
            self._rescue_lost_comments(here, parts, i);
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.hard_line());
        prev_kid = i;
        first_kid = False;
    }
    self._rescue_lost_comments(here, parts, None);
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}
