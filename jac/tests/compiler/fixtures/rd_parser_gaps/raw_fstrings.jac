"""Test raw f-string parsing."""

glob name = "world";
with entry {
    msg = rf"Hello \n {name}";
    print(msg);
}
