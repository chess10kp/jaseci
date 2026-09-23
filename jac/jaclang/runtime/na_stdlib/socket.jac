import from _socket_native {
    resolve_all,
    gai_str,
    sa_inet,
    sa_inet6,
    sa_un,
    sa_decode,
    sock_open,
    sock_pair,
    sock_connect,
    sock_send,
    sock_recv,
    sock_bind,
    sock_listen,
    sock_accept,
    sock_getsockname,
    sock_setsockopt,
    sock_sendto,
    sock_recvfrom,
    sock_shutdown,
    sock_close
}
import from _errno_native { errno_message }

glob AF_UNSPEC: int = 0,
     AF_UNIX: int = 1,
     AF_INET: int = 2,
     AF_INET6: int = 10;

glob SOCK_STREAM: int = 1,
     SOCK_DGRAM: int = 2;

glob IPPROTO_TCP: int = 6,
     IPPROTO_UDP: int = 17;

glob SHUT_RD: int = 0,
     SHUT_WR: int = 1,
     SHUT_RDWR: int = 2;

glob SOL_SOCKET: int = 1,
     SO_REUSEADDR: int = 2,
     SO_TYPE: int = 3,
     SO_BROADCAST: int = 6,
     SO_KEEPALIVE: int = 9,
     SO_REUSEPORT: int = 15,
     SOMAXCONN: int = 4096;

glob TCP_NODELAY: int = 1;


obj:pub socket {
    has family: int = 2,
        socktype: int = 1,
        proto: int = 0,
        _fd: int = -1;

    def init(
        family: int = 2, socktype: int = 1, proto: int = 0, fileno: int = -1
    ) {
        self.family = family;
        self.socktype = socktype;
        self.proto = proto;
        if fileno >= 0 {
            self._fd = fileno;
        } else {
            self._fd = sock_open(family, socktype, proto);
        }
    }

    def fileno -> int {
        return self._fd;
    }

    def _connect_sa(sa: bytes) -> bool {
        return sock_connect(self._fd, sa) == 0;
    }

    def connect(address: tuple[(str, int)]) -> None {
        if self._fd < 0 {
            raise OSError("socket() failed: " + errno_message());
        }
        host = address[0];
        port = address[1];
        service = str(port);
        (addrs, rc) = resolve_all(host, service);
        if len(addrs) == 0 {
            raise OSError(
                "getaddrinfo failed for " + host + ":" + service + ": " + gai_str(rc)
            );
        }
        for sa in addrs {
            fam = sa[0] + sa[1] * 256;
            if fam == self.family and self._connect_sa(sa) {
                return;
            }
        }
        raise OSError(
            "connect to " + host + ":" + service + " failed: " + errno_message()
        );
    }

    def send(data: bytes) -> int {
        sent = sock_send(self._fd, data, 0);
        if sent < 0 {
            raise OSError("send failed: " + errno_message());
        }
        return sent;
    }

    def sendall(data: bytes) {
        total = len(data);
        off = 0;
        while off < total {
            sent = sock_send(self._fd, data, off);
            if sent < 0 {
                raise OSError("send failed: " + errno_message());
            }
            if sent == 0 {
                raise OSError("send returned 0 (peer closed the connection)");
            }
            off += sent;
        }
    }

    def recv(bufsize: int) -> bytes {
        return sock_recv(self._fd, bufsize);
    }

    def connect_path(path: str) -> None {
        sa = sa_un(path);
        if sock_connect(self._fd, sa) < 0 {
            raise OSError("connect to " + path + " failed: " + errno_message());
        }
    }

    def connect6(address: tuple[(str, int, int, int)]) -> None {
        sa = sa_inet6(address[0], address[1], address[2], address[3]);
        if sock_connect(self._fd, sa) < 0 {
            raise OSError(
                "connect to " + address[0] + " failed: " + errno_message()
            );
        }
    }

    def bind(address: tuple[(str, int)]) -> None {
        sa = sa_inet(address[0], address[1]);
        if sock_bind(self._fd, sa) < 0 {
            raise OSError("bind failed: " + errno_message());
        }
    }

    def bind6(address: tuple[(str, int, int, int)]) -> None {
        sa = sa_inet6(address[0], address[1], address[2], address[3]);
        if sock_bind(self._fd, sa) < 0 {
            raise OSError("bind failed: " + errno_message());
        }
    }

    def bind_path(path: str) -> None {
        sa = sa_un(path);
        if sock_bind(self._fd, sa) < 0 {
            raise OSError("bind failed: " + errno_message());
        }
    }

    def listen(backlog: int = 4096) -> None {
        if sock_listen(self._fd, backlog) < 0 {
            raise OSError("listen failed: " + errno_message());
        }
    }

    def _fmt_addr(sa: bytes) -> tuple[(str, int, int, int)] {
        d = sa_decode(sa);
        return (d[1], d[2], d[3], d[4]);
    }

    def accept() -> tuple[(socket, tuple[(str, int, int, int)])] {
        pr = sock_accept(self._fd);
        cfd = pr[0];
        if cfd < 0 {
            raise OSError("accept failed: " + errno_message());
        }
        cs = socket(
            family=self.family, socktype=self.socktype, proto=self.proto, fileno=cfd
        );
        return (cs, self._fmt_addr(pr[1]));
    }

    def getsockname() -> tuple[(str, int, int, int)] {
        return self._fmt_addr(sock_getsockname(self._fd));
    }

    def setsockopt(level: int, optname: int, value: int) -> None {
        if sock_setsockopt(self._fd, level, optname, value) < 0 {
            raise OSError("setsockopt failed: " + errno_message());
        }
    }

    def sendto(
        data: bytes, address: tuple[(str, int)]
    ) -> int {
        sa = sa_inet(address[0], address[1]);
        sent = sock_sendto(self._fd, data, sa);
        if sent < 0 {
            raise OSError("sendto failed: " + errno_message());
        }
        return sent;
    }

    def sendto6(
        data: bytes, address: tuple[(str, int, int, int)]
    ) -> int {
        sa = sa_inet6(address[0], address[1], address[2], address[3]);
        sent = sock_sendto(self._fd, data, sa);
        if sent < 0 {
            raise OSError("sendto failed: " + errno_message());
        }
        return sent;
    }

    def sendto_path(data: bytes, path: str) -> int {
        sa = sa_un(path);
        sent = sock_sendto(self._fd, data, sa);
        if sent < 0 {
            raise OSError("sendto failed: " + errno_message());
        }
        return sent;
    }

    def recvfrom(bufsize: int) -> tuple[(bytes, tuple[(str, int, int, int)])] {
        pr = sock_recvfrom(self._fd, bufsize);
        return (pr[0], self._fmt_addr(pr[1]));
    }

    def shutdown(how: int) -> None {
        if sock_shutdown(self._fd, how) < 0 {
            raise OSError("shutdown failed: " + errno_message());
        }
    }

    def _sa4(addr: tuple[(str, int, int, int)]) -> bytes {
        if self.family == 1 {
            return sa_un(addr[0]);
        }
        if self.family == 10 {
            return sa_inet6(addr[0], addr[1], addr[2], addr[3]);
        }
        return sa_inet(addr[0], addr[1]);
    }

    def bind_addr(addr: tuple[(str, int, int, int)]) -> None {
        if sock_bind(self._fd, self._sa4(addr)) < 0 {
            raise OSError("bind failed: " + errno_message());
        }
    }

    def sendto_addr(data: bytes, addr: tuple[(str, int, int, int)]) -> int {
        sent = sock_sendto(self._fd, data, self._sa4(addr));
        if sent < 0 {
            raise OSError("sendto failed: " + errno_message());
        }
        return sent;
    }

    def makefile(mode: str = "r") -> SockFile {
        return SockFile(self);
    }

    def close {
        if self._fd >= 0 {
            sock_close(self._fd);
            self._fd = -1;
        }
    }
}


