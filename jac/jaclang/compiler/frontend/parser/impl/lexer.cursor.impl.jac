impl Lexer.push_mode(mode: LexerMode) {
    self.mode_stack.append(mode);
}

impl Lexer.pop_mode -> LexerMode | None {
    if len(self.mode_stack) > 0 {
        return self.mode_stack.pop();
    }
    return None;
}

impl Lexer.current_mode -> LexerMode {
    if len(self.mode_stack) > 0 {
        return self.mode_stack[-1];
    }
    return LexerMode.NORMAL;
}

impl Lexer.in_jsx -> bool {
    mode = self.current_mode();
    return mode in [LexerMode.JSX_TAG, LexerMode.JSX_CONTENT];
}

impl Lexer.in_view_body -> bool {
    return len(self._view_body_depths) > 0;
}

impl Lexer._track_view_context(tok: LexToken) {
    k = tok.kind;
    if k == TokenKind.LPAREN {
        self._paren_depth += 1;
    } elif k == TokenKind.RPAREN {
        if self._paren_depth > 0 {
            self._paren_depth -= 1;
        }
    } elif k == TokenKind.LSQUARE {
        self._bracket_depth += 1;
    } elif k == TokenKind.RSQUARE {
        if self._bracket_depth > 0 {
            self._bracket_depth -= 1;
        }
    } elif k == TokenKind.LBRACE {
        self._brace_depth += 1;
    } elif k == TokenKind.RBRACE {
        if len(self._view_body_depths) > 0
            and self._brace_depth == self._view_body_depths[-1] {
            self._view_body_depths.pop();
        }
        if self._brace_depth > 0 {
            self._brace_depth -= 1;
        }
    }
}

impl Lexer.prev_is_value -> bool {
    return self.prev_token_kind
        in [
            TokenKind.NAME,
            TokenKind.KWESC_NAME,
            TokenKind.INT,
            TokenKind.FLOAT,
            TokenKind.HEX,
            TokenKind.BIN,
            TokenKind.OCT,
            TokenKind.STRING,
            TokenKind.BOOL,
            TokenKind.NULL,
            TokenKind.ELLIPSIS,
            TokenKind.RPAREN,
            TokenKind.RSQUARE,
            TokenKind.RBRACE,
            TokenKind.KW_SELF,
            TokenKind.KW_SUPER,
            TokenKind.KW_HERE,
            TokenKind.KW_ROOT,
            TokenKind.F_DQ_END,
            TokenKind.F_SQ_END,
            TokenKind.F_TDQ_END,
            TokenKind.F_TSQ_END,
            TokenKind.JSX_SELF_CLOSE,
            TokenKind.JSX_TAG_END,
            TokenKind.JSX_FRAG_CLOSE
        ];
}

impl Lexer._width_of(lead: int) -> int {
    if lead < 0x80 {
        return 1;
    }
    if lead < 0xE0 {
        return 2;
    }
    if lead < 0xF0 {
        return 3;
    }
    return 4;
}

impl Lexer._rune_width(byte_idx: int) -> int {
    return self._width_of(int.from_bytes(self._enc[byte_idx:byte_idx + 1], "big"));
}

impl Lexer._char_at(byte_idx: int) -> str {
    if byte_idx < 0 or byte_idx >= self._source_len {
        return "";
    }
    if self._ascii {
        return self.source[byte_idx];
    }
    one = self._enc[byte_idx:byte_idx + 1];
    lead = int.from_bytes(one, "big");
    if lead < 0x80 {
        return one.decode("utf-8");
    }
    if lead < 0xC0 {
        return "";
    }
    w = self._width_of(lead);
    return self._enc[byte_idx:byte_idx + w].decode("utf-8", errors="replace");
}

impl Lexer._slice(a: int, c: int) -> str {
    if self._ascii {
        return self.source[a:c];
    }
    return self._enc[a:c].decode("utf-8");
}

impl Lexer.current -> str {
    if self.pos >= self._source_len {
        return "";
    }
    if self._ascii {
        return self.source[self.pos];
    }
    return self._char_at(self.pos);
}

impl Lexer.peek(offset: int = 1) -> str {
    if self._ascii {
        idx = self.pos + offset;
        if idx >= self._source_len {
            return "";
        }
        return self.source[idx];
    }

    bi = self.pos;
    k = 0;
    while k < offset and bi < self._source_len {
        bi += self._rune_width(bi);
        k += 1;
    }
    return self._char_at(bi);
}

impl Lexer.advance -> str {
    if self._ascii {
        ch = self.current();
        if ch == "\n" {
            self.line += 1;
            self.col = 1;
        } else {
            self.col += 1;
        }
        self.pos += 1;
        return ch;
    }

