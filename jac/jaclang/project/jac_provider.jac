import json;
import os;
import re;
import shutil;
import tomllib;
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig }
import from jaclang.project.dependency_model {
    DependencySpec,
    PendingRequest,
    validate_dependency_spec,
    validate_import_root
}
import from jaclang.project.dep_roots { deps_map_path, read_deps_map }
import from jaclang.project.providers {
    EcosystemProvider,
    InstallContext,
    ResolvedDependency
}
import from jaclang.project.jac_store {
    JacDepError,
    FetchResult,
    dirhash,
    fetch_package,
    git_package_name,
    materialize,
    normalize_git_url
}
import from jaclang.project.versioning { caret_upper, parse_release, vtuple }

glob REF_HEX: str = "^[0-9a-fA-F]{40}$",
     DEPS_MAP_VERSION: str = "1";

obj JacPackage {
    has name: str = "",
        key: str = "",
        source: str = "git",
        ref: str = "",
        req_commit: str = "",
        sha: str = "",
        tree: str = "",
        pkg_root: str = "",
        version: str = "",
        local_path: Path | None = None,
        requested_by: list[str] = [],
        manifest: dict[str, any] = {};
}


def manifest_jac_deps(config: JacConfig) -> tuple[dict[str, any], dict[str, any]] {
    raw = config.plugin_dependencies.get("jac", {});
    deps: dict[str, dict[str, any]] = {};
    dev_deps: dict[str, dict[str, any]] = {};
    for (name, value) in raw.items() {
        if name == "dev" {
            if not isinstance(value, dict) {
                raise entry_error(
                    name, value, "legacy [dependencies.jac.dev] must be a table"
                );
            }
            for (dname, dval) in value.items() {
                if isinstance(dval, dict) {
                    dev_deps[dname] = dval;
                } else {
                    raise entry_error(
                        dname,
                        dval,
                        "[dev-dependencies.jac] entries must be inline tables"
                    );
                }
            }
            continue;
        }
        if isinstance(value, dict) {
            deps[name] = value;
        } else {
            raise entry_error(
                name,
                value,
                "a bare string has no meaning here (there is no jac registry "
                "to resolve a name against); use { git = ... } or { path = ... }"
            );
        }
    }
    return (deps, dev_deps);
}


def manifest_jac_specs(
    config: JacConfig
) -> tuple[list[DependencySpec], list[DependencySpec]] {
    raw = config.plugin_dependencies.get("jac", {});
    raw = raw if isinstance(raw, dict) else {};
    main: dict[str, any] = {
        str(name): value
        for (name, value) in raw.items()
        if name != "dev"
    };
    dev_raw = raw.get("dev", {});
    dev: dict[str, any] = dev_raw if isinstance(dev_raw, dict) else {};
    base_dir = config.project_root or Path.cwd();

    def parse_entry(alias: str, dep_value: any, is_dev: bool) -> DependencySpec {
        if not isinstance(dep_value, dict) {
            raise entry_error(
                alias, dep_value, "dependency entries must be inline tables"
            );
        }
        (source, location) = _entry_key(alias, dep_value, base_dir);
        (ref, commit) = _entry_ref(alias, dep_value);
        import_root = str(dep_value.get("package", "") or "").strip();
        if import_root {
            try {
                import_root = validate_import_root(import_root);
            } except ValueError as e {
                raise entry_error(alias, dep_value, str(e)) from None;
            }
        }
        spec = DependencySpec(
            ecosystem="jac",
            alias=str(alias),
            source=source,
            source_location=(
                str(dep_value.get("path", "")) if source == "path" else location
            ),
            ref=ref,
            commit=commit,
            version_constraint=str(dep_value.get("version", "") or ""),
            import_root=import_root,
            dev=is_dev
        );
        try {
            return validate_dependency_spec(spec);
        } except ValueError as e {
            raise entry_error(alias, dep_value, str(e)) from None;
        }
    }

    main_specs = [
        parse_entry(str(alias), value, False) for (alias, value) in main.items()
    ];
    dev_specs = [
        parse_entry(str(alias), value, True) for (alias, value) in dev.items()
    ];
    return (main_specs, dev_specs);
}


def entry_error(name: str, dep: any, why: str) -> JacDepError {
    return JacDepError(
        f"Invalid [dependencies.jac] dep '{name}': {why}\n"
        f"  got: {dep}\n"
        "  expected e.g. { git = \"github.com/user/repo\", branch = \"main\" } "
        "or { path = \"../utils\" }"
    );
}


