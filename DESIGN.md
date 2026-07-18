# jac-ai-tui -- Design Document

A terminal user interface for the Jac AI coding agent. This document describes
**what the system is, how it is structured, and how it behaves** -- the contract
between its parts and the decisions that shape it. It is grounded in the actual
source under `jac/jaclang/cli/ai_tui/` (Python embed glue) and
`jac/jaclang/cli/ai_tui_na/` (native TUI host, ~4.2k LOC of `.na.jac`). It
primarily documents the **current, pre-refactor implementation**; `PLAN.md`
defines the future module ownership and migration gates.

---

## 1. Purpose

`jac-ai-tui` is the TUI mode of `jac ai`. It gives a user a full-screen,
mouse-aware, streaming chat surface for the agent: type a prompt, watch the
agent's reasoning/answer/tool calls render incrementally, switch models, attach
project files, and stop/reset turns -- all without leaving the terminal.

The agent itself (LLM I/O, tool use, conversation ledger) lives in Python
(`jaclang.cli.ai_agent`). The TUI is **native machine code** that embeds that
Python agent in-process and renders its event stream to the controlling tty.

**Design goal, stated plainly:** a self-contained release payload centered on
one native TUI host -- the renderer is linked Jac, and the agent runs in an
embedded CPython brought up inside that same long-lived process. There is no
dedicated renderer subprocess and no JSON-over-stdio transport. Transient
project-discovery/build commands and user-requested agent tools may still spawn
subprocesses.

## 2. Goals & non-goals

**Goals**

- One long-lived TUI process and one address space: native renderer + embedded
  Python agent, with no dedicated renderer process.
- Smooth streaming: incremental token deltas painted with minimal tty traffic.
- Responsive input under load: key handling never waits on the agent.
- Self-contained release payload: native host, embedded CPython/Jac payload, and
  required adjacent runtime shim are packaged together.
- Idiomatic Jac on the native side (see `IDIOMATIC-JAC.md`).

**Non-goals (today)**

- A component/multi-window framework (the renderer is one monolithic composer).
- Session persistence across runs (no transcript save/resume yet).
- Network/remote operation (it is local, talking to a real tty).

## 3. System architecture

One long-lived TUI process. Two cooperating runtimes share an address space,
separated by an **in-process but marshalled** boundary (text frames one way,
command lines the other). This topology statement excludes transient
project-discovery/build commands and user-requested tool subprocesses.

```
 ┌──────────────────────────── single fused binary: bin/jac-ai-tui ────────────────────────────┐
 │                                                                                              │
 │   NATIVE HOST (host_embed.na.jac, .na.jac)            EMBEDDED CPython (libjacpyembed)       │
 │                                                                                              │
 │   ┌──────────────┐   poll()/send() via     ┌─────────────────────┐   ui_stream()    ┌──────┐ │
 │   │  TUI loop    │◄──── C-API callable ────┤ embed_agent.jac     │◄──subscribe()─── │ bus  │ │
 │   │  tui_loop    │      PyObject_Call*      │ setup/poll/send/stop│                  │Queue │ │
 │   │              │────── send(cmd) ────────►│ _dispatch_cmd       │──ui_send/stop──► │      │ │
 │   └──────┬───────┘                          └─────────────────────┘                  └──────┘ │
 │          │                                                                                   │
 │   ┌──────▼────────┐  raw mode tty                              AgentEventBus.emit/emit_stream  │
 │   │  render diff  │  alt screen, mouse, sync-update            (reasoning/answer/tool/...)    │
 │   │  (tty fd)     │                                                                          │
 │   └───────────────┘                                                                          │
 └──────────────────────────────────────────────────────────────────────────────────────────────┘
                 ▲                                                       ▲
                 │ raw bytes / ANSI / DEC escapes                        │ LLM provider calls
                 ▼                                                       ▼
            controlling tty                                              (litellm/openai/...)
```

