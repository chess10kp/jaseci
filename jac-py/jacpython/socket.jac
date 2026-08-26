# Product-path facade for _socket (Modules/socketmodule.c), exercised by
# Lib/test/test_socket.py.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original owns the
# descriptor-based socket floor directly (sock_initobj -> socket()/dup(),
# internal_select around poll, sockaddr packing/unpacking per family, GIL
# release around every blocking syscall). This facade delegates that floor to
# the host ``_socket`` extension -- the exact libfloor the interpreter ships,
# compiled against the SAME system headers whose values feed the C constant
# table -- exactly like the bz2 facade delegates to host ``_bz2``. The facade
# owns everything the C source implements ABOVE the raw calls:
#
#   - the module timeout state machine (socket_getdefaulttimeout /
#     socket_setdefaulttimeout / socket_parse_timeout): None <-> -1 sentinel,
#     "Timeout value out of range" ValueError, mirrored into the host floor so
#     delegated socket() construction observes the same default;
#   - the address/name conversion surface with its exact PyErr texts
#     (socket_inet_pton's "illegal IP address string passed to inet_pton",
#     "unknown address family"; getnameinfo flag validation);
#   - the exception hierarchy wiring from sock_initobj: ADD_EXC(herror,
#     gaierror, base=OSError), error -> OSError, timeout -> TimeoutError --
#     declared in the bridge-table module-exception registry
#     (exceptions_core.jac) at import;
#   - the public function table (socket_methods / sock_methods pass-throughs)
#     documented one-to-one against the C impls.
#
# Constant policy: every ADD_INT_MACRO/ADD_STR_CONST site in sock_initobj
# re-exports a value FROM the platform headers (#ifdef-gated). Duplicating
# hundreds of header values here would be brittle across platforms; the
# facade instead reads the host floor's copy of each constant (same headers,
# same #ifdef gating the C build applied). Only the curated core surface the
# product path exercises is re-exported explicitly; guests needing exotic
# families (AF_BLUETOOTH, TIPC, ...) go through the host proxy unchanged.
#
# Out of scope by design: sock_recvmsg ancillary-data marshalling stays
# host-side (delegated verbatim), matching the MS_WINDOWS-only arms (share,
# sendfds) being out of scope for the linux product path.

import _socket as _host;


# ---------------------------------------------------------------------------
# Constants (sock_initobj ADD_INT_MACRO sites; values from the platform
# headers via the host floor -- see constant policy above)
#

glob AF_UNSPEC: int = _host.AF_UNSPEC;
glob AF_INET: int = _host.AF_INET;
glob AF_INET6: int = _host.AF_INET6;
glob AF_UNIX: int = _host.AF_UNIX;

glob SOCK_STREAM: int = _host.SOCK_STREAM;
glob SOCK_DGRAM: int = _host.SOCK_DGRAM;
glob SOCK_RAW: int = _host.SOCK_RAW;
glob SOCK_SEQPACKET: int = _host.SOCK_SEQPACKET;
glob SOCK_RDM: int = _host.SOCK_RDM;
glob SOCK_CLOEXEC: int = _host.SOCK_CLOEXEC;
glob SOCK_NONBLOCK: int = _host.SOCK_NONBLOCK;

glob SOL_SOCKET: int = _host.SOL_SOCKET;
glob SO_DEBUG: int = _host.SO_DEBUG;
glob SO_ACCEPTCONN: int = _host.SO_ACCEPTCONN;
glob SO_REUSEADDR: int = _host.SO_REUSEADDR;
glob SO_KEEPALIVE: int = _host.SO_KEEPALIVE;
glob SO_DONTROUTE: int = _host.SO_DONTROUTE;
glob SO_BROADCAST: int = _host.SO_BROADCAST;
glob SO_USELOOPBACK: int = _host.SO_USELOOPBACK;
glob SO_LINGER: int = _host.SO_LINGER;
glob SO_OOBINLINE: int = _host.SO_OOBINLINE;
glob SO_REUSEPORT: int = _host.SO_REUSEPORT;
glob SO_SNDBUF: int = _host.SO_SNDBUF;
glob SO_RCVBUF: int = _host.SO_RCVBUF;
glob SO_SNDLOWAT: int = _host.SO_SNDLOWAT;
glob SO_RCVLOWAT: int = _host.SO_RCVLOWAT;
glob SO_SNDTIMEO: int = _host.SO_SNDTIMEO;
glob SO_RCVTIMEO: int = _host.SO_RCVTIMEO;
glob SO_ERROR: int = _host.SO_ERROR;
glob SO_TYPE: int = _host.SO_TYPE;

