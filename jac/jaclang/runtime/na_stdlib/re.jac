glob:pub I: int = 2,
     IGNORECASE: int = 2,
     L: int = 4,
     LOCALE: int = 4,
     M: int = 8,
     MULTILINE: int = 8,
     S: int = 16,
     DOTALL: int = 16,
     U: int = 32,
     UNICODE: int = 32,
     X: int = 64,
     VERBOSE: int = 64,
     A: int = 256,
     ASCII: int = 256,
     T: int = 1,
     TEMPLATE: int = 1;

glob _K_SEQ: int = 1,
     _K_ALT: int = 2,
     _K_CHAR: int = 3,
     _K_ANY: int = 4,
     _K_CLASS: int = 5,
     _K_AT: int = 6,
     _K_GROUP: int = 7,
     _K_REP: int = 8,
     _K_BACKREF: int = 9,
     _K_LOOK: int = 10,
     _K_FLAGS: int = 11;

glob _AT_BOS: int = 1,
     _AT_BEG: int = 2,
     _AT_BEGLINE: int = 3,
     _AT_EOS: int = 4,
     _AT_END: int = 5,
     _AT_ENDLINE: int = 6,
     _AT_WB: int = 7,
     _AT_WNB: int = 8;

glob _OP_CHAR: int = 1,
     _OP_ANY: int = 2,
     _OP_CLASS: int = 3,
     _OP_SPLIT: int = 4,
     _OP_JMP: int = 5,
     _OP_MARK: int = 6,
     _OP_JMPNZ: int = 7,
     _OP_SAVE: int = 8,
     _OP_MATCH: int = 9,
     _OP_BOS: int = 10,
     _OP_BEGLINE: int = 11,
     _OP_END: int = 12,
     _OP_ENDLINE: int = 13,
     _OP_EOS: int = 14,
     _OP_WB: int = 15,
     _OP_BACKREF: int = 16,
     _OP_FPUSH: int = 17,
     _OP_FPOP: int = 18,
     _OP_LOOK: int = 19;

glob _MAXCP: int = 1114111;


def _isdig(c: int) -> bool {
    return c >= 48 and c <= 57;
}


def _isword(c: int) -> bool {
    return (c >= 48 and c <= 57)
        or (c >= 65 and c <= 90)
        or (c >= 97 and c <= 122)
        or c == 95;
}


def _isalpha(c: int) -> bool {
    return (c >= 65 and c <= 90) or (c >= 97 and c <= 122);
}


def _swap(c: int) -> int {
    if c >= 65 and c <= 90 {
        return c + 32;
    }
    if c >= 97 and c <= 122 {
        return c - 32;
    }
    return c;
}


def _hexv(c: int) -> int {
    if c >= 48 and c <= 57 {
        return c - 48;
    }
    if c >= 65 and c <= 70 {
        return c - 55;
    }
    if c >= 97 and c <= 102 {
        return c - 87;
    }
    return -1;
}


def _digit_pairs -> list[int] {
    return [48, 57];
}


def _ndigit_pairs -> list[int] {
    return [0, 47, 58, _MAXCP];
}


def _space_pairs -> list[int] {
    return [9, 13, 32, 32];
}


def _nspace_pairs -> list[int] {
    return [0, 8, 14, 31, 33, _MAXCP];
}


def _word_pairs -> list[int] {
    return [48, 57, 65, 90, 95, 95, 97, 122];
}


def _nword_pairs -> list[int] {
    return [0, 47, 58, 64, 91, 94, 96, 96, 123, _MAXCP];
}


def _in_pairs(pairs: list[int], c: int) -> bool {
    k: int = 0;
    n: int = len(pairs);
    while k + 1 < n {
        if c >= pairs[k] and c <= pairs[k + 1] {
            return True;
        }
        k += 2;
    }
    return False;
}


def _name_index(names: dict[str, int], nm: str) -> int {
    for k in names {
        if k == nm {
            return names[k];
        }
    }
    return -1;
}


obj _Node {
    has kind: int = 0,
        ch: int = 0,
        lo: int = 0,
        hi: int = -1,
        neg: bool = False,
        greedy: bool = True,
        pairs: list[int] = [],
        kids: list[_Node] = [],
        name: str = "";
}


obj _Ins {
    has op: int = 0,
        a: int = 0,
        b: int = 0;
}


obj _Cls {
    has pairs: list[int] = [],
        neg: bool = False;
}


