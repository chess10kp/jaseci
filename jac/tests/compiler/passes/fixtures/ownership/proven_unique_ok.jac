obj Buffer {
    has n: int = 0;
}

def take(x: Buffer) {}

with entry {
    a: own Buffer = Buffer();
    take(a);
}
