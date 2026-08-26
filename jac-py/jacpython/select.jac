# Product-path facade for select.
# Semantics mirror CPython 3.14 ``Modules/selectmodule.c`` (Linux build:
# poll + epoll present, devpoll/kqueue absent -- exactly as on Linux where
# HAVE_SYS_DEVPOLL_H is undefined).
#
# Surface lifted natively from the C source: the full argument-validation
# ladder of select_select_impl / seq2set / PyObject_AsFileDescriptor
# (sequence-protocol TypeError, fileno() protocol TypeErrors, the
# FD_SETSIZE range ValueError, negative-timeout ValueError), the constant
# block (PIPE_BUF, POLL*, EPOLL*) as Linux values per the mmap.jac
# convention, and ``error`` aliased to OSError (PyModule_AddObjectRef of
# PyExc_OSError in _select_exec).
#
# The syscall floor delegates to the host select extension (the same libc
# select/poll/epoll calls the C module wraps), exactly like bz2.jac
# delegates its libbz2 floor to _bz2: poll()/epoll() instances hold the
# host object and forward, so kernel-level semantics, EINTR discipline,
# and error channels stay byte-exact without reimplementing libc.

import from objects {
    PyObj,
    PyInt,
    PyBool,
    PyFloat,
    PyStr,
    PyList,
    PyTuple,
    PyNoneType,
    PyModule,
    py_none,
    py_error,
    py_exception_type,
    is_error,
}
import from ceval {
    _jac_host_import,
    from_host,
}

# ---------------- module constants (_select_exec ADD_INT block, Linux) --------

glob PIPE_BUF: int = 4096,

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

     EPOLLIN: int = 0x0001,
     EPOLLPRI: int = 0x0002,
     EPOLLOUT: int = 0x0004,
     EPOLLERR: int = 0x0008,
     EPOLLHUP: int = 0x0010,
     EPOLLRDNORM: int = 0x0040,
     EPOLLRDBAND: int = 0x0080,
     EPOLLWRNORM: int = 0x0100,
     EPOLLWRBAND: int = 0x0200,
     EPOLLMSG: int = 0x0400,
     EPOLLRDHUP: int = 0x2000,
     EPOLLET: int = 0x80000000,
     EPOLLONESHOT: int = 0x40000000,
     EPOLLEXCLUSIVE: int = 0x10000000,
     EPOLLWAKEUP: int = 0x20000000,
     EPOLL_CLOEXEC: int = 0x80000;

# FD_SETSIZE from the C source (!_PyIsSelectable_fd bound).
glob _FD_SETSIZE: int = 1024;

glob _POLL_DEFAULT_MASK: int = POLLIN | POLLPRI | POLLOUT;
glob _EPOLL_DEFAULT_MASK: int = EPOLLIN | EPOLLPRI;

# ---------------- host floor --------------------------------------------------

# Cached host select module resolved through the runtime import bridge
# (host sys.modules["select"] is always the C extension -- the shim registry
# lives only on the guest side, so there is no self-import hazard here).

def _p2_floor_module() -> any {
    res = _jac_host_import("select", PyList(t="list", items=[]));
    if res[0] as bool {
        return res[1];
    }
    return None;
}

def _p2_floor_error(exc: any) -> PyObj {
    # Native-floor exception crossing into the guest: keep the original type
    # name and text so except-handlers match (mirrors _jac_host_error slots
    # 0..2 consumed across the boundary).
    return py_error(type(exc).__name__, str(exc));
}

def _p2_host_call_value(callable_val: any, args: list) -> PyObj {
    try {
        return from_host(callable_val(*args));
    } except BaseException as exc {
        return _p2_floor_error(exc);
    }
}

# ---------------- argument helpers --------------------------------------------

# PyObject_AsFileDescriptor lift: int (or bool) passes; otherwise the fileno()
# protocol with the byte-exact TypeError channels. Returns (ok, fd); an error
# PyObj comes back in slot 1 with ok=False.
def _p2_as_fildes(o: PyObj) -> tuple[bool, any] {
    if isinstance(o, PyInt) {
        return (True, (o as PyInt).val);
    }
    if isinstance(o, PyBool) {
        return (True, 1 if (o as PyBool).val else 0);
    }
    f = o.tp_getattro("fileno");
    if is_error(f) {
        return (
            False,
            py_error("TypeError", "argument must be an int, or have a fileno() method."),
        );
    }
    try {
        r = f.tp_call([], {});
    } except BaseException as exc {
        return (False, _p2_floor_error(exc));
    }
    if is_error(r) {
        return (False, r);
    }
    if isinstance(r, PyInt) {
        return (True, (r as PyInt).val);
    }
    if isinstance(r, PyBool) {
        return (True, 1 if (r as PyBool).val else 0);
    }
    tname: str = "object";
    if isinstance(r, PyStr) {
        tname = "str";
    } elif isinstance(r, PyFloat) {
        tname = "float";
    } elif isinstance(r, PyList) or isinstance(r, PyTuple) {
        tname = "list";
    }
    return (
        False,
        py_error("TypeError", "fileno() returned a non-integer of type " + tname),
    );
}

