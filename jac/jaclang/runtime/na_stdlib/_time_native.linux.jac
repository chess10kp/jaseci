import from c { def clock_gettime(clk: i32, ts: &mut bytes) -> i32;  }
import from c {
    def clock_nanosleep(clk: i32, flags: i32, req: &bytes, rem: &mut bytes) -> i32;
}
import from _errno_native { EINTR, last_errno, raise_errno }
import from _time_common { _NS_PER_SEC, _ts_load }

glob _CLOCK_REALTIME_ID: int = 0,
     _CLOCK_MONOTONIC_ID: int = 1,
     _CLOCK_PROCESS_CPUTIME_ID: int = 2,
     _CLOCK_THREAD_CPUTIME_ID: int = 3,
     _CLOCK_MONOTONIC_RAW_ID: int = 4,
     _TIMER_ABSTIME: int = 1;

def:pub time_sleep_ns(ns: int) {
    now: own bytes = b"\x00" * 16;
    if clock_gettime(i32(_CLOCK_MONOTONIC_ID), &mut now) != 0 {
        raise_errno(last_errno());
    }
    add_sec: int = ns // _NS_PER_SEC;
    nsec: int = _ts_load(&now, 8) + ns - add_sec * _NS_PER_SEC;
    sec: int = _ts_load(&now, 0) + add_sec;
    if nsec >= _NS_PER_SEC {
        nsec -= _NS_PER_SEC;
        sec += 1;
    }
    req: own bytes = sec.to_bytes(8, "little") + nsec.to_bytes(8, "little");
    rem: own bytes = b"\x00" * 16;
    res: i32 = clock_nanosleep(
        i32(_CLOCK_MONOTONIC_ID), i32(_TIMER_ABSTIME), &req, &mut rem
    );
    while res == EINTR {
        res = clock_nanosleep(
            i32(_CLOCK_MONOTONIC_ID), i32(_TIMER_ABSTIME), &req, &mut rem
        );
    }
    if res != 0 {
        raise_errno(int(res));
    }
}
