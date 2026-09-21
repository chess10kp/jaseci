"""Fixture: a type error that should make `jac check` point at the jac-types guide."""

glob count: int = "not a number";
with entry {
    print(count);
}
