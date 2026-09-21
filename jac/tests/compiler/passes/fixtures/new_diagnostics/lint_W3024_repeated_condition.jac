"""Fixture for W3024: Repeated identical condition in if/elif chain."""

glob x = 5;

with entry {
    if x > 0 {
        print("positive");
    } elif x > 0 {  # <-- Warning W3024: same condition as if
        print("also positive?");
    } elif x < 0 {  # <-- Ok: different condition
        print("negative");
    }
}
