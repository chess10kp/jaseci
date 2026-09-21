"""Tests for the pure-jac dependency provider ([dependencies.jac]).

Covers jaclang.project.jac_store (URL normalization, tree hashing,
content-addressed fetch from local git fixtures) and
jaclang.project.jac_provider (spec parsing, closure resolution, flat
unification conflicts, [override], deps map, remove).
"""

import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.project.config { JacConfig }
import from tests.deps_fixtures {
    git_branch,
    git_commit_all,
    git_head,
    isolate_store,
    jac_sync,
    make_git_repo,
    make_project,
    restore_store
}
import from jaclang.project.jac_store {
    JacDepError,
    dirhash,
    fetch_package,
    git_package_name,
    materialize,
    normalize_git_url,
    store_root
}
import from jaclang.project.dep_roots { read_deps_map, read_deps_roots }
import from jaclang.project.jac_provider {
    JacDepProvider,
    manifest_jac_deps,
    parse_jac_spec,
    version_satisfied
}
import from jaclang.project.providers { InstallContext, get_provider_registry }
import from jaclang.project.dependency_model { ResolutionPlan }
import from jaclang.project.lockfile { jac_lock_rows, read_lock, write_lock }


# ===== URL and spec parsing =====
test "normalize_git_url canonical forms" {
    assert normalize_git_url("github.com/foo/bar") == "https://github.com/foo/bar";
    assert (
        normalize_git_url("https://github.com/foo/bar.git")
        == "https://github.com/foo/bar"
    );
    assert (
        normalize_git_url("git@github.com:foo/bar/") == "ssh://git@github.com/foo/bar"
    );
    assert (
        normalize_git_url("ssh://git@github.com/foo/bar")
        == "ssh://git@github.com/foo/bar"
    );
    assert (
        normalize_git_url("ssh://git@github.com:2222/foo/bar")
        == "ssh://git@github.com:2222/foo/bar"
    );
    assert normalize_git_url("/tmp/some/repo") == "/tmp/some/repo";
    assert normalize_git_url("../local/repo") == "../local/repo";
    raised = False;
    try {
        normalize_git_url("ftp://example.com/x");
    } except JacDepError {
        raised = True;
    }
    assert raised;
}

test "git_package_name extracts last segment" {
    assert git_package_name("github.com/foo/my-lib.git") == "my-lib";
    assert git_package_name("/tmp/some/repo/") == "repo";
}

test "parse_jac_spec forms" {
    (name, ent) = parse_jac_spec("jac:github.com/foo/mylib");
    assert name == "mylib";
    assert ent == {"git": "github.com/foo/mylib"};
    (name, ent) = parse_jac_spec("jac:github.com/foo/mylib@v1.2");
    assert ent == {"git": "github.com/foo/mylib", "ref": "v1.2"};
    (name, ent) = parse_jac_spec("jac:github.com/foo/mylib@" + "a" * 40);
    assert ent == {"git": "github.com/foo/mylib", "commit": "a" * 40};
    (name, ent) = parse_jac_spec("jac:git@github.com:org/repo");
    assert name == "repo";
    assert ent == {"git": "git@github.com:org/repo"};
    (name, ent) = parse_jac_spec("jac:ssh://git@example.com:2222/org/repo");
    assert name == "repo";
    assert ent == {"git": "ssh://git@example.com:2222/org/repo"};
    (name, ent) = parse_jac_spec("jac:ssh://git@example.com:2222/org/repo@v1");
    assert name == "repo";
    assert ent == {"git": "ssh://git@example.com:2222/org/repo", "ref": "v1"};
    (name, ent) = parse_jac_spec("jac:https://user@github.com/org/repo");
    assert name == "repo";
    assert ent == {"git": "https://user@github.com/org/repo"};
    (name, ent) = parse_jac_spec("jac:../utils");
    assert name == "utils";
    assert ent == {"path": "../utils"};
    raised = False;
    try {
        parse_jac_spec("jac:justaname");
    } except JacDepError {
        raised = True;
    }
    assert raised;
}

