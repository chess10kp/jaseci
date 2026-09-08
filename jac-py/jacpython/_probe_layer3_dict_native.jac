import from product_compile { compile_source }
import from pyc_first { PyObj, PyStr, to_host, is_error, exec_code }

glob src = "def f(): pass\n"
     "f.tag = 7\n"
     "fd = f.__dict__['tag']\n"
     "class C:\n"
     "    cvar = 5\n"
     "cd = 'cvar' in C.__dict__\n"
     "o = C()\n"
     "o.iv = 9\n"
     "od = o.__dict__['iv']\n"
     "import operator\n"
     "md = 'add' in operator.__dict__\n";

with entry {
    g: dict[str, PyObj] = {
        "__name__": PyStr(t="str", val="m"),
        "__package__": PyStr(t="str", val="")
    };
    co = compile_source(src, "<m>", "exec", 0);
    if is_error(co) {
        print("COMPILE_ERROR");
    } else {
        outcome = exec_code(co, [], g);
        if is_error(outcome) {
            print("EXEC_ERROR");
        } else {
            print("fd=" + str(to_host(g["fd"])));
            print("cd=" + str(to_host(g["cd"])));
            print("od=" + str(to_host(g["od"])));
            print("md=" + str(to_host(g["md"])));
        }
    }
}
