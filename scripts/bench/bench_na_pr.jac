"""Dual-lane benchmark for the bundled string/re/reprlib modules.

    jac run -b native  scripts/bench/bench_na_pr.jac   (bundled na_stdlib)
    jac run -b python  scripts/bench/bench_na_pr.jac   (CPython bridge)

Rows print name|n|ns_per_op|acc; acc must match the CPython reference
(scripts/bench/bench_na_pr.py) lane for lane.
"""

import time;
import math;
import string;
import re;
import reprlib;


def emit_i(name: str, n: int, dt: float, acc: int) {
    print(name, "|", n, "|", dt * 1000000000.0 / n, "ns/op |", acc);
}


def emit_f(name: str, n: int, dt: float, acc: float) {
    print(name, "|", n, "|", dt * 1000000000.0 / n, "ns/op |", acc);
}


def bench_sqrt(n: int) -> tuple[float, float] {
    t0: float = time.perf_counter();
    acc: float = 0.0;
    i: int = 0;
    while i < n {
        fi: float = i;
        acc = acc + math.sqrt(fi + 0.5);
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_capwords(n: int) -> tuple[float, int] {
    s: str = "the quick brown fox jumps over the lazy dog";
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(string.capwords(s));
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_template(n: int) -> tuple[float, int] {
    t = string.Template("Hello, $name! You have $count messages.");
    m: dict[str, any] = {"name": "Ada", "count": 3};
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(t.safe_substitute(m));
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_re_search(n: int) -> tuple[float, int] {
    pat = re.compile("(\\d+)-(\\w+)");
    txt: str = "id 42-alpha; id 7-beta; id 100-gamma;";
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        mm = pat.search(txt);
        if mm is not None {
            acc += mm.start() + mm.end();
        }
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_re_findall(n: int) -> tuple[float, int] {
    txt: str = "the quick brown fox jumps over the lazy dog";
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        ws: list[str] = re.findall("\\w+", txt);
        for w in ws {
            acc += len(w);
        }
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_repr(n: int) -> tuple[float, int] {
    lv: list[any] = [1, "two", 3.5];
    d: dict[str, any] = {"name": "ada", "n": 7, "items": lv};
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(reprlib.repr(d));
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


with entry {
    # Warmup, then best-of-3 for each row.
    (wt, wacc) = bench_sqrt(100000);
    resf = bench_sqrt(2000000);
    dtf: float = resf[0];
    i: int = 0;
    while i < 2 {
        resf = bench_sqrt(2000000);
        if resf[0] < dtf {
            dtf = resf[0];
        }
        i += 1;
    }
    emit_f("math.sqrt", 2000000, dtf, resf[1]);

    resi = bench_capwords(1000);
    resi = bench_capwords(100000);
    dti: float = resi[0];
    acci: int = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_capwords(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("string.capwords", 100000, dti, acci);

    resi = bench_template(1000);
    resi = bench_template(50000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_template(50000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("string.Template.safe_substitute", 50000, dti, acci);

    resi = bench_re_search(1000);
    resi = bench_re_search(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_re_search(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("re.search", 100000, dti, acci);

    resi = bench_re_findall(200);
    resi = bench_re_findall(20000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_re_findall(20000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("re.findall", 20000, dti, acci);

    resi = bench_repr(1000);
    resi = bench_repr(50000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_repr(50000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("reprlib.repr", 50000, dti, acci);
}
