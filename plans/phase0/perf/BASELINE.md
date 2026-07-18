# Phase 0 performance baseline method

Measure **before** adapter/UI refactors change costs. Record numbers in
`results/` (gitignored) with host sha from `BASELINE.md`.

## Metrics

| Metric | How |
|---|---|
| Startup | time from `execve` to first paint (debug log stamp or PTY first bytes) |
| p50/p95 key→paint | instrument `tui_loop_once` / render path under local key flood |
| Streaming Hz | paints with new frames under synthetic EVA burst |
| Idle CPU | `top`/`pidstat` after settle, 30s window |
| RSS | `ps`/`/proc/<pid>/status` VmRSS after settle and after 10‑min stream |
| Queue depth | max `_q.qsize()` under burst (debug) |

## Initial gates (from PLAN §12; not yet enforced)

- p95 key→paint ≤ baseline + 10 ms
- streaming ≥ 20 Hz when updates available
- drain ≤ 64 frames/tick (already `_FRAME_DRAIN_CAP`)
- idle CPU regression ≤ +1 pp
- RSS: one process (no second runtime)

## Reproduce stub startup sample

```bash
/usr/bin/time -f 'elapsed=%e rss_kb=%M' \
  python3 plans/phase0/pty/harness.py --scenario boot_quit --deadline 20
```

Fill `results/perf-<date>.json` manually after a representative run on a quiet
machine. Phase 0 exit requires a reproducible method and at least one sample;
absolute budgets are reviewed at Phase 7.

## Phase 5 poll profile (2026-07-15)

Short pass on `call_poll` / batch / snapshot-on-tick (see
`plans/probes/_probe_poll_profile.jac`):

| Knob | Current | Verdict |
|---|---|---|
| `_FRAME_DRAIN_CAP` | 64 | Keep -- matches PLAN drain bound |
| `transport.poll_gil` wake | 50 ms | Keep -- no measured idle CPU blame |
| Snapshot | only when `apply_batch` sets `need_snap` | Keep -- not every tick |

No production knob changes. Re-measure under stub stream before Phase 7 budget
review if jank is still reported.
