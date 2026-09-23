import from c { def socket(domain: i32, socktype: i32, protocol: i32) -> i32;  }
import from c {
    def syscall(num: i64, a: i64, b: i64, c: i64, d: bytes) -> i64;
}
import from c { def connect(fd: i32, addr: bytes, addrlen: i32) -> i32;  }
import from c { def bind(fd: i32, addr: bytes, addrlen: i32) -> i32;  }
import from c { def listen(fd: i32, backlog: i32) -> i32;  }
import from c { def accept(fd: i32, addr: bytes, addrlen: bytes) -> i32;  }
import from c {
    def getsockname(fd: i32, addr: bytes, addrlen: bytes) -> i32;
}
import from c {
    def setsockopt(
        fd: i32, level: i32, optname: i32, optval: bytes, optlen: i32
    ) -> i32;
}
import from c { def send(fd: i32, buf: bytes, n: u64, flags: i32) -> i64;  }
import from c { def recv(fd: i32, buf: bytes, n: u64, flags: i32) -> i64;  }
import from c {
    def sendto(
        fd: i32, buf: bytes, n: u64, flags: i32, addr: bytes, addrlen: i32
    ) -> i64;
}
import from c {
    def recvfrom(
        fd: i32, buf: bytes, n: u64, flags: i32, addr: bytes, addrlen: bytes
    ) -> i64;
}
import from c { def close(fd: i32) -> i32;  }
import from c { def shutdown(fd: i32, how: i32) -> i32;  }
import from c { def inet_pton(af: i32, src: str, dst: bytes) -> i32;  }
import from c { def inet_ntop(af: i32, src: bytes, dst: bytes, size: i32) -> str;  }
import from c { def strncpy(dst: bytes, src: str, n: u64) -> int;  }
import from c {
    def getaddrinfo(hostname: str, service: str, hints: int, res: bytes) -> i32;
}
import from c { def freeaddrinfo(res: int) -> None;  }
import from c { def gai_strerror(errcode: i32) -> str;  }
import from c { def memcpy(dst: bytes, src: int, n: u64) -> int;  }
import from _errno_native { errno_message }

glob _AI_ADDRLEN_OFF: int = 16,
     _AI_ADDR_OFF: int = 24,
     _AI_NEXT_OFF: int = 40,
     _AI_SIZE: int = 48;

glob _SOCKADDR_MAX: int = 128;


def:pub resolve_all(host: str, service: str) -> tuple[(list[bytes], int)] {
    out: list[bytes] = [];
    res_slot = b"\x00" * 8;
    rc = getaddrinfo(host, service, 0, res_slot);
    if rc != 0 {
        return (out, rc);
    }
    head = int.from_bytes(res_slot, "little");
    cur = head;
    while cur != 0 {
        ai = b"\x00" * _AI_SIZE;
        memcpy(ai, cur, u64(_AI_SIZE));
        addrlen = int.from_bytes(ai[_AI_ADDRLEN_OFF:_AI_ADDRLEN_OFF + 4], "little");
        addr = int.from_bytes(ai[_AI_ADDR_OFF:_AI_ADDR_OFF + 8], "little");
        if addr != 0 and addrlen > 0 and addrlen <= _SOCKADDR_MAX {
            sa = b"\x00" * addrlen;
            memcpy(sa, addr, u64(addrlen));
            out.append(sa);
        }
        cur = int.from_bytes(ai[_AI_NEXT_OFF:_AI_NEXT_OFF + 8], "little");
    }
    if head != 0 {
        freeaddrinfo(head);
    }
    return (out, 0);
}


def:pub gai_str(rc: int) -> str {
    return gai_strerror(i32(rc));
}


def:pub sock_open(family: int, socktype: int, proto: int) -> int {
    return socket(i32(family), i32(socktype), i32(proto));
}


def:pub sock_pair() -> tuple[(int, int)] {
    sv = b"\x00" * 8;
    if syscall(53, 1, 1, 0, sv) < 0 {
        raise OSError("socketpair failed: " + errno_message());
    }
    return (
        int.from_bytes(sv[0:4], "little"), int.from_bytes(sv[4:8], "little")
    );
}


def:pub sock_connect(fd: int, sa: bytes) -> int {
    return connect(i32(fd), sa, i32(len(sa)));
}


def:pub sock_send(fd: int, data: bytes, off: int) -> int {
    n = len(data);
    if off >= n {
        return 0;
    }
    chunk = data[off:n];
    sent = send(i32(fd), chunk, u64(len(chunk)), 0);
    return sent;
}


def:pub sock_recv(fd: int, bufsize: int) -> bytes {
    if bufsize <= 0 {
        return b"";
    }
    buf = b"\x00" * bufsize;
    got = recv(i32(fd), buf, u64(bufsize), 0);
    if got < 0 {
        raise OSError("recv failed: " + errno_message());
    }
    if got == 0 {
        return b"";
    }
    return buf[0:got];
}


def:pub sock_close(fd: int) {
    if fd >= 0 {
        close(i32(fd));
    }
}


