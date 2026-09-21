import from _math_native {
    m_acos,
    m_acosh,
    m_asin,
    m_asinh,
    m_atan,
    m_atanh,
    m_atan2,
    m_cbrt,
    m_ceil,
    m_copysign,
    m_cos,
    m_cosh,
    m_erf,
    m_erfc,
    m_exp,
    m_exp2,
    m_expm1,
    m_fabs,
    m_floor,
    m_fma,
    m_fmod,
    m_lgamma,
    m_log,
    m_log2,
    m_log10,
    m_log1p,
    m_pow,
    m_remainder,
    m_sin,
    m_sinh,
    m_sqrt,
    m_tan,
    m_tanh,
    m_tgamma,
    m_trunc
}

glob:pub pi: float = 3.141592653589793,
     e: float = 2.718281828459045,
     tau: float = 6.283185307179586,
     inf: float = float("inf"),
     nan: float = float("nan");

def:pub isnan(x: float) -> bool {
    return x != x;
}


def:pub isinf(x: float) -> bool {
    return x == inf or x == -inf;
}


def:pub isfinite(x: float) -> bool {
    return not isnan(x) and not isinf(x);
}

# Internal libm-wrapper opcodes (int, not an enum: native enum member refs
# do not yet resolve reliably outside constant-folded comparisons).
# 0 acos, 1 acosh, 2 asin, 3 asinh, 4 atan, 5 atanh, 6 cbrt, 7 cos,
# 8 cosh, 9 erf, 10 erfc, 11 exp, 12 exp2, 13 expm1, 14 fabs, 15 gamma,
# 16 lgamma, 17 log1p, 18 sin, 19 sinh, 20 sqrt, 21 tan, 22 tanh,
# 23 atan2, 24 copysign, 25 fmod, 26 remainder, 27 pow.

def _domain_msg(op: int, x: float) -> str {
    if op == 0 or op == 2 {
        return "expected a number in range from -1 up to 1, got " + str(x);
    }
    if op == 1 {
        return "expected argument value not less than 1, got " + str(x);
    }
    if op == 5 {
        return "expected a number between -1 and 1, got " + str(x);
    }
    if op == 7 or op == 18 or op == 21 {
        return "expected a finite input, got " + str(x);
    }
    if op == 15 or op == 16 {
        return "expected a noninteger or positive integer, got " + str(x);
    }
    if op == 17 {
        return "expected argument value > -1, got " + str(x);
    }
    if op == 20 {
        return "expected a nonnegative input, got " + str(x);
    }
    return "math domain error";
}


def _check_unary(op: int, x: float, r: float) -> float {
    if isnan(r) and not isnan(x) {
        raise ValueError(_domain_msg(op, x));
    }
    if isinf(r) and isfinite(x) {
        if (op == 15 or op == 16) and x <= 0.0 and x == m_floor(x) {
            raise ValueError(_domain_msg(op, x));
        }
        if op == 8
            or op == 11
            or op == 12
            or op == 13
            or op == 15
            or op == 16
            or op == 19 {
            raise OverflowError("math range error");
        }
        raise ValueError(_domain_msg(op, x));
    }
    return r;
}

def:pub acos(x: float) -> float {
    return _check_unary(0, x, m_acos(x));
}


def:pub acosh(x: float) -> float {
    return _check_unary(1, x, m_acosh(x));
}


def:pub asin(x: float) -> float {
    return _check_unary(2, x, m_asin(x));
}


def:pub asinh(x: float) -> float {
    return _check_unary(3, x, m_asinh(x));
}


def:pub atan(x: float) -> float {
    return _check_unary(4, x, m_atan(x));
}


def:pub atanh(x: float) -> float {
    return _check_unary(5, x, m_atanh(x));
}


def:pub cbrt(x: float) -> float {
    return _check_unary(6, x, m_cbrt(x));
}


def:pub cos(x: float) -> float {
    return _check_unary(7, x, m_cos(x));
}


def:pub cosh(x: float) -> float {
    return _check_unary(8, x, m_cosh(x));
}


