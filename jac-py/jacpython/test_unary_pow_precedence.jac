# Unary operator / `**` precedence pin (objects track, from the
# 080-range-hugeint-hash audit finding).
#
# CPython binds `**` tighter than unary +/-/~ (grammar:
# u_expr ::= power | "-" u_expr | "+" u_expr | "~" u_expr,
# power ::= primary ["**" u_expr]), so -2**4 parses as -(2**4) == -16.
# The Jac parser used to fold the unary into the base first
# ((-2)**4 == 16); these pins lock the CPython grouping. The assertions
# live in Jac source, so compiling this file itself exercises the fixed
# parse_power/parse_factor path.

# Groupings that differ between the two readings:
test "unary minus binds looser than **" {
    assert -2**4 == -16;
    assert -2**6 == -64;
    assert -3**2 == -9;
}

# RHS of ** is a full unary expression (CPython power ::= primary ["**" u_expr]):
test "** right operand takes unary operators" {
    assert 2**-1 == 0.5;
    assert 4**-2 == 0.0625;
    assert -2**-2 == -0.25;
}

# Right-associativity is preserved through the shared entry point:
test "** stays right associative with unaries mixed in" {
    assert 2**3**2 == 512;
    assert -2**3**1 == -8;
}

# Explicit parens still override, and unary ops without ** are unchanged:
test "explicit parens and plain unaries unchanged" {
    assert (-2)**4 == 16;
    assert (-3)**2 == 9;
    assert -4 == -4;
    assert +5 == 5;
    assert ~0 == -1;
    assert -(2 * 3) == -6;
}
