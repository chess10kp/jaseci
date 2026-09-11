"""Exercise JacPython's explicit compile API using pinned upstream tests.

Run through the checkout's Jac binary, for example:
    jac -c 'import runpy; runpy.run_path("scripts/run_cpython_compiler_tests.py", run_name="__main__")'

With --runtime, the patched runtime dispatches built-in compilation and source
imports to JacPython. Test definitions are loaded before activation; bootstrap
compilation and complete C API coverage are separate gates. --compile-tests
also compiles every definition in the chosen upstream module with JacPython.
Without it, tests with no call to the replacement are reported as skipped.
No CPython test corpus is checked into this repository.
"""

import argparse
import builtins
import hashlib
import importlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import types
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
    parser.add_argument(
        "--runtime", action="store_true",
        help="Exercise the patched C runtime instead of module-local wrappers",
    )
    parser.add_argument("--module", default="test.test_compile")
    parser.add_argument(
        "--compile-tests", action="store_true",
        help="Compile the upstream test module itself with JacPython",
    )
    args = parser.parse_args()
    sys.path.insert(0, str(fetch_tests(args.cache)))
    from test import support
    from jaclang.compiler.backends.py.jacpython.code_object import compile_python

    reference_module = importlib.import_module(args.module)
    test_module = reference_module

    support.use_resources = []
    # Pay import/compilation setup outside individual tests and their timers.
    compile_python("pass", "<warmup>", "exec")
    compiled_codes = set()
    if args.compile_tests:
        path = Path(reference_module.__file__)
        test_module = types.ModuleType(reference_module.__name__)
        test_module.__file__ = str(path)
        test_module.__package__ = reference_module.__package__
        test_module.__spec__ = reference_module.__spec__
        code = compile_python(path.read_bytes(), str(path), "exec")
        pending = [code]
        while pending:
            item = pending.pop()
            compiled_codes.add(id(item))
            pending.extend(c for c in item.co_consts if isinstance(c, types.CodeType))
        sys.modules[args.module] = test_module
        try:
            exec(code, test_module.__dict__)
        finally:
            sys.modules[args.module] = reference_module
        print(f"JACPYTHON_TEST_MODULE {args.module}", flush=True)
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
            method = getattr(test, getattr(test, "_testMethodName", "runTest"), None)
            seen = set()
            self.compiled_test = False
            while method is not None and id(method) not in seen:
                seen.add(id(method))
                if id(getattr(method, "__code__", None)) in compiled_codes:
                    self.compiled_test = True
                    break
                method = getattr(method, "__wrapped__", None)
            super().startTest(test)

        def addSuccess(self, test):
            if calls or self.compiled_test:
                super().addSuccess(test)
            else:
                self.addSkip(test, "no direct call to JacPython in this test")

        def stopTest(self, test):
            print(f"JACPYTHON_CALLS {test.id()} {calls}", flush=True)
            super().stopTest(test)

    original = {
        name: test_module.__dict__.get(name)
        for name in ("compile", "eval", "exec")
    }
    if args.runtime:
        import ctypes

        try:
            bridge_version = ctypes.pythonapi._PyJac_CompilerBridgeVersion
        except AttributeError as error:
            raise RuntimeError("Rebuild the Python runtime with the JacPython bridge") from error
        if bridge_version() != 1:
            raise RuntimeError("Unsupported JacPython runtime bridge version")
        if getattr(sys, "_jacpython_compile", None) is not None:
            raise RuntimeError("JacPython runtime dispatch is already enabled")
        sys._jacpython_compile = replacement_compile
    else:
        test_module.compile = replacement_compile
        test_module.eval = replacement_eval
        test_module.exec = replacement_exec
    print("Compiler path:", "C runtime dispatch" if args.runtime else "direct API", flush=True)
    try:
        sys.modules[args.module] = test_module
        if args.tests:
            names = [
                f"TestSpecifics.{name}"
                if name.startswith("test_") and hasattr(test_module, "TestSpecifics")
                else name
                for name in args.tests
            ]
            suite = unittest.defaultTestLoader.loadTestsFromNames(
                names, test_module
            )
        elif not args.compile_tests and args.module == "test.test_compile":
            suite = unittest.defaultTestLoader.loadTestsFromTestCase(
                test_module.TestSpecifics
            )
        else:
            suite = unittest.defaultTestLoader.loadTestsFromModule(test_module)
        result = unittest.TextTestRunner(verbosity=2, resultclass=Result).run(suite)
        return int(not result.wasSuccessful())
    finally:
        sys.modules[args.module] = reference_module
        if args.runtime:
            del sys._jacpython_compile
        for name, value in original.items():
            if value is None:
                test_module.__dict__.pop(name, None)
            else:
                setattr(test_module, name, value)


if __name__ == "__main__":
    sys.exit(main())
