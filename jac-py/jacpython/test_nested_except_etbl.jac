# Regression pins for m2b: nested try/except exception-table emission.
#
# Bug: an enclosing try's unwind-bind pass retargeted the inner try's
# exception-table regions to the outer unwind chain (shared pending list),
# so an exception escaping an inner handler bypassed every outer handler.
# Fix: per-invocation region ownership in visit_try plus published
# success-epilogue spans consumed by the outer carve-out region.
#
# Parity is asserted on co_exceptiontable bytes vs the host CPython oracle
# (co_code const-registration order can differ benignly on nested shapes).
import from layer9_product_exec { product_exec, oracle_exec }
import from objects { PyCode }

def etbl_parity(name: str, src: str) -> bool {
    a = product_exec(src) as PyCode;
    e = oracle_exec(src, "<nested_except_etbl>") as PyCode;
    return a.exceptiontable == e.exceptiontable;
}

glob SRC_2LVL_MISMATCH = (
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError:\n"
    "        r = 'wrong'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

glob SRC_2LVL_MATCH_INNER = (
    "try:\n"
    "    try:\n"
    "        raise ValueError('x')\n"
    "    except ValueError:\n"
    "        r = 'inner'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

glob SRC_3LVL = (
    "try:\n"
    "    try:\n"
    "        try:\n"
    "            raise KeyError('x')\n"
    "        except ValueError:\n"
    "            r = 'a'\n"
    "    except TypeError:\n"
    "        r = 'b'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

glob SRC_BOUND_HANDLERS = (
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError as v:\n"
    "        r = 'wrong'\n"
    "except KeyError as e:\n"
    "        r = 'outer'\n"
);

glob SRC_FLAT_CONTROL = (
    "try:\n"
    "    raise KeyError('x')\n"
    "except KeyError:\n"
    "    r = 'ok'\n"
);

test "nested except etbl: two-level mismatched inner" {
    assert etbl_parity("2lvl-mismatch", SRC_2LVL_MISMATCH);
}

test "nested except etbl: two-level matching inner" {
    assert etbl_parity("2lvl-match", SRC_2LVL_MATCH_INNER);
}

test "nested except etbl: three levels" {
    assert etbl_parity("3lvl", SRC_3LVL);
}

test "nested except etbl: bound handlers" {
    assert etbl_parity("bound", SRC_BOUND_HANDLERS);
}

test "nested except etbl: flat control" {
    assert etbl_parity("flat", SRC_FLAT_CONTROL);
}

glob SRC_MULTI_UNBOUND = (
    "try:\n"
    "    raise KeyError('x')\n"
    "except ValueError:\n"
    "    r = 'a'\n"
    "except TypeError:\n"
    "    r = 'b'\n"
);

glob SRC_MULTI_BOUND = (
    "try:\n"
    "    raise KeyError('x')\n"
    "except ValueError as v:\n"
    "    r = 'a'\n"
    "except TypeError as t:\n"
    "    r = 'b'\n"
);

glob SRC_MULTI_MIXED = (
    "try:\n"
    "    raise KeyError('x')\n"
    "except ValueError as v:\n"
    "    r = 'a'\n"
    "except TypeError:\n"
    "    r = 'b'\n"
);

glob SRC_THREE_HANDLERS = (
    "try:\n"
    "    raise KeyError('x')\n"
    "except ValueError:\n"
    "    r = 'a'\n"
    "except TypeError:\n"
    "    r = 'b'\n"
    "except IndexError:\n"
    "    r = 'c'\n"
);

glob SRC_NESTED_MULTI = (
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError:\n"
    "        r = 'a'\n"
    "    except TypeError:\n"
    "        r = 'b'\n"
    "except KeyError:\n"
    "    r = 'outer'\n"
);

# Chained handlers keep CPython's uncovered NOT_TAKEN block split: adjacent
# same-target spans must not coalesce across it, and bound-tail segments run
# to the successor's NOT_TAKEN hole (last one through the reraise chain).
test "multi handler etbl: chained unbound" {
    assert etbl_parity("multi-unbound", SRC_MULTI_UNBOUND);
}

test "multi handler etbl: chained bound" {
    assert etbl_parity("multi-bound", SRC_MULTI_BOUND);
}

test "multi handler etbl: chained mixed" {
    assert etbl_parity("multi-mixed", SRC_MULTI_MIXED);
}

test "multi handler etbl: three handlers" {
    assert etbl_parity("three", SRC_THREE_HANDLERS);
}

test "multi handler etbl: nested multi" {
    assert etbl_parity("nested-multi", SRC_NESTED_MULTI);
}

# Runtime: an exception raised inside an inner handler body must reach the
# OUTER matching handler instead of escaping every handler.
glob SRC_RT_ESCAPE = (
    "out = []\n"
    "try:\n"
    "    try:\n"
    "        raise KeyError('x')\n"
    "    except ValueError:\n"
    "        raise RuntimeError('inner handler ran')\n"
    "except KeyError:\n"
    "    out.append('outer-keyerror')\n"
    "assert out == ['outer-keyerror'], out\n"
);

glob SRC_RT_CHAIN = (
    "hits = []\n"
    "try:\n"
    "    try:\n"
    "        raise ValueError(7)\n"
    "    except LookupError:\n"
    "        hits.append(1)\n"
    "    raise KeyError('k')\n"
    "except KeyError:\n"
    "    hits.append(2)\n"
    "assert hits == [1, 2], hits\n"
);

test "nested except runtime: inner-handler raise reaches outer handler" {
    product_exec(SRC_RT_ESCAPE);
}

test "nested except runtime: sequential raises through nested handlers" {
    product_exec(SRC_RT_CHAIN);
}

# except*/finally: the whole CHECK_EG_MATCH walk is forward-nested in the
# finally (CPython-identical lowering). Exception-table parity is pinned for
# both layouts - early inline copy (normal path reaches the finally) and late
# copy (body always terminates, only the nothing-to-reraise path reaches it).
glob SRC_TRYSTAR_FIN_BOUND = (
    "out = []\n"
    "try:\n"
    "    raise ValueError(1)\n"
    "except* TypeError as e:\n"
    "    out.append('t')\n"
    "finally:\n"
    "    out.append('f')\n"
);

glob SRC_TRYSTAR_FIN_UNBOUND = (
    "out = []\n"
    "try:\n"
    "    out.append(0)\n"
    "except* TypeError:\n"
    "    out.append('t')\n"
    "except* ValueError:\n"
    "    out.append('v')\n"
    "finally:\n"
    "    out.append('f')\n"
);

glob SRC_TRYSTAR_FIN_MULTI = (
    "out = []\n"
    "try:\n"
    "    raise ValueError(1)\n"
    "except* TypeError as t:\n"
    "    out.append('t')\n"
    "except* ValueError:\n"
    "    out.append('v')\n"
    "finally:\n"
    "    out.append('f')\n"
);

# Early layout (normal path reaches the finally).
test "trystar finally etbl: unbound handlers, early copy" {
    assert etbl_parity("trystar-fin-unbound", SRC_TRYSTAR_FIN_UNBOUND);
}

# Late layout (body terminates by raising).
test "trystar finally etbl: bound handler, late copy" {
    assert etbl_parity("trystar-fin-bound", SRC_TRYSTAR_FIN_BOUND);
}

test "trystar finally etbl: multi handlers, late copy" {
    assert etbl_parity("trystar-fin-multi", SRC_TRYSTAR_FIN_MULTI);
}

# Runtime: handler runs before finally; unmatched groups propagate after it.
glob SRC_TRYSTAR_FIN_RT_MATCH = (
    "out = []\n"
    "try:\n"
    "    raise ValueError(1)\n"
    "except* ValueError:\n"
    "    out.append('v')\n"
    "finally:\n"
    "    out.append('f')\n"
    "assert out == ['v', 'f'], out\n"
);

test "trystar finally runtime: handler then finally" {
    product_exec(SRC_TRYSTAR_FIN_RT_MATCH);
}

glob SRC_TRYSTAR_FIN_RT_NOMATCH = (
    "out = []\n"
    "try:\n"
    "    try:\n"
    "        raise KeyError('k')\n"
    "    except* ValueError:\n"
    "        out.append('v')\n"
    "    finally:\n"
    "        out.append('f')\n"
    "except KeyError:\n"
    "    out.append('outer')\n"
    "assert out == ['f', 'outer'], out\n"
);

test "trystar finally runtime: finally runs before propagation" {
    product_exec(SRC_TRYSTAR_FIN_RT_NOMATCH);
}

glob SRC_TRYSTAR_FIN_RT_HANDLER_RAISE = (
    "out = []\n"
    "try:\n"
    "    try:\n"
    "        raise ValueError(1)\n"
    "    except* ValueError:\n"
    "        raise TypeError('t')\n"
    "    finally:\n"
    "        out.append('f')\n"
    "except TypeError:\n"
    "    out.append('t')\n"
    "assert out == ['f', 't'], out\n"
);

test "trystar finally runtime: raise inside handler runs finally" {
    product_exec(SRC_TRYSTAR_FIN_RT_HANDLER_RAISE);
}

