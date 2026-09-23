"""CPython reference rows for scripts/bench/bench_na_pr.jac.

    python3 scripts/bench/bench_na_pr.py

Same rows, same n, same acc semantics; compare ns/op across lanes.
"""

import math
import re
import reprlib
import string
import time


def emit(name, n, dt, acc):
    print(name, "|", n, "|", dt * 1e9 / n, "ns/op |", acc)


def best(fn, warmup, n, rounds=3):
    fn(warmup)
    res = fn(n)
    dt, acc = res
    for _ in range(rounds - 1):
        res = fn(n)
        if res[0] < dt:
            dt = res[0]
    return dt, acc


def bench_sqrt(n):
    t0 = time.perf_counter()
    acc = 0.0
    for i in range(n):
        acc += math.sqrt(i + 0.5)
    return time.perf_counter() - t0, acc


def bench_capwords(n):
    s = "the quick brown fox jumps over the lazy dog"
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        acc += len(string.capwords(s))
    return time.perf_counter() - t0, acc


def bench_template(n):
    t = string.Template("Hello, $name! You have $count messages.")
    m = {"name": "Ada", "count": 3}
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        acc += len(t.safe_substitute(m))
    return time.perf_counter() - t0, acc


def bench_re_search(n):
    pat = re.compile("(\\d+)-(\\w+)")
    txt = "id 42-alpha; id 7-beta; id 100-gamma;"
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        mm = pat.search(txt)
        if mm is not None:
            acc += mm.start() + mm.end()
    return time.perf_counter() - t0, acc


def bench_re_findall(n):
    txt = "the quick brown fox jumps over the lazy dog"
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        for w in re.findall("\\w+", txt):
            acc += len(w)
    return time.perf_counter() - t0, acc


def bench_repr(n):
    d = {"name": "ada", "n": 7, "items": [1, "two", 3.5]}
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        acc += len(reprlib.repr(d))
    return time.perf_counter() - t0, acc


if __name__ == "__main__":
    dt, acc = best(bench_sqrt, 100000, 2000000)
    emit("math.sqrt", 2000000, dt, acc)
    dt, acc = best(bench_capwords, 1000, 100000)
    emit("string.capwords", 100000, dt, acc)
    dt, acc = best(bench_template, 1000, 50000)
    emit("string.Template.safe_substitute", 50000, dt, acc)
    dt, acc = best(bench_re_search, 1000, 100000)
    emit("re.search", 100000, dt, acc)
    dt, acc = best(bench_re_findall, 200, 20000)
    emit("re.findall", 20000, dt, acc)
    dt, acc = best(bench_repr, 1000, 50000)
    emit("reprlib.repr", 50000, dt, acc)
