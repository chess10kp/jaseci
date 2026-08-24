# except* / exception-group support -- implementation scope (CPython 3.14 semantics)

Status: DESIGN / SCOPE doc. No runtime edits made by this lane. Author:
docs-scope agent on `docs/except-star-scope`. Ground truth:
`reference/cpython` @ c63aec69bd (CPython **3.14.6**, see `CURRENT.md`):
`Python/codegen.c` (`codegen_try_star_except`, comment block ~line 2548),
`Python/bytecodes.c` (`CHECK_EG_MATCH` ~2821), `Python/intrinsics.c`
(`prep_reraise_star` ~237), `Objects/exceptions.c` (split/subgroup/
subset/`_PyExc_PrepReraiseStar` ~900-1760), `Python/ceval.c`
(`_PyEval_ExceptionGroupMatch` ~2295, `_PyEval_CheckExceptStarTypeValid`
~3353). Our side: `jac-py/jacpython/compiler_exc.jac` (TryStar lowering,
band-11, 4886e7de4), `jac-py/jacpython/ceval.jac` (exception arms),
`jac-py/jacpython/exceptions_core.jac` + `objects.jac` (exc hierarchy).

## 0. Where things stand today

| Piece | State |
|---|---|
| Compiler lowering of flat try/except* | LANDED (band-11), byte-layout pinned against host dis for bare/bound/multi/else shapes |
| `except*` + `finally` | compiler `codegen_fail` NotImplementedError |
| `try*` without `except*` | compiler `codegen_fail` |
| `except*` inside a plain except handler | compiler `codegen_fail` |
| `CHECK_EG_MATCH` VM arm | IN FLIGHT by another agent -- design against the contract in section 2.1, do not duplicate |
| `CALL_INTRINSIC_2` oparg 1 (PREP_RERAISE_STAR) | MISSING -- ceval.jac implements only oparg 2..5 |
| ExceptionGroup / BaseExceptionGroup objects | MISSING -- names exist only in the hierarchy table (`_EXC_PARENT`); no group type, no ctor, no split/subgroup/derive |
| RERAISE / POP_EXCEPT / PUSH_EXC_INFO arms | LANDED, incl. tb-cadence merge 3383d579d |
| ExceptionGroup->BaseExceptionGroup MI edge | LANDING on `origin/fix/exc-group-edge` (EXC_EXTRA_PARENTS table) |

Bottom line: the *compiler* already emits a full CPython-3.14-shaped
instruction stream including `CHECK_EG_MATCH` and
`CALL_INTRINSIC_2 PREP_RERAISE_STAR`; running any except* program fails
today at the VM/runtime layer. The remaining work is almost entirely
runtime-side.

## 1. Compiler side: emitted code today vs CPython

Our `visit_try_star_except` (compiler_exc.jac ~1645) mirrors
`codegen_try_star_except` one-for-one. The shared shape:

```
[nop] [body] [orelse] [normal-path continuation]
he:      PUSH_EXC_INFO ; BUILD_LIST 0 ; COPY 2        # [orig, res]
match_i: <E_i> ; CHECK_EG_MATCH ; COPY 1 ;
         POP_JUMP_IF_NONE nm_i                         # [orig, res, rest/match?]
pre_i:   store-to-V_i or POP_TOP                       # i>0 guarded by own NOT_TAKEN blk
b_i:     SETUP_CLEANUP-region body_i                   # inner handler span -> ce_i
x_i:     name=None/del cleanup ; LIST_APPEND 1 (last)  # success epilogue -> rr_match
ce_i:    name=None/del ; LIST_APPEND 3 ; POP_TOP ;     # body raised: exc into res
         LIST_APPEND 1 (last)
nm_i:    POP_TOP ; LIST_APPEND 1 (last)                # no match: rest flows on
rr_match: CALL_INTRINSIC_2 1 ; COPY 1 ; POP_JUMP_IF_NOT_NONE reraise
rr_nt/pt/pe: NOT_TAKEN ; POP_TOP ; POP_EXCEPT ; join-or-return
reraise: SWAP 2 ; POP_EXCEPT ; RERAISE 0               # rethrow prepared EG
unwind:  COPY 3 ; POP_EXCEPT ; RERAISE 1              # error inside he/match run
```

