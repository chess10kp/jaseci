# Plan 3 -- Session persistence (JSONL tree, branching)

**Status:** proposal · **Layer:** python (`ai_agent.jac`) · **Effort:** M · **Depends on:** --
**Unblocks:** 4 (SDK loads/continues sessions), 9 (sub-agents = child sessions), 10 (compaction writes summary entries)
**Benchmark:** pi append-only JSONL tree -- header line + `SessionEntry{id, parentId, timestamp}` variants, `getBranch()`/`branch()`/`forkFrom()` (`coding-agent/src/core/session-manager.ts`); opencode `parentID` branching + append-only `seq` event log + JSON `revert` checkpoint (`session/schema.ts`, `sql.ts`).

## 1. Goal

Persist conversations across runs with a **branching tree** model so users can resume, rewind,
and fork. Today a session lives only in the in-memory root graph and the TUI's `state.events`
(capped ring buffer); quitting loses everything.

## 2. Current state

`ai_agent.jac`:

- `AgentRuntime.active_session: AgentSession | None` (line 176); `AgentSession` is a **walker**
  (line 480) with `objective`, `ledger`, `stats`, `steps`; it traverses a `Plan→Build→QA→Done`
  node graph (the phase state machine).
- `AgentEventBus` (line 130) holds `events: list[dict]` (cap 4000), `convos: dict[int, list]`,
  `convo_tools: dict[int, list]`, `_cur_convo`, `_convo_seq` -- conversation turns exist in memory only.
- `BrowseTools.session_id = "jac-ai"` (line 73) is a browser session id, unrelated.
- `reset_session` (line 253) clears state. `Ledger` (line 262) holds `changes`/`notes` (the agent's
  working memory across phases) -- also in-memory.
- **Persistence today**: only the Jac root graph persists automatically (a language feature), and the
  editor input history (`EditorState.history`, ≤100, in-memory on the native side). No conversation
  transcript is written to disk.

**Problem:** no resume, no history browser, no branching/rewind, no fork. `/reset` is destructive.

## 3. Reference design

- **pi**: one JSONL file per session under a sessions dir. Line 1 = `SessionHeader{version,id,cwd,parentSession?}`.
  Each next line = a `SessionEntry` with `parentId` (uuidv7, time-sortable) → a tree. `leafId` selects the
  active branch. `getBranch(fromId?)` walks parent pointers leaf→root, reverses → the linear LLM context.
  `branch(id)` just repoints `leafId` (non-destructive rewind). `forkFrom()` writes a new file copying
  entries to the fork point. Entry variants include `message`, `compaction{summary,firstKeptEntryId}`,
  `branch_summary`, `model_change`, `custom`.
- **opencode**: same idea in SQLite -- `parent_id` column + `seq` append-only message log + a `revert`
  JSON checkpoint for rewind. Event-sourced reconstruction via a projector.

## 4. Target design

Adopt pi's **append-only JSONL tree** (simplest, matches the file-oriented CLI; SQLite is overkill here).

```
# ~/.jac/ai-sessions/<project-hash>/<session-id>.jsonl
# line 1: header
{ "type":"session", "v":1, "id":"ses_...", "ts":..., "cwd":"/abs", "parent_session":null, "model":"..." }
# subsequent lines: entries, each with a tree pointer
{ "type":"message", "id":"...", "parent_id":"...", "ts":..., "role":"user|assistant|tool", "content":... }
{ "type":"phase",   "id":"...", "parent_id":"...", "phase":"Build", ... }        # Plan/Build/QA transitions
{ "type":"note",    "id":"...", "parent_id":"...", "text":... }                  # Ledger notes
{ "type":"compaction","id":"...","parent_id":"...","summary":...,"first_kept":"..." }  # Plan 10
{ "type":"branch_summary","id":"...","parent_id":"...","from_id":"...","summary":... }
```

- **`SessionStore` obj** (new, `ai_agent.jac` or a new `session_store.jac`):
  - `create(cwd, model) -> SessionInfo` -- new file + header; id = monotonic (time-sortable) string.
  - `append(entry: dict)` -- set `entry.parent_id = self.leaf_id`, `appendFileSync`, advance `leaf_id`.
  - `load(session_id) -> None` -- read file, build `by_id: dict`, set `leaf_id` = last line.
  - `branch(from_id)` -- repoint `leaf_id` (non-destructive). `branch_with_summary(from_id, text)`.
  - `fork_from(session_id, at_id) -> SessionInfo` -- new file, copy entries up to `at_id`, `parent_session` set.
  - `active_branch() -> list[dict]` -- walk `parent_id` leaf→root, reverse (the linear turn list).
  - `build_context() -> list[msg]` -- active branch → LLM messages, honoring compaction cut points.
  - `list_sessions(cwd) -> list[SessionInfo]`, `latest(cwd)`.
