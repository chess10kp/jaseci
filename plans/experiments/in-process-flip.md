# Experiment: in-process flip (Python owns agent, dlopen renderer)

Status: scoped; implementation in flight
Contradicts: `PLAN.md` §2.2 (execve → embed host); run as a **measured experiment**, not an approved reversal
Last revised: 2026-07-18

## Hypothesis

The embed shim (`libjacpyembed` + `EmbedRuntime` + CPython-in-native) may be heavier than necessary. The Phase 4 typed bridge (`bridge_schema`, `TuiSessionAdapter`) is already pure Python. If the CLI process stays alive and owns the adapter directly, the native side only needs tty render + input, loadable as `libtui.so` via ctypes, as `build_embed.sh` comments reference.

**Measure:** startup latency, binary size, GIL/thread complexity, shutdown reliability, dev-loop rebuild time.

## Topology comparison

### Shipped today (embed host)

```text
jac ai --tui
  └─ execve(bin/jac-ai-tui)           # Python process dies
       ├─ native TuiRuntime + loop
       ├─ EmbedRuntime (jacpyembed)    # boots bundled CPython inside native
       └─ embed_agent → TuiSessionAdapter (managed, second interpreter)
```

### Experiment (in-process flip)

```text
jac ai --tui  (JAC_AI_TUI_BACKEND=inprocess)
  └─ Python CLI stays alive
       ├─ TuiSessionAdapter            # same interpreter, no C-API shim
       ├─ PythonSessionBridge          # mirrors EmbedSessionClient in Python
       └─ ctypes.CDLL(libtui.so)       # native renderer only, no jacpyembed
            └─ host_dlopen.na.jac C-ABI exports
```

Single OS process in both cases. The flip removes the second interpreter and inverts loop ownership: **Python drives the session seam; native is a render/input library.**

## Non-goals (this experiment)

- Do not delete `host_embed.na.jac`, `build_embed.sh`, or the embed default path.
- Do not change `bridge_schema` wire shapes.
- Do not remove the `SEND:` legacy cmd round-trip (separate typed-CmdQueue refactor).
- Do not bake `libtui.so` into the fused payload yet (dev-tree experiment only).

## C-ABI surface (`host_dlopen.na.jac` → `bin/libtui.so`)

Built with `jac nacompile host_dlopen.na.jac --shared -o bin/libtui.so`.

| Export | Args | Returns | Notes |
|--------|------|---------|-------|
| `tui_init` | project, files_env, presets_env, tty_dev | 0 / errno | Idempotent; opens tty, enters alt-screen |
| `tui_apply_batch` | json (c_char_p) | 0 ok / 1 err | `decode_batch` + `apply_batch` + optional snapshot refresh |
| `tui_apply_snapshot` | json (c_char_p) | 0 ok / 1 err | `decode_snapshot` + `apply_snapshot` |
| `tui_wait_key` | timeout_ms | 1 ready / 0 timeout | Lock-free poll; GIL released by ctypes caller |
| `tui_handle_key` | (none) | 1 quit / 0 continue | Mutates TuiState; caller holds render lock |
| `tui_next_command` | (none) | c_char_p | FIFO drain of `CmdQueue` (`SEND:…`, `STOP`, …) |
| `tui_quit_requested` | (none) | 0/1 | |
| `tui_render` | (none) | 0 | Paint to native-owned tty fd |
| `tui_shutdown` | (none) | 0 | leave alt-screen, close tty |

Threading contract (same as pre-8a5301ddb `host.na.jac`): only `tui_wait_key` is lock-free; all other exports require the Python-side render lock.

Native module owns `TuiRuntime` as module globals (Jac objects never cross the ABI). No `EmbedRuntime`, no `jacpyembed`, no `embed_session_client`.

## Python side

### `tui_host.jac`

ctypes wrapper around the nine exports (restored from pre-8a5301ddb, updated for `apply_batch`/`apply_snapshot`).

### `python_session_bridge.jac`

Python mirror of `EmbedSessionClient` logic:

- Owns `TuiSessionAdapter` instance
- `start(req)` → adapter.start + return model/presets for `tui_init` seeding
- `submit_*` → adapter.submit with `bridge_schema` encode/decode
- `poll` / `snapshot` / `dispose` → adapter + JSON
- `dispatch_legacy_cmd(cmd)` → maps `CMD_SEND`/`CMD_STOP`/… to typed submit (same as `embed_session_client._dispatch_legacy_cmd`)
- `apply_send_receipt` → update native state fields on prompt acceptance

