# Product-path facade for operator (port of CPython 3.14
# ``Modules/_operator.c``, exercised by ``Lib/test/test_operator.py``).
#
# Every module-level callable mirrors one entry of the C method table: the
# arithmetic/compare families delegate to Jac's own operator expressions, which
# lower to the same PyNumber_*/PyObject_RichCompare slots; the sequence family
# (contains/indexOf/countOf/concat) walks the iterator protocol exactly like
# PySequence_*. The three stateful callables are obj archetypes driven through
# ``__call__``/``__repr__``/``__reduce__`` -- the same na-clean shape as
# _functoolsmodule / itertoolsmodule. Host-exact error texts are pinned against
# CPython 3.14.7 at authoring time.
#
# Divergence from C: _compare_digest keeps the observable contract (result,
# error texts) but not the constant-time memory access pattern -- timing
# safety is unrepresentable in portable guest code.

# ---- truth / unary ------------------------------------------------------------

def truth(a: any) -> bool {
    return bool(a);
}

def not_(a: any) -> bool {
    return not a;
}

def neg(a: any) -> any {
    return -a;
}

def pos(a: any) -> any {
    return +a;
}

def abs(a: any) -> any {
    # PyNumber_Absolute resolves through the nb_absolute (__abs__) slot.
    return a.__abs__();
}

def invert(a: any) -> any {
    return ~a;
}

def index(a: any) -> any {
    return a.__index__();
}

# ---- binary arithmetic --------------------------------------------------------

def add(a: any, b: any) -> any {
    return a + b;
}

def sub(a: any, b: any) -> any {
    return a - b;
}

def mul(a: any, b: any) -> any {
    return a * b;
}

def matmul(a: any, b: any) -> any {
    return a @ b;
}

def floordiv(a: any, b: any) -> any {
    return a // b;
}

def truediv(a: any, b: any) -> any {
    return a / b;
}

def mod(a: any, b: any) -> any {
    return a % b;
}

def pow(a: any, b: any) -> any {
    return a ** b;
}

def lshift(a: any, b: any) -> any {
    return a << b;
}

def rshift(a: any, b: any) -> any {
    return a >> b;
}

def and_(a: any, b: any) -> any {
    return a & b;
}

def xor(a: any, b: any) -> any {
    return a ^ b;
}

def or_(a: any, b: any) -> any {
    return a | b;
}

# ---- in-place variants --------------------------------------------------------
# ``x <op>= y`` on a local lowers to the INPLACE_* slot family, so augmented
# assignment on the parameter reproduces PyNumber_InPlace* semantics: mutable
# targets mutate in place and return self, immutables produce a new value.

def iadd(a: any, b: any) -> any {
    a += b;
    return a;
}

def isub(a: any, b: any) -> any {
    a -= b;
    return a;
}

def imul(a: any, b: any) -> any {
    a *= b;
    return a;
}

def imatmul(a: any, b: any) -> any {
    a @= b;
    return a;
}

def ifloordiv(a: any, b: any) -> any {
    a //= b;
    return a;
}

def itruediv(a: any, b: any) -> any {
    a /= b;
    return a;
}

def imod(a: any, b: any) -> any {
    a %= b;
    return a;
}

def ipow(a: any, b: any) -> any {
    a **= b;
    return a;
}

def ilshift(a: any, b: any) -> any {
    a <<= b;
    return a;
}

def irshift(a: any, b: any) -> any {
    a >>= b;
    return a;
}

def iand(a: any, b: any) -> any {
    a &= b;
    return a;
}

def ixor(a: any, b: any) -> any {
    a ^= b;
    return a;
}

def ior(a: any, b: any) -> any {
    a |= b;
    return a;
}

# ---- rich comparison ----------------------------------------------------------

def lt(a: any, b: any) -> any {
    return a < b;
}

def le(a: any, b: any) -> any {
    return a <= b;
}

def eq(a: any, b: any) -> any {
    return a == b;
}

