# Triage report: `conv_launcher_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_launcher.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+46 quarantined of 46 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion (summary)

All 46 extracted tests are quarantined. Dominant reasons:

- `helper:run_py(helper:find_py(...))`: spawns real `py.exe` / Windows launcher
- `helper:script(...)`: shebang / argv0 launcher scripts
- `helper:fake_venv(...)`: virtualenv layout fixtures

No oracle pins are runnable until convert_suite can lift the Windows `test_launcher`
subprocess harness (`run_py`, `find_py`, `script`, `fake_venv`).

## Census disposition (fp ecc30d23, test_launcher)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_launcher/i-0fbfa59902be2c18a/`
- Farm triage (`conv_launcher.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: entire `test_launcher.py` suite exercises the Windows `py` launcher via
  subprocess helpers that convert_suite cannot pin today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc / test_queue /
  test_timeout). Mitigation: `diff_runner.py` skips jac when `pinned` is empty
  (`wp/census-timeout-fp`).
