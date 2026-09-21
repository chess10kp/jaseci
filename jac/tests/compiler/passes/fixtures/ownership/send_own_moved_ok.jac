obj Buffer {
    has n: int = 0;
}

def use1(x: Buffer) {}

with entry {
    a: own Buffer = Buffer();
    flow use1(a) ;
}
