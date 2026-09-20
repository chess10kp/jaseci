impl _is_secret_path(name: str) -> bool {
    return name == "plugins.scale.secrets"
        or name.startswith("plugins.scale.secrets.")
        or name == "scale.secrets"
        or name.startswith("scale.secrets.");
}


impl _is_dev_section(name: str) -> bool {
    return name == "dev" or name.startswith("dev.");
}


impl sanitized_jac_toml(base: Path) -> (str | None) {
    src = base / "jac.toml";
    if not src.is_file() {
        return None;
    }
    out: list[str] = [];
    pending: list[str] = [];
    in_stripped_section = False;
    current_section = "";
    for line in src.read_text().splitlines() {
        stripped = line.lstrip();
        if stripped.startswith("[") {
            header = stripped.lstrip("[").split("]")[0].strip();
            in_stripped_section = _is_secret_path(header) or _is_dev_section(header);
            current_section = header;
            if in_stripped_section {
                pending = [];
                continue;
            }
            out.extend(pending);
            pending = [];
            out.append(line);
            continue;
        }
        if in_stripped_section {
            continue;
        }
        if stripped == "" or stripped.startswith("#") {
            pending.append(line);
            continue;
        }
        key = stripped.split("=")[0].strip();
        full_key = key if current_section == "" else f"{current_section}.{key}";
        if _is_secret_path(full_key) {
            pending = [];
            continue;
        }
        out.extend(pending);
        pending = [];
        out.append(line);
    }
    out.extend(pending);
    return "\n".join(out) + "\n";
}


impl unresolved_toml_references(text: str, environ: dict[str, str]) -> list[str] {
    import from jaclang.project.config { interpolate_env_vars }
    found: list[str] = [];
    def collect(item: any, path: str) {
        if isinstance(item, dict) {
            for (key, value) in item.items() {
                collect(value, f"{path}.{key}" if path else str(key));
            }
        } elif isinstance(item, list) {
            for (i, element) in enumerate(item) {
                collect(element, f"{path}[{i}]");
            }
        } elif isinstance(item, str) {
            try {
                interpolate_env_vars(item, environ);
            } except ValueError as e {
                found.append(f"{path}: {e}");
            }
        }
    }
    collect(tomllib.loads(text), "");
    return found;
}


impl nested_sanitized_tomls(base: Path) -> dict[str, str] {
    excluded = source_filter_for(base);
    out: dict[str, str] = {};
    for toml_path in sorted(base.rglob("jac.toml")) {
        rel = toml_path.relative_to(base);
        if len(rel.parts) == 1 or excluded.excludes_tree(rel) {
            continue;
        }
        text = sanitized_jac_toml(toml_path.parent);
        if text is not None {
            out[rel.as_posix()] = text;
        }
    }
    return out;
}
