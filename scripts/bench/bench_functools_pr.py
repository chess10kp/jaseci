"""CPython reference for the bundled functools module benchmark.

    python3 scripts/bench/bench_functools_pr.py

Rows print name|n|ns_per_op|acc; acc must match the jac lanes (sv bridge and
native) row for row. Mirrors scripts/bench/bench_functools_pr.jac exactly.
"""

import time
import functools
from functools import reduce, partial, lru_cache, cache, wraps


def emit(name, n, dt, acc):
    print(f"{name} | {n} | {dt * 1e9 / n} ns/op | {acc}")


def ft_add(a, b):
    return a + b


def ft_mul(a, b):
    return a * b


def ft_square(x):
    return x * x


def ft_id(x):
    return x


def ft_base(x):
    return x + 1


def ft_wrapped(x):
    return ft_base(x) * 10


def bench_reduce(n):
    data = [i % 7 for i in range(1024)]
    reps = n // 1024
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += reduce(ft_add, data)
    return time.perf_counter() - t0, acc


def bench_partial(n):
    p = partial(ft_mul, 10)
    t0 = time.perf_counter()
    acc = 0
    for i in range(n):
        acc += p.__call__(i % 13)
    return time.perf_counter() - t0, acc


def bench_lru_hit(n):
    sq = lru_cache(maxsize=128).__call__(ft_square)
    t0 = time.perf_counter()
    acc = 0
    for i in range(n):
        acc += sq.__call__(i % 64)
    return time.perf_counter() - t0, acc


def bench_lru_miss(n):
    sq = lru_cache(maxsize=8).__call__(ft_square)
    t0 = time.perf_counter()
    acc = 0
    for i in range(n):
        acc += sq.__call__(i % 64)
    return time.perf_counter() - t0, acc


def bench_cache(n):
    ub = cache(ft_id)
    t0 = time.perf_counter()
    acc = 0
    for i in range(n):
        acc += ub.__call__(i % 64)
    return time.perf_counter() - t0, acc


def bench_wraps_call(n):
    g = wraps(ft_base).__call__(ft_wrapped)
    t0 = time.perf_counter()
    acc = 0
    for i in range(n):
        acc += g(i % 13)
    return time.perf_counter() - t0, acc


def round_i(name, warm_n, n, f):
    f(warm_n)
    dt, acc = f(n)
    for _ in range(2):
        d2, a2 = f(n)
        if d2 < dt:
            dt = d2
        acc = a2
    emit(name, n, dt, acc)


if __name__ == "__main__":
    round_i("functools.reduce", 16, 16384, bench_reduce)
    round_i("functools.partial", 2000, 100000, bench_partial)
    round_i("functools.lru_cache hit", 2000, 100000, bench_lru_hit)
    round_i("functools.lru_cache miss", 2000, 100000, bench_lru_miss)
    round_i("functools.cache", 2000, 100000, bench_cache)
    round_i("functools.wraps-call", 2000, 100000, bench_wraps_call)
