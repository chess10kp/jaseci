import from c {
    def __select(nfds: i32, r: bytes, w: bytes, e: bytes, tv: bytes) -> i32;
}
import from c { def poll(fds: bytes, nfds: u64, timeout: i32) -> i32;  }
import from c { def epoll_create1(flags: i32) -> i32;  }
import from c { def epoll_ctl(epfd: i32, op: i32, fd: i32, ev: bytes) -> i32;  }
import from c {
    def epoll_wait(epfd: i32, evs: bytes, maxevents: i32, timeout: i32) -> i32;
}
import from c { def close(fd: i32) -> i32;  }
import from _errno_native { clear_errno, errno_message, last_errno }

glob:pub FD_SETSIZE: int = 1024;


def:pub raise_errno(what: str) {
    raise OSError(what + " failed: " + errno_message());
}


def:pub fdset_build(fds: list[int]) -> bytes {
    ba = bytearray(FD_SETSIZE // 8);
    for fd in fds {
        if fd < 0 or fd >= FD_SETSIZE {
            raise ValueError("filedescriptor out of range in select()");
        }
        ba[fd // 8] = ba[fd // 8] | (1 << (fd % 8));
    }
    return bytes(ba);
}


def:pub fdset_isset(setbuf: bytes, fd: int) -> bool {
    return (setbuf[fd // 8] & (1 << (fd % 8))) != 0;
}


def:pub timeval_build(timeout: float) -> bytes {
    if timeout < 0.0 {
        raise ValueError("timeout must be non-negative");
    }
    sec = int(timeout);
    usec = int((timeout - sec * 1.0) * 1000000.0);
    return sec.to_bytes(8, "little") + usec.to_bytes(8, "little");
}


def:pub sel_select_tv(
    nfds: int, rbuf: bytes, wbuf: bytes, ebuf: bytes, tvbuf: bytes
) -> int {
    clear_errno();
    return __select(i32(nfds), rbuf, wbuf, ebuf, tvbuf);
}


def:pub sel_select_inf(nfds: int, rbuf: bytes, wbuf: bytes, ebuf: bytes) -> int {
    clear_errno();
    return __select(i32(nfds), rbuf, wbuf, ebuf, 0);
}


def:pub pollfd_pack(fds: list[int], events: list[int]) -> bytes {
    out = b"";
    for i in range(len(fds)) {
        ev = events[i] & 0xFFFF;
        out += fds[i].to_bytes(4, "little") + ev.to_bytes(2, "little") + b"\x00\x00";
    }
    return out;
}


def:pub poll_call(buf: bytes, nfds: int, timeout_ms: int) -> int {
    clear_errno();
    return poll(buf, u64(nfds), i32(timeout_ms));
}


def:pub pollfd_revents(buf: bytes, i: int) -> int {
    off = i * 8 + 6;
    return int.from_bytes(buf[off:off + 2], "little");
}


def:pub epoll_create(flags: int) -> int {
    clear_errno();
    return epoll_create1(i32(flags));
}


def:pub epoll_event_pack(events: int, fd: int) -> bytes {
    return (events & 0xFFFFFFFF).to_bytes(4, "little") + fd.to_bytes(8, "little");
}


def:pub epoll_ctrl(epfd: int, op: int, fd: int, evbuf: bytes) -> int {
    clear_errno();
    return epoll_ctl(i32(epfd), i32(op), i32(fd), evbuf);
}


def:pub epoll_wait_call(
    epfd: int, evbuf: bytes, maxevents: int, timeout_ms: int
) -> int {
    clear_errno();
    return epoll_wait(i32(epfd), evbuf, i32(maxevents), i32(timeout_ms));
}


def:pub epoll_event_unpack(buf: bytes, i: int) -> tuple[(int, int)] {
    off = i * 12;
    events = int.from_bytes(buf[off:off + 4], "little");
    fd = int.from_bytes(buf[off + 4:off + 12], "little");
    return (fd, events);
}


def:pub fd_close(fd: int) {
    if fd >= 0 {
        close(i32(fd));
    }
}
