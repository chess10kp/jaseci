# Plan 4 -- Python SDK for programmatic use

**Status:** proposal · **Layer:** python (`ai_agent.jac`) · **Effort:** M · **Depends on:** 3
**Unblocks:** 6 (extensions instantiate sessions), 9 (sub-agents = nested SDK sessions)
**Benchmark:** pi `createAgentSession(options) -> { session, ... }` as the single embeddable entry backing CLI/RPC/print/subagents; dependency-injected defaults; re-exports `ToolDefinition`/`defineTool`/tool factories (`coding-agent/src/core/sdk.ts:167`, `docs/sdk.md`).

## 1. Goal

Expose the agent as an **embeddable API** so people can drive it from their own Python/Jac code
(scripts, tests, other tools, sub-agents) instead of only through `jac ai`/the TUI. Today the only
programmatic seam is the `ui_*` module functions, which are TUI-shaped (frame dicts, global singleton).

## 2. Current state

`ai_agent.jac`:

- A **module-global singleton** drives everything: `glob agent: AgentRuntime = AgentRuntime()` (line 192),
  `glob agent_model = build_model()` (line 216). `run_phase`/`run_turn`/`run_agent` operate on this singleton.
- The programmatic surface is the `ui_*` set (lines 497-521): `ui_configure`, `ui_send(prompt)->bool`,
  `ui_stream()->any` (frame generator), `ui_stop`, `ui_reset`, `ui_apply_settings(...)`, `ui_poll`,
  `ui_graph`, `ui_call_detail`, `ui_phase_context`, `ui_settings`. These are consumed by
  `tui_shared._CMD_HANDLERS` and `embed_agent`.
- `AgentSession` walker (line 480) is the actual "session" but is constructed internally by `run_turn`;
  there's no clean external constructor, no injection of cwd/model/tools, and state is global.

**Problem:** one global agent; can't run two sessions in one process (blocks Plan 9 sub-agents),
can't embed without the TUI frame protocol, config is env-var driven (`_configure_ui_env`).

## 3. Reference design

- **pi**: `createAgentSession(options?)` returns `{ session, extensionsResult, ... }`. Everything is
  DI with defaults (`AuthStorage.create`, `ModelRegistry.create`, `SessionManager.create(cwd)`), so the
  same factory backs CLI, RPC, print, and in-process sub-agents. Embedders subscribe to
  `AgentSessionEvent` and call `session.sendUserMessage`. The SDK module re-exports the public types
  (`ToolDefinition`, `defineTool`, tool factories, `withFileMutationQueue`).

## 4. Target design

Introduce a **`createAgentSession()`-style factory returning a session object**, and refactor the
global singleton into a default instance of it. The `ui_*` functions become thin adapters over the
same object (no behavior change for the TUI).

```
obj AgentSessionOptions {
    has cwd: str = "",
        model: str = "",
        n_ctx: int = 0,
        temperature: float | None = None,
        api_key: str = "", base_url: str = "",
        tools: list[str] = [],           # allowlist by name; [] = defaults
        exclude_tools: list[str] = [],
        custom_tools: list = [],          # Plan 6 ToolSpec-likes
        yolo_mode: bool = True,
        session_id: str = "",             # Plan 3: resume; "" = new
        store: SessionStore | None = None;
}

obj Agent {                               # the embeddable handle (wraps AgentRuntime + model)
    has rt: AgentRuntime, model: Model, store: SessionStore, bus: AgentEventBus;

    def send(prompt: str) -> bool;                 # enqueue a turn (async, non-blocking) -- like ui_send
    def run(prompt: str) -> TurnResult;            # blocking: run a full turn, return result+stats
    def stream -> any;                             # iterator of AgentEvent (Plan 8 typed) -- like ui_stream
    def stop; def reset;
    def apply_settings(...) -> ApplySettingsResult;
    def resume(session_id: str); def fork(at_id: str) -> Agent;   # Plan 3
    def subagent(opts: AgentSessionOptions) -> Agent;            # Plan 9
}

def create_agent_session(opts: AgentSessionOptions = AgentSessionOptions()) -> Agent;
```

