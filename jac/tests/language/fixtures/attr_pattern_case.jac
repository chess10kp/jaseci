obj A {
    has b: B;
}

obj B {
    has c: str;
}

glob expr = "Hello Jaseci!";
with entry {
    a = A(B(expr));
    match expr {
        case a.b.c:
            print("Matched a.b.c", a.b.c);

        case _:
            print("No match");

    }
}
