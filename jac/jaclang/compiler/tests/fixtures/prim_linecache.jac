"""Bundled native ``linecache`` cross-backend equivalence fixture.

The sv entry uses CPython's linecache; the na entry the bundled
`na_stdlib/linecache.jac` (a four-table cache of (size, mtime, lines,
fullname) per filename over open()+splitlines(keepends)). Both lanes
pin cached/stale refresh behavior, empty-file and missing-file edge
cases as scalars. The PEP 302 loader path and the sys.path fallback
are out of scope on the na lane (documented). ES/JS opts out.
"""

import os;
import shutil;
import linecache;


def _file_py(path: str, body: str) {
    f = open(path, "w");
    f.write(body);
    f.close();
}


def linecache_py -> dict[any, any] {
    base = "/tmp/jac_prim_linecache_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    f1 = base + "/one.txt";
    f2 = base + "/two.txt";
    _file_py(f1, "alpha\nbeta\ngamma");
    _file_py(f2, "");
    linecache.clearcache();
    d = {
        "l1": linecache.getline(f1, 1),
        "l2": linecache.getline(f1, 2),
        "l3_padded": linecache.getline(f1, 3),
        "l0": linecache.getline(f1, 0),
        "l_big": linecache.getline(f1, 99),
        "lines_n": len(linecache.getlines(f1)),
        "empty_n": len(linecache.getlines(f2)),
        "empty_l1": linecache.getline(f2, 1),
        "missing": linecache.getline(base + "/missing.txt", 1),
        "angle": linecache.getline("<stdin>", 1),
        "frozen": linecache.getline("<frozen abc>", 1),
        "lazycache": linecache.lazycache(f1, {}),

    };
    _file_py(f1, "alpha\nbeta\ngamma\ndelta\n");
    d["stale_l4"] = linecache.getline(f1, 4);
    linecache.checkcache();
    d["fresh_l4"] = linecache.getline(f1, 4);
    linecache.clearcache();
    d["post_clear"] = linecache.getline(f1, 4);
    d["up_n"] = len(linecache.updatecache(f1));
    shutil.rmtree(base);
    return d;
}


def linecache_cl -> dict[any, any] {
    return {};
}


def _file_na(path: str, body: str) {
    f = open(path, "w");
    f.write(body);
    f.close();
}


def linecache_na -> dict[str, any] {
    base = "/tmp/jac_prim_linecache_fix";
    if os.path.exists(base) {
        shutil.rmtree(base);
    }
    os.makedirs(base);
    f1 = base + "/one.txt";
    f2 = base + "/two.txt";
    _file_na(f1, "alpha\nbeta\ngamma");
    _file_na(f2, "");
    linecache.clearcache();
    d: dict[str, any] = {};
    d["l1"] = linecache.getline(f1, 1);
    d["l2"] = linecache.getline(f1, 2);
    d["l3_padded"] = linecache.getline(f1, 3);
    d["l0"] = linecache.getline(f1, 0);
    d["l_big"] = linecache.getline(f1, 99);
    d["lines_n"] = len(linecache.getlines(f1));
    d["empty_n"] = len(linecache.getlines(f2));
    d["empty_l1"] = linecache.getline(f2, 1);
    d["missing"] = linecache.getline(base + "/missing.txt", 1);
    d["angle"] = linecache.getline("<stdin>", 1);
    d["frozen"] = linecache.getline("<frozen abc>", 1);
    d["lazycache"] = linecache.lazycache(f1);
    _file_na(f1, "alpha\nbeta\ngamma\ndelta\n");
    d["stale_l4"] = linecache.getline(f1, 4);
    linecache.checkcache();
    d["fresh_l4"] = linecache.getline(f1, 4);
    linecache.clearcache();
    d["post_clear"] = linecache.getline(f1, 4);
    d["up_n"] = len(linecache.updatecache(f1));
    shutil.rmtree(base);
    return d;
}
