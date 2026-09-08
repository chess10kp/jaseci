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
    print("1-try: " + (compile_text(t1, "a") or "OK"));
    print("2-try: " + (compile_text(t1 + t1, "b") or "OK"));
    print("3-try: " + (compile_text(t1 + t1 + t1, "c") or "OK"));
    print("try+stmt+try: " + (compile_text(t1 + "x = 1\n" + t1, "d") or "OK"));
    print(
        "try-except-else+try: "
            + (
                compile_text(
                    "try:\n    pass\nexcept ImportError:\n    pass\nelse:\n    pass\n"
                        + t1,
                    "e"
                )
                or "OK"
            )
    );
    print(
        "try-except-finally+try: "
            + (
                compile_text(
                    "try:\n    pass\nexcept ImportError:\n    pass\nfinally:\n    pass\n"
                        + t1,
                    "f"
                )
                or "OK"
            )
    );
    print(
        "try-bare-except+try: "
            + (compile_text("try:\n    pass\nexcept:\n    pass\n" + t1, "g") or "OK")
    );
    print(
        "try-finally+try: "
            + (compile_text("try:\n    pass\nfinally:\n    pass\n" + t1, "h") or "OK")
    );
    print(
        "fn-with-try+try: "
            + (
                compile_text(
                    "def f():\n    try:\n        pass\n    except ImportError:\n        pass\n"
                        + t1,
                    "i"
                )
                or "OK"
            )
    );
}
