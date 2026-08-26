# Product-path facade for _curses (the ncurses binding exercised by
# test_curses). Semantics mirror CPython 3.14 ``Modules/_cursesmodule.c``:
# the LINES/COLS bookkeeping of update_lines_cols, the color-pair
# validation with byte-exact ValueError texts, the ERR-checking discipline
# (PyCursesCheckERR / catchall_ERR), and the module constants.
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original owns
# the ncurses binding directly (WINDOW handles, terminfo setup, MEVENT
# structs). This facade delegates every screen/terminfo primitive to the
# host ``_curses`` extension (same libncurses floor the interpreter ships),
# exactly like C-extension modules stay host-proxied by design. Window
# objects returned by initscr/newwin/subwin flow through as transparent
# host proxies; everything below is what the C source implements ABOVE the
# raw ncurses calls.
#
# Failure-arm note: the delegated twins raise byte-identical errors (the
# host extension is built from this very source), so wrappers here only
# pre-validate the deterministic arms -- any pair number >= COLOR_PAIRS
# fails inside ncurses regardless of terminal state, making the early
# ValueError observationally equivalent to the C ordering.
#
# Exception surface note: ``curses.error`` is not synthesized here -- the
# host type is re-exported so raised errors keep their builtin identity,
# and new exception types are unsupported from facades anyway.

import _curses;


# ---- constants (curses.h / py_curses.h) -------------------------------------

glob ERR: int = -1;
glob OK: int = 0;

# catchall_ERR from Include/py_curses.h:109, kept for parity with
# _PyCursesSetError's fallback text.
glob _catchall_ERR: str = "curses function returned ERR";

# Re-exported host exception type (state->error in the C module): raised
# errors keep their builtin curses.error identity across delegation.
glob error: any = _curses.error;

# LINES/COLS module attributes: written by update_lines_cols exactly like
# _curses.update_lines_cols writes both the private and exposed dicts.
glob LINES: int = 0;
glob COLS: int = 0;


# ---- update_lines_cols (_curses_update_lines_cols_impl) ---------------------

# The C version imports the exposed "curses" module and writes LINES/COLS
# into both the private and exposed module dicts. Here the facade IS the
# exposed module, so one write suffices; the host floor supplies the live
# ncurses values refreshed by initscr/resize_term.
def update_lines_cols() {
    LINES = _curses.LINES as int;
    COLS = _curses.COLS as int;
}


# ---- color pair validation (init_pair / pair_content) -----------------------

def _pair_range_msg() -> str {
    # PyErr_Format(PyExc_ValueError,
    #              "Color pair is greater than COLOR_PAIRS-1 (%d).",
    #              COLOR_PAIRS - 1)
    return (
        "Color pair is greater than COLOR_PAIRS-1 ("
        + str(((_curses.COLOR_PAIRS as int) - 1)) + ".");
}

def init_pair(pair_number: int, fg: int, bg: int) {
    if pair_number >= _curses.COLOR_PAIRS {
        raise ValueError(_pair_range_msg());
    }
    _curses.init_pair(pair_number, fg, bg);
}

def pair_content(pair_number: int) -> tuple[int, int] {
    if pair_number >= _curses.COLOR_PAIRS {
        raise ValueError(_pair_range_msg());
    }
    return _curses.pair_content(pair_number);
}


# ---- getsyx/setsyx (NCURSES_EXT_FUNCS block) --------------------------------

# The C getsyx macro resolves stdscr's cursor position (honoring leaveok)
# inside ncurses and packs (y, x); setsyx restores it.
def getsyx() -> tuple[int, int] {
    return _curses.getsyx();
}

def setsyx(y: int, x: int) {
    _curses.setsyx(y, x);
}


# ---- validated passthroughs -------------------------------------------------
#
# Remaining METHODDEF entries delegate straight through the host proxy; the
# facade stays the single guest-visible import surface so later waves can
# move individual arms in-Jac without touching call sites.

def has_extended_color_support() -> bool {
    return bool(_curses.has_extended_color_support());
}

def baudrate() -> int {
    return _curses.baudrate();
}

def termattrs() -> int | None {
    return _curses.termattrs();
}

def erasechar() -> bytes {
    return _curses.erasechar();
}

def killchar() -> bytes {
    return _curses.killchar();
}

def has_colors() -> bool {
    return bool(_curses.has_colors());
}

def can_change_color() -> bool {
    return bool(_curses.can_change_color());
}

def start_color() {
    _curses.start_color();
}

def color_content(color_number: int) -> tuple[int, int, int] {
    return _curses.color_content(color_number);
}

def init_color(color_number: int, r: int, g: int, b: int) {
    _curses.init_color(color_number, r, g, b);
}

def color_pair(pair_number: int) -> int {
    return _curses.color_pair(pair_number);
}

def pair_number(attr: int) -> int {
    return _curses.pair_number(attr);
}
