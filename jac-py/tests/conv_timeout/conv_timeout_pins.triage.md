# Triage report: `conv_timeout_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_timeout.py
- guest leg: 0/0 marks (no jac invocation; zero pinned pins)
- pins: **0 passed** / 0 run (+14 quarantined of 14 extracted)

| pin | result | got |
|---|---|---|

## Quarantined at conversion

| test | reason |
|---|---|
| CreationTestCase.testObjectCreation | helper:setUp(uses-self.enterContext) |
| CreationTestCase.testFloatReturnValue | helper:setUp(uses-self.enterContext) |
| CreationTestCase.testReturnType | helper:setUp(uses-self.enterContext) |
| CreationTestCase.testTypeCheck | helper:setUp(uses-self.enterContext) |
| CreationTestCase.testRangeCheck | helper:setUp(uses-self.enterContext) |
| CreationTestCase.testTimeoutThenBlocking | helper:setUp(uses-self.enterContext) |
| CreationTestCase.testBlockingThenTimeout | helper:setUp(uses-self.enterContext) |
| TCPTimeoutTestCase.testConnectTimeout | helper:setUp(uses-self.enterContext) |
| TCPTimeoutTestCase.testRecvTimeout | helper:setUp(uses-self.enterContext) |
| TCPTimeoutTestCase.testAcceptTimeout | helper:setUp(uses-self.enterContext) |
| TCPTimeoutTestCase.testSend | helper:setUp(uses-self.enterContext) |
| TCPTimeoutTestCase.testSendto | helper:setUp(uses-self.enterContext) |
| TCPTimeoutTestCase.testSendall | helper:setUp(uses-self.enterContext) |
| UDPTimeoutTestCase.testRecvfromTimeout | helper:setUp(uses-self.enterContext) |

## Census disposition (fp ecc30d23, test_timeout)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_timeout/i-078910eb87773942e/`
- Farm triage (`conv_timeout.triage.md`): `guest leg: TIMEOUT at 60s cap` with **0 pins
  run** - false positive: diff_runner invoked jac on an empty harness; cap hit
  fingerprinted as TIMEOUT despite no runnable guest leg.
- Root cause: all 14 tests use `setUp` with `self.enterContext`, which convert_suite
  cannot lift today.
- Disposition: **zero-pin false TIMEOUT** (same class as test_abc / test_queue).
  Mitigation: `diff_runner.py` skips jac when `pinned` is empty (`wp/census-timeout-fp`).
