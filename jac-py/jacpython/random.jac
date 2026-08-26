# Product-path facade for the random PYTHON layer (CPython 3.14
# ``Lib/random.py``) exercised by Lib/test/test_random.py.
#
# ``_randommodule.jac`` carries the C-accelerator truth
# (Modules/_randommodule.c wave 18): the MT19937 kernel, seeding, and the
# raw random()/getrandbits()/getstate/setstate surface. This module lifts
# everything random.py itself owns on top of it: the versioned seed
# conversion (sha512 for str/bytes/bytearray, legacy version=1), the
# version-3 state tuple, the integer/sequence methods (randrange family,
# choice/shuffle/sample/choices) and every custom distribution
# (normalvariate through binomialvariate), plus the SystemRandom
# os.urandom core and the module-level singleton delegation.
#
# REPRESENTATION CHOICES (divergence ledger candidates):
# - Jac objs have no constructor hook and no class objects, so
#   ``random.Random(x)`` / ``random.SystemRandom()`` construction surfaces
#   as the factories ``new_random(x)`` / ``new_system_random()``; a bare
#   ``Random()`` carries an unseeded core (core=None) exactly like a bare
#   ``_random.Random`` archetype and must be seeded before use.
# - Inheritance (Lib Random(_random.Random)) becomes composition: the MT
#   core is held in the ``core`` field. Subclassing test legs
#   (Subclass(random.Random)) have no surface yet.
# - Keyword-only parameters (sample(counts=...), choices(cum_weights=...))
#   are positional-or-keyword here; misused positional forms raise the
#   same TypeError up front instead of after accumulation.
# - The _collections_abc.Sequence gate in sample() is a duck check:
#   anything with __getitem__/__len__ except dict/set passes (CPython
#   also accepts arbitrary Sequence ABC registrations we cannot see).
# - itertools.repeat-driven hot loops are plain range loops; accumulate
#   and bisect come from the native itertools/bisect facades.
# - ``math``/``hashlib``/``operator``/``os`` delegate to the host stdlib --
#   the same floor-delegation policy as csv.jac (`import re`) and
#   cmath.jac (`import math`).
# - ``__getstate__``/``__setstate__``/``__reduce__`` pickle support and
#   ``__init_subclass__`` subclass-generator negotiation are omitted with
#   inheritance itself.

import os;
import math as _math;
import hashlib as _hashlib;
import operator as _operator;

import from bisect { bisect as _bisect }
import from itertools { accumulate as _accumulate }
import from _randommodule { Random_new }


# Module constants; float values pinned to the host-computed doubles of
# Lib/random.py's import-time expressions (see comments).
glob NV_MAGICCONST = 1.7155277699214135;      # 4 * exp(-0.5) / sqrt(2.0)
glob LOG4 = 1.3862943611198906;               # log(4.0)
glob SG_MAGICCONST = 2.5040773967762742;      # 1.0 + log(4.5)
glob BPF = 53;                                # Number of bits in a float
glob RECIP_BPF = 1.1102230246251565e-16;      # 2 ** -BPF
glob TWOPI = 6.283185307179586;               # math.tau


# ---------------------------------------------------------------------------
# Random -- the Mersenne Twister generator with random.py's distributions.

