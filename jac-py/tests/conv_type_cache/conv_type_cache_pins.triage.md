# Triage report: `conv_type_cache_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_type_cache.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+12 quarantined of 12 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion (summary)

All 12 extracted tests are quarantined. Dominant reasons:

- `decorator:unittest.skipIf`: version-tag / specialization guards on CPython-only paths
- `helper:_assign_valid_version_or_skip(self.skipTest)`: specialization tests skip when
  `_PyType_GetTypeVersion` is unavailable
- `harness-error:SkipTest: No module named '_testcapi'`: static-type specialization pin

No oracle pins are runnable until convert_suite can lift `unittest.skipIf`,
`_testcapi` helpers, and specialization version probes.

## Census disposition (fp ecc30d23, test_type_cache)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_type_cache/i-0fbfa59902be2c18a/`
- Farm triage (`conv_type_cache.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: entire `test_type_cache.py` suite depends on CPython-only `_testcapi` /
  `unittest.skipIf` guards that convert_suite cannot pin today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc / test_code_module /
  test_launcher / test_queue / test_timeout). Mitigation: `diff_runner.py` skips jac when
  `pinned` is empty (`wp/census-timeout-fp`).
