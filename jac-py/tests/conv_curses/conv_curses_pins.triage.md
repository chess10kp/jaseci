# Triage report: `conv_curses_pins.jac`

- source: reference/cpython/Lib/test/test_curses.py
- guest leg: 0/7 marks
- pins: **0 passed** / 7 run (+74 quarantined of 81 extracted)

| pin | result | got |
|---|---|---|
| MiscTests.test_update_lines_cols | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |
| MiscTests.test_has_extended_color_support | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |
| TestAscii.test_ctypes | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |
| TestAscii.test_ascii | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |
| TestAscii.test_ctrl | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |
| TestAscii.test_alt | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |
| TestAscii.test_unctrl | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 7 | VM-CRASH | `home/jac/repos/jac-python/jac note: /home/jac/repos/jac-python/jac-py/jacpython/_jsonmodule.jac preferred native but did not lower; compiled in the server codespace (error[E1055]: No matching overload found for method "__add__" with the given arguments) [ERROR] Error: error[E1055]: No matching overl` | MiscTests.test_has_extended_color_support, MiscTests.test_update_lines_cols, TestAscii.test_alt, TestAscii.test_ascii, TestAscii.test_ctrl, TestAscii.test_ctypes, TestAscii.test_unctrl |

## Quarantined at conversion

| test | reason |
|---|---|
| TestCurses.test_filter | unsupported-import:test.support |
| TestCurses.test_use_env | unsupported-import:test.support |
| TestCurses.test_create_windows | unsupported-import:test.support |
| TestCurses.test_subwindows_references | unsupported-import:test.support |
| TestCurses.test_move_cursor | unsupported-import:test.support |
| TestCurses.test_refresh_control | unsupported-import:test.support |
| TestCurses.test_output_character | unsupported-import:test.support |
| TestCurses.test_output_string | unsupported-import:test.support |
| TestCurses.test_output_string_embedded_null_chars | unsupported-import:test.support |
| TestCurses.test_read_from_window | unsupported-import:test.support |
| TestCurses.test_getch | unsupported-import:test.support |
| TestCurses.test_getstr | unsupported-import:test.support |
| TestCurses.test_clear | unsupported-import:test.support |
| TestCurses.test_insert_delete | unsupported-import:test.support |
| TestCurses.test_scroll | unsupported-import:test.support |
| TestCurses.test_attributes | unsupported-import:test.support |
| TestCurses.test_chgat | unsupported-import:test.support |
| TestCurses.test_background | unsupported-import:test.support |
| TestCurses.test_overlay | unsupported-import:test.support |
| TestCurses.test_refresh | unsupported-import:test.support |
| TestCurses.test_resize | unsupported-import:test.support |
| TestCurses.test_enclose | unsupported-import:test.support |
| TestCurses.test_putwin | unsupported-import:test.support |
| TestCurses.test_borders_and_lines | unsupported-import:test.support |
| TestCurses.test_unctrl | unsupported-import:test.support |
| TestCurses.test_endwin | self.skipTest |
| TestCurses.test_terminfo | unsupported-import:test.support |
| TestCurses.test_misc_module_funcs | unsupported-import:test.support |
| TestCurses.test_env_queries | unsupported-import:test.support |
| TestCurses.test_output_options | unsupported-import:test.support |
| TestCurses.test_input_options | unsupported-import:test.support |
| TestCurses.test_typeahead | unsupported-import:test.support |
| TestCurses.test_prog_mode | self.skipTest |
| TestCurses.test_beep | self.skipTest |
| TestCurses.test_flash | self.skipTest |
| TestCurses.test_curs_set | unsupported-import:test.support |
| TestCurses.test_escdelay | unsupported-import:test.support |
| TestCurses.test_tabsize | unsupported-import:test.support |
| TestCurses.test_getsyx | unsupported-import:test.support |
| TestCurses.test_has_colors | unsupported-import:test.support |
| TestCurses.test_start_color | self.skipTest |
| TestCurses.test_color_content | unsupported-import:test.support |
| TestCurses.test_init_color | self.skipTest |
| TestCurses.test_pair_content | unsupported-import:test.support |
| TestCurses.test_init_pair | unsupported-import:test.support |
| TestCurses.test_color_attrs | unsupported-import:test.support |
| TestCurses.test_use_default_colors | self.skipTest |
| TestCurses.test_assume_default_colors | self.skipTest |
| TestCurses.test_keyname | unsupported-import:test.support |
| TestCurses.test_has_key | unsupported-import:test.support |
| TestCurses.test_getmouse | self.skipTest |
| TestCurses.test_userptr_without_set | unsupported-import:test.support |
| TestCurses.test_userptr_memory_leak | unsupported-import:test.support |
| TestCurses.test_userptr_segfault | unsupported-import:test.support |
| TestCurses.test_disallow_instantiation | unsupported-import:test.support |
| TestCurses.test_is_term_resized | unsupported-import:test.support |
| TestCurses.test_resize_term | unsupported-import:test.support |
| TestCurses.test_resizeterm | unsupported-import:test.support |
| TestCurses.test_ungetch | unsupported-import:test.support |
| TestCurses.test_issue6243 | unsupported-import:test.support |
| TestCurses.test_unget_wch | unsupported-import:test.support |
| TestCurses.test_encoding | unsupported-import:test.support |
| TestCurses.test_issue21088 | unsupported-import:test.support |
| TestCurses.test_issue13051 | unsupported-import:test.support |
| MiscTests.test_ncurses_version | unsupported-import:test.support |
| TestAscii.test_controlnames | self.skipTest |
| TextboxTest.test_init | self.skipTest |
| TextboxTest.test_insert | self.skipTest |
| TextboxTest.test_delete | self.skipTest |
| TextboxTest.test_move_left | self.skipTest |
| TextboxTest.test_move_right | self.skipTest |
| TextboxTest.test_move_left_and_right | self.skipTest |
| TextboxTest.test_move_up | self.skipTest |
| TextboxTest.test_move_down | self.skipTest |
