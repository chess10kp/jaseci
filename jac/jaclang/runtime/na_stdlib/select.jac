import from _select_native {
    FD_SETSIZE,
    epoll_create,
    epoll_ctrl,
    epoll_event_pack,
    epoll_event_unpack,
    epoll_wait_call,
    fd_close,
    fdset_build,
    fdset_isset,
    poll_call,
    pollfd_pack,
    pollfd_revents,
    raise_errno,
    sel_select_inf,
    sel_select_tv,
    timeval_build
}
import from _errno_native { last_errno }

glob:pub PIPE_BUF: int = 4096,
     POLLIN: int = 0x001,
     POLLPRI: int = 0x002,
     POLLOUT: int = 0x004,
     POLLERR: int = 0x008,
     POLLHUP: int = 0x010,
     POLLNVAL: int = 0x020,
     POLLRDNORM: int = 0x040,
     POLLRDBAND: int = 0x080,
     POLLWRNORM: int = 0x100,
     POLLWRBAND: int = 0x200,
     POLLMSG: int = 0x400,
     POLLRDHUP: int = 0x2000,
     EPOLLIN: int = 0x001,
     EPOLLPRI: int = 0x002,
     EPOLLOUT: int = 0x004,
     EPOLLRDNORM: int = 0x040,
     EPOLLRDBAND: int = 0x080,
     EPOLLWRNORM: int = 0x100,
     EPOLLWRBAND: int = 0x200,
     EPOLLRDHUP: int = 0x2000,
     EPOLLERR: int = 0x008,
     EPOLLHUP: int = 0x010,
     EPOLLET: int = 0x80000000,
     EPOLLONESHOT: int = 0x40000000,
     EPOLL_CTL_ADD: int = 1,
     EPOLL_CTL_DEL: int = 2,
     EPOLL_CTL_MOD: int = 3,
     EPOLL_CLOEXEC: int = 0x80000;

glob _EPOLL_DEF_MASK: int = 0x001 | 0x002 | 0x004,
     _EINTR: int = 4;


def _maxfd(lists: list[list[int]]) -> int {
    m = -1;
    for lst in lists {
        for fd in lst {
            if fd > m {
                m = fd;
            }
        }
    }
    return m;
}


def:pub select(
    rlist: list[int],
    wlist: list[int],
    xlist: list[int],
    timeout: (int | float | None) = None
) -> tuple[(list[int], list[int], list[int])] {
    rbuf = fdset_build(rlist);
    wbuf = fdset_build(wlist);
    ebuf = fdset_build(xlist);
    nfds = _maxfd([rlist, wlist, xlist]) + 1;
    while True {
        rc = -1;
        if timeout is None {
            rc = sel_select_inf(nfds, rbuf, wbuf, ebuf);
        } elif isinstance(timeout, float) {
            tf: float = timeout;
            rc = sel_select_tv(nfds, rbuf, wbuf, ebuf, timeval_build(tf));
        } elif isinstance(timeout, int) {
            ti: int = timeout;
            if ti < 0 {
                raise ValueError("timeout must be non-negative");
            }
            rc = sel_select_tv(
                nfds, rbuf, wbuf, ebuf, ti.to_bytes(8, "little") + b"\x00" * 8
            );
        }
        if rc >= 0 {
            break;
        }
        if last_errno() != _EINTR {
            raise_errno("select");
        }
    }
    rout: list[int] = [];
    wout: list[int] = [];
    eout: list[int] = [];
    for fd in rlist {
        if fdset_isset(rbuf, fd) {
            rout.append(fd);
        }
    }
    for fd in wlist {
        if fdset_isset(wbuf, fd) {
            wout.append(fd);
        }
    }
    for fd in xlist {
        if fdset_isset(ebuf, fd) {
            eout.append(fd);
        }
    }
    return (rout, wout, eout);
}


def _ceil_f(x: float) -> int {
    ms = int(x);
    if x - ms * 1.0 > 0.0 {
        ms += 1;
    }
    return ms;
}


