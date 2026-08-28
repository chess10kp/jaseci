# Triage report: `conv_sort_pins.jac`

- source: reference/cpython/Lib/test/test_sort.py
- guest leg: 0/14 marks
- pins: **3 passed** / 14 run (+7 quarantined of 21 extracted)

| pin | result | got |
|---|---|---|
| TestBase.test_small_stability | PASS | |
| TestBugs.test_bug453523 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestBugs.test_undetected_mutation | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_decorated | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_baddecorator | PASS | |
| TestDecorateSortUndecorate.test_stability | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_key_with_exception | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_key_with_mutation | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_key_with_mutating_del | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_key_with_mutating_del_and_exception | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_reverse | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDecorateSortUndecorate.test_reverse_stability | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestOptimizedCompares.test_not_all_tuples | PASS | |
| TestOptimizedCompares.test_none_in_tuples | GUEST-WRONG-OUTPUT | RUN<'AttributeError: verbose'> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBase.testStressfully | uses-self.i |
| TestOptimizedCompares.test_safe_object_compare | host-raised:NameError: name 'self' is not defined |
| TestOptimizedCompares.test_unsafe_object_compare | host-raised:NameError: name 'self' is not defined |
| TestOptimizedCompares.test_unsafe_latin_compare | host-raised:NameError: name 'self' is not defined |
| TestOptimizedCompares.test_unsafe_long_compare | host-raised:NameError: name 'self' is not defined |
| TestOptimizedCompares.test_unsafe_float_compare | host-raised:NameError: name 'self' is not defined |
| TestOptimizedCompares.test_unsafe_tuple_compare | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### TestBugs.test_bug453523 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBugs.test_undetected_mutation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_decorated (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_key_with_exception (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_key_with_mutating_del (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_key_with_mutating_del_and_exception (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_key_with_mutation (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_reverse (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_reverse_stability (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDecorateSortUndecorate.test_stability (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestOptimizedCompares.test_none_in_tuples (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AttributeError: verbose'>
