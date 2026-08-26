# Native socket data-surface facade (lift of reference/cpython/Modules/
# socketmodule.c, first slice).
#
# socket_exec() is a pure-data prologue before any call path: it declares the
# module exception hierarchy (herror / gaierror under OSError, plus the
# ``error`` -> OSError and ``timeout`` -> TimeoutError aliases), installs the
# socket type, then walks ~700 lines of guarded ADD_INT_MACRO /
# ADD_INT_CONST calls exporting every platform constant in insertion order.
# This facade mirrors that constant table for the Linux/glibc build of the
# pinned CPython 3.14 reference: the lists below are the C file's insertion
# ORDER with only the branches whose guards hold on this platform (#ifdef on
# glibc-defined macros; MS_WINDOWS / USE_BLUETOOTH / macOS-only branches never
# fire here). Insertion order is semantic -- later duplicate adds overwrite --
# so the table must not be sorted or deduped. Values verified against the host
# interpreter's own socket module at authoring time (every name resolves and
# agrees, including the AF_VSOCK explicit-literal block).
#
# Divergence ledger candidates for follow-up slices:
# - Exception CLASS OBJECTS are not installed in the attrs table yet; the
#   hierarchy is declared through the bridge-table registry instead
#   (register_module_exception, same convention as _csvmodule.jac). Guest code
#   catching socket.error resolves via the builtins alias to OSError;
#   herror/gaierror matching works through the registry.
# - The sock type object (socket.socket / SocketType) and every function
#   (bind/connect/send/recv/getaddrinfo/...) belong to later slices; this
#   slice carries the data surface so guest imports of socket/_socket resolve
#   and constant-driven test_socket paths convert.
#
# Wiring: ceval.jac registers this surface as a lazy shim for BOTH the
# ``socket`` and ``_socket`` import names in import_native and host_import,
# mirroring CPython where Lib/socket.py is a thin wrapper over the _socket
# accelerator and suite routing rewrites facade-module:socket->_socket.

import from exceptions_core { register_module_exception }
import from objects { PyObj, PyInt, PyBool }

