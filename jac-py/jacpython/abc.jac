# Product-path facade for _abc (the ABCMeta machinery module).
# Semantics mirror CPython 3.14 ``Modules/_abc.c`` (registry/caches,
# invalidation counter, abstract-method computation, instance/subclass
# check algorithms) with the same host-exact error strings.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original hangs an
# ``_abc_data`` capsule off each class as ``cls._abc_impl`` and keeps
# registry/caches as WEAK-reference sets so dead subclasses evaporate. This
# facade keeps a module-level ``id(cls) -> _ABCImpl`` map and stores strong
# class references; lifetimes are VM-managed anyway and no observable
# Python-level surface depends on weakref eviction. ``_get_dump`` likewise
# returns list snapshots instead of set copies (its only consumer,
# ``ABC._dump_registry``, formats repr strings).
#
# The subclass-check algorithm walks ``__mro__``/``__bases__`` itself rather
# than delegating to builtin issubclass, so virtual (register-based)
# subclasses resolve identically whether callers arrive from native or
# bridged guest classes.

# Internal state held by the ABC machinery (mirrors _abc._abc_data).
obj _ABCImpl {
    has registry: list = [],
        cache: list = [],
        negative_cache: list = [],
        negative_cache_version: int = 0;
}

# Module-level invalidation counter (_abcmodule_state.abc_invalidation_counter):
# bumped on every successful register(); get_cache_token exposes it.
glob _invalidation_counter: int = 0;

# id(class) -> _ABCImpl; populated by _abc_init.
glob _impls: dict[int, _ABCImpl] = {};


def _p2_impl_for(cls: any) -> _ABCImpl | None {
    key = id(cls);
    if key in _impls {
        return _impls[key];
    }
    return None;
}

def _p2_is_abstract(value: any) -> bool {
    # Mirrors _PyObject_IsAbstract: absent marker means concrete.
    try {
        return bool(getattr(value, "__isabstractmethod__"));
    } except AttributeError {
        return False;
    }
}

def _p2_class_dict(cls: any) -> dict | None {
    try {
        return getattr(cls, "__dict__") as dict;
    } except AttributeError {
        return None;
    }
}

def _p2_real_issubclass(sub: any, sup: any) -> bool {
    # Real-inheritance check only (no virtual registry walk).
    try {
        mro = getattr(sub, "__mro__");
    } except AttributeError {
        return bool(issubclass(sub as type, sup as type));
    }
    for node in mro {
        if node == sup {
            return True;
        }
    }
    return False;
}


# ---- abstract-method computation (compute_abstract_methods) -----------------

def _p2_compute_abstract_methods(cls: any) {
    abstracts: set = set();
    ns = _p2_class_dict(cls);
    if ns is not None {
        for name in ns {
            if _p2_is_abstract(ns[name]) {
                abstracts.add(name);
            }
        }
    }
    bases: list = [];
    try {
        for base in getattr(cls, "__bases__") {
            bases.append(base);
        }
    } except AttributeError {
    }
    for base in bases {
        inherited: any = None;
        found_base = True;
        try {
            inherited = getattr(base, "__abstractmethods__");
        } except AttributeError {
            found_base = False;
        }
        if not found_base {
            continue;
        }
        for name in inherited {
            # Still abstract only if the value reachable from cls kept the
            # marker (an override without the marker makes it concrete).
            found = True;
            try {
                current = getattr(cls, name as str);
            } except AttributeError {
                found = False;
            }
            if found and _p2_is_abstract(current) {
                abstracts.add(name);
            }
        }
    }
    cls.__abstractmethods__ = frozenset(abstracts);
}


# ---- module surface (same names Lib/abc.py imports from _abc) ---------------

def _abc_init(cls: any) {
    # Mirrors _abc__abc_init: compute __abstractmethods__, install fresh
    # state, seed the negative-cache version from the global counter.
    # __abc_tpflags__ COLLECTION_FLAGS propagation is a C type-flag concern
    # with no Jac-native equivalent (pattern-matching protocol flags are
    # served by the host type machinery) and is intentionally omitted.
    _p2_compute_abstract_methods(cls);
    _impls[id(cls)] = _ABCImpl(negative_cache_version=_invalidation_counter);
}

def _abc_register(cls: any, subclass: any) -> any {
    # Mirrors _abc__abc_register_impl.
    if not isinstance(subclass, type) {
        raise TypeError("Can only register classes");
    }
    if _p2_real_issubclass(subclass, cls) {
        return subclass;
    }
    # Subtle: cycle test AFTER the already-a-subclass test, so X.register(X)
    # stays a no-op (comment preserved from _abc.c).
    if _p2_real_issubclass(cls, subclass) {
        raise RuntimeError("Refusing to create an inheritance cycle");
    }
    data = _p2_impl_for(cls);
    if data is None {
        raise TypeError("_abc_impl is set to a wrong type");
    }
    if subclass not in data.registry {
        data.registry.append(subclass);
    }
    _invalidation_counter += 1;
    return subclass;
}