def:pub erf(x: float) -> float {
    return _check_unary(9, x, m_erf(x));
}


def:pub erfc(x: float) -> float {
    return _check_unary(10, x, m_erfc(x));
}


def:pub exp(x: float) -> float {
    return _check_unary(11, x, m_exp(x));
}


def:pub exp2(x: float) -> float {
    return _check_unary(12, x, m_exp2(x));
}


def:pub expm1(x: float) -> float {
    return _check_unary(13, x, m_expm1(x));
}


def:pub fabs(x: float) -> float {
    return _check_unary(14, x, m_fabs(x));
}


def:pub gamma(x: float) -> float {
    return _check_unary(15, x, m_tgamma(x));
}


def:pub lgamma(x: float) -> float {
    return _check_unary(16, x, m_lgamma(x));
}


def:pub log1p(x: float) -> float {
    return _check_unary(17, x, m_log1p(x));
}


def:pub sin(x: float) -> float {
    return _check_unary(18, x, m_sin(x));
}


def:pub sinh(x: float) -> float {
    return _check_unary(19, x, m_sinh(x));
}


def:pub sqrt(x: float) -> float {
    return _check_unary(20, x, m_sqrt(x));
}


def:pub tan(x: float) -> float {
    return _check_unary(21, x, m_tan(x));
}


def:pub tanh(x: float) -> float {
    return _check_unary(22, x, m_tanh(x));
}

def _float_to_int(r: float) -> int {
    if isnan(r) {
        raise ValueError("cannot convert float NaN to integer");
    }
    if isinf(r) {
        raise OverflowError("cannot convert float infinity to integer");
    }
    if r >= 9223372036854775808.0 or r < -9223372036854775808.0 {
        raise OverflowError("cannot convert float to integer");
    }
    return int(r);
}


def:pub ceil(x: float) -> int {
    return _float_to_int(m_ceil(x));
}


def:pub floor(x: float) -> int {
    return _float_to_int(m_floor(x));
}


def:pub trunc(x: float) -> int {
    return _float_to_int(m_trunc(x));
}

def _binary(op: int, x: float, y: float) -> float {
    r: float = 0.0;
    if op == 23 {
        r = m_atan2(x, y);
    } elif op == 24 {
        r = m_copysign(x, y);
    } elif op == 25 {
        r = m_fmod(x, y);
    } elif op == 26 {
        r = m_remainder(x, y);
    } else {
        r = m_pow(x, y);
    }
    if isnan(r) {
        if not isnan(x) and not isnan(y) {
            raise ValueError("math domain error");
        }
        return r;
    }
    if isinf(r) and isfinite(x) and isfinite(y) {
        if op == 27 and x == 0.0 {
            raise ValueError("math domain error");
        }
        raise OverflowError("math range error");
    }
    return r;
}


def:pub atan2(y: float, x: float) -> float {
    return _binary(23, y, x);
}


def:pub copysign(x: float, y: float) -> float {
    return _binary(24, x, y);
}


def:pub fmod(x: float, y: float) -> float {
    return _binary(25, x, y);
}


def:pub remainder(x: float, y: float) -> float {
    return _binary(26, x, y);
}


def:pub pow(x: float, y: float) -> float {
    return _binary(27, x, y);
}


def:pub fma(x: float, y: float, z: float) -> float {
    r = m_fma(x, y, z);
    if isnan(r) and not isnan(x) and not isnan(y) and not isnan(z) {
        raise ValueError("invalid operation in fma");
    }
    if isinf(r) and isfinite(x) and isfinite(y) and isfinite(z) {
        raise OverflowError("overflow in fma");
    }
    return r;
}

def:pub degrees(x: float) -> float {
    return x * 57.2957795130823208768;
}


def:pub radians(x: float) -> float {
    return x * 0.0174532925199432957692;
}


