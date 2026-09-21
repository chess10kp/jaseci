"""Fixture for W1102: Redundant None check."""

glob x: int = 5;
with entry {
    if x is not None {  # <-- Warning W1102: x can never be None
        print(x);
    }
}
