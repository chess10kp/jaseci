# `jac prune` - compiler-backed cleanup

`jac prune` finds and reports dead and redundant code using the Jac compiler's
own semantic model - real def-use chains, access modifiers, the module
dependency graph, and byte-precise spans - rather than text heuristics or an
LLM guessing. It is **advice-only by construction**: detectors flag
provably-dead code and the planner renders suggested edits as diffs, but the
tool never writes to your tree. Precision is the product; a finding you can't
trust is worse than no finding.

## Quick start

```bash
jac prune report                 # find dead/redundant code (default action)
jac prune report jac/jaclang     # scope to a path
jac prune report -o json         # machine output (also: -o sarif)
jac prune plan                   # render suggested edits as diffs (writes nothing)
jac prune analyze                # agent redundancy report (advisory)
jac prune facts                  # extract + summarize the fact store
```

## How it works

1. **Ingestion** - enumerate `.jac` files and classify each by role
   (source, `.impl.jac` annex, test, fixture, generated, vendored, docs).
   Fixtures and generated files are excluded from "dead" analysis but still
   count as usage evidence. Pass one fixture file explicitly to analyze it as a
   detector demo; fixture directories remain excluded.
2. **Compile** - one whole-program `JacProgram` compile produces the AST +
   symbol tables + spans.
3. **Fact store** - a read-only walk of the compiled forest is written to a
   SQLite store at `<project_root>/.jac/prune.db` (symbols, references with
   read/write/call kinds, imports, field accesses, branches, module deps).
   Stored per-module content hashes mean only changed modules re-extract.
4. **Detectors** query the store (never raw source) and emit **findings** with
   evidence.
5. **Veto + suppression** downgrade or drop findings (see below).
6. **Risk classifier** assigns each finding a risk tier and a **disposition**:
   `suggested-edit`, `pr-only`, or `report-only` - with a stored, LLM-free rule
   trace.
7. **Planner + span-edit engine** turn `suggested-edit` candidates into minimal
   diffs, rendered for review by `jac prune plan`. Nothing is ever written -
   applying a suggestion is a human (or harness) decision.

## Detectors (Tier 1)

| Detector | Fires on | Default disposition |
|---|---|---|
| `unused-imports` | an import item whose resolved symbol has 0 uses in its module (excluding package `__init__.jac` barrels) | suggested-edit |
| `private-dead-defs` | a `:priv`/`:protect` symbol with 0 references outside its own definition | suggested-edit (top-level vars) / pr-only (archetypes, abilities, nested) |
| `write-only-fields` | a private field written ≥1 time and never read | pr-only |
| `literal-dead-branch` | an `if` with a literal-boolean condition | pr-only |

Detectors are deliberately conservative: only `:priv`/`:protect` symbols are
deletion candidates - a default-access (public) symbol is treated as package API
and is out of scope for automatic deletion.

## Dead-code advisories (Tier 3, opt-in)

| Detector | Fires on | Disposition |
|---|---|---|
| `dead-enum-variants` | an enum variant with 0 references outside its own declaration - never constructed, read, or matched | pr-only |

Unlike the Tier-1 dead-code detectors, `dead-enum-variants` also considers
public variants (an unused variant of a public enum may still be external API),
so it is **opt-in** (`--recipe dead-enum-variants`) and never suggested-edit -
always pr-only for human review.

## Reuse advisories (Tier 3)

These detectors surface duplication rather than dead code. They carry no
planner - every finding is **report-only**, meant for a human
or a harness agent to act on. They are **opt-in**: pass `--recipe <name>` to run
them (they are not in the default recipe set, since a large tree can hold many
intentional lookup tables or boilerplate docs).

| Detector | Fires on | Disposition |
|---|---|---|
| `duplicated-constant-blobs` | one string/collection literal (value-hashed, so quote style is ignored) repeated across ≥2 sites above a size floor - invisible to callable-body hashing | report-only |
| `duplicate-docstrings` | an identical docstring or byLLM `sem` string attached to ≥2 distinct symbols (decl+impl on the same symbol does not count); docstrings and `sem` strings with the same text group together | report-only |

Each finding groups its member sites: `related` carries the member symbol ids
(`sym:<id>`) and `plan_meta` records the site/module counts and the shared hash.

## AST-bloat advisories (Tier 4, opt-in)

`--recipe ast-bloat` uses compiled AST body facts to identify files that
resemble known simplification targets: multiple callable bodies with the same
normalized structural hash, or unusually large callable bodies that may hide a
dispatch table or repeated routing logic. It reports candidates only; it never
rewrites code.

| Detector | Fires on | Disposition |
|---|---|---|
| `ast-bloat` (duplicate family) | ≥3 distinct callables in one module sharing a normalized AST body shape | report-only |
| `ast-bloat` (large body) | a callable with at least 32 statements or 120 lines in the compiled AST | report-only |

Findings include the structural hash, cited symbols, member count, estimated
refactoring signal, not proof that implementations can be merged; declarations,
inheritance, side effects, and backend lowering still require review.

## Module-cohesion advisories (Tier 4, opt-in)

