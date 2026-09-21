glob l: list[int] = [];

with entry {
    for i in l {
        x: int = i;  # <-- Ok
        y: str = i;  # <-- Error
    }
}
