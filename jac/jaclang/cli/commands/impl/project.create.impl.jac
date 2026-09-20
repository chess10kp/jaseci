import os;
import tempfile;
import base64;
import from pathlib { Path }
import from jaclang.cli.console { console }
import type from jaclang.project.template_registry { ProjectTemplate, TemplateRegistry }


impl create(
    name: str = '',
    force: bool = False,
    kind: str = "",
    app: str = "",
    path: str = "",
    use: str = "default",
    awesome: bool = False,
    `list: bool = False,
    pack: str = "",
    pack_output: str = "",
    `skip: bool = False,
    style: str | None = None,
    baseColor: str | None = None,
    theme: str | None = None,
    font: str | None = None,
    radius: str | None = None,
    menuAccent: str | None = None,
    menuColor: str | None = None
) -> int {
    if pack {
        return jacpack(action="pack", path=pack, output=pack_output);
    }
    prev_skip_npm = os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL");
    if `skip {
        os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = "1";
    }
    try {
        return _create_body(
            name,
            force,
            kind,
            app,
            path,
            use,
            awesome,
            `list,
            `skip or bool(os.environ.get("JAC_CLIENT_SKIP_NPM_INSTALL")),
            style,
            baseColor,
            theme,
            font,
            radius,
            menuAccent,
            menuColor
        );
    } finally {
        if `skip {
            if prev_skip_npm is None {
                os.environ.pop("JAC_CLIENT_SKIP_NPM_INSTALL", None);
            } else {
                os.environ["JAC_CLIENT_SKIP_NPM_INSTALL"] = prev_skip_npm;
            }
        }
    }
}

