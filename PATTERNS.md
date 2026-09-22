# Slop patterns -- candidate registry for `prune`

Working document for the simplification campaign. Patterns identified during
refactor passes get written here first, **approved by the repo owner**, then
encoded as AST detectors in `~/repos/prune-cohesion-wt` (`jac/jaclang/prune/`).

## Scope decision: prune is lint/advice only

`prune` produces findings (candidate refactor targets), not edits. A human or a
separate agent pass owns the actual change. Consequences:

- Findings are *diagnostics / refactor suggestions*, not rewrite plans baked
  into the tool.
- False positives cost reviewer time, not corrupted code -- but a detector that
  cries wolf gets ignored, so the evidence bar is still high.
- Judgment-call patterns (design-tagged equivalents) ship opt-in/disabled by
  default, like react-doctor's design rules.

## Methodology (adapted from react-doctor's rule pipeline)

Each pattern goes through three stages before it becomes a detector:

1. **Contract** -- written here in PATTERNS.md, approved before encoding:
   - *Justification*: why this shape is slop (not just style preference).
   - *Evidence*: concrete instances found in this repo (file refs) or OSS.
   - *Positive cases*: minimal code shapes that should fire.
   - *False-positive traps*: shapes that look similar but must NOT fire.
     This field is first-class -- a pattern without traps listed isn't ready.
2. **Detector** -- encode as AST pattern in prune. Detectors key on structure,
   never on incidental source shape (comments, blank lines, formatting).
3. **Validation** -- before a detector is trusted:
   - *Verdict fixtures*: confirmed TP/FP hits get pinned as regression cases
     (react-doctor uses `// verdict: pass|fail` + `// rule:` headers).
   - *Fire coverage*: track per-detector fire counts across the corpus. A
     detector that never fires is dead weight or has a bail bug -- report it.
   - *Invariant check*: semantics-preserving rewrites (added comments, blank
     lines, trailing unused decls) must not change the verdict. Catches
     detectors that secretly match surface syntax.

## Pattern candidates

Status: `idea` → `contract` (this doc, awaiting approval) → `encoded` →
`validated`.

### Structural / architecture

