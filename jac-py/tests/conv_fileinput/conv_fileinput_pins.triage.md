# Triage report: `conv_fileinput_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_fileinput.py
- guest leg: 0/37 marks
- pins: **7 passed** / 37 run (+20 quarantined of 57 extracted)

| pin | result | got |
|---|---|---|
| BufferSizesTests.test_buffer_sizes | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_zero_byte_files | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_files_that_dont_end_with_newline | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_fileno | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_invalid_opening_mode | PASS | |
| FileInputTests.test_stdin_binary_mode | GUEST-WRONG-OUTPUT | RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'"> |
| FileInputTests.test_detached_stdin_binary_mode | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'spam, bacon, sausage, and spam\'], [b\'spam, bacon, sausage, and spam\'])"'> |
| FileInputTests.test_file_opening_hook | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_readline | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileInputTests.test_readline_binary_mode | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| FileInputTests.test_inplace_binary_write_mode | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_inplace_encoding_errors | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_file_hook_backward_compatibility | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_context_manager | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_close_on_exception | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_empty_files_list_specified_to_constructor | PASS | |
| FileInputTests.test_nextfile_oserror_deleting_backup | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_readline_os_fstat_raises_OSError | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_readline_os_chmod_raises_OSError | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_readline_buffering | PASS | |
| FileInputTests.test_iteration_buffering | PASS | |
| FileInputTests.test_pathlike_file | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| FileInputTests.test_pathlike_file_inplace | GUEST-WRONG-OUTPUT | `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>` |
| Test_fileinput_input.test_state_is_not_None_and_state_file_is_None | PASS | |
| Test_fileinput_input.test_state_is_None | PASS | |
| Test_fileinput_close.test_state_is_None | PASS | |
| Test_fileinput_close.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_nextfile.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_filename.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_lineno.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_filelineno.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_fileno.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_isfirstline.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_fileinput_isstdin.test_state_is_not_None | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC TypeError 'object does not support item assignment'"> |
| Test_hook_encoded.test | GUEST-WRONG-OUTPUT | GOT<'ORACLE_EXC TypeError "open() argument \'mode\' must be str, not object"'> |
| Test_hook_encoded.test_errors | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |
| Test_hook_encoded.test_modes | GUEST-WRONG-OUTPUT | `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">` |

## Quarantined at conversion

| test | reason |
|---|---|
| Test_hook_compressed.test_gz_ext_fake | decorator:unittest.skipUnless |
| Test_hook_compressed.test_gz_with_encoding_fake | decorator:unittest.skipUnless |
| Test_hook_compressed.test_bz2_ext_fake | decorator:unittest.skipUnless |
| FileInputTests.test_fileno_when_ValueError_raised | uses-self.__call__ |
| Test_fileinput_input.test_state_is_not_None_and_state_file_is_not_None | unresolved-name:cm |
| Test_fileinput_nextfile.test_state_is_None | unresolved-name:cm |
| Test_fileinput_filename.test_state_is_None | unresolved-name:cm |
| Test_fileinput_lineno.test_state_is_None | unresolved-name:cm |
| Test_fileinput_filelineno.test_state_is_None | unresolved-name:cm |
| Test_fileinput_fileno.test_state_is_None | unresolved-name:cm |
| Test_fileinput_isfirstline.test_state_is_None | unresolved-name:cm |
| Test_fileinput_isstdin.test_state_is_None | unresolved-name:cm |
| Test_hook_compressed.test_empty_string | helper:do_test_use_builtin_open_text(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_no_ext | helper:do_test_use_builtin_open_text(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_blah_ext | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_gz_ext_builtin | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_bz2_ext_builtin | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_binary_mode_encoding | helper:do_test_use_builtin_open_binary(helper:replace_builtin_open(decorated-helper)) |
| Test_hook_compressed.test_text_mode_encoding | helper:do_test_use_builtin_open_text(helper:replace_builtin_open(decorated-helper)) |
| MiscTest.test_all | host-raised:NameError: name 'self' is not defined |

## Expected vs got

### BufferSizesTests.test_buffer_sizes (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_close_on_exception (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_context_manager (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_detached_stdin_binary_mode (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC AssertionError "(\'assertEqual\', [b\'spam, bacon, sausage, and spam\'], [b\'spam, bacon, sausage, and spam\'])"'>

### FileInputTests.test_file_hook_backward_compatibility (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_file_opening_hook (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_fileno (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_files_that_dont_end_with_newline (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_inplace_binary_write_mode (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_inplace_encoding_errors (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_nextfile_oserror_deleting_backup (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_pathlike_file (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_pathlike_file_inplace (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_readline (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileInputTests.test_readline_binary_mode (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### FileInputTests.test_readline_os_chmod_raises_OSError (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_readline_os_fstat_raises_OSError (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### FileInputTests.test_stdin_binary_mode (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: RUN<"ImportError: cannot import name 'nlargest' from '<unknown>'">

### FileInputTests.test_zero_byte_files (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `RUN<'TypeError: EnumCheck.__init_subclass__() takes no keyword arguments'>`

### Test_fileinput_close.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_filelineno.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_filename.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_fileno.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_isfirstline.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_isstdin.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_lineno.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_fileinput_nextfile.test_state_is_not_None (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC TypeError 'object does not support item assignment'">

### Test_hook_encoded.test (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: GOT<'ORACLE_EXC TypeError "open() argument \'mode\' must be str, not object"'>

### Test_hook_encoded.test_errors (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`

### Test_hook_encoded.test_modes (GUEST-WRONG-OUTPUT)
- expected: host oracle = `ok`
- got: `GOT<"ORACLE_EXC TypeError 'BufferedWriter.__enter__() takes no arguments (1 given)'">`
