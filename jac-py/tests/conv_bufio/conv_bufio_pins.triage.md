# Triage report: `conv_bufio_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_bufio.py
- guest leg: 0/4 marks
- pins: **0 passed** / 4 run (+0 quarantined of 4 extracted)

| pin | result | got |
|---|---|---|
| CBufferSizeTest.test_primepat | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PyBufferSizeTest.test_primepat | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| CBufferSizeTest.test_nullpat | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PyBufferSizeTest.test_nullpat | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 4 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | CBufferSizeTest.test_nullpat, CBufferSizeTest.test_primepat, PyBufferSizeTest.test_nullpat, PyBufferSizeTest.test_primepat |