def ne(a: any, b: any) -> any {
    return a != b;
}

def gt(a: any, b: any) -> any {
    return a > b;
}

def ge(a: any, b: any) -> any {
    return a >= b;
}

# ---- identity -----------------------------------------------------------------

def is_(a: any, b: any) -> bool {
    return a is b;
}

def is_not(a: any, b: any) -> bool {
    return a is not b;
}

def is_none(a: any) -> bool {
    return a is None;
}

def is_not_none(a: any) -> bool {
    return a is not None;
}

# ---- mapping / sequence protocol ----------------------------------------------

def getitem(a: any, b: any) -> any {
    return a[b];
}

def setitem(a: any, b: any, c: any) {
    a[b] = c;
}

def delitem(a: any, b: any) {
    del a[b];
}

def contains(a: any, b: any) -> bool {
    # Mirrors _operator.contains: note reversed operands, same as ``b in a``.
    return b in a;
}

def concat(a: any, b: any) -> any {
    return a + b;
}

def iconcat(a: any, b: any) -> any {
    a += b;
    return a;
}

def indexOf(a: any, b: any) -> int {
    # Mirrors PySequence_Index: first position where an element equals b.
    i: int = 0;
    for item in a {
        if item == b {
            return i;
        }
        i = i + 1;
    }
    raise ValueError("sequence.index(x): x not in sequence");
}

def countOf(a: any, b: any) -> int {
    # Mirrors PySequence_Count: elements equal to b.
    count: int = 0;
    for item in a {
        if item == b {
            count = count + 1;
        }
    }
    return count;
}

def length_hint(`obj: any, `default: int = 0) -> int {
    # Mirrors Lib/operator.length_hint / PyObject_LengthHint: len() wins when
    # present, __length_hint__() is consulted next, default otherwise.
    try {
        return len(`obj);
    } except TypeError {
        try {
            lh_getter = getattr(`obj, "__length_hint__");
        } except AttributeError {
            return `default;
        }
        try {
            hint = lh_getter();
        } except TypeError {
            return `default;
        }
        if hint is NotImplemented {
            return `default;
        }
    }
    if not isinstance(hint, int) or isinstance(hint, bool) {
        raise TypeError("__length_hint__() must be an int, not "
            + type(hint).__name__);
    }
    if hint < 0 {
        raise ValueError("__length_hint__() should return >= 0");
    }
    return hint;
}

def call(`obj: any, *args: list, **kwargs: dict) -> any {
    return `obj(*args, **kwargs);
}

# ---- _compare_digest ----------------------------------------------------------
# Timing-safe compare contract over str (ASCII-only) and bytes-like objects.

def _str_is_ascii(s: str) -> bool {
    for ch in s {
        if ord(ch) > 127 {
            return False;
        }
    }
    return True;
}

def _tscmp_bytes(a: bytes, b: bytes) -> bool {
    # Unequal lengths never match; equal lengths compare every byte so the
    # result is exact even though the guest loop is not constant time.
    if len(a) != len(b) {
        return False;
    }
    result: int = 0;
    for i in range(len(a)) {
        result = result | (a[i] ^ b[i]);
    }
    return result == 0;
}

def _tscmp_str(a: str, b: str) -> bool {
    if len(a) != len(b) {
        return False;
    }
    result: bool = True;
    for i in range(len(a)) {
        if a[i] != b[i] and result {
            result = False;
        }
    }
    return result;
}

def _compare_digest(a: any, b: any) -> bool {
    if isinstance(a, str) and isinstance(b, str) {
        if not _str_is_ascii(a) or not _str_is_ascii(b) {
            raise TypeError("comparing strings with non-ASCII characters is "
                "not supported");
        }
        return _tscmp_str(a, b);
    }
    a_bytes: bool = isinstance(a, bytes) or isinstance(a, bytearray);
    b_bytes: bool = isinstance(b, bytes) or isinstance(b, bytearray);
    if a_bytes and b_bytes {
        return _tscmp_bytes(bytes(a), bytes(b));
    }
    raise TypeError("unsupported operand types(s) or combination of types: '"
        + type(a).__name__ + "' and '" + type(b).__name__ + "'");
}

# ---- itemgetter ---------------------------------------------------------------

obj _OpItemgetter {
    has items: tuple = ();

    def __call__(`obj: any) -> any {
        if len(self.items) == 1 {
            return `obj[self.items[0]];
        }
        out: list = [];
        for item in self.items {
            out.append(`obj[item]);
        }
        return tuple(out);
    }

    def __repr__ -> str {
        # Mirrors itemgetter_repr: single item prints bare, several print as
        # the stored tuple.
        if len(self.items) == 1 {
            return type(self).__name__ + "(" + repr(self.items[0]) + ")";
        }
        return type(self).__name__ + repr(self.items);
    }

    def __reduce__ -> any {
        if len(self.items) == 1 {
            return (type(self), (self.items[0],));
        }
        return (type(self), self.items);
    }
}

