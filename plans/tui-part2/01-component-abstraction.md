# Plan 1 -- Component abstraction

**Status:** proposal · **Layer:** native (`ai_tui_na`) · **Effort:** L · **Depends on:** --
**Unblocks:** 2 (overlays), 7 (input routing), 6 (custom tool UI)
**Benchmark:** pi `Component{render(width)/handleInput/invalidate}` (`tui/src/tui.ts:64`), opentui `Renderable.render()/renderSelf()/onUpdate()` + `markDirty()`/coalesced `requestRender()` (`core/src/Renderable.ts`).

## 1. Goal

Break the monolithic `screen_render()` into a tree of self-contained **components**,
each owning `render()`, its own dirty/cache state (`invalidate()`), and (Plan 7) its
own `handle_input()`. The current renderer is a single top-down function that reads a
30-field god-object and rebuilds the whole screen each dirty frame.

## 2. Current state

- `jac/jaclang/cli/ai_tui_na/screen.na.jac` -- `screen_render(state: TuiState, cols, rows) -> list[str]` (line 277). Computes section heights, then imperatively assembles `out: list[str]` from ~20 free helpers: `_transcript_section`, `_warn_row`, `_ac_section`, `_divider_row`, `_editor_rows`, `_status_footer_row`, then `overlay_composite`.
- All section state lives on `TuiState` (`state.na.jac:151`): `events`, `display_rows`, `viewport_top`, `follow_tail`, `editor`, `ac`, `select_list`, `overlay_*`, `layout_dirty`, `layout_cols`.
- Caching is ad-hoc and per-concern: `Event.cached_rows`/`cache_text_len`/`cache_width` (feed), `layout_dirty`+`layout_cols` gate `build_rows()`, `_CMD_DEFS_CACHE` in commands.
- `tui_core.tui_render_once` (line 67) gates the whole thing on `state.dirty` and force-invalidates the diff engine on `overlay_full_redraw`.

**Problem:** there is no unit of composition. Adding a panel means editing height math in `screen_render`, adding fields to `TuiState`, and threading a new helper. Nothing owns its own invalidation; the whole screen is "dirty or not."

## 3. Reference design

- **pi** (`tui.ts:64`): `interface Component { render(width): string[]; handleInput?(data): void; invalidate(): void }`. `Container implements Component` holds `children` and concatenates their lines; `invalidate()` fans out. Each concrete component (e.g. `Text`, `text.ts:7`) caches `cachedLines/cachedWidth/cachedText` and clears on `setText()`/`invalidate()`. Cursor is a zero-width APC marker emitted by the focused component and stripped by the root.
- **opentui** (`Renderable.ts`): abstract `render(buffer, dt)` → `renderBefore/renderSelf/renderAfter` then `markClean()`. `requestRender()` sets `_dirty` and **bubbles one coalesced request** to the renderer (N dirty children → 1 frame). Layout generation counter skips unchanged subtrees.

## 4. Target design for native Jac

Native Jac can't express pi's `interface Component` with polymorphic `children: Component[]`
(no vtable dispatch over a heterogeneous list). Use the **tagged-union component** idiom
already proven by `CmdDef{kind}`:

```
enum CompKind { TRANSCRIPT=0, WARN=1, AUTOCOMPLETE=2, EDITOR=3, STATUS=4, OVERLAY=5 }

obj Component {
    has kind: CompKind,
        dirty: bool = True,
        cache_cols: int = -1,
        cached: list[str] = [],
        height: int = 0;          # last computed height, for layout

    # single dispatch method -- hand-written branch, NOT virtual
    def render(state: TuiState, cols: int, height: int) -> list[str] {
        if not self.dirty and self.cache_cols == cols and len(self.cached) == height {
            return self.cached;
        }
        rows: list[str] = [];
        if self.kind == CompKind.TRANSCRIPT { rows = _render_transcript(state, cols, height); }
        elif self.kind == CompKind.AUTOCOMPLETE { rows = _render_ac(state, cols, height); }
        elif self.kind == CompKind.EDITOR { rows = _render_editor(state, cols, height); }
        elif self.kind == CompKind.STATUS { rows = _render_status(state, cols); }
        elif self.kind == CompKind.WARN { rows = _render_warn(state, cols); }
        self.cached = rows;
        self.cache_cols = cols;
        self.dirty = False;
        return rows;
    }

    def invalidate { self.dirty = True; self.cache_cols = -1; self.cached = []; }
}
```

- The existing section helpers in `screen.na.jac` become the `_render_*` bodies (mostly a rename + moving the height math in). Minimal behavior change.
- A `Screen` container holds a fixed `list[Component]` in draw order plus the height solver:

```
obj Screen {
    has transcript: Component = Component(kind=CompKind.TRANSCRIPT),
        warn: Component = Component(kind=CompKind.WARN),
        ac: Component = Component(kind=CompKind.AUTOCOMPLETE),
        editor: Component = Component(kind=CompKind.EDITOR),
        status: Component = Component(kind=CompKind.STATUS);

    def layout(state: TuiState, cols: int, rows: int) -> ScreenLayout;   # the height math from screen_render 282-289
    def render(state: TuiState, cols: int, rows: int) -> list[str];      # calls each child .render, stacks lines
    def invalidate_all;                                                  # theme change / resize
}
```

