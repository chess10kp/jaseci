# Triage report: `conv_unicodedata_pins.jac`

- source: reference/cpython/Lib/test/test_unicodedata.py
- guest leg: 0/8 marks
- pins: **4 passed** / 8 run (+30 quarantined of 38 extracted)

| pin | result | got |
|---|---|---|
| UnicodeMiscTest.test_failed_import_during_compiling | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'"> |
| UnicodeMiscTest.test_unicodedata_unload_reload | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'"> |
| UnicodeMiscTest.test_ucd_510 | PASS | |
| UnicodeMiscTest.test_bug_5828 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'"> |
| UnicodeMiscTest.test_bug_4971 | PASS | |
| UnicodeMiscTest.test_linebreak_7643 | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'"> |
| NormalizationTest.test_edge_cases | PASS | |
| NormalizationTest.test_bug_834676 | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| UnicodeMethodsTest.test_method_checksum | uses-self.expectedchecksum |
| UnicodeFunctionsTest.test_function_checksum | uses-self.db |
| UnicodeFunctionsTest.test_name | uses-self.db |
| UnicodeFunctionsTest.test_name_inverse_lookup | uses-self.db |
| UnicodeFunctionsTest.test_no_names_in_pua | uses-self.db |
| UnicodeFunctionsTest.test_lookup_nonexistant | uses-self.db |
| UnicodeFunctionsTest.test_digit | uses-self.db |
| UnicodeFunctionsTest.test_numeric | uses-self.old |
| UnicodeFunctionsTest.test_decimal | uses-self.old |
| UnicodeFunctionsTest.test_category | uses-self.old |
| UnicodeFunctionsTest.test_bidirectional | uses-self.old |
| UnicodeFunctionsTest.test_decomposition | uses-self.old |
| UnicodeFunctionsTest.test_mirrored | uses-self.old |
| UnicodeFunctionsTest.test_combining | uses-self.old |
| UnicodeFunctionsTest.test_normalization | uses-self.old |
| UnicodeFunctionsTest.test_pr29 | uses-self.db |
| UnicodeFunctionsTest.test_issue10254 | uses-self.db |
| UnicodeFunctionsTest.test_long_combining_mark_run | uses-self.db |
| UnicodeFunctionsTest.test_combining_mark_run_fast_paths | uses-self.db |
| UnicodeFunctionsTest.test_issue29456 | uses-self.db |
| UnicodeFunctionsTest.test_east_asian_width | uses-self.db |
| UnicodeFunctionsTest.test_east_asian_width_unassigned | uses-self.db |
| UnicodeMiscTest.test_decimal_numeric_consistent | uses-self.db |
| UnicodeMiscTest.test_digit_numeric_consistent | uses-self.db |
| UnicodeMiscTest.test_normalize_consistent | uses-self.db |
| UnicodeMiscTest.test_bug_1704793 | uses-self.db |
| NormalizationTest.test_normalization | helper:run_normalization_tests(helper:unistr(decorated-helper)) |
| NormalizationTest.test_normalization_3_2_0 | helper:run_normalization_tests(helper:unistr(decorated-helper)) |
| NormalizationTest.test_normalize_return_type | uses-self.subTest |
| UnicodeMiscTest.test_disallow_instantiation | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### UnicodeMiscTest.test_bug_5828 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'">

### UnicodeMiscTest.test_failed_import_during_compiling (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'">

### UnicodeMiscTest.test_linebreak_7643 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'">

### UnicodeMiscTest.test_unicodedata_unload_reload (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'open_urlresource' from '<unknown>'">