    if self.pos >= self._source_len {
        return "";
    }
    one = self._enc[self.pos:self.pos + 1];
    lead = int.from_bytes(one, "big");
    if lead < 0x80 {
        ch = one.decode("utf-8");
        w = 1;
    } else {
        w = self._width_of(lead);
        ch = self._enc[self.pos:self.pos + w].decode("utf-8", errors="replace");
    }
    if ch == "\n" {
        self.line += 1;
        self.col = 1;
    } else {
        self.col += 1;
    }
    self.pos += w;
    return ch;
}

impl Lexer.at_end -> bool {
    return self.pos >= self._source_len;
}

impl Lexer.match_char(expected: str) -> bool {
    if self.current() == expected {
        self.advance();
        return True;
    }
    return False;
}

impl Lexer.match_string(expected: str) -> bool {
    if self._ascii {
        if self.source[self.pos:self.pos + len(expected)] == expected {
            for _ in range(len(expected)) {
                self.advance();
            }
            return True;
        }
        return False;
    }

    exp = expected.encode("utf-8");
    exp_bytes = len(exp);
    if self.pos + exp_bytes <= self._source_len
        and self._enc[self.pos:self.pos + exp_bytes] == exp {
        for _ in range(len(expected)) {
            self.advance();
        }
        return True;
    }
    return False;
}

impl Lexer.make_loc(start_line: int, start_col: int, start_pos: int) -> SourceLoc {
    return SourceLoc(
        file_path=self.file_path,
        line=start_line,
        end_line=self.line,
        col_start=start_col,
        col_end=self.col,
        pos_start=start_pos,
        pos_end=self.pos
    );
}

impl Lexer.make_token(
    kind: TokenKind, value: str, start_line: int, start_col: int, start_pos: int
) -> LexToken {
    return LexToken(
        kind=kind, value=value, loc=self.make_loc(start_line, start_col, start_pos)
    );
}

impl Lexer.error(
    message: str, start_line: int, start_col: int, start_pos: int, code_str: str = ""
) {
    self.error_count += 1;
    self.diags.append(
        SrcDiag(
            message=message,
            code_str=code_str,
            loc=self.make_loc(start_line, start_col, start_pos),
            is_error=True
        )
    );
}

impl Lexer.warning(
    message: str, start_line: int, start_col: int, start_pos: int, code_str: str = ""
) {
    self.diags.append(
        SrcDiag(
            message=message,
            code_str=code_str,
            loc=self.make_loc(start_line, start_col, start_pos),
            is_error=False
        )
    );
}

impl Lexer.is_digit(ch: str) -> bool {
    return ch >= "0" and ch <= "9";
}

impl Lexer.is_hex_digit(ch: str) -> bool {
    return self.is_digit(ch) or (ch >= "a" and ch <= "f") or (ch >= "A" and ch <= "F");
}

impl Lexer.is_alpha(ch: str) -> bool {
    return (ch >= "a" and ch <= "z") or (ch >= "A" and ch <= "Z") or ch == "_";
}

impl Lexer.is_alnum(ch: str) -> bool {
    return self.is_alpha(ch) or self.is_digit(ch);
}

impl Lexer.is_whitespace(ch: str) -> bool {
    return ch == " " or ch == "\t" or ch == "\r" or ch == "\n";
}

impl Lexer.skip_whitespace{
    while not self.at_end() and self.is_whitespace(self.current()) {
        self.advance();
    }
}

impl Lexer.skip_line_comment{
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    while not self.at_end() and self.current() != "\n" {
        self.advance();
    }
    comment_text = self._slice(start_pos, self.pos);
    self.comments.append(
        CommentData(
            value=comment_text,
            line=start_line,
            end_line=start_line,
            col_start=start_col,
            col_end=self.col,
            pos_start=start_pos,
            pos_end=self.pos,
            is_block=False
        )
    );
}

impl Lexer.skip_block_comment -> bool {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;

    self.advance();
    self.advance();
    while not self.at_end() {
        if self.current() == "*" and self.peek() == "#" {
            self.advance();
            self.advance();
            comment_text = self._slice(start_pos, self.pos);
            self.comments.append(
                CommentData(
                    value=comment_text,
                    line=start_line,
                    end_line=self.line,
                    col_start=start_col,
                    col_end=self.col,
                    pos_start=start_pos,
                    pos_end=self.pos,
                    is_block=True
                )
            );
            return True;
        }
        self.advance();
    }
    self.error(
        "Unterminated block comment", start_line, start_col, start_pos, code_str="E0101"
    );
    return False;
}

impl Lexer.skip_whitespace_and_comments{
    while not self.at_end() {
        ch = self.current();

        if self.is_whitespace(ch) {
            self.skip_whitespace();
        } elif ch == "#" {
            if self.peek() == "*" {
                self.skip_block_comment();
            } else {
                self.skip_line_comment();
            }
        } else {
            break;
        }
    }
}
