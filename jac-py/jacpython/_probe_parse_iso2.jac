import from parser { parse_file }
import from product_compile { compile_source }
import from objects { is_error }

import sys;
glob path = sys.argv[1];
with entry {
    f = open(path, "r");
    src = f.read();
    f.close();
    m = parse_file(src, path);
    print("parse: " + ("OK" if m is not None else "None"));
    r = compile_source(src, path, "exec", 0);
    print("compile: " + ("ERR: " + str(r) if is_error(r) else "OK"));
}
