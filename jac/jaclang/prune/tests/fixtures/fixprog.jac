"""Rewrite fixture for prune Phase-4 planning + application tests.

Symbol names are kept OUT of this docstring on purpose: docstrings are string
literals, so naming a symbol here trips the string-mention veto and downgrades
its finding to report-only (killing the auto-fix path this fixture exercises).
It carries one unused multi-item import member, one wholly-unused import, and
one dead private global; two imports and their users stay live.
"""

import os;
import from math { sqrt, cos }
import from typing { Any }


glob:priv DEAD_GLOBAL = 5;


def area(r: float) -> float {
    return sqrt(r);
}


def pid() -> int {
    return os.getpid();
}
