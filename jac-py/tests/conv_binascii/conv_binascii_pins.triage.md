# Triage report: `conv_binascii_pins.jac`

- source: reference/cpython/Lib/test/test_binascii.py
- guest leg: 0/47 marks
- pins: **47 passed** / 47 run (+23 quarantined of 70 extracted)

| pin | result | got |
|---|---|---|
| ArrayBinASCIITest.test_exceptions | PASS | |
| BytearrayBinASCIITest.test_exceptions | PASS | |
| MemoryviewBinASCIITest.test_exceptions | PASS | |
| ArrayBinASCIITest.test_functions | PASS | |
| BytearrayBinASCIITest.test_functions | PASS | |
| MemoryviewBinASCIITest.test_functions | PASS | |
| ArrayBinASCIITest.test_returned_value | PASS | |
| BytearrayBinASCIITest.test_returned_value | PASS | |
| MemoryviewBinASCIITest.test_returned_value | PASS | |
| ArrayBinASCIITest.test_base64valid | PASS | |
| BytearrayBinASCIITest.test_base64valid | PASS | |
| MemoryviewBinASCIITest.test_base64valid | PASS | |
| ArrayBinASCIITest.test_base64invalid | PASS | |
| BytearrayBinASCIITest.test_base64invalid | PASS | |
| MemoryviewBinASCIITest.test_base64invalid | PASS | |
| ArrayBinASCIITest.test_uu | PASS | |
| BytearrayBinASCIITest.test_uu | PASS | |
| MemoryviewBinASCIITest.test_uu | PASS | |
| ArrayBinASCIITest.test_crc_hqx | PASS | |
| BytearrayBinASCIITest.test_crc_hqx | PASS | |
| MemoryviewBinASCIITest.test_crc_hqx | PASS | |
| ArrayBinASCIITest.test_crc32 | PASS | |
| BytearrayBinASCIITest.test_crc32 | PASS | |
| MemoryviewBinASCIITest.test_crc32 | PASS | |
| ArrayBinASCIITest.test_hex | PASS | |
| BytearrayBinASCIITest.test_hex | PASS | |
| MemoryviewBinASCIITest.test_hex | PASS | |
| ArrayBinASCIITest.test_hex_separator | PASS | |
| BytearrayBinASCIITest.test_hex_separator | PASS | |
| MemoryviewBinASCIITest.test_hex_separator | PASS | |
| BytearrayBinASCIITest.test_qp | PASS | |
| MemoryviewBinASCIITest.test_qp | PASS | |
| ArrayBinASCIITest.test_empty_string | PASS | |
| BytearrayBinASCIITest.test_empty_string | PASS | |
| MemoryviewBinASCIITest.test_empty_string | PASS | |
| ArrayBinASCIITest.test_unicode_b2a | PASS | |
| BytearrayBinASCIITest.test_unicode_b2a | PASS | |
| MemoryviewBinASCIITest.test_unicode_b2a | PASS | |
| ArrayBinASCIITest.test_unicode_a2b | PASS | |
| BytearrayBinASCIITest.test_unicode_a2b | PASS | |
| MemoryviewBinASCIITest.test_unicode_a2b | PASS | |
| ArrayBinASCIITest.test_b2a_base64_newline | PASS | |
| BytearrayBinASCIITest.test_b2a_base64_newline | PASS | |
| MemoryviewBinASCIITest.test_b2a_base64_newline | PASS | |
| ArrayBinASCIITest.test_c_contiguity | PASS | |
| BytearrayBinASCIITest.test_c_contiguity | PASS | |
| MemoryviewBinASCIITest.test_c_contiguity | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| ArrayBinASCIITest.test_b2a_roundtrip | unresolved-name:backtick |
| BytearrayBinASCIITest.test_b2a_roundtrip | unresolved-name:backtick |
| MemoryviewBinASCIITest.test_b2a_roundtrip | unresolved-name:backtick |
| ArrayBinASCIITest.test_hex_roundtrip | unresolved-name:binary |
| BytearrayBinASCIITest.test_hex_roundtrip | unresolved-name:binary |
| MemoryviewBinASCIITest.test_hex_roundtrip | unresolved-name:binary |
| ArrayBinASCIITest.test_b2a_qp_a2b_qp_round_trip | unresolved-name:binary |
| BytearrayBinASCIITest.test_b2a_qp_a2b_qp_round_trip | unresolved-name:binary |
| MemoryviewBinASCIITest.test_b2a_qp_a2b_qp_round_trip | unresolved-name:binary |
| ArrayBinASCIITest.test_base64_roundtrip | unresolved-name:binary |
| BytearrayBinASCIITest.test_base64_roundtrip | unresolved-name:binary |
| MemoryviewBinASCIITest.test_base64_roundtrip | unresolved-name:binary |
| ArrayBinASCIITest.test_base64_strict_mode | harness-error:AssertionError: SRE module mismatch |
| BytearrayBinASCIITest.test_base64_strict_mode | harness-error:AssertionError: SRE module mismatch |
| MemoryviewBinASCIITest.test_base64_strict_mode | harness-error:AssertionError: SRE module mismatch |
| ArrayBinASCIITest.test_base64_excess_data | harness-error:AssertionError: SRE module mismatch |
| BytearrayBinASCIITest.test_base64_excess_data | harness-error:AssertionError: SRE module mismatch |
| MemoryviewBinASCIITest.test_base64_excess_data | harness-error:AssertionError: SRE module mismatch |
| ArrayBinASCIITest.test_base64errors | harness-error:AssertionError: SRE module mismatch |
| BytearrayBinASCIITest.test_base64errors | harness-error:AssertionError: SRE module mismatch |
| MemoryviewBinASCIITest.test_base64errors | harness-error:AssertionError: SRE module mismatch |
| ArrayBinASCIITest.test_qp | host-raised:UnboundLocalError: cannot access local variable 'type2test' where it is not associated with a value |
| ChecksumBigBufferTestCase.test_big_buffer | harness-error:SyntaxError: invalid syntax |
