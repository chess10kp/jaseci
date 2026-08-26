# Triage report: `conv_itertools_pins.jac`

- source: reference/cpython/Lib/test/test_itertools.py
- guest leg: 0/5 marks
- pins: **4 passed** / 5 run (+133 quarantined of 138 extracted)

| pin | result | got |
|---|---|---|
| TestBasicOps.test_tee_dealloc_segfault | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'threading_helper' from '<unknown>'"> |
| TestExamples.test_filter | PASS | |
| TestExamples.test_map | PASS | |
| TestExamples.test_zip | PASS | |
| RegressionTests.test_sf_793826 | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBasicOps.test_combinations_overflow | decorator:support.bigaddrspacetest |
| TestBasicOps.test_combinations_tuple_reuse | decorator:support.impl_detail |
| TestBasicOps.test_combinations_with_replacement_overflow | decorator:support.bigaddrspacetest |
| TestBasicOps.test_combinations_with_replacement_tuple_reuse | decorator:support.impl_detail |
| TestBasicOps.test_permutations_overflow | decorator:support.bigaddrspacetest |
| TestBasicOps.test_permutations_tuple_reuse | decorator:support.impl_detail |
| TestBasicOps.test_count_threading | decorator:threading_helper.requires_working_threading |
| TestBasicOps.test_zip_tuple_reuse | decorator:support.impl_detail |
| TestBasicOps.test_zip_longest_tuple_reuse | decorator:support.impl_detail |
| TestBasicOps.test_product_overflow | decorator:support.bigaddrspacetest |
| TestBasicOps.test_product_tuple_reuse | decorator:support.impl_detail |
| TestBasicOps.test_tee_concurrent | decorator:threading_helper.requires_working_threading |
| TestBasicOps.test_combinations_result_gc | decorator:support.cpython_only |
| TestBasicOps.test_combinations_with_replacement_result_gc | decorator:support.cpython_only |
| TestBasicOps.test_permutations_result_gc | decorator:support.cpython_only |
| TestBasicOps.test_product_result_gc | decorator:support.cpython_only |
| TestBasicOps.test_zip_longest_result_gc | decorator:support.cpython_only |
| TestBasicOps.test_pairwise_result_gc | decorator:support.cpython_only |
| TestBasicOps.test_immutable_types | decorator:support.cpython_only |
| RegressionTests.test_long_chain_of_empty_iterables | decorator:support.skip_if_pgo_task |
| SizeofTest.test_product_sizeof | decorator:support.cpython_only |
| SizeofTest.test_combinations_sizeof | decorator:support.cpython_only |
| SizeofTest.test_combinations_with_replacement_sizeof | decorator:support.cpython_only |
| SizeofTest.test_permutations_sizeof | decorator:support.cpython_only |
| TestBasicOps.test_accumulate | unresolved-name:accumulate |
| TestBasicOps.test_batched | uses-self.subTest |
| TestBasicOps.test_chain | unresolved-name:chain |
| TestBasicOps.test_chain_from_iterable | unresolved-name:chain |
| TestBasicOps.test_combinations | unresolved-name:combinations |
| TestBasicOps.test_combinations_with_replacement | unresolved-name:combinations |
| TestBasicOps.test_permutations | unresolved-name:permutations |
| TestBasicOps.test_combinatorics | unresolved-name:combinations |
| TestBasicOps.test_compress | unresolved-name:chain |
| TestBasicOps.test_count | unresolved-name:count |
| TestBasicOps.test_count_with_step | unresolved-name:count |
| TestBasicOps.test_count_with_step_threading | self.test_count_threading |
| TestBasicOps.test_cycle | unresolved-name:cycle |
| TestBasicOps.test_groupby | unresolved-name:groupby |
| TestBasicOps.test_groupby_reentrant_eq_does_not_crash | uses-self.do_advance |
| TestBasicOps.test_grouper_reentrant_eq_does_not_crash | uses-self.do_advance |
| TestBasicOps.test_filter | self.pickletest |
| TestBasicOps.test_filterfalse | unresolved-name:count |
| TestBasicOps.test_zip | unresolved-name:count |
| TestBasicOps.test_ziplongest | unresolved-name:count |
| TestBasicOps.test_zip_longest_bad_iterable | unresolved-name:cm |
| TestBasicOps.test_bug_7244 | uses-self.o |
| TestBasicOps.test_pairwise | uses-self.assertEqual |
| TestBasicOps.test_pairwise_reenter | uses-self.count |
| TestBasicOps.test_pairwise_reenter2 | uses-self.count |
| TestBasicOps.test_product | unresolved-name:product |
| TestBasicOps.test_repeat | unresolved-name:repeat |
| TestBasicOps.test_repeat_with_negative_times | unresolved-name:repeat |
| TestBasicOps.test_map | unresolved-name:count |
| TestBasicOps.test_starmap | unresolved-name:count |
| TestBasicOps.test_islice | uses-self.val |
| TestBasicOps.test_takewhile | unresolved-name:takewhile |
| TestBasicOps.test_dropwhile | unresolved-name:dropwhile |
| TestBasicOps.test_tee | unresolved-name:tee |
| TestBasicOps.test_tee_del_backward | unresolved-name:repeat |
| TestBasicOps.test_tee_reenter | uses-self.first |
| TestBasicOps.test_StopIteration | unresolved-name:StopNow |
| TestExamples.test_accumulate | unresolved-name:accumulate |
| TestExamples.test_chain | unresolved-name:chain |
| TestExamples.test_chain_from_iterable | unresolved-name:chain |
| TestExamples.test_combinations | unresolved-name:combinations |
| TestExamples.test_combinations_with_replacement | unresolved-name:combinations_with_replacement |
| TestExamples.test_compress | unresolved-name:compress |
| TestExamples.test_count | unresolved-name:count |
| TestExamples.test_cycle | unresolved-name:cycle |
| TestExamples.test_dropwhile | unresolved-name:dropwhile |
| TestExamples.test_groupby | unresolved-name:groupby |
| TestExamples.test_filterfalse | unresolved-name:filterfalse |
| TestExamples.test_islice | unresolved-name:islice |
| TestExamples.test_zip_longest | unresolved-name:zip_longest |
| TestExamples.test_permutations | unresolved-name:permutations |
| TestExamples.test_product | unresolved-name:product |
| TestExamples.test_repeat | unresolved-name:repeat |
| TestExamples.test_stapmap | unresolved-name:starmap |
| TestExamples.test_takewhile | unresolved-name:takewhile |
| TestPurePythonRoughEquivalents.test_batched_recipe | uses-self.subTest |
| TestPurePythonRoughEquivalents.test_groupby_recipe | unresolved-name:islice |
| TestPurePythonRoughEquivalents.test_islice_recipe | uses-self.islice |
| TestPurePythonRoughEquivalents.test_tee_recipe | uses-self.link |
| TestGC.test_accumulate | self.makecycle |
| TestGC.test_batched | self.makecycle |
| TestGC.test_chain | self.makecycle |
| TestGC.test_chain_from_iterable | self.makecycle |
| TestGC.test_combinations | self.makecycle |
| TestGC.test_combinations_with_replacement | self.makecycle |
| TestGC.test_compress | self.makecycle |
| TestGC.test_count | self.makecycle |
| TestGC.test_cycle | self.makecycle |
| TestGC.test_dropwhile | self.makecycle |
| TestGC.test_groupby | self.makecycle |
| TestGC.test_issue2246 | unresolved-name:groupby |
| TestGC.test_filter | self.makecycle |
| TestGC.test_filterfalse | self.makecycle |
| TestGC.test_zip | self.makecycle |
| TestGC.test_zip_longest | self.makecycle |
| TestGC.test_map | self.makecycle |
| TestGC.test_islice | self.makecycle |
| TestGC.test_pairwise | self.makecycle |
| TestGC.test_permutations | self.makecycle |
| TestGC.test_product | self.makecycle |
| TestGC.test_repeat | self.makecycle |
| TestGC.test_starmap | self.makecycle |
| TestGC.test_takewhile | self.makecycle |
| TestVariousIteratorArgs.test_accumulate | unresolved-name:E |
| TestVariousIteratorArgs.test_batched | uses-self.subTest |
| TestVariousIteratorArgs.test_chain | unresolved-name:E |
| TestVariousIteratorArgs.test_compress | unresolved-name:E |
| TestVariousIteratorArgs.test_product | unresolved-name:E |
| TestVariousIteratorArgs.test_cycle | unresolved-name:E |
| TestVariousIteratorArgs.test_groupby | unresolved-name:E |
| TestVariousIteratorArgs.test_filter | unresolved-name:E |
| TestVariousIteratorArgs.test_filterfalse | unresolved-name:E |
| TestVariousIteratorArgs.test_zip | unresolved-name:E |
| TestVariousIteratorArgs.test_ziplongest | unresolved-name:E |
| TestVariousIteratorArgs.test_map | unresolved-name:E |
| TestVariousIteratorArgs.test_islice | unresolved-name:E |
| TestVariousIteratorArgs.test_pairwise | unresolved-name:E |
| TestVariousIteratorArgs.test_starmap | unresolved-name:E |
| TestVariousIteratorArgs.test_takewhile | unresolved-name:E |
| TestVariousIteratorArgs.test_dropwhile | unresolved-name:E |
| TestVariousIteratorArgs.test_tee | unresolved-name:E |
| LengthTransparency.test_repeat | unresolved-name:repeat |
| LengthTransparency.test_repeat_with_negative_times | unresolved-name:repeat |
| RegressionTests.test_sf_950057 | unresolved-name:chain |
| RegressionTests.test_issue30347_1 | unresolved-name:groupby |
| RegressionTests.test_issue30347_2 | unresolved-name:groupby |
| SubclassWithKwargsTest.test_keywords_in_subclass | uses-self.subTest |
| testR | host-raised:NameError: name 'r' is not defined |
| testR2 | host-raised:NameError: name 'r' is not defined |

## Expected vs got

### TestBasicOps.test_tee_dealloc_segfault (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'threading_helper' from '<unknown>'">
