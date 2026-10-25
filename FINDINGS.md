# Formatter performance verification

## Summary

| Ticket | Verdict | Evidence |
|---|---|---|
| #8489 | **Improved in this worktree; still superlinear** | Reference binary: 5,000 terms in 50.047 s. Worktree source after the fix: 5,000 terms in 4.205 s and 10,000 in 15.352 s. The fitted exponent over 2,000–10,000 terms is about 1.69. |
| #9421 | **FIXED / not reproduced** | Reference formatter processed a valid 3,000-line file in 1.480 s: **2,027 lines/s**, versus the ticket's reported ~350 lines/s/file. This is a single-file sample, not a whole-repository benchmark. |

## Method and baseline

All generated inputs were in fresh `/tmp/jac-fmt-perf-*` scratch directories, outside repository trees. Each sample ran in a separate process with `fmt -j 0`; timings include CLI startup. Inputs used valid Jac assignments and a left-associated `+` chain.

Reference executable: `/Users/jaseci/repos/jac-green-verify/jac/zig-out/bin/jac` (read-only).

| Expression terms | Reference elapsed | Exit |
|---:|---:|---:|
| 100 | 0.862 s | 0 |
| 250 | 1.078 s | 0 |
| 500 | 1.175 s | 0 |
| 1,000 | 2.359 s | 0 |
| 2,000 | 7.540 s | 0 |
| 4,000 | 34.809 s | 0 |
| 5,000 | 50.047 s | 0 |

The reference log-log least-squares exponent is **1.63** over 500–4,000 terms and **1.94** over 1,000–4,000 terms. The valid-input exit-1 regression is not reproduced. A valid 3,000-line file took 1.480 s (2,027 lines/s); `check -p` on a valid 2,000-term expression took 0.54 s, indicating most of the original delay was in formatting rather than parsing.

## Worktree fix and measurements

Root cause: `jac/jaclang/compiler/tools/impl/doc_ir_gen_pass.impl.jac`, `DocIRGenPass.exit_binary_expr`. For each node in a same-operator binary chain, the method recursively flattened the entire same-operator subtree. A long left-associated expression revisited operands repeatedly, causing quadratic DocIR generation.

The fix has two parts. First, same-operator interior nodes no longer flatten their whole subtree. Second, those nodes do not create a fallback DocIR: their parent flattens the chain and reads only leaf operands and operators, so the intermediate documents were unused. Different-operator subexpressions still get normal DocIR.

Measurements with Python 3.14 source launcher and the worktree compiler:

| Terms | Before worktree fix (reference) | After first DocIR fix (source) | After skipping unused interior DocIR (source) |
|---:|---:|---:|---:|
| 2,000 | 7.540 s | 0.946 s | 1.003 s |
| 5,000 | 50.047 s | 3.938 s | 4.205 s |
| 10,000 | not measured | 14.606 s | 15.352 s |

The source timings are not a strict apples-to-apples binary comparison. They include Python CLI startup and a first-run cache warmup was excluded. The extra change did not materially change the exponent: log-log least-squares fit across the three final samples is **1.69** (2,000–10,000 endpoint exponent **1.70**). The 5,000-term sample improved about **11.9x** from the reference run, and the first DocIR fix alone was about **12.7x** on that particular source run. Remaining growth is still superlinear; the goal of flat scaling was not met.

`check -p -j 0` on the same source-generated shapes took 0.345 s / 0.391 s / 0.499 s at 2,000 / 5,000 / 10,000 terms. This points away from parsing as the dominant remaining cost and toward DocIR generation/rendering. A Python cProfile attempt was not usable because the CLI exits before the profiler writes its output. Further attribution is unresolved.

## Build status

Ran `zig build fetch-typeshed` and `zig build fetch-llvm` in `jac/`; both dependencies were already present. Ran the requested `zig build -j4`. It timed out after 30 minutes during the launcher `jac-stub` build, and `jac/zig-out/bin/jac` was not produced. The worktree Python 3.14 source launcher ran the formatter measurements above, but an end-to-end measurement with the requested built binary / native-first parse path is not available.
