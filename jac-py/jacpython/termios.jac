# Native termios module facade (lift of reference/cpython/Modules/termios.c).
#
# Split surface, mirroring what each half needs:
#
# - The CONSTANT table is pure data exactly like errno: the C file's
#   termios_constants[] insertion ORDER for the Linux/glibc build of the pinned
#   CPython 3.14 reference, with every #ifdef branch resolved against this
#   platform's headers. Insertion order is semantic -- duplicate names re-add
#   the same value (B460800/B500000 appear twice in the C table) and dict
#   position stays at first insert -- so the table must not be sorted or
#   deduped. Verified surface-equal against the host interpreter's own termios
#   at authoring time (minus module machinery). TIO* ioctl request constants
#   are added as unsigned ints since gh-119770; all Linux values are positive,
#   so the mask is an identity here.
#
# - The tc* syscall functions cannot be expressed against jacpython's runtime
#   API (no FFI), so they route through a contained ::py:: host bridge driving
#   the HOST termios module, returning tag-typed results that this module
#   wraps into native PyObjs. Errors re-raise NATIVELY as
#   termios.error(errno, strerror): blanket host delegation would leak the
#   host exception class whose type __name__ is plain "error", breaking
#   ``except termios.error`` identity matching in guest code.
#
# Known divergences (documented for replay triage):
# - bool-as-fd skips CPython's RuntimeWarning and raises TypeError instead.
# - tcsetwinsize range-checks the unsigned-short fields before touching the
#   fd; CPython ioctls the OLD winsize first, so an out-of-range winsize on a
#   bad fd reports OverflowError here where CPython reports ENOTTY.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyList,
    PyTuple,
    PyBytes,
    PyModule,
    PyExceptionType,
    py_none,
    py_error,
    py_error_with_args,
    is_error,
}

::py::
def _termios_host_syscall(op, fd, a, b):
    # Host bridge into the real termios extension (see module header).
    # Returns ("ok", payload) | ("os_error", errno, strerror)
    #       | ("error", type_name, message).
    import termios as _t
    try:
        if op == "tcgetattr":
            mode = _t.tcgetattr(fd)
            cc = [("b", ch[0]) if isinstance(ch, bytes) else ("i", ch)
                  for ch in mode[6]]
            return ("ok", [mode[0], mode[1], mode[2], mode[3], mode[4],
                           mode[5], cc])
        if op == "tcsetattr":
            cc = [bytes([item[1]]) if item[0] == "b" else item[1]
                  for item in b[6]]
            _t.tcsetattr(fd, a, [b[0], b[1], b[2], b[3], b[4], b[5], cc])
            return ("ok", None)
        if op == "tcdrain":
            _t.tcdrain(fd)
            return ("ok", None)
        if op == "tcsendbreak":
            _t.tcsendbreak(fd, a)
            return ("ok", None)
        if op == "tcflush":
            _t.tcflush(fd, a)
            return ("ok", None)
        if op == "tcflow":
            _t.tcflow(fd, a)
            return ("ok", None)
        if op == "tcgetwinsize":
            rows, cols = _t.tcgetwinsize(fd)
            return ("ok", [rows, cols])
        if op == "tcsetwinsize":
            _t.tcsetwinsize(fd, (a, b))
            return ("ok", None)
        return ("error", "RuntimeError", "unknown termios operation")
    except Exception as exc:
        if isinstance(exc, _t.error):
            if len(exc.args) >= 2:
                return ("os_error", exc.args[0], exc.args[1])
            return ("os_error", 0, str(exc))
        return ("error", type(exc).__name__, str(exc))
::py::

# struct termios.c_cc array size (termios.h NCCS on Linux/glibc).
glob _TERMIOS_NCCS: int = 32;

