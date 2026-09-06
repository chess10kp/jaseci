# Adversarial oracle pins: dict/set hash collisions with unequal keys.
#
# Ground truth from host CPython (python3): distinct user objects may share
# __hash__ while __eq__ is false; equal keys overwrite values but keep the first
# stored key object. Covers lookup, overwrite, delete, membership, set algebra,
# and insertion-order iteration.
import from pyc_first {
    PyObj,
    PyStr,
    to_host,
    is_error,
    exec_code,
    unmarshal,
    host_compile_marshal,
}

def run_src(src: str) -> dict[str, PyObj] {
    g: dict[str, PyObj] = {"__name__": PyStr(t="str", val="m")};
    outcome = exec_code(unmarshal(host_compile_marshal(src)), [], g);
    assert not is_error(outcome);
    return g;
}

test "dict/set collision: unequal equal-hash keys coexist" {
    src = "class AlwaysHash:\n"
        "    def __init__(self, tag):\n"
        "        self.tag = tag\n"
        "    def __hash__(self):\n"
        "        return 42\n"
        "    def __eq__(self, other):\n"
        "        return False\n"
        "a = AlwaysHash('a')\n"
        "b = AlwaysHash('b')\n"
        "d = {a: 1, b: 2}\n"
        "n = len(d)\n"
        "va = d[a]\n"
        "vb = d[b]\n"
        "mem_a = a in d\n"
        "mem_b = b in d\n"
        "keys = [k.tag for k in d.keys()]\n"
        "s = {a, b}\n"
        "sn = len(s)\n"
        "sa = a in s\n"
        "sb = b in s\n"
        "it = [m.tag for m in s]\n";
    g = run_src(src);
    assert to_host(g["n"]) == 2;
    assert to_host(g["va"]) == 1;
    assert to_host(g["vb"]) == 2;
    assert to_host(g["mem_a"]) == True;
    assert to_host(g["mem_b"]) == True;
    assert to_host(g["keys"]) == ["a", "b"];
    assert to_host(g["sn"]) == 2;
    assert to_host(g["sa"]) == True;
    assert to_host(g["sb"]) == True;
    assert to_host(g["it"]) == ["a", "b"];
}

test "dict/set collision: equal keys overwrite value, first key object kept" {
    src = "class EqHash:\n"
        "    def __init__(self, v):\n"
        "        self.v = v\n"
        "    def __hash__(self):\n"
        "        return 7\n"
        "    def __eq__(self, other):\n"
        "        return isinstance(other, EqHash) and self.v == other.v\n"
        "k1 = EqHash(1)\n"
        "k2 = EqHash(1)\n"
        "d = {k1: 'first'}\n"
        "d[k2] = 'second'\n"
        "val = d[k1]\n"
        "first_key = list(d.keys())[0] is k1\n"
        "n = len(d)\n"
        "del d[k2]\n"
        "after = len(d)\n"
        "s = {k1, k2}\n"
        "sn = len(s)\n";
    g = run_src(src);
    assert to_host(g["val"]) == "second";
    assert to_host(g["first_key"]) == True;
    assert to_host(g["n"]) == 1;
    assert to_host(g["after"]) == 0;
    assert to_host(g["sn"]) == 1;
}

test "dict/set collision: set algebra uses value equality" {
    src = "class AlwaysHash:\n"
        "    def __init__(self, tag):\n"
        "        self.tag = tag\n"
        "    def __hash__(self):\n"
        "        return 99\n"
        "    def __eq__(self, other):\n"
        "        return False\n"
        "a = AlwaysHash('a')\n"
        "b = AlwaysHash('b')\n"
        "c = AlwaysHash('c')\n"
        "u = len({a, b} | {b, c})\n"
        "i = len({a, b} & {b, c})\n"
        "d = len({a, b, c} - {b})\n"
        "x = len({a, b} ^ {b, c})\n";
    g = run_src(src);
    assert to_host(g["u"]) == 3;
    assert to_host(g["i"]) == 0;
    assert to_host(g["d"]) == 2;
    assert to_host(g["x"]) == 3;
}
