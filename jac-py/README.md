# CPython replacement implementations

`jacpython/` contains the Jac interpreter, compiler, object implementations,
module facades, and their focused regression tests. These are development
implementations; the release runtime still builds CPython's C sources through
`jac/bootstrap/python/`. A Jac implementation does not by itself make the
corresponding C source removable.

`tests/` holds focused module parity tests. Bulk converted CPython suites,
historical lift snapshots, campaign manifests, and debugging probes are not
part of this tree. They remain available in Git history.

`LICENSE.cpython` preserves the upstream license for CPython-derived code and
generated sources; source-file headers identify the corresponding originals.

`tools/` retains generators for the Python grammar, AST, tokens, and opcodes,
plus the host-oracle bridges and dependency checks used by the retained tests. Fetch the pinned CPython 3.14.6 reference when regenerating:

```sh
python3 jac-py/tools/fetch_cpython_reference.py
python3 jac-py/tools/asdl2jac.py --check
python3 jac-py/tools/tokens2jac.py --check
python3 jac-py/tools/grammar2jac.py --check
python3 jac-py/tools/opcode_meta2jac.py --check
python3 jac-py/tools/p4_import_gate.py
python3 jac-py/tools/p3_import_cycle_gate.py
```

The reference checkout is ignored and is not a release build input. Run
JacPython tests with `JACPATH=jac-py/jacpython` and, for bytecode comparisons,
`JACPYTHON_CPYTHON` pointing to a CPython 3.14.6 executable. CI runs generator,
interpreter, and module regression checks.
