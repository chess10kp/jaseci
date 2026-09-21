"""`as` binds tighter than comparisons and looser than arithmetic (#7885).

`x as int == 0` parses as `(x as int) == 0`; before the fix the `== 0` was
absorbed into the cast's type expression and the whole expression silently
evaluated to `x`.
"""

glob x: any = 3;
with entry {
    assert (x as int == 0) == False;
    assert (x as int == 3) == True;
    assert (0 == x as int) == False;
    assert (x as int == 3 and True) == True;
    print("compare-ok");
}

glob y: any = None;
with entry {
    assert (y as int | None is None) == True;
    print("union-ok");

    assert ((1 + 2) as int == 3) == True;
    assert (x as int as float == 3.0) == True;
    print("left-binding-ok");
}

glob flag: any = True;
with entry {
    assert (flag as bool and True) == True;
    assert (not (x as int == 0)) == True;
    print("logical-ok");
}
