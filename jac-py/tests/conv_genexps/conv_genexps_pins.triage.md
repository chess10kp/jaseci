# Triage report: `conv_genexps_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_genexps.py
- guest leg: 0/1 marks (local diff_runner, 300s budget)
- pins: **0 passed** / 1 run (+0 quarantined of 1 extracted)

| pin | result | got |
|---|---|---|
| genexps.doctests:doctests | GUEST-WRONG-OUTPUT | RUN<'AssertionError: '> |

## Expected vs got

### genexps.doctests:doctests (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<'AssertionError: '>

## Census disposition (fp ecc30d23, test_genexps)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_genexps/i-04d39ab9ba1e2244a/`
- Farm triage (`conv_genexps.triage.md`): `guest leg: TIMEOUT at 60s cap` for
  `genexps.doctests:doctests` (1 runnable pin; mega-doctest harness with 80+
  generator-expression checks in one snippet).
- Local diff_runner (300s budget): guest finishes but `GUEST-WRONG-OUTPUT`
  (`AssertionError` on doctest oracle) - not a false TIMEOUT like test_abc.
- Disposition: **PERF+semantic** - farm 60s cap fingerprints TIMEOUT before the
  guest leg completes; adequate budget surfaces a real generator-semantics gap.
  Farm cap bump or pin-splitting is infra/converter; AssertionError is runtime.
