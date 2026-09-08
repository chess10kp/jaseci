# Item B shrink: which prefix statements of functools head are essential?
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
    f = open("/home/jac/.cache/jac/rt/1c12cbaf7915a3e3-cc5436a066063c0a/python/lib/python3.14/functools.py", "r");
    lines = f.read().split("\n");
    f.close();
    head = "\n".join(lines[:434]);
    trysniff = "\ntry:\n    pass\nexcept ImportError:\n    pass\n";
    # try whole-head
    print("whole head+try: " + (compile_text(head + trysniff, "w") or "OK"));
    # bisect: drop first N statements — instead bisect by removing trailing part of head (keep first K lines), then re-append the class partial body? Too complex.
    # Simpler: find last failing prefix. Try removing chunks from the START of head, keep the tail (class partial is the important part).
    # class partial spans which lines? find "class partial"
    for i, l in enumerate(lines[:434]) {
        if l.startswith("class partial") or l.startswith("class ") or l.startswith("def ") {
            print("stmt@" + str(i + 1) + ": " + l[:60]);
        }
    }
}
