# Product-path facade for bisect (native list algorithms).
# Staged ``jac-py/Modules/_bisectmodule.jac`` remains the C-API hand oracle
# (PyObj stubs) for cc differential tests - not byte-identical to this facade.
# Semantics mirror CPython 3.14 ``Lib/bisect.py`` / ``Modules/_bisectmodule.c``.

def bisect_right(a: list, x: any, lo: int = 0, hi: int | None = None, key: any = None) -> int {
    if lo < 0 {
        raise ValueError("lo must be non-negative");
    }
    bound: int = 0;
    if hi is None {
        bound = len(a);
    } else {
        bound = hi;
    }
    if key is None {
        while lo < bound {
            mid = (lo + bound) // 2;
            if x < a[mid] {
                bound = mid;
            } else {
                lo = mid + 1;
            }
        }
    } else {
        while lo < bound {
            mid = (lo + bound) // 2;
            if x < key(a[mid]) {
                bound = mid;
            } else {
                lo = mid + 1;
            }
        }
    }
    return lo;
}

def bisect_left(a: list, x: any, lo: int = 0, hi: int | None = None, key: any = None) -> int {
    if lo < 0 {
        raise ValueError("lo must be non-negative");
    }
    bound: int = 0;
    if hi is None {
        bound = len(a);
    } else {
        bound = hi;
    }
    if key is None {
        while lo < bound {
            mid = (lo + bound) // 2;
            if a[mid] < x {
                lo = mid + 1;
            } else {
                bound = mid;
            }
        }
    } else {
        while lo < bound {
            mid = (lo + bound) // 2;
            if key(a[mid]) < x {
                lo = mid + 1;
            } else {
                bound = mid;
            }
        }
    }
    return lo;
}

def bisect(a: list, x: any, lo: int = 0, hi: int | None = None, key: any = None) -> int {
    return bisect_right(a, x, lo, hi, key);
}

def insort_right(a: list, x: any, lo: int = 0, hi: int | None = None, key: any = None) {
    if key is None {
        lo = bisect_right(a, x, lo, hi);
    } else {
        lo = bisect_right(a, key(x), lo, hi, key);
    }
    a.insert(lo, x);
}

def insort_left(a: list, x: any, lo: int = 0, hi: int | None = None, key: any = None) {
    if key is None {
        lo = bisect_left(a, x, lo, hi);
    } else {
        lo = bisect_left(a, key(x), lo, hi, key);
    }
    a.insert(lo, x);
}

def insort(a: list, x: any, lo: int = 0, hi: int | None = None, key: any = None) {
    insort_right(a, x, lo, hi, key);
}
