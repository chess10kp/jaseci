"""Fixture for the dead-enum-variants detector.

Symbol names are kept out of this docstring so the string-mention veto does not
downgrade any finding. `Color` has three live variants and one that is never
constructed, read, or matched.
"""

enum Color {
    RED,
    GREEN,
    BLUE,
    ORPHAN
}


def paint(c: Color) -> str {
    if c == Color.RED {
        return "r";
    }
    if c == Color.GREEN {
        return "g";
    }
    return "b";
}


def make() -> Color {
    return Color.BLUE;
}