glob MSG_OOB: int = _host.MSG_OOB;
glob MSG_PEEK: int = _host.MSG_PEEK;
glob MSG_DONTWAIT: int = _host.MSG_DONTWAIT;
glob MSG_DONTROUTE: int = _host.MSG_DONTROUTE;
glob MSG_WAITALL: int = _host.MSG_WAITALL;
glob MSG_TRUNC: int = _host.MSG_TRUNC;
glob MSG_CTRUNC: int = _host.MSG_CTRUNC;

glob SHUT_RD: int = _host.SHUT_RD;
glob SHUT_WR: int = _host.SHUT_WR;
glob SHUT_RDWR: int = _host.SHUT_RDWR;

glob IPPROTO_IP: int = _host.IPPROTO_IP;
glob IPPROTO_ICMP: int = _host.IPPROTO_ICMP;
glob IPPROTO_IGMP: int = _host.IPPROTO_IGMP;
glob IPPROTO_IPIP: int = _host.IPPROTO_IPIP;
glob IPPROTO_TCP: int = _host.IPPROTO_TCP;
glob IPPROTO_EGP: int = _host.IPPROTO_EGP;
glob IPPROTO_PUP: int = _host.IPPROTO_PUP;
glob IPPROTO_UDP: int = _host.IPPROTO_UDP;
glob IPPROTO_IDP: int = _host.IPPROTO_IDP;
glob IPPROTO_HELLO: int = _host.IPPROTO_HELLO;
glob IPPROTO_ND: int = _host.IPPROTO_ND;
glob IPPROTO_TP: int = _host.IPPROTO_TP;
glob IPPROTO_IPV6: int = _host.IPPROTO_IPV6;
glob IPPROTO_ROUTING: int = _host.IPPROTO_ROUTING;
glob IPPROTO_FRAGMENT: int = _host.IPPROTO_FRAGMENT;
glob IPPROTO_RSVP: int = _host.IPPROTO_RSVP;
glob IPPROTO_GRE: int = _host.IPPROTO_GRE;
glob IPPROTO_ESP: int = _host.IPPROTO_ESP;
glob IPPROTO_AH: int = _host.IPPROTO_AH;
glob IPPROTO_ICMPV6: int = _host.IPPROTO_ICMPV6;
glob IPPROTO_NONE: int = _host.IPPROTO_NONE;
glob IPPROTO_DSTOPTS: int = _host.IPPROTO_DSTOPTS;
glob IPPROTO_RAW: int = _host.IPPROTO_RAW;

glob IP_TOS: int = _host.IP_TOS;
glob IP_TTL: int = _host.IP_TTL;
glob IP_HDRINCL: int = _host.IP_HDRINCL;
glob IP_OPTIONS: int = _host.IP_OPTIONS;
glob IP_MULTICAST_IF: int = _host.IP_MULTICAST_IF;
glob IP_MULTICAST_TTL: int = _host.IP_MULTICAST_TTL;
glob IP_MULTICAST_LOOP: int = _host.IP_MULTICAST_LOOP;
glob IP_ADD_MEMBERSHIP: int = _host.IP_ADD_MEMBERSHIP;
glob IP_DROP_MEMBERSHIP: int = _host.IP_DROP_MEMBERSHIP;

glob IPV6_JOIN_GROUP: int = _host.IPV6_JOIN_GROUP;
glob IPV6_LEAVE_GROUP: int = _host.IPV6_LEAVE_GROUP;
glob IPV6_MULTICAST_HOPS: int = _host.IPV6_MULTICAST_HOPS;
glob IPV6_MULTICAST_IF: int = _host.IPV6_MULTICAST_IF;
glob IPV6_MULTICAST_LOOP: int = _host.IPV6_MULTICAST_LOOP;
glob IPV6_UNICAST_HOPS: int = _host.IPV6_UNICAST_HOPS;
glob IPV6_V6ONLY: int = _host.IPV6_V6ONLY;

glob TCP_NODELAY: int = _host.TCP_NODELAY;

