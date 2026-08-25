# Triage report: `conv_atexit_pins.jac`

- source: reference/cpython/Lib/test/test_atexit.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+6 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| FunctionalTest.test_shutdown | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'SuppressCrashReport' from '<unknown>'"> |
| FunctionalTest.test_atexit_instances | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'SuppressCrashReport' from '<unknown>'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| FunctionalTest.test_atexit_thread_safety | decorator:threading_helper.requires_working_threading |
| SubinterpreterTest.test_callbacks_leak | decorator:support.cpython_only |
| SubinterpreterTest.test_callbacks_leak_refcycle | decorator:support.cpython_only |
| SubinterpreterTest.test_callback_on_subinterpreter_teardown | decorator:support.cpython_only |
| SubinterpreterTest.test_atexit_with_low_memory | decorator:support.cpython_only |
| GeneralTest.test_general | host-raised:AssertionError: script _test_atexit.py failed |

## Expected vs got

### FunctionalTest.test_atexit_instances (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'SuppressCrashReport' from '<unknown>'">

### FunctionalTest.test_shutdown (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'SuppressCrashReport' from '<unknown>'">
