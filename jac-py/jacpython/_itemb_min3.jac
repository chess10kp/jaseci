import from product_compile { compile_source }
import from objects { is_error }

def compile_text(txt: str, name: str) -> str {
    r = compile_source(txt, name, "exec", 0);
    if is_error(r) {
        return str(r);
    }
    return "";
}

glob t1 = "try:\n    pass\nexcept ImportError:\n    pass\n";
with entry {
    print("try+x: " + (compile_text(t1 + "x = 1\n", "a") or "OK"));
    print("try+print: " + (compile_text(t1 + "print(x)\n", "b") or "OK"));
    print("try+x+x: " + (compile_text(t1 + "x = 1\ny = 2\n", "c") or "OK"));
    print("x+try+x: " + (compile_text("x = 0\n" + t1 + "x = 1\n", "d") or "OK"));
    print(
        "try-exc-body+try: "
            + (
                compile_text(
                    "try:\n    x = 1\nexcept ImportError:\n    pass\ntry:\n    pass\nexcept ImportError:\n    pass\n",
                    "e"
                )
                or "OK"
            )
    );
}
