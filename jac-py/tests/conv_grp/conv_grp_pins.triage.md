# Triage report: `conv_grp_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_grp.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+1 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| GroupDatabaseTestCase.test_values | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'"> |
| GroupDatabaseTestCase.test_errors | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| GroupDatabaseTestCase.test_values_extended | self.skipTest |

## Expected vs got

### GroupDatabaseTestCase.test_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### GroupDatabaseTestCase.test_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'import_helper' from '<unknown>'">
