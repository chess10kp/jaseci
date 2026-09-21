import os;
import tempfile;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig, serialize_toml }
import from jaclang.project.providers { manifest_plugin_deps }
import from jaclang.project.versioning { norm_pkg_name }

glob LOCK_FILE_NAME: str = "jac.lock",
     LOCK_VERSION: int = 2;


def lock_path(project_root: Path) -> Path {
    return Path(project_root) / LOCK_FILE_NAME;
}


def read_lock(project_root: Path) -> dict[str, any] {
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
    } except Exception as e {
        console.warning(f"Could not parse {path}; ignoring it: {e}");
        return {};
    }
    if "version" not in data {
        data["version"] = 1;
    }
    if int(data.get("version", 1)) < 2 {
        data["legacy_version"] = int(data.get("version", 1));
        if data.get("python") or data.get("npm") or data.get("python_graph") {
            data["legacy_partial"] = True;
        }
    }
    return data if isinstance(data, dict) else {};
}

def jac_lock_rows(lock_data: dict[str, any]) -> dict[str, any] {
    rows = lock_data.get("jac", {});
    if isinstance(rows, dict) and rows {
        return rows;
    }
    nodes = lock_data.get("nodes", {});
    edges = lock_data.get("edges", []);
    if not isinstance(nodes, dict) {
        return {};
    }
    requirers: dict[str, list[str]] = {};
    if isinstance(edges, list) {
        for graph_edge in edges {
            if not isinstance(graph_edge, dict) {
                continue;
            }
            target = str(graph_edge.get("to_id", ""));
            parent = str(graph_edge.get("from_id", ""));
            if target.startswith("jac:") {
                requirers.setdefault(target, []).append(
                    "root" if parent == "root" else parent.removeprefix("jac:")
                );
            }
        }
    }
    result: dict[str, any] = {};
    for (node_id, graph_node) in nodes.items() {
        if not isinstance(graph_node, dict) or not str(node_id).startswith("jac:") {
            continue;
        }
        alias = str(graph_node.get("alias", str(node_id)[4:]));
        row = {
            "version": str(graph_node.get("version", "")),
            "ref": str(graph_node.get("ref", "")),
            "sha": str(graph_node.get("commit", "")),
            "tree": str(graph_node.get("tree", "")),
            "requested_by": sorted(requirers.get(str(node_id), []))
        };
        if str(graph_node.get("source", "")) == "path" {
            row["path"] = str(graph_node.get("source_location", ""));
        } else {
            row["git"] = str(graph_node.get("source_location", ""));
        }
        result[alias] = row;
    }
    return result;
}


def _lock_doc(lock_data: dict[str, any]) -> dict[str, any] {
    # The single jac.lock document builder: v2 graph plus the legacy `[jac]`
    # rows derived from it via jac_lock_rows (the one compat seam).
    doc: dict[str, any] = {};
    doc["version"] = LOCK_VERSION;
    if lock_data.get("manifest_fingerprint") {
        doc["manifest_fingerprint"] = str(lock_data["manifest_fingerprint"]);
    }
    if "include_dev" in lock_data {
        doc["include_dev"] = bool(lock_data["include_dev"]);
    }
    graph_nodes = lock_data.get("nodes", {});
    if isinstance(graph_nodes, dict) and graph_nodes {
        doc["nodes"] = {
            str(node_id): graph_nodes[node_id]
            for node_id in sorted(graph_nodes.keys())
            if isinstance(graph_nodes[node_id], dict)
        };
    }
    graph_edges = lock_data.get("edges", []);
    if isinstance(graph_edges, list) and graph_edges {
        doc["edges"] = [
            graph_edge
            for graph_edge in graph_edges
            if isinstance(graph_edge, dict)
        ];
    }
    jac_rows = jac_lock_rows(lock_data);
    jac_doc: dict[str, any] = {};
    for name in sorted(jac_rows.keys()) {
        row = jac_rows[name];
        if not isinstance(row, dict) {
            continue;
        }
        entry_row: dict[str, any] = {};
        for field in ("git", "path", "ref", "sha", "tree", "version") {
            value = str(row.get(field, ""));
            if value {
                entry_row[field] = value;
            }
        }
        reqs = row.get("requested_by", []);
        if isinstance(reqs, list) and reqs {
            entry_row["requested_by"] = [str(r) for r in reqs];
        }
        jac_doc[str(name)] = entry_row;
    }
    if jac_doc {
        doc["jac"] = jac_doc;
    }
    py_pins = lock_data.get("python", {});
    if isinstance(py_pins, dict) and py_pins {
        pins_doc: dict[str, any] = {};
        for name in sorted(py_pins.keys()) {
            pins_doc[str(name)] = str(py_pins[name]);
        }
        doc["python"] = pins_doc;
    }
    py_graph = lock_data.get("python_graph", {});
    if isinstance(py_graph, dict) and py_graph {
        graph_doc: dict[str, any] = {};
        for name in sorted(py_graph.keys()) {
            reqs = py_graph[name];
            if isinstance(reqs, list) and reqs {
                graph_doc[str(name)] = [str(r) for r in reqs];
            }
        }
        if graph_doc {
            doc["python_graph"] = graph_doc;
        }
    }
    npm_pins = lock_data.get("npm", {});
    if isinstance(npm_pins, dict) and npm_pins {
        npm_doc: dict[str, any] = {};
        for name in sorted(npm_pins.keys()) {
            npm_doc[str(name)] = str(npm_pins[name]);
        }
        doc["npm"] = npm_doc;
    }
    return doc;
}


