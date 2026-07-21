# Transcript view — free functions + thin Component for D2 dispatch tests.

import from .component { Component }
import from .input_types { InputEvent, InputResult }
import from .state { TuiState, DisplayRow, EventKind, kind_style }
import from .feed { build_rows }
import from .terminal { ansi_fg }
import from .width { ansi_trunc, ansi_pad }
import from .theme { TH_SGR_USER_MSG }
import from .chrome { framed_row, framed_row_border_gap, empty_border_row }
import from .loading_indicator { loading_footer_active, render_loading_footer }

def _transcript_body_h(state: TuiState, height: int) -> int {
    footer = 1 if loading_footer_active(state) else 0;
    return max(0, height - footer);
}

def sync_display_rows(state: TuiState, cols: int) {
    if state.layout_dirty or state.layout_cols != cols {
        build_rows(state);
    }
}

def clamp_viewport(state: TuiState, t_draw_h: int) {
    body_h = _transcript_body_h(state, t_draw_h);
    max_top = max(0, len(state.display_rows) - body_h);
    if state.follow_tail {
        state.viewport_top = max_top;
    }
    state.viewport_top = max(0, min(state.viewport_top, max_top));
    if not state.follow_tail and state.viewport_top >= max_top {
        state.follow_tail = True;
    }
}

def _kind_sgr(kind: EventKind) -> str {
    s = kind_style(kind);
    return ansi_fg(s.color, s.attrs);
}

def _transcript_row(dr: DisplayRow, cols: int) -> str {
    if dr.kind == EventKind.SEP {
        return empty_border_row(cols);
    }
    if dr.pre_styled {
        return framed_row_border_gap(dr.text);
    }
    inner_w = cols - 4;
    if dr.kind == EventKind.USER {
        content_w = inner_w - 1;
        padded = ansi_pad(ansi_trunc(dr.text, content_w), content_w);
        return framed_row(TH_SGR_USER_MSG + padded);
    }
    return framed_row(_kind_sgr(dr.kind) + ansi_trunc(dr.text, inner_w));
}

def render_transcript(state: TuiState, width: int, height: int) -> list[str] {
    drows = state.display_rows;
    total = len(drows);
    body_h = _transcript_body_h(state, height);
    rows: list[str] = [];
    for k in range(body_h) {
        idx = state.viewport_top + k;
        if idx < total {
            rows.append(_transcript_row(drows[idx], width));
        } else {
            rows.append(empty_border_row(width));
        }
    }
    if loading_footer_active(state) {
        rows.append(render_loading_footer(state, width));
    }
    return rows;
}

obj TranscriptView(Component) {
    override def render(width: int) -> list[str] {
        return [empty_border_row(width) for _ in range(self.allocated_h)];
    }

    override def handle_input(ev: InputEvent) -> InputResult {
        return InputResult.IGNORED;
    }
}
