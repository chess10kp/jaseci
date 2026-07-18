"""Native unit tests for overlay modal build and compositing."""

import from .state {
    TuiState,
    OverlayKind,
    OverlayContent,
    OverlaySpec,
    Anchor
}
import from .select_list { SelectItem }
import from .overlay {
    overlay_build_modal,
    overlay_composite,
    overlay_is_active,
    overlay_open_palette,
    overlay_close
}
import from .width { visible_width }
import from .libc_tty { tty_write }


def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

def _all_fit(lines: list[str], cols: int) -> bool {
    for line in lines {
        if line and visible_width(line) > cols {
            return False;
        }
    }
    return True;
}

def _base_frame(cols: int, rows: int) -> list[str] {
    out: list[str] = [];
    for i in range(rows) {
        label = "base-" + str(i);
        if len(label) < cols {
            label = label + (" " * (cols - len(label)));
        } else {
            label = label[:cols];
        }
        out.append(label);
    }
    return out;
}

with entry {
    cols: int = 80;
    rows: int = 24;

    state = TuiState();
    state.term_cols = cols;
    state.term_rows = rows;
    overlay_open_palette(state, "");
    _check("overlay_active_after_open", overlay_is_active(state));

    modal = overlay_build_modal(state, cols, rows);
    _check("modal_row_count", len(modal) == rows);
    _check("modal_width", _all_fit(modal, cols));

    base = _base_frame(cols, rows);
    composed = overlay_composite(base, modal, cols, rows);
    _check("composite_row_count", len(composed) == rows);
    _check("composite_width", _all_fit(composed, cols));

    # Non-empty modal rows replace base rows.
    replaced = False;
    for i in range(rows) {
        if composed[i] and composed[i] != base[i] {
            replaced = True;
        }
    }
    _check("composite_replaces_base", replaced);

    # Empty modal rows preserve base.
    empty_modal: list[str] = [""] * rows;
    preserved = overlay_composite(base, empty_modal, cols, rows);
    _check("empty_modal_preserves_base", preserved == base);

    # CJK in filter text must not blow modal width.
    state2 = TuiState();
    state2.term_cols = cols;
    state2.term_rows = rows;
    state2.select_list.filtered = [
        SelectItem(value="/help", label="/help", description="도움말 한글")
    ];
    state2.overlay_stack.push(
        OverlaySpec(
            content=OverlayContent.SELECT_LIST,
            role=OverlayKind.PALETTE,
            title="명령",
            anchor=Anchor.CENTER,
            width_pct=50
        )
    );
    state2.select_list.filter_text = "도움";
    modal2 = overlay_build_modal(state2, cols, rows);
    _check("cjk_modal_width", _all_fit(modal2, cols));

    overlay_close(state);
    _check("overlay_closed", not overlay_is_active(state));
}
