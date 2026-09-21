obj Buffer {
    has n: int = 0;

    def eat(x: Buffer) {}
}

with entry {
    a: own Buffer = Buffer();
    a.eat(a);
}
