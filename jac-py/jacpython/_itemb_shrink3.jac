# Item B shrink3: binary search minimal failing prefix length
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
}

glob trysniff = "\ntry:\n    pass\nexcept ImportError:\n    pass\n",
     # statement boundaries from host AST
     bounds = [
         2,
         15,
         17,
         18,
         20,
         21,
         22,
         23,
         33,
         34,
         63,
         77,
         94,
         101,
         108,
         115,
         122,
         129,
         136,
         143,
         150,
         157,
         164,
         171,
         186,
         199,
         223,
         228,
         235,
         265,
         293,
         295,
         311,
         357,
         366,
         434
     ];

with entry {
    fails = [];
    for b in bounds {
        head = "\n".join(lines[:b]);
        res = compile_text(head + trysniff, "p" + str(b));
        if res != "" {
            fails = fails + [b];
        }
    }
    print("failing boundaries: " + str([fails]));
    # also test without try
    for b in bounds {
        head = "\n".join(lines[:b]);
        res = compile_text(head + "\n", "q" + str(b));
        if res != "" {
            print("no-try fail @" + str(b) + ": " + res);
        }
    }
    print("done");
}
