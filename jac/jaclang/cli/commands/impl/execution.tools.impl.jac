import sys;
import from pathlib { Path }
import from jaclang.cli.console { console }
import type from importlib.metadata { EntryPoint }


def _tool_site_dirs(use_global: bool) -> list[tuple[str, Path]] {
    import from jaclang.project.tool_paths { python_project_site, python_global_site }

    sites: list[tuple[str, Path]] = [];
    if not use_global {
        proj_site = python_project_site();
        if proj_site is not None {
            sites.append(("project", proj_site));
        }
    }
    glob_site = python_global_site();
    if glob_site is not None {
        sites.append(("global", glob_site));
    }
    return sites;
}

def _console_scripts_in(site_dir: Path) -> list[tuple[str, str, EntryPoint]] {
    import from importlib.metadata { distributions }

    found: list[tuple[str, str, EntryPoint]] = [];
    if not site_dir.exists() {
        return found;
    }
    for dist in distributions(path=[str(site_dir)]) {
        dist_name = dist.metadata["Name"] if dist.metadata else None;
        dist_name = dist_name or "?";
        for ep in dist.entry_points {
            if ep.group == "console_scripts" {
                found.append((ep.name, dist_name, ep));
            }
        }
    }
    return found;
}

def _node_tools_in(bin_dir: Path | None) -> list[str] {
    names: set[str] = set();
    if bin_dir is None or not bin_dir.exists() {
        return [];
    }
    for `entry in bin_dir.iterdir() {
        if `entry.is_dir() {
            continue;
        }
        base = `entry.name;
        for suffix in [".cmd", ".ps1", ".exe", ".bat"] {
            if base.endswith(suffix) {
                base = base[:-len(suffix)];
                break;
            }
        }
        if base and not base.startswith(".") {
            names.add(base);
        }
    }
    return sorted(names);
}

def _find_node_tool(bin_dir: Path | None, name: str) -> Path | None {
    if bin_dir is None or not bin_dir.exists() {
        return None;
    }
    for candidate in [
        name,
        name + ".cmd",
        name + ".exe",
        name + ".bat",
        name + ".ps1"
    ] {
        shim = bin_dir / candidate;
        if shim.exists() {
            return shim;
        }
    }
    return None;
}

def _run_entry_point(
    name: str, ep: EntryPoint, site_dir: Path, args: list[str]
) -> int {
    saved_path = list(sys.path);
    saved_argv = sys.argv;
    site_str = str(site_dir);
    if site_str in sys.path {
        sys.path.remove(site_str);
    }
    sys.path.insert(0, site_str);
    try {
        try {
            func = ep.load();
        } except Exception as e {
            console.error(f"Failed to load tool '{name}': {e}");
            return 1;
        }
        sys.argv = [name] + list(args);
        result = func();
        return result if isinstance(result, int) else 0;
    } except SystemExit as se {
        if se.code is None {
            return 0;
        }
        if isinstance(se.code, int) {
            return se.code;
        }
        console.error(str(se.code));
        return 1;
    } finally {
        sys.argv = saved_argv;
        sys.path.clear();
        sys.path.extend(saved_path);
    }
}

def _run_node_tool(name: str, bin_path: Path, args: list[str]) -> int {
    import subprocess;
    import from jaclang.project.config { get_config }
    import from jaclang.client.bun_installer { get_bun }

    bun = get_bun();
    if bun is None {
        console.error(
            f"Cannot run npm tool '{name}': the bun runtime is unavailable.",
            hint="Install bun, or run the project once (e.g. 'jac run') to let jac provision it."
        );
        return 1;
    }
    config = get_config();
    cwd = str(config.project_root) if config and config.project_root else None;
    result = subprocess.run([bun, str(bin_path)] + list(args), cwd=cwd);
    return result.returncode;
}

def _tool_tiers(use_global: bool, use_node: bool) -> list[tuple[str, str, Path]] {
    import from jaclang.project.config { get_config }
    import from jaclang.project.tool_paths {
        python_project_site,
        python_global_site,
        node_bin_dir
    }

    config = get_config();

    universe: list[tuple[str, str, Path]] = [];
    proj_py = python_project_site(config);
    if proj_py is not None {
        universe.append(("project", "py", proj_py));
    }
    proj_node = node_bin_dir("project", config);
    if proj_node is not None {
        universe.append(("project", "node", proj_node));
    }
    glob_py = python_global_site();
    if glob_py is not None {
        universe.append(("global", "py", glob_py));
    }
    glob_node = node_bin_dir("global", config);
    if glob_node is not None {
        universe.append(("global", "node", glob_node));
    }

    tiers = universe;
    if use_global {
        tiers = [
            t
            for t in tiers
            if t[0] == "global"
        ];
    }
    if use_node {
        tiers = [
            t
            for t in tiers
            if t[1] == "node"
        ];
    }
    return tiers;
}

def _list_tools(tiers: list[tuple[str, str, Path]]) -> int {
    seen: set[str] = set();
    rows: list[tuple[str, str, str]] = [];
    for (label, kind, loc) in tiers {
        if kind == "py" {
            for (script_name, dist_name, _ep) in _console_scripts_in(loc) {
                if script_name in seen {
                    continue;
                }
                seen.add(script_name);
                rows.append((script_name, dist_name, label));
            }
        } else {
            for tool_name in _node_tools_in(loc) {
                if tool_name in seen {
                    continue;
                }
                seen.add(tool_name);
                rows.append((tool_name, "npm", label));
            }
        }
    }
    if not rows {
        console.info(
            "No CLI tools available. Install one with 'jac install <package>' "
            "(project Python), 'jac install --global <package>' (global Python), "
            "'jac install --npm <package>' (project npm), or "
            "'jac install --npm --global <package>' (global npm)."
        );
        return 0;
    }
    console.print("\nAvailable CLI tools (run with 'jac x <name>'):\n", style="info");
    width = max([len(r[0]) for r in rows]);
    for (tool_name, origin, label) in sorted(rows) {
        console.print(f"  {tool_name.ljust(width)}  {origin} [{label}]");
    }
    return 0;
}

impl x(
    name: str = "",
    use_global: bool = False,
    use_node: bool = False,
    list_tools: bool = False,
    args: list[str] = []
) -> int {
    tiers = _tool_tiers(use_global, use_node);

    if list_tools or not name {
        return _list_tools(tiers);
    }

    import from jaclang.project.config { get_config }
    cfg_x = get_config();
    if cfg_x is not None and name in (cfg_x.scripts or {}) {
        import from jaclang.cli.commands.project { script }
        return script(name=name);
    }

    for (label, kind, loc) in tiers {
        if kind == "py" {
            for (script_name, _dist_name, ep) in _console_scripts_in(loc) {
                if script_name == name {
                    return _run_entry_point(name, ep, loc, args);
                }
            }
        } else {
            bin_path = _find_node_tool(loc, name);
            if bin_path is not None {
                return _run_node_tool(name, bin_path, args);
            }
        }
    }

    searched = ", ".join([f"{label} ({loc})" for (label, kind, loc) in tiers])
        or "no tiers";
    console.error(
        f"No CLI tool named '{name}' found.",
        hint=f"Install it — 'jac install <package>' (project Python), "
        f"'jac install --global <package>' (global Python), "
        f"'jac install --npm <package>' (project npm), or "
        f"'jac install --npm --global <package>' (global npm) — "
        f"then 'jac x {name}'. Searched: {searched}."
    );
    return 1;
}
