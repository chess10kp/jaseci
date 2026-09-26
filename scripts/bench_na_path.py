"""CPython oracle for scripts/bench_na_path.jac -- identical loops."""

import filecmp
import fileinput
import fnmatch
import glob as glob_mod
import linecache
import os
import shutil
import sys
import tempfile
import time
from pathlib import Path

BASE = "/tmp/jac_na_path_bench"
F_L = BASE + "/a/lines.txt"


def _w(s):
    sys.stdout.write(s + "\n")


def _setup():
    if os.path.exists(BASE):
        shutil.rmtree(BASE)
    os.makedirs(BASE + "/a/sub/deep")
    os.makedirs(BASE + "/b/sub")
    names = ["a.txt", "b.txt", "c.log", "d.log", ".hidden", "e.txt", "f.log", "g.txt"]
    for n in names:
        for d in (BASE + "/a/", BASE + "/a/sub/", BASE + "/a/sub/deep/", BASE + "/b/"):
            with open(d + n, "w") as f:
                f.write("seed data " + n + "\n")
    with open(F_L, "w") as f:
        for i in range(200):
            f.write("line number " + str(i) + " of the fixture file\n")
    linecache.clearcache()
    linecache.getlines(F_L)


def bench_fnmatch(n):
    acc = 0
    for _ in range(n):
        if fnmatch.fnmatchcase("alpha.txt", "a*?.t?t"):
            acc += 1
        if fnmatch.fnmatch("beta.log", "[a-c]*.txt"):
            acc += 2
        if fnmatch.fnmatchcase("a/b/c.py", "**/*.py"):
            acc += 4
        acc += len(fnmatch.filter(["x.py", "y.txt", "z.log", "w.py"], "*.py"))
        acc += len(fnmatch.normcase("AbC/d"))
    return acc


def bench_translate(n):
    acc = 0
    for _ in range(n):
        acc += len(fnmatch.translate("a*b?c[de].txt"))
        acc += len(glob_mod.escape("dir/x*y?.log"))
        if glob_mod.has_magic("a/b[cd]"):
            acc += 1
    return acc


def bench_glob(n):
    acc = 0
    for _ in range(n):
        acc += len(glob_mod.glob(BASE + "/**/*.txt", recursive=True))
        acc += len(glob_mod.glob(BASE + "/a/*.log"))
        acc += len(glob_mod.glob(BASE + "/a/sub/**/d.log", recursive=True))
        acc += len(glob_mod.glob(BASE + "/*"))
    return acc


def bench_pathlib(n):
    acc = 0
    for _ in range(n):
        p = Path("/a/b/c.txt")
        acc += len(p.name) + len(p.stem) + len(p.suffix)
        acc += len(p.parent.name)
        acc += len(p.parts)
        acc += len(str(p / "d" / "e"))
        acc += len(str(Path("/a/b").joinpath("c", "d")))
        if p.is_absolute():
            acc += 1
        if p.match("*.txt"):
            acc += 1
        acc += len(p.suffixes)
    return acc


def bench_pathlib_io(n):
    acc = 0
    p = Path(BASE + "/a")
    f = Path(F_L)
    for _ in range(n):
        if p.exists():
            acc += 1
        if p.is_dir():
            acc += 1
        if f.is_file():
            acc += 1
        acc += len(f.read_bytes())
    return acc


def bench_which(n):
    acc = 0
    for _ in range(n):
        w = shutil.which("sh")
        if w is not None:
            acc += len(w)
    return acc


def bench_tmpfile(n):
    acc = 0
    for _ in range(n):
        tf = tempfile.NamedTemporaryFile(mode="w+b", dir=BASE)
        tf.write(b"bench")
        tf.seek(0)
        acc += len(tf.read())
        tf.close()
    return acc


def bench_tmpdir(n):
    acc = 0
    for _ in range(n):
        td = tempfile.TemporaryDirectory(dir=BASE)
        td.cleanup()
        acc += 1
    return acc


def bench_filecmp(n):
    acc = 0
    a = BASE + "/a/a.txt"
    b = BASE + "/b/a.txt"
    for _ in range(n):
        if filecmp.cmp(a, b, True):
            acc += 1
        if filecmp.cmp(a, BASE + "/a/b.log", False):
            acc += 2
    return acc


def bench_fileinput(n):
    acc = 0
    for _ in range(n):
        inp = fileinput.input([F_L])
        for line in inp:
            acc += len(line)
        fileinput.close()
    return acc


def bench_linecache(n):
    acc = 0
    for i in range(n):
        acc += len(linecache.getline(F_L, (i % 200) + 1))
        acc += len(linecache.getline(F_L, (i % 199) + 1))
    return acc


def timed(name, n, acc, ns):
    _w(f"{name} n={n} acc={acc} total_ms={ns/1e6} ns_per_op={ns/n}")


NAMES = [
    "fnmatch",
    "translate",
    "glob_walk",
    "pathlib",
    "pathlib_io",
    "shutil_which",
    "tmp_named",
    "tmp_dir",
    "filecmp",
    "fileinput",
    "linecache",
]
NS = [200000, 50000, 2000, 100000, 20000, 20000, 20000, 3000, 30000, 2000, 200000]
BENCHES = [
    bench_fnmatch,
    bench_translate,
    bench_glob,
    bench_pathlib,
    bench_pathlib_io,
    bench_which,
    bench_tmpfile,
    bench_tmpdir,
    bench_filecmp,
    bench_fileinput,
    bench_linecache,
]


def main():
    _setup()
    for name, n, bench in zip(NAMES, NS, BENCHES):
        best = 0
        best_acc = 0
        for r in range(-1, 3):
            t0 = time.perf_counter_ns()
            acc = bench(n)
            el = time.perf_counter_ns() - t0
            if r >= 0 and (best == 0 or el < best):
                best = el
                best_acc = acc
        timed(name, n, best_acc, best)


if __name__ == "__main__":
    main()
