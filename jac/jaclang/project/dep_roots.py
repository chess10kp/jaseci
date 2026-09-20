"""Minimal import-root discovery from the dependency map.

This module must stay importable from the compiler's module resolver
(`modresolver.jac`), so it is deliberately a plain, stdlib-only ``.py``
module: no jac-module imports at module level and no provider, store,
locking, CLI-output, or console concerns. Executing a ``.jac`` module
during the meta-importer bootstrap window would re-enter the partially
initialized runtime, so the only jac-module import here
(``jaclang.project.config``) happens lazily inside ``read_deps_roots``
and tolerates that window.
"""

import json
import os
import shutil
from pathlib import Path
from typing import Any

_deps_roots_cache: dict[str, tuple[float, list[str]]] = {}


def deps_map_path(config: Any) -> Path:
    return Path(str(config.get_build_dir())) / "deps.json"


def _recover_generation(config: Any) -> None:
    deps_root = Path(str(config.get_build_dir())) / "dependencies"
    journal = deps_root / "transaction.json"
    if not journal.is_file():
        return
    try:
        data = json.loads(journal.read_text(encoding="utf-8"))
        generation = Path(str(data.get("generation", "")))
        stage = Path(str(data.get("stage", "")))
        active = Path(
            str(data.get("active", Path(str(config.get_build_dir())) / "packages"))
        )
        if generation.is_dir() and (generation / "packages").is_dir():
            pointer = active.with_name(active.name + ".recover")
            pointer.unlink(missing_ok=True)
            os.symlink(str(generation / "packages"), str(pointer))
            if active.is_symlink() or (active.exists() and not active.is_dir()):
                active.unlink(missing_ok=True)
            elif active.exists():
                shutil.rmtree(active, ignore_errors=True)
            os.replace(str(pointer), str(active))
            if (stage / "deps.json").is_file():
                os.replace(str(stage / "deps.json"), str(deps_map_path(config)))
            project_root = config.project_root or Path.cwd()
            if (stage / "jac.lock").is_file():
                os.replace(str(stage / "jac.lock"), str(Path(project_root) / "jac.lock"))
            if (stage / "jac.toml").is_file() and config.toml_path is not None:
                os.replace(str(stage / "jac.toml"), str(config.toml_path))
            journal.unlink(missing_ok=True)
    except (OSError, ValueError, KeyError):
        return


def read_deps_map(config: Any) -> dict[str, Any]:
    _recover_generation(config)
    map_path = deps_map_path(config)
    try:
        data = json.loads(map_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def read_deps_roots(project_root: Path | str) -> list[str]:
    try:
        from jaclang.project.config import get_config_for_path
    except ImportError:
        # Bootstrap window: the runtime is still initializing and
        # executing config.jac now would re-enter it. The next
        # resolution pass retries discovery.
        return []
    try:
        config = get_config_for_path(Path(str(project_root)))
    except (OSError, ValueError):
        return []
    if config is None:
        return []
    _recover_generation(config)
    map_path = deps_map_path(config)
    if not map_path.is_file():
        return []
    try:
        mtime = map_path.stat().st_mtime
    except OSError:
        return []
    cached = _deps_roots_cache.get(str(map_path))
    if cached is not None and cached[0] == mtime:
        return list(cached[1])
    roots = []
    try:
        data = json.loads(map_path.read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    if not isinstance(data, dict):
        return []
    packages = data.get("packages", [])
    if not isinstance(packages, list):
        return []
    for pkg in packages:
        if not isinstance(pkg, dict):
            continue
        loc = pkg.get("local", "") or pkg.get("root", "")
        if isinstance(loc, str) and loc and os.path.isdir(loc):
            roots.append(loc)
    _deps_roots_cache[str(map_path)] = (mtime, list(roots))
    return roots
