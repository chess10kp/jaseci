"""Runtime behavior of the `expr as Type` cast — it is type-erased.

At runtime the cast does nothing: it evaluates to the operand unchanged.
"""

obj Box {
    has v: int;
}

glob x: any = 42;
with entry {
    y = x as int;
    print(y);

    b: any = Box(v=7);
    bb = b as Box;
    print(bb.v);
}

glob nums: any = [1, 2, 3];
with entry {
    total = sum(nums as list[int]);
    print(total);

    # Cast inside a larger expression.
    print((x as int) + 1);
}
