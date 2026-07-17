# Reducer — sole normal mutator of application state (no terminal/embed I/O).

import from .state { TuiState, AcKind, OverlayKind }
import from .keys { Key, KeyKind }
import from .input_types {
    UiAction,
    UiActionKind,
    Effect,
    EffectKind,
    FocusTarget,
    effect_quit,
    effect_stop,
    effect_reset,
    effect_send,
    effect_render
}
import from .focus { effective_focus }
import from .autocomplete { ac_update, ac_apply }
import from .overlay {
    overlay_open_palette,
    overlay_open_model,
    overlay_open_file,
    overlay_close
}
import from .commands {
    slash_submit_effects,
    command_dispatch_effects,
    apply_model_effects,
    CmdResult
}
import from .select_list { SelectAction }

glob _EDITOR_CHROME_COLS: int = 6,
     _EDITOR_CHROME_ROWS: int = 6,
     _INPUT_EDITOR_MAX_ROWS: int = 10,
     _PAGE_CHROME_ROWS: int = 4,
     _MOUSE_SCROLL_LINES: int = 3,
     _MAX_INPUT_LEN: int = 4096;

obj ReduceResult {
    has effects: list[Effect] = [],
        quit: bool = False;
}

def _extend(res: ReduceResult, effects: list[Effect]) {
    for e in effects {
        res.effects.append(e);
        if e.kind == EffectKind.QUIT {
            res.quit = True;
        }
    }
}

def _editor_width(state: TuiState) -> int {
    return max(1, state.term_cols - _EDITOR_CHROME_COLS);
}

def _editor_max_rows(state: TuiState) -> int {
    return max(1, min(_INPUT_EDITOR_MAX_ROWS, state.term_rows - _EDITOR_CHROME_ROWS));
}

def _sync_editor_view(state: TuiState) {
    state.editor.update_scroll(_editor_width(state), _editor_max_rows(state));
    state.mark_layout_dirty();
}

def _pending_continuation(state: TuiState) -> bool {
    ed = state.editor;
    if not ed.lines {
        return False;
    }
    if ed.cursor_col <= 0 {
        return False;
    }
    cur_line = ed.lines[ed.cursor_line];
    return cur_line[ed.cursor_col - 1] == "\\";
}

def _handle_submit(state: TuiState, res: ReduceResult) {
    ed = state.editor;
    if _pending_continuation(state) {
        ed.backspace();
        ed.newline();
        state.mark_layout_dirty();
        return;
    }
    text = ed.get_text().strip();
    if not text {
        return;
    }
    (cmd_res, effects) = slash_submit_effects(text, state);
    match cmd_res {
        case CmdResult.QUIT:
            ed.submit();
            _extend(res, effects);
            res.quit = True;
            return;

        case CmdResult.OPEN_MODEL:
            ed.submit();
            overlay_open_model(state);
            return;

        case CmdResult.OPEN_FILE:
            ed.submit();
            overlay_open_file(state);
            return;

        case CmdResult.HANDLED:
            ed.submit();
            _extend(res, effects);
            return;

        case CmdResult.NONE:
            if state.status_blocks_prompt() {
                return;
            }
            state.pending_submission.active = True;
            state.pending_submission.text = text;
            res.effects.append(effect_send(text));
    }
}

def _handle_global(state: TuiState, k: Key, res: ReduceResult) -> bool {
    if k.kind != KeyKind.CTRL {
        return False;
    }
    ch = chr(k.code);
    if ch == "c" or ch == "q" {
        res.quit = True;
        res.effects.append(effect_quit());
        return True;
    }
    match ch {
        case "g":
            res.effects.append(effect_stop());
            state.mark_layout_dirty();
            return True;

        case "r":
            res.effects.append(effect_reset());
            state.reset_events();
            state.mark_layout_dirty();
            return True;

        case "o":
            overlay_open_palette(state, "");
            return True;
    }
    return False;
}

def _overlay_select(state: TuiState, res: ReduceResult, item_value: str) {
    kind = state.overlay_stack.active_spec().role;
    match kind {
        case OverlayKind.MODEL:
            _extend(res, apply_model_effects(item_value, state));
            overlay_close(state);
            return;

        case OverlayKind.FILE:
            state.editor.insert_text(f"@{item_value} ");
            overlay_close(state);
            return;

        case OverlayKind.PALETTE:
            (cmd_res, effects) = command_dispatch_effects(item_value, state);
            match cmd_res {
                case CmdResult.OPEN_MODEL:
                    overlay_open_model(state);
                    return;

                case CmdResult.OPEN_FILE:
                    overlay_open_file(state);
                    return;

                case CmdResult.QUIT:
                    _extend(res, effects);
                    res.quit = True;
                    overlay_close(state);
                    return;

                case CmdResult.HANDLED:
                    _extend(res, effects);
                    overlay_close(state);
                    return;

                case CmdResult.NONE:
                    _extend(res, effects);
                    overlay_close(state);
            }
    }
}

def _handle_overlay_key(state: TuiState, k: Key, res: ReduceResult) {
    if not state.overlay_stack.is_active() {
        return;
    }
    action = state.select_list.handle_key(k);
    match action {
        case SelectAction.CANCEL:
            overlay_close(state);
            return;

        case SelectAction.CHANGED:
            state.dirty = True;
            return;

        case SelectAction.SELECT:
            item = state.select_list.current();
            if item is None {
                return;
            }
            _overlay_select(state, res, item.value);

        case SelectAction.NONE:
            return;
    }
}

