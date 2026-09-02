"""P2 wave 20 facade parity: native functools vs host stdlib.

``Lib/functools.py`` / ``Modules/_functoolsmodule.c`` stay the semantic
oracle; this file gates the product-path facade semantics in
jac-py/jacpython/_functoolsmodule.jac against the pinned host oracle
(CPython 3.14). Error texts were verified against host CPython 3.14.7.
"""

import functools as ft;
import from _functoolsmodule {
    _p2_reduce,
    _p2_partial,
    _p2_lru_cache,
    _p2_update_wrapper,
    _p2_wraps,
    _p2_cmp_to_key,
    _p2_total_ordering,
    P2_WRAPPER_ASSIGNMENTS,
    P2_WRAPPER_UPDATES,
    P2_PLACEHOLDER,
}


def _add3(a: int = 0, b: int = 0, c: int = 0) -> int {
    return a + b + c;
}

def _host_add3(a: int = 0, b: int = 0, c: int = 0) -> int {
    return a + b + c;
}

def _collide(a: int = 0, b: int = 0) -> int {
    return a + b;
}


test "wave20 reduce folds left and matches host" {
    cases: list = [
        [1, 2, 3, 4],
        [5],
        ["a", "b", "c"],
        [(1,), (2,)],
    ];
    for data in cases {
        got = _p2_reduce(lambda (a: any, b: any) { a + b; }, data);
        want = ft.reduce(lambda (x: any, y: any) { x + y; }, list(data));
        assert got == want , (data, got, want);
    }
    # explicit initializer, including None
    assert _p2_reduce(lambda (a: any, b: any) { a + b; }, [1, 2], 10) == 13;
    assert ft.reduce(lambda (x: any, y: any) { x + y; }, [1, 2], 10) == 13;
    assert _p2_reduce(lambda (a: any, b: any) { b; }, [], None) is None;
    assert ft.reduce(lambda (x: any, y: any) { y; }, [], None) is None;
    # empty without initializer raises the host-exact TypeError
    raised = "";
    try {
        _p2_reduce(lambda (a: any, b: any) { a + b; }, []);
    } except TypeError as e {
        raised = str(e);
    }
    assert raised == "reduce() of empty iterable with no initial value" , raised;
    # laziness: reduce consumes exactly what it needs and leaves the rest
    src = iter([1, 2, 3, 4, 5]);
    total = _p2_reduce(lambda (a: any, b: any) { a + b; }, src);
    assert total == 15;
    assert list(src) == [] , "reduce must drain its iterator fully";
    src2 = iter([7]);
    assert _p2_reduce(lambda (a: any, b: any) { a + b; }, src2) == 7;
}


test "wave20 partial forwards positionals keywords and chains" {
    p = _p2_partial(_add3, (1,), {"b": 2});
    hp = ft.partial(_host_add3, 1, b=2);
    assert p() == hp() , (p(), hp());
    assert p(c=4) == hp(c=4) == 7;
    # keyword-only partial
    pk = _p2_partial(_add3, (), {"b": 5});
    assert pk() == ft.partial(_host_add3, b=5)() == 5;
    # chaining: partial over partial accumulates both bindings
    pp = _p2_partial(p, (), {"c": 10});
    hpp = ft.partial(hp, c=10);
    assert pp() == hpp() == 13;
    def _add4(a: int = 0, b: int = 0, c: int = 0, d: int = 0) -> int {
        return a + b + c + d;
    }
    q = _p2_partial(_add4, (1,), {"b": 2});
    qq = _p2_partial(q, (), {"c": 10});
    qqq = _p2_partial(qq, (), {"d": 100});
    hq = ft.partial(_add4, 1, b=2);
    hqq = ft.partial(hq, c=10);
    hqqq = ft.partial(hqq, d=100);
    assert qqq() == hqqq() == 113;
    # a chained positional that collides with stored keywords still raises
    bad_chain = _p2_partial(qq, (5,), {});
    msg3 = "";
    try {
        bad_chain();
    } except TypeError as e {
        msg3 = str(e);
    }
    assert "got multiple values for argument" in msg3 , msg3;
    # collision surfaces as the target's own TypeError, like host
    bad = _p2_partial(_collide, (1,), {"b": 2});
    msg = "";
    try {
        bad(5);
    } except TypeError as e {
        msg = str(e);
    }
    # the target name prefix differs across runtimes (qualname rendering);
    # the load-bearing part is the collision wording itself
    assert msg.endswith("got multiple values for argument 'b'") , msg;
    # construction is lazy: building a partial never calls the target
    calls: list = [];
    def spy(x: int) -> int { calls.append(x); return x; }
    lazy_p = _p2_partial(spy, (9,), {});
    assert calls == [] , "partial() must not call func at construction";
    assert lazy_p() == 9 and calls == [9];
    # repr mirrors partial_repr (address elided)
    r = str(repr(p));
    assert r.startswith("functools.partial(<function") , r;
    assert r.endswith(">, 1, b=2)") , r;
}