`--recipe module-cohesion` surfaces *architectural* seams rather than dead code
or duplication. It builds the symbol-to-symbol reference graph already in the
fact store (`symbol_ref_edges`, resolved endpoints only) and reports two
LCOM-style shapes. Like the reuse advisories it is **opt-in** and every finding
is **report-only** - seam-review wording ("consider splitting / merging"), and
(being report-only) always sorted below the suggested-edit and pr-only
findings so it never crowds the top of a report.

| Detector | Fires on | Disposition |
|---|---|---|
| `module-cohesion` (split) | one module whose internal symbols form ≥2 clusters with no reference edge between them - the module is really two units sharing a file | report-only |
| `module-cohesion` (merge) | two modules whose cross-reference count exceeds **both** modules' internal edge counts - the seam between them is tighter than either module's own cohesion | report-only |

`plan_meta.shape` is `split` or `merge`. A **split** finding's `related` cites one
representative symbol per cluster (`sym:<id>`); a **merge** finding's `related`
cites the two modules (`mod:<path>`). Both citation forms are verifiable through
the tool surface (`verify_citations`). The detector needs no schema change or
re-extraction - it is a pure query over facts already stored.

## If-chain dispatch advisories (Tier 4, opt-in)

`--recipe if-chain-dispatch` flags same-selector routing chains that a lookup
table or membership set expresses directly. Extraction records the chain's AST
shape at compile time; detection is a query over those facts. **Opt-in** and
always **report-only**.

| Detector | Fires on | Disposition |
|---|---|---|
| `if-chain-dispatch` (seq-if) | ≥4 sibling `if` statements comparing one selector with `==`, each body a single `return` | report-only |
| `if-chain-dispatch` (elif-chain) | an if/elif chain of the same shape | report-only |
| `if-chain-dispatch` (or-chain) | an `or` expression with ≥4 leaf `==`/`in` comparisons on one selector | report-only |
| `if-chain-dispatch` (and-chain) | an `and` expression with ≥4 leaf `!=`/`not in` comparisons on one selector | report-only |

Vetoes are structural, not textual: any `<`/`>`/`is`-family operand marks the
chain ordered (range checks and guards where evaluation order is semantics),
comparisons on more than one selector mark it mixed, and seq-if/elif findings
require every arm body to be a lone `return`. Chains under 4 arms are not
recorded as findings. `plan_meta` carries the shape, selector, arm counts, and
how many comparands are constants.

## Safety: veto, suppression, risk

- **Dynamic-use veto** - a read-once scan for standalone identifier string
  literals in the same module, `getattr`/inline-Python, fixture text, and
  `jac.toml` references. Prose in docstrings or another module is not dynamic-use
  evidence. Any veto caps a finding at `report-only`.
- **Suppression** - inline `# jac:ignore[prune]` (or `# jac:ignore[<detector>]`)
  on or above the finding line, plus a project suppression file (by fingerprint,
  symbol id, or name).
- **Risk ceiling** - `--risk_ceiling {safe,moderate,risky}` (or the `[prune]`
  table in `jac.toml`) caps how risky a finding may be and still act; anything
  over the ceiling is `report-only`.

## Verification questions in every packet

Each finding and reuse-group packet (`-o json`, `reuse --group`) carries a
`verify` block: 1-4 detector-authored checks the detector could **not** settle
itself - its forward-looking blind spots - each phrased as an executable check
with an expected answer:

```json
"verify": [
  {"q": "Is 'load_template' referenced dynamically (string literal / getattr)?",
   "how": "grep -rn '\"load_template\"' --include='*.jac' <root>",
   "expect": "no hits outside the decl module; any hit = dynamic-dispatch risk"}
]
```

They complement the backward-looking `evidence` rows (what the detector already
checked). A harness agent runs them before issuing a verdict; reuse packets ask
the merge-worthiness questions (shared owner/base, delta class, drift), and the
fuzzy tier adds a contiguity (LCS) check to kill coincidental shingle matches.

## Paginated triage (`list` / `show`)

Hundreds of findings must never land in an agent's context at once. `list` is a
ranked one-line index; `show` drills into exactly one packet:

```
jac prune list                       # ranked index, one row per finding
jac prune list -o json --limit 50    # top 50 as JSON (with total/suppressed)
jac prune show <fingerprint>         # full v2 packet for one finding
jac prune show <group_id>            # ... or one reuse/window/fuzzy group
```

`list` ranks by disposition (suggested-edit first), then a confidence proxy, then
location, and caps output at `--limit` (default 200) while reporting how many
rows the rank suppressed. Each row is `fingerprint  disposition  confidence
location  message`; the stable `fingerprint` is the handle you pass to `show`.

`show` re-derives the single packet on demand and prints the same v2 structure
`report -o json` emits (`evidence`, `verify`, `citations`, `cite_index`,
`trace`). It accepts a finding fingerprint or any reuse group id (`reuse:grp:`,
`reuse:win:`, `reuse:fzy:`); the older `reuse --group <id>` remains an alias.
Pass paths after the id to scope the re-derivation (`jac prune show <id> jac/`).

## Advice-only by construction (`jac prune plan`)

