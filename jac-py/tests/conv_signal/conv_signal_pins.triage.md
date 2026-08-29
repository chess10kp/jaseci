# Triage report: `conv_signal_pins.jac`

- source: reference/cpython/Lib/test/test_signal.py
- guest leg: 0/14 marks
- pins: **0 passed** / 14 run (+43 quarantined of 57 extracted)

| pin | result | got |
|---|---|---|
| GenericTests.test_enums | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| GenericTests.test_functions_module_attr | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PosixTests.test_setting_signal_handler_to_none_raises_error | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PosixTests.test_strsignal | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PosixTests.test_valid_signals | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PosixTests.test_keyboard_interrupt_exit_code | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| WakeupFDTests.test_invalid_call | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| WakeupFDTests.test_set_wakeup_fd_result | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PendingSignalsTests.test_sigpending_empty | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PendingSignalsTests.test_sigtimedwait_negative_timeout | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PendingSignalsTests.test_pthread_sigmask_arguments | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| PendingSignalsTests.test_pthread_sigmask_valid_signals | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| RaiseSignalTest.test_sigint | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| RaiseSignalTest.test_handler | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 14 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | GenericTests.test_enums, GenericTests.test_functions_module_attr, PendingSignalsTests.test_pthread_sigmask_arguments, PendingSignalsTests.test_pthread_sigmask_valid_signals, PendingSignalsTests.test_sigpending_empty, PendingSignalsTests.test_sigtimedwait_negative_timeout, PosixTests.test_keyboard_interrupt_exit_code, PosixTests.test_setting_signal_handler_to_none_raises_error, PosixTests.test_strsignal, PosixTests.test_valid_signals, RaiseSignalTest.test_handler, RaiseSignalTest.test_sigint, WakeupFDTests.test_invalid_call, WakeupFDTests.test_set_wakeup_fd_result |

## Quarantined at conversion

| test | reason |
|---|---|
| WindowsSignalTests.test_valid_signals | skipped-on-host |
| WindowsSignalTests.test_issue9324 | skipped-on-host |
| WindowsSignalTests.test_keyboard_interrupt_exit_code | skipped-on-host |
| WakeupFDTests.test_invalid_socket | decorator:unittest.skipUnless |
| WakeupFDTests.test_set_wakeup_fd_socket_result | decorator:unittest.skipUnless |
| WakeupSignalTests.test_wakeup_write_error | decorator:unittest.skipIf |
| WakeupSocketSignalTests.test_socket | decorator:unittest.skipIf |
| WakeupSocketSignalTests.test_send_error | decorator:unittest.skipIf |
| WakeupSocketSignalTests.test_warn_on_full_buffer | decorator:unittest.skipIf |
| SiginterruptTest.test_siginterrupt_off | decorator:support.requires_resource |
| ItimerTest.test_itimer_virtual | decorator:unittest.skipIf |
| PendingSignalsTests.test_pthread_kill | decorator:threading_helper.requires_working_threading |
| PendingSignalsTests.test_sigwait_thread | decorator:threading_helper.requires_working_threading |
| PendingSignalsTests.test_pthread_sigmask | decorator:threading_helper.requires_working_threading |
| PendingSignalsTests.test_pthread_kill_main_thread | decorator:threading_helper.requires_working_threading |
| StressTest.test_stress_modifying_handlers | decorator:support.requires_gil_enabled |
| RaiseSignalTest.test_invalid_argument | skipped-on-host |
| PidfdSignalTest.test_pidfd_send_signal | skipped-on-host |
| PosixTests.test_out_of_range_signal_number_raises_error | uses-self.trivial_signal_handler |
| PosixTests.test_getsignal | uses-self.trivial_signal_handler |
| PosixTests.test_no_repr_is_called_on_signal_handler | uses-self.trivial_signal_handler |
| PosixTests.test_interprocess_signal | unsupported-import:test.support.script_helper |
| WakeupFDTests.test_set_wakeup_fd_blocking | unresolved-name:cm |
| WakeupSignalTests.test_wakeup_fd_early | helper:check_wakeup(decorated-helper) |
| WakeupSignalTests.test_wakeup_fd_during | helper:check_wakeup(decorated-helper) |
| WakeupSignalTests.test_signum | helper:check_wakeup(decorated-helper) |
| WakeupSignalTests.test_pending | helper:check_wakeup(decorated-helper) |
| SiginterruptTest.test_without_siginterrupt | unsupported-import:test.support.script_helper |
| SiginterruptTest.test_siginterrupt_on | unsupported-import:test.support.script_helper |
| ItimerTest.test_itimer_exc | uses-self.sig_alrm |
| ItimerTest.test_itimer_real | uses-self.sig_alrm |
| ItimerTest.test_itimer_prof | uses-self.sig_alrm |
| ItimerTest.test_setitimer_tiny | uses-self.sig_alrm |
| PendingSignalsTests.test_sigpending | unsupported-import:test.support.script_helper |
| PendingSignalsTests.test_sigwait | helper:wait_helper(decorated-helper) |
| PendingSignalsTests.test_sigwaitinfo | helper:wait_helper(decorated-helper) |
| PendingSignalsTests.test_sigtimedwait | helper:wait_helper(decorated-helper) |
| PendingSignalsTests.test_sigtimedwait_poll | helper:wait_helper(decorated-helper) |
| PendingSignalsTests.test_sigtimedwait_timeout | helper:wait_helper(decorated-helper) |
| StressTest.test_stress_delivery_dependent | helper:decide_itimer_count(self.skipTest) |
| StressTest.test_stress_delivery_simultaneous | helper:decide_itimer_count(self.skipTest) |
| RaiseSignalTest.test__thread_interrupt_main | unsupported-import:test.support.script_helper |
| WakeupFDTests.test_invalid_fd | harness-error:SyntaxError: invalid syntax |