def _entry_key(name: str, dep: dict[str, any], base_dir: Path) -> tuple[str, str] {
    git_val = dep.get("git");
    path_val = dep.get("path");
    has_git = isinstance(git_val, str) and bool(git_val.strip());
    has_path = isinstance(path_val, str) and bool(path_val.strip());
    if has_git and has_path {
        raise entry_error(name, dep, "cannot declare both 'git' and 'path'");
    }
    if has_git {
        return ("git", normalize_git_url(dep["git"]));
    }
    if has_path {
        path_text = str(dep["path"]);
        if any(ord(c) < 32 for c in path_text) {
            raise entry_error(name, dep, "path contains control characters");
        }
        real = os.path.realpath(str(base_dir / dep["path"]));
        return ("path", real);
    }
    raise entry_error(name, dep, "needs a 'git' or 'path' field");
}


def _safe_dep_name(name: str) -> bool {
    if not name or name in (".", "..") {
        return False;
    }
    if any(c in name for c in ("/", "\\", ":")) {
        return False;
    }
    if any(ord(c) < 32 or ord(c) == 127 for c in name) {
        return False;
    }
    if name != name.strip() or name.endswith(".") {
        return False;
    }
    stem = name.split(".", 1)[0].upper();
    if stem
        in {
            "CON",
            "PRN",
            "AUX",
            "NUL",
            "COM1",
            "COM2",
            "COM3",
            "COM4",
            "COM5",
            "COM6",
            "COM7",
            "COM8",
            "COM9",
            "LPT1",
            "LPT2",
            "LPT3",
            "LPT4",
            "LPT5",
            "LPT6",
            "LPT7",
            "LPT8",
            "LPT9"
        } {
        return False;
    }
    return True;
}


def _entry_ref(name: str, dep: dict[str, any]) -> tuple[str, str] {
    ref = "";
    for field in ("ref", "branch", "tag") {
        value = dep.get(field);
        if isinstance(value, str) and value.strip() {
            if ref and ref != value.strip() {
                raise entry_error(
                    name, dep, f"declares conflicting refs '{ref}' and '{value}'"
                );
            }
            ref = value.strip();
        }
    }
    commit = dep.get("commit");
    if commit is not None
        and (not isinstance(commit, str) or not re.match(REF_HEX, commit.strip())) {
        raise entry_error(name, dep, "'commit' must be a 40-hex sha");
    }
    return (ref, commit.strip() if isinstance(commit, str) else "");
}


def _selector_key(ref: str, commit: str) -> str {
    if commit {
        return f"commit {commit[:12]}";
    }
    if ref {
        return f"ref {ref}";
    }
    return "default branch";
}


def _looks_like_git_url(value: str) -> bool {
    scheme = re.match(r"^[A-Za-z][A-Za-z0-9+.-]*://([^/]+)(/.*)?$", value);
    if scheme is not None {
        return scheme.group(2) is not None;
    }
    if re.match(r"^[^/]+@[^:/]+:.+$", value) {
        return True;
    }
    return "/" in value and "." in value.split("/")[0];
}


def _split_git_ref(body: str) -> tuple[str, str] {
    at = body.rfind("@");
    if at <= 0 {
        return (body, "");
    }
    candidate = body[:at];
    if _looks_like_git_url(body) and not _looks_like_git_url(candidate) {
        return (body, "");
    }
    return (candidate, body[at + 1:]);
}


def parse_jac_spec(spec: str) -> tuple[str, dict[str, any]] {
    if not spec.startswith("jac:") {
        raise JacDepError(f"Not a jac: spec: {spec}");
    }
    body = spec[len("jac:"):].strip();
    if not body {
        raise JacDepError("Empty jac: spec");
    }
    if body.startswith(("./", "../", "/")) or body in (".", "..") {
        ppath = Path(body);
        name = ppath.resolve().name if ppath.exists() else ppath.name;
        return (name, {"path": body});
    }
    (url_part, ref_part) = _split_git_ref(body);
    name = git_package_name(url_part);
    if not name or ("/" not in url_part and "." not in url_part) {
        raise JacDepError(
            f"'{spec}' does not name a git repository. "
            "Bare names need a registry (deferred); use jac:<git-url> or jac:<path>."
        );
    }
    dep: dict[str, any] = {"git": url_part};
    if ref_part {
        if re.match(REF_HEX, ref_part) {
            dep["commit"] = ref_part;
        } else {
            dep["ref"] = ref_part;
        }
    }
    return (name, dep);
}

