# Idiomatic Jac -- Style Skill

A style reference distilled from the `ai_tui_na` native-TUI refactor
([jaseci-labs/jaseci `bbb853a`](https://github.com/jaseci-labs/jaseci/commit/bbb853af5eb6b7f1d55ae4d7d523b08cfa89901a)),
which rewrites ~5.5k LOC of hand-lowered C-style `.na.jac` into idiomatic
Jac in a behavior-preserving way (verified by a 604-line golden-bytes harness).

Load this when writing or reviewing `.jac` (and especially `.na.jac`) so the
code reads like the rest of the repo instead of like translated C.

---

## At a glance

| Prefer this | Over this |
|---|---|
| Structured records (`obj Rgb { has r,g,b }`) | Parallel scalar globs (`TH_FOO_R/G/B`) |
| Methods on the owner (`self.update_scroll(...)`) | Free functions taking the state struct (`editor_update_scroll(ed, ...)`) |
| `bool` flags (`term_saved: bool = False`) | Int sentinels (`term_saved: int = 0`) |
| `for x in xs` / `range(...)` / comprehensions | `while i < n { ...; i = i + 1 }` |
| `"".join(parts)` | Repeated `s = s + c` |
| Ternary `x if cond else y` | `if/else` assigning one branch each |
| `if not prefix` / `prefix in val` | `if len(prefix) == 0` / `val.find(prefix) >= 0` |
| `max(0, lo)` / `min(x, hi)` clamps | Nested `if x < 0 { x = 0 }` |
| `match` over a tag enum | Long `if/elif` chains |
| Named constants (`_ROW_RIGHT_MARGIN`) | Magic numbers (`2`, `40`) |
| Keyword-arg construction (`Rgb(r=18, g=18, b=28)`) | Positional soup |
| Docstring on every module, `obj`, and `def` | Naked declarations |

---

## 1. Group related scalars into a structured record

The single biggest win. ~98 `TH_FOO_R/G/B` triple-globs collapse into one
`Rgb` each, and call sites stop threading six ints through every function.

```jac
# ❌ before -- theme.na.jac
glob TH_TITLE_R: int = 204,
     TH_TITLE_G: int = 0,
     TH_TITLE_B: int = 204;

# ✅ after
obj Rgb { has r: int = 0, g: int = 0, b: int = 0; }   # lives in terminal.na.jac
glob TH_TITLE: Rgb = Rgb(r=204, g=0, b=204);

def ansi_sgr(fg: Rgb, bg: Rgb, attrs: int) -> str {    # two records, not six ints
    ...
}
```

Same idea collapses the triplicated `{value,label,description}` triple into one
`SelectItem`, and a `KindStyle`'s `r/g/b` into a single `color: Rgb`.

## 2. Put behavior on the object that owns the state

Free functions that take the state struct as their first arg are just methods
written sideways. Fold them in.

```jac
# ❌ before -- editor.na.jac
def editor_update_scroll(ed: EditorState, width: int, max_rows: int) { ... }
def editor_insert(ed: EditorState, ch: str) { ... }
ed.cursor_col = ed.cursor_col + 1;          # mutation reaches in from outside

# ✅ after
obj EditorState {
    has lines: list[str] = [""], cursor_line: int = 0, ...;
    def update_scroll(self, width: int, max_rows: int) { ... }   # note: self implicit
}
```

> Note: in Jac the receiver is implicit (`self`), so the first param is the
> first *real* argument -- `update_scroll(width, max_rows)`, not `(self, ...)`.

## 3. Use real `bool` for predicates

```jac
# ❌ before -- libc_tty_base.na.jac
has term_saved: int = 0, stdin_ready: int = 0;
def tty_stdin_ready -> int { return g_tty.stdin_ready; }
if g_tty.term_saved != 0 { ... }

# ✅ after
has term_saved: bool = False, stdin_ready: bool = False;
def tty_stdin_ready -> bool { return g_tty.stdin_ready; }
if g_tty.term_saved { ... }
```

## 4. Iterate declaratively

Drop `while i < n { ...; i = i + 1 }` for `for`/comprehensions, and build
strings by appending to a list then joining.

```jac
# ❌ before -- select_list.na.jac
next_filtered: list[SelectItem] = [];
i: int = 0;
while i < len(self.items) {
    if self._matches(self.items[i], prefix) { next_filtered.append(self.items[i]); }
    i = i + 1;
}

# ✅ after
self.filtered = [item for item in self.items if self._matches(item, prefix)];

# ❌ before -- editor.na.jac            ✅ after
total = 0;  i = 0;                     for line in lines[:before_idx] {
while i < before_idx {                     total += _vl_count(len(line), width);
    total += _vl_count(len(lines[i]),  width); }
    i += 1;
}

# ❌ tty_read_line                      ✅ after
out = "";                               chars: list[str] = [];
out = out + chr(c);                     chars.append(chr(c));
return out;                             return "".join(chars);
```

## 5. Ternaries, truthiness, `in`, clamps

Reach for the compact, intent-revealing form.

```jac
# ternary over two-branch assignment
prefix = "→ " if is_selected else "  ";
return item.label if item.label else item.value;
self.selected = n - 1 if self.selected == 0 else self.selected - 1;
return SelectAction.SELECT if self.filtered else SelectAction.NONE;

# truthiness over length checks
if not prefix { return True; }
if item.description and inner_w > _TWO_COL_MIN_W { ... }

# `in` over .find() >= 0
return prefix in val;
return SelectAction.CANCEL if ch in "cq" else SelectAction.NONE;

# max/min clamps over nested ifs
mv = max(1, self.max_visible);
start = max(0, self.selected - mv // 2);
start = min(start, max(0, n - mv));
max_val = max(1, inner_w - visible_width(prefix) - _ROW_RIGHT_MARGIN);
```

## 6. `match` over a tag enum

```jac
# ❌ before -- state.na.jac (10 stacked `if kind == ...`)
if kind == EventKind.USER {
    return KindStyle(prefix="> ", r=TH_USER_R, g=TH_USER_G, b=TH_USER_B, attrs=TH_BOLD);
}
if kind == EventKind.ANSWER { ... }

# ✅ after
match kind {
    case EventKind.USER:
        return KindStyle(prefix="> ", color=TH_USER,  attrs=TH_BOLD);
    case EventKind.ANSWER:
        return KindStyle(prefix="  ", color=TH_ANSWER, mode=RenderMode.MARKDOWN);
    case EventKind.REASONING:
        return KindStyle(prefix="~ ", color=TH_REASON, attrs=TH_DIM_ITALIC,
                         mode=RenderMode.MARKDOWN);
    ...
}
```

## 7. Named constants, one source of truth, precomposed values

- **Magic numbers become named constants.** Module-private ones get a leading
  `_`: `_TWO_COL_MIN_W`, `_PRIMARY_COL_W`, `_ROW_RIGHT_MARGIN`, `_WINSIZE_SZ`,
  `_TTY_BYTE_LF`, `HISTORY_MAX`.
- **One home per concern.** Every ANSI/DEC escape byte lives in
  `terminal.na.jac`; siblings import the symbols instead of spelling escapes.
- **Precompose expensive/hot values once.** The `TH_SGR_*` globs are full
  escape strings built at init (`TH_SGR_TITLE = ansi_sgr(TH_TITLE, TH_BG, TH_BOLD)`),
  so the hot path does a string concat, not a function call per cell.

```jac
glob ANSI_RESET: str   = "\033[0m",
     ANSI_BOLD: str    = "\033[1m",
     ANSI_CLEAR_SCREEN: str = "\033[2J\033[H";
```

## 8. Keyword-argument construction

```jac
Rgb(r=18, g=18, b=28)
KindStyle(prefix="> ", color=TH_USER, attrs=TH_BOLD, mode=RenderMode.MARKDOWN)
```

## 9. Extract small helpers, then delegate

```jac
# the little-endian readers were copy-pasted; now one helper, two thin wrappers
def _read_le(buf: str, off: int, nbytes: int) -> int {
    val: int = 0;
    for i in range(nbytes) { val |= ord(buf[off + i]) << (8 * i); }
    return val;
}
def read_u32(buf: str, off: int) -> int { return _read_le(buf, off, 4); }
def u16le (buf: str, off: int) -> int { return _read_le(buf, off, 2); }
```

Shared utilities (`parse_int_or`, `split_kv`) earn their own `util.na.jac`
rather than being re-invented per module.

## 10. Docstrings + guard clauses + section dividers

- **Module docstring** at the top states what the module owns and its
  invariants/conventions (the FFI conventions box below is one).
- **A docstring before every `def`/method and every `obj`/`enum`.** One line is
  fine; a short paragraph when behavior is subtle.
- **Guard clause first** -- handle the empty/early case and `return` before the
  body, so the happy path isn't indented inside an `if`.
- **`# --- section ---` dividers** group a file into coherent regions
  (constants → record → open/close → window size → polling → read/write).

---

## Native pathway constraints (load-bearing -- read before touching `.na.jac`)

These are documented *in the code* because violating them corrupts state or
crashes the compiler. They are the reason the refactor is "behavior-preserving
*within the constraints the native pathway supports*."

1. **`str` doubles as `char*`.** na has no `bytes`/buffer type. `calloc()`
   returns an `int` pointer that is re-typed via an annotated local
   (`out: str = p;`) and every `calloc` is paired with a `free` on all paths.

2. **Negative repeat corrupts the heap.** `term_repeat` guards `n <= 0` before
   `c * n` -- the comment is explicit: *"n <= 0 guard is load-bearing."*

3. **Cross-module glob init-order hazard.** An imported `obj` glob is still
   `None` while *another* module's glob init runs. Therefore functions called
   *from a glob initializer* must keep their bodies **glob-free / literal**.
   That's why `ansi_reset()` returns a literal `"\033[0m"` instead of
   `ANSI_RESET`, and `ansi_sgr()` keeps its bit values literal even though
   `TH_BOLD` exists -- both are called from `theme.na.jac`'s `TH_SGR_*` globs.

4. **`jac fmt` must NOT run over these files.** The formatter rewrites
   `x if x else y` into `x or y`, which ICEs the native compiler (the cluster-2b
   gap in jaseci #7320). The commit was made `--no-verify` for this reason.
   Pre-commit hooks must skip `.na.jac` formatting.

5. **Sgr-composition lives in the module that owns the palette** (see #3): the
   `TH_SGR_*` escape strings are built *inside* `theme.na.jac`'s own glob init,
   and consumers only touch the `Rgb` globs at function scope.

---

## File shape checklist

A well-shaped `.na.jac` module in this codebase looks like:

```
"""Module docstring -- what it owns + invariants/FFI conventions."""
import ...;

# --- named constants (public UPPER_CASE; private _leading_underscore) ---
glob HISTORY_MAX: int = 100,
     _ROW_RIGHT_MARGIN: int = 2;

# --- records (obj) and tag enums (enum) ---
obj Rgb { has r: int = 0, g: int = 0, b: int = 0; }
enum SelectAction { NONE = 0, CHANGED = 1, SELECT = 2, CANCEL = 3 }

# --- stateful objects: has-fields + methods (behavior lives here) ---
obj EditorState {
    has lines: list[str] = [""], ...;
    """Docstring per method."""
    def update_scroll(width: int, max_rows: int) { ... }
}

# --- free functions: thin helpers, guard clause first, one job ---
def parse_int_or(s: str, fallback: int) -> int {
    try { return int(s); }
    except Exception { return fallback; }
}
```

---

## Source

Commit `bbb853af` -- *"refactor(ai_tui_na): rewrite native TUI in idiomatic
Jac style"*. Representative files to study in full:
`theme.na.jac` (Rgb + precomposed SGRs), `terminal.na.jac` (single escape home

- the glob-init hazard comment), `editor.na.jac` (free-fn → method fold),
`select_list.na.jac` (ternaries/comprehensions/clamps), `state.na.jac`
(`match` + keyword construction), `tty/libc_tty_base.na.jac` (bools + FFI
conventions), `util.na.jac` (shared helpers).
