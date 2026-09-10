# Product-path facade for cmath (complex transcendental functions).
# Semantics mirror CPython 3.14 ``Modules/cmathmodule.c`` byte-for-byte at the
# algorithm level: identical C99-Annex-G special-value tables, identical
# scaling guards (CM_LARGE_DOUBLE / subnormal rescaling), and identical errno
# discipline (EDOM -> ValueError "math domain error", ERANGE -> OverflowError
# "math range error"). Real transcendentals come from the host math module;
# every branch structure below is a direct lift of the corresponding c_* /
# cmath_*_impl function in the C source.

import math as host_math;

# ---------------- module constants (cmath_exec) ----------------

glob pi: float = 3.141592653589793;
glob e: float = 2.718281828459045;
glob tau: float = 6.283185307179586;
glob inf: float = float("inf");
glob nan: float = float("nan");
glob infj: complex = complex(0.0, float("inf"));
glob nanj: complex = complex(0.0, float("nan"));

# ---------------- C limits (float.h / pycore_pymath.h) ----------------

glob _DBL_MAX: float = 1.7976931348623157e308;
glob _DBL_MIN: float = 2.2250738585072014e-308;
glob _DBL_MANT_DIG: int = 53;
glob _CM_LARGE_DOUBLE: float = _DBL_MAX / 4.0;
glob _CM_SQRT_LARGE_DOUBLE: float = 6.703904478183408e153;
glob _CM_LOG_LARGE_DOUBLE: float = 354.8913564466919;
glob _CM_SQRT_DBL_MIN: float = 1.4916681462400413e-154;
# FLT_RADIX==2: CM_SCALE_UP = 2*(DBL_MANT_DIG/2)+1, CM_SCALE_DOWN = -(UP+1)/2
glob _CM_SCALE_UP: int = 2 * (_DBL_MANT_DIG // 2) + 1;
glob _CM_SCALE_DOWN: int = -((_CM_SCALE_UP + 1) // 2);
glob _M_LN2: float = 0.6931471805599453094;
glob _M_LN10: float = 2.302585092994045684;

# errno codes lifted to ints: EDOM=1, ERANGE=2, none=0
glob _EDOM: int = 1;
glob _ERANGE: int = 2;

# ---------------- special-value machinery ----------------

# special_type(d): ST_NINF, ST_NEG, ST_NZERO, ST_PZERO, ST_POS, ST_PINF,
# ST_NAN -- indexed 0..6, matching the C enum order.
def _special_type(d: float) -> int {
    if host_math.isfinite(d) {
        if d != 0.0 {
            return 4 if host_math.copysign(1.0, d) == 1.0 else 1;
        }
        return 3 if host_math.copysign(1.0, d) == 1.0 else 2;
    }
    if host_math.isnan(d) {
        return 6;
    }
    return 5 if host_math.copysign(1.0, d) == 1.0 else 0;
}

# Table entry sentinel: the C code uses an unlikely placeholder (U) for
# combinations that SPECIAL_VALUE can never reach; kept as None and defended
# with a domain error rather than silently propagating garbage.
def _sv_entry(table: list, z: complex) -> tuple[float, float] {
    cell: any = table[_special_type(z.real)][_special_type(z.imag)];
    if cell is None {
        raise ValueError("math domain error");
    }
    return cell;
}

glob _INF: float = float("inf");
glob _NAN: float = float("nan");
glob _PI: float = 3.141592653589793;
glob _P14: float = 0.25 * _PI;
glob _P12: float = 0.5 * _PI;
glob _P34: float = 0.75 * _PI;

# acos_special_values
glob _ACOS_SV: list = [
    [(_P34, _INF), (_PI, _INF), (_PI, _INF), (_PI, -_INF), (_PI, -_INF), (_P34, -_INF), (_NAN, _INF)],
    [(_P12, _INF), None, None, None, None, (_P12, -_INF), (_NAN, _NAN)],
    [(_P12, _INF), None, (_P12, 0.0), (_P12, -0.0), None, (_P12, -_INF), (_P12, _NAN)],
    [(_P12, _INF), None, (_P12, 0.0), (_P12, -0.0), None, (_P12, -_INF), (_P12, _NAN)],
    [(_P12, _INF), None, None, None, None, (_P12, -_INF), (_NAN, _NAN)],
    [(_P14, _INF), (0.0, _INF), (0.0, _INF), (0.0, -_INF), (0.0, -_INF), (_P14, -_INF), (_NAN, _INF)],
    [(_NAN, _INF), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, -_INF), (_NAN, _NAN)],
];

# acosh_special_values
glob _ACOSH_SV: list = [
    [(_INF, -_P34), (_INF, -_PI), (_INF, -_PI), (_INF, _PI), (_INF, _PI), (_INF, _P34), (_INF, _NAN)],
    [(_INF, -_P12), None, None, None, None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P12), None, (0.0, -_P12), (0.0, _P12), None, (_INF, _P12), (_NAN, _P12)],
    [(_INF, -_P12), None, (0.0, -_P12), (0.0, _P12), None, (_INF, _P12), (_NAN, _P12)],
    [(_INF, -_P12), None, None, None, None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P14), (_INF, -0.0), (_INF, -0.0), (_INF, 0.0), (_INF, 0.0), (_INF, _P14), (_INF, _NAN)],
    [(_INF, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_INF, _NAN), (_NAN, _NAN)],
];

