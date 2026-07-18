"""Native unit tests for display-cell width primitives (width.na.jac)."""

import from .width { visible_width, ansi_trunc, ansi_pad }
import from .libc_tty { tty_write }


def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

with entry {
    _check("W1_empty", visible_width("") == 0);
    _check("W2_ascii", visible_width("abc") == 3);

    colored = "a" + "\x1b[31m" + "b" + "\x1b[0m" + "c";
    _check("W3_ansi_skipped", visible_width(colored) == 3);

    trunc = ansi_trunc("hello", 3);
    _check("W4_trunc", trunc == "he~" and visible_width(trunc) == 3);

    padded = ansi_pad("hi", 5);
    _check("W5_pad", padded == "hi   " and visible_width(padded) == 5);

    _check("W6_emoji_one_cell", visible_width("😀") == 1);

    t40 = ansi_trunc("abcdefghijklmnopqrstuvwxyz", 10);
    _check("W7_trunc_bound", visible_width(t40) <= 10);

    # CJK counts as one cell under the current algorithm (documented limitation).
    cjk = "가나다라";
    _check("W8_cjk_one_cell_each", visible_width(cjk) == 4);

    osc = "\x1b]8;;https://example.com\x07link\x1b]8;;\x07";
    _check("W9_osc_hyperlink", visible_width(osc) == 4);

    tabbed = "\t界";
    _check("W10_tab_non_printable", visible_width(tabbed) == 1);
}
