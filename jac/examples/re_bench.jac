"""Regex micro-benchmark: identical program on both backends.

`jac run re_bench.jac`          -> CPython backend, CPython's C `re` (baseline)
`jac run --native re_bench.jac` -> native backend, bundled na_stdlib/re.jac

Emits `ns=<name> <ns_per_iter>` lines plus correctness digests (any line not
starting with `ns=`). Run each backend 5 times, compare medians.
"""

import re;
import time;

glob MONTHS: list[str] = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12"],
     DAYS: list[str] = ["01", "02", "03", "04", "05", "06", "07", "08", "09", "10", "11", "12", "13", "14", "15", "16", "17", "18", "19", "20", "21", "22", "23", "24", "25", "26", "27", "28"],
     ACTS: list[str] = ["login", "logout", "buy", "sell"],
     TAGS: list[str] = ["foo", "bar", "baz"];


def make_text -> str {
    base: str = "The quick brown fox jumps over the lazy dog. " +
                "Pack my box with five dozen liquor jugs. " +
                " foo bar baz quux 2024-06-11 1999-12-31 weird   spacing\n";
    return base * 700;
}

def make_lines -> list[str] {
    lines: list[str] = [];
    for i in range(4000) {
        s: str = "log line " + str(i) + ": user=uid" + str(i) +
                 " action=" + ACTS[i % 4] + " tag=" + TAGS[i % 3];
        lines.append(s);
    }
    return lines;
}

def make_dates -> list[str] {
    dates: list[str] = [];
    for i in range(4000) {
        if i % 2 == 0 {
            dates.append(str(1990 + i % 35) + "-" + MONTHS[i % 12] + "-" + DAYS[i % 28] + " event " + str(i));
        } else {
            dates.append("no date here " + str(i));
        }
    }
    return dates;
}

def make_idents -> list[str] {
    ids: list[str] = [];
    for i in range(4000) {
        if i % 5 == 0 {
            ids.append("9bad-" + str(i));
        } else {
            ids.append("_valid_ident_" + str(i));
        }
    }
    return ids;
}


glob TEXT: str = make_text(),
     LINES: list[str] = make_lines(),
     DATES: list[str] = make_dates(),
     IDENTS: list[str] = make_idents(),
     A22: str = "a" * 21,
     DATE_RE = "(\\d{4})-(\\d{2})-(\\d{2})",
     ALT_RE = "foo|bar|baz",
     WS_RE = "\\s+",
     BT_RE = "(a+)+b",
     IDENT_RE = "^[A-Za-z_][A-Za-z0-9_]*$",
     KV_RE = "(\\w+)=(\\w+)";


def w_tokenize -> int {
    return len(re.findall("\\w+", TEXT));
}

def w_dates -> int {
    n: int = 0;
    for s in DATES {
        m = re.search(DATE_RE, s);
        if m is not None {
            n += int(m.group(2));
        }
    }
    return n;
}

def w_alt -> int {
    n: int = 0;
    for s in LINES {
        if re.search(ALT_RE, s) is not None {
            n += 1;
        }
    }
    return n;
}

def w_ws -> int {
    return len(re.sub(WS_RE, " ", TEXT));
}

def w_backtrack -> int {
    if re.fullmatch(BT_RE, A22) is not None {
        return 1;
    }
    return 0;
}

def w_ident -> int {
    n: int = 0;
    for s in IDENTS {
        if re.match(IDENT_RE, s) is not None {
            n += 1;
        }
    }
    return n;
}

def w_compiled -> int {
    p = re.compile(KV_RE);
    n: int = 0;
    for s in LINES {
        m = p.search(s);
        if m is not None {
            n += len(m.group(1));
        }
    }
    return n;
}

def w_compile_cost -> int {
    n: int = 0;
    for _ in range(20) {
        p = re.compile("^(?:foo|bar|baz)_([a-z]+)_\\d{2,4}(?:-[a-z]+)?$");
        n += 1;
    }
    return n;
}


def bench(name: str, iters: int, fn) -> None {
    fn();  # warmup; correctness digest already printed via the m: pass below
    best: int = -1;
    for _ in range(5) {
        t0: int = time.perf_counter_ns();
        for _ in range(iters) {
            fn();
        }
        dt: int = time.perf_counter_ns() - t0;
        if best < 0 or dt < best {
            best = dt;
        }
    }
    print("ns=", name, best // iters);
}


with entry {
    print("m:tokens", w_tokenize());
    print("m:dates", w_dates());
    print("m:alt", w_alt());
    print("m:ws", w_ws());
    print("m:bt", w_backtrack());
    print("m:ident", w_ident());
    print("m:compiled", w_compiled());
    print("m:compile_cost", w_compile_cost());
    bench("tokenize_63k", 20, w_tokenize);
    bench("dates_4k", 30, w_dates);
    bench("alt_4k", 30, w_alt);
    bench("ws_63k", 20, w_ws);
    bench("backtrack21", 10, w_backtrack);
    bench("ident_4k", 30, w_ident);
    bench("compiled_4k", 30, w_compiled);
    bench("compile20", 40, w_compile_cost);
}
