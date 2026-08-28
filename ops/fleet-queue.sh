# fleet-queue.sh — filesystem pull-queue for the jac-python fleet.
# Source this from a worker or orchestrator (pi) session, or from overnight.sh.
#
#   source ops/fleet-queue.sh
#   WORKER=worker3 LANE=runtime worker_loop   # a worker drains a lane
#   snapshot                                  # orchestrator reads full state (~few KB)
#   reap                                      # requeue dead-worker claims
#
# Design (per fable advisor): queue lives OUTSIDE the git tree so `git clean`,
# branch switches, and the jac-format hook never touch it; atomic claim via
# rename(2); heartbeat (.hb) drives reaping so slow-but-alive workers are never
# robbed; status lines are overwritten (tmp+mv) so the desk never reads a torn line.

QROOT="${QROOT:-$HOME/.local/state/jacq}"
HB_STALE_MIN="${HB_STALE_MIN:-15}"   # requeue a claim whose heartbeat is older than this (~3x hb interval)

# Cross-shell: make an unmatched glob expand to nothing (bash default leaves the
# literal; zsh aborts). Every loop below tolerates both via an [ -e ] guard.
if [ -n "${ZSH_VERSION:-}" ]; then setopt NULL_GLOB 2>/dev/null; fi
if [ -n "${BASH_VERSION:-}" ]; then shopt -s nullglob 2>/dev/null; fi

# --- worker: claim the next pending item in a lane --------------------------
# claim_next <lane>  ->  echoes claimed .task path, rc=1 if lane empty
claim_next() {
  local lane="$1" src dst
  : "${WORKER:?set WORKER=worker1..worker7}"
  for src in "$QROOT/lanes/$lane/pending"/*.task; do
    [ -e "$src" ] || continue   # nullglob: no files -> loop body skipped -> return 1 below
    dst="$QROOT/lanes/$lane/claimed/${src##*/}"
    # mv -n is atomic; the loser of a two-worker race finds src gone and the
    # double-check ([ ! -e src ] && [ -e dst ]) fails, so it tries the next file.
    if mv -n "$src" "$dst" 2>/dev/null && [ ! -e "$src" ] && [ -e "$dst" ]; then
      printf '%s claimed %s\n' "$WORKER" "$(date +%s)" > "$dst.owner"
      touch "$dst.hb"
      echo "$dst"
      return 0
    fi
  done
  return 1
}

# heartbeat a claimed task (call from the worker's progress loop / keepalive)
beat() { touch "$1.hb" 2>/dev/null; }

# finish a claim: complete <task> <one-line-outcome>  /  fail <task> <reason>
complete() {
  local t="$1" lane; lane="${t%/claimed/*}"; shift
  printf '%s\n' "$*" > "$t.result"
  rm -f "$t.owner" "$t.hb"
  mv -n "$t" "$lane/done/${t##*/}" && mv -n "$t.result" "$lane/done/${t##*/}.result" 2>/dev/null
}
fail() {
  local t="$1" lane; lane="${t%/claimed/*}"; shift
  printf '%s\n' "$*" > "$t.err"
  rm -f "$t.owner" "$t.hb"
  mv -n "$t" "$lane/failed/${t##*/}" && mv -n "$t.err" "$lane/failed/${t##*/}.err" 2>/dev/null
}

# --- worker: overwrite-in-place status line (torn-read safe) ----------------
# status <state> <item> [msg]      e.g.  status busy runtime/143-tp_call "compiling"
status() {
  : "${WORKER:?set WORKER}"
  local tmp="$QROOT/status/$WORKER.line.tmp"
  printf '%s %s %s %s %s\n' "$WORKER" "${1:--}" "${2:--}" "$(date +%s)" "${3:-}" > "$tmp" \
    && mv "$tmp" "$QROOT/status/$WORKER.line"
}

# --- worker: drain a lane until empty ---------------------------------------
# Override `do_task` in your worker to actually run the item; default just prints.
do_task() { echo "[$WORKER] would run: $1  (contents: $(head -c120 "$1"))"; }
worker_loop() {
  local lane="${LANE:?set LANE=runtime|parser|review}" t
  : "${WORKER:?set WORKER}"
  while t="$(claim_next "$lane")"; do
    # Idempotency guard: a flaky-net requeue can hand us an item another worker
    # already finished. If a done/ record exists for this name, skip re-running.
    if [ -e "$QROOT/lanes/$lane/done/${t##*/}" ]; then
      rm -f "$t" "$t.owner" "$t.hb"; status idle - "skip-dup ${t##*/}"; continue
    fi
    status busy "$lane/${t##*/}" "start"
    if do_task "$t"; then complete "$t" "ok"; else fail "$t" "do_task rc=$?"; fi
    status idle - ""
  done
  status idle - "lane $lane drained"
}

# --- reaper: requeue claims whose worker went dark --------------------------
reap() {
  local t lane
  for t in "$QROOT"/lanes/*/claimed/*.task; do
    [ -e "$t" ] || continue
    if [ ! -e "$t.hb" ] || [ -n "$(find "$t.hb" -mmin +"$HB_STALE_MIN" 2>/dev/null)" ]; then
      lane="${t%/claimed/*}"
      echo "$(date +%s) requeued ${t##*/} (owner: $(cat "$t.owner" 2>/dev/null || echo ?))" >> "$QROOT/reaper.log"
      rm -f "$t.owner" "$t.hb"
      mv -n "$t" "$lane/pending/${t##*/}"   # if the worker finishes mid-reap, its own mv to done/ wins
    fi
  done
}