# seq2set range guard: !_PyIsSelectable_fd(v) rejects negatives and fds at or
# above FD_SETSIZE before the syscall floor ever sees them.
def _p2_fd_in_range(v: int) -> bool {
    return v >= 0 and v < _FD_SETSIZE;
}

# One sequence leg of seq2set: validate the container, coerce every item,
# build the plain-int fd list plus the fd->object map set2list needs to
# restore the ORIGINAL objects (identity preserved). Returns (ok, payload):
# ok=True carries [fd_list, obj_map]; ok=False carries the error PyObj.
def _p2_seq_to_fdset(seq: PyObj) -> tuple[bool, any] {
    if not (isinstance(seq, PyList) or isinstance(seq, PyTuple)) {
        return (False, py_error("TypeError", "arguments 1-3 must be sequences"));
    }
    fds: list[int] = [];
    objs: dict[int, PyObj] = {};
    items: list[PyObj];
    if isinstance(seq, PyList) {
        items = (seq as PyList).items;
    } else {
        items = (seq as PyTuple).items;
    }
    for item in items {
        (ok, fd_res) = _p2_as_fildes(item);
        if not ok {
            return (False, fd_res);
        }
        v = fd_res as int;
        if not _p2_fd_in_range(v) {
            return (
                False,
                py_error("ValueError", "filedescriptor out of range in select()"),
            );
        }
        fds.append(v);
        objs[v] = item;
    }
    return (True, [fds, objs]);
}

# set2list lift: map a ready int list back through the fd->object map into a
# fresh guest list (fresh lists are what test_returned_list_identity pins).
def _p2_fdset_to_list(fds: list, objs: dict[int, PyObj]) -> PyList {
    out_items: list[PyObj] = [];
    for v in fds {
        out_items.append(objs[v]);
    }
    return PyList(t="list", items=out_items);
}

# Host-scalar conversion for forwarded wrapper arguments (timeout, masks).
def _p2_to_host_scalar(o: PyObj) -> any {
    if isinstance(o, PyInt) {
        return (o as PyInt).val;
    }
    if isinstance(o, PyBool) {
        return (o as PyBool).val;
    }
    if isinstance(o, PyFloat) {
        return (o as PyFloat).val;
    }
    if isinstance(o, PyStr) {
        return (o as PyStr).val;
    }
    if isinstance(o, PyNoneType) {
        return None;
    }
    return o;
}

# ---------------- select.select ------------------------------------------------

obj PySelectFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        # Merge positional + keyword onto the clinic vector
        # [rlist, wlist, xlist, timeout=None].
        names: list[str] = ["rlist", "wlist", "xlist", "timeout"];
        values: list[PyObj] = [];
        k: int = 0;
        while k < 4 {
            if k < len(args) {
                values.append(args[k]);
            } elif names[k] in kwargs {
                values.append(kwargs[names[k]]);
            } else {
                values.append(py_none());
            }
            k = k + 1;
        }
        for key in kwargs {
            known: bool = False;
            n: int = 0;
            while n < 4 {
                if key == names[n] {
                    known = True;
                }
                n = n + 1;
            }
            if not known {
                return py_error(
                    "TypeError",
                    "'" + key + "' is an invalid keyword argument for select()",
                );
            }
        }
        if len(args) > 4 {
            return py_error(
                "TypeError",
                "select expected at most 4 arguments, got " + str(len(args)),
            );
        }
        if len(args) < 3 {
            missing: list[str] = ["'rlist' (pos 1)", "'wlist' (pos 2)", "'xlist' (pos 3)"];
            return py_error(
                "TypeError",
                "function missing required argument " + missing[len(args)],
            );
        }

        # Timeout ladder from select_select_impl: None blocks; numeric values
        # pass to the floor (which raises OverflowError on inf/NaN with the
        # exact C text); anything else hits the clinic TypeError; negatives
        # hit the post-conversion ValueError.
        timeout_obj = values[3];
        timeout_host: any = None;
        if not isinstance(timeout_obj, PyNoneType) {
            if isinstance(timeout_obj, PyInt) {
                tv: float = (timeout_obj as PyInt).val;
            } elif isinstance(timeout_obj, PyFloat) {
                tv = (timeout_obj as PyFloat).val;
            } else {
                return py_error("TypeError", "timeout must be a float or None");
            }
            if tv < 0 {
                return py_error("ValueError", "timeout must be non-negative");
            }
            timeout_host = tv;
        }

        legs: list = [];
        maps: list = [];
        n2: int = 0;
        while n2 < 3 {
            (ok, payload) = _p2_seq_to_fdset(values[n2]);
            if not ok {
                return payload as PyObj;
            }
            legs.append(payload[0]);
            maps.append(payload[1]);
            n2 = n2 + 1;
        }

        mod = _p2_floor_module();
        if mod is None {
            return py_error("ImportError", "host select module unavailable");
        }
        try {
            ready = mod.select(legs[0], legs[1], legs[2], timeout_host);
        } except BaseException as exc {
            return _p2_floor_error(exc);
        }
        return PyTuple(
            t="tuple",
            items=[
                _p2_fdset_to_list(ready[0], maps[0]),
                _p2_fdset_to_list(ready[1], maps[1]),
                _p2_fdset_to_list(ready[2], maps[2]),
            ],
        );
    }
}