def _abc_subclasscheck(cls: any, subclass: any) -> bool {
    # Mirrors _abc__abc_subclasscheck_impl steps 1-6.
    if not isinstance(subclass, type) {
        raise TypeError("issubclass() arg 1 must be a class");
    }
    data = _p2_impl_for(cls);
    if data is None {
        raise TypeError("_abc_impl is set to a wrong type");
    }

    # 1. Positive cache.
    if subclass in data.cache {
        return True;
    }

    # 2. Negative cache; invalidate when stale.
    if data.negative_cache_version < _invalidation_counter {
        data.negative_cache.clear();
        data.negative_cache_version = _invalidation_counter;
    } elif subclass in data.negative_cache {
        return False;
    }

    # 3. Subclass hook.
    hook: any = None;
    try {
        hook = getattr(cls, "__subclasshook__");
    } except AttributeError {
    }
    if hook is not None {
        ok = hook(subclass);
        if isinstance(ok, bool) {
            if ok {
                data.cache.append(subclass);
                return True;
            }
            data.negative_cache.append(subclass);
            return False;
        }
        if not (ok is NotImplemented or ok == NotImplemented) {
            raise AssertionError(
                "__subclasshook__ must return either"
                " False, True, or NotImplemented"
            );
        }
    }

    # 4. Direct real subclass.
    if _p2_real_issubclass(subclass, cls) {
        data.cache.append(subclass);
        return True;
    }

    # 5. Subclass of a registered virtual subclass (recursive).
    for registered in data.registry {
        if _p2_virtual_subclasscheck(subclass, registered) {
            data.cache.append(subclass);
            return True;
        }
    }

    # 6. Subclass of a real subclass (recursive).
    subclasses: list = [];
    try {
        for scls in getattr(cls, "__subclasses__")() {
            subclasses.append(scls);
        }
    } except AttributeError {
    }
    for scls in subclasses {
        if _p2_virtual_subclasscheck(subclass, scls) {
            data.cache.append(subclass);
            return True;
        }
    }

    # No dice; update negative cache.
    data.negative_cache.append(subclass);
    return False;
}

def _p2_virtual_subclasscheck(sub: any, sup: any) -> bool {
    # Real inheritance plus the target's own registry, recursively -- the
    # shared core behind subclasscheck steps 5/6 (PyObject_IsSubclass).
    if _p2_real_issubclass(sub, sup) {
        return True;
    }
    data = _p2_impl_for(sup);
    if data is None {
        return False;
    }
    for registered in data.registry {
        if _p2_virtual_subclasscheck(sub, registered) {
            return True;
        }
    }
    return False;
}

def _abc_instancecheck(cls: any, instance: any) -> bool {
    # Mirrors _abc__abc_instancecheck_impl: positive cache fast path, then
    # exact-type negative-cache short circuit, then the subclass check on
    # both the claimed and the actual class.
    data = _p2_impl_for(cls);
    if data is None {
        raise TypeError("_abc_impl is set to a wrong type");
    }
    subclass: any = getattr(instance, "__class__");
    if subclass in data.cache {
        return True;
    }
    subtype: any = type(instance);
    if subtype == subclass {
        if data.negative_cache_version == _invalidation_counter {
            if subclass in data.negative_cache {
                return False;
            }
        }
        return _abc_subclasscheck(cls, subclass);
    }
    if _abc_subclasscheck(cls, subclass) {
        return True;
    }
    return _abc_subclasscheck(cls, subtype);
}

def get_cache_token() -> int {
    # Opaque-but-comparable cache version token; changes on every register().
    return _invalidation_counter;
}

def _get_dump(cls: any) -> tuple {
    # Shallow snapshots of registry, both caches, and the negative-cache
    # version (list copies here; see representation note in the header).
    data = _p2_impl_for(cls);
    if data is None {
        raise TypeError("_abc_impl is set to a wrong type");
    }
    return (
        list(data.registry),
        list(data.cache),
        list(data.negative_cache),
        data.negative_cache_version,
    );
}

def _reset_registry(cls: any) {
    data = _p2_impl_for(cls);
    if data is None {
        raise TypeError("_abc_impl is set to a wrong type");
    }
    data.registry.clear();
}

def _reset_caches(cls: any) {
    data = _p2_impl_for(cls);
    if data is None {
        raise TypeError("_abc_impl is set to a wrong type");
    }
    data.cache.clear();
    data.negative_cache.clear();
}
