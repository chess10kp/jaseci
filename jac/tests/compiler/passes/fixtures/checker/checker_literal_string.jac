"""Tests for Literal and LiteralString type checking."""

glob ok_str: str = "hello",
     ok_str2: str = "a" + "b",
     ok_fstring: str = f"value: {ok_str}",
     inferred_literal = "inferred",
     err_literal_to_int: int = "not an int";

# Error: Literal["not an int"] to int
def take_str(s: str) -> str {
    return s;
}
def take_int(n: int) -> int {
    return n;
}

glob x: str = "literal";
with entry {
    a = take_str("arg");
    b = take_str(x);

    err1 = take_int("wrong");  # Error: Literal["wrong"] to int param
}