# asinh_special_values
glob _ASINH_SV: list = [
    [(-_INF, -_P14), (-_INF, -0.0), (-_INF, -0.0), (-_INF, 0.0), (-_INF, 0.0), (-_INF, _P14), (-_INF, _NAN)],
    [(-_INF, -_P12), None, None, None, None, (-_INF, _P12), (_NAN, _NAN)],
    [(-_INF, -_P12), None, (-0.0, -0.0), (-0.0, 0.0), None, (-_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P12), None, (0.0, -0.0), (0.0, 0.0), None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P12), None, None, None, None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P14), (_INF, -0.0), (_INF, -0.0), (_INF, 0.0), (_INF, 0.0), (_INF, _P14), (_INF, _NAN)],
    [(_INF, _NAN), (_NAN, _NAN), (_NAN, -0.0), (_NAN, 0.0), (_NAN, _NAN), (_INF, _NAN), (_NAN, _NAN)],
];

# atanh_special_values
glob _ATANH_SV: list = [
    [(-0.0, -_P12), (-0.0, -_P12), (-0.0, -_P12), (-0.0, _P12), (-0.0, _P12), (-0.0, _P12), (-0.0, _NAN)],
    [(-0.0, -_P12), None, None, None, None, (-0.0, _P12), (_NAN, _NAN)],
    [(-0.0, -_P12), None, (-0.0, -0.0), (-0.0, 0.0), None, (-0.0, _P12), (-0.0, _NAN)],
    [(0.0, -_P12), None, (0.0, -0.0), (0.0, 0.0), None, (0.0, _P12), (0.0, _NAN)],
    [(0.0, -_P12), None, None, None, None, (0.0, _P12), (_NAN, _NAN)],
    [(0.0, -_P12), (0.0, -_P12), (0.0, -_P12), (0.0, _P12), (0.0, _P12), (0.0, _P12), (0.0, _NAN)],
    [(0.0, -_P12), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (0.0, _P12), (_NAN, _NAN)],
];

# cosh_special_values
glob _COSH_SV: list = [
    [(_INF, _NAN), None, (_INF, 0.0), (_INF, -0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_NAN, 0.0), None, (1.0, 0.0), (1.0, -0.0), None, (_NAN, 0.0), (_NAN, 0.0)],
    [(_NAN, 0.0), None, (1.0, -0.0), (1.0, 0.0), None, (_NAN, 0.0), (_NAN, 0.0)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_INF, _NAN), None, (_INF, -0.0), (_INF, 0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), (_NAN, _NAN), (_NAN, 0.0), (_NAN, 0.0), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN)],
];

