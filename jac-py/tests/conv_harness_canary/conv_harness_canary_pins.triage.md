# Triage report: `conv_harness_canary_pins.jac`

- source: (none - hand-written harness canary)
- guest leg: 0/8 marks
- pins: **5 passed** / 8 run (+0 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| HarnessCanary.test_pprint_import | PASS | |
| HarnessCanary.test_ordereddict_repr_surface | PASS | |
| HarnessCanary.test_guest_class_dunder_fallback | PASS | |
| HarnessCanary.test_functools_cache_present | PASS | |
| HarnessCanary.test_typing_import | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| HarnessCanary.test_function_descriptor_protocol | PASS | |
| HarnessCanary.test_intflag_inheritance | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| HarnessCanary.test_super_seed_bridge | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |

## Expected vs got

### HarnessCanary.test_intflag_inheritance (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### HarnessCanary.test_super_seed_bridge (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### HarnessCanary.test_typing_import (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`
