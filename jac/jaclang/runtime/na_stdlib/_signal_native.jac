import from c { def bsd_signal(signum: i32, handler: int) -> int;  }
import from c { def kill(pid: i32, signum: i32) -> i32;  }
import from c { def getpid -> i32;  }
import from c { def ualarm(usecs: u32, interval: u32) -> u32;  }
import from c {
    def select(
        nfds: i32, readfds: int, writefds: int, exceptfds: int, timeout: int
    ) -> i32;
}
import from c { def sigdescr_np(signum: i32) -> str;  }
import from c { def sigprocmask(how: i32, set: bytes, oldset: bytes) -> i32;  }
import from c { def sigemptyset(set: bytes) -> i32;  }
import from c { def sigaddset(set: bytes, signum: i32) -> i32;  }
import from c { def sigismember(set: bytes, signum: i32) -> i32;  }
import from _errno_native { last_errno, errno_message }

glob _fn_handlers: dict[int, Callable[[int, any], None]] = {};

def _trampoline(signum: int) {
    if signum in _fn_handlers {
        _fn_handlers[signum](signum, None);
    }
}

def:pub sig_install_fn(signum: int, handler: Callable[[int, any], None]) -> int {
    _fn_handlers[signum] = handler;
    return bsd_signal(i32(signum), _trampoline);
}

def:pub sig_install_addr(signum: int, handler: int) -> int {
    if signum in _fn_handlers {
        del _fn_handlers[signum];
    }
    return bsd_signal(i32(signum), handler);
}

def:pub sig_kill_self(signum: int) -> int {
    return kill(getpid(), i32(signum));
}

def:pub sig_send(pid: int, signum: int) -> int {
    return kill(i32(pid), i32(signum));
}

def:pub sig_alarm(seconds: int) -> int {
    return int(ualarm(u32(seconds * 1000000), u32(0))) // 1000000;
}

def:pub sig_pause {
    select(i32(0), 0, 0, 0, 0);
}

def:pub sig_describe(signum: int) -> str {
    return sigdescr_np(i32(signum));
}

def:pub sig_mask(how: int, signums: list[int], nsig: int) -> list[int] {
    set_bits = b"\x00" * 128;
    sigemptyset(set_bits);
    for s in signums {
        if s >= 1 and s < nsig {
            sigaddset(set_bits, i32(s));
        }
    }
    old_bits = b"\x00" * 128;
    rc = sigprocmask(i32(how), set_bits, old_bits);
    if rc != 0 {
        return [-rc];
    }
    out: list[int] = [];
    for s in range(1, nsig) {
        if sigismember(old_bits, i32(s)) == 1 {
            out.append(s);
        }
    }
    return out;
}

def:pub sig_errno -> int {
    return last_errno();
}

def:pub sig_errno_text -> str {
    return errno_message();
}