def:pub log(x: float, base: float | None = None) -> float {
    if x <= 0.0 {
        raise ValueError("expected a positive input, got " + str(x));
    }
    num = m_log(x);
    if base is None {
        return num;
    }
    if base <= 0.0 {
        raise ValueError("expected a positive input, got " + str(base));
    }
    den = m_log(base);
    if den == 0.0 {
        raise ZeroDivisionError("division by zero");
    }
    return num / den;
}


def:pub log2(x: float) -> float {
    if x <= 0.0 {
        raise ValueError("expected a positive input, got " + str(x));
    }
    return m_log2(x);
}


def:pub log10(x: float) -> float {
    if x <= 0.0 {
        raise ValueError("expected a positive input, got " + str(x));
    }
    return m_log10(x);
}

def:pub factorial(n: int) -> int {
    if n < 0 {
        raise ValueError("factorial() not defined for negative values");
    }
    if n > 20 {
        raise OverflowError("factorial() result too large");
    }
    r: int = 1;
    for i in range(2, n + 1) {
        r *= i;
    }
    return r;
}


def:pub isqrt(n: int) -> int {
    if n < 0 {
        raise ValueError("isqrt() argument must be nonnegative");
    }
    if n < 2 {
        return n;
    }
    x = n // 2 + 1;
    y = (x + n // x) // 2;
    while y < x {
        x = y;
        y = (x + n // x) // 2;
    }
    return x;
}


def _gcd(a: int, b: int) -> int {
    x: int = a;
    if x < 0 {
        x = -x;
    }
    y: int = b;
    if y < 0 {
        y = -y;
    }
    while y != 0 {
        t = y;
        y = x % y;
        x = t;
    }
    return x;
}


def _gcd_all(*ints: int) -> int {
    r: int = 0;
    for v in ints {
        r = _gcd(r, v);
    }
    return r;
}


# Bounded-arity surface: the interop bridge cannot marshal a parameter pack,
# so the variadic fold stays private behind defaulted extras (same pattern as
# os.path.join). 0 is the gcd identity, so omitted slots are no-ops and the
# zero-argument call still answers 0 like CPython.
def:pub gcd(
    a: int = 0,
    b: int = 0,
    p1: int = 0,
    p2: int = 0,
    p3: int = 0,
    p4: int = 0,
    p5: int = 0,
    p6: int = 0,
    p7: int = 0,
    p8: int = 0
) -> int {
    return _gcd_all(a, b, p1, p2, p3, p4, p5, p6, p7, p8);
}


def _lcm_all(*ints: int) -> int {
    r: int = 1;
    for v in ints {
        if v < 0 {
            v = -v;
        }
        if r == 0 or v == 0 {
            r = 0;
            continue;
        }
        q = r // _gcd(r, v);
        if v > 9223372036854775807 // q {
            raise OverflowError("lcm() result too large");
        }
        r = q * v;
    }
    return r;
}


# 1 is the lcm identity, so omitted slots are no-ops and the zero-argument
# call still answers 1 like CPython.
def:pub lcm(
    a: int = 1,
    b: int = 1,
    p1: int = 1,
    p2: int = 1,
    p3: int = 1,
    p4: int = 1,
    p5: int = 1,
    p6: int = 1,
    p7: int = 1,
    p8: int = 1
) -> int {
    return _lcm_all(a, b, p1, p2, p3, p4, p5, p6, p7, p8);
}


def:pub comb(n: int, k: int) -> int {
    if n < 0 {
        raise ValueError("n must be a non-negative integer");
    }
    if k < 0 {
        raise ValueError("k must be a non-negative integer");
    }
    if k > n {
        return 0;
    }
    kk = k;
    if n - k < kk {
        kk = n - k;
    }
    r: int = 1;
    for i in range(kk) {
        g = _gcd(r, i + 1);
        rp = r // g;
        c = (i + 1) // g;
        m = (n - i) // c;
        if m != 0 and rp > 9223372036854775807 // m {
            raise OverflowError("comb() result too large");
        }
        r = rp * m;
    }
    return r;
}


