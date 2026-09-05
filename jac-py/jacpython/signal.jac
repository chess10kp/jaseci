# Native signal module facade (lift of reference/cpython/Modules/signalmodule.c).
#
# signalmodule.c is OS-coupled end to end: real delivery needs kernel signal
# disposition on the HOST process, which no guest VM state can influence. This
# facade lifts what maps cleanly onto jacpython's runtime and layers it over
# the delegated host snapshot at the import sites (see build_signal_facade in
# ceval.jac), so nothing that works through delegation regresses:
#
# - Constants: the full Linux/glibc surface built by signal_add_constants()
#   (C file insertion order; WSA/#else branches never fire on this platform),
#   as guest-native ints so identity and arithmetic stay in-VM. Values are
#   pinned against the CPython 3.14 linux-x86_64 build CI gates.
# - SIG_DFL / SIG_IGN: exposed as native int sentinels 0 / 1 instead of the
#   host IntEnum members. IntEnum identity across the bridge is not
#   reproducible without minting enum instances; int comparison semantics
#   (the only thing signal code relies on) are preserved exactly.
# - Synchronous dispatch core, implemented natively over a handler table:
#   signal()/getsignal()/raise_signal()/default_int_handler. raise_signal
#   delivers SYNCHRONOUSLY like CPython's raise_signal_impl: the registered
#   handler runs on the calling "thread" before raise_signal returns, and
#   default_int_handler raises KeyboardInterrupt.
#
# Known divergences (ledger):
# - Handler REGISTRATION stays guest-side only: the host process disposition
#   is not touched, because a guest callable cannot run from the host C
#   trampoline. OS-delivered signals therefore do not invoke guest handlers;
#   only raise_signal-driven delivery does.
# - SIG_DFL delivery for a fatal signum cannot terminate the process from
#   inside the VM; raise_signal treats it as delivered-and-ignored.
# - Everything needing live kernel/process state (alarm, setitimer/getitimer,
#   pthread_sigmask, sigpending, sigwait/sigtimedwait/sigwaitinfo, pause,
#   pthread_kill, set_wakeup_fd/wakeup_fd, strsignal, valid_signals,
#   siginterrupt, ItimerError, struct_siginfo, Signals/Handlers/Sigmasks
#   enums) resolves from the delegated host snapshot under the native
#   overrides -- identical behavior to pre-facade delegation, minus repeated
#   whole-module proxying.

import from objects {
    PyObj,
    PyStr,
    PyInt,
    PyBool,
    PyFloat,
    PyBytes,
    PyList,
    PyTuple,
    PyDict,
    PySet,
    PyNoneType,
    py_none,
    py_error,
}

# ---- constants (Linux/glibc, signal_add_constants() order) ------------------

glob NSIG: int = 65,

     SIG_BLOCK: int = 0,
     SIG_UNBLOCK: int = 1,
     SIG_SETMASK: int = 2,

     SIGHUP: int = 1,
     SIGINT: int = 2,
     SIGQUIT: int = 3,
     SIGILL: int = 4,
     SIGTRAP: int = 5,
     SIGIOT: int = 6,
     SIGABRT: int = 6,
     SIGFPE: int = 8,
     SIGKILL: int = 9,
     SIGBUS: int = 7,
     SIGSEGV: int = 11,
     SIGSYS: int = 31,
     SIGPIPE: int = 13,
     SIGALRM: int = 14,
     SIGTERM: int = 15,
     SIGUSR1: int = 10,
     SIGUSR2: int = 12,
     SIGCLD: int = 17,
     SIGCHLD: int = 17,
     SIGPWR: int = 30,
     SIGIO: int = 29,
     SIGURG: int = 23,
     SIGWINCH: int = 28,
     SIGPOLL: int = 29,
     SIGSTOP: int = 19,
     SIGSTKFLT: int = 16,
     SIGTSTP: int = 20,
     SIGCONT: int = 18,
     SIGTTIN: int = 21,
     SIGTTOU: int = 22,
     SIGVTALRM: int = 26,
     SIGPROF: int = 27,
     SIGXCPU: int = 24,
     SIGXFSZ: int = 25,
     SIGRTMIN: int = 34,
     SIGRTMAX: int = 64,

     ITIMER_REAL: int = 0,
     ITIMER_VIRTUAL: int = 1,
     ITIMER_PROF: int = 2;

# ---- handler-table state ----------------------------------------------------
# Values mirror signal_get_set_handlers(): every signum starts at SIG_DFL
# (native int 0) except SIGINT, which gets default_int_handler -- the exact
# initialization CPython performs at module exec.

