# Fleet tooling recovery

Recovered on 2026-08-28 from read-only Pi JSONL transcripts. No fleet process,
worker, Jac command, test, git commit, push, or recovered script was executed.
Validation was limited to byte-count checks and `bash -n`.

## Recovered files

All recovered sections are exact transcript evidence. No guessed section was
needed, so none carries a `# [reconstructed]` marker.

| File | Confidence | Primary transcript evidence |
|---|---|---|
| `fleet-queue.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T14-51-23-046Z_01a03e8d-ea26-7b64-97fd-86a661996cac.jsonl`: full `cat` result, 8,984 bytes, matching the pre-deletion inventory. |
| `fleet-supervisor.sh` | **exact (edit replay)** | `--home-jac-repos-jac-python--/2026-08-26T20-25-09-974Z_01a03fbf-8056-7388-b1a2-826dbad64613.jsonl`: full 11,725-byte base read plus the three successful cursor-runtime edit sets. The resulting 15,717-byte file matches later line-range reads in `2026-08-27T00-20-27-676Z_01a04096-eb9c-705a-bdf4-2dd4d33b1a0b.jsonl`. |
| `fleet-watchdog.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-25T21-38-26-898Z_01a03adc-3bd2-72df-a086-ce37fdde2022.jsonl`: complete script in the `sed -n 1,60p` tool result, 2,676 bytes, matching inventory. |
| `OWNERS` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T10-42-07-968Z_01a03da9-b7e0-7e4d-a58a-11b9a79f84f1.jsonl`: full `cat`, 2,066 bytes, matching inventory. |
| `worker-prompt.sh` | **exact** | `--home-jac-repos-jac-python--/2026-08-26T20-25-09-974Z_01a03fbf-8056-7388-b1a2-826dbad64613.jsonl`: final full-file `write` from the cursor-agent migration, 6,066 bytes. |
| `desk-prompt.sh` | **exact** | Same 2026-08-26T20-25-09 transcript: full read, 1,870 bytes, matching inventory. |
| `seed-backlog.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T07-26-06-678Z_01a03cf6-4156-72c8-9f12-d6e7c58e6dd2.jsonl`: full read, 3,497 bytes, matching inventory. |
| `gapq-bridge.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T13-46-52-486Z_01a03e52-dac6-74a9-9188-2896e86edf65.jsonl`: full `cat`, 3,628 bytes, matching inventory. |
| `port-backlog.sh` | **exact (edit replay)** | Base full `cat` in `--home-jac-repos-jac-python-ops--/2026-08-25T21-38-26-898Z_01a03adc-3bd2-72df-a086-ce37fdde2022.jsonl`, then the successful family-routing edit in `2026-08-26T01-30-58-740Z_01a03bb1-1f34-7788-8500-ddf036d3d924.jsonl`; 3,126 bytes, matching inventory. |
| `lane-keeper.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T01-30-58-740Z_01a03bb1-1f34-7788-8500-ddf036d3d924.jsonl`: full `cat`, 3,337 bytes, matching inventory. |
| `census-keeper.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T08-03-27-956Z_01a03d18-7454-7757-9c13-d88d5e9f8441.jsonl`: full read, 2,466 bytes, matching inventory. |
| `warm-jac-cache.sh` | **exact** | `--home-jac-repos-jac-python-ops--/2026-08-26T06-35-41-002Z_01a03cc8-164a-7d02-be5a-9a67257c370a.jsonl`: complete `cat` before the `===` marker, 1,690 bytes, matching inventory. |

Recovered shell scripts have executable mode. `OWNERS` has mode 0644.

## Syntax validation

`bash -n` passed for all recovered shell scripts:

- `fleet-queue.sh`
- `fleet-supervisor.sh`
- `fleet-watchdog.sh`
- `worker-prompt.sh`
- `desk-prompt.sh`
- `seed-backlog.sh`
- `gapq-bridge.sh`
- `port-backlog.sh`
- `lane-keeper.sh`
- `census-keeper.sh`
- `warm-jac-cache.sh`

## Not recovered

These files were present in the pre-deletion inventory, but no complete source
or deterministic full edit history was found. They were not invented.

| File | Evidence found | Result |
|---|---|---|
| `tmp-janitor.sh` | Calls from supervisor/watchdog and repeated post-deletion ENOENT messages; inventory size 4,481 bytes. No content-bearing read/write. | **unrecoverable** |
| `capture-state.sh` | Middle line-range read and later cursor-agent edits only; no complete base file. | **unrecoverable without guessing** |
| `farm-orphan-reaper.sh` | References and short head fragments only. | **unrecoverable without guessing** |
| `audit.sh` | Inventory/reference only; the committed `audit_fields*.py` tools are different files. | **unrecoverable** |
| `snap.sh` | Executions only; no content-bearing read/write. | **unrecoverable** |

The deleted non-shell documents (`README.md`, `RUNBOOK.md`, `BACKLOG.md`, archive
and capture directories) were outside the requested shell-tooling recovery and
were not recreated. `DESK.md` was preserved and left unchanged.

## Fresh reimplementation files

`fleet-worker.sh` and `worker-protocol.md` were left byte-for-byte untouched.
They were created after deletion and do not appear in the original inventory.
The recovered original design instead uses `fleet-supervisor.sh` plus
`worker-prompt.sh` to invoke one prompt per process directly. Therefore the
recovered pair supersedes the fresh pair's orchestration role, but the fresh
files remain available for comparison.

## Most valuable transcript

`/home/jac/.pi/agent/sessions/--home-jac-repos-jac-python--/2026-08-26T20-25-09-974Z_01a03fbf-8056-7388-b1a2-826dbad64613.jsonl`

It contains the full supervisor before migration, every successful edit that
produced the final cursor/composer-2.5 runtime with the `RUNTIME=pi` rollback,
the final full `worker-prompt.sh` authoring write, a full `desk-prompt.sh` read,
and the original syntax/preflight checks.
