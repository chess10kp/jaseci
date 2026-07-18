# Phase 0 event-trace fixtures

These traces freeze **current** fused-host semantics before Phase 1–2 rewrites.
They are derived from source paths (`embed_agent`, `ai_agent.ui_*`, native
`ipc`/`input`) plus stub PTY runs. Authoritative runtime captures belong under
`results/` (gitignored) after `python3 plans/phase0/pty/harness.py --scenario boot_prompt_stub`.

## Canonical happy path (target after Phase 1+)

```text
boot -> snapshot(idle)
  -> submit(prompt) -> CommandReceipt(accepted)
  -> authoritative user message (host id >= 0)
  -> thinking/text/tool updates
  -> assistant message_end
  -> agent_end
  -> agent_settled
  -> quit (tty restored before dispose wait)
```

## Current (pre-Phase-1) observed semantics

### Prompt submit

```text
Enter
  -> editor.submit() clears text
  -> upsert_event(id=-1, USER, text)          # optimistic native row
  -> queue SEND:<text>
  -> flush -> embed_agent.send -> ui_send
       ui_send False if running/stopping (bool only logged)
       ui_send True  -> emit user + status=running + turn worker
  -> later EV with real id adopts id=-1 row if text matches
```

Gaps vs plan: acceptance not returned; optimistic row; busy rejection can leave
cleared editor with no row or a stale `-1` row depending on timing.

### Stop

```text
/stop or CMD_STOP
  -> ui_stop
  -> if running: cancel_requested, status=stopping, system "Stopping…"
  -> native parse_tui_status("stopping") -> UNKNOWN   # bug
```

### Settlement

There is no distinct `agent_settled` wire event yet. Turn completion sets
`status=idle` via the turn worker finally path. Phase 2 introduces typed
`agent_end` / `agent_settled`.

## Fixture checklist (capture when running stub/real)

| Trace id | Trigger | Assert |
|---|---|---|
| `T-boot` | host start | full frame, status idle, system/logo |
| `T-user` | prompt | one user EV after acceptance (Phase 1: no -1) |
| `T-stream` | answer/reasoning | EVA appends in order |
| `T-tool` | tool call | call + tool_result kinds |
| `T-stop` | /stop while running | status stopping then idle |
| `T-busy` | submit while running | no new user row |
| `T-reset` | /reset | events cleared; host reset |
| `T-quit` | /quit | process exit; tty restored |

Wire kinds today (from `parse_event_kind`): `user`, `answer`, `reasoning`,
`system`, `logo`, `error`, `phase`, `call`/`tool`, `tool_result`, `img`.
Status is out-of-band via `STATUS:` field.