obj Random {
    has core: any = None,
        gauss_next: any = None,
        VERSION: int = 3;

    def seed(a: any = None, version: int = 2) {
        if self.core is None {
            # Urandom-seeded MT core; overridden below unless a is None.
            self.core = Random_new(None);
        }
        if a is None {
            self.gauss_next = None;
            return;
        }
        av: any = a;
        if version == 1 and isinstance(a, (str, bytes)) {
            s = (_bytes_decode_latin1(a) if isinstance(a, bytes) else a);
            x = (ord(s[0]) << 7) if len(s) else 0;
            for c in s {
                x = ((1000003 * x) ^ ord(c)) & 0xFFFFFFFFFFFFFFFF;
            }
            x ^= len(s);
            av = -2 if x == -1 else x;
        } elif version == 2 and isinstance(a, (str, bytes, bytearray)) {
            b = (a.encode() if isinstance(a, str) else bytes(a));
            digest = _hashlib.sha512(b).digest();
            av = int.from_bytes(b + digest);
        } elif not isinstance(a, (int, float, str, bytes, bytearray)) {
            raise TypeError(
                "The only supported seed types are:\n"
                "None, int, float, str, bytes, and bytearray."
            );
        }
        self.core.seed(av);
        self.gauss_next = None;
    }

    def getstate -> tuple {
        return tuple([self.VERSION, self.core.getstate(), self.gauss_next]);
    }

    def setstate(state: any) {
        version = state[0];
        if version == 3 {
            self.gauss_next = state[2];
            self.core.setstate(state[1]);
        } elif version == 2 {
            # Version 2 saved signed ints; normalize to unsigned 32-bit.
            try {
                internal = tuple([x % 4294967296 for x in state[1]]);
            } except ValueError {
                raise TypeError("an integer is required");
            }
            self.gauss_next = state[2];
            self.core.setstate(internal);
        } else {
            raise ValueError(
                "state with version " + str(version)
                + " passed to Random.setstate() of version "
                + str(self.VERSION)
            );
        }
    }

    # ---- raw generator surface (delegates to the MT core; these are the
    # methods Lib Random inherits from _random.Random) ----

    def random -> float {
        return self.core.random();
    }

    def getrandbits(k: int) -> int {
        return self.core.getrandbits(k);
    }

    # ---- internal support for evenly distributed integers ----

    def _randbelow(n: int) -> int {
        k = n.bit_length();
        r = self.getrandbits(k);  # 0 <= r < 2**k
        while r >= n {
            r = self.getrandbits(k);
        }
        return r;
    }

    # ---- bytes methods ----

    def randbytes(n: int) -> bytes {
        return self.getrandbits(n * 8).to_bytes(n, "little");
    }

    # ---- integer methods ----

    def randrange(start: any, stop: any = None, step: any = 1) -> int {
        istart = _index(start);
        if stop is None {
            if not isinstance(step, int) or step != 1 {
                raise TypeError("Missing a non-None stop argument");
            }
            if istart > 0 {
                return self._randbelow(istart);
            }
            raise ValueError("empty range for randrange()");
        }
        istop = _index(stop);
        width = istop - istart;
        istep = _index(step);
        if istep > 0 {
            nsteps = (width + istep - 1) // istep;
        } elif istep < 0 {
            nsteps = (width + istep + 1) // istep;
        } else {
            raise ValueError("zero step for randrange()");
        }
        if istep == 1 {
            if width > 0 {
                return istart + self._randbelow(width);
            }
            raise ValueError(
                "empty range in randrange("
                + str(start) + ", " + str(stop) + ")"
            );
        }
        if nsteps <= 0 {
            raise ValueError(
                "empty range in randrange("
                + str(start) + ", " + str(stop) + ", " + str(step) + ")"
            );
        }
        return istart + istep * self._randbelow(nsteps);
    }

    def randint(a: any, b: any) -> int {
        ia = _index(a);
        ib = _index(b);
        if ib < ia {
            raise ValueError(
                "empty range in randint(" + str(ia) + ", " + str(ib) + ")"
            );
        }
        return ia + self._randbelow(ib - ia + 1);
    }

    # ---- sequence methods ----

    def choice(seq: any) -> any {
        if not len(seq) {
            raise IndexError("Cannot choose from an empty sequence");
        }
        return seq[self._randbelow(len(seq))];
    }

    def shuffle(x: any) {
        i = len(x) - 1;
        while i > 0 {
            # pick an element in x[:i+1] with which to exchange x[i]
            j = self._randbelow(i + 1);
            tmp: any = x[i];
            x[i] = x[j];
            x[j] = tmp;
            i -= 1;
        }
    }

    def sample(population: any, k: int, counts: any = None) -> list {
        if isinstance(population, dict) or isinstance(population, set) or (
            not hasattr(population, "__getitem__")
        ) or not hasattr(population, "__len__") {
            raise TypeError(
                "Population must be a sequence.  "
                "For dicts or sets, use sorted(d)."
            );
        }
        n = len(population);
        if counts is not None {
            cum_counts: list = list(_accumulate(counts));
            if len(cum_counts) != n {
                raise ValueError(
                    "The number of counts does not match the population"
                );
            }
            total: any = cum_counts.pop() if cum_counts else 0;
            if not isinstance(total, int) {
                raise TypeError("Counts must be integers");
            }
            if total < 0 {
                raise ValueError("Counts must be non-negative");
            }
            selections = self.sample(range(total), k);
            out: list = [];
            for s in selections {
                out.append(population[_bisect(cum_counts, s)]);
            }
            return out;
        }
        if k < 0 or k > n {
            raise ValueError("Sample larger than population or is negative");
        }
        result: list = [None] * k;
        setsize: int = 21;
        if k > 5 {
            big_exp: int = int(_math.ceil(_math.log(k * 3, 4)));
            setsize += int(4 ** big_exp);
        }
        if n <= setsize {
            # An n-length pool beats a k-length selection set.
            pool: list = list(population);
            for i in range(k) {
                j = self._randbelow(n - i);
                result[i] = pool[j];
                pool[j] = pool[n - i - 1];
            }
        } else {
            selected: set = set();
            for i in range(k) {
                j = self._randbelow(n);
                while j in selected {
                    j = self._randbelow(n);
                }
                selected.add(j);
                result[i] = population[j];
            }
        }
        return result;
    }

    def choices(population: any, weights: any = None,
                cum_weights: any = None, k: int = 1) -> list {
        n = len(population);
        cw: list = [];
        if cum_weights is None {
            if weights is None {
                out: list = [];
                for _ in range(k) {
                    out.append(population[_math.floor(self.random() * n)]);
                }
                return out;
            }
            if isinstance(weights, int) {
                # CPython reaches this through a failed accumulate(); the
                # message renders the misused positional k.
                raise TypeError(
                    "The number of choices must be a keyword argument: k="
                    + str(weights)
                );
            }
            cw = list(_accumulate(weights));
        } else {
            if weights is not None {
                raise TypeError(
                    "Cannot specify both weights and cumulative weights"
                );
            }
            cw = list(cum_weights);
        }
        if len(cw) != n {
            raise ValueError(
                "The number of weights does not match the population"
            );
        }
        total = cw[len(cw) - 1] + 0.0;
        if total <= 0.0 {
            raise ValueError("Total of weights must be greater than zero");
        }
        if not _math.isfinite(total) {
            raise ValueError("Total of weights must be finite");
        }
        hi = n - 1;
        out: list = [];
        for _ in range(k) {
            out.append(population[_bisect(cw, self.random() * total, 0, hi)]);
        }
        return out;
    }

    # ---- real-valued distributions ----

    def uniform(a: float, b: float) -> float {
        return a + (b - a) * self.random();
    }

    def triangular(low: float = 0.0, high: float = 1.0,
                   mode: any = None) -> float {
        u = self.random();
        try {
            c = 0.5 if mode is None else (mode - low) / (high - low);
        } except ZeroDivisionError {
            return low;
        }
        if u > c {
            u = 1.0 - u;
            c = 1.0 - c;
            tmp = low;
            low = high;
            high = tmp;
        }
        return low + (high - low) * _math.sqrt(u * c);
    }

    def normalvariate(mu: float = 0.0, sigma: float = 1.0) -> float {
        # Kinderman and Monahan ratio-of-uniforms method.
        z: float = 0.0;
        accepted = False;
        while not accepted {
            u1 = self.random();
            u2 = 1.0 - self.random();
            z = NV_MAGICCONST * (u1 - 0.5) / u2;
            zz = z * z / 4.0;
            if zz <= -_math.log(u2) {
                accepted = True;
            }
        }
        return mu + z * sigma;
    }

    def gauss(mu: float = 0.0, sigma: float = 1.0) -> float {
        z: any = self.gauss_next;
        self.gauss_next = None;
        if z is None {
            x2pi = self.random() * TWOPI;
            g2rad = _math.sqrt(-2.0 * _math.log(1.0 - self.random()));
            z = _math.cos(x2pi) * g2rad;
            self.gauss_next = _math.sin(x2pi) * g2rad;
        }
        return mu + z * sigma;
    }

    def lognormvariate(mu: float, sigma: float) -> float {
        return _math.exp(self.normalvariate(mu, sigma));
    }

    def expovariate(lambd: float = 1.0) -> float {
        # 1-random() precludes taking the log of zero.
        return -_math.log(1.0 - self.random()) / lambd;
    }

    def vonmisesvariate(mu: float, kappa: float) -> float {
        if kappa <= 1e-6 {
            return TWOPI * self.random();
        }
        s = 0.5 / kappa;
        r = s + _math.sqrt(1.0 + s * s);
        z: float = 0.0;
        accepted = False;
        while not accepted {
            u1 = self.random();
            z = _math.cos(_math.pi * u1);
            d = z / (r + z);
            u2 = self.random();
            if u2 < 1.0 - d * d or u2 <= (1.0 - d) * _math.exp(d) {
                accepted = True;
            }
        }
        q = 1.0 / r;
        f = (q + z) / (1.0 + q * z);
        u3 = self.random();
        if u3 > 0.5 {
            theta = (mu + _math.acos(f)) % TWOPI;
        } else {
            theta = (mu - _math.acos(f)) % TWOPI;
        }
        return theta;
    }

    def gammavariate(alpha: float, beta: float) -> float {
        if alpha <= 0.0 or beta <= 0.0 {
            raise ValueError("gammavariate: alpha and beta must be > 0.0");
        }
        if alpha > 1.0 {
            # R.C.H. Cheng's non-integral shape algorithm.
            ainv = _math.sqrt(2.0 * alpha - 1.0);
            bbb = alpha - LOG4;
            ccc = alpha + ainv;
            accepted = False;
            while not accepted {
                u1 = self.random();
                if u1 <= 1e-7 or u1 >= 0.9999999 {
                    continue;
                }
                u2 = 1.0 - self.random();
                v = _math.log(u1 / (1.0 - u1)) / ainv;
                x = alpha * _math.exp(v);
                z = u1 * u1 * u2;
                r = bbb + ccc * v - x;
                if r + SG_MAGICCONST - 4.5 * z >= 0.0 or r >= _math.log(z) {
                    accepted = True;
                }
            }
            return x * beta;
        } elif alpha == 1.0 {
            # expovariate(1/beta)
            return -_math.log(1.0 - self.random()) * beta;
        } else {
            # ALGORITHM GS (Kennedy & Gentle) for 0 < alpha < 1.
            x: float = 0.0;
            accepted = False;
            while not accepted {
                u = self.random();
                b = (_math.e + alpha) / _math.e;
                p = b * u;
                if p <= 1.0 {
                    x = p ** (1.0 / alpha);
                } else {
                    x = -_math.log((b - p) / alpha);
                }
                u1 = self.random();
                if p > 1.0 {
                    if u1 <= x ** (alpha - 1.0) {
                        accepted = True;
                    }
                } elif u1 <= _math.exp(-x) {
                    accepted = True;
                }
            }
            return x * beta;
        }
    }

    def betavariate(alpha: float, beta: float) -> float {
        y = self.gammavariate(alpha, 1.0);
        if y {
            return y / (y + self.gammavariate(beta, 1.0));
        }
        return 0.0;
    }

    def paretovariate(alpha: float) -> float {
        u = 1.0 - self.random();
        return u ** (-1.0 / alpha);
    }

    def weibullvariate(alpha: float, beta: float) -> float {
        u = 1.0 - self.random();
        return alpha * (-_math.log(u)) ** (1.0 / beta);
    }

    # ---- discrete distributions ----

    def binomialvariate(n: int = 1, p: float = 0.5) -> int {
        if n < 0 {
            raise ValueError("n must be non-negative");
        }
        if p <= 0.0 or p >= 1.0 {
            if p == 0.0 {
                return 0;
            }
            if p == 1.0 {
                return n;
            }
            raise ValueError("p must be in the range 0.0 <= p <= 1.0");
        }
        if n == 1 {
            return 1 if self.random() < p else 0;
        }
        if p > 0.5 {
            # Symmetry: establish p <= 0.5.
            return n - self.binomialvariate(n, 1.0 - p);
        }
        if n * p < 10.0 {
            # BG: Devroye's geometric method, O(np).
            x = 0;
            y = 0;
            c = _math.log2(1.0 - p);
            if not c {
                return x;
            }
            returned = False;
            while not returned {
                try {
                    y += _math.floor(_math.log2(self.random()) / c) + 1;
                } except ValueError {
                    # Reject case where random() returned 0.0.
                    continue;
                }
                if y > n {
                    returned = True;
                } else {
                    x += 1;
                }
            }
            return x;
        }
        # BTRS: Hörmann's transformed rejection with squeeze.
        setup_complete = False;
        spq = _math.sqrt(n * p * (1.0 - p));
        b = 1.15 + 2.53 * spq;
        a = -0.0873 + 0.0248 * b + 0.01 * p;
        c = n * p + 0.5;
        vr = 0.92 - 4.2 / b;
        alpha_btrs: float = 0.0;
        lpq: float = 0.0;
        m: int = 0;
        h: float = 0.0;
        returned = False;
        kk_out: int = 0;
        while not returned {
            u = self.random();
            u -= 0.5;
            us = 0.5 - abs(u);
            kk = _math.floor((2.0 * a / us + b) * u + c);
            if kk < 0 or kk > n {
                continue;
            }
            v = self.random();
            if us >= 0.07 and v <= vr {
                return kk;
            }
            if not setup_complete {
                alpha_btrs = (2.83 + 5.1 / b) * spq;
                lpq = _math.log(p / (1.0 - p));
                m = _math.floor((n + 1) * p);
                h = _math.lgamma(m + 1) + _math.lgamma(n - m + 1);
                setup_complete = True;
            }
            v *= alpha_btrs / (a / (us * us) + b);
            if _math.log(v) <= (
                h - _math.lgamma(kk + 1) - _math.lgamma(n - kk + 1)
                + (kk - m) * lpq
            ) {
                returned = True;
                kk_out = kk;
            }
        }
        return kk_out;
    }
}


