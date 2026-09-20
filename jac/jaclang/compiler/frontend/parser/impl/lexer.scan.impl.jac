impl Lexer.scan_identifier -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = "";
    while not self.at_end() and self.is_alnum(self.current()) {
        value += self.advance();
    }

    if value == "not" {
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;

        while not self.at_end() and (self.current() == " " or self.current() == "\t") {
            self.advance();
        }

        if not self.at_end() and self.current() == "i" {
            if self._slice(self.pos, self.pos + 2) == "in"
                and (
                    self.pos + 2 >= self._source_len
                    or not self.is_alnum(self._char_at(self.pos + 2))
                ) {
                self.advance();
                self.advance();
                return self.make_token(
                    TokenKind.KW_NIN, "not in", start_line, start_col, start_pos
                );
            }
        }

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
    }
    if value == "is" {
        saved_pos = self.pos;
        saved_line = self.line;
        saved_col = self.col;

        while not self.at_end() and (self.current() == " " or self.current() == "\t") {
            self.advance();
        }

        if not self.at_end() and self.current() == "n" {
            if self._slice(self.pos, self.pos + 3) == "not"
                and (
                    self.pos + 3 >= self._source_len
                    or not self.is_alnum(self._char_at(self.pos + 3))
                ) {
                self.advance();
                self.advance();
                self.advance();
                return self.make_token(
                    TokenKind.KW_ISN, "is not", start_line, start_col, start_pos
                );
            }
        }

        self.pos = saved_pos;
        self.line = saved_line;
        self.col = saved_col;
    }

    kind = lookup_keyword(value);
    if kind is not None {
        return self.make_token(kind, value, start_line, start_col, start_pos);
    }
    return self.make_token(TokenKind.NAME, value, start_line, start_col, start_pos);
}

impl Lexer.scan_kwesc_name -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;

    self.advance();
    value = "`";
    while not self.at_end() and self.is_alnum(self.current()) {
        value += self.advance();
    }
    bare = value[1:];
    if lookup_keyword(bare) is None {
        self.error(
            f"'{bare}' is not a keyword -- remove the backtick",
            start_line,
            start_col,
            start_pos,
            code_str="E0014"
        );
    }
    return self.make_token(
        TokenKind.KWESC_NAME, value, start_line, start_col, start_pos
    );
}

impl Lexer.scan_number -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = "";
    kind = TokenKind.INT;

    if self.current() == "0" {
        value += self.advance();
        if self.current() == "x" or self.current() == "X" {
            value += self.advance();
            kind = TokenKind.HEX;
            while not self.at_end()
                and (self.is_hex_digit(self.current()) or self.current() == "_") {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        } elif self.current() == "b" or self.current() == "B" {
            value += self.advance();
            kind = TokenKind.BIN;
            while not self.at_end()
                and (
                    self.current() == "0"
                    or self.current() == "1"
                    or self.current() == "_"
                ) {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        } elif self.current() == "o" or self.current() == "O" {
            value += self.advance();
            kind = TokenKind.OCT;
            while not self.at_end()
                and (
                    self.current() >= "0"
                    and self.current() <= "7"
                    or self.current() == "_"
                ) {
                value += self.advance();
            }
            return self.make_token(kind, value, start_line, start_col, start_pos);
        }
    }

    while not self.at_end()
        and (self.is_digit(self.current()) or self.current() == "_") {
        value += self.advance();
    }

    if self.current() == "." and self.is_digit(self.peek()) {
        kind = TokenKind.FLOAT;
        value += self.advance();
        while not self.at_end()
            and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }

    if self.current() == "e" or self.current() == "E" {
        kind = TokenKind.FLOAT;
        value += self.advance();
        if self.current() == "+" or self.current() == "-" {
            value += self.advance();
        }
        while not self.at_end()
            and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }
    return self.make_token(kind, value, start_line, start_col, start_pos);
}

impl Lexer.scan_leading_dot_float -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = self.advance();
    while not self.at_end()
        and (self.is_digit(self.current()) or self.current() == "_") {
        value += self.advance();
    }

    if not self.at_end() and (self.current() == "e" or self.current() == "E") {
        value += self.advance();
        if not self.at_end() and (self.current() == "+" or self.current() == "-") {
            value += self.advance();
        }
        while not self.at_end()
            and (self.is_digit(self.current()) or self.current() == "_") {
            value += self.advance();
        }
    }
    return self.make_token(TokenKind.FLOAT, value, start_line, start_col, start_pos);
}

