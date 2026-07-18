# Plan 9 -- Sub-agent / workflow support

**Status:** proposal · **Layer:** python (`ai_agent.jac`) · **Effort:** L · **Depends on:** 3, 4, 8
**Benchmark:** opencode task tool = spawn a **permission-narrowed child session** via `sessions.create({parentID, agent})`, foreground `raceFirst` / background `start` + `inject()` synthetic result, recursion-guarded (`packages/opencode/src/tool/task.ts`); pi sub-agents as an extension: a tool's `execute()` calls `createAgentSession()` with a restricted toolset, `executionMode: "parallel"|"sequential"` for fan-out vs chain.

## 1. Goal

Let the agent **delegate work to sub-agents** -- parallel fan-out, sequential chains, and async
background tasks -- for multi-step coding work, instead of one linear `Plan→Build→QA` walker.

## 2. Current state

`ai_agent.jac`:

- Single linear phase machine: `AgentSession` walker (line 480) traverses `Plan→Build→QA→Done` nodes
  (lines 322-347) via `Flow` edges; `run_phase` (line 288) is one `by agent_model(...)` call per phase.
- `byllm.parallel` is imported (`mark_serialize`, line 4) and `run_phase` sets `parallelize=True`
  (line 297) -- so **parallel *tool* calls within a turn** already work, but there is no parallel *agent*.
- `AgentEventBus.convos: dict[int, list]` + `_cur_convo`/`_convo_seq` track conversation turns; the `node`
  field on every event already namespaces output by phase/tool -- a natural sub-agent label carrier.
- No child-session concept, no delegation tool, no orchestration primitive.

**Problem:** complex tasks are handled by one context; no isolation, no parallelism across independent
subtasks, no async "go do X while I continue."

## 3. Reference design

- **opencode task tool**: `execute` resolves `agent.get(subagent_type)`, calls
  `sessions.create({parentID: ctx.sessionID, agent, permission})` (child of the current session -- reuses
  the Plan 3 `parentID` tree), **narrows permissions** (`deriveSubagentSessionPermission`) and auto-denies
  `task`/`todowrite` to prevent infinite recursion, then either foregrounds
  (`Effect.raceFirst(wait, waitForPromotion)`, wires abort) or backgrounds (`start` + later `inject()`
  posts a synthetic message into the parent). Agents have `mode: "subagent"|"primary"|"all"`; subagents are
  hidden from the user picker.
- **pi**: same idea as an extension -- the tool's `execute()` spins a nested `createAgentSession()` with a
  restricted `tools`/`noTools` allowlist and its own model, drives it to completion, returns the transcript.
  Parallel/chain/async are expressed via `executionMode` + N concurrent tool calls.

## 4. Target design

Build on Plan 4's `Agent.subagent(opts)` and Plan 3's session tree. A sub-agent is a **child `Agent`
with a child session and a narrowed toolset**, invoked as a **tool** the model can call.

```
# a built-in tool (registered like any other, Plan 6)
def task(description: str, prompt: str, agent_type: str = "general",
         background: bool = False) -> str;
```

- **Spawn**: `task(...)` calls `parent.subagent(AgentSessionOptions(
    cwd=parent.cwd, model=parent.model_name,
    tools=_subagent_tools(agent_type),          # narrowed allowlist
    exclude_tools=["task"],                      # RECURSION GUARD (mirror opencode)
    session_id="",                               # new child session
  ))`; the child session is created with `parent_session = parent.session.id` (Plan 3 `fork`/child link),
  giving a persisted delegation tree.
- **Agent types**: a small registry `AGENT_TYPES: dict[str, AgentTypeDef]` with `{tools, phases, system_prompt}` --
  e.g. `"explore"` (read-only tools, no Build/QA), `"build"` (full), `"review"` (read + check). Mirrors
  opencode's `mode: subagent` agents; these are also the natural place for Plan 6 extensions to register new
  agent types.
- **Foreground (chain / blocking)**: `task(background=False)` runs the child turn to completion
  (`child.run(prompt)` from Plan 4) and returns the child's final text as the tool result. Multiple
  `task(...)` calls in one model step run in **parallel** because tool calls already parallelize
  (`run_phase parallelize=True`) -- that gives fan-out for free. Chain = sequential tool calls.
