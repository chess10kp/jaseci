# Census audit: wp/7546-integration @ 8867f425e

PR #7546: `@jac/runtime` import injection via `EsastGenPass._inject_runtime_import`.

## Annex modules (esast_gen_pass family)

All 9 `impl/esast_gen_pass.*.impl.jac` annex slices present on `origin/wp/7546-integration`:

| Module | Present |
|--------|---------|
| `esast_gen_pass.impl.jac` | yes |
| `esast_gen_pass.async.impl.jac` | yes |
| `esast_gen_pass.comprehensions.impl.jac` | yes |
| `esast_gen_pass.funcdef.impl.jac` | yes |
| `esast_gen_pass.imports.impl.jac` | yes |
| `esast_gen_pass.jsx.impl.jac` | yes |
| `esast_gen_pass.literals.impl.jac` | yes |
| `esast_gen_pass.runtime_imports.impl.jac` | yes (new in #7546) |
| `esast_gen_pass.spawn.impl.jac` | yes |

## `jac check` (local, dev compiler from jac-python tree)

| File | Result |
|------|--------|
| `esast_gen_pass.jac` | FAIL: E2017 duplicate impl (`funcdef` vs main); spawn E1053; jsx E1099 many |
| `esast_gen_pass.async.impl.jac` | OK |
| `esast_gen_pass.comprehensions.impl.jac` | OK |
| `esast_gen_pass.funcdef.impl.jac` | FAIL: E2017 duplicate `_ability_is_generator` |
| `esast_gen_pass.impl.jac` | FAIL: transitive from parent check |
| `esast_gen_pass.imports.impl.jac` | FAIL: transitive |
| `esast_gen_pass.jsx.impl.jac` | FAIL: E1099 Optional narrowing (`backend`, `jsx_processor`); E1030 `component_call_abi` |
| `esast_gen_pass.literals.impl.jac` | OK (warnings only) |
| `esast_gen_pass.runtime_imports.impl.jac` | OK |
| `esast_gen_pass.spawn.impl.jac` | FAIL: E1053 `rpc_props.append(slot.value)` type mismatch |
| `tests/client/test_js_runtime_globals_emission.jac` | FAIL: 245 errors (stdlib `tarfile.extractfile` Optional, `any` backend param) |

Runtime behavior unverified locally; CI gates it.

## CI / integration

- Desk notes `jac-py P4 gates` FAILURE @8867f425e (P3 import cycle).
- PR test plan item "CI full suite" still unchecked.

## Verdict

Annex set complete. Local `jac check` not green on root `esast_gen_pass.jac`, `funcdef`/`jsx`/`spawn` annexes, or `test_js_runtime_globals_emission.jac`. Integration branch blocked on type-check failures and CI import-cycle gate.