# Constant names/values in termios_constants[] insertion order,
# Linux/glibc surface; _termios_names[i] <-> _termios_codes[i].
def _termios_names -> list[str] {
    return [
    "B0", "B50", "B75", "B110", "B134", "B150", "B200", "B300", "B600", "B1200", "B1800",
    "B2400", "B4800", "B9600", "B19200", "B38400", "B57600", "B115200", "B230400", "B460800",
    "B500000", "B576000", "B921600", "B1000000", "B1152000", "B1500000", "B2000000",
    "B2500000", "B3000000", "B3500000", "B4000000", "CBAUDEX", "TCSANOW", "TCSADRAIN",
    "TCSAFLUSH", "TCIFLUSH", "TCOFLUSH", "TCIOFLUSH", "TCOOFF", "TCOON", "TCIOFF", "TCION",
    "IGNBRK", "BRKINT", "IGNPAR", "PARMRK", "INPCK", "ISTRIP", "INLCR", "IGNCR", "ICRNL",
    "IUCLC", "IXON", "IXANY", "IXOFF", "IMAXBEL", "IUTF8", "OPOST", "OLCUC", "ONLCR", "OCRNL",
    "ONOCR", "ONLRET", "OFILL", "OFDEL", "NLDLY", "CRDLY", "TABDLY", "BSDLY", "VTDLY", "FFDLY",
    "NL0", "NL1", "CR0", "CR1", "CR2", "CR3", "TAB0", "TAB1", "TAB2", "TAB3", "XTABS", "BS0",
    "BS1", "VT0", "VT1", "FF0", "FF1", "CSIZE", "CSTOPB", "CREAD", "PARENB", "PARODD", "HUPCL",
    "CLOCAL", "CIBAUD", "CRTSCTS", "CS5", "CS6", "CS7", "CS8", "ISIG", "ICANON", "XCASE",
    "ECHO", "ECHOE", "ECHOK", "ECHONL", "ECHOCTL", "ECHOPRT", "ECHOKE", "FLUSHO", "NOFLSH",
    "TOSTOP", "PENDIN", "IEXTEN", "EXTPROC", "VINTR", "VQUIT", "VERASE", "VKILL", "VEOF",
    "VTIME", "VMIN", "VSWTC", "VSWTCH", "VSTART", "VSTOP", "VSUSP", "VEOL", "VREPRINT",
    "VDISCARD", "VWERASE", "VLNEXT", "VEOL2", "B7200", "B14400", "B28800", "B76800", "B460800",
    "B500000", "CBAUD", "CDSUSP", "CEOF", "CEOL", "CEOT", "CERASE", "CFLUSH", "CINTR", "CKILL",
    "CLNEXT", "CQUIT", "CRPRNT", "CSTART", "CSTOP", "CSUSP", "CWERASE", "EXTA", "EXTB",
    "FIOASYNC", "FIOCLEX", "FIONBIO", "FIONCLEX", "FIONREAD", "IBSHIFT", "IOCSIZE_MASK",
    "IOCSIZE_SHIFT", "NCCS", "N_MOUSE", "N_PPP", "N_SLIP", "N_STRIP", "N_TTY", "TCFLSH",
    "TCGETA", "TCGETS", "TCSBRK", "TCSBRKP", "TCSETA", "TCSETAF", "TCSETAW", "TCSETS",
    "TCSETSF", "TCSETSW", "TCXONC", "TIOCCONS", "TIOCEXCL", "TIOCGETD", "TIOCGICOUNT",
    "TIOCGLCKTRMIOS", "TIOCGPGRP", "TIOCGSERIAL", "TIOCGSOFTCAR", "TIOCGWINSZ", "TIOCINQ",
    "TIOCLINUX", "TIOCMBIC", "TIOCMBIS", "TIOCMGET", "TIOCMIWAIT", "TIOCMSET", "TIOCM_CAR",
    "TIOCM_CD", "TIOCM_CTS", "TIOCM_DSR", "TIOCM_DTR", "TIOCM_LE", "TIOCM_RI", "TIOCM_RNG",
    "TIOCM_RTS", "TIOCM_SR", "TIOCM_ST", "TIOCNOTTY", "TIOCNXCL", "TIOCOUTQ", "TIOCPKT",
    "TIOCPKT_DATA", "TIOCPKT_DOSTOP", "TIOCPKT_FLUSHREAD", "TIOCPKT_FLUSHWRITE",
    "TIOCPKT_NOSTOP", "TIOCPKT_START", "TIOCPKT_STOP", "TIOCSCTTY", "TIOCSERCONFIG",
    "TIOCSERGETLSR", "TIOCSERGETMULTI", "TIOCSERGSTRUCT", "TIOCSERGWILD", "TIOCSERSETMULTI",
    "TIOCSERSWILD", "TIOCSER_TEMT", "TIOCSETD", "TIOCSLCKTRMIOS", "TIOCSPGRP", "TIOCSSERIAL",
    "TIOCSSOFTCAR", "TIOCSTI", "TIOCSWINSZ", "_POSIX_VDISABLE",
    ];
}

