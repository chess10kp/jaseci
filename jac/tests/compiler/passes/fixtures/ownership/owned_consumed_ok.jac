obj File {
    has fd: int = 0;
}

def take(x: File) {}

with entry {
    f: own File = File();
    take(f);
}
