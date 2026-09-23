"""The bundled `pathlib` shim must answer exactly what CPython's does.

`import from pathlib { Path }` binds CPython's `pathlib` on the sv pathway and
`na_stdlib/pathlib.jac` on the na pathway, so running one fixture through both
and demanding identical stdout *is* the congruence contract -- CPython is the
oracle, not a hand-copied expectation table.

`pathlib_probe.jac` exercises the whole provided surface: the constructor over
a `str` and over a `Path`, `str()`, f-string interpolation, truthiness,
`.name`, `.stem`, `.parent`, `/`, `.resolve()`, `.exists()` and `.is_dir()`,
including an `obj` carrying a `Path`-typed `has` field with a `Path("")`
default -- the shape `compiler/types/types.jac` declares.
"""

import from tests.support { jac_command, na_run, same_lines, sv_run }

import os;
import subprocess;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "the native Path answers what CPython's Path answers" {
    (sv_out, _sv_err) = sv_run(os.path.join(FIXTURES, "pathlib_probe.jac"));
    (na_out, _na_err) = na_run(os.path.join(FIXTURES, "pathlib_probe.jac"));
    same_lines(sv_out, na_out, "pathlib");
}

test "a Path member outside the provided surface fails the native compile" {
    src = os.path.join(FIXTURES, "pathlib_unsupported.jac");
    out_bin = os.path.join(tempfile.mkdtemp(), "nope.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    combined = (comp.stdout or "") + (comp.stderr or "");
    assert comp.returncode != 0 , f"unsupported Path member compiled silently: {combined[-600:]}";
    assert "suffix" in combined , f"diagnostic does not name the member: {combined[-600:]}";
}
