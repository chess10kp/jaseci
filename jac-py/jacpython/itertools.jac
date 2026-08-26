# Product-path facade exposing the PUBLIC itertools API.
# ``itertoolsmodule.jac`` carries the runtime truth (wave-12 na-clean iterator
# archetypes lifted from CPython 3.14 ``Modules/itertoolsmodule.c``); this
# module binds the standard names (count/cycle/repeat/chain/...) onto those
# implementations so guest code can ``import itertools``-style callables
# without reaching the host C extension.
#
# Signatures mirror CPython 3.14. Where CPython marks parameters keyword-only
# (product(repeat=), zip_longest(fillvalue=)), this facade accepts them as
# named arguments via **kwargs so callers get the documented spellings.

import from itertoolsmodule {
    _p2_count,
    _p2_cycle,
    _p2_repeat,
    _p2_chain,
    _p2_chain_from_iterable,
    _p2_product,
    _p2_combinations,
    _p2_cwr,
    _p2_permutations,
    _p2_groupby,
    _p2_tee,
    _p2_islice_stop,
    _p2_islice_full,
    _p2_starmap,
    _p2_accumulate,
    ACC_INITIAL_MISSING,
    _p2_compress,
    _p2_dropwhile,
    _p2_takewhile,
    _p2_filterfalse,
    _p2_pairwise,
    _p2_batched,
    _p2_zip_longest,
}

# ---- infinite iterators ------------------------------------------------------

def count(start: any = 0, step: any = 1) -> any {
    return _p2_count(start, step);
}

def cycle(iterable: any) -> any {
    return _p2_cycle(iterable);
}

def repeat(element: any, times: any = None) -> any {
    return _p2_repeat(element, times);
}

# ---- finite iterators --------------------------------------------------------

obj _ChainNamespace {
    # ``chain`` is a namespace-like callable in CPython (a type with a
    # classmethod); here one shared instance carries both entry points.
    def __call__(*iterables: list) -> any {
        return _p2_chain(*iterables);
    }

    def from_iterable(iterable: any) -> any {
        return _p2_chain_from_iterable(iterable);
    }
}

glob chain: _ChainNamespace = _ChainNamespace();

def combinations(iterable: any, r: int) -> any {
    return _p2_combinations(iterable, r);
}

def combinations_with_replacement(iterable: any, r: int) -> any {
    return _p2_cwr(iterable, r);
}

def permutations(iterable: any, r: any = None) -> any {
    return _p2_permutations(iterable, r);
}

# product(*iterables, repeat=1)
def product(*iterables: list, **kwargs: dict) -> any {
    rep: int = 1;
    if "repeat" in kwargs {
        rep = kwargs["repeat"] as int;
    }
    return _p2_product(iterables, rep);
}

def compress(data: any, selectors: any) -> any {
    return _p2_compress(data, selectors);
}

def dropwhile(predicate: any, iterable: any) -> any {
    return _p2_dropwhile(predicate, iterable);
}

def filterfalse(predicate: any, iterable: any) -> any {
    return _p2_filterfalse(predicate, iterable);
}

def groupby(iterable: any, key: any = None) -> any {
    return _p2_groupby(iterable, key);
}

def pairwise(iterable: any) -> any {
    return _p2_pairwise(iterable);
}

def starmap(function: any, iterable: any) -> any {
    return _p2_starmap(function, iterable);
}

def takewhile(predicate: any, iterable: any) -> any {
    return _p2_takewhile(predicate, iterable);
}

def batched(iterable: any, n: int, strict: bool = False) -> any {
    return _p2_batched(iterable, n, strict);
}

# zip_longest(*iterables, fillvalue=None)
def zip_longest(*iterables: list, **kwargs: dict) -> any {
    fillvalue: any = None;
    if "fillvalue" in kwargs {
        fillvalue = kwargs["fillvalue"];
    }
    return _p2_zip_longest(iterables, fillvalue);
}

# ---- slicing / accumulation --------------------------------------------------

def accumulate(iterable: any, func: any = None, initial: any = ACC_INITIAL_MISSING) -> any {
    return _p2_accumulate(iterable, func, initial);
}

def tee(iterable: any, n: int = 2) -> any {
    return _p2_tee(iterable, n);
}

def islice(iterable: any, start: any, stop: any = None, step: any = None) -> any {
    # CPython's arg-count dispatch: islice(it, stop) vs islice(it, start, stop[, step]).
    # A two-argument call lands in (start, None): that first bound is `stop`.
    if stop is None and step is None {
        return _p2_islice_stop(iterable, start);
    }
    return _p2_islice_full(iterable, start, stop, step);
}
