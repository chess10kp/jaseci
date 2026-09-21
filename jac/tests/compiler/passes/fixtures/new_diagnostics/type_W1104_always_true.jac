"""Fixture for W1104: Condition is always true/false."""

with entry {
    if True {  # <-- Warning W1104: condition is always true
        print("yes");
    }

    if False {  # <-- Warning W1104: condition is always false
        print("no");
    }
}

glob x = 5;
with entry {
    if x {  # <-- Ok: runtime value
        print("maybe");
    }
}
