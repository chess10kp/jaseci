# Census audit: wp/7546-integration @ origin (ff83b3589)

Ref: #7546 runtime-import emission + esast_gen_pass annex split.

## Annex modules (7/7 present)

| File | jac check |
|------|-----------|
| `esast_gen_pass.jac` | 141 errors, 99 warnings |
| `impl/esast_gen_pass.impl.jac` | 112 errors, 54 warnings |
| `impl/esast_gen_pass.literals.impl.jac` | pass |
| `impl/esast_gen_pass.spawn.impl.jac` | 1 error |
| `impl/esast_gen_pass.imports.impl.jac` | 13 errors, 4 warnings |
| `impl/esast_gen_pass.jsx.impl.jac` | 15 errors, 2 warnings |
| `impl/esast_gen_pass.runtime_imports.impl.jac` | pass |

## #7546 client test

| File | jac check |
|------|-----------|
| `jac/tests/client/test_js_runtime_globals_emission.jac` | 245 errors, 2 warnings (likely cascades from esast_gen_pass type errors) |

## Notes

- Fresh worktree lacks `vendor/typeshed/stdlib/` (metadata only); symlinked from main checkout for local gate.
- Runtime behavior unverified locally; CI gates it.
- Integration branch is not jac-check-clean on the esast_gen_pass family; literals + runtime_imports slices are clean.
