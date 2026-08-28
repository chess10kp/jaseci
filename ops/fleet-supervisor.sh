#!/usr/bin/env bash
# fleet-supervisor.sh — keep the pi AI-worker fleet alive + the lanes fed.
# This is the pi-fleet counterpart to jacpy-farm's overnight.sh (which supervises
# the CLOUD census, not these local AI sessions). It does NOT touch overnight.sh.
#
# Connection-resistance model:
#   * Each worker runs inside a tmux `until` loop -> if the pi session dies
#     (disconnect, OOM, kill) tmux respawns it; on restart it re-sources its key
#     and re-enters worker_loop, self-claiming the next pending item.
#   * A short net blip does NOT kill the session (the pi client retries API calls)
#     and the LOCAL heartbeat keeps touching, so `reap` won't steal live work.
#   * A long outage kills the session -> heartbeat goes stale -> `reap` requeues
#     the task -> another worker (or the respawned one) picks it up. Nothing lost.
#   * ALL state is on disk, so this supervisor itself is restartable: rerun it
#     anytime; the fleet + queue resume from where they were.
#
# Usage:
#   ops/fleet-supervisor.sh start     # launch/repair fleet + start control loop
#   ops/fleet-supervisor.sh reap      # one reaper pass (or let the loop do it)
#   ops/fleet-supervisor.sh stop      # kill all worker tmux sessions + loop
set -euo pipefail
cd "$(dirname "$0")"
source ./fleet-queue.sh

TICK="${TICK:-120}"                 # control-loop period (s)
PENDING_LOW="${PENDING_LOW:-2}"     # refill a lane when its pending drops below this
LOCK="$QROOT/fleet-supervisor.lock"

# AGENT RUNTIME policy — which CLI every fleet session drives. All sessions are
# non-interactive one-prompt-per-process; the tmux until-loops below provide the
# repetition, so each session handles one task/batch -> minimal context, clean
# recycle (the pi-agnostic way to cap worker context).
#   cursor : cursor-agent -p — auth = Cursor login (`cursor-agent login`), NO
#            per-worker keys. Default since the free opencode models died
#            (x-preview-f-free 401'd upstream; mimo-v2.5-free 429s under 6
#            workers) — rides the Cursor subscription instead of credits.
#            Note: cursor-agent has no subagent fan-out; worker-prompt.sh gives
#            that runtime a hands-on work loop instead.
#   pi     : pi -p — needs the per-worker OPENCODE_API_KEY keyfiles (WORKERS map).
RUNTIME="${RUNTIME:-cursor}"
CURSOR_BIN="${CURSOR_BIN:-$HOME/.local/bin/cursor-agent}"
CURSOR_MODEL="${CURSOR_MODEL:-composer-2.5}"   # cursor default; list: "$CURSOR_BIN" models
MODEL="${MODEL:-}"                             # pi default; empty => pi config default (zai/glm-5.2)
DESK_MODEL="${DESK_MODEL:-}"                   # desk is light; empty => runtime default
REPO="$(cd .. && pwd)"                          # agent workspace (ops/.. == repo root)
declare -A MODELS=(                  # optional per-worker overrides; ids must match RUNTIME:
  # [worker7]="gpt-5.3-codex-high"        # cursor: typesys/metaclass is hard -> stronger model
  # [worker4]="composer-2.5-fast"         # cursor: mechanical -> fast is fine
  # [worker7]="opencode/deepseek-v4-pro"  # pi
)
# Full invocation for one non-interactive prompt. pi: -p processes the prompt to
# completion and EXITS, -a trusts project-local files, -n names the session.
# cursor: -p prints to completion, --yolo force-approves tool calls (no
# interactive prompter inside a tmux loop), --trust accepts the workspace.
agent_cli() {  # <session-name> <model-default>  (MODELS[name] override wins)
  local w="$1" m="${MODELS[$w]:-${2:-}}"
  if [ "$RUNTIME" = pi ]; then
    printf 'pi -p -a -n %q' "$w"
    m="${m:-$MODEL}"; [ -n "$m" ] && printf ' --model %q' "$m"
  else
    printf '%q -p --yolo --trust --workspace %q' "$CURSOR_BIN" "$REPO"
    m="${m:-$CURSOR_MODEL}"; [ -n "$m" ] && printf ' --model %q' "$m"
  fi
}
# Per-respawn env for the pi runtime only (cursor-agent auth is the shared Cursor
# login, not per-worker keys). Keyfiles set OPENCODE_API_KEY bare; it must be
# exported so pi subagents inherit it (402 guard).
pi_env_block() {  # <worker> <keyfile> — emits nothing unless RUNTIME=pi
  [ "$RUNTIME" = pi ] || return 0
  printf '  [ -f "%s" ] && . "%s"\n  export OPENCODE_API_KEY\n' "$2" "$2"
}

