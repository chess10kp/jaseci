"""Native unit tests for markdown rendering (markdown.na.jac)."""

import from .markdown { md_render }
import from .terminal { Rgb }
import from .width { visible_width }
import from .libc_tty { tty_write }


def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

def _plain(line: str) -> str {
    out: str = "";
    i: int = 0;
    n = len(line);
    while i < n {
        if line[i] == "\x1b" {
            i += 1;
            while i < n and line[i] != "m" {
                i += 1;
            }
            i += 1;
            continue;
        }
        out = out + line[i];
        i += 1;
    }
    return out;
}

def _all_fit(lines: list[str], width: int) -> bool {
    for line in lines {
        if visible_width(line) > width {
            return False;
        }
    }
    return True;
}

with entry {
    color = Rgb(r=200, g=200, b=200);
    width: int = 60;

    h1 = md_render("# Title\n", width, color, 0);
    _check("heading_h1", len(h1) >= 1 and "Title" in _plain(h1[0]));
    _check("heading_h1_width", _all_fit(h1, width));

    ul = md_render("- one\n- two\n", width, color, 0);
    plain_ul = "".join(_plain(ln) for ln in ul);
    _check("unordered_list", "one" in plain_ul and "two" in plain_ul);
    _check("unordered_width", _all_fit(ul, width));

    fence = md_render("```py\nprint(1)\n```\n", width, color, 0);
    plain_fence = "".join(_plain(ln) for ln in fence);
    _check("code_fence", "```" in plain_fence and "print(1)" in plain_fence);
    _check("fence_width", _all_fit(fence, width));

    bold = md_render("**bold** text\n", width, color, 0);
    _check("inline_bold", "bold" in _plain(bold[0]) and "text" in _plain(bold[0]));

    hr = md_render("---\n", width, color, 0);
    hr_plain = "".join(_plain(ln) for ln in hr);
    _check("horizontal_rule", "---" in hr_plain or "─" in hr_plain or "-" in hr_plain);

    bq = md_render("> quoted\n", width, color, 0);
    plain_bq = _plain(bq[0]);
    _check("blockquote", "quoted" in plain_bq);
    _check("blockquote_width", _all_fit(bq, width));

    ol = md_render("1. first\n2. second\n", width, color, 0);
    plain_ol = "".join(_plain(ln) for ln in ol);
    _check("ordered_list", "first" in plain_ol and "second" in plain_ol);

    long_para = md_render(
        "This is a long paragraph that should wrap across multiple display rows "
        "when the terminal width is narrow enough to force wrapping behavior.",
        width,
        color,
        0
    );
    _check("wrap_multiple_lines", len(long_para) >= 2);
    _check("wrap_width", _all_fit(long_para, width));
}