# Names and values in socketmodule.c socket_exec() insertion order,
# Linux/glibc surface; _socket_names[i] <-> _socket_vals[i].
def _socket_names -> list[str] {
    return [
    "AF_UNSPEC", "AF_INET", "AF_UNIX", "AF_AX25", "AF_IPX", "AF_APPLETALK", "AF_NETROM", "AF_BRIDGE",
    "AF_ATMPVC", "AF_X25", "AF_INET6", "AF_ROSE", "AF_DECnet", "AF_NETBEUI", "AF_SECURITY", "AF_KEY",
    "AF_NETLINK", "NETLINK_ROUTE", "NETLINK_USERSOCK", "NETLINK_FIREWALL", "NETLINK_NFLOG", "NETLINK_XFRM", "NETLINK_IP6_FW", "NETLINK_DNRTMSG",
    "NETLINK_CRYPTO", "AF_QIPCRTR", "AF_VSOCK", "SO_VM_SOCKETS_BUFFER_SIZE", "SO_VM_SOCKETS_BUFFER_MIN_SIZE", "SO_VM_SOCKETS_BUFFER_MAX_SIZE", "VMADDR_CID_ANY", "VMADDR_PORT_ANY",
    "VMADDR_CID_LOCAL", "VMADDR_CID_HOST", "VM_SOCKETS_INVALID_VERSION", "IOCTL_VM_SOCKETS_GET_LOCAL_CID", "AF_ROUTE", "AF_ASH", "AF_ECONET", "AF_ATMSVC",
    "AF_SNA", "AF_IRDA", "AF_PPPOX", "AF_WANPIPE", "AF_LLC", "AF_CAN", "PF_CAN", "AF_RDS",
    "PF_RDS", "AF_PACKET", "PF_PACKET", "PACKET_HOST", "PACKET_BROADCAST", "PACKET_MULTICAST", "PACKET_OTHERHOST", "PACKET_OUTGOING",
    "PACKET_LOOPBACK", "PACKET_FASTROUTE", "ETHERTYPE_ARP", "ETHERTYPE_IP", "ETHERTYPE_IPV6", "ETHERTYPE_VLAN", "ETH_P_ALL", "SOCK_STREAM",
    "SOCK_DGRAM", "SOCK_RAW", "SOCK_SEQPACKET", "SOCK_RDM", "SOCK_CLOEXEC", "SOCK_NONBLOCK", "SO_DEBUG", "SO_ACCEPTCONN",
    "SO_REUSEADDR", "SO_INCOMING_CPU", "SO_KEEPALIVE", "SO_DONTROUTE", "SO_BROADCAST", "SO_LINGER", "SO_OOBINLINE", "SO_ORIGINAL_DST",
    "SO_REUSEPORT", "SO_SNDBUF", "SO_RCVBUF", "SO_SNDLOWAT", "SO_RCVLOWAT", "SO_SNDTIMEO", "SO_RCVTIMEO", "SO_ERROR",
    "SO_TYPE", "SO_PASSCRED", "SO_PEERCRED", "SO_PASSSEC", "SO_PEERSEC", "SO_BINDTODEVICE", "SO_BINDTOIFINDEX", "SO_PRIORITY",
    "SO_MARK", "SO_DOMAIN", "SO_PROTOCOL", "SOMAXCONN", "SCM_RIGHTS", "SCM_CREDENTIALS", "MSG_OOB", "MSG_PEEK",
    "MSG_DONTROUTE", "MSG_DONTWAIT", "MSG_EOR", "MSG_TRUNC", "MSG_CTRUNC", "MSG_WAITALL", "MSG_NOSIGNAL", "MSG_CMSG_CLOEXEC",
    "MSG_ERRQUEUE", "MSG_CONFIRM", "MSG_MORE", "MSG_FASTOPEN", "SOL_SOCKET", "SOL_IP", "SOL_TCP", "SOL_UDP",
    "SOL_CAN_BASE", "SOL_CAN_RAW", "CAN_RAW", "SOL_RDS", "IPPROTO_IP", "IPPROTO_HOPOPTS", "IPPROTO_ICMP", "IPPROTO_IGMP",
    "IPPROTO_IPV6", "IPPROTO_IPIP", "IPPROTO_TCP", "IPPROTO_EGP", "IPPROTO_PUP", "IPPROTO_UDP", "IPPROTO_UDPLITE", "UDPLITE_SEND_CSCOV",
    "UDPLITE_RECV_CSCOV", "IPPROTO_IDP", "IPPROTO_TP", "IPPROTO_ROUTING", "IPPROTO_FRAGMENT", "IPPROTO_RSVP", "IPPROTO_GRE", "IPPROTO_ESP",
    "IPPROTO_AH", "IPPROTO_ICMPV6", "IPPROTO_NONE", "IPPROTO_DSTOPTS", "IPPROTO_PIM", "IPPROTO_SCTP", "IPPROTO_MPTCP", "IPPROTO_RAW",
    "IPPORT_RESERVED", "IPPORT_USERRESERVED", "INADDR_ANY", "INADDR_BROADCAST", "INADDR_LOOPBACK", "INADDR_UNSPEC_GROUP", "INADDR_ALLHOSTS_GROUP", "INADDR_MAX_LOCAL_GROUP",
    "INADDR_NONE", "IP_OPTIONS", "IP_HDRINCL", "IP_TOS", "IP_TTL", "IP_RECVERR", "IP_RECVOPTS", "IP_RECVORIGDSTADDR",
    "IP_RECVRETOPTS", "IP_RECVTOS", "IP_RECVTTL", "IP_RETOPTS", "IP_MULTICAST_IF", "IP_MULTICAST_TTL", "IP_MULTICAST_LOOP", "IP_ADD_MEMBERSHIP",
    "IP_DROP_MEMBERSHIP", "IP_DEFAULT_MULTICAST_TTL", "IP_DEFAULT_MULTICAST_LOOP", "IP_MAX_MEMBERSHIPS", "IP_FREEBIND", "IP_TRANSPARENT", "IP_PKTINFO", "IP_BIND_ADDRESS_NO_PORT",
    "IP_UNBLOCK_SOURCE", "IP_BLOCK_SOURCE", "IP_ADD_SOURCE_MEMBERSHIP", "IP_DROP_SOURCE_MEMBERSHIP", "IPV6_JOIN_GROUP", "IPV6_LEAVE_GROUP", "IPV6_MULTICAST_HOPS", "IPV6_MULTICAST_IF",
    "IPV6_MULTICAST_LOOP", "IPV6_UNICAST_HOPS", "IPV6_V6ONLY", "IPV6_CHECKSUM", "IPV6_DONTFRAG", "IPV6_DSTOPTS", "IPV6_HOPLIMIT", "IPV6_HOPOPTS",
    "IPV6_NEXTHOP", "IPV6_PATHMTU", "IPV6_PKTINFO", "IPV6_RECVDSTOPTS", "IPV6_RECVERR", "IPV6_RECVHOPLIMIT", "IPV6_RECVHOPOPTS", "IPV6_RECVPKTINFO",
    "IPV6_RECVRTHDR", "IPV6_RECVTCLASS", "IPV6_RTHDR", "IPV6_RTHDRDSTOPTS", "IPV6_RTHDR_TYPE_0", "IPV6_RECVPATHMTU", "IPV6_TCLASS", "TCP_NODELAY",
    "TCP_MAXSEG", "TCP_CORK", "TCP_KEEPIDLE", "TCP_KEEPINTVL", "TCP_KEEPCNT", "TCP_SYNCNT", "TCP_LINGER2", "TCP_DEFER_ACCEPT",
    "TCP_WINDOW_CLAMP", "TCP_INFO", "TCP_QUICKACK", "TCP_CONGESTION", "TCP_MD5SIG", "TCP_THIN_LINEAR_TIMEOUTS", "TCP_THIN_DUPACK", "TCP_USER_TIMEOUT",
    "TCP_REPAIR", "TCP_REPAIR_QUEUE", "TCP_QUEUE_SEQ", "TCP_REPAIR_OPTIONS", "TCP_FASTOPEN", "TCP_TIMESTAMP", "TCP_NOTSENT_LOWAT", "TCP_CC_INFO",
    "TCP_SAVE_SYN", "TCP_SAVED_SYN", "TCP_REPAIR_WINDOW", "TCP_FASTOPEN_CONNECT", "TCP_ULP", "TCP_MD5SIG_EXT", "TCP_FASTOPEN_KEY", "TCP_FASTOPEN_NO_COOKIE",
    "TCP_ZEROCOPY_RECEIVE", "TCP_INQ", "TCP_TX_DELAY", "EAI_ADDRFAMILY", "EAI_AGAIN", "EAI_BADFLAGS", "EAI_FAIL", "EAI_FAMILY",
    "EAI_MEMORY", "EAI_NODATA", "EAI_NONAME", "EAI_OVERFLOW", "EAI_SERVICE", "EAI_SOCKTYPE", "EAI_SYSTEM", "AI_PASSIVE",
    "AI_CANONNAME", "AI_NUMERICHOST", "AI_NUMERICSERV", "AI_ALL", "AI_ADDRCONFIG", "AI_V4MAPPED", "NI_MAXHOST", "NI_MAXSERV",
    "NI_NOFQDN", "NI_NUMERICHOST", "NI_NAMEREQD", "NI_NUMERICSERV", "NI_DGRAM", "NI_IDN", "SHUT_RD", "SHUT_WR",
    "SHUT_RDWR",
    ];
}

