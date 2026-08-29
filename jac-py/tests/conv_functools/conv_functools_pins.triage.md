# Triage report: `conv_functools_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_functools.py
- guest leg: 0/105 marks
- pins: **0 passed** / 105 run (+139 quarantined of 244 extracted)

| pin | result | got |
|---|---|---|
| TestImportTime.test_lazy_import | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialCSubclass.test_nested_optimization | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialPySubclass.test_nested_optimization | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialCSubclass.test_nested_optimization_bug | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialPySubclass.test_nested_optimization_bug | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialCSubclass.test_nested_partial_with_attribute | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialPySubclass.test_nested_partial_with_attribute | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialCSubclass.test_construct_placeholder_singleton | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialPySubclass.test_construct_placeholder_singleton | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialCSubclass.test_partial_genericalias | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialPySubclass.test_partial_genericalias | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialCSubclass.test_repr_safety_against_reentrant_mutation | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialPySubclass.test_repr_safety_against_reentrant_mutation | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialMethod.test_invalid_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialMethod.test_positional_only | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPartialMethod.test_subclass_optimization | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_no_update | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_selective_update | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_missing_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_update_type_wrapper | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_update_wrapper_annotations | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_default_update | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_no_update | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestWraps.test_selective_update | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_total_ordering_lt | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_total_ordering_le | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_total_ordering_gt | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_total_ordering_ge | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_total_ordering_no_overwrite | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_no_operations_defined | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_notimplemented | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_pickle | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestTotalOrdering.test_total_ordering_for_metaclasses_issue_44605 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachePy.test_cache | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCacheC.test_cache | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_no_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_bug_35780 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_bug_36650 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_hash_only_once | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_reentrancy_with_len | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_star_arg_handling | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_type_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_with_maxsize_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_with_maxsize_negative | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_with_types | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_cache_typed_is_not_recursive | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_with_keyword_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_with_keyword_args_maxsize_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_kwargs_order | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_cache_decoration | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_need_for_rlock | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_method | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_cache_parameters | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_lru_cache_weakrefable | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_common_signatures | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestLRUPy.test_get_annotations | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_simple_overloads | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_mro | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_register_decorator | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_wrapping_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_compose_mro | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_register_abc | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_c3_abc | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_false_meta | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_cache_invalidation | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_annotations | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_staticmethod_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_slotted_class | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_classmethod_slotted_class | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_staticmethod_slotted_class | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_assignment_behavior | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_classmethod_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_callable_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_abstractmethod_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_type_ann_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_staticmethod_type_ann_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_classmethod_type_ann_register | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_wrapping_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_repr | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_double_wrapped_methods | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_invalid_positional_argument | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_invalid_positional_argument_singledispatchmethod | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_union | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_union_conflict | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_union_None | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_register_genericalias | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_register_genericalias_decorator | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_register_genericalias_annotation | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_equal_instances | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_bad_hash | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_no_reference_loops | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_signatures | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestSingleDispatch.test_method_signatures | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_cached | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_cached_attribute_name_differs_from_func_name | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_object_with_slots | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_immutable_dict | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_reuse_same_name | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_set_name_not_called | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_access_from_class | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_doc | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_module | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestCachedProperty.test_subclass_with___set__ | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 103 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | TestCacheC.test_cache, TestCachePy.test_cache, TestCachedProperty.test_access_from_class, TestCachedProperty.test_cached, TestCachedProperty.test_cached_attribute_name_differs_from_func_name, TestCachedProperty.test_doc, TestCachedProperty.test_immutable_dict, TestCachedProperty.test_module, TestCachedProperty.test_object_with_slots, TestCachedProperty.test_reuse_same_name, TestCachedProperty.test_set_name_not_called, TestCachedProperty.test_subclass_with___set__, TestImportTime.test_lazy_import, TestLRUPy.test_common_signatures, TestLRUPy.test_get_annotations, TestLRUPy.test_kwargs_order, TestLRUPy.test_lru, TestLRUPy.test_lru_bug_35780, TestLRUPy.test_lru_bug_36650, TestLRUPy.test_lru_cache_decoration, TestLRUPy.test_lru_cache_parameters, TestLRUPy.test_lru_cache_typed_is_not_recursive, TestLRUPy.test_lru_cache_weakrefable, TestLRUPy.test_lru_hash_only_once, TestLRUPy.test_lru_method, TestLRUPy.test_lru_no_args, TestLRUPy.test_lru_reentrancy_with_len, TestLRUPy.test_lru_star_arg_handling, TestLRUPy.test_lru_type_error, TestLRUPy.test_lru_with_keyword_args, TestLRUPy.test_lru_with_keyword_args_maxsize_none, TestLRUPy.test_lru_with_maxsize_negative, TestLRUPy.test_lru_with_maxsize_none, TestLRUPy.test_lru_with_types, TestLRUPy.test_need_for_rlock, TestPartialCSubclass.test_construct_placeholder_singleton, TestPartialCSubclass.test_nested_optimization, TestPartialCSubclass.test_nested_optimization_bug, TestPartialCSubclass.test_nested_partial_with_attribute, TestPartialCSubclass.test_partial_genericalias, TestPartialCSubclass.test_repr_safety_against_reentrant_mutation, TestPartialMethod.test_invalid_args, TestPartialMethod.test_positional_only, TestPartialMethod.test_subclass_optimization, TestPartialPySubclass.test_construct_placeholder_singleton, TestPartialPySubclass.test_nested_optimization, TestPartialPySubclass.test_nested_optimization_bug, TestPartialPySubclass.test_nested_partial_with_attribute, TestPartialPySubclass.test_partial_genericalias, TestPartialPySubclass.test_repr_safety_against_reentrant_mutation, TestSingleDispatch.test_abstractmethod_register, TestSingleDispatch.test_annotations, TestSingleDispatch.test_assignment_behavior, TestSingleDispatch.test_c3_abc, TestSingleDispatch.test_cache_invalidation, TestSingleDispatch.test_callable_register, TestSingleDispatch.test_classmethod_register, TestSingleDispatch.test_classmethod_slotted_class, TestSingleDispatch.test_classmethod_type_ann_register, TestSingleDispatch.test_compose_mro, TestSingleDispatch.test_double_wrapped_methods, TestSingleDispatch.test_false_meta, TestSingleDispatch.test_invalid_positional_argument, TestSingleDispatch.test_invalid_positional_argument_singledispatchmethod, TestSingleDispatch.test_method_bad_hash, TestSingleDispatch.test_method_equal_instances, TestSingleDispatch.test_method_no_reference_loops, TestSingleDispatch.test_method_register, TestSingleDispatch.test_method_repr, TestSingleDispatch.test_method_signatures, TestSingleDispatch.test_method_wrapping_attributes, TestSingleDispatch.test_mro, TestSingleDispatch.test_register_abc, TestSingleDispatch.test_register_decorator, TestSingleDispatch.test_register_genericalias, TestSingleDispatch.test_register_genericalias_annotation, TestSingleDispatch.test_register_genericalias_decorator, TestSingleDispatch.test_signatures, TestSingleDispatch.test_simple_overloads, TestSingleDispatch.test_slotted_class, TestSingleDispatch.test_staticmethod_register, TestSingleDispatch.test_staticmethod_slotted_class, TestSingleDispatch.test_staticmethod_type_ann_register, TestSingleDispatch.test_type_ann_register, TestSingleDispatch.test_union, TestSingleDispatch.test_union_None, TestSingleDispatch.test_union_conflict, TestSingleDispatch.test_wrapping_attributes, TestTotalOrdering.test_no_operations_defined, TestTotalOrdering.test_notimplemented, TestTotalOrdering.test_pickle, TestTotalOrdering.test_total_ordering_for_metaclasses_issue_44605, TestTotalOrdering.test_total_ordering_ge, TestTotalOrdering.test_total_ordering_gt, TestTotalOrdering.test_total_ordering_le, TestTotalOrdering.test_total_ordering_lt, TestTotalOrdering.test_total_ordering_no_overwrite, TestWraps.test_default_update, TestWraps.test_missing_attributes, TestWraps.test_no_update, TestWraps.test_selective_update, TestWraps.test_update_type_wrapper, TestWraps.test_update_wrapper_annotations |