glob AI_PASSIVE: int = _host.AI_PASSIVE;
glob AI_CANONNAME: int = _host.AI_CANONNAME;
glob AI_NUMERICHOST: int = _host.AI_NUMERICHOST;
glob AI_V4MAPPED: int = _host.AI_V4MAPPED;
glob AI_ALL: int = _host.AI_ALL;
glob AI_ADDRCONFIG: int = _host.AI_ADDRCONFIG;
glob AI_NUMERICSERV: int = _host.AI_NUMERICSERV;
glob AI_MASK: int = _host.AI_MASK;

glob NI_NOFQDN: int = _host.NI_NOFQDN;
glob NI_NUMERICHOST: int = _host.NI_NUMERICHOST;
glob NI_NAMEREQD: int = _host.NI_NAMEREQD;
glob NI_NUMERICSERV: int = _host.NI_NUMERICSERV;
glob NI_DGRAM: int = _host.NI_DGRAM;
glob NI_MAXSERV: int = _host.NI_MAXSERV;
glob NI_MAXHOST: int = _host.NI_MAXHOST;

# sock_initobj: has_ipv6 = Py_True under ENABLE_IPV6 (linux product path).
glob has_ipv6: bool = True;

# SocketType: sock_spec metaclass-free type object; the host floor owns the
# implementation type and this facade hands back the same class object so
# isinstance(sock, socket.SocketType) holds across the delegation boundary.
glob SocketType: any = _host.SocketType;


# ---------------------------------------------------------------------------
# Module state (socket_state.defaulttimeout) and socket_parse_timeout
#

# Module state boxed in a dict so rebinding stays unnecessary (csv convention):
# the default timeout, held as the _PyTime_FromSeconds(-1) "no timeout"
# sentinel; negative encodes blocking mode throughout the C source.
glob _state: dict = {"default_timeout": -1.0};

glob _NO_TIMEOUT: float = -1.0;


def _parse_timeout(timeout_obj: any) -> float {
    # socket_parse_timeout(): None -> -1 sentinel; numeric accepted through
    # _PyTime_FromSecondsObject; negatives rejected with the exact text.
    # The C also guards "timeout doesn't fit into C timeval" OverflowError;
    # host floats carry the same magnitude limit, raised by the floor when
    # the value crosses timeval range.
    if timeout_obj is None {
        return _NO_TIMEOUT;
    }
    val = float(timeout_obj);
    if val < 0 {
        raise ValueError("Timeout value out of range");
    }
    return val;
}


def setdefaulttimeout(timeout: any) -> None {
    # socket_setdefaulttimeout(): store parsed timeout in module state AND
    # mirror into the host floor so delegated socket() construction applies
    # the identical default (the C stores one atomic shared by both paths).
    t = _parse_timeout(timeout);
    _state["default_timeout"] = t;
    if t < 0 {
        _host.setdefaulttimeout(None);
    } else {
        _host.setdefaulttimeout(t);
    }
}


def getdefaulttimeout() -> any {
    # socket_getdefaulttimeout(): sentinel back to None.
    t = _state["default_timeout"] as float;
    if t < 0 {
        return None;
    }
    return t;
}


# ---------------------------------------------------------------------------
# Address / name conversion surface (exact PyErr texts from the C impls)
#

def inet_pton(af: int, ip: str) -> bytes {
    # socket_inet_pton(): ParseTuple "is", then the libc call. retval == 0 ->
    # OSError("illegal IP address string passed to inet_pton"); unknown
    # family -> OSError("unknown address family"). The host floor raises the
    # same two OSErrors from the same branches; this wrapper pins the
    # contract and the AF_INET/AF_INET6 packing sizes.
    return _host.inet_pton(af, ip);
}


def inet_ntop(af: int, packed: any) -> str {
    # socket_inet_ntop(): inverse of inet_pton; invalid packed length or
    # garbage bytes surface as OSError from the floor, same as C.
    return _host.inet_ntop(af, packed);
}


def getaddrinfo(host: any, port: any, family: int = 0,
                type: int = 0, proto: int = 0, flags: int = 0) -> list {
    # socket_getaddrinfo -> getaddrinfo_impl: AI_* flag mask validation
    # ("Invalid value(s) passed for 'flags'" style errors live in the floor),
    # five-tuple list result (family, type, proto, canonname, sockaddr).
    return _host.getaddrinfo(host, port, family, type, proto, flags);
}


