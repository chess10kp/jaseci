"""Bundled native ``fnmatch`` cross-backend equivalence fixture.

The sv entry uses CPython's fnmatch; the na entry the bundled
`na_stdlib/fnmatch.jac` (backtracking matcher plus a mechanical port of
CPython's ``translate`` regex emitter). The same pattern/name grid is
pinned on both lanes; `translate` results compare as raw strings and
`filter` as a newline-joined list. ES/JS opts out.
"""

import fnmatch;

glob PATS: list[str] = [
         "*.txt",
         "a?c",
         "[ab]c",
         "[!a]c",
         "[a-c]x",
         "a*b*c",
         "**",
         "a***b",
         "[]a]",
         "[a-]",
         "[-a]",
         "x[",
         "a\\b",
         "a b",
         "a.b",
         "[a&&b]",
         "[~a]",
         "a(b)",
         "foo|bar",
         "[z-a]",
         "*.tar.gz",
         "x/**/y"
     ],
     NAMES: list[str] = [
         "foo.txt",
         "bar.log",
         "a.tar.gz",
         "abc",
         "aXc",
         "ac",
         "axc",
         "aXXbXc",
         "a b",
         "a.b",
         "a\\b",
         "x[",
         "z",
         "-a",
         "[a&&b]",
         "x/y",
         "x/a/b/y"
     ];


def _grid_py(d: dict[any, any]) {
    i: int = 0;
    while i < len(PATS) {
        j: int = 0;
        while j < len(NAMES) {
            nm: str = NAMES[j];
            pt: str = PATS[i];
            d["m" + str(i) + "_" + str(j)] = fnmatch.fnmatch(nm, pt);
            d["c" + str(i) + "_" + str(j)] = fnmatch.fnmatchcase(nm, pt);
            j += 1;
        }
        d["t" + str(i)] = fnmatch.translate(PATS[i]);
        i += 1;
    }
    d["filt_txt"] = "\n".join(fnmatch.filter(NAMES, "*.txt"));
    d["filt_case"] = "\n".join(fnmatch.filter(NAMES, "A*"));
    d["normcase"] = fnmatch.normcase("AbC/x");
}


def fnmatch_py -> dict[any, any] {
    d: dict[any, any] = {};
    _grid_py(d);
    return d;
}


def fnmatch_cl -> dict[any, any] {
    return {};
}


def _grid_na(d: dict[str, any]) {
    i: int = 0;
    while i < len(PATS) {
        j: int = 0;
        while j < len(NAMES) {
            nm: str = NAMES[j];
            pt: str = PATS[i];
            d["m" + str(i) + "_" + str(j)] = fnmatch.fnmatch(nm, pt);
            d["c" + str(i) + "_" + str(j)] = fnmatch.fnmatchcase(nm, pt);
            j += 1;
        }
        d["t" + str(i)] = fnmatch.translate(PATS[i]);
        i += 1;
    }
    d["filt_txt"] = "\n".join(fnmatch.filter(NAMES, "*.txt"));
    d["filt_case"] = "\n".join(fnmatch.filter(NAMES, "A*"));
    d["normcase"] = fnmatch.normcase("AbC/x");
}


def fnmatch_na -> dict[str, any] {
    d: dict[str, any] = {};
    _grid_na(d);
    return d;
}