def:pub perm(n: int, k: int | None = None) -> int {
    if n < 0 {
        raise ValueError("n must be a non-negative integer");
    }
    if k is None {
        return factorial(n);
    }
    if k < 0 {
        raise ValueError("k must be a non-negative integer");
    }
    if k > n {
        return 0;
    }
    r: int = 1;
    for i in range(k) {
        f = n - i;
        if r > 9223372036854775807 // f {
            raise OverflowError("perm() result too large");
        }
        r *= f;
    }
    return r;
}

def:pub frexp(x: float) -> tuple[(float, int)] {
    if x == 0.0 or not isfinite(x) {
        return (x, 0);
    }
    b = __float_bits(x);
    mag = b & 9223372036854775807;
    expo = mag >> 52;
    if expo == 0 {
        (f2, e2) = frexp(x * 18446744073709551616.0);
        return (f2, e2 - 64);
    }
    mant = mag & 4503599627370495;
    nb = (b & (1 << 63)) | 4602678819172646912 | mant;
    return (__bits_float(nb), expo - 1022);
}


def:pub modf(x: float) -> tuple[(float, float)] {
    if isnan(x) {
        return (x, x);
    }
    if isinf(x) {
        return (m_copysign(0.0, x), x);
    }
    ip = m_trunc(x);
    fp = x - ip;
    if fp == 0.0 {
        fp = m_copysign(0.0, x);
    }
    return (fp, ip);
}


def:pub ldexp(x: float, i: int) -> float {
    if x == 0.0 or not isfinite(x) {
        return x;
    }

    if i > 2098 {
        raise OverflowError("math range error");
    }
    if i < -2098 {
        return m_copysign(0.0, x);
    }
    (mf, expo) = frexp(x);
    n = expo + i;
    b = __float_bits(mf);
    sgn = b & (1 << 63);
    mant = b & 4503599627370495;
    if n > 1024 {
        raise OverflowError("math range error");
    }
    if n >= -1021 {
        return __bits_float(sgn | ((n + 1022) << 52) | mant);
    }

    f = mant | 4503599627370496;
    s = -n - 1021;
    if s >= 54 {
        return __bits_float(sgn);
    }
    mant2 = f >> s;
    rem = f - (mant2 << s);
    half = 1 << (s - 1);
    if rem > half or (rem == half and (mant2 & 1) == 1) {
        mant2 += 1;
    }
    return __bits_float(sgn | mant2);
}


def:pub nextafter(x: float, y: float, *, steps: int = 1) -> float {
    if steps < 0 {
        raise ValueError("steps must be a non-negative integer");
    }
    count = steps;
    if count == 0 {
        return x;
    }
    if x == y {
        return y;
    }
    if isnan(x) {
        return x;
    }
    if isnan(y) {
        return y;
    }
    sgn_mask = 1 << 63;
    mag_mask = 9223372036854775807;
    first = __float_bits(x);
    last = __float_bits(y);
    fm = first & mag_mask;
    lm = last & mag_mask;
    fs = first & sgn_mask;
    ls = last & sgn_mask;
    if fs != ls {
        if count <= fm {
            return __bits_float(fs | (fm - count));
        }
        rem = count - fm;
        if rem >= lm {
            return y;
        }
        return __bits_float(ls | rem);
    }
    delta = fm - lm if fm > lm else lm - fm;
    if count >= delta {
        return y;
    }
    rb = first - count if fm > lm else first + count;
    return __bits_float(rb);
}


def:pub ulp(x: float) -> float {
    if isnan(x) {
        return x;
    }
    x = m_fabs(x);
    if isinf(x) {
        return x;
    }
    following = nextafter(x, inf);
    if isinf(following) {
        return x - nextafter(x, -inf);
    }
    return following - x;
}

