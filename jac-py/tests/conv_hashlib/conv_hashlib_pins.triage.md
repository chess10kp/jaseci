# Triage report: `conv_hashlib_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_hashlib.py
- guest leg: 0/11 marks
- pins: **0 passed** / 11 run (+71 quarantined of 82 extracted)

| pin | result | got |
|---|---|---|
| HashLibTestCase.test_algorithms_guaranteed | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_unknown_hash | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_new_upper_to_lower | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_sha256_update_over_4gb | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_sha3_256_update_over_4gb | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_blake2_update_over_4gb | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_blake2b | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_blake2s | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| HashLibTestCase.test_sha256_gil | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| KDFTests.test_normalized_name | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| KDFTests.test_file_digest | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 11 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | HashLibTestCase.test_algorithms_guaranteed, HashLibTestCase.test_blake2_update_over_4gb, HashLibTestCase.test_blake2b, HashLibTestCase.test_blake2s, HashLibTestCase.test_new_upper_to_lower, HashLibTestCase.test_sha256_gil, HashLibTestCase.test_sha256_update_over_4gb, HashLibTestCase.test_sha3_256_update_over_4gb, HashLibTestCase.test_unknown_hash, KDFTests.test_file_digest, KDFTests.test_normalized_name |

## Quarantined at conversion

| test | reason |
|---|---|
| HashLibTestCase.test_clinic_signature | decorator:unittest.skipIf |
| HashLibTestCase.test_clinic_signature_errors | decorator:unittest.skipIf |
| HashLibTestCase.test_get_builtin_constructor | decorator:support.thread_unsafe |
| HashLibTestCase.test_case_md5_huge | decorator:unittest.skipIf |
| HashLibTestCase.test_case_md5_uintmax | decorator:unittest.skipIf |
| HashLibTestCase.test_threaded_hashing | decorator:threading_helper.requires_working_threading |
| HashLibTestCase.test_disallow_instantiation | decorator:support.cpython_only |
| HashLibTestCase.test_hash_disallow_instantiation | decorator:unittest.skipUnless |
| KDFTests.test_pbkdf2_hmac_c | decorator:unittest.skipIf |
| KDFTests.test_scrypt | decorator:unittest.skipUnless |
| HashLibTestCase.test_hash_array | uses-self.hash_constructors |
| HashLibTestCase.test_algorithms_available | helper:skip_if_blake2_not_builtin(self.skipTest) |
| HashLibTestCase.test_usedforsecurity_true | self.skipTest |
| HashLibTestCase.test_usedforsecurity_false | uses-self._hashlib |
| HashLibTestCase.test_hexdigest | uses-self.hash_constructors |
| HashLibTestCase.test_digest_length_overflow | uses-self.hash_constructors |
| HashLibTestCase.test_name_attribute | uses-self.hash_constructors |
| HashLibTestCase.test_large_update | uses-self.hash_constructors |
| HashLibTestCase.test_no_unicode | uses-self.constructors_to_test |
| HashLibTestCase.test_no_unicode_blake2 | uses-self.constructors_to_test |
| HashLibTestCase.test_no_unicode_sha3 | uses-self.constructors_to_test |
| HashLibTestCase.test_blocksize_and_name | uses-self.constructors_to_test |
| HashLibTestCase.test_blocksize_name_sha3 | uses-self.constructors_to_test |
| HashLibTestCase.test_extra_sha3 | uses-self.constructors_to_test |
| HashLibTestCase.test_blocksize_name_blake2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_md5_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_md5_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_md5_2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha1_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha1_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha1_2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha1_3 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha224_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha224_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha224_2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha224_3 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha256_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha256_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha256_2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha256_3 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha384_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha384_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha384_2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha384_3 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha512_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha512_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha512_2 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha512_3 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_blake2b_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_blake2b_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_blake2b_all_parameters | uses-self.constructors_to_test |
| HashLibTestCase.test_blake2b_vectors | uses-self.constructors_to_test |
| HashLibTestCase.test_case_blake2s_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_blake2s_1 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_blake2s_all_parameters | uses-self.constructors_to_test |
| HashLibTestCase.test_blake2s_vectors | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_224_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_224_vector | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_256_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_256_vector | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_384_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_384_vector | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_512_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_sha3_512_vector | uses-self.constructors_to_test |
| HashLibTestCase.test_case_shake_128_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_shake128_vector | uses-self.constructors_to_test |
| HashLibTestCase.test_case_shake_256_0 | uses-self.constructors_to_test |
| HashLibTestCase.test_case_shake256_vector | uses-self.constructors_to_test |
| HashLibTestCase.test_gil | uses-self.hash_constructors |
| HashLibTestCase.test_get_fips_mode | uses-self.is_fips_mode |
| HashLibTestCase.test_readonly_types | uses-self.constructors_to_test |
