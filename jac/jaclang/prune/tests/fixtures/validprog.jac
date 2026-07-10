"""Phase-5 validation fixture: a small, clean, type-correct module.

Used to prove the validation gate passes a well-formed file end-to-end (parse +
typecheck-vs-baseline). Kept deliberately warning-free.
"""

def add(a: int, b: int) -> int {
    return a + b;
}


def main -> int {
    return add(1, 2);
}
