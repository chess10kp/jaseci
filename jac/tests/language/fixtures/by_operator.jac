"""Test file for by operator."""

glob
     # Test 1: Simple by expression
     result = "hello" by "world";
with entry {
    print("Test 1:", result);
}

glob
     # Test 2: Chained by expressions
     result2 = "a" by "b" by "c";
with entry {
    print("Test 2:", result2);
}

glob
     # Test 3: By with complex expressions
     result3 = (1 + 2) by (3 * 3) by (5 / 2 by 1);
with entry {
    print("Test 3:", result3);
}

glob
     # Test 4: By in assignment
     x = "input" by "output";
with entry {
    print("Test 4:", x);
}
