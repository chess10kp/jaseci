# Triage report: `conv_argparse_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_argparse.py
- guest leg: 0/20 marks
- pins: **0 passed** / 20 run (+485 quarantined of 505 extracted)

| pin | result | got |
|---|---|---|
| StdStreamTest.test_skip_invalid_stderr | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestBooleanOptionalAction.test_const | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_exit_on_error_with_good_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_unrecognized_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_unrecognized_intermixed_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_with_metavar | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_n | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_n_with_metavar | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_optional | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_zero_or_more | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_one_or_more | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_one_or_more_with_metavar | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_args_remainder | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_required_mutually_exclusive_args | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_conflicting_mutually_exclusive_args_optional_with_metavar | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_conflicting_mutually_exclusive_args_zero_or_more_with_metavar1 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_conflicting_mutually_exclusive_args_zero_or_more_with_metavar2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_ambiguous_option | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestExitOnError.test_os_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 20 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | StdStreamTest.test_skip_invalid_stderr, TestBooleanOptionalAction.test_const, TestExitOnError.test_ambiguous_option, TestExitOnError.test_conflicting_mutually_exclusive_args_optional_with_metavar, TestExitOnError.test_conflicting_mutually_exclusive_args_zero_or_more_with_metavar1, TestExitOnError.test_conflicting_mutually_exclusive_args_zero_or_more_with_metavar2, TestExitOnError.test_exit_on_error_with_good_args, TestExitOnError.test_os_error, TestExitOnError.test_required_args, TestExitOnError.test_required_args_n, TestExitOnError.test_required_args_n_with_metavar, TestExitOnError.test_required_args_one_or_more, TestExitOnError.test_required_args_one_or_more_with_metavar, TestExitOnError.test_required_args_optional, TestExitOnError.test_required_args_remainder, TestExitOnError.test_required_args_with_metavar, TestExitOnError.test_required_args_zero_or_more, TestExitOnError.test_required_mutually_exclusive_args, TestExitOnError.test_unrecognized_args, TestExitOnError.test_unrecognized_intermixed_args |

## Quarantined at conversion

