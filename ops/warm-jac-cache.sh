#!/usr/bin/env bash
# warm-jac-cache.sh — populate the SHARED jac compiler cache (~/.cache/jac, global
# and content-hash-keyed) BEFORE the fleet fans out, so 40 subagents don't all
# trigger the multi-minute cold compiler-compile at once (thundering herd on a
# compute-constrained box). After this, a fresh worktree's first `jac check` pays
# only ~15-20s of path-adaptation instead of minutes; subsequent checks are ~0.4s.
#
# Safe/idempotent: if the cache already matches the current origin tip, this is a
# few seconds. Run at supervisor start and again after a big compiler landing.
set -uo pipefail
REPO="${REPO:-/home/jac/repos/jac-python}"
JAC="${JAC:-$REPO/.venv/bin/jac}"
cd "$REPO"

echo "[warm] fetching origin tip..."
git fetch origin jac-python -q 2>/dev/null || true

# Warm both paths workers exercise: the compiler front-end (dev-mode compile of
# jaclang) and a runtime jacpython file. `jac check` rc is irrelevant here — a
# file with type errors still populates the compiler cache we care about.
echo "[warm] compiling + caching compiler (first run is the slow one)..."
t0=$(date +%s)
timeout 600 "$JAC" check jac/jaclang/compiler/absyntree.jac >/dev/null 2>&1 || true
timeout 300 "$JAC" check jac/jaclang/compiler/program.jac   >/dev/null 2>&1 || true
# a runtime file if present (jacpython lives in jac-py/)
f=$(find jac-py/jacpython -maxdepth 1 -name '*.jac' 2>/dev/null | head -1)
[ -n "$f" ] && timeout 300 "$JAC" check "$f" >/dev/null 2>&1 || true
t1=$(date +%s)

sz=$(du -sh ~/.cache/jac 2>/dev/null | cut -f1)
echo "[warm] done in $((t1-t0))s; shared cache ~/.cache/jac = ${sz:-?}"
echo "[warm] fresh worktrees now pay ~15-20s on first check, ~0.4s after."
