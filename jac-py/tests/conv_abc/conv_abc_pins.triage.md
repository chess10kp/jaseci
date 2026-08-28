# Triage report: `conv_abc_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_abc.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+1 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| test_factory | uses-self.assertEqual |

## Census disposition (fp ecc30d23, test_abc)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_abc/i-0127a1817986604d6/`
- Farm triage showed `guest leg: TIMEOUT at 60s cap` with **0 pins run** - false
  positive: diff_runner invoked jac on an empty harness; cap hit fingerprinted
  as TIMEOUT despite no runnable guest leg.
- Root cause: `test_factory` is a unittest factory (dynamic TestCase classes);
  convert_suite quarantines it (`uses-self.assertEqual`). No oracle pins exist.
- Fix: diff_runner skips jac when `pinned` is empty; cluster TIMEOUTs for suites
  with runnable pins are addressed by `DEFAULT_JAC_TIMEOUT=300` (70e44a374).
