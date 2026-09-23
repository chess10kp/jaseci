"""Bundled native `socketserver` cross-backend equivalence fixture (#6978).

`import socketserver` binds the bundled `na_stdlib/socketserver.jac` module on
the na backend; the sv reference is CPython's real `socketserver`. Both sides
run a self-contained loopback echo: a server bound to an ephemeral port, a
client connect/send, one `handle_request()` pump, and a reply read.

API divergence exercised here: the bundled module takes a handler *instance*
(`TCPServer(addr, Echo())`) because native Jac cannot invoke a class object
stored in a field; CPython takes the handler *class* (`TCPServer(addr, Echo)`).
The handler classes also differ: the na handlers need an explicit no-arg
`init` so the instance is constructible before a request arrives. Everything
observable -- bound port, reply bytes, source address -- is pinned congruent.

The native functions return plain `int`s (counts of checks that held), driven
through the JIT (`get_func`), mirroring `test_socket_equivalence`.
"""

import os;
import socket;
import socketserver;


"""CPython echo handler (py lane): writes a fixed reply on the socket file."""
class _StreamEchoPy(socketserver.StreamRequestHandler) {
    def handle(self: _StreamEchoPy) {
        self.wfile.write(b"pong");
    }
}


"""CPython datagram handler (py lane): echoes via the BytesIO wfile."""
class _DatagramEchoPy(socketserver.DatagramRequestHandler) {
    def handle(self: _DatagramEchoPy) {
        self.wfile.write(b"pong");
    }
}


def socketserver_py -> dict[any, any] {
    srv = socketserver.TCPServer(("127.0.0.1", 0), _StreamEchoPy);
    port = int(srv.server_address[1]);
    cli = socket.create_connection(("127.0.0.1", port));
    srv.handle_request();
    resp = cli.makefile("rb").readline();
    cli.close();
    srv.server_close();
    return {"port_ok": 1 if port > 0 else 0, "tcp": 1 if resp == b"pong" else 0};
}


def socketserver_udp_py -> dict[any, any] {
    srv = socketserver.UDPServer(("127.0.0.1", 0), _DatagramEchoPy);
    port = int(srv.server_address[1]);
    cli = socket.socket(socket.AF_INET, socket.SOCK_DGRAM);
    cli.sendto(b"ping", ("127.0.0.1", port));
    srv.handle_request();
    (data, addr) = cli.recvfrom(64);
    cli.close();
    srv.server_close();
    return {
        "port_ok": 1 if port > 0 else 0,
        "udp": 1 if data == b"pong" else 0,
        "addr": 1 if addr[0] == "127.0.0.1" else 0
    };
}


def socketserver_cl -> dict[any, any] {
    return {};
}


import from socket { socket as Socket, AF_INET, SOCK_STREAM, SOCK_DGRAM }
import from socketserver {
    TCPServer,
    UDPServer,
    StreamRequestHandler,
    DatagramRequestHandler,
    BaseRequestHandler
}

# na lane handlers: instance-based (`Echo()`), so they need an explicit
# no-arg `init` -- the request is delivered later via `run`/`begin`.
obj _StreamEchoNa(StreamRequestHandler) {
    def init() {
    }
    def handle {
        self.wfile.write(b"pong");
    }
}

obj _DatagramEchoNa(DatagramRequestHandler) {
    def init() {
    }
    def handle {
        self.wfile.write(b"pong");
    }
}

obj _ShutdownEchoNa(StreamRequestHandler) {
    def init() {
    }
    def handle {
        self.wfile.write(b"pong");
        # na divergence: shutdown() just sets a flag (no inter-thread wait),
        # so it is callable from a handler on the same thread.
        self.server.shutdown();
    }
}

# TCP echo through TCPServer.handle_request: bind ephemeral, connect,
# pump one request, read the reply line. Returns checks held (4 == all).
def sserver_tcp_na -> int {
    srv = TCPServer(("127.0.0.1", 0), _StreamEchoNa());
    ok = 0;
    sn: tuple[(str, int, int, int)] = srv.server_address;
    port = sn[1];
    if port > 0 {
        ok += 1;
    }
    if srv.fileno() >= 0 {
        ok += 1;
    }
    cli = Socket(AF_INET, SOCK_STREAM);
    cli.connect(("127.0.0.1", port));
    srv.handle_request();
    resp = cli.makefile("rb").readline();
    if resp == b"pong" {
        ok += 1;
    }
    cli.close();
    srv.server_close();
    if srv.socket.fileno() < 0 {
        ok += 1;
    }
    return ok;
}

# UDP echo through UDPServer.handle_request: sendto, pump one request,
# recvfrom the reply. Returns checks held (3 == all).
def sserver_udp_na -> int {
    srv = UDPServer(("127.0.0.1", 0), _DatagramEchoNa());
    ok = 0;
    sn: tuple[(str, int, int, int)] = srv.server_address;
    port = sn[1];
    if port > 0 {
        ok += 1;
    }
    cli = Socket(AF_INET, SOCK_DGRAM);
    cli.sendto_addr(b"ping", ("127.0.0.1", port, 0, 0));
    srv.handle_request();
    rf: tuple[(bytes, tuple[(str, int, int, int)])] = cli.recvfrom(64);
    if rf[0] == b"pong" {
        ok += 1;
    }
    ra: tuple[(str, int, int, int)] = rf[1];
    if ra[0] == "127.0.0.1" {
        ok += 1;
    }
    cli.close();
    srv.server_close();
    return ok;
}

# serve_forever + handler-driven shutdown: the request is handled, then the
# loop exits when the handler sets the flag. Returns checks held (3 == all).
def sserver_forever_na -> int {
    srv = TCPServer(("127.0.0.1", 0), _ShutdownEchoNa());
    ok = 0;
    sn: tuple[(str, int, int, int)] = srv.server_address;
    port = sn[1];
    if port > 0 {
        ok += 1;
    }
    cli = Socket(AF_INET, SOCK_STREAM);
    cli.connect(("127.0.0.1", port));
    srv.serve_forever(0.05);
    ok += 1;
    resp = cli.makefile("rb").readline();
    if resp == b"pong" {
        ok += 1;
    }
    cli.close();
    srv.server_close();
    return ok;
}
