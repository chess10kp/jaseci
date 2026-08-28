# Triage report: `conv_atexit_pins.jac`

- source: reference/cpython/Lib/test/test_atexit.py
- guest leg: 0/3 marks
- pins: **0 passed** / 3 run (+5 quarantined of 8 extracted)

| pin | result | got |
|---|---|---|
| GeneralTest.test_general | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FunctionalTest.test_shutdown | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FunctionalTest.test_atexit_instances | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 3 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | FunctionalTest.test_atexit_instances, FunctionalTest.test_shutdown, GeneralTest.test_general |

## Quarantined at conversion

| test | reason |
|---|---|
| FunctionalTest.test_atexit_thread_safety | decorator:threading_helper.requires_working_threading |
| SubinterpreterTest.test_callbacks_leak | decorator:support.cpython_only |
| SubinterpreterTest.test_callbacks_leak_refcycle | decorator:support.cpython_only |
| SubinterpreterTest.test_callback_on_subinterpreter_teardown | decorator:support.cpython_only |
| SubinterpreterTest.test_atexit_with_low_memory | decorator:support.cpython_only |
