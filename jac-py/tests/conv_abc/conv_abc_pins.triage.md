# Triage report: `conv_abc_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_abc.py
- guest leg: 0/0 marks
- pins: **0 passed** / 0 run (+1 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| test_factory | uses-self.assertEqual |

## Census disposition (fp ecc30d23, test_abc)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_abc/i-053a30bda3c271857/`
- Farm triage (`conv_abc.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: sole extracted test `test_factory` uses `self.assertEqual` / unittest
  helpers that convert_suite cannot lift today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_queue / test_timeout).
  Mitigation: `diff_runner.py` skips jac when `pinned` is empty (`wp/census-timeout-fp`).
