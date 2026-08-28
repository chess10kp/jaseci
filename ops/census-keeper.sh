#!/usr/bin/env bash
# census-keeper.sh — auto-resume wrapper for the AWS census supervisor.
# overnight.sh is idempotent (resumes past state/*.done, reuses the fleet) but
# under `set -Eeuo pipefail` a dropped connection kills it mid-run. This keeper
# reruns it until the run reaches DONE — so a lost-internet event self-heals.
#
# It does NOT edit overnight.sh. It reads status.json to tell apart:
#   * DIED / process-gone  -> transient (network); rerun with backoff.
#   * BLOCKED              -> a REAL gate failure needing a human; STOP + alert.
#   * DONE                 -> finished; exit 0.
#
# Usage:  ops/census-keeper.sh                (foreground; run under tmux/nohup)
#         MAX_TRIES=0 ops/census-keeper.sh    (0 = retry forever)
set -uo pipefail

SUP="${SUP:-/home/jac/projects/jacpy-farm/supervisor}"
OVERNIGHT="$SUP/overnight.sh"
STATUS="$SUP/status.json"
BACKOFF="${BACKOFF:-30}"; BACKOFF_MAX="${BACKOFF_MAX:-600}"
MAX_TRIES="${MAX_TRIES:-0}"     # 0 = forever
: "${ALERT_EMAIL:=}"

stage() { jq -r '.stage // "unknown"' "$STATUS" 2>/dev/null || echo unknown; }
online() { curl -fsS -m 10 -o /dev/null https://raw.githubusercontent.com 2>/dev/null; }

try=0; sleep_s="$BACKOFF"
while :; do
  try=$((try+1))
  # Don't burn reruns while the network is down — wait for connectivity first.
  until online; do echo "[keeper] offline; waiting ${BACKOFF}s"; sleep "$BACKOFF"; done

  echo "[keeper] run attempt $try (stage=$(stage))"
  # overnight.sh holds its own flock, so a stale live run won't be double-started.
  ALERT_EMAIL="$ALERT_EMAIL" "$OVERNIGHT" >>"$SUP/nohup.out" 2>&1
  rc=$?
  st="$(stage)"
  echo "[keeper] overnight.sh exited rc=$rc stage=$st"

  case "$st" in
    DONE) echo "[keeper] census DONE"; exit 0 ;;
    BLOCKED)
      echo "[keeper] BLOCKED (real gate failure) — NOT auto-retrying. See $SUP/BLOCKED.md"
      [ -n "$ALERT_EMAIL" ] && command -v aws >/dev/null && \
        aws sns publish --message "census BLOCKED: $(jq -r .blocked_reason "$STATUS")" \
          --subject "jacpy census BLOCKED" 2>/dev/null || true
      exit 1 ;;
    *)  # DIED / unknown / init: treat as transient, back off and resume
      (( MAX_TRIES > 0 && try >= MAX_TRIES )) && { echo "[keeper] gave up after $try tries"; exit 2; }
      echo "[keeper] transient (rc=$rc); resuming in ${sleep_s}s"
      sleep "$sleep_s"
      sleep_s=$(( sleep_s*2 > BACKOFF_MAX ? BACKOFF_MAX : sleep_s*2 ))  # exp backoff, capped
      ;;
  esac
done
