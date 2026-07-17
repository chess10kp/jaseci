"""Native dispatch harness: key routing via handle_key (no CPython boot).

Exercises reduce_input through the production input.na.jac adapter. Emits
PASS/FAIL lines; pytest fails on any FAIL. Guards ctrl-c quit, movement,
editor insert, and overlay routing before reducer if/elif -> match refactors.
"""

import from .input { handle_key }
import from .runtime { TuiRuntime }
import from .state { TuiState }
import from .keys { Key, KeyKind }
import from .overlay { overlay_open_palette }
import from .ipc_schema { CMD_QUIT, CMD_STOP, CMD_RESET }
import from .libc_tty { tty_write }

def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

def _fresh_rt -> TuiRuntime {
    rt = TuiRuntime();
    rt.state.term_cols = 80;
    rt.state.term_rows = 24;
    rt.state.ipc_fd = -1;
    rt.cmd_queue.clear();
    return rt;
}

def _key(kind: KeyKind, code: int) -> Key {
    return Key(kind=kind, code=code);
}

def _queue_has(cmds: list[str], want: str) -> bool {
    for c in cmds {
        if c == want {
            return True;
        }
    }
    return False;
}

with entry {
    # ctrl-c -> quit + CMD_QUIT queued (ipc_fd = -1 buffers commands)
    rt = _fresh_rt();
    quit = handle_key(_key(KeyKind.CTRL, 99), rt);
    cmds = rt.cmd_queue.drain_all();
    _check("ctrl_c_quits", quit);
    _check("ctrl_c_cmd_queued", _queue_has(cmds, CMD_QUIT));

    # ctrl-g -> STOP
    rt2 = _fresh_rt();
    handle_key(_key(KeyKind.CTRL, 103), rt2);
    cmds2 = rt2.cmd_queue.drain_all();
    _check("ctrl_g_stop", _queue_has(cmds2, CMD_STOP));

    # ctrl-r -> RESET
    rt3 = _fresh_rt();
    handle_key(_key(KeyKind.CTRL, 114), rt3);
    cmds3 = rt3.cmd_queue.drain_all();
    _check("ctrl_r_reset", _queue_has(cmds3, CMD_RESET));

    # char insert grows editor
    rt4 = _fresh_rt();
    before = rt4.state.editor.text_len();
    handle_key(_key(KeyKind.CHAR, ord("a")), rt4);
    after = rt4.state.editor.text_len();
    _check("char_inserts", after == before + 1);

    # overlay: open palette then escape closes
    rt5 = _fresh_rt();
    overlay_open_palette(rt5.state, "");
    _check("overlay_active", rt5.state.overlay_stack.is_active());
    handle_key(_key(KeyKind.ESCAPE, 0), rt5);
    _check("overlay_escape_closes", not rt5.state.overlay_stack.is_active());

    # right arrow advances cursor when not already at line end
    rt6 = _fresh_rt();
    rt6.state.editor.insert("ab");
    rt6.state.editor.move_line_start();
    col_before = rt6.state.editor.cursor_col;
    handle_key(_key(KeyKind.RIGHT, 0), rt6);
    _check("right_moves_cursor", rt6.state.editor.cursor_col == col_before + 1);
}
