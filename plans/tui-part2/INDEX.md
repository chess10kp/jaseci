# Part 2 -- Feature / Architecture Improvement Plans

Detailed implementation plans for the `jac ai --tui` stack, benchmarked against
the reference implementations in `reference/` (**pi**, **opencode**, **opentui**,
**toad**, **claurst**).

These are **planning documents only**. No code is changed by adopting this folder.

## The two layers (every plan lives in one or both)

| Layer | Where | Language | Nature |
|---|---|---|---|
| **Native TUI frontend** | `jac/jaclang/cli/ai_tui_na/*.na.jac` | native Jac (`.na.jac`, compiled to a machine-code binary `bin/jac-ai-tui`) | render loop, input, overlays, theme, wire-protocol parsing |
| **Python agent host** | `jac/jaclang/cli/ai_tui/*.jac` + `jac/jaclang/cli/ai_agent.jac` | Python-flavored Jac (CPython, embedded in the binary) | agent state machine, byLLM, sessions, tools, retry |

The two communicate over a **line-oriented text IPC** (`ipc_schema` / `tui_shared._frame_blob`):
frames flow agent→TUI (`poll`), commands flow TUI→agent (`send`).

## The single most important constraint (read before any plan)

**Native Jac resolves every call statically -- no vtables, no virtual dispatch,
no generic higher-order functions, no `dict[Key, fn]` dispatch tables.**
(See memory: *native no indirect calls*.) The existing code already lives within
this constraint using two idioms, and every native-side plan below MUST reuse one
of them rather than reaching for polymorphism:

1. **Tagged-union + enum dispatch** -- one `obj` with a `kind: SomeEnum` field and a
   hand-written `if self.kind == X { ... }` chain. Precedent: `CmdDef{kind: CmdKind}.execute()`,
   `OverlayKind` switch in `overlay_handle_key`, `kind_style(kind)` `match`.
2. **Single concrete inheritance, bound at the call site to the concrete type** -- the
   only place inheritance is used is `Transport → TtyFdTransport → EmbedPyTransport`, and
   `TuiRuntime.transport` is typed as the concrete `EmbedPyTransport` so the hot path is a
   static call. A base class with default bodies works *only* if callers hold the concrete type.

Anything needing true dynamic dispatch (arbitrary user-registered tools/renderers)
must be pushed **into the embedded Python layer** (`tui_shared.jac` already uses a
`dict[str, fn]` `_CMD_HANDLERS` -- that is legal because it is CPython, not native).

Other standing NA gotchas that recur in these plans (from prior work / memory):

- No docstrings in `.na.jac` function bodies (`E0002`) -- use `#` comments. Core `.na.jac` is comment-stripped by CI lint; keep comments out of shipped core.
- `chr()`+concat drops NUL bytes; `len()` on a `calloc`'d buffer is `strlen`. Keep binary work out of these text paths.
- Method call on a `T | None` receiver is silently dropped -- rebind to a plain-typed local first.
- External `obj.field` writes on derived/nested objects miss the 8-byte header -- mutate shared structs **through methods**, keep zero-copy reads read-only.
- Build with `.venv/bin/python -m jaclang`; the global `jac` is stale. Embed host rebuild is mtime-gated (`_ensure_embed_host`) and can take minutes; SIGKILL mid-compile cools the jir cache (14–32s boots).

## Plans

| # | Plan | Layer | Effort | Depends on |
|---|---|---|---|---|
| 1 | [Component abstraction](01-component-abstraction.md) | native | L | -- |
| 2 | [Extensible overlay system](02-overlay-system.md) | native | M | 1, 7 |
| 3 | [Session persistence (JSONL tree)](03-session-persistence.md) | python | M | -- |
| 4 | [Python SDK](04-python-sdk.md) | python | M | 3 |
| 5 | [Theme system](05-theme-system.md) | native (+ipc) | M | -- |
| 6 | [Extension / staged-tool model](06-extension-tool-model.md) | python (+native custom UI) | L | 4, 1, 2 |
| 7 | [Input routing to focused component](07-input-routing.md) | native | M | 1 |
| 8 | [Typed event system](08-typed-event-system.md) | ipc (both) | M | -- |
| 9 | [Sub-agent / workflow support](09-subagents-workflows.md) | python | L | 3, 4, 8 |
| 10 | [Retry / compaction hooks](10-retry-compaction.md) | python | M | 3, 8 |

## Recommended sequencing

```
Phase A (foundations, parallelizable):
  8  Typed event system      ← unblocks 6, 9, 10 (clean event contract)
  5  Theme system            ← independent, quick win
  3  Session persistence     ← unblocks 4, 9, 10

Phase B (native UI refactor, ordered):
  1  Component abstraction    ← the render() split; everything UI sits on it
  7  Input routing            ← focus stack; needs 1
  2  Overlay system           ← anchor/stack/focus; needs 1 + 7

Phase C (agent capabilities):
  4  Python SDK               ← needs 3
  10 Retry / compaction       ← needs 3 + 8
  9  Sub-agents / workflows    ← needs 3 + 4 + 8
  6  Extension / tool model    ← needs 4 + (native) 1 + 2
```

Phase A items are low-risk and independently shippable. Phase B is one coherent
native refactor (do 1→7→2 in a single arc; they share the component contract).
Phase C is agent-side and can proceed once 3/4/8 land.

## Benchmark cheat-sheet (what to steal from where)

- **opentui** -- component model: `BaseRenderable`/`Renderable` split, `render()/renderSelf()/onUpdate()`, `markDirty()` + coalesced `requestRender()`, cached absolute coords, focused-node key subscription with `stopPropagation/preventDefault`.
- **pi** -- the closest whole-app blueprint: `Component{render(width)/handleInput/invalidate}`, anchor+`%` overlay stack with `preFocus` restore, JSONL session tree, `createAgentSession()` SDK, semantic theme tokens → precomputed ANSI, `registerTool`/`ctx.ui.custom`, discriminated `AssistantMessageEvent`, compaction `session_before_compact` hook with `customInstructions`.
- **opencode** -- data-model rigor: `parentID` session branching + append-only `seq` event log, `Schema.toTaggedUnion` message/event parts with Started/Delta/Ended streaming, `resolveTheme()` with `{dark,light}` pairs + cycle detection, task-delegation as a permission-narrowed child session, scoped/stacked tool registry.
- **claurst** -- pure overlay geometry helpers (`centered_rect`, `ModalLayout`, `render_dark_overlay`) worth mirroring for native overlay math.