Exception-table spans (our `except_region` list, host entry order):
outer protect span -> `he`; `he`->first body under `unwind`; per-handler
inner spans -> `ce_i`; mid-run spans -> `unwind`; tail span `rr_pt`->`rr_pe`
-> `unwind`. Empty-body handlers coalesce spans via `merge_except_spans`
(matches host behavior where the inner SETUP_CLEANUP region vanishes).

Deltas vs CPython worth knowing (not blockers):

- CPython wraps the whole thing in SETUP_FINALLY/POP_BLOCK + SETUP_CLEANUP;
  we express the same protection as exception-table regions directly (same
  model as the rest of compiler_exc.jac). Stack depths in the region list
  already account for the extra runtime pushes (depths 1+nest .. 6+nest).
- CPython emits an explicit NOP at label L2 per handler for lineno purposes;
  we carry locations on the epilogue ops instead (host-dis verified).
- The last handler's LIST_APPEND folds into x/ce/nm tails; non-last handlers
  jump forward to the next match block. Matches host dis.

Open compiler gaps (each its own slice, do NOT bundle):

1. `try/except*/finally` -- needs the finally epilogue spliced onto every
   exit path (reraise, unwind, normal, each ce/nm). Same machinery as plain
   try/finally but with the group walk in between.
2. `except*` nested inside a plain `except` handler -- bridging
   `handler_fallthrough_*` bookkeeping with per-handler SETUP_CLEANUP spans.
3. `try*` (bare try with only except*, no else semantics change) -- trivial
   once 1/2 land; currently rejected outright.

## 2. VM side: opcode contracts

### 2.1 CHECK_EG_MATCH (arm owned by another agent -- contract only)

Stack `(exc_value, match_type -- rest, match)`:

1. Validate match_type: class or tuple-of-classes that are exception
   classes; REJECT anything subclassing BaseExceptionGroup
   (`_PyEval_CheckExceptStarTypeValid`) -- TypeError "catching classes that
   do not inherit from BaseException is not allowed" family messages apply
   for non-classes.
2. If exc_value is None: push None, None.
3. Full-instance match (`PyErr_GivenExceptionMatches(exc_value, match_type)`):
   if exc_value is itself a group, match = exc_value; if it is a NAKED
   exception, wrap it: `ExceptionGroup("", [exc_value])` with a fresh
   traceback built from the current frame. rest = None in both cases.
4. Otherwise partial match: if exc_value is a group, call its `split`
   method (must return a >=2 tuple, TypeError otherwise); match/rest are
   elements 0/1 or None. A non-group non-matching leaf: match = rest = None.