def _bytes_decode_latin1(b: bytes) -> str {
    return b.decode("latin-1");
}


def _index(v: any) -> int {
    # operator.index: __index__-aware integer coercion with builtin
    # TypeError messages ("'str' object cannot be interpreted as an
    # integer" etc.) byte-exact against the host.
    return _operator.index(v);
}


# random() and getrandbits() are named like the module functions below;
# keep the method surface readable by defining the factories first.

obj SystemRandom {
    has VERSION: int = 3;

    def random -> float {
        return (int.from_bytes(os.urandom(7)) >> 3) * RECIP_BPF;
    }

    def getrandbits(k: int) -> int {
        if k < 0 {
            raise ValueError("number of bits must be non-negative");
        }
        numbytes = (k + 7) // 8;
        x = int.from_bytes(os.urandom(numbytes));
        return x >> (numbytes * 8 - k);
    }

    def randbytes(n: int) -> bytes {
        # os.urandom raises ValueError for n < 0 and returns b"" for 0.
        return os.urandom(n);
    }

    def seed(a: any = None, version: int = 2) -> None {
        return None;
    }

    def getstate -> any {
        raise NotImplementedError("System entropy source does not have state.");
    }

    def setstate(state: any) {
        raise NotImplementedError("System entropy source does not have state.");
    }
}


