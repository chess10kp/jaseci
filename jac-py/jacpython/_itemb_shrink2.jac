# Item B shrink2: minimal head that fails with trailing module try
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
    f = open("/tmp/itemb_cands.json", "r");
}
import json;
with entry {
    cands = json.loads(f.read());
    f.close();
}

glob trysniff = "\ntry:\n    pass\nexcept ImportError:\n    pass\n";
with entry {
    for k in cands.keys() {
        res = compile_text(cands[k] + trysniff, k);
        print(k + ": " + (res or "OK"));
    }
}
