def _hex2(c: int) -> str {
    digits: str = "0123456789abcdef";
    return digits[c // 16] + digits[c % 16];
}


def _repr_str(s: str) -> str {
    has_single: bool = False;
    has_double: bool = False;
    i: int = 0;
    n: int = len(s);
    while i < n {
        c: int = ord(s[i]);
        if c == 39 {
            has_single = True;
        } elif c == 34 {
            has_double = True;
        }
        i += 1;
    }
    quote: str = "'";
    qc: int = 39;
    if has_single and not has_double {
        quote = "\"";
        qc = 34;
    }
    out: str = quote;
    j: int = 0;
    while j < n {
        c2: int = ord(s[j]);
        if c2 == 92 {
            out += "\\\\";
        } elif c2 == qc {
            out += "\\" + quote;
        } elif c2 == 10 {
            out += "\\n";
        } elif c2 == 9 {
            out += "\\t";
        } elif c2 == 13 {
            out += "\\r";
        } elif c2 < 32 or c2 == 127 {
            out += "\\x" + _hex2(c2);
        } else {
            out += s[j];
        }
        j += 1;
    }
    out += quote;
    return out;
}


def _fill(s: str, limit: int) -> str {
    if len(s) <= limit {
        return s;
    }
    i: int = (limit - 3) // 2;
    if i < 0 {
        i = 0;
    }
    j: int = limit - 3 - i;
    if j < 0 {
        j = 0;
    }
    return s[0:i] + "..." + s[len(s) - j:];
}


def _any_lt(a: any, b: any) -> bool {
    if isinstance(a, int) and isinstance(b, int) {
        ai: int = a;
        bi: int = b;
        return ai < bi;
    }
    if isinstance(a, str) and isinstance(b, str) {
        astr: str = a;
        bstr: str = b;
        m: int = len(astr);
        if len(bstr) < m {
            m = len(bstr);
        }
        i: int = 0;
        while i < m {
            ca: int = ord(astr[i]);
            cb: int = ord(bstr[i]);
            if ca != cb {
                return ca < cb;
            }
            i += 1;
        }
        return len(astr) < len(bstr);
    }
    return False;
}


def _homogeneous(xs: list[any]) -> bool {
    if len(xs) == 0 {
        return False;
    }
    want: int = 0;
    if isinstance(xs[0], int) and not isinstance(xs[0], bool) {
        want = 1;
    } elif isinstance(xs[0], str) {
        want = 2;
    } else {
        return False;
    }
    i: int = 1;
    while i < len(xs) {
        if want == 1 {
            if not isinstance(xs[i], int) or isinstance(xs[i], bool) {
                return False;
            }
        } elif not isinstance(xs[i], str) {
            return False;
        }
        i += 1;
    }
    return True;
}


def _sort_any(xs: list[any]) -> list[any] {
    if not _homogeneous(xs) {
        return xs;
    }
    i: int = 1;
    n: int = len(xs);
    while i < n {
        j: int = i;
        while j > 0 and _any_lt(xs[j], xs[j - 1]) {
            tmp: any = xs[j - 1];
            xs[j - 1] = xs[j];
            xs[j] = tmp;
            j -= 1;
        }
        i += 1;
    }
    return xs;
}


def _dict_keys(d: dict[any, any]) -> list[any] {
    keys: list[any] = [];
    for k in d {
        keys.append(k);
    }
    return _sort_any(keys);
}


obj:pub Repr {
    has maxlevel: int = 6,
        maxtuple: int = 6,
        maxlist: int = 6,
        maxdict: int = 4,
        maxset: int = 4,
        maxfrozenset: int = 4,
        maxstring: int = 30,
        maxlong: int = 40,
        maxother: int = 30;

    def _iter(x: list[any], level: int, left: str, right: str, maxiter: int) -> str {
        n: int = len(x);
        if level <= 0 and n > 0 {
            return left + "..." + right;
        }
        out: str = left;
        i: int = 0;
        while i < n and i < maxiter {
            if i > 0 {
                out += ", ";
            }
            out += self.repr1(x[i], level - 1);
            i += 1;
        }
        if n > maxiter {
            if i > 0 {
                out += ", ";
            }
            out += "...";
        }
        return out + right;
    }

    def repr1(x: any, level: int) -> str {
        if isinstance(x, bool) {
            bv: bool = x;
            return "True" if bv else "False";
        }
        if isinstance(x, int) {
            iv: int = x;
            return _fill(str(iv), self.maxlong);
        }
        if isinstance(x, float) {
            fv: float = x;
            return str(fv);
        }
        if isinstance(x, str) {
            sv: str = x;
            r: str = _repr_str(sv[0:self.maxstring]);
            return _fill(r, self.maxstring);
        }
        if isinstance(x, list) {
            lv: list[any] = x;
            return self._iter(lv, level, "[", "]", self.maxlist);
        }
        if isinstance(x, dict) {
            dv: dict[any, any] = x;
            n: int = len(dv);
            if n == 0 {
                return "{}";
            }
            if level <= 0 {
                return "{...}";
            }
            keys: list[any] = _dict_keys(dv);
            out: str = "{";
            i: int = 0;
            while i < n and i < self.maxdict {
                if i > 0 {
                    out += ", ";
                }
                k: any = keys[i];
                out += self.repr1(k, level - 1) + ": " + self.repr1(dv[k], level - 1);
                i += 1;
            }
            if n > self.maxdict {
                if i > 0 {
                    out += ", ";
                }
                out += "...";
            }
            return out + "}";
        }
        if isinstance(x, set) or isinstance(x, frozenset) {
            raise ValueError("reprlib: unsupported value type on native");
        }
        return "None";
    }

    def repr(x: any) -> str {
        return self.repr1(x, self.maxlevel);
    }
}


glob _AREPR: Repr = Repr();


def:pub repr(x: any) -> str {
    return _AREPR.repr(x);
}