def _ms_of(timeout: (int | float | None)) -> int {
    if timeout is None {
        return -1;
    }
    ms = -1;
    if isinstance(timeout, float) {
        tf: float = timeout;
        ms = _ceil_f(tf);
    } elif isinstance(timeout, int) {
        ti: int = timeout;
        ms = ti;
    }
    if ms < 0 {
        return -1;
    }
    return ms;
}


def _ms_ep(timeout: (int | float | None)) -> int {
    if timeout is None {
        return -1;
    }
    ms = -1;
    if isinstance(timeout, float) {
        tf: float = timeout;
        ms = _ceil_f(tf * 1000.0);
    } elif isinstance(timeout, int) {
        ti: int = timeout;
        ms = ti * 1000;
    }
    if ms < 0 {
        return -1;
    }
    return ms;
}


obj:pub poll {
    has _fds: dict[int, int] = {};

    def:pub register(fd: int, eventmask: int = 0x001 | 0x002 | 0x004) {
        self._fds[fd] = eventmask;
    }

    def:pub modify(fd: int, eventmask: int) {
        if not (fd in self._fds) {
            raise KeyError("fd not registered");
        }
        self._fds[fd] = eventmask;
    }

    def:pub unregister(fd: int) {
        if not (fd in self._fds) {
            raise KeyError("fd not registered");
        }
        del self._fds[fd];
    }

    def:pub poll(timeout: (int | float | None) = None) -> list[tuple[(int, int)]] {
        fds: list[int] = [];
        events: list[int] = [];
        for fd in self._fds.keys() {
            fds.append(fd);
            events.append(self._fds[fd]);
        }
        buf = pollfd_pack(fds, events);
        ms = _ms_of(timeout);
        while True {
            rc = poll_call(buf, len(fds), ms);
            if rc >= 0 {
                break;
            }
            if last_errno() != _EINTR {
                raise_errno("poll");
            }
        }
        out: list[tuple[(int, int)]] = [];
        for i in range(len(fds)) {
            rev = pollfd_revents(buf, i);
            if rev != 0 {
                out.append((fds[i], rev));
            }
        }
        return out;
    }
}


obj:pub epoll {
    has:pub closed: bool = False;
    has _epfd: int = -1;

    def init(sizehint: int = -1, flags: int = 0) {
        self._epfd = epoll_create(flags);
        if self._epfd < 0 {
            raise_errno("epoll_create1");
        }
    }

    def:pub fileno -> int {
        return self._epfd;
    }

    def:pub register(fd: int, eventmask: int = 0x001 | 0x002 | 0x004) {
        if self.closed {
            raise ValueError("epoll object is closed");
        }
        ev = epoll_event_pack(eventmask, fd);
        if epoll_ctrl(self._epfd, 1, fd, ev) < 0 {
            raise_errno("epoll_ctl");
        }
    }

    def:pub modify(fd: int, eventmask: int) {
        if self.closed {
            raise ValueError("epoll object is closed");
        }
        ev = epoll_event_pack(eventmask, fd);
        if epoll_ctrl(self._epfd, 3, fd, ev) < 0 {
            raise_errno("epoll_ctl");
        }
    }

    def:pub unregister(fd: int) {
        if self.closed {
            raise ValueError("epoll object is closed");
        }
        ev = epoll_event_pack(0, fd);
        if epoll_ctrl(self._epfd, 2, fd, ev) < 0 {
            raise_errno("epoll_ctl");
        }
    }

    def:pub poll(
        timeout: (int | float | None) = None, maxevents: int = -1
    ) -> list[tuple[(int, int)]] {
        if self.closed {
            raise ValueError("epoll object is closed");
        }
        if maxevents <= 0 {
            maxevents = FD_SETSIZE;
        }
        evbuf = b"\x00" * (maxevents * 12);
        ms = _ms_ep(timeout);
        while True {
            n = epoll_wait_call(self._epfd, evbuf, maxevents, ms);
            if n >= 0 {
                break;
            }
            if last_errno() != _EINTR {
                raise_errno("epoll_wait");
            }
        }
        out: list[tuple[(int, int)]] = [];
        for i in range(n) {
            out.append(epoll_event_unpack(evbuf, i));
        }
        return out;
    }

    def:pub close {
        if not self.closed {
            self.closed = True;
            fd_close(self._epfd);
            self._epfd = -1;
        }
    }
}
