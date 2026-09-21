"""Test @= (matrix multiply assign) operator parsing."""

with entry {
    a = [[1, 2], [3, 4]];
}
glob b = [[5, 6], [7, 8]];
with entry {
    a @= b;
    print(a);
}