def _handle_ac_key(state: TuiState, k: Key, res: ReduceResult) {
    if k.kind == KeyKind.TAB {
        ac_apply(state);
        _sync_editor_view(state);
        return;
    }
    match k.kind {
        case KeyKind.ESCAPE:
            state.ac.dismiss();
            state.mark_layout_dirty();
            return;

        case KeyKind.UP:
            state.ac.nav_up();
            state.mark_layout_dirty();
            return;

        case KeyKind.DOWN:
            state.ac.nav_down();
            state.mark_layout_dirty();
            return;

        case KeyKind.ENTER:
            ac_kind = state.ac.kind;
            ac_apply(state);
            state.editor.update_scroll(_editor_width(state), _editor_max_rows(state));
            if ac_kind == AcKind.SLASH {
                _handle_submit(state, res);
            }
            return;
    }
    state.ac.dismiss();
    _handle_edit_key(state, k, res);
}

def _handle_editor_ctrl(state: TuiState, k: Key) {
    ed = state.editor;
    match chr(k.code) {
        case "a":
            ed.move_line_start();

        case "e":
            ed.move_line_end();

        case "k":
            ed.delete_to_line_end();

        case "u":
            ed.delete_to_line_start();

        case "w":
            ed.delete_word_back();

        case _:
            return;
    }
    _sync_editor_view(state);
}

def _handle_movement(state: TuiState, k: Key) -> bool {
    ed = state.editor;
    ew = _editor_width(state);
    if k.kind == KeyKind.UP {
        if ed.is_on_first_vline(ew) {
            navigated = ed.nav_history(-1);
            if not navigated {
                ed.move_line_start();
            }
        } else {
            ed.move_up(ew);
        }
        _sync_editor_view(state);
        return True;
    }
    if k.kind == KeyKind.DOWN {
        if ed.is_on_last_vline(ew) {
            navigated = ed.nav_history(1);
            if not navigated {
                ed.move_line_end();
            }
        } else {
            ed.move_down(ew);
        }
        _sync_editor_view(state);
        return True;
    }
    match k.kind {
        case KeyKind.LEFT:
            ed.move_left();

        case KeyKind.RIGHT:
            ed.move_right();

        case KeyKind.HOME:
            ed.move_line_start();

        case KeyKind.END:
            ed.move_line_end();

        case KeyKind.WORD_LEFT:
            ed.word_left();

        case KeyKind.WORD_RIGHT:
            ed.word_right();

        case KeyKind.PAGE_UP:
            state.scroll_up(state.term_rows - _PAGE_CHROME_ROWS);
            return True;

        case KeyKind.PAGE_DOWN:
            state.scroll_down(state.term_rows - _PAGE_CHROME_ROWS);
            return True;

        case _:
            return False;
    }
    _sync_editor_view(state);
    return True;
}

def _handle_edit_key(state: TuiState, k: Key, res: ReduceResult) {
    ed = state.editor;
    match k.kind {
        case KeyKind.TAB:
            ed_text = ed.get_text();
            if ed_text.startswith("/") {
                overlay_open_palette(state, ed_text[1:]);
            }
            return;

        case KeyKind.SHIFT_ENTER:
            ed.newline();
            _sync_editor_view(state);
            return;

        case KeyKind.ENTER:
            _handle_submit(state, res);
            return;

        case KeyKind.BACKSPACE:
            ed.backspace();
            _sync_editor_view(state);
            ac_update(state);
            return;

        case KeyKind.MOUSE_SCROLL_UP:
            state.scroll_up(_MOUSE_SCROLL_LINES);
            return;

        case KeyKind.MOUSE_SCROLL_DOWN:
            state.scroll_down(_MOUSE_SCROLL_LINES);
            return;

        case KeyKind.DELETE:
            ed.forward_delete();
            _sync_editor_view(state);
            return;

        case KeyKind.CHAR:
            if ed.text_len() >= _MAX_INPUT_LEN {
                return;
            }
            ed.insert(chr(k.code));
            _sync_editor_view(state);
            ac_update(state);
            return;

        case _:
            return;
    }
}

def _handle_transcript_key(state: TuiState, k: Key) {
    match k.kind {
        case KeyKind.PAGE_UP:
            state.scroll_up(state.term_rows - _PAGE_CHROME_ROWS);

        case KeyKind.PAGE_DOWN:
            state.scroll_down(state.term_rows - _PAGE_CHROME_ROWS);

        case KeyKind.MOUSE_SCROLL_UP:
            state.scroll_up(_MOUSE_SCROLL_LINES);

        case KeyKind.MOUSE_SCROLL_DOWN:
            state.scroll_down(_MOUSE_SCROLL_LINES);

        case _:
            return;
    }
}

def reduce_input(model: TuiState, action: UiAction) -> ReduceResult {
    res = ReduceResult();
    if action.kind == UiActionKind.SET_FOCUS {
        model.set_focus(action.focus);
        return res;
    }
    if action.kind != UiActionKind.KEY {
        return res;
    }
    k = action.key;
    if k.kind == KeyKind.UNKNOWN {
        return res;
    }
    if _handle_global(model, k, res) {
        return res;
    }
    match effective_focus(model) {
        case FocusTarget.OVERLAY:
            _handle_overlay_key(model, k, res);
            return res;

        case FocusTarget.AUTOCOMPLETE:
            _handle_ac_key(model, k, res);
            return res;

        case FocusTarget.TRANSCRIPT:
            _handle_transcript_key(model, k);
            return res;

        case FocusTarget.EDITOR:
            if k.kind == KeyKind.CTRL {
                _handle_editor_ctrl(model, k);
                return res;
            }
            if _handle_movement(model, k) {
                return res;
            }
            _handle_edit_key(model, k, res);
            return res;
    }
    return res;
}

def reduce_session(model: TuiState, dirty: bool) -> ReduceResult {
    res = ReduceResult();
    if dirty {
        model.dirty = True;
        res.effects.append(effect_render());
    }
    return res;
}
