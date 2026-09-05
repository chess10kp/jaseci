#!/usr/bin/env bash
# port-backlog.sh — generate PORTING tasks (the proactive work stream, distinct
# from census gap-closing). Two kinds, computed LIVE against the tree so they
# stay current as suites/modules land:
#   1. convert-suite : CPython Lib/test/test_X.py not yet in the census corpus
#                      -> converter lane (worker6). Widens the census frontier.
#   2. port-module   : CPython Modules/X.c with no jacpython/X.jac yet, AND paired
#                      with a stdlib test suite -> mech lane (worker4). High-value,
#                      no make-work on C-infra modules.
# Idempotent: enqueue skips names already in any lane. Safe to run every refill.
set -uo pipefail
cd "$(dirname "$0")"
source ./fleet-queue.sh
REPO="${REPO:-/home/jac/repos/jac-python}"
MAN="${MAN:-/home/jac/projects/jacpy-farm/manifest}"

# --- 1. missing test suites -> converter lane -------------------------------
missing_suites=$(comm -23 \
  <(ls "$REPO"/reference/cpython/Lib/test/test_*.py 2>/dev/null | xargs -n1 basename | sed 's/\.py$//' | sort -u) \
  <(for j in "$MAN"/*.json; do jq -r '.job_id // empty' "$j" 2>/dev/null; done | sort -u))

# --- 2. un-ported modules, but ONLY those with a matching test suite --------
# (a module nothing tests is either C-infra or not worth porting blind)
ported=$(ls "$REPO"/jac-py/jacpython/*.jac 2>/dev/null | xargs -n1 basename | sed 's/\.jac$//;s/^_//' | sort -u)
suitestems=$(ls "$REPO"/reference/cpython/Lib/test/test_*.py 2>/dev/null | xargs -n1 basename | sed 's/^test_//;s/\.py$//' | sort -u)

n_s=0
while read -r s; do
  [ -z "$s" ] && continue; s="${s%.py}"                       # strip any stray suffix
  [ -f "$REPO/reference/cpython/Lib/test/$s.py" ] || continue
  printf 'family: converter | PORT: convert a CPython test suite into the corpus\nRun jac-py/tools/convert_suite.py on reference/cpython/Lib/test/%s.py\n(--outdir <out> --name conv_%s --cpython-lib reference/cpython/Lib). Fix conversion\nfailures, land the manifest so the census picks it up. DONE = conv_%s.conv.json + pins.\n' \
    "$s" "${s#test_}" "${s#test_}" | enqueue converter "400-convert-$s" | grep -q '^queued ' && n_s=$((n_s+1))
done <<< "$missing_suites"

n_m=0
for c in "$REPO"/reference/cpython/Modules/*.c; do
  stem=$(basename "$c" .c); stem="${stem#_}"; stem="${stem%module}"
  grep -qxF "$stem" <<<"$ported" && continue                  # already ported
  grep -qxF "$stem" <<<"$suitestems" || continue              # only if a test suite exercises it
  printf 'family: port | PORT: lift a CPython C module to jac (any lane may take — standalone new file, no family conflict; lane-keeper spreads these from mech)\nModule reference/cpython/Modules/%s exercised by test_%s. Lift/port to\njac-py/jacpython/%s.jac (see lift_p2_corpus.py / lift_p3_objects.py). Gate with\n.venv/bin/jac check. DONE = %s.jac imports + test_%s converts further than before.\n' \
    "$(basename "$c")" "$stem" "$stem" "$stem" "$stem" | enqueue mech "600-port-$stem" | grep -q '^queued ' && n_m=$((n_m+1))
done

echo "port-backlog: +$n_s NEW convert-suite (converter), +$n_m NEW port-module (mech) [skips not counted]"
