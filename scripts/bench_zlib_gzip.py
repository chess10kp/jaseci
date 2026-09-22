import time
import zlib
import gzip

P = 2147483647


def digest(data):
    acc = 1
    for b in data:
        acc = (acc * 131 + b) % P
    return acc


def make_data():
    return (b"The quick brown fox jumps over the lazy dog. " * 6000) + (
        b"0123456789" * 4000
    )


def make_random(n):
    out = bytearray(n)
    x = 88172645
    for i in range(n):
        x = (x * 48271) % 2147483647
        out[i] = x % 251
    return bytes(out)


def bench_crc32(buf, iters):
    acc = zlib.crc32(buf)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            acc = zlib.crc32(buf, acc)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print("crc32_300k ns=" + str(best // iters) + " digest=" + str(acc))


def bench_adler32(buf, iters):
    acc = zlib.adler32(buf)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            acc = zlib.adler32(buf, acc)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print("adler32_300k ns=" + str(best // iters) + " digest=" + str(acc))


def bench_zlib_compress(buf, iters):
    out = zlib.compress(buf)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            out = zlib.compress(buf)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print(
        "zlib_compress_300k ns=" + str(best // iters) + " digest=" + str(digest(out))
    )


def bench_zlib_decompress(comp, iters):
    out = zlib.decompress(comp)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            out = zlib.decompress(comp)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print(
        "zlib_decompress_300k ns="
        + str(best // iters)
        + " digest="
        + str(digest(out))
    )


def bench_zlib_compress_rand(buf, iters):
    out = zlib.compress(buf)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            out = zlib.compress(buf)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print(
        "zlib_compress_rand64k ns="
        + str(best // iters)
        + " digest="
        + str(digest(out))
    )


def bench_gzip_compress(buf, iters):
    out = gzip.compress(buf)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            out = gzip.compress(buf)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print(
        "gzip_compress_300k ns=" + str(best // iters) + " digest=" + str(digest(out))
    )


def bench_gzip_decompress(comp, iters):
    out = gzip.decompress(comp)
    best = 0
    for _ in range(3):
        t0 = time.perf_counter_ns()
        for _ in range(iters):
            out = gzip.decompress(comp)
        dt = time.perf_counter_ns() - t0
        if best == 0 or dt < best:
            best = dt
    print(
        "gzip_decompress_300k ns="
        + str(best // iters)
        + " digest="
        + str(digest(out))
    )


text = make_data()
rnd = make_random(65536)
zcomp = zlib.compress(text)
gcomp = gzip.compress(text)

bench_crc32(text, 30)
bench_adler32(text, 30)
bench_zlib_compress(text, 20)
bench_zlib_decompress(zcomp, 20)
bench_zlib_compress_rand(rnd, 20)
bench_gzip_compress(text, 20)
bench_gzip_decompress(gcomp, 20)
