import time;
import zlib;
import gzip;

glob P: int = 2147483647;


def digest(data: bytes) -> int {
    acc: int = 1;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % P;
        i += 1;
    }
    return acc;
}


def make_data -> bytes {
    return (b"The quick brown fox jumps over the lazy dog. " * 6000)
        + (b"0123456789" * 4000);
}


def make_random(n: int) -> bytes {
    out = bytearray(n);
    x: int = 88172645;
    i: int = 0;
    while i < n {
        x = (x * 48271) % 2147483647;
        out[i] = x % 251;
        i += 1;
    }
    return bytes(out);
}


def bench_crc32(buf: bytes, iters: int) {
    acc: int = 0;
    acc = zlib.crc32(buf);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            acc = zlib.crc32(buf, acc);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print("crc32_300k ns=" + str(best // iters) + " digest=" + str(acc));
}


def bench_adler32(buf: bytes, iters: int) {
    acc: int = 1;
    acc = zlib.adler32(buf);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            acc = zlib.adler32(buf, acc);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print("adler32_300k ns=" + str(best // iters) + " digest=" + str(acc));
}


def bench_zlib_compress(buf: bytes, iters: int) {
    out: bytes = zlib.compress(buf);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = zlib.compress(buf);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(
        "zlib_compress_300k ns=" + str(best // iters) + " digest=" + str(digest(out))
    );
}


def bench_zlib_decompress(comp: bytes, iters: int) {
    out: bytes = zlib.decompress(comp);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = zlib.decompress(comp);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(
        "zlib_decompress_300k ns=" + str(best // iters) + " digest=" + str(digest(out))
    );
}


def bench_zlib_compress_rand(buf: bytes, iters: int) {
    out: bytes = zlib.compress(buf);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = zlib.compress(buf);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(
        "zlib_compress_rand64k ns=" + str(best // iters) + " digest=" + str(digest(out))
    );
}


def bench_gzip_compress(buf: bytes, iters: int) {
    out: bytes = gzip.compress(buf);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = gzip.compress(buf);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(
        "gzip_compress_300k ns=" + str(best // iters) + " digest=" + str(digest(out))
    );
}


def bench_gzip_decompress(comp: bytes, iters: int) {
    out: bytes = gzip.decompress(comp);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = gzip.decompress(comp);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(
        "gzip_decompress_300k ns=" + str(best // iters) + " digest=" + str(digest(out))
    );
}


with entry {
    text: bytes = make_data();
    rnd: bytes = make_random(65536);
    zcomp: bytes = zlib.compress(text);
    gcomp: bytes = gzip.compress(text);

    bench_crc32(text, 30);
    bench_adler32(text, 30);
    bench_zlib_compress(text, 20);
    bench_zlib_decompress(zcomp, 20);
    bench_zlib_compress_rand(rnd, 20);
    bench_gzip_compress(text, 20);
    bench_gzip_decompress(gcomp, 20);
}
