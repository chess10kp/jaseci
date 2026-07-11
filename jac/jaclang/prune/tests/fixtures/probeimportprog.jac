"""Fixture for the probe-import veto.

Symbol names are kept out of this docstring on purpose (a name here would be a
string literal and could trip the string-mention veto).
"""

import from math { sqrt }


with entry {
    try {
        import from math { pi }
    } except ImportError {
        pi = None;
    }
}


def used() -> int {
    return 1;
}
