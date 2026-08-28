# Triage report: `conv_code_module_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_code_module.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+17 quarantined of 17 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion (summary)

All 17 extracted tests are quarantined. Dominant reasons:

- `harness-error:exit 0`: `InteractiveConsole.interact()` REPL harness (mocked
  `code.input` / `code.sys.stdout` / `code.sys.stderr`)
- `self.assertStartsWith`: `test_unicode_error` uses unittest assertion helper

No oracle pins are runnable until convert_suite can lift the interactive-console
REPL harness (`mock_sys`, `infunc.side_effect`, `console.interact()`).

## Census disposition (fp ecc30d23, test_code_module)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_code_module/i-0ce8662224e3420ac/`
- Farm triage (`conv_code_module.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: entire `test_code_module.py` suite exercises `code.InteractiveConsole`
  via mocked stdin/stdout/stderr REPL helpers that convert_suite cannot pin today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc / test_launcher /
  test_queue / test_timeout). Mitigation: `diff_runner.py` skips jac when `pinned` is empty
  (`wp/census-timeout-fp`).
