"""The bundled `signal` / `subprocess` modules must answer what CPython answers.

`import signal` and `import subprocess` bind CPython's modules on the sv
pathway and `na_stdlib/signal.jac` / `na_stdlib/subprocess.jac` on the na
pathway, so running one fixture through both and demanding identical
output *is* the congruence contract -- CPython is the oracle, not a
hand-copied expectation table.

`signal_probe.jac` exercises handler install/dispatch through the C-ABI
trampoline (which delivers `(signum, None)` where CPython delivers
`(signum, frame)` -- only the signum is printed), the `SIG_IGN` / `SIG_DFL`
sentinel handlers, `getsignal` shadow lookup, `strsignal`, `alarm`,
`valid_signals`, and `pthread_sigmask` blocking with pending delivery on
unblock.

`subprocess_probe.jac` exercises `run` over list and str args, `shell=True`,
stdout/stderr capture, `stderr=STDOUT` merge, `env` replacement, `cwd`,
`DEVNULL`, `call` / `check_call` / `check_output`, `CalledProcessError`,
`CompletedProcess.check_returncode`, `TimeoutExpired`, and a `Popen`
terminated with SIGTERM (returncode -15 on both lanes). The na
implementation drives the child through fork/dup2/system, so shell
quoting of list args is pinned by the `["sh", "-c", ...]` case.
"""

import from tests.support { jac_command }

import os;
import subprocess;
import sys;
import tempfile;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

def _sv_run(fixture: str) -> tuple[(str, str)] {
    src = os.path.join(FIXTURES, fixture);
    proc = subprocess.run(
        jac_command("run", src), capture_output=True, text=True, timeout=900
    );
    assert proc.returncode == 0 , f"sv run failed: {proc.stderr[-800:]
        if proc.stderr
        else '(empty)'}";
    return (proc.stdout, proc.stderr);
}

def _na_run(fixture: str) -> tuple[(str, str)] {
    src = os.path.join(FIXTURES, fixture);
    out_bin = os.path.join(tempfile.mkdtemp(), "probe.bin");
    comp = subprocess.run(
        jac_command("build", "--native", src, "-o", out_bin),
        capture_output=True,
        text=True,
        timeout=900
    );
    assert comp.returncode == 0 , f"nacompile failed: {comp.stderr[-800:]
        if comp.stderr
        else '(empty)'}";
    proc = subprocess.run([out_bin], capture_output=True, text=True, timeout=120);
    assert proc.returncode == 0 , f"binary failed: {proc.stderr[-400:]
        if proc.stderr
        else '(empty)'}";
    return (proc.stdout, proc.stderr);
}

def _same_lines(sv_text: str, na_text: str, what: str) {
    sv = [
        _l
        for _l in sv_text.split("\n")
        if _l.strip()
    ];
    na = [
        _l
        for _l in na_text.split("\n")
        if _l.strip()
    ];
    assert sv , f"{what}: sv pathway produced no output";
    assert len(sv) == len(na) , f"{what} line count: sv {len(sv)} vs na {len(na)}";
    for idx in range(len(sv)) {
        assert sv[idx] == na[idx] , f"{what} line {idx}: sv {sv[idx]!r} vs na {na[
            idx
        ]!r}";
    }
}

test "native signal answers what CPython's signal answers" {
    (sv_out, _sv_err) = _sv_run("signal_probe.jac");
    (na_out, _na_err) = _na_run("signal_probe.jac");
    _same_lines(sv_out, na_out, "signal");
}

test "native subprocess answers what CPython's subprocess answers" {
    (sv_out, _sv_err) = _sv_run("subprocess_probe.jac");
    (na_out, _na_err) = _na_run("subprocess_probe.jac");
    _same_lines(sv_out, na_out, "subprocess");
}
