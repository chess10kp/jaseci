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

## Feedback ledger

Every finding's fate - `reported`, `previewed`, `applied`, `reverted`,
`validation-failed`, `suppressed` - is appended to
`<project_root>/.jac/prune-feedback.jsonl`, keyed on the finding fingerprint.
Nothing consumes it yet; it is the corpus for later threshold-tuning and recipe
mining.

## Options

| Flag | Meaning |
|---|---|
| `action` (positional) | `report` (default), `facts`, `fix`, `analyze` |
| `paths…` | paths to analyze (default: project root) |
| `--exclude <glob>` | glob patterns to exclude (repeatable) |
| `--recipe <name>` | restrict to named detectors (repeatable) |
| `--risk_ceiling {safe,moderate,risky}` | max risk tier to act on |
| `-o, --output {table,json,sarif}` | output format |
| `--preview` | with `fix`: print diffs without writing |
| `--apply` | with `fix`: write, validate, revert on failure |
| `--model {heuristic,none}` | with `analyze`: the redundancy judge |
