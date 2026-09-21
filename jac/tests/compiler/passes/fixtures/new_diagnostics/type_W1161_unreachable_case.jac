"""Fixture for W1161: Unreachable match case."""

glob x: int = 5;

with entry {
    match x {
        case _:
            print("catch all");

        case 5:
            print("five");
  # <-- Warning W1161: unreachable after wildcard
    }
}