**Why one process.** The agent is Python (byLLM + the LLM/numpy stack). The TUI
is native because raw-mode tty, frame-diff rendering, and per-tick polling want
to be fast and allocation-light. Embedding CPython lets both coexist without a
serialization boundary *across a pipe* -- the boundary that remains is across a
function call, inside one address space (see §13).

## 4. Component map

### Native side -- `ai_tui_na/`

| Module | Role |
|---|---|
| `host_embed.na.jac` | **Entry.** Boots engine+CPython, opens tty, binds Python callables, runs the loop, tears down. |
| `tui_loop.na.jac` | The main tick: poll (GIL-released) → process keys → drain frames → render. |
| `tui_core.na.jac` | Loop orchestration helpers: size sync, screen enter/leave, render-once, state seeding. |
| `runtime.na.jac` | `TuiRuntime` -- the root bundle (state + diff engine + transport + cmd queue + paint buf). |
| `state.na.jac` | `TuiState` + `Event`/`DisplayRow`/`KindStyle`/`AcState`, event kinds, status/overlay enums. |
| `transport.na.jac` | **Legacy/pre-Phase-4 owner:** `EmbedPyTransport` performs CPython C-API/GIL poll/send, frame re-segmentation, and `CmdQueue`; target ownership moves to `EmbedRuntime` per `PLAN.md`. |
| `ipc.na.jac` | Frame parser: decodes key:value lines into `TuiState` mutations. |
| `ipc_schema.na.jac` | The shared wire constants (field/cmd names, separators). |
| `input.na.jac` | Key routing: overlay → autocomplete → ctrl → movement → edit. |
| `keys.na.jac` | Raw escape-sequence → typed `Key`/`KeyKind`. |
| `commands.na.jac` | Table-driven slash-command + palette registry (`CmdDef`). |
| `overlay.na.jac` | Modal pickers: command palette, model list, file list. |
| `select_list.na.jac` | Filterable, scrollable pick list used by overlays and autocomplete. |
| `autocomplete.na.jac` | Inline `/`-command and `@`-file completion. |
| `editor.na.jac` | `EditorState` -- multiline input, wrap-aware cursor/scroll, submit history ring. |
| `feed.na.jac` | Event → display rows: wrapping, prefix/color, render-mode dispatch. |
| `markdown.na.jac` | Markdown renderer (headings, code, fences, blockquote, hr). |
| `tool_block.na.jac` | Tool-call and tool-result block rendering. |
| `terminal_image.na.jac` | Inline images (Kitty/iTerm protocols, hyperlink fallback). |
| `screen.na.jac` | The monolithic frame composer → `list[str]` of styled rows. |
| `diff.na.jac` | `DiffEngine` -- incremental paint of changed cells with synchronized output. |
| `terminal.na.jac` | Single home of every ANSI/DEC escape; `Rgb`; SGR builders. |
| `theme.na.jac` | Palette (`Rgb` globs) + precomposed `TH_SGR_*` style strings. |
| `width.na.jac` | Visible-width / ANSI-aware truncation & padding. |
| `util.na.jac` | Shared helpers (`parse_int_or`, `split_kv`). |
| `tty/libc_tty_base.na.jac` | Libc FFI: raw mode, winsize, poll, key decode, stdio contract. |
| `tty/tty_plat.{linux,darwin}.na.jac` | Platform struct offsets/sizes. |

### Python side -- `ai_tui/`

| Module | Role |
|---|---|
| `embed_agent.jac` | The host's Python face: `setup` boots the agent, `poll` batches frames, `send` dispatches commands, `stop` shuts down. |
| `tui_shared.jac` | Frame serialization (`_frame_blob`), command handlers (`_dispatch_cmd`), tty probe, env wiring, and **lazy build** of the native host (`_ensure_embed_host`). |
| `ipc_schema.jac` | Wire constants (shared symbolically with the native side). |
| `run_tui_embed.jac` | `run_tui_embed(req)` -- the CLI entry into the embed path. |

## 5. Runtime lifecycle

`host_embed.na.jac` `with entry { _run_embed() }`:

