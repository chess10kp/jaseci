# test.support shim gc_collect pins (layer_p2_libtest support_attrs).
#
# Census gap fp-v1:0cb264d9488d (ClearTest.test_clear_locals, Lib/test
# suites test_frame + test_pow): converted Lib/test pins call
# ``support.gc_collect()`` for weakref liveness assertions; the shim did not
# expose the helper and the snippet died with AttributeError 'gc_collect'
# before reaching its own asserts.
#
# Guest PyUserObj/PyClass objects are ordinary host CPython objects, so the
# host gc drives their lifetime exactly -- the pin below mirrors the CPython
# oracle: after dropping the last strong reference and calling
# support.gc_collect(), the weakref must return None.

import from layer_p2_libtest { p2_libtest_run_snippet }

def expect_ok(name: str, src: str) {
    (ok, detail) = p2_libtest_run_snippet(src);
    assert ok , name + " RUN<" + detail + ">";
    assert detail == "ok" , name + " GOT<" + detail + ">";
}

# NOTE: callable(support.gc_collect) is NOT asserted here -- obj_is_callable
# (ceval.jac) does not recognize tp_call-bearing native shim objs; converted
# Lib/test pins only ever invoke the helper, so the pin mirrors that shape.
test "support_shim: gc_collect resolves and runs on test.support" {
    expect_ok(
        "gc_collect_resolves",
        "from test import support\n"
        "def _t():\n"
        "    support.gc_collect()\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "support_shim: gc_collect drops unreferenced object weakref" {
    # Mirrors CPython ClearTest.test_clear_locals liveness core:
    # import order matches the converted Lib/test pin shape.
    expect_ok(
        "gc_collect_weakref_liveness",
        "import weakref\n"
        "from test import support\n"
        "def _t():\n"
        "    class C:\n"
        "        pass\n"
        "    c = C()\n"
        "    wr = weakref.ref(c)\n"
        "    del c\n"
        "    support.gc_collect()\n"
        "    assert None is wr(), ('assertIs', None, wr())\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "support_shim: gc_collect keeps strongly referenced object alive" {
    expect_ok(
        "gc_collect_strong_ref_alive",
        "import weakref\n"
        "from test import support\n"
        "def _t():\n"
        "    class C:\n"
        "        pass\n"
        "    c = C()\n"
        "    wr = weakref.ref(c)\n"
        "    support.gc_collect()\n"
        "    assert None is not wr(), ('assertIsNot', None, wr())\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}
