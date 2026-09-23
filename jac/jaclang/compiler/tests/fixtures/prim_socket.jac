"""Bundled native `socket` cross-backend equivalence fixture (#6978 Phase 1).

`import socket` binds the bundled `na_stdlib/socket.jac` Mechanism-A/F module
(a pure-Jac client surface over the libc BSD-sockets FFI floor) on the na
backend; the sv reference is CPython's real `socket`. There is no live network:
the owning `test_socket_equivalence` suite stands up a loopback TCP/HTTP server
on an ephemeral port, publishes it in `JAC_SOCKET_TEST_PORT`, and pins the two
client implementations congruent on what a raw GET against the SAME server
yields -- the HTTP status code and the exact total response byte count (both
deterministic for a fixed server reply, so they must match to the byte).

Both sides drive a blocking TCP client by hand -- `create_connection`,
`sendall(request)`, then a `recv` loop to end-of-stream -- so the fixture
exercises the whole client path: DNS (loopback resolution through
`getaddrinfo`), `connect`, `send`, and a multi-`recv` read drain. The native
functions return plain `int`s, driven directly through the JIT (`get_func`),
mirroring `test_urllib_equivalence`. ES/JS opts out (no socket floor).
"""

import os;
import socket;


"""The fixed request both clients send (HTTP/1.0 + close so the server drains
and shuts the connection, ending the recv loop deterministically)."""
def _request -> str {
    return "GET /hello HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n";
}


"""Parse the HTTP status code from the start of a raw response (`HTTP/1.x SSS`).
The 3 status digits sit at byte offsets 9..11 of the status line."""
def _status_of(resp: bytes) -> int {
    if len(resp) < 12 {
        return -1;
    }
    return (resp[9] - 48) * 100 + (resp[10] - 48) * 10 + (resp[11] - 48);
}


def socket_py -> dict[any, any] {
    port = int(os.getenv("JAC_SOCKET_TEST_PORT"));
    s = socket.create_connection(("127.0.0.1", port));
    s.sendall(_request().encode());
    total = 0;
    first = b"";
    chunk = s.recv(4096);
    while len(chunk) > 0 {
        if len(first) == 0 {
            first = chunk;
        }
        total += len(chunk);
        chunk = s.recv(4096);
    }
    s.close();
    return {"status": _status_of(first), "total": total};
}


def socket_cl -> dict[any, any] {
    return {};
}


import from socket {
    create_connection,
    socket as Socket,
    AF_INET,
    SOCK_STREAM,
    SOCK_DGRAM,
    SOL_SOCKET,
    SO_REUSEADDR
}

# `_request`/`_status_of` are sv module-level helpers; native code can only
# reach them through the JIT interop bridge, so the request string and status
# parse are inlined here (the `test_urllib_equivalence` convention) to keep
# these functions fully native.
def socket_status_na -> int {
    port = int(os.getenv("JAC_SOCKET_TEST_PORT"));
    s = create_connection(("127.0.0.1", port));
    s.sendall(
        "GET /hello HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n".encode()
    );
    first = s.recv(4096);
    s.close();
    if len(first) < 12 {
        return -1;
    }
    return (first[9] - 48) * 100 + (first[10] - 48) * 10 + (first[11] - 48);
}

def socket_total_na -> int {
    port = int(os.getenv("JAC_SOCKET_TEST_PORT"));
    s = create_connection(("127.0.0.1", port));
    s.sendall(
        "GET /hello HTTP/1.0\r\nHost: 127.0.0.1\r\nConnection: close\r\n\r\n".encode()
    );
    total = 0;
    chunk = s.recv(4096);
    while len(chunk) > 0 {
        total += len(chunk);
        chunk = s.recv(4096);
    }
    s.close();
    return total;
}

# Connecting to a closed port must raise a *catchable* `OSError` -- proving
# the surface's error path unwinds to a handler one module up (native
# cross-module exceptions, #7013/#7021), not aborts. Returns 1 if caught.
def socket_refused_caught_na -> int {
    try {
        # Port 1 on loopback has no listener -> connect() ECONNREFUSED.
        s = create_connection(("127.0.0.1", 1));
        s.close();
        return 0;
    } except OSError as e {
        return 1;
    }
}

# Server-side surface (Phase 2): a full in-process TCP loopback exchange --
# setsockopt, bind on an ephemeral port, getsockname, listen, connect, accept,
# and a ping-pong over the accepted socket. Returns the count of checks that
# held (4 == all pass).
def socket_server_na -> int {
    srv = Socket(AF_INET, SOCK_STREAM);
    srv.setsockopt(SOL_SOCKET, SO_REUSEADDR, 1);
    srv.bind(("127.0.0.1", 0));
    srv.listen(4);
    sn: tuple[(str, int, int, int)] = srv.getsockname();
    port = sn[1];
    ok = 0;
    if port > 0 {
        ok += 1;
    }
    cli = Socket(AF_INET, SOCK_STREAM);
    cli.connect(("127.0.0.1", port));
    ac: tuple[(Socket, tuple[(str, int, int, int)])] = srv.accept();
    cs: Socket = ac[0];
    ca: tuple[(str, int, int, int)] = ac[1];
    if ca[0] == "127.0.0.1" and ca[1] > 0 {
        ok += 1;
    }
    cli.sendall(b"ping");
    if cs.recv(8) == b"ping" {
        ok += 1;
    }
    cs.sendall(b"pong");
    if cli.recv(8) == b"pong" {
        ok += 1;
    }
    cs.close();
    cli.close();
    srv.close();
    return ok;
}

# UDP datagram surface: bind both ends on ephemeral ports, sendto one byte
# pair, recvfrom the other, and confirm the decoded source address is the
# sender's bound address. Returns the count of checks that held (3 == all).
def socket_udp_na -> int {
    u1 = Socket(AF_INET, SOCK_DGRAM);
    u2 = Socket(AF_INET, SOCK_DGRAM);
    u1.bind(("127.0.0.1", 0));
    u2.bind(("127.0.0.1", 0));
    sn1: tuple[(str, int, int, int)] = u1.getsockname();
    sn2: tuple[(str, int, int, int)] = u2.getsockname();
    p1 = sn1[1];
    p2 = sn2[1];
    n = u1.sendto(b"hi", ("127.0.0.1", p2));
    rf: tuple[(bytes, tuple[(str, int, int, int)])] = u2.recvfrom(64);
    ok = 0;
    if n == 2 {
        ok += 1;
    }
    if rf[0] == b"hi" {
        ok += 1;
    }
    ra: tuple[(str, int, int, int)] = rf[1];
    if ra[0] == "127.0.0.1" and ra[1] == p1 {
        ok += 1;
    }
    u1.close();
    u2.close();
    return ok;
}