- **Background (async)**: `task(background=True)` starts the child on its own thread, returns immediately
  with a handle envelope (opencode's `<task id=... state="running">`), and on completion **injects** a
  synthetic `system`/`answer` event into the parent bus (Plan 8 event with a `node="subagent:<id>"` label)
  so the parent turn or a later turn can consume it.
- **Events & UI**: sub-agent output is namespaced by the existing `node` field (`subagent:<id>`) -- the native
  feed can group/indent it (small `feed.na.jac` tweak, optional). A Plan 2 overlay could show a live
  sub-agent task list. No new native machinery is required for the core feature.
- **Cancellation**: parent `stop()` cancels children (thread stop-events, mirror the existing `_stop: Event`
  pattern in `embed_agent`).

## 5. File-by-file changes

- **`ai_agent.jac`** -- `AgentTypeDef` + `AGENT_TYPES` registry; the `task` tool + its `ToolSpec`; wire
  `Agent.subagent` (Plan 4) to create child sessions with narrowed tools + recursion guard; background
  thread runner + `inject` into the parent bus.
- **`agent_sdk.jac`** (Plan 4) -- expose `subagent`/agent-type registration for extensions (Plan 6).
- **`session_store.jac`** (Plan 3) -- child sessions carry `parent_session`; `list_sessions` can show the tree.
- **`feed.na.jac` (native, optional)** -- indent/group events whose `node` starts with `subagent:`.
- **`ipc`/Plan 8** -- no new fields strictly needed (reuse `node`); optionally a `task_state` field for the
  live task list overlay.

## 6. Phased implementation

1. **Foreground `task` tool** -- synchronous child `Agent.run` with a narrowed read-only `"explore"` type;
   returns transcript. Recursion guard (`exclude task`). Verify the model can delegate a sub-question.
2. **Agent-type registry + fan-out** -- multiple types; confirm N parallel `task(...)` calls fan out.
3. **Background tasks** -- thread runner + `inject` synthetic result; handle envelope; cancellation on stop.
4. **UI polish (optional)** -- native sub-agent grouping + a task-list overlay (Plan 2).

## 7. Constraints & risks

- **Recursion / runaway cost** is the top risk -- a sub-agent spawning sub-agents can explode token spend.
  Enforce: `exclude_tools=["task"]` for children (like opencode), a max delegation depth, and a per-turn
  sub-agent budget/count cap. Surface spend in the status line (Plan 8 usage events).
- **Depends heavily on Plan 4's global→instance refactor** -- you cannot run two agents in one process until
  `create_agent_session` truly isolates bus/model/store/byLLM-conversation. The byLLM `by agent_model`
  module-glob binding (see Plan 4 §7) is the key spike: confirm a child turn can run with its own
  model/tools/conversation without clobbering the parent's `run_phase` context. If byLLM can't isolate,
  fall back to running sub-agents in a **separate process** (opencode `orchestrator` model) over the
  existing IPC -- heavier but sidesteps shared-glob issues.
- **Thread-safety**: parent + background children share the GIL and the same bus if not careful; each child
  gets its own `AgentEventBus`, and `inject` into the parent bus must take the parent's `_lock`.
- **Determinism/logging**: persist each sub-agent as a child session (Plan 3) so delegated work is auditable.

## 8. Testing / verification

- Unit: `task("explore", "list the walkers")` against a stub model returns child output; child cannot call
  `task` (recursion guard verified).
- Fan-out: two `task` calls in one step complete concurrently; results both returned.
- Background: `task(background=True)` returns immediately; a synthetic result event arrives later; parent
  `stop()` cancels a running child.
- Isolation: parent and child event streams don't interleave incorrectly (namespaced by `node`).

## 9. Out of scope / follow-ups

- Multi-process supervisor (opencode `orchestrator`, spawns full instances) -- only if in-process isolation
  proves insufficient; the IPC + SDK make it a natural later extension.
- A DAG/workflow DSL (declarative multi-step pipelines) -- start with imperative `task` calls; formalize
  later if patterns recur.
