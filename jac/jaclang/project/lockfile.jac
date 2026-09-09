"""jac.lock: the project's reproducibility record (repo root, committed).

[jac.<name>]   resolved pure-jac pins: git/path key, requested ref, resolved
               commit, tree hash, version, and the requirers that pulled the
               package in
[python]       harvested pip pins: name -> "==x.y.z"
[python_graph] reverse edges for `jac why`: name -> [requirers]
[npm]          harvested npm pins: name -> installed version

`jac install` replays the file when present: floating pure-jac refs resolve
to the recorded commits (tree hashes verified), python installs the recorded
pins. Fresh resolves merge into it; `jac update` re-resolves floating refs
and rewrites the rows. Python pins are harvested from the venv's installed
metadata after a fresh install; stale entries survive until the next fresh
harvest.
"""

import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig }
import from jaclang.project.providers { manifest_plugin_deps }

glob LOCK_FILE_NAME: str = "jac.lock";


def lock_path(project_root: Path) -> Path {
    return Path(project_root) / LOCK_FILE_NAME;
}


def read_lock(project_root: Path) -> dict {
    path = lock_path(project_root);
    if not path.is_file() {
        return {};
    }
    try {
        text = path.read_text(encoding="utf-8");
    } except OSError {
        return {};
    }
    try {
        import tomllib;
        data = tomllib.loads(text);
    } except Exception {
        console.warning(f"Could not parse {LOCK_FILE_NAME}; ignoring it.");
        return {};
    }
    return data if isinstance(data, dict) else {};
}


def jac_lock_rows(lock_data: dict) -> dict {
    rows = lock_data.get("jac", {});
    return rows if isinstance(rows, dict) else {};
}


def write_lock(project_root: Path, lock_data: dict) -> bool {
    lines: list[str] = [];
    jac_rows = jac_lock_rows(lock_data);
    for name in sorted(jac_rows.keys()) {
        row = jac_rows[name];
        if not isinstance(row, dict) {
            continue;
        }
        lines.append(f"[jac.{name}]");
        for field in ("git", "path", "ref", "sha", "tree", "version") {
            value = str(row.get(field, ""));
            if value {
                lines.append(f'{field} = "{value}"');
            }
        }
        reqs = row.get("requested_by", []);
        if isinstance(reqs, list) and reqs {
            inner = ", ".join(f'"{r}"' for r in reqs);
            lines.append(f"requested_by = [{inner}]");
        }
        lines.append("");
    }
    py_pins = lock_data.get("python", {});
    if isinstance(py_pins, dict) and py_pins {
        lines.append("[python]");
        for name in sorted(py_pins.keys()) {
            lines.append(f'{name} = "{py_pins[name]}"');
        }
        lines.append("");
    }
    py_graph = lock_data.get("python_graph", {});
    if isinstance(py_graph, dict) and py_graph {
        lines.append("[python_graph]");
        for name in sorted(py_graph.keys()) {
            reqs = py_graph[name];
            if isinstance(reqs, list) and reqs {
                inner = ", ".join(f'"{r}"' for r in reqs);
                lines.append(f"{name} = [{inner}]");
            }
        }
        lines.append("");
    }
    npm_pins = lock_data.get("npm", {});
    if isinstance(npm_pins, dict) and npm_pins {
        lines.append("[npm]");
        for name in sorted(npm_pins.keys()) {
            lines.append(f'{name} = "{npm_pins[name]}"');
        }
        lines.append("");
    }
    try {
        lock_path(project_root).write_text(
            "\n".join(lines) + "\n", encoding="utf-8"
        );
    } except OSError as e {
        console.error(f"Could not write {LOCK_FILE_NAME}: {e}");
        return False;
    }
    return True;
}


def update_jac_rows(project_root: Path, resolved: dict) -> bool {
    # merge the resolved pure-jac closure into the [jac.*] rows
    lock_data = read_lock(project_root);
    rows: dict = {};
    for pkg in resolved.values() {
        row = {
            "version": pkg.version,
            "ref": pkg.ref,
            "sha": pkg.sha,
            "tree": pkg.tree,
            "requested_by": sorted(pkg.requested_by),
        };
        if pkg.source == "path" {
            row["path"] = pkg.key;
        } else {
            row["git"] = pkg.key;
        }
        rows[pkg.name] = row;
    }
    lock_data["jac"] = rows;
    return write_lock(project_root, lock_data);
}


