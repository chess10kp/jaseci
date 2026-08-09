"""flow for runtime semantics: per-element body over lent collections,
join at the closing brace. Output is an order-independent reduction (sum)
so it is deterministic and byte-identical across backends and gc modes,
including the rc build's real pthread fan-out (#7870/#7873), where the
per-element execution order is not preserved."""

obj P {
    has x: int = 0;
}

with entry {
    ps: list[P] = [P(x=1), P(x=2), P(x=3)];
    flow for m in &mut ps {
        m.x = m.x * 10;
    }
    # Read back sequentially: the in-place &mut flow leaves list order
    # intact (each task writes disjoint element slots), so a positional
    # sum is deterministic regardless of the flow's execution order.
    total: int = 0;
    for m in &ps {
        total += m.x;
    }
    print(total);
}

glob xs = [4, 5],
     k = 2;

with entry {
    # Immutable flow-for reduction: `+=` on an outer int accumulator is
    # lowered as per-task partials combined at the join, so the result is
    # identical across gc modes and thread widths.
    acc: int = 0;
    flow for v in &xs {
        acc += v * k;
    }
    print(acc);
    print("end");
}
