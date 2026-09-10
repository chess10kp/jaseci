# Product-path facade for _thread (CPython 3.14 Modules/_threadmodule.c),
# exercised by CPython's Lib/test/test_thread.py.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original is
# pthread-backed -- lockobject wraps a PyMutex with PyTime_t timeout handling,
# and thread creation bootstraps interpreter state on a fresh OS thread
# (daemon accounting, shutdown handles, excepthook routing). This facade
# splits the surface along what jacpython's ceval owns today:
#
#   * Locks are a native state machine over a locked flag, with byte-exact
#     argument validation and error strings from lock_acquire_parse_args /
#     lock_PyThread_release_lock ("can't specify a timeout for a non-blocking
#     call", "timeout value must be a non-negative number", "timeout value is
#     too large", "release unlocked lock"). The guest ceval is single-threaded,
#     so a contended blocking acquire cannot park the caller; it raises
#     RuntimeError instead of deadlocking the whole interpreter (documented
#     divergence; revisit when ceval grows a cross-thread substrate).
#   * OS-thread primitives with no guest-visible state (get_ident,
#     get_native_id, _count, stack_size, interrupt_main) delegate to the host
#     _thread through the same host-module bridge getpath.jac uses for its
#     os/stat probes: jacpython runs atop CPython, so host values are ground
#     truth.
#   * Thread creation (start_new_thread/start_new/start_joinable_thread)
#     validates arguments exactly like the C converters, then fails with the
#     C "can't start new thread" ThreadError: running guest bytecode on
#     another OS thread needs ceval concurrency plumbing that PLAN §12.4
#     defers. exit()/exit_thread() raise SystemExit like the C originals;
#     _ThreadHandle mirrors the handle surface inertly (nothing can start).
#
# Out of scope by design: RLock (test_thread does not exercise it -- add it
# together with its implementation module when threading.RLock converts) and
# the host-side internals _excepthook/_shutdown/_make_thread_handle/_setname.
# The obsolete "exit" alias of exit_thread is likewise absent (keyword
# collision); guest code uses exit_thread.

import _thread as host_thread;

glob TIMEOUT_MAX: any = 9223372036.0;
# Host-derived pin: PY_TIMEOUT_MAX microseconds expressed in seconds, the
# value host CPython exposes as _thread.TIMEOUT_MAX on this platform.


# ---------------- LockType (lockobject.c) ----------------

obj _P2Lock {
    has locked_flag: bool = False;

    # lock_acquire_parse_args: the unset-timeout sentinel is -1 (seconds), so
    # an explicit acquire(blocking=True, timeout=-1) equals no timeout given.
    def acquire(blocking: bool = True, timeout: any = -1) -> any {
        if not blocking and timeout != -1 {
            raise ValueError("can't specify a timeout for a non-blocking call");
        }
        if timeout < 0 and timeout != -1 {
            raise ValueError("timeout value must be a non-negative number");
        }
        if blocking and timeout != -1 {
            micros = timeout * 1000000;
            if micros > 9223372036854775807 {
                raise OverflowError("timeout value is too large");
            }
        }
        if not self.locked_flag {
            self.locked_flag = True;
            return True;
        }
        if not blocking {
            return False;
        }
        # Single-ceval-thread model: no other thread can release this lock,
        # so blocking here would hang the interpreter. CPython would park.
        raise RuntimeError("deadlock: lock is already locked");
    }

    # Sanity check mirrors lock_PyThread_release_lock: the lock must be locked.
    def release {
        if not self.locked_flag {
            raise RuntimeError("release unlocked lock");
        }
        self.locked_flag = False;
    }

    def locked -> bool {
        return self.locked_flag;
    }

    def __enter__ -> any {
        return self.acquire();
    }

    def __exit__(et: any, ev: any, tb: any) -> any {
        self.release();
        return None;
    }
}


# ---------------- _ThreadHandle (PyThreadHandleObject) ----------------

obj _P2ThreadHandle {
    has ident: int = 0;

    def join(timeout: any = None) {
        # ThreadHandle_join on a never-started handle.
        raise RuntimeError("thread not started");
    }

    def is_done -> bool {
        return False;
    }

    def _set_done {
        return None;
    }

    def __repr__ -> str {
        return "<_thread._ThreadHandle object: ident=" + str(self.ident) + ">";
    }
}


# ---------------- module-level surface (thread_methods[]) ----------------

def allocate_lock -> _P2Lock {
    return _P2Lock();
}


def exit_thread {
    # thread_PyThread_exit_thread: SystemExit unwinds the calling thread.
    # The obsolete "exit" spelling collides with a Jac keyword and is
    # intentionally absent; exit_thread is the non-keyword name.
    raise SystemExit;
}


def get_ident -> int {
    return host_thread.get_ident();
}


def get_native_id -> int {
    return host_thread.get_native_id();
}


def _count -> int {
    return host_thread._count();
}


def stack_size(new_size: int = 0) -> int {
    # Delegated: PyThread_get/set_stacksize validation ("size must be at
    # least %zi bytes" / "size not valid: %zd bytes") is platform-exact on
    # the host and carries the cross-call global state for free.
    return host_thread.stack_size(new_size);
}


def interrupt_main(signum: int = 2) -> any {
    # Default signum is signal.SIGINT; PyErr_SetInterruptEx's range check
    # raises the host's own "signal number out of range" ValueError. The
    # any-cast sidesteps typeshed's Signals-enum annotation on the host stub.
    return host_thread.interrupt_main(signum as any);
}


def daemon_threads_allowed -> bool {
    # No daemon-thread substrate on the single-threaded ceval.
    return False;
}


def _is_main_interpreter -> bool {
    return True;
}


def start_new_thread(func: any, args: any, kwargs: any = None) -> int {
    # Converter order mirrors thread_PyThread_start_new_thread.
    if not callable(func) {
        raise TypeError("first arg must be callable");
    }
    if not isinstance(args, tuple) {
        raise TypeError("2nd arg must be a tuple");
    }
    if kwargs is not None and not isinstance(kwargs, dict) {
        raise TypeError("optional 3rd arg must be a dictionary");
    }
    raise RuntimeError("can't start new thread");
}


def start_new(func: any, args: any, kwargs: any = None) -> int {
    # Obsolete synonym of start_new_thread().
    return start_new_thread(func, args, kwargs);
}


def start_joinable_thread(func: any, handle: any = None, daemon: bool = True) -> _P2ThreadHandle {
    # PyArg keywords are (function, handle, daemon); converter messages match
    # thread_PyThread_start_joinable_thread.
    if not callable(func) {
        raise TypeError("thread function must be callable");
    }
    if handle is not None and not isinstance(handle, _P2ThreadHandle) {
        raise TypeError("'handle' must be a _ThreadHandle");
    }
    raise RuntimeError("can't start new thread");
}


# Old alias: the lock type object exposed under its historic name.
glob error = RuntimeError;
glob LockType = _P2Lock;
