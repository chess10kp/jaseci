# Product-path facade for math (float transcendentals + integer kernels).
# Semantics mirror CPython 3.14 ``Modules/mathmodule.c`` exercised by
# CPython's ``test_math``.
#
# Split of responsibilities, mirroring the C module's own structure:
#   * Libm float surface (acos..ulp): in the C module these are thin
#     clinic wrappers over libm with the errno discipline
#     (EDOM -> ValueError "math domain error", ERANGE ->
#     OverflowError "math range error"). The wrappers below are pure
#     ``*args`` trampolines onto the host math module, which IS that C
#     code -- arity, argument-coercion, and error messages therefore stay
#     byte-exact instead of being re-approximated here.
#   * Integer kernels (gcd/lcm/isqrt/perm/comb/factorial/fsum/prod/dist):
#     direct lifts of the corresponding math_*_impl algorithms, operating
#     on arbitrary-precision ints after a PyNumber_Index-style coercion.
#
# The host bridge goes through importlib because a bare ``import math``
# inside this package resolves same-directory first and would re-enter
# this very module now that jacpython/math.jac exists (the resolver tries
# ``<importer dir>/<name>.jac`` before the stdlib). Consumers in this
# directory that ``import math`` get this facade; every name it exports
# delegates to the identical host implementation, so cmath.jac's
# ``host_math`` usage keeps its exact semantics.

import from importlib { import_module }

# Host libm bridge (see header note).
glob _hm: any = import_module("math");

# ---------------- module constants (math_exec) ----------------

glob pi: float = 3.141592653589793;
glob e: float = 2.718281828459045;
glob tau: float = 6.283185307179586;
glob inf: float = float("inf");
glob nan: float = float("nan");

# ---------------- libm surface (math_1 / math_2 wrappers) ----------------

def acos(*args: any) -> any {
    return _hm.acos(*args);
}

def acosh(*args: any) -> any {
    return _hm.acosh(*args);
}

def asin(*args: any) -> any {
    return _hm.asin(*args);
}

def asinh(*args: any) -> any {
    return _hm.asinh(*args);
}

def atan(*args: any) -> any {
    return _hm.atan(*args);
}

def atan2(*args: any) -> any {
    return _hm.atan2(*args);
}

def atanh(*args: any) -> any {
    return _hm.atanh(*args);
}

def cbrt(*args: any) -> any {
    return _hm.cbrt(*args);
}

def ceil(*args: any) -> any {
    return _hm.ceil(*args);
}

def copysign(*args: any) -> any {
    return _hm.copysign(*args);
}

def cos(*args: any) -> any {
    return _hm.cos(*args);
}

def cosh(*args: any) -> any {
    return _hm.cosh(*args);
}

def degrees(*args: any) -> any {
    return _hm.degrees(*args);
}

def erf(*args: any) -> any {
    return _hm.erf(*args);
}

def erfc(*args: any) -> any {
    return _hm.erfc(*args);
}

def exp(*args: any) -> any {
    return _hm.exp(*args);
}

def exp2(*args: any) -> any {
    return _hm.exp2(*args);
}

def expm1(*args: any) -> any {
    return _hm.expm1(*args);
}

def fabs(*args: any) -> any {
    return _hm.fabs(*args);
}

def floor(*args: any) -> any {
    return _hm.floor(*args);
}

def fma(*args: any) -> any {
    return _hm.fma(*args);
}

def fmod(*args: any) -> any {
    return _hm.fmod(*args);
}

def frexp(*args: any) -> any {
    return _hm.frexp(*args);
}

def gamma(*args: any) -> any {
    return _hm.gamma(*args);
}

def hypot(*args: any) -> any {
    return _hm.hypot(*args);
}

def isclose(*args: any, **kwargs: any) -> any {
    return _hm.isclose(*args, **kwargs);
}

def isfinite(*args: any) -> any {
    return _hm.isfinite(*args);
}

def isinf(*args: any) -> any {
    return _hm.isinf(*args);
}

def isnan(*args: any) -> any {
    return _hm.isnan(*args);
}

def ldexp(*args: any) -> any {
    return _hm.ldexp(*args);
}

def lgamma(*args: any) -> any {
    return _hm.lgamma(*args);
}

def log(*args: any) -> any {
    return _hm.log(*args);
}

def log10(*args: any) -> any {
    return _hm.log10(*args);
}

def log1p(*args: any) -> any {
    return _hm.log1p(*args);
}

