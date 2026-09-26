"""FFI-floor lane for the na-path bench: raw C calls with no bundled
module on top. Run only under `jac run -b native` (floor modules don't
load on the sv lane). Pairs with the same ops through the bundled
surface in bench_na_path.jac to decompose per-call module overhead.
"""

import time;
import sys;
import os;
import shutil;
import from _glob_native { glob_lexists }
import from _filecmp_native { fc_probe }
import from _tempfile_native { tf_create_excl, tf_write, tf_close, tf_unlink }

glob BASE: str = "/tmp/jac_na_path_bench_ffi",
     TGT: str = BASE + "/x.txt",
     TMP: str = BASE + "/tmp.bin";


def _w(s: str) {
    sys.stdout.write(s + "\n");
}


def _setup {
    if os.path.exists(BASE) {
        shutil.rmtree(BASE);
    }
    os.makedirs(BASE);
    f = open(TGT, "w");
    f.write("seed\n");
    f.close();
}


def bench_lstat(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        if glob_lexists(TGT) {
            acc += 1;
        }
        if glob_lexists(BASE + "/nope") {
            acc += 1;
        }
        i += 1;
    }
    return acc;
}


def bench_stat(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        p: int = fc_probe(TGT);
        if p > 0 {
            acc += p % 7;
        }
        i += 1;
    }
    return acc;
}


def bench_fd_cycle(n: int) -> int {
    acc: int = 0;
    i: int = 0;
    while i < n {
        tf_unlink(TMP);
        fd: int = tf_create_excl(TMP, 384);
        if fd >= 0 {
            tf_write(fd, b"bench");
            tf_close(fd);
            acc += 1;
        }
        i += 1;
    }
    tf_unlink(TMP);
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

with entry {
    _setup();
    phase: int = 0;
}

glob ns_list: list[int] = [200000, 200000, 20000];

with entry {
    names: list[str] = [];
    names = ["lstat", "stat_probe", "fd_cycle"];
    while phase < 3 {
        n = ns_list[phase];
        best: int = 0;
        best_acc: int = 0;
        r: int = -1;
        while r < rounds {
            t0 = time.perf_counter_ns();
            acc: int = 0;
            if phase == 0 {
                acc = bench_lstat(n);
            } elif phase == 1 {
                acc = bench_stat(n);
            } else {
                acc = bench_fd_cycle(n);
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
