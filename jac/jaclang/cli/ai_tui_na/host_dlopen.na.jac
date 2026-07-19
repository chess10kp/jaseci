"""In-process TUI renderer: C-ABI :pub surface for ctypes dlopen (no jacpyembed).

Built as a shared library:  jac nacompile host_dlopen.na.jac --shared -o bin/libtui.so
Loaded from the Python CLI via ctypes.CDLL; see jaclang/cli/ai_tui/tui_host.jac.

Module globals hold a TuiRuntime — Jac objects never cross the ABI. na -> Python is a
pull queue: tui_handle_key enqueues commands into cmd_queue; the host drains via
tui_next_command.

Threading contract the host MUST honor: tui_wait_key is the ONLY lock-free export
(pure poll, GIL released); all other exports read or mutate TuiState under the
host's render lock.
"""

# Import order matters: the native cross-module type resolver is DFS-order
# sensitive and resolves leaf types (e.g. select_list.SelectItem, reached via
# input -> overlay) to <Unknown> if first seen too deep -- E5090/E2018. This flat
# block mirrors the proven-good order primed by tui.na.jac / host.na.jac; the
# libc_tty / terminal / screen symbols beyond what the exports use are otherwise
# unused but REQUIRED to keep the --shared build green. Do not prune them.
# Upstream fix tracked in jaseci-labs/jac#6793.
import from .libc_tty {
    tty_open,
    tty_close,
    tty_fd,
    tty_configure_device,
    tty_update_size,
    tty_rows,
    tty_cols,
    tty_x_pixels,
    tty_y_pixels,
    tty_poll,
    tty_stdin_ready,
    tty_key_ready,
    tty_read_key,
    tty_write
}
import from .terminal {
    term_enter_alt_screen,
    term_leave_alt_screen,
    term_hide_cursor,
    term_show_cursor,
    term_enable_mouse,
    term_disable_mouse
}
import from .state { TuiState, TuiStatus }
# See tui.na.jac priming comment: phase-7 state.na.jac changes require explicit
# select_list priming so SelectItem resolves in overlay.na.jac during DFS.
import from .select_list { SelectList, SelectItem }
import from .screen { Screen }
import from .diff { DiffEngine, PaintBuf }
import from .transport { CmdQueue }
import from .runtime { TuiRuntime }
import from .input { handle_key }
import from .keys { parse_key }
import from .terminal_image { term_hyperlink, image_rows }
import from .tui_core {
    tui_populate_state,
    tui_enter_screen,
    tui_leave_screen,
    tui_render_once,
    tui_sync_size
}
import from .bridge_schema { decode_batch, decode_snapshot }
import from .session_apply { apply_batch, apply_snapshot }

glob host_rt: TuiRuntime = TuiRuntime(),
     _cmd_pending: list[str] = [];


def _reset_host_state {
    host_rt.cmd_queue.clear();
    _cmd_pending = [];
    st = host_rt.state;
    st.reset_events();
    st.files = [];
    st.model_presets = [];
    st.quit_flag = False;
    st.ipc_fd = -1;
    st.status = TuiStatus.IDLE;
    st.active = "";
    st.model_name = "";
    st.needs_key = False;
    st.key_env = "";
    st.editor.clear();
    st.overlay_stack.clear();
    st.overlay_full_redraw = False;
    host_rt.diff.invalidate();
}


def _pop_command -> str {
    if len(_cmd_pending) == 0 {
        _cmd_pending = host_rt.cmd_queue.drain_all();
    }
    if len(_cmd_pending) == 0 {
        return "";
    }
    cmd = _cmd_pending[0];
    if len(_cmd_pending) == 1 {
        _cmd_pending = [];
    } else {
        _cmd_pending = _cmd_pending[1:];
    }
    return cmd;
}


# One-time setup. Returns 0 on success, non-zero on tty failure. Idempotent.
# `tty_dev` is /dev/pts/N or "" for the JAC_AI_TUI_TTY / /dev/tty default.
def:pub tui_init(project: str, files_env: str, presets_env: str, tty_dev: str) -> int {
    _reset_host_state();
    if tty_dev {
        tty_configure_device(tty_dev);
    }
    fd: int = tty_open();
    if fd < 0 {
        return 1;
    }
    host_rt.state.render_fd = fd;
    tui_populate_state(host_rt.state, project, files_env, presets_env);
    tui_enter_screen(host_rt.state);
    return 0;
}


# Apply a typed session_event_batch JSON blob. snapshot_required mutations are
# applied (layout dirty) but the host must call tui_apply_snapshot separately.
def:pub tui_apply_batch(json: str) -> int {
    try {
        batch = decode_batch(json);
    } except Exception {
        return 1;
    }
    apply_batch(host_rt.state, batch);
    return 0;
}


def:pub tui_apply_snapshot(json: str) -> int {
    try {
        snap = decode_snapshot(json);
    } except Exception {
        return 1;
    }
    apply_snapshot(host_rt.state, snap);
    return 0;
}


# Block on poll(2) over the tty. Lock-free; does not touch TuiState.
def:pub tui_wait_key(timeout_ms: int) -> int {
    tty_poll(timeout_ms);
    return tty_key_ready();
}


# Read one keystroke, route through reducer/input, enqueue cmds. Returns 1 on quit.
def:pub tui_handle_key -> int {
    raw = tty_read_key();
    if len(raw) == 0 {
        return 0;
    }
    should_quit = handle_key(parse_key(raw), host_rt);
    if should_quit {
        host_rt.state.quit_flag = True;
        return 1;
    }
    return 0;
}


def:pub tui_next_command -> str {
    return _pop_command();
}


def:pub tui_quit_requested -> int {
    if host_rt.state.quit_flag {
        return 1;
    }
    return 0;
}


def:pub tui_render -> int {
    if host_rt.state.render_fd < 0 {
        return 0;
    }
    tui_sync_size(host_rt.state);
    tui_render_once(host_rt);
    return 0;
}


def:pub tui_shutdown -> int {
    if host_rt.state.render_fd >= 0 {
        tui_leave_screen(host_rt.state);
    }
    tty_close();
    return 0;
}
