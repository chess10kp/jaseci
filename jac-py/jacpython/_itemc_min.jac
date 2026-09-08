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
        "/home/jac/.cache/jac/rt/1c12cbaf7915a3e3-cc5436a066063c0a/python/lib/python3.14/collections/__init__.py",
        "r"
    );
    lines = f.read().split("\n");
    f.close();
    print(
        "coll[:55]: "
            + (
                compile_text("SENTINEL = 0\n" + "\n".join(lines[:55]) + "\n", "c55")
                or "OK"
            )
    );
    print(
        "coll[:49]: "
            + (
                compile_text("SENTINEL = 0\n" + "\n".join(lines[:49]) + "\n", "c49")
                or "OK"
            )
    );
}
