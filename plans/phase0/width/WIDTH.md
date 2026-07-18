# Display-width classification (Phase 0)

Independent of golden byte equality. Production functions:
`visible_width`, `ansi_trunc`, `ansi_pad` in
`jac/jaclang/cli/ai_tui_na/width.na.jac`.

## Rules

1. Every non-image transcript/editor/status/overlay row must fit the supplied
   display-cell width after styling.
2. ANSI/CSI/OSC/APC sequences contribute **zero** cells.
3. ASCII printables (0x20–0x7E) contribute 1 cell.
4. UTF-8 multibyte sequences currently contribute **1 cell each** in
   `visible_width` (no East-Asian wide-table yet). Document this as known
   limitation; CJK/emoji goldens that assume width=2 are **invalid** under the
   current algorithm and must not block Phase 1.
5. `ansi_trunc` reserves one cell for `~` when truncating.

## Case table (executable via `width_probe.na.jac`)

| id | input (conceptual) | width arg | expect |
|---|---|---|---|
| W1 | `""` | -- | `visible_width=0` |
| W2 | `abc` | -- | `3` |
| W3 | `a\x1b[31mb\x1b[0mc` | -- | `3` |
| W4 | `hello` | trunc 3 | `he~` (vw=3) |
| W5 | `hi` | pad 5 | `hi` + 3 spaces |
| W6 | emoji `😀` | -- | `1` under current algo |
| W7 | combining / OSC-8 | -- | escapes skipped; payload cells counted |

## Golden classification

Run goldens through width checks before regenerating:

| Class | Meaning | Action |
|---|---|---|
| valid | every non-image line `visible_width(line) <= cols` | keep |
| invalid-narrow | line exceeds cols at fixture size | fix renderer or golden intentionally |
| invalid-wide-assumption | expects wcwidth=2 for emoji/CJK | document; do not “fix” by widening algo casually |

`test_tui_render_golden.jac` remains byte-exact. Phase 0 adds
`plans/phase0/width/width_probe.na.jac` as the independent invariant suite.
