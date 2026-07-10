"""Single-caller-inline fixture for prune Tier-3 tests.

Symbol names are kept OUT of this docstring on purpose (docstrings are string
literals; naming a symbol here would trip the string-mention veto).
"""

obj Box {
    def once_caller -> int {
        return self._only_once();
    }

    def:priv _only_once -> int {
        return 1;
    }

    def multi_a -> int {
        return self._multi();
    }

    def multi_b -> int {
        return self._multi();
    }

    def:priv _multi -> int {
        return 2;
    }

    def big_caller -> int {
        return self._big();
    }

    def:priv _big -> int {
        x = 1;
        y = 2;
        z = 3;
        w = 4;
        return x + y + z + w;
    }
}
