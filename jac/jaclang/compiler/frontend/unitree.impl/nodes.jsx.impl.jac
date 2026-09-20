impl JsxElement.postinit -> None {
    UniNode.postinit(self);
    Expr.postinit(self);
    AstSymbolStubNode._init_stub(self, sym_type=SymbolType.OBJECT_ARCH);
}

impl JsxElement.get_body_start_line -> (int | None) {
    if not self.kid {
        return None;
    }
    opening_tag = self.kid[0];
    if isinstance(opening_tag, JsxElement) {
        for k in opening_tag.kid {
            if (isinstance(k, Token) and (k.name == Tok.JSX_TAG_END) and k.loc) {
                return k.loc.last_line + 1;
            }
        }
    }
    return None;
}

impl JsxElement.get_body_end_line -> (int | None) {
    if not self.kid {
        return None;
    }
    closing_tag = self.kid[-1];
    if isinstance(closing_tag, JsxElement) {
        for k in closing_tag.kid {
            if (isinstance(k, Token) and (k.name == Tok.JSX_CLOSE_START) and k.loc) {
                return k.loc.first_line;
            }
        }
    }
    return None;
}

impl JsxElementName.postinit -> None {
    UniNode.postinit(self);
}

impl JsxAttribute.postinit -> None {
    UniNode.postinit(self);
}

impl JsxSpreadAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}

impl JsxNormalAttribute.postinit -> None {
    JsxAttribute.postinit(self);
}

impl JsxChild.postinit -> None {
    UniNode.postinit(self);
}

impl JsxText.postinit -> None {
    JsxChild.postinit(self);
}

impl JsxText.get_normalized_text -> str {
    raw = self.value.value if isinstance(self.value, Token) else str(self.value);
    if not raw {
        return "";
    }
    lines = raw.replace('\r\n', '\n').replace('\r', '\n').split('\n');

    last_non_empty = -1;
    for i in range(len(lines)) {
        if lines[i].strip(' \t') != '' {
            last_non_empty = i;
        }
    }
    result = "";
    for i in range(len(lines)) {
        line = lines[i].replace('\t', ' ');
        is_first = i == 0;
        is_last = i == len(lines) - 1;
        if not is_first {
            line = line.lstrip(' ');
        }
        if not is_last {
            line = line.rstrip(' ');
        }
        if line {
            if last_non_empty >= 0 and i != last_non_empty {
                line += ' ';
            }
            result += line;
        }
    }
    return result;
}

impl JsxExpression.postinit -> None {
    JsxChild.postinit(self);
}

impl JsxSlot.postinit -> None {
    JsxChild.postinit(self);
}

impl JsxComment.postinit -> None {
    JsxChild.postinit(self);
}
