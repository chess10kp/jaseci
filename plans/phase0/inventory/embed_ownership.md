# Embed ownership inventory (Phase 0 / E1 input)

Source of truth for current fused-host resources. Target owners are from `PLAN.md` §4.

## Module-global managed state (`embed_agent.jac`)

| Symbol | Type | Role | Target owner |
|---|---|---|---|
| `_q` | `Queue[str]` | framed agent→TUI blobs | instance `TuiEventQueue` |
| `_stop` | `threading.Event` | feed stop signal | instance `AgentSession` / adapter |
| `_stub` | `bool` | stub vs real | instance adapter |
| `_thread` | `Thread \| None` | feed worker | tracked non-daemon worker |
| `_poll_count` | `int` | debug counter | drop or instance |

Public callables bound by host: `setup`, `poll`, `send`, `stop`.

## Workers

| Thread | Created by | Daemon | Joined today |
|---|---|---|---|
| Feed `_feed` | `_start_real` / `_start_stub` | **yes** | `stop()` → `join(2.0)`, swallow errors |
| Turn `_ui_turn_worker` | `ui_send` | **yes** | **not** joined; cancelled via `ui_stop` |

Phase 3 requires non-daemon tracked workers and explicit timeout results.

## Native CPython / GIL sites

| Location | Symbols | Notes |
|---|---|---|
| `host_embed.na.jac` | `jac_engine_boot`, `PyRun_*`, `Py_Finalize`, bind poll/send | process lifecycle |
| `transport.na.jac` `EmbedPyTransport` | `PyEval_SaveThread`/`RestoreThread`, `CallNoArgs`/`CallOneArg`, `DecRef` | **GIL + callable refs live here today** |
| Target | `EmbedRuntime` only | **Closed in Phase 4** |

Callable refs: `py_poll_fn` / `py_send_fn` as `int` holding `PyObject*`. `close_py` exists but host must not call it after the loop (object may be dead); finalization owns cleanup today.

## Shutdown sequence (Phase 0 baseline → Phase 1 target)

### Baseline at Phase 0 start (pre-Phase-1 reorder)

1. `_agent_stop()` (set stop, join feed ≤2s, `ui_stop`)
2. `tui_leave_screen`
3. `Py_Finalize`
4. `tty_close`

Problem: managed cleanup waits happen **before** full tty restoration.

### Phase 1 target (terminal-first)

1. Reject further input (`quit_flag` / leave loop)
2. `tui_leave_screen` (mouse/paste/cursor/alt-screen)
3. `tty_close` (restore termios)
4. `_agent_stop()` under deadline (join + diagnostics)
5. `Py_Finalize` only after stop returns (Phase 4/6 add skip-on-timeout)

## Resource release checklist

1. tty fd + saved termios
2. alt-screen / mouse / cursor protocols
3. feed thread
4. turn worker(s) (cancel; hard join still missing)
5. bus subscription inside `ui_stream`
6. queue `_q` (reclaimed on process exit / finalize)
7. bound poll/send callables
8. embedded CPython
9. engine boot / trailer runtime

## Lifecycle status gap

| Managed wire | Native `TuiStatus` (pre-Phase-1) |
|---|---|
| `idle` | `IDLE` |
| `running` | `RUNNING` |
| `stopping` | **`UNKNOWN`** ← bug |
| other | `UNKNOWN` |

## Optimistic transcript gap

`input._handle_submit` inserts `upsert_event(-1, USER, …)` before host acceptance. `ui_send` bool is logged only, not returned to native. Phase 1 replaces this with `PendingSubmission` + command receipt.