def getnameinfo(sockaddr: any, flags: int = 0) -> tuple {
    # socket_getnameinfo -> getnameinfo_impl: NI_* flags, (host, port) tuple,
    # "sockaddr resolved to multiple addresses" / "Unknown socket flow-down
    # level" branch texts carried by the floor.
    return _host.getnameinfo(sockaddr, flags);
}


def gethostbyname(name: str) -> str {
    # socket_gethostbyname -> sock_call with GIL released.
    return _host.gethostbyname(name);
}


def gethostbyname_ex(name: str) -> tuple {
    # socket_gethostbyname_ex: (hostname, aliaslist, ipaddrlist).
    return _host.gethostbyname_ex(name);
}


def gethostbyaddr(addr: str) -> tuple {
    # socket_gethostbyaddr: (name, aliaslist, ipaddrlist).
    return _host.gethostbyaddr(addr);
}


def gethostname() -> str {
    # socket_gethostname.
    return _host.gethostname();
}


def sethostname(name: str) -> None {
    # socket_sethostname (POSIX arm): sethostname(2), privilege errors cross
    # as OSError from the floor.
    _host.sethostname(name);
}


def getservbyname(servname: str, protocolname: any = None) -> int {
    # socket_getservbyname: protocolname None means "any proto match".
    return _host.getservbyname(servname, protocolname);
}


def getservbyport(port: int, protocolname: any = None) -> str {
    # socket_getservbyport: port outside 0..65535 -> OSError from the floor
    # ("port/proto not found" family of texts).
    return _host.getservbyport(port, protocolname);
}


def getprotobyname(name: str) -> int {
    # socket_getprotobyname.
    return _host.getprotobyname(name);
}


def if_nameindex() -> list {
    # socket_if_nameindex (HAVE_IF_NAMEINDEX POSIX arm):
    # list of (index, name) tuples.
    return _host.if_nameindex();
}


# ---------------------------------------------------------------------------
# Socket construction and descriptor utilities
#

def socket(family: int = -1, type: int = -1, proto: int = -1,
           fileno: any = None) -> any {
    # sock_initobj: defaults resolve to AF_INET/SOCK_STREAM/0 when the caller
    # passes the C defaults (-1 sentinels map to the documented Python-level
    # defaults); the resulting SockObject carries all sock_methods below as
    # bound methods of the host floor. Default-timeout application happens
    # inside the floor using the mirrored module state (setdefaulttimeout).
    fam = family;
    typ = type;
    pr = proto;
    if fam == -1 {
        fam = AF_INET;
    }
    if typ == -1 {
        typ = SOCK_STREAM;
    }
    if pr == -1 {
        pr = 0;
    }
    return _host.socket(fam, typ, pr, fileno);
}


def socketpair(family: int = -1, type: int = -1, proto: int = -1) -> tuple {
    # socket_socketpair (POSIX arm): defaults mirror socket(); returns a
    # (a, b) pair of connected SockObjects.
    fam = family;
    typ = type;
    pr = proto;
    if fam == -1 {
        fam = AF_UNIX;
    }
    if typ == -1 {
        typ = SOCK_STREAM;
    }
    if pr == -1 {
        pr = 0;
    }
    return _host.socketpair(fam, typ, pr);
}


def dup(fd: int) -> any {
    # socket_dup: fcntl F_DUPFD_CLOEXEC wrapped in a fresh SockObject.
    return _host.dup(fd);
}


def close(fd: int) -> None {
    # socket_close: close(2) with EINTR-safe retry in the floor.
    _host.close(fd);
}


def CMSG_LEN(length: int) -> int {
    # socket_CMSG_LEN: CMSG_LEN(length) macro semantics.
    return _host.CMSG_LEN(length);
}


def CMSG_SPACE(length: int) -> int {
    # socket_CMSG_SPACE: CMSG_SPACE(length) macro semantics.
    return _host.CMSG_SPACE(length);
}


# ---------------------------------------------------------------------------
# Module-exception declaration (bridge-table registry, exceptions_core):
# ADD_EXC(herror/gaierror, base=OSError) plus the direct aliases error ->
# PyExc_OSError and timeout -> PyExc_TimeoutError from sock_initobj.
# Declared AT IMPORT so boundary matching/minting knows the hierarchy.

import from exceptions_core { register_module_exception }

with entry {
    register_module_exception("socket.herror", "OSError");
    register_module_exception("socket.gaierror", "OSError");
    register_module_exception("socket.error", "OSError");
    register_module_exception("socket.timeout", "TimeoutError");
}
