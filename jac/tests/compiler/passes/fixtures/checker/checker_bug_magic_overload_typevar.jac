"""A magic-method overload's own TypeVars must be solved from the arguments."""

obj A {
    has ok: bool = False;
}

obj B {
    has ok: bool = False;
}

def concat(xs: list[A], ys: list[B]) {
    for i in xs + ys {
        i.ok = True;
    }
}

def homogeneous(xs: list[A], ys: list[A]) {
    for i in xs + ys {
        i.ok = True;
    }
}
