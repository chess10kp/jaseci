impl DocIRGenPass.exit_jsx_expression with uni.JsxExpression exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_slot with uni.JsxSlot exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_text with uni.JsxText exit {
    first_kid = here.kid[0] if here.kid else None;
    source_tok = first_kid if isinstance(first_kid, uni.Token) else None;
    here.gen.doc_ir = doc.Text(here.get_normalized_text(), source_token=source_tok);
}

impl DocIRGenPass.exit_jsx_comment with uni.JsxComment exit {
    first_kid = here.kid[0] if here.kid else None;
    source_tok = first_kid if isinstance(first_kid, uni.Token) else None;
    raw = here.value.value if isinstance(here.value, uni.Token) else str(here.value);
    here.gen.doc_ir = doc.Text(raw, source_token=source_tok);
}

impl DocIRGenPass.jsx_whitespace -> doc.DocType {
    return self.if_break(
        self.concat([self.text('{" "}'), self.tight_line()]), self.space()
    );
}

impl DocIRGenPass.jsx_mixed_child_parts(
    children: Sequence[uni.UniNode]
) -> list[doc.DocType] {
    parts: list[doc.DocType] = [];

    pending = "";
    have_content = False;
    for child in children {
        content: (doc.DocType | None) = None;
        trail = "";
        if isinstance(child, uni.JsxText) {
            norm = child.get_normalized_text();
            if norm == "" {
                if pending != "space" {
                    pending = "break";
                }
                continue;
            } elif norm.strip(" ") == "" {
                pending = "space";
                continue;
            }
            if norm.startswith(" ") {
                pending = "space";
            }
            trail = "space" if norm.endswith(" ") else "";
            content = self.text(norm.strip(" "));
        } else {
            if isinstance(child, uni.JsxExpression) {
                expr = child.expr;
                is_ws = False;
                if isinstance(expr, uni.String) {
                    is_ws = expr.lit_value == " ";
                } elif isinstance(expr, uni.MultiString) {
                    is_ws = expr.lit_value == " ";
                }
                if is_ws {
                    pending = "space";
                    continue;
                }
            }
            content = child.gen.doc_ir;
        }
        if have_content {
            parts.append(
                self.jsx_whitespace() if pending == "space" else self.hard_line()
            );
        }
        parts.append(content);
        have_content = True;
        pending = trail;
    }
    return parts;
}