## Quarantined at conversion

| test | reason |
|---|---|
| TestPartial.test_recursive_pickle | decorator:support.skip_if_sanitizer |
| TestPartialC.test_attributes_unwritable | decorator:unittest.skipUnless |
| TestPartialC.test_manually_adding_non_string_keyword | decorator:unittest.skipUnless |
| TestPartialC.test_keystr_replaces_value | decorator:unittest.skipUnless |
| TestPartialC.test_placeholders_refcount_smoke | decorator:unittest.skipUnless |
| TestUpdateWrapper.test_default_update_doc | decorator:unittest.skipIf |
| TestUpdateWrapper.test_builtin_update | decorator:support.requires_docstrings |
| TestWraps.test_default_update_doc | decorator:unittest.skipIf |
| TestCmpToKey.test_cmp_to_signature | decorator:unittest.skipIf |
| TestCmpToKeyC.test_disallow_instantiation | decorator:unittest.skipUnless |
| TestLRU.test_lru_cache_threaded | decorator:threading_helper.requires_working_threading |
| TestLRU.test_lru_cache_threaded2 | decorator:threading_helper.requires_working_threading |
| TestLRU.test_lru_cache_threaded3 | decorator:threading_helper.requires_working_threading |
| TestLRU.test_lru_recursion | decorator:support.skip_on_s390x |
| TestSingleDispatch.test_c_classes | decorator:unittest.skipUnless |
| TestPartialCSubclass.test_basic_examples | uses-self.partial |
| TestPartialPySubclass.test_basic_examples | uses-self.partial |
| TestPartialCSubclass.test_attributes | uses-self.partial |
| TestPartialPySubclass.test_attributes | uses-self.partial |
| TestPartialCSubclass.test_argument_checking | uses-self.partial |
| TestPartialPySubclass.test_argument_checking | uses-self.partial |
| TestPartialCSubclass.test_protection_of_callers_dict_argument | uses-self.partial |
| TestPartialPySubclass.test_protection_of_callers_dict_argument | uses-self.partial |
| TestPartialCSubclass.test_kwargs_copy | uses-self.partial |
| TestPartialPySubclass.test_kwargs_copy | uses-self.partial |
| TestPartialCSubclass.test_arg_combinations | uses-self.partial |
| TestPartialPySubclass.test_arg_combinations | uses-self.partial |
| TestPartialCSubclass.test_kw_combinations | uses-self.partial |
| TestPartialPySubclass.test_kw_combinations | uses-self.partial |
| TestPartialCSubclass.test_positional | uses-self.partial |
| TestPartialPySubclass.test_positional | uses-self.partial |
| TestPartialCSubclass.test_keyword | uses-self.partial |
| TestPartialPySubclass.test_keyword | uses-self.partial |
| TestPartialCSubclass.test_no_side_effects | uses-self.partial |
| TestPartialPySubclass.test_no_side_effects | uses-self.partial |
| TestPartialCSubclass.test_error_propagation | uses-self.partial |
| TestPartialPySubclass.test_error_propagation | uses-self.partial |
| TestPartialCSubclass.test_weakref | uses-self.partial |
| TestPartialPySubclass.test_weakref | uses-self.partial |
| TestPartialCSubclass.test_with_bound_and_unbound_methods | uses-self.partial |
| TestPartialPySubclass.test_with_bound_and_unbound_methods | uses-self.partial |
| TestPartialCSubclass.test_placeholders_trailing_raise | uses-self.partial |
| TestPartialPySubclass.test_placeholders_trailing_raise | self.partial |
| TestPartialCSubclass.test_placeholders | uses-self.partial |
| TestPartialPySubclass.test_placeholders | uses-self.partial |
| TestPartialCSubclass.test_placeholders_optimization | uses-self.partial |
| TestPartialPySubclass.test_placeholders_optimization | uses-self.partial |
| TestPartialCSubclass.test_placeholders_kw_restriction | uses-self.partial |
| TestPartialPySubclass.test_placeholders_kw_restriction | uses-self.partial |
| TestPartialCSubclass.test_repr | uses-self.partial |
| TestPartialPySubclass.test_repr | uses-self.partial |
| TestPartialCSubclass.test_recursive_repr | uses-self.partial |
| TestPartialPySubclass.test_recursive_repr | uses-self.partial |
| TestPartialCSubclass.test_pickle | uses-self.partial |
| TestPartialPySubclass.test_pickle | uses-self.partial |
| TestPartialCSubclass.test_copy | uses-self.partial |
| TestPartialPySubclass.test_copy | uses-self.partial |
| TestPartialCSubclass.test_deepcopy | uses-self.partial |
| TestPartialPySubclass.test_deepcopy | uses-self.partial |
| TestPartialCSubclass.test_setstate | uses-self.partial |
| TestPartialPySubclass.test_setstate | uses-self.partial |
| TestPartialCSubclass.test_setstate_errors | uses-self.partial |
| TestPartialPySubclass.test_setstate_errors | uses-self.partial |
| TestPartialCSubclass.test_setstate_subclasses | uses-self.partial |
| TestPartialPySubclass.test_setstate_subclasses | uses-self.partial |
| TestPartialCSubclass.test_setstate_refcount | uses-self.partial |
| TestPartialPySubclass.test_setstate_refcount | uses-self.partial |
| TestPartialCSubclass.test_partial_as_method | uses-self.partial |
| TestPartialPySubclass.test_partial_as_method | uses-self.partial |
| TestPartialPySubclass.test_subclass_optimization | uses-self.partial |
| TestPartialMethod.test_arg_combinations | unresolved-name:A |
| TestPartialMethod.test_nested | unresolved-name:A |
| TestPartialMethod.test_over_partial | unresolved-name:A |
| TestPartialMethod.test_bound_method_introspection | unresolved-name:A |
| TestPartialMethod.test_unbound_method_retrieval | unresolved-name:A |
| TestPartialMethod.test_descriptors | unresolved-name:A |
| TestPartialMethod.test_overriding_keywords | unresolved-name:A |
| TestPartialMethod.test_repr | unresolved-name:A |
| TestPartialMethod.test_abstract | unresolved-name:A |
| TestReduceC.test_reduce | uses-self.reduce |
| TestReducePy.test_reduce | uses-self.reduce |
| TestReduceC.test_iterator_usage | uses-self.reduce |
| TestReducePy.test_iterator_usage | uses-self.reduce |
| TestReduceC.test_initial_keyword | uses-self.reduce |
| TestReducePy.test_initial_keyword | uses-self.reduce |
| TestReducePy.test_reduce_with_kwargs | self.reduce |
| TestCmpToKeyC.test_cmp_to_key | uses-self.cmp_to_key |
| TestCmpToKeyPy.test_cmp_to_key | uses-self.cmp_to_key |
| TestCmpToKeyC.test_cmp_to_key_arguments | uses-self.cmp_to_key |
| TestCmpToKeyPy.test_cmp_to_key_arguments | uses-self.cmp_to_key |
| TestCmpToKeyC.test_bad_cmp | uses-self.cmp_to_key |
| TestCmpToKeyPy.test_bad_cmp | uses-self.cmp_to_key |
| TestCmpToKeyC.test_obj_field | uses-self.cmp_to_key |
| TestCmpToKeyPy.test_obj_field | uses-self.cmp_to_key |
| TestCmpToKeyC.test_sort_int | uses-self.cmp_to_key |
| TestCmpToKeyPy.test_sort_int | uses-self.cmp_to_key |
| TestCmpToKeyC.test_sort_int_str | uses-self.cmp_to_key |
| TestCmpToKeyPy.test_sort_int_str | uses-self.cmp_to_key |
| TestCmpToKeyC.test_hash | self.assertNotIsInstance |
| TestCmpToKeyPy.test_hash | self.assertNotIsInstance |
| TestTotalOrdering.test_type_error_when_not_implemented | uses-self.assertRaises |
| TestLRUC.test_lru | unresolved-name:c_cached_func |
| TestLRUC.test_lru_no_args | unresolved-name:c_cached_func |
| TestLRUC.test_lru_bug_35780 | unresolved-name:c_cached_func |
| TestLRUC.test_lru_bug_36650 | unresolved-name:c_cached_func |
| TestLRUC.test_lru_hash_only_once | unresolved-name:c_cached_func |
| TestLRUC.test_lru_reentrancy_with_len | unresolved-name:c_cached_func |
| TestLRUC.test_lru_star_arg_handling | unresolved-name:c_cached_func |
| TestLRUC.test_lru_type_error | unresolved-name:c_cached_func |
| TestLRUC.test_lru_with_maxsize_none | unresolved-name:c_cached_func |
| TestLRUC.test_lru_with_maxsize_negative | unresolved-name:c_cached_func |
| TestLRUPy.test_lru_with_exceptions | unresolved-name:cm |
| TestLRUC.test_lru_with_exceptions | unresolved-name:c_cached_func |
| TestLRUC.test_lru_with_types | unresolved-name:c_cached_func |
| TestLRUC.test_lru_cache_typed_is_not_recursive | unresolved-name:c_cached_func |
| TestLRUC.test_lru_with_keyword_args | unresolved-name:c_cached_func |
| TestLRUC.test_lru_with_keyword_args_maxsize_none | unresolved-name:c_cached_func |
| TestLRUC.test_kwargs_order | unresolved-name:c_cached_func |
| TestLRUC.test_lru_cache_decoration | unresolved-name:c_cached_func |
| TestLRUC.test_need_for_rlock | unresolved-name:c_cached_func |
| TestLRUC.test_lru_method | unresolved-name:c_cached_func |
| TestLRUC.test_pickle | unresolved-name:c_cached_func |
| TestLRUC.test_copy | unresolved-name:c_cached_func |
| TestLRUC.test_deepcopy | unresolved-name:c_cached_func |
| TestLRUC.test_lru_cache_parameters | unresolved-name:c_cached_func |
| TestLRUC.test_lru_cache_weakrefable | unresolved-name:c_cached_func |
| TestLRUC.test_common_signatures | unresolved-name:c_cached_func |
| TestLRUC.test_get_annotations | unresolved-name:c_cached_func |
| TestLRUPy.test_get_annotations_with_forwardref | unresolved-name:nonexistent |
| TestLRUC.test_get_annotations_with_forwardref | unresolved-name:c_cached_func |
| TestSingleDispatch.test_mro_conflicts | unresolved-name:re_one |
| TestSingleDispatch.test_invalid_registrations | self.assertStartsWith |
| TestSingleDispatch.test_forward_reference | unresolved-name:undefined |
| TestSingleDispatch.test_unresolved_forward_reference | unresolved-name:undefined |
| TestCachedProperty.test_reuse_different_names | unresolved-name:ctx |
| TestWraps.test_default_update | host-raised:ValueError: not enough values to unpack (expected 1, got 0) |
| TestLRUPy.test_pickle | host-raised:AttributeError: type object '_SelfNS' has no attribute 'cached_meth' |
| TestLRUPy.test_copy | host-raised:AttributeError: type object '_SelfNS' has no attribute 'cached_meth' |
| TestLRUPy.test_deepcopy | host-raised:AttributeError: type object '_SelfNS' has no attribute 'cached_meth' |
