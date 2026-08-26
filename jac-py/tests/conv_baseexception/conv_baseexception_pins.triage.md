# Triage report: `conv_baseexception_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_baseexception.py
- guest leg: 0/6 marks
- pins: **6 passed** / 6 run (+5 quarantined of 11 extracted)

| pin | result | got |
|---|---|---|
| ExceptionClassTests.test_setstate_refcount_no_crash | PASS | |
| UsageTests.test_raise_new_style_non_exception | PASS | |
| UsageTests.test_raise_string | PASS | |
| UsageTests.test_catch_non_BaseException | PASS | |
| UsageTests.test_catch_BaseException_instance | PASS | |
| UsageTests.test_catch_string | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ExceptionClassTests.test_builtins_new_style | self.assertIsSubclass |
| ExceptionClassTests.test_inheritance | helper:verify_instance_interface(self.assertHasAttr) |
| ExceptionClassTests.test_interface_single_arg | host-raised:NameError: name 'self' is not defined |
| ExceptionClassTests.test_interface_multi_arg | host-raised:NameError: name 'self' is not defined |
| ExceptionClassTests.test_interface_no_arg | host-raised:NameError: name 'self' is not defined |