impl DocIRGenPass.exit_jsx_normal_attribute with uni.JsxNormalAttribute exit {
    parts: list[doc.DocType] = [];
    for child in here.kid {
        parts.append(child.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_spread_attribute with uni.JsxSpreadAttribute exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_element_name with uni.JsxElementName exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        parts.append(i.gen.doc_ir);
    }
    here.gen.doc_ir = self.concat(parts, ast_node=here);
}

impl DocIRGenPass.exit_jsx_element with uni.JsxElement exit {
    has_tokens = any(isinstance(kid, uni.Token) for kid in here.kid);
    if has_tokens {
        first_child = here.kid[0] if here.kid else None;
        if (
            isinstance(first_child, uni.Token)
            and (first_child.name == Tok.JSX_CLOSE_START)
        ) {
            here.gen.doc_ir = self.group(
                self.concat([kid.gen.doc_ir for kid in here.kid])
            );
            return;
        }
        start_token = here.kid[0]
            if (here.kid and isinstance(here.kid[0], uni.Token))
            else None;
        end_token = here.kid[-1]
            if (here.kid and isinstance(here.kid[-1], uni.Token))
            else None;
        if (not start_token or not end_token) {
            here.gen.doc_ir = self.group(
                self.concat([kid.gen.doc_ir for kid in here.kid])
            );
            return;
        }
        name_kids = [
            kid
            for kid in here.kid
            if isinstance(kid, uni.JsxElementName)
        ];
        name_node = name_kids[0] if name_kids else None;
        attr_docs = [attr.gen.doc_ir for attr in here.attributes];
        parts: list[doc.DocType] = [start_token.gen.doc_ir];
        if name_node {
            parts.append(name_node.gen.doc_ir);
        } elif not here.is_fragment {
            for k in here.kid[1:] {
                if (
                    isinstance(k, uni.JsxNormalAttribute)
                    or isinstance(k, uni.JsxSpreadAttribute)
                    or (
                        isinstance(k, uni.Token)
                        and k.name in (Tok.JSX_TAG_END, Tok.JSX_SELF_CLOSE)
                    )
                ) {
                    break;
                }
                parts.append(k.gen.doc_ir);
            }
        }

        if attr_docs {
            attr_content: list[doc.DocType] = [self.line()];
            attr_content.extend(self.intersperse(attr_docs, self.line()));
            attr_group = self.group(
                self.concat(
                    [
                        self.indent(self.concat(attr_content), ast_node=here),
                        self.if_break(self.line(), self.concat([]))
                    ]
                ),
                ast_node=here
            );
            parts.append(attr_group);
        }
        is_self_closing = end_token.name == Tok.JSX_SELF_CLOSE;
        open_end_tok: (uni.Token | None) = None;
        close_start_idx = -1;
        for (_ki, _kn) in enumerate(here.kid) {
            if not isinstance(_kn, uni.Token) {
                continue;
            }
            if open_end_tok is None
                and _kn.name in (Tok.JSX_TAG_END, Tok.JSX_SELF_CLOSE) {
                open_end_tok = _kn;
            }
            if _kn.value == "</" {
                close_start_idx = _ki;
            }
        }
        if (not is_self_closing and close_start_idx > 0 and open_end_tok is not None) {
            parts.append(open_end_tok.gen.doc_ir);
        }
        if (not is_self_closing and here.children) {
            child_parts = self.jsx_mixed_child_parts(here.children);
            inline_child_types = (uni.JsxText, uni.JsxExpression, uni.JsxComment);
            all_inline_children = bool(here.children)
                and all(
                    isinstance(child, inline_child_types) for child in here.children
                );

            if all_inline_children {
                inline_doc = self.concat([child.gen.doc_ir for child in here.children]);
                parts.append(
                    self.group(
                        self.concat(
                            [
                                self.indent(
                                    self.concat([self.tight_line(), inline_doc]),
                                    ast_node=here
                                ),
                                self.tight_line()
                            ]
                        ),
                        break_contiguous=True,
                        ast_node=here
                    )
                );
            } elif child_parts {
                has_jsx_ws = any(isinstance(p, doc.IfBreak) for p in child_parts);
                lead = self.tight_line() if has_jsx_ws else self.hard_line();
                tail = self.tight_line() if has_jsx_ws else self.hard_line();
                parts.append(
                    self.group(
                        self.concat(
                            [
                                self.indent(
                                    self.concat([lead, *child_parts]), ast_node=here
                                ),
                                tail
                            ]
                        ),
                        break_contiguous=True,
                        ast_node=here
                    )
                );
            }
        }
        if is_self_closing {
            parts.append(self.if_break(self.concat([]), self.space()));
            parts.append(end_token.gen.doc_ir);
        } elif close_start_idx > 0 {
            for _ck in here.kid[close_start_idx:] {
                parts.append(_ck.gen.doc_ir);
            }
        } else {
            parts.append(end_token.gen.doc_ir);
        }
        here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
        return;
    }
    if not here.kid {
        here.gen.doc_ir = self.group(self.concat([]));
        return;
    }
    opening_doc = here.kid[0].gen.doc_ir;
    closing_doc = here.kid[-1].gen.doc_ir if (len(here.kid) > 1) else self.concat([]);
    children: Sequence[uni.UniNode] = here.children or [];
    child_parts = self.jsx_mixed_child_parts(children);
    inline_child_types = (uni.JsxText, uni.JsxExpression);
    all_inline_children = bool(children)
        and all(isinstance(child, inline_child_types) for child in children);
    parts = [opening_doc];

    if all_inline_children {
        inline_doc = self.concat([child.gen.doc_ir for child in children]);
        parts.append(
            self.group(
                self.concat(
                    [
                        self.indent(
                            self.concat([self.tight_line(), inline_doc]), ast_node=here
                        ),
                        self.tight_line()
                    ]
                ),
                break_contiguous=True,
                ast_node=here
            )
        );
    } elif child_parts {
        has_jsx_ws = any(isinstance(p, doc.IfBreak) for p in child_parts);
        lead = self.tight_line() if has_jsx_ws else self.hard_line();
        tail = self.tight_line() if has_jsx_ws else self.hard_line();
        parts.append(
            self.group(
                self.concat(
                    [
                        self.indent(self.concat([lead, *child_parts]), ast_node=here),
                        tail
                    ]
                ),
                break_contiguous=True,
                ast_node=here
            )
        );
    }
    parts.append(closing_doc);
    here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
}