1. **Boot runtimes.** `jac_engine_boot()` (Jac engine) then `jpy_PyRun_SimpleString(_BOOTSTRAP_PY)` imports `embed_agent.{setup,poll,send,stop}` into `__main__`.
2. **Start the agent.** `_agent_setup()` → `embed_agent.setup()` → `ui_configure()` + a daemon thread that subscribes to the agent bus (`ui_stream()`) and pushes each frame onto a `Queue`.
3. **Open the tty.** `tty_open()` → raw mode, non-blocking, saved-termios for restore; the fd is dup2'd up to ≥10 so later stdio rewiring can't clobber it.
4. **Seed state** from env (`JAC_AI_UI_PROJECT/FILES/MODEL_PRESETS`): cwd, project file list (via `git ls-files`), model presets.
5. **Enter screen.** Alt-screen (DEC 1049), hide cursor (DEC 25), enable mouse (DEC 1000/1006), sync size.
6. **Bind the boundary.** Resolve `_agent_poll` and `_agent_send` as Python callables (`PyRun_String` + `PY_EVAL`) and hand them to `EmbedPyTransport.bind_py`.
7. **Run the loop** `while tui_loop_once(rt) { }`.
8. **Tear down** (current `finally` order): `_agent_stop()`, leave the
   alternate screen, unconditionally call `Py_Finalize`, then `tty_close()` to
   restore termios. Callable handles are left to interpreter finalization.

Managed stop only attempts a bounded join of a daemon feed thread. Because
`Py_Finalize` still precedes termios restoration, a live worker race or slow
finalization can delay/prevent full terminal restoration. This is a known Phase
1/3/4 lifecycle defect, not a satisfied contract. The target restores the tty
before cleanup waits and skips finalization unless workers have explicitly
quiesced.

If the real agent can't boot (missing byLLM/deps), `setup` falls back to a
**stub agent** (configurable tick) unless `JAC_AI_TUI_NO_STUB` is set -- so the
binary always renders *something*.

## 6. The main loop

`tui_loop_once(rt) -> bool` runs one ~50 ms tick:

```
poll_gil(50)          # release the GIL (PyEval_SaveThread) so the agent thread
                       #   can run, while we poll the tty for stdin/key readiness
   │
   ├─ process_keys()   # if a key is ready: parse + route (handle_key);
   │                   #   flush resulting commands to Python immediately
   │
   ├─ drain_blobs()    # ONE C-API crossing pulls the whole Python queue into a
   │                   #   local buffer; hand back ≤ _FRAME_DRAIN_CAP (64) frames
   │                   #   this tick; parse each into TuiState. stdin EOF → quit.
   │
   └─ render_once()    # only if state.dirty: screen_render → DiffEngine.paint
```

Two properties matter:

- **GIL release during poll.** The agent runs on the embedded interpreter's
  thread; the native loop explicitly drops the GIL while waiting on the tty so
  the agent makes progress instead of being blocked by an idle poll.
- **Coalesced, backpressured draining.** One `poll()` per tick drains the entire
  queue; the cap bounds work per tick, leftovers stay buffered, and Python is
  not re-polled until the buffer drains. Frame ordering stays strict; a burst
  can't starve input.

## 7. Data flow across the boundary

The boundary carries two streams, both text, both defined by `ipc_schema`.

### 7.1 Agent → TUI (frames)

The agent publishes to an in-process `Queue` via `AgentEventBus`. `embed_agent.poll()`
batches whatever has accumulated into **one counted frame blob**:

```
L:<n>          ← number of body lines that follow (length-prefix framing)
TYPE:full|delta STATUS:idle ACTIVE:<phase> MODEL:<name> NEEDS_KEY:0|1 KEY_ENV:<env>
EV:<id>:<kind>:<node>:<text>      ← a whole event
EVA:<id>:<delta>                  ← a streaming append to event <id>
...                               ← (exactly <n> body lines)
---                               ← FRAME_SEP
```

