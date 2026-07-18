# Plan 10 -- Retry / compaction hooks

**Status:** proposal · **Layer:** python (`ai_agent.jac`) · **Effort:** M · **Depends on:** 3, 8
**Benchmark:** pi pure `shouldCompact/prepareCompaction/compact` + driver with exponential-backoff `auto_retry_start/end`, overflow-vs-threshold auto-compaction, `session_before_compact` hook with mutable `customInstructions` and cancel/replace (`coding-agent/src/core/compaction/compaction.ts`, `core/agent-session.ts`); opencode `SessionContextEpochTable` baseline + `time_compacting`.

## 1. Goal

Add real **context management**: automatic + manual conversation compaction (summarize old turns
when the context window fills), retryable-error auto-retry with backoff, and extension hook points --
replacing the current crude fixed limits.

## 2. Current state

`ai_agent.jac`:

- **Retry-ish**: `verify_and_continue(max_rounds: int = 3)` (line 493) loops QA verification;
  `glob _REWRITE_LIMIT = 5` (line 256); `run_phase` sets `max_react_iterations=60` and
  `on_iteration=_progress_guard` (line 259/298). `AgentSession.max_steps = 16`. There is **no
  error-retry with backoff** -- a provider error surfaces as an `error` event (`embed_agent._feed`
  emits id=-100 on exception) and the turn ends.
- **No compaction**: context is `AgentEventBus.convos: dict[int, list]` + `phase_ctx` (line 186), capped
  only by event count (`_cap=4000`). When the model's context window overflows, the request just fails --
  no summarize-and-continue. `max_tool_result_length=4000`/`max_tokens=8192` (lines 298-299) are the only
  guards.
- No `n_ctx`-aware budgeting beyond passing `n_ctx` to `build_model`.

**Problem:** long sessions hit context limits and fail; transient provider errors abort turns; no way for
users/extensions to steer what gets kept.

## 3. Reference design

- **pi compaction** (pure logic): `shouldCompact(contextTokens, contextWindow, settings)`,
  `prepareCompaction(entries) -> {messagesToSummarize, kept, cutPoint, previousSummary}`,
  `compact(...)` → `generateSummary(..., customInstructions)`. Driver auto-triggers on **overflow**
  (`isContextOverflow` → compact-then-retry once, guarded) and on **threshold** (`shouldCompact`).
  Compaction emits `compaction_start/end` with `reason: manual|threshold|overflow` and `willRetry`.
- **pi retry**: on `agent_end`, checks `getRetrySettings()` + `isRetryableError`, schedules
  exponential-backoff retry emitting `auto_retry_start/end` with `attempt/maxAttempts/delayMs`.
- **pi hooks**: `session_before_compact` fires with `preparation`, `reason`, `willRetry`, mutable
  `customInstructions`; handler may `cancel` or fully `replace` the summary. `ctx.compact({customInstructions})`
  triggers it imperatively. Extension-made compactions are marked `fromHook`.

## 4. Target design

Two pure modules (retry policy, compaction) + driver wiring in the turn loop, all Python. Persist
compaction as a Plan 3 session entry; emit Plan 8 typed events; expose Plan 6 hooks.

### 4a. Retry

```
obj RetrySettings { has enabled: bool = True, max_retries: int = 3, base_delay_ms: int = 1000; }
def is_retryable(err: Exception) -> bool;         # rate-limit / 5xx / timeout / connection
def retry_delay(attempt: int, s: RetrySettings) -> int;   # exponential backoff w/ jitter
```

