# Product-path facade for select (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/selectmodule.c`` (Linux/HAVE_POLL
# branch): the select.select() argument ladder (timeout parse -> per-set fd
# collection -> _PyIsSelectable_fd range gate -> FD_SETSIZE count cap), the
# PyObject_AsFileDescriptor conversion contract (int | fileno()), byte-exact
# error strings from the C sources, the poll object surface
# (register/modify/unregister/poll with POLLNVAL reporting), and the module
# constant table with ``error`` aliased to OSError.
#
# The guest VM has no descriptor table, so readiness routes through one
# narrow host-bridge helper: os.fstat(fd) validates a descriptor (failure
# surfaces as OSError "[Errno 9] Bad file descriptor", byte-matching
# PyErr_SetFromErrno for EBADF), and a valid fd is reported ready in every
# requested set -- Linux regular-file/tty semantics. When a real io layer
# lands, only that helper changes. poll() reports POLLIN|POLLOUT bits of the
# requested mask for valid fds and POLLNVAL for dead ones, matching what the
# host kernel does for files/pipes-with-space.
#
# Faithful quirk kept from the C source: seq2set iterates list/tuple inputs
# LIVE (PySequence_Fast returns the same object for exact sequences), so a
# fileno() callback mutating the sequence mid-call shifts the iteration --
# Lib/test/test_select.py::test_select_mutated pins exactly this.
#
# Error-channel convention matches the other facades (mmap et al): built-in
# TypeError/ValueError/OverflowError/OSError/KeyError keep their builtin type
# names exactly so guest except-handlers match them.

import from objects {
    PyObj,
    PyInt,
    PyBool,
    PyFloat,
    PyList,
    PyTuple,
    PyNoneType,
    PyModule,
    py_none,
    py_error,
    py_error_with_args,
    py_exception_type,
    is_error,
}

import from ceval { py_iter, drain_to_list }

import os as _host_os;

# ---------------- module constants (Linux values) ----------------------------

glob FD_SETSIZE: int = 1024,

     PIPE_BUF: int = 4096,

     POLLIN: int = 0x0001,
     POLLPRI: int = 0x0002,
     POLLOUT: int = 0x0004,
     POLLERR: int = 0x0008,
     POLLHUP: int = 0x0010,
     POLLNVAL: int = 0x0020,
     POLLRDNORM: int = 0x0040,
     POLLRDBAND: int = 0x0080,
     POLLWRNORM: int = 0x0004,
     POLLWRBAND: int = 0x0100,
     POLLMSG: int = 0x0400,
     POLLRDHUP: int = 0x2000,

     EPOLLIN: int = 0x0001,
     EPOLLPRI: int = 0x0002,
     EPOLLOUT: int = 0x0004,
     POLLERR_EPOLL: int = 0x0008,
     EPOLLHUP: int = 0x0010,
     EPOLLRDNORM: int = 0x0040,
     EPOLLRDBAND: int = 0x0080,
     EPOLLWRNORM: int = 0x0004,
     EPOLLWRBAND: int = 0x0100,
     EPOLLMSG: int = 0x0400,
     EPOLLRDHUP: int = 0x2000,
     EPOLLEXCLUSIVE: int = 0x10000000,
     EPOLLWAKEUP: int = 0x20000000,
     EPOLLONESHOT: int = 0x40000000,
     EPOLLET: int = 0x80000000,
     EPOLL_CLOEXEC: int = 0x80000;

# PyTime_t is an int64 nanosecond count: seconds beyond INT64_MAX / 1e9 and
# milliseconds beyond INT64_MAX / 1e6 overflow the conversion either way.
glob _P2_PYTIME_MAX_S: float = 9223372036.854775807;
glob _P2_PYTIME_MAX_MS: float = 9223372036854775.807;

# ---------------- host-bridge helpers ----------------------------------------

def _p2_host_fd_valid(fd: int) -> bool {
    try {
        _host_os.fstat(fd);
        return True;
    } except Exception {
        return False;
    }
}

# ---------------- PyObject_AsFileDescriptor ----------------------------------

def _p2_as_file_descriptor(o: PyObj) -> PyObj {
    v: int = 0;
    if isinstance(o, PyInt) or isinstance(o, PyBool) {
        idx = o.to_index();
        if is_error(idx) or not isinstance(idx, PyInt) {
            return py_error("OverflowError", "Python int too large to convert to C int");
        }
        v = (idx as PyInt).val;
    } else {
        meth = o.tp_getattro("fileno");
        if is_error(meth) {
            return py_error(
                "TypeError", "argument must be an int, or have a fileno() method."
            );
        }
        fno = meth.tp_call([], {});
        if is_error(fno) {
            return fno;
        }
        idx = fno.to_index();
        if is_error(idx) or not isinstance(idx, PyInt) {
            return py_error("TypeError", "fileno() returned a non-integer");
        }
        v = (idx as PyInt).val;
    }
    if v < 0 {
        return py_error(
            "ValueError", "file descriptor cannot be a negative integer (" + str(v) + ")"
        );
    }
    return PyInt(t="int", val=v);
}

