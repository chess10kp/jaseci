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
import from z {
    def compress2(dst: bytes, dlen: bytes, src: bytes, slen: u64, lvl: i32) -> i32;
}
import from z { def compressBound(slen: u64) -> u64;  }
import from z { def crc32_z(crc: u64, buf: bytes, n: u64) -> u64;  }
import from z { def adler32_z(adler: u64, buf: bytes, n: u64) -> u64;  }
import from c { def memchr(s: bytes, c: i32, n: u64) -> int;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }

glob _Z_STREAM_SIZE: int = 112;


def _payload_addr(buf: bytes) -> int {
    if len(buf) == 0 {
        return 0;
    }
    return memchr(buf, i32(buf[0]), u64(1));
}


def _signed32(status: int) -> int {
    if status >= 2147483648 {
        return status - 4294967296;
    }
    return status;
}


# Raw floor: exact-size output, inflate straight into a bytes result.
def ffi_exact(src: bytes, out_cap: int, window_bits: int) -> int {
    strm: bytes = b"\x00" * _Z_STREAM_SIZE;
    sa: int = _payload_addr(strm);
    __mem_store_i64(sa + 0, _payload_addr(src));
    __mem_store_i32(sa + 8, i32(len(src)));
    rc: int = inflateInit2_(strm, i32(window_bits), zlibVersion(), i32(_Z_STREAM_SIZE));
    if rc != 0 {
        return -rc;
    }
    out: bytes = b"\x00" * out_cap;
    __mem_store_i64(sa + 24, _payload_addr(out));
    __mem_store_i32(sa + 32, i32(out_cap));
    status: int = inflate(strm, i32(0));
    total: int = __mem_load_i64(sa + 40);
    inflateEnd(strm);
    return total;
}


# Driver replica: bytes arena, regrow by doubling or predictor.
def ffi_grow(
    src: bytes, cap: int, ceiling: int, window_bits: int, use_pred: bool
) -> int {
    strm: bytes = b"\x00" * _Z_STREAM_SIZE;
    sa: int = _payload_addr(strm);
    src_len: int = len(src);
    __mem_store_i64(sa + 0, _payload_addr(src));
    __mem_store_i32(sa + 8, i32(src_len));
    rc: int = inflateInit2_(strm, i32(window_bits), zlibVersion(), i32(_Z_STREAM_SIZE));
    if rc != 0 {
        return -rc;
    }
    buf: bytes = b"\x00" * cap;
    status: int = 0;
    total: int = 0;
    while status == 0 {
        if total == cap {
            if cap >= ceiling {
                status = -5;
                break;
            }
            fed: int = __mem_load_i64(sa + 16);
            newcap: int = cap * 2;
            if use_pred and fed > 0 {
                pred: int = (total * src_len) // fed + total // 4 + 4096;
                if pred > newcap {
                    newcap = pred;
                }
            }
            if newcap > ceiling {
                newcap = ceiling;
            }
            nbuf: bytes = b"\x00" * newcap;
            memcpy(nbuf, _payload_addr(buf), u64(total));
            buf = nbuf;
            cap = newcap;
        }
        __mem_store_i64(sa + 24, _payload_addr(buf) + total);
        __mem_store_i32(sa + 32, i32(cap - total));
        status = inflate(strm, i32(0));
        total = __mem_load_i64(sa + 40);
        if status == -5 {
            fed2: int = __mem_load_i64(sa + 16);
            if fed2 < src_len {
                __mem_store_i32(sa + 8, i32(src_len - fed2));
                status = 0;
            } elif total == cap {
                status = 0;
            }
        }
    }
    inflateEnd(strm);
    return total;
}


# Raw floor: one crc32_z FFI call — what zlib.crc32 wraps.
def ffi_crc32(buf: bytes) -> int {
    return int(crc32_z(u64(0), buf, u64(len(buf))));
}


# Raw floor: one adler32_z FFI call — what zlib.adler32 wraps.
def ffi_adler32(buf: bytes) -> int {
    return int(adler32_z(u64(1), buf, u64(len(buf))));
}


# Raw floor: compress2 into a caller-owned dst+dlen cell, reset per call.
# Isolates deflate FFI cost from the driver's alloc + result-slice work.
def ffi_compress2_reuse(
    src: bytes, dst: bytes, dlen: bytes, bound: int, level: int
) -> int {
    __mem_store_i64(_payload_addr(dlen), bound);
    compress2(dst, dlen, src, u64(len(src)), i32(level));
    return int(__mem_load_i64(_payload_addr(dlen)));
}


