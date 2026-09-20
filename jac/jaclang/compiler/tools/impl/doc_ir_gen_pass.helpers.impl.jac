impl DocIRGenPass.format_comma_collection(nd: uni.UniNode) -> doc.DocType {
    flat_parts: list[doc.DocType] = [];
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            flat_parts.append(i.gen.doc_ir);
            flat_parts.append(self.space());
        } else {
            flat_parts.append(i.gen.doc_ir);
        }
    }
    not_broke = self.concat(flat_parts, ast_node=nd);
    broken_parts: list[doc.DocType] = [];
    for i in nd.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            broken_parts.append(i.gen.doc_ir);
            broken_parts.append(self.hard_line());
        } else {
            broken_parts.append(i.gen.doc_ir);
        }
    }
    if (len(broken_parts) >= 3) {
        broke = self.concat(
            [
                broken_parts[0],
                self.indent(
                    self.concat([self.hard_line(), *broken_parts[1:-1]], ast_node=nd),
                    ast_node=nd
                ),
                self.hard_line(),
                broken_parts[-1]
            ],
            ast_node=nd
        );
    } else {
        broke = self.concat(broken_parts, ast_node=nd);
    }
    return self.group(self.if_break(broke, not_broke), ast_node=nd);
}

impl DocIRGenPass._rescue_lost_comments(
    nd: uni.Module, parts: list[doc.DocType], next_kid: (uni.UniNode | None)
) -> None {
    if not (isinstance(nd, uni.Module) and nd.source and nd.source.comments) {
        return;
    }
    if self._emitted_comment_ids is None {
        self._emitted_comment_ids = set();
    }
    mod_dc = nd.gen.doc_comments;
    own_ids: set[int] = set();
    if mod_dc is not None {
        for c in (mod_dc.leading + mod_dc.trailing_inline + mod_dc.trailing_own) {
            own_ids.add(id(c));
        }
    }
    limit = self.effective_first_line(next_kid) if (next_kid is not None) else None;
    prev_line: (int | None) = None;
    for c in nd.source.comments {
        if ((id(c) in self._emitted_comment_ids) or (id(c) in own_ids)) {
            continue;
        }
        if not self._comment_is_live(c) {
            continue;
        }
        if (limit is not None and (c.loc.first_line >= limit)) {
            continue;
        }
        if (prev_line is not None and ((prev_line + 1) < c.loc.first_line)) {
            parts.append(self.hard_line());
        }
        parts.append(self.text(c.value, source_token=c));
        parts.append(self.hard_line());
        self._emitted_comment_ids.add(id(c));
        prev_line = c.loc.last_line;
    }
}

impl DocIRGenPass.remove_all_spaces(doc_node: doc.DocType) -> doc.DocType {
    if isinstance(doc_node, doc.Text) {
        if (doc_node.text == ' ') {
            return self.concat([]);
        }
        return doc_node;
    } elif isinstance(doc_node, doc.Line) {
        if not (doc_node.hard or doc_node.literal) {
            return self.concat([]);
        }
        return doc_node;
    } elif isinstance(doc_node, doc.Concat) {
        new_parts = [];
        for part in doc_node.parts {
            processed = self.remove_all_spaces(part);
            if not (isinstance(processed, doc.Concat) and not processed.parts) {
                new_parts.append(processed);
            }
        }
        return doc.Concat(new_parts, ast_node=doc_node.ast_node);
    } elif isinstance(doc_node, doc.Group) {
        return doc.Group(
            self.remove_all_spaces(doc_node.contents),
            doc_node.break_contiguous,
            ast_node=doc_node.ast_node
        );
    } elif isinstance(doc_node, doc.Indent) {
        return doc.Indent(
            self.remove_all_spaces(doc_node.contents), ast_node=doc_node.ast_node
        );
    } elif isinstance(doc_node, doc.IfBreak) {
        return doc.IfBreak(
            self.remove_all_spaces(doc_node.break_contents),
            self.remove_all_spaces(doc_node.flat_contents)
        );
    } else {
        return doc_node;
    }
}

impl DocIRGenPass.tight_line -> doc.Line {
    return doc.Line(tight=True);
}

