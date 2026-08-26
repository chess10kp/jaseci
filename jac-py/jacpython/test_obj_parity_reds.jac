# Census-0824 parity-red regression pins (objects lane).
#
# Fingerprint fp "cannot use 'property_ctor' as a set element (unhashable
# type: 'property_ctor')" blocked ~45 pins across test_copy / test_pprint /
# test_structseq / test_types: CPython's stdlib puts the property TYPE and
# property instances into sets and type-keyed registries (copy._copy_dispatch,
# codec registries, ABC caches), which requires the identity hash added in
# feat(vm): identity hash for property objects (aa434beb2). These oracle pins
# hold the behavior so the census red cannot resurface.
import from layer0_replay_harness {
    ReplayResult,
    layer1_replay_source,
}

test "obj parity: property type and instances are hashable" {
    src = "class TestPropertyHashable(unittest.TestCase):\n"
    "    def test_property_type_in_set(self):\n"
    "        s = {property}\n"
    "        self.assertIn(property, s)\n"
    "    def test_instance_hash_is_stable(self):\n"
    "        p = property()\n"
    "        self.assertEqual(hash(p), hash(p))\n"
    "    def test_instance_as_dict_key(self):\n"
    "        d = {}\n"
    "        p = property()\n"
    "        d[p] = 1\n"
    "        self.assertEqual(d[p], 1)\n"
    "    def test_distinct_instances_distinct_keys(self):\n"
    "        d = {property(): 1}\n"
    "        q = property()\n"
    "        d[q] = 2\n"
    "        self.assertEqual(len(d), 2)\n"
    "        self.assertEqual(d[q], 2)\n";
    result = layer1_replay_source(src);
    assert result.passed == 4;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}

# copy.py builds its dispatch table as {type: func} over builtin types; the
# census red fired the moment the registry touched `property`. Mirror the
# registry idiom directly.
test "obj parity: property in type-keyed registry idiom" {
    src = "class TestRegistryIdiom(unittest.TestCase):\n"
    "    def test_type_keyed_registry_roundtrip(self):\n"
    "        registry = {}\n"
    "        registry[property] = lambda o: o\n"
    "        self.assertTrue(callable(registry[property]))\n"
    "    def test_set_difference_over_descriptor_types(self):\n"
    "        known = {property}\n"
    "        probe = {property}\n"
    "        self.assertEqual(probe - known, set())\n";
    result = layer1_replay_source(src);
    assert result.passed == 2;
    assert result.skipped == 0;
    assert result.failed == 0;
    assert result.errored == 0;
}
