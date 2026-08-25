# Triage report: `conv_set_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_set.py
- guest leg: 0/300 marks
- pins: **257 passed** / 300 run (+246 quarantined of 546 extracted)

| pin | result | got |
|---|---|---|
| TestBasicOpsEmpty.test_repr | PASS | |
| TestBasicOpsSingleton.test_repr | PASS | |
| TestBasicOpsTuple.test_repr | PASS | |
| TestBasicOpsTriple.test_repr | PASS | |
| TestBasicOpsEmpty.test_length | PASS | |
| TestBasicOpsSingleton.test_length | PASS | |
| TestBasicOpsTuple.test_length | PASS | |
| TestBasicOpsTriple.test_length | PASS | |
| TestBasicOpsString.test_length | PASS | |
| TestBasicOpsBytes.test_length | PASS | |
| TestBasicOpsEmpty.test_self_equality | PASS | |
| TestBasicOpsSingleton.test_self_equality | PASS | |
| TestBasicOpsTuple.test_self_equality | PASS | |
| TestBasicOpsTriple.test_self_equality | PASS | |
| TestBasicOpsString.test_self_equality | PASS | |
| TestBasicOpsBytes.test_self_equality | PASS | |
| TestBasicOpsEmpty.test_equivalent_equality | PASS | |
| TestBasicOpsSingleton.test_equivalent_equality | PASS | |
| TestBasicOpsTuple.test_equivalent_equality | PASS | |
| TestBasicOpsTriple.test_equivalent_equality | PASS | |
| TestBasicOpsString.test_equivalent_equality | PASS | |
| TestBasicOpsBytes.test_equivalent_equality | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_copy | PASS | |
| TestBasicOpsSingleton.test_copy | PASS | |
| TestBasicOpsTuple.test_copy | PASS | |
| TestBasicOpsTriple.test_copy | PASS | |
| TestBasicOpsString.test_copy | PASS | |
| TestBasicOpsBytes.test_copy | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_self_union | PASS | |
| TestBasicOpsSingleton.test_self_union | PASS | |
| TestBasicOpsTuple.test_self_union | PASS | |
| TestBasicOpsTriple.test_self_union | PASS | |
| TestBasicOpsString.test_self_union | PASS | |
| TestBasicOpsBytes.test_self_union | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_empty_union | PASS | |
| TestBasicOpsSingleton.test_empty_union | PASS | |
| TestBasicOpsTuple.test_empty_union | PASS | |
| TestBasicOpsTriple.test_empty_union | PASS | |
| TestBasicOpsString.test_empty_union | PASS | |
| TestBasicOpsBytes.test_empty_union | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_union_empty | PASS | |
| TestBasicOpsSingleton.test_union_empty | PASS | |
| TestBasicOpsTuple.test_union_empty | PASS | |
| TestBasicOpsTriple.test_union_empty | PASS | |
| TestBasicOpsString.test_union_empty | PASS | |
| TestBasicOpsBytes.test_union_empty | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_self_intersection | PASS | |
| TestBasicOpsSingleton.test_self_intersection | PASS | |
| TestBasicOpsTuple.test_self_intersection | PASS | |
| TestBasicOpsTriple.test_self_intersection | PASS | |
| TestBasicOpsString.test_self_intersection | PASS | |
| TestBasicOpsBytes.test_self_intersection | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_empty_intersection | PASS | |
| TestBasicOpsSingleton.test_empty_intersection | PASS | |
| TestBasicOpsTuple.test_empty_intersection | PASS | |
| TestBasicOpsTriple.test_empty_intersection | PASS | |
| TestBasicOpsString.test_empty_intersection | PASS | |
| TestBasicOpsBytes.test_empty_intersection | PASS | |
| TestBasicOpsEmpty.test_intersection_empty | PASS | |
| TestBasicOpsSingleton.test_intersection_empty | PASS | |
| TestBasicOpsTuple.test_intersection_empty | PASS | |
| TestBasicOpsTriple.test_intersection_empty | PASS | |
| TestBasicOpsString.test_intersection_empty | PASS | |
| TestBasicOpsBytes.test_intersection_empty | PASS | |
| TestBasicOpsEmpty.test_self_isdisjoint | PASS | |
| TestBasicOpsSingleton.test_self_isdisjoint | PASS | |
| TestBasicOpsTuple.test_self_isdisjoint | PASS | |
| TestBasicOpsTriple.test_self_isdisjoint | PASS | |
| TestBasicOpsString.test_self_isdisjoint | PASS | |
| TestBasicOpsBytes.test_self_isdisjoint | PASS | |
| TestBasicOpsEmpty.test_empty_isdisjoint | PASS | |
| TestBasicOpsSingleton.test_empty_isdisjoint | PASS | |
| TestBasicOpsTuple.test_empty_isdisjoint | PASS | |
| TestBasicOpsTriple.test_empty_isdisjoint | PASS | |
| TestBasicOpsString.test_empty_isdisjoint | PASS | |
| TestBasicOpsBytes.test_empty_isdisjoint | PASS | |
| TestBasicOpsEmpty.test_isdisjoint_empty | PASS | |
| TestBasicOpsSingleton.test_isdisjoint_empty | PASS | |
| TestBasicOpsTuple.test_isdisjoint_empty | PASS | |
| TestBasicOpsTriple.test_isdisjoint_empty | PASS | |
| TestBasicOpsString.test_isdisjoint_empty | PASS | |
| TestBasicOpsBytes.test_isdisjoint_empty | PASS | |
| TestBasicOpsEmpty.test_self_symmetric_difference | PASS | |
| TestBasicOpsSingleton.test_self_symmetric_difference | PASS | |
| TestBasicOpsTuple.test_self_symmetric_difference | PASS | |
| TestBasicOpsTriple.test_self_symmetric_difference | PASS | |
| TestBasicOpsString.test_self_symmetric_difference | PASS | |
| TestBasicOpsBytes.test_self_symmetric_difference | PASS | |
| TestBasicOpsEmpty.test_empty_symmetric_difference | PASS | |
| TestBasicOpsSingleton.test_empty_symmetric_difference | PASS | |
| TestBasicOpsTuple.test_empty_symmetric_difference | PASS | |
| TestBasicOpsTriple.test_empty_symmetric_difference | PASS | |
| TestBasicOpsString.test_empty_symmetric_difference | PASS | |
| TestBasicOpsBytes.test_empty_symmetric_difference | PASS | |
| TestBasicOpsEmpty.test_self_difference | PASS | |
| TestBasicOpsSingleton.test_self_difference | PASS | |
| TestBasicOpsTuple.test_self_difference | PASS | |
| TestBasicOpsTriple.test_self_difference | PASS | |
| TestBasicOpsString.test_self_difference | PASS | |
| TestBasicOpsBytes.test_self_difference | PASS | |
| TestBasicOpsEmpty.test_empty_difference | PASS | |
| TestBasicOpsSingleton.test_empty_difference | PASS | |
| TestBasicOpsTuple.test_empty_difference | PASS | |
| TestBasicOpsTriple.test_empty_difference | PASS | |
| TestBasicOpsString.test_empty_difference | PASS | |
| TestBasicOpsBytes.test_empty_difference | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_empty_difference_rev | PASS | |
| TestBasicOpsSingleton.test_empty_difference_rev | PASS | |
| TestBasicOpsTuple.test_empty_difference_rev | PASS | |
| TestBasicOpsTriple.test_empty_difference_rev | PASS | |
| TestBasicOpsString.test_empty_difference_rev | PASS | |
| TestBasicOpsBytes.test_empty_difference_rev | PASS | |
| TestBasicOpsEmpty.test_iteration | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__length_hint__'">` |
| TestBasicOpsSingleton.test_iteration | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__length_hint__'">` |
| TestBasicOpsTuple.test_iteration | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__length_hint__'">` |
| TestBasicOpsTriple.test_iteration | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__length_hint__'">` |
| TestBasicOpsString.test_iteration | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__length_hint__'">` |
| TestBasicOpsBytes.test_iteration | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__length_hint__'">` |
| TestBasicOpsEmpty.test_pickling | PASS | |
| TestBasicOpsSingleton.test_pickling | PASS | |
| TestBasicOpsTuple.test_pickling | PASS | |
| TestBasicOpsTriple.test_pickling | PASS | |
| TestBasicOpsString.test_pickling | PASS | |
| TestBasicOpsBytes.test_pickling | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'> |
| TestBasicOpsEmpty.test_issue_37219 | PASS | |
| TestBasicOpsSingleton.test_issue_37219 | PASS | |
| TestBasicOpsTuple.test_issue_37219 | PASS | |
| TestBasicOpsTriple.test_issue_37219 | PASS | |
| TestBasicOpsString.test_issue_37219 | PASS | |
| TestBasicOpsBytes.test_issue_37219 | PASS | |
| TestBasicOpsSingleton.test_in | PASS | |
| TestBasicOpsSingleton.test_not_in | PASS | |
| TestBasicOpsTuple.test_in | PASS | |
| TestBasicOpsTuple.test_not_in | PASS | |
| TestExceptionPropagation.test_instanceWithException | PASS | |
| TestExceptionPropagation.test_instancesWithoutException | PASS | |
| TestExceptionPropagation.test_changingSizeWhileIterating | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'no exception when changing size during iteration'"> |
| TestSetOfSets.test_constructor | PASS | |
| TestBinaryOps.test_eq | PASS | |
| TestBinaryOps.test_union_subset | PASS | |
| TestBinaryOps.test_union_superset | PASS | |
| TestBinaryOps.test_union_overlap | PASS | |
| TestBinaryOps.test_union_non_overlap | PASS | |
| TestBinaryOps.test_intersection_subset | PASS | |
| TestBinaryOps.test_intersection_superset | PASS | |
| TestBinaryOps.test_intersection_overlap | PASS | |
| TestBinaryOps.test_intersection_non_overlap | PASS | |
| TestBinaryOps.test_isdisjoint_subset | PASS | |
| TestBinaryOps.test_isdisjoint_superset | PASS | |
| TestBinaryOps.test_isdisjoint_overlap | PASS | |
| TestBinaryOps.test_isdisjoint_non_overlap | PASS | |
| TestBinaryOps.test_sym_difference_subset | PASS | |
| TestBinaryOps.test_sym_difference_superset | PASS | |
| TestBinaryOps.test_sym_difference_overlap | PASS | |
| TestBinaryOps.test_sym_difference_non_overlap | PASS | |
| TestUpdateOps.test_union_subset | PASS | |
| TestUpdateOps.test_union_superset | PASS | |
| TestUpdateOps.test_union_overlap | PASS | |
| TestUpdateOps.test_union_non_overlap | PASS | |
| TestUpdateOps.test_union_method_call | PASS | |
| TestUpdateOps.test_intersection_subset | PASS | |
| TestUpdateOps.test_intersection_superset | PASS | |
| TestUpdateOps.test_intersection_overlap | PASS | |
| TestUpdateOps.test_intersection_non_overlap | PASS | |
| TestUpdateOps.test_intersection_method_call | PASS | |
| TestUpdateOps.test_sym_difference_subset | PASS | |
| TestUpdateOps.test_sym_difference_superset | PASS | |
| TestUpdateOps.test_sym_difference_overlap | PASS | |
| TestUpdateOps.test_sym_difference_non_overlap | PASS | |
| TestUpdateOps.test_sym_difference_method_call | PASS | |
| TestUpdateOps.test_difference_subset | PASS | |
| TestUpdateOps.test_difference_superset | PASS | |
| TestUpdateOps.test_difference_overlap | PASS | |
| TestUpdateOps.test_difference_non_overlap | PASS | |
| TestUpdateOps.test_difference_method_call | PASS | |
| TestMutate.test_add_present | PASS | |
| TestMutate.test_add_absent | PASS | |
| TestMutate.test_add_until_full | PASS | |
| TestMutate.test_remove_present | PASS | |
| TestMutate.test_remove_absent | PASS | |
| TestMutate.test_remove_until_empty | PASS | |
| TestMutate.test_discard_present | PASS | |
| TestMutate.test_discard_absent | PASS | |
| TestMutate.test_clear | PASS | |
| TestMutate.test_pop | PASS | |
| TestMutate.test_update_empty_tuple | PASS | |
| TestMutate.test_update_unit_tuple_overlap | PASS | |
| TestMutate.test_update_unit_tuple_non_overlap | PASS | |
| TestSubsetEqualEmpty.test_issubset | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestSubsetEqualNonEmpty.test_issubset | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestSubsetEmptyNonEmpty.test_issubset | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestSubsetPartial.test_issubset | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestSubsetNonOverlap.test_issubset | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'> |
| TestOnlySetsNumeric.test_eq_ne | PASS | |
| TestOnlySetsDict.test_eq_ne | PASS | |
| TestOnlySetsOperator.test_eq_ne | PASS | |
| TestOnlySetsTuple.test_eq_ne | PASS | |
| TestOnlySetsString.test_eq_ne | PASS | |
| TestOnlySetsGenerator.test_eq_ne | PASS | |
| TestOnlySetsNumeric.test_ge_gt_le_lt | PASS | |
| TestOnlySetsDict.test_ge_gt_le_lt | PASS | |
| TestOnlySetsOperator.test_ge_gt_le_lt | PASS | |
| TestOnlySetsTuple.test_ge_gt_le_lt | PASS | |
| TestOnlySetsString.test_ge_gt_le_lt | PASS | |
| TestOnlySetsGenerator.test_ge_gt_le_lt | PASS | |
| TestOnlySetsNumeric.test_update_operator | PASS | |
| TestOnlySetsDict.test_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsOperator.test_update_operator | PASS | |
| TestOnlySetsTuple.test_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsString.test_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsGenerator.test_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsNumeric.test_update | PASS | |
| TestOnlySetsDict.test_update | PASS | |
| TestOnlySetsOperator.test_update | PASS | |
| TestOnlySetsTuple.test_update | PASS | |
| TestOnlySetsString.test_update | PASS | |
| TestOnlySetsGenerator.test_update | PASS | |
| TestOnlySetsNumeric.test_union | PASS | |
| TestOnlySetsDict.test_union | PASS | |
| TestOnlySetsOperator.test_union | PASS | |
| TestOnlySetsTuple.test_union | PASS | |
| TestOnlySetsString.test_union | PASS | |
| TestOnlySetsGenerator.test_union | PASS | |
| TestOnlySetsNumeric.test_intersection_update_operator | PASS | |
| TestOnlySetsDict.test_intersection_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsOperator.test_intersection_update_operator | PASS | |
| TestOnlySetsTuple.test_intersection_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsString.test_intersection_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsGenerator.test_intersection_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsNumeric.test_intersection_update | PASS | |
| TestOnlySetsDict.test_intersection_update | PASS | |
| TestOnlySetsOperator.test_intersection_update | PASS | |
| TestOnlySetsTuple.test_intersection_update | PASS | |
| TestOnlySetsString.test_intersection_update | PASS | |
| TestOnlySetsGenerator.test_intersection_update | PASS | |
| TestOnlySetsNumeric.test_intersection | PASS | |
| TestOnlySetsDict.test_intersection | PASS | |
| TestOnlySetsOperator.test_intersection | PASS | |
| TestOnlySetsTuple.test_intersection | PASS | |
| TestOnlySetsString.test_intersection | PASS | |
| TestOnlySetsGenerator.test_intersection | PASS | |
| TestOnlySetsNumeric.test_sym_difference_update_operator | PASS | |
| TestOnlySetsDict.test_sym_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsOperator.test_sym_difference_update_operator | PASS | |
| TestOnlySetsTuple.test_sym_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsString.test_sym_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsGenerator.test_sym_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsNumeric.test_sym_difference_update | PASS | |
| TestOnlySetsDict.test_sym_difference_update | PASS | |
| TestOnlySetsOperator.test_sym_difference_update | PASS | |
| TestOnlySetsTuple.test_sym_difference_update | PASS | |
| TestOnlySetsString.test_sym_difference_update | PASS | |
| TestOnlySetsGenerator.test_sym_difference_update | PASS | |
| TestOnlySetsNumeric.test_sym_difference | PASS | |
| TestOnlySetsDict.test_sym_difference | PASS | |
| TestOnlySetsOperator.test_sym_difference | PASS | |
| TestOnlySetsTuple.test_sym_difference | PASS | |
| TestOnlySetsString.test_sym_difference | PASS | |
| TestOnlySetsGenerator.test_sym_difference | PASS | |
| TestOnlySetsNumeric.test_difference_update_operator | PASS | |
| TestOnlySetsDict.test_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsOperator.test_difference_update_operator | PASS | |
| TestOnlySetsTuple.test_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsString.test_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsGenerator.test_difference_update_operator | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'expected TypeError'"> |
| TestOnlySetsNumeric.test_difference_update | PASS | |
| TestOnlySetsDict.test_difference_update | PASS | |
| TestOnlySetsOperator.test_difference_update | PASS | |
| TestOnlySetsTuple.test_difference_update | PASS | |
| TestOnlySetsString.test_difference_update | PASS | |
| TestOnlySetsGenerator.test_difference_update | PASS | |
| TestOnlySetsNumeric.test_difference | PASS | |
| TestOnlySetsDict.test_difference | PASS | |
| TestOnlySetsOperator.test_difference | PASS | |
| TestOnlySetsTuple.test_difference | PASS | |
| TestOnlySetsString.test_difference | PASS | |
| TestOnlySetsGenerator.test_difference | PASS | |
| TestCopyingEmpty.test_copy | PASS | |
| TestCopyingSingleton.test_copy | PASS | |
| TestCopyingTriple.test_copy | PASS | |
| TestCopyingTuple.test_copy | PASS | |
| TestCopyingNested.test_copy | PASS | |
| TestCopyingEmpty.test_deep_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopyingSingleton.test_deep_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopyingTriple.test_deep_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopyingTuple.test_deep_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestCopyingNested.test_deep_copy | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'"> |
| TestIdentities.test_binopsVsSubsets | PASS | |
| TestIdentities.test_commutativity | PASS | |
| TestIdentities.test_summations | PASS | |
| TestIdentities.test_exclusion | PASS | |
| TestVariousIteratorArgs.test_constructor | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'G\' object is not iterable"'> |
| TestVariousIteratorArgs.test_inline_methods | PASS | |
| TestVariousIteratorArgs.test_inplace_methods | PASS | |
| TestWeirdBugs.test_8420_set_merge | PASS | |
| TestWeirdBugs.test_iter_and_mutate | PASS | |
| TestWeirdBugs.test_merge_and_mutate | PASS | |
| TestWeirdBugs.test_hash_collision_concurrent_add | PASS | |
| TestGraphs.test_cube | PASS | |
| TestGraphs.test_cuboctahedron | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestSetSubclass.test_new_or_init | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_new_or_init | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_uniquification | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_uniquification | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_len | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_len | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_contains | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_contains | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_union | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_union | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_or | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_or | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_intersection | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_intersection | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_isdisjoint | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_isdisjoint | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_and | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_and | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_difference | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_difference | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_sub | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_sub | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_symmetric_difference | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_symmetric_difference | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_xor | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_xor | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_equality | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_equality | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_setOfFrozensets | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_setOfFrozensets | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_sub_and_super | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_sub_and_super | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_pickling | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_pickling | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_iterator_pickling | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_iterator_pickling | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_deepcopy | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_deepcopy | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_gc | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_gc | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_subclass_with_custom_hash | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_subclass_with_custom_hash | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_badcmp | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_badcmp | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_cyclical_repr | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_cyclical_repr | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_do_not_rehash_dict_keys | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_do_not_rehash_dict_keys | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_container_iterator | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_container_iterator | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_free_after_iterating | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_free_after_iterating | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_init | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_constructor_identity | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_set_literal | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_set_literal_insertion_order | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_set_literal_evaluation_order | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_hash | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_clear | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_copy | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_add | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_remove | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_remove_keyerror_unpacking | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_remove_keyerror_set | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_discard | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_pop | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_update | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_ior | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_intersection_update | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_iand | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_difference_update | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_isub | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_symmetric_difference_update | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_ixor | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_inplace_on_self | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_weakref | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_rich_compare | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_set_membership | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_unhashable_element | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_hash_collision_remove_add | helper:setUp(uses-self.thetype) |
| TestSetSubclass.test_keywords_in_subclass | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_init | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_constructor_identity | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_hash | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_copy | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_frozen_as_dictkey | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_hash_caching | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_hash_effectiveness | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_keywords_in_subclass | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_constructor_identity | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_copy | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_nested_empty_constructor | helper:setUp(uses-self.thetype) |
| TestFrozenSetSubclass.test_singleton_empty_frozenset | helper:setUp(uses-self.thetype) |
| TestBasicOpsMixedStringBytes.test_repr | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_length | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_self_equality | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_equivalent_equality | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_copy | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_self_union | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_empty_union | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_union_empty | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_self_intersection | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_empty_intersection | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_intersection_empty | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_self_isdisjoint | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_empty_isdisjoint | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_isdisjoint_empty | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_self_symmetric_difference | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_empty_symmetric_difference | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_self_difference | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_empty_difference | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_empty_difference_rev | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_iteration | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_pickling | helper:setUp(self.enterContext) |
| TestBasicOpsMixedStringBytes.test_issue_37219 | helper:setUp(self.enterContext) |
| TestBasicOpsString.test_repr | helper:check_repr_against_values(self.assertStartsWith) |
| TestBasicOpsBytes.test_repr | helper:check_repr_against_values(self.assertStartsWith) |
| TestBasicOpsMixedStringBytes.test_repr | helper:setUp(self.enterContext) |
| TestBinaryOpsMutating_Set_Set.test_eq_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_eq_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_eq_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_eq_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_ne_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_ne_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_ne_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_ne_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_lt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_lt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_lt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_lt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_le_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_le_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_le_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_le_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_gt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_gt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_gt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_gt_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_ge_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_ge_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_ge_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_ge_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_and_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_and_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_and_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_and_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_or_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_or_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_or_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_or_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_sub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_sub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_sub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_sub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_xor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_xor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_xor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_xor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_iadd_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_iadd_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_iadd_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_iadd_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_ior_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_ior_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_ior_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_ior_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_isub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_isub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_isub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_isub_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_ixor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_ixor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_ixor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_ixor_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Set.test_iteration_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Subclass.test_iteration_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Set_Subclass.test_iteration_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBinaryOpsMutating_Subclass_Set.test_iteration_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_issubset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_issuperset_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_intersection_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_union_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_symmetric_difference_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_isdisjoint_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_intersection_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_symmetric_difference_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Set.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Subclass.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Subclass.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Subclass_Set.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_Dict.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestMethodsMutating_Set_List.test_update_with_mutation | helper:check_set_op_does_not_crash(helper:make_sets_of_bad_objects(uses-self.constructor1)) |
| TestBasicOpsString.test_repr | host-raised:AttributeError: '_SelfNS' object has no attribute 'repr' |
| TestBasicOpsBytes.test_repr | host-raised:AttributeError: '_SelfNS' object has no attribute 'repr' |

