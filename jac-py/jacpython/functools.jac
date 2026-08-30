# Product-path facade for functools (wave 20).
# Per-type implementations live in ``_functoolsmodule.jac``; this module is the
# public-name assembly point for guest code and converted Lib/test pins.

import from _functoolsmodule {
    P2_MISSING,
    P2_PLACEHOLDER,
    P2_WRAPPER_ASSIGNMENTS,
    P2_WRAPPER_UPDATES,
    _P2CacheInfo,
    _p2_reduce,
    _p2_partial,
    _p2_lru_cache,
    _p2_update_wrapper,
    _p2_wraps,
    _p2_cmp_to_key,
    _p2_total_ordering,
}

glob Placeholder: any = P2_PLACEHOLDER;

glob WRAPPER_ASSIGNMENTS: tuple = P2_WRAPPER_ASSIGNMENTS;

glob WRAPPER_UPDATES: tuple = P2_WRAPPER_UPDATES;

# Namedtuple-shaped cache_info() return type (functools._CacheInfo in Lib).
glob _CacheInfo: any = _P2CacheInfo;

def reduce(function: any, iterable: any, initial: any = P2_MISSING) -> any {
    return _p2_reduce(function, iterable, initial);
}

# _p2_partial stores (func, part_args, keywords); expose CPython partial(*args).
def partial(func: any, *args: list, **kwargs: dict) -> any {
    return _p2_partial(func, tuple(args), kwargs);
}

def lru_cache(user_function: any = P2_MISSING, typed: bool = False) -> any {
    return _p2_lru_cache(user_function, typed);
}

def cache(user_function: any) -> any {
    deco = _p2_lru_cache(None);
    return deco(user_function);
}

def update_wrapper(
    wrapper: any,
    wrapped: any,
    assigned: any = P2_WRAPPER_ASSIGNMENTS,
    updated: any = P2_WRAPPER_UPDATES,
) -> any {
    return _p2_update_wrapper(wrapper, wrapped, assigned, updated);
}

def wraps(
    wrapped: any,
    assigned: any = P2_WRAPPER_ASSIGNMENTS,
    updated: any = P2_WRAPPER_UPDATES,
) -> any {
    return _p2_wraps(wrapped, assigned, updated);
}

def cmp_to_key(mycmp: any) -> any {
    return _p2_cmp_to_key(mycmp);
}

def total_ordering(cls: any) -> any {
    return _p2_total_ordering(cls);
}

glob __all__: list = [
    "update_wrapper",
    "wraps",
    "WRAPPER_ASSIGNMENTS",
    "WRAPPER_UPDATES",
    "total_ordering",
    "cache",
    "cmp_to_key",
    "lru_cache",
    "reduce",
    "partial",
    "Placeholder",
];