def _create_body(
    name: str,
    force: bool,
    kind: str,
    app_name: str,
    app_path: str,
    use: str,
    awesome: bool,
    list_kinds: bool,
    skip_deps: bool,
    style: str | None,
    baseColor: str | None,
    theme: str | None,
    font: str | None,
    radius: str | None,
    menuAccent: str | None,
    menuColor: str | None
) -> int {
    if use == "jac-shadcn" {
        import from jaclang.cli.shadcn.cli { stash_create_theme }
        theme_args = {
            "style": style,
            "baseColor": baseColor,
            "theme": theme,
            "font": font,
            "radius": radius,
            "menuAccent": menuAccent,
            "menuColor": menuColor
        };
        overrides = {
            k: v
            for (k, v) in theme_args.items()
            if v is not None
        };
        stash_create_theme(overrides);
    }
    import from jaclang.project.config { find_project_root }
    import from jaclang.project.template_registry {
        TemplateRegistry,
        get_template_registry
    }
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import from jaclang.project.kinds { is_valid_kind, VALID_KINDS }
    registry: TemplateRegistry = get_template_registry();

    if list_kinds {
        kinds = registry.list_kinds();
        if kinds {
            console.print(
                "\nProject kinds (jac create --kind <kind>):\n", style="info"
            );
            for (kname, desc) in kinds {
                console.print(f"  {kname}: {desc}");
            }
        }
        variants = [
            (tname, desc)
            for (tname, desc) in registry.list_templates()
            if not is_valid_kind(tname)
        ];
        if variants {
            console.print(
                "\nNamed variants (jac create --use <name>):\n", style="info"
            );
            for (tname, desc) in variants {
                console.print(f"  {tname}: {desc}");
            }
        }
        if not kinds and not variants {
            console.info("No project templates available.");
        }
        return 0;
    }

    explicit_use = use != "default";
    if app_name {
        if awesome or explicit_use {
            console.error(
                "--app scaffolds a built-in kind inside the current project; drop --awesome/--use.",
                hint="jac create --app <name> --kind <kind>"
            );
            return 1;
        }
        return _create_app(registry, app_name, kind, app_path, force);
    }
    if kind and explicit_use {
        console.error(
            "Use either --kind or --use, not both.",
            hint="--kind <kind> scaffolds a built-in kind; --use <path|url> a custom template."
        );
        return 1;
    }
    if awesome and (kind or explicit_use) {
        console.error(
            "--awesome is a complete template; drop --kind/--use.",
            hint="jac create <name> --awesome"
        );
        return 1;
    }
    if awesome {
        tmpl = _resolve_awesome_template();
        if tmpl is None {
            console.error(
                "The awesome template is not available in this jac build.",
                hint="It ships inside the released binary's payload (awesome_template beside the jaclang package) or a source checkout's examples/jaclang_org."
            );
            return 1;
        }
        if "apps" not in tmpl.config {
            console.error(
                "The awesome template has no [apps] table; the flagship is a workspace.",
                hint="examples/jaclang_org/jac.toml declares [apps.*]; refresh the bundled awesome_template."
            );
            return 1;
        }
    } elif explicit_use {
        tmpl = _resolve_template(use, registry);
        if tmpl is None {
            console.error(f"Unknown template: {use}");
            console.print(
                "Use --list to see available kinds and named variants.", style="muted"
            );
            return 1;
        }
    } else {
        target_kind = kind or "cli";
        if not is_valid_kind(target_kind) {
            console.error(
                f"Unknown project kind '{target_kind}'.",
                hint=f"Valid kinds: {', '.join(VALID_KINDS)}"
            );
            return 1;
        }
        tmpl = registry.get_by_kind(target_kind);
        if tmpl is None {
            console.error(
                f"No template registered for kind '{target_kind}'.",
                hint="This is unexpected for a core kind; please report it."
            );
            return 1;
        }
    }
    cwd = Path.cwd();
    create_subdir = bool(name);
    if create_subdir {
        project_name = name;
    } else {
        project_name = _project_name_from_cwd(cwd);
        if not project_name {
            console.error(
                "Cannot infer a project name from the current directory.",
                hint="Run from a named directory or pass a project name: jac create myapp"
            );
            return 1;
        }
    }

    if create_subdir {
        project_path = cwd / name;
        if project_path.exists() and not force {
            console.error(
                f"Directory '{name}' already exists. Use --force to overwrite."
            );
            return 1;
        }
        project_path.mkdir(parents=True, exist_ok=True);
    } else {
        project_path = cwd;
        existing = find_project_root(cwd);
        if existing and not force {
            (project_root, toml_path) = existing;

            if Path(project_root).resolve() == cwd.resolve() {
                console.error(f"Already in a Jac project: {toml_path}");
                console.print("Use --force to reinitialize.", style="muted");
                return 1;
            }
            console.warning(
                f"Creating a nested project inside {project_root}; the "
                "nearest jac.toml wins for files under this directory.",
                emoji=False
            );
        }
    }
    project_path.mkdir(parents=True, exist_ok=True);
    toml_path = project_path / "jac.toml";
    if toml_path.exists() and not force {
        console.error("jac.toml already exists. Use --force to overwrite.");
        return 1;
    }

    for dir_path in tmpl.directories {
        (project_path / dir_path).mkdir(parents=True, exist_ok=True);
    }
    import time;
    start_time = time.time();
    console.print(f"\nCreating project '{project_name}'\n", style="bold cyan");
    console.print("  Setting up project structure", style="muted");

    import copy;
    render_config = copy.deepcopy(tmpl.config);
    _stamp_kind(render_config, tmpl.kind);
    _stamp_jac_version(render_config);

    toml_content = _render_config_to_toml(render_config, project_name);
    with open(toml_path, "w", encoding="utf-8") as f {
        f.write(toml_content);
    }
    console.print(f"  ✔ jac.toml", style="success");

    for (file_path, content) in tmpl.files.items() {
        full_path = project_path / file_path;
        full_path.parent.mkdir(parents=True, exist_ok=True);
        if not full_path.exists() or force {
            if content.startswith("base64:") {
                binary_data = base64.b64decode(content[7:]);
                with open(full_path, "wb") as f {
                    f.write(binary_data);
                }
            } else {
                rendered = content.replace("{{name}}", project_name);
                with open(full_path, "w", encoding="utf-8") as f {
                    f.write(rendered);
                }
            }
            console.print(f"  ✔ {file_path}", style="success");
        }
    }

    if _seed_agent_guide(project_path, force) {
        console.print(f"  ✔ AGENTS.md", style="success");
    }

    if tmpl.root_gitignore_entries {
        _create_root_gitignore(project_path, tmpl.root_gitignore_entries);
    }

    if tmpl.post_create is not None {
        try {
            tmpl.post_create(project_path, project_name);
        } except Exception as e {
            console.warning(f"Post-create hook failed: {e}");
        }
    }

    deps_installed = False;
    if not skip_deps {
        deps_installed = _bootstrap_project_deps(project_path);
    }

    elapsed_time = time.time() - start_time;
    console.print();
    if elapsed_time < 1 {
        console.success(
            f"Project '{project_name}' created in {elapsed_time * 1000:.0f}ms"
        );
    } else {
        console.success(f"Project '{project_name}' created in {elapsed_time:.1f}s");
    }

    steps = [];
    if create_subdir {
        steps.append(f"cd {name}");
    }
    if not deps_installed {
        steps.append("jac install           Install dependencies");
    }
    if "apps" in render_config {
        steps.append(
            "jac run               Run the default app (jac run --show lists every app)"
        );
    } else {
        steps.append(f"jac run               {_run_blurb(tmpl.kind)}");
    }
    console.print_next_steps(steps);
    console.print();
    return 0;
}