impl Lexer.scan_string(quote: str) -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = "";

    prefix = "";
    pp = start_pos - 1;
    while pp >= 0 and self.is_alnum(self._char_at(pp)) {
        prefix = self._char_at(pp) + prefix;
        pp -= 1;
    }
    is_raw = prefix.lower() in ["r", "rb", "br"];
    is_bytes = prefix.lower() in ["b", "rb", "br"];
    triple = False;

    if self.peek() == quote and self.peek(2) == quote {
        triple = True;
        value += self.advance();
        value += self.advance();
        value += self.advance();
    } else {
        value += self.advance();
    }
    while not self.at_end() {
        ch = self.current();

        if triple {
            if ch == quote and self.peek() == quote and self.peek(2) == quote {
                value += self.advance();
                value += self.advance();
                value += self.advance();
                return self.make_token(
                    TokenKind.STRING, value, start_line, start_col, start_pos
                );
            }
        } else {
            if ch == quote {
                value += self.advance();
                return self.make_token(
                    TokenKind.STRING, value, start_line, start_col, start_pos
                );
            }
            if ch == "\n" {
                self.error(
                    "Unterminated string literal",
                    start_line,
                    start_col,
                    start_pos,
                    code_str="E0100"
                );
                return self.make_token(
                    TokenKind.ERROR, value, start_line, start_col, start_pos
                );
            }
        }

        if ch == "\\" {
            esc_line = self.line;
            esc_col = self.col;
            esc_pos = self.pos;
            value += self.advance();
            if not self.at_end() {
                esc = self.current();
                value += self.advance();

                if (not is_raw and not is_bytes and esc == "N") {
                    self.error(
                        "Unsupported escape sequence '\\N{...}'",
                        esc_line,
                        esc_col,
                        esc_pos,
                        code_str="E0110"
                    );
                } elif (
                    not is_raw
                    and esc not in "nrtbfva01234567xNuU"
                    and esc != "\\"
                    and esc != "\""
                    and esc != "'"
                    and esc != "\n"
                    and esc != "\r"
                ) {
                    self.warning(
                        f"Invalid escape sequence '\\{esc}'",
                        esc_line,
                        esc_col,
                        esc_pos,
                        code_str="W0100"
                    );
                }
            }
        } else {
            value += self.advance();
        }
    }
    self.error(
        "Unterminated string literal",
        start_line,
        start_col,
        start_pos,
        code_str="E0100"
    );
    return self.make_token(TokenKind.ERROR, value, start_line, start_col, start_pos);
}

impl Lexer.scan_regular_token -> LexToken {
    self.skip_whitespace_and_comments();
    if self.at_end() {
        return LexToken(
            kind=TokenKind.EOF,
            value="",
            loc=SourceLoc(
                file_path=self.file_path,
                line=self.line,
                end_line=self.line,
                col_start=self.col,
                col_end=self.col,
                pos_start=self.pos,
                pos_end=self.pos
            )
        );
    }
    ch = self.current();

    if self.is_alpha(ch) {
        if ch == "f" and (self.peek() == "\"" or self.peek() == "'") {
            self.advance();
            return self.scan_fstring("f");
        }
        if ch == "r"
            and self.peek() == "f"
            and (self.peek(2) == "\"" or self.peek(2) == "'") {
            self.advance();
            self.advance();
            return self.scan_fstring("rf");
        }
        return self.scan_identifier();
    }

    if self.is_digit(ch) {
        return self.scan_number();
    }

