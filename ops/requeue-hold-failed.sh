#!/usr/bin/env bash
# requeue-hold-failed.sh — requeue only real P4-HOLD implementation tasks.
#
# Safety: requires GATES_GREEN=1 (set after jac-py gates workflow is green on tip).
# Dry-run:  ./requeue-hold-failed.sh --dry-run
# Execute:  GATES_GREEN=1 ./requeue-hold-failed.sh
#
# Converter/000 is skipped unless REPO/reference/cpython exists (worker may lack tree).
set -euo pipefail
OPS="$(cd "$(dirname "$0")" && pwd)"
QROOT="${QROOT:-$HOME/.local/state/jacq}"
REPO="${REPO:-$(cd "$OPS/.." && pwd)}"
DRY=0
[[ "${1:-}" == "--dry-run" ]] && DRY=1

if [[ "$DRY" -eq 0 && "${GATES_GREEN:-}" != "1" ]]; then
  echo "Refusing: set GATES_GREEN=1 after full jac-py gates are green on tip." >&2
  exit 1
fi

requeue_one() {
  local lane="$1" task="$2" skip_cpython="${3:-0}"
  local src="$QROOT/lanes/$lane/failed/$task"
  local dst="$QROOT/lanes/$lane/pending/$task"
  if [[ ! -e "$src" ]]; then
    echo "skip (missing) $lane/$task"
    return 0
  fi
  if [[ "$skip_cpython" == "1" && ! -d "$REPO/reference/cpython" ]]; then
    echo "skip (no cpython tree) $lane/$task"
    return 0
  fi
  if [[ -e "$dst" ]]; then
    echo "skip (already pending) $lane/$task"
    return 0
  fi
  if [[ "$DRY" -eq 1 ]]; then
    echo "would requeue $lane/$task"
    return 0
  fi
  mv -n "$src" "$dst"
  echo "requeued $lane/$task"
}

# Exceptions backup/drain tasks are synthetic and intentionally not requeued.

# mech (3)
for t in \
  900-layer1-ratchet-baseline-bump.task \
  904-land-gate-instrumentation.task \
  016-merge-integration-to-jacpy.task
do requeue_one mech "$t"; done

# objects (1 real task)
requeue_one objects 010-slice-zero-gates-evidence.task

# typesys backup/drain tasks are synthetic and intentionally not requeued.

# converter (1) — needs reference/cpython on the worker host
requeue_one converter 000-conversion-wave-v5.task 1

if [[ "$DRY" -eq 0 ]]; then
  echo "$(date +%s) desk: bulk requeue hold-failed-19 (GATES_GREEN=1)" >> "$QROOT/reaper.log"
fi