def _run_blurb(kind: str) -> str {
    import from jaclang.project.kinds { VALID_KINDS }
    blurbs: dict[str, str] = {
        "cli": "Execute the project",
        "cli-native": "Native-compile and run",
        "native-binary": "Build a native binary into dist/",
        "native-lib": "Build a shared library",
        "service": "Serve the headless API",
        "service-mesh": "Serve the microservice",
        "py-package": "Build a wheel into dist/",
        "js-package": "Build an npm package into dist/",
        "web-app": "Serve the app (dev mode)",
        "web-static": "Serve the client-only app (static)",
        "desktop": "Run the desktop app",
        "mobile": "Build the mobile app"
    };

    assert set(blurbs.keys()) >= set(VALID_KINDS) , (
        f"_run_blurb missing kinds: {set(VALID_KINDS) - set(blurbs.keys())}"
    );
    return blurbs.get(kind, "Run the project");
}

def _create_app(
    registry: TemplateRegistry, app_name: str, kind: str, app_path: str, force: bool
) -> int {
    import from jaclang.project.config { find_project_root }
    import from jaclang.project.kinds { is_valid_kind, VALID_KINDS }
    import from jaclang.project.template_loader { scaffold_app }

    existing = find_project_root(Path.cwd());
    if existing is None {
        console.error(
            "jac create --app needs an existing project.",
            hint="Run inside a project (jac.toml), or scaffold one first: jac create <name>"
        );
        return 1;
    }
    (project_root, toml_path) = existing;
    if not kind {
        console.error(
            "--app requires --kind.", hint=f"Valid kinds: {', '.join(VALID_KINDS)}"
        );
        return 1;
    }
    if not is_valid_kind(kind) {
        console.error(
            f"Unknown app kind '{kind}'.", hint=f"Valid kinds: {', '.join(VALID_KINDS)}"
        );
        return 1;
    }
    if "/" in app_name or "\\" in app_name or app_name.endswith(".jac") {
        console.error(
            f"'{app_name}' is not a valid app name.",
            hint="App names carry no path separators and no .jac suffix."
        );
        return 1;
    }
    tmpl = registry.get_by_kind(kind);
    if tmpl is None {
        console.error(
            f"No template registered for kind '{kind}'.",
            hint="This is unexpected for a core kind; please report it."
        );
        return 1;
    }
    rel_path = app_path or app_name;
    app_dir = Path(project_root) / rel_path;
    if app_dir.exists() and any(app_dir.iterdir()) and not force {
        console.error(
            f"Directory '{rel_path}' already exists and is not empty. Use --force to scaffold into it."
        );
        return 1;
    }
    console.print(
        f"\nAdding app '{app_name}' ({kind}) to {toml_path}\n", style="bold cyan"
    );
    apps_before = _toml_apps(Path(toml_path));
    try {
        written = scaffold_app(str(project_root), app_name, kind, rel_path, tmpl);
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    for rel in written {
        console.print(f"  ✔ {rel}", style="success");
    }
    console.print(f"  ✔ jac.toml [apps.{app_name}]", style="success");
    (apps_after, default_app) = _toml_apps_and_default(Path(toml_path));
    for migrated in apps_after {
        if migrated not in apps_before and migrated != app_name {
            console.print(
                f"  ✔ jac.toml [apps.{migrated}] (the project's entry, now a "
                f"file-rooted app; default-app = {default_app or migrated})",
                style="success"
            );
        }
    }
    console.success(f"App '{app_name}' added");
    console.print_next_steps([f"jac run {app_name}".ljust(22) + _run_blurb(kind)]);
    console.print();
    return 0;
}

def _toml_apps_and_default(toml_path: Path) -> tuple[set[str], str] {
    import from jaclang.project.tomlio { read_toml_with_encoding }
    try {
        doc = read_toml_with_encoding(str(toml_path));
    } except Exception {
        return (set(), "");
    }
    apps = doc.get("apps", {});
    project = doc.get("project", {});
    default_app = str(project.get("default-app", ""))
        if isinstance(project, dict)
        else "";
    return (set(apps.keys()) if isinstance(apps, dict) else set(), default_app);
}

def _toml_apps(toml_path: Path) -> set[str] {
    return _toml_apps_and_default(toml_path)[0];
}

def _stamp_kind(config: dict[str, any], kind: str) -> None {
    if not kind or kind == "workspace" or "apps" in config {
        return;
    }
    proj = config.get("project");
    if not isinstance(proj, dict) {
        proj = {};
        config["project"] = proj;
    }
    if not proj.get("kind") {
        proj["kind"] = kind;
    }
}

def _stamp_jac_version(config: dict[str, any]) {
    proj = config.get("project");
    if not isinstance(proj, dict) {
        proj = {};
        config["project"] = proj;
    }
    if not proj.get("jac-version") {
        import from jaclang.cli.cli { jac_version }
        proj["jac-version"] = f"=={jac_version()}";
    }
}

def _seed_agent_guide(project_path: Path, force: bool) -> bool {
    agents_path = project_path / "AGENTS.md";
    if agents_path.exists() and not force {
        return False;
    }
    content = """# Working in this Jac project

This is a [Jac](https://www.jaseci.org/) project. Jac's syntax has evolved and
is easily confused with Python or JSX -- before writing or editing `.jac`
files, consult the reference guides bundled with the compiler.

## Reference guides

The `jac` CLI ships curated reference guides ("Agent Skills") -- versioned
coding guidance for the installed compiler:

- `jac guide` -- list every available guide
- `jac guide <name>` -- print a guide (e.g. `jac guide jac-types`)
- `jac guide --search <keyword>` -- find guides by topic
- `jac guide --json` -- machine-readable output for tooling

Start with `jac guide jac-essentials`, then load the guide for your task.
Use `jac guide <name> --sections` to list headings and
`jac guide <name> --section <slug>` to retrieve a relevant section.

## Validate your work

- `jac check <file>` -- type-check and lint. Compiler diagnostics link to the
  relevant guide; follow the `-> run 'jac guide ...'` hints.
- `jac run <file>` -- execute a Jac script.
- `jac run --dev main.jac` -- serve a web-app or service in dev mode
  (hot-reload for client files; restart for server changes). Use this instead
  of `jac run` for apps.
- `jac browse <action>` -- QA a running app in a headless browser:
  `jac browse open localhost:8000`, then `snapshot` (accessibility tree with
  `@e1`-style refs), `click @e5`, `fill '#email' user@example.com`, `screenshot`, `close`.

_Generated by `jac create`._
""";
    with open(agents_path, "w", encoding="utf-8") as f {
        f.write(content);
    }
    return True;
}

def _project_name_from_cwd(cwd: Path) -> str {
    return cwd.resolve().name;
}

def _resolve_awesome_template -> ProjectTemplate | None {
    import jaclang;
    import from jaclang.project.template_loader { load_template_from_directory }
    pkg = Path(jaclang.__file__).parent;
    candidates = [
        pkg.parent / "awesome_template",
        pkg.parent / "examples" / "jaclang_org"
    ];
    for cand in candidates {
        if not (cand / "jac.toml").exists() {
            continue;
        }
        tmpl = load_template_from_directory(cand);

        tmpl.config.pop("dev", None);
        if isinstance(tmpl.config.get("project"), dict) {
            tmpl.config["project"]["name"] = "{{name}}";
        }
        return tmpl;
    }
    return None;
}

def _resolve_template(use: str, registry: TemplateRegistry) -> ProjectTemplate | None {
    import from jaclang.project.template_loader {
        load_template_from_json,
        load_template_from_directory
    }
    import tempfile;
    import urllib.request;
    import urllib.error;

    if use.startswith("http://") or use.startswith("https://") {
        console.print(f"Downloading template from {use}");
        try {
            with tempfile.NamedTemporaryFile(suffix=".jacpack", delete=False) as tmp {
                tmp_path = Path(tmp.name);
            }
            urllib.request.urlretrieve(use, tmp_path);
            tmpl = load_template_from_json(tmp_path);

            tmp_path.unlink();
            console.print(f"Using template '{tmpl.name}' from URL");
            return tmpl;
        } except urllib.error.URLError as e {
            console.error(f"Error downloading template from URL: {e}");
            return None;
        } except Exception as e {
            console.error(f"Error loading template from URL: {e}");
            return None;
        }
    }

    use_path = Path(use);
    if use_path.exists() {
        try {
            if use_path.is_file() {
                if use_path.suffix == ".jacpack" or use.endswith(".jacpack") {
                    tmpl = load_template_from_json(use_path);
                    console.print(f"Using template '{tmpl.name}' from {use_path}");
                    return tmpl;
                } else {
                    console.error(f"Error: File must be a .jacpack file: {use}");
                    return None;
                }
            } elif use_path.is_dir() {
                tmpl = load_template_from_directory(use_path);
                console.print(f"Using template '{tmpl.name}' from {use_path}");
                return tmpl;
            }
        } except Exception as e {
            console.error(f"Error loading template from {use}: {e}");
            return None;
        }
    }

    if "/" in use or use.endswith(".jacpack") {
        console.error(f"Error: Template file or directory not found: {use}");
        return None;
    }

    named = registry.get(use);
    if named is None {
        console.error(f"Unknown template: {use}");
        console.error("Use --list to see available kinds and named variants.");
        console.error("You can also specify a path to a .jacpack file or a URL.");
        return None;
    }
    return named;
}

def _quote_toml_key(k: str) -> str {
    stripped: str = k.replace('_', '').replace('-', '');
    if stripped.isalnum() and len(k) > 0 {
        return k;
    }
    return f'"{k}"';
}

def _render_config_to_toml(config: dict[str, any], project_name: str) -> str {
    lines: list[str] = [];

    def render_value(v: any) -> str {
        if isinstance(v, str) {
            v = v.replace("{{name}}", project_name);
            return f'"{v}"';
        } elif isinstance(v, bool) {
            return "true" if v else "false";
        } elif isinstance(v, (int, float)) {
            return str(v);
        } elif isinstance(v, list) {
            items = [render_value(item) for item in v];
            return "[" + ", ".join(items) + "]";
        } else {
            return str(v);
        }
    }

    def render_section(
        section_name: str, section_data: dict[str, any], indent: str = ""
    ) {
        simple_values: dict[str, any] = {};
        nested_sections: dict[str, dict[str, any]] = {};

        for (k, v) in section_data.items() {
            if isinstance(v, dict) {
                nested_sections[k] = v;
            } else {
                simple_values[k] = v;
            }
        }

        if section_name {
            lines.append(f"[{section_name}]");
        }

        for (k, v) in simple_values.items() {
            lines.append(f"{_quote_toml_key(k)} = {render_value(v)}");
        }

        if simple_values and nested_sections {
            lines.append("");
        }

        for (k, v) in nested_sections.items() {
            nested_name = f"{section_name}.{k}" if section_name else k;
            render_section(nested_name, v);
            lines.append("");
        }
    }

    for (section, data) in config.items() {
        if isinstance(data, dict) {
            render_section(section, data);
            lines.append("");
        } else {
            lines.append(f"{section} = {render_value(data)}");
        }
    }

    while lines and lines[-1] == "" {
        lines.pop();
    }
    lines.append("");

    return "\n".join(lines);
}

def _create_root_gitignore(project_path: Path, entries: list[str]) {
    gitignore_path = project_path / ".gitignore";
    with open(gitignore_path, "w", encoding="utf-8") as f {
        f.write("\n".join(entries) + "\n");
    }
    console.print(f"  ✔ .gitignore", style="success");
}
