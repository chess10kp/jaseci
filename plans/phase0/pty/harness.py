#!/usr/bin/env python3
"""Phase 0 PTY characterization harness for jac-ai-tui.

Uses stdlib ``pty`` (no pexpect required). Each scenario has a wall-clock
deadline. Writes a JSON summary under ``plans/phase0/pty/results/``.

Examples::

    python3 plans/phase0/pty/harness.py --list
    python3 plans/phase0/pty/harness.py --scenario boot_quit --deadline 20
    python3 plans/phase0/pty/harness.py --all --deadline 30

Requires a built host at ``jac/jaclang/cli/ai_tui_na/bin/jac-ai-tui``.
Stub mode is forced by clearing byLLM seams so boot never blocks on providers.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import os
import pty
import select
import signal
import struct
import sys
import termios
import time
from dataclasses import asdict, dataclass, field
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
HOST = REPO / "jac" / "jaclang" / "cli" / "ai_tui_na" / "bin" / "jac-ai-tui"
RESULTS = Path(__file__).resolve().parent / "results"


@dataclass
class ScenarioResult:
    name: str
    ok: bool
    deadline_s: float
    elapsed_s: float
    exit_status: int | None
    notes: list[str] = field(default_factory=list)
    output_tail: str = ""


def _child_env() -> dict[str, str]:
    env = os.environ.copy()
    # Prefer stub: no real provider during characterization.
    env.pop("JAC_AI_TUI_BYLLM_SRC", None)
    env.pop("JAC_AI_TUI_DEPS", None)
    env.pop("JAC_AI_TUI_NO_STUB", None)
    env.setdefault("TERM", "xterm-256color")
    debug = RESULTS / "debug.log"
    debug.parent.mkdir(parents=True, exist_ok=True)
    env["JAC_AI_TUI_DEBUG_LOG"] = str(debug)
    return env


def _set_winsize(fd: int, rows: int = 24, cols: int = 80) -> None:
    # TIOCSWINSZ
    packed = struct.pack("HHHH", rows, cols, 0, 0)
    try:
        import fcntl

        fcntl.ioctl(fd, termios.TIOCSWINSZ, packed)
    except OSError:
        pass


def _spawn_host() -> tuple[int, int]:
    if not HOST.is_file():
        raise FileNotFoundError(f"missing host binary: {HOST}")
    pid, master = pty.fork()
    if pid == 0:
        os.environ.update(_child_env())
        os.chdir(str(REPO))
        os.execve(str(HOST), [str(HOST)], os.environ)
    _set_winsize(master)
    return pid, master


def _drain(master: int, budget_s: float) -> bytes:
    end = time.monotonic() + budget_s
    chunks: list[bytes] = []
    while time.monotonic() < end:
        timeout = max(0.0, end - time.monotonic())
        r, _, _ = select.select([master], [], [], min(timeout, 0.2))
        if not r:
            continue
        try:
            data = os.read(master, 4096)
        except OSError:
            break
        if not data:
            break
        chunks.append(data)
    return b"".join(chunks)


def _wait_pid(pid: int, deadline: float) -> int | None:
    end = time.monotonic() + deadline
    while time.monotonic() < end:
        wpid, status = os.waitpid(pid, os.WNOHANG)
        if wpid == pid:
            if os.WIFEXITED(status):
                return os.WEXITSTATUS(status)
            if os.WIFSIGNALED(status):
                return -os.WTERMSIG(status)
            return status
        time.sleep(0.05)
    return None


def _kill(pid: int, sig: int = signal.SIGTERM) -> None:
    with contextlib.suppress(ProcessLookupError):
        os.kill(pid, sig)


def run_scenario(name: str, deadline_s: float) -> ScenarioResult:
    t0 = time.monotonic()
    notes: list[str] = []
    pid = -1
    master = -1
    out = b""
    try:
        pid, master = _spawn_host()
        # Embedded interpreter may compile on first boot; wait for activity or budget.
        boot_budget = min(12.0, max(3.0, deadline_s / 2))
        out += _drain(master, boot_budget)
        if len(out) == 0:
            notes.append(
                "no pty output during boot wait (host opens /dev/tty; paint may "
                "still be live — quit/signal paths remain valid)"
            )
        # Enter is LF; the native decoder also accepts CR.
        enter = b"\n"
        if name == "boot_quit":
            os.write(master, b"/quit" + enter)
            out += _drain(master, min(5.0, deadline_s / 3))
        elif name == "boot_ctrl_c_idle":
            os.write(master, b"\x03")
            out += _drain(master, min(2.0, deadline_s / 4))
            os.write(master, b"/quit" + enter)
            out += _drain(master, min(5.0, deadline_s / 3))
        elif name == "boot_prompt_stub":
            os.write(master, b"hello from pty" + enter)
            out += _drain(master, min(4.0, deadline_s / 3))
            os.write(master, b"/quit" + enter)
            out += _drain(master, min(5.0, deadline_s / 3))
        elif name == "boot_sigterm":
            _kill(pid, signal.SIGTERM)
        elif name == "boot_sighup":
            _kill(pid, signal.SIGHUP)
        elif name == "boot_resize":
            _set_winsize(master, 30, 100)
            out += _drain(master, min(2.0, deadline_s / 4))
            os.write(master, b"/quit" + enter)
            out += _drain(master, min(5.0, deadline_s / 3))
        elif name == "boot_eof":
            os.close(master)
            master = -1
        else:
            notes.append(f"unknown scenario {name!r}; sending /quit")
            os.write(master, b"/quit" + enter)
            out += _drain(master, min(5.0, deadline_s / 3))

        remaining = max(0.5, deadline_s - (time.monotonic() - t0))
        status = _wait_pid(pid, remaining)
        if status is None:
            notes.append("deadline exceeded; sending SIGKILL")
            _kill(pid, signal.SIGKILL)
            status = _wait_pid(pid, 2.0)
            ok = False
        else:
            if name in ("boot_sigterm", "boot_sighup", "boot_eof"):
                ok = status is not None
                notes.append("signal/eof exit characterized (not a restore gate)")
            else:
                ok = status == 0
                if status != 0:
                    notes.append(f"unexpected exit status {status}")
        notes.append(f"captured {len(out)} output bytes")
        tail = out[-400:].decode("utf-8", errors="replace")
        return ScenarioResult(
            name=name,
            ok=bool(ok),
            deadline_s=deadline_s,
            elapsed_s=round(time.monotonic() - t0, 3),
            exit_status=status,
            notes=notes,
            output_tail=tail,
        )
    except Exception as exc:  # noqa: BLE001 — characterization must always report
        if pid > 0:
            _kill(pid, signal.SIGKILL)
        return ScenarioResult(
            name=name,
            ok=False,
            deadline_s=deadline_s,
            elapsed_s=round(time.monotonic() - t0, 3),
            exit_status=None,
            notes=[f"exception: {exc!r}"],
            output_tail=out[-400:].decode("utf-8", errors="replace") if out else "",
        )
    finally:
        if master >= 0:
            with contextlib.suppress(OSError):
                os.close(master)


SCENARIOS = [
    "boot_quit",
    "boot_ctrl_c_idle",
    "boot_prompt_stub",
    "boot_resize",
    "boot_sigterm",
    "boot_sighup",
    "boot_eof",
]


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--scenario", action="append", default=[])
    ap.add_argument("--all", action="store_true")
    ap.add_argument("--deadline", type=float, default=25.0)
    args = ap.parse_args()
    if args.list:
        return 0
    names = list(SCENARIOS) if args.all else (args.scenario or ["boot_quit"])
    RESULTS.mkdir(parents=True, exist_ok=True)
    results = [run_scenario(n, args.deadline) for n in names]
    stamp = time.strftime("%Y%m%d-%H%M%S")
    out_path = RESULTS / f"pty-{stamp}.json"
    payload = {
        "host": str(HOST),
        "host_exists": HOST.is_file(),
        "results": [asdict(r) for r in results],
    }
    out_path.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    return 0 if all(r.ok for r in results) else 1


if __name__ == "__main__":
    sys.exit(main())
