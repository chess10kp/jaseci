# Product-path facade for functools (wave 20).
# Staged ``Lib/functools.py`` stays the semantic oracle; this module carries
# the runtime truth for reduce / partial (+Placeholder, pickling) /
# lru_cache (+copy/reduce) / wraps+update_wrapper / cmp_to_key /
# total_ordering. Semantics mirror CPython 3.14
# ``Lib/functools.py`` + ``Modules/_functoolsmodule.c``, including host-exact
# error texts (pinned against CPython 3.14.7 at authoring time).
#
# Higher-order shapes are stateful obj archetypes driven through ``__call__``
# and rich-compare dunders, the same na-clean pattern as itertoolsmodule.

# Sentinel distinguishing "argument omitted" from an explicit None
# (reduce(initial=...), lru_cache() bare application, accumulate(initial=)).
obj _P2Missing {
}

glob P2_MISSING: _P2Missing = _P2Missing();

# Marks a slot inside a partial's stored positionals that is filled from the
# call's own leading arguments (CPython 3.14 functools.Placeholder).
obj _P2Placeholder {
    def __repr__ -> str {
        return "Placeholder";
    }

    def __reduce__ -> any {
        return "Placeholder";
    }
}

glob P2_PLACEHOLDER: _P2Placeholder = _P2Placeholder();

def _advance(it: any) -> any {
    return it.__next__();
}

def _get_iter(x: any) -> any {
    return x.__iter__();
}

# ---- reduce -----------------------------------------------------------------

def _p2_reduce(function: any, iterable: any, initial: any = P2_MISSING) -> any {
    # Mirrors functools.reduce (Modules/_functoolsmodule.c): empty iterable
    # without an initializer is a TypeError; otherwise fold left.
    it: any = _get_iter(iterable);
    acc: any = None;
    if initial is P2_MISSING {
        try {
            acc = _advance(it);
        } except StopIteration {
            raise TypeError("reduce() of empty iterable with no initial value");
        }
    } else {
        acc = initial;
    }
    while True {
        try {
            item: any = _advance(it);
        } except StopIteration {
            return acc;
        }
        acc = function(acc, item);
    }
}

# ---- partial ----------------------------------------------------------------

obj _P2Partial {
    has func: any = None,
        part_args: tuple = (),
        keywords: dict = {},
        phcount: int = 0;


    def __call__(*args: list, **kwargs: dict) -> any {
        # Mirrors partial_call: Placeholder slots consume the call's leading
        # positionals, so too few arguments is a host-exact TypeError.
        if len(args) < self.phcount {
            raise TypeError(
                "missing positional arguments in 'partial' call; "
                + "expected at least " + str(self.phcount)
                + ", got " + str(len(args))
            );
        }
        # Merge stored keywords under the new ones; collisions surface as the
        # target's own "got multiple values for argument" TypeError.
        merged: dict = {};
        for key in self.keywords {
            merged[key] = self.keywords[key];
        }
        for key in kwargs {
            merged[key] = kwargs[key];
        }
        filled: list = [];
        idx: int = 0;
        for stored in self.part_args {
            if stored is P2_PLACEHOLDER {
                filled.append(args[idx]);
                idx += 1;
            } else {
                filled.append(stored);
            }
        }
        while idx < len(args) {
            filled.append(args[idx]);
            idx += 1;
        }
        return self.func(*filled, **merged);
    }

    def __repr__ -> str {
        # Mirrors partial_repr in Modules/_functoolsmodule.c: single stored
        # positional prints bare, several print as a tuple.
        parts: list = ["functools.partial(", str(repr(self.func))];
        if len(self.part_args) == 1 {
            parts.append(", ");
            parts.append(str(repr(self.part_args[0])));
        } elif len(self.part_args) > 1 {
            parts.append(", ");
            parts.append(str(repr(self.part_args)));
        }
        if len(self.keywords) > 0 {
            if len(self.part_args) > 0 {
                parts.append(", ");
            }
            sep: str = "";
            for key in self.keywords {
                parts.append(sep);
                parts.append(str(key));
                parts.append("=");
                parts.append(str(repr(self.keywords[key])));
                sep = ", ";
            }
        }
        parts.append(")");
        return "".join(parts);
    }

    def _fields -> tuple {
        return (self.func, self.part_args, self.keywords);
    }

    def __reduce__ -> any {
        # Pickle shape of partial_reduce: (type, (fn,), (fn, args, kw, dict)).
        inst_dict: any = None;
        d = getattr(self, "__dict__", None);
        if isinstance(d, dict) {
            inst_dict = d;
        }
        return (
            _P2Partial,
            (self.func,),
            (self.func, self.part_args, self.keywords, inst_dict),
        );
    }

    def __setstate__(state: any) {
        # Mirrors partial_setstate: replace the whole state atomically and
        # validate every member before mutating anything.
        if not isinstance(state, tuple) or len(state) != 4 {
            raise TypeError("invalid partial state");
        }
        fn: any = state[0];
        fnargs: any = state[1];
        kw: any = state[2];
        sdict: any = state[3];
        if (
            not callable(fn)
            or not isinstance(fnargs, tuple)
            or (kw is not None and not isinstance(kw, dict))
            or (sdict is not None and not isinstance(sdict, dict))
        ) {
            raise TypeError("invalid partial state");
        }
        if len(fnargs) > 0 and fnargs[len(fnargs) - 1] is P2_PLACEHOLDER {
            raise TypeError("trailing Placeholders are not allowed");
        }
        restored: int = 0;
        for i in range(len(fnargs) - 1) {
            if fnargs[i] is P2_PLACEHOLDER {
                restored += 1;
            }
        }
        clean_kw: dict = {};
        if kw is not None {
            for key in kw {
                clean_kw[key] = kw[key];
            }
        }
        self.func = fn;
        self.part_args = fnargs;
        self.keywords = clean_kw;
        self.phcount = restored;
        if sdict is not None {
            for attr_key in sdict {
                setattr(self, attr_key, sdict[attr_key]);
            }
        }
    }
}

