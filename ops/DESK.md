# DESK state — pass 2026-09-08 (evening)

## gotchas (standing — read first)
- **Cache isolation is mandatory**: sibling sessions share `~/.cache/jac` and
  poison bootstrap entries mid-run (hangs at every commit, VM spins). Run all
  jac commands with `XDG_CACHE_HOME=$REPO/.xdg-cache`. Full writeup:
  `ops/local-cache-isolation.md`. Never bare `git add -A` (swept 113 MB
  runtime binaries at fa0e4dbd5; push bounced).
- Local inexplicable hang → CI is the arbiter (sealed binary); don't bisect
  locally.

## gates
- **upstream merge LANDED**: fa0e4dbd5 = 075453d07 + upstream/main (147
  commits, #9022 semantics/native migration). Merge `fa0e4dbd5` pushed.
- 185 LANDED @d23b36e80 + repair @c2bc9ada4: oracle parity reached
  (co_code/linetable/stacksize). Merged-tree local (isolated cache):
  layer10 140/140, layer9 203/203, vm_conformance 199/199, flowgraph 29/29.
- Full jacpy-gates.yml re-dispatched on fa0e4dbd5 (run 34285012919) —
  watching libtest harness (difflib snippet) as the open verdict.

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
