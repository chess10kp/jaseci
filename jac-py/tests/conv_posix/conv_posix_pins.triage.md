# Triage report: `conv_posix_pins.jac`

- source: reference/cpython/Lib/test/test_posix.py
- guest leg: 0/80 marks
- pins: **0 passed** / 80 run (+146 quarantined of 226 extracted)

| pin | result | got |
|---|---|---|
| TestPosixSpawn.test_returns_pid | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_returns_pid | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_no_such_executable | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_no_such_executable | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_specify_environment | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_specify_environment | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_none_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_none_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_empty_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_empty_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_resetids_explicit_default | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_resetids_explicit_default | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_resetids | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_resetids | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setpgroup | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setpgroup | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setpgroup_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setpgroup_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setpgroup_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setpgroup_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigmask | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigmask | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigmask_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigmask_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigdef | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigdef | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigdef_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigdef_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_scheduler_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_scheduler_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setscheduler_only_param | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setscheduler_only_param | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setscheduler_with_policy | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setscheduler_with_policy | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_open_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_open_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_close_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_close_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_dup2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_dup2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_returns_pid | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_no_such_executable | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_specify_environment | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_none_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_empty_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_resetids_explicit_default | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_resetids | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setpgroup | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setpgroup_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setpgroup_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigmask | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigmask_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigdef | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setsigdef_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_scheduler_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setscheduler_only_param | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_setscheduler_with_policy | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_open_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_close_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawn.test_dup2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_returns_pid | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_no_such_executable | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_specify_environment | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_none_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_empty_file_actions | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_resetids_explicit_default | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_resetids | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setpgroup | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setpgroup_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setpgroup_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigmask | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigmask_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigdef | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setsigdef_wrong_type | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_scheduler_allow_none | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setscheduler_only_param | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_setscheduler_with_policy | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_open_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_close_file | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |
| TestPosixSpawnP.test_dup2 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 40 | VM-CRASH | jaclang/compiler/backends/native/na_ir_gen/gc_debug.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/generics.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/globals.jac...   Compiling jaclang/compiler/backends/native/na_ir_gen/hash_core.jac...   Compiling jaclang/compiler | TestPosixSpawn.test_close_file, TestPosixSpawn.test_dup2, TestPosixSpawn.test_empty_file_actions, TestPosixSpawn.test_no_such_executable, TestPosixSpawn.test_none_file_actions, TestPosixSpawn.test_open_file, TestPosixSpawn.test_resetids, TestPosixSpawn.test_resetids_explicit_default, TestPosixSpawn.test_returns_pid, TestPosixSpawn.test_scheduler_allow_none, TestPosixSpawn.test_setpgroup, TestPosixSpawn.test_setpgroup_allow_none, TestPosixSpawn.test_setpgroup_wrong_type, TestPosixSpawn.test_setscheduler_only_param, TestPosixSpawn.test_setscheduler_with_policy, TestPosixSpawn.test_setsigdef, TestPosixSpawn.test_setsigdef_wrong_type, TestPosixSpawn.test_setsigmask, TestPosixSpawn.test_setsigmask_wrong_type, TestPosixSpawn.test_specify_environment, TestPosixSpawnP.test_close_file, TestPosixSpawnP.test_dup2, TestPosixSpawnP.test_empty_file_actions, TestPosixSpawnP.test_no_such_executable, TestPosixSpawnP.test_none_file_actions, TestPosixSpawnP.test_open_file, TestPosixSpawnP.test_resetids, TestPosixSpawnP.test_resetids_explicit_default, TestPosixSpawnP.test_returns_pid, TestPosixSpawnP.test_scheduler_allow_none, TestPosixSpawnP.test_setpgroup, TestPosixSpawnP.test_setpgroup_allow_none, TestPosixSpawnP.test_setpgroup_wrong_type, TestPosixSpawnP.test_setscheduler_only_param, TestPosixSpawnP.test_setscheduler_with_policy, TestPosixSpawnP.test_setsigdef, TestPosixSpawnP.test_setsigdef_wrong_type, TestPosixSpawnP.test_setsigmask, TestPosixSpawnP.test_setsigmask_wrong_type, TestPosixSpawnP.test_specify_environment |

## Quarantined at conversion