| Pattern | Status | Notes |
|---|---|---|
| God file (single file carrying too many roles/clusters) | contract | Evidence: `roles.impl` (annotated for split in 39133e108). Signal: multiple disjoint member clusters, high fan-in. Traps: genuinely cohesive registries/tables (e.g. opcode_meta), generated files. |
| Mergeable helper cluster (same signature shape, near-identical bodies) | contract | Evidence: helper proliferation found during simplify passes. Traps: intentional seam for override, differing contracts behind same shape. |
| If-else routing chains that should table-drive | **encoded** (`if-chain-dispatch`) | Evidence: popped/pushed stack-effect classifiers (5287b36ca); residual `op == OP_*` dynamic arms in `_opcode_num_popped`/`_opcode_num_pushed`; `has_target` 24-way or-chain duplicating `_OPCODE_HAS_JUMP_SET`. Empirical: `ast-bloat` fires on the two residual classifiers (49 stmts/148 lines, 32 stmts/97 lines) but misses `has_target` (29 lines) -- threshold proxy, not the shape. AST shapes: (a) run of ≥4 sibling `if` stmts, each `CompareExpr(sel == const)` on the SAME selector with a single-`return` body; (b) `elif` chains of the same form; (c) `BoolExpr(or)` with ≥4 leaf comparisons on one selector using `==`/`in` (leaves are `CfgExpr`-wrapped -- unwrap `.expr`); (d) `BoolExpr(and)` of `!=`/`not in` on one selector. Traps (all vetoed, verified): `<`,`>`,`is`-family operands (ordered); >1 selector in a chain (mixed); non-single-return bodies in if-runs; chains under 4 arms. Extracted facts: `chains` table (shape, n_arms, n_total, selector, const_arms, uniform_returns, ordered_ops, mixed_selector). Detector: `detect_if_chain_dispatch`, Tier-4 opt-in (`--recipe`), report-only. Validation: 5 new tests (`test_prune_chains.jac` + `fixtures/chainprog.jac`), 322/322 suite green. Corpus: `jaclang/runtime` 163 files → 33 findings; `compiler/{passes,frontend,types}` 126 files → 12 (incl. 113-arm `kind→read_node_*` dispatch in `ast_input.jac`, `ct_eval._cmp`, lexer/tokenizer char-class ors); `runtimelib+cli` 152 files → 2 (MCP `_dispatch` method table, prompt name dispatch). Spot-checks ~10 sites: 0 FPs; grayest is `ct_eval._cmp` (arms apply different operators -- still dispatch-shaped). Gotcha fixed: Jac string literals are `uni.MultiString`, not `uni.String`; fact hash must cover ALL persisted columns or sync skips re-extraction; `BoolExpr.values` are `CfgExpr`-wrapped. Limit: whole-`compiler` (517 files) OOM-killed the pipeline -- scalability issue, not detector-specific. |
| Accreted dispatch by name-prefix/suffix (`handle_*`, `visit_*` scattered) | idea | Signal for missing jump-table/registry abstraction. |
| Wrapper that only forwards (def f(x): return g(x)) | idea | Dead indirection. Traps: interface conformance, ability/override semantics, deliberate extension points. |
| Stringly-typed API dispatch (method-name strings passed as params, then `getattr(api, name)(...)`) | contract | Evidence: `KubernetesTarget._apply_or_replace` took read/patch/create method-name strings; replaced by kind→stem convention in `patch_k8s_resource` (stack-3). AST shape: a param typed `str` flowing into `getattr`/`call` position, with callers passing `"<verb>_<noun>"` literals. Traps: plugin-driven registries where names are data, not dispatch. |
| Read→mutate, except-404→create apply triplet | contract | Evidence: ~30 sites across monitoring/ingress/target/postgres; consolidated into `apply_k8s_resource`/`patch_k8s_resource`/`_apply_custom_object` (stack-3). AST shape: `try { api.read_X(...); api.<replace\|patch>_X(...) } except E { if e.status == 404 { api.create_X(...) } else raise }`. Traps: create-only resources (no replace verb exists -- PVCs/Services), poll-until-404 wait loops, reads whose 404 maps to a domain error (`raise ValueError`), different tolerated status sets. |
| Delete with tolerated-status guard | contract | Evidence: ~15 sites; consolidated into `delete_resource`/`delete_collection_if_exists`/`_delete_custom_object` (stack-3). AST shape: `try { api.delete_X(...) } except E { if e.status [not] in <status-list> { ... } }`. Includes the list→iterate→delete-per-item variant. Traps: deferred-error semantics (collect errors across several deletes, raise worst afterward -- do NOT collapse into raise-first), per-site tolerated sets (parameterize, don't hardcode). |
| Manifest/envelope dict literal | contract | Evidence: ~20 `{apiVersion, kind, metadata, ...}` dict literals across the k8s deploy tree; consolidated into `k8s_manifest` with `kind→apiVersion` map + explicit `api_version` override for CRDs (stack-3). AST shape: dict literal with literal keys `apiVersion`/`kind`/`metadata` where apiVersion is derivable from kind. Traps: yaml/doc fixtures, envelopes whose metadata shape is itself the point under test. |
| Deferred-error accumulation with dead nuance | idea | Evidence: `destroy_http_activation` collected two delete errors, checked `!= 403` per error, then raised `e1 or e2` unconditionally -- the 403 branches were dead (stack-3). AST shape: per-error status branches followed by a catch-all raise that subsumes them. Traps: genuinely selective swallow (status X must not propagate at all). |
| Label/security-context boilerplate | contract | Evidence: `{'managed': 'jac-scale'}` and PSS-restricted container `securityContext` dicts repeated ~10× in monitoring/postgres; consolidated into `managed_labels`/`app_labels`/`restricted_container_security`/`pod_security_context` (stack-3). AST shape: identical dict literal at ≥3 sites in a module family. Traps: literal that is *intentionally* a per-site contract (e.g. test expectations). |
| Endpoint-registration boilerplate | APPLIED (stack-3) | Consolidated into `ep()`/`path_param`/`query_param`/`body_param`/`header_param` in `server/serving/endpoint.jac` + `authed`/`authed_thread` callback wrappers in `scale/admin/auth_wrap.jac`. ~80 `server.add_endpoint(JEndPoint(...))` sites → `ep(method, path, callback, ...)` (positional trio + kwarg metadata, `**kw` passthrough for rare fields); ~50 seven-line `APIParameter` blobs → one-line `*_param(name, desc, type, default_value)` calls where `required` derives from a `_NO_DEFAULT` sentinel (so `required=False, default=None` stays expressible). `parameters=[]`/`response_model=None` redundant kwargs dropped (None ≡ [] in `bind_parameters`/`openapi`). Route-table form used where every endpoint shares tags (`register_admin_endpoints` 497→~215, `register_workloads_endpoints` → list+loop with `endpoint.tags`/`forward_undeclared_query_params` injected once). Traps (all left as raw ctors): dynamic `type_obj`/`required`/`kind` params in `walkers.jac`/`webhook_ext.jac` field loops; handlers that read `request.query_params` directly instead of declared params. |
| Uniform auth-binding handler stubs | contract | Evidence: 13 `async def X_handler(request) { authorization = request.headers.get('Authorization'); return self.method(params, authorization); }` stubs in `admin_portal.impl.jac`, 4 `asyncio.to_thread` variants in `workloads.impl.jac`. All admin methods take a trailing `Authorization: str \| None` kwarg, so a generic `authed(fn)`/`authed_thread(fn)` factory (`async def h(request, **kw): return fn(Authorization=<header>, **kw)`) eliminates every stub. REQUIREMENT: the wrapper's `**kwargs` sets `accepts_var_kw` in the callback spec, so undeclared query params would leak into `fn` -- the endpoint must set `forward_undeclared_query_params=False` (safe: the stubs' declared params were already the complete set). AST shape: handler body = header get + single `return self.m(*params, auth)` tail call. |
| God-object → impl annexes | APPLIED (stack-3) | `obj X` with 50+ methods spanning unrelated concerns → keep `has` + signatures in the decl file, move bodies to `<mod>.impl/<topic>.impl.jac` (per-module annex dir discovered by `discover_annex_files`: `<base>.impl/` holds ALL `*.impl.jac`; shared `impl/` dir requires `<base>.` filename prefix). Impl syntax `impl Obj.method(sig) -> ret { }` with implicit `self`; annexes share the decl module's imports via `merge_annex_into`, and each annex can carry its own imports. Applied: `target.jac` 2124→256 (5 annexes), `manifest_builder.jac` 1823→187 (6 annexes), `server.impl.jac` 1752→3 per-class annexes (`impl/server.{exec,introspect,api}.impl.jac`). Detection: `module-cohesion` cluster size + single-obj file >1000 lines. Traps: methods with nested `def` inside bodies (keep inside the moved body verbatim); `has` blocks must stay in the decl; splitting surfaces dead imports the monolith masked (MISSING, Archetype in server.impl.jac). |
| Config-schema spec literals | APPLIED (stack-3) | Every plugin_config option was a 5-line `{"type":..,"default":..,"description":..}` dict (~315 leaves across scale/byllm/client/mcp files); dict sections added `nested` boilerplate. `opt(type, default_value, description)` + `opt_group(description, nested)` in `jaclang.project.config_schema` compress leaves to one line (scale file 1400→1157 after `jac fmt` rewraps long descriptions). AST shape: dict literal whose key set is exactly {type,default,description} or {type,default,description,nested}. TRAP: `default` is a Jac keyword -- can't be a param name. Related-but-risky followup: `get_default_config`/`get_*_config` accessors in config_loader.impl.jac re-hardcode every default -- deriving them from the schema would inject ~40 kubernetes keys into loaded configs (behavior change), so it needs an explicit audit, not a mechanical refactor. |
| SSO provider method clones | rejected -- already minimal | `authorize_url`/`token_url`/`scope` are one-line literal-return overrides of an abstract method contract (`raise NotImplementedError` in base); `fetch_user` bodies genuinely differ (Apple: id_token decode; Google: userinfo endpoint; GitHub: extra API call). Shared hashes came from the NotImplementedError stubs -- the documented abstract-stub trap. Field-izing would break the `self.authorize_url()` call convention for ~30 LOC; not worth it. |

