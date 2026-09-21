import from c { def malloc(size: u64) -> int;  }
import from c { def clock_gettime(clk: i32, ts: int) -> i32;  }
import from c { def clock_settime(clk: i32, ts: int) -> i32;  }
import from c { def nanosleep(req: int, rem: int) -> i32;  }
import from _errno_native { last_errno, raise_errno }

glob _CLOCK_REALTIME_ID: int = 0,
     _CLOCK_MONOTONIC_ID: int = 6,
     _CLOCK_MONOTONIC_RAW_ID: int = 4,
     _CLOCK_PROCESS_CPUTIME_ID: int = 12,
     _CLOCK_THREAD_CPUTIME_ID: int = 16,
     EINTR: int = 4,
     _NS_PER_SEC: int = 1000000000,
     _TS: int = malloc(32);

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

def:pub time_clock_ns(clk: int) -> int {
    if clock_gettime(i32(clk), _TS) != 0 {
        raise_errno(last_errno());
    }
    return __mem_load_i64(_TS) * _NS_PER_SEC + __mem_load_i64(_TS + 8);
}

def:pub time_clock_seconds(clk: int) -> float {
    if clock_gettime(i32(clk), _TS) != 0 {
        raise_errno(last_errno());
    }
    return float(__mem_load_i64(_TS)) + float(__mem_load_i64(_TS + 8)) * 1e-9;
}

def:pub time_clock_set_ns(clk: int, ns: int) {
    sec: int = ns // _NS_PER_SEC;
    __mem_store_i64(_TS, sec);
    __mem_store_i64(_TS + 8, ns - sec * _NS_PER_SEC);
    if clock_settime(i32(clk), _TS) != 0 {
        raise_errno(last_errno());
    }
}

def:pub time_sleep_ns(ns: int) {
    __mem_store_i64(_TS, ns // _NS_PER_SEC);
    __mem_store_i64(_TS + 8, ns % _NS_PER_SEC);
    while nanosleep(_TS, _TS + 16) != 0 {
        code: int = last_errno();
        if code == EINTR {
            __mem_store_i64(_TS, __mem_load_i64(_TS + 16));
            __mem_store_i64(_TS + 8, __mem_load_i64(_TS + 24));
            continue;
        }
        raise_errno(code);
    }
}