# worker -> "LANE KEYFILE" — derived from the LIVE tmux sessions (workerN pi
# --name workerN-orchestrator) and their stated FAMILY, Aug 25. Keys map by
# ordinal (second->2 ... eight->8); worker5/.fifth is the documented spare.
# Lane == the worker's family (its owned files); see OWNERS for territories.
declare -A WORKERS=(
  [worker2]="objects     $HOME/.second-worker.env"  # objects.jac: dataclass bridge, __dict__, property, __kwdefaults__
  [worker3]="exceptions  $HOME/.third-worker.env"   # exceptions_core.jac + compiler exception-table paths
  [worker4]="mech        $HOME/.fourth.env"          # runtime-gap / mechanical conversions / bridge-policy
  [worker6]="converter   $HOME/.sixth.env"           # converter throughput (jac-py/tools), doctest extraction
  [worker7]="typesys     $HOME/.seven.env"           # type-system / metaclass surface (design-heavy)
  [worker8]="census      $HOME/.eight.env"           # census-driven gap closing  <- consumes gapq-bridge output
)
# worker5/.fifth.env is the SPARE and is used by the DESK (IronUnion) by default —
# see DESK_KEY. To field worker5 as a 7th claimer, give it a free key and add it here.

# The command a worker session runs: a LEAN CLAIMER. Each session is
# wall-clock-bounded (MAX_SESSION_MIN) so context resets on respawn. When the
# agent exits (lane drained, timeout, or death), the until-loop respawns it
# fresh with a new lean prompt; it re-claims.
MAX_SESSION_MIN="${MAX_SESSION_MIN:-45}"
ALOG="$PWD/logs/agent"     # per-session agent output (agent-<worker>.log, truncated each respawn)
mkdir -p "$PWD/logs"
worker_cmd() {  # <worker> <lane> <keyfile>
  local w="$1" lane="$2" key="$3"
  cat <<EOF
until false; do
$(pi_env_block "$w" "$key")
  export WORKER="$w" LANE="$lane"
  PROMPT="\$(bash "$PWD/worker-prompt.sh" "$w" "$lane")"
  # One prompt per process (see agent_cli); this until-loop provides the
  # repetition, so each session handles a single task -> minimal context.
  # Output teed to logs/agent-<w>.log so credit_guard (supervisor tick) can see
  # billing/auth failures — without this an out-of-credits fleet just churns.
  timeout ${MAX_SESSION_MIN}m $(agent_cli "$w" "$MODEL") "\$PROMPT" 2>&1 | tee "$ALOG-$w.log" || true
  echo "[\$(date -u +%FT%TZ)] $w session ended; respawn in 5s" >&2
  sleep 5
done
EOF
}

ensure_worker() {  # start the tmux session if absent (session name == worker name)
  local w="$1" spec="${WORKERS[$w]}" lane key sess="$w"
  lane="$(awk '{print $1}' <<<"$spec")"; key="$(awk '{print $2}' <<<"$spec")"
  # If a stale dead-shell session with this name exists (e.g. reboot-restored),
  # replace it so the claimer actually starts.
  if tmux has-session -t "$sess" 2>/dev/null; then
    local pp; pp="$(tmux list-panes -t "$sess" -F '#{pane_pid}' 2>/dev/null | head -1)"
    if [ -n "$pp" ] && pgrep -P "$pp" >/dev/null 2>&1; then return 0; fi   # alive: leave it
    tmux kill-session -t "$sess" 2>/dev/null || true                       # dead shell: recycle
  fi
  tmux new-session -d -s "$sess" "$(worker_cmd "$w" "$lane" "$key")"
  echo "launched $sess (lane=$lane)"
}

# The single desk (IronUnion). Recyclable pi session reading only `snapshot`.
DESK_KEY="${DESK_KEY:-$HOME/.fifth.env}"          # desk key (pi runtime only)
ensure_desk() {
  local sess="desk"
  # Liveness check like ensure_worker: a session that EXISTS but whose agent
  # process has died leaves a dead shell. Without this the desk can sit dead
  # forever while the supervisor thinks it is fine (this bit us: desk dead ~1h,
  # no merges).
  if tmux has-session -t "$sess" 2>/dev/null; then
    local pp; pp="$(tmux list-panes -t "$sess" -F '#{pane_pid}' 2>/dev/null | head -1)"
    if [ -n "$pp" ] && pgrep -P "$pp" >/dev/null 2>&1; then return 0; fi   # alive
    tmux kill-session -t "$sess" 2>/dev/null || true                       # dead shell: recycle
  fi
  tmux new-session -d -s "$sess" "until false; do
$(pi_env_block desk "$DESK_KEY")
    timeout ${MAX_SESSION_MIN}m $(agent_cli desk "${DESK_MODEL:-}") \"\$(bash '$PWD/desk-prompt.sh')\" 2>&1 | tee '$ALOG-desk.log' || true
    sleep 5
  done"
  echo "launched $sess (desk=IronUnion)"
}

