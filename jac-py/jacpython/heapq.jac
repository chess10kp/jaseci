# Product-path facade for heapq (native list algorithms).
# ``_heapqmodule.jac`` carries the runtime truth (_p2_* list kernels lifted
# from CPython 3.14 ``Modules/_heapqmodule.c``); this module binds the
# standard Lib/heapq.py names so guest code can ``import heapq`` without
# reaching the host C extension or the MUTABLE_COPY list-mutation hazard.
#
# Staged ``jac-py/Modules/_heapqmodule.jac`` remains the C-API hand oracle
# (PyObj stubs) for cc differential tests - not byte-identical to this facade.

import from _heapqmodule {
    _p2_heapify as heapify,
    _p2_heappush as heappush,
    _p2_heappop as heappop,
    _p2_heapreplace as heapreplace,
    _p2_heappushpop as heappushpop,
    _p2_heapify_max as heapify_max,
    _p2_heappush_max as heappush_max,
    _p2_heappop_max as heappop_max,
    _p2_heapreplace_max as heapreplace_max,
    _p2_heappushpop_max as heappushpop_max,
}

# CPython documents nlargest/nsmallest as sorted(..., reverse=...)[:n].
def nsmallest(n: int, iterable: any, key: any = None) -> list {
    if n <= 0 {
        return [];
    }
    if key is None {
        ordered = sorted(iterable);
    } else {
        ordered = sorted(iterable, key=key);
    }
    if n >= len(ordered) {
        return ordered;
    }
    return ordered[:n];
}

def nlargest(n: int, iterable: any, key: any = None) -> list {
    if n <= 0 {
        return [];
    }
    if key is None {
        ordered = sorted(iterable, reverse=True);
    } else {
        ordered = sorted(iterable, key=key, reverse=True);
    }
    if n >= len(ordered) {
        return ordered;
    }
    return ordered[:n];
}