def version_satisfied(constraint: str, actual: str) -> bool {
    constraint = constraint.strip();
    actual_v = vtuple(actual);
    if constraint.startswith("^") {
        try {
            base = parse_release(constraint[1:]);
        } except ValueError {
            raise JacDepError(
                f"Unsupported version constraint '{constraint}': use an exact "
                "version ('1.2.3' or '=1.2.3') or a caret ('^1.2.3')"
            ) from None;
        }
        upper = caret_upper(base);
        return actual_v >= base and actual_v < upper;
    }
    exact = constraint.lstrip("=");
    if re.match(r"^\d+(\.\d+)*$", exact) {
        return actual_v == vtuple(exact);
    }
    raise JacDepError(
        f"Unsupported version constraint '{constraint}': use an exact "
        "version ('1.2.3' or '=1.2.3') or a caret ('^1.2.3')"
    );
}


def _read_tree_manifest(pkg_root: Path) -> dict[str, any] {
    toml_path = pkg_root / "jac.toml";
    if not toml_path.is_file() {
        raise JacDepError(
            f"Fetched package has no jac.toml at its root ({pkg_root}). "
            "A pure-jac dependency must be a jac project."
        );
    }
    try {
        with open(toml_path, "rb") as f {
            return tomllib.load(f);
        }
    } except tomllib.TOMLDecodeError as e {
        raise JacDepError(f"Malformed jac.toml in {pkg_root}: {e}") from None;
    }
}


def _validate_package_field(pkg_root: Path, name: str, dep: dict[str, any]) -> None {
    module = dep.get("package");
    if not isinstance(module, str) or not module.strip() {
        return;
    }
    module = module.strip();
    base = pkg_root / module.replace(".", "/");
    module_file = base.with_suffix(".jac");
    if not module_file.is_file() and not (base / "__init__.jac").is_file() {
        raise JacDepError(
            f"[dependencies.jac] '{name}' declares package = \"{module}\", "
            f"but the fetched tree provides no {module}.jac "
            f"(or {module}/__init__.jac) at its root"
        );
    }
}


def restore_saved_packages(config: JacConfig) {
    data = read_deps_map(config);
    packages_root = config.get_build_dir() / "packages";
    known: set[str] = set();
    for row in data.get("packages", []) {
        if not isinstance(row, dict) {
            continue;
        }
        name = str(row.get("name", ""));
        src_root = str(row.get("root", ""));
        if not name or not _safe_dep_name(name) {
            continue;
        }
        known.add(name);
        if src_root and os.path.isdir(src_root) {
            materialize(Path(src_root), packages_root / name);
        }
    }
    if packages_root.is_dir() {
        for child in packages_root.iterdir() {
            if child.name in known or not _safe_dep_name(child.name) {
                continue;
            }
            if child.is_symlink() or not child.is_dir() {
                child.unlink(missing_ok=True);
            } else {
                shutil.rmtree(child, ignore_errors=True);
            }
        }
    }
}


def pth_lines(resolved: dict[str, JacPackage]) -> list[str] {
    seen: set[str] = set();
    lines: list[str] = [];
    for name in sorted(resolved.keys()) {
        local = resolved[name].local_path;
        if local is None {
            continue;
        }
        text = str(local.resolve());
        if text in seen {
            continue;
        }
        if any(ord(c) < 32 for c in text) {
            raise JacDepError(
                f"Dependency path for '{name}' contains control characters "
                "and would corrupt the import map"
            );
        }
        seen.add(text);
        lines.append(text);
    }
    return lines;
}


def pth_path(config: JacConfig) -> Path | None {
    import from jaclang.project.pyvenv { get_venv_site_packages }
    venv_dir = config.get_venv_dir();
    if not venv_dir {
        return None;
    }
    site = Path(get_venv_site_packages(Path(venv_dir)));
    if not site.is_dir() {
        return None;
    }
    return site / "_jac_deps.pth";
}


def write_pth(config: JacConfig, resolved: dict[str, JacPackage]) -> None {
    pth = pth_path(config);
    if pth is None {
        return;
    }
    lines = pth_lines(resolved);
    if lines {
        pth.write_text("\n".join(lines) + "\n", encoding="utf-8");
    } else {
        pth.unlink(missing_ok=True);
    }
}


def _apply_override(
    overrides: dict[str, any],
    noted: set[str],
    name: str,
    dep: dict[str, any],
    requirer: str
) -> dict[str, any] {
    if name in overrides and isinstance(overrides[name], dict) {
        if name not in noted {
            console.print(
                f"  override: using [override] dep for '{name}' "
                f"(requested by {requirer})",
                style="muted"
            );
            noted.add(name);
        }
        return overrides[name];
    }
    return dep;
}


