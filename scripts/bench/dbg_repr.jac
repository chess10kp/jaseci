import from reprlib { Repr, repr }


def fn_repr(d: dict[str, any]) -> str {
    return repr(d);
}


def fn_dictret -> dict[any, any] {
    d1: dict[str, any] = {"b": 1, "a": 2, "c": 3, "d": 4, "e": 5};
    return {"d1": repr(d1)};
}


def fn_inst(d: dict[str, any]) -> str {
    r: Repr = Repr();
    return r.repr(d);
}


glob d: dict[str, any] = {"b": 1, "a": 2, "c": 3, "d": 4, "e": 5};

with entry {
    res: dict[any, any] = fn_dictret();
    print("entry-repr:", repr(d));
    print("fn-repr:", fn_repr(d));
    print("fn-inst:", fn_inst(d));
    print("dictret-d1:", res["d1"]);
}
