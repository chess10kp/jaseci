#!/usr/bin/env bash
# gapq-bridge.sh — feed the AWS census output into the pi-fleet fix-lanes.
#
# The census farm (jacpy-farm/supervisor/overnight.sh, EC2+S3) emits
# results-canary/gap_queue.json: one entry per semantic-gap fingerprint, with a
# priority (suites x severity), suite_ids, evidence S3 URIs, and a state/claim/
# resolution model. This bridge turns each `ready`, unclaimed entry into a .task
# in the runtime lane so AI workers self-claim real, deduped, priority-ordered
# work — keeping the 7 keys fed straight from live census output.
#
# This is the ONLY coupling between the two systems: census PRODUCES gaps here,
# the pi fleet CONSUMES them. overnight.sh is never modified.
#
# Usage:  ./gapq-bridge.sh [path/to/gap_queue.json]   (default: latest census)
set -euo pipefail
cd "$(dirname "$0")"
source ./fleet-queue.sh

# --resolve <fp12> <notes> : record a fingerprint as fixed. Provenance only —
# the census regenerates gap_queue.json each cycle; dedupe is enforced by the
# task staying in done/ (known() scans it), so a resolved gap is never re-queued
# while its done/ record survives. This log lets the desk/census confirm closure.
if [ "${1:-}" = "--resolve" ]; then
  fp12="${2:?fp12}"; shift 2
  printf '{"fp12":"%s","at":"%s","notes":"%s"}\n' "$fp12" "$(date -u +%FT%TZ)" "$*" \
    >> "$QROOT/resolutions.jsonl"
  echo "recorded resolution for $fp12"; exit 0
fi

GAPQ="${1:-/home/jac/projects/jacpy-farm/supervisor/results-canary/gap_queue.json}"
[ -f "$GAPQ" ] || { echo "no gap_queue at $GAPQ (run a census first)"; exit 1; }
command -v jq >/dev/null || { echo "jq required"; exit 1; }

# fingerprints already known to ANY lane (pending/claimed/done/failed) — dedupe
known() {
  { find "$QROOT/lanes" -name '*gap-*.task*' -printf '%f\n' 2>/dev/null \
      | sed -n 's/.*gap-\([0-9a-f]\{12\}\).*/\1/p'
    # resolved fingerprints stay known even if done/ is later pruned.
    # `|| true`: missing log must not trip pipefail+set -e.
    { sed -n 's/.*"fp12":"\([0-9a-f]\{12\}\)".*/\1/p' "$QROOT/resolutions.jsonl" 2>/dev/null || true; }
  } | sort -u
}
KNOWN="$(known)"

added=0; skipped=0
# stream entries as TSV: fp \t score \t kind \t signature \t nsuites
while IFS=$'\t' read -r fp score kind sig nsuites; do
  fp12="${fp#fp-v1:}"; fp12="${fp12:0:12}"
  if grep -qxF "$fp12" <<<"$KNOWN"; then skipped=$((skipped+1)); continue; fi
  # higher score -> smaller NNN -> claimed first. clamp to [0,899]; reserve 9xx for hand items.
  nnn=$(( score > 899 ? 0 : 899 - score )); printf -v nnn '%03d' "$nnn"
  # census gaps default to worker8's census lane; type-system/metaclass gaps
  # route to worker7's typesys lane (design-heavy).
  lane=census
  case "$sig" in *"cannot extend"*|*"metaclass"*|*"__init_subclass__"*|*"IntFlag"*|*"IntEnum"*) lane=typesys;; esac
  enqueue "$lane" "${nnn}-gap-${fp12}" >/dev/null <<EOF
lane: $lane | source: census gap_queue | fingerprint: $fp
kind: $kind | priority(score=suites*sev): $score | suites_hit: $nsuites
signature: $sig
evidence: s3 results/<suite>/ for the suite_ids in gap_queue.json entry $fp12
DONE = fix + oracle pin; write resolution back via: ./gapq-bridge.sh --resolve $fp12 "<sha/notes>"
EOF
  added=$((added+1))
done < <(jq -r '
  .entries[]
  | select(.state=="ready" and (.claim==null))
  | [ .fingerprint,
      ((.priority.suites // 1) * (.priority.severity // 1)),
      .kind,
      (.signature|gsub("\t";" ")),
      (.suite_ids|length) ] | @tsv' "$GAPQ")

echo "gapq-bridge: +$added queued, $skipped already known (from $(basename "$(dirname "$GAPQ")")/gap_queue.json)"
snapshot | sed -n '/== pending ==/,/== in-flight ==/p'
