"""Shared ``jac`` subprocess helpers for jac-py Python drivers.

GitHub Actions step ``env:`` blocks are not inherited by ``python3 …`` gate
drivers that spawn their own ``jac run`` / ``jac test`` children. Those
subprocesses need an explicit ``JACPATH`` or ceval/replay gates silently
score zero passes (see ``replay_gate.py``).

Use :func:`subprocess_env` in every Python tool that shells out to ``jac`` on
jacpython product-path code. Do **not** set ``JACPATH`` at the whole-workflow
level: ``jac-py/jacpython`` on the host import path breaks jaclang bootstrap,
and oracle steps under ``jac-py/tests`` need ``JACPATH=jac`` instead.
"""

from __future__ import annotations

import os
import shutil
from pathlib import Path
from typing import Literal

REPO_ROOT = Path(__file__).resolve().parents[2]

JacSubprocessProfile = Literal["jacpython", "jac_lang", "jacpython_modules"]

_PROFILE_ENTRIES: dict[JacSubprocessProfile, tuple[str, ...]] = {
    "jacpython": ("jac-py/jacpython",),
    "jac_lang": ("jac",),
    "jacpython_modules": ("jac-py/jacpython", "jac-py/Modules"),
}


def resolve_jac(repo_root: Path | None = None) -> Path | None:
    """``$JAC`` override, then PATH (CI sealed binary), then ``.venv/bin/jac``."""
    env_bin = os.environ.get("JAC")
    if env_bin:
        return Path(env_bin)
    on_path = shutil.which("jac")
    if on_path:
        return Path(on_path)
    root = repo_root or REPO_ROOT
    venv_bin = root / ".venv" / "bin" / "jac"
    return venv_bin if venv_bin.is_file() else None


def jacpath_entries(env: dict[str, str]) -> list[str]:
    raw = env.get("JACPATH", "")
    return [part.strip() for part in raw.split(os.pathsep) if part.strip()]


def ensure_jacpath(env: dict[str, str], *entries: str) -> None:
    """Prepend any missing ``JACPATH`` roots (existing entries stay, order kept)."""
    current = jacpath_entries(env)
    prefix: list[str] = []
    for entry in entries:
        if entry not in current and entry not in prefix:
            prefix.append(entry)
    if prefix:
        env["JACPATH"] = os.pathsep.join(prefix + current)


def _prepend_pythonpath(env: dict[str, str], entry: Path) -> None:
    entry_s = str(entry)
    existing = env.get("PYTHONPATH", "")
    parts = [p for p in existing.split(os.pathsep) if p]
    if entry_s not in parts:
        env["PYTHONPATH"] = (
            entry_s if not existing else f"{entry_s}{os.pathsep}{existing}"
        )


def subprocess_env(
    repo_root: Path | None = None,
    *,
    profile: JacSubprocessProfile = "jacpython",
    include_dev_source: bool | None = None,
) -> dict[str, str]:
    """Environment dict for a ``jac run`` / ``jac test`` child process."""
    root = repo_root or REPO_ROOT
    env = os.environ.copy()
    ensure_jacpath(env, *_PROFILE_ENTRIES[profile])
    if include_dev_source is None:
        include_dev_source = env.get("JAC_NO_DEV_SOURCE", "").strip() not in (
            "1",
            "true",
            "True",
        )
    if include_dev_source:
        jac_src = root / "jac"
        _prepend_pythonpath(env, jac_src)
        env["JAC_DEV_SOURCE"] = str(jac_src)
    return env
