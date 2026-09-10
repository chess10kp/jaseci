# Python compiler replacement

The retained JacPython code targets Python source compilation. CPython remains
the execution engine, object runtime and standard library.

| Location (from repository root) | Responsibility |
| --- | --- |
| `jac/jaclang/compiler/frontend/python/` | Python tokens, tokenizer, PEG parser, AST, validation and symbol tables |
| `jac/jaclang/compiler/backends/py/jacpython/` | Python bytecode generation, control flow and assembly |
| `jac/jaclang/runtime/python/` | Compiler values and code objects, opcode metadata and the symbol-table adapter |
| `scripts/python/` | Generators for AST nodes, tokens, grammar and opcode metadata |

Imports use the `jaclang` package paths; no `JACPATH` setting is required.
These are development implementations. They ship as source and are excluded
from the compiler bootstrap and sealed release runtime. Releases still build
CPython's C sources through `jac/bootstrap/python/`.

`product_compile.jac` connects the frontend and backend and produces the
`PyCode` representation in `objects.jac`. The compiler directly depends on
`objects.jac` and `opcode_meta.jac`; their shared support is retained while
compiler-specific values and helpers are separated from interpreter behavior.
`symtable.jac` is a starting point for the public symbol-table interface and
still needs adaptation to CPython's result objects.

The Jac interpreter, standard-library replacements, guest import machinery and
host-compiler subprocess bridge have been removed. Connecting the retained
compiler to CPython code objects, runtime compilation APIs and bootstrap loading
is future work. No CPython C source can be retired on the strength of this
cleanup alone.

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
A future CI workflow will run CPython's upstream compiler tests against the
replacement; that workflow is not implemented here. Jac's own compiler and
runtime regression suites remain.

[`LICENSE.cpython`](LICENSE.cpython) applies to CPython-derived code and generated
sources across these packages. File headers identify their upstream origins.
