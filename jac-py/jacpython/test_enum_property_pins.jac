# Guest-descriptor resolution pins (lane typesys/enum -- gap probe finding).
#
# Surface under test: ceval's default_user_getattro instance-dict arm and
# descriptor_get's generalized guest-descriptor dispatch.
#
# Ground truth recorded from host python3.14.7:
#   - an object whose CLASS defines __get__ routes through the descriptor
#     protocol on both instance and class access (slot_tp_descr_get); the
#     descriptor itself decides what None-instance means;
#   - values stored in an INSTANCE dict stay raw -- CPython applies function
#     binding only to class/MRO entries, never per-instance attributes;
#   - enum.property (Lib/enum.py, subclass of types.DynamicClassAttribute)
#     depends on BOTH rules: instance access must invoke its __get__, and its
#     own self.fget read (an instance-dict entry) must yield the unbound
#     getter so fget(member) receives exactly one argument.
#
# Before the fix the VM returned raw guest descriptors on instance access and
# implicitly bound instance-dict functions, so enum.property getters received
# the descriptor as an extra leading argument (overflowing the one-argument
# getter).

import from layer_p2_libtest { p2_libtest_run_snippet }


test "enumprop: guest descriptor instance access routes through __get__" {
    snippet = (
        "class Desc:\n"
        "    def __init__(self, fget):\n"
        "        self.fget = fget\n"
        "    def __get__(self, obj, cls=None):\n"
        "        if obj is None:\n"
        "            return self\n"
        "        return self.fget(obj)\n"
        "\n"
        "class C:\n"
        "    @Desc\n"
        "    def x(self):\n"
        "        return 42\n"
        "\n"
        "c = C()\n"
        "assert c.x == 42, ('instance access bypassed __get__', c.x)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_run_snippet(snippet);
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "enumprop: class-level access invokes __get__(None, owner)" {
    snippet = (
        "class Desc:\n"
        "    def __init__(self, val):\n"
        "        self.val = val\n"
        "    def __get__(self, obj, cls=None):\n"
        "        if obj is None:\n"
        "            return self.val\n"
        "        return obj.stored * 2\n"
        "\n"
        "class C:\n"
        "    tag = Desc('klass')\n"
        "    def __init__(self):\n"
        "        self.stored = 10\n"
        "\n"
        "c = C()\n"
        "assert C.tag == 'klass', ('class access wrong', C.tag)\n"
        "assert c.tag == 20, ('instance access wrong', c.tag)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_run_snippet(snippet);
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "enumprop: instance-dict callable stays raw (unbound)" {
    # CPython binds only class/MRO entries; a function assigned onto an
    # instance is called WITHOUT a prepended receiver.
    snippet = (
        "def helper(v):\n"
        "    return v * 2\n"
        "\n"
        "class C:\n"
        "    pass\n"
        "\n"
        "c = C()\n"
        "c.helper = helper\n"
        "got = c.helper(21)\n"
        "assert got == 42, ('instance-dict function was bound', got)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_run_snippet(snippet);
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}

test "enumprop: enum.property getter fires end-to-end" {
    # The motivating case: Lib/enum.py's property reads self.fget off its own
    # instance dict inside __get__; that read must be raw and the call must
    # pass exactly the enum member.
    snippet = (
        "import enum\n"
        "\n"
        "class Color(enum.Enum):\n"
        "    RED = 1\n"
        "    GREEN = 2\n"
        "\n"
        "    @enum.property\n"
        "    def doubled(self):\n"
        "        return self._value_ * 2\n"
        "\n"
        "r = Color.RED.doubled\n"
        "g = Color.GREEN.doubled\n"
        "assert r == 2, ('RED.doubled wrong', r)\n"
        "assert g == 4, ('GREEN.doubled wrong', g)\n"
        "print('ok')\n"
    );
    (ok, detail) = p2_libtest_run_snippet(snippet);
    assert ok , "RUN<" + detail + ">";
    assert detail == "ok" , "GOT<" + detail + ">";
}
