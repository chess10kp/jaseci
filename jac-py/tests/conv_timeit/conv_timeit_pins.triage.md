# Triage report: `conv_timeit_pins.jac`

- source: reference/cpython/Lib/test/test_timeit.py
- guest leg: 0/7 marks
- pins: **7 passed** / 7 run (+34 quarantined of 41 extracted)

| pin | result | got |
|---|---|---|
| TestTimeit.test_reindent_empty | PASS | |
| TestTimeit.test_reindent_single | PASS | |
| TestTimeit.test_reindent_multi_empty | PASS | |
| TestTimeit.test_reindent_multi | PASS | |
| TestTimeit.test_timer_invalid_stmt | PASS | |
| TestTimeit.test_timer_invalid_setup | PASS | |
| TestTimeit.test_timer_empty_stmt | PASS | |

## Quarantined at conversion

| test | reason |
|---|---|
| TestTimeit.test_main_help | decorator:unittest.skipIf |
| TestTimeit.test_timeit_zero_iters | helper:timeit(uses-self.fake_timer) |
| TestTimeit.test_timeit_few_iters | helper:timeit(uses-self.fake_timer) |
| TestTimeit.test_timeit_callable_stmt | helper:timeit(uses-self.fake_timer) |
| TestTimeit.test_timeit_callable_setup | helper:timeit(uses-self.fake_timer) |
| TestTimeit.test_timeit_callable_stmt_and_setup | helper:timeit(uses-self.fake_timer) |
| TestTimeit.test_timeit_function_zero_iters | uses-self.fake_stmt |
| TestTimeit.test_timeit_globals_args | unresolved-name:FakeTimer |
| TestTimeit.test_repeat_zero_reps | helper:repeat(uses-self.fake_timer) |
| TestTimeit.test_repeat_zero_iters | helper:repeat(uses-self.fake_timer) |
| TestTimeit.test_repeat_few_reps_and_iters | helper:repeat(uses-self.fake_timer) |
| TestTimeit.test_repeat_callable_stmt | helper:repeat(uses-self.fake_timer) |
| TestTimeit.test_repeat_callable_setup | helper:repeat(uses-self.fake_timer) |
| TestTimeit.test_repeat_callable_stmt_and_setup | helper:repeat(uses-self.fake_timer) |
| TestTimeit.test_repeat_function_zero_reps | uses-self.fake_stmt |
| TestTimeit.test_repeat_function_zero_iters | uses-self.fake_stmt |
| TestTimeit.test_print_exc | helper:assert_exc_string(self.assertStartsWith) |
| TestTimeit.test_main_bad_switch | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_seconds | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_milliseconds | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_microseconds | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_fixed_iters | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_setup | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_multiple_setups | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_fixed_reps | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_negative_reps | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_verbose | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_very_verbose | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_with_time_unit | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_exception | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_main_exception_fixed_reps | helper:run_main(uses-self.fake_stmt) |
| TestTimeit.test_autorange | helper:autorange(uses-self.fake_stmt) |
| TestTimeit.test_autorange_second | helper:autorange(uses-self.fake_stmt) |
| TestTimeit.test_autorange_with_callback | helper:autorange(uses-self.fake_stmt) |
