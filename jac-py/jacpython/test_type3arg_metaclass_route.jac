# 3-arg type() metaclass-delegation regression pins.
#
# CPython type_new_impl hands the WHOLE type(name, bases, ns, **kwds) call to
# the bases' winning metatype when that metatype's tp_new is not type_new --
# stdlib enum relies on it (EnumType.__new__ creates IntFlag/Flag via
# `type(cls_name, (etype,), body, boundary=..., _simple=True)`). Host-routing
# the call instead leaked the keywords into __init_subclass__
# ("EnumCheck.__init_subclass__() takes no keyword arguments") and bypassed
# guest EnumType.__new__, so every enum import crashed at first use. Each pin
# replays the guest behavior via layer_p2_libtest and pins the CPython-oracle
# outcome (probed against python3.14).
#
# NOTE member `.name`/`.value` attribute access still returns the raw
# enum.property object (a separate descriptor-binding gap), so these pins
# deliberately probe members through value lookup / int() instead.
import from layer_p2_libtest { p2_libtest_run_snippet }

def expect_ok(name: str, src: str) {
    (ok, detail) = p2_libtest_run_snippet(src);
    assert ok , name + " RUN<" + detail + ">";
    assert detail == "ok" , name + " GOT<" + detail + ">";
}

test "IntFlag member survives guest enum import" {
    expect_ok(
        "intflag_member",
        "import enum\n"
        "\n"
        "def _t():\n"
        "    class X(enum.IntFlag):\n"
        "        A = 1\n"
        "    assert int(X.A) == 1\n"
        "    assert X(1) is X.A\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "plain Enum class creation works again" {
    expect_ok(
        "plain_enum_member",
        "import enum\n"
        "\n"
        "def _t():\n"
        "    class Color(enum.Enum):\n"
        "        RED = 1\n"
        "    assert list(Color) == [Color.RED]\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "3-arg type() with class keywords delegates to base's metaclass" {
    expect_ok(
        "type3_kwargs_delegate",
        "def _t():\n"
        "    seen = {}\n"
        "    class Meta(type):\n"
        "        def __new__(mcls, name, bases, ns, **kwds):\n"
        "            seen.update(kwds)\n"
        "            return super().__new__(mcls, name, bases, ns)\n"
        "    class Base(metaclass=Meta):\n"
        "        pass\n"
        "    C = type('C', (Base,), {}, tag=7)\n"
        "    assert C.__class__ is Meta\n"
        "    assert C.__bases__ == (Base,)\n"
        "    assert seen == {'tag': 7}, seen\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "kwarg-less 3-arg type() still routes through guest metaclass" {
    expect_ok(
        "type3_noargs_delegate",
        "def _t():\n"
        "    made = []\n"
        "    class Meta(type):\n"
        "        def __new__(mcls, name, bases, ns):\n"
        "            made.append(name)\n"
        "            return super().__new__(mcls, name, bases, ns)\n"
        "    class Base(metaclass=Meta):\n"
        "        pass\n"
        "    C = type('C', (Base,), {})\n"
        "    assert C.__class__ is Meta\n"
        "    # CPython delegates BOTH creations through Meta.__new__\n"
        "    assert made == ['Base', 'C'], made\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "plain 3-arg type() keeps default-type behavior" {
    expect_ok(
        "type3_default_type",
        "def _t():\n"
        "    C = type('C', (), {'x': 3})\n"
        "    assert C.__name__ == 'C'\n"
        "    assert C().x == 3\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}
