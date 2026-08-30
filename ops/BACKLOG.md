# jac-python backlog

Human source of truth for fleet refill (`seed-backlog.sh`). Census gaps are
seeded separately via `gapq-bridge.sh`; porting frontier via `port-backlog.sh`.

**Tip:** edit this file, then run `./seed-backlog.sh` (idempotent — skips names
already in any lane). Parser-only items stay here and are **not** auto-seeded.

---

## Recently landed (do not re-seed)

| Item | Commit / gate | Notes |
|------|---------------|-------|
| compiler_slice band11 parity | `bf069783e` | **286/286** `jac test jac-py/jacpython/compiler_slice.jac` |
| param_count / TO_BOOL / with-return unwind | `892ef6261` | prior orchestration batch |
| except\* nested in plain except handler | `bf069783e` | exception-table + double POP_EXCEPT path |
| module AnnAssign `__annotate__` on early terminate | `bf069783e` | |
| comprehension filter call push_null (`abs(y)`) | `bf069783e` | |
| exception-table varint decode | `bf069783e` | `pycode_diff.jac` |

---

## P0 — CI / merge gate

| ID | Lane | Summary | Gate / repro |
|----|------|---------|--------------|
| gates-full | census | Full `jacpy-gates.yml` green on tip (`bf069783e+`) | GitHub Actions jac-py P4 gates |
| hold-failed-19 | desk | Triage 19 failed queue items (HOLD until full gates green) | `ops/DESK.md` |

---

## P1 — Exception control-flow (compiler_exc / flowgraph)

Blocks many real programs; several are hard **crashes** not byte diffs.

| ID | Lane | Summary | Gate / repro |
|----|------|---------|--------------|
| cfg-try-trailing-code | exceptions | `try`/`except*` followed by more module/fn code → `verify_cfg: instructions after terminator` | `compile_parsed_exec("try:\n    x=1\nexcept ValueError:\n    a=1\nprint(x)\n")` |
| try-finally-return | exceptions | `try`/`finally` with `return` in body (fn scope) → codegen crash | BAND12 #3 |
| try-finally-module | exceptions | `try`/`finally` at module scope → post-assemble crash | BAND12 #4 |
| break-continue-in-try | exceptions | `break`/`continue` inside `try` in loop → stackdepth fallthrough crash | BAND12 #5 |
| loop-else-cfg-tail | exceptions | `for`/`else`, `while`/`else` then more code → CFG terminator crash | BAND12 #6 |
| co-names-else-order | exceptions | Fresh names in `try`/`else` get wrong `co_names` index vs CPython AST order | BAND11 learnings #3 |

---

## P2 — Bytecode / assembler parity (high leverage)

| ID | Lane | Summary | Gate / repro |
|----|------|---------|--------------|
| assembler-nested-linetable | mech | Nested def/class linetable wrong while `co_code` exact (~35 shapes) | BAND12 #2; `notes/BAND12_FRONTIER.md` |
| fstring-end-to-end | mech | Native f-string tokenize + JoinedStr lowering + ceval FORMAT_VALUE/BUILD_STRING | BAND12 #1; band12 tests in `compiler_slice.jac` (hand-built AST green; native parse not) |
| ceval-check-eg-match | mech | `CHECK_EG_MATCH` in ceval — except\* compiles but won't run | BAND11 learnings #4 |
| async-with-import | exceptions | `async with` → NameError `await_send_loop` missing import in `compiler_exc.jac` | BAND12 #7 (S crash fix) |
| cond-expr-jumps | exceptions | `1 if flag else 2` module scope co_code+linetable diverge | BAND12 #11 |
| augassign-attr | exceptions | `o.a *= 2` fn-scope co_code diverge | BAND12 #12 |
| match-in-fn | exceptions | `match` in fn scope (tuple/list/guard/mapping) co_code+linetable | BAND12 #10 |
| comprehension-star-unpack | exceptions | `[*ps]` in comprehension elt co_code+exctab | BAND12 #19 |
| kwonly-defaults | exceptions | `def f(*, k=1)` wrong defaults const | BAND12 #13 |
| lambda-defaults | exceptions | lambda with defaults — missing defaults tuple const | BAND12 #14 |
| decorator-with-args | exceptions | `@deco(1)` missing const / co_code diverge | BAND12 #15 |
| global-write | exceptions | `global` stmt write from fn shifts module bytes | BAND12 #16 |
| import-alias-level | exceptions | `import a.b as c`, `from . import x` | BAND12 #17 |
| class-slots | typesys | `__slots__` class-body machinery + runtime enforcement | BAND12 #18; ties typesys/objects |

---

## P3 — Literal / parser fidelity (mostly parser-owned)

**Not auto-seeded** — separate branch or parser lane when one exists.

| ID | Summary | Gate / repro |
|----|---------|--------------|
| parser-8473-trailing-kwarg-star | `f(a=1, **d)` — native parser drops trailing `**` after named kw | BAND10 |
| parser-try-except-span | try/except\* rules set bad `end_lineno`/`end_col_offset`; compiler uses `trystar_*_loc` workarounds | BAND11 #1 |
| parser-posonly-after-default | `def f(a, b=2, /)` parse fails | BAND12 #20 |
| string-escape-decode | `\uXXXX` stored raw not decoded | BAND12 #8 |
| bytes-literal-tag | `b'abc'` materializes as str-tagged const | BAND12 #9 |

---

## P4 — Runtime / objects (existing seeded items)

See `seed-backlog.sh` for live enqueue text:

- objects `010` slice step-zero, `020` bool index, `040` slice object subscript
- exceptions `050` exc class synthesis (`__cause__` attr)
- mech `030` range bridge (design-first), `120` deadcode cleanup
- converter `300` superseed bridge, `310` conversion wave
- typesys `150` type_slots verify
- census `130` pr6973 corpus

---

## P5 — Runtime probes (not compiler; ledgered separately)

| Item | Owner | Notes |
|------|-------|-------|
| repr/str dispatch | objects/walker | `str(P())` → `'None'` when only `__repr__` defined | BAND12 item 53 |
| slice richcompare | objects | `slice(1,2)==slice(1,2)` False | BAND12 item 54 |

---

## References

- `jac-py/BAND11_SLICE_LEARNINGS.md` — except\* / try lowering notes
- `jac-py/BAND12_SLICE_LEARNINGS.md` — if present
- `jac-py/notes/BAND12_FRONTIER.md` — 53-shape differential sweep (Aug 2026)
- `.github/workflows/jacpy-gates.yml` — full gate list
