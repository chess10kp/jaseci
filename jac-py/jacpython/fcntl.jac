# Product-path facade for fcntl: file control and I/O control on file
# descriptors. Semantics mirror CPython 3.14 ``Modules/fcntlmodule.c`` on the
# pinned POSIX host.
#
# The four entry points (fcntl/ioctl/flock/lockf) are thin syscalls whose
# entire behavior -- fildes coercion (int or object with fileno()),
# integer/bytes/str third-argument polymorphism, EINTR retry, and errno ->
# OSError mapping -- lives in the host C extension. This facade crosses the
# substrate boundary via the ceval host bridge so every call executes real
# syscalls and errors cross back byte-exact (type name + message), exactly
# like the test.support.os_helper shims.
#
# The constant surface (LOCK_*, F_*, FD_CLOEXEC, DN_*, ...) is
# platform-dependent by design in CPython (every export is guarded by #ifdef).
# Rather than hardcoding one platform's values, the snapshot below mirrors the
# connected host's fcntl module at attrs-build time, so constants can never
# drift from the module that actually performs the syscalls.

import from objects {
    PyObj,
    PyStr,
    PyList,
    py_none,
    py_error,
}
import from ceval {
    _jac_host_import,
    _jac_dir_names,
    _jac_host_getattr,
    _jac_host_call,
    to_host,
    from_host,
}

# Resolve the host fcntl module once per need; returns it or an error PyObj
# (ModuleNotFoundError crossing from the host, i.e. a non-POSIX host).
def _fc_host_module() -> tuple[bool, any] {
    star: list[PyObj] = [PyStr(t="str", val="*")];
    res = _jac_host_import("fcntl", to_host(PyList(t="list", items=star)));
    if res[0] as bool {
        return (True, res[1]);
    }
    return (False, py_error(str(res[1]), str(res[2])));
}

# Shared boundary for all four entry points: convert guest args/kwargs across
# the bridge, invoke the named host function, and map the outcome back.
# Argument validation is intentionally NOT duplicated here -- the host
# clinic-generated signatures already raise the canonical TypeError/ValueError
# (including "takes no keyword arguments" for the positional-only surfaces),
# and forwarding keeps those messages byte-exact.
def _fc_bridge_call(fn_name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    mod = _fc_host_module();
    if not ((mod[0] as bool)) {
        return mod[1] as PyObj;
    }
    fn_res = _jac_host_getattr(mod[1], fn_name);
    if not ((fn_res[0] as bool)) {
        return py_error(str(fn_res[1]), str(fn_res[2]));
    }
    host_args: list[any] = [];
    for a in args {
        host_args.append(to_host(a));
    }
    host_kwargs: dict[str, any] = {};
    for k in kwargs {
        host_kwargs[k] = to_host(kwargs[k]);
    }
    res = _jac_host_call(fn_res[1], host_args, host_kwargs);
    if res[0] as bool {
        return from_host(res[1]);
    }
    return py_error(str(res[1]), str(res[2]));
}

obj FcntlFcntlFn(PyObj) {
    # fcntl.fcntl(fd, cmd, arg=0) -> int | bytes
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _fc_bridge_call("fcntl", args, kwargs);
    }
}

obj FcntlIoctlFn(PyObj) {
    # fcntl.ioctl(fd, request, arg=0, mutate_flag=True) -> int | bytes
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _fc_bridge_call("ioctl", args, kwargs);
    }
}

obj FcntlFlockFn(PyObj) {
    # fcntl.flock(fd, operation) -> None
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _fc_bridge_call("flock", args, kwargs);
    }
}

obj FcntlLockfFn(PyObj) {
    # fcntl.lockf(fd, cmd, len=0, start=0, whence=0) -> None
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _fc_bridge_call("lockf", args, kwargs);
    }
}

# Module surface for the shim registry: the four syscall entry points plus the
# host's full exported constant set (LOCK_*/F_*/FD_CLOEXEC/DN_*/I_* ...),
# snapshotted so values always match the module executing the syscalls.
# Dunder machinery (__loader__/__spec__/...) never round-trips meaningfully;
# __name__ is synthesized by the PyModule shim itself.
def fcntl_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {
        "fcntl": FcntlFcntlFn(t="function"),
        "ioctl": FcntlIoctlFn(t="function"),
        "flock": FcntlFlockFn(t="function"),
        "lockf": FcntlLockfFn(t="function"),
    };
    mod = _fc_host_module();
    if mod[0] as bool {
        names_res = _jac_dir_names(mod[1]);
        if names_res[0] as bool {
            for attr_name in names_res[1] {
                if attr_name in attrs or attr_name.startswith("_") {
                    continue;
                }
                got = _jac_host_getattr(mod[1], attr_name);
                if got[0] as bool {
                    attrs[attr_name] = from_host(got[1]);
                }
            }
        }
    }
    return attrs;
}