def _p2_partial(func: any, part_args: tuple = (), keywords: dict = {}) -> _P2Partial {
    # Construction-time Placeholder restrictions from partial_new: a trailing
    # placeholder would stay unfilled forever, and keyword placeholders have
    # no positional slot to bind into.
    if len(part_args) > 0 and part_args[len(part_args) - 1] is P2_PLACEHOLDER {
        raise TypeError("trailing Placeholders are not allowed");
    }
    for key in keywords {
        if keywords[key] is P2_PLACEHOLDER {
            raise TypeError("Placeholder cannot be passed as a keyword argument");
        }
    }
    phcount: int = 0;
    for i in range(len(part_args) - 1) {
        if part_args[i] is P2_PLACEHOLDER {
            phcount += 1;
        }
    }
    pto = _P2Partial(
        func=func, part_args=part_args, keywords=keywords, phcount=phcount
    );
    return pto;
}

# ---- lru_cache --------------------------------------------------------------

obj _P2CacheInfo {
    # Namedtuple-shaped CacheInfo(hits, misses, maxsize, currsize).
    has hits: int = 0,
        misses: int = 0,
        maxsize: any = None,
        currsize: int = 0;


    def __iter__ -> any {
        return iter((self.hits, self.misses, self.maxsize, self.currsize));
    }

    def __getitem__(index: any) -> any {
        items: list = [self.hits, self.misses, self.maxsize, self.currsize];
        return items[index];
    }

    def __len__ -> int {
        return 4;
    }

    def __eq__(other: any) -> any {
        if isinstance(other, _P2CacheInfo) {
            o = other as _P2CacheInfo;
            return (
                self.hits == o.hits and self.misses == o.misses
                and self.maxsize == o.maxsize and self.currsize == o.currsize
            );
        }
        if isinstance(other, tuple) {
            return (
                self.hits == other[0] and self.misses == other[1]
                and self.maxsize == other[2] and self.currsize == other[3]
            );
        }
        return NotImplemented;
    }

    def __ne__(other: any) -> any {
        eq = self.__eq__(other);
        if eq is NotImplemented {
            return eq;
        }
        return not eq;
    }

    def __repr__ -> str {
        return (
            "CacheInfo(hits=" + str(self.hits)
            + ", misses=" + str(self.misses)
            + ", maxsize=" + str(self.maxsize)
            + ", currsize=" + str(self.currsize) + ")"
        );
    }
}