Named fields (not a `list[Component]`) keep every `.render()` call statically bound to a
concrete `Component` -- dispatch stays inside the one `if self.kind` chain, which is the
only indirection and it's static.

**Invalidation wiring** (replaces the single `state.dirty`):

- `TuiState` mutators that today set `dirty=True` gain a targeted invalidator. e.g.
  `upsert_event`/`append_to_event` → `screen.transcript.invalidate()`; `ac.*` →
  `screen.ac.invalidate()`; editor edits → `screen.editor.invalidate()`; status fields
  (`status`,`active`,`model_name`) → `screen.status.invalidate()`.
- Keep a coalesced top-level `state.dirty` (opentui's model): any child invalidation also
  sets `state.dirty=True`, so `tui_render_once` still short-circuits when clean, but
  `Screen.render` only rebuilds the children that were invalidated. This is a strict
  perf improvement over "rebuild everything on any change" and preserves the existing diff-paint.
- `cols` change → `Screen.invalidate_all()` (mirrors current `layout_dirty` on width change).

## 5. File-by-file changes

- **New** `ai_tui_na/component.na.jac` -- `enum CompKind`, `obj Component`, `obj ScreenLayout`, `obj Screen`. Imports the `_render_*` free functions.
- **`screen.na.jac`** -- keep the `_render_*` helpers (renamed from `_transcript_section` etc.), delete the monolithic `screen_render`; its height math moves to `Screen.layout`. Overlay compositing (`overlay_build_modal`/`overlay_composite`) moves under `Screen.render` (or Plan 2's overlay stack).
- **`state.na.jac`** -- add `screen: Screen = Screen()` to `TuiState` (or hold `Screen` in `TuiRuntime`, see note). Change `mark_layout_dirty` and the event/scroll mutators to call targeted `screen.*.invalidate()`.
- **`tui_core.na.jac`** -- `tui_render_once` calls `rt.screen.render(state, cols, rows)` instead of `screen_render(...)`.
- **`runtime.na.jac`** -- decision: put `Screen` on `TuiRuntime` (cleaner separation from serializable state) rather than `TuiState`. `TuiRuntime` already holds `diff`, `paint_buf`, `transport`; add `screen: Screen`.

## 6. Phased implementation

1. **Extract without behavior change** -- introduce `Component`/`Screen`, move the section
   helpers, make `Screen.render` reproduce `screen_render` byte-for-byte (all children always
   dirty). Verify identical output via the golden test below. *This is the risky, high-value step.*
2. **Targeted invalidation** -- wire per-child `invalidate()` into `TuiState` mutators; flip
   children to cache. Verify no stale-frame regressions on scroll/stream/resize.
3. **Cursor as marker (optional, enables Plan 7)** -- adopt pi's zero-width APC cursor marker so
   the editor component emits its own cursor position instead of `screen_render` computing it
   globally. Lets the editor become a focusable component.

## 7. NA constraints & risks

- **No `list[Component]` with virtual render.** Enforced by named fields + `if self.kind` dispatch. Do not refactor to a loop over a polymorphic list.
- **Method call on `Component | None`** must never happen -- `Screen` holds concrete non-optional children.
- **Header-offset write bug**: `Component.dirty`/`cache_cols` are written via methods (`invalidate`, inside `render`) -- safe. Never write `comp.cached = ...` from outside a method on a nested/derived obj.
- **Comment-strip lint** on core `.na.jac`: keep the `#` design comments out of the shipped bodies or they'll be stripped by CI (`jaseci deslop lint policy`); put rationale in this plan, not the source.
- Behavioral risk is concentrated in step 1 (the extraction). Height math (`screen_render:282-289`) is fiddly (`transcript_h = rows - 1 - editor_h - ac_h - 1`, warn steals a row) -- port it verbatim into `Screen.layout`.

## 8. Testing / verification

- **Golden render test** (native): construct a `TuiState` with a fixed event list + editor
  contents at several `(cols, rows)` and assert `Screen.render(...)` equals the pre-refactor
  `screen_render(...)` output. Capture the baseline before touching anything.
- Drive the live TUI (`.venv/bin/python -m jaclang ... jac ai --tui`, stub agent) and exercise:
  stream a long answer (transcript cache + follow-tail), open autocomplete, resize the terminal,
  toggle the missing-key warning. Wait ≥45s for embed boot (cache warmth caveat).
- Assert frame count / diff-paint size drops after step 2 (fewer rebuilt children).

## 9. Out of scope / follow-ups

- True dynamic child lists (needed only if Plan 6 wants arbitrary extension panels) -- defer to
  a Python-side render escape hatch, not native.
- Flexbox-style layout (opentui/Yoga) is overkill; the fixed vertical stack is sufficient.
