def make(a: int, b: int, c: int) {}
def greet(name: str, greeting: str) {}

glob
     # A `*`/`**` spread of statically-unknown contents may supply a param, but
     # we cannot prove it did -- so a later explicit keyword for that param is
     # NOT a duplicate. None of the calls below should emit E1057.
     nums = (1, 2);
with entry {
    make(*nums, c=3);  # *-spread covers a, b -- explicit c is not a duplicate
}

glob opts = {"greeting": "hello"};
with entry {
    greet(**opts, name="bob");  # **-spread covers greeting -- explicit name is fine
}

glob extra = {"b": 2};
with entry {
    make(1, **extra, c=3);  # positional a + **-spread + explicit c -- none duplicated
}

glob
     # Preserved behavior: a spread still satisfies the required-param check, so
     # the params it may supply are not reported as missing.
     full = {"a": 1, "b": 2, "c": 3};
with entry {
    make(**full);
}
