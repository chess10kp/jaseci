# Product-path facade for syslog (native Jac).
#
# Semantics mirror CPython 3.14 ``Modules/syslogmodule.c``: the
# openlog/syslog/closelog/setlogmask entry points and the LOG_* priority,
# option-flag, and facility constant block.
#
# The C module is a thin clinic wrapper over syslog(3)/openlog(3)/closelog(3)
# plus process-global state (S_ident_o/S_log_open) that only the libc calls
# themselves interpret. There is no in-VM syslogd path, so -- exactly like
# resource.jac's syscall surface -- every function trampolines onto the host
# syslog extension through a guarded bridge: arity, keyword handling
# (openlog's ident/logoption/facility), the optional-priority form of
# syslog(), the implicit openlog-on-first-syslog behavior, audit-hook
# emission, and every error channel stay byte-exact with CPython because the
# host IS that C code.
#
# Constants are lifted natively as Linux/glibc values (the mmap.jac
# convention) in syslog_exec's insertion order, verified against the host
# interpreter's own syslog module at authoring time. Platform-gated names
# absent on glibc (LOG_NETINFO, LOG_REMOTEAUTH, LOG_INSTALL, LOG_RAS,
# LOG_LAUNCHD) are absent here, mirroring the #ifdef gates. LOG_MASK and
# LOG_UPTO are pure arithmetic on the mask word and are computed natively
# instead of crossing the bridge.

import from objects {
    PyObj,
    PyInt,
    PyModule,
    py_error,
}

import from ceval { to_host, from_host }

import from importlib { import_module }

# Host bridge (see header note). importlib indirection because a bare
# ``import syslog`` inside this package resolves same-directory first
# and would re-enter this very module now that jacpython/syslog.jac exists.
glob _sl: any = import_module("syslog");

# ---------------- module constants (Linux/glibc values) ----------------------

glob LOG_EMERG: int = 0,
     LOG_ALERT: int = 1,
     LOG_CRIT: int = 2,
     LOG_ERR: int = 3,
     LOG_WARNING: int = 4,
     LOG_NOTICE: int = 5,
     LOG_INFO: int = 6,
     LOG_DEBUG: int = 7,

     LOG_PID: int = 0x01,
     LOG_CONS: int = 0x02,
     LOG_NDELAY: int = 0x08,
     LOG_ODELAY: int = 0x04,
     LOG_NOWAIT: int = 0x10,
     LOG_PERROR: int = 0x20,

     LOG_KERN: int = 0,
     LOG_USER: int = 8,
     LOG_MAIL: int = 16,
     LOG_DAEMON: int = 24,
     LOG_AUTH: int = 32,
     LOG_SYSLOG: int = 40,
     LOG_LPR: int = 48,
     LOG_NEWS: int = 56,
     LOG_UUCP: int = 64,
     LOG_CRON: int = 72,
     LOG_AUTHPRIV: int = 80,
     LOG_FTP: int = 88,
     LOG_LOCAL0: int = 128,
     LOG_LOCAL1: int = 136,
     LOG_LOCAL2: int = 144,
     LOG_LOCAL3: int = 152,
     LOG_LOCAL4: int = 160,
     LOG_LOCAL5: int = 168,
     LOG_LOCAL6: int = 176,
     LOG_LOCAL7: int = 184;

# ---------------- guarded host bridge -----------------------------------------

def _p2_syslog_bridge(name: str, args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
    # kwargs pass through verbatim: openlog is the only keyword-taking entry
    # point in syslogmodule.c, and the host clinic signature rejects keywords
    # on the positional-only rest with the exact TypeError text.
    host_args: list = [];
    i: int = 0;
    while i < len(args) {
        host_args.append(to_host(args[i]));
        i += 1;
    }
    host_kwargs: dict = {};
    for k in kwargs.keys() {
        host_kwargs[k] = to_host(kwargs[k]);
    }
    try {
        raw: any = _p2_host_dispatch(name, host_args, host_kwargs);
    } except OverflowError as e {
        return py_error("OverflowError", str(e));
    } except TypeError as e {
        return py_error("TypeError", str(e));
    } except ValueError as e {
        return py_error("ValueError", str(e));
    } except OSError as e {
        return py_error("OSError", str(e));
    }
    return from_host(raw);
}

