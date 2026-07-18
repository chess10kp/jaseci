# Plan 2 -- Extensible overlay system

**Status:** proposal · **Layer:** native (`ai_tui_na`) · **Effort:** M · **Depends on:** 1, 7
**Unblocks:** 6 (`ctx.ui.custom` extension overlays)
**Benchmark:** pi anchor + `%`-size overlay **stack** with `preFocus` restore and 9 anchors (`tui.ts:127,171,493,905`); opencode `dialog.tsx` focus-restoring modal stack at high zIndex; claurst pure geometry (`centered_rect`, `ModalLayout`, `render_dark_overlay`, `overlays.rs`).

## 1. Goal

Replace the 3 hardcoded, always-centered overlay kinds with a small **overlay stack** of
generic, anchor-positioned, percentage-sizable overlays that manage focus save/restore --
so new modals (settings dialog, file picker, confirmation, extension UI) are data, not new
enum arms + `if` branches.

## 2. Current state

- `enum OverlayKind { PALETTE=0, MODEL=1, FILE=2 }` (`state.na.jac:96`). Exactly three, all
  backed by one shared `state.select_list`, all centered.
- `overlay.na.jac`: `overlay_open_palette/model/file` each call `_overlay_show(kind, title, items, filter)`;
  `overlay_handle_key` switches on `state.overlay_kind` for the on-select action
  (`MODEL`→apply_model, `FILE`→insert `@file`, else `command_dispatch`).
- Rendering: `_modal_width` (clamp to `_MODAL_MAX_W=64`), `_frame_box`, `_center_rows` (always
  centered), `overlay_composite` (paint non-empty modal lines over base). Single overlay only --
  `state.overlay_active: bool`, no stack.
- Full-redraw on open/close via `state.overlay_full_redraw` → `diff.invalidate()`.