def:pub fsum[T](data: list[T]) -> float {
    partials: list[float] = [];
    special: float = 0.0;
    infinities: float = 0.0;
    low: float = 0.0;
    for item in data {
        x = float(item);
        original = x;
        count = 0;
        for j in range(len(partials)) {
            y = partials[j];
            if m_fabs(x) < m_fabs(y) {
                tmp = x;
                x = y;
                y = tmp;
            }
            high = x + y;
            rounded = high - x;
            low = y - rounded;
            if low != 0.0 {
                partials[count] = low;
                count += 1;
            }
            x = high;
        }
        while len(partials) > count {
            partials.pop();
        }
        if x != 0.0 {
            if not isfinite(x) {
                if isfinite(original) {
                    raise OverflowError("intermediate overflow in fsum");
                }
                if isinf(original) {
                    infinities += original;
                }
                special += original;
                partials.clear();
            } else {
                partials.append(x);
            }
        }
    }
    if special != 0.0 {
        if isnan(infinities) {
            raise ValueError("-inf + inf in fsum");
        }
        return special;
    }
    high: float = 0.0;
    if len(partials) > 0 {
        high = partials.pop();
        while len(partials) > 0 {
            x = high;
            y = partials.pop();
            high = x + y;
            rounded = high - x;
            low = y - rounded;
            if low != 0.0 {
                break;
            }
        }
        if len(partials) > 0
            and (
                (low < 0.0 and partials[-1] < 0.0) or (low > 0.0 and partials[-1] > 0.0)
            ) {
            y = low * 2.0;
            x = high + y;
            rounded = x - high;
            if y == rounded {
                high = x;
            }
        }
    }
    return high;
}

def _double_sum(a: float, b: float) -> tuple[(float, float)] {
    high = a + b;
    rounded = high - a;
    return (high, (a - (high - rounded)) + (b - rounded));
}


def _fast_sum(a: float, b: float) -> tuple[(float, float)] {
    high = a + b;
    return (high, (a - high) + b);
}


def _double_product(a: float, b: float) -> tuple[(float, float)] {
    high = a * b;
    return (high, m_fma(a, b, -high));
}


def _triple_product(
    a: float, b: float, total: tuple[(float, float, float)]
) -> tuple[(float, float, float)] {
    product = _double_product(a, b);
    high = _double_sum(total[0], product[0]);
    first = _double_sum(total[1], product[1]);
    second = _double_sum(first[0], high[1]);
    return (high[0], second[0], total[2] + first[1] + second[1]);
}


def _triple_value(total: tuple[(float, float, float)]) -> float {
    last = _double_sum(total[1], total[0]);
    return total[2] + last[1] + last[0];
}


def _norm(values: list[float], largest: float, found_nan: bool) -> float {
    if isinf(largest) {
        return largest;
    }
    if found_nan {
        return nan;
    }
    if largest == 0.0 or len(values) <= 1 {
        return largest;
    }
    (frac, power) = frexp(largest);
    if power < -1023 {
        for i in range(len(values)) {
            values[i] = values[i] / 2.2250738585072014e-308;
        }
        return 2.2250738585072014e-308
            * _norm(values, largest / 2.2250738585072014e-308, found_nan);
    }
    scale = ldexp(1.0, -power);
    total: float = 1.0;
    fraction1: float = 0.0;
    fraction2: float = 0.0;
    for value in values {
        x = value * scale;
        product = _double_product(x, x);
        addition = _fast_sum(total, product[0]);
        total = addition[0];
        fraction1 += product[1];
        fraction2 += addition[1];
    }
    result = m_sqrt(total - 1.0 + (fraction1 + fraction2));
    correction = _double_product(-result, result);
    addition = _fast_sum(total, correction[0]);
    total = addition[0];
    fraction1 += correction[1];
    fraction2 += addition[1];
    residual = total - 1.0 + (fraction1 + fraction2);
    result += residual / (2.0 * result);
    return result / scale;
}


def _hypot_all(*coords: float) -> float {
    values: list[float] = [];
    largest: float = 0.0;
    found_nan = False;
    for v in coords {
        x = m_fabs(v);
        values.append(x);
        found_nan = found_nan or isnan(x);
        if x > largest {
            largest = x;
        }
    }
    return _norm(values, largest, found_nan);
}


