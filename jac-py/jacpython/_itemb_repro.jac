# Item B repro: functools head (1-434) + module-level try -> stack underflow?
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
    f = open(
        "/home/jac/.cache/jac/rt/1c12cbaf7915a3e3-cc5436a066063c0a/python/lib/python3.14/functools.py",
        "r"
    );
    lines = f.read().split("\n");
    f.close();
    head = "\n".join(lines[:434]);
    print("head434 alone: " + (compile_text(head + "\n", "functools_head") or "OK"));
    print(
        "head434+try: "
            + (
                compile_text(
                    head
                        + "\ntry:\n    from _functools import partial, Placeholder, _PlaceholderType\nexcept ImportError:\n    pass\n",
                    "functools_head_try"
                )
                or "OK"
            )
    );
    print(
        "head434+trypass: "
            + (
                compile_text(
                    head + "\ntry:\n    pass\nexcept ImportError:\n    pass\n",
                    "functools_head_trypass"
                )
                or "OK"
            )
    );
}
