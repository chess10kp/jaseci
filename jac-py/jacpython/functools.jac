# Product-path facade for functools (wave 20).
# Per-type implementations live in ``_functoolsmodule.jac``; this module is the
# public-name assembly point for guest code and converted Lib/test pins.

import from _functoolsmodule {
    _p2_reduce as reduce,
    _p2_partial as partial,
    _p2_lru_cache as lru_cache,
    _p2_update_wrapper as update_wrapper,
    _p2_wraps as wraps,
    _p2_cmp_to_key as cmp_to_key,
    _p2_total_ordering as total_ordering,
    P2_PLACEHOLDER as Placeholder,
    P2_WRAPPER_ASSIGNMENTS as WRAPPER_ASSIGNMENTS,
    P2_WRAPPER_UPDATES as WRAPPER_UPDATES,
}