obj _P {
    has src: str = "",
        n: int = 0,
        i: int = 0,
        flags: int = 0,
        ngroups: int = 0,
        names: dict[str, int] = {},
        pending: list[int] = [],
        pendingpos: list[int] = [],
        opengroups: list[int] = [],
        depth: int = 0,
        top_items: int = 0;

    def _err(msg: str, pos: int) {
        raise ValueError(msg + " at position " + str(pos));
    }

    def _skip_verbose {
        if (self.flags & 64) == 0 {
            return;
        }
        while self.i < self.n {
            c: int = ord(self.src[self.i]);
            if c == 32 or (c >= 9 and c <= 13) {
                self.i += 1;
                continue;
            }
            if c == 35 {
                while self.i < self.n and ord(self.src[self.i]) != 10 {
                    self.i += 1;
                }
                continue;
            }
            break;
        }
    }

    def _is_repeat_spec(pos: int) -> bool {
        if pos >= self.n or ord(self.src[pos]) != 123 {
            return False;
        }
        j: int = pos + 1;
        digs: int = 0;
        while j < self.n and _isdig(ord(self.src[j])) {
            j += 1;
            digs += 1;
        }
        if j < self.n and ord(self.src[j]) == 44 {
            j += 1;
            while j < self.n and _isdig(ord(self.src[j])) {
                j += 1;
                digs += 1;
            }
        }
        if j >= self.n or ord(self.src[j]) != 125 {
            return False;
        }
        return digs > 0 or j > pos + 2;
    }

    def _rep_spec(pos: int) -> list[int] {
        j: int = pos + 1;
        lo: int = 0;
        hi: int = -1;
        have_lo: bool = False;
        while j < self.n and _isdig(ord(self.src[j])) {
            lo = lo * 10 + (ord(self.src[j]) - 48);
            j += 1;
            have_lo = True;
        }
        if j < self.n and ord(self.src[j]) == 44 {
            j += 1;
            hi = -1;
            if j < self.n and _isdig(ord(self.src[j])) {
                hi = 0;
                while j < self.n and _isdig(ord(self.src[j])) {
                    hi = hi * 10 + (ord(self.src[j]) - 48);
                    j += 1;
                }
            }
        } else {
            hi = lo;
        }
        self.i = j + 1;
        if hi >= 0 and lo > hi {
            self._err("min repeat greater than max repeat", pos);
        }
        return [lo, hi];
    }

    def _atom -> (_Node | None) {
        c: int = ord(self.src[self.i]);
        if c == 40 {
            return self._group();
        }
        if c == 91 {
            return self._class();
        }
        if c == 46 {
            self.i += 1;
            nd: _Node = _Node();
            nd.kind = _K_ANY;
            return nd;
        }
        if c == 94 {
            self.i += 1;
            nd = _Node();
            nd.kind = _K_AT;
            nd.ch = _AT_BEGLINE if (self.flags & 8) != 0 else _AT_BEG;
            return nd;
        }
        if c == 36 {
            self.i += 1;
            nd = _Node();
            nd.kind = _K_AT;
            nd.ch = _AT_ENDLINE if (self.flags & 8) != 0 else _AT_END;
            return nd;
        }
        if c == 42 or c == 43 or c == 63 {
            self._err("nothing to repeat", self.i);
        }
        if c == 123 and self._is_repeat_spec(self.i) {
            self._err("nothing to repeat", self.i);
        }
        if c == 92 {
            return self._escape_atom();
        }
        self.i += 1;
        nd = _Node();
        nd.kind = _K_CHAR;
        nd.ch = c;
        return nd;
    }

    def _piece -> (_Node | None) {
        atom: (_Node | None) = self._atom();
        if atom is None {
            return None;
        }
        self._skip_verbose();
        if self.i >= self.n {
            return atom;
        }
        c: int = ord(self.src[self.i]);
        if c != 42 and c != 43 and c != 63 and c != 123 {
            return atom;
        }
        lo: int = 0;
        hi: int = -1;
        if c == 42 {
            self.i += 1;
        } elif c == 43 {
            lo = 1;
            self.i += 1;
        } elif c == 63 {
            hi = 1;
            self.i += 1;
        } elif c == 123 {
            if not self._is_repeat_spec(self.i) {
                return atom;
            }
            spec: list[int] = self._rep_spec(self.i);
            lo = spec[0];
            hi = spec[1];
        }
        greedy: bool = True;
        if self.i < self.n {
            nc: int = ord(self.src[self.i]);
            if nc == 63 {
                greedy = False;
                self.i += 1;
            } elif nc == 43 {
                self._err("possessive quantifiers not supported on native", self.i);
            }
        }
        if self.i < self.n {
            nc = ord(self.src[self.i]);
            if nc == 42 or nc == 43 or nc == 63 {
                self._err("multiple repeat", self.i);
            }
            if nc == 123 and self._is_repeat_spec(self.i) {
                self._err("multiple repeat", self.i);
            }
        }
        nd: _Node = _Node();
        nd.kind = _K_REP;
        nd.lo = lo;
        nd.hi = hi;
        nd.greedy = greedy;
        a2: _Node = atom;
        nd.kids.append(a2);
        return nd;
    }

    def _seq -> _Node {
        kids: list[_Node] = [];
        while True {
            self._skip_verbose();
            if self.i >= self.n {
                break;
            }
            c: int = ord(self.src[self.i]);
            if c == 124 or c == 41 {
                break;
            }
            piece: (_Node | None) = self._piece();
            if piece is None {
                continue;
            }
            kids.append(piece);
            if self.depth == 0 {
                self.top_items += 1;
            }
        }
        if len(kids) == 1 {
            return kids[0];
        }
        nd: _Node = _Node();
        nd.kind = _K_SEQ;
        nd.kids = kids;
        return nd;
    }

    def _alt -> _Node {
        first: _Node = self._seq();
        if self.i >= self.n or ord(self.src[self.i]) != 124 {
            return first;
        }
        kids: list[_Node] = [];
        kids.append(first);
        while self.i < self.n and ord(self.src[self.i]) == 124 {
            self.i += 1;
            kids.append(self._seq());
        }
        nd: _Node = _Node();
        nd.kind = _K_ALT;
        nd.kids = kids;
        return nd;
    }

    def _expect_close(open_pos: int) {
        if self.i >= self.n or ord(self.src[self.i]) != 41 {
            self._err("missing ), unterminated subpattern", open_pos);
        }
        self.i += 1;
    }

    def _flagval(c: int) -> int {
        if c == 105 {
            return 2;
        }
        if c == 109 {
            return 8;
        }
        if c == 115 {
            return 16;
        }
        if c == 120 {
            return 64;
        }
        if c == 97 {
            return 256;
        }
        if c == 117 {
            return 32;
        }
        if c == 76 {
            return 4;
        }
        return 0;
    }

    def _group -> (_Node | None) {
        p0: int = self.i;
        self.i += 1;
        if self.i >= self.n {
            self._err("missing ), unterminated subpattern", p0);
        }
        if ord(self.src[self.i]) != 63 {
            self.ngroups += 1;
            g: int = self.ngroups;
            self.opengroups.append(g);
            self.depth += 1;
            body: _Node = self._alt();
            self.depth -= 1;
            self.opengroups.pop();
            self._expect_close(p0);
            nd: _Node = _Node();
            nd.kind = _K_GROUP;
            nd.lo = g;
            nd.kids.append(body);
            return nd;
        }
        self.i += 1;
        if self.i >= self.n {
            self._err("missing ), unterminated subpattern", p0);
        }
        c2: int = ord(self.src[self.i]);
        if c2 == 58 {
            self.i += 1;
            self.depth += 1;
            body = self._alt();
            self.depth -= 1;
            self._expect_close(p0);
            return body;
        }
        if c2 == 35 {
            while self.i < self.n and ord(self.src[self.i]) != 41 {
                self.i += 1;
            }
            self._expect_close(p0);
            return None;
        }
        if c2 == 61 or c2 == 33 {
            neg: bool = c2 == 33;
            self.i += 1;
            self.depth += 1;
            body = self._alt();
            self.depth -= 1;
            self._expect_close(p0);
            nd = _Node();
            nd.kind = _K_LOOK;
            nd.lo = 1 if neg else 0;
            nd.kids.append(body);
            return nd;
        }
        if c2 == 80 {
            self.i += 1;
            if self.i < self.n and ord(self.src[self.i]) == 60 {
                self.i += 1;
                nstart: int = self.i;
                while self.i < self.n and ord(self.src[self.i]) != 62 {
                    self.i += 1;
                }
                if self.i >= self.n {
                    self._err("missing ), unterminated subpattern", p0);
                }
                nm: str = self.src[nstart:self.i];
                if len(nm) == 0 {
                    self._err("missing group name", self.i);
                }
                ok: bool = True;
                k: int = 0;
                while k < len(nm) {
                    cc: int = ord(nm[k]);
                    if not _isword(cc) or (k == 0 and _isdig(cc)) {
                        ok = False;
                    }
                    k += 1;
                }
                if not ok {
                    self._err("bad character in group name '" + nm + "'", nstart);
                }
                self.i += 1;
                old: int = _name_index(self.names, nm);
                if old >= 0 {
                    self._err(
                        "redefinition of group name '"
                            + nm
                            + "' as group "
                            + str(self.ngroups + 1)
                            + "; was group "
                            + str(old),
                        self.i - 1
                    );
                }
                self.ngroups += 1;
                g = self.ngroups;
                self.names[nm] = g;
                self.opengroups.append(g);
                self.depth += 1;
                body = self._alt();
                self.depth -= 1;
                self.opengroups.pop();
                self._expect_close(p0);
                nd = _Node();
                nd.kind = _K_GROUP;
                nd.lo = g;
                nd.name = nm;
                nd.kids.append(body);
                return nd;
            }
            if self.i < self.n and ord(self.src[self.i]) == 61 {
                self.i += 1;
                ns2: int = self.i;
                while self.i < self.n and ord(self.src[self.i]) != 41 {
                    self.i += 1;
                }
                if self.i >= self.n {
                    self._err("missing ), unterminated subpattern", p0);
                }
                nm2: str = self.src[ns2:self.i];
                self.i += 1;
                gnum2: int = _name_index(self.names, nm2);
                if gnum2 < 0 {
                    self._err("unknown group name '" + nm2 + "'", ns2);
                }
                nd = _Node();
                nd.kind = _K_BACKREF;
                nd.lo = gnum2;
                return nd;
            }
            self._err("unknown extension ?P", p0 + 1);
        }
        if c2 == 60 {
            if self.i + 1 < self.n {
                c3: int = ord(self.src[self.i + 1]);
                if c3 == 61 or c3 == 33 {
                    self._err("lookbehind not supported on native", self.i);
                }
                self._err("unknown extension ?<" + self.src[self.i + 1], p0 + 1);
            }
            self._err("unknown extension ?<", p0 + 1);
        }
        if c2 == 40 {
            self._err("unknown extension ?(", p0 + 1);
        }
        if c2 == 35 {
            while self.i < self.n and ord(self.src[self.i]) != 41 {
                self.i += 1;
            }
            if self.i >= self.n {
                self._err("missing ), unterminated comment", p0);
            }
            self.i += 1;
            return None;
        }
        fv: int = self._flagval(c2);
        if fv != 0 or c2 == 45 or c2 == 58 {
            newf: int = self.flags;
            j: int = self.i;
            while j < self.n {
                fch: int = self._flagval(ord(self.src[j]));
                if fch == 0 {
                    break;
                }
                newf = newf | fch;
                j += 1;
            }
            if j < self.n and ord(self.src[j]) == 45 {
                j += 1;
                while j < self.n {
                    fch = self._flagval(ord(self.src[j]));
                    if fch == 0 {
                        break;
                    }
                    if (newf & fch) != 0 {
                        newf -= fch;
                    }
                    j += 1;
                }
            }
            if j < self.n and ord(self.src[j]) == 41 {
                self.i = j + 1;
                if self.depth > 0 or self.top_items > 0 {
                    self._err("global flags not at the start of the expression", p0);
                }
                self.flags = newf;
                return None;
            }
            if j < self.n and ord(self.src[j]) == 58 {
                self.i = j + 1;
                saved: int = self.flags;
                self.flags = newf;
                self.depth += 1;
                body = self._alt();
                self.depth -= 1;
                self._expect_close(p0);
                self.flags = saved;
                nd = _Node();
                nd.kind = _K_FLAGS;
                nd.lo = newf;
                nd.kids.append(body);
                return nd;
            }
            self._err("missing -, : or )", j);
        }
        self._err("unknown extension ?" + self.src[self.i], p0 + 1);
        return None;
    }

    def _class_item(pairs: list[int]) -> int {
        c: int = ord(self.src[self.i]);
        if c == 92 {
            bp: int = self.i;
            self.i += 1;
            if self.i >= self.n {
                self._err("bad escape (end of pattern)", bp);
            }
            e: int = ord(self.src[self.i]);
            self.i += 1;
            if e == 100 {
                pp: list[int] = _digit_pairs();
                k: int = 0;
                while k < len(pp) {
                    pairs.append(pp[k]);
                    k += 1;
                }
                return -1;
            }
            if e == 68 {
                pp = _ndigit_pairs();
                k = 0;
                while k < len(pp) {
                    pairs.append(pp[k]);
                    k += 1;
                }
                return -1;
            }
            if e == 115 {
                pp = _space_pairs();
                k = 0;
                while k < len(pp) {
                    pairs.append(pp[k]);
                    k += 1;
                }
                return -1;
            }
            if e == 83 {
                pp = _nspace_pairs();
                k = 0;
                while k < len(pp) {
                    pairs.append(pp[k]);
                    k += 1;
                }
                return -1;
            }
            if e == 119 {
                pp = _word_pairs();
                k = 0;
                while k < len(pp) {
                    pairs.append(pp[k]);
                    k += 1;
                }
                return -1;
            }
            if e == 87 {
                pp = _nword_pairs();
                k = 0;
                while k < len(pp) {
                    pairs.append(pp[k]);
                    k += 1;
                }
                return -1;
            }
            if e == 98 {
                return 8;
            }
            if e == 110 {
                return 10;
            }
            if e == 114 {
                return 13;
            }
            if e == 116 {
                return 9;
            }
            if e == 102 {
                return 12;
            }
            if e == 118 {
                return 11;
            }
            if e == 97 {
                return 7;
            }
            if e >= 48 and e <= 55 {
                v: int = e - 48;
                cnt: int = 1;
                while cnt < 3 and self.i < self.n {
                    d: int = ord(self.src[self.i]);
                    if d < 48 or d > 55 {
                        break;
                    }
                    v = v * 8 + (d - 48);
                    self.i += 1;
                    cnt += 1;
                }
                return v & _MAXCP;
            }
            if e == 56 or e == 57 {
                self._err("bad escape \\" + self.src[self.i - 1], bp);
            }
            if e == 120 {
                if self.i + 1 >= self.n {
                    self._err("bad escape \\x", bp);
                }
                h1: int = _hexv(ord(self.src[self.i]));
                h2: int = _hexv(ord(self.src[self.i + 1]));
                if h1 < 0 or h2 < 0 {
                    self._err("bad escape \\x", bp);
                }
                self.i += 2;
                return h1 * 16 + h2;
            }
            if e == 117 {
                if self.i + 3 >= self.n {
                    self._err("bad escape \\u", bp);
                }
                v = 0;
                k = 0;
                while k < 4 {
                    hv: int = _hexv(ord(self.src[self.i + k]));
                    if hv < 0 {
                        self._err("bad escape \\u", bp);
                    }
                    v = v * 16 + hv;
                    k += 1;
                }
                self.i += 4;
                return v;
            }
            if _isalpha(e) {
                self._err("bad escape \\" + self.src[self.i - 1], bp);
            }
            return e;
        }
        self.i += 1;
        return c;
    }

    def _class -> _Node {
        p0: int = self.i;
        self.i += 1;
        nd: _Node = _Node();
        nd.kind = _K_CLASS;
        pairs: list[int] = [];
        first: bool = True;
        if self.i < self.n and ord(self.src[self.i]) == 94 {
            nd.neg = True;
            self.i += 1;
        }
        while True {
            if self.i >= self.n {
                self._err("unterminated character set", p0);
            }
            if ord(self.src[self.i]) == 93 and not first {
                self.i += 1;
                break;
            }
            lo_pos: int = self.i;
            lo: int = self._class_item(pairs);
            first = False;
            if lo < 0 {
                continue;
            }
            if self.i < self.n and ord(self.src[self.i]) == 45 {
                if self.i + 1 < self.n and ord(self.src[self.i + 1]) != 93 {
                    self.i += 1;
                    hi: int = self._class_item(pairs);
                    if hi < 0 {
                        pairs.append(lo);
                        pairs.append(lo);
                        pairs.append(45);
                        pairs.append(45);
                        continue;
                    }
                    if hi < lo {
                        self._err(
                            "bad character range " + chr(lo) + "-" + chr(hi), lo_pos
                        );
                    }
                    pairs.append(lo);
                    pairs.append(hi);
                    continue;
                }
                pairs.append(lo);
                pairs.append(lo);
                pairs.append(45);
                pairs.append(45);
                self.i += 1;
                continue;
            }
            pairs.append(lo);
            pairs.append(lo);
        }
        nd.pairs = pairs;
        return nd;
    }

    def _escape_atom -> _Node {
        bp: int = self.i;
        self.i += 1;
        if self.i >= self.n {
            self._err("bad escape (end of pattern)", bp);
        }
        e: int = ord(self.src[self.i]);
        self.i += 1;
        nd: _Node = _Node();
        if e == 65 {
            nd.kind = _K_AT;
            nd.ch = _AT_BOS;
            return nd;
        }
        if e == 90 {
            nd.kind = _K_AT;
            nd.ch = _AT_EOS;
            return nd;
        }
        if e == 98 {
            nd.kind = _K_AT;
            nd.ch = _AT_WB;
            return nd;
        }
        if e == 66 {
            nd.kind = _K_AT;
            nd.ch = _AT_WNB;
            return nd;
        }
        if e == 100 {
            nd.kind = _K_CLASS;
            nd.pairs = _digit_pairs();
            return nd;
        }
        if e == 68 {
            nd.kind = _K_CLASS;
            nd.pairs = _ndigit_pairs();
            return nd;
        }
        if e == 115 {
            nd.kind = _K_CLASS;
            nd.pairs = _space_pairs();
            return nd;
        }
        if e == 83 {
            nd.kind = _K_CLASS;
            nd.pairs = _nspace_pairs();
            return nd;
        }
        if e == 119 {
            nd.kind = _K_CLASS;
            nd.pairs = _word_pairs();
            return nd;
        }
        if e == 87 {
            nd.kind = _K_CLASS;
            nd.pairs = _nword_pairs();
            return nd;
        }
        if e >= 48 and e <= 57 {
            if e == 48 {
                v: int = 0;
                cnt: int = 0;
                while cnt < 2 and self.i < self.n {
                    d: int = ord(self.src[self.i]);
                    if d < 48 or d > 55 {
                        break;
                    }
                    v = v * 8 + (d - 48);
                    self.i += 1;
                    cnt += 1;
                }
                nd.kind = _K_CHAR;
                nd.ch = v;
                return nd;
            }
            num: int = e - 48;
            while self.i < self.n and _isdig(ord(self.src[self.i])) {
                num = num * 10 + (ord(self.src[self.i]) - 48);
                self.i += 1;
            }
            og: int = 0;
            while og < len(self.opengroups) {
                if self.opengroups[og] == num {
                    self._err("cannot refer to an open group", bp);
                }
                og += 1;
            }
            self.pending.append(num);
            self.pendingpos.append(bp);
            nd.kind = _K_BACKREF;
            nd.lo = num;
            return nd;
        }
        if e == 120 {
            if self.i + 1 >= self.n {
                self._err("bad escape \\x", bp);
            }
            h1: int = _hexv(ord(self.src[self.i]));
            h2: int = _hexv(ord(self.src[self.i + 1]));
            if h1 < 0 or h2 < 0 {
                self._err("bad escape \\x", bp);
            }
            self.i += 2;
            nd.kind = _K_CHAR;
            nd.ch = h1 * 16 + h2;
            return nd;
        }
        if e == 117 {
            if self.i + 3 >= self.n {
                self._err("bad escape \\u", bp);
            }
            v = 0;
            k: int = 0;
            while k < 4 {
                hv: int = _hexv(ord(self.src[self.i + k]));
                if hv < 0 {
                    self._err("bad escape \\u", bp);
                }
                v = v * 16 + hv;
                k += 1;
            }
            self.i += 4;
            nd.kind = _K_CHAR;
            nd.ch = v;
            return nd;
        }
        if e == 85 {
            if self.i + 7 >= self.n {
                self._err("bad escape \\U", bp);
            }
            v = 0;
            k = 0;
            while k < 8 {
                hv = _hexv(ord(self.src[self.i + k]));
                if hv < 0 {
                    self._err("bad escape \\U", bp);
                }
                v = v * 16 + hv;
                k += 1;
            }
            self.i += 8;
            nd.kind = _K_CHAR;
            nd.ch = v;
            return nd;
        }
        if e == 78 {
            if self.i < self.n and ord(self.src[self.i]) == 123 {
                j: int = self.i + 1;
                while j < self.n and ord(self.src[j]) != 125 {
                    j += 1;
                }
                if j < self.n {
                    nm: str = self.src[self.i + 1:j];
                    self._err("undefined character name '" + nm + "'", bp);
                }
            }
            self._err("bad escape \\N", bp);
        }
        if e == 110 {
            nd.kind = _K_CHAR;
            nd.ch = 10;
            return nd;
        }
        if e == 114 {
            nd.kind = _K_CHAR;
            nd.ch = 13;
            return nd;
        }
        if e == 116 {
            nd.kind = _K_CHAR;
            nd.ch = 9;
            return nd;
        }
        if e == 102 {
            nd.kind = _K_CHAR;
            nd.ch = 12;
            return nd;
        }
        if e == 118 {
            nd.kind = _K_CHAR;
            nd.ch = 11;
            return nd;
        }
        if e == 97 {
            nd.kind = _K_CHAR;
            nd.ch = 7;
            return nd;
        }
        if _isalpha(e) {
            self._err("bad escape \\" + self.src[self.i - 1], bp);
        }
        nd.kind = _K_CHAR;
        nd.ch = e;
        return nd;
    }

    def _parse -> _Node {
        nd: _Node = self._alt();
        if self.i < self.n {
            self._err("unbalanced parenthesis", self.i);
        }
        k: int = 0;
        while k < len(self.pending) {
            if self.pending[k] > self.ngroups {
                self._err(
                    "invalid group reference " + str(self.pending[k]),
                    self.pendingpos[k]
                );
            }
            k += 1;
        }
        return nd;
    }
}


