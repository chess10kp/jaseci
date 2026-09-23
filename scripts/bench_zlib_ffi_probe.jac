import time;
import zlib;
import gzip;

import from z {
    def inflateInit2_(
        strm: bytes, windowBits: i32, version: int, stream_size: i32
    ) -> i32;
}
import from z { def inflate(strm: bytes, flush: i32) -> i32;  }
import from z { def inflateEnd(strm: bytes) -> i32;  }
import from z { def zlibVersion -> int;  }
import from c { def memchr(s: bytes, c: i32, n: u64) -> int;  }
import from c { def malloc(n: u64) -> int;  }
import from c { def free(p: int) -> None;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }

glob _Z_STREAM_SIZE: int = 112;


def _payload_addr(buf: bytes) -> int {
    if len(buf) == 0 {
        return 0;
    }
    return memchr(buf, i32(buf[0]), u64(1));
}


def ffi_inflate(src: bytes, out_cap: int, window_bits: int, to_bytes: bool) -> int {
    strm: bytes = b"\x00" * _Z_STREAM_SIZE;
    sa: int = _payload_addr(strm);
    __mem_store_i64(sa + 0, _payload_addr(src));
    __mem_store_i32(sa + 8, i32(len(src)));
    rc: int = inflateInit2_(strm, i32(window_bits), zlibVersion(), i32(_Z_STREAM_SIZE));
    if rc != 0 {
        return -rc;
    }
    buf: int = malloc(u64(out_cap));
    __mem_store_i64(sa + 24, buf);
    __mem_store_i32(sa + 32, i32(out_cap));
    status: int = inflate(strm, i32(0));
    total: int = __mem_load_i64(sa + 40);
    if to_bytes and status == 1 {
        out = b"\x00" * total;
        memcpy(out, buf, u64(total));
    }
    free(buf);
    inflateEnd(strm);
    return total;
}


def make_data -> bytes {
    return (b"The quick brown fox jumps over the lazy dog. " * 6000)
        + (b"0123456789" * 4000);
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
    cap: int = len(text);
    zcomp: bytes = zlib.compress(text);
    gcomp: bytes = gzip.compress(text);

    total: int = ffi_inflate(zcomp, cap, 15, False);
    print("zlib raw total=" + str(total));
    total = ffi_inflate(gcomp, cap, 31, False);
    print("gzip raw total=" + str(total));

    _bench("ffi_zlib_raw_300k", 20, lambda { ffi_inflate(zcomp, cap, 15, False); });
    _bench("ffi_zlib_copy_300k", 20, lambda { ffi_inflate(zcomp, cap, 15, True); });
    _bench("na_zlib_decompress_300k", 20, lambda { zlib.decompress(zcomp); });

    _bench("ffi_gzip_raw_300k", 20, lambda { ffi_inflate(gcomp, cap, 31, False); });
    _bench("ffi_gzip_copy_300k", 20, lambda { ffi_inflate(gcomp, cap, 31, True); });
    _bench("na_gzip_decompress_300k", 20, lambda { gzip.decompress(gcomp); });
}