def:pub sock_shutdown(fd: int, how: int) -> int {
    return shutdown(i32(fd), i32(how));
}


def:pub sa_inet(host: str, port: int) -> bytes {
    ab = b"\x00" * 4;
    if len(host) > 0 and inet_pton(2, host, ab) != 1 {
        r: tuple[(list[bytes], int)] = resolve_all(host, str(port));
        addrs: list[bytes] = r[0];
        for sa in addrs {
            fam = sa[0] + sa[1] * 256;
            if fam == 2 {
                return sa;
            }
        }
        raise OSError("no AF_INET address for " + host);
    }
    return (2).to_bytes(2, "little") + port.to_bytes(2, "big") + ab + b"\x00" * 8;
}


def:pub sa_inet6(
    host: str, port: int, flowinfo: int, scopeid: int
) -> bytes {
    ab = b"\x00" * 16;
    if len(host) > 0 and inet_pton(10, host, ab) != 1 {
        r: tuple[(list[bytes], int)] = resolve_all(host, str(port));
        addrs: list[bytes] = r[0];
        for sa in addrs {
            fam = sa[0] + sa[1] * 256;
            if fam == 10 {
                return sa;
            }
        }
        raise OSError("no AF_INET6 address for " + host);
    }
    return (10).to_bytes(2, "little") + port.to_bytes(2, "big") + flowinfo.to_bytes(
        4, "big"
    ) + ab + scopeid.to_bytes(4, "little");
}


def:pub sa_un(path: str) -> bytes {
    n = len(path);
    if n >= 108 {
        raise OSError("AF_UNIX path too long");
    }
    pb = b"\x00" * 108;
    if n > 0 {
        strncpy(pb, path, u64(n));
    }
    return (1).to_bytes(2, "little") + pb[0:n + 1];
}


def:pub sa_decode(sa: bytes) -> tuple[(int, str, int, int, int)] {
    fam = sa[0] + sa[1] * 256;
    if fam == 2 {
        port = int.from_bytes(sa[2:4], "big");
        db = b"\x00" * 16;
        ip = inet_ntop(2, sa[4:8], db, 16);
        return (2, ip, port, 0, 0);
    }
    if fam == 10 {
        port = int.from_bytes(sa[2:4], "big");
        flw = int.from_bytes(sa[4:8], "big");
        scid = int.from_bytes(sa[24:28], "little");
        db = b"\x00" * 46;
        ip = inet_ntop(10, sa[8:24], db, 46);
        return (10, ip, port, flw, scid);
    }
    if fam == 1 {
        n = 0;
        while 2 + n < len(sa) and sa[2 + n] != 0 {
            n += 1;
        }
        return (1, sa[2:2 + n].decode(), 0, 0, 0);
    }
    return (fam, "", 0, 0, 0);
}


def:pub sock_bind(fd: int, sa: bytes) -> int {
    return bind(i32(fd), sa, i32(len(sa)));
}


def:pub sock_listen(fd: int, backlog: int) -> int {
    return listen(i32(fd), i32(backlog));
}


def:pub sock_accept(fd: int) -> tuple[(int, bytes)] {
    sa = b"\x00" * 128;
    ln = (128).to_bytes(8, "little");
    cfd = accept(i32(fd), sa, ln);
    if cfd < 0 {
        return (-1, b"");
    }
    alen = int.from_bytes(ln[0:4], "little");
    if alen > 128 {
        alen = 128;
    }
    return (cfd, sa[0:alen]);
}


def:pub sock_getsockname(fd: int) -> bytes {
    sa = b"\x00" * 128;
    ln = (128).to_bytes(8, "little");
    if getsockname(i32(fd), sa, ln) < 0 {
        raise OSError("getsockname failed: " + errno_message());
    }
    alen = int.from_bytes(ln[0:4], "little");
    if alen > 128 {
        alen = 128;
    }
    return sa[0:alen];
}


def:pub sock_setsockopt(fd: int, level: int, optname: int, value: int) -> int {
    vb = value.to_bytes(4, "little");
    return setsockopt(i32(fd), i32(level), i32(optname), vb, 4);
}


def:pub sock_sendto(fd: int, data: bytes, sa: bytes) -> int {
    return sendto(i32(fd), data, u64(len(data)), 0, sa, i32(len(sa)));
}


def:pub sock_recvfrom(fd: int, bufsize: int) -> tuple[(bytes, bytes)] {
    if bufsize <= 0 {
        return (b"", b"");
    }
    buf = b"\x00" * bufsize;
    sa = b"\x00" * 128;
    ln = (128).to_bytes(8, "little");
    got = recvfrom(i32(fd), buf, u64(bufsize), 0, sa, ln);
    if got < 0 {
        raise OSError("recvfrom failed: " + errno_message());
    }
    alen = int.from_bytes(ln[0:4], "little");
    if alen > 128 {
        alen = 128;
    }
    if got == 0 {
        return (b"", sa[0:alen]);
    }
    return (buf[0:got], sa[0:alen]);
}
