import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.project.tool_paths { jac_global_prefix }
import from jaclang.cli.console { console }

glob TREE_HASH_PREFIX: str = "sha256-",
     STORE_DIR_NAME: str = "store",
     TMP_DIR_NAME: str = "_tmp",
     ORIGIN_MARKER: str = ".jac-origin",
     HASH_EXCLUDE: set[str] = {
         ".git",
         ".jac",
         "node_modules",
         "__pycache__",
         ORIGIN_MARKER
     };


obj JacDepError(Exception) {
    has message: str = "";

    def postinit -> None;
}

impl JacDepError.postinit -> None {
    Exception.__init__(self, self.message);
}


obj FetchResult {
    has path: str = "",
        sha: str = "",
        tree: str = "";
}


def store_root -> Path {
    return jac_global_prefix() / STORE_DIR_NAME;
}


def normalize_git_url(spec: str) -> str {
    spec = spec.strip().rstrip("/");
    known = spec.startswith(
        ("https://", "http://", "ssh://", "file://", "/", "./", "../", "~/")
    );
    if not known and spec.startswith("git@") and ":" in spec {
        spec = "ssh://" + spec.replace(":", "/", 1);
    } elif not known and "://" in spec {
        raise JacDepError(f"Unsupported git URL scheme: {spec}");
    } elif not known {
        spec = "https://" + spec;
    }

    if spec.endswith(".git")
        and not spec.startswith(("file://", "/", "./", "../", "~/")) {
        spec = spec[:-4];
    }
    return spec;
}


def git_package_name(spec: str) -> str {
    base = normalize_git_url(spec).rstrip("/");
    name = base.rsplit("/", 1)[-1];
    if name.endswith(".git") {
        name = name[:-4];
    }
    return name;
}


def _run_git(args: list[str], cwd: str | None = None) -> str {
    result = subprocess.run(["git"] + args, cwd=cwd, capture_output=True, text=True);
    if result.returncode != 0 {
        detail = (result.stderr or result.stdout or "").strip();
        raise JacDepError(f"git {' '.join(args)} failed:\n  {detail}");
    }
    return result.stdout.strip();
}


def _assert_no_symlinks(tree_dir: Path) {
    for (dir_root, dirs, files) in os.walk(tree_dir, followlinks=False) {
        tree_root = Path(str(dir_root));
        for name in list(dirs) + list(files) {
            candidate = tree_root / str(name);
            if os.path.islink(str(candidate)) {
                raise JacDepError(
                    f"Dependency tree contains a symlink: "
                    f"{candidate.relative_to(tree_dir)}"
                );
            }
            os.lstat(str(candidate));
        }
    }
}


def dirhash(tree_dir: Path) -> str {
    import hashlib;
    if not tree_dir.is_dir() or tree_dir.is_symlink() {
        raise JacDepError(f"Dependency tree is not a real directory: {tree_dir}");
    }
    _assert_no_symlinks(tree_dir);
    entries: list[str] = [];
    prefix_len = len(str(tree_dir)) + 1;
    for (dir_root, dirs, files) in os.walk(tree_dir, followlinks=False) {
        dirs[:] = sorted(
            d
            for d in dirs
            if d not in HASH_EXCLUDE
        );
        tree_root = Path(str(dir_root));
        for dirname in dirs {
            dpath = tree_root / str(dirname);
            rel = str(dpath)[prefix_len:].replace(os.sep, "/");
            entries.append(f"D\\n{rel}\\n");
        }
        for fname in sorted(files) {
            if fname in HASH_EXCLUDE {
                continue;
            }
            fpath = tree_root / str(fname);
            rel = str(fpath)[prefix_len:].replace(os.sep, "/");
            digest = hashlib.sha256(fpath.read_bytes()).hexdigest();
            entries.append(f"F\\n{rel}\\n{digest}\\n");
        }
    }
    joined = "".join(entries).encode("utf-8");
    return TREE_HASH_PREFIX + hashlib.sha256(joined).hexdigest();
}


def _clone_to(dest: Path, url: str) {
    if dest.exists() {
        shutil.rmtree(dest, ignore_errors=True);
    }
    dest.parent.mkdir(parents=True, exist_ok=True);
    try {
        _run_git(["clone", "--quiet", "--filter=blob:none", url, str(dest)]);
    } except JacDepError {
        raise JacDepError(
            f"Could not clone {url}. Check the URL and your credentials."
        ) from None;
    }
}


