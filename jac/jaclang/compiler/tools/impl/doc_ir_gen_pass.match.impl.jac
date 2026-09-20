impl DocIRGenPass.exit_match_arch with uni.MatchArch exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COMMA)) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
        }
    }
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_k_v_pair with uni.MatchKVPair exit {
    parts: list[doc.DocType] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name in [Tok.STAR_POW, Tok.STAR_MUL])) {
            parts.append(i.gen.doc_ir);
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.pop();
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_star with uni.MatchStar exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_wild with uni.MatchWild exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_as with uni.MatchAs exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_or with uni.MatchOr exit {
    operands: list[uni.UniNode] = [];
    ops: list[uni.UniNode] = [];
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.BW_OR)) {
            ops.append(i);
        } else {
            operands.append(i);
        }
    }
    if len(operands) != (len(ops) + 1) {
        self._assign_space_group(here);
        return;
    }
    self._assign_operator_chain(here, operands, ops);
}

impl DocIRGenPass.exit_match_mapping with uni.MatchMapping exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_sequence with uni.MatchSequence exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_singleton with uni.MatchSingleton exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_match_value with uni.MatchValue exit {
    self._assign_space_group(here);
}

impl DocIRGenPass.exit_switch_case with uni.SwitchCase exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (i in here.body) {
            self.add_body_stmt_with_spacing(indent_parts, i, prev_body_item);
            prev_body_item = i;
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.append(
        self.indent(self.concat(([self.hard_line()] + indent_parts)), ast_node=here)
    );
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass._assign_case_block_doc_ir(
    nd: (uni.SwitchStmt | uni.MatchStmt)
) -> None {
    parts: list[doc.DocType] = [];
    case_parts: list[doc.DocType] = [self.hard_line()];
    for i in nd.kid {
        if (i == nd.target) {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } elif isinstance(i, (uni.SwitchCase, uni.MatchCase)) {
            case_parts.append(i.gen.doc_ir);
            case_parts.append(self.hard_line());
        } elif (isinstance(i, uni.Token) and (i.name == Tok.RBRACE)) {
            if (case_parts and isinstance(case_parts[-1], doc.Line)) {
                case_parts.pop();
            }
            parts.append(
                self.indent(self.concat(case_parts, ast_node=nd), ast_node=nd)
            );
            parts.append(self.hard_line());
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    nd.gen.doc_ir = self.group(self.concat(parts, ast_node=nd), ast_node=nd);
}

impl DocIRGenPass.exit_switch_stmt with uni.SwitchStmt exit {
    self._assign_case_block_doc_ir(here);
}

impl DocIRGenPass.exit_match_case with uni.MatchCase exit {
    parts: list[doc.DocType] = [];
    indent_parts: list[doc.DocType] = [];
    prev_body_item: (uni.UniNode | None) = None;
    for i in here.kid {
        if (isinstance(i, uni.Token) and (i.name == Tok.COLON)) {
            parts.pop();
            parts.append(i.gen.doc_ir);
        } elif (i in here.body) {
            self.add_body_stmt_with_spacing(indent_parts, i, prev_body_item);
            prev_body_item = i;
        } else {
            parts.append(i.gen.doc_ir);
            parts.append(self.space());
        }
    }
    parts.append(
        self.indent(self.concat(([self.hard_line()] + indent_parts)), ast_node=here)
    );
    here.gen.doc_ir = self.group(self.concat(parts, ast_node=here), ast_node=here);
}

impl DocIRGenPass.exit_match_stmt with uni.MatchStmt exit {
    self._assign_case_block_doc_ir(here);
}
