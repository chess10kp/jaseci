impl DocIRGenPass.exit_test with uni.Test exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (i == here.doc) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (here.description is not None and i == here.description) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif ((i == here.name) and isinstance(i, uni.Name)) {
            if not i.value.startswith('_jac_gen_') {
                parts.append(i.gen.doc_ir);
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
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_py_inline_code with uni.PyInlineCode exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (i == here.doc) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.PYNLINE)) {
            parts.append(self.text('::py::'));
            parts.append(i.gen.doc_ir);
            parts.append(self.text('::py::'));
            parts.append(self.hard_line());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_visit_stmt with uni.VisitStmt exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
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

impl DocIRGenPass.exit_module_code with uni.ModuleCode exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [];
    in_body = False;
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (here.doc and (i is here.doc)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.hard_line());
        } elif (i == here.name) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
            parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
            in_body = True;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            in_body = False;
            self.trim_trailing_line(body_parts);
            parts.append(self.indent(self.concat(body_parts), ast_node=here));
            if len(body_parts) {
                parts.append(self.hard_line());
            }
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif in_body {
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_global_vars with uni.GlobalVars exit {
    prefix_parts: list[doc.DocType] = [];
    assignment_parts: list[doc.DocType] = [];
    semi_doc: (doc.DocType | None) = None;
    has_multiple_assignments = len(here.assignments) > 1;
    for i in here.kid {
        if (i == here.doc) {
            prefix_parts.append(i.gen.doc_ir);
            prefix_parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            if assignment_parts {
                assignment_parts.pop();
            }
            semi_doc = i.gen.doc_ir;
        } elif (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            assignment_parts.pop();
            assignment_parts.append(i.gen.doc_ir);
            if has_multiple_assignments {
                assignment_parts.append(self.hard_line());
            } else {
                assignment_parts.append(self.space());
            }
        } elif isinstance(i, uni.Assignment) {
            assignment_parts.append(i.gen.doc_ir);
            assignment_parts.append(self.space());
        } elif isinstance(i, uni.SubTag) {
            prefix_parts.pop();
            prefix_parts.append(i.gen.doc_ir);
            prefix_parts.append(self.space());
        } else {
            prefix_parts.append(i.gen.doc_ir);
            prefix_parts.append(self.space());
        }
    }
    self.trim_trailing_line(assignment_parts);

    aligned_assignments = self.align(self.concat(assignment_parts), n=5);
    prefix_parts.append(aligned_assignments);
    if semi_doc {
        prefix_parts.append(semi_doc);
    }
    here.gen.doc_ir = self.group(
        self.concat(prefix_parts, ast_node=here), ast_node=here
    );
}

impl DocIRGenPass.exit_raise_stmt with uni.RaiseStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_assert_stmt with uni.AssertStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_report_stmt with uni.ReportStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_disengage_stmt with uni.DisengageStmt exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_delete_stmt with uni.DeleteStmt exit {
    self._assign_semi_stmt_doc_ir(here);
}

impl DocIRGenPass.exit_ctrl_stmt with uni.CtrlStmt exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_with_stmt with uni.WithStmt exit {
    parts: list[doc.DocType] = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    for i in here.kid {
        if (isinstance(here.body, Sequence) and self.is_within(i, here.body)) {
            if (i == here.body[0]) {
                parts.append(self.indent(self.concat(body_parts), ast_node=here));
                parts.append(self.hard_line());
            }
            body_parts.append(i.gen.doc_ir);
            body_parts.append(self.hard_line());
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not here.body
        ) {
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
    parts.pop();
    body_parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts), ast_node=here);
}

impl DocIRGenPass.exit_finally_stmt with uni.FinallyStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_except with uni.Except exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_try_stmt with uni.TryStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_awaiting_clause with uni.AwaitingClause exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_iter_for_stmt with uni.IterForStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_in_for_stmt with uni.InForStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_while_stmt with uni.WhileStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_open_stmt with uni.OpenStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_forever_stmt with uni.ForeverStmt exit {
    here.gen.doc_ir = self.format_simple_stmt_with_body(here, here.body);
}

impl DocIRGenPass.exit_return_stmt with uni.ReturnStmt exit {
    parts: list[doc.DocType] = [];

    if here.is_implicit {
        for i in here.kid {
            parts.append(i.gen.doc_ir);
        }
        here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
        return;
    }

    is_jsx_return = isinstance(here.expr, uni.JsxElement);
    if is_jsx_return {
        for i in here.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
                parts.append(i.gen.doc_ir);
            } elif isinstance(i, uni.JsxElement) {
                parts.append(self.indent(self.concat([self.line(), i.gen.doc_ir])));
            } else {
                parts.append(i.gen.doc_ir);
            }
        }
        here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
        return;
    }
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
        }
        parts.append(self.space());
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_expr_stmt with uni.ExprStmt exit {
    self._assign_group_concat(here);
}

