"""Bundled native `select` cross-backend equivalence fixture (#6978).

The sv entry drives CPython's real `select` + `socket.socketpair`; the na
entry drives the bundled `na_stdlib/select.jac` (+ `socket.jac`'s
`socketpair`, an AF_UNIX SOCK_STREAM pair) through the same names -- the
`from:` pins bind the from-imports to the bundled modules on the native
backend while the py lane resolves them against CPython. Readiness is
exercised for real: a byte pushed through the socketpair makes the peer fd
readable on every backend. fd numbers are never compared across lanes (they
are process-local), only counts, event masks, and constants. ES/JS opts out.

Native scope notes: `select.select` returns a tuple like CPython; `poll` /
`epoll` objects expose register/modify/unregister/poll(/close/fileno).
`select.error` (`OSError`), `kqueue`, `devpoll`, and `epoll.fromfd` are
native gaps documented in the module.
"""

import from select {
    select,
    poll,
    epoll,
    POLLIN,
    POLLOUT,
    POLLERR,
    POLLHUP,
    EPOLLIN,
    EPOLLOUT,
    PIPE_BUF
}
import from socket { socket, socketpair }


def select_py() -> dict[any, any] {
    sp = socketpair();
    a = sp[0];
    b = sp[1];
    # Nothing written yet: read set empty, write set ready, zero timeout.
    t0 = select([a.fileno()], [a.fileno(), b.fileno()], [], 0.0);
    r0 = t0[0];
    w0 = t0[1];
    b.send(b"X");
    t1 = select([a.fileno()], [], [], 1.0);
    r1 = t1[0];
    got = a.recv(8);
    # select() with all-empty lists and a small timeout -> ((), (), ()).
    t2 = select([], [], [], 0.0);
    p = poll();
    p.register(a.fileno(), POLLIN);
    p.register(b.fileno(), POLLOUT);
    pevs = p.poll(0);
    pn = 0;
    pm = 0;
    samefd = 1;
    for pr in pevs {
        fd = pr[0];
        ev = pr[1];
        pn += 1;
        pm |= ev;
        if fd != a.fileno() and fd != b.fileno() {
            samefd = 0;
        }
    }
    p.unregister(b.fileno());
    p.modify(a.fileno(), POLLIN | POLLOUT);
    ep = epoll();
    ep.register(a.fileno(), EPOLLIN);
    b.send(b"Y");
    eevs = ep.poll(0.5, 4);
    en = 0;
    em = 0;
    efd = 1;
    for pr in eevs {
        fd = pr[0];
        ev = pr[1];
        en += 1;
        em |= ev;
        if fd != a.fileno() {
            efd = 0;
        }
    }
    epfd_ok = 1 if ep.fileno() >= 0 else 0;
    ep.close();
    a.close();
    b.close();
    return {
        "sel_r0": len(r0),
        "sel_w0": len(w0),
        "sel_r1": len(r1),
        "sel_r1fd": 1 if (len(r1) == 1 and r1[0] == a.fileno()) else 0,
        "sel_got": str(got),
        "sel_empty": len(t2[0]) + len(t2[1]) + len(t2[2]),
        "poll_n": pn,
        "poll_mask": pm,
        "poll_fds": samefd,
        "epoll_n": en,
        "epoll_mask": em,
        "epoll_fd": efd,
        "epoll_fileno": epfd_ok,
        "epoll_closed": 1 if ep.closed else 0,
        "c_pollin": POLLIN,
        "c_pollout": POLLOUT,
        "c_pollerr": POLLERR,
        "c_pollhup": POLLHUP,
        "c_epollin": EPOLLIN,
        "c_epollout": EPOLLOUT,
        "c_pipebuf": PIPE_BUF
    };
}


def select_cl() -> dict[any, any] {
    return {};
}


def select_na() -> dict[str, any] {
    sp: tuple[(socket, socket)] = socketpair();
    a = sp[0];
    b = sp[1];
    t0 = select([a.fileno()], [a.fileno(), b.fileno()], [], 0.0);
    r0 = t0[0];
    w0 = t0[1];
    b.send(b"X");
    t1 = select([a.fileno()], [], [], 1.0);
    r1 = t1[0];
    got = a.recv(8);
    t2 = select([], [], [], 0.0);
    p = poll();
    p.register(a.fileno(), POLLIN);
    p.register(b.fileno(), POLLOUT);
    pevs = p.poll(0);
    pn = 0;
    pm = 0;
    samefd = 1;
    for pr in pevs {
        fd = pr[0];
        ev = pr[1];
        pn += 1;
        pm |= ev;
        if fd != a.fileno() and fd != b.fileno() {
            samefd = 0;
        }
    }
    p.unregister(b.fileno());
    p.modify(a.fileno(), POLLIN | POLLOUT);
    ep = epoll();
    ep.register(a.fileno(), EPOLLIN);
    b.send(b"Y");
    eevs = ep.poll(0.5, 4);
    en = 0;
    em = 0;
    efd = 1;
    for pr in eevs {
        fd = pr[0];
        ev = pr[1];
        en += 1;
        em |= ev;
        if fd != a.fileno() {
            efd = 0;
        }
    }
    epfd_ok = 1 if ep.fileno() >= 0 else 0;
    ep.close();
    a.close();
    b.close();
    return {
        "sel_r0": len(r0),
        "sel_w0": len(w0),
        "sel_r1": len(r1),
        "sel_r1fd": 1 if (len(r1) == 1 and r1[0] == a.fileno()) else 0,
        "sel_got": str(got),
        "sel_empty": len(t2[0]) + len(t2[1]) + len(t2[2]),
        "poll_n": pn,
        "poll_mask": pm,
        "poll_fds": samefd,
        "epoll_n": en,
        "epoll_mask": em,
        "epoll_fd": efd,
        "epoll_fileno": epfd_ok,
        "epoll_closed": 1 if ep.closed else 0,
        "c_pollin": POLLIN,
        "c_pollout": POLLOUT,
        "c_pollerr": POLLERR,
        "c_pollhup": POLLHUP,
        "c_epollin": EPOLLIN,
        "c_epollout": EPOLLOUT,
        "c_pipebuf": PIPE_BUF
    };
}