| test | reason |
|---|---|
| StdStreamTest.test_skip_invalid_stdout | uses-self.subTest |
| TestStrEnumChoices.test_parse_enum_value | helper:setUp(uses-self.enterContext) |
| TestStrEnumChoices.test_help_message_contains_enum_choices | helper:setUp(uses-self.enterContext) |
| TestStrEnumChoices.test_invalid_enum_value_raises_error | helper:setUp(uses-self.enterContext) |
| TestFileTypeDeprecation.test | helper:setUp(uses-self.enterContext) |
| TestFileTypeRepr.test_r | helper:setUp(uses-self.enterContext) |
| TestFileTypeRepr.test_wb_1 | helper:setUp(uses-self.enterContext) |
| TestFileTypeRepr.test_r_latin | helper:setUp(uses-self.enterContext) |
| TestFileTypeRepr.test_w_big5_ignore | helper:setUp(uses-self.enterContext) |
| TestFileTypeRepr.test_r_1_replace | helper:setUp(uses-self.enterContext) |
| TestFileTypeOpenArgs.test_open_args | helper:setUp(uses-self.enterContext) |
| TestFileTypeOpenArgs.test_invalid_file_type | helper:setUp(uses-self.enterContext) |
| TestFileTypeMissingInitialization.test | helper:setUp(uses-self.enterContext) |
| TestTypeRegistration.test | helper:setUp(uses-self.enterContext) |
| TestActionRegistration.test | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_wrong_argument_error_with_suggestions | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_wrong_argument_error_no_suggestions | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_wrong_argument_subparsers_with_suggestions | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_wrong_argument_subparsers_no_suggestions | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_wrong_argument_no_suggestion_implicit | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_suggestions_choices_empty | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_suggestions_choices_int | helper:setUp(uses-self.enterContext) |
| TestArgumentAndSubparserSuggestions.test_suggestions_choices_mixed_types | helper:setUp(uses-self.enterContext) |
| TestInvalidAction.test_invalid_type | helper:setUp(uses-self.enterContext) |
| TestInvalidAction.test_modified_invalid_action | helper:setUp(uses-self.enterContext) |
| TestPositionalsGroups.test_nongroup_first | helper:setUp(uses-self.enterContext) |
| TestPositionalsGroups.test_group_first | helper:setUp(uses-self.enterContext) |
| TestPositionalsGroups.test_interleaved_groups | helper:setUp(uses-self.enterContext) |
| TestGroupConstructor.test_group_prefix_chars | helper:setUp(uses-self.enterContext) |
| TestGroupConstructor.test_group_prefix_chars_default | helper:setUp(uses-self.enterContext) |
| TestGroupConstructor.test_nested_argument_group | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_invalid_add_argument_group | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_invalid_add_argument | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_help | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_optional_order | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_help_subparser_all_mutually_exclusive_group_members_suppressed | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_usage_empty_group | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_nested_mutex_groups | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveInGroup.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalOptional.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalWithDefault.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusivePositionalWithDefault.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_invalid_add_argument_group | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_invalid_add_argument | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_help | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_optional_order | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_help_subparser_all_mutually_exclusive_group_members_suppressed | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_usage_empty_group | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveGroupErrorsParent.test_nested_mutex_groups | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveSimpleParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveLongParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveFirstSuppressedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveManySuppressedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalAndPositionalParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsMixedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_failures_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_failures_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_successes_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_successes_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_usage_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_usage_when_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_help_when_not_required | helper:setUp(uses-self.enterContext) |
| TestMutuallyExclusiveOptionalsAndPositionalsMixedParent.test_help_when_required | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_no_args | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_with_args | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_subparsers | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_parents | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_on_parent_and_subparser | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_same_as_add_argument | helper:setUp(uses-self.enterContext) |
| TestSetDefaults.test_set_defaults_same_as_add_argument_group | helper:setUp(uses-self.enterContext) |
| TestGetDefault.test_get_default | helper:setUp(uses-self.enterContext) |
| TestNamespaceContainsSimple.test_empty | helper:setUp(uses-self.enterContext) |
| TestNamespaceContainsSimple.test_non_empty | helper:setUp(uses-self.enterContext) |
| TestHelpUsageNoWhitespaceCrash.test_all_suppressed_mutex_followed_by_long_arg | helper:setUp(uses-self.enterContext) |
| TestHelpUsageNoWhitespaceCrash.test_newline_in_metavar | helper:setUp(uses-self.enterContext) |
| TestHelpUsageNoWhitespaceCrash.test_empty_metavar_required_arg | helper:setUp(uses-self.enterContext) |
| TestHelpUsageNoWhitespaceCrash.test_all_suppressed_mutex_with_optional_nargs | helper:setUp(uses-self.enterContext) |
| TestHelpUsageNoWhitespaceCrash.test_long_mutex_groups_wrap | helper:setUp(uses-self.enterContext) |
| TestHelpUsageNoWhitespaceCrash.test_mutex_groups_with_mixed_optionals_positionals_wrap | helper:setUp(uses-self.enterContext) |
| TestHelpCustomHelpFormatter.test_custom_formatter_function | helper:setUp(uses-self.enterContext) |
| TestHelpCustomHelpFormatter.test_custom_formatter_class | helper:setUp(uses-self.enterContext) |
| TestHelpCustomHelpFormatter.test_usage_long_subparser_command | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_invalid_keyword_arguments | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_missing_destination | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_invalid_option_strings | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_invalid_prefix | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_invalid_type | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_invalid_action | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_invalid_help | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_multiple_dest | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_no_argument_actions | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_no_argument_no_const_actions | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_more_than_one_argument_actions | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_required_const_actions | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_parsers_action_missing_params | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_version_missing_params | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_required_positional | helper:setUp(uses-self.enterContext) |
| TestInvalidArgumentConstructors.test_user_defined_action | helper:setUp(uses-self.enterContext) |
| TestActionsReturned.test_dest | helper:setUp(uses-self.enterContext) |
| TestActionsReturned.test_misc | helper:setUp(uses-self.enterContext) |
| TestConflictHandling.test_bad_type | helper:setUp(uses-self.enterContext) |
| TestConflictHandling.test_conflict_error | helper:setUp(uses-self.enterContext) |
| TestConflictHandling.test_resolve_error | helper:setUp(uses-self.enterContext) |
| TestConflictHandling.test_subparser_conflict | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_version | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_version_format | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_version_no_help | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_version_action | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_no_help | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_alternate_help_version | helper:setUp(uses-self.enterContext) |
| TestOptionalsHelpVersionActions.test_help_version_extra_arguments | helper:setUp(uses-self.enterContext) |
| TestStrings.test_optional | helper:setUp(uses-self.enterContext) |
| TestStrings.test_argument | helper:setUp(uses-self.enterContext) |
| TestStrings.test_namespace | helper:setUp(uses-self.enterContext) |
| TestStrings.test_namespace_starkwargs_notidentifier | helper:setUp(uses-self.enterContext) |
| TestStrings.test_namespace_kwargs_and_starkwargs_notidentifier | helper:setUp(uses-self.enterContext) |
| TestStrings.test_namespace_starkwargs_identifier | helper:setUp(uses-self.enterContext) |
| TestStrings.test_parser | helper:setUp(uses-self.enterContext) |
| TestNamespace.test_constructor | helper:setUp(uses-self.enterContext) |
| TestNamespace.test_equality | helper:setUp(uses-self.enterContext) |
| TestNamespace.test_equality_returns_notimplemented | helper:setUp(uses-self.enterContext) |
| TestEncoding.test_argparse_module_encoding | helper:setUp(uses-self.enterContext) |
| TestEncoding.test_test_argparse_module_encoding | helper:setUp(uses-self.enterContext) |
| TestArgumentError.test_argument_error | helper:setUp(uses-self.enterContext) |
| TestArgumentTypeError.test_argument_type_error | helper:setUp(uses-self.enterContext) |
| TestMessageContentError.test_missing_argument_name_in_message | helper:setUp(uses-self.enterContext) |
| TestMessageContentError.test_optional_optional_not_in_message | helper:setUp(uses-self.enterContext) |
| TestMessageContentError.test_optional_positional_not_in_message | helper:setUp(uses-self.enterContext) |
| TestTypeFunctionCallOnlyOnce.test_type_function_call_only_once | helper:setUp(uses-self.enterContext) |
| TestDeprecatedArguments.test_deprecated_option | helper:setUp(uses-self.enterContext) |
| TestDeprecatedArguments.test_deprecated_boolean_option | helper:setUp(uses-self.enterContext) |
| TestDeprecatedArguments.test_deprecated_arguments | helper:setUp(uses-self.enterContext) |
| TestDeprecatedArguments.test_deprecated_varargument | helper:setUp(uses-self.enterContext) |
| TestDeprecatedArguments.test_deprecated_subparser | helper:setUp(uses-self.enterContext) |
| TestTypeFunctionCalledOnDefault.test_type_function_call_with_non_string_default | helper:setUp(uses-self.enterContext) |
| TestTypeFunctionCalledOnDefault.test_type_function_call_with_string_default | helper:setUp(uses-self.enterContext) |
| TestTypeFunctionCalledOnDefault.test_no_double_type_conversion_of_default | helper:setUp(uses-self.enterContext) |
| TestTypeFunctionCalledOnDefault.test_issue_15906 | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_arguments_tuple | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_arguments_list | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_arguments_tuple_positional | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_arguments_list_positional | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_optionals | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_mixed | helper:setUp(uses-self.enterContext) |
| TestParseKnownArgs.test_zero_or_more_optional | helper:setUp(uses-self.enterContext) |
| TestDoubleDash.test_single_argument_option | helper:setUp(uses-self.enterContext) |
| TestDoubleDash.test_multiple_argument_option | helper:setUp(uses-self.enterContext) |
| TestDoubleDash.test_multiple_double_dashes | helper:setUp(uses-self.enterContext) |
| TestDoubleDash.test_remainder | helper:setUp(uses-self.enterContext) |
| TestDoubleDash.test_subparser | helper:setUp(uses-self.enterContext) |
| TestDoubleDash.test_subparser_after_multiple_argument_option | helper:setUp(uses-self.enterContext) |
| TestIntermixedArgs.test_basic | helper:setUp(uses-self.enterContext) |
| TestIntermixedArgs.test_remainder | helper:setUp(uses-self.enterContext) |
| TestIntermixedArgs.test_required_exclusive | helper:setUp(uses-self.enterContext) |
| TestIntermixedArgs.test_required_exclusive_with_positional | helper:setUp(uses-self.enterContext) |
| TestIntermixedArgs.test_invalid_args | helper:setUp(uses-self.enterContext) |
| TestIntermixedMessageContentError.test_missing_argument_name_in_message | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_None_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_None_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_None_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_None_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_None_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_optional_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_optional_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_optional_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_optional_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_optional_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_zeroormore_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_zeroormore_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_zeroormore_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_zeroormore_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_zeroormore_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_oneormore_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_oneormore_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_oneormore_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_oneormore_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_oneormore_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_remainder_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_remainder_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_remainder_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_remainder_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_remainder_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_parser_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_parser_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_parser_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_parser_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_parser_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_1_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_1_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_1_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_1_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_1_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_2_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_2_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_2_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_2_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_2_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_3_metavar_string | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_3_metavar_length0 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_3_metavar_length1 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_3_metavar_length2 | helper:setUp(uses-self.enterContext) |
| TestAddArgumentMetavar.test_nargs_3_metavar_length3 | helper:setUp(uses-self.enterContext) |
| TestInvalidNargs.test_nargs_alphabetic | helper:setUp(uses-self.enterContext) |
| TestInvalidNargs.test_nargs_zero | helper:setUp(uses-self.enterContext) |
| TestImportStar.test | helper:setUp(uses-self.enterContext) |
| TestImportStar.test_all_exports_everything_but_modules | helper:setUp(uses-self.enterContext) |
| TestProgName.test_script_compiled | self.test_script |
| TestProgName.test_directory_compiled | self.test_directory |
| TestProgName.test_module_compiled | self.test_module |
| TestProgName.test_package_compiled | self.test_package |
| TestProgName.test_zipfile_compiled | self.test_zipfile |
| TestProgName.test_directory_in_zipfile_compiled | self.test_directory_in_zipfile |
| TestTranslations.test_translations | self.assertMsgidsEqual |
| TestColorized.test_argparse_color | helper:setUp(self.enterContext) |
| TestColorized.test_argparse_color_mutually_exclusive_group_usage | helper:setUp(self.enterContext) |
| TestColorized.test_argparse_color_custom_usage | helper:setUp(self.enterContext) |
| TestColorized.test_custom_formatter_function | helper:setUp(self.enterContext) |
| TestColorized.test_custom_formatter_class | helper:setUp(self.enterContext) |
| TestColorized.test_subparser_prog_is_stored_without_color | helper:setUp(self.enterContext) |
| TestArgumentParserPickleable.test_pickle_roundtrip | host-raised:AttributeError: Can't get local object 'ArgumentParser.**init**.<locals>.identity' |
| TestBooleanOptionalAction.test_invalid_name | host-raised:AssertionError: assertRaises: did not raise |
| TestAddSubparsers.test_parse_args_failures | harness-error:SyntaxError: can't use starred expression here |
| TestAddSubparsers.test_parse_args_failures_details | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_parse_args_failures_details_custom_usage | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_parse_args | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_parse_known_args | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_parse_known_args_to_class_namespace | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_abbreviation | harness-error:SyntaxError: can't use starred expression here |
| TestAddSubparsers.test_parse_known_args_with_single_dash_option | harness-error:SyntaxError: can't use starred expression here |
| TestAddSubparsers.test_dest | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_required_subparsers_via_attribute | harness-error:SyntaxError: can't use starred expression here |
| TestAddSubparsers.test_required_subparsers_via_kwarg | harness-error:SyntaxError: can't use starred expression here |
| TestAddSubparsers.test_required_subparsers_default | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_required_subparsers_no_destination_error | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_optional_subparsers | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_help_extra_prefix_chars | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_help_non_breaking_spaces | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_help_blank | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_help_alternate_prefix_chars | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_parser_command_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_invalid_subparsers_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_invalid_subparser_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_subparser_title_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_subparser1_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_subparser2_help | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_alias_invocation | host-raised:RuntimeError: super(): no arguments |
| TestAddSubparsers.test_error_alias_invocation | harness-error:SyntaxError: can't use starred expression here |
| TestAddSubparsers.test_alias_help | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_single_parent | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_single_parent_mutex | harness-error:SyntaxError: can't use starred expression here |
| TestParentParsers.test_single_grandparent_mutex | harness-error:SyntaxError: can't use starred expression here |
| TestParentParsers.test_multiple_parents | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_multiple_parents_mutex | harness-error:SyntaxError: can't use starred expression here |
| TestParentParsers.test_conflicting_parents | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_conflicting_parents_mutex | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_same_argument_name_parents | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_subparser_parents | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_subparser_parents_mutex | harness-error:SyntaxError: can't use starred expression here |
| TestParentParsers.test_parent_help | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_groups_parents | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_wrong_type_parents | host-raised:RuntimeError: super(): no arguments |
| TestParentParsers.test_mutex_groups_parents | host-raised:RuntimeError: super(): no arguments |
| TestWrappingMetavar.test_help_with_metavar | host-raised:RuntimeError: super(): no arguments |
| TestExitOnError.test_exit_on_error_with_bad_args | harness-error:IndentationError: expected an indented block after 'except' statement on line 20 |
| TestProgName.test_script | harness-error:SyntaxError: invalid syntax |
| TestProgName.test_directory | harness-error:SyntaxError: invalid syntax |
| TestProgName.test_module | harness-error:SyntaxError: invalid syntax |
| TestProgName.test_package | harness-error:SyntaxError: invalid syntax |
| TestProgName.test_zipfile | harness-error:SyntaxError: invalid syntax |
| TestProgName.test_directory_in_zipfile | harness-error:SyntaxError: invalid syntax |
