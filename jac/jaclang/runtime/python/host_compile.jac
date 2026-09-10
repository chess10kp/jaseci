# Bootstrap compilation used by JacPython dataclass method generation.

import os;
import shutil;
import subprocess;
import sys;
import from pathlib { Path }


def _runner_python() -> str {
    env = os.environ.get("JACPYTHON_CPYTHON", "");
    if env {
        return env;
    }
    for name in ("python3.14", "python3", "python") {
        found = shutil.which(name);
        if found {
            return found;
        }
    }
    return sys.executable;
}


def _bridge_path() -> str {
    return str(Path(__file__).with_name("host_compile_bridge.py"));
}


glob _BRIDGE = _bridge_path();


def _host_compile_marshal_py(source: any, filename: str, mode: str, optimize: int = 0) -> bytes {
    payload = source;
    if isinstance(source, str) {
        payload = source.encode("utf-8");
    }
    proc = subprocess.run(
        [_runner_python(), _BRIDGE, filename, mode, str(optimize)],
        input=payload,
        capture_output=True,
        check=True,
    );
    return proc.stdout;
}


def host_compile_marshal(
    source: str, filename: str, mode: str, optimize: int = 0
) -> list[int] {
    raw = _host_compile_marshal_py(source, filename, mode, optimize);
    return raw as list[int];
}
