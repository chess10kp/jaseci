import from reprlib { Repr, repr }

glob d: dict[str, any] = {"b": 1, "a": 2, "c": 3, "d": 4, "e": 5},
     r: Repr = Repr(),
     keys: list[str] = [];

with entry {
    print("mod-repr:", repr(d));
    print("maxdict:", r.maxdict, " maxlist:", r.maxlist);
    print("inst-repr:", r.repr(d));
    for k in d {
        keys.append(k);
    }
    print("keys:", keys);
}