## Expected vs got

### TestBasicOpsBytes.test_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_empty_difference (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_empty_union (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_equivalent_equality (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__length_hint__'">`

### TestBasicOpsBytes.test_pickling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_self_intersection (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_self_union (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsBytes.test_union_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', {b\'c\', b\'b\', b\'a\'}, {b\'c\', b\'b\', b\'a\'})"'>

### TestBasicOpsEmpty.test_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__length_hint__'">`

### TestBasicOpsSingleton.test_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__length_hint__'">`

### TestBasicOpsString.test_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__length_hint__'">`

### TestBasicOpsTriple.test_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__length_hint__'">`

### TestBasicOpsTuple.test_iteration (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__length_hint__'">`

### TestCopyingEmpty.test_deep_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopyingNested.test_deep_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopyingSingleton.test_deep_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopyingTriple.test_deep_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestCopyingTuple.test_deep_copy (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC Error 'un(deep)copyable object of type <object>'">

### TestExceptionPropagation.test_changingSizeWhileIterating (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'no exception when changing size during iteration'">

### TestGraphs.test_cuboctahedron (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### TestOnlySetsDict.test_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsDict.test_intersection_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsDict.test_sym_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsDict.test_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsGenerator.test_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsGenerator.test_intersection_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsGenerator.test_sym_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsGenerator.test_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsString.test_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsString.test_intersection_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsString.test_sym_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsString.test_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsTuple.test_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsTuple.test_intersection_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsTuple.test_sym_difference_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestOnlySetsTuple.test_update_operator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'expected TypeError'">

### TestSubsetEmptyNonEmpty.test_issubset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestSubsetEqualEmpty.test_issubset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestSubsetEqualNonEmpty.test_issubset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestSubsetNonOverlap.test_issubset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestSubsetPartial.test_issubset (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC NameError "name \'x\' is not defined"'>

### TestVariousIteratorArgs.test_constructor (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'G\' object is not iterable"'>
