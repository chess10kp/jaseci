"""The empty tuple names its arguments by writing an empty argument list,
wherever it appears in the annotation."""

obj Stage {
    static has PROVIDES: tuple[()] = (),
        REQUIRES: tuple[str] = ('x', );
}


glob NOTHING: tuple[()] = (),
     NESTED_EMPTY: list[tuple[()]] = [],
     MAYBE_EMPTY: tuple[()] | None = None;


def bare_still_errors(rows: dict[str, tuple]) -> int {
    return len(rows);
}
