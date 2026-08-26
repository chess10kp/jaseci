"""Regression: universal dunders resolve on optional exception-chaining attrs.

`__cause__`/`__context__` are typed `BaseException | None`; CPython answers
`__class__` (and the other universal identity dunders) on every object,
None included, so chained access like `e.__cause__.__class__.__name__`
must type check instead of reporting "attribute is missing from NoneType".
"""

def cause_class_name(e: BaseException) -> str {
    c = e.__cause__;
    return c.__class__.__name__;  # Ok
}

def context_class_name(e: BaseException) -> str {
    return e.__context__.__class__.__name__;  # Ok
}

def suppress_flag(e: BaseException) -> bool {
    return e.__suppress_context__;  # Ok
}