impl DocIRGenPass.exit_else_stmt with uni.ElseStmt exit {
    self._assign_else_doc_ir(here, here.body);
}

impl DocIRGenPass.exit_else_if with uni.ElseIf exit {
    self._assign_else_doc_ir(here, here.body);
}

impl DocIRGenPass.exit_if_stmt with uni.IfStmt exit {
    if here.__class__ is not uni.IfStmt {
        return;
    }
    flat_capable = (
        isinstance(here.parent, uni.LambdaExpr)
        and not (
            isinstance(here.parent.body, Sequence) and len(list(here.parent.body)) > 1
        )
        and (here.else_body is None)
        and (len(here.body) == 1)
        and not self.has_gap(here, here.body[0])
    );
    if flat_capable {
        parts: list[doc.DocType] = [];
        body_placed = False;
        for i in here.kid {
            if (isinstance(i, uni.Token) and (i.name == Tok.LBRACE)) {
                parts.append(i.gen.doc_ir);
            } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
                parts.append(self.line());
                parts.append(i.gen.doc_ir);
            } elif (isinstance(here.body, Sequence) and self.is_within(i, here.body)) {
                if not body_placed {
                    parts.append(
                        self.indent(
                            self.concat([self.line(), i.gen.doc_ir]), ast_node=here
                        )
                    );
                    body_placed = True;
                }
            } else {
                parts.append(i.gen.doc_ir);
                parts.append(self.space());
            }
        }
        here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
        return;
    }
    parts = [];
    body_parts: list[doc.DocType] = [self.hard_line()];
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(here.body, Sequence) and self.is_within(i, here.body)) {
            if (i == here.body[0]) {
                parts.append(self.indent(self.concat(body_parts), ast_node=here));
                parts.append(self.hard_line());
            }
            self.add_body_stmt_with_spacing(body_parts, i, prev_body_item);
            prev_body_item = i;
        } elif (
            isinstance(i, uni.Token) and (i.name == Tok.LBRACE) and not here.body
        ) {
            parts.append(i.gen.doc_ir);
        } elif (isinstance(i, uni.Token) and (i.name == Tok.SEMI)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.pop();
    body_parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_assignment with uni.Assignment exit {
    lhs_parts: list[doc.DocType] = [];
    rhs_parts: list[doc.DocType] = [];
    eq_tok: (doc.DocType | None) = None;
    seen_eq = False;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.EQ) and not seen_eq) {
            eq_tok = i.gen.doc_ir;
            seen_eq = True;
        } elif seen_eq {
            rhs_parts.append(i.gen.doc_ir);
        } else {
            if (i == here.aug_op) {
                lhs_parts.append(self.space());
            }
            lhs_parts.append(i.gen.doc_ir);
            if (i == here.aug_op)
                or (isinstance(i, uni.Token) and (i.name == Tok.KW_COMPTIME)) {
                lhs_parts.append(self.space());
            }
        }
    }
    if (eq_tok is not None) {
        rhs_concat = self.group(self.concat(rhs_parts));
        here.gen.doc_ir = self.group(
            self.concat(
                [
                    *lhs_parts,
                    self.space(),
                    eq_tok,
                    self.concat([self.space(), rhs_concat])
                ]
            )
        );
    } else {
        here.gen.doc_ir = self.group(self.concat((lhs_parts + rhs_parts)));
    }
}
