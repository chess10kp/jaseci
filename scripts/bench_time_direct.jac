import from c { def clock_gettime(clk: i32, ts: bytes) -> i32;  }

glob N: int = 1000000;

def _le64(buf: bytes, off: int) -> int {
    v: int = 0;
    i: int = 7;
    while i >= 0 {
        v = (v << 8) | buf[off + i];
        i -= 1;
    }
    return v;
}

def _now_ns(tb: bytes) -> int {
    clock_gettime(1, tb);
    return _le64(tb, 0) * 1000000000 + _le64(tb, 8);
}

glob buf = b"\x00" * 16,
     tb = b"\x00" * 16;

with entry {
    acc: int = 0;
    i: int = 0;

    t0: int = _now_ns(tb);
    while i < N {
        acc += i % 65536;
        i += 1;
    }
    t1: int = _now_ns(tb);
    print("bare_loop_ns_per_iter:", (t1 - t0) / N);

    i = 0;
    t0 = _now_ns(tb);
    while i < N {
        clock_gettime(1, buf);
        acc += buf[0];
        i += 1;
    }
    t1 = _now_ns(tb);
    print("ffi_call_reused_buf_ns_per_iter:", (t1 - t0) / N, "acc:", acc);

    i = 0;
    t0 = _now_ns(tb);
    while i < N {
        fbuf = b"\x00" * 16;
        clock_gettime(1, fbuf);
        acc += fbuf[0];
        i += 1;
    }
    t1 = _now_ns(tb);
    print("ffi_call_fresh_buf_ns_per_iter:", (t1 - t0) / N, "acc:", acc);

    i = 0;
    t0 = _now_ns(tb);
    while i < N {
        fbuf2 = b"\x00" * 16;
        clock_gettime(1, fbuf2);
        acc += (_le64(fbuf2, 0) * 1000000000 + _le64(fbuf2, 8)) % 65536;
        i += 1;
    }
    t1 = _now_ns(tb);
    print("ffi_call_alloc_parse_ns_per_iter:", (t1 - t0) / N, "acc:", acc);
}
