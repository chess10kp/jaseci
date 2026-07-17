#!/usr/bin/env bash
# build_dispatch_selftest.sh — build the native dispatch harness binary.
#
# Compiles selftest_dispatch.na.jac -> bin/selftest_dispatch: exercises
# handle_key / reduce_input routing without booting embedded CPython.
# Used by jac/tests/cli/test_ai_tui_dispatch.jac.
#
# Mirrors build_selftest.sh staging (TTY backend + libjacpyembed shim +
# flat tui/components copies).
#
# Usage: bash build_dispatch_selftest.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REPO_JAC="$REPO_ROOT/jac/zig-out/bin/jac"
REPO_VENV="$REPO_ROOT/.venv"

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

HOST="$(uname -s 2>/dev/null || echo "unknown")"
case "${JAC_AI_TUI_TARGET:-}" in
    linux)  TTY=linux  ;;
    darwin) TTY=darwin ;;
    *)
        case "$HOST" in
            Linux*)  TTY=linux  ;;
            Darwin*) TTY=darwin ;;
            *) echo "==> Unsupported host '$HOST'; set JAC_AI_TUI_TARGET" >&2; exit 1 ;;
        esac
        ;;
esac
case "$TTY" in
    linux)  PLAT=tty/tty_plat.linux.na.jac;  SHIM=libjacpyembed.so    ;;
    darwin) PLAT=tty/tty_plat.darwin.na.jac; SHIM=libjacpyembed.dylib ;;
esac

XFLAGS=""
case "$TTY" in
    darwin) [[ "$HOST" != Darwin* ]] && XFLAGS="--target darwin" ;;
esac

echo "==> TTY backend: $TTY   shim: $SHIM"

SHIM_SRC="${JAC_PYEMBED_SHIM:-$REPO_ROOT/jac/jaclang/runtimelib/client/targets/desktop/native/$SHIM}"
if [ ! -f "$SHIM_SRC" ]; then
    echo "==> libjacpyembed shim not found at $SHIM_SRC" >&2
    exit 1
fi

cp "$PLAT" tty_plat.na.jac
cp tty/libc_tty_base.na.jac libc_tty.na.jac
cp "$SHIM_SRC" "$SHIM"

source "$SCRIPT_DIR/_stage_modules.sh"
stage_tui_modules

mkdir -p bin
OUT="bin/selftest_dispatch"
TMP="bin/.selftest_dispatch.partial.$$"
trap "rm -f tty_plat.na.jac libc_tty.na.jac '$SCRIPT_DIR/$SHIM' '$SCRIPT_DIR/$TMP'; cleanup_staged_modules" EXIT

echo "==> Compiling selftest_dispatch (dispatch harness) ..."
"${JAC[@]}" nacompile selftest_dispatch.na.jac ${XFLAGS:+$XFLAGS} -o "$TMP"
echo "==> Compiled: $SCRIPT_DIR/$TMP"

cp "$SHIM_SRC" "bin/$SHIM"
mv -f "$TMP" "$OUT"
echo "==> Done. Dispatch harness: $SCRIPT_DIR/$OUT (+ bin/$SHIM)"
echo "    Verify: pytest jac/tests/cli/test_ai_tui_dispatch.jac"
