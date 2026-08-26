# Pins: keywords_in_subclass family (CPython Lib/test test_set/test_list/
# test_tuple `test_keywords_in_subclass`) -- builtin-subclass instantiation
# keyword routing through PyClass.tp_call (ceval.jac).
#
# CPython 3.14.6 oracle provenance (reference/cpython Lib/test):
#   - plain subclass, positional args: fills the boxed base;
#   - `subclass(sequence=())` with NO user __init__: TypeError (the
#     MRO-resolved builtin initializer rejects keywords);
#   - subclass_with_init: user __init__ receives the kwargs; super().__init__
#     fills the live boxed storage;
#   - subclass_with_new: user __new__ controls construction; call-site kwargs
#     are FINE for list/tuple (their inherited initializer ignores them via
#     object.__init__) but set/frozenset reject them (set_init checks kwds)
#     -- both sides pinned.
#
# Harness: snippets run host-compiled through layer_p2_libtest (same route as
# the P3 layer1 replay gate), so verdicts match the gate, not the native
# front end.

import from layer_p2_libtest { p2_libtest_run_snippet }

# ---------------- set ----------------

test "set subclass plain positional + kw reject" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass(set):\n        pass\n    u = subclass([1, 2])\n    assert type(u) is subclass\n    assert set(u) == {1, 2}\n    try:\n        subclass(sequence=())\n    except TypeError:\n        pass\n    else:\n        raise AssertionError('assertRaises: did not raise')\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "set subclass_with_init routes newarg kwarg" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass_with_init(set):\n        def __init__(self, arg, newarg=None):\n            super().__init__(arg)\n            self.newarg = newarg\n    u = subclass_with_init([1, 2], newarg=3)\n    assert type(u) is subclass_with_init\n    assert set(u) == {1, 2}\n    assert u.newarg == 3\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "set subclass_with_new: no-kw ok, kw raises TypeError" {
    # Host oracle: set_init rejects kwds even when __new__ is user-defined.
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass_with_new(set):\n        def __new__(cls, arg, newarg=None):\n            self = super().__new__(cls, arg)\n            self.newarg = newarg\n            return self\n    u = subclass_with_new([1, 2])\n    assert type(u) is subclass_with_new\n    assert set(u) == {1, 2}\n    assert u.newarg is None\n    try:\n        subclass_with_new([1, 2], newarg=3)\n    except TypeError:\n        pass\n    else:\n        raise AssertionError('assertRaises: did not raise')\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

# ---------------- frozenset ----------------

test "frozenset subclass plain positional + kw reject + init kwarg" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass(frozenset):\n        pass\n    u = subclass([1, 2])\n    assert type(u) is subclass\n    assert set(u) == {1, 2}\n    try:\n        subclass(sequence=())\n    except TypeError:\n        pass\n    else:\n        raise AssertionError('assertRaises: did not raise')\n    class subclass_with_init(frozenset):\n        def __init__(self, arg, newarg=None):\n            self.newarg = newarg\n    u = subclass_with_init([1, 2], newarg=3)\n    assert type(u) is subclass_with_init\n    assert set(u) == {1, 2}\n    assert u.newarg == 3\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

# ---------------- list ----------------

test "list subclass plain positional + kw reject" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass(list):\n        pass\n    u = subclass([1, 2])\n    assert type(u) is subclass\n    assert list(u) == [1, 2]\n    try:\n        subclass(sequence=())\n    except TypeError:\n        pass\n    else:\n        raise AssertionError('assertRaises: did not raise')\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "list subclass_with_init routes seq/newarg" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass_with_init(list):\n        def __init__(self, seq, newarg=None):\n            super().__init__(seq)\n            self.newarg = newarg\n    u = subclass_with_init([1, 2], newarg=3)\n    assert type(u) is subclass_with_init\n    assert list(u) == [1, 2]\n    assert u.newarg == 3\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "list subclass_with_new accepts call-site kwargs (host parity)" {
    # Host oracle (CPython 3.14.6): list's inherited initializer does NOT
    # reject kwds here -- L([1,2], newarg=3) succeeds and sets .newarg.
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass_with_new(list):\n        def __new__(cls, seq, newarg=None):\n            self = super().__new__(cls, seq)\n            self.newarg = newarg\n            return self\n    u = subclass_with_new([1, 2], newarg=3)\n    assert type(u) is subclass_with_new\n    assert list(u) == [1, 2]\n    assert u.newarg == 3\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

# ---------------- tuple ----------------

test "tuple subclass plain positional + kw reject" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass(tuple):\n        pass\n    u = subclass([1, 2])\n    assert type(u) is subclass\n    assert list(u) == [1, 2]\n    try:\n        subclass(sequence=())\n    except TypeError:\n        pass\n    else:\n        raise AssertionError('assertRaises: did not raise')\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "tuple subclass_with_init stores attr, ignores base init" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass_with_init(tuple):\n        def __init__(self, arg, newarg=None):\n            self.newarg = newarg\n    u = subclass_with_init([1, 2], newarg=3)\n    assert type(u) is subclass_with_init\n    assert list(u) == [1, 2]\n    assert u.newarg == 3\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "tuple subclass_with_new accepts call-site kwargs (host parity)" {
    (ok, detail) = p2_libtest_run_snippet("def _t():\n    class subclass_with_new(tuple):\n        def __new__(cls, arg, newarg=None):\n            self = super().__new__(cls, arg)\n            self.newarg = newarg\n            return self\n    u = subclass_with_new([1, 2], newarg=3)\n    assert type(u) is subclass_with_new\n    assert list(u) == [1, 2]\n    assert u.newarg == 3\ntry:\n    _t()\nexcept BaseException as _e:\n    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\nelse:\n    print('ok')\n");
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}
