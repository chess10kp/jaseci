"""Dual-lane benchmark for the bundled select/socket/socketserver/urllib/
ipaddress/robotparser modules.

    jac run -b native  scripts/bench/bench_na_socket.jac   (bundled na_stdlib)
    jac run -b python  scripts/bench/bench_na_socket.jac   (CPython bridge)

Rows print name|n|ns_per_op|acc; acc must match the CPython reference
(scripts/bench/bench_na_socket.py) lane for lane.
"""

import time;
import math;
import urllib.parse;
import urllib.robotparser;
import ipaddress;


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
        i = i + 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_urlparse(n: int) -> tuple[float, int] {
    u: str = "https://user:pw@example.com:8443/a/b/c?x=1&y=2#frag";
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        p = urllib.parse.urlparse(u);
        acc += len(p.scheme) + len(p.netloc) + len(p.path) + len(p.query);
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_urljoin(n: int) -> tuple[float, int] {
    base: str = "https://example.com/a/b/c.html";
    rel: str = "../d/e.html?x=1";
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(urllib.parse.urljoin(base, rel));
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_quote_unquote(n: int) -> tuple[float, int] {
    s: str = "a path/with spaces & symbols=+?%";
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        acc += len(urllib.parse.unquote(urllib.parse.quote(s)));
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_ipaddress(n: int) -> tuple[float, int] {
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        a = ipaddress.ip_address("192.168.10.20");
        b = ipaddress.ip_address("2001:db8::ff00:42:8329");
        acc += a.version + b.version + len(a.compressed) + len(b.compressed);
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def _robots() -> list[str] {
    return [
        "User-agent: *",
        "Disallow: /private",
        "Allow: /private/pub",
        "",
        "User-agent: badbot",
        "Disallow: /",
        "Crawl-delay: 5",
        "",
        "User-agent: starbot",
        "Disallow: /*.gif$",
        "Disallow: /tmp/*"
    ];
}


def bench_robotparser(n: int) -> tuple[float, int] {
    rp = urllib.robotparser.RobotFileParser("http://ex.com/robots.txt");
    rp.parse(_robots());
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        if rp.can_fetch("bot", "http://ex.com/private/pub/x") {
            acc += 1;
        }
        if rp.can_fetch("starbot", "http://ex.com/i.gif") {
            acc += 1;
        }
        if rp.can_fetch("badbot", "http://ex.com/tmp/a") {
            acc += 1;
        }
        i += 1;
    }
    return (time.perf_counter() - t0, acc);
}


def bench_robot_parse(n: int) -> tuple[float, int] {
    lines = _robots();
    t0: float = time.perf_counter();
    acc: int = 0;
    i: int = 0;
    while i < n {
        rp = urllib.robotparser.RobotFileParser("http://ex.com/robots.txt");
        rp.parse(lines);
        acc += len(rp.entries);
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

    resi = bench_urlparse(1000);
    resi = bench_urlparse(100000);
    dti: float = resi[0];
    acci: int = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_urlparse(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("urllib.parse.urlparse", 100000, dti, acci);

    resi = bench_urljoin(1000);
    resi = bench_urljoin(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_urljoin(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("urllib.parse.urljoin", 100000, dti, acci);

    resi = bench_quote_unquote(1000);
    resi = bench_quote_unquote(100000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_quote_unquote(100000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("urllib.parse.quote+unquote", 100000, dti, acci);

    resi = bench_ipaddress(1000);
    resi = bench_ipaddress(50000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_ipaddress(50000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("ipaddress.ip_address", 50000, dti, acci);

    resi = bench_robotparser(1000);
    resi = bench_robotparser(50000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_robotparser(50000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("robotparser.can_fetch x3", 50000, dti, acci);

    resi = bench_robot_parse(100);
    resi = bench_robot_parse(5000);
    dti = resi[0];
    acci = resi[1];
    i = 0;
    while i < 2 {
        resi = bench_robot_parse(5000);
        if resi[0] < dti {
            dti = resi[0];
        }
        i += 1;
    }
    emit_i("robotparser.parse", 5000, dti, acci);
}