# exp_special_values
glob _EXP_SV: list = [
    [(0.0, 0.0), None, (0.0, -0.0), (0.0, 0.0), None, (0.0, 0.0), (0.0, 0.0)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_NAN, _NAN), None, (1.0, -0.0), (1.0, 0.0), None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_NAN, _NAN), None, (1.0, -0.0), (1.0, 0.0), None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_INF, _NAN), None, (_INF, -0.0), (_INF, 0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), (_NAN, _NAN), (_NAN, -0.0), (_NAN, 0.0), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN)],
];

# log_special_values
glob _LOG_SV: list = [
    [(_INF, -_P34), (_INF, -_PI), (_INF, -_PI), (_INF, _PI), (_INF, _PI), (_INF, _P34), (_INF, _NAN)],
    [(_INF, -_P12), None, None, None, None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P12), None, (-_INF, -_PI), (-_INF, _PI), None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P12), None, (-_INF, -0.0), (-_INF, 0.0), None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P12), None, None, None, None, (_INF, _P12), (_NAN, _NAN)],
    [(_INF, -_P14), (_INF, -0.0), (_INF, -0.0), (_INF, 0.0), (_INF, 0.0), (_INF, _P14), (_INF, _NAN)],
    [(_INF, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_INF, _NAN), (_NAN, _NAN)],
];

# sqrt_special_values
glob _SQRT_SV: list = [
    [(_INF, -_INF), (0.0, -_INF), (0.0, -_INF), (0.0, _INF), (0.0, _INF), (_INF, _INF), (_NAN, _INF)],
    [(_INF, -_INF), None, None, None, None, (_INF, _INF), (_NAN, _NAN)],
    [(_INF, -_INF), None, (0.0, -0.0), (0.0, 0.0), None, (_INF, _INF), (_NAN, _NAN)],
    [(_INF, -_INF), None, (0.0, -0.0), (0.0, 0.0), None, (_INF, _INF), (_NAN, _NAN)],
    [(_INF, -_INF), None, None, None, None, (_INF, _INF), (_NAN, _NAN)],
    [(_INF, -_INF), (_INF, -0.0), (_INF, -0.0), (_INF, 0.0), (_INF, 0.0), (_INF, _INF), (_INF, _NAN)],
    [(_INF, -_INF), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN), (_INF, _INF), (_NAN, _NAN)],
];

# sinh_special_values
glob _SINH_SV: list = [
    [(_INF, _NAN), None, (-_INF, -0.0), (-_INF, 0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(0.0, _NAN), None, (-0.0, -0.0), (-0.0, 0.0), None, (0.0, _NAN), (0.0, _NAN)],
    [(0.0, _NAN), None, (0.0, -0.0), (0.0, 0.0), None, (0.0, _NAN), (0.0, _NAN)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_INF, _NAN), None, (_INF, -0.0), (_INF, 0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), (_NAN, _NAN), (_NAN, -0.0), (_NAN, 0.0), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN)],
];

# tanh_special_values
glob _TANH_SV: list = [
    [(-1.0, 0.0), None, (-1.0, -0.0), (-1.0, 0.0), None, (-1.0, 0.0), (-1.0, 0.0)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(-0.0, _NAN), None, (-0.0, -0.0), (-0.0, 0.0), None, (-0.0, _NAN), (-0.0, _NAN)],
    [(0.0, _NAN), None, (0.0, -0.0), (0.0, 0.0), None, (0.0, _NAN), (0.0, _NAN)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(1.0, 0.0), None, (1.0, -0.0), (1.0, 0.0), None, (1.0, 0.0), (1.0, 0.0)],
    [(_NAN, _NAN), (_NAN, _NAN), (_NAN, -0.0), (_NAN, 0.0), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN)],
];

