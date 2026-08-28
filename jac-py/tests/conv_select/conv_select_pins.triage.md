# Triage report: `conv_select_pins.jac`

- source: reference/cpython/Lib/test/test_select.py
- guest leg: 0/2 marks
- pins: **0 passed** / 2 run (+4 quarantined of 6 extracted)

| pin | result | got |
|---|---|---|
| SelectTestCase.test_error_conditions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SelectTestCase.test_returned_list_identity | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | SelectTestCase.test_error_conditions, SelectTestCase.test_returned_list_identity |

## Quarantined at conversion

| test | reason |
|---|---|
| SelectTestCase.test_select | decorator:support.requires_fork |
| SelectTestCase.test_select_mutated | decorator:unittest.skipIf |
| SelectTestCase.test_errno | unresolved-name:**file** |
| SelectTestCase.test_disallow_instantiation | host-raised:NameError: name 'self' is not defined |
