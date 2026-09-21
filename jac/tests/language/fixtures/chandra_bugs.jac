def foo(param: int, **kwargs: int) -> tuple[any, ...] {
    return (param + kwargs['bar'], 'from_foo');
}

glob mydict = {'new_val': 1, 'where': 0};
with entry {
    (mydict['new_val'], mydict['where']) = foo(1, bar=2);
    print(f"<link href='{mydict}' rel='stylesheet'>");
    print(1 != 2);
}
