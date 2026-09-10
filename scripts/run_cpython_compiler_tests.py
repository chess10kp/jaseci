"""Exercise JacPython's explicit compile API using pinned upstream tests.

Run through the checkout's Jac binary, for example:
    jac -c 'import runpy; runpy.run_path("scripts/run_cpython_compiler_tests.py", run_name="__main__")'

Test definitions and reference ASTs still use the host compiler. This runner
does not prove replacement of imports, C entry points or bootstrap compilation.
Tests with no call to the replacement are reported as skipped, not coverage.
No CPython test corpus is checked into this repository.
"""

import argparse
import builtins
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
import urllib.request


def fetch_tests(cache: Path) -> Path:
    repo = Path(__file__).resolve().parents[1]
    pin_path = repo / "jac/bootstrap/python/sources.json"
    pin = json.loads(pin_path.read_text())["cpython"]
    destination = cache / pin["sha256"]
    library = destination / f"Python-{pin['version']}" / "Lib"
    marker = destination / ".complete"
    print(f"CPython {pin['version']} tests; archive SHA256 {pin['sha256']}", flush=True)
    if marker.is_file() and (library / "test/test_compile.py").is_file():
        return library
    with urllib.request.urlopen(pin["url"], timeout=120) as response:
        archive = response.read()
    if hashlib.sha256(archive).hexdigest() != pin["sha256"]:
        raise RuntimeError("CPython test archive checksum mismatch")
    destination.mkdir(parents=True, exist_ok=True)
    prefix = f"Python-{pin['version']}/Lib/test/"
    with tarfile.open(fileobj=io.BytesIO(archive), mode="r:gz") as bundle:
        members = [m for m in bundle if m.isfile() and m.name.startswith(prefix)]
        bundle.extractall(destination, members=members, filter="data")
    marker.write_text(pin["sha256"] + "\n")
    return library


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--cache", type=Path,
        default=Path(tempfile.gettempdir()) / "jac-cpython-tests",
    )
    parser.add_argument(
        "--tests", nargs="+",
        help="TestSpecifics method names; default: entire class",
    )
    args = parser.parse_args()
    sys.path.insert(0, str(fetch_tests(args.cache)))
    from test import support, test_compile
    from jaclang.compiler.backends.py.jacpython.code_object import compile_python

    support.use_resources = []
    # Pay import/compilation setup outside individual tests and their timers.
    compile_python("pass", "<warmup>", "exec")
    calls = 0

    def replacement_compile(*args, **kwargs):
        nonlocal calls
        calls += 1
        return compile_python(*args, **kwargs)

    def replacement_eval(source, globals=None, locals=None):
        frame = sys._getframe(1)
        if globals is None:
            globals = frame.f_globals
            if locals is None:
                locals = frame.f_locals
        if isinstance(source, (str, bytes, bytearray, memoryview)):
            source = replacement_compile(source, "<string>", "eval")
        return builtins.eval(source, globals, locals)

    def replacement_exec(source, globals=None, locals=None, *, closure=None):
        frame = sys._getframe(1)
        if globals is None:
            globals = frame.f_globals
            if locals is None:
                locals = frame.f_locals
        if isinstance(source, (str, bytes, bytearray, memoryview)):
            source = replacement_compile(source, "<string>", "exec")
        return builtins.exec(source, globals, locals, closure=closure)

    class Result(unittest.TextTestResult):
        def startTest(self, test):
            nonlocal calls
            calls = 0
            super().startTest(test)

        def addSuccess(self, test):
            if calls:
                super().addSuccess(test)
            else:
                self.addSkip(test, "no direct call to JacPython in this test")

        def stopTest(self, test):
            print(f"JACPYTHON_CALLS {test.id()} {calls}", flush=True)
            super().stopTest(test)

    original = {
        name: test_compile.__dict__.get(name)
        for name in ("compile", "eval", "exec")
    }
    test_compile.compile = replacement_compile
    test_compile.eval = replacement_eval
    test_compile.exec = replacement_exec
    try:
        if args.tests:
            suite = unittest.TestSuite(
                test_compile.TestSpecifics(name) for name in args.tests
            )
        else:
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(
                test_compile.TestSpecifics
            )
        result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite)
        return int(not result.wasSuccessful())
    finally:
        for name, value in original.items():
            if value is None:
                test_compile.__dict__.pop(name, None)
            else:
                setattr(test_compile, name, value)


if __name__ == "__main__":
    sys.exit(main())
