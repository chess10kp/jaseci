import from c { def clock_gettime(clk: i32, ts: &mut bytes) -> i32;  }
import from c { def clock_settime(clk: i32, ts: &bytes) -> i32;  }
import from _errno_native { last_errno, raise_errno }

glob _NS_PER_SEC: int = 1000000000;

def _ts_load(buf: &bytes, off: int) -> int {
    v: int = 0;
    i: int = 7;
    while i >= 0 {
        v = (v << 8) | buf[off + i];
        i -= 1;
    }
    return v;
}

def:pub time_clock_ns(clk: int) -> int {
    ts: own bytes = b"\x00" * 16;
    if clock_gettime(i32(clk), &mut ts) != 0 {
        raise_errno(last_errno());
    }
    return _ts_load(&ts, 0) * _NS_PER_SEC + _ts_load(&ts, 8);
}

def:pub time_clock_seconds(clk: int) -> float {
    ts: own bytes = b"\x00" * 16;
    if clock_gettime(i32(clk), &mut ts) != 0 {
        raise_errno(last_errno());
    }
    return float(_ts_load(&ts, 0)) + float(_ts_load(&ts, 8)) * 1e-9;
}

def:pub time_clock_set_ns(clk: int, ns: int) {
    sec: int = ns // _NS_PER_SEC;
    nsec: int = ns - sec * _NS_PER_SEC;
    ts: own bytes = sec.to_bytes(8, "little") + nsec.to_bytes(8, "little");
    if clock_settime(i32(clk), &ts) != 0 {
        raise_errno(last_errno());
    }
}