# ===== tree hashing =====
test "dirhash stable, sensitive, ignores junk dirs" {
    tmp = tempfile.mkdtemp(prefix="jac_hash_test_");
    try {
        a = Path(tmp) / "a";
        b = Path(tmp) / "b";
        for d in (a, b) {
            d.mkdir();
            (d / "lib.jac").write_text("def f -> int { return 1; }\n");
            (d / ".jac").mkdir();
            (d / ".jac" / "cache.bin").write_text("junk");
        }
        assert dirhash(a) == dirhash(b);
        (a / "extra.jac").write_text("def g {}\n");
        assert dirhash(a) != dirhash(b);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


def make_plain_pkg(path: Path, jac_toml: str, files: dict[str, str]) -> str {
    path.mkdir(parents=True, exist_ok=True);
    (path / "jac.toml").write_text(jac_toml, encoding="utf-8");
    for (name, content) in files.items() {
        (path / name).write_text(content, encoding="utf-8");
    }
    return str(path);
}


# ===== manifest table round-trip =====
test "jac manifest table round-trips through save" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\n'
        'mylib = { git = "github.com/foo/mylib", branch = "main" }\n\n'
        '[dev-dependencies.jac]\n'
        'utils = { path = "../utils" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        (deps, dev_deps) = manifest_jac_deps(config);
        assert deps["mylib"]["git"] == "github.com/foo/mylib";
        assert deps["mylib"]["branch"] == "main";
        assert dev_deps["utils"]["path"] == "../utils";
        config.save();
        toml_loc = config.toml_path;
        assert toml_loc is not None;
        reloaded = JacConfig.load(toml_loc);
        (deps2, dev_deps2) = manifest_jac_deps(reloaded);
        assert deps2["mylib"] == deps["mylib"];
        assert dev_deps2["utils"] == dev_deps["utils"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# ===== closure resolution (path deps, offline) =====
test "path dep closure writes deps map" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nlibb = { path = "../libb" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        libb = base / "libb";
        libc = base / "libc";
        libc.mkdir();
        (libc / "jac.toml").write_text(
            '[project]\nname = "libc"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        (libc / "libc.jac").write_text(
            "def c() -> int { return 3; }\n", encoding="utf-8"
        );
        make_plain_pkg(
            libb,
            '[project]\nname = "libb"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nlibc = { path = "../libc" }\n',
            {"libb.jac": "def b() -> int { return 2; }\n"}
        );
        provider = JacDepProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        assert sorted(resolved.keys()) == ["libb", "libc"];
        assert resolved["libc"].requested_by == ["libb"];
        assert resolved["libc"].local_path == libc.resolve();
        jac_sync(config);
        map_path = config.get_build_dir() / "deps.json";
        assert map_path.is_file();
        roots = read_deps_roots(config.project_root or Path.cwd());
        assert len(roots) == 2;
        # Roots point at the materialized generation snapshot, not the
        # source tree.
        libb_root = [
            Path(r)
            for r in roots
            if (Path(r) / "libb.jac").is_file()
        ];
        libc_root = [
            Path(r)
            for r in roots
            if (Path(r) / "libc.jac").is_file()
        ];
        assert libb_root and libc_root , f"generation roots incomplete: {roots}";
        assert (libb_root[0] / "jac.toml").is_file();
        assert (libc_root[0] / "jac.toml").is_file();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "name collision across requirers is a hard error" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nx = { path = "../x" }\ny = { path = "../y" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        for pkg in ("x", "y") {
            sub = base / pkg;
            sub_toml = (
                f'[project]\nname = "{pkg}"\nversion = "1.0.0"\n\n'
                f'[dependencies.jac]\nshared = {{ path = "../shared_{pkg}" }}\n'
            );
            make_plain_pkg(sub, sub_toml, {});
            shared = base / f"shared_{pkg}";
            make_plain_pkg(
                shared, '[project]\nname = "shared"\nversion = "1.0.0"\n', {}
            );
        }
        provider = JacDepProvider();
        try {
            provider.resolve_closure(config, InstallContext());
            assert False;
        } except JacDepError as e {
            assert "collision" in str(e);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "override replaces a transitive entry" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nx = { path = "../x" }\n\n'
        '[override]\nshared = { path = "../shared_override" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(
            base / "x",
            '[project]\nname = "x"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nshared = { path = "../shared_x" }\n',
            {}
        );
        make_plain_pkg(
            base / "shared_x", '[project]\nname = "shared"\nversion = "1.0.0"\n', {}
        );
        make_plain_pkg(
            base / "shared_override",
            '[project]\nname = "shared"\nversion = "9.9.9"\n',
            {}
        );
        provider = JacDepProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        shared = resolved["shared"];
        shared_dir = base / "shared_override";
        assert shared.key == os.path.realpath(str(shared_dir));
        assert shared.requested_by == ["x"];
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

# ===== git deps (local fixture origin) =====
test "git dep fetches into store and dedupes" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_git_test_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        fetched = fetch_package(url=origin, ref="");
        assert Path(fetched.path).is_dir();
        assert (Path(fetched.path) / "mylib.jac").is_file();
        assert fetched.tree.startswith("sha256-");
        assert not (Path(fetched.path) / ".git").exists();
        refetched = fetch_package(url=origin, sha=fetched.sha);
        assert refetched.path == fetched.path;
        assert refetched.tree == fetched.tree;
        assert store_root().is_dir();
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "git dep end-to-end through the provider" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_git_e2e_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            roots = read_deps_roots(config.project_root or Path.cwd());
            assert len(roots) == 1;
            assert (Path(roots[0]) / "mylib.jac").is_file();
            local = config.get_build_dir() / "packages" / "mylib";
            assert (local / "mylib.jac").is_file();
            assert (local / "jac.toml").is_file();
            assert not (local / ".git").exists();
            resolved = provider.resolve_closure(config, InstallContext());
            assert resolved["mylib"].version == "1.2.0";
            assert resolved["mylib"].sha;
            import from jaclang.project.dependency_model { PackageOperation }
            import from jaclang.project.package_manager { commit_plan, plan_operation }
            remove_plan = plan_operation(
                config,
                PackageOperation(action="remove", ecosystem="jac", targets=["mylib"])
            );
            commit_plan(config, remove_plan);
            assert read_deps_roots(config.project_root or Path.cwd()) == [];
            fresh_config = JacConfig.load(
                (config.project_root or Path.cwd()) / "jac.toml"
            );
            (deps, _) = manifest_jac_deps(fresh_config);
            assert "mylib" not in deps;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "registry exposes the jac provider" {
    registry = get_provider_registry();
    provider = registry.get("jac");
    assert provider is not None;
    assert provider.name == "jac";
    assert registry.get_by_flag("--npm") is not None;
}

# ===== jac.lock =====
test "lock rows round-trip through install" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_rt_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            lock_file = (config.project_root or Path.cwd()) / "jac.lock";
            assert lock_file.is_file();
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert "mylib" in rows;
            row = rows["mylib"];
            assert row["git"] == origin;
            assert row["sha"];
            assert row["tree"].startswith("sha256-");
            assert row["version"] == "1.2.0";
            assert row["requested_by"] == ["root"];
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "frozen replay keeps the recorded commit" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_fz_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            pinned_sha = rows["mylib"]["sha"];
            (origin_path / "extra.jac").write_text(
                "def extra() -> int { return 7; }\n", encoding="utf-8"
            );
            env = dict(os.environ);
            subprocess.run(
                ["git", "-C", str(origin_path), "add", "-A"], check=True, env=env
            );
            subprocess.run(
                [
                    "git",
                    "-C",
                    str(origin_path),
                    "-c",
                    "user.name=t",
                    "-c",
                    "user.email=t@t",
                    "commit",
                    "-q",
                    "-m",
                    "second"
                ],
                check=True,
                env=env
            );
            replayed = provider.resolve_closure(
                config,
                InstallContext(frozen=True),
                frozen_pins=jac_lock_rows(read_lock(config.project_root or Path.cwd()))
            );
            assert replayed["mylib"].sha == pinned_sha;
            fresh = provider.resolve_closure(config, InstallContext());
            assert fresh["mylib"].sha != pinned_sha;
            # Advancing the lock is an update: plain install keeps pins.
            import from jaclang.project.dependency_model { PackageOperation }
            import from jaclang.project.package_manager { commit_plan, plan_operation }
            commit_plan(
                config,
                plan_operation(
                    config,
                    PackageOperation(
                        action="update", ecosystem="jac", targets=["mylib"]
                    )
                )
            );
            rows2 = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert rows2["mylib"]["sha"] == fresh["mylib"].sha;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install replays a moved branch from the recorded commit" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_fzb_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"},
            branch="main"
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\n'
            f'mylib = {{ git = "{origin}", branch = "main" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert rows["mylib"]["ref"] == "main";
            pinned_sha = rows["mylib"]["sha"];
            # main advances past the recorded commit.
            (origin_path / "mylib.jac").write_text(
                "def hello() -> int { return 43; }\n", encoding="utf-8"
            );
            moved = git_commit_all(origin_path, "advance main");
            assert moved != pinned_sha;
            # Cold store: the replay must re-fetch, so it exercises the
            # commit-first checkout instead of a store hit.
            store_dir = store_root();
            for item in store_dir.iterdir() {
                if item.is_dir() {
                    shutil.rmtree(item, ignore_errors=True);
                } else {
                    item.unlink();
                }
            }
            jac_sync(config, frozen=True);
            rows2 = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert rows2["mylib"]["sha"] == pinned_sha;
            assert rows2["mylib"]["ref"] == "main";
            # A fresh (non-frozen, pin-free) resolution still follows main.
            fresh = provider.resolve_closure(config, InstallContext());
            assert fresh["mylib"].sha == moved;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "frozen install errors when manifest is ahead of lock" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_lock_st_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        origin2 = make_git_repo(
            Path(outer) / "origin2",
            '[project]\nname = "otherlib"\nversion = "2.0.0"\n',
            {"otherlib.jac": "def other() -> int { return 1; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            section = config.plugin_dependencies.setdefault("jac", {});
            section["newdep"] = {"git": origin2};
            config.save();
            try {
                jac_sync(config, frozen=True);
                assert False , "frozen install accepted a manifest ahead of the lock";
            } except JacDepError {
                handled = True;
            }
            jac_sync(config);
            rows = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert "newdep" in rows;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}

test "why chains trace reverse edges" {
    import from jaclang.project.lockfile { why_chains }
    lock_data = {
        "jac": {
            "mylib": {"git": "https://x", "requested_by": ["root"]},
            "shared": {"git": "https://y", "requested_by": ["mylib", "other"]}
        },
        "python_graph": {"requests": ["root"], "urllib3": ["requests"]}
    };
    chains = why_chains(lock_data, "urllib3");
    assert chains == [("python", ["urllib3", "requests", "root"])];
    shared_chains = why_chains(lock_data, "shared");
    assert ("jac", ["shared", "mylib", "root"]) in shared_chains;
    assert ("jac", ["shared", "other"]) in shared_chains;
    assert why_chains(lock_data, "mylib") == [("jac", ["mylib", "root"])];
    assert why_chains(lock_data, "nope") == [("jac", ["nope"])];
}


test "dependency paths with control characters are rejected" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nevil = { path = "../ok\\nimport os" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(base / "ok", '[project]\nname = "ok"\nversion = "1.0.0"\n', {});
        provider = JacDepProvider();
        try {
            provider.resolve_closure(config, InstallContext());
            assert False;
        } except JacDepError as e {
            assert "control characters" in str(e);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "override resolves a genuine cross-parent conflict" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nx = { path = "../x" }\ny = { path = "../y" }\n\n'
        '[override]\nshared = { path = "../shared_override" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        make_plain_pkg(
            base / "x",
            '[project]\nname = "x"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nshared = { path = "../shared_x" }\n',
            {}
        );
        make_plain_pkg(
            base / "y",
            '[project]\nname = "y"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\nshared = { path = "../shared_y" }\n',
            {}
        );
        make_plain_pkg(
            base / "shared_x", '[project]\nname = "shared"\nversion = "1.0.0"\n', {}
        );
        make_plain_pkg(
            base / "shared_y", '[project]\nname = "shared"\nversion = "2.0.0"\n', {}
        );
        make_plain_pkg(
            base / "shared_override",
            '[project]\nname = "shared"\nversion = "9.9.9"\n',
            {}
        );
        provider = JacDepProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        assert sorted(resolved.keys()) == ["shared", "x", "y"];
        assert resolved["shared"].key
            == os.path.realpath(str(base / "shared_override"));
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

test "frozen install fails when a transitive dep misses the lock" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_frozen_t_");
        sub_origin = make_git_repo(
            Path(outer) / "sub",
            '[project]\nname = "sub"\nversion = "1.0.0"\n',
            {"sub.jac": "def s() -> int { return 1; }\n"}
        );
        mylib_origin = make_git_repo(
            Path(outer) / "mylib",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n\n'
            f'[dependencies.jac]\nsub = {{ git = "{sub_origin}" }}\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{mylib_origin}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            lock = read_lock(config.project_root or Path.cwd());
            rows = jac_lock_rows(lock);
            assert "sub" in rows;
            del rows["sub"];
            lock["jac"] = rows;
            assert write_lock(config.project_root or Path.cwd(), lock);
            try {
                jac_sync(config, frozen=True);
                assert False , "frozen install missed a transitive lock row";
            } except JacDepError {
                handled = True;
            }
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "targeted replay keeps non-targeted deps pinned" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_targeted_");
        origin_a_path = Path(outer) / "a";
        origin_a = make_git_repo(
            origin_a_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        origin_b = make_git_repo(
            Path(outer) / "b",
            '[project]\nname = "otherlib"\nversion = "2.0.0"\n',
            {"otherlib.jac": "def other() -> int { return 1; }\n"}
        );
        toml_text = (
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nmylib = {{ git = "{origin_a}" }}\n'
            f'otherlib = {{ git = "{origin_b}" }}\n'
        );
        (config, tmp) = make_project(toml_text);
        try {
            provider = JacDepProvider();
            jac_sync(config);
            old_b = jac_lock_rows(read_lock(config.project_root or Path.cwd()))[
                "otherlib"
            ]["sha"];
            (origin_a_path / "extra.jac").write_text(
                "def extra() -> int { return 7; }\n", encoding="utf-8"
            );
            new_a = git_commit_all(origin_a_path, "advance");
            pins = jac_lock_rows(read_lock(config.project_root or Path.cwd()));
            assert pins["mylib"]["sha"] != new_a;
            del pins["mylib"];
            resolved = provider.resolve_closure(
                config, InstallContext(), frozen_pins=pins
            );
            assert resolved["mylib"].sha == new_a;
            assert resolved["otherlib"].sha == old_b;
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "dedupe keeps the requested origin provenance" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_dedupe_");
        payload = '[project]\nname = "mylib"\nversion = "1.2.0"\n';
        files = {"mylib.jac": "def hello() -> int { return 42; }\n"};
        origin_a = make_git_repo(Path(outer) / "a", payload, files);
        origin_b = make_git_repo(Path(outer) / "b", payload, files);
        env = dict(os.environ);
        subprocess.run(
            [
                "git",
                "-C",
                str(Path(outer) / "b"),
                "-c",
                "user.name=t",
                "-c",
                "user.email=t@t",
                "commit",
                "-q",
                "--allow-empty",
                "-m",
                "second"
            ],
            check=True,
            env=env
        );
        sha_a = git_head(Path(outer) / "a");
        sha_b = git_head(Path(outer) / "b");
        assert sha_a != sha_b;
        first = fetch_package(url=origin_a, ref="");
        second = fetch_package(url=origin_b, ref="");
        assert first.tree == second.tree;
        assert first.path == second.path;
        assert second.sha == sha_b;
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "moved tag fails and moved branch replays" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_ref_check_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        head1 = git_head(origin_path);
        subprocess.run(["git", "-C", str(origin_path), "tag", "v1"], check=True);
        (origin_path / "mylib.jac").write_text(
            "def hello() -> int { return 43; }\n", encoding="utf-8"
        );
        head2 = git_commit_all(origin_path, "move on");
        subprocess.run(
            ["git", "-C", str(origin_path), "tag", "-f", "v1", head2],
            check=True,
            capture_output=True
        );
        branch = git_branch(origin_path);
        replayed = fetch_package(url=origin, ref=branch, sha=head1);
        assert replayed.sha == head1;
        try {
            fetch_package(url=origin, ref="v1", sha=head1);
            assert False;
        } except JacDepError as e {
            assert "no longer resolves" in str(e);
        }
        ok = fetch_package(url=origin, ref="v1", sha=head2);
        assert ok.sha == head2;
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "materialization rejects symlinks" {
    tmp = tempfile.mkdtemp(prefix="jac_material_");
    try {
        src = Path(tmp) / "src";
        src.mkdir(parents=True);
        (src / "a.txt").write_text("one", encoding="utf-8");
        outside = Path(tmp) / "outside";
        outside.mkdir();
        os.symlink(str(outside), str(src / "link"));
        dest = Path(tmp) / "dest";
        raised = False;
        try {
            materialize(src, dest);
        } except JacDepError {
            raised = True;
        }
        assert raised;
        assert not dest.exists();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "lock writer emits valid TOML for odd names and values" {
    tmp = tempfile.mkdtemp(prefix="jac_lock_toml_");
    try {
        ok = write_lock(
            Path(tmp),
            {
                "jac": {
                    "my.json": {
                        "git": "https://x/my-json",
                        "path": "C:\\Users\\x\"y",
                        "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                        "tree": "sha256-deadbeef",
                        "requested_by": ["root"]
                    },
                    "plain": {
                        "git": "https://x/plain",
                        "sha": "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                    }
                },
                "python": {"some-pkg": "==1.0.0"},
                "python_graph": {"requests": ["root"]},
                "npm": {"left-pad": "1.2.3"}
            }
        );
        assert ok;
        data = read_lock(Path(tmp));
        rows = jac_lock_rows(data);
        assert rows["my.json"]["path"] == "C:\\Users\\x\"y";
        assert rows["my.json"]["requested_by"] == ["root"];
        assert data["python"]["some-pkg"] == "==1.0.0";
        assert data["python_graph"]["requests"] == ["root"];
        assert data["npm"]["left-pad"] == "1.2.3";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "why chains surface every ecosystem for a shared name" {
    import from jaclang.project.lockfile { why_chains }
    lock_data = {
        "jac": {"dup": {"git": "https://x", "requested_by": ["root"]}},
        "python_graph": {"dup": ["root"], "requests": ["root"]}
    };
    chains = why_chains(lock_data, "dup");
    assert len(chains) == 2;
    assert ("jac", ["dup", "root"]) in chains;
    assert ("python", ["dup", "root"]) in chains;
}


test "read_deps_roots ignores malformed deps maps" {
    import from jaclang.project.config { get_config, set_config }
    cwd = os.getcwd();
    payloads = [
        '[]',
        '7',
        '"str"',
        '{"packages": 5}',
        '{"packages": ["nope", 7, null, {"local": 9}]}'
    ];
    try {
        # Each case gets its own fresh project dir: a fresh deps.json path
        # means a fresh _deps_roots_cache key, so no case can serve a stale
        # cache entry on coarse-mtime filesystems.
        for payload in payloads {
            case_dir = Path(tempfile.mkdtemp(prefix="jac_deps_roots_"));
            (case_dir / "jac.toml").write_text(
                '[project]\nname = "proj"\nversion = "0.1.0"\n', encoding="utf-8"
            );
            os.chdir(case_dir);
            set_config(None);
            config = get_config();
            assert config is not None;
            config.get_build_dir().mkdir(parents=True, exist_ok=True);
            (config.get_build_dir() / "deps.json").write_text(
                payload, encoding="utf-8"
            );
            assert read_deps_roots(case_dir) == [] , (
                f"malformed deps map not ignored: {payload}"
            );
        }
        # A well-formed map still yields its existing local roots.
        good = Path(tempfile.mkdtemp(prefix="jac_deps_roots_"));
        (good / "jac.toml").write_text(
            '[project]\nname = "proj"\nversion = "0.1.0"\n', encoding="utf-8"
        );
        os.chdir(good);
        set_config(None);
        gconfig = get_config();
        assert gconfig is not None;
        gconfig.get_build_dir().mkdir(parents=True, exist_ok=True);
        pkg_dir = good / "vendor" / "local_pkg";
        pkg_dir.mkdir(parents=True);
        (gconfig.get_build_dir() / "deps.json").write_text(
            f'{{"packages": ["junk", {{"local": "{pkg_dir}"}}]}}', encoding="utf-8"
        );
        assert read_deps_roots(good) == [str(pkg_dir)];
    } finally {
        os.chdir(cwd);
        set_config(None);
    }
}


test "safe dependency name check rejects traversal components" {
    import from jaclang.project.jac_provider { _safe_dep_name }
    bs = chr(92);
    ok = ["mylib", "my-lib", "My_Lib2", "a.b.c", "lib-1.2"];
    for name in ok {
        assert _safe_dep_name(name) , f"safe name rejected: {name}";
    }
    bad = [
        "",
        ".",
        "..",
        "a/b",
        bs.join(["..", "..", "escaped"]),
        "C:" + bs + "temp",
        "con",
        "COM1",
        "nul.txt",
        " x",
        "x ",
        "x.",
        "a" + chr(9)
    ];
    for name in bad {
        assert not _safe_dep_name(name) , f"unsafe name accepted: {name}";
    }
}


test "transitive dependency with unsafe name is rejected" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_unsafe_name_");
        bs = chr(92);
        origin_path = Path(outer) / "origin";
        # Windows traversal name: on Windows this escapes .jac/packages.
        bad_name = ".." + bs + ".." + bs + "escaped";
        origin = make_git_repo(
            origin_path,
            "[project]\nname = \"outer\"\nversion = \"1.0.0\"\n\n"
            "[dependencies.jac]\n"
                + "\""
                + bad_name
                + "\" = { path = \"../sibling\" }\n",
            {"outer.jac": "def o() -> int { return 1; }\n"}
        );
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nouter = {{ git = "{origin}", branch = "main" }}\n'
        );
        try {
            provider = JacDepProvider();
            try {
                jac_sync(config);
                assert False , ("unsafe transitive dependency name was accepted");
            } except JacDepError {
                handled = True;
            }
            packages_root = config.get_build_dir() / "packages";
            assert not (config.get_build_dir() / "escaped").exists();
            assert not (Path(tmp) / "escaped").exists();
            if packages_root.is_dir() {
                for item in packages_root.iterdir() {
                    assert item.name == "outer" , (
                        f"unexpected package directory: {item.name}"
                    );
                }
            }
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install validates path dependency tree hashes" {
    (store_tmp, old_env) = isolate_store();
    try {
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\nutils = { path = "../utils" }\n'
        );
        utils = Path(tmp) / "utils";
        utils.mkdir();
        (utils / "jac.toml").write_text(
            '[project]\nname = "utils"\nversion = "1.0.0"\n', encoding="utf-8"
        );
        (utils / "utils.jac").write_text(
            "def u() -> int { return 1; }\n", encoding="utf-8"
        );
        project_dir = Path(tmp) / "proj";
        try {
            provider = JacDepProvider();
            jac_sync(config);
            rows = jac_lock_rows(read_lock(project_dir));
            assert os.path.realpath(str(project_dir / rows["utils"]["path"]))
                == os.path.realpath(str(utils)) , f"lock row path mismatch: {rows[
                'utils'
            ]}";
            assert rows["utils"]["tree"] , "lock row records no tree hash";

            # Unchanged content: frozen replay succeeds.
            jac_sync(config, frozen=True);

            # Content drift must fail the frozen replay.
            (utils / "utils.jac").write_text(
                "def u() -> int { return 999; }\n", encoding="utf-8"
            );
            try {
                jac_sync(config, frozen=True);
                assert False , "frozen replay accepted drifted path dependency content";
            } except JacDepError {
                handled = True;
            }

            # Restoring the recorded content unblocks the replay.
            (utils / "utils.jac").write_text(
                "def u() -> int { return 1; }\n", encoding="utf-8"
            );
            jac_sync(config, frozen=True);
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install requires lock rows for transitive path deps" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_frozen_tpath_");
        origin_path = Path(outer) / "origin";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "outer"\nversion = "1.0.0"\n\n'
            '[dependencies.jac]\ntv = { path = "tv" }\n',
            {
                "outer.jac": "def o() -> int { return 1; }\n",
                "tv/jac.toml": '[project]\nname = "tv"\nversion = "1.0.0"\n',
                "tv/tv.jac": "def t() -> int { return 2; }\n"
            },
            branch="main"
        );
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            f'[dependencies.jac]\nouter = {{ git = "{origin}", branch = "main" }}\n'
        );
        project_dir = Path(tmp) / "proj";
        try {
            jac_sync(config);
            rows = jac_lock_rows(read_lock(project_dir));
            assert "tv" in rows , f"transitive path dep not locked: {rows.keys()}";

            # Drop the transitive path row from the v2 graph: frozen replay
            # must fail.
            import from jaclang.project.lockfile { write_lock }
            original_lock = read_lock(project_dir);
            trimmed = {
                node_id: node
                for (node_id, node) in original_lock.get("nodes", {}).items()
                if node_id != "jac:tv"
            };
            trimmed_lock = dict(original_lock);
            trimmed_lock["nodes"] = trimmed;
            trimmed_lock["edges"] = [
                graph_edge
                for graph_edge in original_lock.get("edges", [])
                if graph_edge.get("to_id") != "jac:tv"
            ];
            # Drop the derived [jac] compat rows too: jac_lock_rows prefers
            # explicit rows over graph derivation, so leaving them would
            # keep tv pinned.
            trimmed_lock.pop("jac", None);
            assert write_lock(project_dir, trimmed_lock);
            try {
                jac_sync(config, frozen=True);
                assert False , "frozen replay accepted a missing transitive path lock row";
            } except JacDepError {
                handled = True;
            }

            # Restore the full lock: frozen replay succeeds again.
            assert write_lock(project_dir, original_lock);
            jac_sync(config, frozen=True);
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "no-save install materializes without touching manifest or lock" {
    import from jaclang.cli.commands { project }
    import from jaclang.project.config { set_config }
    import from jaclang.project.dep_roots { read_deps_map }
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = tempfile.mkdtemp(prefix="jac_nosave_");
        # The install derives the dep name from the URL's last segment.
        origin_path = Path(outer) / "mylib";
        origin = make_git_repo(
            origin_path,
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        (config, tmp) = make_project('[project]\nname = "proj"\nversion = "0.1.0"\n');
        project_dir = Path(tmp) / "proj";
        try {
            os.chdir(project_dir);
            set_config(None);
            toml_before = (project_dir / "jac.toml").read_text(encoding="utf-8");

            result = project.install(packages=[f"jac:file://{origin}"], no_save=True);
            assert result == 0 , f"no-save install failed: {result}";

            # Manifest untouched; no lock created.
            assert (project_dir / "jac.toml").read_text(encoding="utf-8")
                == toml_before , "jac.toml was modified by --no-save";
            assert not (project_dir / "jac.lock").exists() , (
                "--no-save wrote a lockfile"
            );

            # But the closure is installed into the project's dep state.
            fresh = JacConfig.load(project_dir / "jac.toml");
            fresh.project_root = project_dir;
            installed = {
                p.get("name", "") for p in read_deps_map(fresh).get("packages", [])
            };
            assert "mylib" in installed , f"deps map missing mylib: {installed}";
            assert (
                fresh.get_build_dir() / "packages" / "mylib" / "mylib.jac"
            ).is_file() , "mylib was not materialized under .jac/packages";

            # Import path discovery picks the materialized root up.
            roots = read_deps_roots(project_dir);
            assert any("mylib" in p for p in roots) , (
                f"deps roots do not include mylib: {roots}"
            );
        } finally {
            os.chdir(cwd);
            set_config(None);
            shutil.rmtree(tmp, ignore_errors=True);
        }
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "why chains keep same-shaped chains across ecosystems" {
    import from jaclang.project.lockfile { why_chains }
    lock_data = {
        "jac": {"dup": {"git": "https://x", "requested_by": []}},
        "npm": {"dup": "1.0.0"}
    };
    chains = why_chains(lock_data, "dup");
    assert ("jac", ["dup"]) in chains , f"jac chain dropped: {chains}";
    assert ("npm", ["dup"]) in chains , (
        f"npm chain suppressed by same-shaped jac chain: {chains}"
    );
    py_lock = {"python_graph": {"dup": []}, "npm": {"dup": "1.0.0"}};
    py_chains = why_chains(py_lock, "dup");
    assert ("python", ["dup"]) in py_chains , f"python chain dropped: {py_chains}";
    assert ("npm", ["dup"]) in py_chains , (
        f"npm chain suppressed by same-shaped python chain: {py_chains}"
    );
}


test "normalize_git_url preserves local .git suffixes" {
    assert (normalize_git_url("file:///tmp/x/repo.git") == "file:///tmp/x/repo.git");
    assert normalize_git_url("/tmp/x/repo.git") == "/tmp/x/repo.git";
    assert (
        normalize_git_url("https://github.com/foo/bar.git")
        == "https://github.com/foo/bar"
    );
    # The suffix still never leaks into the derived package name.
    assert git_package_name("file:///tmp/x/repo.git") == "repo";
    assert git_package_name("/tmp/x/repo.git/") == "repo";
    assert git_package_name("https://github.com/foo/bar.git") == "bar";
}


test "bare repo with a .git name fetches under its real path" {
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_bare_git_");
        work = make_git_repo(
            Path(outer) / "work",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        bare = Path(outer) / "repo.git";
        subprocess.run(
            ["git", "clone", "--quiet", "--bare", work, str(bare)], check=True
        );
        assert (normalize_git_url("file://" + str(bare)) == "file://" + str(bare));
        fetched = fetch_package(url="file://" + str(bare), ref="");
        assert (Path(fetched.path) / "mylib.jac").is_file();
        assert fetched.tree.startswith("sha256-");
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "tampered store entry is repaired by refetch" {
    import from jaclang.project.jac_store { _store_hit_for }
    (store_tmp, old_env) = isolate_store();
    try {
        outer = tempfile.mkdtemp(prefix="jac_tamper_");
        origin = make_git_repo(
            Path(outer) / "origin",
            '[project]\nname = "mylib"\nversion = "1.2.0"\n',
            {"mylib.jac": "def hello() -> int { return 42; }\n"}
        );
        fetched = fetch_package(url=origin, ref="");
        tampered = Path(fetched.path);
        (tampered / "mylib.jac").write_text(
            "def hello() -> int { return 1; }\n", encoding="utf-8"
        );
        # The lock-driven hit (directory name matches the recorded tree)
        # must not serve content that fails the hash.
        hit = _store_hit_for(
            store_root(), normalize_git_url(origin), fetched.sha, fetched.tree, True
        );
        assert hit is None , "tampered store entry passed verification";
        repaired = fetch_package(
            url=origin, sha=fetched.sha, expected_tree=fetched.tree
        );
        assert repaired.tree == fetched.tree;
        assert (Path(repaired.path) / "mylib.jac").read_text(encoding="utf-8")
            == "def hello() -> int { return 42; }\n";
        shutil.rmtree(outer, ignore_errors=True);
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "version constraints share one caret implementation" {
    assert version_satisfied("^1.2.3", "1.9.0");
    assert not version_satisfied("^1.2.3", "2.0.0");
    assert not version_satisfied("^1.2.3", "1.2.2");
    assert version_satisfied("^0.2.3", "0.2.9");
    assert not version_satisfied("^0.2.3", "0.3.0");
    assert version_satisfied("^0.0.3", "0.0.3");
    assert not version_satisfied("^0.0.3", "0.0.4");
    assert version_satisfied("1.2.3", "1.2.3");
    assert not version_satisfied("=1.2.3", "1.2.4");
    assert version_satisfied("^1.2", "1.3.9");
    for bad in (">=1.0", "~1.2", "*", "^abc", "") {
        raised = False;
        try {
            version_satisfied(bad, "1.0.0");
        } except JacDepError {
            raised = True;
        }
        assert raised , f"constraint silently matched: {bad!r}";
    }
}


test "lock carries a schema version" {
    tmp = tempfile.mkdtemp(prefix="jac_lock_ver_");
    try {
        assert write_lock(
            Path(tmp),
            {
                "jac": {
                    "mylib": {
                        "git": "https://x/mylib",
                        "sha": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                        "tree": "sha256-deadbeef"
                    }
                }
            }
        );
        data = read_lock(Path(tmp));
        assert data["version"] == 2;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== package field validation =====
test "package field accepts module file and package dir" {
    toml_text = (
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\n'
        'liba = { path = "../liba", package = "liba" }\n'
        'libn = { path = "../libn", package = "a.b" }\n'
    );
    (config, tmp) = make_project(toml_text);
    try {
        base = Path(tmp);
        liba = base / "liba";
        make_plain_pkg(
            liba,
            '[project]\nname = "liba"\nversion = "1.0.0"\n',
            {"liba.jac": "def a -> int { return 1; }\n"}
        );
        libn = base / "libn";
        make_plain_pkg(libn, '[project]\nname = "libn"\nversion = "1.0.0"\n', {});
        (libn / "a").mkdir();
        (libn / "a" / "b.jac").write_text(
            "def n -> int { return 2; }\n", encoding="utf-8"
        );
        provider = JacDepProvider();
        resolved = provider.resolve_closure(config, InstallContext());
        assert sorted(resolved.keys()) == ["liba", "libn"];

        (bad_config, bad_tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\n'
            'liba = { path = "../liba", package = "ghost" }\n'
        );
        try {
            ghost_base = Path(bad_tmp);
            make_plain_pkg(
                ghost_base / "liba",
                '[project]\nname = "liba"\nversion = "1.0.0"\n',
                {"liba.jac": "def a -> int { return 1; }\n"}
            );
            provider = JacDepProvider();
            raised = False;
            try {
                provider.resolve_closure(bad_config, InstallContext());
            } except JacDepError as e {
                raised = "provides no ghost.jac" in str(e);
            }
            assert raised , "missing package root was accepted";
        } finally {
            shutil.rmtree(bad_tmp, ignore_errors=True);
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== selector unification is order-independent =====
test "mixed selectors conflict regardless of declaration order" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_selector_"));
        repo = outer / "libc_repo";
        make_git_repo(
            repo,
            '[project]\nname = "libc"\nversion = "1.0.0"\n',
            {"libc.jac": "def c -> int { return 3; }\n"},
            branch="main"
        );
        subprocess.run(["git", "-C", str(repo), "tag", "v1"], check=True);
        libb = outer / "libb";
        make_plain_pkg(
            libb,
            '[project]\nname = "libb"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nlibc = {{ git = "{repo}", branch = "main" }}\n',
            {"libb.jac": "def b -> int { return 2; }\n"}
        );

        # Manifest order A: libc declared after libb, so the conflict must
        # surface from the transitive edge while libc is still only queued.
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\n'
            f'libb = {{ path = "{libb}" }}\n'
            f'libc = {{ git = "{repo}", tag = "v1" }}\n'
        );
        try {
            provider = JacDepProvider();
            raised = False;
            try {
                provider.resolve_closure(config, InstallContext());
            } except JacDepError as e {
                raised = "Version conflict for 'libc'" in str(e);
            }
            assert raised , "default-vs-ref divergence on queued dep was accepted";
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }

        # Manifest order B: libc first (resolved, tag v1), then libb's
        # transitive branch=main request must hit the same hard conflict.
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\n'
            f'libc = {{ git = "{repo}", tag = "v1" }}\n'
            f'libb = {{ path = "{libb}" }}\n'
        );
        try {
            provider = JacDepProvider();
            raised = False;
            try {
                provider.resolve_closure(config, InstallContext());
            } except JacDepError as e {
                raised = "Version conflict for 'libc'" in str(e);
            }
            assert raised , "ref-vs-branch divergence on resolved dep was accepted";
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        os.chdir(cwd);
        restore_store(store_tmp, old_env);
        shutil.rmtree(outer, ignore_errors=True);
    }
}


test "identical selectors unify across requirers" {
    (store_tmp, old_env) = isolate_store();
    cwd = os.getcwd();
    try {
        outer = Path(tempfile.mkdtemp(prefix="jac_unify_"));
        repo = outer / "libc_repo";
        make_git_repo(
            repo,
            '[project]\nname = "libc"\nversion = "1.0.0"\n',
            {"libc.jac": "def c -> int { return 3; }\n"},
            branch="main"
        );
        subprocess.run(["git", "-C", str(repo), "tag", "v1"], check=True);
        libb = outer / "libb";
        make_plain_pkg(
            libb,
            '[project]\nname = "libb"\nversion = "1.0.0"\n\n'
            f'[dependencies.jac]\nlibc = {{ git = "{repo}", tag = "v1" }}\n',
            {"libb.jac": "def b -> int { return 2; }\n"}
        );
        (config, tmp) = make_project(
            '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
            '[dependencies.jac]\n'
            f'libc = {{ git = "{repo}", tag = "v1" }}\n'
            f'libb = {{ path = "{libb}" }}\n'
        );
        try {
            provider = JacDepProvider();
            resolved = provider.resolve_closure(config, InstallContext());
            assert sorted(resolved.keys()) == ["libb", "libc"];
            assert sorted(resolved["libc"].requested_by) == ["libb", "root"];
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        os.chdir(cwd);
        restore_store(store_tmp, old_env);
        shutil.rmtree(outer, ignore_errors=True);
    }
}


# ===== Backend install-plan sync on commit =====

import from unittest.mock { MagicMock }


def _plan_with_python_rows(dep_root: Path) -> ResolutionPlan {
    import from jaclang.project.dependency_model {
        DependencyNode,
        ProviderResolution,
        ResolutionPlan
    }
    python_rows = ProviderResolution();
    python_rows.install_plan = [
        {"id": "python:six", "name": "six", "version": "1.16.0", "url": ""},
        {"id": "python:ghost", "name": "ghost", "version": "", "url": ""}
    ];
    return ResolutionPlan(
        nodes={
            "jac:dep": DependencyNode(
                id="jac:dep",
                ecosystem="jac",
                alias="dep",
                project_name="dep",
                source="path",
                source_location=str(dep_root),
                import_root="dep"
            )
        },
        lock_data={"version": 2, "nodes": {}, "edges": []},
        staged_materializations={
            "jac:dep": {"source": str(dep_root), "tree": "t", "alias": "dep"}
        },
        provider_resolutions={"python": python_rows}
    );
}


test "commit plan pins resolved backend deps into the venv" {
    import from jaclang.project.package_manager { commit_plan }
    import from jaclang.project.providers { PythonProvider }
    (config, tmp) = make_project(
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n[dependencies.jac]\n'
    );
    try {
        dep_root = Path(tmp) / "dep";
        make_plain_pkg(
            dep_root,
            '[project]\nname = "dep"\nversion = "1.0.0"\n',
            {"dep.jac": "def d -> int { return 1; }\n"}
        );
        plan = _plan_with_python_rows(dep_root);
        pip = MagicMock(return_value=(0, "", ""));
        with patch("jaclang.project.providers.ensure_venv") as _ev, patch.object(
            PythonProvider, "_run_project_pip", pip
        ) {
            commit_plan(config, plan);
        }
        install_calls = [
            list(call.args[1])
            for call in pip.call_args_list
            if len(call.args) > 1 and call.args[1] and call.args[1][0] == "install"
        ];
        assert install_calls == [["install", "--upgrade", "six==1.16.0"]] , (
            f"pip received {install_calls}; expected the exact resolved pin"
        );
        assert (config.project_root / "jac.lock").is_file();
        assert read_deps_map(config)["packages"][0]["name"] == "dep";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "commit plan aborts publication when backend sync fails" {
    import from jaclang.project.package_manager { commit_plan }
    import from jaclang.project.providers { PythonProvider }
    (config, tmp) = make_project(
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n[dependencies.jac]\n'
    );
    try {
        dep_root = Path(tmp) / "dep";
        make_plain_pkg(
            dep_root,
            '[project]\nname = "dep"\nversion = "1.0.0"\n',
            {"dep.jac": "def d -> int { return 1; }\n"}
        );
        plan = _plan_with_python_rows(dep_root);
        pip = MagicMock(return_value=(1, "", "boom"));
        raised = False;
        with patch("jaclang.project.providers.ensure_venv") as _ev, patch.object(
            PythonProvider, "_run_project_pip", pip
        ) {
            try {
                commit_plan(config, plan);
            } except JacDepError as e {
                raised = "python" in str(e);
            }
        }
        assert raised , "failed backend sync must abort the transaction";
        assert not (config.project_root / "jac.lock").exists();
        assert read_deps_map(config) == {};
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "commit plan stays offline when no backend plan is staged" {
    import from jaclang.project.dependency_model { DependencyNode, ResolutionPlan }
    import from jaclang.project.package_manager { commit_plan }
    import from jaclang.project.providers { PythonProvider }
    (config, tmp) = make_project(
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n[dependencies.jac]\n'
    );
    try {
        dep_root = Path(tmp) / "dep";
        make_plain_pkg(
            dep_root,
            '[project]\nname = "dep"\nversion = "1.0.0"\n',
            {"dep.jac": "def d -> int { return 1; }\n"}
        );
        plan = ResolutionPlan(
            nodes={
                "jac:dep": DependencyNode(
                    id="jac:dep",
                    ecosystem="jac",
                    alias="dep",
                    project_name="dep",
                    source="path",
                    source_location=str(dep_root),
                    import_root="dep"
                )
            },
            lock_data={"version": 2, "nodes": {}, "edges": []},
            staged_materializations={
                "jac:dep": {"source": str(dep_root), "tree": "t", "alias": "dep"}
            },
            provider_resolutions={}
        );
        pip = MagicMock(return_value=(0, "", ""));
        with patch("jaclang.project.providers.ensure_venv") as _ev, patch.object(
            PythonProvider, "_run_project_pip", pip
        ) {
            commit_plan(config, plan);
        }
        assert pip.call_args_list == [] , "no staged backend plan must not touch pip";
        assert (config.project_root / "jac.lock").is_file();
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== provider lock-graph resolution =====

glob _PIP_REPORT: dict[str, any] = {
         "install": [
             {
                 "is_direct": True,
                 "metadata": {
                     "name": "requests",
                     "version": "2.31.0",
                     "requires_dist": ["urllib3<3,>=1.21.1"]
                 },
                 "download_info": {
                     "url": "https://files.pythonhosted.org/requests-2.31.0.whl",
                     "archive_info": {
                         "hashes": {"sha256": "f0f0"},
                         "hash": "sha256:f0f0"
                     }
                 }
             },
             {
                 "is_direct": False,
                 "metadata": {
                     "name": "urllib3",
                     "version": "2.2.0",
                     "requires_dist": []
                 },
                 "download_info": {
                     "url": "https://files.pythonhosted.org/urllib3-2.2.0.whl"
                 }
             }
         ]
     };


def _write_pip_report(args: list[str], **kwargs: any) -> any {
    # Stand-in for `pip install --dry-run --report <path>`: writes the
    # pinned report and returns a successful CompletedProcess-like value.
    import json;
    import from types { SimpleNamespace }
    report_path = str(args[list(args).index("--report") + 1]);
    Path(report_path).write_text(json.dumps(_PIP_REPORT), encoding="utf-8");
    return SimpleNamespace(returncode=0, stderr="", stdout="");
}


test "python provider records transitive edges from requires_dist" {
    import from unittest.mock { patch }
    import from jaclang.project.dependency_model {
        LockGraph,
        ProviderRequirement,
        ResolutionContext
    }
    import from jaclang.project.providers { PythonProvider }
    project_root = tempfile.mkdtemp(prefix="jac_py_transitive_");
    requirements = [
        ProviderRequirement(
            consumer_id="root",
            ecosystem="python",
            name="requests",
            constraint=">=2.0",
            location=project_root
        )
    ];
    try {
        with patch("subprocess.run", _write_pip_report) {
            resolution = PythonProvider().resolve_requirements(
                ResolutionContext(), requirements, LockGraph()
            );
        }
        assert "python:requests" in resolution.nodes;
        assert resolution.nodes["python:urllib3"].version == "2.2.0";
        edges = {(edge.from_id, edge.to_id, edge.kind) for edge in resolution.edges};
        assert ("root", "python:requests", "requirement") in edges , (
            f"missing direct requirement edge, got {edges}"
        );
        assert ("python:requests", "python:urllib3", "dependency") in edges , (
            f"transitive python edge never added to the graph, got {edges}"
        );
        plan_ids = {row["id"] for row in resolution.install_plan};
        assert plan_ids == {"python:requests", "python:urllib3"};
        assert resolution.nodes["python:requests"].source == "artifact";
    } finally {
        shutil.rmtree(project_root, ignore_errors=True);
    }
}


test "npm provider resolves lockfile nodes and transitive edges" {
    import json;
    import from jaclang.client.npm_provider { NpmProvider }
    import from jaclang.project.dependency_model {
        LockGraph,
        ProviderRequirement,
        ResolutionContext
    }
    tmp = tempfile.mkdtemp(prefix="jac_npm_resolve_");
    try {
        (Path(tmp) / "package-lock.json").write_text(
            json.dumps(
                {
                    "packages": {
                        "": {"name": "proj"},
                        "node_modules/react": {
                            "version": "19.2.0",
                            "resolved": (
                                "https://registry.npmjs.org/react/-/" "react-19.2.0.tgz"
                            ),
                            "integrity": "sha512-abc",
                            "dependencies": {"scheduler": "^0.26.0"}
                        },
                        "node_modules/react/node_modules/scheduler": {
                            "version": "0.26.0"
                        },
                        "node_modules/vite": {
                            "version": "6.4.1",
                            "dev": True,
                            "dependencies": {"esbuild": "^0.21.0"}
                        },
                        "node_modules/esbuild": {"version": "0.21.0"}
                    }
                }
            ),
            encoding="utf-8"
        );
        requirements = [
            ProviderRequirement(
                consumer_id="root",
                ecosystem="npm",
                name="react",
                constraint="^19.2.0",
                location=str(tmp)
            ),
            ProviderRequirement(
                consumer_id="root",
                ecosystem="npm",
                name="vite",
                constraint="^6.4.1",
                location=str(tmp)
            )
        ];
        resolution = NpmProvider().resolve_requirements(
            ResolutionContext(), requirements, LockGraph()
        );
        # A nested node_modules path must resolve to the leaf package name
        # (regression: package_name was read before it was assigned).
        scheduler = resolution.nodes.get("npm:scheduler");
        assert scheduler is not None , "nested lockfile entry produced no node";
        assert scheduler.project_name == "scheduler";
        assert scheduler.version == "0.26.0";
        assert resolution.nodes["npm:vite"].dev is True;
        edges = {
            (edge.from_id, edge.to_id, edge.kind, edge.requirement)
            for edge in resolution.edges
        };
        assert ("root", "npm:react", "requirement", "^19.2.0") in edges;
        assert ("root", "npm:vite", "requirement", "^6.4.1") in edges;
        assert ("npm:react", "npm:scheduler", "dependency", "^0.26.0") in edges , (
            f"forward-referenced child edge missing, got {edges}"
        );
        assert ("npm:vite", "npm:esbuild", "dependency", "^0.21.0") in edges;
        assert len(resolution.install_plan) == 4;
        react_row = [
            row
            for row in resolution.install_plan
            if row["name"] == "react"
        ][0];
        assert react_row["resolved"].endswith("react-19.2.0.tgz");
        assert react_row["integrity"] == "sha512-abc";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


# ===== unified plan/commit pipeline (mixed manifests) =====
test "mixed manifest installs through one transaction" {
    (store_tmp, old_env) = isolate_store();
    try {
        import json;
        (config, tmp) = make_project(
            '[project]\nname = "mx"\nversion = "0.1.0"\n\n'
            '[dependencies]\npackaging = "*"\n\n'
            '[dependencies.jac]\nlib = { path = "../lib" }\n'
        );
        try {
            make_plain_pkg(
                Path(tmp) / "lib",
                '[project]\nname = "lib"\nversion = "1.0.0"\n',
                {"lib.jac": "def l() -> int { return 1; }\n"}
            );
            jac_sync(config);
            build = config.get_build_dir();
            packages_dir = build / "packages";
            assert packages_dir.is_symlink() , (
                "build/packages is not a generation symlink"
            );
            deps_doc = json.loads((build / "deps.json").read_text(encoding="utf-8"));
            assert deps_doc.get("version") == 2 , (
                f"deps.json is not v2: {deps_doc.get('version')}"
            );
            assert deps_doc.get("generation");
            lock_data = read_lock(config.project_root or Path.cwd());
            assert "jac:lib" in lock_data.get("nodes", {});
            assert "python:packaging" in lock_data.get("nodes", {});
            import from jaclang.project.pyvenv { get_venv_site_packages }
            site = Path(get_venv_site_packages(config.get_venv_dir()));
            assert site.is_dir();
            assert any(p.name.startswith("packaging") for p in site.iterdir()) , "packaging missing from the project venv";
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "frozen install pins python deps from the lock" {
    (store_tmp, old_env) = isolate_store();
    try {
        (config, tmp) = make_project(
            '[project]\nname = "mx"\nversion = "0.1.0"\n\n'
            '[dependencies]\npackaging = "*"\n'
        );
        try {
            project_dir = Path(tmp) / "proj";
            jac_sync(config);
            lock_data = read_lock(project_dir);
            locked_version = str(
                lock_data.get("nodes", {}).get("python:packaging", {}).get(
                    "version", ""
                )
            );
            assert locked_version , "lock recorded no python:packaging version";

            # Wipe the venv: a frozen replay must re-pin from the lock.
            shutil.rmtree(config.get_venv_dir(), ignore_errors=True);
            jac_sync(config, frozen=True);
            import from jaclang.project.pyvenv { get_venv_site_packages }
            site = Path(get_venv_site_packages(config.get_venv_dir()));
            dists = [
                p.name
                for p in site.iterdir()
                if p.name.startswith("packaging-") and p.name.endswith(".dist-info")
            ];
            assert dists , "packaging missing after frozen replay";
            assert locked_version in dists[0] , (
                f"frozen replay installed {dists[0]}, lock pinned " f"{locked_version}"
            );
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "mixed update re-resolves python alongside the jac closure" {
    (store_tmp, old_env) = isolate_store();
    try {
        import from jaclang.project.dependency_model { PackageOperation }
        import from jaclang.project.package_manager { plan_operation }
        (config, tmp) = make_project(
            '[project]\nname = "mx"\nversion = "0.1.0"\n\n'
            '[dependencies]\npackaging = "*"\n\n'
            '[dependencies.jac]\nlib = { path = "../lib" }\n'
        );
        try {
            make_plain_pkg(
                Path(tmp) / "lib",
                '[project]\nname = "lib"\nversion = "1.0.0"\n',
                {"lib.jac": "def l() -> int { return 1; }\n"}
            );
            jac_sync(config);
            plan = plan_operation(
                config,
                PackageOperation(action="update", ecosystem="jac", targets=["lib"])
            );
            assert "jac:lib" in plan.nodes , "update plan dropped the jac node";
            assert "python:packaging" in plan.nodes , (
                "update plan dropped the python node"
            );
            assert "python" in plan.provider_resolutions , (
                "update plan skipped python re-resolution"
            );
            assert plan.provider_resolutions["python"].install_plan , (
                "update plan carries no python install rows"
            );
        } finally {
            shutil.rmtree(tmp, ignore_errors=True);
        }
    } finally {
        restore_store(store_tmp, old_env);
    }
}


test "version conflict raises JacDepError with requirer context" {
    (config, tmp) = make_project(
        '[project]\nname = "proj"\nversion = "0.1.0"\n\n'
        '[dependencies.jac]\nb = { path = "../b", version = "^2.0" }\n'
    );
    try {
        make_plain_pkg(
            Path(tmp) / "b",
            '[project]\nname = "b"\nversion = "1.0.0"\n',
            {"b.jac": "def b() -> int { return 1; }\n"}
        );
        try {
            jac_sync(config);
            assert False , "manifest/lock version conflict was accepted";
        } except JacDepError as e {
            assert "Version conflict for 'b'" in str(e) , (
                f"wrong conflict message: {e}"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