test "wave20 partial Placeholder fills leading call args like host" {
    assert str(repr(P2_PLACEHOLDER)) == str(repr(ft.Placeholder));
    jp = _p2_partial(_add3, (P2_PLACEHOLDER, 2), {});
    hp = ft.partial(_host_add3, ft.Placeholder, 2);
    assert jp(1) == hp(1) == 3 , (jp(1), hp(1));
    # extra positionals after the filled slots still append
    assert jp(1, 5) == hp(1, 5) == 8;
    # too few arguments raises the host-exact TypeError
    jmsg = "";
    try {
        jp();
    } except TypeError as e {
        jmsg = str(e);
    }
    hmsg = "";
    try {
        hp();
    } except TypeError as e {
        hmsg = str(e);
    }
    assert jmsg == hmsg , (jmsg, hmsg);
    # construction-time restrictions mirror partial_new
    raised = "";
    try {
        _p2_partial(_add3, (1, P2_PLACEHOLDER), {});
    } except TypeError as e {
        raised = str(e);
    }
    assert raised == "trailing Placeholders are not allowed" , raised;
    raised_kw = "";
    try {
        _p2_partial(_add3, (), {"b": P2_PLACEHOLDER});
    } except TypeError as e {
        raised_kw = str(e);
    }
    assert raised_kw == "Placeholder cannot be passed as a keyword argument" , raised_kw;
}


test "wave20 partial reduce setstate round trips state atomically" {
    jp = _p2_partial(_add3, (P2_PLACEHOLDER, 2), {"c": 4});
    pr: any = jp.__reduce__();
    assert isinstance(pr, tuple) and len(pr) == 3;
    # pickle protocol shape: (type, (fn,), (fn, args, kw, dict_or_None))
    assert pr[0] is not None and isinstance(pr[1], tuple) and len(pr[1]) == 1;
    fresh = _p2_partial(_add3, (), {});
    fresh.__setstate__(pr[2]);
    assert fresh(1) == jp(1) == 7;
    # invalid states are rejected wholesale with the C error text
    bad = _p2_partial(_add3, (), {});
    m1 = "";
    try {
        bad.__setstate__((_add3, [1], {}, None));
    } except TypeError as e {
        m1 = str(e);
    }
    assert m1 == "invalid partial state" , m1;
    m2 = "";
    try {
        bad.__setstate__((None, (), {}, None));
    } except TypeError as e {
        m2 = str(e);
    }
    assert m2 == "invalid partial state" , m2;
    m3 = "";
    try {
        bad.__setstate__((_add3, (1, P2_PLACEHOLDER), {}, None));
    } except TypeError as e {
        m3 = str(e);
    }
    assert m3 == "trailing Placeholders are not allowed" , m3;
    # a rejected setstate must not have mutated the target
    assert bad() == 0;
}


test "wave20 lru_cache wrapper copies by identity and reduces by qualname" {
    w = _p2_lru_cache(2)(_spy_square);
    hw = ft.lru_cache(maxsize=2)(_host_spy_square);
    w(3);
    assert w.__copy__() is w;
    assert w.__deepcopy__(None) is w;
    assert isinstance(w.__reduce__(), str);
    assert str(getattr(hw, "__reduce__")()) == str(getattr(hw, "__qualname__"));
    # copied wrapper shares the live cache, like the C identity copy
    got = w.__copy__();
    assert got.cache_info() == w.cache_info();
}


def _spy_square(x: int) -> int {
    return x * x;
}

