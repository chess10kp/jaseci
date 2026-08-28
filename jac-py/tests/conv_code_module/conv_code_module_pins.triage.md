# Triage report: `conv_code_module_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_code_module.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+17 quarantined of 17 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| TestInteractiveConsole.test_unicode_error | self.assertStartsWith |
| TestInteractiveConsole.test_ps1 | harness-error:exit 0 |
| TestInteractiveConsole.test_ps2 | harness-error:exit 0 |
| TestInteractiveConsole.test_console_stderr | harness-error:exit 0 |
| TestInteractiveConsole.test_syntax_error | harness-error:exit 0 |
| TestInteractiveConsole.test_indentation_error | harness-error:exit 0 |
| TestInteractiveConsole.test_sysexcepthook | harness-error:exit 0 |
| TestInteractiveConsole.test_sysexcepthook_syntax_error | harness-error:exit 0 |
| TestInteractiveConsole.test_sysexcepthook_indentation_error | harness-error:exit 0 |
| TestInteractiveConsole.test_sysexcepthook_crashing_doesnt_close_repl | harness-error:exit 0 |
| TestInteractiveConsole.test_sysexcepthook_raising_BaseException | harness-error:exit 0 |
| TestInteractiveConsole.test_sysexcepthook_raising_SystemExit_gets_through | harness-error:exit 0 |
| TestInteractiveConsole.test_banner | harness-error:exit 0 |
| TestInteractiveConsole.test_exit_msg | harness-error:exit 0 |
| TestInteractiveConsole.test_cause_tb | harness-error:exit 0 |
| TestInteractiveConsole.test_context_tb | harness-error:exit 0 |
| TestInteractiveConsoleLocalExit.test_exit | harness-error:exit 0 |

## Census disposition (fp ecc30d23, test_code_module)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_code_module/i-0ce8662224e3420ac/`
- Farm triage (`conv_code_module.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: all 17 `InteractiveConsole` tests depend on `unittest.mock.patch` /
  `ExitStack` REPL harness helpers that convert_suite cannot lift today (`harness-error:exit 0`
  on host-oracle capture; one test also uses `assertStartsWith`).
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc / test_queue / test_timeout).
  Mitigation: `diff_runner.py` skips jac when `pinned` is empty (`wp/census-timeout-fp`).