# ---------------- timeout parsing (_PyTime_FromSecondsObject family) ---------

def _p2_seconds_from_object(o: PyObj) -> PyObj {
    # Returns PyFloat seconds, or the C-source error channel.
    if isinstance(o, PyFloat) {
        f: float = (o as PyFloat).val;
        if f != f {
            return py_error("ValueError", "Invalid value NaN (not a number)");
        }
        if f > _P2_PYTIME_MAX_S or f < -_P2_PYTIME_MAX_S {
            return py_error("OverflowError", "timestamp out of range for C PyTime_t");
        }
        return PyFloat(t="float", val=f);
    }
    if isinstance(o, PyInt) or isinstance(o, PyBool) {
        idx = o.to_index();
        if is_error(idx) {
            return py_error("TypeError", "timeout must be a float or None");
        }
        v: int = (idx as PyInt).val;
        f: float = v;
        if f > _P2_PYTIME_MAX_S or f < -_P2_PYTIME_MAX_S - 1.0 {
            return py_error("OverflowError", "timestamp out of range for C PyTime_t");
        }
        return PyFloat(t="float", val=f);
    }
    return py_error("TypeError", "timeout must be a float or None");
}

def _p2_millis_from_object(o: PyObj) -> PyObj {
    # Returns PyFloat milliseconds, or the C-source error channel.
    if isinstance(o, PyFloat) {
        f: float = (o as PyFloat).val;
        if f != f {
            return py_error("ValueError", "Invalid value NaN (not a number)");
        }
        if f > _P2_PYTIME_MAX_MS or f < -_P2_PYTIME_MAX_MS {
            return py_error("OverflowError", "timestamp out of range for C PyTime_t");
        }
        return PyFloat(t="float", val=f);
    }
    if isinstance(o, PyInt) or isinstance(o, PyBool) {
        idx = o.to_index();
        if is_error(idx) {
            return py_error("TypeError", "timeout must be an integer or None");
        }
        v: int = (idx as PyInt).val;
        f: float = v;
        if f > _P2_PYTIME_MAX_MS or f < -_P2_PYTIME_MAX_MS {
            return py_error("OverflowError", "timestamp out of range for C PyTime_t");
        }
        return PyFloat(t="float", val=f);
    }
    return py_error("TypeError", "timeout must be an integer or None");
}

# ---------------- seq2set (CPython seq2set, live-iteration form) -------------

# Collects (fd, original-object) pairs from one argument list. Returns
# (error, fds, objs); on success error is py_none(). List/tuple inputs are
# iterated by live index so fileno() side effects on the container show
# through; any other iterable snapshots first (PySequence_Fast copy path).
def _p2_seq2set(seq: PyObj) -> tuple[PyObj, list[int], list[PyObj]] {
    fds: list[int] = [];
    objs: list[PyObj] = [];

    live: bool = False;
    items: list[PyObj] = [];
    if isinstance(seq, PyList) {
        live = True;
        items = (seq as PyList).items;
    } elif isinstance(seq, PyTuple) {
        live = True;
        items = (seq as PyTuple).items;
    } else {
        it = py_iter(seq);
        if is_error(it) {
            return (
                py_error("TypeError", "arguments 1-3 must be sequences"),
                fds,
                objs,
            );
        }
        snap = drain_to_list(it);
        if is_error(snap) {
            return (snap, fds, objs);
        }
        items = (snap as PyList).items;
    }

    i: int = 0;
    while i < len(items) {
        o = items[i];
        conv = _p2_as_file_descriptor(o);
        if is_error(conv) {
            return (conv, fds, objs);
        }
        v: int = (conv as PyInt).val;
        if v >= FD_SETSIZE {
            return (
                py_error("ValueError", "filedescriptor out of range in select()"),
                fds,
                objs,
            );
        }
        if len(fds) >= FD_SETSIZE {
            return (
                py_error("ValueError", "too many file descriptors in select()"),
                fds,
                objs,
            );
        }
        fds.append(v);
        objs.append(o);
        if live {
            # Re-read the container length every round: a fileno() callback
            # may shrink it (test_select_mutated).
            if isinstance(seq, PyList) {
                items = (seq as PyList).items;
            } else {
                items = (seq as PyTuple).items;
            }
        }
        i = i + 1;
    }
    return (py_none(), fds, objs);
}

