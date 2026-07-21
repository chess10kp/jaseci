# Animated loading footer shown while the agent turn is in flight.

import from .state { TuiState, TuiStatus, EventKind }
import from .theme { TH_SGR_PHASE, TH_SGR_BORDER_DIM }
import from .chrome { framed_row }
import from .width { ansi_pad, ansi_trunc }
import from .terminal { ANSI_RESET }

glob _LOADING_SPIN_STEP: int = 5,
     _SPINNER: list[str] = [
    "⠋",
    "⠙",
    "⠹",
    "⠸",
    "⠼",
    "⠴",
    "⠦",
    "⠧",
    "⠇",
    "⠏"
];

def loading_spinner_frame(tick: int) -> int {
    return (tick // _LOADING_SPIN_STEP) % len(_SPINNER);
}

def loading_footer_active(state: TuiState) -> bool {
    if not state.status_blocks_prompt() {
        return False;
    }
    if state.status == TuiStatus.STOPPING {
        return True;
    }
    if not state.events {
        return True;
    }
    last = state.events[-1];
    return last.kind == EventKind.USER or last.kind == EventKind.TOOL_RESULT;
}

def loading_label(state: TuiState) -> str {
    if state.active {
        return state.active;
    }
    if state.status == TuiStatus.STOPPING {
        return "Stopping…";
    }
    return "Thinking…";
}

def render_loading_footer(state: TuiState, width: int) -> str {
    inner_w = max(1, width - 4);
    frame = loading_spinner_frame(state.loading_tick);
    spin = _SPINNER[frame];
    label = loading_label(state);
    body = TH_SGR_PHASE + spin + " " + label + TH_SGR_BORDER_DIM + ANSI_RESET;
    padded = ansi_pad(ansi_trunc(body, inner_w), inner_w);
    return framed_row(padded);
}
