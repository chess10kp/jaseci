"""Fixture for W3025: Identical branches in if/else."""

glob x = 5;

with entry {
    if x > 0 {
        print("hello");  # <-- Warning W3025: identical branches
    } else {
        print("hello");
    }

    if x > 0 {
        print("positive");  # <-- Ok: different branches
    } else {
        print("not positive");
    }
}
