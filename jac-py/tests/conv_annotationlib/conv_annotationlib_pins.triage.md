# Triage report: `conv_annotationlib_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_annotationlib.py
- guest leg: 0/67 marks
- pins: **0 passed** / 67 run (+50 quarantined of 117 extracted)

| pin | result | got |
|---|---|---|
| TestFormat.test_enum | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefFormat.test_closure | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefFormat.test_multiple_closure | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_closure | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_closure_undefined | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_reverse_ops | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_literals | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_displays | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_unsupported_operations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestStringFormat.test_shenanigans | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_builtin_type | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_custom_metaclass | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_missing_dunder_dict | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_custom_object_with_annotations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_custom_format_eval_str | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_eval_str_wrapped_cycle_self | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_eval_str_wrapped_cycle_mutual | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_eval_str_wrapped_chain_no_cycle | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stock_annotations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stock_annotations_in_module | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stock_annotations_on_wrapper | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotations_in_module | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotations_in_empty_module | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotations_with_star_unpack | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotations_on_wrapper | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotations_on_class | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotations_on_custom_object | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_stringized_annotation_permutations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_modify_annotations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_annotations_on_custom_object | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_raising_annotations_on_custom_object | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_forwardref_prefers_annotations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_only_annotate | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_no_annotations | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_partial_evaluation | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_partial_evaluation_error | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_partial_evaluation_cell | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_nonlocal_in_annotation_scope | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestGetAnnotations.test_raises_error_from_value | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallEvaluateFunction.test_fake_global_evaluation | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_value | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_forwardref_supported | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_forwardref_fakeglobals | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_forwardref_value_fallback | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_string_supported | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_string_fakeglobals | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_user_annotate_string_value_fallback | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_condition_not_stringified | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_unsupported_formats | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestCallAnnotateFunction.test_error_from_value_raised | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| MetaclassTests.test_annotated_meta | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| MetaclassTests.test_unannotated_meta | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| MetaclassTests.test_ordering | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestAnnotationsToString.test_annotations_to_string | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_forwardref_instance_type_error | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_forwardref_subclass_type_error | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_forwardref_only_str_arg | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_special_attrs | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_evaluate_string_format | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_evaluate_forwardref_format | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_fwdref_with_module | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_fwdref_to_builtin | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_fwdref_value_is_not_cached | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_fwdref_with_owner | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_fwdref_invalid_syntax | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_re_evaluate_generics | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| TestForwardRefClass.test_fwdref_final_class | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |

## Quarantined at conversion

