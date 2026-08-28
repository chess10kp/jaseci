# Triage report: `conv_stable_abi_ctypes_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_stable_abi_ctypes.py
- guest leg: VM-CRASH (1 runnable pin; farm typeshed missing)
- pins: **0 passed** / 1 run (+2 quarantined of 3 extracted)

| pin | result | got |
|---|---|---|
| TestStableABIAvailability.test_available_symbols | VM-CRASH | typeshed stdlib stubs missing on farm EC2 |

## Quarantined at conversion

| test | reason |
|---|---|
| TestStableABIAvailability.test_windows_feature_macros | decorator:unittest.skipIf |
| TestStableABIAvailability.test_feature_macros | unresolved-name:get_feature_macros |

## Expected vs got

### TestStableABIAvailability.test_available_symbols (VM-CRASH)

- expected: host oracle = `ok`
- got: `Error: type inference is on the critical path of every compilation, but the
  vendored typeshed stdlib stubs are missing from this environment`

## Census disposition (fp ecc30d23, test_stable_abi_ctypes)

- S3: `s3://jacpy-farm-490004654770-us-west-2/results/test_stable_abi_ctypes/i-04d39ab9ba1e2244a/`
- Farm triage (`conv_stable_abi_ctypes.triage.md`): `VM-CRASH` on the sole runnable
  pin when jac cannot compile due to missing typeshed on the farm worker image.
- Root cause: **farm infra gap** (typeshed not fetched via `zig build fetch-typeshed`),
  not a jacpython semantic failure. Remaining pins need `get_feature_macros` lifting
  or platform `skipIf` guards.
- Disposition: **farm-infra false VM-CRASH**. Re-run after typeshed bootstrap on
  farm; no jac runtime fix required for this fingerprint. Runtime unverified locally -
  CI gates it.
