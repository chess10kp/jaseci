"""Fixture for the T3 fuzzy (token-overlap) clone tier.

Three independent buckets, isolated by arity so they never cross-contaminate:

  - arity 1 (fuzzy pair): `scan_wide` / `scan_narrow` share a body except for
    one inserted guard statement -> different structural hash, high token
    overlap -> the ONLY group the fuzzy tier should emit.
  - arity 2 (structural pair): `price_a` / `price_b` differ only in a literal
    constant -> same structural hash -> a T2 group, must be EXCLUDED from the
    fuzzy tier (a fuzzy group requires >1 distinct structural hash).
  - arity 3 (negative control): `far_a` / `far_b` are genuinely different ->
    below threshold -> no group.
"""

def scan_wide(items: list) -> list {
    out = [];
    total = 0;
    seen = 0;
    for it in items {
        total = total + 1;
        seen = seen + len(str(it));
        out.append(it);
    }
    if total > 0 {
        out.append(total);
        out.append(seen);
    }
    return out;
}


def scan_narrow(items: list) -> list {
    out = [];
    total = 0;
    seen = 0;
    for it in items {
        total = total + 1;
        if it is None {
            continue;
        }
        seen = seen + len(str(it));
        out.append(it);
    }
    if total > 0 {
        out.append(total);
        out.append(seen);
    }
    return out;
}


def price_a(x: int, y: int) -> int {
    base = 10;
    r = x * base + y;
    return r;
}


def price_b(x: int, y: int) -> int {
    base = 20;
    r = x * base + y;
    return r;
}


def far_a(p: int, q: int, r: int) -> int {
    return p + q + r;
}


def far_b(p: int, q: int, r: int) -> str {
    s = "";
    for i in range(p) {
        s = s + str(q);
    }
    return s;
}