impl DocIRGenPass.hard_line -> doc.Line {
    return doc.Line(hard=True);
}

impl DocIRGenPass.line(hard: bool = False, literal: bool = False) -> doc.Line {
    return doc.Line(hard, literal);
}

impl DocIRGenPass.space -> doc.Text {
    return doc.Text(' ');
}

impl DocIRGenPass.text(text: str, source_token: (uni.Token | None) = None) -> doc.Text {
    return doc.Text(text, source_token=source_token);
}

impl DocIRGenPass.line_suffix(contents: doc.DocType) -> doc.LineSuffix {
    return doc.LineSuffix(contents);
}

impl DocIRGenPass.break_parent -> doc.BreakParent {
    return doc.BreakParent();
}

impl DocIRGenPass.doc_ir_default_exit with uni.UniNode exit {
    if (here.gen._doc_ir is None) and here.kid {
        self._assign_space_group(here);
    }
}

impl DocIRGenPass.finish_doc_comments with uni.UniNode exit {
    if here.gen.doc_comments is not None {
        self._wrap_doc_comments(here);
    }
}

impl DocIRGenPass._comment_is_live(c: uni.CommentToken) -> bool {
    if self._live_comment_ids is None {
        src = self.module.source if isinstance(self.module, uni.Module) else None;
        self._live_comment_ids = {id(lc) for lc in (src.comments if src else [])};
    }
    return id(c) in self._live_comment_ids;
}

impl DocIRGenPass.effective_first_line(nd: uni.UniNode) -> int {
    dc = nd.gen.doc_comments;
    if (dc is not None and dc.leading) {
        for c in dc.leading {
            if self._comment_is_live(c) {
                return c.loc.first_line;
            }
        }
    }
    return nd.loc.first_line;
}

impl DocIRGenPass._wrap_doc_comments(nd: uni.UniNode) -> None {
    dc = nd.gen.doc_comments;
    if dc is None {
        return;
    }
    base = nd.gen.doc_ir;
    leading = [
        c
        for c in dc.leading
        if self._comment_is_live(c)
    ];
    trailing_inline = [
        c
        for c in dc.trailing_inline
        if self._comment_is_live(c)
    ];
    trailing_own = [
        c
        for c in dc.trailing_own
        if self._comment_is_live(c)
    ];
    if self._emitted_comment_ids is None {
        self._emitted_comment_ids = set();
    }
    for c in (leading + trailing_inline + trailing_own) {
        self._emitted_comment_ids.add(id(c));
    }
    if leading {
        pre: list[doc.DocType] = [doc.Line(hard=True, fresh=True)];
        prev_last: (int | None) = None;
        for c in leading {
            if (prev_last is not None and ((prev_last + 1) < c.loc.first_line)) {
                pre.append(self.hard_line());
            }
            pre.append(self.text(c.value, source_token=c));
            pre.append(self.hard_line());
            prev_last = c.loc.last_line;
        }
        if (prev_last is not None and ((prev_last + 1) < nd.loc.first_line)) {
            pre.append(self.hard_line());
        }
        pre.append(base);
        base = self.concat(pre);
    }
    if trailing_inline {
        inline_parts: list[doc.DocType] = [base];
        for c in trailing_inline {
            inline_parts.append(
                self.line_suffix(
                    self.concat([self.text('  '), self.text(c.value, source_token=c)])
                )
            );
        }
        inline_parts.append(self.break_parent());
        base = self.concat(inline_parts);
    }
    if trailing_own {
        post: list[doc.DocType] = [];
        own_prev = nd.loc.last_line;
        for c in trailing_own {
            post.append(self.hard_line());
            if ((own_prev + 1) < c.loc.first_line) {
                post.append(self.hard_line());
            }
            post.append(self.text(c.value, source_token=c));
            own_prev = c.loc.last_line;
        }
        if dc.indent_trailing_own {
            base = self.concat(
                [base, self.indent(self.concat(post)), self.hard_line()]
            );
        } else {
            base = self.concat([base, *post]);
        }
    }
    nd.gen.doc_ir = base;
}