# ---------------- select.select ----------------------------------------------

obj PySelectFn(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            return py_error("TypeError", "select.select() takes no keyword arguments");
        }
        if len(args) < 3 {
            return py_error(
                "TypeError",
                "select expected at least 3 arguments, got " + str(len(args)),
            );
        }
        if len(args) > 4 {
            return py_error(
                "TypeError",
                "select expected at most 4 arguments, got " + str(len(args)),
            );
        }

        timeout_obj = args[3];
        if not isinstance(timeout_obj, PyNoneType) {
            secs = _p2_seconds_from_object(timeout_obj);
            if is_error(secs) {
                return secs;
            }
            s: float = (secs as PyFloat).val;
            if s < 0 {
                return py_error("ValueError", "timeout must be non-negative");
            }
        }

        got_r = _p2_seq2set(args[0]);
        if is_error(got_r[0]) {
            return got_r[0];
        }
        rfds: list[int] = got_r[1];
        robjs: list[PyObj] = got_r[2];
        got_w = _p2_seq2set(args[1]);
        if is_error(got_w[0]) {
            return got_w[0];
        }
        wfds: list[int] = got_w[1];
        wobjs: list[PyObj] = got_w[2];
        got_x = _p2_seq2set(args[2]);
        if is_error(got_x[0]) {
            return got_x[0];
        }
        xfds: list[int] = got_x[1];
        xobjs: list[PyObj] = got_x[2];

        # Descriptor validation through the host bridge: an unopenable fd is
        # EBADF ("[Errno 9] Bad file descriptor"), checked r- then w- then
        # x-set like the C call order.
        k: int = 0;
        while k < len(rfds) {
            if not _p2_host_fd_valid(rfds[k]) {
                return py_error("OSError", "[Errno 9] Bad file descriptor");
            }
            k = k + 1;
        }
        k = 0;
        while k < len(wfds) {
            if not _p2_host_fd_valid(wfds[k]) {
                return py_error("OSError", "[Errno 9] Bad file descriptor");
            }
            k = k + 1;
        }
        k = 0;
        while k < len(xfds) {
            if not _p2_host_fd_valid(xfds[k]) {
                return py_error("OSError", "[Errno 9] Bad file descriptor");
            }
            k = k + 1;
        }

        # Valid fds report ready in every requested set (fresh lists each
        # call -- set2list builds three distinct lists in the C source too).
        rout: list[PyObj] = [];
        wout: list[PyObj] = [];
        xout: list[PyObj] = [];
        rout.extend(robjs);
        wout.extend(wobjs);
        xout.extend(xobjs);
        return PyTuple(
            t="tuple",
            items=[
                PyList(t="list", items=rout),
                PyList(t="list", items=wout),
                PyList(t="list", items=xout),
            ],
        );
    }
}

# ---------------- select.poll ------------------------------------------------

# Registration state as parallel vectors (insertion order preserved, matching
# the C poll object's dict-backed ufd array ordering).
obj PyPollObj(PyObj) {
    has keys: list[int],
        masks: list[int];

    def tp_getattro(name: str) -> PyObj {
        if name == "register" or name == "modify" or name == "unregister"
            or name == "poll" {
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
        if self.name == "register" {
            if len(args) < 1 or len(args) > 2 {
                return py_error(
                    "TypeError",
                    "register expected 1 or 2 arguments, got " + str(len(args)),
                );
            }
            return _p2_poll_register(self.target, args);
        }
        if self.name == "modify" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "modify expected 2 arguments, got " + str(len(args)),
                );
            }
            return _p2_poll_modify(self.target, args);
        }
        if self.name == "unregister" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    "unregister expected 1 argument, got " + str(len(args)),
                );
            }
            return _p2_poll_unregister(self.target, args);
        }
        # poll([timeout])
        if len(args) > 1 {
            return py_error(
                "TypeError", "poll expected at most 1 argument, got " + str(len(args))
            );
        }
        return _p2_poll_poll(self.target, args);
    }
}

def _p2_poll_find(p: PyPollObj, fd: int) -> int {
    i: int = 0;
    while i < len(p.keys) {
        if p.keys[i] == fd {
            return i;
        }
        i = i + 1;
    }
    return -1;
}

