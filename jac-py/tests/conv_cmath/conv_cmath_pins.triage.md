# Triage report: `conv_cmath_pins.jac`

- source: reference/cpython/Lib/test/test_cmath.py
- guest leg: 0/14 marks
- pins: **0 passed** / 14 run (+8 quarantined of 22 extracted)

| pin | result | got |
|---|---|---|
| CMathTests.test_constants | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_infinity_and_nan_constants | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_user_object | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_input_type | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_cmath_matches_math | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_specific_values | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_polar | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_polar_errno | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'requires_IEEE_754' from '<unknown>'"> |
| CMathTests.test_abs | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_abs_overflows | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_rect | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_isfinite | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_isnan | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |
| CMathTests.test_isinf | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.test_math'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| CMathTests.test_phase | decorator:unittest.skipIf |
| CMathTests.testTanhSign | self.assertComplexesAreIdentical |
| CMathTests.testAtanSign | self.assertComplexesAreIdentical |
| CMathTests.testAtanhSign | self.assertComplexesAreIdentical |
| IsCloseTests.test_reject_complex_tolerances | uses-self.isclose |
| IsCloseTests.test_complex_values | self.assertAllClose |
| IsCloseTests.test_complex_near_zero | self.assertAllClose |
| IsCloseTests.test_complex_special | self.assertIsNotClose |

## Expected vs got

### CMathTests.test_abs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_abs_overflows (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_cmath_matches_math (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_constants (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_infinity_and_nan_constants (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_input_type (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_isfinite (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_isinf (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_isnan (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_polar (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_polar_errno (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'requires_IEEE_754' from '<unknown>'">

### CMathTests.test_rect (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_specific_values (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">

### CMathTests.test_user_object (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.test_math'">
