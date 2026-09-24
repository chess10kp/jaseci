"""CPython oracle for scripts/bench_na_stdlib.jac -- identical loops."""

import errno
import glob as globmod
import os
import platform
import stat
import sys
import time

BASE = "/tmp/jac_na_stdlib_bench_tree"


def _w(s):
    sys.stdout.write(s + "\n")


def _setup_tree():
    if os.path.exists(BASE):
        return
    os.makedirs(BASE + "/da/sub")
    os.makedirs(BASE + "/db/sub")
    for n in ["a.txt", "b.txt", "c.log"]:
        with open(BASE + "/" + n, "w") as f:
            f.write("x")
    for n in ["a.txt", "b.txt", "c.log"]:
        for d in ("da", "db"):
            with open(BASE + "/" + d + "/" + n, "w") as f:
                f.write("x")
    with open(BASE + "/da/sub/deep.txt", "w") as f:
        f.write("x")


def bench_stat(n):
    acc = 0
    for i in range(n):
        m = 0o100000 + (i % 0o17777)
        acc += stat.S_IMODE(m) + stat.S_IFMT(m)
        if stat.S_ISREG(m):
            acc += 1
        if stat.S_ISDIR(m):
            acc += 2
        if stat.S_ISLNK(m):
            acc += 4
        acc += len(stat.filemode(m))
    return acc


def bench_glob(n):
    acc = 0
    for _ in range(n):
        acc += len(globmod.glob(BASE + "/**/*.txt", recursive=True))
        acc += len(globmod.glob(BASE + "/d?/*.log"))
        acc += len(globmod.glob(BASE + "/*"))
        if globmod.has_magic(BASE + "/*"):
            acc += 1
    return acc


def bench_platform(n):
    acc = 0
    for _ in range(n):
        acc += len(platform.system())
        acc += len(platform.release())
        acc += len(platform.machine())
        acc += len(platform.platform())
        u = platform.uname()
        acc += len(u.system) + len(u.machine)
    return acc


def bench_errno(n):
    acc = 0
    for _ in range(n):
        acc += errno.EPERM + errno.EINVAL
        acc += (
            len(errno.errorcode[errno.EPERM])
            + len(errno.errorcode[errno.ENOENT])
            + len(errno.errorcode[errno.EAGAIN])
        )
    return acc


def timed(name, n, acc, ns):
    _w(
        name
        + " n="
        + str(n)
        + " acc="
        + str(acc)
        + " total_ms="
        + str(ns / 1000000.0)
        + " ns_per_op="
        + str(ns / n)
    )


if __name__ == "__main__":
    _setup_tree()
    names = ["stat", "glob", "platform", "errno"]
    ns_list = [200000, 2000, 20000, 200000]
    fns = [bench_stat, bench_glob, bench_platform, bench_errno]
    for phase in range(4):
        n = ns_list[phase]
        best = 0
        best_acc = 0
        for r in range(-1, 3):
            t0 = time.perf_counter_ns()
            acc = fns[phase](n)
            el = time.perf_counter_ns() - t0
            if r >= 0 and (best == 0 or el < best):
                best = el
                best_acc = acc
        timed(names[phase], n, best_acc, best)
