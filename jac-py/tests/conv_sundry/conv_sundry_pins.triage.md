# Triage report: `conv_sundry_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_sundry.py
- guest leg: TIMEOUT at 60s cap (1 runnable pin)
- pins: **0 passed** / 1 run (+0 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|
| TestUntestedModules.test_untested_modules_can_be_imported | TIMEOUT | jac run hit 60s cap |

## Expected vs got

### TestUntestedModules.test_untested_modules_can_be_imported (TIMEOUT)

- expected: host oracle = `ok`
- got: jac run hit 60s cap

## Census disposition (fp ecc30d23, test_sundry)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_sundry/i-0127a1817986604d6/`
- Farm triage (`conv_sundry.triage.md`): `guest leg: TIMEOUT at 60s cap` for
  `TestUntestedModules.test_untested_modules_can_be_imported` (1 runnable pin;
  mega-import sweep of every stdlib module not covered by other tests).
- Root cause: single pin imports hundreds of stdlib modules sequentially; guest
  leg exceeds farm 60s cap before completion (PERF, not zero-pin false TIMEOUT).
- Disposition: **PERF** - farm cap fingerprints TIMEOUT before import sweep
  finishes. Mitigation: `DEFAULT_JAC_TIMEOUT=300` for runnable pins (897-gap /
  70e44a374) or pin-splitting at converter. Runtime unverified locally - CI gates it.
