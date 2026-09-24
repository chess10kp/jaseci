"""CPython reference for the bundled itertools module benchmark.

    python3 scripts/bench/bench_itertools_pr.py

Rows print name|n|ns_per_op|acc; acc must match the jac lanes (sv bridge and
native) row for row. Mirrors scripts/bench/bench_itertools_pr.jac exactly.
"""

import time
import itertools
from itertools import (
    count, cycle, accumulate, chain, groupby, islice,
    permutations, combinations, product, zip_longest, batched, tee,
)


def emit(name, n, dt, acc):
    print(f"{name} | {n} | {dt * 1e9 / n} ns/op | {acc}")


def digest_ints(vals):
    acc = 0
    for v in vals:
        acc += v
    return acc


def digest_rows(vals):
    acc = 0
    for row in vals:
        acc += 1
        for v in row:
            acc += v
    return acc


def bench_accumulate(n):
    data = [i % 17 for i in range(512)]
    reps = n // 512
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_ints(accumulate(data))
    return time.perf_counter() - t0, acc


def bench_chain(n):
    a = list(range(170))
    b = [i * 2 for i in range(170)]
    c = [i * 3 for i in range(170)]
    reps = n // 510
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_ints(chain(a, b, c))
    return time.perf_counter() - t0, acc


def bench_islice_count(n):
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        acc += digest_ints(islice(count(0), 100))
    return time.perf_counter() - t0, acc


def bench_permutations(n):
    data = [i + 1 for i in range(6)]
    reps = n // 720
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_rows(permutations(data))
    return time.perf_counter() - t0, acc


def bench_combinations(n):
    data = list(range(16))
    reps = n // 560
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_rows(combinations(data, 3))
    return time.perf_counter() - t0, acc


def bench_product(n):
    reps = n // 64
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_rows(product([0, 1], [0, 1], [0, 1], repeat=1))
        acc += digest_rows(product([0, 1, 2], repeat=2))
    return time.perf_counter() - t0, acc


def bench_groupby(n):
    data = [i % 8 for i in range(400)]
    reps = n // 400
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        for kg in groupby(data):
            acc += 1
            for v in kg[1]:
                acc += v
    return time.perf_counter() - t0, acc


def bench_zl_batched(n):
    a = list(range(150))
    b = [i * 2 for i in range(150)]
    reps = n // 450
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_rows(zip_longest(a, b))
        for bt in batched(a, 5):
            acc += 1
            for v in bt:
                acc += v
    return time.perf_counter() - t0, acc


def bench_cycle_tee(n):
    src = list(range(100))
    reps = n // 500
    t0 = time.perf_counter()
    acc = 0
    for _ in range(reps):
        acc += digest_ints(islice(cycle(src), 250))
        t2 = tee(src, 2)
        acc += digest_ints(t2[0])
        acc += digest_ints(t2[1])
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
    round_i("itertools.accumulate", 64, 16384, bench_accumulate)
    round_i("itertools.chain", 32, 8160, bench_chain)
    round_i("itertools.islice+count", 1000, 100000, bench_islice_count)
    round_i("itertools.permutations", 8, 1440, bench_permutations)
    round_i("itertools.combinations", 8, 4480, bench_combinations)
    round_i("itertools.product", 100, 6400, bench_product)
    round_i("itertools.groupby", 50, 8000, bench_groupby)
    round_i("itertools.zip_longest+batched", 100, 9000, bench_zl_batched)
    round_i("itertools.cycle+tee", 100, 20000, bench_cycle_tee)
