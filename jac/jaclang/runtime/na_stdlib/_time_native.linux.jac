import from c { def clock_gettime(clk: i32, ts: &mut bytes) -> i32;  }
import from c {
    def clock_nanosleep(clk: i32, flags: i32, req: &bytes, rem: &mut bytes) -> i32;
}
import from _errno_native { EINTR, last_errno, raise_errno }
import from _time_common { NS_PER_SEC, ts_load, ts_pack }

glob CLK_REALTIME: int = 0,
     CLK_MONOTONIC: int = 1,
     CLK_PROCESS_CPUTIME: int = 2,
     CLK_THREAD_CPUTIME: int = 3,
     CLK_MONOTONIC_RAW: int = 4,
     _TIMER_ABSTIME: int = 1;

def:pub time_sleep_ns(ns: int) {
    now: own bytes = b"\x00" * 16;
    if clock_gettime(i32(CLK_MONOTONIC), &mut now) != 0 {
        raise_errno(last_errno());
    }
    add_sec: int = ns // NS_PER_SEC;
    nsec: int = ts_load(&now, 8) + ns - add_sec * NS_PER_SEC;
    sec: int = ts_load(&now, 0) + add_sec;
    if nsec >= NS_PER_SEC {
        nsec -= NS_PER_SEC;
        sec += 1;
    }
    req: own bytes = ts_pack(sec, nsec);
    rem: own bytes = b"\x00" * 16;
    res: i32 = clock_nanosleep(i32(CLK_MONOTONIC), i32(_TIMER_ABSTIME), &req, &mut rem);
    while res == EINTR {
        res = clock_nanosleep(i32(CLK_MONOTONIC), i32(_TIMER_ABSTIME), &req, &mut rem);
    }
    if res != 0 {
        raise_errno(int(res));
    }
}
