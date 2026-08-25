# Guest setattr policy on host builtin types (CPython type_setattro).
# Immutable builtin bases (int/str/bool/...) reject attribute writes with
# TypeError -- only heap types have a writable type dict -- while a guest
# subclass of a builtin accepts writes that STICK (class dict read-back and
# instance visibility). Regression tests in the layer0_replay idiom: import
# layer0_replay_harness (NOT layer0_replay) for a clean ceval slate.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

test "builtin setattr: immutable base rejects, guest subclass sticks" {
    src = "class TestBuiltinTypeSetattr(unittest.TestCase):\n"
    "    def test_immutable_base_rejects_setattr(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            int._value_repr_ = lambda v: hex(v)\n"
    "        with self.assertRaises(TypeError):\n"
    "            str._value_repr_ = 'x'\n"
    "        with self.assertRaises(TypeError):\n"
    "            bool.custom_flag = True\n"
    "    def test_guest_subclass_of_builtin_sticks(self):\n"
    "        class MyInt(int):\n"
    "            pass\n"
    "        MyInt._value_repr_ = 41\n"
    "        self.assertEqual(MyInt._value_repr_, 41)\n"
    "        m = MyInt(3)\n"
    "        self.assertEqual(m._value_repr_, 41)\n"
    "        MyInt._value_repr_ = 42\n"
    "        self.assertEqual(MyInt._value_repr_, 42)\n"
    "    def test_delattr_on_immutable_base_raises(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            delattr(int, '__repr__')\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
