import from product_compile { compile_source }
import from objects { is_error }

glob t1 = "try:\n    pass\nexcept ImportError:\n    pass\n";
with entry {
    r = compile_source(t1 + t1, "b", "exec", 0);
    print("res: " + (str(r) if is_error(r) else "OK"));
}
