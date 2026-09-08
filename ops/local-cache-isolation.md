# Local cache isolation — standing rule for every session in this repo

Date: 2026-09-08. Cost when missed: ~6 hours of misdiagnosis (hangs blamed on
code, a Python-version theory, a wasted CI bisect) during the 185 landing +
upstream merge day.

## The hazard

`~/.cache/jac/` (JIR bootstrap `.jbc`, `rt/` runtime caches) is keyed by
module name and **shared machine-wide**. Any concurrent jac process from
another checkout — sibling worktrees (`jaseci-wt/pkgmgr-8813`), worker fleets,
the user's own sessions — rewrites those entries while our runs are reading
them. Result: bytecode assembled from mixed trees; processes spin at 98% CPU
or grow RSS unboundedly, reproducibly, at *every* commit including known-green
ones.

## Symptom signature (check this BEFORE debugging compiler code)

- A hang or spin that survives `git checkout` across commits, including
  commits where CI was green.
- Stall right after `Setting up Jac for first use (compiling and caching
  compiler)...`, often at `Compiling jaclang/cli/cli.jac...`.
- `jac` process with climbing utime or ballooning RSS; `ps -eo pid,ppid,cmd`
  shows **jac processes whose cwd is not your tree** — that's the smoking gun.
- A repo-internal `.xdg-cache/jac/rt/...` path appearing in unexpected output.

If you see these: do NOT bisect commits locally, do NOT derive a
host-Python-version theory. Isolate the cache and move on; let CI arbitrate
(sealed binary, fresh runner — the only clean environment when local state is
suspect).

## The rule

Every jac invocation in this repo runs with an isolated cache:

```bash
export XDG_CACHE_HOME="$REPO_ROOT/.xdg-cache"   # cache_paths honors XDG
```

- One warm-up costs minutes (the merged tree compiles ~73 full-compiler
  modules); every later lane run is seconds. Purge only
  `$REPO_ROOT/.xdg-cache` — never the shared `~/.cache/jac`.
- `.xdg-cache/` is gitignored. It contains 100 MB+ binaries (`bun`,
  `python3.14`, `libjacllvm.so`).

## The adjacent trap

A bare `git add -A` sweeps `.xdg-cache` (or any runtime dir) into the index;
GitHub's pre-receive hook rejects >100 MB files and the push bounces. Check
`git status --short` before staging, or stage explicit paths. (Happened at
fa0e4dbd5; fixed by `git rm -r --cached .xdg-cache` + amend.)
