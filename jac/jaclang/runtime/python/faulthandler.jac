# Product-path facade for faulthandler (crash-time traceback dumps).
# Semantics mirror CPython 3.14 ``Modules/faulthandler.c``: enable/disable/
# is_enabled fatal-signal handling, dump_traceback, dump_c_stack, the
# dump_traceback_later/cancel_dump_traceback_later watchdog, and the
# register/unregister user-signal surface.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original installs
# sigaction handlers over an alternate stack and dumps raw interpreter state
# from signal context (async-signal-safe writes to a stored fd). This facade
# runs inside a live VM, so handlers are host-level Python signal handlers
# that format Python-level tracebacks (sys._current_frames / frame walking)
# and re-raise through the previously saved handler; the fd is resolved
# eagerly like faulthandler_get_fileno but writes go through the sink object.
#
# Out of scope by design (documented divergences):
# - _raise_exception: MS_WINDOWS-only arm of the C source (linux product path).
# - _stack_overflow cannot fault a guard page under the guest VM; it recurses
#   until RecursionError instead of dying by SIGSEGV.
# - core-dump suppression (faulthandler_suppress_crash_report) needs
#   setrlimit and stays host-side.

import os as host_os;
import signal as host_signal;
import sys as host_sys;
import threading as host_threading;

glob FATAL_SIGNAL_NAMES: dict = {
    "SIGABRT": "Aborted",
    "SIGBUS": "Bus error",
    "SIGFPE": "Floating point exception",
    "SIGILL": "Illegal instruction",
    "SIGSEGV": "Segmentation fault",
};

# faulthandler.c static state: fatal_error + watchdog + user_signals table.
glob _state: dict = {
    "enabled": False,
    "file": None,
    "all_threads": True,
    "previous": {},
    "watchdog": None,
    "watchdog_repeat": False,
    "watchdog_exit": False,
    "user": {},
};


def _check_signum(signum: int) -> None {
    # check_signum: reject out-of-range signal numbers.
    nsig = getattr(host_signal, "NSIG", 65);
    if signum <= 0 or signum >= nsig {
        raise ValueError("signal out of range");
    }
}


def _resolve_sink(file: any) -> any {
    # faulthandler_get_fileno: default to stderr, accept an int fd or an
    # object with fileno()/write(). Returns the write sink used everywhere.
    if file is None or file is host_sys.stderr {
        return host_sys.stderr;
    }
    return file;
}


def _write(sink: any, text: str) -> None {
    if isinstance(sink, int) and not isinstance(sink, bool) {
        host_os.write(sink, text.encode());
        return;
    }
    sink.write(text);
}


def _format_frames(frame: any) -> str {
    # faulthandler_dump_traceback per-frame rendering:
    #   File "<file>", line <n> in <name>
    lines = "";
    while frame is not None {
        code = frame.f_code;
        lines += (
            "  File \"" + str(code.co_filename) + "\", line "
            + str(frame.f_lineno) + " in " + str(code.co_name) + "\n"
        );
        frame = frame.f_back;
    }
    return lines;
}


def _format_thread(ident: any, frame: any, current: bool) -> str {
    label = "Current thread" if current else "Thread";
    return (
        label + " 0x" + format(ident, "x") + " (most recent call first):\n"
        + _format_frames(frame)
    );
}


def _dump_all_threads(sink: any, all_threads: bool) -> None {
    # deduce_all_threads + faulthandler_dump_traceback: current thread always,
    # others only when all_threads is set. Frames snapshot via _current_frames
    # (the C original walks tstate chains directly).
    frames = host_sys._current_frames();
    cur_id = host_threading.get_ident();
    _write(sink, _format_thread(cur_id, frames.get(cur_id), True));
    if not all_threads {
        return;
    }
    for ident in sorted(frames.keys()) {
        if ident == cur_id {
            continue;
        }
        _write(sink, "\n");
        _write(sink, _format_thread(ident, frames[ident], False));
    }
}


def _format_timeout(timeout: float) -> str {
    # format_timeout (faulthandler.c): "D days (H:MM:SS)" beyond one day,
    # zero-padded H:MM:SS otherwise.
    total = int(timeout);
    days = total // 86400;
    rem = total % 86400;
    hh = rem // 3600;
    mm = (rem % 3600) // 60;
    ss = rem % 60;
    body = str(hh).zfill(2) + ":" + str(mm).zfill(2) + ":" + str(ss).zfill(2);
    if days > 0 {
        return str(days) + " days (" + body + ")";
    }
    return body;
}


# ---------------- fatal-signal handling (enable/disable) ----------------

def _fatal_handler(signum: int, frame: any) -> None {
    # faulthandler_fatal_error: announce, dump, restore previous handlers,
    # then re-raise so default disposition kills the process.
    if not _state["enabled"] {
        return;
    }
    disable();
    name = "";
    for key in FATAL_SIGNAL_NAMES {
        if getattr(host_signal, key, None) == signum {
            name = FATAL_SIGNAL_NAMES[key];
        }
    }
    _write(_state["file"], "Fatal Python error: " + name + "\n\n");
    _dump_all_threads(_state["file"], _state["all_threads"]);
    prev = _state["previous"].get(signum);
    if prev is not None {
        host_signal.signal(signum, prev);
    } else {
        host_signal.signal(signum, host_signal.SIG_DFL);
    }
    host_os.kill(host_os.getpid(), signum);
}