def _socket_vals -> list[int] {
    return [
    0, 2, 1, 3, 4, 5, 6, 7,
    8, 9, 10, 11, 12, 13, 14, 15,
    16, 0, 2, 3, 5, 6, 13, 14,
    21, 42, 40, 0, 1, 2, 4294967295, 4294967295,
    1, 2, 4294967295, 1977, 16, 18, 19, 20,
    22, 23, 24, 25, 26, 29, 29, 21,
    21, 17, 17, 0, 1, 2, 3, 4,
    5, 6, 2054, 2048, 34525, 33024, 3, 1,
    2, 3, 5, 4, 524288, 2048, 1, 30,
    2, 49, 9, 5, 6, 13, 10, 80,
    15, 7, 8, 19, 18, 21, 20, 4,
    3, 16, 17, 34, 31, 25, 62, 12,
    36, 39, 38, 4096, 1, 2, 1, 2,
    4, 64, 128, 32, 8, 256, 16384, 1073741824,
    8192, 2048, 32768, 536870912, 1, 0, 6, 17,
    100, 101, 1, 276, 0, 0, 1, 2,
    41, 4, 6, 8, 12, 17, 136, 10,
    11, 22, 29, 43, 44, 46, 47, 50,
    51, 58, 59, 60, 103, 132, 262, 255,
    1024, 5000, 0, 4294967295, 2130706433, 3758096384, 3758096385, 3758096639,
    4294967295, 4, 3, 1, 2, 11, 6, 20,
    7, 13, 12, 7, 32, 33, 34, 35,
    36, 1, 1, 20, 15, 19, 8, 24,
    37, 38, 39, 40, 20, 21, 18, 17,
    19, 16, 26, 7, 62, 59, 52, 54,
    9, 61, 50, 58, 25, 51, 53, 49,
    56, 66, 57, 55, 0, 60, 67, 1,
    2, 3, 4, 5, 6, 7, 8, 9,
    10, 11, 12, 13, 14, 16, 17, 18,
    19, 20, 21, 22, 23, 24, 25, 26,
    27, 28, 29, 30, 31, 32, 33, 34,
    35, 36, 37, -9, -3, -1, -4, -6,
    -10, -5, -2, -12, -8, -7, -11, 1,
    2, 4, 1024, 16, 32, 8, 1025, 32,
    4, 1, 8, 2, 16, 32, 0, 1,
    2,
    ];
}

# Shim-module attribute table consumed by the ceval import sites.
def socket_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    names = _socket_names();
    vals = _socket_vals();
    for i in range(len(names)) {
        attrs[names[i]] = PyInt(t="int", val=vals[i]);
    }
    # ENABLE_IPV6 branch holds on Linux/glibc.
    attrs["has_ipv6"] = PyBool(t="bool", val=True);
    return attrs;
}

with entry {
    # Module-exception declaration (bridge-table registry, exceptions_core):
    # ADD_EXC(m, "herror", ..., PyExc_OSError) and ADD_EXC(m, "gaierror",
    # ..., PyExc_OSError) at socket_exec(). ``error`` (OSError) and
    # ``timeout`` (TimeoutError) are plain builtin aliases -- no declaration.
    register_module_exception("socket.herror", "OSError");
    register_module_exception("socket.gaierror", "OSError");
}
