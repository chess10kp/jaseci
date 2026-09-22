import from c { def clock_gettime(clk: i32, ts: bytes) -> i32;  }
import from c { def clock_settime(clk: i32, ts: bytes) -> i32;  }
import from c { def nanosleep(req: bytes, rem: bytes) -> i32;  }
import from _errno_native { EINTR, last_errno, raise_errno }

glob _CLOCK_REALTIME_ID: int = 0,
     _CLOCK_MONOTONIC_ID: int = 6,
     _CLOCK_MONOTONIC_RAW_ID: int = 4,
     _CLOCK_PROCESS_CPUTIME_ID: int = 12,
     _CLOCK_THREAD_CPUTIME_ID: int = 16,
     _NS_PER_SEC: int = 1000000000;

def:pub time_clk_realtime -> int {
    return _CLOCK_REALTIME_ID;
}

def:pub time_clk_monotonic -> int {
    return _CLOCK_MONOTONIC_ID;
}

def:pub time_clk_monotonic_raw -> int {
    return _CLOCK_MONOTONIC_RAW_ID;
}

def:pub time_clk_process_cputime -> int {
    return _CLOCK_PROCESS_CPUTIME_ID;
}

def:pub time_clk_thread_cputime -> int {
    return _CLOCK_THREAD_CPUTIME_ID;
}

def _ts_load(buf: bytes, off: int) -> int {
    v: int = 0;
    i: int = 7;
    while i >= 0 {
        v = (v << 8) | buf[off + i];
        i -= 1;
    }
    return v;
}

def:pub time_clock_ns(clk: int) -> int {
    ts: bytes = b"\x00" * 16;
    if clock_gettime(i32(clk), ts) != 0 {
        raise_errno(last_errno());
    }
    return _ts_load(ts, 0) * _NS_PER_SEC + _ts_load(ts, 8);
}

def:pub time_clock_seconds(clk: int) -> float {
    ts: bytes = b"\x00" * 16;
    if clock_gettime(i32(clk), ts) != 0 {
        raise_errno(last_errno());
    }
    return float(_ts_load(ts, 0)) + float(_ts_load(ts, 8)) * 1e-9;
}

def:pub time_clock_set_ns(clk: int, ns: int) {
    sec: int = ns // _NS_PER_SEC;
    nsec: int = ns - sec * _NS_PER_SEC;
    ts: bytes = sec.to_bytes(8, "little") + nsec.to_bytes(8, "little");
    if clock_settime(i32(clk), ts) != 0 {
        raise_errno(last_errno());
    }
}

def:pub time_sleep_ns(ns: int) {
    sec: int = ns // _NS_PER_SEC;
    nsec: int = ns % _NS_PER_SEC;
    req: bytes = sec.to_bytes(8, "little") + nsec.to_bytes(8, "little");
    rem: bytes = b"\x00" * 16;
    while nanosleep(req, rem) != 0 {
        code: int = last_errno();
        if code == EINTR {
            rsec: int = _ts_load(rem, 0);
            rnsec: int = _ts_load(rem, 8);
            req = rsec.to_bytes(8, "little") + rnsec.to_bytes(8, "little");
            rem = b"\x00" * 16;
            continue;
        }
        raise_errno(code);
    }
}
