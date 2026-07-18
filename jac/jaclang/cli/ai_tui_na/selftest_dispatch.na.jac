"""Native dispatch harness: key routing via handle_key (no CPython boot).

Exercises reduce_input through the production input.na.jac adapter. Emits
PASS/FAIL lines; pytest fails on any FAIL. Guards ctrl-c quit, movement,
editor insert, and overlay routing before reducer if/elif -> match refactors.
"""

import from .input { handle_key }
import from .runtime { TuiRuntime }
import from .state { TuiState, EventKind }
import from .keys { Key, KeyKind }
import from .overlay { overlay_open_palette }
import from .ipc_schema { CMD_QUIT, CMD_STOP, CMD_RESET, CMD_SEND }
import from .libc_tty { tty_write }
import from .session_apply { apply_mutation }
import from .bridge_schema {
    MUT_MESSAGE_START,
    MUT_MESSAGE_UPDATE,
    MUT_TOOL_START,
    MUT_TOOL_END
}

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

    # THE ROUND-TRIP HALF: typing a prompt + ENTER must queue SEND:<text>.
    # This is the reducer/effect half of "type input -> agent gets a prompt".
    rt_send = _fresh_rt();
    handle_key(_key(KeyKind.CHAR, ord("p")), rt_send);
    handle_key(_key(KeyKind.CHAR, ord("i")), rt_send);
    handle_key(_key(KeyKind.CHAR, ord("n")), rt_send);
    handle_key(_key(KeyKind.CHAR, ord("g")), rt_send);
    _check("prompt_text_buffered", rt_send.state.editor.text_len() == 4);
    handle_key(_key(KeyKind.ENTER, 0), rt_send);
    cmds_send = rt_send.cmd_queue.drain_all();
    _check("enter_queues_send", _queue_has(cmds_send, CMD_SEND + ":ping"));

    # SESSION-APPLY MAPPING: a user start + a distinct answer update must land as
    # TWO separate transcript events (USER then ANSWER) -- not the answer glued
    # onto the user row. Guards the native consumer half of the round-trip fix.
    rt_apply = _fresh_rt();
    st = rt_apply.state;
    user_mut: dict[str, any] = {
        "kind": MUT_MESSAGE_START,
        "op": "user",
        "message_id": "1",
        "text": "hi"
    };
    answer_mut: dict[str, any] = {
        "kind": MUT_MESSAGE_UPDATE,
        "op": "replace_partial",
        "message_id": "2",
        "text": "echo: hi"
    };
    apply_mutation(st, user_mut);
    apply_mutation(st, answer_mut);
    _check("apply_two_distinct_events", len(st.events) == 2);
    two = len(st.events) == 2;
    _check(
        "apply_user_event_is_user",
        two and st.events[0].kind == EventKind.USER and st.events[0].text == "hi"
    );
    _check(
        "apply_answer_event_is_answer",
        two
        and st.events[1].kind == EventKind.ANSWER
        and st.events[1].text == "echo: hi"
    );

    # ...and reusing the user's id (the old bug) glues the answer onto the user
    # row instead of creating a second event -- assert we can still tell them apart.
    rt_glue = _fresh_rt();
    st2 = rt_glue.state;
    apply_mutation(st2, user_mut);
    collide: dict[str, any] = {
        "kind": MUT_MESSAGE_UPDATE,
        "op": "text_append",
        "message_id": "1",
        "text": "echo: hi"
    };
    apply_mutation(st2, collide);
    _check(
        "apply_id_reuse_fuses_row",
        len(st2.events) == 1 and st2.events[0].text == "hiecho: hi"
    );

    # STREAMED ANSWER (real wire shape): the bus publishes cumulative `ev` frames,
    # which normalize to MUT_MESSAGE_UPDATE op="replace_partial" with the FULL text
    # each time and a stable message id. The reducer must upsert one ANSWER row and
    # replace its text -- not append or duplicate.
    rt_stream = _fresh_rt();
    st3 = rt_stream.state;
    ans1: dict[str, any] = {
        "kind": MUT_MESSAGE_UPDATE,
        "op": "replace_partial",
        "message_id": "7",
        "text": "hello "
    };
    ans2: dict[str, any] = {
        "kind": MUT_MESSAGE_UPDATE,
        "op": "replace_partial",
        "message_id": "7",
        "text": "hello world"
    };
    apply_mutation(st3, ans1);
    apply_mutation(st3, ans2);
    _check(
        "stream_answer_replace_upserts_answer",
        len(st3.events) == 1
        and st3.events[0].kind == EventKind.ANSWER
        and st3.events[0].text == "hello world"
    );

    # TOOL events (real wire shape): a real turn emits call/tool_result, which
    # normalize to MUT_TOOL_START / MUT_TOOL_END. These were silently dropped --
    # the reducer must surface them as CALL / TOOL_RESULT rows.
    rt_tool = _fresh_rt();
    st4 = rt_tool.state;
    tool_start: dict[str, any] = {
        "kind": MUT_TOOL_START,
        "message_id": "11",
        "text": "read_file"
    };
    tool_end: dict[str, any] = {
        "kind": MUT_TOOL_END,
        "message_id": "12",
        "text": "file contents"
    };
    apply_mutation(st4, tool_start);
    apply_mutation(st4, tool_end);
    _check(
        "apply_tool_start_is_call",
        len(st4.events) == 2
        and st4.events[0].kind == EventKind.CALL
        and st4.events[0].text == "read_file"
    );
    _check(
        "apply_tool_end_is_tool_result",
        len(st4.events) == 2 and st4.events[1].kind == EventKind.TOOL_RESULT
    );

    # right arrow advances cursor when not already at line end
    rt6 = _fresh_rt();
    rt6.state.editor.insert("ab");
    rt6.state.editor.move_line_start();
    col_before = rt6.state.editor.cursor_col;
    handle_key(_key(KeyKind.RIGHT, 0), rt6);
    _check("right_moves_cursor", rt6.state.editor.cursor_col == col_before + 1);
}
