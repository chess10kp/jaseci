# Product-path facade for cmath (complex math).
# Port of CPython ``Modules/cmathmodule.c`` (3.14): every public entry mirrors
# the C implementation -- C99 Annex G algorithms, the 7x7 special-value tables
# for non-finite parts, subnormal/large-argument rescaling, and the errno
# contract (errno==EDOM -> ValueError("math domain error"), errno==ERANGE ->
# OverflowError("math range error")). Values run as host ``complex`` so
# arithmetic and complex division match _Py_c_* bit for bit.

import math;
import sys;

# ---------------- constants (cmath_exec module init) ----------------

glob pi: float = math.pi;
glob e: float = math.e;
glob tau: float = math.tau;
glob inf: float = math.inf;
glob nan: float = abs(float("nan"));
glob infj: complex = complex(0.0, math.inf);
glob nanj: complex = complex(0.0, float("nan"));

# ---------------- numeric limits (cmathmodule.c #defines) -------------

glob _LARGE: float = sys.float_info.max / 4.0;  # CM_LARGE_DOUBLE
glob _SQRT_LARGE: float = math.sqrt(_LARGE);  # CM_SQRT_LARGE_DOUBLE
glob _LOG_LARGE: float = math.log(_LARGE);  # CM_LOG_LARGE_DOUBLE
glob _SQRT_DBL_MIN: float = math.sqrt(sys.float_info.min);  # CM_SQRT_DBL_MIN
glob _LN2: float = math.log(2.0);  # M_LN2
glob _LN10: float = math.log(10.0);  # M_LN10
glob _MANT_DIG: int = sys.float_info.mant_dig;  # DBL_MANT_DIG
glob _DBL_MIN: float = sys.float_info.min;  # DBL_MIN
# Odd scale turning a subnormal into a normal (CM_SCALE_UP / CM_SCALE_DOWN).
glob _SCALE_UP: int = 2 * (_MANT_DIG // 2) + 1;
glob _SCALE_DOWN: int = -((_SCALE_UP + 1) // 2);
# Unlikely-value placeholder used by the reference tables for unreachable cells.
glob _U: float = -9.5426319407711027e33;

# ---------------- special values -------------------------------------
# special_type codes: ST_NINF, ST_NEG, ST_NZERO, ST_PZERO, ST_POS, ST_PINF, ST_NAN.

def _special_type(d: float) -> int {
    if math.isfinite(d) {
        if d != 0.0 {
            return 4 if math.copysign(1.0, d) == 1.0 else 1;
        }
        return 3 if math.copysign(1.0, d) == 1.0 else 2;
    }
    if math.isnan(d) {
        return 6;
    }
    return 5 if math.copysign(1.0, d) == 1.0 else 0;
}

# SPECIAL_VALUE macro: table lookup when either part is non-finite, else None.
def _sv(z: complex, table: list[list[complex]]) -> any {
    if not math.isfinite(z.real) or not math.isfinite(z.imag) {
        return table[_special_type(z.real)][_special_type(z.imag)];
    }
    return None;
}

glob _TABLES: dict[str, list[list[complex]]] = {};

def _tables() -> dict[str, list[list[complex]]] {
    if _TABLES {
        return _TABLES;
    }
    P = math.pi;
    P14 = 0.25 * P;
    P12 = 0.5 * P;
    P34 = 0.75 * P;
    INF = math.inf;
    N = float("nan");
    U = _U;
    c = complex;
    _TABLES["acos"] = [
        [c(P34, INF), c(P, INF), c(P, INF), c(P, -INF), c(P, -INF), c(P34, -INF), c(N, INF)],
        [c(P12, INF), c(U, U), c(U, U), c(U, U), c(U, U), c(P12, -INF), c(N, N)],
        [c(P12, INF), c(U, U), c(P12, 0.0), c(P12, -0.0), c(U, U), c(P12, -INF), c(P12, N)],
        [c(P12, INF), c(U, U), c(P12, 0.0), c(P12, -0.0), c(U, U), c(P12, -INF), c(P12, N)],
        [c(P12, INF), c(U, U), c(U, U), c(U, U), c(U, U), c(P12, -INF), c(N, N)],
        [c(P14, INF), c(0.0, INF), c(0.0, INF), c(0.0, -INF), c(0.0, -INF), c(P14, -INF), c(N, INF)],
        [c(N, INF), c(N, N), c(N, N), c(N, N), c(N, N), c(N, -INF), c(N, N)],
    ];
    _TABLES["acosh"] = [
        [c(INF, -P34), c(INF, -P), c(INF, -P), c(INF, P), c(INF, P), c(INF, P34), c(INF, N)],
        [c(INF, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P12), c(U, U), c(0.0, -P12), c(0.0, P12), c(U, U), c(INF, P12), c(N, P12)],
        [c(INF, -P12), c(U, U), c(0.0, -P12), c(0.0, P12), c(U, U), c(INF, P12), c(N, P12)],
        [c(INF, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P14), c(INF, -0.0), c(INF, -0.0), c(INF, 0.0), c(INF, 0.0), c(INF, P14), c(INF, N)],
        [c(INF, N), c(N, N), c(N, N), c(N, N), c(N, N), c(INF, N), c(N, N)],
    ];
    _TABLES["asinh"] = [
        [c(-INF, -P14), c(-INF, -0.0), c(-INF, -0.0), c(-INF, 0.0), c(-INF, 0.0), c(-INF, P14), c(-INF, N)],
        [c(-INF, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(-INF, P12), c(N, N)],
        [c(-INF, -P12), c(U, U), c(-0.0, -0.0), c(-0.0, 0.0), c(U, U), c(-INF, P12), c(N, N)],
        [c(INF, -P12), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P14), c(INF, -0.0), c(INF, -0.0), c(INF, 0.0), c(INF, 0.0), c(INF, P14), c(INF, N)],
        [c(INF, N), c(N, N), c(N, -0.0), c(N, 0.0), c(N, N), c(INF, N), c(N, N)],
    ];
    _TABLES["atanh"] = [
        [c(-0.0, -P12), c(-0.0, -P12), c(-0.0, -P12), c(-0.0, P12), c(-0.0, P12), c(-0.0, P12), c(-0.0, N)],
        [c(-0.0, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(-0.0, P12), c(N, N)],
        [c(-0.0, -P12), c(U, U), c(-0.0, -0.0), c(-0.0, 0.0), c(U, U), c(-0.0, P12), c(-0.0, N)],
        [c(0.0, -P12), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(0.0, P12), c(0.0, N)],
        [c(0.0, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(0.0, P12), c(N, N)],
        [c(0.0, -P12), c(0.0, -P12), c(0.0, -P12), c(0.0, P12), c(0.0, P12), c(0.0, P12), c(0.0, N)],
        [c(0.0, -P12), c(N, N), c(N, N), c(N, N), c(N, N), c(0.0, P12), c(N, N)],
    ];
    _TABLES["cosh"] = [
        [c(INF, N), c(U, U), c(INF, 0.0), c(INF, -0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(N, 0.0), c(U, U), c(1.0, 0.0), c(1.0, -0.0), c(U, U), c(N, 0.0), c(N, 0.0)],
        [c(N, 0.0), c(U, U), c(1.0, -0.0), c(1.0, 0.0), c(U, U), c(N, 0.0), c(N, 0.0)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(INF, N), c(U, U), c(INF, -0.0), c(INF, 0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(N, N), c(N, 0.0), c(N, 0.0), c(N, N), c(N, N), c(N, N)],
    ];
    _TABLES["exp"] = [
        [c(0.0, 0.0), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(0.0, 0.0), c(0.0, 0.0)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(N, N), c(U, U), c(1.0, -0.0), c(1.0, 0.0), c(U, U), c(N, N), c(N, N)],
        [c(N, N), c(U, U), c(1.0, -0.0), c(1.0, 0.0), c(U, U), c(N, N), c(N, N)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(INF, N), c(U, U), c(INF, -0.0), c(INF, 0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(N, N), c(N, -0.0), c(N, 0.0), c(N, N), c(N, N), c(N, N)],
    ];
    _TABLES["log"] = [
        [c(INF, -P34), c(INF, -P), c(INF, -P), c(INF, P), c(INF, P), c(INF, P34), c(INF, N)],
        [c(INF, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P12), c(U, U), c(-INF, -P), c(-INF, P), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P12), c(U, U), c(-INF, -0.0), c(-INF, 0.0), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P12), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, P12), c(N, N)],
        [c(INF, -P14), c(INF, -0.0), c(INF, -0.0), c(INF, 0.0), c(INF, 0.0), c(INF, P14), c(INF, N)],
        [c(INF, N), c(N, N), c(N, N), c(N, N), c(N, N), c(INF, N), c(N, N)],
    ];
    _TABLES["sinh"] = [
        [c(INF, N), c(U, U), c(-INF, -0.0), c(-INF, 0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(0.0, N), c(U, U), c(-0.0, -0.0), c(-0.0, 0.0), c(U, U), c(0.0, N), c(0.0, N)],
        [c(0.0, N), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(0.0, N), c(0.0, N)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(INF, N), c(U, U), c(INF, -0.0), c(INF, 0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(N, N), c(N, -0.0), c(N, 0.0), c(N, N), c(N, N), c(N, N)],
    ];
    _TABLES["sqrt"] = [
        [c(INF, -INF), c(0.0, -INF), c(0.0, -INF), c(0.0, INF), c(0.0, INF), c(INF, INF), c(N, INF)],
        [c(INF, -INF), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, INF), c(N, N)],
        [c(INF, -INF), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(INF, INF), c(N, N)],
        [c(INF, -INF), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(INF, INF), c(N, N)],
        [c(INF, -INF), c(U, U), c(U, U), c(U, U), c(U, U), c(INF, INF), c(N, N)],
        [c(INF, -INF), c(INF, -0.0), c(INF, -0.0), c(INF, 0.0), c(INF, 0.0), c(INF, INF), c(INF, N)],
        [c(INF, -INF), c(N, N), c(N, N), c(N, N), c(N, N), c(INF, INF), c(N, N)],
    ];
    _TABLES["tanh"] = [
        [c(-1.0, 0.0), c(U, U), c(-1.0, -0.0), c(-1.0, 0.0), c(U, U), c(-1.0, 0.0), c(-1.0, 0.0)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(-0.0, N), c(U, U), c(-0.0, -0.0), c(-0.0, 0.0), c(U, U), c(-0.0, N), c(-0.0, N)],
        [c(0.0, N), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(0.0, N), c(0.0, N)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(1.0, 0.0), c(U, U), c(1.0, -0.0), c(1.0, 0.0), c(U, U), c(1.0, 0.0), c(1.0, 0.0)],
        [c(N, N), c(N, N), c(N, -0.0), c(N, 0.0), c(N, N), c(N, N), c(N, N)],
    ];
    _TABLES["rect"] = [
        [c(INF, N), c(U, U), c(-INF, 0.0), c(-INF, -0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(0.0, 0.0), c(U, U), c(-0.0, 0.0), c(-0.0, -0.0), c(U, U), c(0.0, 0.0), c(0.0, 0.0)],
        [c(0.0, 0.0), c(U, U), c(0.0, -0.0), c(0.0, 0.0), c(U, U), c(0.0, 0.0), c(0.0, 0.0)],
        [c(N, N), c(U, U), c(U, U), c(U, U), c(U, U), c(N, N), c(N, N)],
        [c(INF, N), c(U, U), c(INF, -0.0), c(INF, 0.0), c(U, U), c(INF, N), c(INF, N)],
        [c(N, N), c(N, N), c(N, 0.0), c(N, 0.0), c(N, N), c(N, N), c(N, N)],
    ];
    return _TABLES;
}

# ---------------- core implementations (C99 Annex G) -------------------

def _sqrt_impl(z: complex) -> complex {
    # Reduce to nonnegative x/y, then s = sqrt((|z|+x)/2), d = (y/2)/s.
    # Large args rescale by 8 to avoid overflow; subnormals by 2**_SCALE_UP
    # to keep hypot() in the normal range.
    sv = _sv(z, _tables()["sqrt"]);
    if sv is not None {
        return sv;
    }
    if z.real == 0.0 and z.imag == 0.0 {
        return complex(0.0, z.imag);
    }
    ax: float = abs(z.real);
    ay: float = abs(z.imag);
    if ax < _DBL_MIN and ay < _DBL_MIN {
        ax = math.ldexp(ax, _SCALE_UP);
        s: float = math.ldexp(math.sqrt(ax + math.hypot(ax, math.ldexp(ay, _SCALE_UP))),
                       _SCALE_DOWN);
    } else {
        ax /= 8.0;
        s: float = 2.0 * math.sqrt(ax + math.hypot(ax, ay / 8.0));
    }
    d: float = ay / (2.0 * s);
    if z.real >= 0.0 {
        return complex(s, math.copysign(d, z.imag));
    }
    return complex(d, math.copysign(s, z.imag));
}

def _acos_impl(z: complex) -> complex {
    sv = _sv(z, _tables()["acos"]);
    if sv is not None {
        return sv;
    }
    if abs(z.real) > _LARGE or abs(z.imag) > _LARGE {
        # Avoid unnecessary overflow for large arguments.
        rr: float = math.atan2(abs(z.imag), z.real);
        ri: float = -math.copysign(math.log(math.hypot(z.real / 2.0, z.imag / 2.0)) + _LN2 * 2.0,
                                   z.imag);
    } else {
        s1 = _sqrt_impl(complex(1.0 - z.real, -z.imag));
        s2 = _sqrt_impl(complex(1.0 + z.real, z.imag));
        rr: float = 2.0 * math.atan2(s1.real, s2.real);
        ri: float = math.asinh(s2.real * s1.imag - s2.imag * s1.real);
    }
    return complex(rr, ri);
}

def _acosh_impl(z: complex) -> complex {
    sv = _sv(z, _tables()["acosh"]);
    if sv is not None {
        return sv;
    }
    if abs(z.real) > _LARGE or abs(z.imag) > _LARGE {
        rr: float = math.log(math.hypot(z.real / 2.0, z.imag / 2.0)) + _LN2 * 2.0;
        ri: float = math.atan2(z.imag, z.real);
    } else {
        s1 = _sqrt_impl(complex(z.real - 1.0, z.imag));
        s2 = _sqrt_impl(complex(z.real + 1.0, z.imag));
        rr: float = math.asinh(s1.real * s2.real + s1.imag * s2.imag);
        ri: float = 2.0 * math.atan2(s1.imag, s2.real);
    }
    return complex(rr, ri);
}

def _asinh_impl(z: complex) -> complex {
    sv = _sv(z, _tables()["asinh"]);
    if sv is not None {
        return sv;
    }
    if abs(z.real) > _LARGE or abs(z.imag) > _LARGE {
        if z.imag >= 0.0 {
            rr: float = math.copysign(math.log(math.hypot(z.real / 2.0, z.imag / 2.0)) + _LN2 * 2.0,
                                      z.real);
        } else {
            rr: float = -math.copysign(math.log(math.hypot(z.real / 2.0, z.imag / 2.0)) + _LN2 * 2.0,
                                       -z.real);
        }
        ri: float = math.atan2(z.imag, abs(z.real));
    } else {
        s1 = _sqrt_impl(complex(1.0 + z.imag, -z.real));
        s2 = _sqrt_impl(complex(1.0 - z.imag, z.real));
        rr: float = math.asinh(s1.real * s2.imag - s2.real * s1.imag);
        ri: float = math.atan2(z.imag, s1.real * s2.real - s1.imag * s2.imag);
    }
    return complex(rr, ri);
}

def _atanh_impl(z: complex) -> complex {
    sv = _sv(z, _tables()["atanh"]);
    if sv is not None {
        return sv;
    }
    # Reduce to z.real >= 0 using atanh(z) = -atanh(-z).
    if z.real < 0.0 {
        return -_atanh_impl(-z);
    }
    ay: float = abs(z.imag);
    if z.real > _SQRT_LARGE or ay > _SQRT_LARGE {
        # |z| large: atanh(z) ~ 1/z +/- i*pi/2 (+/- depending on sign of z.imag).
        h: float = math.hypot(z.real / 2.0, z.imag / 2.0);  # safe from overflow
        rr: float = z.real / 4.0 / h / h;
        ri: float = math.copysign(math.pi / 2.0, z.imag);
    } elif z.real == 1.0 and ay < _SQRT_DBL_MIN {
        # C99: atanh(1+/-0.) is inf +/- 0i -> EDOM.
        if ay == 0.0 {
            raise ValueError("math domain error");
        }
        rr: float = -math.log(math.sqrt(ay) / math.sqrt(math.hypot(ay, 2.0)));
        ri: float = math.copysign(math.atan2(2.0, -ay) / 2.0, z.imag);
    } else {
        rr: float = math.log1p(4.0 * z.real / ((1.0 - z.real) * (1.0 - z.real) + ay * ay)) / 4.0;
        ri: float = -math.atan2(-2.0 * z.imag, (1.0 - z.real) * (1.0 + z.real) - ay * ay) / 2.0;
    }
    return complex(rr, ri);
}

def _cosh_impl(z: complex) -> complex {
    if not math.isfinite(z.real) or not math.isfinite(z.imag) {
        # cosh(+/-inf + iy): signs come from cos/sin of the finite part.
        if math.isinf(z.real) and math.isfinite(z.imag) and z.imag != 0.0 {
            if z.real > 0 {
                r: complex = complex(math.copysign(math.inf, math.cos(z.imag)),
                                     math.copysign(math.inf, math.sin(z.imag)));
            } else {
                r: complex = complex(math.copysign(math.inf, math.cos(z.imag)),
                                     -math.copysign(math.inf, math.sin(z.imag)));
            }
        } else {
            r: complex = _tables()["cosh"][_special_type(z.real)][_special_type(z.imag)];
        }
        if math.isinf(z.imag) and not math.isnan(z.real) {
            raise ValueError("math domain error");
        }
        return r;
    }
    if abs(z.real) > _LOG_LARGE {
        # cosh(z.real) overflows but cosh(z) need not.
        x_minus_one: float = z.real - math.copysign(1.0, z.real);
        r: complex = complex(math.cos(z.imag) * math.cosh(x_minus_one) * math.e,
                             math.sin(z.imag) * math.sinh(x_minus_one) * math.e);
    } else {
        r: complex = complex(math.cos(z.imag) * math.cosh(z.real),
                             math.sin(z.imag) * math.sinh(z.real));
    }
    if math.isinf(r.real) or math.isinf(r.imag) {
        raise OverflowError("math range error");
    }
    return r;
}

def _sinh_impl(z: complex) -> complex {
    if not math.isfinite(z.real) or not math.isfinite(z.imag) {
        if math.isinf(z.real) and math.isfinite(z.imag) and z.imag != 0.0 {
            if z.real > 0 {
                r: complex = complex(math.copysign(math.inf, math.cos(z.imag)),
                                     math.copysign(math.inf, math.sin(z.imag)));
            } else {
                r: complex = complex(-math.copysign(math.inf, math.cos(z.imag)),
                                     math.copysign(math.inf, math.sin(z.imag)));
            }
        } else {
            r: complex = _tables()["sinh"][_special_type(z.real)][_special_type(z.imag)];
        }
        if math.isinf(z.imag) and not math.isnan(z.real) {
            raise ValueError("math domain error");
        }
        return r;
    }
    if abs(z.real) > _LOG_LARGE {
        x_minus_one = z.real - math.copysign(1.0, z.real);
        r: complex = complex(math.cos(z.imag) * math.sinh(x_minus_one) * math.e,
                             math.sin(z.imag) * math.cosh(x_minus_one) * math.e);
    } else {
        r: complex = complex(math.cos(z.imag) * math.sinh(z.real),
                             math.sin(z.imag) * math.cosh(z.real));
    }
    if math.isinf(r.real) or math.isinf(r.imag) {
        raise OverflowError("math range error");
    }
    return r;
}

def _exp_impl(z: complex) -> complex {
    if not math.isfinite(z.real) or not math.isfinite(z.imag) {
        if math.isinf(z.real) and math.isfinite(z.imag) and z.imag != 0.0 {
            if z.real > 0 {
                r = complex(math.copysign(math.inf, math.cos(z.imag)),
                            math.copysign(math.inf, math.sin(z.imag)));
            } else {
                r: complex = complex(math.copysign(0.0, math.cos(z.imag)),
                                 math.copysign(0.0, math.sin(z.imag)));
            }
        } else {
        r: complex = _tables()["exp"][_special_type(z.real)][_special_type(z.imag)];
        }
        if math.isinf(z.imag)
            and (math.isfinite(z.real) or (math.isinf(z.real) and z.real > 0)) {
            raise ValueError("math domain error");
        }
        return r;
    }
    if z.real > _LOG_LARGE {
        l: float = math.exp(z.real - 1.0);
        r: complex = complex(l * math.cos(z.imag) * math.e, l * math.sin(z.imag) * math.e);
    } else {
        l: float = math.exp(z.real);
        r: complex = complex(l * math.cos(z.imag), l * math.sin(z.imag));
    }
    if math.isinf(r.real) or math.isinf(r.imag) {
        raise OverflowError("math range error");
    }
    return r;
}

def _tanh_impl(z: complex) -> complex {
    # tanh(x+iy) = (tanh(x)(1+tan(y)^2) + i tan(y)(1-tanh(x))^2)
    #              / (1+tan(y)^2 tanh(x)^2)
    # with 1-tanh(x)^2 computed as 1/cosh(x)^2 (4*exp(-2|x|) when |x| large).
    if not math.isfinite(z.real) or not math.isfinite(z.imag) {
        if math.isinf(z.real) and math.isfinite(z.imag) and z.imag != 0.0 {
            sign: float = 1.0 if z.real > 0 else -1.0;
            r: complex = complex(sign, math.copysign(0.0, 2.0 * math.sin(z.imag) * math.cos(z.imag)));
        } else {
            r: complex = _tables()["tanh"][_special_type(z.real)][_special_type(z.imag)];
        }
        if math.isinf(z.imag) and math.isfinite(z.real) {
            raise ValueError("math domain error");
        }
        return r;
    }
    if abs(z.real) > _LOG_LARGE {
        ax: float = abs(z.real);
        r: complex = complex(math.copysign(1.0, z.real),
                             4.0 * math.sin(z.imag) * math.cos(z.imag) * math.exp(-2.0 * ax));
    } else {
        tx: float = math.tanh(z.real);
        ty: float = math.tan(z.imag);
        cx: float = 1.0 / math.cosh(z.real);
        txty: float = tx * ty;
        denom: float = 1.0 + txty * txty;
        r: complex = complex(tx * (1.0 + ty * ty) / denom, (ty / denom) * cx * cx);
    }
    return r;
}

def _c_log(z: complex) -> complex {
    # log(hypot(x, y)) is replaced by rescaled/log1p forms near 0, 1, and
    # DBL_MAX to keep full precision (see cmathmodule.c c_log comment).
    sv = _sv(z, _tables()["log"]);
    if sv is not None {
        return sv;
    }
    ax: float = abs(z.real);
    ay: float = abs(z.imag);
    if ax > _LARGE or ay > _LARGE {
        rr: float = math.log(math.hypot(ax / 2.0, ay / 2.0)) + _LN2;
    } elif ax < _DBL_MIN and ay < _DBL_MIN {
        if ax > 0.0 or ay > 0.0 {
            # Catch cases where hypot(ax, ay) is subnormal.
            rr: float = (math.log(math.hypot(math.ldexp(ax, _MANT_DIG),
                                      math.ldexp(ay, _MANT_DIG)))
                  - float(_MANT_DIG) * _LN2);
        } else {
            # log(+/-0 +/- 0i) -> EDOM.
            raise ValueError("math domain error");
        }
    } else {
        h: float = math.hypot(ax, ay);
        if 0.71 <= h and h <= 1.73 {
            am: float = ax if ax > ay else ay;  # max(ax, ay)
            an: float = ay if ax > ay else ax;  # min(ax, ay)
            rr: float = math.log1p((am - 1.0) * (am + 1.0) + an * an) / 2.0;
        } else {
            rr: float = math.log(h);
        }
    }
    return complex(rr, math.atan2(z.imag, z.real));
}

# ---------------- public API -------------------------------------------

def acos(z: complex) -> complex {
    return _acos_impl(complex(z));
}

def acosh(z: complex) -> complex {
    return _acosh_impl(complex(z));
}

def asin(z: complex) -> complex {
    # asin(z) = -i asinh(iz)
    s = _asinh_impl(complex(-z.imag, z.real));
    return complex(s.imag, -s.real);
}

def asinh(z: complex) -> complex {
    return _asinh_impl(complex(z));
}

def atan(z: complex) -> complex {
    # atan(z) = -i atanh(iz)
    s = _atanh_impl(complex(-z.imag, z.real));
    return complex(s.imag, -s.real);
}

def atanh(z: complex) -> complex {
    return _atanh_impl(complex(z));
}

def cos(z: complex) -> complex {
    # cos(z) = cosh(iz)
    return _cosh_impl(complex(-z.imag, z.real));
}

def cosh(z: complex) -> complex {
    return _cosh_impl(complex(z));
}

def sin(z: complex) -> complex {
    # sin(z) = -i sinh(iz)
    s = _sinh_impl(complex(-z.imag, z.real));
    return complex(s.imag, -s.real);
}

def sinh(z: complex) -> complex {
    return _sinh_impl(complex(z));
}

def tan(z: complex) -> complex {
    # tan(z) = -i tanh(iz)
    s = _tanh_impl(complex(-z.imag, z.real));
    return complex(s.imag, -s.real);
}

def tanh(z: complex) -> complex {
    return _tanh_impl(complex(z));
}

def exp(z: complex) -> complex {
    return _exp_impl(complex(z));
}

def sqrt(z: complex) -> complex {
    return _sqrt_impl(complex(z));
}

def log(z: any, base: any = None) -> complex {
    x: complex = _c_log(complex(z));
    if base is not None {
        x = x / _c_log(complex(base));
    }
    return x;
}

def log10(z: complex) -> complex {
    r = _c_log(complex(z));
    return complex(r.real / _LN10, r.imag / _LN10);
}

def phase(z: complex) -> float {
    return math.atan2(complex(z).imag, complex(z).real);
}

def polar(z: complex) -> tuple[float, float] {
    w = complex(z);
    phi: float = math.atan2(w.imag, w.real);
    r: float = math.hypot(w.real, w.imag);
    if math.isfinite(w.real) and math.isfinite(w.imag) and math.isinf(r) {
        raise OverflowError("math range error");
    }
    return (r, phi);
}

def rect(r: float, phi: float) -> complex {
    r = float(r);
    phi = float(phi);
    if not math.isfinite(r) or not math.isfinite(phi) {
        if math.isinf(r) and math.isfinite(phi) and phi != 0.0 {
            if r > 0 {
                z: complex = complex(math.copysign(math.inf, math.cos(phi)),
                                     math.copysign(math.inf, math.sin(phi)));
            } else {
                z: complex = complex(-math.copysign(math.inf, math.cos(phi)),
                                     -math.copysign(math.inf, math.sin(phi)));
            }
        } else {
            z: complex = _tables()["rect"][_special_type(r)][_special_type(phi)];
        }
        if r != 0.0 and not math.isnan(r) and math.isinf(phi) {
            raise ValueError("math domain error");
        }
        return z;
    }
    if phi == 0.0 {
        # Workaround for buggy results with phi=-0.0 (bugs.python.org/issue18513).
        return complex(r, r * phi);
    }
    return complex(r * math.cos(phi), r * math.sin(phi));
}

def isfinite(z: complex) -> bool {
    w = complex(z);
    return math.isfinite(w.real) and math.isfinite(w.imag);
}

def isnan(z: complex) -> bool {
    w = complex(z);
    return math.isnan(w.real) or math.isnan(w.imag);
}

def isinf(z: complex) -> bool {
    w = complex(z);
    return math.isinf(w.real) or math.isinf(w.imag);
}

def isclose(a: complex, b: complex, rel_tol: float = 1e-09, abs_tol: float = 0.0) -> bool {
    wa = complex(a);
    wb = complex(b);
    if rel_tol < 0.0 or abs_tol < 0.0 {
        raise ValueError("tolerances must be non-negative");
    }
    # Short-circuit exact equality: catches two infinities of the same sign.
    if wa == wb {
        return True;
    }
    # Opposite infinities, or one infinity and one finite number.
    if math.isinf(wa.real) or math.isinf(wa.imag)
        or math.isinf(wb.real) or math.isinf(wb.imag) {
        return False;
    }
    # The "weak" test from the Boost library.
    diff: float = abs(wa - wb);
    da: float = abs(wa);
    db: float = abs(wb);
    return (diff <= rel_tol * db or diff <= rel_tol * da) or diff <= abs_tol;
}
