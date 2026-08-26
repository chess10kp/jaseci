# Triage report: `conv_grammar_pins.jac`

- source: reference/cpython/Lib/test/test_grammar.py
- guest leg: 0/52 marks
- pins: **44 passed** / 52 run (+23 quarantined of 75 extracted)

| pin | result | got |
|---|---|---|
| TokenTests.test_backslash | PASS | |
| TokenTests.test_plain_integers | PASS | |
| TokenTests.test_long_integers | PASS | |
| TokenTests.test_floats | PASS | |
| TokenTests.test_float_exponent_tokenization | PASS | |
| TokenTests.test_underscore_literals | PASS | |
| TokenTests.test_string_literals | PASS | |
| TokenTests.test_string_prefixes | PASS | |
| TokenTests.test_bytes_prefixes | PASS | |
| TokenTests.test_ellipsis | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'> |
| GrammarTests.test_eval_input | PASS | |
| GrammarTests.test_var_annot_basics | PASS | |
| GrammarTests.test_annotations_inheritance | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'"> |
| GrammarTests.test_var_annot_module_semantics | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.typinganndata'"> |
| GrammarTests.test_var_annot_in_module | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| GrammarTests.test_var_annot_simple_exec | GUEST-WRONG-OUTPUT | RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>"> |
| GrammarTests.test_var_annot_rhs | GUEST-WRONG-OUTPUT | RUN<'AttributeError: cache'> |
| GrammarTests.test_simple_stmt | PASS | |
| GrammarTests.test_del_stmt | PASS | |
| GrammarTests.test_pass_stmt | PASS | |
| GrammarTests.test_break_stmt | PASS | |
| GrammarTests.test_continue_stmt | PASS | |
| GrammarTests.test_break_continue_loop | PASS | |
| GrammarTests.test_raise | PASS | |
| GrammarTests.test_import | PASS | |
| GrammarTests.test_global | PASS | |
| GrammarTests.test_nonlocal | PASS | |
| GrammarTests.test_assert | PASS | |
| GrammarTests.test_assert_warning_promotes_to_syntax_error | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'"> |
| GrammarTests.test_if | PASS | |
| GrammarTests.test_while | PASS | |
| GrammarTests.test_try | PASS | |
| GrammarTests.test_try_star | PASS | |
| GrammarTests.test_suite | PASS | |
| GrammarTests.test_test | PASS | |
| GrammarTests.test_comparison | PASS | |
| GrammarTests.test_binary_mask_ops | PASS | |
| GrammarTests.test_shift_ops | PASS | |
| GrammarTests.test_additive_ops | PASS | |
| GrammarTests.test_multiplicative_ops | PASS | |
| GrammarTests.test_unary_ops | PASS | |
| GrammarTests.test_selectors | PASS | |
| GrammarTests.test_atoms | PASS | |
| GrammarTests.test_classdef | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError '**call**'"> |
| GrammarTests.test_dictcomps | PASS | |
| GrammarTests.test_comprehension_specials | PASS | |
| GrammarTests.test_with_statement | PASS | |
| GrammarTests.test_if_else_expr | PASS | |
| GrammarTests.test_paren_evaluation | PASS | |
| GrammarTests.test_async_for | PASS | |
| GrammarTests.test_async_with | PASS | |
| GrammarTests.test_complex_lambda | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| GrammarTests.test_assert_failures | decorator:unittest.skipUnless |
| TokenTests.test_bad_numerical_literals | uses-self.check_syntax_error |
| TokenTests.test_end_of_numerical_literals | self.check_syntax_warning |
| TokenTests.test_eof_error | unresolved-name:cm |
| TokenTests.test_max_level | self.assertStartsWith |
| GrammarTests.test_var_annot_basic_semantics | uses-self.x |
| GrammarTests.test_lambdef | unresolved-name:d |
| GrammarTests.test_former_statements_refer_to_builtins | uses-self.subTest |
| GrammarTests.test_yield | unresolved-name:f |
| GrammarTests.test_yield_in_comprehensions | uses-self.check_syntax_error |
| GrammarTests.test_assert_syntax_warnings | self.check_syntax_warning |
| GrammarTests.test_for | uses-self.max |
| GrammarTests.test_comparison_is_literal | self.check_syntax_warning |
| GrammarTests.test_warn_missed_comma | self.check_syntax_warning |
| GrammarTests.test_matrix_mul | uses-self.other |
| GrammarTests.test_async_await | unresolved-name:someobj |
| GrammarTests.test_var_annot_syntax_errors | host-raised:NameError: name 'self' is not defined |
| GrammarTests.test_funcdef | host-raised:NameError: name 'self' is not defined |
| GrammarTests.test_expr_stmt | host-raised:NameError: name 'self' is not defined |
| GrammarTests.test_return | host-raised:NameError: name 'self' is not defined |
| GrammarTests.test_control_flow_in_finally | host-raised:NameError: name 'self' is not defined |
| GrammarTests.test_listcomps | host-raised:NameError: name 'self' is not defined |
| GrammarTests.test_genexps | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### GrammarTests.test_annotations_inheritance (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC SystemError 'unsupported opcode 36'">

### GrammarTests.test_assert_warning_promotes_to_syntax_error (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AssertionError 'assertRaises: did not raise'">

### GrammarTests.test_classdef (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError '**call**'">

### GrammarTests.test_var_annot_in_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">

### GrammarTests.test_var_annot_module_semantics (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.typinganndata'">

### GrammarTests.test_var_annot_rhs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: cache'>

### GrammarTests.test_var_annot_simple_exec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"TypeError: <enum 'IntFlag'> cannot extend <class 'ceval.Flag'>">

### TokenTests.test_ellipsis (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertTrue\', False)"'>
