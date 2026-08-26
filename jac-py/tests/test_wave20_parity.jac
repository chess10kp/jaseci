"""P2 wave 20 kernel parity: math + array overflow guards vs host oracle.

jac-py/Modules/{math_fsum_cascade,array_repeat_guard}.{c,jac} are the staged
c2jac corpus pair (staging=lift) carrying CPython 3.14 kernel extracts
verbatim (math.fsum partial-compaction cascade, isclose tolerance ladder,
perm/comb small-step fast loops; array concat/repeat/do_extend/
inplace_repeat PY_SSIZE_T_MAX overflow ladders + negative-repeat clamps).
This file gates the lifted kernels against the host oracle.
Expected values were verified against real python3 at authoring time
(same pattern as wave-21's test_datetime_parity.jac); float cases pin
IEEE-754 bit-exact hi/lo pairs including overflow to inf/nan.
"""

import from math_fsum_cascade {
    comb_small_step,
    dl_fast_sum,
    dl_sum,
    fsum_fold_partials,
    isclose_tol_invalid,
    isclose_weak_test,
    m_fabs,
    perm_small_step,
}
import from array_repeat_guard {
    array_concat_size_ok,
    array_do_extend_size_ok,
    array_inplace_repeat_size_ok,
    array_repeat_byte_count,
    array_repeat_clamp_count,
    array_repeat_size_ok,
    c_idiv,
    c_imod,
}


def _expect(cond: bool, msg: str) {
    assert cond , msg;
}


test "wave20 c_idiv/c_imod match C truncating division semantics" {
    # Host oracle: int(a/b) truncation toward zero and C % (sign of dividend).
    cases: list = [
        ("div", 7, 2, 3),
        ("div", -7, 2, -3),
        ("div", 7, -2, -3),
        ("div", -7, -2, 3),
        ("div", 9223372036854775807, 1, 9223372036854775807),
        ("div", 0, 5, 0),
        ("mod", 7, 2, 1),
        ("mod", -7, 2, -1),
        ("mod", 7, -2, 1),
        ("mod", -7, -2, -1),
    ];
    for row in cases {
        if row[0] == "div" {
            _expect(c_idiv(row[1] as int, row[2] as int) == (row[3] as int), str(row));
        } else {
            _expect(c_imod(row[1] as int, row[2] as int) == (row[3] as int), str(row));
        }
    }
}

test "wave20 array_concat_size_ok overflow ladder" {
    # (size_a, size_b, expected)
    cases: list = [
        (10, 20, 1),
        (9223372036854775807, 0, 1),
        (9223372036854775807, 1, 0),
        (0, 9223372036854775807, 1),
        (4611686018427387903, 4611686018427387905, 0),
    ];
    for row in cases {
        got = array_concat_size_ok(row[0] as int, row[1] as int);
        _expect(got == (row[2] as int), str(row) + " got " + str(got));
    }
}

test "wave20 array repeat guards clamp negatives and bound products" {
    _expect(array_repeat_clamp_count(-5) == 0, "negative repeat clamps to 0");
    _expect(array_repeat_clamp_count(0) == 0, "zero repeat stays 0");
    _expect(array_repeat_clamp_count(7) == 7, "positive repeat unchanged");

    # array_repeat_size_ok(array_length, n): reject n > MAX // length.
    cases: list = [
        (3, 4, 1),
        (0, 5, 1),
        (4, 9223372036854775807, 0),
        (9223372036854775807, 2, 0),
        (2, 4611686018427387903, 1),
    ];
    for row in cases {
        got = array_repeat_size_ok(row[0] as int, row[1] as int);
        _expect(got == (row[2] as int), str(row) + " got " + str(got));
    }
}

