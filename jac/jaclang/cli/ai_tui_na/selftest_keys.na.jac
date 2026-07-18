"""Native unit tests for keyboard input parsing (keys.na.jac)."""

import from .keys { parse_key, KeyKind }
import from .libc_tty { tty_write }


def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

def _kind(raw: str) -> KeyKind {
    return parse_key(raw).kind;
}

def _ctrl(raw: str) -> int {
    return parse_key(raw).code;
}

with entry {
    _check("char_a", _kind("a") == KeyKind.CHAR and parse_key("a").code == ord("a"));
    _check("tab", _kind("\t") == KeyKind.TAB);
    _check("enter_cr", _kind("\r") == KeyKind.ENTER);
    _check("enter_lf", _kind("\n") == KeyKind.ENTER);
    _check("backspace_del", _kind("\x7f") == KeyKind.BACKSPACE);
    _check("backspace_bs", _kind("\x08") == KeyKind.BACKSPACE);

    _check("ctrl_c", _kind("\x03") == KeyKind.CTRL and _ctrl("\x03") == ord("c"));
    _check("ctrl_g", _kind("\x07") == KeyKind.CTRL and _ctrl("\x07") == ord("g"));
    _check("ctrl_r", _kind("\x12") == KeyKind.CTRL and _ctrl("\x12") == ord("r"));

    _check("escape_alone", _kind("\x1b") == KeyKind.ESCAPE);
    _check("arrow_up", _kind("\x1b[A") == KeyKind.UP);
    _check("arrow_down", _kind("\x1b[B") == KeyKind.DOWN);
    _check("arrow_right", _kind("\x1b[C") == KeyKind.RIGHT);
    _check("arrow_left", _kind("\x1b[D") == KeyKind.LEFT);
    _check("home", _kind("\x1b[H") == KeyKind.HOME);
    _check("end", _kind("\x1b[F") == KeyKind.END);
    _check("delete", _kind("\x1b[3~") == KeyKind.DELETE);
    _check("page_up", _kind("\x1b[5~") == KeyKind.PAGE_UP);
    _check("page_down", _kind("\x1b[6~") == KeyKind.PAGE_DOWN);
    _check("word_left", _kind("\x1b[1;5D") == KeyKind.WORD_LEFT);
    _check("word_right", _kind("\x1b[1;5C") == KeyKind.WORD_RIGHT);
    _check("shift_enter", _kind("\x1b\r") == KeyKind.SHIFT_ENTER);

    _check("mouse_wheel_up", _kind("\x1b[<64;1;1M") == KeyKind.MOUSE_SCROLL_UP);
    _check("mouse_wheel_down", _kind("\x1b[<65;1;1M") == KeyKind.MOUSE_SCROLL_DOWN);

    _check("empty_unknown", _kind("") == KeyKind.UNKNOWN);
    _check("garbage_unknown", _kind("\x00") == KeyKind.UNKNOWN);
}
