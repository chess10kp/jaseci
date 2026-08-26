"""Dynamic slice-object subscript oracle pins (TODO item 20, slice family).

Locks the shared mp_subscript / mp_ass_subscript / mp_del_subscript contract:
a dynamic PySlice VALUE (s = slice(1, 7, 2) built at runtime) must route to the
same slice path as inline ``l[1:7:2]`` syntax on every sequence shape -- get,
assign, and delete alike. Every expectation below is a CPython oracle literal.
"""

import from layer_p2_libtest { p2_libtest_run_snippet }


def _run(src: str) -> tuple[bool, str] {
    return p2_libtest_run_snippet(src);
}


test "dynamic-slice: list get routes to slice path" {
    (ok, detail) = _run(
        "l = list(range(10))\n"
        "s = slice(1, 7, 2)\n"
        "assert l[s] == [1, 3, 5], l[s]\n"
        "assert l[1:7:2] == l[s]\n"
        "print('ok')\n"
    );
    assert ok, "RUN<" + detail + ">";
    assert detail == "ok", "GOT<" + detail + ">";
}

test "dynamic-slice: list stepped assign accepts any iterable value" {
    (ok, detail) = _run(
        "l = list(range(10))\n"
        "s = slice(1, 7, 2)\n"
        "l[s] = ['a', 'b', 'c']\n"
        "assert l == [0, 'a', 2, 'b', 4, 'c', 6, 7, 8, 9], l\n"
        "print('ok')\n"
    );
    assert ok, "RUN<" + detail + ">";
    assert detail == "ok", "GOT<" + detail + ">";
}

test "dynamic-slice: list del removes sliced indices" {
    (ok, detail) = _run(
        "l = list(range(10))\n"
        "s = slice(1, 7, 2)\n"
        "del l[s]\n"
        "assert l == [0, 2, 4, 6, 7, 8, 9], l\n"
        "print('ok')\n"
    );
    assert ok, "RUN<" + detail + ">";
    assert detail == "ok", "GOT<" + detail + ">";
}

test "dynamic-slice: str/bytes/tuple reads match inline syntax" {
    (ok, detail) = _run(
        "s = slice(1, 7, 2)\n"
        "assert 'abcdefgh'[s] == 'bdf'\n"
        "assert b'abcdefgh'[s] == b'bdf'\n"
        "assert tuple(range(10))[s] == (1, 3, 5)\n"
        "print('ok')\n"
    );
    assert ok, "RUN<" + detail + ">";
    assert detail == "ok", "GOT<" + detail + ">";
}

test "dynamic-slice: user setitem/delitem receive the slice object" {
    (ok, detail) = _run(
        "seen = []\n"
        "class Y:\n"
        "    def __setitem__(self, i, v):\n"
        "        seen.append(('set', type(i).__name__, i.start, i.stop, i.step, v))\n"
        "    def __delitem__(self, i):\n"
        "        seen.append(('del', type(i).__name__))\n"
        "y = Y()\n"
        "s = slice(1, 7, 2)\n"
        "y[s] = 5\n"
        "del y[s]\n"
        "assert seen == [('set', 'slice', 1, 7, 2, 5), ('del', 'slice')], seen\n"
        "print('ok')\n"
    );
    assert ok, "RUN<" + detail + ">";
    assert detail == "ok", "GOT<" + detail + ">";
}

test "dynamic-slice: zero step raises ValueError on get/assign/del" {
    (ok, detail) = _run(
        "z = slice(1, 7, 0)\n"
        "msgs = []\n"
        "l = [1, 2, 3]\n"
        "for op in ('get', 'set', 'del'):\n"
        "    try:\n"
        "        if op == 'get':\n"
        "            l[z]\n"
        "        elif op == 'set':\n"
        "            l[z] = []\n"
        "        else:\n"
        "            del l[z]\n"
        "    except ValueError as e:\n"
        "        msgs.append(str(e))\n"
        "assert msgs == ['slice step cannot be zero'] * 3, msgs\n"
        "print('ok')\n"
    );
    assert ok, "RUN<" + detail + ">";
    assert detail == "ok", "GOT<" + detail + ">";
}
