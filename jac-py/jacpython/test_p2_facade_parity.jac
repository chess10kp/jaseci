"""Semantic facade parity: native jacpython bisect/heapq vs host stdlib.

Modules/*.jac stay C-API hand oracles (byte-identity is getplatform-only).
"""

import bisect as host_bisect;
import heapq as host_heapq;
import from _bisectmodule {
    _p2_bisect_right,
    _p2_bisect_left,
    _p2_insort,
    _p2_insort_left,
}
import from _heapqmodule {
    _p2_heappush,
    _p2_heappop,
    _p2_heapify,
    _p2_heapreplace,
    _p2_heappushpop,
    _p2_heappush_max,
    _p2_heappop_max,
    _p2_heapify_max,
    _p2_heapreplace_max,
    _p2_heappushpop_max,
}


test "P2 bisect facade agrees with host bisect on representative cases" {
    cases: list = [
        ([], 1),
        ([1], 1),
        ([1, 2, 3], 2),
        ([1, 1, 2, 2], 1.5),
        ([1, 2, 2, 3, 3, 3, 4, 4, 4, 4], 3),
        ([0, 0, 0, 0], 0),
        (list(range(20)), 7),
    ];
    for (data, item) in cases {
        a = list(data);
        b = list(data);
        assert _p2_bisect_right(a, item) == host_bisect.bisect_right(b, item) , (
            f"bisect_right {data!r} {item!r}"
        );
        assert _p2_bisect_left(a, item) == host_bisect.bisect_left(b, item) , (
            f"bisect_left {data!r} {item!r}"
        );
    }
    a = [1, 2, 3];
    b = [1, 2, 3];
    assert _p2_bisect_right(a, 2, 0, 2) == host_bisect.bisect_right(b, 2, 0, 2);
    assert _p2_bisect_left(a, 2, 1, 3) == host_bisect.bisect_left(b, 2, 1, 3);

    d1 = [1, 3, 5];
    d2 = [1, 3, 5];
    _p2_insort(d1, 4);
    host_bisect.insort(d2, 4);
    assert d1 == d2 , d1;
    _p2_insort_left(d1, 3);
    host_bisect.insort_left(d2, 3);
    assert d1 == d2 , d1;
}

test "P2 heapq facade agrees with host heapq on representative cases" {
    src = [5, 1, 9, 3, 7, 2, 8, 4, 6, 0];
    a = list(src);
    b = list(src);
    _p2_heapify(a);
    host_heapq.heapify(b);
    assert a == b , (a, b);

    a = [];
    b = [];
    for x in [3, 1, 4, 1, 5, 9, 2, 6] {
        _p2_heappush(a, x);
        host_heapq.heappush(b, x);
        assert a == b , (a, b);
    }
    out_a: list = [];
    out_b: list = [];
    while a {
        out_a.append(_p2_heappop(a));
        out_b.append(host_heapq.heappop(b));
    }
    assert out_a == out_b , (out_a, out_b);
    assert out_a == sorted([3, 1, 4, 1, 5, 9, 2, 6]);
}

test "P2 heapq facade replace/pushpop agrees with host heapq" {
    a = [1, 3, 2];
    b = [1, 3, 2];
    assert _p2_heapreplace(a, 5) == host_heapq.heapreplace(b, 5);
    assert a == b , (a, b);
    assert _p2_heapreplace(a, 0) == host_heapq.heapreplace(b, 0);
    assert a == b , (a, b);
    assert _p2_heappushpop(a, 4) == host_heapq.heappushpop(b, 4);
    assert a == b , (a, b);
    assert _p2_heappushpop(a, -1) == host_heapq.heappushpop(b, -1);
    assert a == b , (a, b);
    e1: list = [];
    e2: list = [];
    assert _p2_heappushpop(e1, 7) == host_heapq.heappushpop(e2, 7) == 7;
    assert len(e1) == 0 and len(e2) == 0;
}

test "P2 heapq max-heap facade agrees with host heapq" {
    src = [5, 1, 9, 3, 7, 2, 8, 4, 6, 0];
    a = list(src);
    b = list(src);
    _p2_heapify_max(a);
    host_heapq.heapify_max(b);
    assert a == b , (a, b);
    for x in [3, 11, 4] {
        _p2_heappush_max(a, x);
        host_heapq.heappush_max(b, x);
        assert a == b , (a, b);
    }
    assert _p2_heapreplace_max(a, 12) == host_heapq.heapreplace_max(b, 12);
    assert a == b , (a, b);
    assert _p2_heappushpop_max(a, 10) == host_heapq.heappushpop_max(b, 10);
    assert a == b , (a, b);
    assert _p2_heappushpop_max(a, -1) == host_heapq.heappushpop_max(b, -1);
    assert a == b , (a, b);
    out_a: list = [];
    out_b: list = [];
    while a {
        out_a.append(_p2_heappop_max(a));
        out_b.append(host_heapq.heappop_max(b));
    }
    assert out_a == out_b , (out_a, out_b);
    assert out_a == sorted(src, reverse=True);
    e1: list = [];
    e2: list = [];
    assert _p2_heappushpop_max(e1, 7) == host_heapq.heappushpop_max(e2, 7) == 7;
    assert len(e1) == 0 and len(e2) == 0;
}
