# Triage report: `conv_sys_pins.jac`

- source: reference/cpython/Lib/test/test_sys.py
- guest leg: 0/19 marks
- pins: **19 passed** / 19 run (+78 quarantined of 97 extracted)

| pin | result | got |
|---|---|---|
| DisplayHookTest.test_lost_displayhook | PASS | |
| ActiveExceptionTests.test_exc_info_no_exception | PASS | |
| ActiveExceptionTests.test_sys_exception_no_exception | PASS | |
| ActiveExceptionTests.test_exc_info_with_exception_instance | PASS | |
| ActiveExceptionTests.test_exc_info_with_exception_type | PASS | |
| ActiveExceptionTests.test_sys_exception_with_exception_instance | PASS | |
| ActiveExceptionTests.test_sys_exception_with_exception_type | PASS | |
| SysModuleTest.test_getdefaultencoding | PASS | |
| SysModuleTest.test_switchinterval | PASS | |
| SysModuleTest.test_getrecursionlimit | PASS | |
| SysModuleTest.test_setrecursionlimit | PASS | |
| SysModuleTest.test_call_tracing | PASS | |
| SysModuleTest.test_refcount | PASS | |
| SysModuleTest.test_thread_info | PASS | |
| SysModuleTest.test_43581 | PASS | |
| SysModuleTest.test_sys_flags | PASS | |
| SysModuleTest.test_getfilesystemencoding | PASS | |
| SysModuleTest.test_no_duplicates_in_meta_path | PASS | |
| SysModuleTest.test_module_names | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| SysModuleTest.test_exit_codes_under_repl | decorator:support.requires_subprocess |
| SysModuleTest.test_dlopenflags | decorator:unittest.skipUnless |
| SysModuleTest.test_current_frames | decorator:threading_helper.requires_working_threading |
| SysModuleTest.test_current_exceptions | decorator:threading_helper.requires_working_threading |
| SysModuleTest.test_emscripten_info | decorator:unittest.skipUnless |
| SysModuleTest.test_subinterp_intern_dynamically_allocated | decorator:support.cpython_only |
| SysModuleTest.test_subinterp_intern_statically_allocated | decorator:support.cpython_only |
| SysModuleTest.test_subinterp_intern_singleton | decorator:support.cpython_only |
| SysModuleTest.test_ioencoding | decorator:support.requires_subprocess |
| SysModuleTest.test_ioencoding_nonascii | decorator:unittest.skipUnless |
| SysModuleTest.test_executable | decorator:unittest.skipIf |
| SysModuleTest.test_c_locale_surrogateescape | decorator:support.requires_subprocess |
| SysModuleTest.test_posix_locale_surrogateescape | decorator:support.requires_subprocess |
| SysModuleTest.test_getallocatedblocks | decorator:unittest.skipUnless |
| SysModuleTest.test_getandroidapilevel | decorator:unittest.skipUnless |
| SysModuleTest.test_sys_tracebacklimit | decorator:support.requires_subprocess |
| SysModuleTest.test__enablelegacywindowsfsencoding | decorator:unittest.skipUnless |
| SysModuleTest.test_orig_argv | decorator:support.requires_subprocess |
| SysModuleTest.test_getobjects | decorator:unittest.skipUnless |
| SysModuleTest.test_pystats | decorator:unittest.skipUnless |
| SysModuleTest.test_disable_gil_abi | decorator:unittest.skipUnless |
| TestRemoteExec.test_remote_exec_undecodable | decorator:unittest.skipUnless |
| ExceptHookTest.test_original_excepthook | self.assertEndsWith |
| ExceptHookTest.test_excepthook_bytes_filename | self.assertEndsWith |
| SysModuleTest.test_exit | self.assertStartsWith |
| SysModuleTest.test_recursionlimit_recovery | self.skipTest |
| SysModuleTest.test_setrecursionlimit_to_depth | unresolved-name:cm |
| SysModuleTest.test_clear_type_cache | uses-self.assertWarnsRegex |
| UnraisableHookTest.test_original_unraisablehook_err | self.assertEndsWith |
| TestRemoteExec.test_remote_exec | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_bytes | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_with_self_process | self.addCleanup |
| TestRemoteExec.test_remote_exec_raises_audit_event | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_with_exception | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_new_namespace_for_each_remote_exec | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_disabled_by_env | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_disabled_by_xoption | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_syntax_error | helper:_run_remote_exec_test(self.addCleanup) |
| TestRemoteExec.test_remote_exec_in_process_without_debug_fails_envvar | self.addCleanup |
| TestRemoteExec.test_remote_exec_in_process_without_debug_fails_xoption | self.addCleanup |
| SysModuleTest.test_getframe | self.skipTest |
| DisplayHookTest.test_original_displayhook | harness-error:SyntaxError: invalid syntax |
| DisplayHookTest.test_custom_displayhook | harness-error:SyntaxError: invalid syntax |
| DisplayHookTest.test_gh130163 | harness-error:SyntaxError: invalid syntax |
| ExceptHookTest.test_excepthook | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_getwindowsversion | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_getframemodulename | host-raised:AssertionError: ('assertEqual', 'unittest.case', '**main**') |
| SysModuleTest.test_attributes | harness-error:AttributeError: module '_thread' has no attribute 'start_joinable_thread' |
| SysModuleTest.test_intern | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_sys_flags_no_instantiation | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_sys_version_info_no_instantiation | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_sys_getwindowsversion_no_instantiation | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_implementation | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_debugmallocstats | harness-error:AttributeError: module '_thread' has no attribute 'start_joinable_thread' |
| SysModuleTest.test_is_gil_enabled | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_is_finalizing | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_issue20602 | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_sys_ignores_cleaning_up_user_data | harness-error:SyntaxError: invalid syntax |
| SysModuleTest.test_stdlib_dir | harness-error:SyntaxError: invalid syntax |
| UnraisableHookTest.test_original_unraisablehook | harness-error:SyntaxError: invalid syntax |
| UnraisableHookTest.test_original_unraisablehook_exception_qualname | harness-error:SyntaxError: invalid syntax |
| UnraisableHookTest.test_original_unraisablehook_wrong_type | harness-error:SyntaxError: invalid syntax |
| UnraisableHookTest.test_custom_unraisablehook | harness-error:SyntaxError: invalid syntax |
| UnraisableHookTest.test_custom_unraisablehook_fail | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_gc_head_size | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_errors | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_default | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_objecttypes | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_slots | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_pythontypes | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_asyncgen_hooks | harness-error:SyntaxError: invalid syntax |
| SizeofTest.test_changing_sys_stderr_and_removing_reference | harness-error:SyntaxError: invalid syntax |
| TestRemoteExec.test_remote_exec_invalid_pid | host-raised:AttributeError: module 'sys' has no attribute 'remote_exec' |
| TestRemoteExec.test_remote_exec_invalid_script | host-raised:AttributeError: module 'sys' has no attribute 'remote_exec' |
| TestRemoteExec.test_remote_exec_invalid_script_path | host-raised:AttributeError: module 'sys' has no attribute 'remote_exec' |
| TestSysJIT.test_jit_is_available | harness-error:SyntaxError: invalid syntax |
| TestSysJIT.test_jit_is_enabled | harness-error:SyntaxError: invalid syntax |
| TestSysJIT.test_jit_is_active | harness-error:SyntaxError: invalid syntax |