# rect_special_values
glob _RECT_SV: list = [
    [(_INF, _NAN), None, (-_INF, 0.0), (-_INF, -0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(0.0, 0.0), None, (-0.0, 0.0), (-0.0, -0.0), None, (0.0, 0.0), (0.0, 0.0)],
    [(0.0, 0.0), None, (0.0, -0.0), (0.0, 0.0), None, (0.0, 0.0), (0.0, 0.0)],
    [(_NAN, _NAN), None, None, None, None, (_NAN, _NAN), (_NAN, _NAN)],
    [(_INF, _NAN), None, (_INF, -0.0), (_INF, 0.0), None, (_INF, _NAN), (_INF, _NAN)],
    [(_NAN, _NAN), (_NAN, _NAN), (_NAN, 0.0), (_NAN, 0.0), (_NAN, _NAN), (_NAN, _NAN), (_NAN, _NAN)],
];

# ---------------- errno glue (math_error) ----------------

def _check_errno(err: int) {
    if err == _EDOM {
        raise ValueError("math domain error");
    }
    if err == _ERANGE {
        raise OverflowError("math range error");
    }
}

# ---------------- core algorithms (c_* functions) ----------------

def _c_sqrt(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        (re, im) = _sv_entry(_SQRT_SV, z);
        return (re, im, 0);
    }
    if z.real == 0.0 and z.imag == 0.0 {
        return (0.0, z.imag, 0);
    }
    ax = host_math.fabs(z.real);
    ay = host_math.fabs(z.imag);
    if ax < _DBL_MIN and ay < _DBL_MIN {
        # catch cases where hypot(ax, ay) is subnormal
        ax = host_math.ldexp(ax, _CM_SCALE_UP);
        ay_up = host_math.ldexp(ay, _CM_SCALE_UP);
        s = host_math.ldexp(
            host_math.sqrt(ax + host_math.hypot(ax, ay_up)), _CM_SCALE_DOWN
        );
    } else {
        ax = ax / 8.0;
        s = 2.0 * host_math.sqrt(ax + host_math.hypot(ax, ay / 8.0));
    }
    d = ay / (2.0 * s);
    if z.real >= 0.0 {
        return (s, host_math.copysign(d, z.imag), 0);
    }
    return (d, host_math.copysign(s, z.imag), 0);
}

def _c_log(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        (re, im) = _sv_entry(_LOG_SV, z);
        return (re, im, 0);
    }
    ax = host_math.fabs(z.real);
    ay = host_math.fabs(z.imag);
    if ax > _CM_LARGE_DOUBLE or ay > _CM_LARGE_DOUBLE {
        re = host_math.log(host_math.hypot(ax / 2.0, ay / 2.0)) + _M_LN2;
    } elif ax < _DBL_MIN and ay < _DBL_MIN {
        if ax > 0.0 or ay > 0.0 {
            # catch cases where hypot(ax, ay) is subnormal
            re = (
                host_math.log(
                    host_math.hypot(
                        host_math.ldexp(ax, _DBL_MANT_DIG),
                        host_math.ldexp(ay, _DBL_MANT_DIG),
                    )
                )
                - _DBL_MANT_DIG * _M_LN2
            );
        } else {
            # log(+/-0. +/- 0i)
            return (-_INF, host_math.atan2(z.imag, z.real), _EDOM);
        }
    } else {
        h = host_math.hypot(ax, ay);
        if 0.71 <= h and h <= 1.73 {
            am = ax if ax > ay else ay;
            an = ay if ax > ay else ax;
            re = host_math.log1p((am - 1.0) * (am + 1.0) + an * an) / 2.0;
        } else {
            re = host_math.log(h);
        }
    }
    return (re, host_math.atan2(z.imag, z.real), 0);
}

def _c_acos(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        (re, im) = _sv_entry(_ACOS_SV, z);
        return (re, im, 0);
    }
    if host_math.fabs(z.real) > _CM_LARGE_DOUBLE or host_math.fabs(z.imag) > _CM_LARGE_DOUBLE {
        # avoid unnecessary overflow for large arguments
        re = host_math.atan2(host_math.fabs(z.imag), z.real);
        im = -host_math.copysign(
            host_math.log(host_math.hypot(z.real / 2.0, z.imag / 2.0))
            + _M_LN2 * 2.0,
            z.imag,
        );
    } else {
        s1 = _c_sqrt(complex(1.0 - z.real, -z.imag));
        s2 = _c_sqrt(complex(1.0 + z.real, z.imag));
        re = 2.0 * host_math.atan2(s1[0], s2[0]);
        im = host_math.asinh(s2[0] * s1[1] - s2[1] * s1[0]);
    }
    return (re, im, 0);
}

