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
    print("try+while: " + (compile_text(t1 + "while x:\n    x = 0\n", "a") or "OK"));
    print("try+if: " + (compile_text(t1 + "if x:\n    y = 1\n", "b") or "OK"));
    print("try+for: " + (compile_text(t1 + "for i in x:\n    y = 1\n", "c") or "OK"));
    print("try+with: " + (compile_text(t1 + "with x:\n    y = 1\n", "d") or "OK"));
    print("try+def: " + (compile_text(t1 + "def f():\n    pass\n", "e") or "OK"));
    print("try+class: " + (compile_text(t1 + "class C:\n    pass\n", "f") or "OK"));
    print("try+lambda-assign: " + (compile_text(t1 + "f = lambda: 1\n", "g") or "OK"));
}
