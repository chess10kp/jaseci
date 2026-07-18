# Phase 0 -- Baseline inventory

Captured: 2026-07-14
Host: Linux x86_64
Scope: `PLAN.md` Phase 0 / `plans/SCOPE.md` §3.1

## Pre-existing dirty tree (do not reset)

Recorded at Phase 0 start. Treat as user work, not Phase scaffolding.

| Path | Status |
|---|---|
| `jac/jaclang/cli/ai_tui/embed_agent.jac` | modified (thread join + `_thread` tracking) |
| `jac/jaclang/cli/ai_tui_na/host_embed.na.jac` | modified (leave-screen before finalize) |
| `jac/jaclang/cli/ai_tui_na/transport.na.jac` | modified (poll/GIL path hardening) |
| `jac/jaclang/cli/ai_tui_na/tui_loop.na.jac` | modified (flush before quit flag) |
| `jac/tests/cli/test_ai_tui_bridge.jac` | modified (no late `close_py`) |
| `DESIGN.md`, `IDIOMATIC-JAC.md`, `PLAN.md`, `plans/` | untracked / planning |
| `.pi-subagents/` | untracked |

## Launch identity

```text
jac ai --tui
  → run_tui_embed(req)
  → _ensure_embed_host(...)   # may bash build_embed.sh if missing/stale
  → os.execve(ai_tui_na/bin/jac-ai-tui, [host], env)
  → host_embed._run_embed()   # one OS process: native TUI + embedded CPython
```

| Artifact | Path | Notes |
|---|---|---|
| Native host | `jac/jaclang/cli/ai_tui_na/bin/jac-ai-tui` | gitignored `bin/` |
| Embed shim | `jac/jaclang/cli/ai_tui_na/bin/libjacpyembed.so` | staged beside host |
| Build script | `jac/jaclang/cli/ai_tui_na/build_embed.sh` | `jac nacompile` + trailer |
| Shim source build | `cd jac && zig build` / `zig build pyembed` | |

### Host/shim identity at capture

| File | mtime | size | sha256 (16) |
|---|---|---|---|
| `bin/jac-ai-tui` | 2026-07-14 04:36:32 -0400 | 126153645 | `6d3f2a2a4d86a9f1` |
| `bin/libjacpyembed.so` | 2026-07-14 04:45:40 -0400 | 11333901 | `10eef26d0631f228` |

### Rebuild commands

```bash
cd /home/jac/repos/jac-ai-tui/jac && zig build
bash jac/jaclang/cli/ai_tui_na/build_embed.sh
```

Force lazy rebuild: `JAC_AI_TUI_REBUILD=1 jac ai --tui …`

### Stub / seams

| Env | Role |
|---|---|
| *(byLLM boot failure)* | stub agent (`embed_agent._start_stub`) |
| `JAC_AI_TUI_NO_STUB` | re-raise instead of stub |
| `JAC_AI_TUI_BYLLM_SRC` / `JAC_AI_TUI_DEPS` | real agent path |
| `JAC_AI_TUI_DEBUG_LOG` | redacted debug sink |
| `JAC_AI_TUI_TTY` | tty override (default `/dev/tty`) |

No dedicated fake-provider flag yet (Phase target).

## Topology check

Idle product path after `execve`: **one** long-lived `jac-ai-tui` process containing one embedded CPython. No renderer child. Tool subprocesses are user-requested and out of scope for idle topology.

## Related Phase 0 artifacts

| Artifact | Path |
|---|---|
| Embed ownership inventory | `plans/phase0/inventory/embed_ownership.md` |
| PTY harness | `plans/phase0/pty/harness.py` |
| Event traces | `plans/phase0/traces/` |
| Width classification | `plans/phase0/width/` |
| Perf method | `plans/phase0/perf/BASELINE.md` |
| D1/D2/E1 probes | `plans/probes/PROBES.md` |
