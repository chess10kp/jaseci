import re;
import from pathlib { Path }


glob VALID_ECOSYSTEMS: set[str] = {"jac", "python", "npm"},
     VALID_SOURCES: set[str] = {
         "git",
         "path",
         "pypi",
         "npm",
         "python",
         "jac",
         "registry",
         "url",
         "workspace"
     },
     VERSION_PATTERN: str = r"^(\^|=|>=|<=|>|<|~)?\d+(\.\d+){0,2}([*-][0-9A-Za-z.-]+)?$";


obj DependencySpec {
    has ecosystem: str = "jac",
        alias: str = "",
        source: str = "",
        source_location: str = "",
        ref: str = "",
        commit: str = "",
        version_constraint: str = "",
        import_root: str = "",
        dev: bool = False;
}


obj DependencyNode {
    has id: str = "",
        ecosystem: str = "",
        alias: str = "",
        project_name: str = "",
        source: str = "",
        source_location: str = "",
        ref: str = "",
        commit: str = "",
        tree: str = "",
        version: str = "",
        import_root: str = "",
        dev: bool = False;
}


obj DependencyEdge {
    has from_id: str = "",
        to_id: str = "",
        kind: str = "dependency",
        requirement: str = "",
        dev: bool = False;
}


obj ProviderRequirement {
    has consumer_id: str = "",
        ecosystem: str = "",
        name: str = "",
        constraint: str = "",
        source: str = "",
        location: str = "",
        dev: bool = False,
        extras: list[str] = [];
}


obj ProviderResolution {
    has nodes: dict[str, DependencyNode] = {},
        edges: list[DependencyEdge] = [],
        install_plan: list[any] = [];
}


obj ResolutionContext {
    has include_dev: bool = False,
        frozen: bool = False,
        update_targets: set[str] = set(),
        manifest_fingerprint: str = "",
        # Interpreter the resolved pins will actually be installed with
        # (the project venv's python). Empty means "unknown, fall back to
        # sys.executable", which is what the venv will be created from.
        interpreter: str = "";
}


obj ProviderStage {
    has paths: list[str] = [],
        metadata: dict[str, any] = {};
}


obj LockGraph {
    has nodes: dict[str, DependencyNode] = {},
        edges: list[DependencyEdge] = [],
        manifest_fingerprint: str = "",
        include_dev: bool = False;
}


obj ResolutionPlan {
    has nodes: dict[str, DependencyNode] = {},
        edges: list[DependencyEdge] = [],
        manifest_text: str = "",
        lock_data: dict[str, any] = {},
        staged_materializations: dict[str, any] = {},
        provider_resolutions: dict[str, ProviderResolution] = {},
        save_manifest: bool = True,
        dry_run: bool = False;
}


obj PackageOperation {
    has action: str = "install",
        specs: list[DependencySpec] = [],
        targets: list[str] = [],
        ecosystem: str = "jac",
        include_dev: bool = False,
        frozen: bool = False,
        dry_run: bool = False,
        save: bool = True,
        extras: list[str] = [],
        scale: bool = False;
}


obj PendingRequest {
    has name: str = "",
        dep: dict[str, any] = {},
        base_dir: str = "",
        requirer: str = "root",
        source: str = "git",
        key: str = "",
        ref: str = "",
        commit: str = "";
}


def normalize_ecosystem(ecosystem: str) -> str {
    normalized = str(ecosystem).strip().lower();
    if normalized not in VALID_ECOSYSTEMS {
        raise ValueError(
            f"Unsupported dependency ecosystem '{ecosystem}'; "
            "expected jac, python, or npm"
        );
    }
    return normalized;
}


def normalize_dependency_name(ecosystem: str, name: str) -> str {
    ecosystem = normalize_ecosystem(ecosystem);
    value = str(name).strip();
    if not value {
        raise ValueError("Dependency name cannot be empty");
    }
    if ecosystem in {"python", "npm"} {
        return re.sub(r"[-_.]+", "-", value).lower();
    }
    validate_alias(value);
    return value;
}


def canonical_dependency_id(ecosystem: str, name: str) -> str {
    return f"{normalize_ecosystem(ecosystem)}:{normalize_dependency_name(
        ecosystem, name
    )}";
}


def validate_alias(alias: str) -> str {
    value = str(alias).strip();
    if (
        not value
        or value in {".", ".."}
        or value != str(alias)
        or any(c in value for c in ("/", "\\", ":"))
        or any(ord(c) < 32 or ord(c) == 127 for c in value)
        or value.endswith(".")
        or not re.match(r"^[A-Za-z0-9][A-Za-z0-9_.-]*$", value)
    ) {
        raise ValueError(
            f"Unsafe dependency alias '{alias}'; use a single path component"
        );
    }
    return value;
}


def validate_import_root(import_root: str) -> str {
    value = str(import_root).strip();
    if not value or value.startswith(".") or value.endswith(".") {
        raise ValueError(f"Invalid import root '{import_root}'");
    }
    parts = value.split(".");
    if any(not p or not re.match(r"^[A-Za-z_][A-Za-z0-9_]*$", p) for p in parts) {
        raise ValueError(f"Invalid import root '{import_root}'");
    }
    return value;
}


def validate_source(source: str) -> str {
    value = str(source).strip().lower();
    if value not in VALID_SOURCES {
        raise ValueError(
            f"Unsupported dependency source '{source}'; expected one of: "
                + ", ".join(sorted(VALID_SOURCES))
        );
    }
    return value;
}


def validate_version_constraint(constraint: str) -> str {
    value = str(constraint).strip();
    if not value {
        return value;
    }
    if any(ord(c) < 32 for c in value) or not re.match(VERSION_PATTERN, value) {
        raise ValueError(f"Unsupported version constraint '{constraint}'");
    }
    return value;
}


def validate_dependency_spec(spec: DependencySpec) -> DependencySpec {
    spec.ecosystem = normalize_ecosystem(spec.ecosystem);
    spec.alias = validate_alias(spec.alias);
    spec.source = validate_source(spec.source);
    spec.version_constraint = validate_version_constraint(spec.version_constraint);
    if spec.import_root {
        spec.import_root = validate_import_root(spec.import_root);
    }
    if spec.source_location.strip() == "" {
        raise ValueError(f"Dependency '{spec.alias}' has no source location");
    }
    if spec.commit and not re.match(r"^[0-9a-fA-F]{40}$", spec.commit) {
        raise ValueError(f"Dependency '{spec.alias}' has an invalid commit");
    }
    return spec;
}
