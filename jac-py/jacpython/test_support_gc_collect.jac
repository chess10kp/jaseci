# Regression pins for the test.support shim's gc_collect helper.
#
# Census gap fp-v1:0cb264d9488d: converted Lib/test snippets call
# ``support.gc_collect()`` (Lib/test support wrapper over gc.collect), but the
# layer_p2_libtest test.support shim did not expose the name, so every such
# pin died with AttributeError 'gc_collect' (ClearTest.test_clear_locals in
# test_frame was the reported signature). Guest objects are real host-CPython
# objects, so bridging to the host cycle collector is the faithful
# implementation; these pins gate name presence + return contract.
import from layer_p2_libtest { p2_libtest_run_snippet }

def expect_ok(name: str, src: str) {
    (ok, detail) = p2_libtest_run_snippet(src);
    assert ok , name + " RUN<" + detail + ">";
    assert detail == "ok" , name + " GOT<" + detail + ">";
}

test "support shim exposes gc_collect returning collect count" {
    expect_ok(
        "gc_collect_present",
        "from test import support\n"
        "\n"
        "def _t():\n"
        "    n = support.gc_collect()\n"
        "    assert isinstance(n, int), ('type', type(n))\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "support.gc_collect keeps live weakref target alive" {
    # Mirrors ClearTest.test_clear_locals' first invariant: gc_collect must not
    # resurrect/kill objects that are still strongly reachable.
    expect_ok(
        "gc_collect_live_weakref",
        "from test import support\n"
        "import weakref\n"
        "\n"
        "def _t():\n"
        "\n"
        "    class C:\n"
        "        pass\n"
        "    c = C()\n"
        "    wr = weakref.ref(c)\n"
        "    support.gc_collect()\n"
        "    assert wr() is not None, ('assertIsNot', None, wr())\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}
