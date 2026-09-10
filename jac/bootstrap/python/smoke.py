"""The Python distribution must support Jac's bootstrap and native runtime."""
import bz2
import ctypes
import decimal
import hashlib
import lzma
import multiprocessing
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
callback = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_int)(lambda value: value + 1)
assert callback(41) == 42
assert sysconfig.get_config_var("Py_ENABLE_SHARED") == 1
assert sysconfig.get_config_var("CC") == "cc"
ca = Path(sys.executable).resolve().parents[2] / "build" / "cacert.pem"
assert ssl.create_default_context(cafile=str(ca)).cert_store_stats()["x509_ca"] > 0
for library in ("ssl", "crypto", "sqlite3", "mpdec", "lzma", "bz2", "expat", "z", "zstd", "ffi"):
    archive = ca.parent / "lib" / f"lib{library}.a"
    assert archive.is_file() and archive.stat().st_size > 8, archive
xml.parsers.expat.ParserCreate().Parse(b"<jac/>", True)
with tempfile.TemporaryDirectory(prefix="jac-python-venv-") as directory:
    venv.EnvBuilder(with_pip=True).create(directory)
    subprocess.run(
        [str(Path(directory) / "bin/python"), "-I", "-c", "import ssl, sqlite3, pip; assert 6 * 7 == 42"],
        check=True,
    )
print(f"CPython {sys.version.split()[0]}: runtime module checks passed ({ssl.OPENSSL_VERSION})")
