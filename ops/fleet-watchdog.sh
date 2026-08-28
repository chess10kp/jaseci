#!/usr/bin/env bash
# fleet-watchdog.sh — the thing that watches the watcher.
#
# The supervisor respawns workers + desk, but NOTHING respawned the supervisor:
# when it died (ENOSPC spike, a failing warm under set -e, OOM) the whole fleet
# went dark with no recovery. This closes that gap. It is deliberately tiny and
# dependency-light so it cannot itself wedge, and it is safe to run from cron
# every couple of minutes (idempotent; a flock stops overlap).
#
# Responsibilities (in order):
#   1. Keep disk clear      — run tmp-janitor; if /tmp is critically full, purge
#                             hard so a build spike can't ENOSPC-kill the fleet.
#   2. Keep supervisor up   — if `fleet-supervisor.sh start` isn't running,
#                             relaunch it in tmux `pi-sup` (WARM_CACHE=0 so the
#                             warm can never abort start()). The supervisor then
#                             brings workers + desk back (both liveness-checked).
#
# Install (runs every 2 min):
#   ( crontab -l 2>/dev/null | grep -v fleet-watchdog; \
#     echo "*/2 * * * * cd $HOME/repos/jac-python/ops && ./fleet-watchdog.sh >> logs/watchdog.log 2>&1" ) | crontab -
set -uo pipefail
cd "$(dirname "$0")"
OPS="$(pwd)"
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

LOCK="/tmp/fleet-watchdog.lock"
exec 9>>"$LOCK"; flock -n 9 || exit 0     # another watchdog tick is running; skip
ts() { date -u +%FT%TZ; }

# 1) disk hygiene — never let /tmp fill and kill the fleet.
TMP_PCT="$(df --output=pcent /tmp 2>/dev/null | tail -1 | tr -dc 0-9)"; TMP_PCT="${TMP_PCT:-0}"
bash "$OPS/tmp-janitor.sh" >/dev/null 2>&1 || true
if (( TMP_PCT >= 90 )); then
  echo "[$(ts)] /tmp at ${TMP_PCT}% — HARD purge of stale scratch"
  # merged-worktree reclaim already tried; now drop old non-worktree scratch hard.
  find /tmp -maxdepth 1 -mindepth 1 \( -name 'jac-cache-*' -o -name 'broken-rt-*' \
      -o -name 'tmp.*' -o -name '*-fix' -o -name '*-run' -o -name 'prfix-*' \
      -o -name 'pi-bash-*.log' -o -name 'wt-*' \) -mmin +20 -exec rm -rf {} + 2>/dev/null || true
fi

# 2) supervisor liveness — relaunch if down.
if pgrep -f 'fleet-supervisor.sh start' >/dev/null 2>&1; then
  exit 0
fi
echo "[$(ts)] supervisor DOWN — relaunching"
tmux kill-session -t pi-sup 2>/dev/null || true
# reap stale claims from whatever died, so tasks requeue rather than orphan.
bash "$OPS/fleet-supervisor.sh" reap >/dev/null 2>&1 || true
tmux new -d -s pi-sup "WARM_CACHE=0 SUPERVISE_DESK=1 $OPS/fleet-supervisor.sh start 2>&1 | tee -a $OPS/logs/supervisor.log" \
  && echo "[$(ts)] supervisor relaunched" \
  || echo "[$(ts)] FAILED to relaunch supervisor"
