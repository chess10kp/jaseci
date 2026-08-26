# Product-path facade for readline (Modules/readline.c).
#
# Semantics mirror CPython 3.14 ``Modules/readline.c`` on the pinned host:
# the full Python-visible surface (history manipulation, hook registry,
# completer plumbing, word-break delimiters, completion-scope indices).
#
# REPRESENTATION CHOICE (divergence ledger candidate): the C original binds
# GNU readline/libedit global state (rl_* variables) and drives a real
# terminal editor loop. The guest has no readline backend, so the module
# state below IS the history/editor model: the history list, hook slots and
# line buffer behave exactly as the C module's observable state does, while
# the terminal-facing entry points (parse_and_bind keymap parsing,
# redisplay, interactive input) are documented accept-and-ignore arms --
# identical to the C module's behavior when stdout is not a tty.
#
# History indexing follows the GNU readline arm (libedit emulation off):
# get_history_item is one-based, remove/replace_history_item are zero-based,
# out-of-range item access yields None (get) or ValueError (remove/replace),
# matching each PyErr site in the C source. File operations raise OSError
# subclasses exactly where PyErr_SetFromErrno(PyExc_OSError) fires.
#
# The reported backend/version constants describe the facade's emulated GNU
# readline 8.2 surface: ``backend == "readline"``,
# ``_READLINE_LIBRARY_VERSION`` never contains the libedit version tag, so
# test suites probing ``is_editline`` take the GNU arm.

import os as host_os;


# Module constants (PyInit_readline).
glob backend: str = "readline";
glob _READLINE_VERSION: int = 0x0802;
glob _READLINE_RUNTIME_VERSION: int = 0x0802;
glob _READLINE_LIBRARY_VERSION: str = "8.2";

# Default word-break characters (setup_readline): all non-alphanumerics
# except '.'.
glob _DEFAULT_DELIMS: str = " \t\n`~!@#$%^&*()-=+[{]}\\|;:'\",<>/?";

# Module state boxed in a dict so rebinding stays unnecessary (same
# convention as _csvmodule.jac).
glob _state: dict = {
    "history": [],
    "history_length": -1,
    "auto_add_history": True,
    "completer": None,
    "startup_hook": None,
    "pre_input_hook": None,
    "display_matches_hook": None,
    "begidx": 0,
    "endidx": 0,
    "line_buffer": "",
    "cursor": 0,
    "completion_type": 0,
    "delims": _DEFAULT_DELIMS,
};


# ---------------- encode()/decode() stand-ins ----------------


def _need_str(v: any, arg: str) -> str {
    # encode(): PyUnicode_EncodeLocale rejects everything but str.
    if not isinstance(v, str) {
        raise TypeError(arg + " must be a string");
    }
    return v as str;
}


def _fs_path(v: any) -> str {
    # PyUnicode_FSConverter arm: str, bytes or os.PathLike.
    if isinstance(v, str) {
        return v as str;
    }
    if isinstance(v, bytes) {
        return (v as bytes).decode("utf-8", "surrogateescape");
    }
    if hasattr(v, "__fspath__") {
        return host_os.fspath(v);
    }
    raise TypeError("filename must be a str, bytes or os.PathLike object");
}


# ---------------- generic hook setter (set_hook) ----------------


def _set_hook(funcname: str, key: str, function: any) {
    slot = _state[key];
    if function is None {
        _state[key] = None;
        return;
    }
    if callable(function) {
        _state[key] = function;
        return;
    }
    raise TypeError(
        "set_" + funcname + "(func): argument not callable");
}


# ---------------- history file helpers ----------------


def _default_history_file() -> str {
    # The C module hands NULL to the history package with the documented
    # default ~/.history (which readline expands internally).
    return host_os.path.expanduser("~/.history");
}


def _truncate_for_write(lines: list) -> list {
    # write_history_file truncates the FILE to history_length after writing
    # (history_truncate_file) when a length was ever set (>= 0).
    limit = _state["history_length"];
    if limit >= 0 and len(lines) > limit {
        return lines[len(lines) - limit:];
    }
    return lines;
}


# ---------------- init / parse_and_bind ----------------


def parse_and_bind(string: any) {
    # rl_parse_and_bind: executes an inputrc-style init line. No keymap
    # exists in the guest, so accepted lines are recorded nowhere -- the
    # observable module state is unchanged, as on a non-tty host.
    _need_str(string, "string");
}


def read_init_file(filename: any = None) {
    path: str | None = None;
    if filename is not None {
        path = _fs_path(filename);
        if not host_os.path.isfile(path) {
            raise FileNotFoundError(
                2, "No such file or directory", path);
        }
    }
}


# ---------------- history file interface ----------------


def read_history_file(filename: any = None) {
    path = _default_history_file();
    if filename is not None {
        path = _fs_path(filename);
    }
    fp = open(path, "r", encoding="utf-8", errors="surrogateescape");
    try {
        data = fp.read();
    } finally {
        fp.close();
    }
    history = _state["history"];
    for line in data.split("\n") {
        history.append(line);
    }
    while len(history) and history[-1] == "" {
        history.pop();
    }
}


