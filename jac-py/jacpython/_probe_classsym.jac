import from product_compile { compile_source }
import from objects { is_error, PyError }

def try_src(label: str, src: str) {
    r = compile_source(src, "<t>", "exec", 0);
    if is_error(r) {
        ex = (r as PyError).exception;
        print(label + ": " + ex.type_name + ": " + ex.message);
    } else {
        print(label + ": OK");
    }
}

with entry {
    try_src(
        "SC1 two same-name classes with methods",
        "class C:\n"
        "    def m(self):\n"
        "        return 1\n"
        "class C:\n"
        "    def n(self):\n"
        "        return 2\n"
        "x = C().n()\n"
    );
}
