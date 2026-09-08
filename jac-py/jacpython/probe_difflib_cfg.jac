import from ceval { import_native }
import from objects { is_error, PyError }

def try_import(name: str) {
    mod = import_native(name);
    if is_error(mod) {
        e = mod as PyError;
        print(
            name + " import: FAIL " + e.exception.type_name + ": " + e.exception.message
        );
    } else {
        print(name + " import: OK");
    }
}

test "probe difflib cfg" {
    try_import("difflib");
    try_import("collections");
    try_import("types");
    assert False;
}
