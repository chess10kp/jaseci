"""Fixture module for prune Phase-2 fact-extraction golden tests.

Deliberately contains: unused imports (os, sqrt), a referenced def
(used_helper, called twice), a read+written field (stored) and a write-only
field (writeonly). The Phase-2 tests pin the extracted facts against these.
"""

import os;
import from math { sqrt }


def used_helper() -> int {
    return 1;
}


def caller() -> int {
    return used_helper() + used_helper();
}


obj Box {
    has stored: int = 0,
        writeonly: int = 0;

    def fill(v: int) -> None {
        self.stored = v;
        self.writeonly = v;
    }

    def peek -> int {
        return self.stored;
    }
}
