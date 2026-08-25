# Traceback-surface differential pins (TB wave A).
#
# Pins cover shapes verified against host CPython 3.14 behavior via
# product_exec-direct assertion style. Multi-entry guest-side tb_next walks
# followed by trailing statements currently hit a native-codegen layout bug
# (bound-handler as-cleanup epilogue collides with the loop head); see
# jac-py/notes/TB-SURFACE-FINDINGS.md before extending with walk pins.
import from layer9_product_exec { product_exec }

glob SRC_HEAD = (
    "def g():\n"
    "    raise ValueError('x')\n"
    "try:\n"
    "    g()\n"
    "except ValueError as e:\n"
    "    tb = e.__traceback__\n"
    "    assert tb is not None\n"
    "    assert tb.tb_frame.f_code.co_name == '<module>', tb.tb_frame.f_code.co_name\n"
    "    assert tb.tb_lineno == 4, tb.tb_lineno\n"
);

glob SRC_LASTI = (
    "try:\n"
    "    raise ValueError('l')\n"
    "except ValueError as e:\n"
    "    t = e.__traceback__\n"
    "    assert isinstance(t.tb_lasti, int), type(t.tb_lasti).__name__\n"
    "    assert isinstance(t.tb_lineno, int), type(t.tb_lineno).__name__\n"
);

glob SRC_FMT_TB_SHAPE = (
    "def h():\n"
    "    raise ValueError('d')\n"
    "try:\n"
    "    h()\n"
    "except ValueError as e:\n"
    "    import traceback\n"
    "    out = traceback.format_tb(e.__traceback__)\n"
    "    assert isinstance(out, list)\n"
    "    assert len(out) == 2, out\n"
    "    assert 'line 4, in <module>' in out[0], out[0]\n"
    "    assert 'line 2, in h' in out[1], out[1]\n"
);

glob SRC_SINGLE_ENTRY = (
    "try:\n"
    "    raise RuntimeError('r')\n"
    "except RuntimeError as e:\n"
    "    tb = e.__traceback__\n"
    "    info = (tb.tb_lineno, tb.tb_next is None)\n"
    "    assert info == (2, True), info\n"
);

glob SRC_WITH_TRACEBACK = (
    "def inner():\n"
    "    raise ValueError('b')\n"
    "def log_reraise(exc):\n"
    "    raise exc.with_traceback(exc.__traceback__)\n"
    "try:\n"
    "    try:\n"
    "        inner()\n"
    "    except ValueError as e:\n"
    "        log_reraise(e)\n"
    "except ValueError as e2:\n"
    "    tb = e2.__traceback__\n"
    "    assert tb is not None\n"
    "    assert tb.tb_frame.f_code.co_name == '<module>', tb.tb_frame.f_code.co_name\n"
    "    assert tb.tb_lineno == 9, tb.tb_lineno\n"
    "    assert tb.tb_next.tb_frame.f_code.co_name == 'log_reraise', tb.tb_next.tb_frame.f_code.co_name\n"
);

glob SRC_WITH_TRACEBACK_TYPEERR = (
    "try:\n"
    "    raise ValueError('x')\n"
    "except ValueError as e:\n"
    "    try:\n"
    "        e.with_traceback(42)\n"
    "    except TypeError as t:\n"
    "        assert '__traceback__ must be a traceback or None' in str(t), str(t)\n"
    "    else:\n"
    "        assert False, 'no TypeError'\n"
);

glob SRC_TB_TYPE_NAME = (
    "import types\n"
    "try:\n"
    "    raise ValueError('t')\n"
    "except ValueError as e:\n"
    "    assert isinstance(e.__traceback__, types.TracebackType), type(e.__traceback__)\n"
);

test "tb surface: chain headed at catching frame" { product_exec(SRC_HEAD); }
test "tb surface: tb_lasti/tb_lineno are ints" { product_exec(SRC_LASTI); }
test "tb surface: format_tb two-frame shape" { product_exec(SRC_FMT_TB_SHAPE); }
test "tb surface: single entry at raise line" { product_exec(SRC_SINGLE_ENTRY); }
test "tb surface: with_traceback reraise helper keeps chain" { product_exec(SRC_WITH_TRACEBACK); }
test "tb surface: with_traceback rejects non-traceback" { product_exec(SRC_WITH_TRACEBACK_TYPEERR); }
test "tb surface: __traceback__ types as TracebackType" { product_exec(SRC_TB_TYPE_NAME); }