def _c_acosh(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        (re, im) = _sv_entry(_ACOSH_SV, z);
        return (re, im, 0);
    }
    if host_math.fabs(z.real) > _CM_LARGE_DOUBLE or host_math.fabs(z.imag) > _CM_LARGE_DOUBLE {
        # avoid unnecessary overflow for large arguments
        re = host_math.log(host_math.hypot(z.real / 2.0, z.imag / 2.0)) + _M_LN2 * 2.0;
        im = host_math.atan2(z.imag, z.real);
    } else {
        s1 = _c_sqrt(complex(z.real - 1.0, z.imag));
        s2 = _c_sqrt(complex(z.real + 1.0, z.imag));
        re = host_math.asinh(s1[0] * s2[0] + s1[1] * s2[1]);
        im = 2.0 * host_math.atan2(s1[1], s2[0]);
    }
    return (re, im, 0);
}

def _c_asinh(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        (re, im) = _sv_entry(_ASINH_SV, z);
        return (re, im, 0);
    }
    if host_math.fabs(z.real) > _CM_LARGE_DOUBLE or host_math.fabs(z.imag) > _CM_LARGE_DOUBLE {
        if z.imag >= 0.0 {
            re = host_math.copysign(
                host_math.log(host_math.hypot(z.real / 2.0, z.imag / 2.0))
                + _M_LN2 * 2.0,
                z.real,
            );
        } else {
            re = -host_math.copysign(
                host_math.log(host_math.hypot(z.real / 2.0, z.imag / 2.0))
                + _M_LN2 * 2.0,
                -z.real,
            );
        }
        im = host_math.atan2(z.imag, host_math.fabs(z.real));
    } else {
        s1 = _c_sqrt(complex(1.0 + z.imag, -z.real));
        s2 = _c_sqrt(complex(1.0 - z.imag, z.real));
        re = host_math.asinh(s1[0] * s2[1] - s2[0] * s1[1]);
        im = host_math.atan2(z.imag, s1[0] * s2[0] - s1[1] * s2[1]);
    }
    return (re, im, 0);
}

def _c_atanh(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        (re, im) = _sv_entry(_ATANH_SV, z);
        return (re, im, 0);
    }
    # Reduce to case where z.real >= 0., using atanh(z) = -atanh(-z).
    negate = z.real < 0.0;
    zz = complex(-z.real, -z.imag) if negate else z;
    ay = host_math.fabs(zz.imag);
    if zz.real > _CM_SQRT_LARGE_DOUBLE or ay > _CM_SQRT_LARGE_DOUBLE {
        # abs(z) large: atanh(z) ~ 1/z +/- i*pi/2 (+/- depending on sign of imag)
        h = host_math.hypot(zz.real / 2.0, zz.imag / 2.0);  # safe from overflow
        re = zz.real / 4.0 / h / h;
        im = host_math.copysign(_PI / 2.0, zz.imag);
        err = 0;
    } elif zz.real == 1.0 and ay < _CM_SQRT_DBL_MIN {
        # C99 standard says: atanh(1+/-0.) should be inf +/- 0i
        if ay == 0.0 {
            re = _INF;
            im = zz.imag;
            err = _EDOM;
        } else {
            re = -host_math.log(
                host_math.sqrt(ay) / host_math.sqrt(host_math.hypot(ay, 2.0))
            );
            im = host_math.copysign(host_math.atan2(2.0, -ay) / 2, zz.imag);
            err = 0;
        }
    } else {
        re = host_math.log1p(
            4.0 * zz.real / ((1.0 - zz.real) * (1.0 - zz.real) + ay * ay)
        ) / 4.0;
        im = -host_math.atan2(
            -2.0 * zz.imag, (1.0 - zz.real) * (1.0 + zz.real) - ay * ay
        ) / 2.0;
        err = 0;
    }
    if negate {
        return (-re, -im, err);  # float negation only
    }
    return (re, im, err);
}

