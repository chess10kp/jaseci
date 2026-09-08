# DESK state — pass 2026-09-07 (layer3_import ALL GREEN)

## desk pass 2026-09-07/08 (fleet restart + DELETE_DEREF cutover fix)

- Fleet restarted (`fleet-supervisor.sh start`, cursor runtime): 4 lean claimer
  shells (w2/w3/w4/w7) idle; w6/w8 status lines are known ghost-busy residue.
  Lanes were fully drained — seed-backlog items all in done/ with landed
  results; gapq-bridge +0 (1 known); port-backlog +0.
- Backlog reconciled: layer3 P0.5 marked RESOLVED (104/0); its 7 stale enqueues
  pruned from seed-backlog.sh so refill can't re-seed landed work.
- Full gates RED on e769c7375 (run 34185004683, Phase 6 VM conformance,
  198p/1f): "vm: DELETE_DEREF unbinds closure cell". Root cause probe-verified:
  1c6a63f14 added the run_frame arm + emission but skipped the
  opcode_allowlist regen (the header's documented pairing rule) — host opcode
  62 rejected at marshal load (`unknown opcode 62`). Seeded mech
  170-opcode-allowlist-delete-deref; worker4 landed
  wp4/opcode-allowlist-delete-deref@9f42eafa4 (desk-verified 199/0), merged
  ff to jac-python @9f42eafa4. Gate confirmation CI pending.


## layer3_import COMPLETE (104 passed / 0 failed)
- Full CPython-stdlib boot in-VM under layer3 now green. Final root causes
  (all verified minimal-repro / byte-diff, then full-suite):
  1. namedtuple factory silent-None: visit_try folded module return when
     try/except was last stmt of an `if` body (tail_join != None ignored);
     + visit_if missing JUMP_FORWARD to join before deferred handler
     machinery (compiler_exc.jac ~1547, compiler_loops.jac ~389/~427).
  2. namedtuple `_make` identity split: `tuple.__new__` → PyNativeNew built
     guest PyUserObj for guest classes while constructor path minted host
     standin instances — repr/==/field descriptors diverged. Fixed: tuple-base
     PyNativeNew with guest PyClass target routes host-side via standin
     (_jac_builtin_new) — ceval_defs.jac PyNativeNew.tp_call.
  3. Bridge: _jac_standin_install_methods copies non-function attrs (field
     descriptors resolve host-side); _jac_standin_method/_dunder fallback via
     _jac_guest_cls_ for host-created standin instances.
  4. Earlier same-session: emit_name_store/delete deref-first + OP_DELETE_DEREF;
     loop-try normal-exit; loop_except_depth_bump ×3; star-import
     CALL_INTRINSIC_1 2.
- Gates: layer3_import 104/0; compiler_slice 297; _matrix 36; boot cluster 76.
  All DBG instrumentation removed; session probes deleted.

## CRITICAL PATH (P4)
- **jac-py merge gate**: GREEN @b1e92cf55 (origin/jac-python tip). 34052233556 green @6e79055ed, then +1 commit.
- **jac-py gates (full)**: 34046113204 RED on bd86f2454 — only failing step "Layer 4 oracle contract tests": 2 pyc-first failures (builtin subclassing KeyError '5'; set literal update/sorted). BOTH FIXED on tip (42a1b19d3, b1e92cf55) — re-dispatch pending merge-gate green.

## landed this pass (desk, direct)
| commit | what |
|--------|------|
| 6e79055ed | fix(jac-py): parse f-string concatenations through JoinedStr parts — pa_concatenate_strings dropped lone/mixed JoinedStr; every f-string atom failed rule_strings (root of exec-module-parse-gap; functools.py first f-string L282 killed the module parse) |
| 42a1b19d3 | fix(jac-py): refill set order list on update methods — PySetMethod *_update rebound items only; order stale → sorted(s) missed updated members |
| b1e92cf55 | fix(jac-py): compare int against int-subclass user objects numerically — PyInt.tp_richcompare now unwraps boxed bases via __index__ (PyLong_Check analog); fixes d[MyInt(5)] KeyError |

## regression forensics (obj lane)
- Both pyc-first reds introduced by 19cc134a9 (ordered-slots rewrite, 09-05 23:48); Track B/set-literal were green @d3e1d55a1 (verified: 40 passed on that checkout).
- 19cc134a9 state measured directly: 37 passed / 1 failed / 2 error.
- Digests were NEVER the issue (digest(MyInt(5)) == digest(5) == "n:5" post-rewrite) — the misses were (a) stale order list on update writeback, (b) concrete-False int richcompare vs boxed subclass.

## layer3_import state (96p/8f → 98p/6f mid-pass; codegen lane still burning)
- Root causes this pass (all verified by minimal repro + oracle byte-diff):
  1. operator.py boot = UAdd unlowered (3.14 dropped UNARY_POSITIVE; now
     CALL_INTRINSIC_1 5 in compiler_emit.jac visit_expr + visit_comp_elt).
  2. "instructions after terminator" = nested-if join adoption
     (compiler_codegen.jac visit_stmts) + dropped stmt_cont.terminated on
     adopted joins (compiler_loops.jac visit_if ×4 paths). types.py OK.
  3. reprlib/collections parse = grammar2jac lookahead-token leak masked by a
     rule_atom swap in _patch_store_target_rules + missing PEP 701 format-spec
     tokenizer mode (`f'{x:x}'`) + missing implicit NEWLINE at unterminated EOF.
     Both modules parse clean now; positions host-exact.
  4. Same-name nested def/class symtable children matched name-only → second
     body compiled against first's sym block (operator.py attrgetter genexp).
     Now positional (sym_function_child_at / sym_class_child_at).
  5. Parity bonuses: CO_METHOD flag, CO_NESTED, nested qualnames (17-shape host
     verified); implicit f-string join seams folded (repr_int 9-value JoinedStr).
- Remaining 6 → RESOLVED 09-07: functools `with`-guard return + contextlib
  SEND-loop depth (loop_except_depth_bump + loop-try normal-exit fixes);
  namedtuple underflow (visit_try tail-fold + visit_if join jumps) — see top.

## verification this pass (addendum, 09-06)
- parser_p3: 12 passed (6 new regression tests). compiler_slice: 295 passed
  (2 new oracle-diff bands). grammar2jac --check: up to date (regenerated
  parser.jac). layer3_import: 98p/6f (failures moved deeper, not fixed).

## verification this pass
- grammar2jac --check: up to date.
- compiler_slice: 293 passed (was 291p+2f+1e — 2 pre-existing reds now fixed).
- pyc_first filtered: 40 passed. collision pins: 79 passed. density gates P1/P2/P2w: green.

## in-flight
| worker | lane | task |
|--------|------|------|
| w4 | mech | 250-tail-codegen-audit (hb-fresh; 240 done) |

## failed
50/50 HOLD — 49 backup drain-only (do not requeue) + 900 SUPERSEDED (baselines on origin; hold-failed skip).

## next
1. Re-dispatch jacpy-gates.yml on b1e92cf55 once merge gate green → expect P0 "full gates green on tip" UNBLOCKED.
2. layer3_import DONE (104/0) — keep green on merge; no further burn-down.
3. Keep pyc-first Track B/d-e green — do not re-seed.