### Dead code / bloat

| Pattern | Status | Notes |
|---|---|---|
| Unused file / export / dependency | contract | Needs whole-project graph, not per-file. Traps: entry points, dynamic import targets, plugin-discovered modules. |
| Redundant defensive check after an establishing guard | idea | e.g. re-checking `is not None` after a guard that established it. Traps: mutation between guard and check, closure capture. |
| Try/except that swallows then re-raises identically | idea | Pure noise error handling. |
| Comment/docstring that restates the code verbatim | idea | Low value alone; signal when clustered. |
| Declared-but-never-read variable / `has` field | idea | Traps: protocol-required fields, serialization surface. |

### Generalized from react.doctor (frontend-specific → cross-language)

| Their rule | Generalized pattern | Status |
|---|---|---|
| `no-derived-state` / `react-you-might-not-need-an-effect` ports | State/effect storing what a computation could produce; redundant recompute-or-cache | idea |
| `no-fetch-in-effect` family | Work triggered at wrong lifecycle layer (init vs. lazy vs. cached) | idea |
| `repeated-jsx` extraction | Repeated multi-node block worth extracting (clone detection -- prune already has `clones.jac`) | idea |
| `circular-dependency`, `unused-dependency` | Same, at Jac module/import level | contract |
| design-tagged rules off by default | Judgment-call findings ship opt-in | adopted as policy |

