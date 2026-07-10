"""Suppression fixture: three private-dead globals, one suppressed inline for
prune, one suppressed for an unrelated code (which must NOT match)."""

glob:priv ALPHA = 1;


glob:priv BETA = 2; # jac:ignore[prune]


glob:priv GAMMA = 3; # jac:ignore[other]
