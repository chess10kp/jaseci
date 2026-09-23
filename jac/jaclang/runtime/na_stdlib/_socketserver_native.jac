"""Tiny libc FFI floor for ``socketserver``'s ``ForkingMixIn`` (issue #6978):
``fork`` / ``waitpid`` / ``_exit``. Kept as a separate Mechanism-F floor like
the other ``_*_native`` modules so the surface file stays pure Jac.
"""

import from c { def fork() -> i32;  }
import from c { def waitpid(pid: i32, status: bytes, options: i32) -> i32;  }
import from c { def _exit(status: i32) -> None;  }


def:pub proc_fork() -> int {
    return fork();
}


def:pub proc_waitpid(pid: int, options: int) -> int {
    st = b"\x00" * 4;
    return waitpid(i32(pid), st, i32(options));
}


def:pub proc_exit(status: int) {
    _exit(i32(status));
}
