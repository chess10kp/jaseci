# Triage report: `conv_cmd_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_cmd.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+3 quarantined of 5 extracted)

| pin | result | got |
|---|---|---|
| TestAlternateInput.test_file_with_missing_final_nl | VM-CRASH | `ac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overload found for method "__add__" with the given argumen` |
| TestAlternateInput.test_input_reset_at_EOF | VM-CRASH | `ac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overload found for method "__add__" with the given argumen` |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 2 | VM-CRASH | `ac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overload found for method "__add__" with the given argumen` | TestAlternateInput.test_file_with_missing_final_nl, TestAlternateInput.test_input_reset_at_EOF |

## Quarantined at conversion

| test | reason |
|---|---|
| LazyImportTest.test_lazy_import | harness-error:SyntaxError: invalid syntax |
| CmdTestReadline.test_basic_completion | harness-error:AssertionError: SRE module mismatch |
| CmdTestReadline.test_bang_completion_without_do_shell | harness-error:AssertionError: SRE module mismatch |
