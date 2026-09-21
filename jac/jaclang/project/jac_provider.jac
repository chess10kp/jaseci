import os;
import re;
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

glob REF_HEX: str = "^[0-9a-fA-F]{40}$";

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
            if not isinstance(request.dep, dict) {
                raise entry_error(
                    request.name,
                    request.dep,
                    "string entries have no meaning here; a pure-jac dep needs "
                    "{ git = ... } or { path = ... }"
                );
            }
            existing = resolved.get(request.name);
            if existing is not None {
                self._check_unification(
                    existing,
                    request.name,
                    request.key,
                    request.ref,
                    request.commit,
                    request.dep,
                    request.requirer
                );
                continue;
            }
            pkg = self._resolve_one(request, frozen_pins.get(request.name, {}), ctx);
            resolved[request.name] = pkg;
            self._materialize_pkg(pkg, packages_root, ctx, collect_only);
            dependency_table = pkg.manifest.get("dependencies", {});
            if dependency_table is None {
                dependency_table = {};
            }
            if not isinstance(dependency_table, dict) {
                raise JacDepError(f"Malformed dependencies table in '{request.name}'");
            }
            transitive = dependency_table.get("jac", {});
            if transitive is None {
                transitive = {};
            }
            if not isinstance(transitive, dict) {
                raise JacDepError(
                    f"Malformed [dependencies.jac] table in '{request.name}'"
                );
            }
            for (tname, tentry) in transitive.items() {
                if str(tname) == request.name {
                    raise JacDepError(
                        f"Dependency '{request.name}' declares itself as a "
                        "dependency"
                    );
                }
                if not isinstance(tentry, dict) {
                    raise entry_error(
                        str(tname), tentry, "transitive entries must be inline tables"
                    );
                }
                tentry = _apply_override(
                    overrides, noted_overrides, tname, tentry, request.name
                );
                (tsource, tkey) = _entry_key(tname, tentry, Path(pkg.pkg_root));
                (tref, tcommit) = _entry_ref(tname, tentry);
                existing = resolved.get(tname);
                if existing is not None {
                    self._check_unification(
                        existing, tname, tkey, tref, tcommit, tentry, request.name
                    );
                    continue;
                }
                if tname in seen {
                    (skey, sref, scommit) = seen[tname];
                    if tkey != skey {
                        raise JacDepError(
                            f"Dependency name collision: '{tname}' is '{skey}' "
                            f"and '{tkey}' (via {request.name}). Rename one of "
                            "the packages or use [override]."
                        );
                    }
                    if _selector_key(sref, scommit) != _selector_key(tref, tcommit) {
                        raise JacDepError(
                            f"Version conflict for '{tname}': "
                            f"{_selector_key(sref, scommit)} vs "
                            f"{_selector_key(tref, tcommit)} "
                            f"(via {request.name}). Unify the selectors or "
                            "use [override]."
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
                            requirer=request.name,
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
        (name, dep) = (request.name, request.dep);
        if not _safe_dep_name(name) {
            raise JacDepError(
                f"Unsafe dependency name: '{name}' (requested by "
                f"{request.requirer}). "
                "Names must be a single safe path component."
            );
        }
        if request.source == "path" {
            if not os.path.isdir(request.key) {
                raise JacDepError(
                    f"[dependencies.jac] '{name}': path '{dep.get('path')}' "
                    f"(resolved {request.key}) does not exist"
                );
            }
            pkg_tree = dirhash(Path(request.key));
            if ctx is not None and ctx.frozen {
                row = pins if isinstance(pins, dict) else {};
                if not row {
                    raise JacDepError(
                        f"jac.lock is missing '{name}' (requested by "
                        f"{request.requirer}). Run 'jac install' to refresh the "
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
                        os.path.realpath(str(Path(request.base_dir) / recorded_path)),
                        os.path.realpath(recorded_path),
                        os.path.realpath(str(Path.cwd() / recorded_path))
                    ];
                    if os.path.realpath(request.key) not in recorded_abs_candidates {
                        raise JacDepError(
                            f"'{name}': manifest path resolves to {request.key} "
                            f"but jac.lock records {recorded_path}. Run "
                            f"'jac install' to refresh the lockfile."
                        );
                    }
                }
            }
            pkg = JacPackage(
                name=name,
                key=request.key,
                source="path",
                pkg_root=request.key,
                tree=pkg_tree,
                requested_by=[request.requirer]
            );
        } else {
            pin_sha = str(pins.get("sha", "")) if pins else "";
            stale: list[str] = [];
            if pin_sha and request.commit and request.commit != pin_sha {
                stale.append(
                    f"manifest pins commit {request.commit[:12]} but jac.lock "
                    f"records {pin_sha[:12]}"
                );
            }
            if pin_sha and str(pins.get("git", "")) != request.key {
                stale.append(
                    f"manifest source is {request.key} but jac.lock records "
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
                    f"{request.requirer}). Run 'jac install' to refresh the "
                    f"lockfile."
                );
            }
            fetched = fetch_package(
                url=request.key,
                ref=request.ref,
                sha=request.commit or pin_sha or None,
                expected_tree=str(pins.get("tree", "")),
                verify=bool(pins),
                frozen=(ctx is not None and ctx.frozen)
            );
            pkg = JacPackage(
                name=name,
                key=request.key,
                source="git",
                ref=request.ref,
                req_commit=request.commit,
                sha=fetched.sha,
                tree=fetched.tree,
                pkg_root=fetched.path,
                requested_by=[request.requirer]
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
                f"Version conflict for '{name}': '{request.requirer}' requires "
                f"{constraint}, but {request.key} resolves to {pkg.version}"
            );
        }
        _validate_package_field(Path(pkg.pkg_root), name, dep);
        if ctx is not None and ctx.verbose {
            via = f" @ {pkg.sha[:12]}" if pkg.sha else "";
            console.print(f"  jac dep {name}{via} -> {pkg.pkg_root}", style="muted");
        }
        return pkg;
    }

    override def add_package(
        config: JacConfig, name: str, version: str, dev: bool, ctx: InstallContext
    ) -> str | None {
        raise NotImplementedError(
            "pure-jac deps are added with 'jac install jac:<url-or-path>'"
        );
    }
}