def write_atomic(path: Path, text: str) -> None {
    # The one durable temp-and-replace writer for generated lock/manifest
    # documents: write a sibling temp file, fsync it, then atomically swap
    # it into place so a crash can never leave a torn file behind.
    path.parent.mkdir(parents=True, exist_ok=True);
    (fd, tmp_name) = tempfile.mkstemp(prefix=path.name + ".", dir=str(path.parent));
    tmp = Path(tmp_name);
    try {
        with os.fdopen(fd, "w", encoding="utf-8") as stream {
            stream.write(text);
            stream.flush();
            os.fsync(stream.fileno());
        }
        os.replace(str(tmp), str(path));
    } except Exception {
        tmp.unlink(missing_ok=True);
        raise;
    }
}


def write_lock(project_root: Path, lock_data: dict[str, any]) -> bool {
    text = serialize_toml(_lock_doc(lock_data)) + "\n";
    try {
        write_atomic(lock_path(project_root), text);
    } except OSError as e {
        console.error(f"Could not write {LOCK_FILE_NAME}: {e}");
        return False;
    }
    return True;
}


def update_python_rows(
    project_root: Path,
    pins: dict[str, any] | None,
    py_graph: dict[str, any] | None,
    npm_pins: dict[str, any] | None = None
) -> bool {
    lock_data = read_lock(project_root);
    if pins is not None {
        lock_data["python"] = pins;
    }
    if py_graph is not None {
        lock_data["python_graph"] = py_graph;
    }
    if npm_pins is not None {
        lock_data["npm"] = npm_pins;
    }
    return write_lock(project_root, lock_data);
}


