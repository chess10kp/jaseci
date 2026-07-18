#!/usr/bin/env python3
"""PTY integration tests for bin/jac-ai-tui with stub backend.

Phases:
  1. TUI chrome paints
  2. Typed prompt -> stub echo reply (round-trip)
  3. Terminal resize does not crash the host
  4. Second prompt round-trip after resize
  5. Clean quit on ctrl-c
"""

from __future__ import annotations

import contextlib
import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import time
from collections.abc import Callable


def _read_available(master: int) -> bytes:
    try:
        return os.read(master, 65536)
    except OSError:
        return b""


def _strip_ansi(data: bytes) -> str:
    return re.sub(r"\x1b\[[0-9;?]*[a-zA-Z]", "", data.decode("utf-8", "replace"))


def _wait_for(
    master: int,
    predicate: Callable[[bytes], bool],
    deadline: float,
    out: bytes,
) -> tuple[bytes, bool]:
    while time.time() < deadline:
        if select.select([master], [], [], 0.2)[0]:
            chunk = _read_available(master)
            if not chunk:
                break
            out += chunk
            if predicate(out):
                return out, True
    return out, False


def _set_winsize(master: int, rows: int, cols: int) -> None:
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: ai_tui_pty_smoke.py <bindir>", file=sys.stderr)
        return 2

    bindir = os.path.abspath(sys.argv[1])
    binary = os.path.join(bindir, "jac-ai-tui")
    if not os.path.isfile(binary):
        print(f"missing binary: {binary}", file=sys.stderr)
        return 2

    env = dict(os.environ)
    env["TERM"] = "xterm-256color"
    ld = bindir
    if env.get("LD_LIBRARY_PATH"):
        ld = bindir + os.pathsep + env["LD_LIBRARY_PATH"]
    env["LD_LIBRARY_PATH"] = ld
    env.pop("OPENAI_API_KEY", None)

    pid, master = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
        tty_path = os.ttyname(0)
        os.chdir(bindir)
        os.execve(binary, [binary, "--stub", "--tty", tty_path], env)
        raise SystemExit(127)

    out = b""
    exit_code: int | None = None

    def _child_exited() -> bool:
        nonlocal exit_code
        waited = os.waitpid(pid, os.WNOHANG)
        if waited[0] == pid:
            status = waited[1]
            exit_code = (status >> 8) if os.WIFEXITED(status) else 1
            return True
        return False

    # Phase 1: wait for chrome
    deadline = time.time() + 15.0
    while time.time() < deadline:
        if select.select([master], [], [], 0.2)[0]:
            out += _read_available(master)
        if "│".encode() in out and len(out) > 400:
            break
        if _child_exited():
            break

    if exit_code is not None:
        print(f"child exited early: {exit_code}", file=sys.stderr)
        print(_strip_ansi(out)[-500:], file=sys.stderr)
        return 1
    if "│".encode() not in out:
        print("no TUI border in output", file=sys.stderr)
        print(_strip_ansi(out)[:500], file=sys.stderr)
        return 1

    # Phase 2: first round-trip
    with contextlib.suppress(OSError):
        os.write(master, b"ping roundtrip\r")
    out, ok = _wait_for(
        master, lambda b: b"echo:" in _strip_ansi(b).encode(), time.time() + 8.0, out
    )
    if not ok:
        print(
            "ROUND TRIP FAILED: typed a prompt but stub produced no output",
            file=sys.stderr,
        )
        print(_strip_ansi(out)[-800:], file=sys.stderr)
        return 1

    # Phase 3: resize to 30x100 — must not kill the process
    _set_winsize(master, 30, 100)
    time.sleep(0.4)
    if _child_exited():
        print("process died after resize", file=sys.stderr)
        return 1
    if select.select([master], [], [], 0.5)[0]:
        out += _read_available(master)

    # Phase 4: second round-trip after resize
    with contextlib.suppress(OSError):
        os.write(master, b"second prompt\r")
    out, ok2 = _wait_for(
        master,
        lambda b: b"echo: second prompt" in _strip_ansi(b).encode(),
        time.time() + 8.0,
        out,
    )
    if not ok2:
        print("SECOND ROUND TRIP FAILED after resize", file=sys.stderr)
        print(_strip_ansi(out)[-800:], file=sys.stderr)
        return 1

    # Phase 5: quit
    with contextlib.suppress(OSError):
        os.write(master, b"\x03")
    time.sleep(0.5)
    for _ in range(10):
        if select.select([master], [], [], 0.1)[0]:
            out += _read_available(master)

    if exit_code is None:
        end = time.time() + 5.0
        while time.time() < end:
            if _child_exited():
                break
            time.sleep(0.1)
        else:
            with contextlib.suppress(ProcessLookupError):
                os.kill(pid, signal.SIGTERM)
            os.waitpid(pid, 0)
            exit_code = 1

    if len(out) <= 200:
        print("too little pty output", file=sys.stderr)
        return 1
    if exit_code != 0:
        print(f"bad exit code: {exit_code}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
