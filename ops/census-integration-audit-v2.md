# Census audit: wp/7546-integration @ 5b989e571

Compared against `origin/jac-python` @ 6c631027a (2026-08-28).

## Annex modules present (esast_gen_pass)

Integration branch has **9** `.impl.jac` annex slices (jac-python HEAD has **1** monolithic `esast_gen_pass.impl.jac`):

| Module | Lines | jac check |
|--------|------:|-----------|
| `esast_gen_pass.async.impl.jac` | 109 | PASS |
| `esast_gen_pass.comprehensions.impl.jac` | 204 | PASS |
| `esast_gen_pass.funcdef.impl.jac` | 769 | 26e/2w |
| `esast_gen_pass.impl.jac` | 5357 | 82e/54w |
| `esast_gen_pass.imports.impl.jac` | 431 | 13e/4w |
| `esast_gen_pass.jsx.impl.jac` | 483 | 15e/2w |
| `esast_gen_pass.literals.impl.jac` | 212 | PASS |
| `esast_gen_pass.runtime_imports.impl.jac` | 54 | PASS |
| `esast_gen_pass.spawn.impl.jac` | 535 | 1e |

Main entry `esast_gen_pass.jac`: **701** lines, **137e/101w** (jac-python main: 690 lines, **145e/108w**).

## ceval split (integration)

| File | Lines | jac check |
|------|------:|-----------|
| `ceval.jac` | 13951 | 27e/854w |
| `ceval_exec_frame.jac` | 2812 | 22e/55w |
| `ceval_bridge_guest.jac` | 853 | 1e/7w |
| `ceval_exceptions.jac` | 759 | 1e/129w |
| `ceval_host_bridge.jac` | 768 | PASS |
| `ceval_opcodes_containers.jac` | 366 | PASS |
| `ceval_slice.jac` | 4 | PASS |

jac-python HEAD: monolithic `ceval.jac` **18582** lines, **45e/895w**; `ceval_slice.jac` PASS.

## Error count delta vs jac-python HEAD

| Target | Integration | jac-python HEAD | Δ errors |
|--------|------------:|----------------:|---------:|
| esast main | 137 | 145 | −8 |
| esast impl slice(s) | 82 (split) | 145 (monolith) | −63 |
| ceval main | 27 | 45 | −18 |

Annex passes: async, comprehensions, literals, runtime_imports, ceval_host_bridge, ceval_opcodes_containers, ceval_slice.

Remaining red slices: funcdef (26e), imports (13e), jsx (15e), spawn (1e), ceval_exec_frame (22e), ceval_bridge_guest (1e), ceval_exceptions (1e).