# ---------------- poll objects -------------------------------------------------
#
# select_poll_*_impl family: the fd->eventmask bookkeeping lives on the HOST
# poll instance, so register/modify/unregister validation (unsigned-short
# mask channels, KeyError/FileNotFoundError texts) comes from the floor
# byte-exact; this side only coerces guest objects to fds.

obj PyPollObj(PyObj) {
    has inner: any = None;

    def tp_getattro(name: str) -> PyObj {
        if name == "register" or name == "modify" or name == "unregister"
            or name == "poll" or name == "close" or name == "fileno" {
            return PyPollMethod(t="poll_method", target=self, name=name);
        }
        return py_error(
            "AttributeError", "'select.poll' object has no attribute '" + name + "'"
        );
    }
}

obj PyPollMethod(PyObj) {
    has target: PyPollObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        inner = self.target.inner;
        if inner is None {
            return py_error("OSError", "[Errno 9] Bad file descriptor");
        }
        # fd-leading methods: coerce the guest object first, then let the
        # floor own every remaining channel (mask ranges, KeyError, ...).
        if self.name != "poll" and self.name != "close" and self.name != "fileno" {
            if len(args) < 1 {
                return py_error("TypeError", "function missing required argument 'fd'");
            }
            (ok, fd_res) = _p2_as_fildes(args[0]);
            if not ok {
                return fd_res as PyObj;
            }
            call_args: list = [fd_res];
            n: int = 1;
            while n < len(args) {
                call_args.append(_p2_to_host_scalar(args[n]));
                n = n + 1;
            }
            return _p2_host_call_value(_p2_bind(inner, self.name), call_args);
        }
        raw_args: list = [];
        for a in args {
            raw_args.append(_p2_to_host_scalar(a));
        }
        return _p2_host_call_value(_p2_bind(inner, self.name), raw_args);
    }
}

# Bound-method fetch off the host instance; AttributeError surfaces as the
# standard guest error channel.
def _p2_bind(host_obj: any, meth_name: str) -> any {
    return getattr(host_obj, meth_name);
}

obj PyPollCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "poll() takes no keyword arguments");
        }
        if len(args) > 0 {
            return py_error(
                "TypeError",
                "poll expected 0 arguments, got " + str(len(args)),
            );
        }
        mod = _p2_floor_module();
        if mod is None {
            return py_error("ImportError", "host select module unavailable");
        }
        try {
            inner = mod.poll();
        } except BaseException as exc {
            return _p2_floor_error(exc);
        }
        return PyPollObj(t="poll_obj", inner=inner);
    }
}

# ---------------- epoll objects ------------------------------------------------

obj PyEpollObj(PyObj) {
    has inner: any = None;

    def tp_getattro(name: str) -> PyObj {
        if name == "closed" {
            try {
                return from_host(self.inner.closed);
            } except BaseException as exc {
                return _p2_floor_error(exc);
            }
        }
        if name == "register" or name == "modify" or name == "unregister"
            or name == "wait" or name == "poll" or name == "close"
            or name == "fileno" {
            return PyEpollMethod(t="epoll_method", target=self, name=name);
        }
        return py_error(
            "AttributeError", "'select.epoll' object has no attribute '" + name + "'"
        );
    }
}

