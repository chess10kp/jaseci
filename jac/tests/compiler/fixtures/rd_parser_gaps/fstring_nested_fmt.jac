"""Test f-string with nested format spec parsing."""

glob width = 10,
     value = 3.14;

with entry {
    msg = f"{value:{width}}";
    print(msg);
}
