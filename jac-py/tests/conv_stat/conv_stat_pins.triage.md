# Triage report: `conv_stat_pins.jac`

- source: reference/cpython/Lib/test/test_stat.py
- guest leg: 0/9 marks
- pins: **0 passed** / 9 run (+9 quarantined of 18 extracted)

| pin | result | got |
|---|---|---|
| TestFilemodeCStat.test_filemode_does_not_misclassify_random_bits | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodePyStat.test_filemode_does_not_misclassify_random_bits | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodeCStat.test_directory | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodeCStat.test_link | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodeCStat.test_socket | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodeCStat.test_module_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodePyStat.test_module_attributes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodeCStat.test_flags_consistent | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFilemodePyStat.test_flags_consistent | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 9 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | TestFilemodeCStat.test_directory, TestFilemodeCStat.test_filemode_does_not_misclassify_random_bits, TestFilemodeCStat.test_flags_consistent, TestFilemodeCStat.test_link, TestFilemodeCStat.test_module_attributes, TestFilemodeCStat.test_socket, TestFilemodePyStat.test_filemode_does_not_misclassify_random_bits, TestFilemodePyStat.test_flags_consistent, TestFilemodePyStat.test_module_attributes |

## Quarantined at conversion

| test | reason |
|---|---|
| TestFilemode.test_fifo | decorator:unittest.skipUnless |
| TestFilemode.test_devices | decorator:unittest.skipUnless |
| TestFilemode.test_file_attribute_constants | decorator:unittest.skipUnless |
| TestFilemode.test_macosx_attribute_values | decorator:unittest.skipUnless |
| TestFilemodeCStat.test_mode | self.assertStartsWith |
| TestFilemodePyStat.test_mode | self.assertStartsWith |
| TestFilemodePyStat.test_directory | unresolved-name:assertS_IS |
| TestFilemodePyStat.test_link | unresolved-name:assertS_IS |
| TestFilemodePyStat.test_socket | unresolved-name:assertS_IS |