def _termios_codes -> list[int] {
    return [
    0, 50, 75, 110, 134, 150, 200, 300, 600, 1200, 1800, 2400, 4800, 9600, 19200, 38400, 57600,
    115200, 230400, 460800, 500000, 576000, 921600, 1000000, 1152000, 1500000, 2000000,
    2500000, 3000000, 3500000, 4000000, 4096, 0, 1, 2, 0, 1, 2, 0, 1, 2, 3, 1, 2, 4, 8, 16, 32,
    64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 1, 2, 4, 8, 16, 32, 64, 128, 256, 1536,
    6144, 8192, 16384, 32768, 0, 256, 0, 512, 1024, 1536, 0, 2048, 4096, 6144, 6144, 0, 8192,
    0, 16384, 0, 32768, 48, 64, 128, 256, 512, 1024, 2048, 269418496, 2147483648, 0, 16, 32,
    48, 1, 2, 4, 8, 16, 32, 64, 512, 1024, 2048, 4096, 128, 256, 16384, 32768, 65536, 0, 1, 2,
    3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 7200, 14400, 28800, 76800, 460800,
    500000, 4111, 25, 4, 0, 4, 127, 15, 3, 21, 22, 28, 18, 17, 19, 26, 23, 19200, 38400, 21586,
    21585, 21537, 21584, 21531, 16, 1073676288, 16, 32, 2, 3, 1, 4, 0, 21515, 21509, 21505,
    21513, 21541, 21510, 21512, 21511, 21506, 21508, 21507, 21514, 21533, 21516, 21540, 21597,
    21590, 21519, 21534, 21529, 21523, 21531, 21532, 21527, 21526, 21525, 21596, 21528, 64, 64,
    32, 256, 2, 1, 128, 128, 4, 16, 8, 21538, 21517, 21521, 21536, 0, 32, 1, 2, 16, 8, 4,
    21518, 21587, 21593, 21594, 21592, 21588, 21595, 21589, 1, 21539, 21591, 21520, 21535,
    21530, 21522, 21524, 0,
    ];
}

# Map a bridge result to the native error it carries (py_none when ok).
def _termios_bridge_err(res: any) -> PyObj {
    if res[0] == "os_error" {
        args: list[PyObj] = [
            PyInt(t="int", val=res[1]),
            PyStr(t="str", val=res[2]),
        ];
        return py_error_with_args("termios.error", "", args);
    }
    if res[0] == "error" {
        return py_error(res[1], res[2]);
    }
    return py_none();
}

# PyObject_AsFileDescriptor mirror (Objects/fileobject.c): int-or-fileno()
# with CPython's exact error surface. Returns the fd as PyInt or a PyError.
def _termios_fd_arg(arg: PyObj) -> PyObj {
    if isinstance(arg, PyInt) {
        return _termios_fd_from_long((arg as PyInt).val);
    }
    meth = arg.tp_getattro("fileno");
    if is_error(meth) {
        return py_error(
            "TypeError", "argument must be an int, or have a fileno() method."
        );
    }
    raw = (meth as PyObj).tp_call([], {});
    if is_error(raw) {
        return raw;
    }
    if isinstance(raw, PyInt) {
        return _termios_fd_from_long((raw as PyInt).val);
    }
    return py_error("TypeError", "fileno() returned a non-integer");
}

def _termios_fd_from_long(value: int) -> PyObj {
    # PyLong_AsInt bound first (OverflowError), negative check second
    # (ValueError) -- Objects/fileobject.c order.
    if value < -2147483648 or value > 2147483647 {
        return py_error("OverflowError", "Python int too large to convert to C int");
    }
    if value < 0 {
        return py_error(
            "ValueError",
            "file descriptor cannot be a negative integer (" + str(value) + ")"
        );
    }
    return PyInt(t="int", val=value);
}

# __index__ protocol mirror: bool folds like the int subclass CPython treats
# it as; anything non-integral raises the protocol TypeError text.
def _termios_int_like(arg: PyObj) -> PyObj {
    if isinstance(arg, PyBool) {
        return (arg as PyBool).to_index();
    }
    if isinstance(arg, PyInt) {
        return arg;
    }
    return py_error(
        "TypeError",
        "'" + arg.tp_type_name() + "' object cannot be interpreted as an integer"
    );
}

