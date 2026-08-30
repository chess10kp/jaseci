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

enqueue exceptions 060-cfg-try-trailing-code <<'EOF'
family: exceptions | ref: BAND11 learnings #2, BAND12 #6 family
visit_try/visit_try_star tail: try/except followed by more module or fn-level code
crashes verify_cfg ("instructions after terminator").
Repro: compile_parsed_exec("try:\n    x = 1\nexcept ValueError:\n    a = 1\nprint(x)\n")
Gate: jac test jac-py/jacpython/compiler_slice.jac (band11 else/trailing shapes when added)
      + jac test jac-py/jacpython/layer_flowgraph_verify.jac
EOF

enqueue exceptions 070-try-finally-return-crash <<'EOF'
family: exceptions | ref: BAND12 #3-#4
try/finally with return in body (fn scope) crashes codegen ("list index out of range").
Module-scope try/finally can crash post-assemble ("NoneType has no len()").
Gate: jac test jac-py/jacpython/layer10_product_controlflow.jac
      jac test jac-py/jacpython/compiler_slice.jac
EOF

enqueue exceptions 075-break-continue-in-try <<'EOF'
family: exceptions | ref: BAND12 #5
break/continue inside try within a loop: "inconsistent stackdepth at block via fallthrough".
Gate: jac test jac-py/jacpython/layer10_product_controlflow.jac
EOF

enqueue exceptions 080-loop-else-cfg-tail <<'EOF'
family: exceptions | ref: BAND12 #6
for/else and while/else followed by more code: CFG terminator crash (generalizes try-tail bug).
Gate: jac test jac-py/jacpython/layer10_product_controlflow.jac
EOF

enqueue exceptions 085-co-names-else-order <<'EOF'
family: exceptions | ref: BAND11 learnings #3
try/else binding fresh names: co_names order is body->orelse->handlers; CPython uses AST order.
Add a compiler_slice pin with distinct orelse vs handler names; match oracle co_names.
Gate: jac test jac-py/jacpython/compiler_slice.jac
EOF

enqueue exceptions 090-async-with-import <<'EOF'
family: exceptions | ref: BAND12 #7
async-with: NameError await_send_loop used at compiler_exc.jac without import from compiler_emit.jac.
Land the one-line import first; then align async-with co_code vs oracle.
Gate: jchk jac-py/jacpython/compiler_exc.jac ; jac test jac-py/jacpython/layer10_product_controlflow.jac
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

enqueue mech 140-assembler-nested-linetable <<'EOF'
family: mech | ref: BAND12 #2
Nested def/class scopes: co_code exact vs oracle but linetable diverges (~35 shapes).
Fix assembler.jac PEP 626 location-table writer (single root cause).
Gate: jac test jac-py/jacpython/compiler_slice.jac ; spot-check layer8/layer9 nested fns
EOF

enqueue mech 150-ceval-check-eg-match <<'EOF'
family: mech | ref: BAND11 learnings #4
Implement CHECK_EG_MATCH in ceval.jac so except* (ExceptionGroup) runs after compile parity.
Gate: jac test jac-py/jacpython/test_p1exc_prep_reraise.jac ; runtime except* probe
EOF

enqueue mech 160-fstring-end-to-end <<'EOF'
family: mech | ref: BAND12 #1
f-strings: tokenizer still plain STRING; need parse -> JoinedStr -> FORMAT_VALUE/BUILD_STRING
lowering + ceval. Hand-built AST band12 tests in compiler_slice.jac are the oracle pins.
Gate: jac test jac-py/jacpython/compiler_slice.jac (band 12 f-string tests) + native f'...' exec
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

# Note: parser items (#8473 trailing **d, try/except span ends, posonly-after-default,
# string escapes, bytes literal tags) have NO family owner — kept in BACKLOG.md only.
echo "--- seeded family lanes ---"; snapshot | sed -n '/== pending ==/,/== in-flight ==/p'