def enable(file: any = None, all_threads: bool = True) -> None {
    # faulthandler_enable: install the handler for every supported fatal
    # signal present on this platform, keeping the previous disposition.
    sink = _resolve_sink(file);
    for key in FATAL_SIGNAL_NAMES {
        signum = getattr(host_signal, key, None);
        if signum is None {
            continue;
        }
        _state["previous"][signum] = host_signal.signal(signum, _fatal_handler);
    }
    _state["enabled"] = True;
    _state["file"] = sink;
    _state["all_threads"] = all_threads;
}


def disable() -> None {
    # faulthandler_disable_py: restore every saved previous disposition.
    for signum in list(_state["previous"].keys()) {
        host_signal.signal(signum, _state["previous"][signum]);
    }
    _state["previous"] = {};
    _state["enabled"] = False;
    _state["file"] = None;
}


def is_enabled() -> bool {
    return _state["enabled"];
}


# ---------------- explicit dumps ----------------

def dump_traceback(file: any = None, all_threads: bool = True) -> None {
    # faulthandler_dump_traceback_py: traceback only, no banner.
    _dump_all_threads(_resolve_sink(file), all_threads);
}


def dump_c_stack(file: any = None) -> None {
    # faulthandler_dump_c_stack / _Py_DumpStack: the guest VM has no access to
    # the native C stack, so emit the marker the C path would have written
    # followed by nothing (documented divergence).
    _write(_resolve_sink(file), "Cannot dump native C stack under guest VM\n");
}


# ---------------- delayed watchdog ----------------

def _watchdog_fire() -> None {
    # watchdog_callback: banner with formatted timeout, full-thread dump,
    # optional os._exit(1), reschedule when repeat was requested.
    sink = _state["file"];
    _write(sink, "Timeout (" + _format_timeout(_state["watchdog_timeout"]) + "):\n\n");
    _dump_all_threads(sink, True);
    if hasattr(sink, "flush") {
        sink.flush();
    }
    if _state["watchdog_exit"] {
        host_os._exit(1);
    }
    if _state["watchdog_repeat"] {
        timer = host_threading.Timer(_state["watchdog_timeout"], _watchdog_fire);
        timer.daemon = True;
        _state["watchdog"] = timer;
        timer.start();
    }
}


def dump_traceback_later(timeout: float, repeat: bool = False, file: any = None, `exit: bool = False) -> None {
    # faulthandler_dump_traceback_later: arm (replacing any pending watchdog)
    # a daemon timer that dumps after timeout seconds.
    cancel_dump_traceback_later();
    sink = _resolve_sink(file);
    _state["file"] = sink;
    _state["watchdog_timeout"] = timeout;
    _state["watchdog_repeat"] = repeat;
    _state["watchdog_exit"] = `exit;
    timer = host_threading.Timer(timeout, _watchdog_fire);
    timer.daemon = True;
    _state["watchdog"] = timer;
    timer.start();
}


def cancel_dump_traceback_later() -> None {
    # faulthandler_cancel_dump_traceback_later_py: safe when never armed.
    timer = _state.get("watchdog");
    if timer is not None {
        timer.cancel();
        _state["watchdog"] = None;
    }
    _state["watchdog_repeat"] = False;
    _state["watchdog_exit"] = False;
}


# ---------------- user-registered signals ----------------

def _make_user_handler(signum: int) -> any {
    def handler(sig: int, frame: any) -> None {
        user = _state["user"].get(signum);
        if user is None {
            return;
        }
        _dump_all_threads(user["file"], user["all_threads"]);
        if user["chain"] {
            prev = user["previous"];
            if callable(prev) {
                prev(sig, frame);
            }
        }
    }
    return handler;
}


def register(signum: int, file: any = None, all_threads: bool = True, chain: bool = False) -> None {
    # faulthandler_register_py: keep the previous disposition once, refresh
    # the dump configuration on repeated registrations. Returns None.
    _check_signum(signum);
    user = _state["user"].get(signum);
    if user is None {
        previous = host_signal.signal(signum, _make_user_handler(signum));
        user = {"previous": previous};
        _state["user"][signum] = user;
    }
    user["file"] = _resolve_sink(file);
    user["all_threads"] = all_threads;
    user["chain"] = chain;
}


def unregister(signum: int) -> bool {
    # faulthandler_unregister_py: False when nothing is registered.
    _check_signum(signum);
    user = _state["user"].pop(signum, None);
    if user is None {
        return False;
    }
    host_signal.signal(signum, user["previous"]);
    return True;
}


# ---------------- crash primitives (test-only surface) ----------------

def _read_null() -> None {
    # faulthandler_read_null: dereferences NULL -> SIGSEGV/SIGBUS. Under the
    # facade the same process death comes from raising SIGSEGV directly.
    host_os.kill(host_os.getpid(), host_signal.SIGSEGV);
}


def _sigsegv(release_gil: bool = False) -> None {
    # faulthandler_sigsegv: raise(SIGSEGV); release_gil is meaningless under
    # the GIL-hosted facade and accepted for signature parity.
    host_os.kill(host_os.getpid(), host_signal.SIGSEGV);
}


def _sigfpe() -> None {
    # faulthandler_sigfpe: integer div-by-zero or manual raise(SIGFPE).
    host_os.kill(host_os.getpid(), host_signal.SIGFPE);
}


def _sigabrt() -> None {
    # faulthandler_sigabrt: abort().
    host_os.abort();
}


def _fatal_error_c_thread() -> None {
    # faulthandler_fatal_error_c_thread: Py_FatalError("in new thread") from
    # a fresh C thread; Py_FatalError aborts, so mirror write + abort.
    def die() -> None {
        host_sys.stderr.write("Fatal Python error: in new thread\n\n");
        host_sys.stderr.flush();
        host_os.abort();
    }
    thread = host_threading.Thread(target=die);
    thread.daemon = True;
    thread.start();
    thread.join();
}
