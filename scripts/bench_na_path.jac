"""Benchmark: bundled na_stdlib path modules vs sv bridge vs CPython.

Lanes: `jac run -b native` (na bundled modules), `jac run -b python`
(Jac over CPython), and `python3 scripts/bench_na_path.py` (CPython
oracle). Identical loops and checksums across lanes; best-of-3 with a
warmup round. Modules benched: fnmatch, glob, pathlib, shutil.which,
tempfile, filecmp, fileinput, linecache.
"""

import time;
import sys;
import os;
import shutil;
import fnmatch;
import tempfile;
import filecmp;
import fileinput;
import linecache;
import from glob { iglob, has_magic, escape }
import from pathlib { Path }

glob BASE: str = "/tmp/jac_na_path_bench",
     F_L: str = BASE + "/a/lines.txt";


def _w(s: str) {
    sys.stdout.write(s + "\n");
}


def _setup {
    if os.path.exists(BASE) {
        shutil.rmtree(BASE);
    }
    os.makedirs(BASE + "/a/sub/deep");
    os.makedirs(BASE + "/b/sub");
    names: list[str] = [
        "a.txt",
        "b.txt",
        "c.log",
        "d.log",
        ".hidden",
        "e.txt",
        "f.log",
        "g.txt"
    ];
    for n in names {
        f = open(BASE + "/a/" + n, "w");
        f.write("seed data " + n + "\n");
        f.close();
        f = open(BASE + "/a/sub/" + n, "w");
        f.write("seed data " + n + "\n");
        f.close();
        f = open(BASE + "/a/sub/deep/" + n, "w");
        f.write("seed data " + n + "\n");
        f.close();
        f = open(BASE + "/b/" + n, "w");
        f.write("seed data " + n + "\n");
        f.close();
    }
    f = open(F_L, "w");
    i: int = 0;
    while i < 200 {
        f.write("line number " + str(i) + " of the fixture file\n");
        i += 1;
    }
    f.close();
    linecache.clearcache();
    linecache.getlines(F_L);
}


def bench_fnmatch(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        if fnmatch.fnmatchcase("alpha.txt", "a*?.t?t") {
            acc += 1;
        }
        if fnmatch.fnmatch("beta.log", "[a-c]*.txt") {
            acc += 2;
        }
        if fnmatch.fnmatchcase("a/b/c.py", "**/*.py") {
            acc += 4;
        }
        acc += len(list(fnmatch.filter(["x.py", "y.txt", "z.log", "w.py"], "*.py")));
        acc += len((fnmatch.normcase("AbC/d") as str));
        i += 1;
    }
    return acc;
}


def bench_translate(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(fnmatch.translate("a*b?c[de].txt"));
        i += 1;
    }
    return acc;
}


def bench_escape(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(escape("dir/x*y?.log"));
        if has_magic("a/b[cd]") {
            acc += 1;
        }
        i += 1;
    }
    return acc;
}


def bench_glob(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(list(iglob(BASE + "/**/*.txt", recursive=True)));
        acc += len(list(iglob(BASE + "/a/*.log")));
        acc += len(list(iglob(BASE + "/a/sub/**/d.log", recursive=True)));
        acc += len(list(iglob(BASE + "/*")));
        i += 1;
    }
    return acc;
}


def bench_pathlib(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        p = Path("/a/b/c.txt");
        acc += len(p.name) + len(p.stem) + len(p.suffix);
        acc += len(p.parent.name);
        acc += len(p.parts);
        acc += len(str(p / "d" / "e"));
        acc += len(str(Path("/a/b").joinpath("c", "d")));
        if p.is_absolute() {
            acc += 1;
        }
        if p.match("*.txt") {
            acc += 1;
        }
        acc += len(p.suffixes);
        i += 1;
    }
    return acc;
}


def bench_pathlib_io(n: int) -> int {
    acc: int = 0;
    p = Path(BASE + "/a");
    f = Path(F_L);
    i: int = 0;
    while i < n {
        if p.exists() {
            acc += 1;
        }
        if p.is_dir() {
            acc += 1;
        }
        if f.is_file() {
            acc += 1;
        }
        acc += len(f.read_bytes());
        i += 1;
    }
    return acc;
}


def bench_which(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        w = shutil.which("sh");
        if w is not None {
            acc += len(w);
        }
        i += 1;
    }
    return acc;
}


def bench_tmpfile(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        tf = tempfile.NamedTemporaryFile(mode="w+b", dir=BASE);
        tf.write(b"bench");
        tf.seek(0);
        acc += len((tf.read() as bytes));
        tf.close();
        i += 1;
    }
    return acc;
}


def bench_tmpdir(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        td = tempfile.TemporaryDirectory(dir=BASE);
        td.cleanup();
        acc += 1;
        i += 1;
    }
    return acc;
}


def bench_filecmp(n: int) -> int {
    acc: int = 0;
    a = BASE + "/a/a.txt";
    b = BASE + "/b/a.txt";
    i: int = 0;
    while i < n {
        if filecmp.cmp(a, b, True) {
            acc += 1;
        }
        if filecmp.cmp(a, BASE + "/a/b.log", False) {
            acc += 2;
        }
        i += 1;
    }
    return acc;
}


def bench_fileinput(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        inp = fileinput.input([F_L]);
        for line in inp {
            acc += len(line);
        }
        fileinput.close();
        i += 1;
    }
    return acc;
}


def bench_linecache(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(linecache.getline(F_L, (i % 200) + 1));
        acc += len(linecache.getline(F_L, (i % 199) + 1));
        i += 1;
    }
    return acc;
}


def timed(name: str, n: int, acc: int, ns: int) {
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
    );
}


glob rounds: int = 3;
glob names: list[str] = [
         "fnmatch",
         "translate",
         "escape",
         "glob_walk",
         "pathlib",
         "pathlib_io",
         "shutil_which",
         "tmp_named",
         "tmp_dir",
         "filecmp",
         "fileinput",
         "linecache"
     ],
     ns_list: list[int] = [
         200000,
         50000,
         150000,
         2000,
         100000,
         20000,
         20000,
         20000,
         3000,
         30000,
         2000,
         200000
     ];

with entry {
    _setup();
    phase: int = 0;
    while phase < len(names) {
        n = ns_list[phase];
        best: int = 0;
        best_acc: int = 0;
        r: int = -1;
        while r < rounds {
            t0 = time.perf_counter_ns();
            acc: int = 0;
            if phase == 0 {
                acc = bench_fnmatch(n);
            } elif phase == 1 {
                acc = bench_translate(n);
            } elif phase == 2 {
                acc = bench_escape(n);
            } elif phase == 3 {
                acc = bench_glob(n);
            } elif phase == 4 {
                acc = bench_pathlib(n);
            } elif phase == 5 {
                acc = bench_pathlib_io(n);
            } elif phase == 6 {
                acc = bench_which(n);
            } elif phase == 7 {
                acc = bench_tmpfile(n);
            } elif phase == 8 {
                acc = bench_tmpdir(n);
            } elif phase == 9 {
                acc = bench_filecmp(n);
            } elif phase == 10 {
                acc = bench_fileinput(n);
            } else {
                acc = bench_linecache(n);
            }
            el = time.perf_counter_ns() - t0;
            if r >= 0 and (best == 0 or el < best) {
                best = el;
                best_acc = acc;
            }
            r += 1;
        }
        timed(names[phase], n, best_acc, best);
        phase += 1;
    }
}
