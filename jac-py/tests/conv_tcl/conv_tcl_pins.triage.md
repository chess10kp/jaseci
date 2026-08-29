# Triage report: `conv_tcl_pins.jac`

- source: reference/cpython/Lib/test/test_tcl.py
- guest leg: 0/35 marks (deferred CI)
- pins: **0 passed** / 35 run (+14 quarantined of 49 extracted)

| pin | result | got |
|---|---|---|
| TclTest.testEval | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_eval_null_in_result | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_eval_surrogates_in_result | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testEvalException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testEvalException2 | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_eval_returns_tcl_obj | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testCall | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_call_passing_null | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testCallException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testCallException2 | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_call_returns_tcl_obj | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testSetVar | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_setvar_passing_null | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testSetVarArray | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testGetVar | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testGetVarArray | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testGetVarException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testGetVarArrayException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_getvar_returns_tcl_obj | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testUnsetVar | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testUnsetVarArray | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testUnsetVarException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_getdouble | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_getboolean | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testEvalFileException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.testPackageRequireException | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_exprstring | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_exprdouble | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_exprlong | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_exprboolean | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_booleans | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_expr_bignum | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_passing_tcl_obj | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_splitdict | VM-CRASH | runtime unverified locally - CI gates diff_runner |
| TclTest.test_join | VM-CRASH | runtime unverified locally - CI gates diff_runner |

## Shared failure signatures

These pins fail with a byte-identical detail, which usually means
one shared root cause (for example an import-time error in the
guest module) instead of per-test defects.

| count | classification | got | pins |
|---|---|---|---|
| 35 | VM-CRASH | runtime unverified locally - CI gates diff_runner | TclTest.testCall, TclTest.testCallException, TclTest.testCallException2, TclTest.testEval, TclTest.testEvalException, TclTest.testEvalException2, TclTest.testEvalFileException, TclTest.testGetVar, TclTest.testGetVarArray, TclTest.testGetVarArrayException, TclTest.testGetVarException, TclTest.testPackageRequireException, TclTest.testSetVar, TclTest.testSetVarArray, TclTest.testUnsetVar, TclTest.testUnsetVarArray, TclTest.testUnsetVarException, TclTest.test_booleans, TclTest.test_call_passing_null, TclTest.test_call_returns_tcl_obj, TclTest.test_eval_null_in_result, TclTest.test_eval_returns_tcl_obj, TclTest.test_eval_surrogates_in_result, TclTest.test_expr_bignum, TclTest.test_exprboolean, TclTest.test_exprdouble, TclTest.test_exprlong, TclTest.test_exprstring, TclTest.test_getboolean, TclTest.test_getdouble, TclTest.test_getvar_returns_tcl_obj, TclTest.test_join, TclTest.test_passing_tcl_obj, TclTest.test_setvar_passing_null, TclTest.test_splitdict |

## Quarantined at conversion

| test | reason |
|---|---|
| TclTest.testLoadWithUNC | skipped-on-host |
| BigmemTclTest.test_huge_string_call | decorator:unittest.skipUnless |
| BigmemTclTest.test_huge_string_builtins | decorator:unittest.skipUnless |
| BigmemTclTest.test_huge_string_builtins2 | decorator:unittest.skipUnless |
| TclTest.test_passing_values | uses-self.passValue |
| TclTest.test_user_command | uses-self.assertEqual |
| TkinterTest.testFlattenLen | harness-error:SyntaxError: invalid syntax |
| TclTest.test_getint | harness-error:SyntaxError: invalid syntax |
| TclTest.testEvalFile | harness-error:SyntaxError: invalid syntax |
| TclTest.test_evalfile_null_in_result | harness-error:SyntaxError: invalid syntax |
| TclTest.test_evalfile_surrogates_in_result | harness-error:SyntaxError: invalid syntax |
| TclTest.test_set_object_concurrent_mutation_in_sequence_conversion | harness-error:exit -11 |
| TclTest.test_splitlist | harness-error:SyntaxError: invalid syntax |
| TclTest.test_new_tcl_obj | harness-error:SyntaxError: invalid syntax |
