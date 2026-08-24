"""Wave-1 D2 pilot parity: Lib/operator.py vs pinned CPython 3.14.6.

Snippets are adapted from ``reference/cpython/Lib/test/test_operator.py``
(OperatorTestCase subsets). Each runs through jacpython's ceval via
layer_p2_libtest and must print ``ok`` exactly as on the host oracle.

Pilot scope note: comparison/identity (operator.is_), sequence mutation
(setitem/delitem round-trip), in-place variants (iadd identity), attrgetter
and methodcaller over VM objects are EXCLUDED -- they fail because
``import operator`` star-imports the host-proxied ``_operator`` C module,
whose callables see converted copies of VM objects (identity lost, mutations
not visible in-VM, VM-defined attributes unreachable). See the wave-1 pilot
report for the full gap list.
"""

import from layer_p2_libtest {
    p2_libtest_expect_ok,
}


test "pilot operator: arithmetic and bitwise family" {
    snippet = (
        "import operator as op\n"
        "assert op.add(3, 4) == 7 and op.sub(10, 1) == 9\n"
        "assert op.mul(6, 7) == 42\n"
        "assert op.floordiv(20, 3) == 6 and op.truediv(7, 2) == 3.5\n"
        "assert op.mod(11, 4) == 3\n"
        "assert op.neg(-5) == 5 and op.pos(-5) == -5 and op.abs(-2) == 2\n"
        "assert op.invert(0xFF) == -256\n"
        "assert op.lshift(2, 4) == 32 and op.rshift(32, 4) == 2\n"
        "assert op.and_(0xF0, 0x0F) == 0\n"
        "assert op.or_(0xF0, 0x0F) == 0xFF\n"
        "assert op.xor(0xFF, 0x0F) == 0xF0\n"
        "assert op.index(3) == 3\n"
        "try:\n"
        "    op.floordiv(1, 0)\n"
        "except ZeroDivisionError:\n"
        "    pass\n"
        "else:\n"
        "    raise AssertionError('no ZeroDivisionError')\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}


test "pilot operator: value comparisons and truth" {
    snippet = (
        "import operator as op\n"
        "assert op.lt(1, 2) and op.le(2, 2) and op.gt(3, 2) and op.ge(2, 2)\n"
        "assert op.eq(1, 1.0) and not op.ne(1, 1.0)\n"
        "assert not op.truth(()) and op.truth((0,))\n"
        "assert op.not_(False) is True\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}


test "pilot operator: read-only sequence and mapping protocols" {
    snippet = (
        "import operator as op\n"
        "d = {'k': 1}\n"
        "lst = [1, 2, 3]\n"
        "assert op.concat('ab', 'cd') == 'abcd'\n"
        "assert op.contains([1, 2, 3], 2) and not op.contains([], 1)\n"
        "assert op.countOf([1, 2, 1, 3, 1], 1) == 3\n"
        "assert op.indexOf([4, 5, 6], 5) == 1\n"
        "assert op.getitem(d, 'k') == 1\n"
        "assert op.getitem(lst, -1) == 3\n"
        "assert op.length_hint([1, 2], 99) == 2\n"
        "assert op.length_hint(object(), 7) == 7\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}


test "pilot operator: itemgetter" {
    snippet = (
        "import operator as op\n"
        "g = op.itemgetter(1)\n"
        "assert g((10, 20, 30)) == 20\n"
        "assert g([5, 6, 7]) == 6\n"
        "g2 = op.itemgetter(0, 2)\n"
        "assert g2('abcdef') == ('a', 'c'), g2('abcdef')\n"
        "recs = [('a', 1), ('b', 2)]\n"
        "assert [r[1] for r in recs] == list(map(op.itemgetter(1), recs))\n"
        "try:\n"
        "    g([])\n"
        "except IndexError:\n"
        "    pass\n"
        "else:\n"
        "    raise AssertionError('no IndexError')\n"
        "try:\n"
        "    op.itemgetter(2)(None)\n"
        "except TypeError:\n"
        "    pass\n"
        "else:\n"
        "    raise AssertionError('no TypeError')\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_expect_ok(snippet);
    assert ok , detail;
}
