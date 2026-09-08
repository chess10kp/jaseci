import from product_compile { compile_source }
import from objects { is_error }

def check(path: str, name: str) {
    f = open(path, "r");
    src = f.read();
    f.close();
    r = compile_source(src, name, "exec", 0);
    if is_error(r) {
        print(name + ": FAIL " + str(r));
    } else {
        print(name + ": OK");
    }
}

glob RT = "/home/jac/.cache/jac/rt/1c12cbaf7915a3e3-cc5436a066063c0a/python/lib/python3.14/";
with entry {
    check(RT + "functools.py", "functools.py");
    check(RT + "collections/__init__.py", "collections/__init__.py");
    check(RT + "contextlib.py", "contextlib.py");
    check(RT + "types.py", "types.py");
    check(RT + "reprlib.py", "reprlib.py");
    check(RT + "operator.py", "operator.py");
}
