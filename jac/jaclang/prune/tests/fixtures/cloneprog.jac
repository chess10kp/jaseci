"""Fixture for structural-clone detection (R-A).

Contains three clone shapes plus a negative control:
  - exact, cross-class: `find`/`find_one` byte-identical across two sibling
    classes (VolatileStore, SqliteStore) -> collide on the exact body hash.
  - structural, constant-diff: `emit_sub`/`emit_super`/`emit_disjoint` differ
    only in literal constants -> collide on the structural hash, not the exact.
  - negative control: `tally` has the same signature/shape as another callable
    but genuinely different behavior -> must not collide on the exact hash.
"""

obj VolatileStore {
    has data: dict = {};

    def find(key: str, limit: int) -> list {
        out = [];
        for k in self.data.keys() {
            if k == key {
                out.append(self.data[k]);
            }
        }
        return out[:limit];
    }

    def find_one(key: str) -> str {
        val = self.data.get(key);
        if val is None {
            return "";
        }
        return str(val);
    }
}

obj SqliteStore {
    has data: dict = {};

    def find(key: str, limit: int) -> list {
        out = [];
        for k in self.data.keys() {
            if k == key {
                out.append(self.data[k]);
            }
        }
        return out[:limit];
    }

    def find_one(key: str) -> str {
        val = self.data.get(key);
        if val is None {
            return "";
        }
        return str(val);
    }
}


def emit_sub(a: set, b: set) -> str {
    tag = "ssub";
    ok = True;
    parts = [];
    for x in a {
        parts.append(tag + str(x));
    }
    if len(parts) > 0 and ok {
        return ",".join(parts);
    }
    return tag;
}


def emit_super(a: set, b: set) -> str {
    tag = "ssup";
    ok = False;
    parts = [];
    for x in a {
        parts.append(tag + str(x));
    }
    if len(parts) > 0 and ok {
        return ",".join(parts);
    }
    return tag;
}


def emit_disjoint(a: set, b: set) -> str {
    tag = "sdis";
    ok = True;
    parts = [];
    for x in a {
        parts.append(tag + str(x));
    }
    if len(parts) > 0 and ok {
        return ",".join(parts);
    }
    return tag;
}


def tally(a: set, b: set) -> str {
    total = 0;
    for x in a {
        if x in b {
            total += 1;
        }
    }
    return str(total);
}