# PyLong_AsInt range gate (clinic int params: when/duration/queue/action).
def _termios_cint_check(value: int) -> PyObj {
    if value < -2147483648 or value > 2147483647 {
        return py_error("OverflowError", "Python int too large to convert to C int");
    }
    return py_none();
}

# PyLong_AsLong range gate (tcsetattr flag/speed/cc slots, winsize fields).
def _termios_clong_check(value: int) -> PyObj {
    if value < -9223372036854775808 or value > 9223372036854775807 {
        return py_error("OverflowError", "Python int too large to convert to C long");
    }
    return py_none();
}

# tcgetattr payload -> the 7-element list: six ints plus cc (bytes of length
# 1, except VMIN/VTIME as ints in noncanonical mode -- the tagging decision
# lives host-side where ICANON is consulted, mirroring termios_tcgetattr_impl).
def _termios_wrap_attrs(payload: any) -> PyObj {
    out: list[PyObj] = [];
    for i in range(6) {
        out.append(PyInt(t="int", val=payload[i]) as PyObj);
    }
    cc: list[PyObj] = [];
    for item in payload[6] {
        if item[0] == "b" {
            cc.append(PyBytes(t="bytes", val=[item[1]]) as PyObj);
        } else {
            cc.append(PyInt(t="int", val=item[1]) as PyObj);
        }
    }
    out.append(PyList(t="list", items=cc) as PyObj);
    return PyList(t="list", items=out);
}

