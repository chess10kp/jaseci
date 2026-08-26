# Triage report: `conv_zipfile64_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_zipfile64.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+2 quarantined of 4 extracted)

| pin | result | got |
|---|---|---|
| OtherTests.testMoreThan64kFiles | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| OtherTests.testMoreThan64kFilesAppend | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |

## Quarantined at conversion

| test | reason |
|---|---|
| TestsWithSourceFile.testStored | host-raised:NameError: name 'self' is not defined |
| TestsWithSourceFile.testDeflated | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### OtherTests.testMoreThan64kFiles (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### OtherTests.testMoreThan64kFilesAppend (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`
