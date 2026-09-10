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
  (co_code/linetable/stacksize).
- Post-merge CI repair chain (each verified locally before dispatch):
  f812832cd is_pyobj_type bool (E1002 strict payload check);
  1a3b82141 skip JIR precompile (seal OOMs runner, SIGTERM ~20m);
  9f950386c woven Module.init accepts campaign fields (decl/impl shadow);
  01e051a03 JAC_PAYLOAD_SKIP_KERNEL (native kernel build exceeds runner
  memory — fork fails outright; demotion warnings in transform.impl are
  upstream's own and benign).
- Full jacpy-gates.yml on 01e051a03: run 34297981315 — setup PASSED (5m36s,
  skip-precompile+kernel-skip); failed Layer 4 → fixed by JAC_COMPILER_LIB=off
  (a27c75e78) → run 34298516569 failed P2 waves lifts → fixed by _role_set
  (b0f5e950c) → run 34301431456 reached libtest, 20m step-timeout with zero
  marks (true hang, confirmed CI-side).
- **OPEN REGRESSION — libtest difflib/import spin (workpackage-ready)**:
  introduced by 1c6a63f14 ("carve try/await exception tables and emit
  DELETE_DEREF", Sep 7) — proven by isolated-cache probe: b1e92cf55 PASSES
  (463s exit 0), 1c6a63f14 HANGS (adjacent commits, single variable).
  Repro: difflib-only slice of layer_p2_libtest under `jac test`; guest VM
  spins 98% CPU importing host stdlib through the layer3 shim path
  (set_layer3_active(True) + IMPORT_NAME routing). Prime suspect: the same
  commit's ceval_bridge_guest stand-in recovery path (host-created guest
  stand-ins, e.g. namedtuple via tuple.**new**) re-entering trampolines.
  Layer lanes don't cover the intersection (layer3 shim routing × bridge
  recovery) — that's the census gap. Fix owner: VM/bridge debugging
  session; instrument ceval find_handler + stand-in trampoline entry.
- **Decl/impl parity sweep**: unitree decl inits vs woven roles.impl inits
  must match param-for-param — the impl shadows the decl. Sweep script
  pattern in this file's history; zero mismatches remain.

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
