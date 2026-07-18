# Plan 6 -- Extension / staged-tool model

**Status:** proposal · **Layer:** python (`ai_agent.jac`) + native custom-UI seam · **Effort:** L · **Depends on:** 4, 1, 2
**Benchmark:** pi `ExtensionFactory = (pi: ExtensionAPI) => void` with `registerTool/registerCommand/registerShortcut/on(event)`, `ToolDefinition{parameters, execute, renderCall?, renderResult?}`, `ctx.ui.custom(factory, {overlay})` (`coding-agent/src/core/extensions/types.ts`); opencode scoped/stacked tool registry with schema-validated in/out (`tool/registry.ts:39`) + task tool as extension.

## 1. Goal

Let users **register custom tools** (and, later, custom UI) without editing core, mirroring pi's
`registerTool`/`ctx.ui.custom`. Today tools are a fixed module-global list and there is no plugin surface.

## 2. Current state

`ai_agent.jac`:

- `glob TOOL_SPECS: list[ToolSpec]` (line 349) -- a **hardcoded list** of `ToolSpec{fn, category: ToolCat,
  serialize, phases: set[type]}` (line 204). Tools are methods on `agent.files/proc/semantic/guides/web`.
- Phase-gating: each `ToolSpec.phases` limits which of `Plan/Build/QA` may call it. `PhaseState.tools()`
  filters `TOOL_SPECS` by phase. Write/Run tools tracked in `_WRITE_TOOLS`/`_RUN_TOOLS`.
- `mark_serialize` (line 4, from `byllm.parallel`) marks tools that must not run in parallel.
- No registration API, no user hooks, no per-tool custom rendering. The native TUI renders tool calls
  generically (`tool_block.na.jac`, `RenderMode.TOOL_CALL/TOOL_RESULT`).

**Problem:** extending the agent means editing `TOOL_SPECS` and the tool classes. No third-party tools,
no custom event hooks, no interactive tool UI.

## 3. Reference design

- **pi**: an extension is `(pi: ExtensionAPI) => void`. `ExtensionAPI` = `on(event, handler)` (typed per
  event), `registerTool(def)`, `registerCommand`, `registerShortcut`, `registerMessageRenderer`,
  `registerProvider`, plus actions (`sendMessage`, `setModel`, `setActiveTools`, `events`).
  `ToolDefinition` carries a TypeBox `parameters` schema, `execute(id, params, signal, onUpdate, ctx)`,
  `executionMode: "sequential"|"parallel"`, and optional `renderCall/renderResult` returning `Component`s.
  Interactive UI via `ctx.ui.custom(factory, {overlay, overlayOptions, onHandle})` mounting a focus-capturing
  component; each run-mode supplies its own `ExtensionUIContext` so it degrades gracefully.
- **opencode**: schema-first registry -- `register(tools)` is **scoped and stacked** (newest wins, auto-
  removed on scope close), input decoded + output re-validated against schemas. Sub-agents/MCP/plan-mode
  are all built as extensions, not core.

## 4. Target design

The **registry and execution are pure Python-Jac** (dynamic dispatch is legal here -- `tui_shared` already
uses a `dict[str, fn]`). The **only native touch** is a `CUSTOM` overlay content type (Plan 2) fed by IPC.

### 4a. Registration API (Python)

```
obj ToolDefinition {
    has name: str, description: str,
        parameters: dict,                 # JSON-schema dict (byLLM already builds schemas from signatures)
        category: ToolCat = ToolCat.Read,
        phases: set[type] = set(),        # {Plan, Build, QA}; empty = all
        serialize: bool = False,
        execute: any = None,              # fn(params: dict, ctx: ToolCtx) -> str
        render_call: any = None,          # optional: fn(args) -> list[str] (native overlay/inline lines)
        render_result: any = None;
}

obj ExtensionAPI {
    def register_tool(t: ToolDefinition);
    def register_command(name: str, handler: any, help: str = "");   # slash commands
    def on(event: str, handler: any);                                 # Plan 8 event hooks
    def set_model(name: str); def send_message(text: str);
    # ctx.ui:
    def ui_select(title: str, items: list) -> any;                    # → native SELECT_LIST overlay
    def ui_confirm(msg: str) -> bool;                                 # → native CONFIRM overlay
    def ui_custom(lines: list[str], on_key: any) -> any;             # → native CUSTOM overlay (Plan 2)
}

# an extension is a function: def my_ext(pi: ExtensionAPI) { pi.register_tool(...); pi.on("turn_end", ...); }
```

- **Registry** on the `Agent` (Plan 4): `Agent.extensions: list`, `Agent.tool_registry: dict[str, ToolDefinition]`.
  `build_tools(opts)` (Plan 4) merges built-in `TOOL_SPECS` + registered tools, honoring opencode's
  **newest-wins** override and per-session allow/exclude lists.
