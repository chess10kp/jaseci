# Triage report: `conv_type_cache_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_type_cache.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+12 quarantined of 12 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| TypeCacheTests.test_tp_version_tag_unique | decorator:unittest.skipIf |
| TypeCacheTests.test_type_assign_version | decorator:unittest.skipIf |
| TypeCacheTests.test_type_assign_specific_version | decorator:unittest.skipIf |
| TypeCacheTests.test_per_class_limit | decorator:unittest.skipIf |
| TypeCacheTests.test_119462 | decorator:unittest.skipIf |
| TypeCacheTests.test_abc_register_invalidates_subclass_versions | decorator:unittest.skipIf |
| TypeCacheWithSpecializationTests.test_class_load_attr_specialization_user_type | helper:_assign_valid_version_or_skip(self.skipTest) |
| TypeCacheWithSpecializationTests.test_property_load_attr_specialization_user_type | helper:_assign_valid_version_or_skip(self.skipTest) |
| TypeCacheWithSpecializationTests.test_store_attr_specialization_user_type | helper:_assign_valid_version_or_skip(self.skipTest) |
| TypeCacheWithSpecializationTests.test_class_call_specialization_user_type | helper:_assign_valid_version_or_skip(self.skipTest) |
| TypeCacheWithSpecializationTests.test_to_bool_specialization_user_type | helper:_assign_valid_version_or_skip(self.skipTest) |
| TypeCacheWithSpecializationTests.test_class_load_attr_specialization_static_type | harness-error:unittest.case.SkipTest: No module named '_testcapi' |

## Census disposition (fp ecc30d23, test_type_cache)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_type_cache/i-0fbfa59902be2c18a/`
- Farm triage (`conv_type_cache.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: all 12 tests are gated on `unittest.skipIf` / `_testcapi` specialization
  helpers that convert_suite cannot lift today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc / test_code_module).
  Mitigation: `diff_runner.py` skips jac when `pinned` is empty (`wp/census-timeout-fp`).