obj _P2LRUWrapper {
    # Dict-of-key -> result plus an LRU recency list (order[0] = coldest).
    # CPython uses an intrusive linked hash map; the observable hit/miss/
    # eviction sequence is identical. maxsize < 0 is normalized to 0 by
    # lru_cache_new, and 0 caches nothing (every call is a miss).
    has func: any = None,
        maxsize: any = None,
        typed: bool = False,
        hits: int = 0,
        misses: int = 0,
        cache: dict = {},
        order: list = [];

    # Unbounded marker: cache_info reports maxsize=None, never -1.
    def _info_maxsize -> any {
        if self.maxsize < 0 {
            return None;
        }
        return self.maxsize;
    }


    def _make_key(args: list, kwargs: dict) -> any {
        # Mirrors the C key layout: positionals, then (kwd_mark, sorted pairs),
        # then -- when typed -- one more segment of argument types.
        key_parts: list = [];
        for a in args {
            key_parts.append(a);
        }
        if len(kwargs) > 0 {
            key_parts.append(_P2_KWD_MARK);
            keys: list = [];
            for k in kwargs {
                keys.append(k);
            }
            keys.sort();
            for k in keys {
                key_parts.append((k, kwargs[k]));
            }
        }
        if self.typed {
            for a in args {
                key_parts.append(type(a));
            }
            for k in kwargs {
                key_parts.append(type(kwargs[k]));
            }
        }
        return tuple(key_parts);
    }


    def __call__(*args: list, **kwargs: dict) -> any {
        key: any = self._make_key(args, kwargs);
        if key in self.cache {
            self.hits = self.hits + 1;
            # Touch: promote to most-recently-used.
            self.order.remove(key);
            self.order.append(key);
            return self.cache[key];
        }
        self.misses = self.misses + 1;
        result: any = self.func(*args, **kwargs);
        if self.maxsize != 0 {
            self.cache[key] = result;
            self.order.append(key);
            while self.maxsize > 0 and len(self.order) > self.maxsize {
                evicted: any = self.order.pop(0);
                self.cache.pop(evicted, None);
            }
        }
        return result;
    }

    def cache_info -> _P2CacheInfo {
        info = _P2CacheInfo(
            hits=self.hits,
            misses=self.misses,
            maxsize=self._info_maxsize(),
            currsize=len(self.order),
        );
        return info;
    }

    def cache_clear {
        self.hits = 0;
        self.misses = 0;
        self.cache = {};
        self.order = [];
    }

    def cache_parameters -> dict {
        params: dict = {"maxsize": self._info_maxsize(), "typed": self.typed};
        return params;
    }

    def __reduce__ -> any {
        # lru_cache_reduce pickles by qualname: the wrapper reconstructs from
        # its module-level binding, cache contents excluded.
        return getattr(self, "__qualname__", "");
    }

    def __copy__(*args: list) -> any {
        return self;
    }

    def __deepcopy__(*args: list) -> any {
        return self;
    }
}

# Separates positional keys from sorted keyword pairs inside a cache key
# (the C implementation's kwd_mark role; identity, not value, matters).
glob _P2_KWD_MARK: _P2Missing = _P2Missing();

obj _P2LRUDecorator {
    has dec_maxsize: any = None,
        dec_typed: bool = False;


    def __call__(user_function: any) -> any {
        stored: any = self.dec_maxsize;
        if stored is None {
            stored = -1;
        }
        wrapper = _P2LRUWrapper(
            func=user_function, maxsize=stored, typed=self.dec_typed
        );
        # CPython sets __wrapped__ so introspection sees through the cache.
        setattr(wrapper, "__wrapped__", user_function);
        setattr(wrapper, "__module__", "functools");
        setattr(wrapper, "__name__", user_function.__name__);
        setattr(wrapper, "__qualname__", user_function.__qualname__);
        setattr(wrapper, "__doc__", user_function.__doc__);
        return wrapper;
    }
}

