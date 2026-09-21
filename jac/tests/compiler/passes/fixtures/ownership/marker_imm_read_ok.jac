obj Buffer {
    has n: int = 0;
}

def use1(x: Buffer) {}

with entry {
    v: imm Buffer = Buffer();
    x = v.n;
    use1(v);
}
