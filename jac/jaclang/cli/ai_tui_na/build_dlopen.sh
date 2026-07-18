#!/usr/bin/env bash
# Build the in-process TUI shared library (host_dlopen.na.jac -> bin/libtui.so).
#
# Unlike build_embed.sh, this emits a ctypes-loadable renderer only — no jacpyembed,
# no fused-runtime trailer. Used by JAC_AI_TUI_BACKEND=inprocess (see
# plans/experiments/in-process-flip.md).
#
# Run from any directory; paths resolve relative to this script.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_JAC="$REPO_ROOT/jac/zig-out/bin/jac"
REPO_VENV="$REPO_ROOT/.venv"

# ── resolve the jac toolchain for nacompile (same order as build_embed.sh) ────
if [ -n "${JAC_BIN:-}" ]; then
    JAC=("$JAC_BIN")
    echo "==> Using \$JAC_BIN: $JAC_BIN"
elif [ -n "${JAC_PY:-}" ]; then
    JAC=("$JAC_PY" -m jaclang)
    echo "==> Using \$JAC_PY: $JAC_PY -m jaclang"
elif [ -x "$REPO_JAC" ]; then
    JAC=("$REPO_JAC")
    echo "==> Using repo-built jac binary: $REPO_JAC"
elif [ -x "$REPO_VENV/bin/python" ]; then
    JAC=("$REPO_VENV/bin/python" -m jaclang)
    echo "==> Using repo editable jaclang: $REPO_VENV/bin/python -m jaclang"
else
    echo "==> No jac build toolchain found (set JAC_BIN, build zig-out, or .venv)." >&2
    exit 1
fi

# ── select the TTY backend (same matrix as build_embed.sh) ────────────────────
HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    *)
        case "$HOST" in
            Linux*)       TTY=linux  ;;
            Darwin*)      TTY=darwin ;;
            *) echo "==> Unsupported host '$HOST'; set JAC_AI_TUI_TARGET" >&2; exit 1 ;;
        esac
        ;;
esac
case "$TTY" in
    linux)  PLAT=tty/tty_plat.linux.na.jac;  LIBNAME=libtui.so    ;;
    darwin) PLAT=tty/tty_plat.darwin.na.jac; LIBNAME=libtui.dylib ;;
esac

XFLAGS=""
case "$TTY" in
    darwin) [[ "$HOST" != Darwin* ]] && XFLAGS="--target darwin" ;;
esac

echo "==> TTY backend: $TTY   shared lib: $LIBNAME"

# ── stage the split TTY backend into the compile dir ──────────────────────────
cp "$PLAT" tty_plat.na.jac
cp tty/libc_tty_base.na.jac libc_tty.na.jac

# Stage Phase 5 nested tui/ + components/ modules flat for nacompile.
# shellcheck source=_stage_modules.sh
source "$SCRIPT_DIR/_stage_modules.sh"
stage_tui_modules

mkdir -p bin

OUT="bin/$LIBNAME"
TMP="bin/.$LIBNAME.partial.$$"
trap "rm -f tty_plat.na.jac libc_tty.na.jac '$SCRIPT_DIR/$TMP'; cleanup_staged_modules" EXIT

echo "==> Compiling $LIBNAME (dlopen host) ..."
"${JAC[@]}" nacompile host_dlopen.na.jac --shared ${XFLAGS:+$XFLAGS} -o "$TMP"
echo "==> Compiled: $SCRIPT_DIR/$TMP"

mv -f "$TMP" "$OUT"

# Record input freshness so the Python host can reject stale artifacts.
python3 - "$SCRIPT_DIR" "$SCRIPT_DIR/bin" <<'PYEOF'
import glob, os, sys
na_dir, bindir = sys.argv[1], sys.argv[2]
newest = 0.0
for path in glob.glob(os.path.join(na_dir, "**", "*.na.jac"), recursive=True):
    try:
        newest = max(newest, os.path.getmtime(path))
    except OSError:
        pass
for name in ("build_dlopen.sh", "_stage_modules.sh"):
    p = os.path.join(na_dir, name)
    try:
        newest = max(newest, os.path.getmtime(p))
    except OSError:
        pass
with open(os.path.join(bindir, ".dlopen_build_stamp"), "w", encoding="utf-8") as f:
    f.write(f"{newest}\n")
PYEOF

echo "==> Done. In-process TUI library: $SCRIPT_DIR/$OUT"