def log2(*args: any) -> any {
    return _hm.log2(*args);
}

def modf(*args: any) -> any {
    return _hm.modf(*args);
}

def nextafter(*args: any) -> any {
    return _hm.nextafter(*args);
}

def pow(*args: any) -> any {
    return _hm.pow(*args);
}

def radians(*args: any) -> any {
    return _hm.radians(*args);
}

def remainder(*args: any) -> any {
    return _hm.remainder(*args);
}

def sin(*args: any) -> any {
    return _hm.sin(*args);
}

def sinh(*args: any) -> any {
    return _hm.sinh(*args);
}

def sqrt(*args: any) -> any {
    return _hm.sqrt(*args);
}

def sumprod(*args: any) -> any {
    return _hm.sumprod(*args);
}

def tan(*args: any) -> any {
    return _hm.tan(*args);
}

def tanh(*args: any) -> any {
    return _hm.tanh(*args);
}

def trunc(*args: any) -> any {
    return _hm.trunc(*args);
}

def ulp(*args: any) -> any {
    return _hm.ulp(*args);
}

# ---------------- integer kernels ----------------

# Mirrors PyNumber_Index argument discipline for the kernels below:
# exact ints pass through, objects exposing __index__ coerce, everything
# else raises CPython's integer-coercion TypeError.
def _index(x: any) -> int {
    if isinstance(x, bool) {
        return int(x);
    }
    if isinstance(x, int) {
        return x;
    }
    try {
        return x.__index__();
    } except AttributeError {
        raise TypeError(
            "'" + type(x).__name__ + "' object cannot be interpreted as an integer"
        );
    }
}

# Stein's binary GCD -- same algorithm family as _PyLong_GCD behind
# math_gcd_impl; exact on arbitrary-precision ints.
def _gcd2(a: int, b: int) -> int {
    if a == 0 {
        return b;
    }
    if b == 0 {
        return a;
    }
    shift: int = 0;
    t: int = 0;
    while ((a | b) & 1) == 0 {
        a >>= 1;
        b >>= 1;
        shift += 1;
    }
    while (a & 1) == 0 {
        a >>= 1;
    }
    while b != 0 {
        while (b & 1) == 0 {
            b >>= 1;
        }
        if a > b {
            t = a;
            a = b;
            b = t;
        }
        b = b - a;
    }
    return a << shift;
}

# math_gcd_impl: variadic fold; gcd() == 0, single arg folds through abs.
def gcd(*integers: any) -> int {
    n: int = len(integers);
    if n == 0 {
        return 0;
    }
    res: int = abs(_index(integers[0]));
    for i in range(1, n) {
        if res == 1 {
            continue;
        }
        res = _gcd2(res, abs(_index(integers[i])));
    }
    return res;
}

# long_lcm + math_lcm_impl: lcm() == 1, zero annihilates the fold.
def lcm(*integers: any) -> int {
    n: int = len(integers);
    if n == 0 {
        return 1;
    }
    res: int = abs(_index(integers[0]));
    for i in range(1, n) {
        if res == 0 {
            continue;
        }
        x: int = abs(_index(integers[i]));
        if x == 0 {
            return 0;
        }
        res = res // _gcd2(res, x) * x;
    }
    return res;
}