def itemgetter(*items: list) -> _OpItemgetter {
    if len(items) == 0 {
        raise TypeError("itemgetter expected 1 argument, got 0");
    }
    ig = _OpItemgetter();
    ig.items = tuple(items);
    return ig;
}

# ---- attrgetter ---------------------------------------------------------------

def _dotted_getattr(target: any, attr: any) -> any {
    # attr is either a dotted-name tuple (chained getattr) or a plain string.
    cur: any = target;
    if isinstance(attr, tuple) {
        for part in attr {
            cur = getattr(cur, part);
        }
        return cur;
    }
    return getattr(cur, attr);
}

def _dotjoinattr(attr: any) -> any {
    if isinstance(attr, tuple) {
        return ".".join(attr);
    }
    return attr;
}

obj _OpAttrgetter {
    has attrs: tuple = ();

    def __call__(`obj: any) -> any {
        if len(self.attrs) == 1 {
            return _dotted_getattr(`obj, self.attrs[0]);
        }
        out: list = [];
        for attr in self.attrs {
            out.append(_dotted_getattr(`obj, attr));
        }
        return tuple(out);
    }

    def __repr__ -> str {
        # Mirrors attrgetter_repr: single name bare, several as the joined
        # tuple form.
        if len(self.attrs) == 1 {
            return type(self).__name__ + "("
                + repr(_dotjoinattr(self.attrs[0])) + ")";
        }
        names: list = [];
        for attr in self.attrs {
            names.append(_dotjoinattr(attr));
        }
        return type(self).__name__ + repr(tuple(names));
    }

    def __reduce__ -> any {
        names: list = [];
        for attr in self.attrs {
            names.append(_dotjoinattr(attr));
        }
        if len(names) == 1 {
            return (type(self), (names[0],));
        }
        return (type(self), tuple(names));
    }
}

def attrgetter(*attrs: list) -> _OpAttrgetter {
    if len(attrs) == 0 {
        raise TypeError("attrgetter expected 1 argument, got 0");
    }
    prepared: list = [];
    for attr in attrs {
        if not isinstance(attr, str) {
            raise TypeError("attribute name must be a string");
        }
        parts: list = attr.split(".");
        if len(parts) == 1 {
            prepared.append(parts[0]);
        } else {
            prepared.append(tuple(parts));
        }
    }
    ag = _OpAttrgetter();
    ag.attrs = tuple(prepared);
    return ag;
}

# ---- methodcaller -------------------------------------------------------------

obj _OpMethodcaller {
    has name: str = "",
        call_args: tuple = (),
        call_kwargs: dict = {};

    def __call__(`obj: any) -> any {
        method: any = getattr(`obj, self.name);
        return method(*self.call_args, **self.call_kwargs);
    }

    def __repr__ -> str {
        # Mirrors methodcaller_repr: name plus reprs of positional then
        # keyword arguments, ", "-joined.
        if len(self.call_args) == 0 and len(self.call_kwargs) == 0 {
            return type(self).__name__ + "(" + repr(self.name) + ")";
        }
        parts: list = [repr(self.name)];
        for arg in self.call_args {
            parts.append(repr(arg));
        }
        for key in self.call_kwargs {
            parts.append(str(key) + "=" + repr(self.call_kwargs[key]));
        }
        sep: str = ", ";
        return type(self).__name__ + "(" + sep.join(parts) + ")";
    }

    def __reduce__ -> any {
        # No-keyword case reconstructs from (name, *args); with keywords the
        # standard reduce 3-tuple carries the kwargs dict, which rebuilds the
        # caller identically (CPython routes through functools.partial).
        if len(self.call_kwargs) == 0 {
            newargs: list = [self.name];
            for arg in self.call_args {
                newargs.append(arg);
            }
            return (type(self), tuple(newargs));
        }
        allargs: list = [self.name];
        for arg in self.call_args {
            allargs.append(arg);
        }
        return (type(self), tuple(allargs), self.call_kwargs);
    }
}

def methodcaller(name: any, *args: list, **kwargs: dict) -> _OpMethodcaller {
    # Mirrors methodcaller_new validation order.
    if not isinstance(name, str) {
        raise TypeError("method name must be a string");
    }
    mc = _OpMethodcaller();
    mc.name = name;
    mc.call_args = tuple(args);
    mc.call_kwargs = kwargs;
    return mc;
}

# ---- dunder aliases -----------------------------------------------------------
# Lib/operator.py exposes every plain name under its dunder spelling; keep both
# surfaces importable so converted suites can reach either spelling.

glob __abs__: any = abs;
glob __add__: any = add;
glob __and__: any = and_;
glob __concat__: any = concat;
glob __contains__: any = contains;
glob __delitem__: any = delitem;
glob __eq__: any = eq;
glob __floordiv__: any = floordiv;
glob __ge__: any = ge;
glob __getitem__: any = getitem;
glob __gt__: any = gt;
glob __iadd__: any = iadd;
glob __iand__: any = iand;
glob __iconcat__: any = iconcat;
glob __ifloordiv__: any = ifloordiv;
glob __ilshift__: any = ilshift;
glob __imatmul__: any = imatmul;
glob __imod__: any = imod;
glob __imul__: any = imul;
glob __index__: any = index;
glob __inv__: any = invert;
glob __invert__: any = invert;
glob __ior__: any = ior;
glob __ipow__: any = ipow;
glob __irshift__: any = irshift;
glob __isub__: any = isub;
glob __itruediv__: any = itruediv;
glob __ixor__: any = ixor;
glob __le__: any = le;
glob __lshift__: any = lshift;
glob __lt__: any = lt;
glob __matmul__: any = matmul;
glob __mod__: any = mod;
glob __mul__: any = mul;
glob __ne__: any = ne;
glob __neg__: any = neg;
glob __not__: any = not_;
glob __or__: any = or_;
glob __pos__: any = pos;
glob __pow__: any = pow;
glob __rshift__: any = rshift;
glob __setitem__: any = setitem;
glob __sub__: any = sub;
glob __truediv__: any = truediv;
glob __truth__: any = truth;
glob __xor__: any = xor;

# ---- __all__ ------------------------------------------------------------------

glob __all__: list = [
    "abs", "add", "and_", "attrgetter", "call", "concat", "contains",
    "countOf", "delitem", "eq", "floordiv", "ge", "getitem", "gt", "iadd",
    "iand", "iconcat", "ifloordiv", "ilshift", "imatmul", "imod", "imul",
    "index", "indexOf", "ior", "ipow", "irshift", "is_", "is_not",
    "is_none", "is_not_none", "isub", "itruediv", "itemgetter", "ixor",
    "le", "length_hint", "lshift", "lt", "matmul", "methodcaller", "mod",
    "mul", "ne", "neg", "not_", "or_", "pos", "pow", "rshift", "setitem",
    "sub", "truediv", "truth", "xor", "_compare_digest",
];
