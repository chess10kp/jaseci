"""Library module for the cross-module visibility-tightening real-source test.

`exported_used` is called from `viscon.jac` (a real cross-module call), so it
must NOT be flagged for visibility tightening. `only_local` is public but called
only within this module, so it MUST be flagged. Exercises the cross-module
reference extraction path against compiled Jac rather than hand-built facts.
"""

def exported_used(n: int) -> int {
    return n * 2;
}


def only_local(n: int) -> int {
    return n + 1;
}


def _driver() -> int {
    return only_local(exported_used(1));
}