| test | reason |
|---|---|
| PosixTester.test_getresuid | decorator:unittest.skipUnless |
| PosixTester.test_getresgid | decorator:unittest.skipUnless |
| PosixTester.test_setresuid | decorator:unittest.skipUnless |
| PosixTester.test_setresuid_exception | decorator:unittest.skipUnless |
| PosixTester.test_setresgid | decorator:unittest.skipUnless |
| PosixTester.test_setresgid_exception | decorator:unittest.skipUnless |
| PosixTester.test_initgroups | decorator:unittest.skipUnless |
| PosixTester.test_statvfs | decorator:unittest.skipUnless |
| PosixTester.test_fstatvfs | decorator:unittest.skipUnless |
| PosixTester.test_ftruncate | decorator:unittest.skipUnless |
| PosixTester.test_truncate | decorator:unittest.skipUnless |
| PosixTester.test_fexecve | decorator:support.requires_fork |
| PosixTester.test_waitid | decorator:unittest.skipUnless |
| PosixTester.test_register_at_fork | decorator:support.requires_fork |
| PosixTester.test_lockf | decorator:unittest.skipUnless |
| PosixTester.test_pread | decorator:unittest.skipUnless |
| PosixTester.test_preadv | decorator:unittest.skipUnless |
| PosixTester.test_preadv_flags | decorator:unittest.skipUnless |
| PosixTester.test_preadv_overflow_32bits | decorator:unittest.skipUnless |
| PosixTester.test_pwrite | decorator:unittest.skipUnless |
| PosixTester.test_pwritev | decorator:unittest.skipUnless |
| PosixTester.test_pwritev_flags | decorator:unittest.skipUnless |
| PosixTester.test_pwritev_overflow_32bits | decorator:unittest.skipUnless |
| PosixTester.test_posix_fallocate | decorator:unittest.skipUnless |
| PosixTester.test_posix_fallocate_errno | decorator:unittest.skipUnless |
| PosixTester.test_posix_fadvise | decorator:unittest.skipUnless |
| PosixTester.test_posix_fadvise_errno | decorator:unittest.skipUnless |
| PosixTester.test_writev | decorator:unittest.skipUnless |
| PosixTester.test_writev_overflow_32bits | decorator:unittest.skipUnless |
| PosixTester.test_readv | decorator:unittest.skipUnless |
| PosixTester.test_readv_overflow_32bits | decorator:unittest.skipUnless |
| PosixTester.test_dup | decorator:unittest.skipUnless |
| PosixTester.test_confstr | decorator:unittest.skipUnless |
| PosixTester.test_sysconf | decorator:unittest.skipUnless |
| PosixTester.test_dup2 | decorator:unittest.skipUnless |
| PosixTester.test_oscloexec | decorator:support.requires_linux_version |
| PosixTester.test_osexlock | decorator:unittest.skipUnless |
| PosixTester.test_osshlock | decorator:unittest.skipUnless |
| PosixTester.test_fstat | decorator:unittest.skipUnless |
| PosixTester.test_stat_fd_zero_follow_symlinks | decorator:unittest.skipUnless |
| PosixTester.test_mkfifo | decorator:unittest.skipUnless |
| PosixTester.test_mknod | decorator:unittest.skipUnless |
| PosixTester.test_makedev | decorator:unittest.skipUnless |
| PosixTester.test_chown | decorator:unittest.skipIf |
| PosixTester.test_fchown | decorator:unittest.skipUnless |
| PosixTester.test_lchown | decorator:unittest.skipUnless |
| PosixTester.test_chdir | decorator:unittest.skipUnless |
| PosixTester.test_listdir_fd | decorator:unittest.skipUnless |
| PosixTester.test_access | decorator:unittest.skipUnless |
| PosixTester.test_umask | decorator:unittest.skipUnless |
| PosixTester.test_strerror | decorator:unittest.skipUnless |
| PosixTester.test_pipe | decorator:unittest.skipUnless |
| PosixTester.test_pipe2 | decorator:support.requires_linux_version |
| PosixTester.test_pipe2_c_limits | decorator:support.requires_linux_version |
| PosixTester.test_utime | decorator:unittest.skipUnless |
| PosixTester.test_lchmod_file | decorator:unittest.skipUnless |
| PosixTester.test_lchmod_dir | decorator:unittest.skipUnless |
| PosixTester.test_lchmod_file_symlink | decorator:unittest.skipUnless |
| PosixTester.test_lchmod_dir_symlink | decorator:unittest.skipUnless |
| PosixTester.test_chflags | decorator:unittest.skipUnless |
| PosixTester.test_lchflags_regular_file | decorator:unittest.skipUnless |
| PosixTester.test_lchflags_symlink | decorator:unittest.skipUnless |
| PosixTester.test_getcwd_long_pathnames | decorator:unittest.skipUnless |
| PosixTester.test_getgrouplist | decorator:unittest.skipUnless |
| PosixTester.test_sched_priority | decorator:unittest.skipUnless |
| PosixTester.test_sched_rr_get_interval | decorator:unittest.skipUnless |
| PosixTester.test_rtld_constants | decorator:unittest.skipIf |
| TestPosixDirFd.test_chown_dir_fd | decorator:unittest.skipIf |
| TestPosixDirFd.test_link_dir_fd | decorator:unittest.skipIf |
| PosixGroupsTester.test_initgroups | decorator:unittest.skipUnless |
| PosixGroupsTester.test_setgroups | decorator:unittest.skipUnless |
| _PosixSpawnMixin.test_scheduler_wrong_type | decorator:support.subTests |
| TestPosixWeaklinking.test_pwritev | skipped-on-host |
| TestPosixWeaklinking.test_stat | skipped-on-host |
| TestPosixWeaklinking.test_ptsname_r | skipped-on-host |
| TestPosixWeaklinking.test_access | skipped-on-host |
| TestPosixWeaklinking.test_chmod | skipped-on-host |
| TestPosixWeaklinking.test_chown | skipped-on-host |
| TestPosixWeaklinking.test_link | skipped-on-host |
| TestPosixWeaklinking.test_listdir_scandir | skipped-on-host |
| TestPosixWeaklinking.test_mkdir | skipped-on-host |
| TestPosixWeaklinking.test_mkfifo | skipped-on-host |
| TestPosixWeaklinking.test_mknod | skipped-on-host |
| TestPosixWeaklinking.test_rename_replace | skipped-on-host |
| TestPosixWeaklinking.test_unlink_rmdir | skipped-on-host |
| TestPosixWeaklinking.test_open | skipped-on-host |
| TestPosixWeaklinking.test_readlink | skipped-on-host |
| TestPosixWeaklinking.test_symlink | skipped-on-host |
| TestPosixWeaklinking.test_utime | skipped-on-host |
| NamespacesTests.test_unshare_setns | decorator:support.requires_linux_version |
| PosixTester.testNoArgFunctions | helper:setUp(self.enterContext) |
| PosixTester.test_utime_with_fd | helper:setUp(self.enterContext) |
| PosixTester.test_utime_nofollow_symlinks | helper:setUp(self.enterContext) |
| PosixTester.test_stat | helper:setUp(self.enterContext) |
| PosixTester.test_listdir | helper:setUp(self.enterContext) |
| PosixTester.test_listdir_default | helper:setUp(self.enterContext) |
| PosixTester.test_listdir_bytes | helper:setUp(self.enterContext) |
| PosixTester.test_listdir_bytes_like | helper:setUp(self.enterContext) |
| PosixTester.test_chmod_file | helper:setUp(self.enterContext) |
| PosixTester.test_chmod_dir | helper:setUp(self.enterContext) |
| PosixTester.test_fchmod_file | helper:setUp(self.enterContext) |
| PosixTester.test_chmod_file_symlink | helper:setUp(self.enterContext) |
| PosixTester.test_chmod_dir_symlink | helper:setUp(self.enterContext) |
| PosixTester.test_environ | helper:setUp(self.enterContext) |
| PosixTester.test_putenv | helper:setUp(self.enterContext) |
| PosixTester.test_getgroups | helper:setUp(self.enterContext) |
| PosixTester.test_cld_xxxx_constants | helper:setUp(self.enterContext) |
| PosixTester.test_sched_yield | helper:setUp(self.enterContext) |
| PosixTester.test_get_and_set_scheduler_and_param | helper:setUp(self.enterContext) |
| PosixTester.test_sched_param | helper:setUp(self.enterContext) |
| PosixTester.test_bug_140634 | helper:setUp(self.enterContext) |
| PosixTester.test_sched_getaffinity | helper:setUp(self.enterContext) |
| PosixTester.test_sched_setaffinity | helper:setUp(self.enterContext) |
| PosixTester.test_fs_holes | helper:setUp(self.enterContext) |
| PosixTester.test_path_error2 | helper:setUp(self.enterContext) |
| PosixTester.test_path_with_null_character | helper:setUp(self.enterContext) |
| PosixTester.test_path_with_null_byte | helper:setUp(self.enterContext) |
| PosixTester.test_pidfd_open | helper:setUp(self.enterContext) |
| PosixTester.test_link_follow_symlinks | helper:setUp(self.enterContext) |
| TestPosixDirFd.test_access_dir_fd | helper:prepare_file(decorated-helper) |
| TestPosixDirFd.test_chmod_dir_fd | helper:prepare_file(decorated-helper) |
| TestPosixDirFd.test_stat_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_utime_dir_fd | helper:prepare_file(decorated-helper) |
| TestPosixDirFd.test_mkdir_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_mknod_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_open_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_readlink_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_rename_dir_fd | helper:prepare_file(decorated-helper) |
| TestPosixDirFd.test_symlink_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_unlink_dir_fd | helper:prepare(decorated-helper) |
| TestPosixDirFd.test_mkfifo_dir_fd | helper:prepare(decorated-helper) |
| TestPosixSpawn.test_setsid | self.skipTest |
| TestPosixSpawnP.test_setsid | self.skipTest |
| TestPosixSpawn.test_multiple_file_actions | unresolved-name:**file** |
| TestPosixSpawnP.test_multiple_file_actions | unresolved-name:**file** |
| TestPosixSpawn.test_bad_file_actions | unresolved-name:**file** |
| TestPosixSpawnP.test_bad_file_actions | unresolved-name:**file** |
| TestPosixSpawn.test_setsid | self.skipTest |
| TestPosixSpawn.test_scheduler_wrong_type | unresolved-name:scheduler |
| TestPosixSpawn.test_multiple_file_actions | unresolved-name:**file** |
| TestPosixSpawn.test_bad_file_actions | unresolved-name:**file** |
| TestPosixSpawnP.test_posix_spawnp | unsupported-import:test.support.script_helper |
| TestPosixSpawnP.test_setsid | self.skipTest |
| TestPosixSpawnP.test_scheduler_wrong_type | unresolved-name:scheduler |
| TestPosixSpawnP.test_multiple_file_actions | unresolved-name:**file** |
| TestPosixSpawnP.test_bad_file_actions | unresolved-name:**file** |
