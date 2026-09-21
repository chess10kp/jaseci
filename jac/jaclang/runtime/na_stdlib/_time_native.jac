import from c { def malloc(size: u64) -> int;  }
import from c { def clock_gettime(clk: i32, ts: int) -> i32;  }
import from c { def clock_settime(clk: i32, ts: int) -> i32;  }
import from c { def clock_nanosleep(clk: i32, flags: i32, req: int, rem: int) -> i32;  }
import from _errno_native { last_errno, raise_errno }

glob _CLOCK_REALTIME_ID: int = 0,
     _CLOCK_MONOTONIC_ID: int = 1,
     _CLOCK_PROCESS_CPUTIME_ID: int = 2,
     _CLOCK_THREAD_CPUTIME_ID: int = 3,
     _CLOCK_MONOTONIC_RAW_ID: int = 4,
     _TIMER_ABSTIME: int = 1,
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
    if clock_gettime(i32(_CLOCK_MONOTONIC_ID), _TS) != 0 {
        raise_errno(last_errno());
    }
    add_sec: int = ns // _NS_PER_SEC;
    nsec: int = __mem_load_i64(_TS + 8) + ns - add_sec * _NS_PER_SEC;
    sec: int = __mem_load_i64(_TS) + add_sec;
    if nsec >= _NS_PER_SEC {
        nsec -= _NS_PER_SEC;
        sec += 1;
    }
    __mem_store_i64(_TS, sec);
    __mem_store_i64(_TS + 8, nsec);
    res: i32 = clock_nanosleep(
        i32(_CLOCK_MONOTONIC_ID), i32(_TIMER_ABSTIME), _TS, _TS + 16
    );
    while res == EINTR {
        res = clock_nanosleep(
            i32(_CLOCK_MONOTONIC_ID), i32(_TIMER_ABSTIME), _TS, _TS + 16
        );
    }
    if res != 0 {
        raise_errno(int(res));
    }
}
