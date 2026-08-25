# Triage report: `conv_weakref_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_weakref.py
- guest leg: 0/74 marks
- pins: **6 passed** / 74 run (+35 quarantined of 109 extracted)

| pin | result | got |
|---|---|---|
| ReferencesTestCase.test_basic_ref | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'weakref\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| ReferencesTestCase.test_repr_failure_gh99184 | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "bridge-table: type \'weakref\' has policy BridgePolicy.FAIL but no to_host conversion arm"'> |
| ReferencesTestCase.test_constructor_kwargs | PASS | |
| ReferencesTestCase.test_ref_reuse | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'"> |
| ReferencesTestCase.test_proxy_reuse | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_basic_proxy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_unicode | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_index | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_div | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_matmul | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_shared_ref_without_callback | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_shared_proxy_without_callback | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_callable_proxy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_deletion | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_bool | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_iter | GUEST-WRONG-OUTPUT | RUN<'compile failed'> |
| ReferencesTestCase.test_proxy_next | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'IteratesWeakly\' object is not iterable"'> |
| ReferencesTestCase.test_proxy_bad_next | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'"> |
| ReferencesTestCase.test_proxy_reversed | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_proxy_hash | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_newstyle_number_ops | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_callbacks_protected | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_sf_bug_840829 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_callback_in_cycle | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_callback_reachable_one_way | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_callback_different_classes | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_callback_in_cycle_resurrection | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_callbacks_on_callback | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_gc_during_ref_creation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_gc_during_proxy_creation | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'proxy'"> |
| ReferencesTestCase.test_ref_created_during_del | PASS | |
| ReferencesTestCase.test_init | PASS | |
| ReferencesTestCase.test_classes | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "cannot create weak reference to \'object\' object"'> |
| ReferencesTestCase.test_equality | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'script_helper' from '<unknown>'"> |
| ReferencesTestCase.test_ordering | PASS | |
| ReferencesTestCase.test_hashing | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unhashable type: \'weakref\'"'> |
| ReferencesTestCase.test_callback_attribute | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_set_callback_attribute | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| ReferencesTestCase.test_callback_gcs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'"> |
| SubclassableWeakrefTestCase.test_subclass_refs | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'"> |
| SubclassableWeakrefTestCase.test_subclass_refs_dont_replace_standard_refs | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'getweakrefs'"> |
| SubclassableWeakrefTestCase.test_subclass_refs_dont_conflate_callbacks | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'getweakrefs'"> |
| SubclassableWeakrefTestCase.test_subclass_refs_with_slots | PASS | |
| SubclassableWeakrefTestCase.test_subclass_refs_with_cycle | PASS | |
| WeakMethodTestCase.test_alive | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakMethod'"> |
| WeakMethodTestCase.test_object_dead | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakMethod'"> |
| WeakMethodTestCase.test_method_dead | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakMethod'"> |
| WeakMethodTestCase.test_callback_when_object_dead | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakMethod'"> |
| WeakMethodTestCase.test_callback_when_method_dead | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakMethod'"> |
| WeakMethodTestCase.test_equality | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'script_helper' from '<unknown>'"> |
| WeakMethodTestCase.test_hashing | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakMethod'"> |
| MappingTestCase.test_weak_keyed_len_cycles | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_valued_len_cycles | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_make_weak_keyed_dict_from_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_make_weak_keyed_dict_from_weak_keyed_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_make_weak_valued_dict_from_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_make_weak_valued_dict_from_weak_valued_dict | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_make_weak_valued_dict_misc | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_weak_valued_dict_popitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_weak_keyed_dict_popitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_valued_dict_setdefault | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_weak_keyed_dict_setdefault | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_valued_dict_update | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_weak_valued_union_operators | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_weak_keyed_dict_update | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_keyed_delitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_keyed_union_operators | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_valued_delitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_weak_keyed_bad_delitem | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| MappingTestCase.test_weak_keyed_cascading_deletes | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'"> |
| MappingTestCase.test_make_weak_valued_dict_repr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'"> |
| MappingTestCase.test_make_weak_keyed_dict_repr | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'"> |
| ModuleTestCase.test_names | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'ReferenceType'"> |
| weakref.doctests:libreftest | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| ReferencesTestCase.test_ref_repr | decorator:support.cpython_only |
| ReferencesTestCase.test_cfunction | decorator:support.cpython_only |
| ReferencesTestCase.test_proxy_repr | decorator:support.cpython_only |
| ReferencesTestCase.test_trashcan_16602 | decorator:unittest.skipIf |
| ReferencesTestCase.test_no_memory_when_clearing | decorator:support.cpython_only |
| WeakMethodTestCase.test_no_cycles | decorator:support.cpython_only |
| MappingTestCase.test_threaded_weak_valued_setdefault | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_threaded_weak_valued_pop | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_threaded_weak_valued_consistency | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_weak_valued_consistency | decorator:support.cpython_only |
| MappingTestCase.test_threaded_weak_key_dict_copy | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_threaded_weak_key_dict_deepcopy | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_threaded_weak_value_dict_copy | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_threaded_weak_value_dict_deepcopy | decorator:threading_helper.requires_working_threading |
| MappingTestCase.test_remove_closure | decorator:support.cpython_only |
| ReferencesTestCase.test_multiple_selfref_callbacks | self.ref |
| MappingTestCase.test_weak_keyed_len_race | helper:check_len_race(self.addCleanup) |
| MappingTestCase.test_weak_valued_len_race | helper:check_len_race(self.addCleanup) |
| FinalizeTestCase.test_finalize | uses-self.A |
| FinalizeTestCase.test_arg_errors | uses-self.A |
| FinalizeTestCase.test_order | uses-self.A |
| FinalizeTestCase.test_all_freed | uses-self.A |
| ReferencesTestCase.test_basic_callback | host-raised:NameError: name 'self' is not defined |
| ReferencesTestCase.test_multiple_callbacks | host-raised:AttributeError: '_SelfNS' object has no attribute 'callback' |
| ReferencesTestCase.test_proxy_ref | host-raised:AttributeError: '_SelfNS' object has no attribute 'callback' |
| ReferencesTestCase.test_getweakrefcount | host-raised:AttributeError: '_SelfNS' object has no attribute 'callback' |
| ReferencesTestCase.test_getweakrefs | host-raised:AttributeError: '_SelfNS' object has no attribute 'callback' |
| ReferencesTestCase.test_callback_attribute_after_deletion | host-raised:AttributeError: '_SelfNS' object has no attribute 'callback' |
| MappingTestCase.test_weak_values | host-raised:NameError: name 'self' is not defined |
| MappingTestCase.test_weak_keys | host-raised:NameError: name 'self' is not defined |
| MappingTestCase.test_weak_keyed_iters | host-raised:NameError: name 'self' is not defined |
| MappingTestCase.test_weak_valued_iters | host-raised:NameError: name 'self' is not defined |
| MappingTestCase.test_weak_keys_destroy_while_iterating | host-raised:NameError: name 'self' is not defined |
| MappingTestCase.test_weak_values_destroy_while_iterating | host-raised:NameError: name 'self' is not defined |
| FinalizeTestCase.test_atexit | host-raised:AssertionError: Process return code is 1 command line: ['/var/tmp/lane8/.venv/bin/python', '-X', 'faulthandler', '-I', '-c', 'from test. |

## Expected vs got

### MappingTestCase.test_make_weak_keyed_dict_from_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_make_weak_keyed_dict_from_weak_keyed_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_make_weak_keyed_dict_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_make_weak_valued_dict_from_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_make_weak_valued_dict_from_weak_valued_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_make_weak_valued_dict_misc (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_make_weak_valued_dict_repr (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_weak_keyed_bad_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_keyed_cascading_deletes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'">

### MappingTestCase.test_weak_keyed_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_keyed_dict_popitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_keyed_dict_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_keyed_dict_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_keyed_len_cycles (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_keyed_union_operators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakKeyDictionary'">

### MappingTestCase.test_weak_valued_delitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_weak_valued_dict_popitem (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_weak_valued_dict_setdefault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_weak_valued_dict_update (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_weak_valued_len_cycles (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### MappingTestCase.test_weak_valued_union_operators (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakValueDictionary'">

### ModuleTestCase.test_names (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'ReferenceType'">

### ReferencesTestCase.test_basic_proxy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_basic_ref (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'weakref\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>

### ReferencesTestCase.test_callable_proxy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_callback_attribute (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callback_different_classes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callback_gcs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callback_in_cycle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callback_in_cycle_resurrection (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callback_reachable_one_way (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callbacks_on_callback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_callbacks_protected (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_classes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "cannot create weak reference to \'object\' object"'>

### ReferencesTestCase.test_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'script_helper' from '<unknown>'">

### ReferencesTestCase.test_gc_during_proxy_creation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_gc_during_ref_creation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_hashing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unhashable type: \'weakref\'"'>

### ReferencesTestCase.test_newstyle_number_ops (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_bad_next (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaisesRegex: message mismatch'">

### ReferencesTestCase.test_proxy_bool (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_deletion (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_div (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_hash (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_index (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_iter (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'compile failed'>

### ReferencesTestCase.test_proxy_matmul (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_next (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'IteratesWeakly\' object is not iterable"'>

### ReferencesTestCase.test_proxy_reuse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_reversed (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_proxy_unicode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_ref_reuse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'">

### ReferencesTestCase.test_repr_failure_gh99184 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "bridge-table: type \'weakref\' has policy BridgePolicy.FAIL but no to_host conversion arm"'>

### ReferencesTestCase.test_set_callback_attribute (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_sf_bug_840829 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### ReferencesTestCase.test_shared_proxy_without_callback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'proxy'">

### ReferencesTestCase.test_shared_ref_without_callback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'weakref.ref expected 1 argument'">

### SubclassableWeakrefTestCase.test_subclass_refs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'">

### SubclassableWeakrefTestCase.test_subclass_refs_dont_conflate_callbacks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'getweakrefs'">

### SubclassableWeakrefTestCase.test_subclass_refs_dont_replace_standard_refs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'getweakrefs'">

### WeakMethodTestCase.test_alive (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakMethod'">

### WeakMethodTestCase.test_callback_when_method_dead (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakMethod'">

### WeakMethodTestCase.test_callback_when_object_dead (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakMethod'">

### WeakMethodTestCase.test_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'script_helper' from '<unknown>'">

### WeakMethodTestCase.test_hashing (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakMethod'">

### WeakMethodTestCase.test_method_dead (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakMethod'">

### WeakMethodTestCase.test_object_dead (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'WeakMethod'">

### weakref.doctests:libreftest (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'gc_collect' from '<unknown>'">