test "wave20 do_extend/inplace_repeat ladders bound byte totals" {
    # array_do_extend_size_ok(self_size, bb_size, itemsize), itemsize > 0 only
    # (CPython never calls it with itemsize 0; MAX//0 is UB in C too).
    ext_cases: list = [
        (10, 20, 8, 1),
        (9223372036854775807, 0, 8, 0),
        (0, 9223372036854775807, 1, 1),
        (8, 1152921504606846975, 8, 0),
        (16, 9223372036854775807, 8, 0),
        (8, 1152921504606846976, 8, 0),
    ];
    for row in ext_cases {
        got = array_do_extend_size_ok(
            row[0] as int, row[1] as int, row[2] as int
        );
        _expect(got == (row[3] as int), str(row) + " got " + str(got));
    }

    # array_inplace_repeat_size_ok(itemsize, array_size, n).
    rep_cases: list = [
        (8, 10, 5, 1),
        (8, 10, -3, 1),
        (8, 9223372036854775807, 2, 0),
        (1, 9223372036854775807, 9223372036854775807, 0),
        (8, 1152921504606846975, 1, 1),
        (4, 3, 0, 1),
        (8, 1152921504606846976, 1, 0),
        (8, 1152921504606846975, 1152921504606846975, 0),
    ];
    for row in rep_cases {
        got = array_inplace_repeat_size_ok(
            row[0] as int, row[1] as int, row[2] as int
        );
        _expect(got == (row[3] as int), str(row) + " got " + str(got));
    }
}

test "wave20 repeat byte count multiplies exactly" {
    cases: list = [
        (3, 8, 4, 96),
        (0, 8, 9, 0),
        (2, 4, -1, -8),
        (5, 2, 0, 0),
    ];
    for row in cases {
        got = array_repeat_byte_count(row[0] as int, row[1] as int, row[2] as int);
        _expect(got == (row[3] as int), str(row) + " got " + str(got));
    }
}

test "wave20 m_fabs mirrors fabs sign ladder" {
    _expect(m_fabs(0.0) == 0.0, "+0.0");
    _expect(m_fabs(-0.0) == 0.0, "-0.0 compares equal");
    _expect(not (m_fabs(-0.0) < 0.0), "-0.0 normalizes to +0.0");
    _expect(m_fabs(3.5) == 3.5, "positive passthrough");
    _expect(m_fabs(-3.5) == 3.5, "negative negated");
    _expect(m_fabs(-1.5e300) == 1.5e300, "large magnitude");
}

test "wave20 two-sum kernels produce bit-exact hi/lo pairs" {
    # (a, b, hi_fast, lo_fast, hi_dekker, lo_dekker) -- host-verified IEEE
    # results. dl_fast_sum = Fast2Sum, dl_sum = Dekker's TwoSum; the overflow
    # pair pins inf/-inf propagation and the nan lo of TwoSum at overflow.
    cases: list = [
        (1.0, 2.0, "3.0", "0.0", "3.0", "0.0"),
        (0.1, 0.2, "0.30000000000000004", "-2.7755575615628914e-17",
         "0.30000000000000004", "-2.7755575615628914e-17"),
        (1e16, 1.0, "1e+16", "1.0", "1e+16", "1.0"),
        (-1e100, 1e100, "0.0", "0.0", "0.0", "0.0"),
        (5e-324, -5e-324, "0.0", "0.0", "0.0", "0.0"),
    ];
    for row in cases {
        a: float = row[0] as float;
        b: float = row[1] as float;
        out_f: list = [0.0, 0.0];
        out_d: list = [0.0, 0.0];
        dl_fast_sum(a, b, out_f);
        dl_sum(a, b, out_d);
        _expect(str(out_f[0]) == (row[2] as str), str(a) + "+" + str(b) + " fast hi");
        _expect(str(out_f[1]) == (row[3] as str), str(a) + "+" + str(b) + " fast lo");
        _expect(str(out_d[0]) == (row[4] as str), str(a) + "+" + str(b) + " dekker hi");
        _expect(str(out_d[1]) == (row[5] as str), str(a) + "+" + str(b) + " dekker lo");
    }
    big_out: list = [0.0, 0.0];
    dl_fast_sum(1e308, 1e308, big_out);
    _expect(big_out[0] == float("inf"), "fast hi overflows to inf");
    _expect(big_out[1] == float("-inf"), "fast lo overflows to -inf");
    dl_sum(1e308, 1e308, big_out);
    _expect(big_out[0] == float("inf"), "dekker hi overflows to inf");
    _expect(big_out[1] != big_out[1], "dekker lo is nan at overflow");
}