def harvest_python_lock(
    config: JacConfig, venv_dir: Path
) -> tuple[dict[str, any], dict[str, any]] | None {
    import from jaclang.project.pyvenv { get_venv_site_packages }
    site = get_venv_site_packages(venv_dir);
    if not site or not Path(site).is_dir() {
        return None;
    }
    import importlib.metadata;
    import re;

    by_norm: dict[str, any] = {};
    try {
        for dist in importlib.metadata.distributions(path=[str(site)]) {
            meta = dist.metadata;
            name = meta.get("Name") if meta is not None else None;
            if not name {
                continue;
            }
            by_norm[norm_pkg_name(str(name))] = dist;
        }
    } except Exception {
        return ({}, {});
    }
    roots = [
        norm_pkg_name(str(n))
        for n in list(config.dependencies.keys()) + list(config.dev_dependencies.keys())
    ];
    pins: dict[str, any] = {};
    py_graph: dict[str, any] = {};
    seen: set[str] = set();
    queue: list[tuple[str, str]] = [];
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
            req_name = norm_pkg_name(
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


def harvest_npm_lock(config: JacConfig) -> dict[str, any] | None {
    if config.project_root is None {
        return None;
    }
    import json;
    if not (Path(str(config.project_root)) / "node_modules").is_dir() {
        return None;
    }
    (deps, dev_deps) = manifest_plugin_deps(config, "npm");
    pins: dict[str, any] = {};
    for name in list(deps.keys()) + list(dev_deps.keys()) {
        meta_path = (
            Path(str(config.project_root)) / "node_modules" / str(name) / "package.json"
        );
        try {
            meta = json.loads(meta_path.read_text(encoding="utf-8"));
            pins[str(name)] = str(meta.get("version", ""));
        } except (OSError, ValueError) {
            continue;
        }
    }
    return {
        k: v
        for (k, v) in pins.items()
        if v
    };
}


def _jac_requirers(rows: dict[str, any], cur: str) -> list[str] {
    row = rows.get(cur);
    if isinstance(row, dict) {
        reqs = row.get("requested_by", []);
        if isinstance(reqs, list) {
            return [
                str(r)
                for r in reqs
                if isinstance(r, str)
            ];
        }
    }
    return [];
}


def _graph_requirers(mapping: dict[str, any], cur: str) -> list[str] {
    reqs = mapping.get(cur, []);
    if isinstance(reqs, list) {
        return [
            str(r)
            for r in reqs
            if isinstance(r, str)
        ];
    }
    return [];
}


def _walk_chains(
    edges: dict[str, any], name: str, requirers_of: any
) -> list[list[str]] {
    found: list[list[str]] = [];

    def walk(cur: str, trail: list[str]) -> None {
        if cur in trail {
            return;
        }
        reqs = requirers_of(edges, cur);
        if not reqs {
            found.append(trail + [cur]);
            return;
        }
        for r in reqs {
            if r == "root" {
                found.append(trail + [cur, "root"]);
            } else {
                walk(str(r), trail + [cur]);
            }
        }
    }

    if name in edges {
        walk(name, []);
    }
    return found;
}


def why_chains(lock_data: dict[str, any], name: str) -> list[tuple[str, list[str]]] {
    # Legacy (pre-v2) lock rows only; v2 graph locks go through
    # graph_why_chains (see the `why` command impl).
    jac_rows = jac_lock_rows(lock_data);
    py_graph = lock_data.get("python_graph", {});
    if not isinstance(py_graph, dict) {
        py_graph = {};
    }
    npm_pins = lock_data.get("npm", {});
    if not isinstance(npm_pins, dict) {
        npm_pins = {};
    }

    chains: list[tuple[str, list[str]]] = [];
    for chain in _walk_chains(jac_rows, name, _jac_requirers) {
        chains.append(("jac", chain));
    }
    for chain in _walk_chains(py_graph, name, _graph_requirers) {
        chains.append(("python", chain));
    }

    if name in npm_pins and ("npm", [name]) not in chains {
        chains.append(("npm", [name]));
    }
    if chains {
        return chains;
    }
    fallback = "npm" if name in npm_pins else ("python" if name in py_graph else "jac");
    return [(fallback, [name])];
}

def graph_why_chains(
    lock_data: dict[str, any], selector: str
) -> tuple[list[list[str]], str | None] {
    nodes = lock_data.get("nodes", {});
    edges = lock_data.get("edges", []);
    if not isinstance(nodes, dict) or not isinstance(edges, list) {
        return ([], None);
    }
    matches: list[str] = [];
    for raw_id in nodes.keys() {
        node_id = str(raw_id);
        node_data = nodes[node_id];
        alias = str(node_data.get("alias", "")) if isinstance(node_data, dict) else "";
        if selector == node_id or selector == alias {
            matches.append(node_id);
        }
    }
    if len(matches) != 1 {
        return ([], None if not matches else "ambiguous");
    }
    target = matches[0];
    parents: dict[str, list[str]] = {};
    for graph_edge in edges {
        if not isinstance(graph_edge, dict) {
            continue;
        }
        child = str(graph_edge.get("to_id", ""));
        parent = str(graph_edge.get("from_id", "root"));
        parents.setdefault(child, []).append(parent);
    }
    chains: list[list[str]] = [];
    pending: list[tuple[str, list[str]]] = [(target, [])];
    while pending {
        (cur, trail) = pending.pop();
        if cur in trail {
            chains.append(trail + ["[cycle]"]);
            continue;
        }
        current = trail + [cur];
        reqs = parents.get(cur, []);
        if not reqs {
            chains.append(current + ["root"]);
            continue;
        }
        for parent in reqs {
            if parent == "root" {
                chains.append(current + ["root"]);
            } else {
                pending.append((parent, current));
            }
        }
    }
    return (chains, target);
}
