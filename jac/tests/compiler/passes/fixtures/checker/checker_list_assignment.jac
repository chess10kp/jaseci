with entry {
    foo: int = 42;
    foo = [1, 2, 3];  # <-- Error
}

glob bar = [1, 2, 3];
with entry {
    baz: list[int] = bar;  # <-- Ok
}