def update_python_rows(
    project_root: Path, pins: dict, py_graph: dict, npm_pins: dict | None = None
) -> bool {
    # merge harvested python pins/graph (and optional npm pins)
    lock_data = read_lock(project_root);
    lock_data["python"] = pins;
    lock_data["python_graph"] = py_graph;
    if npm_pins is not None {
        lock_data["npm"] = npm_pins;
    }
    return write_lock(project_root, lock_data);
}


def harvest_python_lock(config: JacConfig, venv_dir: Path) -> tuple[dict, dict] {
    # (pins, graph) for the python closure, read from installed metadata:
    # walk the venv's installed distributions starting from the direct
    # [dependencies]/[dev-dependencies] names in jac.toml. Names are
    # normalized per PEP 503; pins record "==<installed version>".
    import from jaclang.project.pyvenv { get_venv_site_packages }
    site = get_venv_site_packages(venv_dir);
    if not site or not Path(site).is_dir() {
        return ({}, {});
    }
    import importlib.metadata;
    import re;

    def norm(name: str) -> str {
        return re.sub(r"[-_.]+", "-", name).lower();
    }

    by_norm: dict = {};
    try {
        for dist in importlib.metadata.distributions(path=[str(site)]) {
            meta = dist.metadata;
            name = meta.get("Name") if meta is not None else None;
            if not name {
                continue;
            }
            by_norm[norm(str(name))] = dist;
        }
    } except Exception {
        return ({}, {});
    }
    roots = [
        norm(str(n))
        for n in list(config.dependencies.keys())
        + list(config.dev_dependencies.keys())
    ];
    pins: dict = {};
    py_graph: dict = {};
    seen: set[str] = set();
    queue: list[tuple] = [];
    for dep_name in roots {
        if dep_name in by_norm and dep_name not in seen {
            seen.add(dep_name);
            queue.append((dep_name, "root"));
        }
    }
    while queue {
        (nname, requirer) = queue.pop(0);
        dist = by_norm[nname];
        meta = dist.metadata;
        version = str(meta.get("Version") or "");
        if version {
            pins[nname] = f"=={version}";
        }
        reqs = py_graph.setdefault(nname, []);
        if requirer not in reqs {
            reqs.append(requirer);
        }
        if meta is None {
            continue;
        }
        req_list = meta.get_all("Requires-Dist") or [];
        for raw in req_list {
            raw = str(raw);
            marker = raw.split(";", 1)[1] if ";" in raw else "";
            if "extra" in marker {
                continue;
            }
            req_name = norm(
                re.split(r"[<>=!~\[\]]", raw.split(";", 1)[0], 1)[0].strip()
            );
            if not req_name or req_name not in by_norm {
                continue;
            }
            edge_row = py_graph.setdefault(req_name, []);
            if nname not in edge_row {
                edge_row.append(nname);
            }
            if req_name not in seen {
                seen.add(req_name);
                queue.append((req_name, nname));
            }
        }
    }
    return (pins, py_graph);
}


def harvest_npm_lock(config: JacConfig) -> dict {
    # direct npm deps' installed versions from the project's node_modules
    if config.project_root is None {
        return {};
    }
    import json;
    (deps, dev_deps) = manifest_plugin_deps(config, "npm");
    pins: dict = {};
    for name in list(deps.keys()) + list(dev_deps.keys()) {
        meta_path = (
            Path(str(config.project_root))
            / "node_modules"
            / str(name)
            / "package.json"
        );
        try {
            meta = json.loads(meta_path.read_text(encoding="utf-8"));
            pins[str(name)] = str(meta.get("version", ""));
        } except (OSError, ValueError) {
            continue;
        }
    }
    return {k: v for (k, v) in pins.items() if v};
}