def checkout_tree(url: str, ref: str, sha: str | None, dest: Path) -> str {
    tmp = Path(tempfile.mkdtemp(prefix="jac_fetch_"));
    try {
        repo = tmp / "repo";
        _clone_to(repo, url);
        wanted = sha or ref or "HEAD";
        if sha and ref and ref != sha {
            resolved = _run_git(
                ["rev-parse", "--verify", ref + "^{commit}"], cwd=str(repo)
            );
            if resolved != sha {
                raise JacDepError(
                    f"Ref '{ref}' of {url} now points to {resolved}, "
                    f"but the recorded commit is {sha}"
                );
            }
        }
        try {
            _run_git(["checkout", "--quiet", "--detach", wanted], cwd=str(repo));
        } except JacDepError {
            raise JacDepError(f"Commit '{wanted}' not reachable in {url}") from None;
        }
        resolved = _run_git(["rev-parse", "HEAD"], cwd=str(repo));
        if sha and resolved != sha {
            raise JacDepError(f"Resolved {resolved} but expected {sha} for {url}");
        }
        if dest.exists() {
            shutil.rmtree(dest);
        }
        shutil.copytree(repo, dest, symlinks=True);
        _assert_no_symlinks(dest);
        shutil.rmtree(dest / ".git", ignore_errors=True);
        return resolved;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


def _read_origin_meta(marker: Path) -> dict[str, any] {
    import json;
    return json.loads(marker.read_text(encoding="utf-8"));
}


def _write_origin_meta(dest: Path, meta: dict[str, any]) {
    import json;
    marker = dest / ORIGIN_MARKER;

    if marker.is_symlink() or marker.exists() {
        marker.unlink();
    }
    marker.write_text(
        json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    );
}


def _ref_agreement(url: str, ref: str, sha: str) -> tuple[bool, bool] | None {
    try {
        out = _run_git(["ls-remote", url, ref]);
    } except JacDepError {
        return None;
    }
    canonical = {
        "refs/heads/" + ref,
        "refs/tags/" + ref,
        "refs/tags/" + ref + "^{}",
        ref
    };
    matched = False;
    is_tag = False;
    agrees = False;
    for line in out.splitlines() {
        parts = line.split(None, 1);
        if len(parts) != 2 {
            continue;
        }
        (oid, refname) = (parts[0], parts[1].strip());
        if refname not in canonical {
            continue;
        }
        matched = True;
        if refname.startswith("refs/tags/") {
            is_tag = True;
        }
        if oid == sha {
            agrees = True;
        }
    }
    if not matched {
        return None;
    }
    return (agrees, is_tag);
}

def _sidecar_path(store_dir: Path, tree: str) -> Path {
    return store_dir / f"{tree}.json";
}


def _read_sidecar(store_dir: Path, tree: str) -> dict[str, any] {
    import json;
    sidecar = _sidecar_path(store_dir, tree);
    try {
        data = json.loads(sidecar.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return {};
    }
    return data if isinstance(data, dict) else {};
}


def _write_sidecar(store_dir: Path, tree: str, meta: dict[str, any]) {
    import json;
    sidecar = _sidecar_path(store_dir, tree);
    tmp = sidecar.with_name(sidecar.name + f".{os.getpid()}.tmp");
    tmp.write_text(json.dumps(meta, indent=2, sort_keys=True) + "\n", encoding="utf-8");
    os.replace(str(tmp), str(sidecar));
}


def _store_hit_for(
    store_dir: Path, url: str, sha: str, expected_tree: str, verify: bool
) -> FetchResult | None {
    if not expected_tree {
        return None;
    }
    candidate = store_dir / expected_tree;
    if not candidate.is_dir() or candidate.is_symlink() {
        return None;
    }
    if not _tree_matches(candidate, expected_tree) {
        return None;
    }
    meta = _read_sidecar(store_dir, expected_tree);
    if not meta {
        try {
            meta = _read_origin_meta(candidate / ORIGIN_MARKER);
        } except (OSError, ValueError) {
            meta = {};
        }
    }
    if meta and (meta.get("sha") != sha or meta.get("url") != url) {
        return None;
    }
    return FetchResult(path=str(candidate), sha=sha, tree=expected_tree);
}


def _tree_matches(tree_dir: Path, expected: str) -> bool {
    try {
        return dirhash(tree_dir) == expected;
    } except (OSError, JacDepError) {
        return False;
    }
}


def _publish_tree(
    store_dir: Path, tree_dest: Path, tree_hash: str, meta: dict[str, any]
) -> Path {
    # Publish a staged tree into the content-addressed store. Lock-free by
    # design: publication is a single atomic rename, and a lost race with a
    # concurrent publisher of the same tree is resolved by re-checking the
    # published copy (content-identical by definition of the hash) instead
    # of holding a lock file a crash could leak. Keep this in sync with
    # _recover_generation in dep_roots.py, which replays the commit swap.
    final = store_dir / tree_hash;
    if _tree_matches(final, tree_hash) {
        shutil.rmtree(tree_dest, ignore_errors=True);
    } else {
        try {
            if final.exists() or final.is_symlink() {
                quarantine = store_dir
                    / (f".{tree_hash}.quarantine-{os.getpid()}-{id(final)}");
                os.rename(str(final), str(quarantine));
                if quarantine.is_dir() and not quarantine.is_symlink() {
                    shutil.rmtree(quarantine, ignore_errors=True);
                } else {
                    quarantine.unlink(missing_ok=True);
                }
            }
            os.rename(str(tree_dest), str(final));
        } except OSError {
            if not _tree_matches(final, tree_hash) {
                raise;
            }
            shutil.rmtree(tree_dest, ignore_errors=True);
        }
    }
    _write_sidecar(store_dir, tree_hash, meta);
    return final;
}


def fetch_package(
    url: str,
    ref: str = "",
    sha: str | None = None,
    expected_tree: str = "",
    verify: bool = True,
    frozen: bool = False
) -> FetchResult {
    url = normalize_git_url(url);
    store_dir = store_root();
    (store_dir / TMP_DIR_NAME).mkdir(parents=True, exist_ok=True);
    if sha and ref and ref != sha and not frozen {
        agreement = _ref_agreement(url, ref, sha);
        if agreement is not None {
            (agrees, is_tag) = agreement;
            if not agrees and is_tag {
                raise JacDepError(
                    f"Tag '{ref}' of {url} no longer resolves to recorded "
                    f"commit {sha}. The tag was moved; verify upstream and "
                    f"re-lock with 'jac update'."
                );
            }
            if not agrees {
                console.warning(
                    f"ref '{ref}' of {url} moved past recorded commit "
                    f"{sha[:12]}; replaying the recorded commit "
                    "(run 'jac update' to advance)"
                );
                ref = "";
            }
        }
    }
    if sha {
        hit = _store_hit_for(store_dir, url, sha, expected_tree, verify);
        if hit is not None {
            return hit;
        }
    }
    staging = Path(tempfile.mkdtemp(prefix="jac_stage_", dir=store_dir / TMP_DIR_NAME));
    try {
        tree_dest = staging / "tree";
        checkout_ref = "" if (frozen and sha) else ref;
        resolved_sha = checkout_tree(url, checkout_ref, sha, tree_dest);
        tree_hash = dirhash(tree_dest);
        final = _publish_tree(
            store_dir,
            tree_dest,
            tree_hash,
            {"url": url, "sha": resolved_sha, "tree": tree_hash}
        );
        return FetchResult(path=str(final), sha=resolved_sha, tree=tree_hash);
    } finally {
        shutil.rmtree(staging, ignore_errors=True);
    }
}


def _copy_tree(src: Path, dest: Path) {
    if src.is_symlink() {
        raise JacDepError(f"Dependency tree contains a symlink: {src}");
    }
    dest.mkdir(parents=True);
    for item in sorted(src.iterdir()) {
        target = dest / item.name;
        if item.is_symlink() {
            raise JacDepError(f"Dependency tree contains a symlink: {item}");
        } elif not item.is_dir() {
            shutil.copy2(item, target, follow_symlinks=False);
        } else {
            _copy_tree(item, target);
        }
    }
}


def materialize(src: Path, dest: Path) -> Path {
    _assert_no_symlinks(src);
    if dest.is_symlink() or (dest.exists() and not dest.is_dir()) {
        dest.unlink(missing_ok=True);
    } elif dest.exists() {
        shutil.rmtree(dest);
    }
    dest.parent.mkdir(parents=True, exist_ok=True);
    _copy_tree(src, dest);
    return dest;
}


def snapshot_path(source: Path) -> FetchResult {
    source = source.resolve();
    if not source.is_dir() {
        raise JacDepError(f"Path dependency is not a directory: {source}");
    }
    _assert_no_symlinks(source);
    store_dir = store_root();
    (store_dir / TMP_DIR_NAME).mkdir(parents=True, exist_ok=True);
    staging = Path(tempfile.mkdtemp(prefix="jac_path_", dir=store_dir / TMP_DIR_NAME));
    try {
        tree_dest = staging / "tree";
        _copy_tree(source, tree_dest);
        tree_hash = dirhash(tree_dest);
        final = _publish_tree(
            store_dir, tree_dest, tree_hash, {"path": str(source), "tree": tree_hash}
        );
        return FetchResult(path=str(final), sha="", tree=tree_hash);
    } finally {
        shutil.rmtree(staging, ignore_errors=True);
    }
}