5. On a non-None match, mark it HANDLED (CPython `PyErr_SetHandledException`)
   -- this drives later implicit `__context__` chaining and bare `raise`.
   In our VM this maps to pushing onto the `exc_handling` stack (the
   PUSH_EXC_INFO arm's mechanism), NOT to dispatch_exception.

tb cadence: matching itself never raises on the success path; errors from
step 1/4 are real error events and must go through the normal
recover/dispatch path so the traceback gets its entry exactly where host
puts it.

### 2.2 CALL_INTRINSIC_2 oparg 1 -- PREP_RERAISE_STAR (MISSING, ours)

Operands `(lhs=orig, rhs=excs_list)`; result replaces TOS. Semantics =
`_PyExc_PrepReraiseStar(orig, excs)` (section 3.3). Pure computation: no
stack surgery beyond pop2/push1, no traceback events, cannot unwind except
by returning a PyError when the runtime helper errors (TypeError on bad
inputs mirrors `PyUnstable_Exc_PrepReraiseStar` validation only if we ever
expose it; the intrinsic itself asserts instead).

Wire it into the existing OP_CALL_INTRINSIC_2 chain in ceval.jac next to
oparg 2-5; delegate to the new runtime helper (section 3.3), zero logic
inline.

### 2.3 RERAISE arg combos (LANDED, verify only)

- RERAISE 0: pop exc, re-dispatch at the RERAISE's own offset; NO new tb
  entry (re-raise is not an error event).
- RERAISE 1: additionally pops the saved lasti first and attributes the
  unwind search to it (eff_offset). This is what the `unwind` block uses
  (COPY 3 / POP_EXCEPT / RERAISE 1) and what the tb-cadence merge 3383d579d
  aligned with CPython.

Interaction with the except* shape: both reraise blocks sit INSIDE the outer
protect region, so a failure during SWAP 2/POP_EXCEPT/RERAISE itself lands
on `unwind`. The POP_EXCEPT arm must pop BOTH the pushed value slot AND the
matching `exc_handling` entry (it does today).

### 2.4 PUSH_EXC_INFO / POP_EXC_INFO state

`he` opens with PUSH_EXC_INFO: original exception moves under a None slot;
`exc_handling` gains it. All handler bodies run with stack depth 6+nest --
the region depths in compiler_exc.jac encode this; keep them authoritative.

## 3. Runtime surface (the big missing piece)

New native group object alongside PyException in objects.jac (precedent:
PyRange slice). Name it `PyExcGroup` internally, expose types
BaseExceptionGroup and ExceptionGroup through the builtin tree the same way
other builtin exceptions are registered (5967ea874 pattern).

### 3.1 Construction and validation (BaseExceptionGroup.`__new__`)

- args: `(message: str, exceptions: sequence)`; no kwargs.
- exceptions must be a sequence -> tuple; empty -> ValueError "second
  argument (exceptions) must be a non-empty sequence".
- every item must be an exception INSTANCE -> ValueError "Item %zd of
  second argument (exceptions) is not an exception" (0-indexed %zd).
- ExceptionGroup (not Base) with any nested BaseException-only leaf ->
  TypeError "Cannot nest BaseExceptions in an ExceptionGroup".
- Subclassing: user subclasses work like other builtin exc subclasses
  (family resolution); `derive(excs)` default constructs `type(self)`
  preserving subclass identity -- split results use derive, which is why
  user-defined group subclasses keep their type through split.

### 3.2 split / subgroup (shared recursive kernel)

One recursive helper, two entry points (CPython shares it exactly):

- matcher modes: BY_TYPE (class or exc-tuple, PyErr_GivenExceptionMatches),
  BY_PREDICATE (callable, used by subgroup/split with functions),
  BY_INSTANCE_IDS (set of id(leaf) -- internal, used by projection).
- recursion: leaf matches whole -> match=leaf; leaf no-match ->
  rest=leaf (only when constructing rest); group partial -> recurse over
  `excs`, collect sub-matches/rests, rebuild parts via subset.
- subset(orig_group, part): `derive(part)`, then copy metadata from orig:
  traceback (get+set), `__context__`, `__cause__`, and a COPY of `__notes__`
  (independent list per part; non-sequence notes silently ignored).
- Empty match/rest part -> None. split returns (match_or_None,
  rest_or_None); subgroup returns match_or_None only.
- Guard depth with the same recursion guard used elsewhere
  (_Py_EnterRecursiveCall equivalent) -- RecursionError parity.

Also needed on the surface: `.message`, `.exceptions` (read-only members),
`__str__` rendering `"<msg> (<n> sub-exception(s))"` pluralization, and
BaseException.add_note/`__notes__` if not already present (check before
adding; notes are copied by split).

### 3.3 _prep_reraise_star(orig, excs) -> exception or None

Exact `_PyExc_PrepReraiseStar` port:

1. excs empty -> None.
2. orig not a group -> return excs[0] (naked case; assert len <= 2 with
   trailing None).
3. Partition excs (skipping None) into raised vs reraised by
   `is_same_exception_metadata`: identical `notes`/`traceback`/`cause`/
   `context` OBJECT IDENTITY (pointer equality, not ==).
4. reraised -> `exception_group_projection(orig, reraised_list)`: collect
   leaf ids, split orig BY_INSTANCE_IDS, return match or None. Result keeps
   orig's metadata (subset guarantees it).
5. raised empty -> result = projection. Else append projection (if not
   None) to raised list; >1 items -> wrap in fresh
   `ExceptionGroup("", raised)`; exactly 1 -> return it directly.

Chaining through except*: raising the prepared group at the `reraise`
block goes through RAISE/RERAISE paths whose implicit-context rules already
landed (RAISE_VARARGS arm). The handled-exception marking from 2.1 step 5
is what makes a NEW raise inside a handler chain the ORIGINAL group as
`__context__` -- verify with a pin (section 5, P3).

## 4. Interaction inventory

- Generators/coroutines: `gen.throw` unwinding INTO or OUT OF an except*
  frame rides CLEANUP_THROW (OP_CLEANUP_THROW arm, ceval.jac ~12533) and
  the ordinary exception-table search; no special group logic, but the M9
  CLEANUP_THROW work in flight must preserve the saved-lasti contract so
  RERAISE 1 attribution stays correct across yield points. Coordinate, do
  not fix here.
- tb cadence: group walks add NO tb frames for matching; the wrapped-naked-
  exception case builds a traceback FROM THE CURRENT FRAME at match time
  (one frame, matching host). RERAISE paths stay entry-free per 2.3.
- Host boundary: groups crossing to/from host (to_host/from_host bridges)
  will meet host ExceptionGroup instances -- out of scope for the first
  slices, but flag any `isinstance(x, ExceptionGroup)` bridge special-case
  added meanwhile so it routes to the native type once P2 lands.
- exc_handling stack: PUSH/CHECK/POP balance is per-handler-span; the
  unwind block runs with TWO entries live (orig + possibly handled match) --
  COPY 3 reaches below both. Pin this in a stack-depth test.
- EXC_EXTRA_PARENTS MI edge (fix/exc-group-edge): ExceptionGroup must be
  recognized as BaseExceptionGroup by exc_is_subclass_of BEFORE P2 lands or
  hierarchy checks reject group instances; sequence P2 after that branch
  merges, or vendor the same one-row table locally and drop it on merge.

## 5. Phased plan (smallest correct slice first)

Test pins are differential vs host python3.14 unless noted; follow the
existing ratchet/gate wiring (CONFORMANCE.md harnesses). Estimates: S <= 1
day, M ~2-3, L >= 4 (this box: jac check gate + CI, no local suites).

**P1 -- VM plumbing for an already-lowered program (S/M).**
Add CALL_INTRINSIC_2 oparg 1 delegating to a stubbed-but-honest
_prep_reraise_star. Do NOT duplicate the CHECK_EG_MATCH arm owned by the
other agent -- consume its documented contract (section 2.1). Gate:
disassemble-level golden of a bound multi-handler
program compiles and reaches the group walk without "unsupported
CALL_INTRINSIC_2". Pins: compile-only goldens (oracle-bytes style, see dc48b27a), 1 host-diff
of `ExceptionGroup("g",[ValueError()])` construction failing with the exact
ctor ValueError text. Effort: S.

**P2 -- BaseExceptionGroup core object (M).**
PyExcGroup obj + ctor validation + message/exceptions members + str/repr +
hierarchy wiring (coordinate with fix/exc-group-edge). Pins: ctor
validation matrix (empty seq, non-exc item, nested BaseExceptions,
subclass derive identity), str pluralization goldens. Effort: M.

**P3 -- split/subgroup kernel + metadata propagation (M/L).**
Recursive split with three matcher modes, subset/derive, notes copy,
context/cause/tb transfer. Pins vs host: flat-group split, nested-group
split, subgroup-by-type and by-predicate, notes independence, context
preserved on parts, user-subclass derive. Effort: M (L if predicate mode
needs callable-bridge work).

**P4 -- end-to-end except* execution (M).**
With CHECK_EG_MATCH (other agent) + P1-P3: run real programs. Naked-wrap +
frame traceback, handled-marking/context chaining, PrepReraiseStar full
algorithm (metadata-identity partition, projection, sibling wrapping),
reraise-vs-normal path selection. Pins vs host: single naked exc caught,
group partially matched remainder reraised, raise-inside-handler chaining,
multi-handler accumulation order, else-clause, unhandled-rest propagation
message/exit-code parity. Effort: M.

**P5 -- interactions + compiler gap closure (L, separable).**
gen.throw/coroutine through except* frames (with M9 lane), except*/
finally lowering, except*-inside-except bridging, host-boundary group
policy. Pins: generator re-raise across yield, finally-on-every-exit-path
matrix, nested-shape compile goldens. Effort: L.

Sequencing constraint: P2 depends on the MI edge merge; P4 depends on the
CHECK_EG_MATCH arm's documented contract (section 2.1) being honored --
if the arm deviates (e.g. no handled-marking), file back to that lane
rather than patching around it.
