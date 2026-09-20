impl Lexer.scan_jsx_open_start -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    self.advance();
    self.jsx_depth += 1;
    self.push_mode(LexerMode.JSX_TAG);
    return self.make_token(
        TokenKind.JSX_OPEN_START, "<", start_line, start_col, start_pos
    );
}

impl Lexer.scan_jsx_tag_token -> LexToken {
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if ch == "/" and self.peek() == ">" {
        self.advance();
        self.advance();
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_SELF_CLOSE, "/>", start_line, start_col, start_pos
        );
    }

    if ch == ">" {
        self.advance();
        self.pop_mode();
        if self.jsx_closing_tag {
            self.jsx_closing_tag = False;
            self.jsx_depth -= 1;
        } else {
            self.push_mode(LexerMode.JSX_CONTENT);
        }
        return self.make_token(
            TokenKind.JSX_TAG_END, ">", start_line, start_col, start_pos
        );
    }

    if ch == "{" {
        self.advance();
        self.jsx_brace_depth_stack.append(self.jsx_brace_depth);
        self.jsx_brace_depth = 1;
        self.push_mode(LexerMode.NORMAL);
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }

    if self.is_alpha(ch) {
        value = "";
        while self.is_alnum(self.current())
            or self.current() == "-"
            or self.current() == "_" {
            value += self.advance();
        }
        return self.make_token(
            TokenKind.JSX_NAME, value, start_line, start_col, start_pos
        );
    }

    if ch == "=" {
        self.advance();
        return self.make_token(TokenKind.EQ, "=", start_line, start_col, start_pos);
    }

    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }

    if ch == "." {
        self.advance();
        return self.make_token(TokenKind.DOT, ".", start_line, start_col, start_pos);
    }

    if ch == "@" {
        self.advance();
        return self.make_token(
            TokenKind.DECOR_OP, "@", start_line, start_col, start_pos
        );
    }

    self.error(
        f"Unexpected character in JSX tag: '{ch}'",
        start_line,
        start_col,
        start_pos,
        code_str="E0106"
    );
    self.advance();
    return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
}

impl Lexer.scan_jsx_content -> LexToken {
    if self.at_end() {
        self.error(
            "Unexpected end of JSX content",
            self.line,
            self.col,
            self.pos,
            code_str="E0104"
        );
        return self.make_token(TokenKind.ERROR, "", self.line, self.col, self.pos);
    }
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if ch == "<" and self.peek() == "/" and self.peek(2) == ">" {
        self.advance();
        self.advance();
        self.advance();
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_FRAG_CLOSE, "</>", start_line, start_col, start_pos
        );
    }

    if ch == "<" and self.peek() == "/" {
        self.advance();
        self.advance();
        self.pop_mode();
        self.push_mode(LexerMode.JSX_TAG);
        self.jsx_closing_tag = True;
        return self.make_token(
            TokenKind.JSX_CLOSE_START, "</", start_line, start_col, start_pos
        );
    }

    if ch == "<" and (self.is_alpha(self.peek()) or self.peek() == "@") {
        self.advance();
        self.jsx_depth += 1;

        self.push_mode(LexerMode.JSX_TAG);
        return self.make_token(
            TokenKind.JSX_OPEN_START, "<", start_line, start_col, start_pos
        );
    }

    if ch == "<" and self.peek() == ">" {
        self.advance();
        self.advance();
        self.jsx_depth += 1;
        self.push_mode(LexerMode.JSX_CONTENT);
        return self.make_token(
            TokenKind.JSX_FRAG_OPEN, "<>", start_line, start_col, start_pos
        );
    }

    if ch == "{" {
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;
        saved_comments_len = len(self.comments);
        self.advance();
        self.skip_whitespace();
        is_comment_slot = False;
        if (not self.at_end() and self.current() == "#" and self.peek() == "*") {
            if self.skip_block_comment() {
                self.skip_whitespace();
                if not self.at_end() and self.current() == "}" {
                    self.advance();
                    is_comment_slot = True;
                }
            }
        }
        if is_comment_slot {
            self.comments = self.comments[:saved_comments_len];
            value = self._slice(start_pos, self.pos);
            return self.make_token(
                TokenKind.JSX_COMMENT, value, start_line, start_col, start_pos
            );
        }

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
        self.comments = self.comments[:saved_comments_len];
        self.advance();
        self.jsx_brace_depth_stack.append(self.jsx_brace_depth);
        self.jsx_brace_depth = 1;
        self.push_mode(LexerMode.NORMAL);

        self._view_body_depths.append(self._brace_depth + 1);
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }

    value = "";
    while not self.at_end() {
        ch = self.current();
        if ch == "{" {
            break;
        }
        if ch == "<" {
            nxt = self.peek();

            if nxt == "/" or nxt == ">" or nxt == "@" or self.is_alpha(nxt) {
                break;
            }
        }

        value += self.advance();
    }
    if len(value) > 0 {
        return self.make_token(
            TokenKind.JSX_TEXT, value, start_line, start_col, start_pos
        );
    }

    self.error(
        "Unexpected end of JSX content",
        start_line,
        start_col,
        start_pos,
        code_str="E0104"
    );
    return self.make_token(TokenKind.ERROR, "", start_line, start_col, start_pos);
}
