"""CPython reference rows for scripts/bench/bench_na_socket.jac.

    python3 scripts/bench/bench_na_socket.py

Same rows, same n, same acc semantics; compare ns/op across lanes.
"""

import ipaddress
import math
import time
import urllib.parse
import urllib.robotparser


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


def bench_urlparse(n):
    u = "https://user:pw@example.com:8443/a/b/c?x=1&y=2#frag"
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        p = urllib.parse.urlparse(u)
        acc += len(p.scheme) + len(p.netloc) + len(p.path) + len(p.query)
    return time.perf_counter() - t0, acc


def bench_urljoin(n):
    base = "https://example.com/a/b/c.html"
    rel = "../d/e.html?x=1"
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        acc += len(urllib.parse.urljoin(base, rel))
    return time.perf_counter() - t0, acc


def bench_quote_unquote(n):
    s = "a path/with spaces & symbols=+?%"
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        acc += len(urllib.parse.unquote(urllib.parse.quote(s)))
    return time.perf_counter() - t0, acc


def bench_ipaddress(n):
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        a = ipaddress.ip_address("192.168.10.20")
        b = ipaddress.ip_address("2001:db8::ff00:42:8329")
        acc += a.version + b.version + len(a.compressed) + len(b.compressed)
    return time.perf_counter() - t0, acc


def _robots():
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
        "Disallow: /tmp/*",
    ]


def bench_robotparser(n):
    rp = urllib.robotparser.RobotFileParser("http://ex.com/robots.txt")
    rp.parse(_robots())
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        if rp.can_fetch("bot", "http://ex.com/private/pub/x"):
            acc += 1
        if rp.can_fetch("starbot", "http://ex.com/i.gif"):
            acc += 1
        if rp.can_fetch("badbot", "http://ex.com/tmp/a"):
            acc += 1
    return time.perf_counter() - t0, acc


def bench_robot_parse(n):
    lines = _robots()
    t0 = time.perf_counter()
    acc = 0
    for _ in range(n):
        rp = urllib.robotparser.RobotFileParser("http://ex.com/robots.txt")
        rp.parse(lines)
        acc += len(rp.entries)
    return time.perf_counter() - t0, acc


if __name__ == "__main__":
    dt, acc = best(bench_sqrt, 100000, 2000000)
    emit("math.sqrt", 2000000, dt, acc)
    dt, acc = best(bench_urlparse, 1000, 100000)
    emit("urllib.parse.urlparse", 100000, dt, acc)
    dt, acc = best(bench_urljoin, 1000, 100000)
    emit("urllib.parse.urljoin", 100000, dt, acc)
    dt, acc = best(bench_quote_unquote, 1000, 100000)
    emit("urllib.parse.quote+unquote", 100000, dt, acc)
    dt, acc = best(bench_ipaddress, 1000, 50000)
    emit("ipaddress.ip_address", 50000, dt, acc)
    dt, acc = best(bench_robotparser, 1000, 50000)
    emit("robotparser.can_fetch x3", 50000, dt, acc)
    dt, acc = best(bench_robot_parse, 100, 5000)
    emit("robotparser.parse", 5000, dt, acc)