test "wave20 fsum partial-compaction cascade matches host fold" {
    # fsum_fold_partials(partials, n, x, out) -> compacted count, out[0]=final.
    # Expected (count, final) pairs verified against real python3 running the
    # identical msum/fold algorithm on the same inputs.
    cases: list = [
        ([1e100, 1.0, -1e100], 1.0, 2, 0.0),
        ([1.0, 2.0, 3.0], 0.5, 0, 6.5),
        ([1e16, 1.0, -1e16, 1.0], 2.0, 1, 5.0),
        ([], 1.5, 0, 1.5),
    ];
    for row in cases {
        partials: list = [];
        for v in row[0] as list {
            partials.append(v);
        }
        out: list = [0.0];
        n = len(partials);
        count = fsum_fold_partials(partials, n, row[1] as float, out);
        _expect(count == (row[2] as int), str(row[0]) + " count");
        _expect(out[0] == (row[3] as float), str(row[0]) + " final");
    }
    # Overflow keeps propagating through the cascade without killing the run:
    # host oracle folds [1e308, 1e308, -1e308] with x=1.0 to (count=3, inf).
    partials: list = [1e308, 1e308, -1e308];
    out: list = [0.0];
    count = fsum_fold_partials(partials, 3, 1.0, out);
    _expect(count == 3, "overflow cascade compacts all three partials");
    _expect(out[0] == float("inf"), "overflow cascade final is inf");
}

test "wave20 isclose tolerance ladder matches host math.isclose" {
    # (a, b, rel_tol, abs_tol, expected) -- expected from host math.isclose.
    cases: list = [
        (1.0, 1.0000001, 1e-09, 0.0, 0),
        (1.0, 1.0000001, 1e-06, 0.0, 1),
        (100.0, 100.1, 0.001, 0.0, 1),
        (0.0, 1e-12, 1e-09, 1e-10, 1),
        (0.0, 1e-12, 1e-09, 1e-11, 1),
        (1.0, 2.0, 0.5, 0.0, 1),
    ];
    for row in cases {
        got = isclose_weak_test(
            row[0] as float, row[1] as float, row[2] as float, row[3] as float
        );
        _expect(got == (row[4] as int), str(row) + " got " + str(got));
    }
    # NOTE: the inf==inf short-circuit lives in CPython's math.isclose prologue,
    # outside this lifted kernel fragment -- infinities are out of domain here.
    invalid: list = [
        (-0.1, 0.0, 1),
        (0.1, -1.0, 1),
        (0.0, 0.0, 0),
        (1e-09, 1e-09, 0),
        (-1e-09, -1e-09, 1),
    ];
    for row in invalid {
        got = isclose_tol_invalid(row[0] as float, row[1] as float);
        _expect(got == (row[2] as int), str(row) + " got " + str(got));
    }
}

test "wave20 perm/comb small-step loops match host math" {
    # (n, k, comb, perm) -- host math.comb/math.perm for small k.
    cases: list = [
        (10, 3, 120, 720),
        (6, 6, 1, 720),
        (12, 1, 12, 12),
        (20, 3, 1140, 6840),
        (9, 4, 126, 3024),
    ];
    for row in cases {
        got_comb = comb_small_step(row[0] as int, row[1] as int);
        _expect(got_comb == (row[2] as int), str(row) + " comb got " + str(got_comb));
        got_perm = perm_small_step(row[0] as int, row[1] as int);
        _expect(got_perm == (row[3] as int), str(row) + " perm got " + str(got_perm));
    }
}
