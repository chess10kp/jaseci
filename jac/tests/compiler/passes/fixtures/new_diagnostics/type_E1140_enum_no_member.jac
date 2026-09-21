"""Fixture for E1140: Enum has no member."""

enum Color { RED, GREEN, BLUE }

glob c = Color.RED,  # <-- Ok
     d = Color.YELLOW;  # <-- Error E1140: Color has no member 'YELLOW'
