import from c { def nanosleep(req: &bytes, rem: &mut bytes) -> i32;  }
import from _errno_native { EINTR, last_errno, raise_errno }
import from _time_common { _NS_PER_SEC, _ts_load }

glob _CLOCK_REALTIME_ID: int = 0,
     _CLOCK_MONOTONIC_ID: int = 6,
     _CLOCK_MONOTONIC_RAW_ID: int = 4,
     _CLOCK_PROCESS_CPUTIME_ID: int = 12,
     _CLOCK_THREAD_CPUTIME_ID: int = 16;

def:pub time_sleep_ns(ns: int) {
    sec: int = ns // _NS_PER_SEC;
    nsec: int = ns % _NS_PER_SEC;
    req: own bytes = sec.to_bytes(8, "little") + nsec.to_bytes(8, "little");
    rem: own bytes = b"\x00" * 16;
    while nanosleep(&req, &mut rem) != 0 {
        code: int = last_errno();
        if code == EINTR {
            rsec: int = _ts_load(&rem, 0);
            rnsec: int = _ts_load(&rem, 8);
            req = rsec.to_bytes(8, "little") + rnsec.to_bytes(8, "little");
            rem = b"\x00" * 16;
            continue;
        }
        raise_errno(code);
    }
}
