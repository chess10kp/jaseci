# `jac prune` - compiler-backed cleanup

`jac prune` finds and removes dead and redundant code using the Jac compiler's
own semantic model - real def-use chains, access modifiers, the module
dependency graph, and byte-precise spans - rather than text heuristics or an
LLM guessing. It is in the lineage of OpenRewrite / Tricorder: **deterministic
detectors kill provably-dead code, and every automatic fix passes a validation
gate before it lands.** Precision is the product; a finding you can't trust is
worse than no finding.

## Quick start

```bash
jac prune report                 # find dead/redundant code (default action)
jac prune report jac/jaclang     # scope to a path
jac prune report -o json         # machine output (also: -o sarif)
jac prune fix --preview          # show minimal diffs for the safe fixes
jac prune fix --apply            # apply, validate, revert-on-failure
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
   `auto-fix`, `pr-only`, or `report-only` - with a stored, LLM-free rule trace.
7. **Planner + span-edit engine** turn auto-fix candidates into minimal diffs.
8. **Validation gate** is the sole authority for whether a patch lands.

## Detectors (Tier 1)

| Detector | Fires on | Default disposition |
|---|---|---|
| `unused-imports` | an import item whose resolved symbol has 0 uses in its module (excluding package `__init__.jac` barrels) | auto-fix |
| `private-dead-defs` | a `:priv`/`:protect` symbol with 0 references outside its own definition | auto-fix (top-level vars) / pr-only (archetypes, abilities, nested) |
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
so it is **opt-in** (`--recipe dead-enum-variants`) and never auto-fix - always
pr-only for human review.

## Reuse advisories (Tier 3)

These detectors surface duplication rather than dead code. They never edit and
carry no auto-fix planner - every finding is **report-only**, meant for a human
or a harness agent to act on. They are **opt-in**: pass `--recipe <name>` to run
them (they are not in the default recipe set, since a large tree can hold many
intentional lookup tables or boilerplate docs).

| Detector | Fires on | Disposition |
|---|---|---|
| `duplicated-constant-blobs` | one string/collection literal (value-hashed, so quote style is ignored) repeated across ≥2 sites above a size floor - invisible to callable-body hashing | report-only |
| `duplicate-docstrings` | an identical docstring or byLLM `sem` string attached to ≥2 distinct symbols (decl+impl on the same symbol does not count); docstrings and `sem` strings with the same text group together | report-only |

Each finding groups its member sites: `related` carries the member symbol ids
(`sym:<id>`) and `plan_meta` records the site/module counts and the shared hash.

## Module-cohesion advisories (Tier 4, opt-in)

`--recipe module-cohesion` surfaces *architectural* seams rather than dead code
or duplication. It builds the symbol-to-symbol reference graph already in the
fact store (`symbol_ref_edges`, resolved endpoints only) and reports two
LCOM-style shapes. Like the reuse advisories it is **opt-in** and every finding
is **report-only** - seam-review wording ("consider splitting / merging"), never
an edit, and (being report-only) always sorted below the auto-fix and pr-only
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

## The validation gate (`fix --apply`)

Applying is never blind. For a batch of auto-fix edits:

1. snapshot a **pre-patch diagnostics baseline** over the source scope,
2. write the whole batch,
3. **parse** - every touched file must re-parse with zero errors,
4. **typecheck** - a full-scope build must introduce **zero new diagnostics vs
   the baseline** (the repo need not be warning-clean; only regressions fail),
5. on failure, **revert the entire batch** and **bisect** to name the culprit
   file(s).

Affected test files are selected via the reverse dependency graph and reported;
running them (and the full suite by risk policy) is the campaign/CI step.

## Agent redundancy analysis (`jac prune analyze`)

Dead code is the detectors' job. The **advisory** agent loop finds code that is
*alive but redundant* - parallel implementations, pass-through wrapper layers,
and clusters of findings that are really one refactor. It reasons over the fact
store's call graph (a read-only tool surface), **not** raw source. Its findings
are contained by construction:

- they carry `source: agent` and can **never** reach `auto-fix`,
- every claim cites fact IDs, verified against the store before the finding is
  kept - a single unresolvable citation drops it,
- agent findings never reach `auto-fix` or the fix planner; use `jac prune fix`
  only for detector findings classified as `auto-fix`.

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

Every finding's fate - `reported`, `previewed`, `applied`, `reverted`,
`validation-failed`, `suppressed` - is appended to
`<project_root>/.jac/prune-feedback.jsonl`, keyed on the finding fingerprint.
Nothing consumes it yet; it is the corpus for later threshold-tuning and recipe
mining.

## Options

| Flag | Meaning |
|---|---|
| `action` (positional) | `report` (default), `facts`, `fix`, `analyze`, `reuse` |
| `paths…` | paths to analyze (default: project root) |
| `--exclude <glob>` | glob patterns to exclude (repeatable) |
| `--recipe <name>` | restrict to named detectors (repeatable) |
| `--risk_ceiling {safe,moderate,risky}` | max risk tier to act on |
| `-o, --output {table,json,sarif}` | output format |
| `--preview` | with `fix`: print diffs without writing |
| `--apply` | with `fix`: write, validate, revert on failure |
| `--model {heuristic,none}` | with `analyze`: the redundancy judge |
| `--group <id>` | with `reuse`: emit the full evidence packet for one group |
| `--probe` | with `reuse`: dry-run the consolidation (parse + typecheck, revert) |
| `--history` | with `reuse`: add git tandem-edit + divergence evidence |
| `--windows` | with `reuse`: also mine repeated statement-window blocks |
| `--fuzzy` | with `reuse`: also surface fuzzy (token-overlap) near-clones |