    if ch == "." and not self.at_end() and self.is_digit(self.peek()) {
        return self.scan_leading_dot_float();
    }

    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }

    if ch == ":"
        and self.peek() == ":"
        and self.peek(2) == "p"
        and self.peek(3) == "y"
        and self.peek(4) == ":"
        and self.peek(5) == ":" {
        return self.scan_pynline();
    }

    if ch == "`" and self.is_alpha(self.peek()) {
        return self.scan_kwesc_name();
    }

    return self.scan_operator();
}

impl Lexer.scan_pynline -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;

    for _ in range(6) {
        self.advance();
    }

    code = "";
    while not self.at_end() {
        if self.current() == ":"
            and self.peek() == ":"
            and self.peek(2) == "p"
            and self.peek(3) == "y"
            and self.peek(4) == ":"
            and self.peek(5) == ":" {
            for _ in range(6) {
                self.advance();
            }
            return self.make_token(
                TokenKind.PYNLINE, code, start_line, start_col, start_pos
            );
        }
        code += self.advance();
    }
    self.error(
        "Unterminated inline Python block",
        start_line,
        start_col,
        start_pos,
        code_str="E0103"
    );
    return self.make_token(TokenKind.ERROR, code, start_line, start_col, start_pos);
}

impl Lexer.scan_operator -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if self.match_string("<-->") {
        return self.make_token(
            TokenKind.ARROW_BI, "<-->", start_line, start_col, start_pos
        );
    }
    if self.match_string("<++>") {
        return self.make_token(
            TokenKind.CARROW_BI, "<++>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<--") {
        return self.make_token(
            TokenKind.ARROW_L, "<--", start_line, start_col, start_pos
        );
    }
    if self.match_string("-->") {
        return self.make_token(
            TokenKind.ARROW_R, "-->", start_line, start_col, start_pos
        );
    }
    if self.match_string("<++") {
        return self.make_token(
            TokenKind.CARROW_L, "<++", start_line, start_col, start_pos
        );
    }
    if self.match_string("++>") {
        return self.make_token(
            TokenKind.CARROW_R, "++>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<-:") {
        return self.make_token(
            TokenKind.ARROW_L_P1, "<-:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":->") {
        return self.make_token(
            TokenKind.ARROW_R_P2, ":->", start_line, start_col, start_pos
        );
    }

    if self.match_string("->:") {
        return self.make_token(
            TokenKind.ARROW_R_P1, "->:", start_line, start_col, start_pos
        );
    }
    if self.match_string("<+:") {
        return self.make_token(
            TokenKind.CARROW_L_P1, "<+:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":+>") {
        return self.make_token(
            TokenKind.CARROW_R_P2, ":+>", start_line, start_col, start_pos
        );
    }
    if self.match_string("...") {
        return self.make_token(
            TokenKind.ELLIPSIS, "...", start_line, start_col, start_pos
        );
    }
    if self.match_string("**=") {
        return self.make_token(
            TokenKind.STAR_POW_EQ, "**=", start_line, start_col, start_pos
        );
    }
    if self.match_string("//=") {
        return self.make_token(
            TokenKind.FLOOR_DIV_EQ, "//=", start_line, start_col, start_pos
        );
    }
    if self.match_string("<<=") {
        return self.make_token(
            TokenKind.LSHIFT_EQ, "<<=", start_line, start_col, start_pos
        );
    }
    if self.match_string(">>=") {
        return self.make_token(
            TokenKind.RSHIFT_EQ, ">>=", start_line, start_col, start_pos
        );
    }
    if self.match_string("</>") {
        self.jsx_depth -= 1;
        self.pop_mode();
        return self.make_token(
            TokenKind.JSX_FRAG_CLOSE, "</>", start_line, start_col, start_pos
        );
    }

    if self.match_string("**") {
        return self.make_token(
            TokenKind.STAR_POW, "**", start_line, start_col, start_pos
        );
    }
    if self.match_string("//") {
        return self.make_token(
            TokenKind.FLOOR_DIV, "//", start_line, start_col, start_pos
        );
    }
    if self.match_string("==") {
        return self.make_token(TokenKind.EE, "==", start_line, start_col, start_pos);
    }
    if self.match_string("!=") {
        return self.make_token(TokenKind.NE, "!=", start_line, start_col, start_pos);
    }
    if self.match_string("<=") {
        return self.make_token(TokenKind.LTE, "<=", start_line, start_col, start_pos);
    }
    if self.match_string(">=") {
        return self.make_token(TokenKind.GTE, ">=", start_line, start_col, start_pos);
    }
    if self.match_string("<<") {
        return self.make_token(
            TokenKind.LSHIFT, "<<", start_line, start_col, start_pos
        );
    }
    if self.match_string(">>") {
        return self.make_token(
            TokenKind.RSHIFT, ">>", start_line, start_col, start_pos
        );
    }
    if self.match_string("|>") {
        return self.make_token(
            TokenKind.PIPE_FWD, "|>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<|") {
        return self.make_token(
            TokenKind.PIPE_BKWD, "<|", start_line, start_col, start_pos
        );
    }
    if self.match_string(":>") {
        return self.make_token(
            TokenKind.A_PIPE_FWD, ":>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<:") {
        return self.make_token(
            TokenKind.A_PIPE_BKWD, "<:", start_line, start_col, start_pos
        );
    }
    if self.match_string(".>") {
        return self.make_token(
            TokenKind.DOT_FWD, ".>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<.") {
        return self.make_token(
            TokenKind.DOT_BKWD, "<.", start_line, start_col, start_pos
        );
    }
    if self.match_string("->") {
        return self.make_token(
            TokenKind.RETURN_HINT, "->", start_line, start_col, start_pos
        );
    }
    if self.match_char("?") {
        return self.make_token(
            TokenKind.NULL_OK, "?", start_line, start_col, start_pos
        );
    }
    if self.match_string(":=") {
        return self.make_token(
            TokenKind.WALRUS_EQ, ":=", start_line, start_col, start_pos
        );
    }
    if self.match_string("+=") {
        return self.make_token(
            TokenKind.ADD_EQ, "+=", start_line, start_col, start_pos
        );
    }
    if self.match_string("-=") {
        return self.make_token(
            TokenKind.SUB_EQ, "-=", start_line, start_col, start_pos
        );
    }
    if self.match_string("*=") {
        return self.make_token(
            TokenKind.MUL_EQ, "*=", start_line, start_col, start_pos
        );
    }
    if self.match_string("/=") {
        return self.make_token(
            TokenKind.DIV_EQ, "/=", start_line, start_col, start_pos
        );
    }
    if self.match_string("%=") {
        return self.make_token(
            TokenKind.MOD_EQ, "%=", start_line, start_col, start_pos
        );
    }
    if self.match_string("&=") {
        return self.make_token(
            TokenKind.BW_AND_EQ, "&=", start_line, start_col, start_pos
        );
    }
    if self.match_string("|=") {
        return self.make_token(
            TokenKind.BW_OR_EQ, "|=", start_line, start_col, start_pos
        );
    }
    if self.match_string("^=") {
        return self.make_token(
            TokenKind.BW_XOR_EQ, "^=", start_line, start_col, start_pos
        );
    }
    if self.match_string("@=") {
        return self.make_token(
            TokenKind.MATMUL_EQ, "@=", start_line, start_col, start_pos
        );
    }

    if self.match_string(":<-") {
        return self.make_token(
            TokenKind.ARROW_L_P2, ":<-", start_line, start_col, start_pos
        );
    }
    if self.match_string("+>:") {
        return self.make_token(
            TokenKind.CARROW_R_P1, "+>:", start_line, start_col, start_pos
        );
    }
    if self.match_string(":<+") {
        return self.make_token(
            TokenKind.CARROW_L_P2, ":<+", start_line, start_col, start_pos
        );
    }
    if self.match_string("</") {
        return self.make_token(
            TokenKind.JSX_CLOSE_START, "</", start_line, start_col, start_pos
        );
    }
    if self.match_string("/>") {
        return self.make_token(
            TokenKind.JSX_SELF_CLOSE, "/>", start_line, start_col, start_pos
        );
    }
    if self.match_string("<>") {
        self.jsx_depth += 1;
        self.push_mode(LexerMode.JSX_CONTENT);
        return self.make_token(
            TokenKind.JSX_FRAG_OPEN, "<>", start_line, start_col, start_pos
        );
    }

    if self.in_jsx() and self.jsx_brace_depth == 0 {
        if self.match_string("{{") {
            return self.make_token(
                TokenKind.D_LBRACE, "{{", start_line, start_col, start_pos
            );
        }
        if self.match_string("}}") {
            return self.make_token(
                TokenKind.D_RBRACE, "}}", start_line, start_col, start_pos
            );
        }
    }

    self.advance();
    switch ch {
        case "(":
            return self.make_token(
                TokenKind.LPAREN, "(", start_line, start_col, start_pos
            );

        case ")":
            return self.make_token(
                TokenKind.RPAREN, ")", start_line, start_col, start_pos
            );

        case "{":
            if self.jsx_brace_depth > 0 {
                self.jsx_brace_depth += 1;
            }
            return self.make_token(
                TokenKind.LBRACE, "{", start_line, start_col, start_pos
            );

        case "}":
            if self.jsx_brace_depth > 0 {
                self.jsx_brace_depth -= 1;
                if self.jsx_brace_depth == 0 {
                    self.pop_mode();

                    if self.jsx_brace_depth_stack {
                        self.jsx_brace_depth = self.jsx_brace_depth_stack.pop();
                    }
                }
            }
            return self.make_token(
                TokenKind.RBRACE, "}", start_line, start_col, start_pos
            );

        case "[":
            return self.make_token(
                TokenKind.LSQUARE, "[", start_line, start_col, start_pos
            );

        case "]":
            return self.make_token(
                TokenKind.RSQUARE, "]", start_line, start_col, start_pos
            );

        case ",":
            return self.make_token(
                TokenKind.COMMA, ",", start_line, start_col, start_pos
            );

        case ":":
            return self.make_token(
                TokenKind.COLON, ":", start_line, start_col, start_pos
            );

        case ";":
            return self.make_token(
                TokenKind.SEMI, ";", start_line, start_col, start_pos
            );

        case ".":
            return self.make_token(
                TokenKind.DOT, ".", start_line, start_col, start_pos
            );

        case "+":
            return self.make_token(
                TokenKind.PLUS, "+", start_line, start_col, start_pos
            );

        case "-":
            return self.make_token(
                TokenKind.MINUS, "-", start_line, start_col, start_pos
            );

        case "*":
            return self.make_token(
                TokenKind.STAR_MUL, "*", start_line, start_col, start_pos
            );

        case "/":
            return self.make_token(
                TokenKind.DIV, "/", start_line, start_col, start_pos
            );

        case "%":
            return self.make_token(
                TokenKind.MOD, "%", start_line, start_col, start_pos
            );

        case "&":
            return self.make_token(
                TokenKind.BW_AND, "&", start_line, start_col, start_pos
            );

        case "|":
            return self.make_token(
                TokenKind.BW_OR, "|", start_line, start_col, start_pos
            );

        case "^":
            return self.make_token(
                TokenKind.BW_XOR, "^", start_line, start_col, start_pos
            );

        case "~":
            return self.make_token(
                TokenKind.BW_NOT, "~", start_line, start_col, start_pos
            );

        case "<":
            return self.make_token(TokenKind.LT, "<", start_line, start_col, start_pos);

        case ">":
            return self.make_token(TokenKind.GT, ">", start_line, start_col, start_pos);

        case "=":
            return self.make_token(TokenKind.EQ, "=", start_line, start_col, start_pos);

        case "@":
            return self.make_token(
                TokenKind.DECOR_OP, "@", start_line, start_col, start_pos
            );

    }

    self.error(
        f"Unexpected character: '{ch}'",
        start_line,
        start_col,
        start_pos,
        code_str="E0105"
    );
    return self.make_token(TokenKind.ERROR, ch, start_line, start_col, start_pos);
}

impl Lexer.next_token -> LexToken {
    mode = self.current_mode();

    if mode
        in [
            LexerMode.FSTRING_DQ,
            LexerMode.FSTRING_SQ,
            LexerMode.FSTRING_TDQ,
            LexerMode.FSTRING_TSQ
        ] {
        return self.scan_fstring_content();
    } elif mode == LexerMode.FSTRING_EXPR {
        return self.scan_fstring_expr_token();
    }

    if mode == LexerMode.JSX_TAG {
        return self.scan_jsx_tag_token();
    } elif mode == LexerMode.JSX_CONTENT {
        return self.scan_jsx_content();
    }

    self.skip_whitespace_and_comments();
    if self.at_end() {
        return LexToken(
            kind=TokenKind.EOF,
            value="",
            loc=SourceLoc(
                file_path=self.file_path,
                line=self.line,
                end_line=self.line,
                col_start=self.col,
                col_end=self.col,
                pos_start=self.pos,
                pos_end=self.pos
            )
        );
    }
    ch = self.current();

    if ch == "`" and self.is_alpha(self.peek()) {
        return self.scan_kwesc_name();
    }

    if ch == "<" and (self.is_alpha(self.peek()) or self.peek() == "@") {
        if not self.prev_is_value() {
            return self.scan_jsx_open_start();
        }
        if self.in_view_body()
            and self.prev_token_kind
                in [
                    TokenKind.RBRACE,
                    TokenKind.JSX_TAG_END,
                    TokenKind.JSX_SELF_CLOSE,
                    TokenKind.JSX_FRAG_CLOSE
                ] {
            return self.scan_jsx_open_start();
        }
        if self.prev_token_kind in [TokenKind.RBRACE] {
            return self.scan_jsx_open_start();
        }
    }

    if self.is_alpha(ch) {
        if ch == "f" and (self.peek() == "\"" or self.peek() == "'") {
            self.advance();
            return self.scan_fstring("f");
        }
        if ch == "r"
            and self.peek() == "f"
            and (self.peek(2) == "\"" or self.peek(2) == "'") {
            self.advance();
            self.advance();
            return self.scan_fstring("rf");
        }
        return self.scan_identifier();
    }

    if self.is_digit(ch) {
        return self.scan_number();
    }

    if ch == "." and not self.at_end() and self.is_digit(self.peek()) {
        return self.scan_leading_dot_float();
    }

    if ch == "\"" or ch == "'" {
        return self.scan_string(ch);
    }

    if ch == ":"
        and self.peek() == ":"
        and self.peek(2) == "p"
        and self.peek(3) == "y"
        and self.peek(4) == ":"
        and self.peek(5) == ":" {
        return self.scan_pynline();
    }

    return self.scan_operator();
}

impl Lexer.tokenize -> list[LexToken] {
    self._enc = self.source.encode("utf-8");
    self._source_len = len(self._enc);
    self._ascii = self.source.isascii();
    tokens: list[LexToken] = [];
    last_pos = -1;
    while True {
        token = self.next_token();
        tokens.append(token);
        self._track_view_context(token);
        self.prev_token_kind = token.kind;
        if token.kind == TokenKind.EOF {
            break;
        }

        if self.pos == last_pos or self.pos > self._source_len {
            mode = self.current_mode();
            self.error(
                f"Lexer stuck at EOF in mode {mode} (pos={self.pos})",
                self.line,
                self.col,
                self.pos,
                code_str="E0107"
            );
            tokens.append(
                LexToken(
                    kind=TokenKind.EOF,
                    value="",
                    loc=SourceLoc(
                        file_path=self.file_path,
                        line=self.line,
                        end_line=self.line,
                        col_start=self.col,
                        col_end=self.col,
                        pos_start=self.pos,
                        pos_end=self.pos
                    )
                )
            );
            break;
        }
        last_pos = self.pos;
    }
    return tokens;
}