- Wrap the `run_phase`/turn call: on a retryable error, emit `auto_retry_start{attempt,max,delay_ms}`
  (Plan 8), sleep, retry up to `max_retries`, then `auto_retry_end{ok}` or surface the `error` event.
  Non-retryable → straight to error (today's behavior).
- Surfaced in the TUI status line via the typed event (native shows "retrying (2/3)…" in `ACTIVE`).

### 4b. Compaction

```
obj CompactionSettings { has keep_recent_tokens: int = 20000, threshold_ratio: float = 0.8; }
obj CompactionPrep { has to_summarize: list, kept: list, cut_id: str, prev_summary: str; }

def should_compact(context_tokens: int, context_window: int, s: CompactionSettings) -> bool;
def prepare_compaction(branch: list, s: CompactionSettings) -> CompactionPrep;   # turn-aligned cut point
def compact(prep: CompactionPrep, custom_instructions: str) -> CompactionResult by agent_model(...);
```

- `generate_summary` is a `by agent_model(...)` byLLM call (the summary prompt + `custom_instructions`
  appended, pi-style). Returns a summary that **replaces** `to_summarize` in the context; `kept` stays verbatim.
- **Auto-trigger** in the turn driver:
  - **Overflow** (provider says context exceeded, or estimated tokens > window): compact then **retry the
    turn once** (guarded by a `overflow_recovered` flag so it can't loop). `reason="overflow"`, `willRetry=True`.
  - **Threshold** (`should_compact(estimated, n_ctx)`): compact proactively after a turn. `reason="threshold"`.
- **Manual**: a `/compact` command (native → `CMD_COMPACT`) triggers `reason="manual"`.
- **Persistence** (Plan 3): a `compaction` entry `{summary, first_kept: cut_id}` is appended to the session;
  `build_context` (Plan 3 §4) starts from the latest compaction summary + entries after `cut_id`. This is
  the clean interplay: compaction is just another tree entry, and resume respects it.
- **Token estimation**: reuse byLLM/tokenizer usage already tracked (`TurnRenderer._format_tokens`,
  `AgentEventBus.last_stats`); `n_ctx` from `AgentConfig`. Prefer real usage from the last response over
  estimation where available.

### 4c. Hooks (Plan 6)

- `session_before_compact` event fires with `CompactionPrep`, `reason`, `willRetry`, and a **mutable**
  `custom_instructions`; a handler may set `cancel=True` or supply a replacement summary. Emitted through
  the Plan 6 `pi.on(...)` subscriber dispatch. `ctx.compact({custom_instructions})` triggers imperatively.
  Extension-driven compactions marked `from_hook=True` on the entry.

## 5. File-by-file changes

- **New** `jac/jaclang/cli/agent_compaction.jac` -- `CompactionSettings`, `CompactionPrep`, `should_compact`,
  `prepare_compaction`, `compact`/`generate_summary` (byLLM), `RetrySettings`, `is_retryable`, `retry_delay`.
- **`ai_agent.jac`** -- turn driver (`run_turn`/`run_agent`) wraps calls with retry + auto-compaction; add
  `AgentConfig` fields for settings; `/compact` handling; emit `auto_retry_*` / `compaction_*` events;
  fire `session_before_compact` hook.
- **`session_store.jac` (Plan 3)** -- `compaction` entry type; `build_context` honors compaction cut points.
- **`ipc_schema.*` / Plan 8** -- `auto_retry`/`compaction` event kinds (or reuse `system`/`phase` with a
  structured `E.*` field); `CMD_COMPACT` command.
- **`commands.na.jac` (native)** -- `/compact` palette entry; status line shows retry/compaction state
  (reuse `ACTIVE`/`STATUS`, no new native rendering needed).

## 6. Phased implementation

1. **Auto-retry** -- `RetrySettings`/`is_retryable`/backoff around the turn call; `auto_retry_*` events;
   status-line feedback. Independent of compaction; ship first (removes the "transient error kills the turn"
   failure). Verify with an injected rate-limit error.
2. **Manual `/compact`** -- pure `prepare_compaction` + `generate_summary`; replace context; persist a
   compaction entry (needs Plan 3). Verify context shrinks and the conversation stays coherent.
3. **Threshold auto-compaction** -- `should_compact` after each turn using real token usage.
4. **Overflow recovery** -- detect context-overflow errors, compact-then-retry-once (guarded).
5. **Hooks** -- `session_before_compact` + `ctx.compact` (needs Plan 6).

## 7. Constraints & risks

- Python layer -- no NA constraints. Retry (step 1) is genuinely standalone and low-risk; do it first.
- **Compaction correctness**: the cut point must be **turn-aligned** (never split a tool-call/tool-result
  pair, never drop the system prompt or the current objective/`Ledger`). `prepare_compaction` must respect
  the `Plan/Build/QA` structure -- keep the active `Ledger` notes verbatim (they're the agent's durable
  memory) and only summarize completed conversation turns.
- **Token accounting**: estimation errors cause either premature compaction (lossy) or overflow (failure).
  Prefer provider-reported usage; keep `keep_recent_tokens` conservative. Make thresholds configurable.
- **byLLM summary call** happens mid-turn -- ensure it doesn't recurse into retry/compaction itself
  (guard flags), and that its own tokens are budgeted.
- **Interplay with Plan 3 resume**: `build_context` must reconstruct from the latest compaction, or a resumed
  long session re-overflows immediately. Co-develop steps 2-4 with Plan 3 §4's context builder.
- **Interplay with Plan 9**: sub-agent child sessions get their own compaction independently.

## 8. Testing / verification

- Unit: `is_retryable` classification table; `retry_delay` backoff monotonic + jittered; `prepare_compaction`
  never splits a tool pair and always keeps the objective/ledger; cut point is turn-aligned.
- Injected-error test: a stub model that raises a rate-limit once → turn retries and succeeds, `auto_retry_*`
  events emitted.
- Compaction: build a long branch exceeding a small `n_ctx`, run `/compact`, assert context tokens drop and
  the summary entry persists; resume respects it (Plan 3).
- Overflow: stub model raises context-overflow once → compact-then-retry recovers; guard prevents a second loop.

## 9. Out of scope / follow-ups

- Tree-navigation summaries (pi `session_before_tree`) -- pairs with Plan 3 branching; defer.
- Epoch/baseline snapshots (opencode `SessionContextEpochTable`) -- an optimization for incremental context;
  the JSONL + compaction-entry model is sufficient initially.
- Semantic/importance-based retention (keep "important" turns) -- start with recency + turn-alignment.
