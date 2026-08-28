# Triage report: `conv_faulthandler_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_faulthandler.py
- guest leg: 0/4 marks
- pins: **0 passed** / 4 run (+44 quarantined of 48 extracted)

| pin | result | got |
|---|---|---|
| FaultHandlerTests.test_is_enabled | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FaultHandlerTests.test_disabled_by_default | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FaultHandlerTests.test_sys_xoptions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FaultHandlerTests.test_env_var | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 4 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | FaultHandlerTests.test_disabled_by_default, FaultHandlerTests.test_env_var, FaultHandlerTests.test_is_enabled, FaultHandlerTests.test_sys_xoptions |

## Quarantined at conversion

| test | reason |
|---|---|
| FaultHandlerTests.test_read_null | decorator:unittest.skipIf |
| FaultHandlerTests.test_sigabrt | decorator:support.skip_if_sanitizer |
| FaultHandlerTests.test_sigfpe | decorator:unittest.skipIf |
| FaultHandlerTests.test_sigbus | decorator:unittest.skipIf |
| FaultHandlerTests.test_sigill | decorator:unittest.skipIf |
| FaultHandlerTests.test_stack_overflow | decorator:unittest.skipIf |
| FaultHandlerTests.test_enable_fd | decorator:unittest.skipIf |
| FaultHandlerTests.test_dump_traceback_fd | decorator:unittest.skipIf |
| FaultHandlerTests.test_dump_traceback_later_fd | decorator:unittest.skipIf |
| FaultHandlerTests.test_dump_traceback_later_twice | decorator:support.requires_resource |
| FaultHandlerTests.test_register_fd | decorator:unittest.skipIf |
| FaultHandlerTests.test_register_chain | decorator:support.skip_if_sanitizer |
| FaultHandlerTests.test_raise_exception | decorator:unittest.skipUnless |
| FaultHandlerTests.test_ignore_exception | decorator:unittest.skipUnless |
| FaultHandlerTests.test_raise_nonfatal_exception | decorator:unittest.skipUnless |
| FaultHandlerTests.test_disable_windows_exc_handler | decorator:unittest.skipUnless |
| FaultHandlerTests.test_free_threaded_dump_traceback | decorator:threading_helper.requires_working_threading |
| FaultHandlerTests.test_sigsegv | unsupported-import:test.support |
| FaultHandlerTests.test_gc | unsupported-import:test.support |
| FaultHandlerTests.test_fatal_error_c_thread | unsupported-import:test.support |
| FaultHandlerTests.test_fatal_error | helper:check_fatal_error_func(decorated-helper) |
| FaultHandlerTests.test_fatal_error_without_gil | helper:check_fatal_error_func(decorated-helper) |
| FaultHandlerTests.test_gil_released | unsupported-import:test.support |
| FaultHandlerTests.test_enable_file | unsupported-import:test.support |
| FaultHandlerTests.test_enable_single_thread | unsupported-import:test.support |
| FaultHandlerTests.test_disable | unsupported-import:test.support |
| FaultHandlerTests.test_dump_ext_modules | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_file | unsupported-import:test.support |
| FaultHandlerTests.test_truncate | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_threads | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_threads_file | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_later | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_later_repeat | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_later_cancel | unsupported-import:test.support |
| FaultHandlerTests.test_dump_traceback_later_file | unsupported-import:test.support |
| FaultHandlerTests.test_register | helper:check_register(decorated-helper) |
| FaultHandlerTests.test_unregister | helper:check_register(decorated-helper) |
| FaultHandlerTests.test_register_file | helper:check_register(decorated-helper) |
| FaultHandlerTests.test_register_threads | helper:check_register(decorated-helper) |
| FaultHandlerTests.test_stderr_None | helper:check_stderr_none(decorated-helper) |
| FaultHandlerTests.test_cancel_later_without_dump_traceback_later | unsupported-import:test.support |
| FaultHandlerTests.test_dump_c_stack | unsupported-import:test.support |
| FaultHandlerTests.test_dump_c_stack_file | host-raised:AttributeError: module 'faulthandler' has no attribute 'dump_c_stack' |