# Honest floor: bound alloc + compress2 per call, but no result slice —
# same allocation shape as the driver, minus the dest[0:written] copy.
def ffi_compress2_alloc(src: bytes, bound: int, level: int) -> int {
    dst: bytes = b"\x00" * bound;
    dlen: bytes = bound.to_bytes(8, "little");
    compress2(dst, dlen, src, u64(len(src)), i32(level));
    return int.from_bytes(dlen, "little");
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
    cap: int = len(text);
    zcomp: bytes = zlib.compress(text);
    gcomp: bytes = gzip.compress(text);
    zlen: int = len(zcomp);
    glen: int = len(gcomp);
    ceil: int = zlen * 1032 + 67108864;
    crc: int = zlib.crc32(text);
    adl: int = zlib.adler32(text);
    cbound: int = int(compressBound(u64(len(text))));
    rbound: int = int(compressBound(u64(len(rnd))));
    cdst: bytes = b"\x00" * cbound;
    cdlen: bytes = cbound.to_bytes(8, "little");
    rdst: bytes = b"\x00" * rbound;
    rdlen: bytes = rbound.to_bytes(8, "little");
}

glob big: bytes = b"\x00" * 400000;

with entry {
    print("zcomp_len=" + str(zlen) + " gcomp_len=" + str(glen) + " out=" + str(cap));
    print("sanity ffi_exact=" + str(ffi_exact(zcomp, cap, 15)));
    print(
        "sanity ffi_compress2="
            + str(ffi_compress2_reuse(text, cdst, cdlen, cbound, -1))
    );

    # Component costs on this runner.
    _bench("op_zerofill_310k", 30, lambda { b"\x00" * 310000; });
    _bench("op_slice_310k", 30, lambda { big[0:310000]; });
    _bench(
        "op_memcpy_310k", 30, lambda { memcpy(big, _payload_addr(text), u64(310000)); }
    );

    # Checksums: driver is already one FFI call — floor delta should be ~0.
    _bench("ffi_crc32_300k", 30, lambda { ffi_crc32(text); });
    _bench("drv_crc32_300k", 30, lambda { zlib.crc32(text, crc); });
    _bench("ffi_adler32_300k", 30, lambda { ffi_adler32(text); });
    _bench("drv_adler32_300k", 30, lambda { zlib.adler32(text, adl); });

    # Compress floors: bare deflate FFI vs FFI+alloc vs the full driver.
    _bench(
        "ffi_compress2_reuse_300k",
        20,
        lambda { ffi_compress2_reuse(text, cdst, cdlen, cbound, -1); }
    );
    _bench(
        "ffi_compress2_alloc_300k",
        20,
        lambda { ffi_compress2_alloc(text, cbound, -1); }
    );
    _bench("drv_zlib_compress_300k", 20, lambda { zlib.compress(text); });
    _bench(
        "ffi_compress2_reuse_lvl9_300k",
        20,
        lambda { ffi_compress2_reuse(text, cdst, cdlen, cbound, 9); }
    );
    _bench("drv_gzip_compress_300k", 20, lambda { gzip.compress(text); });
    _bench(
        "ffi_compress2_reuse_rand64k",
        20,
        lambda { ffi_compress2_reuse(rnd, rdst, rdlen, rbound, -1); }
    );
    _bench("drv_zlib_compress_rand64k", 20, lambda { zlib.compress(rnd); });

    # Interleaved A/B rounds: isolates within-process gap from env noise.
    r: int = 0;
    while r < 4 {
        _bench(
            "A_ffi_zlib_exact_r" + str(r), 20, lambda { ffi_exact(zcomp, cap, 15); }
        );
        _bench("B_na_zlib_driver_r" + str(r), 20, lambda { zlib.decompress(zcomp); });
        r += 1;
    }

    # Driver-algorithm replica in this process: doubling vs predictor vs exact.
    _bench(
        "rep_zlib_double_300k",
        20,
        lambda { ffi_grow(zcomp, zlen * 4, ceil, 15, False); }
    );
    _bench(
        "rep_zlib_pred_300k", 20, lambda { ffi_grow(zcomp, zlen * 4, ceil, 15, True); }
    );
    _bench("rep_zlib_exact_300k", 20, lambda { ffi_exact(zcomp, cap, 15); });
    _bench("drv_zlib_decompress_300k", 20, lambda { zlib.decompress(zcomp); });

    # gzip: ISIZE gives exact cap — driver should match ffi_exact + crc.
    _bench("rep_gzip_exact_300k", 20, lambda { ffi_exact(gcomp, cap, 31); });
    _bench("drv_gzip_decompress_300k", 20, lambda { gzip.decompress(gcomp); });
}
