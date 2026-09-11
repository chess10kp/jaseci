"""The Python distribution must support Jac's bootstrap and native runtime."""
import bz2
import ctypes
import decimal
import hashlib
import lzma
import multiprocessing
import platform
from pathlib import Path
import sqlite3
import ssl
import sys
import sysconfig
import subprocess
import tempfile
import venv
import xml.parsers.expat
import zlib
from compression import zstd

assert sys.version_info[:3] == (3, 14, 6), sys.version
if sys.platform == "darwin":
    import _scproxy
sample = b"Jac source-built runtime" * 100
for codec in (bz2, lzma, zlib, zstd):
    assert codec.decompress(codec.compress(sample)) == sample
assert sqlite3.connect(":memory:").execute("select 6 * 7").fetchone() == (42,)
assert str(decimal.Decimal("0.1") + decimal.Decimal("0.2")) == "0.3"
assert hashlib.sha256(sample).digest()
assert ctypes.pythonapi.PyInitConfig_Create
assert ctypes.pythonapi._PyJac_CompilerBridgeVersion() == 2
try:
    required_compiler = ctypes.pythonapi._PyJac_CompilerRequired
except AttributeError:
    required_compiler = None  # The separate build-time interpreter retains C.
if required_compiler is not None:
    assert required_compiler() == 1
    assert sys._jacpython_compile.__module__.startswith("_jacpython_seed.")
    assert sys._jacpython_symtable.__module__.startswith("_jacpython_seed.")
    assert sys._jacpython_tokenize.__module__.startswith("_jacpython_seed.")
    compiler = sys._jacpython_compile

    def unavailable(*args, **kwargs):
        raise RuntimeError("compiler failure must propagate")

    sys._jacpython_compile = unavailable
    try:
        compile("pass", "<no-c-fallback>", "exec")
    except RuntimeError as error:
        assert str(error) == "compiler failure must propagate"
    else:
        raise AssertionError("Compilation bypassed the Jac compiler")
    finally:
        sys._jacpython_compile = compiler
    assert "requests" not in sys._jacpython_image
    sys._jacpython_compile = None
    try:
        compile("pass", "<missing-compiler>", "exec")
    except RuntimeError as error:
        assert "Missing JacPython callback" in str(error)
    else:
        raise AssertionError("Compilation used retired bootstrap code")
    finally:
        sys._jacpython_compile = compiler
    with tempfile.TemporaryDirectory(prefix="jac-python-cold-") as cache:
        for optimization in ([], ["-O"], ["-OO"]):
            subprocess.run(
                [sys.executable, "-I", "-S", "-B", "-X", "pycache_prefix=" + cache]
                + optimization + ["-c", "import ast, encodings, sys; assert eval('6 * 7') == 42; "
                                  "assert isinstance(ast.parse('x=1'), ast.Module); "
                                  "assert encodings.search_function.__code__.co_filename == encodings.__file__; "
                                  "assert sys._jacpython_compile.__module__.startswith('_jacpython_seed.')"],
                check=True,
            )
    interactive = subprocess.run(
        [sys.executable, "-I", "-q", "-i"],
        input="def twice(value):\n    return value * 2\n\nprint('INTERACTIVE', twice(21))\n"
              "from __future__ import annotations\ndef typed(x: Missing):\n    return x\n\n"
              "print(typed.__annotations__)\n",
        text=True, capture_output=True, check=True,
    )
    assert "INTERACTIVE 42" in interactive.stdout, interactive
    assert "{'x': 'Missing'}" in interactive.stdout, interactive
    assert "Traceback" not in interactive.stderr, interactive.stderr
callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int)(lambda value: value + 1)
assert callback(41) == 42
assert sysconfig.get_config_var("Py_ENABLE_SHARED") == 1
assert sysconfig.get_config_var("CC") == "cc"
# configure needs Misc/platform_triplet.c to produce wheel-compatible names.
# An empty platform silently builds a runtime that cannot import tagged wheels.
abi_platform = "darwin" if sys.platform == "darwin" else f"{platform.machine()}-linux-gnu"
assert sysconfig.get_config_var("SOABI") == f"cpython-314-{abi_platform}"
ca = Path(sys.executable).resolve().parents[2] / "build" / "cacert.pem"
assert ssl.create_default_context(cafile=str(ca)).cert_store_stats()["x509_ca"] > 0
for library in ("ssl", "crypto", "sqlite3", "mpdec", "lzma", "bz2", "expat", "z", "zstd", "ffi"):
    archive = ca.parent / "lib" / f"lib{library}.a"
    assert archive.is_file() and archive.stat().st_size > 8, archive
xml.parsers.expat.ParserCreate().Parse(b"<jac/>", True)
with tempfile.TemporaryDirectory(prefix="jac-python-venv-") as directory:
    try:
        venv.EnvBuilder(with_pip=True).create(directory)
    except subprocess.CalledProcessError as error:
        print(error.output.decode(errors="replace") if error.output else str(error), file=sys.stderr)
        raise
    subprocess.run(
        [str(Path(directory) / "bin/python"), "-I", "-c", "import ssl, sqlite3, pip; assert 6 * 7 == 42"],
        check=True,
    )
print(f"CPython {sys.version.split()[0]}: runtime module checks passed ({ssl.OPENSSL_VERSION})")
