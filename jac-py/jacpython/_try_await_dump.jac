# Prefix + try/pass cuts for functools reduction.
import from product_compile { compile_source }
import from objects { is_error }

glob rt = "/home/jac/.cache/jac/rt/1c12cbaf7915a3e3-cc5436a066063c0a/python/lib/python3.14";

with entry {
    f = open(rt + "/functools.py", "r");
    lines = f.read().split("\n");
    f.close();
}

glob tail = "try:\n    pass\nexcept ImportError:\n    pass\n";
with entry {
    for upto in [199, 223, 228, 235, 265, 293, 311, 357, 366, 368, 434] {
        prefix = "SENTINEL = 0\n" + "\n".join(lines[:upto]) + "\n" + tail;
        r = compile_source(prefix, "<f>", "exec", 0);
        if is_error(r) {
            print("FAIL @" + str(upto));
        } else {
            print("OK   @" + str(upto));
        }
    }
}
