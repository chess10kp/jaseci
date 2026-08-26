# Triage report: `conv_abstract_numbers_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_abstract_numbers.py
- guest leg: 0/7 marks
- pins: **1 passed** / 7 run (+0 quarantined of 7 extracted)

| pin | result | got |
|---|---|---|
| TestNumbers.test_int | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsSubclass\', <class \'int\'>, <class \'numbers.Integral\'>)"'> |
| TestNumbers.test_float | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsSubclass\', <class \'float\'>, <class \'numbers.Real\'>)"'> |
| TestNumbers.test_complex | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertIsSubclass\', <class \'complex\'>, <class \'numbers.Complex\'>)"'> |
| TestNumbersDefaultMethods.test_complex | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertFalse\', True)"'> |
| TestNumbersDefaultMethods.test_real | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for divmod(): \'MyReal\' and \'int\'"'> |
| TestNumbersDefaultMethods.test_rational | PASS | |
| TestNumbersDefaultMethods.test_integral | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "\'MyIntegral\' object cannot be interpreted as an integer"'> |

## Expected vs got

### TestNumbers.test_complex (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsSubclass\', <class \'complex\'>, <class \'numbers.Complex\'>)"'>

### TestNumbers.test_float (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsSubclass\', <class \'float\'>, <class \'numbers.Real\'>)"'>

### TestNumbers.test_int (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertIsSubclass\', <class \'int\'>, <class \'numbers.Integral\'>)"'>

### TestNumbersDefaultMethods.test_complex (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertFalse\', True)"'>

### TestNumbersDefaultMethods.test_integral (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "\'MyIntegral\' object cannot be interpreted as an integer"'>

### TestNumbersDefaultMethods.test_real (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "unsupported operand type(s) for divmod(): \'MyReal\' and \'int\'"'>
