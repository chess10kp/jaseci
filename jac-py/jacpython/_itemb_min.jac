import from product_compile { compile_source }
import from objects { is_error }

def compile_text(txt: str, name: str) -> str {
    r = compile_source(txt, name, "exec", 0);
    if is_error(r) {
        return str(r);
    }
    return "";
}

with entry {
    print(
        "try+try pass: "
            + (
                compile_text(
                    "try:\n    pass\nexcept ImportError:\n    pass\ntry:\n    pass\nexcept ImportError:\n    pass\n",
                    "a"
                )
                or "OK"
            )
    );
    print(
        "try+try import: "
            + (
                compile_text(
                    "try:\n    from functools import reduce as _reduce\nexcept ImportError:\n    _reduce = None\ntry:\n    pass\nexcept ImportError:\n    pass\n",
                    "b"
                )
                or "OK"
            )
    );
    print(
        "try-import+try-pass: "
            + (
                compile_text(
                    "try:\n    from functools import reduce as _reduce\nexcept ImportError:\n    pass\ntry:\n    pass\nexcept ImportError:\n    pass\n",
                    "c"
                )
                or "OK"
            )
    );
    print(
        "try-real228+trypass: "
            + (
                compile_text(
                    "try:\n    from functools import reduce as _reduce\n    from operator import lt as _lt\nexcept ImportError:\n    _reduce = None\n    _lt = None\ntry:\n    pass\nexcept ImportError:\n    pass\n",
                    "d"
                )
                or "OK"
            )
    );
}
