# Parser precedence pins: unary ops bind LOOSER than `**` (CPython grammar:
# power := primary ['**' u_expr], u_expr := power | '-' u_expr | '+' u_expr
# | '~' u_expr), while `**` stays right-associative with a unary-allowed RHS.
#
# Regression origin: objects/done/080-range-hugeint-hash result -- Jac parsed
# `-2**100` as `(-2)**100` because parse_power took its LEFT operand from the
# unary (factor) level instead of the postfix level. CPython evaluates
# `-2**100` as `-(2**100)`; `(-2)**100` requires explicit parens.
#
# All expected values are byte-exact from the host oracle (CPython 3.14):
#   python3 -c "print(-2**3, -2**4, +2**3, ~2**2, -3**2, 4*-2**2)"
# These cases stay inside machine-int range so they pin PARSER precedence,
# not hugeint pow codegen (tracked separately).

test "unary/pow precedence: leading minus binds looser than **" {
    assert -2**3 == -8, "-2**3";
    assert -2**4 == -16, "-2**4";
    assert -3**2 == -9, "-3**2";
    assert -1024**1 == -1024, "-1024**1";
}

test "unary/pow precedence: parens still force base negation" {
    assert (-2)**3 == -8, "(-2)**3";
    assert (-2)**4 == 16, "(-2)**4";
    assert (-3)**2 == 9, "(-3)**2";
}

test "unary/pow precedence: plus and invert also looser than **" {
    assert +2**3 == 8, "+2**3";
    assert ~2**2 == -5, "~2**2";
    assert ~3**1 == -4, "~3**1";
}

test "pow right-assoc: unary allowed in exponent" {
    assert 2**-1 == 0.5, "2**-1";
    assert -2**-2 == -0.25, "-2**-2";
    assert (-2)**-2 == 0.25, "(-2)**-2";
    assert 2**3**2 == 512, "2**3**2 right-assoc";
}

test "unary/pow precedence under other operators" {
    assert 4 * -2**2 == 16, "4*-2**2";
    assert -2 * 3 == -6, "-2*3 unchanged";
    assert 10 - -2**2 == 6, "10 - -2**2";
}
