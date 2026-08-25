# Triage report: `conv_lzma_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_lzma.py
- guest leg: 0/115 marks
- pins: **10 passed** / 115 run (+6 quarantined of 121 extracted)

| pin | result | got |
|---|---|---|
| CompressorDecompressorTestCase.test_simple_bad_args | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_bad_filter_spec | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_after_eof | PASS | |
| CompressorDecompressorTestCase.test_decompressor_memlimit | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_auto | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_xz | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_alone | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_raw_1 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_raw_2 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_raw_3 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_raw_4 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_chunks | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_chunks_empty | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_chunks_maxsize | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_inputbuf_1 | PASS | |
| CompressorDecompressorTestCase.test_decompressor_inputbuf_2 | PASS | |
| CompressorDecompressorTestCase.test_decompressor_inputbuf_3 | PASS | |
| CompressorDecompressorTestCase.test_decompressor_unused_data | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_bad_input | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_bug_28275 | PASS | |
| CompressorDecompressorTestCase.test_roundtrip_xz | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_roundtrip_alone | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_roundtrip_raw | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_roundtrip_raw_empty | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_roundtrip_chunks | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_roundtrip_empty_chunks | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_decompressor_multistream | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressorDecompressorTestCase.test_pickle | PASS | |
| CompressorDecompressorTestCase.test_uninitialized_LZMADecompressor_crash | PASS | |
| CompressDecompressFunctionTestCase.test_bad_args | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_memlimit | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_good_input | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_incomplete_input | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_bad_input | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_roundtrip | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_multistream | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_trailing_junk | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| CompressDecompressFunctionTestCase.test_decompress_multistream_trailing_junk | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_init | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_init_with_PathLike_filename | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_init_with_filename | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_init_mode | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_init_bad_mode | PASS | |
| FileTestCase.test_init_bad_check | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_init_bad_preset | PASS | |
| FileTestCase.test_init_bad_filter_spec | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_init_with_preset_and_filters | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_close | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BytesIO.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_closed | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_fileno | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seekable | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_readable | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_writable | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_read_0 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_read_10 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_multistream | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_read_multistream_buffer_size_aligned | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_trailing_junk | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_multistream_trailing_junk | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_from_file | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_read_from_file_with_bytes_filename | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_read_from_fileobj | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_read_from_fileobj_with_int_name | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_read_incomplete | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_truncated | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_bad_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read_bad_data | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read1 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read1_0 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read1_10 | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read1_multistream | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_read1_bad_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_peek_bad_args | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__exit__'">` |
| FileTestCase.test_iterator | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_readline | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BytesIO.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_readlines | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BytesIO.__enter__() takes no arguments (1 given)'">` |
| FileTestCase.test_decompress_limited | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_10 | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_append | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_to_file | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_to_file_with_bytes_filename | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_to_fileobj | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_to_fileobj_with_int_name | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_append_to_file | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_write_bad_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_writelines | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| FileTestCase.test_seek_forward | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_forward_across_streams | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_forward_relative_to_current | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_forward_relative_to_end | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_backward | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_backward_across_streams | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_backward_relative_to_end | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_past_end | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_past_start | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_seek_bad_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_tell | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_tell_bad_args | GUEST-WRONG-OUTPUT | RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'"> |
| FileTestCase.test_issue21872 | PASS | |
| FileTestCase.test_issue44439 | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC AttributeError '__exit__'">` |
| OpenTestCase.test_binary_modes | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_text_modes | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_filename | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_with_pathlike_filename | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_bad_params | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_format_and_filters | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_encoding | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_encoding_error_handler | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| OpenTestCase.test_newline | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| MiscellaneousTestCase.test_is_check_supported | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| MiscellaneousTestCase.test__encode_filter_properties | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| MiscellaneousTestCase.test__decode_filter_properties | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |
| MiscellaneousTestCase.test_filter_properties_roundtrip | GUEST-WRONG-OUTPUT | RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| CompressorDecompressorTestCase.test_compressor_bigmem | decorator:support.skip_if_pgo_task |
| CompressorDecompressorTestCase.test_decompressor_bigmem | decorator:support.skip_if_pgo_task |
| CompressorDecompressorTestCase.test_refleaks_in_decompressor___init__ | decorator:support.refcount_test |
| FileTestCase.test_init_with_x_mode | self.addCleanup |
| FileTestCase.test_peek | self.assertStartsWith |
| OpenTestCase.test_x_mode | self.addCleanup |

## Expected vs got

### CompressDecompressFunctionTestCase.test_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_bad_input (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_good_input (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_incomplete_input (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_memlimit (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_multistream (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_multistream_trailing_junk (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_decompress_trailing_junk (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressDecompressFunctionTestCase.test_roundtrip (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_bad_filter_spec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_alone (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_auto (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_bad_input (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_chunks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_chunks_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_chunks_maxsize (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_memlimit (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_multistream (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_raw_1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_raw_2 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_raw_3 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_raw_4 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_unused_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_decompressor_xz (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_roundtrip_alone (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_roundtrip_chunks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_roundtrip_empty_chunks (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_roundtrip_raw (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_roundtrip_raw_empty (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_roundtrip_xz (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### CompressorDecompressorTestCase.test_simple_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_close (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BytesIO.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_closed (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_decompress_limited (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_fileno (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_init (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_init_bad_check (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_init_bad_filter_spec (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_init_mode (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_init_with_PathLike_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_init_with_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_init_with_preset_and_filters (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_issue44439 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__exit__'">`

### FileTestCase.test_iterator (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_peek_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC AttributeError '__exit__'">`

### FileTestCase.test_read (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_read1 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read1_0 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read1_10 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read1_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read1_multistream (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_0 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_read_10 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_bad_data (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_from_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_read_from_file_with_bytes_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_read_from_fileobj (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_read_from_fileobj_with_int_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_read_incomplete (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_multistream (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_read_multistream_buffer_size_aligned (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_multistream_trailing_junk (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_trailing_junk (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_read_truncated (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_readable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_readline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BytesIO.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_readlines (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BytesIO.__enter__() takes no arguments (1 given)'">`

### FileTestCase.test_seek_backward (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_backward_across_streams (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_backward_relative_to_end (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_forward (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_forward_across_streams (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_forward_relative_to_current (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_forward_relative_to_end (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_past_end (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seek_past_start (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_seekable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_tell (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_tell_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_writable (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_write (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_10 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_append (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_append_to_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_bad_args (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: module 'builtins' has no attribute 'UnsupportedOperation'">

### FileTestCase.test_write_to_file (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_to_file_with_bytes_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_to_fileobj (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_write_to_fileobj_with_int_name (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### FileTestCase.test_writelines (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### MiscellaneousTestCase.test__decode_filter_properties (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### MiscellaneousTestCase.test__encode_filter_properties (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### MiscellaneousTestCase.test_filter_properties_roundtrip (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### MiscellaneousTestCase.test_is_check_supported (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_bad_params (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_binary_modes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_encoding (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_encoding_error_handler (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_format_and_filters (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_newline (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_text_modes (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">

### OpenTestCase.test_with_pathlike_filename (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"ModuleNotFoundError: No module named 'test.support.import_helper'">
