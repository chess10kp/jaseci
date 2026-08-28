# Triage report: `conv_symtable_pins.jac`

- source: /home/jac/repos/jac-python/reference/cpython/Lib/test/test_symtable.py
- guest leg: 0/8 marks
- pins: **0 passed** / 8 run (+24 quarantined of 32 extracted)

| pin | result | got |
|---|---|---|
| SymtableTest.test_annotated | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SymtableTest.test_filename_correct | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SymtableTest.test_eval | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SymtableTest.test_single | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SymtableTest.test_exec | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SymtableTest.test_bytes | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| SymtableTest.test__symtable_refleak | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| CommandLineTest.test_stdin | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 8 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | CommandLineTest.test_stdin, SymtableTest.test__symtable_refleak, SymtableTest.test_annotated, SymtableTest.test_bytes, SymtableTest.test_eval, SymtableTest.test_exec, SymtableTest.test_filename_correct, SymtableTest.test_single |

## Quarantined at conversion

| test | reason |
|---|---|
| SymtableTest.test_type | unresolved-name:GenericAlias |
| SymtableTest.test_id | unresolved-name:GenericAlias |
| SymtableTest.test_optimized | unresolved-name:GenericAlias |
| SymtableTest.test_nested | unresolved-name:GenericAlias |
| SymtableTest.test_children | unresolved-name:GenericAlias |
| SymtableTest.test_lineno | unresolved-name:GenericAlias |
| SymtableTest.test_function_info | unresolved-name:GenericAlias |
| SymtableTest.test_globals | unresolved-name:GenericAlias |
| SymtableTest.test_nonlocal | unresolved-name:GenericAlias |
| SymtableTest.test_local | unresolved-name:GenericAlias |
| SymtableTest.test_free | unresolved-name:GenericAlias |
| SymtableTest.test_referenced | unresolved-name:GenericAlias |
| SymtableTest.test_parameters | unresolved-name:GenericAlias |
| SymtableTest.test_symbol_lookup | unresolved-name:GenericAlias |
| SymtableTest.test_namespaces | unresolved-name:GenericAlias |
| SymtableTest.test_assigned | unresolved-name:GenericAlias |
| SymtableTest.test_imported | unresolved-name:GenericAlias |
| SymtableTest.test_name | unresolved-name:GenericAlias |
| SymtableTest.test_class_get_methods | uses-self.assertWarnsRegex |
| SymtableTest.test_symtable_repr | unresolved-name:GenericAlias |
| SymtableTest.test_symbol_repr | unresolved-name:GenericAlias |
| SymtableTest.test_symtable_entry_repr | unresolved-name:GenericAlias |
| ComprehensionTests.test_loopvar_in_only_one_scope | helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(helper:get_identifiers_recursive(deepcopy-recursion)))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))))) |
| CommandLineTest.test_file | self.addCleanup |
