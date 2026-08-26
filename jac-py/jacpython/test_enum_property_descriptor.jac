# enum.property descriptor-routing regression pins.
#
# stdlib enum's `property` (a guest DynamicClassAttribute subclass) is stored
# in the enum class dict under `name`/`value`. Instance attribute lookup used
# to fall through every native-descriptor isinstance arm in
# default_user_getattro/descriptor_get and hand back the RAW descriptor object,
# so member `.name`/`.value` returned `<enum.property object>` instead of
# running its __get__. The fix routes user-defined descriptors through their
# __get__/__set__/__delete__ with CPython's data-descriptor priority. Each pin
# replays the guest behavior via layer_p2_libtest and pins the CPython-oracle
# outcome (probed against python3.14).
import from layer_p2_libtest { p2_libtest_run_snippet }

def expect_ok(name: str, src: str) {
    (ok, detail) = p2_libtest_run_snippet(src);
    assert ok , name + " RUN<" + detail + ">";
    assert detail == "ok" , name + " GOT<" + detail + ">";
}

test "IntEnum member .name/.value run the enum.property descriptor" {
    expect_ok(
        "intenum_member_name_value",
        "import enum\n"
        "\n"
        "def _t():\n"
        "    class Color(enum.IntEnum):\n"
        "        RED = 1\n"
        "        GREEN = 2\n"
        "    assert Color.RED.name == 'RED'\n"
        "    assert Color.GREEN.value == 2\n"
        "    assert int(Color.RED) == 1\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "plain Enum member .name/.value run the descriptor" {
    expect_ok(
        "plain_enum_member_name_value",
        "import enum\n"
        "\n"
        "def _t():\n"
        "    class Color(enum.Enum):\n"
        "        RED = 'red'\n"
        "    assert Color.RED.name == 'RED'\n"
        "    assert Color.RED.value == 'red'\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "user-defined data descriptor outranks the instance dict" {
    expect_ok(
        "user_data_descriptor_priority",
        "def _t():\n"
        "    class Desc:\n"
        "        def __get__(self, obj, objtype=None):\n"
        "            return 'from-desc'\n"
        "        def __set__(self, obj, value):\n"
        "            raise AttributeError('read-only')\n"
        "    class C:\n"
        "        pass\n"
        "    C.attr = Desc()\n"
        "    c = C()\n"
        "    c.__dict__['attr'] = 'from-instance-dict'\n"
        "    assert c.attr == 'from-desc', c.attr\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "user-defined __set__ rejects writes through the descriptor" {
    expect_ok(
        "user_descriptor_set_rejects",
        "def _t():\n"
        "    class ReadOnly:\n"
        "        def __get__(self, obj, objtype=None):\n"
        "            return 42\n"
        "        def __set__(self, obj, value):\n"
        "            raise AttributeError('cannot set')\n"
        "    class C:\n"
        "        ro = ReadOnly()\n"
        "    c = C()\n"
        "    assert c.ro == 42\n"
        "    try:\n"
        "        c.ro = 7\n"
        "    except AttributeError:\n"
        "        assert c.ro == 42\n"
        "    else:\n"
        "        raise AssertionError('set went to instance dict')\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}

test "non-data user descriptor defers to the instance dict" {
    expect_ok(
        "nondata_descriptor_defers",
        "def _t():\n"
        "    class NonData:\n"
        "        def __get__(self, obj, objtype=None):\n"
        "            return 'from-desc'\n"
        "    class C:\n"
        "        attr = NonData()\n"
        "    c = C()\n"
        "    assert c.attr == 'from-desc'\n"
        "    c.attr = 'from-instance'\n"
        "    assert c.attr == 'from-instance', c.attr\n"
        "try:\n"
        "    _t()\n"
        "except BaseException as _e:\n"
        "    print('ORACLE_EXC ' + type(_e).__name__ + ' ' + repr(str(_e)))\n"
        "else:\n"
        "    print('ok')\n"
    );
}
