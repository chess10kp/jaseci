# Native errno module facade (lift of reference/cpython/Modules/errnomodule.c).
#
# errnomodule.c is a pure-data module: at multi-phase init (errno_exec) it
# inserts every platform errno constant into the module dict and the inverse
# mapping into the ``errorcode`` dict. This facade mirrors that surface for the
# Linux/glibc build of the pinned CPython 3.14 reference: the tables below are
# the C file's add_errcode() insertion ORDER with every guard whose macro is
# defined on this platform (#ifdef guards; WSA #else fallback branches never
# fire on Linux). Insertion order is semantic -- duplicate codes overwrite in
# dict order (errorcode[11] -> "EAGAIN", not "EWOULDBLOCK"; 35 -> "EDEADLK"),
# so the table must not be sorted or deduped. Verified against the host
# interpreter's own errno module at authoring time.
#
# Wiring: ceval.jac registers this surface as a lazy shim in both import_native
# and host_import, so guest ``import errno`` resolves proxy-free like
# heapq/traceback instead of leaking a PyHostProxy whose errorcode round-trip
# degrades guest int/str identity.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyDict,
    DictEntry,
    hashkey_str,
}

# Names and codes in errnomodule.c insertion order, Linux/glibc surface;
# _errno_names[i] <-> _errno_codes[i].
def _errno_names -> list[str] {
    return [
    "ENODEV", "ENOCSI", "EHOSTUNREACH", "EHOSTUNREACH", "ENOMSG", "EUCLEAN", "EL2NSYNC", "EL2HLT",
    "ENODATA", "ENOTBLK", "ENOSYS", "EPIPE", "EINVAL", "EINVAL", "EOVERFLOW", "EADV", "EINTR",
    "EINTR", "EUSERS", "EUSERS", "ENOTEMPTY", "ENOTEMPTY", "ENOBUFS", "ENOBUFS", "EPROTO",
    "EREMOTE", "EREMOTE", "ENAVAIL", "ECHILD", "ELOOP", "ELOOP", "EXDEV", "E2BIG", "ESRCH",
    "EMSGSIZE", "EMSGSIZE", "EAFNOSUPPORT", "EAFNOSUPPORT", "EBADR", "EHOSTDOWN", "EHOSTDOWN",
    "EPFNOSUPPORT", "EPFNOSUPPORT", "ENOPROTOOPT", "ENOPROTOOPT", "EBUSY", "EWOULDBLOCK",
    "EWOULDBLOCK", "EBADFD", "EDOTDOT", "EISCONN", "EISCONN", "ENOANO", "ESHUTDOWN", "ESHUTDOWN",
    "ECHRNG", "ELIBBAD", "ENONET", "EBADE", "EBADF", "EBADF", "EMULTIHOP", "EIO", "EUNATCH",
    "EPROTOTYPE", "EPROTOTYPE", "ENOSPC", "ENOEXEC", "EALREADY", "EALREADY", "ENETDOWN",
    "ENETDOWN", "ENOTNAM", "EACCES", "EACCES", "ELNRNG", "EILSEQ", "ENOTDIR", "ENOTUNIQ", "EPERM",
    "EDOM", "EXFULL", "ECONNREFUSED", "ECONNREFUSED", "EISDIR", "EPROTONOSUPPORT",
    "EPROTONOSUPPORT", "EROFS", "EADDRNOTAVAIL", "EADDRNOTAVAIL", "EIDRM", "ECOMM", "ESRMNT",
    "EREMOTEIO", "EL3RST", "EBADMSG", "ENFILE", "ELIBMAX", "ESPIPE", "ENOLINK", "ENETRESET",
    "ENETRESET", "ETIMEDOUT", "ETIMEDOUT", "ENOENT", "EEXIST", "EDQUOT", "EDQUOT", "ENOSTR",
    "EBADSLT", "EBADRQC", "ELIBACC", "EFAULT", "EFAULT", "EFBIG", "EDEADLK", "ENOTCONN",
    "ENOTCONN", "EDESTADDRREQ", "EDESTADDRREQ", "ELIBSCN", "ENOLCK", "EISNAM", "ECONNABORTED",
    "ECONNABORTED", "ENETUNREACH", "ENETUNREACH", "ESTALE", "ESTALE", "ENOSR", "ENOMEM",
    "ENOTSOCK", "ENOTSOCK", "ESTRPIPE", "EMLINK", "ERANGE", "ELIBEXEC", "EL3HLT", "ECONNRESET",
    "ECONNRESET", "EADDRINUSE", "EADDRINUSE", "EOPNOTSUPP", "EOPNOTSUPP", "EREMCHG", "EAGAIN",
    "ENAMETOOLONG", "ENAMETOOLONG", "ENOTTY", "ERESTART", "ESOCKTNOSUPPORT", "ESOCKTNOSUPPORT",
    "ETIME", "EBFONT", "EDEADLOCK", "ETOOMANYREFS", "ETOOMANYREFS", "EMFILE", "EMFILE", "ETXTBSY",
    "EINPROGRESS", "EINPROGRESS", "ENXIO", "ENOPKG", "ENOMEDIUM", "EMEDIUMTYPE", "ECANCELED",
    "ENOKEY", "EHWPOISON", "EKEYEXPIRED", "EKEYREVOKED", "EKEYREJECTED", "EOWNERDEAD",
    "ENOTRECOVERABLE", "ERFKILL", "ECANCELED", "ENOTSUP", "EOWNERDEAD", "ENOTRECOVERABLE"
    ];
}

def _errno_codes -> list[int] {
    return [
    19, 50, 113, 113, 42, 117, 45, 51, 61, 15, 38, 32, 22, 22, 75, 68, 4, 4, 87, 87, 39, 39, 105,
    105, 71, 66, 66, 119, 10, 40, 40, 18, 7, 3, 90, 90, 97, 97, 53, 112, 112, 96, 96, 92, 92, 16,
    11, 11, 77, 73, 106, 106, 55, 108, 108, 44, 80, 64, 52, 9, 9, 72, 5, 49, 91, 91, 28, 8, 114,
    114, 100, 100, 118, 13, 13, 48, 84, 20, 76, 1, 33, 54, 111, 111, 21, 93, 93, 30, 99, 99, 43,
    70, 69, 121, 47, 74, 23, 82, 29, 67, 102, 102, 110, 110, 2, 17, 122, 122, 60, 57, 56, 79, 14,
    14, 27, 35, 107, 107, 89, 89, 81, 37, 120, 103, 103, 101, 101, 116, 116, 63, 12, 88, 88, 86,
    31, 34, 83, 46, 104, 104, 98, 98, 95, 95, 78, 11, 36, 36, 25, 85, 94, 94, 62, 59, 35, 109, 109,
    24, 24, 26, 115, 115, 6, 65, 123, 124, 125, 126, 133, 127, 128, 129, 130, 131, 132, 125, 95,
    130, 131
    ];
}

# Module attrs: every constant plus the inverted errorcode dict -- the exact
# two structures errnomodule.c builds (module_dict + error_dict).
def errno_module_attrs -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    errorcode = PyDict(t="dict", items={});
    names = _errno_names();
    codes = _errno_codes();
    for i in range(len(names)) {
        name = names[i];
        code = PyInt(t="int", val=codes[i]);
        attrs[name] = code;
        hk = hashkey_str(code.tp_hashkey());
        errorcode.items[hk] = DictEntry(key=code, value=PyStr(t="str", val=name));
    }
    attrs["errorcode"] = errorcode;
    return attrs;
}
