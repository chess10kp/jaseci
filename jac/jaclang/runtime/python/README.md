# JacPython implementation

JacPython is organized by responsibility:

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python tokens, tokenizer, PEG parser, AST, validation and symbol tables |
| `jac/jaclang/compiler/backends/py/jacpython/` | Python bytecode generation, control flow and assembly |
| `jac/jaclang/runtime/python/` | Interpreter, objects, marshal reader and Python module implementations |
| `scripts/python/` | Generators for AST nodes, tokens, grammar and opcode metadata |

Imports use the `jaclang` package paths; no `JACPATH` setting is required.
These are development implementations. They ship as source and are excluded
from the compiler bootstrap and sealed release runtime. Releases still build
CPython's C sources through `jac/bootstrap/python/`.

`host_compile.jac` and `host_compile_bridge.py` retain the pinned host compiler
needed for dataclass method generation. They require CPython 3.14.6, selected
with `JACPYTHON_CPYTHON` or discovered locally.

To regenerate sources from the pinned CPython reference, run from the repository
root:

```sh
python3 scripts/python/fetch_cpython_reference.py
python3 scripts/python/asdl2jac.py
python3 scripts/python/tokens2jac.py
python3 scripts/python/grammar2jac.py
python3 scripts/python/opcode_meta2jac.py
```

Each generator accepts `--check` to verify its checked-in output. The ignored
`reference/cpython` checkout is a generator input, not a release build input.

Bundled JacPython test suites, fixtures and test-only helpers have been removed.
A future CI workflow will run CPython's upstream tests through Jac; that workflow
is not implemented here. Jac's own compiler and runtime regression suites remain.

[`LICENSE.cpython`](LICENSE.cpython) applies to CPython-derived code and generated
sources across these packages. File headers identify their upstream origins.
