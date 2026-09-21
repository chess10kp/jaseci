"""Fixture for W2075: Redundant boolean comparison."""

glob x = True;
with entry {
    if x == True {  # <-- Warning W2075: use 'if x' instead
        print("yes");
    }
    if x == False {  # <-- Warning W2075: use 'if not x' instead
        print("no");
    }
    if x {  # <-- Ok
        print("yes");
    }
}
