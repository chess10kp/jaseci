impl interpolate_env_vars(value: str, environ: dict[str, str] | None = None) -> str {
    import os;
    import re;
    if not isinstance(value, str) {
        return value;
    }
    source = os.environ if environ is None else environ;

    pattern = r"\$\{([^}:]+)(?:(:[-?])([^}]*))?\}";
    def replace_env_var(`match: re.Match) -> str {
        var_name = `match.group(1);
        operator = `match.group(2);
        operand = `match.group(3) or "";

        env_value = source.get(var_name);

        if env_value is not None {
            return env_value;
        }

        if operator == ":-" {
            return operand;
        } elif operator == ":?" {
            raise ValueError(f"Environment variable {var_name} is required: {operand}");
        }
        if not var_name.isidentifier() {
            return `match.group(0);
        }
        raise ValueError(f"Environment variable {var_name} is not set");
    }
    return re.sub(pattern, replace_env_var, value);
}

impl find_project_root(start: Path | None = None) -> tuple[Path, Path] | None {
    import from jaclang.project.modresolver { find_project_root as _find_project_root }
    return _find_project_root(start);
}

impl is_in_project -> bool {
    return find_project_root() is not None;
}

impl JacConfig.discover(
    start_path: Path | None = None, profile: str | None = None
) -> JacConfig | None {
    import from pathlib { Path }
    result = find_project_root(start_path);
    if result is None {
        return None;
    }
    (project_root, toml_path) = result;
    config = JacConfig.load(toml_path);

    base = start_path if start_path is not None else Path.cwd();
    config.discovered_from_ancestor = project_root.resolve() != base.resolve();
    if profile {
        config.apply_profile_overlay(profile);
    }
    return config;
}

impl JacConfig.load(toml_path: Path) -> JacConfig {
    import from jaclang.project.tomlio { read_toml_with_encoding }
    if not toml_path.exists() {
        raise FileNotFoundError(f"Configuration file not found: {toml_path}");
    }
    data = read_toml_with_encoding(str(toml_path));
    config = _parse_toml_data(data, toml_path);
    config.config_files = [toml_path];
    return config;
}

impl JacConfig.resolve(
    start_path: Path | None = None, profile: str | None = None
) -> JacConfig | None {
    config = JacConfig.discover(start_path=start_path);
    if config is not None {
        config.profile_override = profile.strip() if profile is not None else None;
        selected = config.profile_override
            if config.profile_override is not None
            else active_profile_name(config).strip();
        config.apply_profile_overlay(selected or None);
    }
    return config;
}

impl JacConfig.from_toml_str(
    toml_str: str, toml_path: Path | None = None
) -> JacConfig {
    import tomllib;
    data = tomllib.loads(toml_str);
    return _parse_toml_data(data, toml_path);
}
