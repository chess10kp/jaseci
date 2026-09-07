#!/usr/bin/env python3
"""token-ledger.py — authoritative token ledger + daily-budget feed.

Why: 2026-08-29 burn (~2B tokens dashboard). Cursor exposes no quota API, but
every cursor-agent invocation auto-writes debug logs containing one
`agent_cli.turn.outcome` structured record per model request, with exact
input/output/cache-read/cache-write token counts and a unique request_id.

This script:
  collect  — incrementally scans known debug-log dirs, dedupes by request_id,
             appends one JSONL row per request to $QROOT/ledger/tokens.jsonl
             (the single authoritative ledger; survives in fleet state, never
             touched by git).
  today    — prints today's totals (UTC) as: input output cache_read cache_write
             total_millions  — machine-readable, one line, for budget_guard.
  maxturn  — prints the largest request for today, optionally restricted to
             rows at or after an ISO-8601 UTC timestamp for restart-safe guards.
  summary  — human table: per-day and grand totals.

Env:
  QROOT               fleet state root (default ~/.local/state/jacq)
  LEDGER_LOG_DIRS     colon-separated debug-log dirs to watch
                      (default: the two known cursor-agent debug dirs)
"""
import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

QROOT = Path(os.environ.get("QROOT", os.path.expanduser("~/.local/state/jacq")))
LEDGER = QROOT / "ledger" / "tokens.jsonl"
OFFSETS = QROOT / "ledger" / ".offsets.json"
LOG_DIRS = [
    d for d in os.environ.get(
        "LEDGER_LOG_DIRS",
        "/tmp/cursor-agent-logs-1000:/tmp/cursor_osp_tmp/cursor-agent-logs-1000",
    ).split(":") if d
]

# [ts] structured-log.info {"key":"agent_cli","message":"agent_cli.turn.outcome","metadata":{...}}
LINE_RE = re.compile(
    r"^\[([0-9T:.\-Z]+)\] structured-log\.info (\{.*\"agent_cli\.turn\.outcome\".*\})\s*$"
)


def read_offsets():
    try:
        return json.loads(OFFSETS.read_text())
    except Exception:
        return {}


def write_offsets(off):
    OFFSETS.parent.mkdir(parents=True, exist_ok=True)
    OFFSETS.write_text(json.dumps(off))


def seen_request_ids():
    ids = set()
    try:
        with LEDGER.open() as f:
            for line in f:
                try:
                    ids.add(json.loads(line)["request_id"])
                except Exception:
                    pass
    except FileNotFoundError:
        pass
    return ids


def log_files():
    for d in LOG_DIRS:
        dp = Path(d)
        if not dp.is_dir():
            continue
        for p in sorted(dp.glob("session-*.log")):
            yield p


def collect():
    LEDGER.parent.mkdir(parents=True, exist_ok=True)
    offsets = read_offsets()
    seen = seen_request_ids()
    new_rows, new_ids = [], []
    for p in log_files():
        key = str(p)
        try:
            size = p.stat().st_size
        except FileNotFoundError:
            continue
        start = int(offsets.get(key, 0))
        if start > size:  # truncated/rotated same name: reread
            start = 0
        if start == size:
            continue
        with p.open("rb") as f:
            f.seek(start)
            blob = f.read()
        # only consume up to the last complete line (tail may be mid-write)
        nl = blob.rfind(b"\n")
        if nl < 0:
            continue
        consumed, chunk = start + nl + 1, blob[: nl + 1].decode("utf-8", "replace")
        for line in chunk.splitlines():
            m = LINE_RE.match(line)
            if not m:
                continue
            try:
                rec = json.loads(m.group(2))
            except json.JSONDecodeError:
                continue
            meta = rec.get("metadata", {})
            rid = meta.get("request_id")
            if not rid or rid in seen:
                continue
            seen.add(rid)
            new_rows.append({
                "ts": m.group(1),
                "worker": None,  # attribution not tracked (2026-08-29: not needed for budget)
                "source": key,
                "request_id": rid,
                "conversation_id": meta.get("conversation_id"),
                "model": meta.get("model"),
                "input_tokens": int(meta.get("input_tokens") or 0),
                "output_tokens": int(meta.get("output_tokens") or 0),
                "cache_read_tokens": int(meta.get("cache_read_tokens") or 0),
                "cache_write_tokens": int(meta.get("cache_write_tokens") or 0),
                "outcome": meta.get("outcome"),
                "duration_ms": int(meta.get("duration_ms") or 0),
            })
            new_ids.append(rid)
        offsets[key] = consumed
    if new_rows:
        with LEDGER.open("a") as f:
            for r in new_rows:
                f.write(json.dumps(r, separators=(",", ":")) + "\n")
    write_offsets(offsets)
    return len(new_rows)


def rows():
    try:
        with LEDGER.open() as f:
            for line in f:
                try:
                    yield json.loads(line)
                except Exception:
                    pass
    except FileNotFoundError:
        pass


def today():
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    t = [0, 0, 0, 0]
    for r in rows():
        if r.get("ts", "").startswith(day):
            t[0] += r["input_tokens"]
            t[1] += r["output_tokens"]
            t[2] += r["cache_read_tokens"]
            t[3] += r["cache_write_tokens"]
    total = sum(t)
    print(f"{t[0]} {t[1]} {t[2]} {t[3]} {total / 1e6:.3f}")


def maxturn(since=None):
    """Max single-request total tokens today, optionally after ``since``."""
    day = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    mx, mx_rid = 0.0, ""
    for r in rows():
        ts = r.get("ts", "")
        if not ts.startswith(day) or (since and ts < since):
            continue
        t = r["input_tokens"] + r["output_tokens"] + r["cache_read_tokens"] + r["cache_write_tokens"]
        if t > mx:
            mx, mx_rid = t, r.get("request_id", "")
    print(f"{mx / 1e6:.3f} {mx_rid}")


def summary():
    days = {}
    for r in rows():
        d = r.get("ts", "")[:10]
        a = days.setdefault(d, [0, 0, 0, 0, 0])
        a[0] += r["input_tokens"]
        a[1] += r["output_tokens"]
        a[2] += r["cache_read_tokens"]
        a[3] += r["cache_write_tokens"]
        a[4] += 1
    if not days:
        print("(ledger empty)")
        return
    print(f"{'day':<12}{'requests':>9}{'input':>12}{'output':>10}{'cache_rd':>14}{'cache_wr':>12}{'total(M)':>11}")
    gt = [0] * 5
    for d in sorted(days):
        a = days[d]
        print(f"{d:<12}{a[4]:>9}{a[0]:>12,}{a[1]:>10,}{a[2]:>14,}{a[3]:>12,}{sum(a[:4]) / 1e6:>11.2f}")
        for i in range(5):
            gt[i] += a[i]
    print(f"{'TOTAL':<12}{gt[4]:>9}{gt[0]:>12,}{gt[1]:>10,}{gt[2]:>14,}{gt[3]:>12,}{sum(gt[:4]) / 1e6:>11.2f}")
    print(f"ledger: {LEDGER}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "summary"
    if cmd == "collect":
        print(f"collected {collect()} new rows")
    elif cmd == "today":
        today()
    elif cmd == "maxturn":
        maxturn(sys.argv[2] if len(sys.argv) > 2 else None)
    elif cmd == "summary":
        summary()
    else:
        sys.exit(f"usage: {sys.argv[0]} {{collect|today|maxturn [since]|summary}}")
