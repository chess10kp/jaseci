"""Native unit tests for fuzzy autocomplete scoring and trigger extraction."""

import from .autocomplete { fuzzy_score, FUZZY_NO_MATCH, ac_update }
import from .editor { EditorState }
import from .state { TuiState, AcKind }
import from .select_list { SelectItem }
import from .libc_tty { tty_write }


def _check(label: str, ok: bool) {
    s: str = "PASS " + label if ok else "FAIL " + label;
    tty_write(1, s + "\n");
}

with entry {
    _check("fuzzy_empty_query", fuzzy_score("", "hello") == 0);
    _check("fuzzy_exact", fuzzy_score("help", "help") != FUZZY_NO_MATCH);
    _check(
        "fuzzy_exact_beats_partial",
        fuzzy_score("help", "help") < fuzzy_score("he", "help")
    );
    _check("fuzzy_partial", fuzzy_score("hp", "help") != FUZZY_NO_MATCH);
    _check("fuzzy_no_match", fuzzy_score("zzz", "help") == FUZZY_NO_MATCH);
    _check("fuzzy_query_too_long", fuzzy_score("toolong", "hi") == FUZZY_NO_MATCH);

    state = TuiState();
    state.editor.insert("/");
    ac_update(state);
    _check(
        "slash_trigger_active",
        state.ac.active and state.ac.kind == AcKind.SLASH and state.ac.query == ""
    );

    state2 = TuiState();
    state2.files = ["readme.txt"];
    state2.editor.insert("@re");
    ac_update(state2);
    _check(
        "at_file_trigger",
        state2.ac.active and state2.ac.kind == AcKind.AT_FILE and state2.ac.query == "re"
    );

    state3 = TuiState();
    state3.editor.insert("/done ");
    ac_update(state3);
    _check("slash_with_space_dismisses", not state3.ac.active);

    state4 = TuiState();
    state4.files = ["src/main.jac", "src/util.jac", "README.md"];
    state4.editor.insert("@ut");
    ac_update(state4);
    _check(
        "file_fuzzy_match",
        state4.ac.active and len(state4.ac.items) >= 1
        and "util" in state4.ac.items[0].label
    );
}