def _p2_lru_cache(
    user_function: any = P2_MISSING, typed: bool = False
) -> any {
    # Dispatch mirrors Lib/functools.py decorating_and_caching:
    #   @lru_cache() / @lru_cache          -> defaults maxsize=128
    #   @lru_cache(maxsize)                -> explicit size (None = unbounded)
    #   lru_cache(fn)                      -> applied directly
    maxsize: any = 128;
    if user_function is not P2_MISSING {
        if user_function is None {
            maxsize = None;
        } elif isinstance(user_function, int) and not isinstance(user_function, bool) {
            if user_function < 0 {
                maxsize = 0;
            } else {
                maxsize = user_function;
            }
        } elif callable(user_function) {
            deco = _P2LRUDecorator(dec_maxsize=128, dec_typed=typed);
            return deco.__call__(user_function);
        } else {
            raise TypeError(
                "Expected first argument to be an integer, a callable, or None"
            );
        }
    }
    return _P2LRUDecorator(dec_maxsize=maxsize, dec_typed=typed);
}

# ---- update_wrapper / wraps --------------------------------------------------

# CPython 3.14 tuple (PEP 649/795): __annotate__ / __type_params__ joined.
glob P2_WRAPPER_ASSIGNMENTS: tuple = (
    "__module__", "__name__", "__qualname__", "__doc__",
    "__annotate__", "__type_params__",
);

glob P2_WRAPPER_UPDATES: tuple = ("__dict__",);


def _p2_update_wrapper(
    wrapper: any,
    wrapped: any,
    assigned: any = P2_WRAPPER_ASSIGNMENTS,
    updated: any = P2_WRAPPER_UPDATES,
) -> any {
    for attr in assigned {
        try {
            value: any = getattr(wrapped, attr);
        } except AttributeError {
            continue;
        }
        setattr(wrapper, attr, value);
    }
    for attr in updated {
        getattr(wrapper, attr).update(getattr(wrapped, attr, {}));
    }
    # Set last so the __dict__ merge cannot copy a stale __wrapped__ through.
    wrapper.__wrapped__ = wrapped;
    return wrapper;
}

obj _P2WrapsDecorator {
    has wrapped: any = None,
        wrap_assigned: any = None,
        wrap_updated: any = None;


    def __call__(wrapper: any) -> any {
        return _p2_update_wrapper(
            wrapper, self.wrapped, self.wrap_assigned, self.wrap_updated
        );
    }
}

def _p2_wraps(
    wrapped: any,
    assigned: any = P2_WRAPPER_ASSIGNMENTS,
    updated: any = P2_WRAPPER_UPDATES,
) -> _P2WrapsDecorator {
    deco = _P2WrapsDecorator(
        wrapped=wrapped, wrap_assigned=assigned, wrap_updated=updated
    );
    return deco;
}

# ---- cmp_to_key --------------------------------------------------------------

obj _P2CmpKey {
    has key_cmp: any = None,
        `obj: any = None;

    def _cmp_result(other: any) -> any {
        return self.key_cmp(self.`obj, other.`obj);
    }


    def __lt__(other: any) -> bool {
        return self._cmp_result(other) < 0;
    }

    def __le__(other: any) -> bool {
        return self._cmp_result(other) <= 0;
    }

    def __gt__(other: any) -> bool {
        return self._cmp_result(other) > 0;
    }

    def __ge__(other: any) -> bool {
        return self._cmp_result(other) >= 0;
    }

    def __eq__(other: any) -> bool {
        return self._cmp_result(other) == 0;
    }

    def __ne__(other: any) -> bool {
        return self._cmp_result(other) != 0;
    }
}

obj _P2CmpKeyFactory {
    has key_cmp: any = None;


    def __call__(`obj: any) -> _P2CmpKey {
        return _P2CmpKey(key_cmp=self.key_cmp, `obj=`obj);
    }
}

def _p2_cmp_to_key(mycmp: any) -> _P2CmpKeyFactory {
    # Mirrors functools.cmp_to_key: returns a CLASS-like callable whose
    # instances order themselves by mycmp(a, b) through the rich protocol,
    # so sort(key=K) drives comparisons without a cmp= parameter.
    return _P2CmpKeyFactory(key_cmp=mycmp);
}

# ---- total_ordering ----------------------------------------------------------
# Conversion functions invoke the ROOT dunder directly (never the operator) to
# avoid reflected-dispatch recursion, exactly like Lib/functools.py. They are
# plain functions so setattr(cls, opname, func) binds through the descriptor
# protocol once attached.