# --- credit/auth guard -------------------------------------------------------
# cursor-agent exposes NO quota endpoint (`status` = auth only), so the only
# observable of an exhausted subscription is the failure text a rejected request
# prints before exiting non-zero. Each session's output is teed to
# logs/agent-<sess>.log; this guard (run every supervisor tick) scans the TAIL
# (final lines = exit errors, avoids matching "402" in normal transcript) for
# fatal billing/auth strings and, on first hit, stops the fleet and raises an
# alarm. 429/rate-limit is deliberately NOT fatal — transient, retryable.
FATAL_PAT='usage limit|usage capped|out of credits|insufficient credits|quota exceeded|payment required|HTTP 402|status[ :]?402|[Ii]nvalid API key|[Uu]nauthorized'
credit_guard() {
  local f sess hits
  for f in "$ALOG"-*.log; do
    [ -e "$f" ] || continue
    hits="$(tail -15 "$f" | { grep -E "$FATAL_PAT" || true; } | head -3)"
    [ -n "$hits" ] || continue
    sess="$(basename "$f" .log)"; sess="${sess#agent-}"
    { echo "$(date -u +%FT%TZ) FATAL: agent billing/auth failure ($sess) — fleet auto-stopped."
      echo "  Re-check the Cursor dashboard (Settings -> Usage/Billing), then"
      echo "  clear this file and run: ops/fleet-supervisor.sh start"
      echo "-- matched lines (tail of $f) --"
      echo "$hits"; } > "$PWD/logs/FLEET-STOPPED.txt"
    echo "credit_guard: FATAL billing/auth pattern from $sess — stopping fleet (ops/logs/FLEET-STOPPED.txt)"
    command -v notify-send >/dev/null 2>&1 \
      && notify-send -u critical "jac-python fleet" "Cursor credits/auth exhausted — fleet stopped. See ops/logs/FLEET-STOPPED.txt" || true
    stop
    return 0
  done
  return 0
}

refill() {  # keep every lane's pending non-empty (token-max toward the deadline)
  local lane depth
  for lane in objects exceptions mech converter typesys census; do
    depth=$(find "$QROOT/lanes/$lane/pending" -maxdepth 1 -name '*.task' 2>/dev/null | wc -l)
    (( depth < PENDING_LOW )) || continue
    echo "lane $lane low ($depth); refilling"
    bash ./seed-backlog.sh >/dev/null 2>&1 || true              # human backlog (idempotent)
    { [ "$lane" = census ] || [ "$lane" = typesys ]; } && bash ./gapq-bridge.sh >/dev/null 2>&1 || true  # census gaps
    { [ "$lane" = converter ] || [ "$lane" = mech ]; } && bash ./port-backlog.sh >/dev/null 2>&1 || true  # porting frontier
  done
}

start() {
  exec 8>>"$LOCK"; flock -n 8 || { echo "supervisor already running ($LOCK)"; exit 1; }
  command -v tmux >/dev/null || { echo "tmux required"; exit 1; }
  echo "== fleet-supervisor start: ${#WORKERS[@]} workers, tick ${TICK}s =="
  # Pre-warm the shared jac cache BEFORE fan-out so subagents don't cold-compile
  # the compiler 40-at-once. Skippable with WARM_CACHE=0. The `|| true` is
  # load-bearing: under `set -euo pipefail` a failing warm (e.g. jac won't build
  # locally) would otherwise abort start() BEFORE the supervise loop, killing the
  # whole fleet silently. This bit us — never let the warm be fatal.
  if [ "${WARM_CACHE:-0}" = 1 ]; then bash "$PWD/warm-jac-cache.sh" 2>&1 | sed 's/^/  /' || true; fi
  # SUPERVISE_DESK=0 -> the supervisor does NOT launch/respawn the desk, so YOU
  # can run it hands-on in your own terminal and steer it interactively without
  # it being recycled under you. Workers are still supervised.
  while true; do
    [ "${SUPERVISE_DESK:-1}" = 1 ] && ensure_desk           # single coordinator
    for w in "${!WORKERS[@]}"; do ensure_worker "$w"; done   # respawn any dead session
    reap                                                     # requeue stale claims
    credit_guard                                             # stop fleet on billing/auth death
    refill                                                   # keep lanes fed
    [ "${JANITOR:-1}" = 1 ] && bash "$PWD/tmp-janitor.sh" >>"$QROOT/janitor.log" 2>&1 || true  # GC merged worktrees; keep /tmp off 100%
    snapshot >> "$QROOT/queue-digest.log"                    # audit trail (desk tails this, not context)
    sleep "$TICK"
  done
}