def _c_cosh(z: complex) -> tuple[float, float, int] {
    # special treatment for cosh(+/-inf + iy) if y is not a NaN
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        if (
            host_math.isinf(z.real)
            and host_math.isfinite(z.imag)
            and z.imag != 0.0
        ) {
            if z.real > 0 {
                re = host_math.copysign(_INF, host_math.cos(z.imag));
                im = host_math.copysign(_INF, host_math.sin(z.imag));
            } else {
                re = host_math.copysign(_INF, host_math.cos(z.imag));
                im = -host_math.copysign(_INF, host_math.sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_COSH_SV, z);
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN
        if host_math.isinf(z.imag) and not host_math.isnan(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if host_math.fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        # deal correctly with cases where cosh(z.real) overflows but
        # cosh(z) does not
        x_minus_one = z.real - host_math.copysign(1.0, z.real);
        re = host_math.cos(z.imag) * host_math.cosh(x_minus_one) * e;
        im = host_math.sin(z.imag) * host_math.sinh(x_minus_one) * e;
    } else {
        re = host_math.cos(z.imag) * host_math.cosh(z.real);
        im = host_math.sin(z.imag) * host_math.sinh(z.real);
    }
    if host_math.isinf(re) or host_math.isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def _c_sinh(z: complex) -> tuple[float, float, int] {
    # special treatment for sinh(+/-inf + iy) if y is finite and nonzero
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        if (
            host_math.isinf(z.real)
            and host_math.isfinite(z.imag)
            and z.imag != 0.0
        ) {
            if z.real > 0 {
                re = host_math.copysign(_INF, host_math.cos(z.imag));
                im = host_math.copysign(_INF, host_math.sin(z.imag));
            } else {
                re = -host_math.copysign(_INF, host_math.cos(z.imag));
                im = host_math.copysign(_INF, host_math.sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_SINH_SV, z);
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN
        if host_math.isinf(z.imag) and not host_math.isnan(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if host_math.fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        x_minus_one = z.real - host_math.copysign(1.0, z.real);
        re = host_math.cos(z.imag) * host_math.sinh(x_minus_one) * e;
        im = host_math.sin(z.imag) * host_math.cosh(x_minus_one) * e;
    } else {
        re = host_math.cos(z.imag) * host_math.sinh(z.real);
        im = host_math.sin(z.imag) * host_math.cosh(z.real);
    }
    if host_math.isinf(re) or host_math.isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def _c_exp(z: complex) -> tuple[float, float, int] {
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        if (
            host_math.isinf(z.real)
            and host_math.isfinite(z.imag)
            and z.imag != 0.0
        ) {
            if z.real > 0 {
                re = host_math.copysign(_INF, host_math.cos(z.imag));
                im = host_math.copysign(_INF, host_math.sin(z.imag));
            } else {
                re = host_math.copysign(0.0, host_math.cos(z.imag));
                im = host_math.copysign(0.0, host_math.sin(z.imag));
            }
        } else {
            (re, im) = _sv_entry(_EXP_SV, z);
        }
        # errno = EDOM if y is +/- infinity and x is not a NaN/-infinity
        if host_math.isinf(z.imag) and (
            host_math.isfinite(z.real)
            or (host_math.isinf(z.real) and z.real > 0)
        ) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    if z.real > _CM_LOG_LARGE_DOUBLE {
        l = host_math.exp(z.real - 1.0);
        re = l * host_math.cos(z.imag) * e;
        im = l * host_math.sin(z.imag) * e;
    } else {
        l = host_math.exp(z.real);
        re = l * host_math.cos(z.imag);
        im = l * host_math.sin(z.imag);
    }
    if host_math.isinf(re) or host_math.isinf(im) {
        return (re, im, _ERANGE);
    }
    return (re, im, 0);
}

def _c_tanh(z: complex) -> tuple[float, float, int] {
    # tanh(x+iy) = (tanh(x)(1+tan(y)^2) + i tan(y)(1-tanh(x))^2) /
    #              (1+tan(y)^2 tanh(x)^2)
    # special treatment for tanh(+/-inf + iy) if y is finite and nonzero
    if not (host_math.isfinite(z.real) and host_math.isfinite(z.imag)) {
        if (
            host_math.isinf(z.real)
            and host_math.isfinite(z.imag)
            and z.imag != 0.0
        ) {
            if z.real > 0 {
                re = 1.0;
            } else {
                re = -1.0;
            }
            im = host_math.copysign(0.0, 2.0 * host_math.sin(z.imag) * host_math.cos(z.imag));
        } else {
            (re, im) = _sv_entry(_TANH_SV, z);
        }
        # errno = EDOM if z.imag is +/- infinity and z.real is finite
        if host_math.isinf(z.imag) and host_math.isfinite(z.real) {
            return (re, im, _EDOM);
        }
        return (re, im, 0);
    }
    # danger of overflow in 2.*z.imag!
    if host_math.fabs(z.real) > _CM_LOG_LARGE_DOUBLE {
        re = host_math.copysign(1.0, z.real);
        im = 4.0 * host_math.sin(z.imag) * host_math.cos(z.imag) * host_math.exp(-2.0 * host_math.fabs(z.real));
        return (re, im, 0);
    }
    tx = host_math.tanh(z.real);
    ty = host_math.tan(z.imag);
    cx = 1.0 / host_math.cosh(z.real);
    txty = tx * ty;
    denom = 1.0 + txty * txty;
    re = tx * (1.0 + ty * ty) / denom;
    im = (ty / denom) * cx * cx;
    return (re, im, 0);
}

# _Py_c_quot (Smith's algorithm); EDOM on zero divisor.
def _c_quot(are: float, aim: float, bre: float, bim: float) -> tuple[float, float, int] {
    abs_breal = host_math.fabs(bre);
    abs_bimag = host_math.fabs(bim);
    if abs_breal >= abs_bimag {
        if abs_breal == 0.0 {
            return (0.0, 0.0, _EDOM);
        }
        ratio = bim / bre;
        denom = bre + bim * ratio;
        return ((are + aim * ratio) / denom, (aim - are * ratio) / denom, 0);
    }
    ratio = bre / bim;
    denom = bre * ratio + bim;
    return ((are * ratio + aim) / denom, (aim * ratio - are) / denom, 0);
}

# _Py_c_abs; ERANGE on overflow of finite operands.
def _c_abs(re: float, im: float) -> tuple[float, int] {
    r = host_math.hypot(re, im);
    if host_math.isinf(r) and host_math.isfinite(re) and host_math.isfinite(im) {
        return (r, _ERANGE);
    }
    return (r, 0);
}

# ---------------- public surface (cmath_methods) ----------------

def acos(z: complex) -> complex {
    (re, im, err) = _c_acos(complex(z));
    _check_errno(err);
    return complex(re, im);
}

def acosh(z: complex) -> complex {
    (re, im, err) = _c_acosh(complex(z));
    _check_errno(err);
    return complex(re, im);
}

def asin(z: complex) -> complex {
    # asin(z) = -i asinh(iz)
    s = _c_asinh(complex(-z.imag, z.real));
    _check_errno(s[2]);
    return complex(s[1], -s[0]);
}

def asinh(z: complex) -> complex {
    (re, im, err) = _c_asinh(complex(z));
    _check_errno(err);
    return complex(re, im);
}

def atan(z: complex) -> complex {
    # atan(z) = -i atanh(iz)
    s = _c_atanh(complex(-z.imag, z.real));
    _check_errno(s[2]);
    return complex(s[1], -s[0]);
}

def atanh(z: complex) -> complex {
    (re, im, err) = _c_atanh(complex(z));
    _check_errno(err);
    return complex(re, im);
}

def cos(z: complex) -> complex {
    # cos(z) = cosh(iz)
    r = _c_cosh(complex(-z.imag, z.real));
    _check_errno(r[2]);
    return complex(r[0], r[1]);
}

def cosh(z: complex) -> complex {
    r = _c_cosh(complex(z));
    _check_errno(r[2]);
    return complex(r[0], r[1]);
}

def exp(z: complex) -> complex {
    r = _c_exp(complex(z));
    _check_errno(r[2]);
    return complex(r[0], r[1]);
}

def isclose(a: complex, b: complex, rel_tol: float = 1e-09, abs_tol: float = 0.0) -> bool {
    if rel_tol < 0.0 or abs_tol < 0.0 {
        raise ValueError("tolerances must be non-negative");
    }
    if a.real == b.real and a.imag == b.imag {
        # short circuit exact equality -- needed to catch two infinities of
        # the same sign
        return True;
    }
    # catches opposite infinities, or one infinity and one finite number
    if (
        host_math.isinf(a.real)
        or host_math.isinf(a.imag)
        or host_math.isinf(b.real)
        or host_math.isinf(b.imag)
    ) {
        return False;
    }
    # the "weak" test from the Boost library
    (diff, _) = _c_abs(a.real - b.real, a.imag - b.imag);
    (abs_a, _) = _c_abs(a.real, a.imag);
    (abs_b, _) = _c_abs(b.real, b.imag);
    return (
        diff <= rel_tol * abs_b or diff <= rel_tol * abs_a or diff <= abs_tol
    );
}

def isfinite(z: complex) -> bool {
    return host_math.isfinite(z.real) and host_math.isfinite(z.imag);
}

def isinf(z: complex) -> bool {
    return host_math.isinf(z.real) or host_math.isinf(z.imag);
}

def isnan(z: complex) -> bool {
    return host_math.isnan(z.real) or host_math.isnan(z.imag);
}

def log(z: complex, base: any = None) -> complex {
    x = _c_log(complex(z));
    if base is not None {
        y = _c_log(complex(base));
        q = _c_quot(x[0], x[1], y[0], y[1]);
        _check_errno(q[2]);
        return complex(q[0], q[1]);
    }
    _check_errno(x[2]);
    return complex(x[0], x[1]);
}

def log10(z: complex) -> complex {
    r = _c_log(complex(z));
    # just in case the divisions affect errno
    _check_errno(r[2]);
    return complex(r[0] / _M_LN10, r[1] / _M_LN10);
}

def phase(z: complex) -> float {
    return host_math.atan2(z.imag, z.real);
}

def polar(z: complex) -> tuple[float, float] {
    phi = host_math.atan2(z.imag, z.real);
    (r, err) = _c_abs(z.real, z.imag);
    _check_errno(err);
    return (r, phi);
}

def rect(r: float, phi: float) -> complex {
    if not (host_math.isfinite(r) and host_math.isfinite(phi)) {
        if host_math.isinf(r) and host_math.isfinite(phi) and phi != 0.0 {
            # (+-INF +-INF i): signs come from cos(phi)/sin(phi)
            if r > 0 {
                re = host_math.copysign(_INF, host_math.cos(phi));
                im = host_math.copysign(_INF, host_math.sin(phi));
            } else {
                re = -host_math.copysign(_INF, host_math.cos(phi));
                im = -host_math.copysign(_INF, host_math.sin(phi));
            }
        } else {
            (re, im) = _sv_entry(_RECT_SV, complex(r, phi));
        }
        # errno = EDOM if r is a nonzero number and phi is infinite
        if r != 0.0 and not host_math.isnan(r) and host_math.isinf(phi) {
            raise ValueError("math domain error");
        }
    } elif phi == 0.0 {
        # workaround for buggy results with phi=-0.0 on some platforms
        re = r;
        im = r * phi;
    } else {
        re = r * host_math.cos(phi);
        im = r * host_math.sin(phi);
    }
    return complex(re, im);
}

def sin(z: complex) -> complex {
    # sin(z) = -i sinh(iz)
    s = _c_sinh(complex(-z.imag, z.real));
    _check_errno(s[2]);
    return complex(s[1], -s[0]);
}

def sinh(z: complex) -> complex {
    r = _c_sinh(complex(z));
    _check_errno(r[2]);
    return complex(r[0], r[1]);
}

def sqrt(z: complex) -> complex {
    r = _c_sqrt(complex(z));
    _check_errno(r[2]);
    return complex(r[0], r[1]);
}

def tan(z: complex) -> complex {
    # tan(z) = -i tanh(iz)
    s = _c_tanh(complex(-z.imag, z.real));
    _check_errno(s[2]);
    return complex(s[1], -s[0]);
}

def tanh(z: complex) -> complex {
    r = _c_tanh(complex(z));
    _check_errno(r[2]);
    return complex(r[0], r[1]);
}