# --- orchestrator: reconstruct FULL state in a few KB (recyclable desk) ------
# The desk reads ONLY this. No ledger, no worker transcripts. Kill/respawn anytime.
# _lst <dir> <pattern> : safe list (never errors, never hangs on empty)
_lst() { find "$1" -maxdepth 1 -name "$2" -printf '%f\n' 2>/dev/null | sort | grep . || echo "(none)"; }
snapshot() {
  echo "== workers =="   ; find "$QROOT/status" -maxdepth 1 -name '*.line' -exec cat {} + 2>/dev/null | grep . || echo "(none)"
  echo "== pending =="   ; for l in "$QROOT"/lanes/*/; do echo "  ${l%/}:"; _lst "$l/pending" '*.task' | sed 's/^/    /'; done
  echo "== in-flight ==" ; find "$QROOT"/lanes/*/claimed -maxdepth 1 -name '*.task' -printf '%p\n' 2>/dev/null | grep . || echo "(none)"
  echo "== review-in ==" ; _lst "$QROOT/lanes/review/pending" '*.task'
  echo "== failed =="    ; find "$QROOT"/lanes/*/failed -maxdepth 1 -name '*.task' -printf '%p\n' 2>/dev/null | grep . || echo "(none)"
  echo "== reaper =="    ; tail -n 10 "$QROOT/reaper.log" 2>/dev/null
}

# --- steering: durable controls the desk/workers obey on their next pass -----
# These persist on disk, so they survive session respawns (unlike typing at an
# ephemeral pi session). This is the real steering surface in model A.

# bump <lane> <task-substr> [NNN] : reprioritize a pending task (rename its order
# prefix). Lower NNN = claimed sooner. Default 000 = jump to front.
bump() {
  local lane="$1" q="$2" nnn="${3:-000}" f base rest
  f=$(find "$QROOT/lanes/$lane/pending" -maxdepth 1 -name "*$q*.task" | head -1)
  [ -n "$f" ] || { echo "no pending task matching '$q' in $lane"; return 1; }
  base="${f##*/}"; rest="${base#*-}"                    # strip old NNN- prefix
  mv -n "$f" "$QROOT/lanes/$lane/pending/${nnn}-${rest}" && echo "bumped -> ${nnn}-${rest}"
}

# pause_lane <lane> / resume_lane <lane> : stop a lane being claimed without
# losing its work (pending -> _paused holding dir, and back).
pause_lane()  { mkdir -p "$QROOT/lanes/$1/_paused"; find "$QROOT/lanes/$1/pending" -maxdepth 1 -name '*.task' -exec mv -n {} "$QROOT/lanes/$1/_paused/" \; ; echo "paused $1"; }
resume_lane() { find "$QROOT/lanes/$1/_paused" -maxdepth 1 -name '*.task' -exec mv -n {} "$QROOT/lanes/$1/pending/" \; 2>/dev/null; echo "resumed $1"; }

# steer "<directive>" : append a bounded directive to DESK.md's open-decisions so
# the desk picks it up on its next snapshot pass. Keep DESK.md short (overwrite
# stale lines yourself); this is for live nudges the desk should act on.
steer() {
  local ops; ops="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
  printf -- '- [steer %s] %s\n' "$(date -u +%H:%MZ)" "$*" >> "$ops/DESK.md"
  echo "noted in DESK.md (desk acts on next pass)"
}

# --- orchestrator handoff: emit the entire boot packet for a fresh desk ------
# The replacement desk needs ONLY this output — no prior transcript, no ledger.
# Usage: handoff  (paste the output as the new pi session's first message)
handoff() {
  local here; here="$(cd "$(dirname "${BASH_SOURCE:-$0}")" && pwd)"
  cat <<EOF
You are the jac-python fleet ORCHESTRATOR (desk). You route work and gate merges;
you edit NO source files. Full operating model: $here/README.md.

Boot:
  source $here/fleet-queue.sh

Your loop:
  1. snapshot                      # read state (this is ALL you ingest)
  2. keep every lane's pending non-empty -> ./seed-backlog.sh (edit BACKLOG.md first)
  3. triage failed/*.err one file at a time; requeue or reassign via OWNERS
  4. when YOUR context gets heavy: update DESK.md, run 'handoff', respawn, stop.

Do NOT read logs/ or worker transcripts into context; open a specific
queue/lanes/*/done|failed/*.{result,err} only when triaging that one item.

===== DESK.md (in-flight decisions) =====
$(cat "$here/DESK.md" 2>/dev/null)

===== snapshot (live queue state) =====
$(snapshot)
EOF
}

# --- helper: enqueue an item -------------------------------------------------
# enqueue <lane> <NNN-slug> < body      (NNN prefix = priority/order)
# Idempotent by name: if a task with this basename already exists in pending/
# claimed/done/failed (any lane), it is NOT re-added — so seed/refill can run on
# every tick and in any order without clobbering in-flight or completed work.
enqueue() {
  local lane="$1" name="$2"
  if find "$QROOT/lanes" -maxdepth 3 -name "$name.task" 2>/dev/null | grep -q .; then
    cat >/dev/null; echo "skip (exists) $lane/$name.task"; return 0
  fi
  cat > "$QROOT/lanes/$lane/pending/$name.task"
  echo "queued $lane/$name.task"
}
