# Triage report: `conv__opcode_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test__opcode.py
- guest leg: 0/5 marks
- pins: **0 passed** / 5 run (+2 quarantined of 7 extracted)

| pin | result | got |
|---|---|---|
| OpListTests.test_invalid_opcodes | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| OpListTests.test_is_valid | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| StackEffectTests.test_stack_effect | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| StackEffectTests.test_stack_effect_jump | GUEST-WRONG-OUTPUT | RUN<'AttributeError: get_intrinsic1_descs'> |
| SpecializationStatsTests.test_specialization_stats | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| OpListTests.test_opmaps | uses-self.assertEqual |
| OpListTests.test_oplists | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### OpListTests.test_invalid_opcodes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### OpListTests.test_is_valid (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### SpecializationStatsTests.test_specialization_stats (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### StackEffectTests.test_stack_effect (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>

### StackEffectTests.test_stack_effect_jump (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: get_intrinsic1_descs'>
