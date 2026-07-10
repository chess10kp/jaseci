"""Fixture for the consolidation dry-run (--probe).

  - exact, cross-class: `read`/`read` byte-identical across two sibling classes
    -> substituting one body for the other is a no-op -> probe passes.
  - structural, type-divergent: `widen_i`/`widen_s` share a structural hash
    (`v = x <op> <lit>; return v`) but the parameter types differ, so
    substituting either body into the other introduces a new type
    diagnostic -> probe fails at typecheck with a divergence pointer.
"""

obj AlphaStore {
    has data: dict = {};

    def read(key: str) -> str {
        val = self.data.get(key);
        if val is None {
            return "";
        }
        return str(val);
    }
}

obj BetaStore {
    has data: dict = {};

    def read(key: str) -> str {
        val = self.data.get(key);
        if val is None {
            return "";
        }
        return str(val);
    }
}


def widen_i(x: int) -> int {
    v = x + 1;
    return v;
}


def widen_s(x: str) -> str {
    v = x + "1";
    return v;
}
