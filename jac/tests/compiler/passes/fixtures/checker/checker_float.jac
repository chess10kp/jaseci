glob pi = 3.14;  # <-- infer the type
with entry {
    f: float = pi;  # <-- OK
    s: str = pi;  # <-- Error
}
