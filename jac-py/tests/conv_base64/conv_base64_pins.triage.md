# Triage report: `conv_base64_pins.jac`

- source: reference/cpython/Lib/test/test_base64.py
- guest leg: 0/18 marks
- pins: **0 passed** / 18 run (+23 quarantined of 41 extracted)

| pin | result | got |
|---|---|---|
| LazyImportTest.test_lazy_import | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| LegacyBase64TestCase.test_decode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b64decode_padding_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b64decode_invalid_chars | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b32decode_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b32hexencode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b32hexdecode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b32hexdecode_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_a85decode_errors | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_b85decode_errors | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_z85decode_errors | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_decode_nonascii_str | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| BaseXYTestCase.test_RFC4648_test_cases | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestMain.test_encode_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestMain.test_encode_from_stdin | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestMain.test_decode | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestMain.test_prints_usage_with_help_flag | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestMain.test_prints_usage_with_invalid_flag | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 18 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | BaseXYTestCase.test_RFC4648_test_cases, BaseXYTestCase.test_a85decode_errors, BaseXYTestCase.test_b32decode_error, BaseXYTestCase.test_b32hexdecode, BaseXYTestCase.test_b32hexdecode_error, BaseXYTestCase.test_b32hexencode, BaseXYTestCase.test_b64decode_invalid_chars, BaseXYTestCase.test_b64decode_padding_error, BaseXYTestCase.test_b85decode_errors, BaseXYTestCase.test_decode_nonascii_str, BaseXYTestCase.test_z85decode_errors, LazyImportTest.test_lazy_import, LegacyBase64TestCase.test_decode, TestMain.test_decode, TestMain.test_encode_file, TestMain.test_encode_from_stdin, TestMain.test_prints_usage_with_help_flag, TestMain.test_prints_usage_with_invalid_flag |

## Quarantined at conversion

| test | reason |
|---|---|
| BaseXYTestCase.test_ErrorHeritage | self.assertIsSubclass |
| LegacyBase64TestCase.test_encodebytes | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| LegacyBase64TestCase.test_decodebytes | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| LegacyBase64TestCase.test_encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b64encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b64decode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b64decode_altchars | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b32encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b32decode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b32decode_casefold | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b32decode_map01 | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b32hexencode_other_types | host-raised:NameError: name 'self' is not defined |
| BaseXYTestCase.test_b32hexdecode_other_types | host-raised:NameError: name 'self' is not defined |
| BaseXYTestCase.test_b16encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b16decode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_a85encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b85encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_z85encode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_a85decode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b85decode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_z85decode | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_a85_padding | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
| BaseXYTestCase.test_b85_padding | host-raised:AttributeError: '_SelfNS' object has no attribute 'assertEqual' |