- **Decouple from the global**: `create_agent_session` builds its own `AgentRuntime`, `Model`
  (`build_model(opts.model, opts.n_ctx)`), `AgentEventBus`, `SessionStore` (Plan 3). The existing
  `glob agent` becomes `glob _default_agent = create_agent_session(_opts_from_env())` -- a lazily-built
  default so the TUI path is unchanged.
- **`ui_*` become adapters**: `ui_send(p)` → `_default_agent.send(p)`; `ui_stream()` →
  `_default_agent.stream()`; `ui_configure()` → build `_default_agent` from `_configure_ui_env`'s values.
  The TUI (`tui_shared`, `embed_agent`) keeps calling `ui_*` -- zero native change.
- **Two output modes** mirror pi: `stream()` (event iterator, what the TUI uses) and `run()` (blocking,
  returns a `TurnResult{text, stats, changed_files, session_id}` -- what a script wants). Both drive the
  same `AgentSession` walker.
- **Tools injection**: `opts.tools`/`custom_tools` filter/extend `TOOL_SPECS` (line 349) per session
  rather than the current module-global list -- prerequisite for Plan 6 and for restricted sub-agents (Plan 9).

## 5. File-by-file changes

- **`ai_agent.jac`** -- add `AgentSessionOptions`, `Agent`, `create_agent_session`; make
  `AgentRuntime`/`AgentEventBus`/model/store instance-scoped; convert `glob agent` to a default `Agent`;
  rewrite `ui_*` as adapters; parameterize `TOOL_SPECS` selection into a per-session `build_tools(opts)`.
- **New (optional)** `jac/jaclang/cli/agent_sdk.jac` -- a thin public re-export module
  (`create_agent_session`, `AgentSessionOptions`, `Agent`, `ToolSpec`, `TurnResult`) so embedders import
  one stable surface, not the internals.
- **`session_store.jac`** (Plan 3) -- injected via `opts.store`.
- **Docs** `docs/` -- an SDK usage page (mirror pi `docs/sdk.md`): "5-line embed" example.

## 6. Phased implementation

1. **Instance-scope the runtime** -- thread an `Agent` object through `run_turn`/`run_phase` instead of
   the global; keep `glob _default_agent` so nothing external breaks. Highest-risk refactor; do behind tests.
2. **`create_agent_session` + `run()`** -- public factory, blocking one-shot path, `TurnResult`.
3. **`ui_*` as adapters** -- prove the TUI works unchanged against the default agent.
4. **Per-session tools** -- `build_tools(opts)`; enables Plan 6/9.

## 7. Constraints & risks

- Python layer -- no NA constraints. The main risk is the **global→instance refactor**: `run_phase` is a
  `by agent_model(...)` byLLM function bound to `glob agent_model` and reads `agent.phase_tools`/`phase_ctx`
  (lines 288-299). Making the model/tools per-instance means either (a) keeping `run_phase` reading a
  thread-local "current agent" set at turn start, or (b) passing context explicitly. byLLM's `by`-binding
  to a module glob is the sticky part -- verify byLLM supports per-call model/tools (it takes `tools=`,
  `conversation=` args already, so likely (a): set `agent.phase_tools`/`phase_ctx` from the active `Agent`
  before each `run_phase`). Confirm with a byLLM spike before committing to full instance isolation.
- Thread-safety: multiple `Agent`s in one process (Plan 9) share the CPython GIL but need separate buses,
  stores, and byLLM conversations -- ensure no residual module-global mutable state leaks between them.
- Keep `ui_*` byte-compatible so the mtime-gated embed host doesn't need a rebuild for the SDK work.

## 8. Testing / verification

- Unit: `create_agent_session(opts).run("say hi")` against a stub/echo model returns a `TurnResult`;
  two concurrent sessions don't cross-contaminate events.
- Regression: full TUI drive (stub agent) unchanged after `ui_*` become adapters.
- Example script in `docs/` runs headless end-to-end.

## 9. Out of scope / follow-ups

- RPC/print run-modes (pi has them) -- a JSONL stdin/stdout mode could reuse `Agent.stream()`; defer.
- Auth/model-registry abstraction (pi `AuthStorage`/`ModelRegistry`) -- current `build_model` + env is
  enough; revisit if multi-provider management grows.