| test | reason |
|---|---|
| TestAnnotationLib.test_lazy_imports | decorator:support.cpython_only |
| TestForwardRefFormat.test_function | unresolved-name:doesntexist |
| TestForwardRefFormat.test_nonexistent_attribute | unresolved-name:module |
| TestForwardRefFormat.test_partially_nonexistent | unresolved-name:call_func |
| TestForwardRefFormat.test_partially_nonexistent_union | unresolved-name:undefined |
| TestStringFormat.test_function | unresolved-name:doesntexist |
| TestStringFormat.test_expressions | unresolved-name:c |
| TestStringFormat.test_template_str | unresolved-name:d |
| TestStringFormat.test_getitem | unresolved-name:undef1 |
| TestStringFormat.test_slice | unresolved-name:c |
| TestStringFormat.test_nested_expressions | unresolved-name:Annotated |
| TestGetAnnotations.test_format | unresolved-name:undefined |
| TestGetAnnotations.test_non_dict_annotations | uses-self.assertRaisesRegex |
| TestGetAnnotations.test_non_dict_annotate | uses-self.assertRaisesRegex |
| TestCallEvaluateFunction.test_evaluation | unresolved-name:undefined |
| TestCallAnnotateFunction.test_basic_non_function_annotate | unresolved-name:cm |
| TestCallAnnotateFunction.test_full_non_function_annotate | unresolved-name:unknown |
| TestGetAnnotateFromClassNamespace.test_with_metaclass | uses-self.assertIsNone |
| TestForwardRefClass.test_forward_equality_and_hash_with_cells | uses-self.assertIs |
| TestForwardRefClass.test_forward_repr_extra_names | unresolved-name:undefined |
| TestForwardRefClass.test_evaluate_string_format_extra_names | unresolved-name:unknown |
| TestForwardRefClass.test_evaluate_notimplemented_format | unresolved-name:alias |
| TestForwardRefClass.test_name_lookup_without_eval | unresolved-name:exc |
| TestForwardRefClass.test_evaluate_undefined_generic | self.assertNotIsInstance |
| TestForwardRefClass.test_fwdref_evaluate_argument_mutation | unresolved-name:T |
| TestGetAnnotations.test_stringized_annotations_on_partial_wrapper | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep695_generic_class_with_future_annotations | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep695_generic_class_with_future_annotations_and_local_shadowing | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep695_generic_class_with_future_annotations_name_clash_with_global_vars | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep_695_generic_function_with_future_annotations | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep_695_generic_function_with_future_annotations_name_clash_with_global_vars | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep_695_generic_method_with_future_annotations | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep_695_generic_method_with_future_annotations_name_clash_with_global_vars | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep_695_generic_method_with_future_annotations_name_clash_with_global_and_local_vars | harness-error:SyntaxError: invalid syntax |
| TestGetAnnotations.test_pep_695_generics_with_future_annotations_nested_in_function | harness-error:SyntaxError: invalid syntax |
| TestTypeRepr.test_type_repr | host-raised:AssertionError: ('assertEqual', '**main**._t.<locals>.Nested', '**main**.TestTypeRepr.test_type_repr.<locals>.Nested') |
| TestForwardRefClass.test_forward_equality | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_forward_equality_get_type_hints | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_forward_equality_hash | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_forward_equality_namespace | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_forward_repr | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_forward_recursion_actually | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_syntax_error | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_delayed_syntax_error | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_syntax_error_empty_string | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_or | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_multiple_ways_to_create | harness-error:SyntaxError: invalid syntax |
| TestForwardRefClass.test_evaluate_with_type_params | host-raised:SyntaxError: invalid syntax (typing.py, line 1991) |
| TestForwardRefClass.test_evaluate_with_type_params_and_scope_conflict | harness-error:SyntaxError: invalid syntax |
| TestAnnotationLib.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### MetaclassTests.test_annotated_meta (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### MetaclassTests.test_ordering (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### MetaclassTests.test_unannotated_meta (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestAnnotationsToString.test_annotations_to_string (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_condition_not_stringified (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_error_from_value_raised (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_unsupported_formats (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_forwardref_fakeglobals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_forwardref_supported (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_forwardref_value_fallback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_string_fakeglobals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_string_supported (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_string_value_fallback (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallAnnotateFunction.test_user_annotate_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestCallEvaluateFunction.test_fake_global_evaluation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestFormat.test_enum (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_evaluate_forwardref_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_evaluate_string_format (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_forwardref_instance_type_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_forwardref_only_str_arg (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_forwardref_subclass_type_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_fwdref_final_class (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_fwdref_invalid_syntax (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_fwdref_to_builtin (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_fwdref_value_is_not_cached (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_fwdref_with_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_fwdref_with_owner (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_re_evaluate_generics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefClass.test_special_attrs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefFormat.test_closure (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestForwardRefFormat.test_multiple_closure (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_annotations_on_custom_object (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_builtin_type (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_custom_format_eval_str (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_custom_metaclass (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_custom_object_with_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_eval_str_wrapped_chain_no_cycle (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_eval_str_wrapped_cycle_mutual (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_eval_str_wrapped_cycle_self (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_forwardref_prefers_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_missing_dunder_dict (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_modify_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_no_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_nonlocal_in_annotation_scope (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_only_annotate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_partial_evaluation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_partial_evaluation_cell (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_partial_evaluation_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_raises_error_from_value (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_raising_annotations_on_custom_object (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stock_annotations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stock_annotations_in_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stock_annotations_on_wrapper (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotation_permutations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotations_in_empty_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotations_in_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotations_on_class (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotations_on_custom_object (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotations_on_wrapper (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestGetAnnotations.test_stringized_annotations_with_star_unpack (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_closure (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_closure_undefined (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_displays (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_literals (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_reverse_ops (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_shenanigans (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### TestStringFormat.test_unsupported_operations (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`