def write_history_file(filename: any = None) {
    path = _default_history_file();
    if filename is not None {
        path = _fs_path(filename);
    }
    lines = _truncate_for_write(_state["history"]);
    fp = open(path, "w", encoding="utf-8", errors="surrogateescape");
    try {
        for line in lines {
            fp.write(line + "\n");
        }
    } finally {
        fp.close();
    }
}


def append_history_file(nelements: int, filename: any = None) {
    if nelements < 0 {
        raise ValueError("nelements must be non-negative");
    }
    path = _default_history_file();
    if filename is not None {
        path = _fs_path(filename);
    }
    history = _state["history"];
    tail = history;
    if nelements < len(history) {
        tail = history[len(history) - nelements:];
    }
    fp = open(path, "a", encoding="utf-8", errors="surrogateescape");
    try {
        for line in tail {
            fp.write(line + "\n");
        }
    } finally {
        fp.close();
    }
    lines = _truncate_for_write(tail);
    if len(lines) != len(tail) {
        # history_length truncation applies to the appended file as a whole;
        # rewrite it compacted, mirroring history_truncate_file.
        fp = open(path, "w", encoding="utf-8", errors="surrogateescape");
        try {
            for line in lines {
                fp.write(line + "\n");
            }
        } finally {
            fp.close();
        }
    }
}


# ---------------- history buffer interface ----------------


def clear_history() {
    _state["history"] = [];
}


def get_history_item(index: int) -> any {
    # One-based (GNU readline arm); out-of-range yields None.
    history = _state["history"];
    if index < 1 or index > len(history) {
        return None;
    }
    return history[index - 1];
}


def get_current_history_length() -> int {
    return len(_state["history"]);
}


def set_history_length(length: int) {
    _state["history_length"] = length;
}


def get_history_length() -> int {
    return _state["history_length"];
}


def set_auto_history(enabled: bool) {
    _state["auto_add_history"] = bool(enabled);
}


def add_history(string: any) {
    _state["history"].append(_need_str(string, "string"));
}


def remove_history_item(pos: int) {
    history = _state["history"];
    if pos < 0 {
        raise ValueError("History index cannot be negative");
    }
    if pos >= len(history) {
        raise ValueError("No history item at position " + str(pos));
    }
    history.pop(pos);
}


def replace_history_item(pos: int, line: any) {
    history = _state["history"];
    if pos < 0 {
        raise ValueError("History index cannot be negative");
    }
    if pos >= len(history) {
        raise ValueError("No history item at position " + str(pos));
    }
    history[pos] = _need_str(line, "line");
}


# ---------------- hook registry ----------------


def set_completer(function: any = None) {
    _set_hook("completer", "completer", function);
}


def get_completer() -> any {
    return _state["completer"];
}


def set_startup_hook(function: any = None) {
    _set_hook("startup_hook", "startup_hook", function);
}


def set_pre_input_hook(function: any = None) {
    _set_hook("pre_input_hook", "pre_input_hook", function);
}


def set_completion_display_matches_hook(function: any = None) {
    _set_hook("completion_display_matches_hook", "display_matches_hook",
              function);
}


# ---------------- completion machinery ----------------


def get_completer_delims() -> str {
    return _state["delims"];
}


def set_completer_delims(string: any) {
    _state["delims"] = _need_str(string, "string");
}


def get_completion_type() -> int {
    return _state["completion_type"];
}


def get_begidx() -> int {
    return _state["begidx"];
}


def get_endidx() -> int {
    return _state["endidx"];
}


def get_line_buffer() -> str {
    return _state["line_buffer"];
}


def insert_text(string: any) {
    # rl_insert_text at the cursor; the cursor advances past the text.
    text = _need_str(string, "string");
    buffer_text = _state["line_buffer"] as str;
    at = _state["cursor"] as int;
    if at < 0 {
        at = 0;
    }
    if at > len(buffer_text) {
        at = len(buffer_text);
    }
    _state["line_buffer"] = (
        buffer_text[:at] + text + buffer_text[at:]);
    _state["cursor"] = at + len(text);
}


def redisplay() {
    # rl_redisplay: nothing is rendered without a terminal backend.
}


# ---------------- completion driver (flex_complete/on_completion) --------
#
# The C module wires flex_complete as rl_attempted_completion_function: it
# records the character scope of the word being completed (begidx/endidx,
# recomputed over decoded UTF-8) and then drives the Python completer with
# the (text, state) protocol until it returns a non-string. This driver is
# that protocol lifted whole, minus the terminal.


def _flex_complete(text: str, start: int, end: int) -> list {
    _state["begidx"] = start;
    _state["endidx"] = end;
    completer = _state["completer"];
    matches: list = [];
    if completer is None {
        return matches;
    }
    state_i: int = 0;
    while True {
        r = completer(text, state_i);
        if r is None or not isinstance(r, str) {
            break;
        }
        matches.append(r);
        state_i = state_i + 1;
    }
    return matches;
}
