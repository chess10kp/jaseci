# Triage report: `conv_random_pins.jac`

- source: reference/cpython/Lib/test/test_random.py
- guest leg: 0/15 marks
- pins: **2 passed** / 15 run (+68 quarantined of 83 extracted)

| pin | result | got |
|---|---|---|
| TestBasicOps.test_bug_1727780 | GUEST-WRONG-OUTPUT | GOT<"ORACLE_EXC AttributeError 'findfile'"> |
| TestRawMersenneTwister.test_bug_41052 | PASS | |
| TestRawMersenneTwister.test_bug_42008 | PASS | |
| TestDistributions.test_zeroinputs | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDistributions.test_avg_std | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDistributions.test_constant | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDistributions.test_binomialvariate | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDistributions.test_von_mises_range | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDistributions.test_von_mises_large_kappa | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestDistributions.test_gammavariate_errors | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestRandomSubclassing.test_random_subclass_with_kwargs | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestRandomSubclassing.test_subclasses_overriding_methods | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestModule.testMagicConstants | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| TestModule.test__all__ | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |
| CommandLineTest.test_main | GUEST-WRONG-OUTPUT | RUN<"AttributeError: 'super' object has no attribute 'seed'"> |

## Quarantined at conversion

| test | reason |
|---|---|
| TestBasicOps.test_53_bits_per_float | decorator:support.requires_IEEE_754 |
| SystemRandom_TestBasicOps.test_autoseed | decorator:unittest.skipUnless |
| SystemRandom_TestBasicOps.test_saverestore | decorator:unittest.skipUnless |
| SystemRandom_TestBasicOps.test_seedargs | decorator:unittest.skipUnless |
| SystemRandom_TestBasicOps.test_gauss | decorator:unittest.skipUnless |
| SystemRandom_TestBasicOps.test_pickling | decorator:unittest.skipUnless |
| MersenneTwister_TestBasicOps.test_getrandbits_4G_bits | decorator:support.bigmemtest |
| MersenneTwister_TestBasicOps.test_randbytes_256M | decorator:support.bigmemtest |
| TestModule.test_after_fork | decorator:.requires_fork |
| CommandLineTest.test_parse_args | decorator:support.force_not_colorized |
| TestBasicOps.test_autoseed | uses-self.gen |
| TestBasicOps.test_saverestore | uses-self.randomlist |
| TestBasicOps.test_seedargs | uses-self.gen |
| TestBasicOps.test_seed_no_mutate_bug_44018 | uses-self.gen |
| TestBasicOps.test_seed_when_randomness_source_not_found | self.test_seedargs |
| TestBasicOps.test_shuffle | uses-self.gen |
| TestBasicOps.test_choice | uses-self.gen |
| TestBasicOps.test_choice_with_numpy | uses-self.gen |
| TestBasicOps.test_sample | uses-self.gen |
| TestBasicOps.test_sample_distribution | uses-self.gen |
| TestBasicOps.test_sample_inputs | uses-self.gen |
| TestBasicOps.test_sample_on_dicts | uses-self.gen |
| TestBasicOps.test_sample_on_sets | uses-self.gen |
| TestBasicOps.test_sample_on_seqsets | uses-self._items |
| TestBasicOps.test_sample_with_counts | uses-self.gen |
| TestBasicOps.test_choices | uses-self.gen |
| TestBasicOps.test_choices_subnormal | uses-self.gen |
| TestBasicOps.test_choices_with_all_zero_weights | uses-self.gen |
| TestBasicOps.test_choices_negative_total | uses-self.gen |
| TestBasicOps.test_choices_infinite_total | uses-self.gen |
| TestBasicOps.test_gauss | uses-self.gen |
| TestBasicOps.test_getrandbits | uses-self.gen |
| TestBasicOps.test_bigrand | uses-self.gen |
| TestBasicOps.test_bigrand_ranges | uses-self.gen |
| TestBasicOps.test_rangelimits | uses-self.gen |
| TestBasicOps.test_randrange_nonunit_step | uses-self.gen |
| TestBasicOps.test_randrange_errors | uses-self.assertRaises |
| TestBasicOps.test_randrange_step | uses-self.gen |
| TestBasicOps.test_randbelow_logic | unresolved-name:_log |
| TestBasicOps.test_randrange_index | uses-self.gen |
| TestBasicOps.test_randint | uses-self.gen |
| TestBasicOps.test_pickling | uses-self.gen |
| TestBasicOps.test_bug_9025 | uses-self.gen |
| TestBasicOps.test_randrange_bug_1590891 | uses-self.gen |
| TestBasicOps.test_randbytes | uses-self.gen |
| TestBasicOps.test_mu_sigma_default_args | uses-self.gen |
| MersenneTwister_TestBasicOps.test_guaranteed_stable | uses-self.gen |
| MersenneTwister_TestBasicOps.test_bug_27706 | uses-self.gen |
| MersenneTwister_TestBasicOps.test_bug_31478 | uses-self.gen |
| MersenneTwister_TestBasicOps.test_bug_31482 | uses-self.gen |
| MersenneTwister_TestBasicOps.test_setstate_first_arg | uses-self.gen |
| MersenneTwister_TestBasicOps.test_setstate_middle_arg | uses-self.gen |
| MersenneTwister_TestBasicOps.test_referenceImplementation | uses-self.gen |
| MersenneTwister_TestBasicOps.test_strong_reference_implementation | uses-self.gen |
| MersenneTwister_TestBasicOps.test_long_seed | uses-self.gen |
| MersenneTwister_TestBasicOps.test_getrandbits | uses-self.gen |
| MersenneTwister_TestBasicOps.test_getrandbits_2G_bits | uses-self.gen |
| MersenneTwister_TestBasicOps.test_randrange_uses_getrandbits | uses-self.gen |
| MersenneTwister_TestBasicOps.test_randbelow_without_getrandbits | uses-self.gen |
| MersenneTwister_TestBasicOps.test_choices_algorithms | uses-self.gen |
| MersenneTwister_TestBasicOps.test_randbytes | uses-self.gen |
| MersenneTwister_TestBasicOps.test_randbytes_getrandbits | uses-self.gen |
| MersenneTwister_TestBasicOps.test_sample_counts_equivalence | uses-self.gen |
| TestDistributions.test_gammavariate_alpha_greater_one | unresolved-name:random_mock |
| TestDistributions.test_gammavariate_alpha_equal_one | unresolved-name:random_mock |
| TestDistributions.test_gammavariate_alpha_equal_one_equals_expovariate | unresolved-name:random_mock |
| TestDistributions.test_gammavariate_alpha_between_zero_and_one | unresolved-name:random_mock |
| TestDistributions.test_betavariate_return_zero | unresolved-name:gammavariate_mock |

## Expected vs got

### CommandLineTest.test_main (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestBasicOps.test_bug_1727780 (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: GOT<"ORACLE_EXC AttributeError 'findfile'">

### TestDistributions.test_avg_std (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDistributions.test_binomialvariate (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDistributions.test_constant (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDistributions.test_gammavariate_errors (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDistributions.test_von_mises_large_kappa (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDistributions.test_von_mises_range (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestDistributions.test_zeroinputs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestModule.testMagicConstants (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestModule.test__all__ (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestRandomSubclassing.test_random_subclass_with_kwargs (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">

### TestRandomSubclassing.test_subclasses_overriding_methods (GUEST-WRONG-OUTPUT)

- expected: host oracle = `ok`
- got: RUN<"AttributeError: 'super' object has no attribute 'seed'">