### From dmmulroy/anti-slop (mined, generalized to Jac)

| Their rule | Generalized pattern | Status |
|---|---|---|
| `no-array-filter-map` | Chained eager collection passes (filter→map→filter as separate comprehensions) where one comprehension suffices | idea |
| `no-widen-then-assert` / `no-known-value-widening` | Precise value widened to `any`/broad dict then re-narrowed downstream (`x: any = <precise>` → later `int(x)`/`str(x)`). Jac's W1037 already flags `any`; the deeper shape is widen-then-narrow flow | idea |
| `no-conditional-empty-object-spread` | `**(a if cond else {})` / `or {}` dict-merge idioms used to conditionally include fields -- prefer a builder that takes optional params | idea |
| `no-runtime-typeof` | Ad-hoc `isinstance` narrowing of untyped config dicts vs. boundary parsing into named types -- evidence: `isinstance(overrides, dict)` guards in kubernetes_postgres | idea |
| `prefer-effect-match` | Chained ternaries / if-elif over the same subject that a table or match expresses directly | idea |
| `require-safety-comment-for-type-assertion` | Non-const casts/dynamic `getattr` calls should carry an invariant note | idea |
| `no-module-mocking` (design-tagged) | Mock-heavy unit tests for thin glue -- the deploy suite's API doubles are the sanctioned seam here, so this stays opt-in/contextual | not adopted for Jac |
| `require-readable-spacing` | Formatting concern; covered by `jac fmt`, not a prune detector | not adopted (formatter-owned) |

### False-positive traps learned this pass (detector must NOT fire)

- **Identical `raise NotImplementedError` abstract stubs** -- an ABC decl block
  (`autoscaler.jac`) produces N AST-equivalent bodies that are the contract
  itself, not a mergeable clone. Trap for ast-bloat/clone detectors.
- **One-line `f"{x}-<literal>"` name templates** -- `resource_name_for` /
  `interceptor_route_name_for` / `http_scaled_object_name_for` share shape but
  the varying part is only a literal; a shared helper adds indirection without
  removing logic. Trap for clone detectors keyed on normalized bodies.