obj PySignalFn(PyObj) {
    has name: str;

    def tp_call(args: list[PyObj], kwargs: dict[str, PyObj]) -> PyObj {
        if self.name == "signal" {
            return _sig_signal(args);
        }
        if self.name == "getsignal" {
            return _sig_getsignal(args);
        }
        if self.name == "raise_signal" {
            return _sig_raise_signal(args);
        }
        if self.name == "default_int_handler" {
            # signal_default_int_handler: the only arm CPython installs by
            # default. Raises KeyboardInterrupt regardless of arguments --
            # the signum/frame pair carries no further information here.
            return py_error("KeyboardInterrupt", "");
        }
        return py_error("SystemError", "unknown signal function '" + self.name + "'");
    }
}

glob _sig_handlers: dict[int, PyObj] = {};
glob _sig_int_handler_fn: PyObj = PySignalFn(
    t="signal_fn", name="default_int_handler"
);

def _sig_init_handlers {
    if len(_sig_handlers) != 0 {
        return;
    }
    dfl = _sig_dfl();
    for signum in range(1, NSIG) {
        _sig_handlers[signum] = dfl;
    }
    # Install the Python SIGINT handler which raises KeyboardInterrupt
    # (signal_get_set_handlers tail).
    _sig_handlers[SIGINT] = _sig_int_handler_fn;
}

def _sig_dfl -> PyObj {
    return PyInt(t="int", val=0);
}

def _sig_ign -> PyObj {
    return PyInt(t="int", val=1);
}

# Strict int argument read (bool folds like the int subclass it is); None
# when absent/not-an-int so the caller raises the clinic TypeError text.
def _sig_int_arg(args: list[PyObj], idx: int) -> int | None {
    if idx >= len(args) {
        return None;
    }
    a = args[idx];
    if isinstance(a, PyBool) {
        return ((a as PyBool).to_index() as PyInt).val;
    }
    if isinstance(a, PyInt) {
        return (a as PyInt).val;
    }
    return None;
}

# Conservative callable check for handler registration. Guest-native
# scalars/containers are never callable; anything else (functions, user
# objects, native shims, host proxies) is accepted -- matching the C side,
# which defers to PyObject_Callable semantics we cannot fully introspect
# without importing the call machinery (import-cycle hazard).
def _sig_callable(o: PyObj) -> bool {
    if (
        isinstance(o, PyNoneType)
        or isinstance(o, PyBool)
        or isinstance(o, PyInt)
        or isinstance(o, PyFloat)
        or isinstance(o, PyStr)
        or isinstance(o, PyBytes)
        or isinstance(o, PyList)
        or isinstance(o, PyTuple)
        or isinstance(o, PyDict)
        or isinstance(o, PySet)
    ) {
        return False;
    }
    return True;
}

# signal.signal(signalnum, handler): registration arm only (see ledger).
def _sig_signal(args: list[PyObj]) -> PyObj {
    if len(args) == 1 {
        return py_error(
            "TypeError",
            "signal() missing 1 required positional argument: 'handler'",
        );
    }
    if len(args) != 2 {
        return py_error(
            "TypeError",
            "signal() missing 2 required positional arguments: "
            + "'signalnum' and 'handler'",
        );
    }
    signum = _sig_int_arg(args, 0);
    if signum is None {
        return py_error("TypeError", "an integer is required");
    }
    if signum < 1 or signum >= NSIG {
        return py_error("ValueError", "signal number out of range");
    }
    handler = args[1];
    if isinstance(handler, PyNoneType) {
        return py_error(
            "TypeError",
            "'signal handler must be signal.SIG_IGN, signal.SIG_DFL, "
            + "or a callable object'",
        );
    }
    is_sentinel = False;
    if isinstance(handler, PyInt) {
        v = (handler as PyInt).val;
        if v == 0 or v == 1 {
            is_sentinel = True;
        }
    }
    if not is_sentinel and not _sig_callable(handler) {
        return py_error(
            "TypeError",
            "'signal handler must be signal.SIG_IGN, signal.SIG_DFL, "
            + "or a callable object'",
        );
    }
    _sig_init_handlers();
    old = _sig_handlers[signum] as PyObj;
    _sig_handlers[signum] = handler;
    return old;
}

def _sig_getsignal(args: list[PyObj]) -> PyObj {
    if len(args) != 1 {
        return py_error(
            "TypeError", "getsignal() takes exactly one argument ("
            + str(len(args)) + " given)"
        );
    }
    signum = _sig_int_arg(args, 0);
    if signum is None {
        return py_error("TypeError", "an integer is required");
    }
    if signum < 1 or signum >= NSIG {
        return py_error("ValueError", "signal number out of range");
    }
    _sig_init_handlers();
    return _sig_handlers[signum];
}

