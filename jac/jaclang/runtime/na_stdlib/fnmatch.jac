def _class_end(pat: str, start: int) -> int {
    n: int = len(pat);
    j: int = start + 1;
    if j < n and pat[j] == "!" {
        j += 1;
    }
    if j < n and pat[j] == "]" {
        j += 1;
    }
    while j < n and pat[j] != "]" {
        j += 1;
    }
    if j >= n {
        return -1;
    }
    return j;
}

def _class_hit(pat: str, start: int, close: int, ch: str) -> bool {
    j: int = start + 1;
    neg: bool = False;
    if j < close and pat[j] == "!" {
        neg = True;
        j += 1;
    }
    hit: bool = False;
    c: int = ord(ch);
    while j < close {
        if j + 2 < close and pat[j + 1] == "-" {
            if ord(pat[j]) <= c and c <= ord(pat[j + 2]) {
                hit = True;
            }
            j += 3;
            continue;
        }
        if pat[j] == ch {
            hit = True;
        }
        j += 1;
    }
    if neg {
        return not hit;
    }
    return hit;
}

def _match(name: str, pat: str) -> bool {
    n: int = len(name);
    m: int = len(pat);
    i: int = 0;
    j: int = 0;
    star_j: int = -1;
    star_i: int = 0;
    while i < n {
        matched: bool = False;
        nj: int = j;
        if j < m {
            pc: str = pat[j];
            if pc == "*" {
                star_j = j;
                star_i = i;
                j += 1;
                continue;
            }
            if pc == "?" {
                matched = True;
                nj = j + 1;
            } elif pc == "[" {
                close: int = _class_end(pat, j);
                if close < 0 {
                    matched = name[i] == "[";
                    nj = j + 1;
                } else {
                    matched = _class_hit(pat, j, close, name[i]);
                    nj = close + 1;
                }
            } else {
                matched = name[i] == pc;
                nj = j + 1;
            }
        }
        if matched {
            i += 1;
            j = nj;
            continue;
        }
        if star_j >= 0 {
            star_i += 1;
            i = star_i;
            j = star_j + 1;
            continue;
        }
        return False;
    }
    while j < m and pat[j] == "*" {
        j += 1;
    }
    return j == m;
}

def:pub normcase(s: str) -> str {
    return s;
}

def:pub fnmatchcase(name: str, pat: str) -> bool {
    return _match(name, pat);
}

def:pub fnmatch(name: str, pat: str) -> bool {
    return _match(normcase(name), normcase(pat));
}

def _re_escape(c: str) -> str {
    if c == "("
        or c == ")"
        or c == "["
        or c == "]"
        or c == "{"
        or c == "}"
        or c == "?"
        or c == "*"
        or c == "+"
        or c == "-"
        or c == "|"
        or c == "^"
        or c == "$"
        or c == "\\"
        or c == "."
        or c == "&"
        or c == "~"
        or c == "#"
        or c == " "
        or c == "\t"
        or c == "\n"
        or c == "\r"
        or c == "\x0b"
        or c == "\x0c" {
        return "\\" + c;
    }
    return c;
}

def _setops_sub(stuff: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(stuff);
    while i < n {
        c: str = stuff[i];
        if (c == "&" or c == "~" or c == "|") {
            out += "\\";
        }
        out += c;
        i += 1;
    }
    return out;
}

def _find_in(hay: str, needle: str, lo: int, hi: int) -> int {
    k: int = lo;
    while k < hi {
        if hay[k] == needle {
            return k;
        }
        k += 1;
    }
    return -1;
}

def _translate(pat: str) -> tuple[(list[str], list[int])] {
    res: list[str] = [];
    star_indices: list[int] = [];
    i: int = 0;
    n: int = len(pat);
    while i < n {
        c: str = pat[i];
        i += 1;
        if c == "*" {
            star_indices.append(len(res));
            res.append("*");
            while i < n and pat[i] == "*" {
                i += 1;
            }
            continue;
        }
        if c == "?" {
            res.append(".");
            continue;
        }
        if c == "[" {
            j: int = i;
            if j < n and pat[j] == "!" {
                j += 1;
            }
            if j < n and pat[j] == "]" {
                j += 1;
            }
            while j < n and pat[j] != "]" {
                j += 1;
            }
            if j >= n {
                res.append("\\[");
                continue;
            }
            stuff: str = pat[i:j];
            if not ("-" in stuff) {
                stuff = stuff.replace("\\", "\\\\");
            } else {
                chunks: list[str] = [];
                k: int = i + 1;
                if pat[i] == "!" {
                    k = i + 2;
                }
                while True {
                    k = _find_in(pat, "-", k, j);
                    if k < 0 {
                        break;
                    }
                    chunks.append(pat[i:k]);
                    i = k + 1;
                    k = k + 3;
                }
                chunk: str = pat[i:j];
                if chunk != "" {
                    chunks.append(chunk);
                } else {
                    last: int = len(chunks) - 1;
                    chunks[last] = chunks[last] + "-";
                }
                k = len(chunks) - 1;
                while k > 0 {
                    prev: str = chunks[k - 1];
                    cur: str = chunks[k];
                    if prev[len(prev) - 1] > cur[0] {
                        chunks[k - 1] = prev[:len(prev) - 1] + cur[1:];
                        chunks.pop(k);
                    }
                    k -= 1;
                }
                parts: list[str] = [];
                for s in chunks {
                    parts.append(s.replace("\\", "\\\\").replace("-", "\\-"));
                }
                stuff = "-".join(parts);
            }
            i = j + 1;
            if stuff == "" {
                res.append("(?!)");
                continue;
            }
            if stuff == "!" {
                res.append(".");
                continue;
            }
            stuff = _setops_sub(stuff);
            if stuff[0] == "!" {
                stuff = "^" + stuff[1:];
            } elif stuff[0] == "^" or stuff[0] == "[" {
                stuff = "\\" + stuff;
            }
            res.append("[" + stuff + "]");
            continue;
        }
        res.append(_re_escape(c));
    }
    return (res, star_indices);
}

def:pub translate(pat: str) -> str {
    tr: tuple[(list[str], list[int])] = _translate(pat);
    parts: list[str] = tr[0];
    star_indices: list[int] = tr[1];
    if not star_indices {
        return "(?s:" + "".join(parts) + ")\\z";
    }
    buf: list[str] = [];
    j: int = star_indices[0];
    i: int = 0;
    while i < j {
        buf.append(parts[i]);
        i += 1;
    }
    i = j + 1;
    si: int = 1;
    while si < len(star_indices) {
        j = star_indices[si];
        buf.append("(?>.*?");
        while i < j {
            buf.append(parts[i]);
            i += 1;
        }
        buf.append(")");
        i = j + 1;
        si += 1;
    }
    buf.append(".*");
    while i < len(parts) {
        buf.append(parts[i]);
        i += 1;
    }
    return "(?s:" + "".join(buf) + ")\\z";
}

def:pub filter(names: list[str], pat: str) -> list[str] {
    np: str = normcase(pat);
    out: list[str] = [];
    for name in names {
        if _match(normcase(name), np) {
            out.append(name);
        }
    }
    return out;
}
