import os;
import from .libc_tty { tty_write }

glob ANSI_RESET: str = "\033[0m",
     ANSI_BOLD: str = "\033[1m",
     ANSI_ITALIC: str = "\033[3m",
     ANSI_INVERSE: str = "\033[7m",
     ANSI_STRIKE: str = "\033[9m",
     ANSI_FG_YELLOW: str = "\033[33m",
     ANSI_CLEAR_SCREEN: str = "\033[2J\033[H",
     ANSI_CLEAR_LINE: str = "\033[2K";

def term_enter_alt_screen(fd: int) {
    tty_write(fd, "\033[?1049h");
}

def term_leave_alt_screen(fd: int) {
    tty_write(fd, "\033[?1049l");
}

def term_hide_cursor(fd: int) {
    tty_write(fd, "\033[?25l");
}

def term_show_cursor(fd: int) {
    tty_write(fd, "\033[?25h");
}

def term_enable_mouse(fd: int) {
    tty_write(fd, "\033[?1000h\033[?1006h");
}

def term_disable_mouse(fd: int) {
    tty_write(fd, "\033[?1006l\033[?1000l");
}

def term_sync_start(fd: int) {
    tty_write(fd, "\033[?2026h");
}

def term_sync_end(fd: int) {
    tty_write(fd, "\033[?2026l");
}

obj Rgb {
    has r: int = 0,
        g: int = 0,
        b: int = 0;
}

def ansi_move(x: int, y: int) -> str {
    return f"\033[{y + 1};{x + 1}H";
}

# --- Color depth: truecolor (24-bit) vs. 256-color fallback -----------------
# Mirrors pi's approach (reference/pi terminal-image.ts + theme.ts): emit
# 24-bit SGR when the terminal advertises it, otherwise degrade each RGB to the
# nearest xterm-256 index via a perceptually weighted cube/grayscale match.

def _detect_truecolor -> bool {
    ct = os.getenv("COLORTERM");
    if ct is not None {
        c = ct.lower();
        if c == "truecolor" or c == "24bit" {
            return True;
        }
    }
    tp = os.getenv("TERM_PROGRAM");
    if tp is not None {
        p = tp.lower();
        if (
            p == "kitty"
            or p == "ghostty"
            or p == "wezterm"
            or p == "iterm.app"
            or p == "vscode"
        ) {
            return True;
        }
    }
    if os.getenv("KITTY_WINDOW_ID") is not None {
        return True;
    }
    if os.getenv("WEZTERM_PANE") is not None {
        return True;
    }
    return False;
}

glob _TRUECOLOR: bool = _detect_truecolor();

# The 6x6x6 color cube channel values (indices 0-5) and the 24-step grayscale
# ramp (indices 232-255), as used by the xterm 256-color palette.
glob _CUBE_VALUES: list[int] = [0, 95, 135, 175, 215, 255];
glob _GRAY_VALUES: list[int] = [
    8, 18, 28, 38, 48, 58, 68, 78, 88, 98, 108, 118,
    128, 138, 148, 158, 168, 178, 188, 198, 208, 218, 228, 238
];

# Weighted squared distance scaled by 1000 (integer, comparison-preserving).
# Weights 299/587/114 track human luminance sensitivity (green > red > blue).
def _color_dist(r1: int, g1: int, b1: int, r2: int, g2: int, b2: int) -> int {
    dr = r1 - r2;
    dg = g1 - g2;
    db = b1 - b2;
    return dr * dr * 299 + dg * dg * 587 + db * db * 114;
}

def _closest_cube_index(value: int) -> int {
    min_dist = -1;
    min_idx = 0;
    for i in range(len(_CUBE_VALUES)) {
        d = value - _CUBE_VALUES[i];
        if d < 0 {
            d = -d;
        }
        if min_dist < 0 or d < min_dist {
            min_dist = d;
            min_idx = i;
        }
    }
    return min_idx;
}

def _closest_gray_index(gray: int) -> int {
    min_dist = -1;
    min_idx = 0;
    for i in range(len(_GRAY_VALUES)) {
        d = gray - _GRAY_VALUES[i];
        if d < 0 {
            d = -d;
        }
        if min_dist < 0 or d < min_dist {
            min_dist = d;
            min_idx = i;
        }
    }
    return min_idx;
}

def rgb_to_256(r: int, g: int, b: int) -> int {
    r_idx = _closest_cube_index(r);
    g_idx = _closest_cube_index(g);
    b_idx = _closest_cube_index(b);
    cube_r = _CUBE_VALUES[r_idx];
    cube_g = _CUBE_VALUES[g_idx];
    cube_b = _CUBE_VALUES[b_idx];
    cube_index = 16 + 36 * r_idx + 6 * g_idx + b_idx;
    cube_dist = _color_dist(r, g, b, cube_r, cube_g, cube_b);

    gray = (299 * r + 587 * g + 114 * b + 500) // 1000;
    gray_idx = _closest_gray_index(gray);
    gray_value = _GRAY_VALUES[gray_idx];
    gray_index = 232 + gray_idx;
    gray_dist = _color_dist(r, g, b, gray_value, gray_value, gray_value);

    # Only pick grayscale for near-neutral colors, so tints keep their hue.
    max_c = max(r, max(g, b));
    min_c = min(r, min(g, b));
    if max_c - min_c < 10 and gray_dist < cube_dist {
        return gray_index;
    }
    return cube_index;
}

def _fg_frag(c: Rgb) -> str {
    if _TRUECOLOR {
        return f";38;2;{c.r};{c.g};{c.b}";
    }
    return f";38;5;{rgb_to_256(c.r, c.g, c.b)}";
}

def _bg_frag(c: Rgb) -> str {
    if _TRUECOLOR {
        return f";48;2;{c.r};{c.g};{c.b}";
    }
    return f";48;5;{rgb_to_256(c.r, c.g, c.b)}";
}

def ansi_bg(c: Rgb) -> str {
    if _TRUECOLOR {
        return f"\033[48;2;{c.r};{c.g};{c.b}m";
    }
    return f"\033[48;5;{rgb_to_256(c.r, c.g, c.b)}m";
}

def term_repeat(c: str, n: int) -> str {
    if n <= 0 {
        return "";
    }
    return c * n;
}

def term_spaces(n: int) -> str {
    return term_repeat(" ", n);
}

def term_dashes(n: int) -> str {
    return term_repeat("─", n);
}

def _sgr_attrs(attrs: int) -> list[str] {
    parts: list[str] = ["\033[0"];
    if attrs & 1 != 0 {
        parts.append(";1");
    }
    if attrs & 2 != 0 {
        parts.append(";2");
    }
    if attrs & 4 != 0 {
        parts.append(";3");
    }
    return parts;
}

# Foreground-only span: emits no background, so the text sits on whatever the
# terminal's own background is (pi's model — we never paint a global bg).
def ansi_fg(fg: Rgb, attrs: int) -> str {
    parts = _sgr_attrs(attrs);
    parts.append(_fg_frag(fg));
    parts.append("m");
    return "".join(parts);
}

# Span with an explicit background (selected rows, code blocks, user messages).
def ansi_sgr(fg: Rgb, bg: Rgb, attrs: int) -> str {
    parts = _sgr_attrs(attrs);
    parts.append(_fg_frag(fg));
    parts.append(_bg_frag(bg));
    parts.append("m");
    return "".join(parts);
}