def new_random(x: any = None) -> Random {
    r: Random = Random();
    r.seed(x);
    return r;
}


def new_system_random -> SystemRandom {
    return SystemRandom();
}


# ---------------------------------------------------------------------------
# Module-level singleton: one instance seeded from urandom at import, whose
# bound methods are exported as module functions (shared-state semantics of
# Lib/random.py).

glob _inst: any = new_random(None);


def seed(a: any = None, version: int = 2) {
    _inst.seed(a, version);
}

def random -> float {
    return _inst.random();
}

def getrandbits(k: int) -> int {
    return _inst.getrandbits(k);
}

def getstate -> tuple {
    return _inst.getstate();
}

def setstate(state: any) {
    _inst.setstate(state);
}

def randbytes(n: int) -> bytes {
    return _inst.randbytes(n);
}

def randrange(start: any, stop: any = None, step: any = 1) -> int {
    return _inst.randrange(start, stop, step);
}

def randint(a: any, b: any) -> int {
    return _inst.randint(a, b);
}

def choice(seq: any) -> any {
    return _inst.choice(seq);
}

def shuffle(x: any) {
    _inst.shuffle(x);
}

def sample(population: any, k: int, counts: any = None) -> list {
    return _inst.sample(population, k, counts);
}

def choices(population: any, weights: any = None,
            cum_weights: any = None, k: int = 1) -> list {
    return _inst.choices(population, weights, cum_weights, k);
}