obj JacDepProvider(EcosystemProvider) {
    has name: str = "jac",
        manifest_key: str = "jac",
        cli_flag: str = "";

    override def resolve(
        config: JacConfig, include_dev: bool = False
    ) -> list[ResolvedDependency] {
        (deps, dev_deps) = manifest_jac_deps(config);
        resolved: list[ResolvedDependency] = [];
        for (pkg_name, dep) in deps.items() {
            resolved.append(
                ResolvedDependency(
                    name=pkg_name,
                    version=str(dep.get("version", "")),
                    ecosystem="jac",
                    source="git" if dep.get("git") else "path",
                    origin="manifest",
                    data={k: str(v) for (k, v) in dep.items()}
                )
            );
        }
        if include_dev {
            for (pkg_name, dep) in dev_deps.items() {
                resolved.append(
                    ResolvedDependency(
                        name=pkg_name,
                        version=str(dep.get("version", "")),
                        ecosystem="jac",
                        source="git" if dep.get("git") else "path",
                        origin="manifest",
                        dev=True,
                        data={k: str(v) for (k, v) in dep.items()}
                    )
                );
            }
        }
        return resolved;
    }

    def resolve_closure(
        config: JacConfig,
        ctx: InstallContext | None = None,
        frozen_pins: dict[str, dict[str, any]] | None = None,
        collect_only: bool = False,
        extra_specs: dict[str, dict[str, any]] | None = None
    ) -> dict[str, JacPackage] {
        frozen_pins = frozen_pins or {};
        overrides = config.get_section("override");
        overrides = overrides if isinstance(overrides, dict) else {};
        noted_overrides: set[str] = set();
        project_root = config.project_root or Path.cwd();
        (root_deps, root_dev) = manifest_jac_deps(config);

        root_entries = dict(root_deps);
        if ctx is not None and ctx.include_dev {
            root_entries.update(root_dev);
        }
        root_entries.update(extra_specs or {});
        packages_root = config.get_build_dir() / "packages";

        queue: list[PendingRequest] = [];
        resolved: dict[str, JacPackage] = {};
        seen: dict[str, tuple[any, any, any]] = {};
        queued: set[str] = set();
        for (name, dep) in root_entries.items() {
            dep = _apply_override(overrides, noted_overrides, name, dep, "root");
            (source, key) = _entry_key(name, dep, Path(str(project_root)));
            (ref, commit) = _entry_ref(name, dep);
            seen[name] = (key, ref, commit);
            queue.append(
                PendingRequest(
                    name=name,
                    dep=dep,
                    base_dir=str(project_root),
                    requirer="root",
                    source=source,
                    key=key,
                    ref=ref,
                    commit=commit
                )
            );
            queued.add(name);
        }
        idx = 0;
        while idx < len(queue) {
            request = queue[idx];
            idx += 1;
            (name, dep, base_dir, requirer, source, key, ref, commit) = (
                request.name,
                request.dep,
                request.base_dir,
                request.requirer,
                request.source,
                request.key,
                request.ref,
                request.commit
            );
            if not isinstance(dep, dict) {
                raise entry_error(
                    name,
                    dep,
                    "string entries have no meaning here; a pure-jac dep needs "
                    "{ git = ... } or { path = ... }"
                );
            }
            existing = resolved.get(name);
            if existing is not None {
                self._check_unification(
                    existing, name, key, ref, commit, dep, requirer
                );
                continue;
            }
            pkg = self._resolve_one(request, frozen_pins.get(name, {}), ctx);
            resolved[name] = pkg;
            self._materialize_pkg(pkg, packages_root, ctx, collect_only);
            dependency_table = pkg.manifest.get("dependencies", {});
            if dependency_table is None {
                dependency_table = {};
            }
            if not isinstance(dependency_table, dict) {
                raise JacDepError(f"Malformed dependencies table in '{name}'");
            }
            transitive = dependency_table.get("jac", {});
            if transitive is None {
                transitive = {};
            }
            if not isinstance(transitive, dict) {
                raise JacDepError(f"Malformed [dependencies.jac] table in '{name}'");
            }
            for (tname, tentry) in transitive.items() {
                if str(tname) == name {
                    raise JacDepError(
                        f"Dependency '{name}' declares itself as a dependency"
                    );
                }
                if not isinstance(tentry, dict) {
                    raise entry_error(
                        str(tname), tentry, "transitive entries must be inline tables"
                    );
                }
                tentry = _apply_override(
                    overrides, noted_overrides, tname, tentry, name
                );
                (tsource, tkey) = _entry_key(tname, tentry, Path(pkg.pkg_root));
                (tref, tcommit) = _entry_ref(tname, tentry);
                existing = resolved.get(tname);
                if existing is not None {
                    self._check_unification(
                        existing, tname, tkey, tref, tcommit, tentry, name
                    );
                    continue;
                }
                if tname in seen {
                    (skey, sref, scommit) = seen[tname];
                    if tkey != skey {
                        raise JacDepError(
                            f"Dependency name collision: '{tname}' is '{skey}' "
                            f"and '{tkey}' (via {name}). Rename one of the "
                            f"packages or use [override]."
                        );
                    }
                    if _selector_key(sref, scommit) != _selector_key(tref, tcommit) {
                        raise JacDepError(
                            f"Version conflict for '{tname}': "
                            f"{_selector_key(sref, scommit)} vs "
                            f"{_selector_key(tref, tcommit)} "
                            f"(via {name}). Unify the selectors or use [override]."
                        );
                    }
                } else {
                    seen[tname] = (tkey, tref, tcommit);
                }
                if tname not in queued {
                    queued.add(tname);
                    queue.append(
                        PendingRequest(
                            name=tname,
                            dep=tentry,
                            base_dir=pkg.pkg_root,
                            requirer=name,
                            source=tsource,
                            key=tkey,
                            ref=tref,
                            commit=tcommit
                        )
                    );
                }
            }
        }
        return resolved;
    }

    def _materialize_pkg(
        pkg: JacPackage,
        packages_root: Path,
        ctx: InstallContext | None,
        collect_only: bool = False
    ) -> None {
        if pkg.source == "path" or (ctx is not None and ctx.is_dry_run()) {
            pkg.local_path = Path(pkg.pkg_root);
            return;
        }
        if collect_only {
            return;
        }
        if not _safe_dep_name(pkg.name) {
            raise JacDepError(f"Unsafe dependency name for install: '{pkg.name}'");
        }
        dest = packages_root / pkg.name;
        real_dest = os.path.realpath(str(dest));
        real_root = os.path.realpath(str(packages_root));
        if not real_dest.startswith(real_root + os.sep) {
            raise JacDepError(
                f"Unsafe dependency destination for install: '{pkg.name}' "
                f"resolves outside {real_root}"
            );
        }
        try {
            pkg.local_path = materialize(Path(pkg.pkg_root), dest);
        } except OSError as e {
            raise JacDepError(
                f"Could not install '{pkg.name}' into {dest}: {e}"
            ) from None;
        }
    }

    def materialize_closure(
        config: JacConfig,
        resolved: dict[str, JacPackage],
        ctx: InstallContext | None = None
    ) {
        packages_root = config.get_build_dir() / "packages";
        for pkg in resolved.values() {
            self._materialize_pkg(pkg, packages_root, ctx);
        }
    }

    def _check_unification(
        existing: JacPackage,
        name: str,
        key: str,
        ref: str,
        commit: str,
        dep: dict[str, any],
        requirer: str
    ) {
        if existing.key != key {
            raise JacDepError(
                f"Dependency name collision: '{name}' is '{existing.key}' "
                f"(via {', '.join(existing.requested_by)}) and '{key}' "
                f"(via {requirer})"
            );
        }
        existing_selector = _selector_key(existing.ref, existing.req_commit);
        incoming_selector = _selector_key(ref, commit);
        if existing_selector != incoming_selector {
            raise JacDepError(
                f"Version conflict for '{name}': "
                f"{existing_selector} "
                f"(via {', '.join(existing.requested_by)}) vs "
                f"{incoming_selector} (via {requirer}). "
                f"Unify the selectors or use [override]."
            );
        }
        constraint = str(dep.get("version", "")) if dep.get("version") else "";
        if constraint
            and existing.version
            and not version_satisfied(constraint, existing.version) {
            raise JacDepError(
                f"Version conflict for '{name}': '{requirer}' requires "
                f"{constraint}, but {key} resolves to {existing.version}"
            );
        }
        if requirer not in existing.requested_by {
            existing.requested_by.append(requirer);
        }
    }

    def _resolve_one(
        request: PendingRequest, pins: dict[str, any], ctx: InstallContext | None
    ) -> JacPackage {
        (name, dep, source, key, ref, commit, base_dir, requirer) = (
            request.name,
            request.dep,
            request.source,
            request.key,
            request.ref,
            request.commit,
            request.base_dir,
            request.requirer
        );
        if not _safe_dep_name(name) {
            raise JacDepError(
                f"Unsafe dependency name: '{name}' (requested by {requirer}). "
                "Names must be a single safe path component."
            );
        }
        if source == "path" {
            if not os.path.isdir(key) {
                raise JacDepError(
                    f"[dependencies.jac] '{name}': path '{dep.get('path')}' "
                    f"(resolved {key}) does not exist"
                );
            }
            pkg_tree = dirhash(Path(key));
            if ctx is not None and ctx.frozen {
                row = pins if isinstance(pins, dict) else {};
                if not row {
                    raise JacDepError(
                        f"jac.lock is missing '{name}' (requested by "
                        f"{requirer}). Run 'jac install' to refresh the "
                        f"lockfile."
                    );
                }
                if row.get("git") {
                    raise JacDepError(
                        f"'{name}': manifest declares a path dependency but "
                        f"jac.lock records a git source. Run 'jac install' to "
                        f"refresh the lockfile."
                    );
                }
                recorded_tree = str(row.get("tree", ""));
                if not recorded_tree {
                    raise JacDepError(
                        f"jac.lock row for path dependency '{name}' records "
                        f"no tree hash. Run 'jac install' to refresh the "
                        f"lockfile."
                    );
                }
                if recorded_tree != pkg_tree {
                    raise JacDepError(
                        f"'{name}': path dependency content differs from the "
                        f"recorded lock entry (lock tree {recorded_tree[:12]}, "
                        f"live tree {pkg_tree[:12]}). Run 'jac install' to "
                        f"refresh the lockfile."
                    );
                }
                recorded_path = str(row.get("path", ""));
                if recorded_path {
                    recorded_abs_candidates = [
                        os.path.realpath(str(Path(base_dir) / recorded_path)),
                        os.path.realpath(recorded_path),
                        os.path.realpath(str(Path.cwd() / recorded_path))
                    ];
                    if os.path.realpath(key) not in recorded_abs_candidates {
                        raise JacDepError(
                            f"'{name}': manifest path resolves to {key} but "
                            f"jac.lock records {recorded_path}. Run 'jac install' "
                            f"to refresh the lockfile."
                        );
                    }
                }
            }
            pkg = JacPackage(
                name=name,
                key=key,
                source="path",
                pkg_root=key,
                tree=pkg_tree,
                requested_by=[requirer]
            );
        } else {
            pin_sha = str(pins.get("sha", "")) if pins else "";
            stale: list[str] = [];
            if pin_sha and commit and commit != pin_sha {
                stale.append(
                    f"manifest pins commit {commit[:12]} but jac.lock records "
                    f"{pin_sha[:12]}"
                );
            }
            if pin_sha and str(pins.get("git", "")) != key {
                stale.append(
                    f"manifest source is {key} but jac.lock records "
                    f"{pins.get('git', '')}"
                );
            }
            if stale and ctx is not None and ctx.frozen {
                raise JacDepError(
                    f"'{name}': {'; '.join(stale)}. "
                    f"Run 'jac install' to refresh the lockfile."
                );
            }
            if stale {
                pins = {};
                pin_sha = "";
            }
            if ctx is not None and ctx.frozen and not pin_sha {
                raise JacDepError(
                    f"jac.lock is missing '{name}' (requested by "
                    f"{requirer}). Run 'jac install' to refresh the lockfile."
                );
            }
            fetched = fetch_package(
                url=key,
                ref=ref,
                sha=commit or pin_sha or None,
                expected_tree=str(pins.get("tree", "")),
                verify=bool(pins),
                frozen=(ctx is not None and ctx.frozen)
            );
            pkg = JacPackage(
                name=name,
                key=key,
                source="git",
                ref=ref,
                req_commit=commit,
                sha=fetched.sha,
                tree=fetched.tree,
                pkg_root=fetched.path,
                requested_by=[requirer]
            );
        }
        pkg.manifest = _read_tree_manifest(Path(pkg.pkg_root));
        project = pkg.manifest.get("project", {});
        pkg.version = str(project.get("version", ""));
        constraint = str(dep.get("version", "")) if dep.get("version") else "";
        if constraint
            and pkg.version
            and not version_satisfied(constraint, pkg.version) {
            raise JacDepError(
                f"Version conflict for '{name}': '{requirer}' requires "
                f"{constraint}, but {key} resolves to {pkg.version}"
            );
        }
        _validate_package_field(Path(pkg.pkg_root), name, dep);
        if ctx is not None and ctx.verbose {
            via = f" @ {pkg.sha[:12]}" if pkg.sha else "";
            console.print(f"  jac dep {name}{via} -> {pkg.pkg_root}", style="muted");
        }
        return pkg;
    }

    def save_deps_map(config: JacConfig, resolved: dict[str, JacPackage]) -> bool {
        map_path = deps_map_path(config);
        map_path.parent.mkdir(parents=True, exist_ok=True);
        packages = [
            {
                "name": p.name,
                "source": p.source,
                "key": p.key,
                "ref": p.ref,
                "sha": p.sha,
                "tree": p.tree,
                "root": p.pkg_root,
                "local": str(p.local_path) if p.local_path else "",
                "version": p.version
            } for p in resolved.values()
        ];
        map_path.write_text(
            json.dumps({"version": DEPS_MAP_VERSION, "packages": packages}, indent=2)
                + "\n",
            encoding="utf-8"
        );
        return True;
    }

    override def install_all(
        config: JacConfig, deps: list[ResolvedDependency], ctx: InstallContext
    ) -> bool {
        (root_deps, root_dev) = manifest_jac_deps(config);
        if not root_deps and not (root_dev if ctx.include_dev else {}) {
            return True;
        }
        import from jaclang.project.lockfile {
            jac_lock_rows,
            read_lock,
            update_jac_rows
        }
        pins = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
        active_roots = dict(root_deps);
        if ctx.include_dev {
            active_roots.update(root_dev);
        }
        if ctx.frozen {
            missing = [
                n
                for n in active_roots
                if n not in pins
            ];
            if missing {
                console.error(
                    f"jac.lock is missing: {', '.join(sorted(missing))}. "
                    f"Run 'jac install' to refresh the lockfile."
                );
                return False;
            }
        }
        try {
            resolved = self.resolve_closure(config, ctx, frozen_pins=pins);
        } except JacDepError as e {
            console.error(str(e));
            return False;
        }
        self.save_deps_map(config, resolved);
        if not ctx.is_dry_run() {
            skipped_dev = set() if ctx.include_dev else set(root_dev.keys());
            if not update_jac_rows(
                config.project_root or Path.cwd(), resolved, preserve=skipped_dev
            ) {
                console.error(
                    "Could not update jac.lock; run 'jac install' to refresh it."
                );
                return False;
            }
            write_pth(config, resolved);
            for pkg in resolved.values() {
                via = f"{pkg.key}@{pkg.sha[:12]}" if pkg.sha else pkg.key;
                console.print(f"  ✔ {pkg.name} ({via})", style="success");
            }
        }
        return True;
    }

    def install_no_save(
        config: JacConfig, specs: list[str], ctx: InstallContext
    ) -> bool {
        extra: dict[str, dict[str, any]] = {};
        for spec in specs {
            (name, ent) = parse_jac_spec(spec);
            extra[name] = ent;
        }
        try {
            resolved = self.resolve_closure(
                config, ctx, collect_only=True, extra_specs=extra
            );
            self.materialize_closure(config, resolved, ctx);
        } except JacDepError as e {
            console.error(str(e));
            try {
                restore_saved_packages(config);
            } except (JacDepError, OSError) {
                console.warning(
                    "Could not restore previous packages; run "
                    "'jac install' to repair .jac/ state."
                );
            }
            return False;
        }
        self.save_deps_map(config, resolved);
        write_pth(config, resolved);
        for pkg in resolved.values() {
            via = f"{pkg.key}@{pkg.sha[:12]}" if pkg.sha else pkg.key;
            console.print(f"  ✔ {pkg.name} ({via})", style="success");
        }
        return True;
    }

    def add_spec(
        config: JacConfig,
        spec: str,
        dev: bool = False,
        ctx: InstallContext | None = None
    ) -> str | None {
        (name, dep) = parse_jac_spec(spec);
        import from jaclang.project.lockfile {
            jac_lock_rows,
            read_lock,
            update_jac_rows
        }

        try {
            resolved = self.resolve_closure(
                config,
                ctx,
                frozen_pins=jac_lock_rows(read_lock(config.project_root or Path.cwd())),
                extra_specs={name: dep}
            );
        } except JacDepError as e {
            console.error(str(e));
            self._rematerialize(config);
            return None;
        }
        section = config.plugin_dependencies.setdefault("jac", {});
        if dev {
            section.setdefault("dev", {})[name] = dep;
        } else {
            section[name] = dep;
        }
        try {
            config.save();
            self.save_deps_map(config, resolved);
        } except OSError as e {
            console.error(f"Could not save dependency metadata: {e}");
            try {
                restore_saved_packages(config);
            } except (JacDepError, OSError) {
                console.warning(
                    "Could not restore previous packages; run "
                    "'jac install' to repair .jac/ state."
                );
            }
            return None;
        }
        if ctx is None or not ctx.is_dry_run() {
            (_, spec_dev) = manifest_jac_deps(config);
            if not update_jac_rows(
                config.project_root or Path.cwd(),
                resolved,
                preserve=set(spec_dev.keys())
            ) {
                console.error(
                    "Could not update jac.lock; run 'jac install' to refresh it."
                );
                try {
                    restore_saved_packages(config);
                } except (JacDepError, OSError) {
                    console.warning(
                        "Could not restore previous packages; run "
                        "'jac install' to repair .jac/ state."
                    );
                }
                return None;
            }
            write_pth(config, resolved);
            pkg = resolved[name];
            via = f"{pkg.key}@{pkg.sha[:12]}" if pkg.sha else pkg.key;
            console.print(f"  ✔ {name} ({via})", style="success");
            return via;
        }
        return name;
    }

    def _rematerialize(config: JacConfig) {
        import from jaclang.project.lockfile { jac_lock_rows, read_lock }
        try {
            pins = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            resolved = self.resolve_closure(config, None, frozen_pins=pins);
            self.save_deps_map(config, resolved);
            write_pth(config, resolved);
        } except (JacDepError, OSError) {
            console.warning(
                "Previous dependencies could not be re-materialized; "
                "run 'jac install' to restore .jac/ state."
            );
        }
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        raise NotImplementedError(
            "pure-jac deps are added with 'jac install jac:<url-or-path>'"
        );
    }

    override def remove_package(
        config: JacConfig, name: str, dev: bool, ctx: InstallContext
    ) -> bool {
        (deps, dev_deps) = manifest_jac_deps(config);
        if name not in deps and name not in dev_deps {
            return False;
        }
        is_dev = dev or (name not in deps and name in dev_deps);
        if is_dev and name in dev_deps {
            previous = dev_deps[name];
        } else {
            previous = deps.get(name);
        }
        if not config.remove_dependency(name, dev=is_dev, dep_type="jac") {
            return False;
        }
        try {
            resolved = self.resolve_closure(config, ctx);
        } except JacDepError as e {
            section = config.plugin_dependencies.setdefault("jac", {});
            if is_dev {
                restored = section.setdefault("dev", {});
                restored[name] = previous;
            } else {
                section[name] = previous;
            }

            console.error(str(e));
            self._rematerialize(config);
            return False;
        }
        stale = config.get_build_dir() / "packages" / name;
        if _safe_dep_name(name) and stale.is_dir() {
            shutil.rmtree(stale, ignore_errors=True);
        }
        self.save_deps_map(config, resolved);
        import from jaclang.project.lockfile { update_jac_rows }
        (_, remaining_dev) = manifest_jac_deps(config);
        if not update_jac_rows(
            config.project_root or Path.cwd(),
            resolved,
            preserve=set(remaining_dev.keys())
        ) {
            console.error(
                "Could not update jac.lock; run 'jac install' to refresh it."
            );
            return False;
        }
        write_pth(config, resolved);
        console.print(f"  ✔ Removed {name} from [dependencies.jac]", style="success");
        return True;
    }

    override def list_installed(config: JacConfig) -> list[str] {
        data = read_deps_map(config);
        return sorted(
            p.get("name", "")
            for p in data.get("packages", [])
            if isinstance(p, dict)
        );
    }

    override def emit_standalone(
        config: JacConfig, deps: list[ResolvedDependency], out_dir: Path, mode: str
    ) -> list[Path] {
        try {
            resolved = self.resolve_closure(config, None);
        } except JacDepError as e {
            console.warning(
                f"Could not resolve jac dependencies ({e}); " "continuing without them."
            );
            resolved = {};
        }
        if not resolved {
            return [];
        }
        out_dir.mkdir(parents=True, exist_ok=True);
        out_path = out_dir / "jac-deps.txt";
        lines: list[str] = [];
        for pkg in resolved.values() {
            if pkg.source == "git" {
                lines.append(f"{pkg.name} {pkg.key}#{pkg.sha}");
            } else {
                lines.append(f"{pkg.name} path:{pkg.key}");
            }
        }
        out_path.write_text("\n".join(lines) + "\n", encoding="utf-8");
        return [out_path];
    }
}


def get_jac_dep_provider -> JacDepProvider {
    import from jaclang.project.providers { get_provider_registry }
    provider = get_provider_registry().get("jac");
    if not isinstance(provider, JacDepProvider) {
        raise RuntimeError("jac provider missing from the registry");
    }
    return provider;
}
