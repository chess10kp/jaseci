"""Supplier module for real-source extraction tests.

Provides public symbols consumed by `sigtypeprog.jac` and `visurfaceprog.jac`
so the cross-module reference and type-annotation extraction paths are exercised
against genuinely compiled Jac, not hand-built facts.
"""

obj Payload {
    has value: int = 0;
}


obj Retval {
    has code: int = 0;
}


obj Elem {
    has idx: int = 0;
}


obj Optel {
    has flag: int = 0;
}


obj Unused {
    has slot: int = 0;
}


def shared_helper(n: int) -> int {
    return n + 1;
}


def only_local_caller() -> int {
    return shared_helper(41);
}
