"""Fixture for if-chain-dispatch extraction.

Positive shapes: sequential if/return dispatch, elif dispatch, or-chains,
and-chains. Negative shapes: ordered guards, side-effect bodies, mixed
selectors, short chains.
"""

glob K_A = 1,
     K_B = 2,
     K_C = 3,
     K_D = 4,
     K_E = 5;


def seq_dispatch(op: int) -> int {
    if op == K_A {
        return 1;
    }
    if op == K_B {
        return 2;
    }
    if op == K_C {
        return 3;
    }
    if op == K_D {
        return 4;
    }
    if op == K_E {
        return 5;
    }
    return 0;
}


def elif_dispatch(op: int) -> int {
    if op == K_A {
        return 1;
    } elif op == K_B {
        return 2;
    } elif op == K_C {
        return 3;
    } elif op == K_D {
        return 4;
    } elif op == K_E {
        return 5;
    }
    return 0;
}


def or_predicate(op: int) -> bool {
    if op == K_A or op == K_B or op == K_C or op == K_D or op == K_E {
        return True;
    }
    return False;
}


def and_negated(op: int) -> bool {
    if op != K_A and op != K_B and op != K_C and op != K_D {
        return True;
    }
    return False;
}


def ordered_guards(x: int) -> int {
    if x < 10 {
        return 1;
    }
    if x < 20 {
        return 2;
    }
    if x < 30 {
        return 3;
    }
    if x < 40 {
        return 4;
    }
    return 0;
}


def side_effect_arms(op: int, sink: list) -> int {
    if op == K_A {
        sink.append(1);
        return 1;
    }
    if op == K_B {
        sink.append(2);
        return 2;
    }
    if op == K_C {
        sink.append(3);
        return 3;
    }
    if op == K_D {
        sink.append(4);
        return 4;
    }
    return 0;
}


def mixed_selectors(a: int, b: int) -> bool {
    if a == K_A or a == K_B or a == K_C or a == K_D or b == K_E {
        return True;
    }
    return False;
}


def short_or(op: int) -> bool {
    if op == K_A or op == K_B or op == K_C {
        return True;
    }
    return False;
}
