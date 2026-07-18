# Plan 7 -- Input routing to the focused component

**Status:** proposal · **Layer:** native (`ai_tui_na`) · **Effort:** M · **Depends on:** 1
**Unblocks:** 2 (overlay focus stacking)
**Benchmark:** pi single `focusedComponent` pointer + `handleInput(data)` dispatch (`tui.ts:761,832`); opentui focused-node key subscription with `stopPropagation()/preventDefault()` and `emitWithPriority` (globals → focused) (`Renderable.ts:414`, `KeyHandler.ts:134`).

## 1. Goal

Replace the single global priority ladder in `handle_key()` with routing to a **currently
focused component**, so each component interprets its own keys. Today input is a fixed
mode cascade; adding a focusable panel (or Plan 2's stacked overlays) means editing the
central ladder.

## 2. Current state

`ai_tui_na/input.na.jac` -- `handle_key(k: Key, rt) -> bool` (line 281) is a hardcoded
priority router:

```
if k.kind == UNKNOWN: return False
if overlay_is_active(state): return overlay_handle_key(k, rt)   # overlay wins
if state.ac.active: return _handle_ac_key(k, rt)                # autocomplete
if k.kind == CTRL: return _handle_ctrl_key(k, rt)              # ctrl chords
if _handle_movement_key(k, rt): return False                   # cursor/scroll
return _handle_edit_key(k, rt)                                 # text edit
```

Focus is **implicit**: whoever is "active" (overlay flag, `ac.active`) intercepts. `keys.na.jac`
turns raw bytes into `Key{kind: KeyKind, code: int}` via `parse_key` (table + `if`). Global
chords (`^C/^Q` quit, `^G` stop, `^R` reset, `^O` palette) are checked inside `_handle_ctrl_key`.

## 3. Reference design

- **pi**: no central switch. `handleInput(data)` runs input listeners, one global debug key,
  overlay-focus reconciliation, then dispatches the bytes to `this.focusedComponent.handleInput(data)`.
  Focus is a single pointer moved by `setFocus`. Overlays capture focus by being pushed on a stack.
- **opentui**: focused node subscribes its own key handler; `emitWithPriority` fires **global
  listeners first**, then the focused renderable, honoring `propagationStopped`/`defaultPrevented`
  between handlers. Mouse events bubble child→parent (stoppable); keys do not bubble.

## 4. Target design for native Jac

Keep the tagged-union discipline. Introduce an explicit **focus target enum** and a
per-component input dispatch -- the mirror of Plan 1's `Component.render`:

```
enum Focus { EDITOR=0, TRANSCRIPT=1, AUTOCOMPLETE=2, OVERLAY=3 }

# on TuiState (or Screen): the focus pointer + overlay focus stack (Plan 2)
has focus: Focus = Focus.EDITOR;

def handle_key(k: Key, rt: TuiRuntime) -> bool {
    state = rt.state;
    if k.kind == KeyKind.UNKNOWN { return False; }

    # 1. global chords, always first (opentui "global listeners first")
    if _handle_global_key(k, rt) { return _global_wants_quit(k); }

    # 2. route to focused target (static branch, not virtual)
    f = _effective_focus(state);   # overlay-active → OVERLAY; ac.active → AUTOCOMPLETE; else state.focus
    if f == Focus.OVERLAY { return overlay_handle_key(k, rt); }
    if f == Focus.AUTOCOMPLETE { return _handle_ac_key(k, rt); }
    if f == Focus.TRANSCRIPT { return _handle_transcript_key(k, rt); }
    return _handle_editor_key(k, rt);   # editor = ctrl-edit + movement + edit merged
}
```

Notes:

- `_effective_focus` preserves today's precedence (overlay > autocomplete > base) but makes it
  **data**, not control flow. This is the smallest step that turns the ladder into routing and is
  the foundation Plan 2 needs (overlay stack sets/clears `Focus.OVERLAY`).
- **Global keys** (`^C/^Q/^G/^R/^O`, and later a debug key) split out of `_handle_ctrl_key` into
  `_handle_global_key`, matching opentui's "globals fire first regardless of focus." The remaining
  emacs edits (`^A/^E/^K/^U/^W`) stay editor-local in `_handle_editor_key`.
- **Consumed flag**: the current mix of `-> bool` (quit) and side-effect returns is confusing.
  Standardize each component key handler on returning a small result -- reuse the `bool` (quit) for
  now, but consider `enum KeyResult { IGNORED, CONSUMED, QUIT }` so a focus target can decline a key
  and let a fallback handle it (opentui's `stopPropagation` analogue). Editor→history-nav already
  needs this ("UP consumed only if on first vline").
- **Transcript focus** becomes real: today PgUp/PgDn/mouse-scroll are handled inside
  `_handle_movement_key`/`_handle_edit_key` regardless of focus. With a `Focus.TRANSCRIPT` target,
  scroll keys route there explicitly, enabling e.g. a future "scroll mode" without stealing typing.

## 5. File-by-file changes

- **`input.na.jac`** -- rewrite `handle_key` as router; split `_handle_global_key`; merge
  `_handle_ctrl_key`(edits) + `_handle_movement_key` + `_handle_edit_key` into `_handle_editor_key`;
  add `_handle_transcript_key` (scroll/pgup/pgdn extracted). Add `_effective_focus`.
- **`state.na.jac`** -- add `focus: Focus = Focus.EDITOR`; add a `set_focus(f)` method (mutate via
  method to dodge the header-offset write bug). Keep `overlay_active`/`ac.active` as the precedence
  inputs to `_effective_focus` (or, in Plan 2, fold them into the focus stack).
- **`keys.na.jac`** -- unchanged (still produces `Key`), unless adopting `KeyResult`.
- **`overlay.na.jac`** -- `overlay_open_*`/`overlay_close` also set/clear focus (Plan 2 formalizes this).

## 6. Phased implementation

1. **Refactor to router, behavior-preserving** -- `_effective_focus` reproduces the exact current
   precedence; split globals out. No user-visible change. Verify against a key-sequence golden test.
2. **Editor as a real focus target** -- merge the three editor sub-handlers, adopt `KeyResult` so
   history-nav / scroll decline cleanly.
3. **Transcript focus** -- route scroll keys through `Focus.TRANSCRIPT`; add a key to toggle
   editor↔transcript focus (e.g. `Esc` when editor empty, or `^↑`). Optional.

## 7. NA constraints & risks

- No `dict[KeyKind, handler]` -- dispatch stays `if`-chains (matches existing `keys.na.jac` style).
- `state.focus` written only through `set_focus()` (header-offset safety).
- Precedence bugs are the main risk: overlay and autocomplete currently short-circuit *before*
  ctrl/edit. `_effective_focus` must keep `^C` working while an overlay is open -- that's why
  globals are checked *before* focus routing (step 1), a deliberate change from today where `^C`
  inside an overlay is swallowed by `overlay_handle_key`. Confirm this is desired (recommend yes).
- Interaction with Plan 1: focus routing and the component tree share the same `CompKind`/`Focus`
  vocabulary -- land Plan 1 first so `handle_input` can live on components later if desired.

## 8. Testing / verification

- **Key-sequence golden test**: feed a scripted `list[Key]` through `handle_key` against a fixed
  state and assert the resulting `TuiState`/editor/`cmd_queue` matches the pre-refactor handler.
  Cover: typing, `^A/^E/^K`, arrow history-nav, PgUp/PgDn, open/navigate/select an overlay, autocomplete
  tab/enter, `^C` quit (from base and from overlay-open).
- Live drive with the stub agent; verify no regressions in editing, scrolling, palette, `@file`.

## 9. Out of scope / follow-ups

- Per-component `handle_input()` methods (pushing dispatch onto `Component` like pi) -- nice, but the
  free-function `_handle_*` form is fine and keeps calls static. Revisit only if Plan 6 needs
  focusable extension panels.
- Mouse bubbling (opentui) -- current mouse handling is scroll-only; no tree hit-testing needed yet.