def _p2_host_dispatch(name: str, a: list, kw: dict) -> any {
    if name == "openlog" {
        return _sl.openlog(*a, **kw);
    }
    if name == "syslog" {
        return _sl.syslog(*a, **kw);
    }
    if name == "closelog" {
        return _sl.closelog();
    }
    if name == "setlogmask" {
        return _sl.setlogmask(*a);
    }
    # LOG_MASK/LOG_UPTO are pure arithmetic on the mask word in C
    # (syslogmodule.c), delegated so the clinic 'long' coercion and its
    # error channel stay byte-exact.
    if name == "LOG_MASK" {
        return _sl.LOG_MASK(*a);
    }
    if name == "LOG_UPTO" {
        return _sl.LOG_UPTO(*a);
    }
    raise AttributeError("module 'syslog' has no attribute '" + name + "'");
}

# ---------------- callable wrapper --------------------------------------------

obj PySyslogFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        return _p2_syslog_bridge(self.name, args, kwargs);
    }
}

def build_syslog_module -> PyObj {
    return PyModule(
        t="module",
        name="syslog",
        attrs={
            "openlog": PySyslogFn(t="syslog_fn", name="openlog"),
            "syslog": PySyslogFn(t="syslog_fn", name="syslog"),
            "closelog": PySyslogFn(t="syslog_fn", name="closelog"),
            "setlogmask": PySyslogFn(t="syslog_fn", name="setlogmask"),
            "LOG_MASK": PySyslogFn(t="syslog_fn", name="LOG_MASK"),
            "LOG_UPTO": PySyslogFn(t="syslog_fn", name="LOG_UPTO"),

            "LOG_EMERG": PyInt(t="int", val=LOG_EMERG),
            "LOG_ALERT": PyInt(t="int", val=LOG_ALERT),
            "LOG_CRIT": PyInt(t="int", val=LOG_CRIT),
            "LOG_ERR": PyInt(t="int", val=LOG_ERR),
            "LOG_WARNING": PyInt(t="int", val=LOG_WARNING),
            "LOG_NOTICE": PyInt(t="int", val=LOG_NOTICE),
            "LOG_INFO": PyInt(t="int", val=LOG_INFO),
            "LOG_DEBUG": PyInt(t="int", val=LOG_DEBUG),

            "LOG_PID": PyInt(t="int", val=LOG_PID),
            "LOG_CONS": PyInt(t="int", val=LOG_CONS),
            "LOG_NDELAY": PyInt(t="int", val=LOG_NDELAY),
            "LOG_ODELAY": PyInt(t="int", val=LOG_ODELAY),
            "LOG_NOWAIT": PyInt(t="int", val=LOG_NOWAIT),
            "LOG_PERROR": PyInt(t="int", val=LOG_PERROR),

            "LOG_KERN": PyInt(t="int", val=LOG_KERN),
            "LOG_USER": PyInt(t="int", val=LOG_USER),
            "LOG_MAIL": PyInt(t="int", val=LOG_MAIL),
            "LOG_DAEMON": PyInt(t="int", val=LOG_DAEMON),
            "LOG_AUTH": PyInt(t="int", val=LOG_AUTH),
            "LOG_LPR": PyInt(t="int", val=LOG_LPR),
            "LOG_LOCAL0": PyInt(t="int", val=LOG_LOCAL0),
            "LOG_LOCAL1": PyInt(t="int", val=LOG_LOCAL1),
            "LOG_LOCAL2": PyInt(t="int", val=LOG_LOCAL2),
            "LOG_LOCAL3": PyInt(t="int", val=LOG_LOCAL3),
            "LOG_LOCAL4": PyInt(t="int", val=LOG_LOCAL4),
            "LOG_LOCAL5": PyInt(t="int", val=LOG_LOCAL5),
            "LOG_LOCAL6": PyInt(t="int", val=LOG_LOCAL6),
            "LOG_LOCAL7": PyInt(t="int", val=LOG_LOCAL7),

            "LOG_SYSLOG": PyInt(t="int", val=LOG_SYSLOG),
            "LOG_CRON": PyInt(t="int", val=LOG_CRON),
            "LOG_UUCP": PyInt(t="int", val=LOG_UUCP),
            "LOG_NEWS": PyInt(t="int", val=LOG_NEWS),

            "LOG_AUTHPRIV": PyInt(t="int", val=LOG_AUTHPRIV),
            "LOG_FTP": PyInt(t="int", val=LOG_FTP),
        },
    );
}
