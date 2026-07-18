# Plan 5 -- Theme system

**Status:** proposal · **Layer:** native (`ai_tui_na`), small IPC touch · **Effort:** M · **Depends on:** --
**Benchmark:** pi semantic tokens → precomputed ANSI, `theme.fg(token,text)`, JSON themes with `vars` refs + `onThemeChange`/`invalidate` (`modes/interactive/theme/theme.ts`); opencode `resolveTheme(json, mode)` with named `defs` refs, `{dark,light}` pairs, cycle detection (`tui/src/theme/index.ts:241`).

## 1. Goal

Replace the fixed dark palette of hardcoded RGB constants with **semantic tokens** resolved
through a theme object, so the TUI can ship multiple themes (dark/light/high-contrast), adapt
to the terminal, and let users pick one at runtime. Today every color is a compile-time constant
with `TH_BG` baked into every SGR string.

## 2. Current state

`ai_tui_na/theme.na.jac`:

- ~40 `glob TH_* : Rgb = Rgb(r=,g=,b=)` constants -- semantically **named** already
  (`TH_USER`, `TH_ERROR`, `TH_PHASE`, `TH_MD_H1`, …) but **fixed values, single theme**.
- ~30 precomputed `glob TH_SGR_* : str = ansi_sgr(fg, TH_BG, attrs)` escape strings, built once at
  module load. **`TH_BG` is hardcoded into every foreground SGR** -- no runtime background swap.
- Attributes are int bitflags (`TH_BOLD=1`, `TH_DIM=2`, `TH_ITALIC=4`).
- Consumers import the `TH_SGR_*` constants directly (`screen.na.jac`, `overlay.na.jac`,
  `feed.na.jac`, `markdown.na.jac`, `state.kind_style`). `kind_style` returns raw `Rgb` colors and
  callers do `ansi_sgr(s.color, TH_BG, s.attrs)`.

**Problem:** a theme is a set of `glob` constants resolved at compile time. No selection, no
light mode, no user override. The `TH_BG`-baked SGRs mean even swapping the background is invasive.

## 3. Reference design

- **pi/opencode**: a theme is a **flat map of ~60 semantic tokens** (`accent`, `border`, `error`,
  `mdHeading`, `syntaxKeyword`, backgrounds, per-thinking-level borders). On-disk JSON; a value may be
  a hex, an ANSI index, a named ref into `defs`/`vars`, or a `{dark,light}` pair. `resolveTheme(json,mode)`
  resolves refs (cycle-detected), picks truecolor vs 256-color from terminal caps, and **precomputes ANSI
  strings into maps**. Components call `theme.fg("accent", text)`; sub-toolkits get adapter maps
  (`getMarkdownTheme()` etc.). `onThemeChange` → components `invalidate()` and re-render.

## 4. Target design for native Jac

Keep pi's shape but resolve at **startup**, not per-call, and stay within NA (no dynamic token maps in
the hot path -- resolve once into a struct of concrete SGR strings).

```
# a palette is the set of raw colors (what varies between themes)
obj Palette {
    has bg: Rgb, border: Rgb, user: Rgb, answer: Rgb, reason: Rgb, system: Rgb,
        logo: Rgb, error: Rgb, phase: Rgb, call: Rgb, result: Rgb, title: Rgb, cwd: Rgb,
        model: Rgb, ac_sel_bg: Rgb, ac_sel_desc: Rgb, ac_desc: Rgb, status_ok: Rgb,
        md_h1: Rgb, md_h2: Rgb, md_h3: Rgb, md_code: Rgb, md_code_bg: Rgb, /* … */ ;
}

# the resolved theme = precomputed SGR strings (what today's TH_SGR_* globals are)
obj Theme {
    has sgr_border: str, sgr_user_msg: str, sgr_error: str, sgr_phase: str, /* … all TH_SGR_* … */,
        bg: Rgb;   # kept for the few call sites that need raw bg
    def fg(color: Rgb, attrs: int) -> str;   # ansi_sgr(color, self.bg, attrs) -- replaces bare TH_BG use
}

def build_theme(p: Palette) -> Theme;        # the current module-load computation, parameterized
def palette_dark -> Palette;                 # today's values
def palette_light -> Palette;                # new
def palette_by_name(name: str) -> Palette;   # "dark"|"light"|"high-contrast"
```

