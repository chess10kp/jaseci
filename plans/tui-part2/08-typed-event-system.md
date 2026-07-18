# Plan 8 -- Typed event system

**Status:** proposal · **Layer:** IPC (both sides) · **Effort:** M · **Depends on:** --
**Unblocks:** 6, 9, 10 (they need a clean, extensible event contract)
**Benchmark:** pi `AssistantMessageEvent` discriminated union with Started/Delta/Ended + `partial`/`contentIndex` (`ai/src/types.ts:459`), wrapped as `message_update` (`extensions/types.ts:735`); opencode `Schema.toTaggedUnion("type")` with Durable vs Ephemeral split and a `Delta`/`Ended` replay contract (`session/event.ts:505`, `message.ts:178`).

## 1. Goal

Replace the stringly-typed event dicts with **typed, discriminated events** end-to-end, and
make the wire protocol carry structured event kinds instead of ad-hoc `kind` strings +
positional `EV:id:kind:node:text`. Today both sides re-parse loose strings and the set of
event kinds is duplicated in three places with no shared contract.

## 2. Current state

- **Python agent** (`ai_agent.jac` `AgentEventBus`): `emit(kind: str, fields: dict)` (line 151) --
  fully string-keyed dicts; `events: list[dict]`. `ui_stream()` yields frame dicts.
- **Wire** (`tui_shared.jac` `_frame_blob`, line 97): flattens to lines
  `TYPE:full|delta|hb`, `STATUS`, `ACTIVE`, `MODEL`, `NEEDS_KEY`, `KEY_ENV`, and per-event
  `EV:<id>:<kind>:<node>:<text>` or delta `EVA:<id>:<delta>`. Text escaped with `\n`/`\\`/`\c`.
- **Native** (`ipc.na.jac`): `parse_event_kind(s: str) -> EventKind` (line 20) -- a 12-arm `if`
  chain mapping `"user"/"answer"/…` to `enum EventKind`. `ipc_apply_line` switches on `FIELD_*`.
- **Kind sets are triplicated**: Python emits arbitrary strings; `parse_event_kind` whitelists 11;
  `EventKind` enum has 12 arms; `RenderMode` maps kinds to render styles in `state.kind_style`.

**Problem:** no single source of truth for event types; a new event kind means editing the
Python emitter, the string→enum parser, the enum, and `kind_style`. Positional `EV:` fields
can't carry structured payloads (tool args, token usage, sub-agent id) without more ad-hoc `:`-packing.

## 3. Reference design

- **pi**: streaming is a `type`-tagged union -- `text_start/text_delta/text_end`,
  `thinking_*`, `toolcall_*`, each carrying `contentIndex` and the accumulating `partial`
  message, so a consumer rebuilds state incrementally. App layer wraps as `message_update`.
- **opencode**: every part/event is a `Schema.Class` unified by `toTaggedUnion(discriminant)`;
  events split **Durable** (persisted, replayable -- the `Ended` full value) vs **Ephemeral**
  (live `Delta` only). This Started/Delta/Ended triple is the clean streaming contract to copy.

## 4. Target design

Two coordinated changes: a **typed event model** on each side, and a **self-describing,
key-based wire frame** so new fields don't break old parsers.

### 4a. Native typed events (`ai_tui_na`)

Formalize the existing `EventKind` as the discriminant and add a structured `Event` payload
that the renderer already half-has (`RenderMode`). This is mostly consolidation:

- Keep `enum EventKind` as the single native discriminant. Add a `phase: str`/`node: str`,
  `stream_state: enum StreamState { START, DELTA, END }` to `obj Event` so streaming is explicit
  rather than inferred from `EVA` vs `EV`.
- Centralize kind metadata: `kind_style(kind)` already is the "table computed by branch." Extend it
  to be the *only* place kind→(prefix,color,mode) lives; delete the parallel `parse_event_kind`
  string map by generating it from a single `enum EventKind` name table (`kind_from_wire(tag: int)`).

### 4b. Wire protocol v2 (`ipc_schema` both sides)

Move from positional `EV:id:kind:node:text` to **tagged key=value events** with an integer kind
so the native side never string-matches, and unknown keys are skipped forward-compatibly:

```
TYPE:full|delta|hb
...header fields...
E:<id>:<kind_int>:<stream_int>            # event envelope
E.node:<id>:<escaped>                     # optional structured fields, keyed by id
E.text:<id>:<escaped>
E.phase:<id>:<escaped>
E.usage:<id>:<prompt>,<completion>        # example structured payload (tool tokens)
---
```