`jac prune plan` renders each `suggested-edit` finding as a unified diff and
stops there - it never touches your tree. The span-edit engine still guards
every suggestion with a pre-text content hash, so a diff that no longer matches
the file is skipped rather than emitted stale. Applying a suggestion (and
re-running parse/typecheck/tests afterward) is the reviewer's or harness's job.

Suggested-edit findings are deliberately narrow: only shapes the planner can
turn into a provably minimal diff (dead private top-level defs, unused import
items) get the `suggested-edit` disposition. Everything else stays `pr-only` or
`report-only` advice.

## Agent redundancy analysis (`jac prune analyze`)

Dead code is the detectors' job. The **advisory** agent loop finds code that is
*alive but redundant* - parallel implementations, pass-through wrapper layers,
and clusters of findings that are really one refactor. It reasons over the fact
store's call graph (a read-only tool surface), **not** raw source. Its findings
are contained by construction:

- they carry `source: agent` and can **never** reach `suggested-edit`,
- every claim cites fact IDs, verified against the store before the finding is
  kept - a single unresolvable citation drops it,
- agent findings never reach `suggested-edit` or the planner; `jac prune plan`
  only renders detector findings classified as `suggested-edit`.

`--model heuristic` (default) is a deterministic structural judge for running
without an LLM; the loop is model-agnostic (an LLM judge slots into the same
interface).

## Structural-duplicate detection (`jac prune reuse`)

Where `analyze` reasons over the call graph, `reuse` reasons over **bodies**. It
renders each callable's body into two hashes - an exact hash (trivia stripped,
names and literals kept) and a structural hash (local names alpha-renamed,
literal constants abstracted, callees and attributes kept concrete) - and groups
callables that collide. Byte-identical bodies form **exact** groups; bodies that
differ only in constants or local naming form **structural** groups, with the
differing constants captured as a per-member delta vector. Body extraction is
impl-annex aware: a body living in a `.impl.jac` is hashed there but attributed
to its declaration.

Groups spanning two or more sibling classes are rolled up into **class-hoist**
candidates (the shape of "extract a shared base class"). Everything is ranked by
a payoff score (lines saved, copies saved, caller reach) and is **report-only by
construction** - the tool loads no model and applies nothing.

```bash
jac prune reuse -o json                  # ranked candidate groups + rollups
jac prune reuse --group <id> -o json     # full evidence packet for one group
jac prune reuse --fuzzy -o json          # + fuzzy (token-overlap) near-clones
```

The evidence packet carries each member's decl, owner, body span (the annex file
when applicable), visibility, delta vector, callers/callees, and citations as
typed fact IDs (`sym:`/`body:`) verifiable through the tool surface. A consuming
agent Reads the cited spans and decides `identical` / `equivalent` /
`not-a-duplicate`; the tool never reaches a verdict.

### Fuzzy near-clones (`--fuzzy`)

The exact and structural hashes are all-or-nothing: a single inserted guard or
one extra statement changes the hash and the pair no longer collides. `--fuzzy`
adds the **token-overlap tier**. Within each `(arity, async, generator,
size-band)` bucket it compares every body's normalized token stream pairwise
with Jaccard over k-gram shingles (default threshold `0.8`) and links matches
into groups. This catches **gapped / Type-3 clones** - near-identical bodies
that drifted by a guard, a broadened condition, or an added statement.

A fuzzy group is only reported when its members span **more than one structural
hash** (otherwise it is just a structural group restated) and at least two
distinct sites, so the tier only ever adds information the exact/structural
tiers missed. Each group's packet (`--group reuse:fzy:<id>`) carries the
minimum and mean pairwise similarity as evidence alongside the usual per-member
citations. Buckets larger than an internal cap are skipped to bound the
pairwise cost and reported under `fuzzy_skipped_buckets` (never dropped
silently). Report-only, like the rest of `reuse`.

## Feedback ledger

Every finding's fate - `suggested`, `verdict-accept`, `verdict-reject`,
`verdict-contested`, `suppressed` - is appended to
`<project_root>/.jac/prune-feedback.jsonl`, keyed on the finding fingerprint.
Nothing consumes it yet; it is the corpus for later threshold-tuning and recipe
mining.

## Options

| Flag | Meaning |
|---|---|
| `action` (positional) | `report` (default), `facts`, `plan`, `analyze`, `reuse`, `list`, `show`, `verdict` |
| `paths…` | paths to analyze (default: project root) |
| `--exclude <glob>` | glob patterns to exclude (repeatable) |
| `--recipe <name>` | restrict to named detectors (repeatable) |
| `--risk_ceiling {safe,moderate,risky}` | max risk tier to act on |
| `-o, --output {table,json,sarif}` | output format |
| `--model {heuristic,none}` | with `analyze`: the redundancy judge |
| `--group <id>` | with `reuse`: emit the full evidence packet for one group |
| `--history` | with `reuse`: add git tandem-edit + divergence evidence |
| `--windows` | with `reuse`: also mine repeated statement-window blocks |
| `--fuzzy` | with `reuse`: also surface fuzzy (token-overlap) near-clones |
| `--limit <n>` | with `list`: max rows before rank-suppressing the tail (default 200) |