def:pub socketpair() -> tuple[(socket, socket)] {
    pr = sock_pair();
    a = socket(family=1, socktype=1, proto=0, fileno=pr[0]);
    b = socket(family=1, socktype=1, proto=0, fileno=pr[1]);
    return (a, b);
}


obj:pub SockFile {
    has _sock: socket,
        _rbuf: bytes = b"",
        closed: bool = False;

    def init(sock_: socket) {
        self._sock = sock_;
    }

    def fileno -> int {
        return self._sock.fileno();
    }

    def readable -> bool {
        return True;
    }

    def writable -> bool {
        return True;
    }

    def read(size: int = -1) -> bytes {
        if size < 0 {
            data = self._rbuf;
            self._rbuf = b"";
            chunk = self._sock.recv(8192);
            while len(chunk) > 0 {
                data += chunk;
                chunk = self._sock.recv(8192);
            }
            return data;
        }
        while len(self._rbuf) < size {
            chunk = self._sock.recv(8192);
            if len(chunk) == 0 {
                break;
            }
            self._rbuf += chunk;
        }
        n = size;
        if len(self._rbuf) < n {
            n = len(self._rbuf);
        }
        out = self._rbuf[0:n];
        self._rbuf = self._rbuf[n:len(self._rbuf)];
        return out;
    }

    def readline(limit: int = -1) -> bytes {
        nl = -1;
        i = 0;
        while i < len(self._rbuf) {
            if self._rbuf[i] == 10 {
                nl = i;
                break;
            }
            i += 1;
        }
        while nl < 0 {
            chunk = self._sock.recv(8192);
            if len(chunk) == 0 {
                break;
            }
            self._rbuf += chunk;
            i = 0;
            while i < len(self._rbuf) {
                if self._rbuf[i] == 10 {
                    nl = i;
                    break;
                }
                i += 1;
            }
        }
        end = len(self._rbuf);
        if nl >= 0 {
            end = nl + 1;
        }
        if limit >= 0 and end > limit {
            end = limit;
        }
        out = self._rbuf[0:end];
        self._rbuf = self._rbuf[end:len(self._rbuf)];
        return out;
    }

    def write(data: bytes) -> int {
        self._sock.sendall(data);
        return len(data);
    }

    def flush {
    }

    def close {
        if not self.closed {
            self.closed = True;
            self._sock.close();
        }
    }
}


def:pub create_connection(address: tuple[(str, int)]) -> socket {
    host = address[0];
    port = address[1];
    service = str(port);
    (addrs, rc) = resolve_all(host, service);
    if len(addrs) == 0 {
        raise OSError(
            "getaddrinfo failed for " + host + ":" + service + ": " + gai_str(rc)
        );
    }
    for sa in addrs {
        fam = sa[0] + sa[1] * 256;
        s = socket(family=fam, socktype=1, proto=0);
        if s.fileno() < 0 {
            continue;
        }
        if s._connect_sa(sa) {
            return s;
        }
        s.close();
    }
    raise OSError(
        "create_connection to " + host + ":" + service + " failed: " + errno_message()
    );
}