obj _C {
    has prog: list[_Ins] = [],
        classes: list[_Cls] = [],
        nmarks: int = 0;
}


def _emit(c: _C, op: int, a: int, b: int) -> int {
    ins: _Ins = _Ins();
    ins.op = op;
    ins.a = a;
    ins.b = b;
    c.prog.append(ins);
    return len(c.prog) - 1;
}


def _compile_node(nd: _Node, c: _C) {
    kind: int = nd.kind;
    if kind == _K_SEQ {
        i: int = 0;
        while i < len(nd.kids) {
            _compile_node(nd.kids[i], c);
            i += 1;
        }
        return;
    }
    if kind == _K_ALT {
        ejects: list[int] = [];
        last: int = len(nd.kids) - 1;
        j: int = 0;
        while j < last {
            si: int = _emit(c, _OP_SPLIT, len(c.prog) + 1, 0);
            ejects.append(si);
            _compile_node(nd.kids[j], c);
            ji: int = _emit(c, _OP_JMP, 0, 0);
            ejects.append(ji);
            j += 1;
        }
        _compile_node(nd.kids[last], c);
        e: int = len(c.prog);
        k: int = 0;
        while k < len(ejects) {
            ins: _Ins = c.prog[ejects[k]];
            if ins.op == _OP_SPLIT {
                ins.b = e;
            } else {
                ins.a = e;
            }
            k += 1;
        }
        return;
    }
    if kind == _K_CHAR {
        _emit(c, _OP_CHAR, nd.ch, 0);
        return;
    }
    if kind == _K_ANY {
        _emit(c, _OP_ANY, 0, 0);
        return;
    }
    if kind == _K_CLASS {
        cl: _Cls = _Cls();
        cl.pairs = nd.pairs;
        cl.neg = nd.neg;
        c.classes.append(cl);
        _emit(c, _OP_CLASS, len(c.classes) - 1, 0);
        return;
    }
    if kind == _K_AT {
        op: int = _OP_BOS;
        if nd.ch == _AT_BEGLINE {
            op = _OP_BEGLINE;
        } elif nd.ch == _AT_END {
            op = _OP_END;
        } elif nd.ch == _AT_ENDLINE {
            op = _OP_ENDLINE;
        } elif nd.ch == _AT_EOS {
            op = _OP_EOS;
        } elif nd.ch == _AT_WB {
            _emit(c, _OP_WB, 0, 0);
            return;
        } elif nd.ch == _AT_WNB {
            _emit(c, _OP_WB, 1, 0);
            return;
        }
        _emit(c, op, 0, 0);
        return;
    }
    if kind == _K_GROUP {
        _emit(c, _OP_SAVE, nd.lo * 2, 0);
        _compile_node(nd.kids[0], c);
        _emit(c, _OP_SAVE, nd.lo * 2 + 1, 0);
        return;
    }
    if kind == _K_REP {
        kid: _Node = nd.kids[0];
        m: int = 0;
        while m < nd.lo {
            _compile_node(kid, c);
            m += 1;
        }
        if nd.hi < 0 {
            lpos: int = len(c.prog);
            si: int = 0;
            if nd.greedy {
                si = _emit(c, _OP_SPLIT, lpos + 1, 0);
            } else {
                si = _emit(c, _OP_SPLIT, 0, lpos + 1);
            }
            mark: int = c.nmarks;
            c.nmarks += 1;
            _emit(c, _OP_MARK, mark, 0);
            _compile_node(kid, c);
            _emit(c, _OP_JMPNZ, mark, lpos);
            epos: int = len(c.prog);
            tins: _Ins = c.prog[si];
            if nd.greedy {
                tins.b = epos;
            } else {
                tins.a = epos;
            }
            return;
        }
        splits: list[int] = [];
        j: int = nd.lo;
        while j < nd.hi {
            si2: int = 0;
            if nd.greedy {
                si2 = _emit(c, _OP_SPLIT, len(c.prog) + 1, 0);
            } else {
                si2 = _emit(c, _OP_SPLIT, 0, len(c.prog) + 1);
            }
            splits.append(si2);
            _compile_node(kid, c);
            j += 1;
        }
        epos = len(c.prog);
        k = 0;
        while k < len(splits) {
            tins = c.prog[splits[k]];
            if nd.greedy {
                tins.b = epos;
            } else {
                tins.a = epos;
            }
            k += 1;
        }
        return;
    }
    if kind == _K_BACKREF {
        _emit(c, _OP_BACKREF, nd.lo, 0);
        return;
    }
    if kind == _K_LOOK {
        li: int = _emit(c, _OP_LOOK, 0, nd.lo);
        ji: int = _emit(c, _OP_JMP, 0, 0);
        lins: _Ins = c.prog[li];
        lins.a = len(c.prog);
        _compile_node(nd.kids[0], c);
        _emit(c, _OP_MATCH, 0, 0);
        jins: _Ins = c.prog[ji];
        jins.a = len(c.prog);
        return;
    }
    if kind == _K_FLAGS {
        _emit(c, _OP_FPUSH, nd.lo, 0);
        _compile_node(nd.kids[0], c);
        _emit(c, _OP_FPOP, 0, 0);
        return;
    }
}


