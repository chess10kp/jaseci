import from c { def nanosleep(req: &bytes, rem: &mut bytes) -> i32;  }
import from _errno_native { EINTR, last_errno, raise_errno }
import from _time_common { NS_PER_SEC, ts_load, ts_pack }

glob CLK_REALTIME: int = 0,
     CLK_MONOTONIC: int = 6,
     CLK_MONOTONIC_RAW: int = 4,
     CLK_PROCESS_CPUTIME: int = 12,
     CLK_THREAD_CPUTIME: int = 16;

def:pub time_sleep_ns(ns: int) {
    sec: int = ns // NS_PER_SEC;
    nsec: int = ns % NS_PER_SEC;
    req: own bytes = ts_pack(sec, nsec);
    rem: own bytes = b"\x00" * 16;
    while nanosleep(&req, &mut rem) != 0 {
        code: int = last_errno();
        if code == EINTR {
            req = ts_pack(ts_load(&rem, 0), ts_load(&rem, 8));
            rem = b"\x00" * 16;
            continue;
        }
        raise_errno(code);
    }
}