# 0.0 is the hypot identity, so omitted slots are no-ops and the
# zero-argument call still answers 0.0 like CPython.
def:pub hypot(
    a: float = 0.0,
    b: float = 0.0,
    p1: float = 0.0,
    p2: float = 0.0,
    p3: float = 0.0,
    p4: float = 0.0,
    p5: float = 0.0,
    p6: float = 0.0,
    p7: float = 0.0,
    p8: float = 0.0
) -> float {
    return _hypot_all(a, b, p1, p2, p3, p4, p5, p6, p7, p8);
}


def:pub dist[T](p: list[T], q: list[T]) -> float {
    if len(p) != len(q) {
        raise ValueError("both points must have the same number of dimensions");
    }
    values: list[float] = [];
    largest: float = 0.0;
    found_nan = False;
    for i in range(len(p)) {
        d = m_fabs(float(p[i]) - float(q[i]));
        values.append(d);
        found_nan = found_nan or isnan(d);
        if d > largest {
            largest = d;
        }
    }
    return _norm(values, largest, found_nan);
}


def _imul_fits(a: int, b: int) -> bool {
    hi = 9223372036854775807;
    lo = -9223372036854775807 - 1;
    if a == 0 or b == 0 or a == 1 or b == 1 {
        return True;
    }
    if a == lo or b == lo {
        return False;
    }
    aa = a if a > 0 else -a;
    bb = b if b > 0 else -b;
    lim = hi // bb;

    if (a < 0) != (b < 0) and hi % bb == bb - 1 {
        lim += 1;
    }
    return aa <= lim;
}


def _iadd_fits(a: int, b: int) -> bool {
    hi = 9223372036854775807;
    lo = -9223372036854775807 - 1;
    return (b <= 0 or a <= hi - b) and (b >= 0 or a >= lo - b);
}


def:pub prod[T](data: list[T], *, start: int | float = 1) -> any {
    ri: int = 1;
    rf: float = 1.0;
    isint = True;
    s = start;
    if isinstance(s, int) {
        si: int = s;
        ri = si;
    } else {
        rf = float(s);
        isint = False;
    }
    for v in data {
        if isint {
            if isinstance(v, int) {
                iv: int = v;
                if _imul_fits(ri, iv) {
                    ri *= iv;
                } else {
                    raise OverflowError("prod() result too large");
                }
            } else {
                rf = float(ri) * float(v);
                isint = False;
            }
        } else {
            rf *= float(v);
        }
    }
    if isint {
        return ri;
    }
    return rf;
}


def:pub sumprod[T](p: list[T], q: list[T]) -> any {
    if len(p) != len(q) {
        raise ValueError("Inputs are not the same length");
    }
    total: tuple[(float, float, float)] = (0.0, 0.0, 0.0);
    ri: int = 0;
    isint = True;
    for i in range(len(p)) {
        x = p[i];
        y = q[i];
        if isint {
            if isinstance(x, int) and isinstance(y, int) {
                xi: int = x;
                yi: int = y;
                if _imul_fits(xi, yi) {
                    t = xi * yi;
                    if _iadd_fits(ri, t) {
                        ri += t;
                    } else {
                        raise OverflowError("sumprod() result too large");
                    }
                } else {
                    raise OverflowError("sumprod() result too large");
                }
            } else {
                isint = False;
            }
            if not isint {
                total = _triple_product(float(ri), 1.0, total);
            }
        }
        if not isint {
            total = _triple_product(float(x), float(y), total);
        }
    }
    if isint {
        return ri;
    }
    return _triple_value(total);
}


def:pub isclose(
    a: float, b: float, *, rel_tol: float = 1e-9, abs_tol: float = 0.0
) -> bool {
    if rel_tol < 0.0 or abs_tol < 0.0 {
        raise ValueError("tolerances must be non-negative");
    }
    if a == b {
        return True;
    }
    if isinf(a) or isinf(b) {
        return False;
    }
    diff = m_fabs(b - a);
    return diff <= abs_tol
        or diff <= m_fabs(rel_tol * a)
        or diff <= m_fabs(rel_tol * b);
}