# math_isqrt: nonnegative floor square root. Newton iteration on ints --
# different iteration scheme than the C adaptive-precision variant, but
# the exact same floor-sqrt semantics on every input.
def isqrt(n: any) -> int {
    x: int = _index(n);
    if x < 0 {
        raise ValueError("isqrt() argument must be nonnegative");
    }
    if x == 0 {
        return 0;
    }
    a: int = x;
    b: int = (a + 1) // 2;
    while b < a {
        a = b;
        b = (a + x // a) // 2;
    }
    return a;
}

# math_factorial: negative input is a domain error; product is exact.
def factorial(x: any) -> int {
    n: int = _index(x);
    if n < 0 {
        raise ValueError("factorial() not defined for negative values");
    }
    result: int = 1;
    for i in range(2, n + 1) {
        result *= i;
    }
    return result;
}

# math_perm_impl: perm(n) == factorial(n); perm(n, k) falls back to 0
# when n < k, domain-errors on negative arguments.
def perm(n: any, k: any = None) -> int {
    if k is None {
        return factorial(n);
    }
    ni: int = _index(n);
    ki: int = _index(k);
    if ni < 0 {
        raise ValueError("n must be a non-negative integer");
    }
    if ki < 0 {
        raise ValueError("k must be a non-negative integer");
    }
    if ni < ki {
        return 0;
    }
    result: int = 1;
    for i in range(ni - ki + 1, ni + 1) {
        result *= i;
    }
    return result;
}

# math_comb_impl: multiplicative binomial with interleaved exact division;
# zero when k > n, domain-errors on negative arguments.
def comb(n: any, k: any) -> int {
    ni: int = _index(n);
    ki: int = _index(k);
    if ni < 0 {
        raise ValueError("n must be a non-negative integer");
    }
    if ki < 0 {
        raise ValueError("k must be a non-negative integer");
    }
    if ki > ni {
        return 0;
    }
    ki = min(ki, ni - ki);
    result: int = 1;
    for i in range(1, ki + 1) {
        result = result * (ni - ki + i) // i;
    }
    return result;
}

# math_fsum: exact summation via Shewchuk's partials algorithm, lifted
# statement-for-statement from the C body (grow-as-needed partials list,
# intermediate-overflow and -inf + inf checks, half-even fix-up across
# partials at the end).
def fsum(seq: any) -> float {
    p: list[float] = [];
    special_sum: float = 0.0;
    inf_sum: float = 0.0;
    lo: float = 0.0;
    x: float = 0.0;
    y: float = 0.0;
    t: float = 0.0;
    hi: float = 0.0;
    yr: float = 0.0;
    for item in seq {
        x = float(item);
        xsave: float = x;
        i: int = 0;
        j: int = 0;
        while j < len(p) {
            y = p[j];
            if _hm.fabs(x) < _hm.fabs(y) {
                t = x;
                x = y;
                y = t;
            }
            hi = x + y;
            yr = hi - x;
            lo = y - yr;
            if lo != 0.0 {
                p[i] = lo;
                i += 1;
            }
            x = hi;
            j += 1;
        }
        p = p[:i];
        if x != 0.0 {
            if not _hm.isfinite(x) {
                # A nonfinite x arises either from intermediate overflow or
                # from a nan/inf summand; distinguish exactly like the C.
                if _hm.isfinite(xsave) {
                    raise OverflowError("intermediate overflow in fsum");
                }
                if _hm.isinf(xsave) {
                    inf_sum += xsave;
                }
                special_sum += xsave;
            } else {
                p.append(x);
            }
        }
    }
    if special_sum != 0.0 {
        if _hm.isnan(inf_sum) {
            raise ValueError("-inf + inf in fsum");
        }
        return special_sum;
    }
    hi_final: float = 0.0;
    n: int = len(p);
    x2: float = 0.0;
    y2: float = 0.0;
    yr2: float = 0.0;
    y3: float = 0.0;
    x3: float = 0.0;
    yr3: float = 0.0;
    if n > 0 {
        hi_final = p[n - 1];
        n -= 1;
        # Sum exact from the top; stop once the running total is precise.
        while n > 0 {
            x2 = hi_final;
            y2 = p[n - 1];
            n -= 1;
            hi_final = x2 + y2;
            yr2 = hi_final - x2;
            lo = y2 - yr2;
            if lo != 0.0 {
                break;
            }
        }
        # Half-even rounding across multiple partials (see C comment).
        if n > 0 and ((lo < 0.0 and p[n - 1] < 0.0) or (lo > 0.0 and p[n - 1] > 0.0)) {
            y3 = lo * 2.0;
            x3 = hi_final + y3;
            yr3 = x3 - hi_final;
            if y3 == yr3 {
                hi_final = x3;
            }
        }
    }
    return hi_final;
}

# math_prod_impl: iterable product with optional start value; numeric
# tower semantics fall out of Python multiplication itself.
def prod(iterable: any, start: any = 1) -> any {
    result: any = start;
    for x in iterable {
        result = result * x;
    }
    return result;
}

# math_dist_impl: euclidean distance folding pairwise coordinate
# differences through hypot(); dimension mismatch is a ValueError.
def dist(p: any, q: any) -> float {
    ip: any = p.__iter__();
    iq: any = q.__iter__();
    acc: float = 0.0;
    while True {
        try {
            x: any = ip.__next__();
        } except StopIteration {
            break;
        }
        try {
            y: any = iq.__next__();
        } except StopIteration {
            raise ValueError("both points must have the same number of dimensions");
        }
        acc = _hm.hypot(acc, x - y);
    }
    try {
        iq.__next__();
    } except StopIteration {
        return acc;
    }
    raise ValueError("both points must have the same number of dimensions");
}
