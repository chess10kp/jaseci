"""P2 facade parity: native struct public-name assembly vs host stdlib.

jac-py/Modules/structmodule.{c,jac} stay the staged c2jac corpus pair
(staging=lift); jac-py/jacpython/_structmodule.jac carries the accelerator
truth (wave 13). This file gates the Lib/struct.py layer -- the public-name
assembly in jac-py/jacpython/struct.jac -- against the pinned host oracle.
Expected values verified against the host stdlib ``struct`` at authoring time.
Run with JACPATH=jac-py/jacpython (same pattern as test_p2_facade_parity).
"""

import from struct {
    Struct,
    calcsize,
    pack,
    pack_into,
    unpack,
    unpack_from,
    iter_unpack,
}


test "facade: Struct re-exported under public name" {
    s = Struct(">ib2s");
    # CPython Struct.format getset: exact constructor string.
    assert s.format == ">ib2s" , s.format;
    assert s.size == 7 , s.size;  # standard mode: no alignment padding
    assert repr(s) == "Struct('>ib2s')" , repr(s);
}


test "facade: module functions round trip" {
    assert calcsize("4s") == 4 , "calcsize";
    data = pack(">h i", 258, 7);
    assert data == b"\x01\x02\x00\x00\x00\x07" , data;
    (h, i) = unpack(">h i", data);
    assert h == 258 and i == 7 , data;
    buf = bytearray(12);
    pack_into(">i", buf, 4, -1);
    (v,) = unpack_from(">i", buf, 4);
    assert v == -1 , buf;
    (a, b) = unpack_from("<2h", b"\x01\x00\x02\x00");
    assert a == 1 and b == 2 , "unpack_from";
}


test "facade: iter_unpack through the facade" {
    it = iter_unpack("<h", b"\x01\x00\x02\x00");
    (v1,) = it.__next__();
    (v2,) = it.__next__();
    assert v1 == 1 and v2 == 2 , (v1, v2);
}


test "facade: error surface raises through registry convention" {
    raised = False;
    got = "";
    try {
        pack("<i", "x");
    } except Exception as e {
        raised = True;
        got = str(e);
    }
    assert raised , "expected an error";
    assert got == "required argument is not an integer" , got;
}