- **Discovery/loading**: extensions are Jac/Python modules under a known dir (e.g. `~/.jac/ai-extensions/`
  or declared in `jac.toml`), each exposing a factory `def register(pi: ExtensionAPI)`. Loaded at
  `create_agent_session` time (Plan 4). A `LoadExtensionsResult` reports failures without crashing boot
  (mirror pi).
- **Event hooks** (Plan 8): `pi.on("tool_call"|"turn_start"|"turn_end"|"session_before_compact"|...)` --
  the `AgentEventBus` gains a subscriber list keyed by event type; hooks run synchronously in the feed thread.
- **Execution**: registered tools flow through the same byLLM tool path. byLLM builds schemas from callable
  signatures today; for `ToolDefinition.execute` we pass the callable + explicit `parameters` schema. Respect
  `serialize` via `mark_serialize`.

### 4b. Custom tool UI (native seam)

- **Inline result rendering**: `render_call`/`render_result` return **pre-formatted lines** (strings), shipped
  over IPC as a new `E.render:<id>:<escaped-lines>` field (Plan 8 forward-compat). The native `feed`/`tool_block`
  renders them verbatim instead of the generic tool block. (No native code executes user logic -- it only
  displays lines the Python side produced. This respects the "no native dynamic dispatch" rule.)
- **Interactive UI**: `ctx.ui_custom(lines, on_key)` opens a Plan 2 `CUSTOM` overlay: Python ships the overlay
  lines; the native overlay captures keys and sends them back over a new `CMD_UIKEY` command; Python's `on_key`
  decides and either updates the overlay (new lines) or closes it with a result. This is a request/response
  loop over the existing IPC -- the native side stays a dumb renderer + key forwarder.

## 5. File-by-file changes

- **New** `jac/jaclang/cli/agent_extensions.jac` -- `ToolDefinition`, `ExtensionAPI`, `load_extensions(dir) -> LoadExtensionsResult`, registry merge/override logic.
- **`ai_agent.jac`** -- `Agent` holds registry + extensions (Plan 4); `build_tools` merges; `AgentEventBus`
  gains typed subscriber dispatch; `TOOL_SPECS` becomes the built-in baseline.
- **`tui_shared.jac`** -- `_CMD_HANDLERS` gains `CMD_UIKEY`; frame builder emits `E.render`/custom-overlay frames.
- **`ipc_schema.*` (Plan 8)** -- `E.render` field, `CMD_UIKEY`, custom-overlay frame type.
- **`overlay.na.jac` (Plan 2)** -- `OverlayContent.CUSTOM` renders shipped lines + forwards keys.
- **`feed.na.jac` / `tool_block.na.jac`** -- honor `E.render` lines for a tool call/result.

## 6. Phased implementation

1. **Programmatic tool registration** -- `ToolDefinition` + `register_tool` + registry merge; no UI, no
   loading-from-disk. Register one example tool in-process, confirm the model can call it.
2. **Extension loading + event hooks** -- `load_extensions(dir)`, `pi.on(event)`; a sample extension file.
3. **Custom inline rendering** -- `render_result` → `E.render` lines in the native feed.
4. **Interactive `ctx.ui_custom`** -- Plan 2 `CUSTOM` overlay + `CMD_UIKEY` round-trip. (Highest complexity.)

## 7. Constraints & risks

- **Keep all extension logic in Python.** Native must never call user code -- it only renders lines and
  forwards keystrokes. This is the crux that keeps NA's no-dynamic-dispatch rule intact while still offering
  "custom UI."
- **Security**: loading arbitrary user modules executes arbitrary code. Gate behind an explicit opt-in
  (`jac.toml` `[ai.extensions] enabled=true` or a flag), document the trust model, and never auto-load from
  a project dir without consent (supply-chain risk).
- **byLLM schema binding**: confirm byLLM accepts a tool given as (callable + explicit JSON-schema dict)
  rather than only introspected signatures -- spike before step 1. If it only introspects signatures, wrap
  `execute` in a generated function with a typed signature.
- Failure isolation: a bad extension must not crash the agent (mirror pi's `LoadExtensionsResult`); wrap
  load + each hook in try/except that emits an `error` event.
- Depends on Plan 4 (per-session tools) and, for UI, Plans 1/2 (component + overlay stack).

## 8. Testing / verification

- Unit: register a tool, run a turn where the model calls it (stub model that emits a tool call), assert
  `execute` ran and the result appears as an event.
- Extension-load test: a good and a deliberately-broken extension file; boot succeeds, broken one reported.
- Live: an example `/hello` command + a tool with `render_result`; a `ctx.ui_confirm` round-trip through
  the native overlay.

## 9. Out of scope / follow-ups

- MCP client tools (opencode has an MCP crate) -- could layer on top of the same registry later.
- `registerProvider` (custom LLM providers) -- defer to a byLLM concern.
- Full component-tree custom UI (pi returns `Component`s) -- the line-shipping model is the NA-appropriate
  substitute; revisit only if a real interactive widget is needed.
