#!/usr/bin/env bash
# seed-backlog.sh — populate the FAMILY lanes from the open backlog (model A).
# Fully idempotent: enqueue skips any task name already present in any lane, so
# this is safe to run repeatedly and on every refill tick. To DROP an item,
# delete its pending file. Census gaps are seeded separately by gapq-bridge.sh.
#
# Lanes = families (see OWNERS): objects exceptions mech converter typesys census.
set -euo pipefail
cd "$(dirname "$0")"
source ./fleet-queue.sh

# ---- objects lane (worker2: objects.jac) ----------------------------------
enqueue objects 010-slice-zero-step <<'EOF'
family: objects | ref: PR#6973 A.1
objects.jac:1591 slice_indices() missing step==0 guard; l[5:1:0] hangs VM.
Raise ValueError "slice step cannot be zero" + oracle test.
EOF
enqueue objects 020-bool-index <<'EOF'
family: objects | ref: PR#6973 A.4
Route PyStr/PyBytes/PyTuple.mp_subscript through to_index() so "abc"[True]=='b'.
EOF
enqueue objects 040-slice-object-subscript <<'EOF'
family: objects
Dynamic slice(1,7,2) value never reaches slice path in mp_subscript.
Shared fix with slice-assignment: mp_subscript/ass/del all accept PySlice.
EOF

# ---- exceptions lane (worker3: exceptions_core.jac + compiler exc paths) ---
enqueue exceptions 050-exc-class-synthesis <<'EOF'
family: exceptions
e.__cause__.__class__.__name__ raises AttributeError. Route __cause__/__context__
(audit all exc attrs) through PyExceptionType synthesis. Unblocks pin-ok-exc-chaining.
EOF

# ---- mech lane (worker4: runtime-gap / bridge-policy) ----------------------
enqueue mech 030-range-bridge <<'EOF'
family: mech (bridge-policy) | DESIGN-FIRST
from_host has no range branch; range(10**9) materializes (memory bomb), no
.start/.stop/.step. Native PyRange (O(1) len/contains/index/slice) OR preserve
host range through the bridge. Agree the design before landing.
EOF
enqueue mech 120-pr6973-deadcode <<'EOF'
family: mech (cleanup) | ref: PR#6973 C
Strip dead code shipped as runtime bloat (detail: logs/runtime-lane-brief.md).
EOF

# ---- converter lane (worker6: converter throughput, jac-py/tools) ---------
enqueue converter 300-superseed-bridge <<'EOF'
family: converter | src: ~/notes/WORK-QUEUE.md "converter + suites"
Held relands (/var/tmp/laneb-out): random/sort ~19 pins blocked on a super().seed
bridge gap. Diagnose the super().__init__/seed bridge and unblock the relands.
EOF
enqueue converter 310-conversion-wave <<'EOF'
family: converter | src: ~/notes/WORK-QUEUE.md
Next conversion wave: pick highest-value suites from the census gap queue
(results-canary/gap_queue.json, priority=suites*severity) and convert them.
Coordinates with census lane (worker8) — take suites census has NOT claimed.
EOF

# ---- typesys lane (worker7: type-system / metaclass) ----------------------
enqueue typesys 150-typeslots-verify <<'EOF'
family: typesys | ref: Next-up #2
type_slots.jac is UNTRACKED debris; PyType_Ready slot lifecycle NOT landed
despite a stale "done" claim. Verify at the call site, then land or delete.
EOF

# ---- census lane (worker8) — corpus/gates integrity rides here ------------
enqueue census 130-pr6973-corpus <<'EOF'
family: census | ref: PR#6973 D
Corpus/gates integrity check (detail: logs/runtime-lane-brief.md).
EOF

# Note: parser #8473 (trailing **d after named kwargs) has NO family owner and is
# parked "separate branch only" — kept in BACKLOG.md, not auto-seeded.
echo "--- seeded family lanes ---"; snapshot | sed -n '/== pending ==/,/== in-flight ==/p'
