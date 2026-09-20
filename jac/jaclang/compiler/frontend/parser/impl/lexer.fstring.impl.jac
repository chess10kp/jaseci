impl Lexer.scan_fstring(prefix: str) -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    value = prefix;

    quote = self.current();
    triple = self.peek() == quote and self.peek(2) == quote;
    if triple {
        value += self.advance();
        value += self.advance();
        value += self.advance();
        if quote == "\"" {
            self.push_mode(LexerMode.FSTRING_TDQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_TDQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_TDQ_START, value, start_line, start_col, start_pos
                );
            }
        } else {
            self.push_mode(LexerMode.FSTRING_TSQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_TSQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_TSQ_START, value, start_line, start_col, start_pos
                );
            }
        }
    } else {
        value += self.advance();
        if quote == "\"" {
            self.push_mode(LexerMode.FSTRING_DQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_DQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_DQ_START, value, start_line, start_col, start_pos
                );
            }
        } else {
            self.push_mode(LexerMode.FSTRING_SQ);
            if prefix == "f" {
                return self.make_token(
                    TokenKind.F_SQ_START, value, start_line, start_col, start_pos
                );
            } else {
                return self.make_token(
                    TokenKind.RF_SQ_START, value, start_line, start_col, start_pos
                );
            }
        }
    }
}

impl Lexer.scan_fstring_content -> LexToken {
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    mode = self.current_mode();
    is_triple = mode in [LexerMode.FSTRING_TDQ, LexerMode.FSTRING_TSQ];
    quote = "\"" if mode in [LexerMode.FSTRING_DQ, LexerMode.FSTRING_TDQ] else "'";
    value = "";
    while not self.at_end() {
        ch = self.current();

        if is_triple {
            if ch == quote and self.peek() == quote and self.peek(2) == quote {
                if len(value) > 0 {
                    text_kind = self.get_fstring_text_kind(mode);
                    return self.make_token(
                        text_kind, value, start_line, start_col, start_pos
                    );
                }

                self.advance();
                self.advance();
                self.advance();
                self.pop_mode();
                end_kind = self.get_fstring_end_kind(mode);
                triple_quote = f"{quote}{quote}{quote}";
                return self.make_token(
                    end_kind, triple_quote, start_line, start_col, start_pos
                );
            }
        } else {
            if ch == quote {
                if len(value) > 0 {
                    text_kind = self.get_fstring_text_kind(mode);
                    return self.make_token(
                        text_kind, value, start_line, start_col, start_pos
                    );
                }
                self.advance();
                self.pop_mode();
                end_kind = self.get_fstring_end_kind(mode);
                return self.make_token(
                    end_kind, quote, start_line, start_col, start_pos
                );
            }
            if ch == "\n" {
                self.error(
                    "Unterminated f-string",
                    start_line,
                    start_col,
                    start_pos,
                    code_str="E0102"
                );
                return self.make_token(
                    TokenKind.ERROR, value, start_line, start_col, start_pos
                );
            }
        }

        if ch == "{" and self.peek() == "{" {
            if len(value) > 0 {
                text_kind = self.get_fstring_text_kind(mode);
                return self.make_token(
                    text_kind, value, start_line, start_col, start_pos
                );
            }
            self.advance();
            self.advance();
            return self.make_token(
                TokenKind.D_LBRACE, "{{", start_line, start_col, start_pos
            );
        }
        if ch == "}" and self.peek() == "}" {
            if len(value) > 0 {
                text_kind = self.get_fstring_text_kind(mode);
                return self.make_token(
                    text_kind, value, start_line, start_col, start_pos
                );
            }
            self.advance();
            self.advance();
            return self.make_token(
                TokenKind.D_RBRACE, "}}", start_line, start_col, start_pos
            );
        }

        if ch == "{" {
            if len(value) > 0 {
                text_kind = self.get_fstring_text_kind(mode);
                return self.make_token(
                    text_kind, value, start_line, start_col, start_pos
                );
            }
            self.advance();
            self.push_mode(LexerMode.FSTRING_EXPR);
            self.fstring_brace_depth_stack.append(self.fstring_brace_depth);
            self.fstring_brace_depth = 1;
            return self.make_token(
                TokenKind.LBRACE, "{", start_line, start_col, start_pos
            );
        }

        if ch == "\\" {
            value += self.advance();
            if not self.at_end() {
                value += self.advance();
            }
        } else {
            value += self.advance();
        }
    }
    self.error(
        "Unterminated f-string", start_line, start_col, start_pos, code_str="E0102"
    );
    return self.make_token(TokenKind.ERROR, value, start_line, start_col, start_pos);
}

impl Lexer.get_fstring_text_kind(mode: LexerMode) -> TokenKind {
    switch mode {
        case LexerMode.FSTRING_DQ:
            return TokenKind.F_TEXT_DQ;

        case LexerMode.FSTRING_SQ:
            return TokenKind.F_TEXT_SQ;

        case LexerMode.FSTRING_TDQ:
            return TokenKind.F_TEXT_TDQ;

        case LexerMode.FSTRING_TSQ:
            return TokenKind.F_TEXT_TSQ;

        default:
            return TokenKind.F_TEXT_DQ;

    }
}

impl Lexer.get_fstring_end_kind(mode: LexerMode) -> TokenKind {
    switch mode {
        case LexerMode.FSTRING_DQ:
            return TokenKind.F_DQ_END;

        case LexerMode.FSTRING_SQ:
            return TokenKind.F_SQ_END;

        case LexerMode.FSTRING_TDQ:
            return TokenKind.F_TDQ_END;

        case LexerMode.FSTRING_TSQ:
            return TokenKind.F_TSQ_END;

        default:
            return TokenKind.F_DQ_END;

    }
}

impl Lexer.scan_fstring_expr_token -> LexToken {
    self.skip_whitespace_and_comments();
    start_line = self.line;
    start_col = self.col;
    start_pos = self.pos;
    ch = self.current();

    if ch == "{" {
        self.fstring_brace_depth += 1;
        self.advance();
        return self.make_token(TokenKind.LBRACE, "{", start_line, start_col, start_pos);
    }
    if ch == "}" {
        self.fstring_brace_depth -= 1;
        self.advance();
        if self.fstring_brace_depth == 0 {
            self.pop_mode();

            if self.fstring_brace_depth_stack {
                self.fstring_brace_depth = self.fstring_brace_depth_stack.pop();
            }
        }
        return self.make_token(TokenKind.RBRACE, "}", start_line, start_col, start_pos);
    }

    if ch == "!" and self.peek() in ["s", "r", "a", "S", "R", "A"] {
        self.advance();
        conv = self.advance();
        return self.make_token(
            TokenKind.CONV, "!" + conv, start_line, start_col, start_pos
        );
    }

    if ch == ":" and self.peek() != "=" {
        self.advance();
        return self.make_token(TokenKind.COLON, ":", start_line, start_col, start_pos);
    }

    return self.scan_regular_token();
}
