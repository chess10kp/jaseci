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

enqueue objects 030-dict-set-hash-buckets <<'EOF'
family: objects | ref: PLAN.md #3 (independent P0 correctness)
dict/set storage loses unequal keys with identical hashes (single-value map).
Ordered hash buckets: same-hash unequal keys coexist; equal keys overwrite in
place keeping the first key object; deletion removes only the match; insertion
order + iterator versioning intact. DONE = collision pins + existing dict pins.
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

enqueue exceptions 095-dict-stackdepth-fallthrough <<'EOF'
family: exceptions | ref: layer3_import `native objects expose __dict__`
CFG stackdepth crash: "Invalid CFG, inconsistent stackdepth at block 2 via
fallthrough (want 1 have 2)" compiling the layer3 __dict__ test body.
flowgraph.jac fallthrough edge. DONE = that layer3 test compiles + passes in CI.
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

enqueue mech 141-exec-module-parse-gap <<'EOF'
family: mech | ref: layer3_import frontier (DESK 2026-09-02)
product_compile.jac:85 "failed to parse exec module" on real stdlib sources:
functools.wraps def + namedtuple-defaults source. Highest-value layer3 red —
blocks functools/contextlib/collections boots. DONE = both sources parse +
execute natively (layer3 tests green).
EOF

enqueue mech 142-namedtuple-unary-op <<'EOF'
family: mech | ref: layer3_import namedtuple trampoline
ceval: NotImplementedError "unsupported unary operator" while the namedtuple
dynamic class boots (layer3_import.jac:338 trampoline). Find the missing
UNARY_* op, implement + oracle pin. DONE = layer3 trampoline test green.
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

enqueue mech 180-compile-context <<'EOF'
family: mech | ref: PLAN.md #4
Compiler state is process-global + not exception-safe (product_compile_active,
pending_break_finishes, statement handlers, ceval op registries, traceback/
module/exec depth). Move to a per-compilation context with exception-safe
cleanup. DONE = failed-then-valid, recursive, repeated compilation all green.
EOF

enqueue mech 185-bridge-lifetime <<'EOF'
family: mech (bridge-policy) | ref: PLAN.md #6
Bridge stand-in caches can retain guest objects. Make caches interpreter-owned
or weakly cleaned; add stale-id() protection. DONE = create/release churn of
many guest classes/objects without retention; live-view deviations documented.
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

enqueue census 140-collections-boot <<'EOF'
family: census | ref: layer3_import.jac:224
Behavioral: collections package + transitive deps must boot in-VM. Diagnose the
first failing bind/opcode vs host oracle; fix or split into precise gap tasks.
DONE = layer3 collections boot green (or named follow-ups seeded).
EOF

enqueue census 145-unittest-closure-boot <<'EOF'
family: census | ref: layer3_import.jac:249
Behavioral: leaf modules across the unittest closure boot proxy-free. Diagnose
vs host oracle. DONE = layer3 unittest-closure test green or split out.
EOF

enqueue census 150-from-import-star <<'EOF'
family: census | ref: layer3_import.jac:292
Behavioral: from-import-star binds a module's public names (skip _-prefixed).
Diagnose IMPORT_STAR path vs oracle. DONE = layer3 from-import-star green.
EOF

enqueue census 155-functools-contextlib-boot <<'EOF'
family: census | ref: layer3_import.jac:467 | BLOCKED-BY mech/141 parse gap
Behavioral: functools + contextlib boot in-VM (wraps / __dict__ / type-keyed
dispatch). Re-diagnose after mech/141 lands; then fix residual binds.
DONE = layer3 functools+contextlib boot green.
EOF

enqueue census 160-bootstrap-tripwire <<'EOF'
family: census | ref: DESK 2026-09-02 next-4 (bootstrap seams)
pyc_first bootstrap transport + dataclassmodule.jac template compiles bypass
note_host_source_marshal — instrument both so NATIVE mode fails loudly there.
DONE = tripwire test covers both seams.
EOF

enqueue census 165-blocking-gates <<'EOF'
family: census | ref: PLAN.md #7
Make CI prove the cutover: import-cycle gate blocking, conformance-dashboard
check blocking, sealed-binary native smoke test, oracle/native/delegated result
separation. DONE = gates fail on cutover regression, not just report it.
EOF

# Note: parser items (#8473 trailing **d, try/except span ends, posonly-after-default,
# string escapes, bytes literal tags) have NO family owner — kept in BACKLOG.md only.
echo "--- seeded family lanes ---"; snapshot | sed -n '/== pending ==/,/== in-flight ==/p'
