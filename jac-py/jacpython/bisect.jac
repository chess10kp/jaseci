# Product-path port of CPython 3.14 ``Modules/_bisectmodule.c``.
# Covers the full public surface: bisect_right/bisect_left (aliases
# ``bisect``/``insort``'s search halves) and insort_right/insort_left,
# each with lo/hi bounds and an optional key callable -- including the
# insort rule of keying x exactly once before searching.
# Staged ``jac-py/Modules/_bisectmodule.c`` remains the C-API hand oracle;
# ``jacpython/_bisectmodule.jac`` keeps its narrower _p2_* facade used by
# the P2 libtest harness.

def bisect_right(data: list, item: any, lo: int = 0, hi: int | None = None, key: any = None) -> int {
    if lo < 0 {
        raise ValueError("lo must be non-negative");
    }
    bound: int = hi if hi is not None else len(data);
    while lo < bound {
        mid = (lo + bound) // 2;
        probe: any = data[mid];
        if key is not None {
            probe = key(probe);
        }
        if item < probe {
            bound = mid;
        } else {
            lo = mid + 1;
        }
    }
    return lo;
}

def bisect_left(data: list, item: any, lo: int = 0, hi: int | None = None, key: any = None) -> int {
    if lo < 0 {
        raise ValueError("lo must be non-negative");
    }
    bound: int = hi if hi is not None else len(data);
    while lo < bound {
        mid = (lo + bound) // 2;
        probe: any = data[mid];
        if key is not None {
            probe = key(probe);
        }
        # key(list[mid]) < item -> right half; else left half
        if probe < item {
            lo = mid + 1;
        } else {
            bound = mid;
        }
    }
    return lo;
}

def insort_right(data: list, item: any, lo: int = 0, hi: int | None = None, key: any = None) {
    probe: any = item;
    if key is not None {
        probe = key(item);
    }
    data.insert(bisect_right(data, probe, lo, hi, key), item);
}

def insort_left(data: list, item: any, lo: int = 0, hi: int | None = None, key: any = None) {
    probe: any = item;
    if key is not None {
        probe = key(item);
    }
    data.insert(bisect_left(data, probe, lo, hi, key), item);
}

# CPython aliases: ``bisect`` is bisect_right, ``insort`` is insort_right.
def bisect(data: list, item: any, lo: int = 0, hi: int | None = None, key: any = None) -> int {
    return bisect_right(data, item, lo, hi, key);
}

def insort(data: list, item: any, lo: int = 0, hi: int | None = None, key: any = None) {
    insort_right(data, item, lo, hi, key);
}
