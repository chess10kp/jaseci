glob:pub whitespace: str = " \t\n\r\x0b\x0c",
     ascii_lowercase: str = "abcdefghijklmnopqrstuvwxyz",
     ascii_uppercase: str = "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
     ascii_letters: str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ",
     digits: str = "0123456789",
     hexdigits: str = "0123456789abcdefABCDEF",
     octdigits: str = "01234567",
     punctuation: str = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~",
     printable: str = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~ \t\n\r\x0b\x0c";


def:pub capwords(s: str, sep: (str | None) = None) -> str {
    parts: list[str] = [];
    joiner: str = " ";
    if sep is None {
        parts = s.split();
    } else {
        sepv: str = sep;
        parts = s.split(sepv);
        joiner = sepv;
    }
    out: str = "";
    i: int = 0;
    n: int = len(parts);
    while i < n {
        if i > 0 {
            out += joiner;
        }
        out += parts[i].capitalize();
        i += 1;
    }
    return out;
}


def _is_id_start(c: int) -> bool {
    return c == 95 or (c >= 65 and c <= 90) or (c >= 97 and c <= 122);
}


def _is_id_char(c: int) -> bool {
    return _is_id_start(c) or (c >= 48 and c <= 57);
}


def _strval(v: any) -> str {
    if isinstance(v, str) {
        s: str = v;
        return s;
    }
    if isinstance(v, bool) {
        b: bool = v;
        return "True" if b else "False";
    }
    if isinstance(v, int) {
        i: int = v;
        return str(i);
    }
    if isinstance(v, float) {
        f: float = v;
        return str(f);
    }
    raise ValueError(
        "Template substitution value must be str/int/float/bool on native"
    );
}


def _invalid(template: str, i: int) {
    lineno: int = 1;
    colno: int = i + 1;
    j: int = 0;
    while j < i {
        if ord(template[j]) == 10 {
            lineno += 1;
            colno = i - j;
        }
        j += 1;
    }
    raise ValueError(
        "Invalid placeholder in string: line " + str(lineno) + ", col " + str(colno)
    );
}


def _expand(template: str, mapping: (dict[str, any] | None), safe: bool) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(template);
    while i < n {
        c: int = ord(template[i]);
        if c != 36 {
            out += template[i];
            i += 1;
            continue;
        }
        if i + 1 >= n {
            if safe {
                out += "$";
                i += 1;
                continue;
            }
            _invalid(template, i);
        }
        nx: int = ord(template[i + 1]);
        if nx == 36 {
            out += "$";
            i += 2;
            continue;
        }
        name: str = "";
        consumed: int = 0;
        raw: str = "";
        if nx == 123 {
            j: int = i + 2;
            while j < n and _is_id_char(ord(template[j])) {
                j += 1;
            }
            if j > i + 2 and j < n and ord(template[j]) == 125 {
                name = template[i + 2:j];
                consumed = j + 1 - i;
                raw = template[i:j + 1];
            } elif safe {
                out += "$";
                i += 1;
                continue;
            } else {
                _invalid(template, i);
            }
        } elif _is_id_start(nx) {
            j = i + 1;
            while j < n and _is_id_char(ord(template[j])) {
                j += 1;
            }
            name = template[i + 1:j];
            consumed = j - i;
            raw = template[i:j];
        } elif safe {
            out += "$";
            i += 1;
            continue;
        } else {
            _invalid(template, i);
        }
        hit: bool = False;
        val: any = None;
        if isinstance(mapping, dict) {
            m2: dict[str, any] = mapping;
            if name in m2 {
                hit = True;
                val = m2[name];
            }
        }
        if hit {
            out += _strval(val);
        } elif safe {
            out += raw;
        } elif mapping is None {
            out += name;
        } else {
            raise KeyError(name);
        }
        i += consumed;
    }
    return out;
}


obj:pub Template {
    has template: str = "",
        delimiter: str = "$";

    def init(template: str) {
        self.template = template;
    }

    def substitute(mapping: dict[str, any]) -> str {
        return _expand(self.template, mapping, False);
    }

    def safe_substitute(mapping: dict[str, any]) -> str {
        return _expand(self.template, mapping, True);
    }

    def is_valid -> bool {
        try {
            _expand(self.template, None, False);
        } except ValueError {
            return False;
        }
        return True;
    }

    def get_identifiers -> list[str] {
        ids: list[str] = [];
        template: str = self.template;
        i: int = 0;
        n: int = len(template);
        while i < n {
            c: int = ord(template[i]);
            if c != 36 {
                i += 1;
                continue;
            }
            if i + 1 >= n {
                i += 1;
                continue;
            }
            nx: int = ord(template[i + 1]);
            if nx == 36 {
                i += 2;
                continue;
            }
            name: str = "";
            consumed: int = 0;
            if nx == 123 {
                j: int = i + 2;
                while j < n and _is_id_char(ord(template[j])) {
                    j += 1;
                }
                if j > i + 2 and j < n and ord(template[j]) == 125 {
                    name = template[i + 2:j];
                    consumed = j + 1 - i;
                }
            } elif _is_id_start(nx) {
                j = i + 1;
                while j < n and _is_id_char(ord(template[j])) {
                    j += 1;
                }
                name = template[i + 1:j];
                consumed = j - i;
            }
            if consumed == 0 {
                i += 1;
                continue;
            }
            seen: bool = False;
            k: int = 0;
            while k < len(ids) {
                if ids[k] == name {
                    seen = True;
                    break;
                }
                k += 1;
            }
            if not seen {
                ids.append(name);
            }
            i += consumed;
        }
        return ids;
    }
}
