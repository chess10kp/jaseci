# Triage report: `conv_frame_pins.jac`

- source: reference/cpython/Lib/test/test_frame.py
- guest leg: 0/14 marks
- pins: **0 passed** / 14 run (+33 quarantined of 47 extracted)

| pin | result | got |
|---|---|---|
| ClearTest.test_clear_does_not_clear_specials | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ClearTest.test_clear_executing | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| ClearTest.test_lineno_with_tracing | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FrameAttrsTest.test_clear_locals | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FrameAttrsTest.test_locals_clear_locals | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| FrameAttrsTest.test_f_lineno_del_segfault | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_closure_with_inline_comprehension | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_as_number | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_non_string_key | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_copy | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_update_with_self | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_repr | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_proxy_key_unhashables | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestFrameLocals.test_overwrite_locals | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 14 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | ClearTest.test_clear_does_not_clear_specials, ClearTest.test_clear_executing, ClearTest.test_lineno_with_tracing, FrameAttrsTest.test_clear_locals, FrameAttrsTest.test_f_lineno_del_segfault, FrameAttrsTest.test_locals_clear_locals, TestFrameLocals.test_as_number, TestFrameLocals.test_closure_with_inline_comprehension, TestFrameLocals.test_copy, TestFrameLocals.test_non_string_key, TestFrameLocals.test_overwrite_locals, TestFrameLocals.test_proxy_key_unhashables, TestFrameLocals.test_repr, TestFrameLocals.test_update_with_self |

## Quarantined at conversion

| test | reason |
|---|---|
| FrameLocalsProxyMappingTests.test_constructor | skipped-on-host |
| FrameLocalsProxyMappingTests.test_write | skipped-on-host |
| FrameLocalsProxyMappingTests.test_popitem | skipped-on-host |
| FrameLocalsProxyMappingTests.test_pop | skipped-on-host |
| FrameLocalsProxyMappingTests.test_clear | skipped-on-host |
| FrameLocalsProxyMappingTests.test_fromkeys | skipped-on-host |
| FrameLocalsProxyMappingTests.test_update | skipped-on-host |
| FrameLocalsProxyMappingTests.test_eq | skipped-on-host |
| TestIncompleteFrameAreInvisible.test_sneaky_frame_object_teardown | decorator:threading_helper.requires_working_threading |
| ReprTest.test_repr | unresolved-name:**file** |
| TestFrameLocals.test_is_mapping | uses-self.assertEqual |
| FrameLocalsProxyMappingTests.test_getitem | uses-self._full_mapping |
| FrameLocalsProxyMappingTests.test_copy | uses-self._empty_mapping |
| TestFrameCApi.test_basic | unresolved-name:**builtins** |
| TestIncompleteFrameAreInvisible.test_issue95818 | unsupported-import:test.support.script_helper |
| ClearTest.test_clear_locals | harness-error:SyntaxError: invalid syntax |
| ClearTest.test_clear_locals_after_f_locals_access | harness-error:SyntaxError: invalid syntax |
| ClearTest.test_clear_generator | host-raised:AssertionError: assertRaises: did not raise |
| ClearTest.test_clear_executing_generator | host-raised:AssertionError: assertRaises: did not raise |
| ClearTest.test_clear_refcycles | harness-error:SyntaxError: invalid syntax |
| FrameAttrsTest.test_f_generator | host-raised:AttributeError: 'frame' object has no attribute 'f_generator' |
| TestFrameLocals.test_scope | host-raised:AssertionError: ('assertEqual', 1, 2) |
| TestFrameLocals.test_closure | host-raised:AssertionError: ('assertEqual', 1, 2) |
| TestFrameLocals.test_as_dict | host-raised:AssertionError: ('assertEqual', 2, 4) |
| TestFrameLocals.test_write_with_hidden | host-raised:UnboundLocalError: cannot access local variable 'b' where it is not associated with a value |
| TestFrameLocals.test_local_objects | host-raised:AssertionError: ('assertEqual', <object object at 0x7fe956d78600>, 'a.b.c') |
| TestFrameLocals.test_delete | host-raised:AssertionError: assertRaises: did not raise |
| TestFrameLocals.test_sizeof | harness-error:SyntaxError: invalid syntax |
| TestFrameLocals.test_unsupport | host-raised:AssertionError: assertRaises: did not raise |
| TestFrameLocals.test_proxy_key_stringlikes_overwrite | host-raised:AssertionError: ('assertEqual', dict_keys(['obj', 'x']), ['obj', 'x', 'proxy']) |
| TestFrameLocals.test_proxy_key_stringlikes_ftrst_write | host-raised:UnboundLocalError: cannot access local variable 'x' where it is not associated with a value |
| TestFrameLocals.test_constructor | host-raised:AssertionError: ('assertEqual', 'dict', 'FrameLocalsProxy') |
| TestIncompleteFrameAreInvisible.test_entry_frames_are_invisible_during_teardown | harness-error:SyntaxError: invalid syntax |