# raise_signal delivers SYNCHRONOUSLY (raise_signal_impl semantics): the
# handler runs before this returns. SIG_DFL for a fatal signum would kill
# the process -- impossible from inside the VM, so it lands as
# delivered-and-ignored (divergence ledger above).
def _sig_raise_signal(args: list[PyObj]) -> PyObj {
    if len(args) != 1 {
        return py_error(
            "TypeError", "raise_signal() takes exactly one argument ("
            + str(len(args)) + " given)"
        );
    }
    signum = _sig_int_arg(args, 0);
    if signum is None {
        return py_error("TypeError", "an integer is required");
    }
    # Signal 0 is the existence probe and never delivers.
    if signum < 0 or signum >= NSIG {
        return py_error("ValueError", "signal number out of range");
    }
    if signum == 0 {
        return py_none();
    }
    _sig_init_handlers();
    handler = _sig_handlers[signum] as PyObj;
    if isinstance(handler, PyInt) {
        # SIG_DFL (0) and SIG_IGN (1): nothing runnable in-process.
        return py_none();
    }
    call_args: list[PyObj] = [];
    call_args.append(PyInt(t="int", val=signum as int));
    call_args.append(py_none());
    return handler.tp_call(call_args, {});
}

# Shim-module attribute table consumed by the import sites (constants +
# native dispatch core; the delegated host snapshot supplies the rest).
def signal_module_attrs() -> dict[str, PyObj] {
    attrs: dict[str, PyObj] = {};

    def add_const(name: str, value: int) -> None {
        attrs[name] = PyInt(t="int", val=value);
    }

    add_const("NSIG", NSIG);
    add_const("SIG_BLOCK", SIG_BLOCK);
    add_const("SIG_UNBLOCK", SIG_UNBLOCK);
    add_const("SIG_SETMASK", SIG_SETMASK);
    add_const("SIGHUP", SIGHUP);
    add_const("SIGINT", SIGINT);
    add_const("SIGQUIT", SIGQUIT);
    add_const("SIGILL", SIGILL);
    add_const("SIGTRAP", SIGTRAP);
    add_const("SIGIOT", SIGIOT);
    add_const("SIGABRT", SIGABRT);
    add_const("SIGFPE", SIGFPE);
    add_const("SIGKILL", SIGKILL);
    add_const("SIGBUS", SIGBUS);
    add_const("SIGSEGV", SIGSEGV);
    add_const("SIGSYS", SIGSYS);
    add_const("SIGPIPE", SIGPIPE);
    add_const("SIGALRM", SIGALRM);
    add_const("SIGTERM", SIGTERM);
    add_const("SIGUSR1", SIGUSR1);
    add_const("SIGUSR2", SIGUSR2);
    add_const("SIGCLD", SIGCLD);
    add_const("SIGCHLD", SIGCHLD);
    add_const("SIGPWR", SIGPWR);
    add_const("SIGIO", SIGIO);
    add_const("SIGURG", SIGURG);
    add_const("SIGWINCH", SIGWINCH);
    add_const("SIGPOLL", SIGPOLL);
    add_const("SIGSTOP", SIGSTOP);
    add_const("SIGSTKFLT", SIGSTKFLT);
    add_const("SIGTSTP", SIGTSTP);
    add_const("SIGCONT", SIGCONT);
    add_const("SIGTTIN", SIGTTIN);
    add_const("SIGTTOU", SIGTTOU);
    add_const("SIGVTALRM", SIGVTALRM);
    add_const("SIGPROF", SIGPROF);
    add_const("SIGXCPU", SIGXCPU);
    add_const("SIGXFSZ", SIGXFSZ);
    add_const("SIGRTMIN", SIGRTMIN);
    add_const("SIGRTMAX", SIGRTMAX);
    add_const("ITIMER_REAL", ITIMER_REAL);
    add_const("ITIMER_VIRTUAL", ITIMER_VIRTUAL);
    add_const("ITIMER_PROF", ITIMER_PROF);

    attrs["SIG_DFL"] = _sig_dfl();
    attrs["SIG_IGN"] = _sig_ign();
    for fname in ["signal", "getsignal", "raise_signal", "default_int_handler"] {
        attrs[fname] = PySignalFn(t="signal_fn", name=fname);
    }
    return attrs;
}
