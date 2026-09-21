"""Test partial extraction when some statements can be extracted and others cannot.

The extractable assignments (x, y) become globs, but the non-extractable
statement (print) stays in the with entry block.
"""

glob x = 5;
with entry {
    print("hello");
}
glob y = 10;
