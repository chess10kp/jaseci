def checked_index(xs: &list[int], i: int) -> int {
    return xs[i];
}

def checked_assert(value: int) -> int {
    assert value != 0;
    return value;
}

glob xs: own list[int] = [1];
with entry {
    try {
        print(checked_index(&xs, 3));
    } except IndexError {
        print("bounds caught");
    } finally {
        print("bounds finalized");
    }
    try {
        print(checked_assert(0));
    } except AssertionError {
        print("assertion caught");
    }
}
