# Triage report: `conv_wave_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_wave.py
- guest leg: 0/10 marks
- pins: **9 passed** / 10 run (+3 quarantined of 13 extracted)

| pin | result | got |
|---|---|---|
| WaveLowLevelTest.test_read_no_chunks | PASS | |
| WaveLowLevelTest.test_read_no_riff_chunk | PASS | |
| WaveLowLevelTest.test_read_not_wave | PASS | |
| WaveLowLevelTest.test_read_no_fmt_no_data_chunk | PASS | |
| WaveLowLevelTest.test_read_no_data_chunk | PASS | |
| WaveLowLevelTest.test_read_no_fmt_chunk | PASS | |
| WaveLowLevelTest.test_read_wrong_form | PASS | |
| WaveLowLevelTest.test_read_wrong_number_of_channels | PASS | |
| WaveLowLevelTest.test_read_wrong_sample_width | PASS | |
| WaveLowLevelTest.test_open_in_write_raises | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'catch_unraisable_exception'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| MiscTestCase.test_read_deprecations | uses-self.assertWarns |
| MiscTestCase.test_write_deprecations | uses-self.assertWarns |
| MiscTestCase.test__all__ | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### WaveLowLevelTest.test_open_in_write_raises (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'catch_unraisable_exception'">