- **Delegating one-line wrappers already at minimal form** -- the 14-member
  `getTraceServices`/`getOpsHealth`/`getMetrics`/... family in
  `scale/admin/ui/services/` all share `return await get(<url>, token)`. That
  IS the abstraction; nothing left to hoist. Clone detectors must weight
  would-be-extraction payoff, not just member count.
- **Enum variants read via cross-module qualified access** -- FIXED in prune.
  Root cause was twofold: (a) member accesses `Enum.MEMBER` bind to the
  *internal-hub* module instance (deps live in `prog._search_hubs()[1]`, not
  `prog.mod.hub`), so uses recorded on them never appeared on the walked
  instance; (b) test modules were never compiled, so test refs couldn't exist.
  Fixes landed in `~/repos/prune-cohesion-wt` (branch `prune/module-cohesion`,
  uncommitted): extractor iterates all hubs for use emission, emits enum-member
  refs directly from `right.sym` (stable ids are instance-independent) with an
  in-manifest decl guard, compiles TEST-role files, stores `src_role` on refs,
  and `dead-enum-variants`/`private-dead-defs` carry `test-only-use` vetoes.
- **Whole-enum iteration makes every variant live** -- `[o.value for o in
  Operations]` in `user_manager.impl.jac` exposes all variants' values without
  any `Enum.MEMBER` access. `dead-enum-variants` flagged `LOGIN`/`REGISTER`
  anyway. Fixed: extractor emits `kind='iterate'` refs for enum-bound names in
  expression position (excluding decl names, import items, and SubTag/
  FuncSignature type positions), and the detector vetoes variants of iterated
  enums (`whole-enum-iteration`). Enum used only as a type annotation
  (`CredentialType` in `auth_models.jac`) is still correctly flagged.
- **Decl+impl pairs of the same symbol in reuse groups** -- FIXED.
  `extract_bodies` now skips `ImplDef` nodes with a `decl_link`; the decl's
  ability body already represents them. Reuse groups on stack-3 scale dropped
  21 → 10 (all remaining groups are real).
- **Side-effect anchor imports** (`X as _pg_anchor`, `X as _state_anchor`) --
  `scale/runtime/provider.jac` imports backends purely to force module
  load/registration. The `_anchor`-suffixed alias is a deliberate convention;
  treat as a veto signal for unused-imports.
- **Optional-dependency shim modules** -- `_optdeps/*.jac` import symbols in
  `with entry`/try-guards as their entire export surface. Correctly capped
  report-only by the existing veto; do not promote.
- **Dev-mode cross-tree binding** -- running worktree-A's `jac` binary against
  worktree-B sources resolves `jaclang.*` imports to worktree-A's own tree, so
  bound symbols carry foreign `decl.loc.mod_path`s. Refs emitted for them are
  orphans (used_id never joins). The extractor now guards enum-member emission
  with `decl.loc.mod_path in manifest`; for ground-truth verification of
  cross-module detectors, run prune against the SAME tree that built the
  binary (in-tree self-analysis).
- **Duplicate/shadowed same-name imports are TRUE positives that look like
  FPs** -- `Request` in `admin/impl/admin_portal.impl.jac` is imported twice
  (module level line 2 + function-local line 81), producing two symbol ids;
  all 14 refs bind to the inner one, so the module-level import is genuinely
  dead. A name-level grep (16 hits) misleads -- verify by resolved_id, not by
  name occurrence. Detector was right; the message could name the shadowing
  scope to make the TP obvious.

## Cross-codebase generalization check

Per PROMPT.md: after each simplification pass, for every pattern used, ask --
"what AST shape would flag this same slop in a different file/codebase?" Log
the generalized form here (not just the instance). Instance-only patterns that
can't generalize stay as one-off edits and don't become detectors.

## Annex-split traps (learned on stack-3 god-file splits)

