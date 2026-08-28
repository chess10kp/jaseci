# Triage report: `conv_queue_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_queue.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+466 quarantined of 466 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion (summary)

All 466 extracted tests are quarantined. Dominant reasons:

- `uses-self.worker` / `uses-self._join_thread` (threading harness helpers)
- `uses-self._get` / `uses-self._put_shutdown` / `uses-self._get_task_done` (queue test helpers)
- `host-raised:RuntimeError: super(): no arguments` (C-extension queue subclasses)

No oracle pins are runnable until convert_suite can lift threading helpers and
`queue` module C-API subclasses.

## Census disposition (fp ecc30d23, test_queue)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_queue/i-078910eb87773942e/`
- Farm triage (`conv_queue.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: entire `test_queue.py` suite depends on unittest threading helpers
  and Py/C queue implementations that convert_suite cannot pin today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc). Mitigation:
  `diff_runner.py` skips jac when `pinned` is empty (`wp/census-timeout-fp`).
  Runnable-pin TIMEOUTs use `DEFAULT_JAC_TIMEOUT=300` (897-gap / 70e44a374).