def uniform(a: float, b: float) -> float {
    return _inst.uniform(a, b);
}

def triangular(low: float = 0.0, high: float = 1.0,
               mode: any = None) -> float {
    return _inst.triangular(low, high, mode);
}

def normalvariate(mu: float = 0.0, sigma: float = 1.0) -> float {
    return _inst.normalvariate(mu, sigma);
}

def gauss(mu: float = 0.0, sigma: float = 1.0) -> float {
    return _inst.gauss(mu, sigma);
}

def lognormvariate(mu: float, sigma: float) -> float {
    return _inst.lognormvariate(mu, sigma);
}

def expovariate(lambd: float = 1.0) -> float {
    return _inst.expovariate(lambd);
}

def vonmisesvariate(mu: float, kappa: float) -> float {
    return _inst.vonmisesvariate(mu, kappa);
}

def gammavariate(alpha: float, beta: float) -> float {
    return _inst.gammavariate(alpha, beta);
}

def betavariate(alpha: float, beta: float) -> float {
    return _inst.betavariate(alpha, beta);
}

def paretovariate(alpha: float) -> float {
    return _inst.paretovariate(alpha);
}

def weibullvariate(alpha: float, beta: float) -> float {
    return _inst.weibullvariate(alpha, beta);
}

def binomialvariate(n: int = 1, p: float = 0.5) -> int {
    return _inst.binomialvariate(n, p);
}