stop() {
  tmux kill-session -t desk 2>/dev/null || true
  for w in "${!WORKERS[@]}"; do tmux kill-session -t "$w" 2>/dev/null || true; done
  pkill -f fleet-supervisor.sh 2>/dev/null || true
  echo "fleet stopped (desk + workers)"
}

# Validate everything WITHOUT launching pi (no tokens spent). Green here => safe to start.
preflight() {
  local ok=1
  echo "== deps =="
  local agent_bin; agent_bin="$([ "$RUNTIME" = pi ] && echo pi || echo "$CURSOR_BIN")"
  for c in tmux jq git "$agent_bin"; do command -v "$c" >/dev/null && echo "  ok   $c" || { echo "  MISS $c"; ok=0; }; done
  echo "== auth (RUNTIME=$RUNTIME) =="
  if [ "$RUNTIME" = pi ]; then
  for w in $(printf '%s\n' "${!WORKERS[@]}" | sort); do
    local key; key="$(awk '{print $2}' <<<"${WORKERS[$w]}")"
    [ -f "$key" ] && echo "  ok   $w -> $(basename "$key")" || { echo "  MISS $w -> $key"; ok=0; }
  done
  [ -f "$DESK_KEY" ] && echo "  ok   desk -> $(basename "$DESK_KEY")" || { echo "  MISS desk -> $DESK_KEY"; ok=0; }
  else
    "$CURSOR_BIN" status >/dev/null 2>&1 && echo "  ok   cursor-agent logged in" \
      || { echo "  MISS cursor-agent login (run: $CURSOR_BIN login)"; ok=0; }
  fi
  echo "== prompts (non-empty?) =="
  for w in $(printf '%s\n' "${!WORKERS[@]}" | sort); do
    local lane; lane="$(awk '{print $1}' <<<"${WORKERS[$w]}")"
    local n; n=$(bash "$PWD/worker-prompt.sh" "$w" "$lane" 2>/dev/null | wc -c)
    (( n > 200 )) && echo "  ok   $w ($lane) ${n}b" || { echo "  BAD  $w prompt ${n}b"; ok=0; }
  done
  local dn; dn=$(bash "$PWD/desk-prompt.sh" 2>/dev/null | wc -c)
  (( dn > 200 )) && echo "  ok   desk prompt ${dn}b" || { echo "  BAD desk prompt"; ok=0; }
  echo "== models (RUNTIME=$RUNTIME; per-worker MODELS[] override; empty => runtime default) =="
  local def; def="$([ "$RUNTIME" = pi ] && echo "${MODEL:-<pi default: glm-5.2>}" || echo "${CURSOR_MODEL:-<cursor default>}")"
  for w in $(printf '%s\n' "${!WORKERS[@]}" | sort); do
    printf '  %-9s %s\n' "$w" "${MODELS[$w]:-$def}"
  done
  printf '  %-9s %s\n' "desk" "${MODELS[desk]:-${DESK_MODEL:-$def}}"
  echo "== lanes (pending depth) =="
  for lane in objects exceptions mech converter typesys census; do
    local d; d=$(find "$QROOT/lanes/$lane/pending" -maxdepth 1 -name '*.task' 2>/dev/null | wc -l)
    printf '  %-10s %s pending%s\n' "$lane" "$d" "$([ "$d" -eq 0 ] && echo '   <- empty: worker will idle until fed' || echo '')"
  done
  echo "== session name collisions =="
  for w in $(printf '%s\n' "${!WORKERS[@]}" | sort) desk; do
    if tmux has-session -t "$w" 2>/dev/null; then
      local pp; pp="$(tmux list-panes -t "$w" -F '#{pane_pid}' 2>/dev/null | head -1)"
      if [ -n "$pp" ] && pgrep -P "$pp" >/dev/null 2>&1; then echo "  LIVE $w (will be left running)"; else echo "  dead $w (will be recycled on start)"; fi
    else echo "  free $w"; fi
  done
  echo; (( ok )) && echo "PREFLIGHT: GREEN — safe to \`$0 start\`" || echo "PREFLIGHT: RED — fix MISS/BAD above first"
  return $(( ok ? 0 : 1 ))
}

case "${1:-start}" in
  start) preflight && start || { echo "refusing to start: preflight red"; exit 1; } ;;
  preflight|check) preflight ;;
  reap)  reap; echo "reap done" ;;
  refill) refill ;;
  stop)  stop ;;
  *) echo "usage: $0 {start|preflight|reap|refill|stop}"; exit 2 ;;
esac
