"""Bundled native `string` cross-backend equivalence fixture (#6978 Phase 3).

The SAME `import from string { ... }` binds CPython's `string` on the sv
(Python) backend and the bundled `na_stdlib/string.jac` Mechanism-B module on
the na (native LLVM) backend. Only the ASCII constant set, `capwords`, and the
`$`-`Template` subset (`substitute`, `safe_substitute`, `is_valid`,
`get_identifiers`) are exercised -- `Formatter`, brace-style templates, and
locale-aware behavior are outside the native module's scope.

`get_identifiers` returns a list, which the cross-backend harness reads as raw
i64, so it is probed via `len(...)` and element reads. `suberr`/`caperr` pin the
KeyError / ValueError paths; `lit*` pin `safe_substitute`'s literal preservation
of malformed placeholders. ES/JS opts out.
"""

import from string { capwords, digits, hexdigits, whitespace, Template }


def string_py -> dict[any, any] {
    suberr: str = "no raise";
    try {
        Template("$nope").substitute({"a": "1"});
    } except KeyError {
        suberr = "KeyError";
    }
    caperr: str = "no raise";
    try {
        capwords("a b", "");
    } except ValueError {
        caperr = "ValueError";
    }
    ids: list[str] = Template("$a $b $a ${c} $$d").get_identifiers();
    m: dict[str, any] = {"n": 42};
    return {
        "digs": digits,
        "hexn": len(hexdigits),
        "wsn": len(whitespace),
        "cap1": capwords("hello world foo"),
        "cap2": capwords("a,b,,c", ","),
        "cap3": capwords("they're bill's"),
        "caperr": caperr,
        "sub1": Template("Hello $name, ${x}y $$ $missing").safe_substitute(
            {"name": "W", "x": "1"}
        ),
        "sub2": Template("$n").substitute(m),
        "sub3": Template("A${b}C").substitute({"b": "z"}),
        "suberr": suberr,
        "valid1": Template("a $b").is_valid(),
        "valid2": Template("a $").is_valid(),
        "valid3": Template("${").is_valid(),
        "ids0": ids[0],
        "ids1": ids[1],
        "idsn": len(ids),
        "lit1": Template("$").safe_substitute({}),
        "lit2": Template("${unclosed").safe_substitute({}),
        "lit3": Template("$1x").safe_substitute({}),
        "lit4": Template("x$y").safe_substitute({})
    };
}


def string_cl -> dict[any, any] {
    return {};
}


def string_na -> dict[str, any] {
    suberr: str = "no raise";
    try {
        Template("$nope").substitute({"a": "1"});
    } except KeyError {
        suberr = "KeyError";
    }
    caperr: str = "no raise";
    try {
        capwords("a b", "");
    } except ValueError {
        caperr = "ValueError";
    }
    ids: list[str] = Template("$a $b $a ${c} $$d").get_identifiers();
    m: dict[str, any] = {"n": 42};
    return {
        "digs": digits,
        "hexn": len(hexdigits),
        "wsn": len(whitespace),
        "cap1": capwords("hello world foo"),
        "cap2": capwords("a,b,,c", ","),
        "cap3": capwords("they're bill's"),
        "caperr": caperr,
        "sub1": Template("Hello $name, ${x}y $$ $missing").safe_substitute(
            {"name": "W", "x": "1"}
        ),
        "sub2": Template("$n").substitute(m),
        "sub3": Template("A${b}C").substitute({"b": "z"}),
        "suberr": suberr,
        "valid1": Template("a $b").is_valid(),
        "valid2": Template("a $").is_valid(),
        "valid3": Template("${").is_valid(),
        "ids0": ids[0],
        "ids1": ids[1],
        "idsn": len(ids),
        "lit1": Template("$").safe_substitute({}),
        "lit2": Template("${unclosed").safe_substitute({}),
        "lit3": Template("$1x").safe_substitute({}),
        "lit4": Template("x$y").safe_substitute({})
    };
}
