import time;
import zlib;
import from _zlib_native {
    z_strm_bytes,
    z_payload_addr,
    z_inflate_init,
    z_inflate_set_out,
    z_inflate,
    z_inflate_total_out,
    z_inflate_end,
    z_copy
}

glob _P_OK: int = 0,
     _P_END: int = 1,
     _P_BUF: int = -5;


def digest(data: bytes) -> int {
    acc: int = 1;
    n: int = len(data);
    i: int = 0;
    while i < n {
        acc = (acc * 131 + data[i]) % 2147483647;
        i += 1;
    }
    return acc;
}


def make_data -> bytes {
    return (b"The quick brown fox jumps over the lazy dog. " * 6000)
        + (b"0123456789" * 4000);
}


def decomp_grow(source: bytes, cap0: int) -> bytes {
    source_len: int = len(source);
    strm: bytes = z_strm_bytes();
    rc: int = z_inflate_init(strm, source, 0, source_len, 15);
    cap: int = cap0;
    out = b"\x00" * cap;
    total: int = 0;
    while True {
        if total == cap {
            newcap: int = cap * 2;
            newout = b"\x00" * newcap;
            z_copy(newout, z_payload_addr(out), total);
            out = newout;
            cap = newcap;
        }
        z_inflate_set_out(strm, out, total, cap - total);
        status: int = z_inflate(strm);
        total = z_inflate_total_out(strm);
        if status == _P_END {
            break;
        }
        if status != _P_OK and status != _P_BUF {
            break;
        }
    }
    z_inflate_end(strm);
    if total == cap {
        return out;
    }
    return out[0:total];
}


def decomp_fixed(source: bytes, cap0: int) -> bytes {
    source_len: int = len(source);
    strm: bytes = z_strm_bytes();
    rc: int = z_inflate_init(strm, source, 0, source_len, 15);
    out = b"\x00" * cap0;
    z_inflate_set_out(strm, out, 0, cap0);
    status: int = z_inflate(strm);
    total: int = z_inflate_total_out(strm);
    z_inflate_end(strm);
    return out[0:total];
}


def bench(label: str, comp: bytes, cap0: int, iters: int) {
    out = decomp_grow(comp, cap0);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = decomp_grow(comp, cap0);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(label + " ns=" + str(best // iters) + " digest=" + str(digest(out)));
}


def bench_fixed(comp: bytes, cap0: int, iters: int) {
    out = decomp_fixed(comp, cap0);
    best: int = 0;
    r: int = 0;
    while r < 3 {
        t0: int = time.perf_counter_ns();
        i: int = 0;
        while i < iters {
            out = decomp_fixed(comp, cap0);
            i += 1;
        }
        dt: int = time.perf_counter_ns() - t0;
        if best == 0 or dt < best {
            best = dt;
        }
        r += 1;
    }
    print(
        "fixed_"
            + str(cap0)
            + " ns="
            + str(best // iters)
            + " digest="
            + str(digest(out))
    );
}


with entry {
    text: bytes = make_data();
    comp: bytes = zlib.compress(text);
    print("comp_len=" + str(len(comp)) + " out_len=" + str(len(text)));
    bench("grow_8k", comp, 8192, 20);
    bench("grow_64k", comp, 65536, 20);
    bench("grow_310k", comp, 310000, 20);
    bench_fixed(comp, 524288, 20);
    bench_fixed(comp, 1048576, 20);
}
