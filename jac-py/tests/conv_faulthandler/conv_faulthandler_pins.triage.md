# Triage report: `conv_faulthandler_pins.jac`

- source: reference/cpython/Lib/test/test_faulthandler.py (CPython 3.14.6)
- conversion: 48 extracted -> 4 pinned / 44 quarantined
- guest leg: NOT RUN locally (compute-gated box; diff_runner is CI-gated on the branch)

## Pins (host oracle captured; runtime unverified locally - CI gates it)

| pin | status |
|---|---|
| FaultHandlerTests.test_is_enabled | pinned |
| FaultHandlerTests.test_disabled_by_default | pinned |
| FaultHandlerTests.test_sys_xoptions | pinned |
| FaultHandlerTests.test_env_var | pinned |

Note: three of the four pins drive subprocess-based checks of interpreter
startup flags (`-X faulthandler`, `PYTHONFAULTHANDLER`); they replay through
`p2_libtest_run_snippet` and depend on guest subprocess support, not on
`jacpython/faulthandler.jac`. `test_is_enabled` exercises the facade directly.

## Quarantine buckets (44)

- 19 unsupported-import:test.support - subprocess/crash harness lives in test.support
- 13 decorator - unittest.skipIf/skipUnless, support.skip_if_sanitizer,
  requires_resource, threading_helper.requires_working_threading
- 7 decorated-helper - check_register x4, check_fatal_error_func x2,
  check_stderr_none x1
- 1 host-raised - host oracle raised during capture (test_dump_c_stack_file)
- 4 remaining decorator/helper variants (see conversion.json for exact list)

## Facade

`jac-py/jacpython/faulthandler.jac` ports Modules/faulthandler.c's Python
surface (enable/disable/is_enabled/dump_traceback/dump_c_stack/
dump_traceback_later/cancel_dump_traceback_later/register/unregister plus the
_read_null/_sigsegv/_sigfpe/_sigabrt/_fatal_error_c_thread crash primitives).
Divergences are documented in the file header (guest-level signal handlers via
host `signal`, `_stack_overflow` hits RecursionError instead of a guard-page
SIGSEGV, MS_WINDOWS `_raise_exception` out of scope).

Re-diff command once CI lands:
`.venv/bin/python jac-py/tools/diff_runner.py jac-py/tests/conv_faulthandler/conv_faulthandler_pins.jac`