- `kind_int` is `EventKind`'s backing value -- **shared enum, one source of truth**. Emit a
  generated `KIND_NAME[str]->int` table on the Python side from the same list.
- `ipc_apply_line` dispatches on the `E`/`E.<field>` prefix; unknown `E.<field>` keys are ignored
  (forward compat -- this is what lets Plans 6/9/10 add fields without a native rebuild).
- Keep `hb`/`full`/`delta` framing and the `\n`/`\\`/`\c` escaping.

### 4c. Python typed events (`ai_agent.jac`)

Introduce a small tagged event obj hierarchy to replace `emit(kind: str, fields: dict)`:

```
enum EvKind { USER, ANSWER, REASONING, SYSTEM, LOGO, ERROR, PHASE, CALL, TOOL_RESULT, IMG, SEP }
obj AgentEvent { has id: int; kind: EvKind; node: str = ""; text: str = ""; phase: str = ""; }
obj CallEvent(AgentEvent) { has tool: str = ""; args: str = ""; usage: dict = {}; }
```

`AgentEventBus.emit_typed(ev: AgentEvent)` serializes via a single `_frame_blob` that knows how to
lay a typed event onto wire v2. `emit(kind,fields)` becomes a thin shim during migration.

## 5. File-by-file changes

- **`ipc_schema.jac` + `ipc_schema.na.jac`** -- add `E`/`E.*` field constants, `StreamState` ints,
  a shared `EVENT_KINDS` ordered list (so both sides agree on `kind_int`).
- **`tui_shared.jac`** `_frame_blob`/`_ev_line` -- emit wire v2 (`E:` envelope + `E.text:` etc.).
- **`ai_agent.jac`** -- `AgentEvent`/`CallEvent` objs; `AgentEventBus.emit_typed`; migrate the ~dozen
  `emit(...)` call sites (kept behind a shim first).
- **`ipc.na.jac`** -- replace `_parse_ev_val`/`_parse_eva_val` with `E`/`E.*` handlers; `kind_from_wire(int)`
  replaces `parse_event_kind(str)`.
- **`state.na.jac`** -- `Event` gains `phase`, `stream_state`; `upsert_event`/`append_to_event` take the
  structured envelope.

## 6. Phased implementation

1. **Consolidate native kind tables** -- one enum-derived `kind_from_wire`, delete the string map.
   No wire change yet. Pure cleanup, low risk.
2. **Wire v2 (additive)** -- emit `E`/`E.*` alongside legacy `EV`/`EVA` for one transition; native
   prefers `E` when present. Then drop legacy.
3. **Python typed events** -- `AgentEvent` objs + `emit_typed`; migrate call sites; remove `emit` shim.
4. **Structured payloads** -- carry tool args / token usage / phase as `E.*` fields (feeds Plan 10's
   compaction UI and Plan 9's sub-agent namespacing).

## 7. NA constraints & risks

- No polymorphic event list on the native side -- `Event` stays one struct with a `kind` discriminant
  (payload fields nullable/empty when unused), exactly as today. `CallEvent`-style subclassing lives
  only in Python.
- Integer kind on the wire avoids native string-matching entirely (perf + simplicity).
- **Compatibility risk**: the embed host binary and the Python agent are versioned together (the host
  imports `ai_agent` in-process), so wire v1→v2 doesn't need cross-version support -- but the mtime-gated
  rebuild (`_ensure_embed_host`) means a stale binary against new Python emits mismatched frames. Bump a
  `PROTO_VERSION` field in the `full` frame and have the native side warn/fallback if it mismatches.
- Forward-compat (skip unknown `E.<field>`) is the property that lets Plans 6/9/10 avoid native rebuilds.

## 8. Testing / verification

- Round-trip test (Python): build each `AgentEvent`, run through `_frame_blob`, parse back on a
  native `TuiState` (via a test harness), assert the reconstructed event equals the source.
- Golden wire-format snapshots for `full`/`delta`/`hb` frames.
- Live: stream an answer with reasoning + a tool call; verify transcript styling unchanged and token
  usage now available for the status/stats line.

## 9. Out of scope / follow-ups

- A binary/length-prefixed protocol (protobuf-style) -- the text protocol is debuggable and adequate;
  revisit only if event volume becomes a bottleneck.
- Persisting the event log is Plan 3 (session persistence); this plan only types the live stream.