def _p2_call_type_dunder(self: any, other: any, dunder: str) -> any {
    op: any = getattr(type(self), dunder);
    return op(self, other);
}

def _p2_gt_from_lt(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__lt__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result and self != other;
}

def _p2_le_from_lt(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__lt__");
    if op_result is NotImplemented {
        return op_result;
    }
    return op_result or self == other;
}

def _p2_ge_from_lt(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__lt__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result;
}

def _p2_ge_from_le(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__le__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result or self == other;
}

def _p2_lt_from_le(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__le__");
    if op_result is NotImplemented {
        return op_result;
    }
    return op_result and self != other;
}

def _p2_gt_from_le(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__le__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result;
}

def _p2_lt_from_gt(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__gt__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result and self != other;
}

def _p2_ge_from_gt(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__gt__");
    if op_result is NotImplemented {
        return op_result;
    }
    return op_result or self == other;
}

def _p2_le_from_gt(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__gt__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result;
}

def _p2_le_from_ge(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__ge__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result or self == other;
}

def _p2_gt_from_ge(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__ge__");
    if op_result is NotImplemented {
        return op_result;
    }
    return op_result and self != other;
}

def _p2_lt_from_ge(self: any, other: any) -> any {
    op_result: any = _p2_call_type_dunder(self, other, "__ge__");
    if op_result is NotImplemented {
        return op_result;
    }
    return not op_result;
}


def _p2_total_ordering(cls: any) -> any {
    # Root preference is max(roots) lexicographic in CPython:
    # __lt__ > __le__ > __gt__ > __ge__; scanning in that order and taking
    # the first user-defined root reproduces it.
    root_op: str = "";
    if getattr(cls, "__lt__", None) is not getattr(object, "__lt__", None) {
        root_op = "__lt__";
    } elif getattr(cls, "__le__", None) is not getattr(object, "__le__", None) {
        root_op = "__le__";
    } elif getattr(cls, "__gt__", None) is not getattr(object, "__gt__", None) {
        root_op = "__gt__";
    } elif getattr(cls, "__ge__", None) is not getattr(object, "__ge__", None) {
        root_op = "__ge__";
    }
    if root_op == "" {
        raise ValueError(
            "must define at least one ordering operation: < > <= >="
        );
    }
    if root_op == "__lt__" {
        if getattr(cls, "__gt__", None) is getattr(object, "__gt__", None) {
            setattr(cls, "__gt__", _p2_gt_from_lt);
        }
        if getattr(cls, "__le__", None) is getattr(object, "__le__", None) {
            setattr(cls, "__le__", _p2_le_from_lt);
        }
        if getattr(cls, "__ge__", None) is getattr(object, "__ge__", None) {
            setattr(cls, "__ge__", _p2_ge_from_lt);
        }
    } elif root_op == "__le__" {
        if getattr(cls, "__ge__", None) is getattr(object, "__ge__", None) {
            setattr(cls, "__ge__", _p2_ge_from_le);
        }
        if getattr(cls, "__lt__", None) is getattr(object, "__lt__", None) {
            setattr(cls, "__lt__", _p2_lt_from_le);
        }
        if getattr(cls, "__gt__", None) is getattr(object, "__gt__", None) {
            setattr(cls, "__gt__", _p2_gt_from_le);
        }
    } elif root_op == "__gt__" {
        if getattr(cls, "__lt__", None) is getattr(object, "__lt__", None) {
            setattr(cls, "__lt__", _p2_lt_from_gt);
        }
        if getattr(cls, "__ge__", None) is getattr(object, "__ge__", None) {
            setattr(cls, "__ge__", _p2_ge_from_gt);
        }
        if getattr(cls, "__le__", None) is getattr(object, "__le__", None) {
            setattr(cls, "__le__", _p2_le_from_gt);
        }
    } else {
        if getattr(cls, "__le__", None) is getattr(object, "__le__", None) {
            setattr(cls, "__le__", _p2_le_from_ge);
        }
        if getattr(cls, "__gt__", None) is getattr(object, "__gt__", None) {
            setattr(cls, "__gt__", _p2_gt_from_ge);
        }
        if getattr(cls, "__lt__", None) is getattr(object, "__lt__", None) {
            setattr(cls, "__lt__", _p2_lt_from_ge);
        }
    }
    return cls;
}
