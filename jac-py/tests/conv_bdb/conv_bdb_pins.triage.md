# Triage report: `conv_bdb_pins.jac`

- source: reference/cpython/Lib/test/test_bdb.py
- guest leg: 0/0 marks
- pins: **0 passed** / 0 run (+36 quarantined of 36 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| StateTestCase.test_step | unsupported-import:test.support |
| StateTestCase.test_step_next_on_last_statement | unsupported-import:test.support |
| StateTestCase.test_stepinstr | unsupported-import:test.support |
| StateTestCase.test_next | unsupported-import:test.support |
| StateTestCase.test_next_over_import | unsupported-import:test.support |
| StateTestCase.test_next_on_plain_statement | unsupported-import:test.support |
| StateTestCase.test_next_in_caller_frame | unsupported-import:test.support |
| StateTestCase.test_return | unsupported-import:test.support |
| StateTestCase.test_return_in_caller_frame | unsupported-import:test.support |
| StateTestCase.test_until | unsupported-import:test.support |
| StateTestCase.test_until_with_too_large_count | unsupported-import:test.support |
| StateTestCase.test_until_in_caller_frame | unsupported-import:test.support |
| StateTestCase.test_skip | unsupported-import:test.support |
| StateTestCase.test_skip_with_no_name_module | unsupported-import:test.support |
| StateTestCase.test_down | unsupported-import:test.support |
| StateTestCase.test_up | unsupported-import:test.support |
| BreakpointTestCase.test_bp_on_non_existent_module | unsupported-import:test.support |
| BreakpointTestCase.test_bp_after_last_statement | unsupported-import:test.support |
| BreakpointTestCase.test_temporary_bp | unsupported-import:test.support |
| BreakpointTestCase.test_disabled_temporary_bp | unsupported-import:test.support |
| BreakpointTestCase.test_bp_condition | unsupported-import:test.support |
| BreakpointTestCase.test_bp_exception_on_condition_evaluation | unsupported-import:test.support |
| BreakpointTestCase.test_bp_ignore_count | unsupported-import:test.support |
| BreakpointTestCase.test_ignore_count_on_disabled_bp | unsupported-import:test.support |
| BreakpointTestCase.test_clear_two_bp_on_same_line | unsupported-import:test.support |
| BreakpointTestCase.test_clear_at_no_bp | unsupported-import:test.support |
| BreakpointTestCase.test_load_bps_from_previous_Bdb_instance | unsupported-import:test.support |
| RunTestCase.test_run_step | unsupported-import:test.support |
| RunTestCase.test_runeval_step | unsupported-import:test.support |
| IssuesTestCase.test_step_at_return_with_no_trace_in_caller | unsupported-import:test.support |
| IssuesTestCase.test_next_until_return_in_generator | unsupported-import:test.support |
| IssuesTestCase.test_next_command_in_generator_for_loop | unsupported-import:test.support |
| IssuesTestCase.test_next_command_in_generator_with_subiterator | unsupported-import:test.support |
| IssuesTestCase.test_return_command_in_generator_with_subiterator | unsupported-import:test.support |
| IssuesTestCase.test_next_to_botframe | unsupported-import:test.support |
| TestRegressions.test_format_stack_entry_no_lineno | unsupported-import:test.support |
