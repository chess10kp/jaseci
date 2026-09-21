# Safe call operator with subscript: ?[
glob items: list[any] | None = None;
with entry {
    val = items?[0];
    nested = items?[0]?[1];
}
