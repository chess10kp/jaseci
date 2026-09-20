import from jaclang.cli.console { console }


impl precommit(
    paths: (list[str] | None) = None,
    staged: bool = False,
    verify: bool = False,
    install: bool = False,
    force: bool = False,
    cache_stats: dict[str, int] | None = None
) -> int {
    import os;
    import shutil;
    import subprocess;
    import tempfile;
    import from jaclang.project.config { get_config }
    if install {
        return _install_precommit_hook(force);
    }
    targets: list[str] = [];
    rel_targets: list[str] = [];
    git_root = "";
    if staged {
        try {
            git_root = subprocess.run(
                ["git", "rev-parse", "--show-toplevel"],
                capture_output=True,
                text=True,
                check=True
            ).stdout.strip();
            completed = subprocess.run(
                ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM"],
                capture_output=True,
                text=True,
                check=True
            );
        } except Exception as e {
            console.error(f"Could not read staged files from git: {e}");
            return 1;
        }
        for line in completed.stdout.splitlines() {
            candidate = line.strip();
            if not candidate.endswith(".jac") {
                continue;
            }
            abs_candidate = os.path.join(git_root, candidate);
            if os.path.exists(abs_candidate) {
                rel_targets.append(candidate);
                targets.append(abs_candidate);
            }
        }
        if not targets {
            console.success("No staged '.jac' files to check.");
            return 0;
        }
    } elif paths {
        targets = list(paths);
    } else {
        config = get_config();
        if config is not None and config.project_root {
            targets = [str(config.project_root)];
        } else {
            targets = ["."];
        }
    }

    fmt_targets = targets;
    tmp_root: (str | None) = None;
    path_map: dict[str, str] = {};
    if staged and verify {
        dirty = _staged_dirty_files(git_root, rel_targets);
        if dirty {
            tmp_root = tempfile.mkdtemp(prefix="jac-precommit-");
            try {
                checkout_paths = list(rel_targets);
                try {
                    import from jaclang.compiler.driver.bccache { discover_annex_files }
                    rel_set = {r for r in rel_targets};
                    annex_rel: list[str] = [];
                    for rel in rel_targets {
                        abs_t = os.path.join(git_root, rel);
                        if not os.path.exists(abs_t) {
                            continue;
                        }
                        for ap in (
                            discover_annex_files(abs_t, '.impl.jac')
                            + discover_annex_files(abs_t, '.test.jac')
                        ) {
                            ap_rel = os.path.relpath(ap, git_root).replace(os.sep, "/");
                            if ap_rel not in rel_set {
                                annex_rel.append(ap_rel);
                            }
                        }
                    }
                    if annex_rel {
                        ls_out = subprocess.run(
                            ["git", "ls-files", "--"] + annex_rel,
                            capture_output=True,
                            text=True,
                            cwd=git_root,
                            check=True
                        ).stdout;
                        for line in ls_out.splitlines() {
                            tracked = line.strip();
                            if tracked and tracked not in rel_set {
                                rel_set.add(tracked);
                                checkout_paths.append(tracked);
                            }
                        }
                    }
                } except Exception {}
                subprocess.run(
                    [
                        "git",
                        "checkout-index",
                        "-f",
                        f"--prefix={tmp_root}{os.sep}",
                        "--"
                    ]
                        + checkout_paths,
                    check=True,
                    cwd=git_root
                );
                fmt_targets = [os.path.join(tmp_root, rel) for rel in rel_targets];

                path_map = {
                    os.path.join(tmp_root, rel): os.path.join(git_root, rel)
                    for rel in rel_targets
                };
                console.print("[precommit] Verifying staged content (index checkout).");
            } except Exception as e {
                shutil.rmtree(tmp_root, ignore_errors=True);
                tmp_root = None;
                fmt_targets = targets;
                path_map = {};
                console.warning(
                    f"[precommit] Could not check out the staged blobs ({e}); "
                    "verifying the WORKTREE copies instead -- staged content "
                    "that differs from the worktree was NOT verified."
                );
            }
        }
    }
    console.print("precommit: formatting (--lintfix)", style="muted");

    stats: dict[str, int] = cache_stats if cache_stats is not None else {};
    fmt_ret = format(
        fmt_targets,
        to_screen=False,
        lintfix=True,
        check=verify,
        cache=True,
        cache_anchor=git_root,
        path_map=path_map,
        cache_stats=stats
    );
    if tmp_root {
        shutil.rmtree(tmp_root, ignore_errors=True);
    }
    console.print("[precommit] Running check...");
    check_ret = check(targets);

    fixes_applied = (
        int(stats.get("changed", 0)) > 0
        or (staged and _staged_dirty_files(git_root, rel_targets))
        or fmt_ret != 0
    );
    if not verify and check_ret == 0 and fixes_applied {
        console.warning(
            "Pre-commit applied formatting/lint fixes — review the changes, "
            "re-stage them, and commit again."
        );
        return 1;
    }
    if fmt_ret != 0 or check_ret != 0 {
        console.error("Pre-commit checks failed.");
        if verify and fmt_ret != 0 {
            console.error(
                "Run 'jac precommit' (without --verify) to apply formatting "
                "fixes, then re-stage."
            );
        }
        return 1;
    }
    console.success("Pre-commit checks passed.");
    return 0;
}