def _p2_poll_register(p: PyPollObj, args: list[PyObj]) -> PyObj {
    conv = _p2_as_file_descriptor(args[0]);
    if is_error(conv) {
        return conv;
    }
    fd: int = (conv as PyInt).val;
    mask: int = POLLIN | POLLPRI | POLLOUT;
    if len(args) == 2 {
        idx = args[1].to_index();
        if is_error(idx) or not isinstance(idx, PyInt) {
            return py_error("TypeError", "an integer is required");
        }
        mask = (idx as PyInt).val & 0xFFFF;
    }
    slot = _p2_poll_find(p, fd);
    if slot >= 0 {
        p.masks[slot] = mask;
    } else {
        p.keys.append(fd);
        p.masks.append(mask);
    }
    return py_none();
}

def _p2_poll_modify(p: PyPollObj, args: list[PyObj]) -> PyObj {
    conv = _p2_as_file_descriptor(args[0]);
    if is_error(conv) {
        return conv;
    }
    fd: int = (conv as PyInt).val;
    idx = args[1].to_index();
    if is_error(idx) or not isinstance(idx, PyInt) {
        return py_error("TypeError", "an integer is required");
    }
    mask: int = (idx as PyInt).val & 0xFFFF;
    slot = _p2_poll_find(p, fd);
    if slot < 0 {
        return py_error("OSError", "[Errno 2] No such file or directory");
    }
    p.masks[slot] = mask;
    return py_none();
}

def _p2_poll_unregister(p: PyPollObj, args: list[PyObj]) -> PyObj {
    conv = _p2_as_file_descriptor(args[0]);
    if is_error(conv) {
        return conv;
    }
    fd: int = (conv as PyInt).val;
    slot = _p2_poll_find(p, fd);
    if slot < 0 {
        # KeyError carries the raw fd like PyDict_DelItem's KeyError(fd).
        return py_error_with_args("KeyError", "", [PyInt(t="int", val=fd)]);
    }
    p.keys.pop(slot);
    p.masks.pop(slot);
    return py_none();
}

def _p2_poll_poll(p: PyPollObj, args: list[PyObj]) -> PyObj {
    timeout_obj = args[0];
    if not isinstance(timeout_obj, PyNoneType) {
        ms = _p2_millis_from_object(timeout_obj);
        if is_error(ms) {
            return ms;
        }
        # Negative timeouts mean "wait indefinitely"; the bridge never blocks.
    }
    out: list[PyObj] = [];
    i: int = 0;
    while i < len(p.keys) {
        fd: int = p.keys[i];
        mask: int = p.masks[i];
        if not _p2_host_fd_valid(fd) {
            reported: int = POLLNVAL;
        } else {
            # Files/pipes-with-space are readable+writable; POLLPRI-class
            # conditions never fire across the bridge.
            reported = mask & (POLLIN | POLLOUT);
        }
        out.append(
            PyTuple(
                t="tuple",
                items=[PyInt(t="int", val=fd), PyInt(t="int", val=reported)],
            )
        );
        i = i + 1;
    }
    return PyList(t="list", items=out);
}

# ---------------- constructor --------------------------------------------------

obj PyPollCtor(PyObj) {
    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(args) > 0 {
            return py_error(
                "TypeError", "poll expected no arguments, got " + str(len(args))
            );
        }
        if len(kwargs) > 0 {
            return py_error("TypeError", "poll() takes no keyword arguments");
        }
        return PyPollObj(t="poll_obj", keys=[], masks=[]);
    }
}

# ---------------- module builder ----------------------------------------------

def build_select_module -> PyObj {
    return PyModule(
        t="module",
        name="select",
        attrs={
            "select": PySelectFn(t="select_fn"),
            "poll": PyPollCtor(t="poll_ctor"),
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
            "EPOLLERR": PyInt(t="int", val=POLLERR_EPOLL),
            "EPOLLHUP": PyInt(t="int", val=EPOLLHUP),
            "EPOLLRDNORM": PyInt(t="int", val=EPOLLRDNORM),
            "EPOLLRDBAND": PyInt(t="int", val=EPOLLRDBAND),
            "EPOLLWRNORM": PyInt(t="int", val=EPOLLWRNORM),
            "EPOLLWRBAND": PyInt(t="int", val=EPOLLWRBAND),
            "EPOLLMSG": PyInt(t="int", val=EPOLLMSG),
            "EPOLLRDHUP": PyInt(t="int", val=EPOLLRDHUP),
            "EPOLLEXCLUSIVE": PyInt(t="int", val=EPOLLEXCLUSIVE),
            "EPOLLWAKEUP": PyInt(t="int", val=EPOLLWAKEUP),
            "EPOLLONESHOT": PyInt(t="int", val=EPOLLONESHOT),
            "EPOLLET": PyInt(t="int", val=EPOLLET),
            "EPOLL_CLOEXEC": PyInt(t="int", val=EPOLL_CLOEXEC),
        },
    );
}
