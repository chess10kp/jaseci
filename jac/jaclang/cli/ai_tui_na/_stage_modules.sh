# Shared staging for nested tui/ and components/ sources into the flat compile cwd.
# Sourced by build_embed.sh and build_selftest.sh. Sets STAGED_MODULE_FILES for trap cleanup.
#
# nacompile resolves `import from .tui` against the tui/ package directory when it
# exists alongside a staged flat tui.na.jac, producing duplicate-type failures. After
# copying nested sources flat, hide the source trees for the compile window.

STAGED_MODULE_FILES=()
_HIDDEN_TUI_DIR=""
_HIDDEN_COMPONENTS_DIR=""

_stage_dir() {
    local src_dir="$1"
    if [ ! -d "$src_dir" ]; then
        return 0
    fi
    local f base dest
    for f in "$src_dir"/*.na.jac; do
        [ -e "$f" ] || continue
        base="$(basename "$f")"
        dest="$SCRIPT_DIR/$base"
        if [ -e "$dest" ] && [ ! -L "$dest" ]; then
            case "$base" in
                screen.na.jac|state.na.jac|runtime.na.jac|host_embed.na.jac|host_dlopen.na.jac|selftest_render.na.jac|input.na.jac|overlay.na.jac|commands.na.jac|theme.na.jac|terminal.na.jac|diff.na.jac|width.na.jac|editor.na.jac|feed.na.jac|keys.na.jac|select_list.na.jac|autocomplete.na.jac|transport.na.jac|ipc_schema.na.jac|util.na.jac|markdown.na.jac|tool_block.na.jac|terminal_image.na.jac|tui_core.na.jac|reducer.na.jac|interactive_app.na.jac|session_dispatch.na.jac|embed_*.na.jac|bridge_schema.na.jac|session_apply.na.jac)
                    if [ "$(realpath "$f")" != "$(realpath "$dest")" ]; then
                        echo "==> staging conflict: $f -> $base already exists as a real file" >&2
                        exit 1
                    fi
                    ;;
            esac
        fi
        cp "$f" "$dest"
        STAGED_MODULE_FILES+=("$dest")
    done
}

_hide_nested_src_trees() {
    if [ -d "$SCRIPT_DIR/tui" ]; then
        _HIDDEN_TUI_DIR="$SCRIPT_DIR/.compile_hide_tui"
        mv "$SCRIPT_DIR/tui" "$_HIDDEN_TUI_DIR"
    fi
    if [ -d "$SCRIPT_DIR/components" ]; then
        _HIDDEN_COMPONENTS_DIR="$SCRIPT_DIR/.compile_hide_components"
        mv "$SCRIPT_DIR/components" "$_HIDDEN_COMPONENTS_DIR"
    fi
}

_restore_nested_src_trees() {
    if [ -n "$_HIDDEN_TUI_DIR" ] && [ -d "$_HIDDEN_TUI_DIR" ]; then
        mv "$_HIDDEN_TUI_DIR" "$SCRIPT_DIR/tui"
        _HIDDEN_TUI_DIR=""
    fi
    if [ -n "$_HIDDEN_COMPONENTS_DIR" ] && [ -d "$_HIDDEN_COMPONENTS_DIR" ]; then
        mv "$_HIDDEN_COMPONENTS_DIR" "$SCRIPT_DIR/components"
        _HIDDEN_COMPONENTS_DIR=""
    fi
}

stage_tui_modules() {
    STAGED_MODULE_FILES=()
    _HIDDEN_TUI_DIR=""
    _HIDDEN_COMPONENTS_DIR=""
    _stage_dir "$SCRIPT_DIR/tui"
    _stage_dir "$SCRIPT_DIR/components"
    _hide_nested_src_trees
}

cleanup_staged_modules() {
    local f
    _restore_nested_src_trees
    for f in "${STAGED_MODULE_FILES[@]:-}"; do
        rm -f "$f"
    done
    STAGED_MODULE_FILES=()
}
