import from product_compile { compile_source }
import from objects { is_error, PyError }

def try_src(label: str, src: str) {
    co = compile_source(src, label, "exec", 0);
    if is_error(co) {
        e = co as PyError;
        print(label + ": " + e.exception.type_name + ": " + e.exception.message);
    } else {
        print(label + ": OK");
    }
}

with entry {
    try_src(
        "full",
        "def f(): pass\nf.tag = 7\nfd = f.__dict__['tag']\nclass C:\n    cvar = 5\ncd = 'cvar' in C.__dict__\no = C()\no.iv = 9\nod = o.__dict__['iv']\nimport operator\nmd = 'add' in operator.__dict__\n"
    );
    try_src("import_only", "import operator\n");
    try_src("import_md", "import operator\nmd = 'add' in operator.__dict__\n");
    try_src("md_only", "md = 'add' in operator.__dict__\n");
}
