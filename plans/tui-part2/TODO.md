# TODO -- TUI Part 2

## Reference plan overview

| File                        | Covers                                                                                                         |
| --------------------------- | ------------------------------------------------------------------------------------------------------------- |
| INDEX.md                    | The two-layer topology, the cross-cutting NA constraint (no vtables/HOFs → tagged-union dispatch), recommended sequencing (Phase A/B/C), and a per-reference "what to steal" cheat-sheet |
| 01-component-abstraction.md | Split screen_render() into a Component{kind}/Screen tree with per-child invalidate()                          |
| 02-overlay-system.md        | OverlayStack of anchor+%-sized, focus-restoring overlays replacing the 3 hardcoded OverlayKinds               |
| 03-session-persistence.md   | pi-style append-only JSONL session tree with parent_id branching/fork/rewind                                  |
| 04-python-sdk.md            | create_agent_session() factory + Agent handle; refactor the global singleton to an instance                   |
| 05-theme-system.md          | Palette→Theme resolver, de-baking TH_BG, runtime /theme switching                                             |
| 06-extension-tool-model.md  | register_tool/ExtensionAPI/ctx.ui_custom, with custom UI as line-shipping over IPC                            |
| 07-input-routing.md         | Focus-target routing replacing the global key ladder; globals-first                                           |
| 08-typed-event-system.md    | Discriminated events + forward-compatible key-based wire protocol v2                                          |
| 09-subagents-workflows.md   | task tool = permission-narrowed child session; fan-out/chain/background                                       |
| 10-retry-compaction.md      | Backoff auto-retry + threshold/overflow compaction + session_before_compact hook                              |

## Checklist

- [ ] INDEX.md -- sequencing, NA constraint, cheat-sheet
- [x] 01-component-abstraction.md -- landed as a cache-free `Screen` composer (the `Component{kind,cached}` row-cache was dropped: redundant with `DiffEngine`, source of the Phase-2 SIGSEGV). `Screen`/`ScreenLayout` live in `screen.na.jac`; golden 10/10 byte-identical.
- [~] 02-overlay-system.md -- Phase 1 (1-deep `OverlayStack`, behavior-preserving) + Phase 2 (`Anchor` + `width_pct` geometry via `_anchor_place`) DONE, golden 12/12 (10 baseline byte-identical + `overlay_bottom`/`overlay_half` proving placement). Remaining: Phase 3 (CONFIRM/TEXT content types + depth-2 stacking) and Phase 4 (CUSTOM), both gated on Plan 7 focus.
- [ ] 03-session-persistence.md
- [ ] 04-python-sdk.md
- [ ] 05-theme-system.md
- [ ] 06-extension-tool-model.md
- [ ] 07-input-routing.md
- [ ] 08-typed-event-system.md
- [ ] 09-subagents-workflows.md
- [ ] 10-retry-compaction.md