**Problem:** every new overlay is a new `OverlayKind` + a branch in `overlay_handle_key` + a new
`overlay_open_*`. No stacking (can't open a confirm over the palette), no anchoring, no reusable
content other than the shared select list.

## 3. Reference design

- **pi** (`tui.ts`): `showOverlay(component, options)` pushes `{component, options, preFocus, focusOrder}`
  onto `overlayStack`. `OverlayOptions`: `anchor` (9 values), `width/minWidth/maxHeight` as
  `number | "${n}%"`, `offsetX/Y`, absolute `row/col`, `visible(w,h)` predicate, `nonCapturing`.
  `resolveOverlayPosition` parses `%` against terminal size, resolves anchor row/col, clamps. Focus:
  each entry records `preFocus`; a restore state machine re-focuses the right target on hide.
- **opencode** `dialog.tsx`: store `{stack, size}`, `push(el, onClose)`, captures + blurs previous
  focus, shows `stack.at(-1)` at `zIndex 3000`, `refocus()` verifies the saved node still exists.
- **claurst** `overlays.rs`: `centered_rect(w,h,area)`, `struct ModalLayout{dialog,inner,header,body,footer}`,
  `render_dark_overlay()` backdrop -- pure math, no manager. Good template for the native geometry fns.

## 4. Target design for native Jac

A **content-typed overlay** (tagged union, same idiom as `CmdDef`) placed by an **anchor+size spec**,
held in a small **stack**. No polymorphic component list.

```
enum OverlayContent { SELECT_LIST=0, TEXT=1, CONFIRM=2, FORM=3, CUSTOM=4 }
enum Anchor { CENTER=0, TOP=1, BOTTOM=2, TOP_LEFT=3, TOP_RIGHT=4, BOTTOM_LEFT=5, BOTTOM_RIGHT=6, LEFT=7, RIGHT=8 }

obj OverlaySpec {
    has content: OverlayContent = OverlayContent.SELECT_LIST,
        anchor: Anchor = Anchor.CENTER,
        width_pct: int = 0,      # 0 => auto (current _modal_width); else % of cols
        max_h_pct: int = 0,      # 0 => auto
        offset_x: int = 0,
        offset_y: int = 0,
        title: str = "",
        # per-content payload (only the relevant one is used):
        role: OverlayKind = OverlayKind.PALETTE,   # keeps existing select-list on-select routing
        prev_focus: Focus = Focus.EDITOR;          # Plan 7: restore target on close
}

obj OverlayStack {
    has entries: list[OverlaySpec] = [];
    def push(spec: OverlaySpec);       # sets prev_focus from current, marks full redraw
    def pop -> bool;                   # restores prev_focus, returns emptied?
    def top -> OverlaySpec | None;
    def is_active -> bool;             # len(entries) > 0
}
```

- **Geometry** -- port claurst's helpers as native free functions: `_anchor_rect(anchor, modal_w, modal_h, cols, rows, ox, oy) -> (start_row, start_col)` replaces the always-centered `_center_rows`; `_center_rows` becomes the `Anchor.CENTER` case. `%` sizing: `modal_w = cols*width_pct//100` when `width_pct>0` else current auto clamp.
- **Rendering the stack** -- composite bottom-to-top: for each entry, build its box (`_frame_box` unchanged) at its anchor and `overlay_composite` onto the accumulator. (pi/opencode only render the top; a stack render lets a small confirm sit over a dimmed palette -- optional, start with top-only to match current behavior.)
- **Content dispatch** -- `overlay_build_modal` switches on `top.content`: `SELECT_LIST` → existing `select_list.render` path; `TEXT` → wrapped static text; `CONFIRM` → message + `[Enter] yes / [Esc] no`; `CUSTOM` → Plan 6 (Python-provided pre-rendered lines shipped over IPC). `overlay_handle_key` switches on `top.content` first, then (for `SELECT_LIST`) on `top.role` -- preserving today's `MODEL/FILE/PALETTE` on-select logic verbatim.
- **Focus** -- integrates with Plan 7: `push` sets `state.focus = Focus.OVERLAY` and stores the prior focus in `spec.prev_focus`; `pop` restores it. `_effective_focus` returns `OVERLAY` iff `overlay_stack.is_active()`.

## 5. File-by-file changes

- **New** `ai_tui_na/overlay_geom.na.jac` -- `enum Anchor`, `_anchor_rect`, `%`-resolution helpers (claurst-style, pure).
- **`overlay.na.jac`** -- introduce `OverlayContent`, `OverlaySpec`, `OverlayStack`; rewrite
  `overlay_open_*` to `push(OverlaySpec(content=SELECT_LIST, role=..., title=...))`; keep
  `_overlay_show` as the select-list payload initializer; `overlay_handle_key` reads `stack.top`;
  `overlay_close` → `stack.pop`; `overlay_build_modal` renders `stack.top` at its anchor.
- **`state.na.jac`** -- replace `overlay_active/overlay_kind/overlay_title/overlay_filter` scalars with
  `overlay_stack: OverlayStack = OverlayStack()` (keep `overlay_full_redraw`). `OverlayKind` stays as
  the select-list *role* discriminator.
- **`screen.na.jac`** -- `if state.overlay_stack.is_active()` gate instead of `overlay_active`.
- **`commands.na.jac`** -- new modals become `push(OverlaySpec(...))` calls; e.g. a `/settings` form,
  a quit-confirm.

## 6. Phased implementation

1. **Stack of one, behavior-preserving** -- replace the scalars with a 1-deep `OverlayStack`; keep
   center anchor + auto width. Palette/model/file work identically. Verify golden modal output.
2. **Anchor + %-size** -- add `_anchor_rect` and `width_pct/max_h_pct`; migrate nothing (all default
   to center/auto) but prove a non-center overlay (e.g. a bottom-anchored toast) renders correctly.
3. **New content types** -- `CONFIRM` (quit confirmation, replace the bare `^C`), `TEXT` (help/about).
   True depth-2 stacking (confirm over palette) once compositing is verified.
4. **`CUSTOM`** -- reserved for Plan 6: Python extension supplies overlay lines + captures keys via IPC.

## 7. NA constraints & risks

- `stack.top -> OverlaySpec | None`: **method call on the `| None` result is silently dropped** --
  callers must rebind: `t = stack.top(); if t is None { return; }` then use `t`. Enforce in review.
- All `OverlaySpec`/`OverlayStack` field writes through methods (`push/pop`), never external field
  writes on the nested spec (header-offset bug).
- Depth-N compositing cost: each overlay re-composites all `rows`. Fine for ≤3 overlays; the
  `overlay_full_redraw` → `diff.invalidate()` path already forces a full paint on open/close.
- Keep the existing `_MODAL_MAX_W=64`, small-terminal `_LIST_ROWS_SMALL` logic as the auto defaults.

## 8. Testing / verification

- Golden tests: render palette / model / file overlays before vs after step 1 -- identical.
  Render a bottom-anchored and a 50%-width overlay; assert placement math.
- Live: open palette → open confirm over it → Esc pops confirm back to palette → Esc closes;
  verify focus returns to the editor with cursor intact (Plan 7 restore).
- `^C` while an overlay is open still quits (Plan 7 globals-first).

## 9. Out of scope / follow-ups

- Backdrop dimming (claurst `render_dark_overlay`) -- cosmetic; add later.
- Draggable/resizable overlays -- not a terminal concern.
- Arbitrary extension-driven interactive overlays land in Plan 6 via `CUSTOM`.