def _host_spy_square(x: int) -> int {
    return x * x;
}


test "wave20 lru_cache tracks hits misses eviction and info exactly" {
    dec = _p2_lru_cache(2);
    w = dec(_spy_square);
    hw = ft.lru_cache(maxsize=2)(_host_spy_square);
    seq: list = [1, 2, 1, 3, 1, 2];
    for x in seq {
        assert w(x) == hw(x) , (x, w(x), hw(x));
    }
    assert str(w.cache_info()) == str(hw.cache_info()) , (
        str(w.cache_info()), str(hw.cache_info())
    );
    assert w.cache_parameters() == hw.cache_parameters();
    # cache_clear resets counters and contents
    w.cache_clear();
    hw.cache_clear();
    assert str(w.cache_info()) == str(hw.cache_info()) == (
        "CacheInfo(hits=0, misses=0, maxsize=2, currsize=0)"
    );
    # maxsize=None is unbounded
    ub = _p2_lru_cache(None)(_spy_square);
    hub = ft.lru_cache(maxsize=None)(_host_spy_square);
    for i in range(30) {
        assert ub(i) == hub(i);
    }
    assert str(ub.cache_info()) == str(hub.cache_info());
    assert ub.cache_parameters()["maxsize"] is None;
    # typed=True separates 1 from 1.0
    tdec = _p2_lru_cache(None, typed=True);
    tw = tdec(_spy_square);
    htw = ft.lru_cache(maxsize=None, typed=True)(_host_spy_square);
    tw(1); tw(1.0); tw(1);
    htw(1); htw(1.0); htw(1);
    assert str(tw.cache_info()) == str(htw.cache_info()) , (
        str(tw.cache_info()), str(htw.cache_info())
    );
    # maxsize=0 caches nothing
    z = _p2_lru_cache(0)(_spy_square);
    z(4); z(4);
    assert str(z.cache_info()) == "CacheInfo(hits=0, misses=2, maxsize=0, currsize=0)";
    # invalid first argument raises the host-exact TypeError
    msg = "";
    try {
        _p2_lru_cache("big");
    } except TypeError as e {
        msg = str(e);
    }
    assert msg == "Expected first argument to be an integer, a callable, or None" , msg;
    # bare @lru_cache application uses default maxsize=128
    bare_w = _p2_lru_cache()(_spy_square);
    hbare = ft.lru_cache()(_host_spy_square);
    bare_w(8); hbare(8);
    assert str(bare_w.cache_info()) == str(hbare.cache_info());
    # __wrapped__ sees through the cache
    assert bare_w.__wrapped__ is _spy_square;
    # unhashable arguments surface the runtime's own TypeError
    m2 = "";
    try {
        w([]);
    } except TypeError as e {
        m2 = type(e).__name__;
    }
    assert m2 == "TypeError";
}


test "wave20 wraps copies WRAPPER_ASSIGNMENTS and sets __wrapped__" {
    assert P2_WRAPPER_ASSIGNMENTS == ft.WRAPPER_ASSIGNMENTS;
    assert P2_WRAPPER_UPDATES == ft.WRAPPER_UPDATES;

    def real(x: int) -> int {
        "the real doc";
        return x;
    }
    @_p2_wraps(real)
    def wrapped(x: int) -> int { return real(x); }

    # wraps copies the WRAPPED function's identity attributes
    assert wrapped.__name__ == "real";
    hwrapped = ft.wraps(_host_spy_square)(lambda (x: int) { x; });
    assert hwrapped.__name__ == "_host_spy_square";
    assert wrapped.__doc__ == "the real doc";
    assert wrapped.__module__ == "__main__" or isinstance(wrapped.__module__, str);
    assert getattr(wrapped, "__wrapped__", None) is real;
    # missing attributes on the wrapped object are skipped silently
    def bare() {}
    @_p2_wraps(bare)
    def w2() {}
    # 3.14: update_wrapper assigns __annotate__, not __annotations__; the
    # wrapper's own annotations dict stays untouched.
    assert w2.__annotations__ == {"return": "None"};
    assert getattr(w2, "__wrapped__", None) is bare;
    # __dict__ merge exposes wrapper-side extras after update_wrapper
    def donor() {}
    setattr(donor, "extra", 42);
    def sink() {}
    out = _p2_update_wrapper(sink, donor);
    assert out is sink;
    assert getattr(sink, "extra", None) == 42;
    assert getattr(sink, "__wrapped__", None) is donor;
    # custom assigned/updated tuples are honored
    def sink2() {}
    _p2_update_wrapper(sink2, donor, ("__name__",), ());
    assert sink2.__name__ == "donor";
    assert getattr(sink2, "extra", None) is None;
    assert getattr(sink2, "__wrapped__", None) is donor;
}


