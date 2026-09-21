glob rows: list[dict[str, int]] = [{"n": 2}, {"n": 1}];
with entry {
    by_key = sorted(rows, key=lambda (d) { d["n"]; });
}

glob nums: list[int] = [3, 1, 2];
with entry {
    descending = sorted(nums, key=lambda (x) { -x; });
    biggest = max(nums, key=lambda (x) { x; });
    smallest = min(nums, key=lambda (x) { x; });
}

glob words: list[str] = ["bb", "a", "ccc"];
with entry {
    by_len = sorted(words, key=lambda (s) { len(s); });
    only_long = list(filter(lambda (s) { len(s) > 1; }, words));

    # Operators, subscripts, and method/attr access on the inferred param.
    arithmetic = sorted(nums, key=lambda (x) { x * 2 - 1; });
}

glob captured_bias: int = 10;
with entry {
    with_capture = sorted(nums, key=lambda (x) { x + captured_bias; });
    dict_arith = sorted(rows, key=lambda (d) { d["n"] + 1; });
    by_upper = sorted(words, key=lambda (s) { s.upper(); });

    # An explicit `return` body seeds exactly like an implicit one.
    ret_subscript = sorted(rows, key=lambda (d) { return d["n"]; });
    ret_call = sorted(words, key=lambda (s) { return len(s); });
    ret_arith = sorted(nums, key=lambda (x) { return x * 2 - 1; });

    print(
        by_key,
        descending,
        biggest,
        smallest,
        by_len,
        only_long,
        arithmetic,
        with_capture,
        dict_arith,
        by_upper,
        ret_subscript,
        ret_call,
        ret_arith
    );
}
