import shutil;
import subprocess;
import from pathlib { Path }
import from jaclang.cli.console { console }
import type from jaclang.project.template_registry { TemplateRegistry }


impl script(name: str = '', list_scripts: bool = False) -> int {
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found. Run 'jac create <name>' to create a project."
        );
        return 1;
    }
    if list_scripts or not name {
        if not config.scripts {
            console.info("No scripts defined in jac.toml.");
            console.print(
                "\nTo add scripts, add a [scripts] section to your jac.toml:",
                style="muted"
            );
            console.print('  [scripts]', style="muted");
            console.print('  dev = "jac run --dev main.jac"', style="muted");
            console.print('  test = "jac test"', style="muted");
            return 0;
        }
        console.print("\nAvailable scripts:\n", style="info");
        for (script_name, script_cmd) in sorted(config.scripts.items()) {
            console.print(f"  {script_name}: {script_cmd}");
        }
        return 0;
    }
    if name not in config.scripts {
        console.error(f"Script '{name}' not found in jac.toml.");
        console.print("\nAvailable scripts:", style="muted");
        for script_name in sorted(config.scripts.keys()) {
            console.print(f"  {script_name}", style="muted");
        }
        return 1;
    }
    script_cmd = config.scripts[name];
    console.info(f"Running: {script_cmd}");
    console.print();
    try {
        result = subprocess.run(
            script_cmd,
            shell=True,
            cwd=str(config.project_root) if config.project_root else None
        );
        return result.returncode;
    } except Exception as e {
        console.error(f"Error running script: {e}");
        return 1;
    }
}

impl clean(
    all: bool = False,
    data: bool = False,
    cache: bool = False,
    packages: bool = False,
    force: bool = False
) -> int {
    import shutil;
    import from jaclang.project.config { get_config }
    config = get_config();
    if config is None {
        console.error(
            "No jac.toml found. Run 'jac create <name>' to create a project."
        );
        return 1;
    }

    dirs_to_clean: list[tuple[str, Path]] = [];

    if all {
        dirs_to_clean.append(("data", config.get_data_dir()));
        dirs_to_clean.append(("cache", config.get_cache_dir()));
        dirs_to_clean.append(("venv", config.get_venv_dir()));
        dirs_to_clean.append(("client", config.get_client_dir()));
    } else {
        if data {
            dirs_to_clean.append(("data", config.get_data_dir()));
        }
        if cache {
            dirs_to_clean.append(("cache", config.get_cache_dir()));
        }
        if packages {
            dirs_to_clean.append(("venv", config.get_venv_dir()));
        }
        if not dirs_to_clean {
            dirs_to_clean.append(("data", config.get_data_dir()));
        }
    }

    existing_dirs = [
        (name, path)
        for (name, path) in dirs_to_clean
        if path.exists()
    ];
    if not existing_dirs {
        console.info("Nothing to clean - no build artifact directories exist.");
        return 0;
    }

    console.print("\nThe following directories will be removed:\n", style="warning");
    for (name, path) in existing_dirs {
        console.print(f"  {name}: {path}", style="muted");
    }
    console.print();

    if not force {
        try {
            response = input("Continue? [y/N] ").strip().lower();
            if response not in ["y", "yes"] {
                console.info("Aborted.");
                return 0;
            }
        } except (EOFError, KeyboardInterrupt) {
            console.print("\nAborted.", style="info");
            return 0;
        }
    }

    errors = 0;
    for (name, path) in existing_dirs {
        try {
            shutil.rmtree(path);
            console.success(f"Removed {name}: {path}");
        } except Exception as e {
            console.error(f"Error removing {name} ({path}): {e}");
            errors += 1;
        }
    }
    if errors > 0 {
        console.error(f"Completed with {errors} error(s).");
        return 1;
    }
    console.success("Clean completed successfully.");
    return 0;
}

impl jacpack(action: str = "", path: str = "", output: str = "") -> int {
    import from jaclang.project.template_registry {
        TemplateRegistry,
        get_template_registry
    }
    import from jaclang.project.template_loader {
        load_template_from_directory,
        load_template_from_json,
        bundle_template
    }
    if not action or action == "list" {
        registry: TemplateRegistry = get_template_registry();
        templates = registry.list_templates();
        if not templates {
            console.print("No templates available.");
            return 0;
        }
        console.print("Available templates:");
        for (tname, desc) in templates {
            console.print(f"  {tname}: {desc}");
        }
        return 0;
    }
    if action == "pack" {
        if not path {
            console.error("Error: Template directory path required.");
            console.print(
                "Usage: jac create --pack <directory> [--pack_output output.jacpack]"
            );
            return 1;
        }
        template_dir = Path(path);
        if not template_dir.is_dir() {
            console.error(f"Error: Not a directory: {template_dir}");
            return 1;
        }

        if output {
            output_path = Path(output);
        } else {
            jac_toml_path = template_dir / "jac.toml";
            if jac_toml_path.exists() {
                import from jaclang.project.tomlio { read_toml_with_encoding }
                jac_config = read_toml_with_encoding(str(jac_toml_path));
                name = jac_config.get("jacpack", {}).get("name", template_dir.name);
            } else {
                name = template_dir.name;
            }
            output_path = Path.cwd() / f"{name}.jacpack";
        }
        try {
            bundle_template(template_dir, output_path);
            return 0;
        } except Exception as e {
            console.error(f"Error bundling template: {e}");
            return 1;
        }
    }
    if action == "info" {
        if not path {
            console.error("Error: Template path required.");
            console.print("Usage: jac jacpack info <path>");
            return 1;
        }
        template_path = Path(path);
        try {
            if template_path.is_dir() {
                tmpl = load_template_from_directory(template_path);
            } elif template_path.suffix == ".json" {
                tmpl = load_template_from_json(template_path);
            } else {
                console.error(f"Error: Unknown template format: {path}");
                return 1;
            }

            console.print(f"Template: {tmpl.name}");
            console.print(f"Description: {tmpl.description}");
            console.print(f"Files: {len(tmpl.files)}");
            for file_path in sorted(tmpl.files.keys()) {
                console.print(f"  - {file_path}");
            }
            console.print(f"Directories: {tmpl.directories}");
            if tmpl.post_create is not None {
                console.print("Post-create hook: Yes");
            }
            return 0;
        } except Exception as e {
            console.error(f"Error loading template: {e}");
            return 1;
        }
    }
    console.error(f"Unknown action: {action}");
    console.print("Available actions: list, pack, info");
    return 1;
}