test "wave20 cmp_to_key sorts through the rich compare protocol" {
    asc = lambda (x: int, y: int) { x - y; };
    desc = lambda (x: int, y: int) { y - x; };
    data: list = [3, 1, 4, 1, 5, 9, 2, 6];
    K = _p2_cmp_to_key(asc);
    assert sorted(data, key=K) == sorted(data) , sorted(data, key=K);
    KD = _p2_cmp_to_key(desc);
    assert sorted(data, key=KD, reverse=True) == sorted(data);
    assert sorted(data, key=KD) == sorted(data, reverse=True);
    # instances expose .obj like host KeyWrapper
    k = K(5);
    assert k.`obj == 5;
    assert (k < K(6)) and not (k < K(4));
    # string comparison via cmp
    by_len = _p2_cmp_to_key(lambda (x: str, y: str) { len(x) - len(y); });
    words = ["pear", "fig", "banana"];
    assert sorted(words, key=by_len) == ["fig", "pear", "banana"];
}


# total_ordering fixtures. The decorator is applied at archetype creation,
# mirroring @functools.total_ordering usage; the host twin applies
# ft.total_ordering to an identical obj archetype.

@_p2_total_ordering
obj JLtRoot {
    has v: int = 0;
    def __eq__(other: any) -> bool { return self.v == other.v; }
    def __lt__(other: any) -> bool { return self.v < other.v; }
}

@ft.total_ordering
obj HLtRoot {
    has v: int = 0;
    def __eq__(other: any) -> bool { return self.v == other.v; }
    def __lt__(other: any) -> bool { return self.v < other.v; }
}

@_p2_total_ordering
obj JGtRoot {
    has v: int = 0;
    def __eq__(other: any) -> bool { return self.v == other.v; }
    def __gt__(other: any) -> bool { return self.v > other.v; }
}

@_p2_total_ordering
obj HGeRoot {
    has v: int = 0;
    def __eq__(other: any) -> bool { return self.v == other.v; }
    def __ge__(other: any) -> bool { return self.v >= other.v; }
}


test "wave20 total_ordering fills missing orderings like host" {
    vals: list = [1, 2, 3];
    for a in vals {
        for b in vals {
            ja: any = JLtRoot(v=a);
            jb: any = JLtRoot(v=b);
            ha: any = HLtRoot(v=a);
            hb: any = HLtRoot(v=b);
            assert (ja < jb) == (ha < hb) , (a, b, "lt");
            assert (ja <= jb) == (ha <= hb) , (a, b, "le");
            assert (ja > jb) == (ha > hb) , (a, b, "gt");
            assert (ja >= jb) == (ha >= hb) , (a, b, "ge");
            # derived ops agree with direct operator semantics
            assert (ja <= jb) == (ja.v <= jb.v);
            assert (ja >= jb) == (ja.v >= jb.v);
        }
    }
    # __gt__-rooted class derives lt/le/ge correctly
    g: any = JGtRoot(v=5);
    g7: any = JGtRoot(v=7);
    g5: any = JGtRoot(v=5);
    assert g < g7;
    assert g <= g5;
    assert g7 >= g5;
    # __ge__-rooted class derives le/gt/lt correctly
    hg1: any = HGeRoot(v=1);
    hg2: any = HGeRoot(v=2);
    assert (hg1 < hg2) and (hg2 > hg1) and (hg2 >= hg1) and not (hg1 >= hg2);
    # no ordering op at all raises the host-exact ValueError
    obj Bad {
        def __eq__(other: any) -> bool { return True; }
    }
    msg = "";
    try {
        _p2_total_ordering(Bad);
    } except ValueError as e {
        msg = str(e);
    }
    assert msg == "must define at least one ordering operation: < > <= >=" , msg;
}