- The current `glob TH_SGR_*` become **fields of a single `Theme` instance** built by `build_theme(palette)`.
- Hold the active `theme: Theme` on `TuiRuntime` (or a module-level `glob active_theme` set once at
  startup). Consumers change from `import { TH_SGR_BORDER }` to `rt.theme.sgr_border` -- a mechanical
  but wide edit across `screen/overlay/feed/markdown`.
- `kind_style` keeps returning raw `Rgb`; callers use `theme.fg(color, attrs)` instead of
  `ansi_sgr(color, TH_BG, attrs)` -- this is what unblocks a non-fixed background.
- **Runtime switching**: a `/theme <name>` command (Plan 6-style, but trivial standalone) sets
  `rt.theme = build_theme(palette_by_name(name))` and calls `screen.invalidate_all()` (Plan 1) or
  `diff.invalidate()` + `state.dirty=True`. Persist the choice via settings (Plan 4/3) or an env var.
- **Terminal adaptation (optional)**: query terminal background via OSC 11 at startup (opentui does
  this) to auto-pick dark/light. Native OSC round-trip is more work; gate behind an env/flag initially.

## 5. File-by-file changes

- **`theme.na.jac`** -- introduce `Palette`, `Theme`, `build_theme`, `palette_dark`/`palette_light`;
  keep `Rgb`, `ansi_sgr`, attr flags. The `TH_SGR_*` globals either (a) become a default
  `glob DEFAULT_THEME: Theme = build_theme(palette_dark())` for a low-churn migration, or (b) are
  deleted in favor of `rt.theme.*`. Recommend (a) first, (b) later.
- **`runtime.na.jac`** -- add `theme: Theme` to `TuiRuntime`, initialized from settings/env.
- **`screen.na.jac`, `overlay.na.jac`, `feed.na.jac`, `markdown.na.jac`, `tool_block.na.jac`** --
  swap `TH_SGR_*` reads for `rt.theme.*` (thread `theme` where these are free functions -- they mostly
  already receive `state`; pass `theme` alongside or read `state`-held theme).
- **`commands.na.jac`** -- `/theme` command lists palettes and applies.
- **IPC (small)** -- surface the resolved theme name in the status line / settings; optionally accept a
  theme name from the Python settings (`ui_apply_settings`) so it persists with other config.

## 6. Phased implementation

1. **Parameterize, one theme** -- `Palette`/`Theme`/`build_theme`; `DEFAULT_THEME = build_theme(palette_dark())`;
   redefine the `TH_SGR_*` globals as fields of `DEFAULT_THEME`. Zero visual change. Verify golden render identical.
2. **Second theme + runtime swap** -- add `palette_light`, `/theme` command, `invalidate_all` on swap.
3. **De-globalize** -- migrate call sites to `rt.theme.*`, remove the `TH_SGR_*` globals; thread `theme`
   through the render functions. (Largest mechanical diff; do after Plan 1 so `Screen` can carry `theme`.)
4. **Terminal auto-detect (optional)** -- OSC 11 background probe → auto dark/light.

## 7. NA constraints & risks

- `Theme` is a flat struct of precomputed `str` fields -- **no `dict[str, str]` token map in the hot
  path** (keeps lookups static and avoids per-frame dict access). Token→field is resolved at author time.
- `Theme`/`Palette` fields written only in `build_theme` (construction) -- no external field writes
  (header-offset safety).
- Wide but mechanical churn in step 3 -- every colored draw site. Keep step 1 truly no-op to de-risk.
- `chr`/NUL and binary caveats don't apply (all text SGR strings).
- Keep design comments out of shipped `.na.jac` (comment-strip lint).

## 8. Testing / verification

- Golden render test: dark theme output identical pre/post step 1.
- Snapshot each theme at a fixed state; eyeball light/high-contrast for legibility.
- Live: `/theme light` mid-session repaints correctly (full redraw), status line reflects the name,
  choice persists across restart if wired to settings.

## 9. Out of scope / follow-ups

- User-authored JSON themes on disk (pi/opencode) -- possible later via the Python host reading a JSON
  file and shipping a resolved `Palette` over IPC at boot; native stays palette-struct-based.
- Syntax-highlight token palette for code fences -- extend `Palette` when markdown syntax coloring lands.
