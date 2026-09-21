import typing;

with entry {
    tl: list[Foo] = [Foo(), Foo()];

    for it in tl {
        tifoo: Foo = it;
        tistr: str = it;  # <-- Error
    }
}

glob K = TypeVar('K'),
     V = TypeVar('V');

obj HashTable(Generic[K, V]) {
    has data: dict[K, V] = {};

    def insert(key: K, value: V) {
        self.data[key] = value;
    }

    def get(key: K) -> V {
        return self.data[key];
    }
}

obj Foo {
    has bar: str = "";
}

with entry {
    lst: list[Foo] = [Foo(), Foo()];
    f: Foo = lst[0];  # <-- Ok
    s: str = lst[0];  # <-- Error

    for it in lst {
        tifoo: Foo = it;  # <-- Ok
        tistr: str = it;  # <-- Error
    }
}

glob m: list[int] = [1, 2, 3];
with entry {
    n: int = m[0];
    p: str = m[0];  # <-- Error
}

glob x: list[str] = ["a", "b", "c"];
with entry {
    y: str = x[1];
    z: int = x[1];  # <-- Error
}

glob d: dict[int, str] = {1: "one", 2: "two"};
with entry {
    s: str = d[1];
    i: int = d[1];  # <-- Error

    ht = HashTable[int, str]();
    ht.insert(1, "one");
    ht.insert("one", "one");  # <-- Error
    ht.insert(1, 1);  # <-- Error

    hv1: str = ht.get(1);
    hv2: int = ht.get(1);  # <-- Error
}
