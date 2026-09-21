"""Bare generic types (e.g. list without type args) are an E1036 error; reads
through them still behave as any, so only the annotation is reported."""

obj Item {
    has name: str,
        value: int;
}

glob
     # Bare list (no type args) - iterating should yield Any, not Unknown
     items: list = [];
with entry {
    for item in items {
        x = item.name;  # <-- Should be OK (Any allows attribute access)
        y = item.whatever;  # <-- Should be OK (Any allows any attribute)
    }
}

glob
     # Bare dict - iterating should yield Any, not Unknown
     data: dict = {};
with entry {
    for key in data {
        z = key.upper;  # <-- Should be OK (Any allows attribute access)
    }
}

glob
     # Bare list in comprehension
     other: list = [];
with entry {
    result = [o.name for o in other];  # <-- Should be OK

    # Bare list subscript should also work (not just iteration)
    first = items[0];
    w = first.whatever;  # <-- Should be OK (Any allows attribute access)
}

glob
     # Typed list should still catch errors
     typed: list[int] = [1, 2, 3];
with entry {
    for t in typed {
        a: int = t;  # <-- OK
        b: str = t;  # <-- Error (int not assignable to str)
    }
}