- **Bootstrap modules can't use `impl/<base>.<topic>.impl.jac` siblings
  unless jac0 knows the pattern.** `runtime.jac` is a seed module compiled by
  the jac0 transpiler (`meta_importer._exec_bootstrap`), whose
  `discover_impl_files` only matched exact `impl/<base>.impl.jac` -- not the
  `<base>.<topic>.impl.jac` siblings the full compiler's
  `discover_annex_files` supports. Symptom: decl-only module, stubs return
  None, `jac` binary dies at `meta_importer.get_bytecode` with
  `compiler is None`. Fixed by aligning jac0 discovery with bccache rules.
  Check `bootstrap_manifest.SEED_PATHS` before splitting impls of any module
  it lists.
- **Module-level `glob`/`import` statements in an impl file are easy to
  silently drop** when splitting by `impl`/`def` boundaries -- `_LATENCY_CUTS`
  in admin_portal went missing mid-file. Always grep the original for
  `^glob |^import |^with` and place each in the annex (or decl) that uses it.
- **Annex free-name imports**: bodies may rely on decl-file imports via
  weaving -- annexes only need imports NOT in the decl module. Verify with a
  per-annex identifier scan rather than copying the original header.
- **Python `open(f,'w').write(hdr + open(f).read())` clobbers the file** --
  `open(f,'w')` truncates before the read evaluates. This wiped
  browser_engine/vite_bundler annexes to import-only stubs, and `jac check`
  PASSED because decl-only modules still typecheck. Always read the body into
  a variable first, and verify splits with a sorted-line diff of old vs new
  (a grep for `^impl` counts is not enough -- the bodies can be gone while
  names still look right in the map).
- **Statement-boundary scanning needs full delimiter awareness**: multi-line
  signatures (`impl X.f(` newline args), triple-quoted strings containing
  JS/CSS (`'''`), `[`/`]` list literals, and `async def`/`static` modifiers
  all break naive `^impl`/brace matching. The verified splitter
  (/tmp/split_implfile.py pattern) tracks paren+bracket depth and skips
  strings/comments; unverified splits corrupt silently.
- **Mid-file `import`/`glob` statements must be routed to a named annex** --
  they are not header material (e.g. `import unparse_node` between impls in
  engine.impl.jac, used only by the nav annex).

## Dead-import sweeps (learned the hard way)

- Group decl files with ALL woven annexes before counting uses:
  `impl/<base>.impl.jac` AND `impl/<base>.*.impl.jac` AND `<base>.impl/*.jac`
  AND same-dir `<base>.<topic>.impl.jac` (e.g.
  `gateway/microservice_gateway.routing.impl.jac`). Impl annexes have no
  imports of their own -- they see the decl module's namespace. Trimming a
  decl import an annex uses breaks bootstrap (8 names stripped from
  microservice_gateway/keda_autoscaler/kubernetes_utils this way).
- A removed import may be a **re-export** consumed via
  `import from <thismodule> { name }` elsewhere -- zero in-file uses is not
  proof. `pipeline.jac` re-exported `collect_client_graph` for
  `jac_client_compiler`; `codeinfo.jac` re-exported `CodeLocInfo` for
  `lsp/server/utils.jac`. Before deleting, grep the whole tree for
  `import from <modpath> {` mentioning the name.
- Skip `import from x { def f(...) -> t; ... }` extern braces (c, crypto,
  ssl, z, zstd) -- brace contents are foreign decls, not names.
- Skip implicit-prelude modules: `runtime/builtin.jac` imports like
  `abstractmethod`/`override`/`ClassVar` are the unqualified surface for
  Jac code and comptime eval -- zero in-file uses is NOT dead there.
- Skip anchor/side-effect imports (`import m { x as _anchor }`),
  re-export hubs (`__init__.jac`, `plugin.jac`), and PEP517 hooks.
- Verify with `jac --version` (exercises manifest comptime) + `jac check`,
  not just text scans -- comptime eval failures surface as module-exec
  NameErrors far from the real cause.