- **Wiring into the agent**: `run_turn` appends a `user` message entry on submit and `assistant`/`tool`
  entries as the turn completes (drive off the Plan 8 typed events -- each `AgentEvent` maps to an entry).
  `Ledger.remember`/`record` also append `note`/`phase` entries. `reset_session` starts a new session file
  instead of wiping (old file remains -- non-destructive, matches pi).
- **Continuation/branch as commands** (surfaces via Plan 2 overlays + Plan 6): `/resume` opens a
  session picker (list `list_sessions`), `/rewind` branches from a chosen entry, `/fork` forks.
- The **TUI** learns nothing new structurally -- on resume, the host replays the active branch as a
  `full` frame (existing `FTYPE_FULL` path already does `state.reset_events()` + repopulate). This is why
  Plan 3 needs no native change beyond possibly a `/resume` command entry.

## 5. File-by-file changes

- **New** `jac/jaclang/cli/session_store.jac` -- `SessionInfo`, `SessionStore` (above). Pure Python-Jac,
  `json` + `os` + `appendFileSync`-equivalent (`open(path,"a")`).
- **`ai_agent.jac`** -- `AgentRuntime` gains `store: SessionStore`; `run_turn`/`reset_session`/`Ledger`
  append entries; `ui_configure` loads latest-or-new; add `ui_resume(id)`, `ui_list_sessions`, `ui_fork(...)`.
- **`tui_shared.jac`** -- new command handlers `_cmd_resume`/`_cmd_fork` in `_CMD_HANDLERS`; the resume
  picker's item list flows to the native overlay (like `file_items`/`model_items` do today).
- **`commands.na.jac` (native)** -- add `/resume`, `/rewind`, `/fork` palette entries that emit the new CMDs.

## 6. Phased implementation

1. **Write-only persistence** -- `SessionStore.create/append`; log user+assistant+tool+note entries every
   turn. No resume yet. Verify files look right; zero behavior change to a running session.
2. **Resume latest** -- `ui_configure` loads the latest session for the cwd and replays it as a `full`
   frame on boot; `/reset` = new session. Add `--continue`/`--session <id>` CLI flags.
3. **Branch/rewind/fork** -- `branch`, `branch_with_summary`, `fork_from`; `/resume` picker, `/rewind`.
4. **Context builder honors compaction** -- `build_context` cut points (co-develop with Plan 10).

## 7. Constraints & risks

- This is the **Python layer** -- full dynamic dispatch, `dict`, `json`, threads available. None of the
  native NA constraints apply. Keep it out of `.na.jac`.
- **Concurrency**: the agent runs on a daemon `_feed` thread (`embed_agent._feed`); appends must be
  serialized (the bus already has a `_lock: any`). Use append-only writes (atomic per line) and flush.
- **Graph-root interaction**: Jac's root graph already persists; decide whether the JSONL is the source
  of truth (recommend yes for the transcript) while the graph holds only live walker state. Avoid double
  bookkeeping -- don't persist walker nodes to JSONL, only messages/notes/phases.
- **Disk growth / privacy**: cap or prune old sessions; sessions may contain code + secrets -- store under
  `~/.jac/ai-sessions` with user-only perms; document and offer a disable flag.
- Id scheme must be time-sortable without `Date.now()` concerns (that's a native-only restriction; Python
  `time.time()` is fine here).

## 8. Testing / verification

- Unit (pytest, `.venv/bin/pytest`): create → append N entries → `active_branch` order; `branch` from a
  mid entry then append → new leaf path excludes the abandoned tail but file still contains it; `fork_from`
  produces an independent file with `parent_session` set.
- Integration: run a stub turn, quit, `--continue`, assert the transcript replays as a `full` frame.
- Property: `build_context(active_branch)` reconstructs the same message list a live turn would have.

## 9. Out of scope / follow-ups

- SQLite/event-sourcing (opencode) -- only if multi-writer or query needs arise.
- Cross-machine sync -- out of scope.
- Session titles/labels auto-generated by the LLM -- nice-to-have after resume lands.