obj PyEpollMethod(PyObj) {
    has target: PyEpollObj,
        name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", self.name + "() takes no keyword arguments");
        }
        inner = self.target.inner;
        if inner is None {
            return py_error("OSError", "[Errno 9] Bad file descriptor");
        }
        if self.name == "close" {
            return _p2_host_call_value(_p2_bind(inner, self.name), []);
        }
        # register/modify/unregister lead with an fildes parameter; wait/poll/
        # fileno forward their scalars untouched.
        if self.name != "wait" and self.name != "poll" and self.name != "fileno" {
            if len(args) < 1 {
                return py_error("TypeError", "function missing required argument 'fd'");
            }
            (ok, fd_res) = _p2_as_fildes(args[0]);
            if not ok {
                return fd_res as PyObj;
            }
            call_args: list = [fd_res];
            n: int = 1;
            while n < len(args) {
                call_args.append(_p2_to_host_scalar(args[n]));
                n = n + 1;
            }
            return _p2_host_call_value(_p2_bind(inner, self.name), call_args);
        }
        raw_args: list = [];
        for a in args {
            raw_args.append(_p2_to_host_scalar(a));
        }
        return _p2_host_call_value(_p2_bind(inner, self.name), raw_args);
    }
}

obj PyEpollCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "epoll() takes no keyword arguments");
        }
        mod = _p2_floor_module();
        if mod is None {
            return py_error("ImportError", "host select module unavailable");
        }
        raw_args: list = [];
        for a in args {
            raw_args.append(_p2_to_host_scalar(a));
        }
        try {
            inner = mod.epoll(*raw_args);
        } except BaseException as exc {
            return _p2_floor_error(exc);
        }
        return PyEpollObj(t="epoll_obj", inner=inner);
    }
}

# ---------------- module builder -----------------------------------------------

def build_select_module -> PyObj {
    return PyModule(
        t="module",
        name="select",
        attrs={
            "select": PySelectFn(t="function"),
            "poll": PyPollCtor(t="function"),
            "epoll": PyEpollCtor(t="function"),
            "error": py_exception_type("OSError"),
            "PIPE_BUF": PyInt(t="int", val=PIPE_BUF),
            "POLLIN": PyInt(t="int", val=POLLIN),
            "POLLPRI": PyInt(t="int", val=POLLPRI),
            "POLLOUT": PyInt(t="int", val=POLLOUT),
            "POLLERR": PyInt(t="int", val=POLLERR),
            "POLLHUP": PyInt(t="int", val=POLLHUP),
            "POLLNVAL": PyInt(t="int", val=POLLNVAL),
            "POLLRDNORM": PyInt(t="int", val=POLLRDNORM),
            "POLLRDBAND": PyInt(t="int", val=POLLRDBAND),
            "POLLWRNORM": PyInt(t="int", val=POLLWRNORM),
            "POLLWRBAND": PyInt(t="int", val=POLLWRBAND),
            "POLLMSG": PyInt(t="int", val=POLLMSG),
            "POLLRDHUP": PyInt(t="int", val=POLLRDHUP),
            "EPOLLIN": PyInt(t="int", val=EPOLLIN),
            "EPOLLPRI": PyInt(t="int", val=EPOLLPRI),
            "EPOLLOUT": PyInt(t="int", val=EPOLLOUT),
            "EPOLLERR": PyInt(t="int", val=EPOLLERR),
            "EPOLLHUP": PyInt(t="int", val=EPOLLHUP),
            "EPOLLRDNORM": PyInt(t="int", val=EPOLLRDNORM),
            "EPOLLRDBAND": PyInt(t="int", val=EPOLLRDBAND),
            "EPOLLWRNORM": PyInt(t="int", val=EPOLLWRNORM),
            "EPOLLWRBAND": PyInt(t="int", val=EPOLLWRBAND),
            "EPOLLMSG": PyInt(t="int", val=EPOLLMSG),
            "EPOLLRDHUP": PyInt(t="int", val=EPOLLRDHUP),
            "EPOLLET": PyInt(t="int", val=EPOLLET),
            "EPOLLONESHOT": PyInt(t="int", val=EPOLLONESHOT),
            "EPOLLEXCLUSIVE": PyInt(t="int", val=EPOLLEXCLUSIVE),
            "EPOLLWAKEUP": PyInt(t="int", val=EPOLLWAKEUP),
            "EPOLL_CLOEXEC": PyInt(t="int", val=EPOLL_CLOEXEC),
        },
    );
}