### `run_tui_in_process.impl.jac`

Two-thread loop (proven shape from old backend):

1. **feeder**: `adapter.poll()` → `host.apply_batch(json)` under render lock
2. **ticker**: `wait_key` (lock-free) → `handle_key` + drain `next_command` + `render` under lock → dispatch commands outside lock via `PythonSessionBridge`

Startup sequence:

1. `_ensure_tui_lib()` (lazy `build_dlopen.sh`)
2. `_require_tty()`
3. `adapter.start(req)` (stub or real)
4. `host.load` + `host.start(project, files, presets, tty)`
5. `host.apply_snapshot(adapter.snapshot_json)` for bootstrap
6. spawn feeder + ticker; join on quit

Shutdown (terminal-first, mirror embed host intent):

1. `stop_evt.set()` → ticker exits
2. `adapter.dispose(deadline_ms=2000)`
3. `host.shutdown()` under render lock
4. restore stdout/stderr redirect + UI env

### Routing

`runtime.impl.jac`:

```jac
if bool(r?.tui) {
    backend = os.environ.get("JAC_AI_TUI_BACKEND", "embed").strip().lower();
    if backend == "inprocess" {
        import from jaclang.cli.ai_tui.run_tui_in_process { run_tui_in_process }
        return run_tui_in_process(req);
    }
    import from jaclang.cli.ai_tui.run_tui_embed { run_tui_embed }
    return run_tui_embed(req);
}
```

Default remains `embed`. Experiment opt-in via `JAC_AI_TUI_BACKEND=inprocess`.

## Build

### `build_dlopen.sh`

- Same toolchain/Tty staging as `build_embed.sh` steps 1-stage modules
- `jac nacompile host_dlopen.na.jac --shared -o bin/libtui.so`
- No trailer, no jacpyembed
- Stamp: `bin/.dlopen_build_stamp`

### `_ensure_tui_lib` in `tui_shared.jac`

Mirror `_ensure_embed_host`: mtime stamp, lazy invoke `build_dlopen.sh`, return `{ok, path, error, hint}`.

## Tests

| Test | What |
|------|------|
| `test_ai_tui_in_process.jac` | build lib, load ctypes, stub adapter round-trip (init → poll → submit → dispose) without a real tty |
| extend `test_ai_tui_bridge.jac` | `PythonSessionBridge.dispatch_legacy_cmd` parity with embed path |
| manual | `JAC_AI_TUI_BACKEND=inprocess jac ai --tui --stub` full tty session |
| regression | default `embed` path unchanged; all 49 existing ai_tui tests pass |

## File checklist

| Action | Path |
|--------|------|
| **new** | `plans/experiments/in-process-flip.md` (this doc) |
| **new** | `ai_tui_na/host_dlopen.na.jac` |
| **new** | `ai_tui_na/build_dlopen.sh` |
| **new** | `ai_tui/tui_host.jac` |
| **new** | `ai_tui/python_session_bridge.jac` |
| **new** | `ai_tui/run_tui_in_process.jac` + `impl/run_tui_in_process.impl.jac` |
| **new** | `tests/cli/test_ai_tui_in_process.jac` |
| **edit** | `jac0core/impl/runtime.impl.jac` (backend switch) |
| **edit** | `tui_shared.jac` (`_ensure_tui_lib`, shared build helpers) |
| **edit** | `ai_tui_na/.gitignore` (`bin/libtui.so*`) |

## Success criteria

1. `JAC_AI_TUI_BACKEND=inprocess jac ai --tui --stub` runs a full interactive session.
2. Typed submit/poll/dispose round-trip works without `embed_agent` or `jacpyembed`.
3. Default embed path (`jac ai --tui`) unchanged; CI green on existing suite.
4. Documented startup/shutdown timings vs embed in experiment notes.

## Risks

| Risk | Mitigation |
|------|------------|
| GIL ↔ render-lock deadlock | Keep dispatch outside render lock (old proven pattern) |
| ctypes + Jac `--shared` ABI drift | Unit test loads lib and calls each export |
| Missing `parse_tui_status` / apply path | Reuse `session_apply.na.jac` verbatim in native lib |
| Stray prints corrupt alt-screen | stdout/stderr redirect (same as old in-process) |
| byLLM path/env | `_configure_ui_env` + adapter start with byllm seams from `tui_shared` |
