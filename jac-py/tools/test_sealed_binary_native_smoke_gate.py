"""Unit tests for sealed_binary_native_smoke_gate.py."""

from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_SPEC = importlib.util.spec_from_file_location(
    "sealed_binary_native_smoke_gate",
    _HERE / "sealed_binary_native_smoke_gate.py",
)
assert _SPEC and _SPEC.loader
smoke = importlib.util.module_from_spec(_SPEC)
sys.modules.setdefault("sealed_binary_native_smoke_gate", smoke)
_SPEC.loader.exec_module(smoke)


def test_smoke_suite_paths_exist() -> None:
    for suite in smoke.SMOKE_SUITES:
        assert suite.is_file(), suite