Native `split_frames` re-segments by the `L:<n>` header -- **robust by
construction**: a body line that happens to equal `---` cannot forge a
boundary, and a stray line desyncs only its own frame. `ipc_parse_frame` then:

- `TYPE:full` → `state.reset_events()` then replay (authoritative snapshot).
- `TYPE:delta` → apply one incremental event.
- `TYPE:hb` → heartbeat, ignore.
- `EV` → upsert event `id` (adopts a pending `-1` user echo if it matches).
- `EVA` → append streaming tokens to event `id` (the hot path for answer/reasoning).

Escaping (`\n`→`\n`, `\`→`\\`, `:`→`\c`) keeps the colon-delimited format safe.

### 7.2 TUI → agent (commands)

`CmdQueue.send(fd, cmd)` emits a single command line. When the Python send
callable is bound, it calls `_agent_send` directly (`PyObject_CallOneArg`),
which dispatches via `_dispatch_cmd`:

| Command | Effect |
|---|---|
| `SEND:<text>` | `ui_send(text)` -- submit a user turn |
| `STOP` | `ui_stop()` -- cancel the running turn |
| `RESET` | `ui_reset()` -- clear the conversation |
| `QUIT` | stop agent + tear down |
| `APPLY:<k=v,k=v>` | `ui_apply_settings(model,n_ctx,api_key,base_url,temperature)` |

## 8. State model

### 8.1 Native `TuiState` (`state.na.jac`)

- **Agent view:** `status` (IDLE/RUNNING/UNKNOWN), `active` phase, `model_name`,
  `needs_key`/`key_env`, `cwd`. This is a known Phase 1 schema defect: managed
  code emits `stopping`, which currently falls back to `UNKNOWN`; do not treat
  that fallback as the intended lifecycle contract.
- **Transcript:** `events: list[Event]` capped at 2000 (`_EVENT_CAP`). Each
  `Event` caches its wrapped `DisplayRow`s, invalidated when text or width
  changes -- re-wrapping only happens on real change.
- **Input:** `editor: EditorState` (multiline, wrap-aware cursor, scroll, a
  `HISTORY_MAX` submit-history ring with draft save/restore on up/down).
- **Viewport:** `viewport_top`, `follow_tail`, `term_rows/cols`,
  `display_rows`, plus `dirty` / `layout_dirty` flags that gate rendering.
- **Overlays & completion:** `overlay_*`, `select_list`, `files`,
  `model_presets`, and `ac: AcState` (inline slash/`@` completion).

Event kinds are a closed enum (`USER, ANSWER, REASONING, SYSTEM, LOGO, ERROR,
PHASE, CALL, TOOL_RESULT, IMG, SEP`); each maps via `kind_style()` to a prefix,
color, attribute set, and `RenderMode` (NORMAL/MARKDOWN/TOOL_CALL/TOOL_RESULT/IMAGE).

### 8.2 Agent `AgentEventBus`

The pub/sub core. `emit(kind, fields)` appends `{id, kind, …}` and publishes
`{…state, "ev": ev}`. `emit_stream(kind, token)` coalesces consecutive tokens
into the last streaming event of that kind and republishes -- this is what makes
token streaming cheap (one event, repeated delta publishes). `subscribe()`
returns a `Queue`; `snapshot()` is the authoritative `full` frame; heartbeats
fire every 10 s of silence to keep the loop awake.

## 9. Rendering pipeline

```
state.dirty? ── no ──► skip (most ticks render nothing)
      │ yes
      ▼
screen_render(state, cols, rows) ──► list[str]   one pre-styled row each
      │   composes: feed rows (build_rows → markdown/tool_block/terminal_image
      │             by RenderMode) + status bar (cwd/model/status) + input editor
      │             + inline autocomplete + overlay modal
      ▼
DiffEngine.paint(lines, cols, fd, paint_buf)
      │   compares to previous frame, emits ONLY changed cells:
      │     cursor-move + clear-line per dirty row, wrapped in
      │     synchronized-output (DEC 2026 begin/end)
      ▼
tty bytes
```

- **Dirty gating.** A tick with no state change writes zero bytes -- the common
  case while idle.
- **Layout vs. paint.** `layout_dirty` triggers re-wrapping of events (width
  change / event add); `dirty` triggers a paint. Overlay transitions and resizes
  call `diff.invalidate()` for a clean full redraw.
- **Styling.** All escapes live in `terminal.na.jac`; `theme.na.jac` precomposes
  the fixed fg/bg/attr combinations as `TH_SGR_*` strings, so the hot path is
  string concat, not per-cell SGR composition.

## 10. Input model

`handle_key` routes in strict priority order:

1. **Overlay open** → `overlay_handle_key` (palette / model / file pickers own the keys).
2. **Autocomplete active** → Tab accepts, ↑/↓ navigate, Esc dismisses.
3. **Ctrl** → `c`/`q` quit, `g` stop, `r` reset, `o` palette, plus emacs line edits (`a`/`e`/`k`/`u`/`w`).
4. **Movement** → arrows/home/end/word, PageUp/Down, mouse scroll. ↑ at the first visual line and ↓ at the last navigate **submit history**.
5. **Edit** → char/insert/backspace/delete/mouse; `Shift-Enter` newline; `Enter` submits.

Submission: `Enter` sends the buffer. A trailing `\` is a line continuation
(insert newline, don't send). Text starting with `/` is a **slash command**
(`/model`, `/files`, `/stop`, `/clear`, `/reset`, `/quit`, `/settings k=v,…`),
resolved through the table-driven `CmdDef` registry. Plain text is echoed
locally as a pending `id=-1` USER event and `SEND`-ed; when the agent's real
event comes back with the same text, the pending echo is **adopted** (id
rewritten) instead of duplicated.

## 11. TTY / FFI layer

`tty/libc_tty_base.na.jac` is the libc boundary:

- **Raw mode** via the cfmakeraw recipe (strip input translation/flow control,
  output post-processing; 8-bit no parity; no echo/canonical/signals), with
  VMIN/VTIME and struct offsets from `tty_plat.{linux,darwin}`.
- **Window size** via `TIOCGWINSZ` (zero-sized reports ignored so the last good
  size sticks).
- **Poll** two `struct pollfd` (stdin + tty), updating readiness flags.
- **Key decode** of single chars, SS3 (`ESC O …`), and CSI (`ESC [ …final`)
  sequences, capped against malformed input.

Convention (load-bearing on the native pathway): **`str` doubles as `char*`**
-- there is no bytes/buffer type in `.na.jac`. `calloc()` returns an `int`
pointer re-typed via an annotated local (`out: str = p;`); every `calloc` is
paired with a `free` on all paths.

## 12. Build & deployment

`build_embed.sh` produces the self-hosting binary in three steps:

1. `nacompile host_embed.na.jac → bin/jac-ai-tui` (with `libjacpyembed` staged
   so `import from jacpyembed` resolves and a `$ORIGIN` runpath is emitted).
2. Stage `libjacpyembed.so` next to the binary so `DT_NEEDED` binds at load.
3. Append the fused `jac` binary's `[payload][trailer]` so `jac_engine_boot()`
   materializes the **same bundled CPython + jaclang** the CLI ships.

`_ensure_embed_host` (in `tui_shared.jac`) makes the current source/development
launch path **lazily self-building**: on first run, or whenever any `.na.jac`
source is newer than the artifact (mtime-gated), it runs `build_embed.sh` under
a `flock` so concurrent launches don't race. `JAC_AI_TUI_REBUILD=1` forces a
rebuild. This is current behavior, not the Phase 7 release contract: a packaged
release must contain a fresh host and adjacent runtime artifacts so startup
performs no compilation or source-tree lookup.

### Payload freshness (dev loop)

The native host does **not** import Python bridge modules from the source tree at
runtime. After `jac_engine_boot()`, it runs the **fused** `[payload][trailer]`
baked into `bin/jac-ai-tui` -- the same bundled CPython + jaclang the CLI ships.
Changes to Python bridge code (`embed_agent.jac`, `agent_session.jac`,
`bridge_schema.jac`, `tui_shared.jac`, etc.) therefore have **no effect** until
that payload is rebuilt and re-appended to the binary.

**Symptom:** the TUI chrome renders (native host is fine) but typed input
produces no agent reply -- e.g. the stub's `echo: …` line never appears in a PTY
smoke run. The native reducer and transport may be correct while the embedded
Python side is still running an older `embed_agent`.

**Dev loop:**

- `JAC_AI_TUI_REBUILD=1 jac ai --tui` -- forces `_ensure_embed_host` to rerun
  `build_embed.sh` (mtime-gated by default).
- `jac/jaclang/cli/ai_tui_na/build_embed.sh` -- rebuild the native host + payload
  directly.
- Full `zig build` in `jac/` -- rebuilds the payload and `libjacpyembed` shim when
  the toolchain is healthy; required before end-to-end PTY smoke passes.

**Regression coverage:** `jac/tests/cli/test_ai_tui_roundtrip.jac` exercises the
embed-agent bridge (`start`/`submit`/`poll`/`snapshot`) without a binary rebuild;
`scripts/ai_tui_pty_smoke.py` covers the full `bin/jac-ai-tui` path and depends
on a fresh payload.

## 13. Key design decisions & constraints

### The crux: an in-process but *marshalled* seam

The native renderer and managed agent share an address space, yet currently
communicate by serializing text frames and command lines across CPython C-API
calls. That remains a valid single-process topology. The debt is the seam's
stringly interface, distributed GIL/reference ownership, and module-global
session lifecycle--not the fact that values are marshalled.

The target direction in `PLAN.md` keeps the seam in-process and marshalled while
making it narrow and typed:

1. keep update coalescing and one paint per UI tick;
2. replace `L:<n>` / positional `key:value` frames with complete typed bridge
   values from one dual-code-space schema;
3. return a synchronous acceptance/rejection receipt for each command, while
   run completion remains an ordered session event;
4. project typed `AgentSessionRuntime` events into a bounded queue and atomic
   snapshots;
5. confine all CPython references, GIL transitions, and finalization to one
   `EmbedRuntime` module;
6. replace module-global adapter state with instance-owned sessions, workers,
   subscriptions, cancellation, and disposal.

The plan deliberately does **not** use zero-copy views of managed mutable
objects, arbitrary native callbacks into live agent state, or a renderer
subprocess. Those approaches can be reconsidered only from measured need and a
separate architecture decision.

### Native-pathway constraints (hard-won, documented in code)

- **`jac fmt` must not run on `.na.jac`** -- it rewrites `x if x else y` into
  `x or y`, which ICEs the native compiler. Commits are made `--no-verify`.
- **Cross-module glob init-order hazard** -- an imported `obj` glob is still
  `None` while another module's glob init runs, so functions called from glob
  initializers must stay literal/glob-free (why `ansi_reset()` returns a literal).
- **Negative repeat corrupts the heap** -- repeat/grow helpers must guard `n <= 0`.
- **`str` as `char*`** -- see §11.

## 14. Glossary

- **Host** -- the native binary (`bin/jac-ai-tui`); entry `host_embed.na.jac`.
- **Frame** -- one agent→TUI message (full snapshot, delta, or heartbeat).
- **Event** -- one transcript item (user/answer/reasoning/tool/…), identified by id.
- **Bus** -- the agent's in-process pub/sub (`AgentEventBus`).
- **Transport** -- in the current pre-Phase-4 implementation, the native object
  that performs C-API crossings (`EmbedPyTransport`); target ownership moves to
  `EmbedRuntime` and `EmbedSessionClient`.
- **Dirty/layout-dirty** -- flags gating whether a tick re-wraps and/or re-paints.
- **Sync update** -- DEC private mode 2026; withholds terminal paint until a
  frame is complete (no tearing).
