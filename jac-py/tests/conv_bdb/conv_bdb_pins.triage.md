# Triage report: `conv_bdb_pins.jac`

- source: /opt/jacpy/repo/reference/cpython/Lib/test/test_bdb.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+34 quarantined of 36 extracted)

| pin | result | got |
|---|---|---|
| StateTestCase.test_skip_with_no_name_module | VM-CRASH | `Compiling jaclang/scale/config/project_env.jac...   Compiling jaclang/scale/_optdeps/__init__.jac...   Compiling jaclang/scale/_optdeps/optional_deps.jac...   Compiling jaclang/project/capabilities.jac...   Compiling jaclang/scale/events/streams/__init__.jac...   Compiling jaclang/scale/events/strea` |
| TestRegressions.test_format_stack_entry_no_lineno | VM-CRASH | `Compiling jaclang/scale/config/project_env.jac...   Compiling jaclang/scale/_optdeps/__init__.jac...   Compiling jaclang/scale/_optdeps/optional_deps.jac...   Compiling jaclang/project/capabilities.jac...   Compiling jaclang/scale/events/streams/__init__.jac...   Compiling jaclang/scale/events/strea` |

## Quarantined at conversion

| test | reason |
|---|---|
| StateTestCase.test_step_next_on_last_statement | unresolved-name:**file** |
| BreakpointTestCase.test_clear_at_no_bp | unresolved-name:**file** |
| BreakpointTestCase.test_load_bps_from_previous_Bdb_instance | unresolved-name:**file** |
| StateTestCase.test_step | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_stepinstr | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_next | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_next_over_import | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_next_on_plain_statement | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_next_in_caller_frame | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_return | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_return_in_caller_frame | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_until | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_until_with_too_large_count | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_until_in_caller_frame | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_skip | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_down | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| StateTestCase.test_up | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_bp_on_non_existent_module | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_bp_after_last_statement | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_temporary_bp | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_disabled_temporary_bp | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_bp_condition | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_bp_exception_on_condition_evaluation | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_bp_ignore_count | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_ignore_count_on_disabled_bp | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| BreakpointTestCase.test_clear_two_bp_on_same_line | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| RunTestCase.test_run_step | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| RunTestCase.test_runeval_step | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| IssuesTestCase.test_step_at_return_with_no_trace_in_caller | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| IssuesTestCase.test_next_until_return_in_generator | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| IssuesTestCase.test_next_command_in_generator_for_loop | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| IssuesTestCase.test_next_command_in_generator_with_subiterator | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| IssuesTestCase.test_return_command_in_generator_with_subiterator | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |
| IssuesTestCase.test_next_to_botframe | host-raised:AttributeError: '_SelfNS' object has no attribute 'id' |

## Expected vs got

### StateTestCase.test_skip_with_no_name_module (VM-CRASH)

- expected: host oracle = `ok`
- got: `Compiling jaclang/scale/config/project_env.jac...   Compiling jaclang/scale/_optdeps/__init__.jac...   Compiling jaclang/scale/_optdeps/optional_deps.jac...   Compiling jaclang/project/capabilities.jac...   Compiling jaclang/scale/events/streams/__init__.jac...   Compiling jaclang/scale/events/strea`

### TestRegressions.test_format_stack_entry_no_lineno (VM-CRASH)

- expected: host oracle = `ok`
- got: `Compiling jaclang/scale/config/project_env.jac...   Compiling jaclang/scale/_optdeps/__init__.jac...   Compiling jaclang/scale/_optdeps/optional_deps.jac...   Compiling jaclang/project/capabilities.jac...   Compiling jaclang/scale/events/streams/__init__.jac...   Compiling jaclang/scale/events/strea`
