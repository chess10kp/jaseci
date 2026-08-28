# Triage report: `conv_base64_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_base64.py
- guest leg: 0/6 marks
- pins: **0 passed** / 6 run (+35 quarantined of 41 extracted)

| pin | result | got |
|---|---|---|
| LegacyBase64TestCase.test_decode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b64decode_padding_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b32hexencode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b32hexdecode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_ErrorHeritage | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_RFC4648_test_cases | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 6 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | BaseXYTestCase.test_ErrorHeritage, BaseXYTestCase.test_RFC4648_test_cases, BaseXYTestCase.test_b32hexdecode, BaseXYTestCase.test_b32hexencode, BaseXYTestCase.test_b64decode_padding_error, LegacyBase64TestCase.test_decode |

## Quarantined at conversion

| test | reason |
|---|---|
| LegacyBase64TestCase.test_encodebytes | uses-self.assertEqual |
| LegacyBase64TestCase.test_decodebytes | uses-self.assertEqual |
| LegacyBase64TestCase.test_encode | uses-self.assertEqual |
| BaseXYTestCase.test_b64encode | uses-self.assertEqual |
| BaseXYTestCase.test_b64decode | uses-self.assertEqual |
| BaseXYTestCase.test_b64decode_altchars | uses-self.assertEqual |
| BaseXYTestCase.test_b32encode | uses-self.assertEqual |
| BaseXYTestCase.test_b32decode | uses-self.assertEqual |
| BaseXYTestCase.test_b32decode_casefold | uses-self.assertEqual |
| BaseXYTestCase.test_b32decode_map01 | uses-self.assertEqual |
| BaseXYTestCase.test_b32hexencode_other_types | uses-self.assertEqual |
| BaseXYTestCase.test_b32hexdecode_other_types | uses-self.assertEqual |
| BaseXYTestCase.test_b16encode | uses-self.assertEqual |
| BaseXYTestCase.test_b16decode | uses-self.assertEqual |
| BaseXYTestCase.test_a85encode | uses-self.assertEqual |
| BaseXYTestCase.test_b85encode | uses-self.assertEqual |
| BaseXYTestCase.test_z85encode | uses-self.assertEqual |
| BaseXYTestCase.test_a85decode | uses-self.assertEqual |
| BaseXYTestCase.test_b85decode | uses-self.assertEqual |
| BaseXYTestCase.test_z85decode | uses-self.assertEqual |
| BaseXYTestCase.test_a85_padding | uses-self.assertEqual |
| BaseXYTestCase.test_b85_padding | uses-self.assertEqual |
| LazyImportTest.test_lazy_import | harness-error:SyntaxError: invalid syntax |
| BaseXYTestCase.test_b64decode_invalid_chars | harness-error:IndentationError: expected an indented block after 'except' statement on line 17 |
| BaseXYTestCase.test_b32decode_error | harness-error:IndentationError: expected an indented block after 'except' statement on line 20 |
| BaseXYTestCase.test_b32hexdecode_error | harness-error:IndentationError: expected an indented block after 'except' statement on line 20 |
| BaseXYTestCase.test_a85decode_errors | harness-error:IndentationError: expected an indented block after 'except' statement on line 12 |
| BaseXYTestCase.test_b85decode_errors | harness-error:IndentationError: expected an indented block after 'except' statement on line 12 |
| BaseXYTestCase.test_z85decode_errors | harness-error:IndentationError: expected an indented block after 'except' statement on line 12 |
| BaseXYTestCase.test_decode_nonascii_str | host-raised:AttributeError: module 'base64' has no attribute 'z85decode' |
| TestMain.test_encode_file | harness-error:SyntaxError: invalid syntax |
| TestMain.test_encode_from_stdin | harness-error:SyntaxError: invalid syntax |
| TestMain.test_decode | harness-error:SyntaxError: invalid syntax |
| TestMain.test_prints_usage_with_help_flag | harness-error:SyntaxError: invalid syntax |
| TestMain.test_prints_usage_with_invalid_flag | harness-error:SyntaxError: invalid syntax |
