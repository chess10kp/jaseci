# DESK state — pass 2026-09-08

## gates
- **merge gate**: pending push @c2bc9ada4 (repair on top of d23b36e80)
- **full jac-py gates**: RED @9f42eafa4 (run 34187063273) — layer10
  `for_break_inside_try_matches_oracle` 1f (139p/1f). Blocks hold-failed-19 requeue.
- 185 LANDED @d23b36e80 + repair @c2bc9ada4: oracle parity reached
  (co_code/linetable/stacksize). Local: layer10 140/140, layer9 203/203,
  vm_conformance 199/199, flowgraph 29/29.
- Re-dispatched jacpy-gates.yml on tip @c2bc9ada4.

## in-flight
| worker | lane | task |
|--------|------|------|
| w3 | exceptions | 185-loop-try-break-inline-v2 (hb-fresh) |

## idle (no real pending)
w2 objects, w4 mech, w6 converter, w7 typesys, w8 census

## failed
50/50 HOLD — 49 backup drain-only (do not requeue) + 900 SUPERSEDED (baselines on origin).

## recent landed (awaiting CI / merge gate on branch push)
| lane | branch@sha | task |
|------|------------|------|
| mech | wp4/250-tail-codegen-audit@085501473 | 250 done |
| mech | wp4/240-for-else-cfg-audit@5ded6bf8c | 240 done |
| mech | wp4/opcode-allowlist-delete-deref@9f42eafa4 | 170 merged tip |
| exceptions | worker3/180-loop-try-break-order@2e2d25998 | 180 done |
| objects | worker2/210-dict-set-collision@b89bee3 | 210 done |
| typesys | worker7/230-class-mro-surface@19d797a63 | 230 done |

## next
1. w3 lands 185 → verify branch CI → merge exceptions family.
2. w4 lands 250/240 branches → verify CI → merge mech family.
3. Full gates green on tip → GATES_GREEN=1 hold-failed requeue (skip 900).
