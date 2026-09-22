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


def _bench(label: str, iters: int, body: Callable[[], None]) {
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            body();
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(label + " ns=" + str(best // iters));
}


with entry {
    text: bytes = make_data();
    rnd: bytes = make_random(65536);
    zcomp: bytes = zlib.compress(text);
    gcomp: bytes = gzip.compress(text);

    crc: int = zlib.crc32(text);
    _bench("crc32_300k", 30, lambda { crc = zlib.crc32(text, crc); });
    print("  digest=" + str(crc));

    adl: int = zlib.adler32(text);
    _bench("adler32_300k", 30, lambda { adl = zlib.adler32(text, adl); });
    print("  digest=" + str(adl));

    zout: bytes = b"";
    _bench("zlib_compress_300k", 20, lambda { zout = zlib.compress(text); });
    print("  digest=" + str(digest(zout)));

    zback: bytes = b"";
    _bench("zlib_decompress_300k", 20, lambda { zback = zlib.decompress(zcomp); });
    print("  digest=" + str(digest(zback)));

    rout: bytes = b"";
    _bench("zlib_compress_rand64k", 20, lambda { rout = zlib.compress(rnd); });
    print("  digest=" + str(digest(rout)));

    gout: bytes = b"";
    _bench("gzip_compress_300k", 20, lambda { gout = gzip.compress(text); });
    print("  digest=" + str(digest(gout)));

    gback: bytes = b"";
    _bench("gzip_decompress_300k", 20, lambda { gback = gzip.decompress(gcomp); });
    print("  digest=" + str(digest(gback)));
}
