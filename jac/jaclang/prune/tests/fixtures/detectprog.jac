"""Detector fixture for prune Phase-3 tests.

Exercises each Tier-1 detector plus the string-mention veto. Symbol names are
kept OUT of this docstring on purpose: docstrings are string literals, so naming
a symbol here would trip the (conservative) string-mention veto and downgrade
its finding to report-only.
"""

import ast;
import os;
import from math { sqrt }


glob:priv DEAD_CONST = 5;


glob:priv VETOED_CONST = 7;


def:priv _dead_helper() -> int {
    return 1;
}


def used_pub() -> int {
    return os.getpid();
}


obj Widget {
    has:priv wonly: int = 0,
        readwrite: int = 0;

    def fill(v: int) -> None {
        self.wonly = v;
        self.readwrite = v;
    }

    def peek -> int {
        return self.readwrite;
    }
}


def brancher(x: int) -> int {
    if False {
        return 99;
    }
    if True {
        return x;
    } else {
        return 0;
    }
}


def mentions() -> str {
    return "VETOED_CONST";
}


def prose() -> str {
    return "ast is a syntax tree";
}
