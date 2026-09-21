glob x: list[int] = [1, 2, 3];
with entry {
    y: list[int] = x[0:2];  # <-- Ok
    z: int = x[0:2];  # <-- Error
}
