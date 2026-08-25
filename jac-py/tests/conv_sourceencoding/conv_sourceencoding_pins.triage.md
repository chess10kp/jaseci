# Triage report: `conv_sourceencoding_pins.jac`

- source: reference/cpython/Lib/test/test_source_encoding.py
- guest leg: 0/8 marks
- pins: **6 passed** / 8 run (+83 quarantined of 91 extracted)

| pin | result | got |
|---|---|---|
| MiscSourceEncodingTest.test_import_encoded_module | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC ModuleNotFoundError "No module named \'test.encoded_modules\'"'> |
| MiscSourceEncodingTest.test_compilestring | PASS | |
| MiscSourceEncodingTest.test_issue2301 | PASS | |
| MiscSourceEncodingTest.test_issue4626 | PASS | |
| MiscSourceEncodingTest.test_issue3297 | PASS | |
| MiscSourceEncodingTest.test_issue7820 | PASS | |
| MiscSourceEncodingTest.test_truncated_utf8_at_eof | PASS | |
| MiscSourceEncodingTest.test_exec_valid_coding | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'a\', \'\')"'> |

## Quarantined at conversion

| test | reason |
|---|---|
| MiscSourceEncodingTest.test_20731 | decorator:support.requires_subprocess |
| UTF8ValidatorTest.test_invalid_utf8 | decorator:unittest.skipIf |
| MiscSourceEncodingTest.test_bad_coding | helper:verify_bad_module(unresolved-name:**file**) |
| MiscSourceEncodingTest.test_bad_coding2 | helper:verify_bad_module(unresolved-name:**file**) |
| MiscSourceEncodingTest.test_error_from_string | self.assertStartsWith |
| FileSourceEncodingTest.test_default_coding | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_first_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_second_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_second_coding_line_empty_first_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_third_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_double_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_double_coding_same_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_double_coding_utf8 | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_long_first_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_long_second_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_long_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_long_coding_name | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_long_first_utf8_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_long_second_utf8_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_first_non_utf8_coding_line | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_second_non_utf8_coding_line | unresolved-name:check_script_output |
| BytesSourceEncodingTest.test_first_utf8_coding_line_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_second_utf8_coding_line_error | helper:check_script_error(unresolved-name:cm) |
| FileSourceEncodingTest.test_utf8_bom | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_utf8_bom_utf8_comments | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_utf8_bom_and_utf8_coding_line | unresolved-name:check_script_output |
| BytesSourceEncodingTest.test_utf8_bom_and_non_utf8_first_coding_line | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_utf8_bom_and_non_utf8_second_coding_line | helper:check_script_error(unresolved-name:cm) |
| FileSourceEncodingTest.test_non_utf8_shebang | unresolved-name:check_script_output |
| BytesSourceEncodingTest.test_utf8_shebang_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_non_utf8_shebang_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_non_utf8_second_line_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_non_utf8_third_line_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_utf8_bom_non_utf8_third_line_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_utf_8_non_utf8_third_line_error | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_utf8_non_utf8_third_line_error | helper:check_script_error(unresolved-name:cm) |
| FileSourceEncodingTest.test_crlf | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_crcrlf | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_crcrcrlf | unresolved-name:check_script_output |
| FileSourceEncodingTest.test_crcrcrlf2 | unresolved-name:check_script_output |
| BytesSourceEncodingTest.test_nul_in_first_coding_line | helper:check_script_error(unresolved-name:cm) |
| BytesSourceEncodingTest.test_nul_in_second_coding_line | helper:check_script_error(unresolved-name:cm) |
| MiscSourceEncodingTest.test_error_message | harness-error:AssertionError: SRE module mismatch |
| MiscSourceEncodingTest.test_file_parse | harness-error:SyntaxError: invalid syntax |
| MiscSourceEncodingTest.test_file_parse_error_multiline | harness-error:SyntaxError: invalid syntax |
| MiscSourceEncodingTest.test_tokenizer_fstring_warning_in_first_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_default_coding | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_first_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_second_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_second_coding_line_empty_first_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_third_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_double_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_double_coding_same_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_double_coding_utf8 | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_long_first_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_long_second_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_long_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_long_coding_name | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_long_first_utf8_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_long_second_utf8_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_first_non_utf8_coding_line | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_second_non_utf8_coding_line | harness-error:SyntaxError: invalid syntax |
| FileSourceEncodingTest.test_first_utf8_coding_line_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_second_utf8_coding_line_error | harness-error:AssertionError: SRE module mismatch |
| BytesSourceEncodingTest.test_utf8_bom | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_utf8_bom_utf8_comments | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_utf8_bom_and_utf8_coding_line | harness-error:SyntaxError: invalid syntax |
| FileSourceEncodingTest.test_utf8_bom_and_non_utf8_first_coding_line | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_utf8_bom_and_non_utf8_second_coding_line | harness-error:AssertionError: SRE module mismatch |
| BytesSourceEncodingTest.test_non_utf8_shebang | harness-error:SyntaxError: invalid syntax |
| FileSourceEncodingTest.test_utf8_shebang_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_non_utf8_shebang_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_non_utf8_second_line_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_non_utf8_third_line_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_utf8_bom_non_utf8_third_line_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_utf_8_non_utf8_third_line_error | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_utf8_non_utf8_third_line_error | harness-error:AssertionError: SRE module mismatch |
| BytesSourceEncodingTest.test_crlf | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_crcrlf | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_crcrcrlf | harness-error:SyntaxError: invalid syntax |
| BytesSourceEncodingTest.test_crcrcrlf2 | harness-error:SyntaxError: invalid syntax |
| FileSourceEncodingTest.test_nul_in_first_coding_line | harness-error:AssertionError: SRE module mismatch |
| FileSourceEncodingTest.test_nul_in_second_coding_line | harness-error:AssertionError: SRE module mismatch |

## Expected vs got

### MiscSourceEncodingTest.test_exec_valid_coding (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', \'a\', \'\')"'>

### MiscSourceEncodingTest.test_import_encoded_module (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC ModuleNotFoundError "No module named \'test.encoded_modules\'"'>