# Callable shim for the eight tc* entry points (PyGcFn pattern from gc.jac):
# one obj class, per-name dispatch, arg-count/conversion error text verbatim
# from Modules/clinic/termios.c.h.
obj TermiosFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if len(kwargs) > 0 {
            # All eight entry points are clinic positional-only (the / mark).
            return py_error(
                "TypeError", self.name + "() takes no keyword arguments"
            );
        }
        if self.name == "tcgetattr" or self.name == "tcdrain"
            or self.name == "tcgetwinsize" {
            if len(args) != 1 {
                return py_error(
                    "TypeError",
                    self.name + " takes exactly one argument ("
                        + str(len(args)) + " given)"
                );
            }
            fd = _termios_fd_arg(args[0]);
            if is_error(fd) {
                return fd;
            }
            res = _termios_host_syscall(self.name, (fd as PyInt).val, 0, None);
            err = _termios_bridge_err(res);
            if is_error(err) {
                return err;
            }
            if self.name == "tcgetattr" {
                return _termios_wrap_attrs(res[1]);
            }
            if self.name == "tcgetwinsize" {
                ws = res[1];
                return PyTuple(t="tuple", items=[
                    PyInt(t="int", val=int(ws[0])),
                    PyInt(t="int", val=int(ws[1])),
                ]);
            }
            return py_none();
        }
        if self.name == "tcsetattr" {
            if len(args) != 3 {
                return py_error(
                    "TypeError", "tcsetattr expected 3 arguments, got "
                        + str(len(args))
                );
            }
            fd = _termios_fd_arg(args[0]);
            if is_error(fd) {
                return fd;
            }
            when = _termios_int_like(args[1]);
            if is_error(when) {
                return when;
            }
            when_val = (when as PyInt).val;
            chk = _termios_cint_check(when_val);
            if is_error(chk) {
                return chk;
            }
            term = args[2];
            if not isinstance(term, PyList) or len((term as PyList).items) != 7 {
                return py_error("TypeError", "tcsetattr, arg 3: must be 7 element list");
            }
            items = (term as PyList).items;
            flags: list[int] = [];
            for i in range(6) {
                v = _termios_int_like(items[i]);
                if is_error(v) {
                    return v;
                }
                vv = (v as PyInt).val;
                chk2 = _termios_clong_check(vv);
                if is_error(chk2) {
                    return chk2;
                }
                flags.append(vv);
            }
            cc = items[6];
            if not isinstance(cc, PyList)
                or len((cc as PyList).items) != _TERMIOS_NCCS {
                return py_error(
                    "TypeError",
                    "tcsetattr: attributes[6] must be "
                        + str(_TERMIOS_NCCS) + " element list"
                );
            }
            cc_tagged: list[any] = [];
            for citem in (cc as PyList).items {
                if isinstance(citem, PyBytes) {
                    bval = (citem as PyBytes).val;
                    if len(bval) != 1 {
                        return py_error(
                            "TypeError",
                            "tcsetattr: elements of attributes must be bytes objects of length 1 or integers"
                        );
                    }
                    cc_tagged.append(["b", bval[0]]);
                } elif isinstance(citem, PyBool) {
                    cc_tagged.append(["i", ((citem as PyBool).to_index() as PyInt).val]);
                } elif isinstance(citem, PyInt) {
                    iv = (citem as PyInt).val;
                    chk3 = _termios_clong_check(iv);
                    if is_error(chk3) {
                        return chk3;
                    }
                    cc_tagged.append(["i", iv]);
                } else {
                    return py_error(
                        "TypeError",
                        "tcsetattr: elements of attributes must be bytes objects of length 1 or integers"
                    );
                }
            }
            tagged: list[any] = [flags[0], flags[1], flags[2], flags[3],
                                 flags[4], flags[5], cc_tagged];
            res = _termios_host_syscall(
                "tcsetattr", (fd as PyInt).val, when_val, tagged
            );
            err = _termios_bridge_err(res);
            if is_error(err) {
                return err;
            }
            return py_none();
        }
        if self.name == "tcsendbreak" or self.name == "tcflush"
            or self.name == "tcflow" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    self.name + " expected 2 arguments, got " + str(len(args))
                );
            }
            fd = _termios_fd_arg(args[0]);
            if is_error(fd) {
                return fd;
            }
            a = _termios_int_like(args[1]);
            if is_error(a) {
                return a;
            }
            av = (a as PyInt).val;
            chk = _termios_cint_check(av);
            if is_error(chk) {
                return chk;
            }
            res = _termios_host_syscall(self.name, (fd as PyInt).val, av, None);
            err = _termios_bridge_err(res);
            if is_error(err) {
                return err;
            }
            return py_none();
        }
        if self.name == "tcsetwinsize" {
            if len(args) != 2 {
                return py_error(
                    "TypeError",
                    "tcsetwinsize expected 2 arguments, got " + str(len(args))
                );
            }
            fd = _termios_fd_arg(args[0]);
            if is_error(fd) {
                return fd;
            }
            winsz = args[1];
            if not isinstance(winsz, PyList) and not isinstance(winsz, PyTuple) {
                return py_error(
                    "TypeError", "tcsetwinsize, arg 2: must be a two-item sequence"
                );
            }
            seq_items: list[PyObj] = [];
            if isinstance(winsz, PyList) {
                seq_items = (winsz as PyList).items;
            } else {
                seq_items = (winsz as PyTuple).items;
            }
            if len(seq_items) != 2 {
                return py_error(
                    "TypeError", "tcsetwinsize, arg 2: must be a two-item sequence"
                );
            }
            vals: list[int] = [];
            for idx in range(2) {
                v = _termios_int_like(seq_items[idx]);
                if is_error(v) {
                    return v;
                }
                vv = (v as PyInt).val;
                chk = _termios_clong_check(vv);
                if is_error(chk) {
                    return chk;
                }
                # Unsigned short field equality check (ws_row/ws_col cast).
                if vv < 0 or vv > 65535 {
                    return py_error("OverflowError", "winsize value(s) out of range.");
                }
                vals.append(vv);
            }
            res = _termios_host_syscall(
                "tcsetwinsize", (fd as PyInt).val, vals[0], vals[1]
            );
            err = _termios_bridge_err(res);
            if is_error(err) {
                return err;
            }
            return py_none();
        }
        return py_error("SystemError", "unknown termios function '" + self.name + "'");
    }
}

# Module attrs consumed by the ceval import sites: the constant table plus
# the native termios.error type and the eight tc* callables -- the exact
# three structures termios_exec builds (module_dict + TermiosError +
# method table).
def termios_module_attrs -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};
    names = _termios_names();
    codes = _termios_codes();
    for i in range(len(names)) {
        attrs[names[i]] = PyInt(t="int", val=codes[i]) as PyObj;
    }
    # PyErr_NewException("termios.error"): plain Exception subclass whose
    # instances carry (errno, strerror) args via PyErr_SetFromErrno.
    attrs["error"] = PyExceptionType(
        t="exception_type", name="termios.error"
    ) as PyObj;
    for fname in [
        "tcgetattr",
        "tcsetattr",
        "tcsendbreak",
        "tcdrain",
        "tcflush",
        "tcflow",
        "tcgetwinsize",
        "tcsetwinsize",
    ] {
        attrs[fname] = TermiosFn(t="termios_fn", name=fname) as PyObj;
    }
    attrs["__name__"] = PyStr(t="str", val="termios");
    return attrs;
}
