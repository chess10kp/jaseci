"""Native unit tests for EditorState and editor_view rendering."""

import from .editor { EditorState }
import from .state { TuiState, TuiStatus }
import from .editor_view { render_editor, editor_text_width }
import from .width { visible_width }
import from .libc_tty { tty_write }


def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

def _fresh_ed() -> EditorState {
    return EditorState();
}

with entry {
    ed = _fresh_ed();
    ed.insert("hello");
    _check("insert_text", ed.get_text() == "hello" and ed.cursor_col == 5);

    ed.backspace();
    _check("backspace", ed.get_text() == "hell" and ed.cursor_col == 4);

    ed2 = _fresh_ed();
    ed2.insert("line1");
    ed2.newline();
    ed2.insert("line2");
    _check("newline_multiline", ed2.lines == ["line1", "line2"] and ed2.cursor_line == 1);

    ed3 = _fresh_ed();
    ed3.insert("one two three");
    ed3.move_line_end();
    ed3.word_left();
    _check("word_left", ed3.cursor_col == 8);
    ed3.word_right();
    _check("word_right", ed3.cursor_col == 13);

    ed4 = _fresh_ed();
    ed4.add_history("first");
    ed4.add_history("second");
    ed4.insert("draft");
    ok_hist = ed4.nav_history(-1);
    _check("history_up_recent", ok_hist and ed4.get_text() == "second");
    ok_hist2 = ed4.nav_history(-1);
    _check("history_up_older", ok_hist2 and ed4.get_text() == "first");
    ok_hist3 = ed4.nav_history(1);
    _check("history_down", ok_hist3 and ed4.get_text() == "second");
    ok_hist4 = ed4.nav_history(1);
    _check("history_restore_draft", ok_hist4 and ed4.get_text() == "draft");

    ed5 = _fresh_ed();
    _check("history_empty_noop", ed5.nav_history(-1) == False);

    submitted = ed5.submit();
    _check("submit_empty", submitted == "" and ed5.get_text() == "");
    ed5.insert("  hi  ");
    submitted2 = ed5.submit();
    _check("submit_trims", submitted2 == "hi" and len(ed5.history) == 1);

    # Wide text must not overflow the editor row visible width at 80 cols.
    state = TuiState();
    state.term_cols = 80;
    state.term_rows = 24;
    wide = (
        "가나다라마바사아자차카타파하 한글 텍스트가 터미널 너비를 초과하면 "
        "크래시가 발생합니다"
    );
    state.editor.insert(wide);
    state.editor.update_scroll(editor_text_width(80), 3);
    rows = render_editor(state, 80, 3);
    text_w = editor_text_width(80);
    overflow = False;
    for row in rows {
        if visible_width(row) > 80 {
            overflow = True;
        }
    }
    _check("cjk_render_no_overflow", not overflow and len(rows) == 3);

    # Cursor scroll keeps cursor visible in wrapped wide text.
    state2 = TuiState();
    state2.editor.insert("가나다라마바사아자차카타파하");
    state2.editor.move_line_start();
    for _ in range(5) {
        state2.editor.move_right();
    }
    state2.editor.update_scroll(editor_text_width(20), 1);
    rows2 = render_editor(state2, 80, 1);
    _check("cursor_scroll_one_row", len(rows2) == 1);
}
