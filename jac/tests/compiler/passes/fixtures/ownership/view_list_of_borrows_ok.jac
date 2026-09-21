obj Item {
    has id: int = 0;
}

def evens(xs: &list[own Item]) -> int {
    picked: list[&Item] = [];
    for it in &xs {
        if it.id % 2 == 0 {
            picked.append(it);
        }
    }
    return len(picked);
}

glob xs: list[own Item] = [];
with entry {
    xs.append(Item(id=2));
    xs.append(Item(id=3));
    print(evens(&xs));
}
