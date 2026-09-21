"""Function-local lists whose header provably stays in the frame.

The `sN` functions bind list displays to locals whose uses are all
header-local, so the backend constructs the header in the frame; the `nN`
functions escape the list (global store, user-call argument) and must fall
back to the heap header. Escape variants read their list after the creating
frame returned, which reads freed memory if the header was wrongly left on
the stack.
"""

glob sink: list[int] = [];
glob item_drops: int = 0;

obj Item {
    has value: int;

    def drop {
        item_drops += 1;
    }
}

def read_sink -> int {
    return sink[0] * 10 + sink[1];
}

def item_drop_count -> int {
    return item_drops;
}

def take_list(v: list[int]) -> int {
    return len(v) * 10 + v[0];
}

def s1_churn_append -> int {
    x = [1, 2];
    x.append(3);
    i = 0;
    t = 0;
    while i < 3 {
        x.append(i);
        t = t + x[i];
        i = i + 1;
    }
    return len(x) + t;
}

def s2_annotated_empty_then_fill -> int {
    x: list[int] = [];
    x.append(41);
    x.append(43);
    return x[0] + x[1];
}

def s3_iterate -> int {
    x = [2, 4, 6];
    t = 0;
    for v in x {
        t = t + v;
    }
    return t;
}

def s4_overwrite -> int {
    x = [1, 1];
    x = [2, 2];
    return x[0] + x[1] + len(x);
}

def s5_items_released_at_scope_exit -> int {
    items: list[Item] = [Item(1), Item(2), Item(3)];
    return items[2].value;
}

def n1_escape_global_store -> int {
    x = [4, 5];
    sink = x;
    return 0;
}

def n2_escape_call_arg -> int {
    x = [7, 8];
    return take_list(x);
}
