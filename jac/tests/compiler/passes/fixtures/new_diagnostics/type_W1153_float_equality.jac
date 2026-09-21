"""Fixture for W1153: Floating point equality comparison."""

glob x: float = 0.1 + 0.2;
with entry {
    if x == 0.3 {  # <-- Warning W1153: float equality comparison
        print("equal");
    }

    if abs(x - 0.3) < 1e-9 {  # <-- Ok: approximate comparison
        print("close enough");
    }
}

glob y: int = 5;
with entry {
    if y == 5 {  # <-- Ok: integer comparison
        print("five");
    }
}