def _staged_dirty_files(git_root: str, rel_targets: list[str]) -> list[str] {
    import subprocess;
    if not git_root or not rel_targets {
        return [];
    }
    try {
        out = subprocess.run(
            ["git", "diff", "--name-only", "--"] + rel_targets,
            capture_output=True,
            text=True,
            check=True,
            cwd=git_root
        ).stdout;
    } except Exception {
        return [];
    }
    return [
        line.strip()
        for line in out.splitlines()
        if line.strip()
    ];
}

def _install_precommit_hook(force: bool = False) -> int {
    import os;
    import subprocess;
    try {
        completed = subprocess.run(
            ["git", "rev-parse", "--git-dir"],
            capture_output=True,
            text=True,
            check=True
        );
    } except Exception as e {
        console.error(f"Not a git repository (or git unavailable): {e}");
        return 1;
    }
    git_dir = completed.stdout.strip();
    hooks_dir = os.path.join(git_dir, "hooks");
    os.makedirs(hooks_dir, exist_ok=True);
    precommit_body = (
        "#!/bin/sh\n"
        "# Installed by `jac precommit --install`\n"
        "exec jac precommit --staged --verify\n"
    );
    commit_msg_body = (
        "#!/bin/sh\n"
        "# Installed by `jac precommit --install`\n"
        "if grep -iEq 'co-authored-by:.*\\b(claude|anthropic|openai|copilot"
        "|composer|cursor|gpt|gemini|ai|bot)\\b' \"$1\"; then\n"
        "  echo 'commit-msg: AI co-author attribution is not allowed.' >&2\n"
        "  exit 1\n"
        "fi\n"
    );
    for pair in [("pre-commit", precommit_body), ("commit-msg", commit_msg_body)] {
        ret = _write_git_hook(os.path.join(hooks_dir, pair[0]), pair[1], force);
        if ret != 0 {
            return ret;
        }
    }
    console.success(f"Installed git hooks in '{hooks_dir}': pre-commit, commit-msg.");
    console.print("pre-commit runs: jac precommit --staged --verify");
    console.print("commit-msg blocks AI co-author attribution lines.");
    return 0;
}

def _write_git_hook(hook_path: str, body: str, force: bool) -> int {
    import os;
    import stat;
    if os.path.exists(hook_path) {
        try {
            with open(hook_path, encoding="utf-8", errors="replace") as f {
                existing = f.read();
            }
        } except Exception {
            existing = "";
        }
        is_ours = "Installed by `jac precommit --install`" in existing;
        is_framework = "generated by pre-commit" in existing;
        if not (is_ours or is_framework or force) {
            console.warning(f"A hook already exists at '{hook_path}'.");
            console.warning(
                "Re-run 'jac precommit --install --force' to replace it "
                "(the old hook is kept as a .bak backup)."
            );
            return 1;
        }
        if not is_ours {
            backup_path = hook_path + ".bak";
            try {
                os.replace(hook_path, backup_path);
            } except Exception as e {
                console.error(f"Could not back up the existing hook: {e}");
                return 1;
            }
            kind = "pre-commit framework hook" if is_framework else "existing hook";
            console.print(f"Replaced {kind} (backup at '{backup_path}').");
        }
    }
    try {
        with open(hook_path, "w", encoding="utf-8") as f {
            f.write(body);
        }
        mode = os.stat(hook_path).st_mode;
        os.chmod(hook_path, mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH);
    } except Exception as e {
        console.error(f"Failed to write hook: {e}");
        return 1;
    }
    return 0;
}
