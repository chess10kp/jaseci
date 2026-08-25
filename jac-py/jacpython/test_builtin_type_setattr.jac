# Host-builtin setattr policy pins (allow-on-subclass-only, CPython
# Objects/typeobject.c type_setattro): a static builtin/extension type rejects
# every attribute write with the canonical TypeError -- regardless of the value
# -- while subclasses (heap types) accept writes that stick. Regression pins
# in the layer0_replay idiom: import layer0_replay_harness (NOT layer0_replay)
# for a clean ceval slate.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

# ---------------- immutable builtin types reject writes ----------------
test "builtin setattr: static builtin type rejects every write" {
    src = "class TestImmutableBuiltinSetattr(unittest.TestCase):\n"
    "    def test_int_type_rejects_write(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            int._value_repr_ = lambda v: repr(v)\n"
    "    def test_str_type_rejects_write(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            str._custom_flag_ = True\n"
    "    def test_rejection_precedes_value_conversion(self):\n"
    "        class Guest:\n"
    "            pass\n"
    "        # CPython raises before examining the value; even an arbitrary\n"
    "        # guest object must not change the outcome.\n"
    "        with self.assertRaises(TypeError):\n"
    "            int._value_repr_ = Guest()\n"
    "    def test_error_message_names_the_type(self):\n"
    "        try:\n"
    "            int._value_repr_ = 1\n"
    "        except TypeError as e:\n"
    "            self.assertEqual(\n"
    "                str(e),\n"
    "                \"can't set attributes of built-in/extension type 'int'\",\n"
    "            )\n"
    "        else:\n"
    "            self.fail('no TypeError')\n"
    "    def test_setattr_builtin_same_rejection(self):\n"
    "        with self.assertRaises(TypeError):\n"
    "            setattr(tuple, '_value_repr_', 1)\n";
    result = layer1_replay_source(src);
    assert result.passed == 5;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# ---------------- subclass writes stick ----------------
test "builtin setattr: subclass attribute writes stick" {
    src = "class TestBuiltinSubclassSetattr(unittest.TestCase):\n"
    "    def test_class_attr_write_sticks(self):\n"
    "        class MyInt(int):\n"
    "            pass\n"
    "        MyInt._value_repr_ = 'V'\n"
    "        self.assertEqual(MyInt._value_repr_, 'V')\n"
    "    def test_write_visible_on_instances(self):\n"
    "        class MyStr(str):\n"
    "            pass\n"
    "        MyStr._tag_ = 'T'\n"
    "        self.assertEqual(MyStr('x')._tag_, 'T')\n"
    "    def test_plain_instance_rejects_write(self):\n"
    "        with self.assertRaises(AttributeError):\n"
    "            setattr(5, '_x_', 1)\n";
    result = layer1_replay_source(src);
    assert result.passed == 3;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
