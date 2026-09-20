impl JacLangServer.get_completion_items_of(
    ty: TypeBase | uni.UniScopeNode
) -> lspt.CompletionList {
    return lspt.CompletionList(is_incomplete=False, items=get_completion_items(ty));
}

impl JacLangServer.get_scope_completion(
    scope: uni.UniScopeNode
) -> lspt.CompletionList {
    result = self.get_completion_items_of(scope);
    seen = {item.label for item in result.items};
    for (tok_name, text) in TOKEN_MAP.items() {
        if not text or not (text[0].isalpha() or text[0] == "_") {
            continue;
        }
        if not all(c.isalnum() or c == "_" for c in text) {
            continue;
        }
        if not (tok_name.startswith("KW_") or tok_name in ("NULL", "NOT", "BOOL")) {
            continue;
        }
        if text in seen {
            continue;
        }
        result.items.append(
            lspt.CompletionItem(label=text, kind=lspt.CompletionItemKind.Keyword)
        );
        seen.add(text);
    }
    return result;
}

impl JacLangServer.get_scope_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.UniScopeNode] {
    ast = self.get_ast_of_file(file_path);
    if not isinstance(ast, uni.UniScopeNode) {
        return None;
    }
    best: uni.UniScopeNode = ast;
    stack = list(ast.kid_scope);
    while stack {
        scope = stack.pop();
        if utils.position_within_node(scope, line + 1, col + 1) {
            best = scope;
            stack.extend(scope.kid_scope);
        }
    }
    return best;
}

impl JacLangServer.get_node_type(n: uni.UniNode) -> Optional[TypeBase] {
    if isinstance(n, uni.Expr) {
        typ = n.type;
        if typ is None {
            typ = self.program.get_type_evaluator().get_type_of_expression(n);
        }
        self.debug("found type " + str(typ) + " for expr " + str(n));
        return typ;
    }
    self.debug("no type found for node " + str(n));
    return None;
}

impl JacLangServer.get_completion_of_node(nd: uni.UniNode) -> lspt.CompletionList {
    if (node_type := self.get_node_type(nd)) {
        self.debug("found type " + str(node_type));
        return self.get_completion_items_of(node_type);
    } elif isinstance(nd, UniScopeNode) {
        self.debug("found scope node " + str(nd));
        return self.get_scope_completion(nd);
    }
    self.debug("no type found for node " + str(nd));
    return lspt.CompletionList(is_incomplete=False, items=[]);
}

impl JacLangServer.get_node_at_position(
    file_path: str, line: int, col: int
) -> Optional[uni.UniNode] {
    if col < 0 {
        return None;
    }
    if (ast := self.get_ast_of_file(file_path)) {
        for ast_node in ast._in_mod_nodes {
            if not isinstance(ast_node, uni.Token) {
                continue;
            }
            if (utils.position_within_node(ast_node, line + 1, col + 1)) {
                return ast_node;
            }
        }
    }
    return None;
}

impl JacLangServer._flush_completion_state(file_uri: str) -> None {
    needs_refresh = False;
    with self._state_lock.read_lock() {
        needs_refresh = bool(self._debounce_timer or self.pipe or self.dirty_files);
    }
    if needs_refresh {
        self.wait_till_idle_sync(file_uri);
    }
}

impl JacLangServer._position_in_string_or_comment(
    file_uri: str, line: int, col: int
) -> bool {
    ln = line + 1;
    co = col + 1;
    try {
        text_doc = self.workspace.get_text_document(file_uri);
        result = tokenize_full(text_doc.source, _path_of(file_uri));
        tokens = result[0];
        comments = result[1];
        for t in tokens {
            k = t.kind;
            if not (
                k == TokenKind.STRING
                or k == TokenKind.F_TEXT_DQ
                or k == TokenKind.F_TEXT_SQ
                or k == TokenKind.F_TEXT_TDQ
                or k == TokenKind.F_TEXT_TSQ
            ) {
                continue;
            }
            loc = t.loc;
            if loc.line < ln < loc.end_line {
                return True;
            }
            if ln < loc.line or ln > loc.end_line {
                continue;
            }
            if ln == loc.line and co < loc.col_start {
                continue;
            }
            if ln == loc.end_line and co >= loc.col_end {
                continue;
            }
            return True;
        }
        for c in comments {
            if c.line < ln < c.end_line {
                return True;
            }
            if ln < c.line or ln > c.end_line {
                continue;
            }
            if ln == c.line and co < c.col_start {
                continue;
            }
            if ln == c.end_line and co >= c.col_end {
                continue;
            }
            return True;
        }
        return False;
    } except Exception {
        return False;
    }
}

impl JacLangServer.get_completion(
    file_uri: str, position: lspt.Position, completion_trigger: Optional[str]
) -> lspt.CompletionList {
    self.debug("Getting completion for " + file_uri + " at " + str(position));
    try {
        self._flush_completion_state(file_uri);
        if self._position_in_string_or_comment(
            file_uri, position.line, position.character
        ) {
            self.debug("completion suppressed (cursor in string or comment)");
            return lspt.CompletionList(is_incomplete=False, items=[]);
        }
        file_path = _path_of(file_uri);
        look_col = position.character - 1 if position.character > 0 else 0;
        node_at_pos = self.get_node_at_position(file_path, position.line, look_col);

        if not node_at_pos {
            node_at_pos = self.get_node_at_position(
                file_path, position.line, position.character
            );
        }

        if node_at_pos {
            self.debug(
                "found the node at pos " + str(position) + " " + str(node_at_pos)
            );
        }

        if isinstance(node_at_pos, uni.Token) {
            if node_at_pos.name == "DOT" {
                member_access = node_at_pos.parent;
                self.debug("found dot " + str(member_access));
                if isinstance(member_access, uni.AtomTrailer) {
                    self.debug("before returning the list");
                    return self.get_completion_of_node(member_access.target);
                }
            } elif isinstance(node_at_pos, uni.Name) {
                parent = node_at_pos.parent;
                if (
                    isinstance(parent, uni.AtomTrailer)
                    and parent.is_attr
                    and node_at_pos is parent.right
                ) {
                    self.debug("found attribute name in atom trailer " + str(parent));
                    return self.get_completion_of_node(parent.target);
                }
                if scope_node := node_at_pos.find_parent_of_type(uni.UniScopeNode) {
                    self.debug("found name in scope node " + str(scope_node));
                    return self.get_scope_completion(scope_node);
                }
            }
        }

        if scope_node
            := self.get_scope_at_position(
                file_path, position.line, position.character
            ) {
            self.debug("fallback scope completion " + str(scope_node));
            return self.get_scope_completion(scope_node);
        }
        return lspt.CompletionList(is_incomplete=False, items=[]);
    } except Exception as e {
        self.log_py(f"Error during completion: {e}");
        return lspt.CompletionList(is_incomplete=False, items=[]);
    }
}