obj _Re {
    has prog: list[_Ins] = [],
        classes: list[_Cls] = [],
        ngroups: int = 0,
        names: dict[str, int] = {},
        nmarks: int = 0,
        flags: int = 0,
        pattern: str = "";
}


obj _St {
    has s: str = "",
        n: int = 0,
        slots: list[int] = [],
        marks: list[int] = [],
        fstack: list[int] = [],
        flags: int = 0;
}


def _run(re: _Re, st: _St, pc0: int, pos0: int) -> int {
    pc: int = pc0;
    pos: int = pos0;
    s: str = st.s;
    n: int = st.n;
    prog: list[_Ins] = re.prog;
    while True {
        ins: _Ins = prog[pc];
        op: int = ins.op;
        if op == _OP_CHAR {
            if pos < n {
                c0: int = ord(s[pos]);
                if c0 == ins.a or ((st.flags & 2) != 0 and _swap(c0) == ins.a) {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            }
            return -1;
        }
        if op == _OP_ANY {
            if pos < n and ((st.flags & 16) != 0 or ord(s[pos]) != 10) {
                pos += 1;
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_CLASS {
            if pos < n {
                cl: _Cls = re.classes[ins.a];
                c1: int = ord(s[pos]);
                hit: bool = _in_pairs(cl.pairs, c1);
                if not hit and (st.flags & 2) != 0 {
                    hit = _in_pairs(cl.pairs, _swap(c1));
                }
                if hit != cl.neg {
                    pos += 1;
                    pc += 1;
                    continue;
                }
            }
            return -1;
        }
        if op == _OP_SPLIT {
            r: int = _run(re, st, ins.a, pos);
            if r >= 0 {
                return r;
            }
            pc = ins.b;
            continue;
        }
        if op == _OP_JMP {
            pc = ins.a;
            continue;
        }
        if op == _OP_MARK {
            st.marks[ins.a] = pos;
            pc += 1;
            continue;
        }
        if op == _OP_JMPNZ {
            if st.marks[ins.a] != pos {
                pc = ins.b;
            } else {
                pc += 1;
            }
            continue;
        }
        if op == _OP_SAVE {
            old: int = st.slots[ins.a];
            st.slots[ins.a] = pos;
            r2: int = _run(re, st, pc + 1, pos);
            if r2 < 0 {
                st.slots[ins.a] = old;
                return -1;
            }
            return r2;
        }
        if op == _OP_MATCH {
            return pos;
        }
        if op == _OP_BOS {
            if pos == 0 {
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_BEGLINE {
            if pos == 0 or ord(s[pos - 1]) == 10 {
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_END {
            if pos == n or (pos == n - 1 and ord(s[pos]) == 10) {
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_ENDLINE {
            if pos == n or (pos < n and ord(s[pos]) == 10) {
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_EOS {
            if pos == n {
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_WB {
            lft: bool = pos > 0 and _isword(ord(s[pos - 1]));
            rgt: bool = pos < n and _isword(ord(s[pos]));
            if (lft != rgt) == (ins.a == 0) {
                pc += 1;
                continue;
            }
            return -1;
        }
        if op == _OP_BACKREF {
            g: int = ins.a * 2;
            lo: int = st.slots[g];
            hi: int = st.slots[g + 1];
            if lo < 0 or hi < lo {
                return -1;
            }
            ln: int = hi - lo;
            if pos + ln > n {
                return -1;
            }
            k2: int = 0;
            ok: bool = True;
            while k2 < ln {
                ca: int = ord(s[lo + k2]);
                cb: int = ord(s[pos + k2]);
                if ca != cb and ((st.flags & 2) == 0 or _swap(ca) != cb) {
                    ok = False;
                    break;
                }
                k2 += 1;
            }
            if not ok {
                return -1;
            }
            pos += ln;
            pc += 1;
            continue;
        }
        if op == _OP_FPUSH {
            st.fstack.append(st.flags);
            st.flags = ins.a;
            r3: int = _run(re, st, pc + 1, pos);
            if r3 < 0 {
                st.flags = st.fstack.pop();
                return -1;
            }
            return r3;
        }
        if op == _OP_FPOP {
            if len(st.fstack) > 0 {
                st.flags = st.fstack.pop();
            }
            pc += 1;
            continue;
        }
        if op == _OP_LOOK {
            if ins.b == 0 {
                r4: int = _run(re, st, ins.a, pos);
                if r4 < 0 {
                    return -1;
                }
                pc += 1;
                continue;
            }
            saved: list[int] = [];
            si: int = 0;
            while si < len(st.slots) {
                saved.append(st.slots[si]);
                si += 1;
            }
            r5: int = _run(re, st, ins.a, pos);
            j2: int = 0;
            while j2 < len(st.slots) {
                st.slots[j2] = saved[j2];
                j2 += 1;
            }
            if r5 >= 0 {
                return -1;
            }
            pc += 1;
            continue;
        }
        return -1;
    }
}


def _new_st(s: str, n: int, re: _Re) -> _St {
    st: _St = _St();
    st.s = s;
    st.n = n;
    st.flags = re.flags;
    st.slots = [];
    i: int = 0;
    while i < (re.ngroups + 1) * 2 {
        st.slots.append(-1);
        i += 1;
    }
    st.marks = [];
    i = 0;
    while i < re.nmarks {
        st.marks.append(-1);
        i += 1;
    }
    st.fstack = [];
    return st;
}


def _reset_slots(st: _St) {
    i: int = 0;
    while i < len(st.slots) {
        st.slots[i] = -1;
        i += 1;
    }
}


obj:pub Match {
    has _re: _Re,
        string: str = "",
        pos: int = 0,
        endpos: int = 0,
        _slots: list[int] = [];

    def init(_re: _Re, string: str, pos: int, endpos: int, slots: list[int]) {
        self._re = _re;
        self.string = string;
        self.pos = pos;
        self.endpos = endpos;
        self._slots = slots;
    }

    def _gnum(i: any) -> int {
        if isinstance(i, int) {
            iv: int = i;
            if iv < 0 or iv > self._re.ngroups {
                raise IndexError("no such group");
            }
            return iv;
        }
        if isinstance(i, str) {
            sv: str = i;
            gn: int = _name_index(self._re.names, sv);
            if gn >= 0 {
                return gn;
            }
            raise IndexError("no such group");
        }
        raise IndexError("no such group");
    }

    def group(i: any = 0) -> any {
        g: int = self._gnum(i);
        lo: int = self._slots[g * 2];
        hi: int = self._slots[g * 2 + 1];
        if lo < 0 or hi < lo {
            return None;
        }
        return self.string[lo:hi];
    }

    def groups(`default: any = None) -> list[any] {
        out: list[any] = [];
        g: int = 1;
        while g <= self._re.ngroups {
            lo: int = self._slots[g * 2];
            hi: int = self._slots[g * 2 + 1];
            if lo < 0 or hi < lo {
                out.append(`default);
            } else {
                out.append(self.string[lo:hi]);
            }
            g += 1;
        }
        return out;
    }

    def groupdict(`default: any = None) -> dict[str, any] {
        out: dict[str, any] = {};
        for nm in self._re.names {
            g: int = self._re.names[nm];
            lo: int = self._slots[g * 2];
            hi: int = self._slots[g * 2 + 1];
            if lo < 0 or hi < lo {
                out[nm] = `default;
            } else {
                out[nm] = self.string[lo:hi];
            }
        }
        return out;
    }

    def start(i: any = 0) -> int {
        g: int = self._gnum(i);
        return self._slots[g * 2];
    }

    def end(i: any = 0) -> int {
        g: int = self._gnum(i);
        return self._slots[g * 2 + 1];
    }

    def span(i: any = 0) -> tuple[(int, int)] {
        g: int = self._gnum(i);
        return (self._slots[g * 2], self._slots[g * 2 + 1]);
    }

    def expand(template: str) -> str {
        return _expand_repl(template, self, self._re);
    }
}


obj:pub Pattern {
    has _re: _Re,
        pattern: str = "",
        flags: int = 0,
        groups: int = 0,
        groupindex: dict[str, int] = {};

    def init(pattern: str, flags: int = 0) {
        self.pattern = pattern;
        self.flags = flags;
        self._re = _compile_re(pattern, flags);
        self.groups = self._re.ngroups;
        self.groupindex = self._re.names;
    }

    def _search_from(string: str, start: int, endpos: int) -> (Match | None) {
        st: _St = _new_st(string, endpos, self._re);
        p: int = start;
        while p <= endpos {
            _reset_slots(st);
            st.flags = self._re.flags;
            r: int = _run(self._re, st, 0, p);
            if r >= 0 {
                st.slots[0] = p;
                st.slots[1] = r;
                return Match(self._re, string, start, endpos, st.slots);
            }
            p += 1;
        }
        return None;
    }

    def search(string: str, pos: int = 0, endpos: int = -1) -> (Match | None) {
        n: int = len(string);
        if endpos < 0 or endpos > n {
            endpos = n;
        }
        if pos < 0 {
            pos = 0;
        }
        if pos > n {
            pos = n;
        }
        if pos > endpos {
            return None;
        }
        return self._search_from(string, pos, endpos);
    }

    def `match(string: str, pos: int = 0, endpos: int = -1) -> (Match | None) {
        n: int = len(string);
        if endpos < 0 or endpos > n {
            endpos = n;
        }
        if pos < 0 {
            pos = 0;
        }
        if pos > n {
            pos = n;
        }
        if pos > endpos {
            return None;
        }
        st: _St = _new_st(string, endpos, self._re);
        r: int = _run(self._re, st, 0, pos);
        if r < 0 {
            return None;
        }
        st.slots[0] = pos;
        st.slots[1] = r;
        return Match(self._re, string, pos, endpos, st.slots);
    }

    def fullmatch(string: str, pos: int = 0, endpos: int = -1) -> (Match | None) {
        m: (Match | None) = self.match(string, pos, endpos);
        if m is None {
            return None;
        }
        m2: Match = m;
        if m2._slots[1] != m2.endpos {
            return None;
        }
        return m2;
    }

    def finditer(string: str, pos: int = 0, endpos: int = -1) -> list[Match] {
        n: int = len(string);
        if endpos < 0 or endpos > n {
            endpos = n;
        }
        if pos < 0 {
            pos = 0;
        }
        if pos > n {
            pos = n;
        }
        out: list[Match] = [];
        p: int = pos;
        while p <= endpos {
            m: (Match | None) = self._search_from(string, p, endpos);
            if m is None {
                break;
            }
            m2: Match = m;
            m2.pos = pos;
            out.append(m2);
            e: int = m2._slots[1];
            if e > p {
                p = e;
            } else {
                p = e + 1;
            }
        }
        return out;
    }

    def findall(string: str, pos: int = 0, endpos: int = -1) -> list[str] {
        ms: list[Match] = self.finditer(string, pos, endpos);
        out: list[str] = [];
        i: int = 0;
        while i < len(ms) {
            m: Match = ms[i];
            if self._re.ngroups == 0 {
                out.append(m.string[m._slots[0]:m._slots[1]]);
            } elif self._re.ngroups == 1 {
                lo: int = m._slots[2];
                hi: int = m._slots[3];
                if lo < 0 or hi < lo {
                    out.append("");
                } else {
                    out.append(m.string[lo:hi]);
                }
            } else {
                raise ValueError(
                    "findall: patterns with more than one group are not supported on native"
                );
            }
            i += 1;
        }
        return out;
    }

    def split(string: str, maxsplit: int = 0) -> list[any] {
        n: int = len(string);
        out: list[any] = [];
        last: int = 0;
        count: int = 0;
        p: int = 0;
        while p <= n {
            m: (Match | None) = self._search_from(string, p, n);
            if m is None {
                break;
            }
            m2: Match = m;
            if maxsplit > 0 and count >= maxsplit {
                break;
            }
            out.append(string[last:m2._slots[0]]);
            g: int = 1;
            while g <= self._re.ngroups {
                lo: int = m2._slots[g * 2];
                hi: int = m2._slots[g * 2 + 1];
                if lo < 0 or hi < lo {
                    out.append(None);
                } else {
                    out.append(string[lo:hi]);
                }
                g += 1;
            }
            last = m2._slots[1];
            count += 1;
            e: int = m2._slots[1];
            if e > p {
                p = e;
            } else {
                p = e + 1;
            }
        }
        out.append(string[last:n]);
        return out;
    }

    def _subn(repl: str, string: str, count: int) -> tuple[(str, int)] {
        n: int = len(string);
        out: str = "";
        last: int = 0;
        nsub: int = 0;
        p: int = 0;
        while p <= n {
            if count != 0 and nsub >= count {
                break;
            }
            m: (Match | None) = self._search_from(string, p, n);
            if m is None {
                break;
            }
            m2: Match = m;
            out += string[last:m2._slots[0]];
            out += _expand_repl(repl, m2, self._re);
            nsub += 1;
            last = m2._slots[1];
            e: int = m2._slots[1];
            if e > p {
                p = e;
            } else {
                p = e + 1;
            }
        }
        out += string[last:n];
        return (out, nsub);
    }

    def sub(repl: str, string: str, count: int = 0) -> str {
        r: tuple[(str, int)] = self._subn(repl, string, count);
        return r[0];
    }

    def subn(repl: str, string: str, count: int = 0) -> tuple[(str, int)] {
        return self._subn(repl, string, count);
    }
}


def _compile_re(pattern: str, flags: int) -> _Re {
    p: _P = _P();
    p.src = pattern;
    p.n = len(pattern);
    p.flags = flags;
    tree: _Node = p._parse();
    c: _C = _C();
    _compile_node(tree, c);
    _emit(c, _OP_MATCH, 0, 0);
    re: _Re = _Re();
    re.prog = c.prog;
    re.classes = c.classes;
    re.ngroups = p.ngroups;
    re.names = p.names;
    re.nmarks = c.nmarks;
    re.flags = p.flags;
    re.pattern = pattern;
    return re;
}


def _expand_repl(template: str, m: Match, re: _Re) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(template);
    while i < n {
        c: int = ord(template[i]);
        if c != 92 {
            out += template[i];
            i += 1;
            continue;
        }
        bp: int = i;
        i += 1;
        if i >= n {
            raise ValueError("bad escape (end of pattern) at position " + str(bp));
        }
        e: int = ord(template[i]);
        i += 1;
        if e == 103 {
            if i >= n or ord(template[i]) != 60 {
                raise ValueError("missing < at position " + str(i));
            }
            i += 1;
            j: int = i;
            while j < n and ord(template[j]) != 62 {
                j += 1;
            }
            if j >= n {
                raise ValueError("missing unterminated name at position " + str(i));
            }
            nm: str = template[i:j];
            i = j + 1;
            num: int = -1;
            if len(nm) > 0 {
                alldig: bool = True;
                k: int = 0;
                while k < len(nm) {
                    if not _isdig(ord(nm[k])) {
                        alldig = False;
                    }
                    k += 1;
                }
                if alldig {
                    num = 0;
                    k = 0;
                    while k < len(nm) {
                        num = num * 10 + (ord(nm[k]) - 48);
                        k += 1;
                    }
                }
            }
            if num < 0 {
                num = _name_index(re.names, nm);
                if num < 0 {
                    raise ValueError(
                        "unknown group name '"
                            + nm
                            + "' at position "
                            + str(j - len(nm))
                    );
                }
            }
            if num > re.ngroups {
                raise ValueError(
                    "invalid group reference "
                        + str(num)
                        + " at position "
                        + str(j - len(nm))
                );
            }
            out += _gtext(m, num);
            continue;
        }
        if e >= 49 and e <= 57 {
            num = e - 48;
            if i < n and _isdig(ord(template[i])) {
                num = num * 10 + (ord(template[i]) - 48);
                i += 1;
            }
            if num > re.ngroups {
                raise ValueError(
                    "invalid group reference " + str(num) + " at position " + str(bp)
                );
            }
            out += _gtext(m, num);
            continue;
        }
        if e == 48 {
            v: int = 0;
            cnt: int = 0;
            while cnt < 3 and i < n {
                d: int = ord(template[i]);
                if d < 48 or d > 55 {
                    break;
                }
                v = v * 8 + (d - 48);
                i += 1;
                cnt += 1;
            }
            out += chr(v);
            continue;
        }
        if e == 120 {
            if i + 1 >= n {
                raise ValueError("bad escape \\x at position " + str(bp));
            }
            h1: int = _hexv(ord(template[i]));
            h2: int = _hexv(ord(template[i + 1]));
            if h1 < 0 or h2 < 0 {
                raise ValueError("bad escape \\x at position " + str(bp));
            }
            i += 2;
            out += chr(h1 * 16 + h2);
            continue;
        }
        if e == 110 {
            out += "\n";
            continue;
        }
        if e == 114 {
            out += "\r";
            continue;
        }
        if e == 116 {
            out += "\t";
            continue;
        }
        if e == 102 {
            out += "\x0c";
            continue;
        }
        if e == 118 {
            out += "\x0b";
            continue;
        }
        if e == 97 {
            out += "\x07";
            continue;
        }
        if _isalpha(e) {
            raise ValueError(
                "bad escape \\" + template[bp + 1] + " at position " + str(bp)
            );
        }
        out += template[bp + 1];
    }
    return out;
}


def _gtext(m: Match, num: int) -> str {
    lo: int = m._slots[num * 2];
    hi: int = m._slots[num * 2 + 1];
    if lo < 0 or hi < lo {
        return "";
    }
    return m.string[lo:hi];
}


def:pub compile(pattern: str, flags: int = 0) -> Pattern {
    return Pattern(pattern, flags);
}


def:pub search(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    p: Pattern = Pattern(pattern, flags);
    return p.search(string);
}


def:pub `match(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    p: Pattern = Pattern(pattern, flags);
    return p.`match(string);
}


def:pub fullmatch(pattern: str, string: str, flags: int = 0) -> (Match | None) {
    p: Pattern = Pattern(pattern, flags);
    return p.fullmatch(string);
}


def:pub findall(pattern: str, string: str, flags: int = 0) -> list[str] {
    p: Pattern = Pattern(pattern, flags);
    return p.findall(string);
}


def:pub finditer(pattern: str, string: str, flags: int = 0) -> list[Match] {
    p: Pattern = Pattern(pattern, flags);
    return p.finditer(string);
}


def:pub split(
    pattern: str, string: str, maxsplit: int = 0, flags: int = 0
) -> list[any] {
    p: Pattern = Pattern(pattern, flags);
    return p.split(string, maxsplit);
}


def:pub sub(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> str {
    p: Pattern = Pattern(pattern, flags);
    return p.sub(repl, string, count);
}


def:pub subn(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> tuple[(str, int)] {
    p: Pattern = Pattern(pattern, flags);
    return p.subn(repl, string, count);
}


def:pub escape(pattern: str) -> str {
    out: str = "";
    i: int = 0;
    n: int = len(pattern);
    special: str = "()[]{}?*+-|^$\\.&~# \t\n\r\x0b\x0c";
    while i < n {
        ch: str = pattern[i];
        if ch in special {
            out += "\\";
        }
        out += ch;
        i += 1;
    }
    return out;
}


def:pub purge {}
