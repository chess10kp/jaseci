#!/usr/bin/env bash
# lane-keeper.sh — keep every worker lane topped up with PORTING work, live.
#
# Problem it solves: family lanes (objects/exceptions/typesys/census) get no new
# work once seed-backlog's static list + farm gaps are exhausted, so workers go
# idle while the real porting backlog (600-port-* CPython module lifts) sits in
# the mech lane where only worker4 can reach it. This keeper runs the live
# generator each tick and rebalances so no lane drops below a low-watermark —
# continuous top-up instead of drain-then-scramble.
#
# Each tick:
#   1. port-backlog.sh  — regenerate port-module (mech) + convert-suite (converter)
#      tasks from the CPython reference tree vs what's already ported (idempotent;
#      a module stops being generated once jacpython/<mod>.jac exists).
#   2. seed-backlog.sh / gapq-bridge.sh — idempotent; catch farm gaps if the farm
#      revives.
#   3. Rebalance: 600-port-* tasks are independent module lifts (own file, no
#      cross-worker conflict), so spread mech's surplus across any family lane
#      below LOW, up to HIGH, keeping a mech floor for worker4.
#
# When the module backlog is genuinely exhausted the generator emits nothing and
# lanes dry legitimately (porting actually done) — that is the real terminal
# state, not a stall.
#
# Usage:  ops/lane-keeper.sh            (foreground; run under tmux)
#         DRY_RUN=1 ops/lane-keeper.sh  (log planned moves, don't move)
set -uo pipefail
cd "$(dirname "$0")"
OPS="$(pwd)"
Q="${QROOT:-/home/jac/.local/state/jacq}/lanes"
INTERVAL="${INTERVAL:-90}"
LOW="${LOW:-4}"          # refill a lane when it drops to/below this
HIGH="${HIGH:-12}"       # refill it up to this
MECH_FLOOR="${MECH_FLOOR:-6}"   # always leave worker4 this many in mech
FAMILY_LANES=(objects exceptions typesys census converter)
DRY_RUN="${DRY_RUN:-0}"
LOG="${LOG:-$OPS/logs/lane-keeper.log}"

say() { echo "[$(date -u +%FT%TZ)] $*" | tee -a "$LOG"; }
depth() { find "$Q/$1/pending" -maxdepth 1 -name '*.task' 2>/dev/null | wc -l | tr -d ' '; }

say "lane-keeper start (interval=${INTERVAL}s low=$LOW high=$HIGH mech_floor=$MECH_FLOOR dry_run=$DRY_RUN)"
while :; do
  # 1+2: regenerate porting backlog + idempotent seeds (quiet)
  bash "$OPS/port-backlog.sh"  >>"$LOG" 2>&1 || true
  bash "$OPS/seed-backlog.sh"  >/dev/null 2>&1 || true
  bash "$OPS/gapq-bridge.sh"   >/dev/null 2>&1 || true

  # 3: rebalance mech surplus into starving family lanes
  for L in "${FAMILY_LANES[@]}"; do
    d=$(depth "$L")
    if [ "$d" -le "$LOW" ]; then
      need=$(( HIGH - d ))
      moved=0
      # pull independent port-module tasks from mech, respecting the mech floor
      for f in $(ls "$Q/mech/pending/"600-port-*.task 2>/dev/null | sort); do
        [ "$moved" -ge "$need" ] && break
        mdepth=$(depth mech)
        [ "$mdepth" -le "$MECH_FLOOR" ] && break
        if [ "$DRY_RUN" = "1" ]; then
          say "would move $(basename "$f") -> $L"
        else
          mv "$f" "$Q/$L/pending/" 2>/dev/null && moved=$((moved+1))
        fi
      done
      [ "$moved" -gt 0 ] && say "topped up $L: $d -> $(depth "$L") (+$moved from mech)"
    fi
  done

  # visibility line: current depths
  say "depths: $(for L in objects exceptions typesys census mech converter; do printf '%s=%s ' "$L" "$(depth "$L")"; done)"
  sleep "$INTERVAL"
done
